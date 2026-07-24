extends SceneTree

const CareerCatalog := preload("res://scripts/career_catalog.gd")
const CombatSystemScript := preload("res://scripts/combat_system.gd")
const CareerActionSystemScript := preload("res://scripts/career_action_system.gd")
const SwarmWorldScript := preload("res://scripts/swarm_world.gd")
const PlayerScript := preload("res://scripts/player.gd")
const LootWorldScript := preload("res://scripts/loot_world.gd")
const DifficultyCatalog := preload("res://scripts/difficulty_catalog.gd")

const LONG_RUN_LEVEL := 256
const WEAPON_IDS: Array[String] = ["bash", "ping", "firewall", "log", "wrench", "rule_chain", "lock_zone", "worker"]
const SIGNATURE_IDS: Array[String] = ["signature_rate", "signature_quantity", "signature_damage", "signature_area"]

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var player := PlayerScript.new()
	var swarm := SwarmWorldScript.new()
	var combat := CombatSystemScript.new()
	var actions := CareerActionSystemScript.new()
	get_root().add_child(player)
	get_root().add_child(swarm)
	get_root().add_child(combat)
	get_root().add_child(actions)
	player.global_position = Vector2(1200.0, 750.0)
	player.set_physics_process(false)
	swarm.set_physics_process(false)
	combat.set_physics_process(false)
	actions.set_physics_process(false)
	swarm.call("configure", player, 20260720)
	combat.call("configure", player, swarm, null)
	actions.call("configure", player, swarm, null, combat)

	_test_authored_upgrade_impact(combat, actions, swarm, player)
	_test_unlimited_weapon_growth(combat, swarm)
	_test_signature_growth_for_all_careers(actions, combat, swarm, player)
	_test_elite_crystal_bursts()
	_test_loot_capacity_and_swap_pop()

	get_root().remove_child(actions)
	get_root().remove_child(combat)
	get_root().remove_child(swarm)
	get_root().remove_child(player)
	actions.free()
	combat.free()
	swarm.free()
	player.free()

	if failed:
		quit(1)
		return
	print("GROWTH_AND_ELITE_LOOT_TEST_PASS weapons=8 level=256 careers=10 signature_axes=4 crystal_tiers=4 cap=900")
	quit(0)


