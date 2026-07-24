extends Node

const CareerCatalog := preload("res://scripts/career_catalog.gd")
const EventCatalog := preload("res://scripts/event_catalog.gd")
const DifficultyCatalog := preload("res://scripts/difficulty_catalog.gd")
const ArtifactCatalog := preload("res://scripts/artifact_catalog.gd")
const FaultCatalog := preload("res://scripts/fault_catalog.gd")

signal profile_changed
signal career_unlocked(career_id: String)
signal difficulty_unlocked(difficulty_id: String)
signal museum_entry_unlocked(category: String, entry_id: String)

const SAVE_PATH := "user://profile_v1.json"
const SCHEMA_VERSION := 6

var data: Dictionary = {}
var session_career_id := "ops"
var session_event_id := "release"
var session_difficulty_id := "normal"
var requested_menu_tab := "home"
var test_mode := false


func _ready() -> void:
	test_mode = OS.get_cmdline_user_args().has("--smoke-test") or OS.get_cmdline_user_args().has("--profile-test")
	_load_profile()
	apply_audio_settings()
	session_career_id = String(data.get("last_career", "ops"))
	if not is_career_unlocked(session_career_id):
		session_career_id = "ops"
	session_event_id = String(data.get("last_event", "release"))
	if session_event_id not in EventCatalog.ids():
		session_event_id = "release"
		data["last_event"] = session_event_id
	session_difficulty_id = String(data.get("last_difficulty", "normal"))
	if not is_difficulty_unlocked(session_difficulty_id):
		session_difficulty_id = "normal"
		data["last_difficulty"] = session_difficulty_id


func _default_data() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"runbook_points": 0,
		"unlocked_careers": ["ops"],
		"career_mastery": {"ops": 0},
		"permanent_upgrades": {"health": 0, "telemetry": 0, "reroll": 0, "mobility": 0},
		"stats": {"runs": 0, "wins": 0, "closed": 0, "elites": 0, "allies": 0, "protocols": 0, "best_level": 1},
		"settings": {"master_volume": 0.85, "music_volume": 0.76, "sfx_volume": 0.86, "music_style": "suno_01", "fault_labels": true, "high_contrast": false},
		"last_career": "ops",
		"last_event": "release",
		"unlocked_difficulties": ["normal"],
		"last_difficulty": "normal",
		"difficulty_stats": _default_difficulty_stats(),
		"event_stats": _default_event_stats(),
		"museum_unlocks": {"fault": [], "boss": [], "artifact": []},
		"committed_run_ids": [],
	}


func _default_event_stats() -> Dictionary:
	var result := {}
	for event_id in EventCatalog.ids():
		result[event_id] = {"attempts": 0, "success": 0, "partial": 0, "failed": 0}
	return result


func _default_difficulty_stats() -> Dictionary:
	var result := {}
	for difficulty_id in DifficultyCatalog.ids():
		result[difficulty_id] = {"runs": 0, "wins": 0, "best_level": 1}
	return result


func _load_profile() -> void:
	data = _default_data()
	if test_mode or not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_merge_profile(parsed)


