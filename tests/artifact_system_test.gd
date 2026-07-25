extends SceneTree

const ArtifactCatalog := preload("res://scripts/artifact_catalog.gd")
const DifficultyCatalog := preload("res://scripts/difficulty_catalog.gd")
const SwarmWorld := preload("res://scripts/swarm_world.gd")

const EXPECTED_DROP_CHANCES := {
	"normal": 0.50,
	"advanced": 0.40,
	"abyss": 0.30,
	"impossible": 0.20,
}

var failure_count := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var profile := get_root().get_node("ProfileStore")
	profile.reset_for_tests()
	_require(profile.select_career("ops"), "test career can be selected")
	var run: Node = load("res://scenes/run.tscn").instantiate()
	run.process_mode = Node.PROCESS_MODE_DISABLED
	get_root().add_child(run)
	if not run.has_method("_try_drop_artifact"):
		push_error("ARTIFACT_SYSTEM_TEST_FAIL: RunController script did not load")
		quit(1)
		return

	_test_difficulty_probabilities(run)
	_test_drop_reservation_pickup_and_static_effect(run)
	_test_timed_trigger(run)
	_test_maximum_health_order_independence(run)
	_test_reboot_fallback_keeps_cooldown(run)
	_test_ground_choices_do_not_consume_carry_slots(run)

	get_root().remove_child(run)
	run.free()
	if failure_count > 0:
		quit(1)
		return
	print("ARTIFACT_SYSTEM_TEST_PASS chances=4 slots=2 pickup=ok static=drop_database_run trigger=kill_minus_9")
	quit(0)


func _test_difficulty_probabilities(run: Node) -> void:
	for difficulty_id in EXPECTED_DROP_CHANCES:
		var expected_chance := float(EXPECTED_DROP_CHANCES[difficulty_id])
		var config := DifficultyCatalog.get_by_id(String(difficulty_id))
		_require(not config.is_empty(), "%s difficulty exists" % difficulty_id)
		_require(is_equal_approx(float(config.get("artifact_drop_chance", -1.0)), expected_chance), "%s artifact chance is %.2f" % [difficulty_id, expected_chance])
		run.difficulty = config
		var snapshot: Dictionary = run.call("get_artifact_runtime_snapshot")
		_require(is_equal_approx(float(snapshot.get("drop_chance", -1.0)), expected_chance), "%s runtime exposes its artifact chance" % difficulty_id)
		_require(bool(run.call("_artifact_drop_succeeds", 0.0)), "%s accepts the lower probability boundary" % difficulty_id)
		_require(bool(run.call("_artifact_drop_succeeds", expected_chance - 0.000001)), "%s accepts rolls strictly below its chance" % difficulty_id)
		_require(not bool(run.call("_artifact_drop_succeeds", expected_chance)), "%s rejects a roll exactly equal to its chance" % difficulty_id)
		_require(not bool(run.call("_artifact_drop_succeeds", expected_chance + 0.000001)), "%s rejects rolls above its chance" % difficulty_id)
		_require(not bool(run.call("_artifact_drop_succeeds", -0.000001)), "%s rejects invalid negative direct rolls" % difficulty_id)
	run.difficulty = DifficultyCatalog.get_by_id("normal")


