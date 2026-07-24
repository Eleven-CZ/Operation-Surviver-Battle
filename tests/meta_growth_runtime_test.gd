extends SceneTree

const CareerCatalog := preload("res://scripts/career_catalog.gd")

const CURVE_TEST_LEVEL := 256
const EPSILON := 0.0001
const GEOMETRY_EPSILON := 0.02

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var profile := get_root().get_node("ProfileStore")
	profile.reset_for_tests()
	profile.unlock_career("network")
	_require(profile.select_career("network"), "network career can be selected for geometry verification")
	var run: Node = load("res://scenes/run.tscn").instantiate()
	run.process_mode = Node.PROCESS_MODE_DISABLED
	get_root().add_child(run)

	_test_movement_curve(run)
	_test_action_cooldown_curves(run.get_node("CareerActionSystem"))
	_test_signature_area_preview_integration(run)

	get_root().remove_child(run)
	run.free()
	if failed:
		quit(1)
		return
	print("META_GROWTH_RUNTIME_TEST_PASS movement=1.60x skill_floor=2s ultimate_floor=18s cooldown_rescale=ratio preview=network")
	quit(0)


func _test_movement_curve(run: Node) -> void:
	var base_multiplier := float(run.call("_movement_multiplier_for_level", 0))
	_require(is_equal_approx(base_multiplier, 1.0), "movement growth starts at the career base speed")
	var previous := base_multiplier
	for level_value in range(1, CURVE_TEST_LEVEL + 1):
		var current := float(run.call("_movement_multiplier_for_level", level_value))
		_require(current > previous, "movement growth remains strictly useful at level %d" % level_value)
		_require(current <= 1.60 + EPSILON, "movement growth never exceeds 1.60x at level %d" % level_value)
		previous = current
	var near_limit := float(run.call("_movement_multiplier_for_level", 1_000_000))
	_require(near_limit > previous and near_limit <= 1.60 + EPSILON, "movement growth approaches but never exceeds its 1.60x asymptote")
	_require(near_limit >= 1.5999, "the long-run movement curve approaches the advertised 1.60x limit")

	var player: Node = run.get_node("Player")
	var runtime_level := 32
	run.movement_speed_level = runtime_level
	run.call("_refresh_meta_growth_and_artifacts")
	var expected_speed := float(run.career_move_speed_base) * float(run.call("_movement_multiplier_for_level", runtime_level))
	_require(absf(float(player.move_speed) - expected_speed) <= EPSILON, "runtime player speed uses the same movement-growth curve")


func _test_action_cooldown_curves(actions: Node) -> void:
	for career in CareerCatalog.all():
		var career_id := String(career.get("id", ""))
		actions.call("configure_career", career)
		var base_skill := float(actions.call("_skill_cooldown_for_level", 0))
		var base_ultimate := float(actions.call("_ultimate_cooldown_for_level", 0))
		var previous_skill := base_skill
		var previous_ultimate := base_ultimate
		for level_value in range(1, CURVE_TEST_LEVEL + 1):
			var skill_cooldown := float(actions.call("_skill_cooldown_for_level", level_value))
			var ultimate_cooldown := float(actions.call("_ultimate_cooldown_for_level", level_value))
			_require(skill_cooldown <= previous_skill + EPSILON, "%s skill cooldown never rises at level %d" % [career_id, level_value])
			_require(ultimate_cooldown <= previous_ultimate + EPSILON, "%s ultimate cooldown never rises at level %d" % [career_id, level_value])
			_require(skill_cooldown >= 2.0 - EPSILON, "%s skill cooldown respects the 2-second floor" % career_id)
			_require(ultimate_cooldown >= 18.0 - EPSILON, "%s ultimate cooldown respects the 18-second floor" % career_id)
			previous_skill = skill_cooldown
			previous_ultimate = ultimate_cooldown
		_require(previous_skill < base_skill and previous_ultimate < base_ultimate, "%s receives useful skill and ultimate cooldown growth" % career_id)

		# Existing timers keep their completion percentage when a new cooldown
		# stack is selected instead of restarting or subtracting a flat amount.
		actions.call("configure_career", career)
		var old_skill_cooldown := float(actions.call("_skill_cooldown"))
		var old_ultimate_cooldown := float(actions.call("_ultimate_cooldown"))
		var old_skill_remaining := old_skill_cooldown * 0.63
		var old_ultimate_remaining := old_ultimate_cooldown * 0.37
		actions.skill_cooldown_left = old_skill_remaining
		actions.ultimate_cooldown_left = old_ultimate_remaining
		actions.call("set_meta_growth_levels", 12, 12)
		var snapshot: Dictionary = actions.call("get_action_snapshot")
		var new_skill_cooldown := float(snapshot.get("skill", {}).get("cooldown", 0.0))
		var new_ultimate_cooldown := float(snapshot.get("ultimate", {}).get("cooldown", 0.0))
		var new_skill_remaining := float(snapshot.get("skill", {}).get("remaining", 0.0))
		var new_ultimate_remaining := float(snapshot.get("ultimate", {}).get("remaining", 0.0))
		_require(new_skill_remaining < old_skill_remaining and new_ultimate_remaining < old_ultimate_remaining, "%s active cooldowns are compressed when cooldown growth is selected" % career_id)
		_require(absf(new_skill_remaining - old_skill_remaining * new_skill_cooldown / old_skill_cooldown) <= EPSILON, "%s active skill cooldown is compressed proportionally" % career_id)
		_require(absf(new_ultimate_remaining - old_ultimate_remaining * new_ultimate_cooldown / old_ultimate_cooldown) <= EPSILON, "%s active ultimate cooldown is compressed proportionally" % career_id)
		_require(absf(new_skill_remaining / new_skill_cooldown - 0.63) <= EPSILON, "%s skill cooldown preserves elapsed progress" % career_id)
		_require(absf(new_ultimate_remaining / new_ultimate_cooldown - 0.37) <= EPSILON, "%s ultimate cooldown preserves elapsed progress" % career_id)


