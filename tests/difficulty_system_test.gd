extends SceneTree

const DifficultyCatalog := preload("res://scripts/difficulty_catalog.gd")
const SwarmWorldScript := preload("res://scripts/swarm_world.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var profile := get_root().get_node("ProfileStore")
	profile.reset_for_tests()
	_require(DifficultyCatalog.ids() == ["normal", "advanced", "abyss", "impossible"], "difficulty order is stable")
	var expected_elites := {"normal": 2, "advanced": 8, "abyss": 23, "impossible": 84}
	var previous_spawn_rate := 0.0
	var previous_enemy_cap := 0
	var previous_normal_health := 0.0
	var previous_elite_health := 0.0
	var previous_boss_health := 0.0
	var previous_normal_damage := 0.0
	var previous_spawn_interval := INF

	for difficulty_config in DifficultyCatalog.all():
		var difficulty_id := String(difficulty_config["id"])
		if not profile.is_difficulty_unlocked(difficulty_id):
			profile.unlock_difficulty(difficulty_id)
		_require(profile.select_difficulty(difficulty_id), "%s can be selected after unlock" % difficulty_id)
		var run: Node = load("res://scenes/run.tscn").instantiate()
		get_root().add_child(run)
		var snapshot: Dictionary = run.call("get_difficulty_runtime_snapshot")
		var swarm: Node = run.get_node("SwarmWorld")
		var swarm_snapshot: Dictionary = swarm.call("get_difficulty_snapshot")
		_require(String(run.difficulty_id) == difficulty_id and String(snapshot["id"]) == difficulty_id, "%s reaches RunController" % difficulty_id)
		_require(String(swarm_snapshot["id"]) == difficulty_id, "%s reaches SwarmWorld" % difficulty_id)
		_require(int(swarm.count) == int(difficulty_config["opening_wave"]), "%s uses its opening-wave count" % difficulty_id)
		_require(_elite_total(difficulty_config) == int(expected_elites[difficulty_id]), "%s has the designed elite total" % difficulty_id)
		_require(float(snapshot["spawn_rate"]) > previous_spawn_rate, "%s spawn pressure is strictly higher" % difficulty_id)
		_require(int(snapshot["enemy_cap"]) > previous_enemy_cap, "%s concurrent-enemy cap is strictly higher" % difficulty_id)
		_require(float(swarm_snapshot["normal_health"]) > previous_normal_health, "%s normal health is strictly higher" % difficulty_id)
		_require(float(swarm_snapshot["elite_health"]) > previous_elite_health, "%s elite health is strictly higher" % difficulty_id)
		_require(float(swarm_snapshot["boss_health"]) > previous_boss_health, "%s boss health is strictly higher" % difficulty_id)
		_require(float(swarm_snapshot["normal_damage"]) > previous_normal_damage, "%s normal damage is strictly higher" % difficulty_id)
		_require(float(snapshot["spawn_interval_start"]) < previous_spawn_interval, "%s starts spawning faster than the previous tier" % difficulty_id)

		swarm.call("clear_all")
		swarm.call("spawn_enemy", SwarmWorldScript.EnemyKind.HTTP_404, run.player.global_position + Vector2(100, 0))
		_require(is_equal_approx(float(swarm.maximum_health[0]), 18.0 * float(difficulty_config["normal_health"])), "%s scales normal health at spawn" % difficulty_id)
		_require(is_equal_approx(float(swarm.speeds[0]), 74.0 * float(difficulty_config["normal_speed"])), "%s scales normal speed at spawn" % difficulty_id)
		_require(is_equal_approx(float(swarm.call("_contact_damage", SwarmWorldScript.EnemyKind.HTTP_404)), 5.0 * float(difficulty_config["normal_damage"])), "%s scales normal contact damage" % difficulty_id)

		swarm.call("clear_all")
		swarm.call("spawn_enemy", SwarmWorldScript.EnemyKind.ELITE_502, run.player.global_position + Vector2(100, 0))
		_require(is_equal_approx(float(swarm.maximum_health[0]), 420.0 * float(difficulty_config["elite_health"])), "%s scales elite health at spawn" % difficulty_id)
		_require(is_equal_approx(float(swarm.call("_contact_damage", SwarmWorldScript.EnemyKind.ELITE_502)), 12.0 * float(difficulty_config["elite_damage"])), "%s scales elite contact damage" % difficulty_id)
		var loot: Node = run.get_node("LootWorld")
		var loot_before: Dictionary = loot.call("get_loot_snapshot")
		swarm.call("damage_index", 0, 1_000_000_000.0)
		var loot_after: Dictionary = loot.call("get_loot_snapshot")
		_require(int(loot_after["count"]) - int(loot_before["count"]) == int(difficulty_config["elite_crystal_count"]), "%s real elite close emits the configured crystal burst" % difficulty_id)
		_require(int(loot_after["stored_value"]) - int(loot_before["stored_value"]) == int(difficulty_config["elite_crystal_total"]), "%s real elite close grants the configured crystal XP" % difficulty_id)
		_require(int(loot_after["elite_count"]) - int(loot_before["elite_count"]) == int(difficulty_config["elite_crystal_count"]), "%s real elite close marks every large crystal" % difficulty_id)

		swarm.call("clear_all")
		run.call("_spawn_boss")
		var boss_index := int(swarm.call("_find_kind", SwarmWorldScript.EnemyKind.INCIDENT_CORE))
		_require(boss_index >= 0, "%s spawns the incident core" % difficulty_id)
		_require(is_equal_approx(float(swarm.maximum_health[boss_index]), 1600.0 * float(difficulty_config["boss_health"])), "%s scales boss health at spawn" % difficulty_id)
		_require(int(run.boss_clues_required) == maxi(3, ceili(8.0 * float(difficulty_config["boss_clue_multiplier"]))), "%s scales boss diagnosis clues" % difficulty_id)

		swarm.call("clear_all")
		run.event_strategy = {"wave": ["HTTP_404"], "wave_count": 10}
		run.call("_spawn_event_wave")
		_require(int(swarm.count) == ceili(10.0 * float(difficulty_config["event_wave_multiplier"])), "%s scales special-event waves" % difficulty_id)
		_require(String(run.call("_build_run_result", false)["difficulty_id"]) == difficulty_id, "%s is recorded in run settlement" % difficulty_id)

		if difficulty_id == "impossible":
			swarm.call("clear_all")
			run.boss_spawned = false
			run.spawning_enabled = true
			run.spawn_accumulator = 0.0
			run.call("_update_spawning", 1000.0)
			_require(int(swarm.count) == 2000, "impossible can saturate its 2000-enemy gameplay cap")
			_require(is_equal_approx(1600.0 * float(difficulty_config["boss_health"]), 25600.0), "impossible incident core has 25,600 HP")
			run.call("_on_boss_defeated")
			run.call("_update_validation", float(difficulty_config["validation_cleanup_time"]) + 0.1)
			_require(bool(run.ended), "an uncleared impossible recovery window fails instead of hanging forever")
			paused = false

		previous_spawn_rate = float(snapshot["spawn_rate"])
		previous_enemy_cap = int(snapshot["enemy_cap"])
		previous_normal_health = float(swarm_snapshot["normal_health"])
		previous_elite_health = float(swarm_snapshot["elite_health"])
		previous_boss_health = float(swarm_snapshot["boss_health"])
		previous_normal_damage = float(swarm_snapshot["normal_damage"])
		previous_spawn_interval = float(snapshot["spawn_interval_start"])
		get_root().remove_child(run)
		run.free()

	print("DIFFICULTY_SYSTEM_TEST_PASS tiers=4 elites=2/8/23/84 impossible_cap=2000 boss_hp=25600")
	quit(0)


func _elite_total(config: Dictionary) -> int:
	var total := 0
	var wave_time := float(config["elite_wave_start"])
	var wave_end := float(config["elite_wave_end"])
	while wave_time < wave_end:
		var wave_size := int(config["elite_wave_size"])
		if wave_time >= float(config["elite_wave_late_time"]):
			wave_size = int(config["elite_wave_late_size"])
		if wave_time >= float(config["elite_wave_final_time"]):
			wave_size = int(config["elite_wave_final_size"])
		total += wave_size
		wave_time += float(config["elite_wave_interval"])
	return total


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("DIFFICULTY_SYSTEM_TEST_FAIL: " + message)
	paused = false
	quit(1)
