extends SceneTree

const CareerCatalog := preload("res://scripts/career_catalog.gd")
const ActionCatalog := preload("res://scripts/career_action_catalog.gd")

const RANDOM_SEED_SAMPLES := 256
const REGULAR_COMBAT_SLOT_CAP := 4
const OPSDEV_COMBAT_SLOT_CAP := 7
const SIGNATURE_GROWTH_IDS: Array[String] = ["signature_rate", "signature_quantity", "signature_damage", "signature_area"]
const META_GROWTH_IDS: Array[String] = ["movement_speed", "career_skill_rate", "career_ultimate_rate"]

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
var failure_count := 0


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
		_assert_random_upgrade_pool(run, combat, actions, career_id)
		_assert_random_architecture_pool(run, combat, career_id)
		_require(not String(run.get_node("HUD").career_protocol_label.text).is_empty(), "%s exposes its protocol in the HUD" % career_id)
		_test_career_protocol(run, combat, actions, career_id)
		_require(int(run.career_protocol_completions) >= 1, "%s records protocol execution for settlement" % career_id)
		_assert_combat_slot_policy(run, combat, career_id)
		get_root().remove_child(run)
		run.free()
	if failure_count > 0:
		quit(1)
		return
	print("CAREER_RUNTIME_TEST_PASS careers=%d" % CareerCatalog.all().size())
	quit(0)


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error("CAREER_RUNTIME_TEST_FAIL: " + message)
	quit(1)


func _assert_random_upgrade_pool(run: Node, combat: Node, actions: Node, career_id: String) -> void:
	var eligible_ids := _eligible_upgrade_ids(run, combat, actions)
	_require(eligible_ids.size() >= 3, "%s has at least three eligible upgrade cards" % career_id)
	var seen_ids := {}
	var saw_choice_without_signature := false
	var saw_choice_without_affinity := false
	var affinity_ids: Array[String] = run.call("_career_affinity_ids")
	for seed_value in range(RANDOM_SEED_SAMPLES):
		run.rng.seed = seed_value + 1
		var choices: Array[Dictionary] = run.call("_build_upgrade_choices")
		_require(choices.size() == mini(3, eligible_ids.size()), "%s rolls exactly three eligible upgrade cards" % career_id)
		var choice_ids: Array[String] = []
		var contains_signature := false
		var contains_affinity := false
		for choice in choices:
			var choice_id := String(choice.get("id", ""))
			_require(choice_id in eligible_ids, "%s never rolls an ineligible upgrade: %s" % [career_id, choice_id])
			_require(choice_id not in choice_ids, "%s samples upgrade cards without replacement" % career_id)
			choice_ids.append(choice_id)
			seen_ids[choice_id] = true
			contains_signature = contains_signature or choice_id in SIGNATURE_GROWTH_IDS
			contains_affinity = contains_affinity or choice_id in affinity_ids
		if not contains_signature:
			saw_choice_without_signature = true
		if not contains_affinity:
			saw_choice_without_affinity = true
	for eligible_id in eligible_ids:
		_require(seen_ids.has(eligible_id), "%s full eligible pool can roll %s" % [career_id, eligible_id])
	for meta_id in META_GROWTH_IDS:
		_require(seen_ids.has(meta_id), "%s can roll global growth %s" % [career_id, meta_id])
	if career_id == "delivery":
		for upgrade_id in actions.call("get_career_upgrade_ids"):
			_require(seen_ids.has(String(upgrade_id)), "delivery random pool can roll career card %s" % String(upgrade_id))
	_require(saw_choice_without_signature, "%s allows a three-card roll without an intrinsic-attack card" % career_id)
	_require(saw_choice_without_affinity, "%s does not force a profession-affinity card into every roll" % career_id)