func _merge_profile(saved: Dictionary) -> void:
	var saved_schema := int(saved.get("schema_version", 0))
	for key in ["runbook_points", "last_career", "last_event", "last_difficulty"]:
		if saved.has(key):
			data[key] = saved[key]
	if saved.get("unlocked_careers") is Array:
		data["unlocked_careers"] = saved["unlocked_careers"]
	if saved.get("committed_run_ids") is Array:
		data["committed_run_ids"] = saved["committed_run_ids"]
	if saved.get("unlocked_difficulties") is Array:
		var unlocked_difficulties: Array[String] = []
		for difficulty_value in saved["unlocked_difficulties"]:
			var difficulty_id := String(difficulty_value)
			if difficulty_id in DifficultyCatalog.ids() and difficulty_id not in unlocked_difficulties:
				unlocked_difficulties.append(difficulty_id)
		data["unlocked_difficulties"] = unlocked_difficulties
	for dictionary_key in ["career_mastery", "permanent_upgrades", "stats", "settings"]:
		if saved.get(dictionary_key) is Dictionary:
			var target: Dictionary = data[dictionary_key]
			target.merge(saved[dictionary_key], true)
			data[dictionary_key] = target
	if saved.get("event_stats") is Dictionary:
		var merged_event_stats: Dictionary = data["event_stats"]
		var saved_event_stats: Dictionary = saved["event_stats"]
		for event_id in EventCatalog.ids():
			if saved_event_stats.get(event_id) is Dictionary:
				var event_stat: Dictionary = merged_event_stats[event_id]
				event_stat.merge(saved_event_stats[event_id], true)
				merged_event_stats[event_id] = event_stat
		data["event_stats"] = merged_event_stats
	if saved.get("difficulty_stats") is Dictionary:
		var merged_difficulty_stats: Dictionary = data["difficulty_stats"]
		var saved_difficulty_stats: Dictionary = saved["difficulty_stats"]
		for difficulty_id in DifficultyCatalog.ids():
			if saved_difficulty_stats.get(difficulty_id) is Dictionary:
				var difficulty_stat: Dictionary = merged_difficulty_stats[difficulty_id]
				difficulty_stat.merge(saved_difficulty_stats[difficulty_id], true)
				merged_difficulty_stats[difficulty_id] = difficulty_stat
		data["difficulty_stats"] = merged_difficulty_stats
	if saved.get("museum_unlocks") is Dictionary:
		var saved_museum: Dictionary = saved["museum_unlocks"]
		var merged_museum: Dictionary = data["museum_unlocks"]
		for category in ["fault", "boss", "artifact"]:
			var valid_ids := _museum_valid_ids(category)
			var unlocked: Array[String] = []
			if saved_museum.get(category) is Array:
				for entry_value in saved_museum[category]:
					var entry_id := String(entry_value)
					if entry_id in valid_ids and entry_id not in unlocked:
						unlocked.append(entry_id)
			merged_museum[category] = unlocked
		data["museum_unlocks"] = merged_museum
	if "ops" not in data["unlocked_careers"]:
		data["unlocked_careers"].append("ops")
	if String(data.get("last_event", "release")) not in EventCatalog.ids():
		data["last_event"] = "release"
	if "normal" not in data["unlocked_difficulties"]:
		data["unlocked_difficulties"].push_front("normal")
	if String(data.get("last_difficulty", "normal")) not in DifficultyCatalog.ids() or not is_difficulty_unlocked(String(data.get("last_difficulty", "normal"))):
		data["last_difficulty"] = "normal"
	var settings: Dictionary = data.get("settings", {})
	var saved_music_style := String(settings.get("music_style", "suno_01"))
	if saved_music_style not in ["suno_01", "suno_02", "pulse", "ambient"]:
		settings["music_style"] = "suno_01"
	elif saved_schema < 5 and saved_music_style == "pulse":
		# Pulse was a project default rather than a player-selected import. Move
		# existing profiles to the new requested BGM01 default once on upgrade.
		settings["music_style"] = "suno_01"
	data["settings"] = settings
	data["schema_version"] = SCHEMA_VERSION


func save_profile() -> void:
	if test_mode:
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "  "))


func reset_for_tests() -> void:
	test_mode = true
	data = _default_data()
	session_career_id = "ops"
	session_event_id = "release"
	session_difficulty_id = "normal"
	profile_changed.emit()


func get_points() -> int:
	return int(data.get("runbook_points", 0))


func get_stats() -> Dictionary:
	return Dictionary(data.get("stats", {})).duplicate()


func get_settings() -> Dictionary:
	return Dictionary(data.get("settings", {})).duplicate()


func get_permanent_upgrades() -> Dictionary:
	return Dictionary(data.get("permanent_upgrades", {})).duplicate()


func get_museum_unlocks() -> Dictionary:
	return Dictionary(data.get("museum_unlocks", {"fault": [], "boss": [], "artifact": []})).duplicate(true)


func is_museum_unlocked(category: String, entry_id: String) -> bool:
	var museum: Dictionary = data.get("museum_unlocks", {})
	return entry_id in museum.get(category, [])