func _test_drop_reservation_pickup_and_static_effect(run: Node) -> void:
	var player: Node = run.get_node("Player")
	var loot: Node = run.get_node("LootWorld")
	var hud: Node = run.get_node("HUD")
	var base_move_speed := float(player.move_speed)
	var base_max_health := float(player.max_health)
	var drop_position: Vector2 = player.global_position + Vector2(8.0, 0.0)

	var failed_at_boundary := String(run.call("_try_drop_artifact", drop_position, 0.50, 0))
	_require(failed_at_boundary.is_empty(), "drop roll equal to the normal chance produces no artifact")
	_require(int(loot.call("get_artifact_snapshot").get("count", -1)) == 0, "failed rolls do not create ground artifacts")

	var first_candidates := ArtifactCatalog.available_excluding([])
	var static_index := _candidate_index(first_candidates, "drop_database_run")
	_require(static_index >= 0, "static artifact is available in the catalog")
	var first_drop := String(run.call("_try_drop_artifact", drop_position, 0.499999, static_index))
	_require(first_drop == "drop_database_run", "successful elite roll can select the requested static artifact")
	_require(loot.call("_artifact_icon_texture", first_drop) != null, "ground artifact visual layer retains its generated icon texture")
	var reel_snapshot: Dictionary = hud.call("get_artifact_reel_snapshot")
	_require(String(reel_snapshot.get("phase", "")) == "spinning" and String(reel_snapshot.get("selected_id", "")) == first_drop, "successful drops start the artifact slot-machine reveal")
	_require(paused and bool(run.call("get_artifact_runtime_snapshot").get("reel_paused", false)), "artifact lottery freezes the entire gameplay tree while the reel spins")
	hud.call("_update_artifact_reel", 2.0)
	reel_snapshot = hud.call("get_artifact_reel_snapshot")
	_require(String(reel_snapshot.get("phase", "")) == "result", "artifact reel stops on a confirmed result")
	_require(Array(reel_snapshot.get("displayed_ids", []))[1] == first_drop, "artifact reel center window stops on the selected artifact")
	_require(ArtifactCatalog.icon_texture(first_drop) != null, "selected artifact has its generated icon")
	_require(paused, "gameplay remains frozen while the artifact result is held on screen")
	hud.call("_update_artifact_reel", 2.0)
	_require(not paused and not bool(run.call("get_artifact_runtime_snapshot").get("reel_paused", true)), "gameplay resumes only after the complete artifact reel presentation")

	var excluded: Array[String] = [first_drop]
	var second_candidates := ArtifactCatalog.available_excluding(excluded)
	var trigger_index := _candidate_index(second_candidates, "kill_minus_9")
	_require(trigger_index >= 0, "trigger artifact remains available after the first reservation")
	var second_drop := String(run.call("_try_drop_artifact", drop_position, 0.0, trigger_index))
	_require(second_drop == "kill_minus_9", "a second successful elite roll reserves the remaining artifact slot")
	_require(paused, "every artifact lottery pauses gameplay, including later drops")
	var reserved_snapshot: Dictionary = run.call("get_artifact_runtime_snapshot")
	_require(int(reserved_snapshot.get("slots", 0)) == 2, "runtime exposes a two-slot artifact cap")
	_require(Array(reserved_snapshot.get("ground", [])).size() == 2, "two ground artifacts reserve both slots")
	_require(int(loot.call("get_artifact_snapshot").get("count", 0)) == 2, "loot world contains both reserved artifacts")
	_require(String(run.call("_try_drop_artifact", drop_position, 0.0, 0)).is_empty(), "equipped plus ground artifacts can never exceed two slots")
	hud.call("_update_artifact_reel", 2.0)
	hud.call("_update_artifact_reel", 2.0)
	_require(not paused, "second artifact reel also restores gameplay after its result hold")

	loot.call("_update_artifact_pickups", 0.0)
	var equipped_snapshot: Dictionary = run.call("get_artifact_runtime_snapshot")
	var equipped: Array = equipped_snapshot.get("equipped", [])
	_require(equipped.size() == 2, "walking over both drops equips both artifacts")
	_require("drop_database_run" in equipped and "kill_minus_9" in equipped, "pickup preserves both artifact identities")
	_require(get_root().get_node("ProfileStore").is_museum_unlocked("artifact", "drop_database_run"), "equipping an artifact unlocks its museum record")
	_require(Array(equipped_snapshot.get("ground", [])).is_empty(), "pickup clears runtime ground reservations")
	_require(int(loot.call("get_artifact_snapshot").get("count", -1)) == 0, "pickup removes artifacts from the loot world")
	_require(not bool(run.call("_equip_artifact", "sudo_bang_bang")), "direct equip also respects the two-slot cap")

	_require(is_equal_approx(float(player.move_speed), base_move_speed * 1.18), "DROP & RUN applies its +18% movement speed")
	_require(is_equal_approx(float(player.max_health), base_max_health * 0.90), "DROP & RUN applies its -10% maximum health")
	var damage_multiplier := float(equipped_snapshot.get("damage_multiplier", 0.0))
	_require(is_equal_approx(damage_multiplier, 1.12), "DROP & RUN applies its +12%% global damage (actual %s)" % str(damage_multiplier))
	var ui_snapshot: Dictionary = hud.call("get_artifact_ui_snapshot")
	_require(int(ui_snapshot.get("capacity", 0)) == 2 and int(ui_snapshot.get("count", 0)) == 2, "HUD renders both occupied artifact slots")
	var ui_ids: Array[String] = []
	for slot in ui_snapshot.get("slots", []):
		if bool(slot.get("occupied", false)):
			ui_ids.append(String(slot.get("id", "")))
	_require("drop_database_run" in ui_ids and "kill_minus_9" in ui_ids, "HUD slot identities match equipped artifacts")


func _test_timed_trigger(run: Node) -> void:
	var player: Node = run.get_node("Player")
	var swarm: Node = run.get_node("SwarmWorld")
	swarm.call("clear_all")
	_require(bool(swarm.call("spawn_enemy", SwarmWorld.EnemyKind.HTTP_404, player.global_position + Vector2(80.0, 0.0))), "trigger target can be spawned")
	_require(get_root().get_node("ProfileStore").is_museum_unlocked("fault", "http_404"), "spawning a fault unlocks its museum record")
	var initial_count := int(swarm.count)
	var initial_health := float(swarm.health[0])
	run.call("_update_artifacts", 11.99)
	_require(int(swarm.count) == initial_count and is_equal_approx(float(swarm.health[0]), initial_health), "timed artifact remains idle before its interval")
	run.call("_update_artifacts", 0.02)
	var damaged_or_closed := int(swarm.count) < initial_count
	if int(swarm.count) == initial_count:
		damaged_or_closed = float(swarm.health[0]) < initial_health
	_require(damaged_or_closed, "kill -9 trigger closes its selected fault after twelve seconds")
	var snapshot: Dictionary = run.call("get_artifact_runtime_snapshot")
	var timers: Dictionary = snapshot.get("timers", {})
	_require(timers.has("kill_minus_9") and float(timers["kill_minus_9"]) > 11.9, "timed trigger schedules its next interval")