func _eligible_upgrade_ids(run: Node, combat: Node, actions: Node) -> Array[String]:
	var candidates: Array[String] = combat.call("get_weapon_upgrade_ids")
	candidates.append_array(actions.call("get_signature_upgrade_ids"))
	candidates.append_array(actions.call("get_career_upgrade_ids"))
	candidates.append_array(META_GROWTH_IDS)
	candidates.append_array(["idempotency", "runbook", "capacity", "redundancy"])
	var eligible: Array[String] = []
	for candidate in candidates:
		if int(run.call("_get_upgrade_level", candidate)) >= int(run.call("_get_upgrade_cap", candidate)):
			continue
		if bool(run.call("_is_combat_weapon", candidate)) and int(run.call("_get_upgrade_level", candidate)) == 0 and int(run.call("_combat_weapon_slot_count")) >= int(run.call("_combat_weapon_slot_cap")):
			continue
		eligible.append(candidate)
	if bool(combat.call("can_evolve")):
		eligible.append("iac")
	return eligible


func _assert_combat_slot_policy(run: Node, combat: Node, career_id: String) -> void:
	var expected_cap := OPSDEV_COMBAT_SLOT_CAP if career_id == "opsdev" else REGULAR_COMBAT_SLOT_CAP
	_require(int(run.call("_combat_weapon_slot_cap")) == expected_cap, "%s exposes the intended combat weapon cap" % career_id)
	var weapon_ids: Array = combat.call("get_weapon_upgrade_ids")
	for weapon_id_value in weapon_ids:
		if int(run.call("_combat_weapon_slot_count")) >= expected_cap:
			break
		var weapon_id := String(weapon_id_value)
		if int(combat.call("get_upgrade_level", weapon_id)) <= 0:
			if career_id == "opsdev" and int(run.call("_combat_weapon_slot_count")) >= REGULAR_COMBAT_SLOT_CAP:
				_require(weapon_id in _eligible_upgrade_ids(run, combat, run.get_node("CareerActionSystem")), "ops development can still roll weapon %s beyond the normal four-slot boundary" % weapon_id)
			combat.call("apply_upgrade", weapon_id)
	_require(int(run.call("_combat_weapon_slot_count")) == expected_cap, "%s can fill exactly %d weapon slots" % [career_id, expected_cap])
	var eligible_after_cap := _eligible_upgrade_ids(run, combat, run.get_node("CareerActionSystem"))
	for weapon_id_value in weapon_ids:
		var weapon_id := String(weapon_id_value)
		if int(combat.call("get_upgrade_level", weapon_id)) <= 0:
			_require(weapon_id not in eligible_after_cap, "%s cannot roll an eighth/new weapon after reaching its cap" % career_id)
	if career_id == "opsdev":
		var architecture_choices: Array[Dictionary] = run.call("_build_architecture_choices")
		for choice in architecture_choices:
			var signature_id := String(run.call("_architecture_signature", String(choice.get("id", ""))))
			_require(signature_id.is_empty() or int(combat.call("get_upgrade_level", signature_id)) > 0, "ops development architecture choices cannot inject an eighth weapon")
		var loadout: Array = run.call("_skill_loadout_for_hud")
		_require(loadout.size() == 8, "ops development HUD exposes its signature plus seven carried weapons")
		var visible_slots := 0
		for slot in run.get_node("HUD").get("skill_slots"):
			if slot.visible:
				visible_slots += 1
		_require(visible_slots == 8, "ops development expands the bottom weapon tray to eight visible entries")


