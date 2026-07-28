extends SceneTree

const CareerCatalog := preload("res://scripts/career_catalog.gd")
const EventCatalog := preload("res://scripts/event_catalog.gd")
const DifficultyCatalog := preload("res://scripts/difficulty_catalog.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var profile := get_root().get_node("ProfileStore")
	var director := get_root().get_node("AudioDirector")
	profile.reset_for_tests()
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	get_root().add_child(menu)
	_require(menu.content_box != null, "main menu builds its content shell")
	_require(menu.cheat_code_input != null, "home page exposes the cheat-code terminal")
	_require(menu.cheat_code_status != null, "cheat-code feedback is visible")
	_require(profile.is_difficulty_unlocked("normal"), "normal difficulty is unlocked by default")
	_require(not profile.is_difficulty_unlocked("advanced"), "advanced difficulty starts locked")
	_require(not menu.call("_apply_cheat_code", "not-the-code"), "invalid cheat code is rejected")
	_require(_unlocked_career_count(profile) == 1, "invalid cheat code leaves progression unchanged")
	_require(_unlocked_difficulty_count(profile) == 1, "invalid cheat code leaves difficulty progression unchanged")
	menu.call("_show_brief", "ops")
	_require(menu.brief_difficulty_option != null and menu.brief_difficulty_option.item_count == 4, "duty brief offers all four difficulties")
	_require(menu.brief_difficulty_option.is_item_disabled(1), "locked advanced difficulty cannot be selected")
	menu.call("_show_home")
	_require(menu.call("_apply_cheat_code", " yesifu "), "unlock-all cheat code is accepted")
	_require(_unlocked_career_count(profile) == CareerCatalog.ids().size(), "cheat code unlocks every career")
	_require(_unlocked_difficulty_count(profile) == DifficultyCatalog.ids().size(), "cheat code unlocks every difficulty")
	_require(String(menu.cheat_code_status.text).contains("职业与难度"), "successful unlock provides visible feedback")
	_require(menu.call("_apply_cheat_code", "YESIFU"), "re-entering the cheat code remains safe")
	_require(_unlocked_career_count(profile) == CareerCatalog.ids().size(), "repeated cheat code does not duplicate careers")
	_require(_unlocked_difficulty_count(profile) == DifficultyCatalog.ids().size(), "repeated cheat code does not duplicate difficulties")
	_require(menu.content_box.get_global_rect().end.y <= 696.5, "home page cheat terminal fits the 1280x720 content frame")
	profile.discover_fault_kind(0)
	profile.discover_fault_kind(7)
	profile.discover_artifact("rm_rf")
	menu.call("_show_museum", "fault")
	var museum_snapshot: Dictionary = menu.call("get_museum_ui_snapshot")
	_require(int(museum_snapshot.get("category_count", 0)) == 3, "museum exposes fault, boss, and artifact archives")
	_require(String(museum_snapshot.get("category", "")) == "fault" and int(museum_snapshot.get("entry_count", 0)) == 7, "fault archive lists five normal and two elite faults")
	_require(String(menu.museum_entry_buttons["http_404"].text).contains("404"), "encountered fault reveals its archive identity")
	menu.call("_show_museum", "boss")
	_require(int(menu.call("get_museum_ui_snapshot").get("entry_count", 0)) == 1, "boss archive lists the incident core")
	_require(String(menu.museum_entry_buttons["incident_core"].text).contains("FATAL"), "encountered boss reveals its archive identity")
	menu.call("_show_museum", "artifact")
	_require(int(menu.call("get_museum_ui_snapshot").get("entry_count", 0)) == 12, "artifact archive lists the complete catalog")
	_require(String(menu.museum_entry_buttons["rm_rf"].text).contains("RM -RF"), "obtained artifact reveals its effect archive")
	_require(menu.museum_entry_buttons["rm_rf"].icon != null, "artifact archive uses the generated icon")
	var emblem_regions: Array[Rect2] = []
	for career_id in CareerCatalog.ids():
		var emblem: Texture2D = menu.call("_career_emblem_texture", career_id)
		_require(emblem is AtlasTexture, "%s has a generated career emblem" % career_id)
		emblem_regions.append((emblem as AtlasTexture).region)
	_require(emblem_regions.size() == 10, "the emblem atlas covers all careers")
	_require(emblem_regions[0] != emblem_regions[9], "career emblems use distinct atlas cells")
	menu.call("_show_careers")
	_require(menu.selected_detail_box != null, "career archive opens")
	menu.call("_show_brief", "ops")
	await process_frame
	_require(menu.content_box.get_global_rect().end.y <= 696.5, "duty brief fits the 1280x720 content frame")
	_require(not menu.brief_difficulty_option.is_item_disabled(3), "cheat code exposes impossible difficulty in the selector")
	menu.call("_select_difficulty", 3, "ops")
	_require(String(profile.session_difficulty_id) == "impossible", "difficulty selector persists impossible difficulty for the run")
	_require(menu.brief_event_buttons.size() == 4, "duty brief offers all four event contracts")
	for event_id in EventCatalog.ids():
		_require(menu.brief_event_buttons.has(event_id), "%s contract is selectable" % event_id)
	_require(String(menu.selected_event_id) == "release", "release is the compatible default event")
	_require(String(menu.brief_event_name_label.text).contains("线上发布"), "selected event identity is visible")
	_require(String(menu.brief_event_objective_label.text).contains(String(EventCatalog.get_by_id("release")["objective"])), "selected event objective is visible")
	_require(menu.brief_strategy_labels.size() == 3, "duty brief previews all three event strategies")
	_require(String(menu.brief_career_bonus_label.text).begins_with("职业加成"), "career-specific event bonus is visible")
	menu.call("_select_event_contract", "backup_restore", "ops")
	_require(String(menu.selected_event_id) == "backup_restore", "switching a contract updates the duty brief")
	_require(String(menu.brief_event_name_label.text).contains("备份恢复演练"), "switched event details are rendered")
	_require(String(menu.brief_event_objective_label.text).contains(String(EventCatalog.get_by_id("backup_restore")["objective"])), "switched event objective is rendered")
	_require(String(profile.session_event_id) == "backup_restore", "event selection is handed to ProfileStore for the run")
	menu.call("_show_runbook")
	_require(menu.content_box.get_child_count() >= 3, "permanent upgrade store opens")
	menu.call("_show_settings")
	_require(menu.content_box.get_child_count() >= 2, "settings menu opens")
	_require(menu.settings_music_style_option != null and menu.settings_music_style_option.item_count == 7, "settings exposes five imported BGM tracks and both original suites")
	menu.settings_music_style_option.select(1)
	menu.settings_music_style_option.item_selected.emit(1)
	_require(String(profile.get_settings().get("music_style", "")) == "suno_02" and String(director.call("get_music_style")) == "suno_02", "settings persists and immediately auditions BGM02")
	menu.settings_music_style_option.select(2)
	menu.settings_music_style_option.item_selected.emit(2)
	_require(String(profile.get_settings().get("music_style", "")) == "maximum_breach" and String(director.call("get_music_style")) == "maximum_breach", "settings persists and immediately auditions a newly imported BGM")
	menu.settings_music_style_option.select(0)
	menu.settings_music_style_option.item_selected.emit(0)
	_require(String(profile.get_settings().get("music_style", "")) == "suno_01" and String(director.call("get_music_style")) == "suno_01", "settings can restore BGM01 as the default")
	get_root().remove_child(menu)
	menu.free()

	profile.select_difficulty("normal")
	var run: Node = load("res://scenes/run.tscn").instantiate()
	get_root().add_child(run)
	run.call("_pause_run")
	_require(paused, "run menu pauses the simulation")
	_require(String(run.get_node("HUD").modal_mode) == "pause", "pause menu is visible")
	run.call("_resume_run")
	_require(not paused, "resume returns to the simulation")
	_require(String(run.get_node("HUD").modal_mode).is_empty(), "pause overlay closes")
	get_root().remove_child(run)
	run.free()
	print("MENU_FLOW_TEST_PASS tabs=5 museum=ok pause=ok")
	quit(0)


func _unlocked_career_count(profile: Node) -> int:
	var count := 0
	for career_id in CareerCatalog.ids():
		if profile.is_career_unlocked(career_id):
			count += 1
	return count


func _unlocked_difficulty_count(profile: Node) -> int:
	var count := 0
	for difficulty_id in DifficultyCatalog.ids():
		if profile.is_difficulty_unlocked(difficulty_id):
			count += 1
	return count


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("MENU_FLOW_TEST_FAIL: " + message)
	paused = false
	quit(1)