func unlock_museum_entry(category: String, entry_id: String) -> bool:
	if entry_id not in _museum_valid_ids(category) or is_museum_unlocked(category, entry_id):
		return false
	var museum: Dictionary = data.get("museum_unlocks", {"fault": [], "boss": [], "artifact": []})
	var unlocked: Array = museum.get(category, [])
	unlocked.append(entry_id)
	museum[category] = unlocked
	data["museum_unlocks"] = museum
	save_profile()
	museum_entry_unlocked.emit(category, entry_id)
	profile_changed.emit()
	return true


func discover_fault_kind(kind: int) -> bool:
	var fault_id := FaultCatalog.id_for_kind(kind)
	if fault_id.is_empty():
		return false
	return unlock_museum_entry(FaultCatalog.category_for_kind(kind), fault_id)


func discover_artifact(artifact_id: String) -> bool:
	return unlock_museum_entry("artifact", artifact_id)


func _museum_valid_ids(category: String) -> Array[String]:
	match category:
		"fault": return FaultCatalog.fault_ids()
		"boss": return FaultCatalog.boss_ids()
		"artifact": return ArtifactCatalog.ids()
	return []


func get_event_stats(event_id: String = "") -> Dictionary:
	var all_stats: Dictionary = data.get("event_stats", _default_event_stats())
	if event_id.is_empty():
		return all_stats.duplicate(true)
	return Dictionary(all_stats.get(event_id, {"attempts": 0, "success": 0, "partial": 0, "failed": 0})).duplicate()


func get_difficulty_stats(difficulty_id: String = "") -> Dictionary:
	var all_stats: Dictionary = data.get("difficulty_stats", _default_difficulty_stats())
	if difficulty_id.is_empty():
		return all_stats.duplicate(true)
	return Dictionary(all_stats.get(difficulty_id, {"runs": 0, "wins": 0, "best_level": 1})).duplicate()


func get_mastery(career_id: String) -> int:
	return int(Dictionary(data.get("career_mastery", {})).get(career_id, 0))


func get_mastery_rank(career_id: String) -> Dictionary:
	var score := get_mastery(career_id)
	var ranks: Array[Dictionary] = [
		{"tier": 0, "threshold": 0, "title": "见习观察"},
		{"tier": 1, "threshold": 20, "title": "独立值班"},
		{"tier": 2, "threshold": 60, "title": "主值班"},
		{"tier": 3, "threshold": 140, "title": "领域专家"},
		{"tier": 4, "threshold": 300, "title": "事故指挥"},
	]
	var current: Dictionary = ranks[0]
	var next_threshold := -1
	for index in range(ranks.size()):
		if score >= int(ranks[index]["threshold"]):
			current = ranks[index]
		elif next_threshold < 0:
			next_threshold = int(ranks[index]["threshold"])
			break
	return {
		"tier": int(current["tier"]),
		"title": String(current["title"]),
		"score": score,
		"next_threshold": next_threshold,
	}


func is_career_unlocked(career_id: String) -> bool:
	return career_id in data.get("unlocked_careers", ["ops"])


func select_career(career_id: String) -> bool:
	if not is_career_unlocked(career_id):
		return false
	session_career_id = career_id
	data["last_career"] = career_id
	save_profile()
	profile_changed.emit()
	return true


func select_event(event_id: String) -> bool:
	if event_id not in EventCatalog.ids():
		return false
	session_event_id = event_id
	data["last_event"] = event_id
	save_profile()
	profile_changed.emit()
	return true


func is_difficulty_unlocked(difficulty_id: String) -> bool:
	return difficulty_id in data.get("unlocked_difficulties", ["normal"])


func select_difficulty(difficulty_id: String) -> bool:
	if difficulty_id not in DifficultyCatalog.ids() or not is_difficulty_unlocked(difficulty_id):
		return false
	session_difficulty_id = difficulty_id
	data["last_difficulty"] = difficulty_id
	save_profile()
	profile_changed.emit()
	return true