func _test_unlimited_weapon_growth(combat: Node, swarm: Node) -> void:
	var ops := CareerCatalog.get_by_id("ops")
	for weapon_id in WEAPON_IDS:
		combat.call("configure_career", ops)
		for ignored in range(5):
			combat.call("apply_upgrade", weapon_id)
		var authored_metrics := _weapon_metrics(combat, weapon_id, 5)
		for ignored in range(LONG_RUN_LEVEL - 5):
			combat.call("apply_upgrade", weapon_id)
		var grown_metrics := _weapon_metrics(combat, weapon_id, LONG_RUN_LEVEL)
		_require(int(combat.call("get_upgrade_level", weapon_id)) == LONG_RUN_LEVEL, "%s can grow beyond the former level-five cap" % weapon_id)
		_require(float(grown_metrics["damage"]) > float(authored_metrics["damage"]), "%s overclock continues increasing damage" % weapon_id)
		_require(float(grown_metrics["range"]) > float(authored_metrics["range"]), "%s overclock continues increasing coverage" % weapon_id)
		_require(float(grown_metrics["cooldown"]) <= float(authored_metrics["cooldown"]), "%s overclock never makes execution slower" % weapon_id)
		_require(float(grown_metrics["cooldown"]) >= float(grown_metrics["cooldown_floor"]), "%s respects its safe scheduling floor" % weapon_id)
		if weapon_id == "rule_chain":
			_require(int(grown_metrics["quantity"]) > int(authored_metrics["quantity"]), "iptables keeps adding one ACL node on every overclock stack")
		else:
			_require(int(grown_metrics["quantity"]) == int(authored_metrics["quantity"]), "%s keeps runtime entity count at its authored shape budget" % weapon_id)
		_require(_reasonable_float(float(grown_metrics["damage"]), 1.0e9), "%s long-run damage remains finite" % weapon_id)
		_require(_reasonable_float(float(grown_metrics["range"]), 20_000.0), "%s long-run range remains finite" % weapon_id)
		var card: Dictionary = combat.call("get_upgrade_card", weapon_id)
		var card_text := "%s %s %s" % [String(card.get("name", "")), String(card.get("title", "")), String(card.get("description", ""))]
		_require(card_text.contains(str(LONG_RUN_LEVEL)) and card_text.contains(str(LONG_RUN_LEVEL + 1)), "%s card reports the real post-five stack transition" % weapon_id)
		_require(card_text.contains("超频") or card_text.contains("无限"), "%s card explains its unbounded continuation" % weapon_id)

	# A fully overclocked loadout must still execute one frame with bounded visual
	# and persistent-object counts. This catches accidental range(level) loops.
	combat.call("configure_career", ops)
	for weapon_id in WEAPON_IDS:
		for ignored in range(LONG_RUN_LEVEL):
			combat.call("apply_upgrade", weapon_id)
	combat.effects.clear()
	combat.lock_zones.clear()
	combat.bash_timer = 0.0
	combat.ping_timer = 0.0
	combat.firewall_timer = 0.0
	combat.log_timer = 0.0
	combat.wrench_timer = 0.0
	combat.rule_chain_timer = 0.0
	combat.lock_place_timer = 0.0
	combat.worker_timer = 0.0
	swarm.call("clear_all")
	combat.call("_physics_process", 0.016)
	_require(combat.effects.size() <= 180, "overclocked loadout respects CombatSystem.MAX_EFFECTS")
	_require(combat.lock_zones.size() <= 3, "overclocked lock zones retain the authored object budget")
	_require(int(combat.call("_ping_pulses", LONG_RUN_LEVEL)) <= 5, "Ping never creates unbounded pulses")
	_require(int(combat.call("_firewall_layers", LONG_RUN_LEVEL)) <= 5, "firewall never creates unbounded layers")
	_require(int(combat.call("_rule_chain_nodes", LONG_RUN_LEVEL)) == LONG_RUN_LEVEL + 2, "iptables adds one real ACL node on every stack through long-run overclock")
	_require(int(combat.call("_worker_count", LONG_RUN_LEVEL)) <= 8, "Worker Pod never creates unbounded workers")