func _test_maximum_health_order_independence(run: Node) -> void:
	_reset_artifacts(run)
	run.capacity_level = 0
	run.call("_refresh_meta_growth_and_artifacts")
	run.get_node("Player").health = run.get_node("Player").max_health
	run.call("_on_upgrade_selected", "capacity")
	_require(bool(run.call("_equip_artifact", "drop_database_run")), "DROP & RUN equips after capacity growth")
	var capacity_then_artifact := float(run.get_node("Player").max_health)

	_reset_artifacts(run)
	run.capacity_level = 0
	run.call("_refresh_meta_growth_and_artifacts")
	run.get_node("Player").health = run.get_node("Player").max_health
	_require(bool(run.call("_equip_artifact", "drop_database_run")), "DROP & RUN equips before capacity growth")
	run.call("_on_upgrade_selected", "capacity")
	var artifact_then_capacity := float(run.get_node("Player").max_health)
	_require(is_equal_approx(capacity_then_artifact, artifact_then_capacity), "maximum-health penalty is independent of pickup order")
	_require(is_equal_approx(float(run.last_player_health), float(run.get_node("Player").health)), "maximum-health recalculation is not reported as incoming damage")


func _test_reboot_fallback_keeps_cooldown(run: Node) -> void:
	_reset_artifacts(run)
	var actions: Node = run.get_node("CareerActionSystem")
	actions.call("set_meta_growth_levels", 256, 0)
	_require(bool(run.call("_equip_artifact", "reboot_device")), "reboot artifact equips for cooldown safety test")
	var total_cooldown := float(actions.call("get_action_snapshot").get("skill", {}).get("cooldown", 0.0))
	actions.skill_cooldown_left = total_cooldown
	var safe_seed := 1
	while safe_seed < 10_000:
		run.artifact_proc_rng.seed = safe_seed
		if run.artifact_proc_rng.randf() >= 0.22:
			break
		safe_seed += 1
	run.artifact_proc_rng.seed = safe_seed
	run.call("_on_career_action_used", "skill", "test")
	var remaining := float(actions.call("get_action_snapshot").get("skill", {}).get("remaining", 0.0))
	_require(remaining >= total_cooldown * 0.60 - 0.0001, "failed reboot proc retains at least 60%% of the effective skill cooldown")
	_require(remaining > 0.0, "failed reboot proc cannot turn a floor-level skill into infinite fire")


func _test_ground_choices_do_not_consume_carry_slots(run: Node) -> void:
	_reset_artifacts(run)
	var player: Node = run.get_node("Player")
	_require(bool(run.call("_equip_artifact", "reboot_device")), "one artifact occupies one carry slot")
	var first_candidates := ArtifactCatalog.available_excluding(["reboot_device"])
	var first_id := String(first_candidates[0]["id"])
	var first_drop := String(run.call("_try_drop_artifact", player.global_position + Vector2(8.0, 0.0), 0.0, 0))
	_require(first_drop == first_id, "one equipped artifact still permits a ground choice")
	var second_excluded: Array[String] = ["reboot_device", first_drop]
	var second_candidates := ArtifactCatalog.available_excluding(second_excluded)
	var second_id := String(second_candidates[0]["id"])
	var second_drop := String(run.call("_try_drop_artifact", player.global_position + Vector2(8.0, 0.0), 0.0, 0))
	_require(second_drop == second_id, "one equipped artifact can coexist with two ground choices")
	var choice_snapshot: Dictionary = run.call("get_artifact_runtime_snapshot")
	_require(Array(choice_snapshot.get("equipped", [])).size() == 1 and Array(choice_snapshot.get("ground", [])).size() == 2, "ground choices do not consume the two carry slots")
	run.get_node("LootWorld").call("_update_artifact_pickups", 0.0)
	var filled_snapshot: Dictionary = run.call("get_artifact_runtime_snapshot")
	_require(Array(filled_snapshot.get("equipped", [])).size() == 2, "choosing a ground artifact fills the second carry slot")
	_require(Array(filled_snapshot.get("ground", [])).is_empty(), "unusable ground choices are reclaimed after both carry slots fill")


func _reset_artifacts(run: Node) -> void:
	run.equipped_artifact_ids.clear()
	run.ground_artifact_ids.clear()
	run.artifact_timers.clear()
	run.artifact_intervals.clear()
	run.artifact_cooldowns.clear()
	run.artifact_once_used.clear()
	run.get_node("LootWorld").call("clear_artifacts")
	run.call("_refresh_meta_growth_and_artifacts")


func _candidate_index(candidates: Array[Dictionary], artifact_id: String) -> int:
	for index in range(candidates.size()):
		if String(candidates[index].get("id", "")) == artifact_id:
			return index
	return -1


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error("ARTIFACT_SYSTEM_TEST_FAIL: " + message)
