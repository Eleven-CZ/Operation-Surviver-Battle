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
	"sre": "adaptive_ring",
	"delivery": "delayed_aoe",
	"ai_infra": "autonomous_summon",
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
		var actions: Node2D = run.get_node("CareerActionSystem")
		var hud: CanvasLayer = run.get_node("HUD")
		actions.debug_disable_auto_signature = true
		actions.set_physics_process(false)
		player.set_physics_process(false)
		swarm.set_physics_process(false)
		swarm.call("clear_all")
		player.global_position = Vector2(1200, 750)
		var snapshot: Dictionary = actions.call("get_action_snapshot")
		var expected_kit := ActionCatalog.get_by_id(career_id)
		_require(String(snapshot.get("career_id", "")) == career_id, "%s config reaches the action runtime" % career_id)
		_require(String(snapshot.get("signature", {}).get("id", "")) == String(expected_kit["signature"]["id"]), "%s signature id matches catalog" % career_id)
		_test_signature_geometry(actions, swarm, player, career_id)

		var skill_cooldown := float(expected_kit["skill"]["cooldown"])
		_require(bool(actions.call("try_skill", Vector2.RIGHT)), "%s skill casts when ready" % career_id)
		snapshot = actions.call("get_action_snapshot")
		_require(float(snapshot["skill"]["remaining"]) > 0.0, "%s skill starts cooldown" % career_id)
		if career_id == "network":
			var combat: Node = run.get_node("CombatSystem")
			actions.call("debug_advance_actions", 0.01)
			_require(is_equal_approx(float(combat.temporary_damage_multiplier), 1.15), "packet capture grants +15% total attack in its area")
			player.global_position += Vector2(260, 0)
			actions.call("debug_advance_actions", 0.01)
			_require(is_equal_approx(float(combat.temporary_damage_multiplier), 1.0), "packet capture buff ends outside its area")
		_require(not bool(actions.call("try_skill", Vector2.RIGHT)), "%s skill cannot be spammed" % career_id)
		actions.call("debug_advance_actions", skill_cooldown + 0.05)
		_require(bool(actions.call("try_skill", Vector2.RIGHT)), "%s skill becomes ready after cooldown" % career_id)

		var ultimate_cooldown := float(expected_kit["ultimate"]["cooldown"])
		_require(bool(actions.call("try_ultimate")), "%s ultimate casts when ready" % career_id)
		snapshot = actions.call("get_action_snapshot")
		_require(float(snapshot["ultimate"]["remaining"]) > 0.0, "%s ultimate starts cooldown" % career_id)
		_require(not bool(actions.call("try_ultimate")), "%s ultimate cannot be spammed" % career_id)
		actions.call("debug_advance_actions", ultimate_cooldown + 0.05)
		_require(bool(actions.call("try_ultimate")), "%s ultimate becomes ready after cooldown" % career_id)

		hud.call("update_career_actions", actions.call("get_action_snapshot"))
		var ui: Dictionary = hud.call("get_action_ui_snapshot")
		_require(bool(ui["skill_visible"]) and bool(ui["ultimate_visible"]), "%s exposes both action slots" % career_id)
		_require(not String(ui["skill_name"]).is_empty() and not String(ui["ultimate_name"]).is_empty(), "%s action slots are named" % career_id)
		_require(Vector2(ui["skill_position"]).y >= 600.0 and Vector2(ui["ultimate_position"]).y >= 600.0, "%s action slots sit on the lower HUD" % career_id)
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
			var before := int(actions.call("get_action_snapshot")["walls"])
			actions.call("debug_cast_signature")
			_require(int(actions.call("get_action_snapshot")["walls"]) == before + 1, "security signature creates a persistent wall")
		_:
			swarm.call("spawn_enemy", SwarmWorld.EnemyKind.ELITE_502, player.global_position + Vector2(90, 0))
			var snapshot_before: Dictionary = actions.call("get_action_snapshot")
			var trace: Dictionary = actions.call("debug_cast_signature")
			var snapshot_after: Dictionary = actions.call("get_action_snapshot")
			var state_changed := int(snapshot_after["zones"]) > int(snapshot_before["zones"]) or int(snapshot_after["nodes"]) > int(snapshot_before["nodes"]) or int(snapshot_after["pending"]) > int(snapshot_before["pending"]) or int(trace.get("hits", 0)) > 0
			_require(state_changed, "%s signature creates or damages through its real runtime effect" % career_id)


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("CAREER_ACTIONS_TEST_FAIL: " + message)
	quit(1)