func unlock_difficulty(difficulty_id: String) -> bool:
	if difficulty_id not in DifficultyCatalog.ids() or is_difficulty_unlocked(difficulty_id):
		return false
	data["unlocked_difficulties"].append(difficulty_id)
	var difficulty_stats: Dictionary = data["difficulty_stats"]
	difficulty_stats[difficulty_id] = Dictionary(difficulty_stats.get(difficulty_id, {"runs": 0, "wins": 0, "best_level": 1}))
	data["difficulty_stats"] = difficulty_stats
	difficulty_unlocked.emit(difficulty_id)
	return true


func unlock_career(career_id: String) -> bool:
	if career_id not in CareerCatalog.ids() or is_career_unlocked(career_id):
		return false
	data["unlocked_careers"].append(career_id)
	var mastery: Dictionary = data["career_mastery"]
	mastery[career_id] = int(mastery.get(career_id, 0))
	data["career_mastery"] = mastery
	career_unlocked.emit(career_id)
	return true


func unlock_all_careers() -> int:
	var unlocked_count := 0
	for career_id in CareerCatalog.ids():
		if unlock_career(career_id):
			unlocked_count += 1
	save_profile()
	profile_changed.emit()
	return unlocked_count


func unlock_all_difficulties() -> int:
	var unlocked_count := 0
	for difficulty_id in DifficultyCatalog.ids():
		if unlock_difficulty(difficulty_id):
			unlocked_count += 1
	save_profile()
	profile_changed.emit()
	return unlocked_count


func unlock_all_progression() -> Dictionary:
	var career_count := 0
	var difficulty_count := 0
	for career_id in CareerCatalog.ids():
		if unlock_career(career_id):
			career_count += 1
	for difficulty_id in DifficultyCatalog.ids():
		if unlock_difficulty(difficulty_id):
			difficulty_count += 1
	save_profile()
	profile_changed.emit()
	return {"careers": career_count, "difficulties": difficulty_count}


func upgrade_definitions() -> Array[Dictionary]:
	return [
		{"id": "health", "name": "容量基线", "description": "每级服务健康度 +6", "max": 5, "base_cost": 45, "step": 35, "color": "65e890"},
		{"id": "telemetry", "name": "遥测索引", "description": "每级经验收益 +3%", "max": 5, "base_cost": 50, "step": 40, "color": "70caff"},
		{"id": "reroll", "name": "变更评审额度", "description": "每级每局额外 +1 次重新评审", "max": 2, "base_cost": 100, "step": 100, "color": "c68cff"},
		{"id": "mobility", "name": "值班动线", "description": "每级移动速度 +2%", "max": 4, "base_cost": 55, "step": 45, "color": "ffd36a"},
	]


func get_upgrade_cost(upgrade_id: String) -> int:
	var levels: Dictionary = data["permanent_upgrades"]
	var current := int(levels.get(upgrade_id, 0))
	for definition in upgrade_definitions():
		if String(definition["id"]) == upgrade_id:
			return int(definition["base_cost"]) + current * int(definition["step"])
	return 999999


func purchase_upgrade(upgrade_id: String) -> bool:
	var levels: Dictionary = data["permanent_upgrades"]
	var current := int(levels.get(upgrade_id, 0))
	var maximum := 0
	for definition in upgrade_definitions():
		if String(definition["id"]) == upgrade_id:
			maximum = int(definition["max"])
			break
	if maximum <= 0 or current >= maximum:
		return false
	var cost := get_upgrade_cost(upgrade_id)
	if get_points() < cost:
		return false
	data["runbook_points"] = get_points() - cost
	levels[upgrade_id] = current + 1
	data["permanent_upgrades"] = levels
	save_profile()
	profile_changed.emit()
	return true


func set_setting(setting_id: String, value: Variant) -> void:
	var settings: Dictionary = data["settings"]
	settings[setting_id] = value
	data["settings"] = settings
	if setting_id in ["master_volume", "music_volume", "sfx_volume"]:
		apply_audio_settings()
	elif setting_id == "music_style" and is_instance_valid(AudioDirector) and AudioDirector.has_method("set_music_style"):
		AudioDirector.call("set_music_style", String(value))
	save_profile()
	profile_changed.emit()


