extends SceneTree

const DifficultyCatalog := preload("res://scripts/difficulty_catalog.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var profile := get_root().get_node("ProfileStore")
	profile.reset_for_tests()
	_require(profile.get_points() == 0, "new profile starts at 0 RP")
	_require(profile.is_career_unlocked("ops"), "ops is unlocked by default")
	_require(not profile.is_career_unlocked("dba"), "advanced careers start locked")
	_require(int(profile.data.get("schema_version", 0)) == 6, "profile uses schema v6")
	_require(not profile.is_museum_unlocked("fault", "http_404"), "museum entries start undiscovered")
	_require(profile.discover_fault_kind(0), "encountering a normal fault unlocks its museum record")
	_require(profile.is_museum_unlocked("fault", "http_404"), "normal fault discovery persists in profile data")
	_require(profile.discover_fault_kind(7), "encountering the incident core unlocks the boss record")
	_require(profile.is_museum_unlocked("boss", "incident_core"), "boss discovery uses the dedicated museum category")
	_require(profile.discover_artifact("rm_rf"), "equipping an artifact unlocks its museum record")
	_require(profile.is_museum_unlocked("artifact", "rm_rf"), "artifact discovery persists in profile data")
	_require(not profile.discover_artifact("rm_rf"), "repeated museum discovery is idempotent")
	_require(String(profile.get_settings().get("music_style", "")) == "suno_01", "new profiles default to BGM01")
	profile.call("_merge_profile", {"schema_version": 4, "settings": {"music_style": "pulse"}})
	_require(String(profile.get_settings().get("music_style", "")) == "suno_01", "legacy pulse defaults migrate to BGM01")
	profile.call("_merge_profile", {"schema_version": 6, "settings": {"music_style": "maximum_breach"}})
	_require(String(profile.get_settings().get("music_style", "")) == "maximum_breach", "new imported BGM selections survive profile loading")
	_require(profile.session_event_id == "release", "release is the default selected event")
	_require(profile.session_difficulty_id == "normal" and profile.is_difficulty_unlocked("normal"), "normal is the default unlocked difficulty")
	_require(not profile.select_difficulty("advanced"), "a locked difficulty cannot be selected")
	_require(profile.select_event("backup_restore"), "a catalog event can be selected")
	_require(profile.session_event_id == "backup_restore" and String(profile.data.get("last_event", "")) == "backup_restore", "event selection persists in the session profile")
	_require(not profile.select_event("unknown_event"), "an unknown event cannot be selected")

	var result := _base_result("profile-structured-001")
	# Legacy release fields deliberately coexist here. Structured events must win
	# and the old +8/+12 path must not be counted a second time.
	result["release_success"] = true
	result["release_choice"] = "full"
	result["events"] = [
		_event("release-001", "release", "full", "success"),
		_event("restore-001", "backup_restore", "full_restore", "success"),
		_event("update-001", "version_update", "in_place", "success"),
		_event("troubleshoot-001", "troubleshoot", "traces", "success"),
	]
	var settlement: Dictionary = profile.award_run(result)
	_require(int(settlement["total"]) == 88, "structured event rewards use catalog base and risk values without legacy double counting")
	_require(_breakdown_value(settlement, "线上发布 · 成功") == 8, "event success uses the catalog success reward")
	_require(_breakdown_value(settlement, "直接全量 · 高风险策略") == 12, "successful high-risk strategy earns its catalog bonus")
	_require(_breakdown_value(settlement, "发布窗口") == 0, "legacy release reward is absent when structured events exist")
	_require(profile.get_points() == 88, "structured settlement is added to the profile")
	for event_id in ["release", "backup_restore", "version_update", "troubleshoot"]:
		var event_stat: Dictionary = profile.get_event_stats(event_id)
		_require(int(event_stat["attempts"]) == 1 and int(event_stat["success"]) == 1, "%s success is recorded once" % event_id)
	for career_id in ["delivery", "dba", "it_ops", "network"]:
		_require(profile.is_career_unlocked(career_id), "%s unlocks from its structured event" % career_id)

	var points_before_duplicate: int = profile.get_points()
	var duplicate: Dictionary = profile.award_run(result)
	_require(bool(duplicate.get("duplicate", false)), "run settlement is idempotent")
	_require(profile.get_points() == points_before_duplicate, "duplicate run settlement awards no RP")
	_require(int(profile.get_event_stats("release")["attempts"]) == 1, "duplicate run does not increment event statistics")

	var duplicate_instance_result := _base_result("profile-instance-002")
	duplicate_instance_result["events"] = [
		_event("restore-shared", "backup_restore", "snapshot", "success"),
		_event("restore-shared", "backup_restore", "full_restore", "success"),
	]
	var instance_settlement: Dictionary = profile.award_run(duplicate_instance_result)
	_require(int(instance_settlement["total"]) == 28, "duplicate instance_id is rewarded only once inside a run")
	_require(int(profile.get_event_stats("backup_restore")["attempts"]) == 2, "duplicate event instance increments statistics once")

	var repeated_instance_result := _base_result("profile-instance-003")
	repeated_instance_result["events"] = [_event("restore-shared", "backup_restore", "full_restore", "success")]
	var repeated_instance: Dictionary = profile.award_run(repeated_instance_result)
	_require(int(repeated_instance["total"]) == 36, "instance_id may repeat in a different run because run_id owns cross-run idempotency")
	_require(int(profile.get_event_stats("backup_restore")["attempts"]) == 3, "a repeated per-run instance is recorded for the new run")

	var outcome_result := _base_result("profile-outcomes-004")
	outcome_result["release_success"] = true
	outcome_result["release_choice"] = "full"
	outcome_result["events"] = [
		_event("release-partial", "release", "rollback", "partial"),
		_event("update-failed", "version_update", "in_place", "failed"),
	]
	var outcome_settlement: Dictionary = profile.award_run(outcome_result)
	_require(int(outcome_settlement["total"]) == 24, "partial earns only partial_reward and failed earns zero")
	_require(_breakdown_value(outcome_settlement, "线上发布 · 部分完成") == 4, "partial outcome uses catalog partial reward")
	_require(_breakdown_value(outcome_settlement, "原地升级 · 高风险策略") == 0, "failed high-risk strategy earns no bonus")
	_require(int(profile.get_event_stats("release")["partial"]) == 1, "partial outcome is recorded")
	_require(int(profile.get_event_stats("version_update")["failed"]) == 1, "failed outcome is recorded")

	var skill_result := _base_result("profile-skills-005")
	skill_result["victory"] = true
	skill_result["ally"] = true
	skill_result["health_ratio"] = 0.75
	skill_result["build"] = {"firewall": 3, "worker": 3, "iac": true}
	profile.award_run(skill_result)
	for career_id in ["security", "helpdesk", "opsdev", "sre", "ai_infra"]:
		_require(profile.is_career_unlocked(career_id), "%s keeps its pre-v2 skill or run condition" % career_id)
	_require(profile.purchase_upgrade("health"), "RP can purchase a permanent baseline")
	_require(int(profile.get_permanent_upgrades()["health"]) == 1, "purchased baseline persists in memory")
	_require(profile.select_career("dba"), "an event-unlocked career can be selected")
	_require(profile.session_career_id == "dba", "career selection updates the next run")

	profile.reset_for_tests()
	var legacy_result := _base_result("profile-legacy-006")
	legacy_result["release_success"] = true
	legacy_result["release_choice"] = "full"
	var legacy_settlement: Dictionary = profile.award_run(legacy_result)
	_require(int(legacy_settlement["total"]) == 40, "a result without events keeps the legacy +8/+12 release reward")
	_require(profile.is_career_unlocked("delivery"), "legacy successful release still unlocks delivery")

	profile.reset_for_tests()
	var failed_normal := _base_result("difficulty-normal-failed")
	profile.award_run(failed_normal)
	_require(not profile.is_difficulty_unlocked("advanced"), "failing normal does not unlock advanced")
	var normal_victory := _base_result("difficulty-normal-win")
	normal_victory["victory"] = true
	var normal_victory_settlement: Dictionary = profile.award_run(normal_victory)
	_require(normal_victory_settlement.get("difficulty_unlocks", []) == ["advanced"], "clearing normal unlocks advanced")
	_require(profile.is_difficulty_unlocked("advanced") and profile.select_difficulty("advanced"), "advanced becomes selectable after normal clear")
	_require(not profile.select_difficulty("abyss"), "abyss cannot be selected before advanced clear")
	var forged_abyss := _base_result("difficulty-abyss-forged")
	forged_abyss["difficulty_id"] = "abyss"
	forged_abyss["victory"] = true
	profile.award_run(forged_abyss)
	_require(not profile.is_difficulty_unlocked("impossible"), "a locked abyss result cannot skip the progression chain")
	var advanced_victory := _base_result("difficulty-advanced-win")
	advanced_victory["difficulty_id"] = "advanced"
	advanced_victory["victory"] = true
	var advanced_settlement: Dictionary = profile.award_run(advanced_victory)
	_require(int(advanced_settlement["total"]) > int(normal_victory_settlement["total"]), "advanced victory applies its RP multiplier")
	_require(profile.is_difficulty_unlocked("abyss") and profile.select_difficulty("abyss"), "clearing advanced unlocks abyss")
	var abyss_victory := _base_result("difficulty-abyss-win")
	abyss_victory["difficulty_id"] = "abyss"
	abyss_victory["victory"] = true
	var abyss_settlement: Dictionary = profile.award_run(abyss_victory)
	_require(abyss_settlement.get("difficulty_unlocks", []) == ["impossible"], "clearing abyss unlocks impossible")
	_require(profile.is_difficulty_unlocked("impossible") and profile.select_difficulty("impossible"), "impossible becomes selectable only after abyss clear")
	_require(int(profile.get_difficulty_stats("abyss")["wins"]) >= 1, "difficulty statistics record abyss completions")

	profile.reset_for_tests()
	var cheat_unlocks: Dictionary = profile.unlock_all_progression()
	_require(int(cheat_unlocks["careers"]) == 9 and int(cheat_unlocks["difficulties"]) == 3, "unlock-all progression opens all careers and difficulties")
	for difficulty_id in DifficultyCatalog.ids():
		_require(profile.is_difficulty_unlocked(difficulty_id), "%s is available after unlock-all progression" % difficulty_id)
	print("PROFILE_REWARD_TEST_PASS schema=6 structured=%d legacy=%d difficulties=4 museum=ok" % [int(settlement["total"]), int(legacy_settlement["total"])])
	quit(0)


func _base_result(run_id: String) -> Dictionary:
	return {
		"run_id": run_id,
		"career_id": "ops",
		"victory": false,
		"level": 1,
		"closed": 0,
		"elites": 0,
		"ally": false,
		"protocol_completions": 0,
		"health_ratio": 0.0,
		"build": {},
	}


func _event(instance_id: String, event_id: String, strategy_id: String, outcome: String) -> Dictionary:
	return {
		"instance_id": instance_id,
		"event_id": event_id,
		"strategy_id": strategy_id,
		"outcome": outcome,
	}


func _breakdown_value(settlement: Dictionary, label: String) -> int:
	var total := 0
	for item in settlement.get("breakdown", []):
		if String(item.get("label", "")) == label:
			total += int(item.get("value", 0))
	return total


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("PROFILE_REWARD_TEST_FAIL: " + message)
	quit(1)