func _test_authored_upgrade_impact(combat: Node, actions: Node, swarm: Node, player: CharacterBody2D) -> void:
	var ops := CareerCatalog.get_by_id("ops")
	for weapon_id in WEAPON_IDS:
		combat.call("configure_career", ops)
		var previous: Dictionary = {}
		var previous_rule_hit_radius := 0.0
		for level_value in range(1, 6):
			combat.call("apply_upgrade", weapon_id)
			var current := _weapon_metrics(combat, weapon_id, level_value)
			if not previous.is_empty():
				_require(float(current["damage"]) >= float(previous["damage"]) * 1.18, "%s authored stack %d adds at least 18%% real payload" % [weapon_id, level_value])
				_require(float(current["range"]) >= float(previous["range"]) * 1.075, "%s authored stack %d visibly expands real geometry" % [weapon_id, level_value])
				_require(float(current["cooldown"]) <= float(previous["cooldown"]) * 0.90, "%s authored stack %d improves real frequency by at least 10%%" % [weapon_id, level_value])
				_require(int(current["quantity"]) >= int(previous["quantity"]), "%s authored stacks never lose physical emissions" % weapon_id)
				if weapon_id == "rule_chain":
					_require(int(current["quantity"]) == int(previous["quantity"]) + 1, "iptables stack %d adds exactly one visible ACL node" % level_value)
					_require(float(combat.call("_rule_chain_hit_radius", level_value)) > previous_rule_hit_radius, "iptables stack %d expands each node's collision range" % level_value)
			if weapon_id == "rule_chain":
				_require(int(current["quantity"]) == level_value + 2, "iptables level %d exposes its enlarged node count" % level_value)
				previous_rule_hit_radius = float(combat.call("_rule_chain_hit_radius", level_value))
			previous = current

	combat.call("configure_career", ops)
	var previous_nodes := 0
	var previous_orbit := 0.0
	var previous_hit_radius := 0.0
	for level_value in range(1, 33):
		var current_nodes := int(combat.call("_rule_chain_nodes", level_value))
		var current_orbit := float(combat.call("_rule_chain_radius", level_value))
		var current_hit_radius := float(combat.call("_rule_chain_hit_radius", level_value))
		_require(current_nodes == level_value + 2, "iptables stack %d keeps adding one visible ACL node" % level_value)
		if level_value > 1:
			_require(current_nodes > previous_nodes and current_orbit > previous_orbit and current_hit_radius > previous_hit_radius, "iptables stack %d expands node count, orbit, and collision range together" % level_value)
		previous_nodes = current_nodes
		previous_orbit = current_orbit
		previous_hit_radius = current_hit_radius

	for _rule_level in range(13):
		combat.call("apply_upgrade", "rule_chain")
	swarm.call("clear_all")
	player.global_position = Vector2(1200.0, 750.0)
	var dense_orbit := float(combat.call("_rule_chain_radius", 13))
	for enemy_index in range(4):
		swarm.call("spawn_enemy", SwarmWorldScript.EnemyKind.ENOSPC, player.global_position + Vector2.from_angle(TAU * float(enemy_index) / 4.0) * dense_orbit)
		swarm.health[enemy_index] = 1000.0
		swarm.maximum_health[enemy_index] = 1000.0
	var dense_health_before := 0.0
	for enemy_index in range(int(swarm.count)):
		dense_health_before += float(swarm.health[enemy_index])
	combat.call("_tick_rule_chain")
	var dense_health_after := 0.0
	for enemy_index in range(int(swarm.count)):
		dense_health_after += float(swarm.health[enemy_index])
	_require(dense_health_after < dense_health_before, "high-stack iptables merges dense nodes into one bounded ring collision pass")

	# Upgrade feedback includes the real post-selection coverage rather than a
	# fixed decorative ring that would look identical at every level.
	combat.call("configure_career", ops)
	for ignored in range(3):
		combat.call("apply_upgrade", "ping")
	combat.effects.clear()
	combat.call("play_upgrade_burst", "ping")
	var largest_feedback_radius := 0.0
	for effect in combat.effects:
		largest_feedback_radius = maxf(largest_feedback_radius, float(effect.get("radius", 0.0)))
	_require(largest_feedback_radius >= float(combat.call("_ping_radius", 3)), "weapon upgrade burst visualizes its real grown range")

	for career in CareerCatalog.all():
		actions.call("configure_career", career)
		var base_cooldown := float(actions.call("_signature_cooldown_for_level", 0))
		_require(float(actions.call("_signature_cooldown_for_level", 1)) <= base_cooldown * 0.89, "%s first signature-rate card is an obvious frequency spike" % String(career["id"]))
		_require(float(actions.call("_signature_damage_multiplier_for_level", 1)) >= 1.25, "%s first signature-damage card adds at least 25%%" % String(career["id"]))
		_require(float(actions.call("_signature_area_multiplier_for_level", 1)) >= 1.20, "%s first signature-area card is visibly larger" % String(career["id"]))
		actions.visuals.clear()
		actions.call("apply_signature_upgrade", "signature_area")
		_require(not actions.visuals.is_empty(), "%s signature selection emits immediate battlefield feedback" % String(career["id"]))
		swarm.call("clear_all")
		player.global_position = Vector2(1200.0, 750.0)