func apply_audio_settings() -> void:
	var settings := get_settings()
	_set_bus_linear("Master", float(settings.get("master_volume", 0.85)))
	_set_bus_linear("Music", float(settings.get("music_volume", 0.76)))
	_set_bus_linear("SFX", float(settings.get("sfx_volume", 0.86)))
	_set_bus_linear("UI", float(settings.get("sfx_volume", 0.86)))


func _set_bus_linear(bus_name: String, linear_value: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	var clamped := clampf(linear_value, 0.0, 1.0)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(clamped) if clamped > 0.0 else -80.0)


func _event_id_from_result(event_result: Dictionary) -> String:
	return String(event_result.get("event_id", event_result.get("id", "")))


func _strategy_id_from_result(event_result: Dictionary) -> String:
	return String(event_result.get("strategy_id", event_result.get("strategy", "")))


func _strategy_definition(event_definition: Dictionary, strategy_id: String) -> Dictionary:
	for strategy_value in event_definition.get("strategies", []):
		if strategy_value is Dictionary and String(strategy_value.get("id", "")) == strategy_id:
			return strategy_value
	return {}


func _record_event_outcome(event_id: String, outcome: String) -> void:
	var all_stats: Dictionary = data.get("event_stats", _default_event_stats())
	var event_stat: Dictionary = all_stats.get(event_id, {"attempts": 0, "success": 0, "partial": 0, "failed": 0})
	event_stat["attempts"] = int(event_stat.get("attempts", 0)) + 1
	event_stat[outcome] = int(event_stat.get(outcome, 0)) + 1
	all_stats[event_id] = event_stat
	data["event_stats"] = all_stats


func _append_structured_event_rewards(events: Array, breakdown: Array[Dictionary]) -> void:
	var seen_instances := {}
	for event_value in events:
		if not event_value is Dictionary:
			continue
		var event_result: Dictionary = event_value
		if not bool(event_result.get("reward_eligible", true)):
			continue
		var event_id := _event_id_from_result(event_result)
		var outcome := String(event_result.get("outcome", "")).to_lower()
		if event_id not in EventCatalog.ids() or outcome not in ["success", "partial", "failed"]:
			continue
		var instance_id := String(event_result.get("instance_id", ""))
		if not instance_id.is_empty() and seen_instances.has(instance_id):
			continue
		if not instance_id.is_empty():
			seen_instances[instance_id] = true

		_record_event_outcome(event_id, outcome)
		var event_definition := EventCatalog.get_by_id(event_id)
		var event_name := String(event_definition.get("name", event_id))
		if outcome == "success":
			var success_reward := int(event_definition.get("success_reward", 0))
			if success_reward > 0:
				breakdown.append({"label": "%s · 成功" % event_name, "value": success_reward})
			var strategy := _strategy_definition(event_definition, _strategy_id_from_result(event_result))
			var risk_bonus := int(strategy.get("risk_bonus", 0))
			if risk_bonus > 0:
				breakdown.append({"label": "%s · 高风险策略" % String(strategy.get("name", event_name)), "value": risk_bonus})
		elif outcome == "partial":
			var partial_reward := int(event_definition.get("partial_reward", 0))
			if partial_reward > 0:
				breakdown.append({"label": "%s · 部分完成" % event_name, "value": partial_reward})