func _assert_random_architecture_pool(run: Node, combat: Node, career_id: String) -> void:
	var eligible_ids: Array[String] = []
	for architecture_id in combat.call("get_architecture_upgrade_ids"):
		var resolved_id := String(architecture_id)
		if int(run.call("_get_upgrade_level", resolved_id)) < 2:
			eligible_ids.append(resolved_id)
	_require(eligible_ids.size() >= 3, "%s has at least three eligible architecture cards" % career_id)
	var seen_ids := {}
	var missing_on_some_roll := {}
	for architecture_id in eligible_ids:
		missing_on_some_roll[architecture_id] = false
	for seed_value in range(RANDOM_SEED_SAMPLES):
		run.rng.seed = 10_000 + seed_value
		var choices: Array[Dictionary] = run.call("_build_architecture_choices")
		_require(choices.size() == mini(3, eligible_ids.size()), "%s rolls exactly three eligible architecture cards" % career_id)
		var choice_ids: Array[String] = []
		for choice in choices:
			var choice_id := String(choice.get("id", ""))
			_require(choice_id in eligible_ids, "%s never rolls an ineligible architecture: %s" % [career_id, choice_id])
			_require(choice_id not in choice_ids, "%s samples architecture cards without replacement" % career_id)
			choice_ids.append(choice_id)
			seen_ids[choice_id] = true
		for architecture_id in eligible_ids:
			if architecture_id not in choice_ids:
				missing_on_some_roll[architecture_id] = true
	for architecture_id in eligible_ids:
		_require(seen_ids.has(architecture_id), "%s full architecture pool can roll %s" % [career_id, architecture_id])
		_require(bool(missing_on_some_roll[architecture_id]), "%s does not force architecture %s into every roll" % [career_id, architecture_id])


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
			run.career_protocol_progress = 0.0
			actions.emit_signal("career_metric", "sre_root_closed", 10.0)
			_require(is_equal_approx(float(run.career_protocol_progress), 10.0), "SRE root-cause closes replenish 10 error budget")
			run.career_protocol_progress = 50.0
			run.career_protocol_cooldown = 0.0
			player.health = player.max_health * 0.30
			var health_before := float(player.health)
			run.call("_update_career_protocol", 0.016)
			_require(float(player.health) > health_before and float(run.career_protocol_progress) < 1.0, "SRE consumes error budget for recovery")
		"delivery":
			actions.call("apply_career_upgrade", "delivery_release_burn_down")
			actions.delivery_support_index = 0
			actions.ultimate_cooldown_left = 20.0
			var swarm: Node = run.get_node("SwarmWorld")
			swarm.call("clear_all")
			for _enemy_index in range(15):
				swarm.call("spawn_enemy", SwarmWorld.EnemyKind.BUG, player.global_position + Vector2(120.0, 0.0))
			_require(bool(actions.call("try_skill", Vector2.RIGHT)), "delivery Q can exercise release burn-down")
			_require(absf(float(actions.ultimate_cooldown_left) - 18.8) <= 0.001, "delivery Q kill reduction respects the 1.2s per-cast level-one cap")
			swarm.emit_signal("enemy_closed_by_source", "delivery_r", player.global_position, 0)
			_require(absf(float(actions.ultimate_cooldown_left) - 18.8) <= 0.001, "delivery R kills never feed their own cooldown loop")
			for _burn_level in range(4):
				actions.call("apply_career_upgrade", "delivery_release_burn_down")
			_require(is_equal_approx(float(actions.call("delivery_q_kill_ultimate_reduction")), 0.36) and is_equal_approx(float(actions.call("delivery_q_cast_ultimate_reduction_cap")), 3.60), "delivery release burn-down grows gradually to its bounded fifth tier")
			var delivery_rerolls_before := int(run.reroll_charges)
			run.call("_complete_delivery_milestone")
			_require(bool(run.career_protocol_triggered) and int(run.reroll_charges) == delivery_rerolls_before + 1, "delivery acceptance milestone grants one review")
		"ai_infra":
			_require(float(combat.career_summon_damage_multiplier) > 1.0, "AI Infra summon damage modifier is applied")
			actions.signature_timer = 5.0
			run.career_protocol_count = 19
			run.call("_career_on_enemy_closed", player.global_position, 0)
			_require(int(run.career_protocol_count) == 0 and float(actions.signature_timer) == 0.0, "AI Infra close batch primes a KV-cache Tensor cycle")