func _weapon_metrics(combat: Node, weapon_id: String, level_value: int) -> Dictionary:
	match weapon_id:
		"bash":
			return {"damage": combat.call("_effective_bash_damage", level_value), "range": combat.call("_bash_range", level_value), "cooldown": combat.call("_bash_cooldown", level_value), "cooldown_floor": 0.16, "quantity": combat.call("_effective_bash_targets", level_value)}
		"ping":
			return {"damage": combat.call("_ping_damage", level_value), "range": combat.call("_ping_radius", level_value), "cooldown": combat.call("_ping_cooldown", level_value), "cooldown_floor": 1.80, "quantity": combat.call("_ping_pulses", level_value)}
		"firewall":
			return {"damage": combat.call("_firewall_damage", level_value), "range": combat.call("_firewall_radius", level_value), "cooldown": combat.call("_firewall_cooldown", level_value), "cooldown_floor": 0.38, "quantity": combat.call("_firewall_layers", level_value)}
		"log":
			return {"damage": combat.call("_log_damage", level_value), "range": combat.call("_log_radius", level_value), "cooldown": combat.call("_log_cooldown", level_value), "cooldown_floor": 1.80, "quantity": combat.call("_log_targets", level_value)}
		"wrench":
			return {"damage": combat.call("_wrench_damage", level_value), "range": combat.call("_wrench_reach", level_value), "cooldown": combat.call("_wrench_cooldown", level_value), "cooldown_floor": 0.36, "quantity": combat.call("_wrench_sweeps", level_value)}
		"rule_chain":
			return {"damage": combat.call("_rule_chain_damage", level_value), "range": combat.call("_rule_chain_radius", level_value), "cooldown": combat.call("_rule_chain_tick", level_value), "cooldown_floor": 0.16, "quantity": combat.call("_rule_chain_nodes", level_value)}
		"lock_zone":
			return {"damage": combat.call("_lock_zone_damage", level_value), "range": combat.call("_lock_zone_radius", level_value), "cooldown": combat.call("_lock_zone_cooldown", level_value), "cooldown_floor": 2.15, "quantity": combat.call("_lock_zone_limit", level_value)}
		"worker":
			return {"damage": combat.call("_worker_damage", level_value), "range": combat.call("_worker_range", level_value), "cooldown": combat.call("_worker_cooldown", level_value), "cooldown_floor": 0.50, "quantity": combat.call("_worker_count", level_value)}
	return {"damage": 0.0, "range": 0.0, "cooldown": 0.0, "cooldown_floor": 0.0, "quantity": 0}