func award_run(result: Dictionary) -> Dictionary:
	var run_id := String(result.get("run_id", ""))
	var committed: Array = data.get("committed_run_ids", [])
	if not run_id.is_empty() and run_id in committed:
		return {"duplicate": true, "total": 0, "breakdown": [], "mastery": 0, "career_id": result.get("career_id", "ops"), "difficulty_id": result.get("difficulty_id", "normal"), "unlocks": [], "difficulty_unlocks": [], "balance": get_points()}
	var level := int(result.get("level", 1))
	var closed := int(result.get("closed", 0))
	var elites := int(result.get("elites", 0))
	var victory := bool(result.get("victory", false))
	var ally := bool(result.get("ally", false))
	var release_success := bool(result.get("release_success", false))
	var release_choice := String(result.get("release_choice", ""))
	var structured_events: Array = result.get("events", []) if result.get("events", []) is Array else []
	var protocol_completions := int(result.get("protocol_completions", 0))
	var career_id := String(result.get("career_id", "ops"))
	var difficulty_id := String(result.get("difficulty_id", "normal"))
	if difficulty_id not in DifficultyCatalog.ids():
		difficulty_id = "normal"
	var rank_before := get_mastery_rank(career_id)
	var breakdown: Array[Dictionary] = [
		{"label": "完成值班记录", "value": 8},
		{"label": "遥测与闭环", "value": mini(30, level * 2 + floori(float(closed) / 20.0))},
	]
	if elites > 0:
		breakdown.append({"label": "精英故障", "value": elites * 6})
	if ally:
		breakdown.append({"label": "War Room 协作", "value": 8})
	if not structured_events.is_empty():
		_append_structured_event_rewards(structured_events, breakdown)
	elif release_success:
		breakdown.append({"label": "发布窗口", "value": 8})
		if release_choice == "full":
			breakdown.append({"label": "高风险全量变更", "value": 12})
	if protocol_completions > 0:
		breakdown.append({"label": "岗位协议执行", "value": mini(8, protocol_completions * 2)})
	if victory:
		breakdown.append({"label": "恢复验证", "value": 32})
	else:
		breakdown.append({"label": "失败复盘保底", "value": 10})
	var total := 0
	for item in breakdown:
		total += int(item["value"])
	total = maxi(20, total)
	var difficulty_definition := DifficultyCatalog.get_by_id(difficulty_id)
	var difficulty_multiplier := float(difficulty_definition.get("reward_multiplier", 1.0))
	if victory and is_difficulty_unlocked(difficulty_id) and difficulty_multiplier > 1.0:
		var difficulty_bonus := maxi(1, roundi(float(total) * (difficulty_multiplier - 1.0)))
		breakdown.append({"label": "%s难度通关 ×%.2f" % [difficulty_definition["name"], difficulty_multiplier], "value": difficulty_bonus})
		total += difficulty_bonus
	data["runbook_points"] = get_points() + total

	var stats: Dictionary = data["stats"]
	stats["runs"] = int(stats.get("runs", 0)) + 1
	stats["wins"] = int(stats.get("wins", 0)) + (1 if victory else 0)
	stats["closed"] = int(stats.get("closed", 0)) + closed
	stats["elites"] = int(stats.get("elites", 0)) + elites
	stats["allies"] = int(stats.get("allies", 0)) + (1 if ally else 0)
	stats["protocols"] = int(stats.get("protocols", 0)) + protocol_completions
	stats["best_level"] = maxi(int(stats.get("best_level", 1)), level)
	data["stats"] = stats
	_record_difficulty_result(difficulty_id, victory, level)

	var mastery_gain := maxi(5, floori(float(total) / 5.0))
	var mastery: Dictionary = data["career_mastery"]
	mastery[career_id] = int(mastery.get(career_id, 0)) + mastery_gain
	data["career_mastery"] = mastery
	var rank_after := get_mastery_rank(career_id)
	var unlocks := _evaluate_unlocks(result)
	var difficulty_unlocks := _evaluate_difficulty_unlocks(difficulty_id, victory)
	if not run_id.is_empty():
		committed.append(run_id)
		while committed.size() > 100:
			committed.pop_front()
		data["committed_run_ids"] = committed
	save_profile()
	profile_changed.emit()
	return {
		"total": total,
		"breakdown": breakdown,
		"mastery": mastery_gain,
		"mastery_total": int(rank_after["score"]),
		"mastery_rank": rank_after,
		"rank_up": int(rank_after["tier"]) > int(rank_before["tier"]),
		"career_id": career_id,
		"difficulty_id": difficulty_id,
		"events": _settlement_event_entries(structured_events),
		"unlocks": unlocks,
		"difficulty_unlocks": difficulty_unlocks,
		"balance": get_points(),
	}


