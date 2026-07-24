extends SceneTree

const CoworkerCatalog := preload("res://scripts/coworker_catalog.gd")
const EventCatalog := preload("res://scripts/event_catalog.gd")
const AllySupportScript := preload("res://scripts/ally_support_system.gd")
const PlayerScript := preload("res://scripts/player.gd")
const SwarmWorldScript := preload("res://scripts/swarm_world.gd")
const LootWorldScript := preload("res://scripts/loot_world.gd")
const PressureProjectionScript := preload("res://scripts/pressure_projection.gd")
const CareerActionSystemScript := preload("res://scripts/career_action_system.gd")
const CareerCatalog := preload("res://scripts/career_catalog.gd")

var failed := false
var player: CharacterBody2D
var swarm: Node2D
var loot: Node2D
var projection: Node2D
var actions: Node2D
var support: Node2D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_build_runtime()
	_test_catalog_and_event_coverage()
	_test_join_gate_and_growth()
	_test_all_nine_personas()
	_test_hud_contract()
	_destroy_runtime()
	if failed:
		quit(1)
		return
	print("ALLY_SUPPORT_SYSTEM_TEST_PASS personas=9 strategies=12 roles=heal/shield/resource/control/chain/area/clear/single/cooldown")
	quit(0)


func _build_runtime() -> void:
	player = PlayerScript.new()
	swarm = SwarmWorldScript.new()
	loot = LootWorldScript.new()
	projection = PressureProjectionScript.new()
	actions = CareerActionSystemScript.new()
	support = AllySupportScript.new()
	get_root().add_child(player)
	get_root().add_child(swarm)
	get_root().add_child(loot)
	get_root().add_child(projection)
	get_root().add_child(actions)
	get_root().add_child(support)
	player.global_position = Vector2(1200.0, 750.0)
	projection.global_position = player.global_position + Vector2(74.0, -58.0)
	projection.call("configure", player)
	projection.ally = true
	projection.active = true
	swarm.call("configure", player, 20260721)
	loot.call("configure", player)
	actions.call("configure", player, swarm, projection, null)
	actions.call("configure_career", CareerCatalog.get_by_id("ops"))
	support.call("configure", player, swarm, loot, projection, actions)
	player.set_physics_process(false)
	swarm.set_physics_process(false)
	loot.set_physics_process(false)
	projection.set_physics_process(false)
	actions.set_physics_process(false)
	support.set_physics_process(false)


func _destroy_runtime() -> void:
	for node in [support, actions, projection, loot, swarm, player]:
		get_root().remove_child(node)
		node.free()


func _test_catalog_and_event_coverage() -> void:
	var ids := CoworkerCatalog.ids()
	_require(ids.size() == 9, "catalog exposes exactly nine distinct coworkers")
	_require(ids.duplicate().all(func(persona_id: String) -> bool: return not persona_id.is_empty()), "all coworker ids are non-empty")
	var seen: Array[String] = []
	var strategy_count := 0
	for event in EventCatalog.all():
		for strategy in event.get("strategies", []):
			strategy_count += 1
			var persona_id := String(strategy.get("persona_id", ""))
			_require(persona_id in ids, "%s/%s has a valid coworker" % [event.get("id", "event"), strategy.get("id", "strategy")])
			if persona_id not in seen:
				seen.append(persona_id)
	_require(strategy_count == 12, "all twelve event strategies are audited")
	_require(seen.size() == ids.size(), "the twelve strategies make every coworker reachable")


func _test_join_gate_and_growth() -> void:
	player.max_health = 100.0
	player.health = 50.0
	support.call("deactivate")
	support.call("_physics_process", 30.0)
	_require(is_equal_approx(player.health, 50.0), "coworkers have no effect before alignment")
	support.call("set_run_level", 1)
	var base_scale := float(support.call("_power_scale"))
	support.call("set_run_level", 80)
	var grown_scale := float(support.call("_power_scale"))
	_require(grown_scale > base_scale, "coworker power grows with the run without entering the card pool")
	support.call("activate", "qa")
	var snapshot: Dictionary = support.call("get_support_snapshot")
	_require(bool(snapshot.get("active", false)) and String(snapshot.get("ability", "")).contains("回归"), "alignment activates the selected coworker kit")
	_require(float(snapshot.get("cooldown", 0.0)) > 0.0 and float(snapshot.get("remaining", -1.0)) >= 0.0, "support snapshot exposes real cooldown state")