func _test_signature_growth_for_all_careers(actions: Node, combat: Node, swarm: Node, player: CharacterBody2D) -> void:
	for career in CareerCatalog.all():
		var career_id := String(career["id"])
		combat.call("configure_career", career)
		actions.call("configure_career", career)
		var base: Dictionary = actions.call("get_signature_growth_snapshot")
		var base_actual_damage := float(actions.call("_signature_damage", 10.0))
		_require(actions.call("get_signature_upgrade_ids") == SIGNATURE_IDS, "%s exposes all four stable signature-growth ids" % career_id)
		for upgrade_id in SIGNATURE_IDS:
			var card: Dictionary = actions.call("get_signature_upgrade_card", upgrade_id)
			_require(String(card.get("description", "")).contains("无限叠加"), "%s %s card promises unbounded growth" % [career_id, upgrade_id])
			actions.call("apply_signature_upgrade", upgrade_id)
		var grown: Dictionary = actions.call("get_signature_growth_snapshot")
		var levels: Dictionary = grown["levels"]
		_require(int(grown["total_level"]) == 4, "%s records all four signature-growth selections independently" % career_id)
		_require(int(levels["rate"]) == 1 and int(levels["quantity"]) == 1 and int(levels["damage"]) == 1 and int(levels["area"]) == 1, "%s keeps four independent signature levels" % career_id)
		_require(float(grown["cooldown"]) < float(base["cooldown"]), "%s frequency growth changes the real signature cooldown" % career_id)
		_require(float(actions.call("_signature_damage", 10.0)) > base_actual_damage, "%s damage growth changes the real signature payload" % career_id)
		_require(float(grown["area_multiplier"]) > float(base["area_multiplier"]), "%s area growth changes the real geometry multiplier" % career_id)
		_require(int(grown["quantity"]) > int(base["quantity"]), "%s quantity growth changes its profession-specific emission count" % career_id)
		_require(is_equal_approx(float(actions.call("_signature_cooldown")), float(grown["cooldown"])), "%s snapshot reports the scheduler's actual cooldown" % career_id)
		_require(is_equal_approx(float(actions.call("_signature_area_multiplier")), float(grown["area_multiplier"])), "%s snapshot reports the geometry's actual area multiplier" % career_id)
		_require(int(actions.call("_signature_quantity_value")) == int(grown["quantity"]), "%s snapshot reports the cast's actual quantity" % career_id)
		var signature_snapshot: Dictionary = actions.call("get_action_snapshot")["signature"]
		_require(int(signature_snapshot["level"]) == 5, "%s HUD snapshot raises the intrinsic attack above level one" % career_id)

		# Quantity is not cosmetic: every profession must produce more of its own
		# native attack shape after one quantity selection.
		var base_observable := _signature_quantity_observable(actions, swarm, player, career, false)
		var grown_observable := _signature_quantity_observable(actions, swarm, player, career, true)
		_require(grown_observable > base_observable, "%s quantity growth changes its actual %s runtime" % [career_id, String(actions.call("_signature_quantity_label"))])

		# Long-run signature levels remain numerically useful while concrete walls,
		# zones, pods, delayed actions, and visuals stay bounded.
		actions.call("configure_career", career)
		for upgrade_id in SIGNATURE_IDS:
			for ignored in range(LONG_RUN_LEVEL):
				actions.call("apply_signature_upgrade", upgrade_id)
		var long_run: Dictionary = actions.call("get_signature_growth_snapshot")
		_require(int(long_run["total_level"]) == LONG_RUN_LEVEL * 4, "%s signature growth has no former five-stack ceiling" % career_id)
		_require(float(long_run["cooldown"]) >= 0.18, "%s signature scheduler retains the global audio/CPU floor" % career_id)
		_require(int(long_run["quantity"]) <= 19, "%s physical emissions remain within the shared survivor budget" % career_id)
		_require(float(long_run["quantity_overflow_multiplier"]) > 1.0, "%s excess quantity stacks convert into constant-cost damage" % career_id)
		_require(_reasonable_float(float(long_run["damage_multiplier"]), 1.0e9), "%s long-run signature damage remains finite" % career_id)
		_require(_reasonable_float(float(long_run["area_multiplier"]), 20_000.0), "%s long-run signature area remains finite" % career_id)
		swarm.call("clear_all")
		for cast_index in range(100):
			actions.call("debug_cast_signature")
		_require(actions.walls.size() <= 16, "%s repeated casts respect MAX_WALLS" % career_id)
		_require(actions.zones.size() <= 18, "%s repeated casts respect MAX_ZONES" % career_id)
		_require(actions.nodes.size() <= 16, "%s repeated casts respect MAX_NODES" % career_id)
		_require(actions.pending_actions.size() <= 72, "%s repeated casts respect MAX_PENDING_ACTIONS" % career_id)
		_require(actions.visuals.size() <= 140, "%s repeated casts respect MAX_VISUALS" % career_id)


