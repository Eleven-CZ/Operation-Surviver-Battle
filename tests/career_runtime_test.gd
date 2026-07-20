extends SceneTree

const CareerCatalog := preload("res://scripts/career_catalog.gd")
const ActionCatalog := preload("res://scripts/career_action_catalog.gd")

var expected_start := {
	"ops": {},
	"dba": {},
	"network": {},
	"security": {},
	"it_ops": {},
	"helpdesk": {},
	"opsdev": {"idempotency": 1},
	"sre": {"runbook": 1},
	"delivery": {"runbook": 1},
	"ai_infra": {},
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var profile := get_root().get_node("ProfileStore")
	profile.reset_for_tests()
	for career in CareerCatalog.all():
		var career_id := String(career["id"])
		if career_id != "ops":
			profile.unlock_career(career_id)
		_require(profile.select_career(career_id), "%s can be selected" % career_id)
		var run: Node = load("res://scenes/run.tscn").instantiate()
		get_root().add_child(run)
		_require(String(run.career_id) == career_id, "%s reaches RunController" % career_id)
		_require(String(run.get_node("Player").career_id) == career_id, "%s reaches player visuals" % career_id)
		_require(run.get_node("HUD").career_icon.texture is AtlasTexture, "%s emblem reaches the combat HUD" % career_id)
		var combat: Node = run.get_node("CombatSystem")
		var actions: Node = run.get_node("CareerActionSystem")
		for upgrade_id in expected_start[career_id]:
			var actual := int(run.runbook_level) if upgrade_id == "runbook" else int(combat.call("get_upgrade_level", upgrade_id))
			_require(actual == int(expected_start[career_id][upgrade_id]), "%s starts with %s" % [career_id, upgrade_id])
		var action_snapshot: Dictionary = actions.call("get_action_snapshot")
		_require(String(action_snapshot.get("signature", {}).get("id", "")) == String(ActionCatalog.get_by_id(career_id)["signature"]["id"]), "%s always has its profession signature attack" % career_id)
		_require("×0" not in String(combat.call("get_build_summary")), "%s build summary hides zero-level tools" % career_id)
		var affinity_ids: Array[String] = run.call("_career_affinity_ids")
		var upgrade_choices: Array[Dictionary] = run.call("_build_upgrade_choices")
		var has_affinity := false
		for choice in upgrade_choices:
			if String(choice["id"]) in affinity_ids:
				has_affinity = true
		_require(has_affinity, "%s receives a profession-fit upgrade choice" % career_id)
		var architecture_choices: Array[Dictionary] = run.call("_build_architecture_choices")
		var preferred_architecture: String = run.call("_career_architecture_id")
		var has_preferred_architecture := false
		for choice in architecture_choices:
			if String(choice["id"]) == preferred_architecture:
				has_preferred_architecture = true
		_require(has_preferred_architecture, "%s sees its preferred architecture" % career_id)
		_require(not String(run.get_node("HUD").career_protocol_label.text).is_empty(), "%s exposes its protocol in the HUD" % career_id)
		_test_career_protocol(run, combat, actions, career_id)
		_require(int(run.career_protocol_completions) >= 1, "%s records protocol execution for settlement" % career_id)
		get_root().remove_child(run)
		run.free()
	print("CAREER_RUNTIME_TEST_PASS careers=%d" % CareerCatalog.all().size())
	quit(0)


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("CAREER_RUNTIME_TEST_FAIL: " + message)
	quit(1)


func _test_career_protocol(run: Node, combat: Node, actions: Node, career_id: String) -> void:
	var player: Node = run.get_node("Player")
	match career_id:
		"ops":
			combat.call("apply_upgrade", "bash")
			combat.call("apply_upgrade", "ping")
			combat.call("apply_upgrade", "log")
			var ops_rerolls_before := int(run.reroll_charges)
			run.call("_evaluate_career_milestones")
			_require(bool(run.career_protocol_triggered) and int(run.reroll_charges) == ops_rerolls_before + 1, "ops cross-domain protocol grants one review")
		"dba":
			run.career_protocol_count = 17
			run.call("_career_on_enemy_closed", player.global_position, 0)
			_require(int(run.career_protocol_count) == 0, "dba commits every 18 closes")
		"network":
			actions.signature_timer = 5.0
			player.global_position += Vector2(1000.0, 0.0)
			run.call("_update_career_protocol", 0.016)
			_require(int(run.career_protocol_count) == 1 and float(actions.signature_timer) == 0.0, "network movement converges and primes ICMP")
		"security":
			run.last_player_health = 100.0
			run.career_protocol_cooldown = 0.0
			run.call("_career_on_health_changed", 90.0)
			_require(float(run.career_protocol_cooldown) == 8.0, "security damage triggers quarantine cooldown")
		"it_ops":
			player.health = 80.0
			run.last_player_health = 80.0
			run.career_protocol_count = 5
			run.call("_career_on_enemy_closed", player.global_position, 0)
			_require(float(player.health) == 84.0 and int(run.career_protocol_count) == 0, "IT ops nearby closes restore health")
		"helpdesk":
			var loot: Node = run.get_node("LootWorld")
			var loot_before := int(loot.positions.size())
			run.career_protocol_count = 11
			run.call("_career_on_enemy_closed", player.global_position, 0)
			_require(int(run.career_protocol_count) == 0 and int(loot.positions.size()) == loot_before + 1, "Helpdesk SLA batch creates bonus telemetry")
		"opsdev":
			actions.signature_timer = 5.0
			run.career_protocol_count = 13
			run.call("_career_on_enemy_closed", player.global_position, 0)
			_require(int(run.career_protocol_count) == 0 and float(actions.signature_timer) == 0.0, "ops development triggers idempotent script retry")
		"sre":
			run.career_protocol_progress = 50.0
			run.career_protocol_cooldown = 0.0
			player.health = player.max_health * 0.30
			var health_before := float(player.health)
			run.call("_update_career_protocol", 0.016)
			_require(float(player.health) > health_before and float(run.career_protocol_progress) < 1.0, "SRE consumes error budget for recovery")
		"delivery":
			var delivery_rerolls_before := int(run.reroll_charges)
			run.call("_complete_delivery_milestone")
			_require(bool(run.career_protocol_triggered) and int(run.reroll_charges) == delivery_rerolls_before + 1, "delivery acceptance milestone grants one review")
		"ai_infra":
			_require(float(combat.career_summon_damage_multiplier) > 1.0, "AI Infra summon damage modifier is applied")
			actions.signature_timer = 5.0
			run.career_protocol_count = 19
			run.call("_career_on_enemy_closed", player.global_position, 0)
			_require(int(run.career_protocol_count) == 0 and float(actions.signature_timer) == 0.0, "AI Infra close batch primes autoscaling salvo")