func _test_all_nine_personas() -> void:
	for persona_id in CoworkerCatalog.ids():
		_prepare_cast(persona_id)
		var health_before: float = _enemy_health_total()
		var player_health_before: float = float(player.health)
		var loot_before: int = loot.positions.size()
		var skill_before := float(actions.skill_cooldown_left)
		var ultimate_before := float(actions.ultimate_cooldown_left)
		var trace: Dictionary = support.call("debug_trigger", persona_id)
		_require(String(trace.get("persona_id", "")) == persona_id, "%s produces a concrete runtime trace" % persona_id)
		match persona_id:
			"qa":
				_require(player.health > player_health_before and player.health <= player.max_health, "QA slowly heals without overhealing")
				_require(float(trace.get("heal", 0.0)) <= 1.90, "QA late-run healing multiplier is capped")
			"hr":
				_require(player.health > player_health_before and player.invulnerability_left >= 1.19, "HR performs a low-health rescue with protection")
			"finance":
				_require(loot.positions.size() > loot_before and int(trace.get("xp", 0)) > 0, "finance recovers a visible telemetry crystal")
			"product":
				_require(int(trace.get("hits", 0)) > 0 and _has_slowed_enemy(), "product applies a real area control effect")
			"frontend":
				_require(int(trace.get("hits", 0)) >= 3 and _enemy_health_total() < health_before, "frontend chains ranged damage through multiple targets")
			"backend":
				_require(int(trace.get("hits", 0)) > 0 and _enemy_health_total() < health_before, "backend resolves a queued area burst")
			"leader":
				_require(int(trace.get("hits", 0)) > 0 and _enemy_health_total() < health_before, "leader performs a high-impact clearing pulse")
			"customer":
				_require(float(trace.get("damage", 0.0)) > 0.0 and _enemy_health_total() < health_before, "customer reproduces and damages a single target")
			"supervisor":
				_require(actions.skill_cooldown_left < skill_before and actions.ultimate_cooldown_left < ultimate_before, "supervisor advances both action cooldowns")
		_require(support.trigger_count == 1, "%s records one successful proc for HUD and settlement" % persona_id)

	# HR holds its rescue while the player is healthy instead of wasting a proc.
	_prepare_cast("hr")
	player.health = 90.0
	var held_trace: Dictionary = support.call("debug_trigger", "hr")
	_require(held_trace.is_empty() and support.trigger_count == 0, "HR rescue waits for the low-health threshold")


func _prepare_cast(persona_id: String) -> void:
	swarm.call("clear_all")
	loot.positions.clear()
	loot.values.clear()
	loot.qualities.clear()
	loot.scales.clear()
	player.max_health = 100.0
	player.health = 40.0 if persona_id == "hr" else (55.0 if persona_id == "qa" else 100.0)
	player.invulnerability_left = 0.0
	actions.skill_cooldown_left = 10.0
	actions.ultimate_cooldown_left = 10.0
	support.call("set_run_level", 80 if persona_id == "qa" else 10)
	support.call("activate", persona_id)
	for index in range(8):
		var position := player.global_position + Vector2.from_angle(TAU * float(index) / 8.0) * (105.0 + float(index % 2) * 35.0)
		swarm.call("spawn_enemy", SwarmWorldScript.EnemyKind.ENOSPC, position)
		swarm.health[index] = 10_000.0
		swarm.maximum_health[index] = 10_000.0


func _enemy_health_total() -> float:
	var total := 0.0
	for index in range(swarm.count):
		total += float(swarm.health[index])
	return total


func _has_slowed_enemy() -> bool:
	for index in range(swarm.count):
		if float(swarm.slow_timers[index]) > 0.0:
			return true
	return false


func _test_hud_contract() -> void:
	var run: Node = load("res://scenes/run.tscn").instantiate()
	run.process_mode = Node.PROCESS_MODE_DISABLED
	get_root().add_child(run)
	var hud: Node = run.get_node("HUD")
	hud.call("show_pressure_persona", "qa", "测试工程师", false)
	var before: Dictionary = hud.call("get_ally_ui_snapshot")
	_require(bool(before.get("visible", false)) and String(before.get("badge", "")) == "QA", "HUD identifies the QA pressure projection")
	_require(String(before.get("ability", "")).contains("回归绿灯"), "HUD previews the ally ability before alignment")
	hud.call("set_pressure_persona_allied", true)
	var snapshot: Dictionary = support.call("get_support_snapshot")
	snapshot["active"] = true
	snapshot["persona_id"] = "qa"
	snapshot["ability"] = "回归绿灯"
	snapshot["role"] = "持续治疗"
	snapshot["remaining"] = 2.4
	snapshot["cooldown"] = 3.8
	snapshot["trigger_count"] = 3
	hud.call("update_ally_support", snapshot)
	var after: Dictionary = hud.call("get_ally_ui_snapshot")
	_require(String(after.get("cooldown", "")).contains("2.4") and String(after.get("status", "")).contains("×3"), "HUD displays ally cooldown and proc count")
	_require(String(after.get("tooltip", "")).contains("最近"), "HUD tooltip explains the current support state")
	get_root().remove_child(run)
	run.free()


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("ALLY_SUPPORT_SYSTEM_TEST_FAIL: " + message)