func _signature_quantity_observable(actions: Node, swarm: Node, player: CharacterBody2D, career: Dictionary, upgraded: bool) -> float:
	actions.call("configure_career", career)
	if upgraded:
		actions.call("apply_signature_upgrade", "signature_quantity")
	swarm.call("clear_all")
	player.global_position = Vector2(1200.0, 750.0)
	player.max_health = 100.0
	player.health = 100.0
	var career_id := String(career["id"])
	match career_id:
		"ops", "network":
			swarm.call("spawn_enemy", SwarmWorldScript.EnemyKind.ENOSPC, player.global_position + Vector2(90.0 if career_id != "network" else 300.0, 0.0))
			swarm.health[0] = 10_000.0
			swarm.maximum_health[0] = 10_000.0
			var before := float(swarm.health[0])
			actions.call("debug_cast_signature")
			return before - float(swarm.health[0])
		"sre":
			for index in range(7):
				swarm.call("spawn_enemy", SwarmWorldScript.EnemyKind.ENOSPC, player.global_position + Vector2(90.0 + float(index) * 54.0, float(index % 2) * 42.0))
				swarm.health[index] = 10_000.0
				swarm.maximum_health[index] = 10_000.0
			var trace: Dictionary = actions.call("debug_cast_signature")
			return float(trace.get("hits", 0))
		"dba":
			actions.call("debug_cast_signature")
			return float(actions.zones.size())
		"security":
			actions.call("debug_cast_signature")
			return float(actions.walls.size())
		"it_ops":
			actions.call("debug_cast_signature")
			return float(actions.nodes.size())
		"helpdesk":
			for index in range(24):
				var angle := TAU * float(index) / 24.0
				swarm.call("spawn_enemy", SwarmWorldScript.EnemyKind.ENOSPC, player.global_position + Vector2.from_angle(angle) * (110.0 + float(index % 3) * 28.0))
			var trace: Dictionary = actions.call("debug_cast_signature")
			return float(trace.get("hits", 0))
		"opsdev":
			swarm.call("spawn_enemy", SwarmWorldScript.EnemyKind.ENOSPC, player.global_position + Vector2(120.0, 0.0))
			actions.call("debug_cast_signature")
			return float(actions.pending_actions[0].get("repeat", 0))
		"delivery":
			actions.call("debug_cast_signature")
			return float(actions.pending_actions.size())
		"ai_infra":
			return float(actions.call("get_worker_count"))
	return 0.0


func _test_elite_crystal_bursts() -> void:
	var previous_count := 0
	var previous_total := 0
	var previous_scale := 0.0
	for config in DifficultyCatalog.all():
		var player := Node2D.new()
		var loot := LootWorldScript.new()
		get_root().add_child(player)
		get_root().add_child(loot)
		player.global_position = Vector2(-5000.0, -5000.0)
		loot.set_physics_process(false)
		loot.call("configure", player)
		loot.call("spawn_xp", Vector2(1000.0, 1000.0), 2)
		var normal_size := float(loot.call("_crystal_size", 0))
		var crystal_count := int(config["elite_crystal_count"])
		var crystal_total := int(config["elite_crystal_total"])
		var crystal_scale := float(config["elite_crystal_scale"])
		var created := int(loot.call("spawn_xp_burst", Vector2(1400.0, 900.0), crystal_total, crystal_count, 1, crystal_scale))
		var snapshot: Dictionary = loot.call("get_loot_snapshot")
		_require(created == crystal_count and crystal_count >= 4, "%s elite drops a visible multi-crystal burst" % String(config["id"]))
		_require(int(snapshot["count"]) == crystal_count + 1, "%s burst adds every configured crystal" % String(config["id"]))
		_require(int(snapshot["stored_value"]) == crystal_total + 2, "%s crystal burst conserves its configured XP" % String(config["id"]))
		_require(int(snapshot["elite_count"]) == crystal_count, "%s marks every elite crystal with elite quality" % String(config["id"]))
		var burst_positions: Array = snapshot["positions"].slice(1)
		var has_spread := false
		for index in range(1, burst_positions.size()):
			if Vector2(burst_positions[index]).distance_to(Vector2(burst_positions[0])) >= 10.0:
				has_spread = true
				break
		_require(has_spread, "%s elite crystals visibly fan out instead of overlapping" % String(config["id"]))
		for index in range(1, int(snapshot["count"])):
			_require(int(snapshot["qualities"][index]) == 1, "%s elite crystal quality metadata stays aligned" % String(config["id"]))
			_require(is_equal_approx(float(snapshot["scales"][index]), crystal_scale), "%s elite crystal scale metadata stays aligned" % String(config["id"]))
			_require(float(loot.call("_crystal_size", index)) > normal_size * 1.5, "%s elite crystals are materially larger than normal telemetry" % String(config["id"]))
		_require(crystal_count > previous_count and crystal_total > previous_total and crystal_scale > previous_scale, "%s increases elite-crystal count, reward, and size over the previous difficulty" % String(config["id"]))
		previous_count = crystal_count
		previous_total = crystal_total
		previous_scale = crystal_scale
		get_root().remove_child(loot)
		get_root().remove_child(player)
		loot.free()
		player.free()