func _test_signature_area_preview_integration(run: Node) -> void:
	var actions: Node = run.get_node("CareerActionSystem")
	actions.call("configure_career", CareerCatalog.get_by_id("network"))
	actions.visuals.clear()
	actions.call("play_signature_range_preview")
	var base_line := _preview_line(actions)
	_require(not base_line.is_empty(), "network base range preview creates a line geometry")
	if base_line.is_empty():
		return
	var base_growth: Dictionary = actions.call("get_signature_growth_snapshot")
	var base_multiplier := float(base_growth.get("area_multiplier", 0.0))
	var previous_length := Vector2(base_line["from"]).distance_to(Vector2(base_line["to"]))
	var previous_width := float(base_line.get("half_width", 0.0)) * 2.0
	_require(absf(previous_length - 640.0 * base_multiplier) <= GEOMETRY_EPSILON, "base preview length uses the real signature-area snapshot multiplier")
	_require(absf(previous_width - 34.0 * base_multiplier) <= GEOMETRY_EPSILON, "base preview width uses the real signature-area snapshot multiplier")

	for expected_level in range(1, 6):
		actions.visuals.clear()
		run.call("_on_upgrade_selected", "signature_area")
		var growth: Dictionary = actions.call("get_signature_growth_snapshot")
		var levels: Dictionary = growth.get("levels", {})
		var multiplier := float(growth.get("area_multiplier", 0.0))
		var preview := _preview_line(actions)
		_require(int(levels.get("area", -1)) == expected_level, "signature-area upgrade reaches stack %d" % expected_level)
		_require(not preview.is_empty(), "signature-area upgrade automatically calls its range preview at stack %d" % expected_level)
		if preview.is_empty():
			return
		var preview_length := Vector2(preview["from"]).distance_to(Vector2(preview["to"]))
		var preview_width := float(preview.get("half_width", 0.0)) * 2.0
		_require(multiplier > base_multiplier, "signature-area snapshot multiplier grows at stack %d" % expected_level)
		_require(preview_length > previous_length and preview_width > previous_width, "network preview becomes longer and wider at stack %d" % expected_level)
		_require(absf(preview_length - 640.0 * multiplier) <= GEOMETRY_EPSILON, "network preview length matches the runtime multiplier at stack %d" % expected_level)
		_require(absf(preview_width - 34.0 * multiplier) <= GEOMETRY_EPSILON, "network preview width matches the runtime multiplier at stack %d" % expected_level)
		_require(absf(float(actions.call("_signature_area_multiplier")) - multiplier) <= EPSILON, "signature-area snapshot matches the cast geometry multiplier at stack %d" % expected_level)
		base_multiplier = multiplier
		previous_length = preview_length
		previous_width = preview_width


func _preview_line(actions: Node) -> Dictionary:
	for index in range(actions.visuals.size() - 1, -1, -1):
		var visual: Dictionary = actions.visuals[index]
		if String(visual.get("type", "")) == "range_preview_line":
			return visual
	return {}


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("META_GROWTH_RUNTIME_TEST_FAIL: " + message)
