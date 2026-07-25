extends SceneTree

const CareerCatalog := preload("res://scripts/career_catalog.gd")
const ActionCatalog := preload("res://scripts/career_action_catalog.gd")

const EXPECTED_ARCHETYPES := {
	"ops": "melee_combo",
	"dba": "delayed_zone",
	"network": "piercing_projectile",
	"security": "persistent_wall",
	"it_ops": "deployable_node",
	"helpdesk": "chain_bounce",
	"opsdev": "delayed_repeat",
	"sre": "trace_replay",
	"delivery": "delayed_aoe",
	"ai_infra": "tensor_pipeline",
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var profile := get_root().get_node("ProfileStore")
	profile.reset_for_tests()
	_require(ActionCatalog.all().size() == 10, "ten career action kits exist")
	var signature_ids := {}
	var skill_ids := {}
	var ultimate_ids := {}
	var archetypes := {}
	for kit in ActionCatalog.all():
		var career_id := String(kit["career_id"])
		var signature: Dictionary = kit["signature"]
		var skill: Dictionary = kit["skill"]
		var ultimate: Dictionary = kit["ultimate"]
		signature_ids[String(signature["id"])] = true
		skill_ids[String(skill["id"])] = true
		ultimate_ids[String(ultimate["id"])] = true
		archetypes[String(signature["archetype"])] = true
		_require(String(signature["archetype"]) == EXPECTED_ARCHETYPES[career_id], "%s has its intended attack geometry" % career_id)
		_require(float(skill["cooldown"]) > 0.0 and float(ultimate["cooldown"]) > float(skill["cooldown"]), "%s has short and long cooldown tiers" % career_id)
	_require(signature_ids.size() == 10 and skill_ids.size() == 10 and ultimate_ids.size() == 10 and archetypes.size() == 10, "all action identities are unique")

	for career in CareerCatalog.all():
		var career_id := String(career["id"])
		if career_id != "ops":
			profile.unlock_career(career_id)
		_require(profile.select_career(career_id), "%s can be selected" % career_id)
		var run: Node = load("res://scenes/run.tscn").instantiate()
		get_root().add_child(run)
		var player: CharacterBody2D = run.get_node("Player")
		var swarm: Node2D = run.get_node("SwarmWorld")
		var combat: Node2D = run.get_node("CombatSystem")
		var actions: Node2D = run.get_node("CareerActionSystem")
		var hud: CanvasLayer = run.get_node("HUD")
		actions.debug_disable_auto_signature = true
		actions.set_physics_process(false)
		combat.set_physics_process(false)
		player.set_physics_process(false)
		swarm.set_physics_process(false)
		swarm.call("clear_all")
		player.global_position = Vector2(1200, 750)
		var snapshot: Dictionary = actions.call("get_action_snapshot")
		var expected_kit := ActionCatalog.get_by_id(career_id)
		_require(String(snapshot.get("career_id", "")) == career_id, "%s config reaches the action runtime" % career_id)
		_require(String(snapshot.get("signature", {}).get("id", "")) == String(expected_kit["signature"]["id"]), "%s signature id matches catalog" % career_id)
		_test_signature_geometry(actions, swarm, player, career_id)
		if career_id == "security":
			for _upgrade_index in range(3):
				actions.call("apply_career_upgrade", "security_cryo_acl")
				actions.call("apply_career_upgrade", "security_storm_ids")
		if career_id == "opsdev":
			for weapon_id in ["ping", "log", "wrench"]:
				combat.call("apply_upgrade", weapon_id)
				combat.emit_signal("attack_fired", weapon_id, player.global_position, 1.0)
			swarm.call("clear_all")
			for enemy_index in range(6):
				swarm.call("spawn_enemy", SwarmWorld.EnemyKind.ELITE_502, player.global_position + Vector2(180.0 + float(enemy_index % 3) * 90.0, float(enemy_index / 3) * 150.0 - 75.0))
				swarm.health[enemy_index] = 10_000.0
				swarm.maximum_health[enemy_index] = 10_000.0

		var skill_cooldown := float(expected_kit["skill"]["cooldown"])
		_require(bool(actions.call("try_skill", Vector2.RIGHT)), "%s skill casts when ready" % career_id)
		snapshot = actions.call("get_action_snapshot")
		_require(float(snapshot["skill"]["remaining"]) > 0.0, "%s skill starts cooldown" % career_id)
		if career_id == "network":
			actions.call("debug_advance_actions", 0.01)
			_require(is_equal_approx(float(combat.temporary_damage_multiplier), 1.15), "packet capture grants +15% total attack in its area")
			player.global_position += Vector2(260, 0)
			actions.call("debug_advance_actions", 0.01)
			_require(is_equal_approx(float(combat.temporary_damage_multiplier), 1.0), "packet capture buff ends outside its area")
		if career_id == "delivery":
			_assert_delivery_skill(actions, swarm, skill_cooldown)
		else:
			_require(not bool(actions.call("try_skill", Vector2.RIGHT)), "%s skill cannot be spammed" % career_id)
		if career_id == "sre":
			_assert_sre_skill(actions)
		elif career_id == "security":
			_assert_security_skill(actions, swarm)
		elif career_id == "opsdev":
			_assert_opsdev_skill(actions, combat, swarm, player)
		elif career_id == "ai_infra":
			_assert_ai_infra_skill(actions)
		if career_id != "delivery":
			actions.call("debug_advance_actions", skill_cooldown + 0.05)
			_require(bool(actions.call("try_skill", Vector2.RIGHT)), "%s skill becomes ready after cooldown" % career_id)

		if career_id == "opsdev":
			swarm.call("clear_all")
			swarm.call("spawn_enemy", SwarmWorld.EnemyKind.ELITE_502, player.global_position + Vector2(280, 0))
			swarm.health[0] = 10_000.0
			swarm.maximum_health[0] = 10_000.0
		var ultimate_cooldown := float(expected_kit["ultimate"]["cooldown"])
		_require(bool(actions.call("try_ultimate")), "%s ultimate casts when ready" % career_id)
		snapshot = actions.call("get_action_snapshot")
		_require(float(snapshot["ultimate"]["remaining"]) > 0.0, "%s ultimate starts cooldown" % career_id)
		_require(not bool(actions.call("try_ultimate")), "%s ultimate cannot be spammed" % career_id)
		if career_id == "sre":
			_assert_sre_ultimate(actions, player)
		elif career_id == "security":
			_assert_security_ultimate(actions)
		elif career_id == "opsdev":
			_assert_opsdev_ultimate(actions, combat, player)
		elif career_id == "delivery":
			_assert_delivery_ultimate(actions)
		elif career_id == "ai_infra":
			_assert_ai_infra_ultimate(actions)
		actions.call("debug_advance_actions", ultimate_cooldown + 0.05)
		_require(bool(actions.call("try_ultimate")), "%s ultimate becomes ready after cooldown" % career_id)

		hud.call("update_career_actions", actions.call("get_action_snapshot"))
		var ui: Dictionary = hud.call("get_action_ui_snapshot")
		_require(bool(ui["skill_visible"]) and bool(ui["ultimate_visible"]), "%s exposes both action slots" % career_id)
		_require(not String(ui["skill_name"]).is_empty() and not String(ui["ultimate_name"]).is_empty(), "%s action slots are named" % career_id)
		_require(Vector2(ui["skill_position"]).y >= 600.0 and Vector2(ui["ultimate_position"]).y >= 600.0, "%s action slots sit on the lower HUD" % career_id)
		if career_id == "delivery":
			_require(String(ui.get("skill_cooldown", "")).contains("/"), "delivery HUD displays available and maximum Q charges")
		elif career_id == "opsdev":
			_require(bool(ui.get("opsdev_toolchain_visible", false)), "ops development exposes the expandable toolchain HUD")
			_require(bool(ui.get("opsdev_overlay_active", false)), "ops development removes the baked five-slot blue frame overlay")
			var pipeline_names: Array = ui.get("opsdev_toolchain_names", [])
			_require(pipeline_names.size() == 7 and not String(pipeline_names[0]).contains("EMPTY") and not String(pipeline_names[6]).contains("LOCKED"), "toolchain HUD expands to seven named weapon snippets")
		else:
			_require(not bool(ui.get("opsdev_overlay_active", false)), "%s keeps the standard five-slot HUD overlay" % career_id)
		get_root().remove_child(run)
		run.free()

	_require(InputMap.has_action("career_skill") and InputMap.has_action("career_ultimate"), "keyboard/gamepad actions are registered")
	_require(InputMap.action_get_events("career_skill").size() >= 3, "skill supports Q, Space and gamepad")
	_require(InputMap.action_get_events("career_ultimate").size() >= 2, "ultimate supports R and gamepad")
	print("CAREER_ACTIONS_TEST_PASS careers=10 signatures=10 skills=10 ultimates=10")
	quit(0)


func _test_signature_geometry(actions: Node2D, swarm: Node2D, player: CharacterBody2D, career_id: String) -> void:
	match career_id:
		"ops":
			swarm.call("spawn_enemy", SwarmWorld.EnemyKind.ENOSPC, player.global_position + Vector2(78, 0))
			swarm.call("spawn_enemy", SwarmWorld.EnemyKind.ENOSPC, player.global_position + Vector2(260, 0))
			var near_health := float(swarm.health[0])
			var far_health := float(swarm.health[1])
			var trace: Dictionary = actions.call("debug_cast_signature")
			_require(int(trace.get("hits", 0)) >= 1 and float(swarm.health[0]) < near_health, "ops melee hits the near target")
			_require(float(swarm.health[1]) == far_health, "ops melee does not become a ranged attack")
		"network":
			swarm.call("spawn_enemy", SwarmWorld.EnemyKind.ENOSPC, player.global_position + Vector2(500, 0))
			var health_before := float(swarm.health[0])
			var trace: Dictionary = actions.call("debug_cast_signature")
			_require(int(trace.get("hits", 0)) >= 1 and float(swarm.health[0]) < health_before, "network probe damages at long range")
		"security":
			_require(is_equal_approx(float(actions.call("_security_signature_damage_factor", 0)), 0.50) and is_equal_approx(float(actions.call("_security_signature_damage_factor", 5)), 1.0), "security wall attack starts at half payload and recovers its prior ceiling by stack five")
			var previous_stack_five_scale := 1.0 + 1.45 * 5.0 / 11.0
			_require(is_equal_approx(float(actions.call("_signature_area_multiplier_for_level", 0)), 0.45), "security wall geometry starts at forty-five percent of its former baseline")
			_require(is_equal_approx(float(actions.call("_signature_area_multiplier_for_level", 5)), previous_stack_five_scale), "security area stack five recovers the previous full geometry ceiling")
			var before := int(actions.call("get_action_snapshot")["walls"])
			actions.call("debug_cast_signature")
			_require(int(actions.call("get_action_snapshot")["walls"]) == before + 1, "security signature creates a persistent wall")
			var wall: Dictionary = actions.get("walls")[actions.get("walls").size() - 1]
			var wall_start := Vector2(wall["start"])
			var wall_end := Vector2(wall["end"])
			_require(wall_start.distance_to(wall_end) < 150.0 and float(wall.get("width", 999.0)) < 18.0, "security's initial checkpoint is short and narrow")
			var wall_midpoint := wall_start.lerp(wall_end, 0.5)
			var protected_direction := (player.global_position - wall_midpoint).normalized()
			swarm.call("spawn_enemy", SwarmWorld.EnemyKind.HTTP_404, wall_midpoint + protected_direction * 6.0)
			swarm.health[0] = 1000.0
			swarm.maximum_health[0] = 1000.0
			var health_before := float(swarm.health[0])
			actions.call("debug_advance_actions", 0.05)
			var largest_initial_flame_radius := 0.0
			for visual in actions.get("visuals"):
				if String(visual.get("type", "")) == "security_flame":
					largest_initial_flame_radius = maxf(largest_initial_flame_radius, float(visual.get("radius", 0.0)))
			_require(largest_initial_flame_radius > 0.0 and largest_initial_flame_radius < 26.0, "security's initial attached burn circles use the compact real hit radius")
			var wall_direction := (wall_end - wall_start).normalized()
			var wall_normal := wall_direction.orthogonal()
			var protected_side := signf((player.global_position - wall_start).dot(wall_normal))
			var enemy_side := signf((Vector2(swarm.positions[0]) - wall_start).dot(wall_normal))
			_require(enemy_side != protected_side, "security wall physically blocks ordinary faults from crossing toward the player")
			_require(float(swarm.health[0]) < health_before, "security wall burns blocked faults on contact")
		"sre":
			swarm.call("spawn_enemy", SwarmWorld.EnemyKind.ENOSPC, player.global_position + Vector2(110, 30))
			swarm.call("spawn_enemy", SwarmWorld.EnemyKind.ENOSPC, player.global_position + Vector2(220, -40))
			swarm.call("spawn_enemy", SwarmWorld.EnemyKind.ELITE_502, player.global_position + Vector2(330, 55))
			var elite_id := int(swarm.entity_ids[2])
			var trace: Dictionary = actions.call("debug_cast_signature")
			_require(int(trace.get("hits", 0)) == 3, "SRE Trace samples three prioritized SPAN nodes")
			var pending: Array = actions.get("pending_actions")
			_require(not pending.is_empty() and String(pending[0].get("type", "")) == "sre_trace_return", "SRE Trace schedules a reverse replay")
			var target_ids: Array = pending[0].get("target_ids", [])
			_require(not target_ids.is_empty() and int(target_ids[target_ids.size() - 1]) == elite_id, "SRE Trace ends at the highest-threat root cause")
			actions.call("debug_advance_actions", 0.65)
			_require(_count_pending_type(actions, "sre_trace_hit") == 3, "SRE reverse replay expands into ordered return hits")
			actions.call("debug_advance_actions", 0.30)
			_require(_count_pending_type(actions, "sre_trace_hit") == 0, "SRE reverse replay resolves all SPAN hits")
			swarm.call("clear_all")
			for kind in [SwarmWorld.EnemyKind.HTTP_404, SwarmWorld.EnemyKind.TIMEOUT_408, SwarmWorld.EnemyKind.ENOSPC]:
				swarm.call("spawn_enemy", kind, player.global_position + Vector2(120.0 + float(swarm.count) * 85.0, 0.0))
			actions.call("debug_cast_signature")
			actions.call("debug_advance_actions", 0.65)
			actions.call("debug_advance_actions", 0.30)
			_require(int(swarm.count) == 0, "SRE Trace has enough baseline damage to close a three-fault path")
		"ai_infra":
			swarm.call("spawn_enemy", SwarmWorld.EnemyKind.ENOSPC, player.global_position + Vector2(310, 0))
			swarm.health[0] = 10_000.0
			swarm.maximum_health[0] = 10_000.0
			var health_before := float(swarm.health[0])
			var trace: Dictionary = actions.call("debug_cast_signature")
			_require(int(trace.get("hits", 0)) == 2, "AI Infra starts two parallel Tensor tokens")
			_require(_count_pending_type(actions, "ai_tensor_stage") == 2, "AI Infra schedules the next Tensor stage for each token")
			for _stage in range(3):
				actions.call("debug_advance_actions", 0.16)
			_require(health_before - float(swarm.health[0]) >= 100.0, "AI Infra four-stage baseline deals at least 100 raw damage per cycle")
			_assert_ai_infra_has_no_circle_visuals(actions)
			swarm.call("clear_all")
		_:
			swarm.call("spawn_enemy", SwarmWorld.EnemyKind.ELITE_502, player.global_position + Vector2(90, 0))
			var snapshot_before: Dictionary = actions.call("get_action_snapshot")
			var trace: Dictionary = actions.call("debug_cast_signature")
			var snapshot_after: Dictionary = actions.call("get_action_snapshot")
			var state_changed := int(snapshot_after["zones"]) > int(snapshot_before["zones"]) or int(snapshot_after["nodes"]) > int(snapshot_before["nodes"]) or int(snapshot_after["pending"]) > int(snapshot_before["pending"]) or int(trace.get("hits", 0)) > 0
			_require(state_changed, "%s signature creates or damages through its real runtime effect" % career_id)


func _assert_sre_skill(actions: Node2D) -> void:
	var walls: Array = actions.get("walls")
	_require(not walls.is_empty() and String(walls[walls.size() - 1].get("kind", "")) == "traffic_link", "SRE traffic shift creates a primary-to-DR data link")
	for zone in actions.get("zones"):
		_require(String(zone.get("kind", "")) != "heal", "SRE traffic shift does not fall back to a healing circle")
	_assert_sre_has_no_circle_visuals(actions)


func _assert_security_skill(actions: Node2D, swarm: Node2D) -> void:
	_require(is_equal_approx(float(actions.call("_security_action_damage_factor")), 1.0), "maxed security augments restore Q and R to their previous damage ceiling")
	var walls: Array = actions.get("walls")
	var corridor_count := 0
	var corridor_midpoint := Vector2.ZERO
	for wall in walls:
		if String(wall.get("kind", "")) == "corridor":
			corridor_count += 1
			corridor_midpoint = Vector2(wall["start"]).lerp(Vector2(wall["end"]), 0.5)
			_require(int(wall.get("frost_level", 0)) == 3 and int(wall.get("storm_level", 0)) == 3, "security Q inherits maxed cryo ACL and storm IDS augments")
	_require(corridor_count >= 3, "security Q creates two burning lanes and a blocking gate")
	var lightning_target_index := int(swarm.get("count"))
	swarm.call("spawn_enemy", SwarmWorld.EnemyKind.ELITE_502, corridor_midpoint)
	swarm.health[lightning_target_index] = 1000.0
	swarm.maximum_health[lightning_target_index] = 1000.0
	actions.call("debug_advance_actions", 0.15)
	var has_flame := false
	var has_frost := false
	var has_lightning := false
	for visual in actions.get("visuals"):
		match String(visual.get("type", "")):
			"security_flame": has_flame = true
			"security_frost": has_frost = true
			"security_lightning": has_lightning = true
	_require(has_flame and has_frost, "security Q renders burning and freezing wall feedback")
	_require(has_lightning or int(swarm.get("count")) == 0, "storm IDS emits lightning when targets are available")


func _assert_opsdev_skill(actions: Node2D, combat: Node2D, swarm: Node2D, player: CharacterBody2D) -> void:
	var snapshot: Dictionary = actions.call("get_action_snapshot")
	var toolchain: Array = snapshot.get("opsdev_toolchain", [])
	_require(toolchain.size() == 3, "ops development records the last three distinct weapons")
	_require(String(toolchain[0].get("id", "")) == "ping" and String(toolchain[1].get("id", "")) == "log" and String(toolchain[2].get("id", "")) == "wrench", "toolchain preserves recent distinct weapon order")
	_require(String(toolchain[0].get("modifier", "")) == "FORK" and String(toolchain[1].get("modifier", "")) == "LOOP" and String(toolchain[2].get("modifier", "")) == "OPT", "Q assigns fork, loop and optimize compiler passes")
	_require(_count_pending_type(actions, "opsdev_compiled_stage") == 3, "Q schedules all three compiled weapon stages")
	var health_before := 0.0
	for enemy_index in range(int(swarm.get("count"))):
		health_before += float(swarm.health[enemy_index])
	actions.call("debug_advance_actions", 0.58)
	var health_after := 0.0
	for enemy_index in range(int(swarm.get("count"))):
		health_after += float(swarm.health[enemy_index])
	_require(health_after < health_before, "compiled weapon stages use the real combat geometry and damage the swarm")
	_require(not Array(combat.get("effects")).is_empty(), "compiled weapon stages reuse CombatSystem weapon visuals")
	var compiler_modifiers: Array[String] = ["fork", "loop_echo", "optimize"]
	var weapon_ids: Array = combat.call("get_weapon_upgrade_ids")
	for weapon_index in range(weapon_ids.size()):
		var weapon_id := String(weapon_ids[weapon_index])
		if int(combat.call("get_upgrade_level", weapon_id)) <= 0:
			combat.call("apply_upgrade", weapon_id)
		var compiled_result: Dictionary = combat.call("execute_compiled_weapon", weapon_id, player.global_position, Vector2.RIGHT, compiler_modifiers[weapon_index % compiler_modifiers.size()], 0.5, "opsdev_test")
		_require(bool(compiled_result.get("executed", false)), "compiler supports %s weapon geometry" % weapon_id)
	for _capacity_level in range(4):
		actions.call("apply_career_upgrade", "opsdev_pipeline_capacity")
	for weapon_id in ["bash", "firewall", "rule_chain", "worker"]:
		combat.emit_signal("attack_fired", weapon_id, player.global_position, 1.0)
	snapshot = actions.call("get_action_snapshot")
	toolchain = snapshot.get("opsdev_toolchain", [])
	_require(int(snapshot.get("opsdev_toolchain_capacity", 0)) == 7, "toolchain lottery upgrades expand capacity from three to seven")
	_require(toolchain.size() == 7 and String(toolchain[6].get("modifier", "")) == "JIT", "seven-slot toolchain retains seven distinct weapons and unlocks the JIT pass")


func _assert_opsdev_ultimate(actions: Node2D, combat: Node2D, player: CharacterBody2D) -> void:
	var snapshot: Dictionary = actions.call("get_action_snapshot")
	_require(String(snapshot.get("active", "")) == "opsdev_hot_reload", "ops development ultimate enters runtime hot reload mode")
	_require(_count_pending_type(actions, "opsdev_combo_tool") == 7 and _count_pending_type(actions, "opsdev_combo_commit") == 1, "hot reload opens by revealing and linking every tool before the combo commit")
	actions.call("debug_advance_actions", 0.50)
	var before_first_hook := _count_pending_type(actions, "opsdev_compiled_stage")
	combat.emit_signal("attack_fired", "ping", player.global_position, 1.0)
	var after_first_hook := _count_pending_type(actions, "opsdev_compiled_stage")
	combat.emit_signal("attack_fired", "ping", player.global_position, 1.0)
	var after_duplicate_hook := _count_pending_type(actions, "opsdev_compiled_stage")
	_require(after_first_hook == before_first_hook + 1, "hot reload intercepts the first weapon trigger in an epoch")
	_require(after_duplicate_hook == after_first_hook, "hot reload caps each weapon to one rewrite per epoch")
	actions.call("debug_advance_actions", 1.12)
	_require(int(actions.call("get_action_snapshot").get("opsdev_hot_reload_epoch", 0)) >= 1, "hot reload opens a fresh interception epoch")
	_require(_count_pending_type(actions, "opsdev_compiled_stage") >= 7, "every hot-reload epoch proactively executes the full seven-slot toolchain")


func _assert_security_ultimate(actions: Node2D) -> void:
	var snapshot: Dictionary = actions.call("get_action_snapshot")
	_require(String(snapshot.get("active", "")) == "security_lockdown", "security ultimate enters the global lockdown mode")
	var lockdown_walls := 0
	for wall in actions.get("walls"):
		if String(wall.get("kind", "")) == "lockdown":
			lockdown_walls += 1
	_require(lockdown_walls == 6, "global lockdown builds a complete six-wall hard perimeter")


func _assert_sre_ultimate(actions: Node2D, player: CharacterBody2D) -> void:
	var snapshot: Dictionary = actions.call("get_action_snapshot")
	_require(String(snapshot.get("active", "")) == "sre_multi_active", "SRE ultimate enters active-active mode")
	_require(int(snapshot.get("sre_replicas", 0)) == 2, "SRE ultimate restores two historical disaster-recovery sites")
	_require(is_equal_approx(float(player.temporary_damage_reduction), 0.30), "SRE active-active mode grants 30% temporary damage reduction")
	_assert_sre_has_no_circle_visuals(actions)


func _assert_ai_infra_skill(actions: Node2D) -> void:
	_require(_count_pending_type(actions, "ai_pipeline_flush") == 9, "AI Infra Q schedules the remaining three lanes by three Tensor stages")
	_require(_count_pending_type(actions, "ai_pipeline_output") == 3, "AI Infra Q schedules three Output Heads")
	var lane_visuals := 0
	for effect in actions.get("visuals"):
		if String(effect.get("type", "")) == "pipeline_lane":
			lane_visuals += 1
	_require(lane_visuals == 3, "AI Infra Q visibly opens three parallel data channels")
	_assert_ai_infra_has_no_circle_visuals(actions)


func _assert_ai_infra_ultimate(actions: Node2D) -> void:
	var snapshot: Dictionary = actions.call("get_action_snapshot")
	_require(String(snapshot.get("active", "")) == "ai_foundation_model", "AI Infra ultimate enters foundation-model inference")
	_require(_count_pending_type(actions, "ai_prefill_scan") == 6, "AI Infra ultimate schedules six Prefill scan lines")
	var has_matrix := false
	for effect in actions.get("visuals"):
		if String(effect.get("type", "")) == "attention_matrix":
			has_matrix = true
	_require(has_matrix, "AI Infra ultimate draws a full-screen attention matrix")
	actions.call("debug_advance_actions", 7.70)
	_require(bool(actions.get("ai_model_eos_fired")), "AI Infra ultimate reaches the EOS execution phase")
	_assert_ai_infra_has_no_circle_visuals(actions)


func _assert_delivery_skill(actions: Node2D, swarm: Node2D, skill_cooldown: float) -> void:
	var first_snapshot: Dictionary = actions.call("get_action_snapshot")
	_require(int(first_snapshot.get("skill", {}).get("charges", -1)) == 1 and int(first_snapshot.get("skill", {}).get("max_charges", 0)) == 2, "delivery Q starts with two independent stored charges")
	_require(String(first_snapshot.get("delivery_next_support", "")) == "dba", "delivery support rotation advances after the first teammate")
	actions.call("debug_advance_actions", 1.0)
	_require(bool(actions.call("try_skill", Vector2.RIGHT)), "delivery can spend its second stored Q immediately")
	var empty_snapshot: Dictionary = actions.call("get_action_snapshot")
	var timers: Array = empty_snapshot.get("skill", {}).get("charge_timers", [])
	_require(int(empty_snapshot.get("skill", {}).get("charges", -1)) == 0 and timers.size() == 2, "delivery tracks both spent Q charges separately")
	_require(timers.size() == 2 and absf(float(timers[0]) - float(timers[1])) > 0.9, "delivery Q recharge timers preserve their independent start times")
	_require(not bool(actions.call("try_skill", Vector2.RIGHT)), "delivery cannot cast after both stored Q charges are spent")
	actions.call("debug_advance_actions", skill_cooldown - 0.95)
	var restored_snapshot: Dictionary = actions.call("get_action_snapshot")
	_require(int(restored_snapshot.get("skill", {}).get("charges", -1)) == 1, "delivery restores the first Q charge while the second is still recharging")
	_require(bool(actions.call("try_skill", Vector2.RIGHT)), "delivery can spend a charge as soon as that individual timer finishes")
	_require(String(actions.call("get_action_snapshot").get("delivery_next_support", "")) == "security", "delivery support rotation keeps advancing across teams")
	var has_uat := false
	for zone in actions.get("zones"):
		if String(zone.get("kind", "")) == "uat":
			has_uat = true
	_require(has_uat, "every third delivery support call creates joint UAT acceptance")
	var test_position := Vector2(1520, 750)
	swarm.call("spawn_enemy", SwarmWorld.EnemyKind.ENOSPC, test_position)
	var vulnerable_index := int(swarm.count) - 1
	var health_before := float(swarm.health[vulnerable_index])
	swarm.call("amplify_damage_area", test_position, 32.0, 1.15, 1.0)
	swarm.call("damage_index", vulnerable_index, 10.0)
	_require(is_equal_approx(health_before - float(swarm.health[vulnerable_index]), 11.5), "UAT damage amplification applies its 15% vulnerability")
	while not Array(actions.get("delivery_skill_charge_timers")).is_empty():
		actions.call("debug_reset_cooldowns")
	actions.call("apply_career_upgrade", "delivery_sync_reserve")
	_require(int(actions.call("get_action_snapshot").get("skill", {}).get("max_charges", 0)) == 3, "delivery reserve card adds one Q charge")
	actions.call("apply_career_upgrade", "delivery_sync_parallel")
	actions.visuals.clear()
	_require(bool(actions.call("try_skill", Vector2.RIGHT)), "delivery can cast its upgraded parallel Q")
	var silhouette_count := 0
	for effect in actions.get("visuals"):
		if String(effect.get("type", "")) == "career_silhouette":
			silhouette_count += 1
	_require(silhouette_count == 2, "delivery parallel-signoff card increases silhouettes per Q from one to two")


func _assert_delivery_ultimate(actions: Node2D) -> void:
	_require(String(actions.call("get_action_snapshot").get("active", "")) == "delivery_all_hands", "delivery ultimate enters all-hands mode")
	var silhouette_count := 0
	for effect in actions.get("visuals"):
		if String(effect.get("type", "")) == "career_silhouette":
			silhouette_count += 1
	_require(silhouette_count >= 9, "delivery ultimate calls all nine other career silhouettes")
	_require(_count_pending_type(actions, "delivery_all_hands_wave") == 3, "delivery ultimate schedules three borrowed-signature waves")


func _assert_sre_has_no_circle_visuals(actions: Node2D) -> void:
	for effect in actions.get("visuals"):
		_require(String(effect.get("type", "")) not in ["ring", "blast", "marker", "range_preview_circle"], "SRE rework avoids circle-based attack visuals")


func _assert_ai_infra_has_no_circle_visuals(actions: Node2D) -> void:
	for effect in actions.get("visuals"):
		_require(String(effect.get("type", "")) not in ["ring", "blast", "marker", "range_preview_circle"], "AI Infra uses pipelines and matrices instead of circle attacks")


func _count_pending_type(actions: Node2D, pending_type: String) -> int:
	var result := 0
	for pending in actions.get("pending_actions"):
		if String(pending.get("type", "")) == pending_type:
			result += 1
	return result


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("CAREER_ACTIONS_TEST_FAIL: " + message)
	quit(1)