func _test_loot_capacity_and_swap_pop() -> void:
	var player := Node2D.new()
	var loot := LootWorldScript.new()
	get_root().add_child(player)
	get_root().add_child(loot)
	player.global_position = Vector2(-5000.0, -5000.0)
	loot.set_physics_process(false)
	loot.call("configure", player)
	var collected := {"value": 0}
	loot.xp_collected.connect(func(value: int) -> void: collected["value"] = int(collected["value"]) + value)
	for index in range(899):
		loot.call("_append_xp", Vector2(10_000.0 + float(index), 10_000.0), 1, 0, 1.0)
	var before: Dictionary = loot.call("get_loot_snapshot")
	var created := int(loot.call("spawn_xp_burst", Vector2.ZERO, 42, 7, 1, 1.75))
	var almost_full: Dictionary = loot.call("get_loot_snapshot")
	_require(created == 1 and int(almost_full["count"]) == 900, "899/900 boundary concentrates an elite burst into the last slot")
	_require(int(almost_full["stored_value"]) - int(before["stored_value"]) + int(collected["value"]) == 42, "899/900 boundary preserves the complete elite reward")
	_require(_metadata_is_aligned(almost_full), "parallel loot metadata stays aligned at capacity")

	var stored_at_capacity := int(almost_full["stored_value"])
	var collected_before_full_burst := int(collected["value"])
	created = int(loot.call("spawn_xp_burst", Vector2.ZERO, 42, 7, 1, 1.75))
	var full: Dictionary = loot.call("get_loot_snapshot")
	_require(created == 0 and int(full["count"]) == 900 and int(full["stored_value"]) == stored_at_capacity, "900/900 boundary never exceeds LootWorld.MAX_ORBS")
	_require(int(collected["value"]) - collected_before_full_burst == 42, "a full loot pool immediately credits rather than loses elite XP")
	_require(_metadata_is_aligned(full), "full-pool metadata arrays remain aligned")
	get_root().remove_child(loot)
	get_root().remove_child(player)
	loot.free()
	player.free()

	# Remove index zero while another orb remains so swap-pop must copy value,
	# quality, and scale together.
	player = Node2D.new()
	loot = LootWorldScript.new()
	get_root().add_child(player)
	get_root().add_child(loot)
	player.global_position = Vector2.ZERO
	loot.set_physics_process(false)
	loot.call("configure", player)
	collected = {"value": 0}
	loot.xp_collected.connect(func(value: int) -> void: collected["value"] = int(collected["value"]) + value)
	loot.call("spawn_xp", Vector2.ZERO, 6, 1, 1.75)
	loot.call("spawn_xp", Vector2(1000.0, 0.0), 2, 0, 1.0)
	loot.call("_physics_process", 0.016)
	var swapped: Dictionary = loot.call("get_loot_snapshot")
	_require(int(collected["value"]) == 6 and int(swapped["count"]) == 1, "elite crystal pickup emits its exact value")
	_require(int(swapped["values"][0]) == 2 and int(swapped["qualities"][0]) == 0 and is_equal_approx(float(swapped["scales"][0]), 1.0), "loot swap-pop keeps the surviving normal crystal's metadata together")
	_require(_metadata_is_aligned(swapped), "loot metadata remains aligned after swap-pop pickup")
	get_root().remove_child(loot)
	get_root().remove_child(player)
	loot.free()
	player.free()


func _metadata_is_aligned(snapshot: Dictionary) -> bool:
	var expected := int(snapshot["count"])
	return snapshot["positions"].size() == expected and snapshot["values"].size() == expected and snapshot["qualities"].size() == expected and snapshot["scales"].size() == expected


func _reasonable_float(value: float, upper_bound: float) -> bool:
	return not is_nan(value) and not is_inf(value) and value > 0.0 and value < upper_bound


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("GROWTH_AND_ELITE_LOOT_TEST_FAIL: " + message)