func _record_difficulty_result(difficulty_id: String, victory: bool, level: int) -> void:
	var all_stats: Dictionary = data.get("difficulty_stats", _default_difficulty_stats())
	var difficulty_stat: Dictionary = all_stats.get(difficulty_id, {"runs": 0, "wins": 0, "best_level": 1})
	difficulty_stat["runs"] = int(difficulty_stat.get("runs", 0)) + 1
	difficulty_stat["wins"] = int(difficulty_stat.get("wins", 0)) + (1 if victory else 0)
	difficulty_stat["best_level"] = maxi(int(difficulty_stat.get("best_level", 1)), level)
	all_stats[difficulty_id] = difficulty_stat
	data["difficulty_stats"] = all_stats


func _evaluate_difficulty_unlocks(difficulty_id: String, victory: bool) -> Array[String]:
	var unlocked_now: Array[String] = []
	if not victory or not is_difficulty_unlocked(difficulty_id):
		return unlocked_now
	var next_difficulty_id := DifficultyCatalog.next_id(difficulty_id)
	if not next_difficulty_id.is_empty() and unlock_difficulty(next_difficulty_id):
		unlocked_now.append(next_difficulty_id)
	return unlocked_now


func _settlement_event_entries(events: Array) -> Array[Dictionary]:
	var normalized: Array[Dictionary] = []
	var seen := {}
	for event_value in events:
		if not event_value is Dictionary:
			continue
		var event_result: Dictionary = event_value
		var event_id := _event_id_from_result(event_result)
		var outcome := String(event_result.get("outcome", "")).to_lower()
		if event_id not in EventCatalog.ids() or outcome not in ["success", "partial", "failed", "not_started"]:
			continue
		var instance_id := String(event_result.get("instance_id", "%s-%d" % [event_id, normalized.size()]))
		if seen.has(instance_id):
			continue
		seen[instance_id] = true
		var event_definition := EventCatalog.get_by_id(event_id)
		var strategy_id := _strategy_id_from_result(event_result)
		var strategy_definition := _strategy_definition(event_definition, strategy_id)
		normalized.append({
			"instance_id": instance_id,
			"event_id": event_id,
			"title": String(event_result.get("title", event_definition.get("name", event_id))),
			"strategy_id": strategy_id,
			"strategy_name": String(event_result.get("strategy_name", strategy_definition.get("name", strategy_id))),
			"outcome": outcome,
			"outcome_text": String(event_result.get("outcome_text", "")),
		})
	return normalized


func _evaluate_unlocks(result: Dictionary) -> Array[String]:
	var unlocked_now: Array[String] = []
	var build: Dictionary = result.get("build", {})
	var successful_events := _successful_event_ids(result)
	var candidates := {
		"dba": int(build.get("lock_zone", 0)) >= 3 or "backup_restore" in successful_events,
		"network": int(build.get("ping", 0)) >= 3 or "troubleshoot" in successful_events,
		"security": int(build.get("firewall", 0)) >= 3,
		"it_ops": int(build.get("wrench", 0)) >= 3 or "version_update" in successful_events,
		"helpdesk": bool(result.get("ally", false)),
		"opsdev": bool(build.get("iac", false)),
		"sre": bool(result.get("victory", false)) and float(result.get("health_ratio", 0.0)) >= 0.50,
		"delivery": "release" in successful_events,
		"ai_infra": int(build.get("worker", 0)) >= 3,
	}
	for career_id in candidates:
		if bool(candidates[career_id]) and unlock_career(String(career_id)):
			unlocked_now.append(String(career_id))
	return unlocked_now


func _successful_event_ids(result: Dictionary) -> Array[String]:
	var successful: Array[String] = []
	var events: Array = result.get("events", []) if result.get("events", []) is Array else []
	if not events.is_empty():
		for event_value in events:
			if not event_value is Dictionary:
				continue
			var event_result: Dictionary = event_value
			var event_id := _event_id_from_result(event_result)
			if bool(event_result.get("reward_eligible", true)) and event_id in EventCatalog.ids() and String(event_result.get("outcome", "")).to_lower() == "success" and event_id not in successful:
				successful.append(event_id)
	elif bool(result.get("release_success", false)):
		successful.append("release")
	return successful
