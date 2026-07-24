extends Control

const CareerCatalog := preload("res://scripts/career_catalog.gd")
const ActionCatalog := preload("res://scripts/career_action_catalog.gd")
const EventCatalog := preload("res://scripts/event_catalog.gd")
const DifficultyCatalog := preload("res://scripts/difficulty_catalog.gd")
const ArtifactCatalog := preload("res://scripts/artifact_catalog.gd")
const FaultCatalog := preload("res://scripts/fault_catalog.gd")
const GENERATED_BACKGROUND := "res://assets/generated/ui_menu_war_room.png"
const UNLOCK_ALL_CHEAT_CODE := "yesifu"

var content_box: VBoxContainer
var points_label: Label
var current_career_label: Label
var selected_career_id := "ops"
var selected_event_id := "release"
var selected_detail_box: VBoxContainer
var first_focus: Control
var brief_event_buttons: Dictionary = {}
var brief_event_name_label: Label
var brief_event_objective_label: Label
var brief_career_bonus_label: Label
var brief_strategy_labels: Array[Label] = []
var brief_difficulty_option: OptionButton
var cheat_code_input: LineEdit
var cheat_code_status: Label
var settings_music_style_option: OptionButton
var museum_category := "fault"
var museum_detail_box: VBoxContainer
var museum_entry_buttons: Dictionary = {}
var museum_category_buttons: Dictionary = {}


func _ready() -> void:
	get_tree().paused = false
	AudioDirector.enter_menu()
	selected_career_id = String(ProfileStore.session_career_id)
	selected_event_id = _get_session_event_id()
	_build_shell()
	ProfileStore.profile_changed.connect(_refresh_header)
	match ProfileStore.requested_menu_tab:
		"careers": _show_careers()
		"runbook": _show_runbook()
		"museum": _show_museum()
		"settings": _show_settings()
		_: _show_home()
	ProfileStore.requested_menu_tab = "home"


func _build_shell() -> void:
	var high_contrast := bool(ProfileStore.get_settings().get("high_contrast", false))
	var background := ColorRect.new()
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("07131e")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(GENERATED_BACKGROUND):
		var art := TextureRect.new()
		add_child(art)
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.texture = load(GENERATED_BACKGROUND)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.modulate = Color(0.76, 0.84, 0.92, 0.34 if high_contrast else 0.62)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shade := ColorRect.new()
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.025, 0.045, 0.68 if high_contrast else 0.42)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var header := PanelContainer.new()
	add_child(header)
	header.position = Vector2(24, 18)
	header.custom_minimum_size = Vector2(1232, 62)
	header.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.075, 0.105, 0.98 if high_contrast else 0.88), Color("73fff0") if high_contrast else Color("2fcfc1")))
	var header_margin := MarginContainer.new()
	header.add_child(header_margin)
	header_margin.add_theme_constant_override("margin_left", 18)
	header_margin.add_theme_constant_override("margin_right", 18)
	header_margin.add_theme_constant_override("margin_top", 10)
	header_margin.add_theme_constant_override("margin_bottom", 10)
	var header_row := HBoxContainer.new()
	header_margin.add_child(header_row)
	var title := _label("iT-BATTLE  /  值班幸存者", 25, Color("75f3df"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title)
	points_label = _label("", 17, Color("ffd36a"))
	header_row.add_child(points_label)
	_refresh_header()

	var nav_panel := PanelContainer.new()
	add_child(nav_panel)
	nav_panel.position = Vector2(24, 92)
	nav_panel.custom_minimum_size = Vector2(264, 604)
	nav_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.065, 0.095, 0.98 if high_contrast else 0.90), Color("6b9dad") if high_contrast else Color("28596a")))
	var nav_margin := MarginContainer.new()
	nav_panel.add_child(nav_margin)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		nav_margin.add_theme_constant_override(side, 16)
	var nav := VBoxContainer.new()
	nav_margin.add_child(nav)
	nav.add_theme_constant_override("separation", 10)
	var shift := _label("NOC · NIGHT SHIFT", 14, Color("698e9e"))
	nav.add_child(shift)
	var current := CareerCatalog.get_by_id(ProfileStore.session_career_id)
	current_career_label = _label("当前岗位\n%s" % current["name"], 20, Color(String(current["color"])))
	current_career_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	current_career_label.custom_minimum_size = Vector2(220, 62)
	nav.add_child(current_career_label)
	nav.add_child(HSeparator.new())
	var home_button := _nav_button("值班大厅", _show_home)
	nav.add_child(home_button)
	nav.add_child(_nav_button("职业档案", _show_careers))
	nav.add_child(_nav_button("能力基线", _show_runbook))
	nav.add_child(_nav_button("故障博物馆", _show_museum))
	nav.add_child(_nav_button("设置与操作", _show_settings))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nav.add_child(spacer)
	var stats := ProfileStore.get_stats()
	var lifetime := _label("累计值班 %d\n恢复验证 %d\n关闭故障 %d\n岗位协议 %d" % [int(stats.get("runs", 0)), int(stats.get("wins", 0)), int(stats.get("closed", 0)), int(stats.get("protocols", 0))], 13, Color("7897a5"))
	nav.add_child(lifetime)
	var exit_button := _nav_button("退出系统", func() -> void: get_tree().quit())
	nav.add_child(exit_button)
	first_focus = home_button

	var content_panel := PanelContainer.new()
	add_child(content_panel)
	content_panel.position = Vector2(304, 92)
	content_panel.custom_minimum_size = Vector2(952, 604)
	content_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.065, 0.095, 0.98 if high_contrast else 0.90), Color("6b9dad") if high_contrast else Color("28596a")))
	var content_margin := MarginContainer.new()
	content_panel.add_child(content_margin)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		content_margin.add_theme_constant_override(side, 24)
	content_box = VBoxContainer.new()
	content_margin.add_child(content_box)
	content_box.add_theme_constant_override("separation", 12)


func _show_home() -> void:
	_clear_content()
	var career := CareerCatalog.get_by_id(ProfileStore.session_career_id)
	var difficulty := DifficultyCatalog.get_by_id(ProfileStore.session_difficulty_id)
	content_box.add_child(_section_title("值班大厅", "选择岗位、确认能力基线，然后进入生产环境"))
	var hero := PanelContainer.new()
	hero.custom_minimum_size = Vector2(890, 250)
	hero.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.11, 0.14, 0.92), Color(String(career["color"]))))
	content_box.add_child(hero)
	var hero_margin := MarginContainer.new()
	hero.add_child(hero_margin)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		hero_margin.add_theme_constant_override(side, 22)
	var hero_row := HBoxContainer.new()
	hero_margin.add_child(hero_row)
	hero_row.add_theme_constant_override("separation", 24)
	var badge := _career_badge(career, Vector2(190, 190))
	hero_row.add_child(badge)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 9)
	hero_row.add_child(details)
	details.add_child(_label("%s  /  %s" % [career["badge"], career["name"]], 28, Color(String(career["color"]))))
	details.add_child(_label(String(career["domain"]), 15, Color("8fb6c5")))
	var desc := _label(String(career["description"]), 16, Color("d6e4e8"))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(610, 54)
	details.add_child(desc)
	details.add_child(_label(String(career["passive"]), 15, Color("ffd36a")))
	var rank := ProfileStore.get_mastery_rank(String(career["id"]))
	details.add_child(_label("职业履历  %d  ·  %s" % [int(rank["score"]), String(rank["title"])], 14, Color("70caff")))

	var start_button := Button.new()
	start_button.text = "开始值班  ·  %s难度  ·  生产环境 06:00" % difficulty["name"]
	start_button.custom_minimum_size = Vector2(890, 68)
	start_button.add_theme_font_size_override("font_size", 22)
	start_button.pressed.connect(_show_brief.bind(String(career["id"])))
	content_box.add_child(start_button)
	var shortcuts := HBoxContainer.new()
	shortcuts.alignment = BoxContainer.ALIGNMENT_CENTER
	shortcuts.add_theme_constant_override("separation", 12)
	content_box.add_child(shortcuts)
	var career_button := Button.new()
	career_button.text = "更换职业"
	career_button.custom_minimum_size = Vector2(270, 46)
	career_button.pressed.connect(_show_careers)
	shortcuts.add_child(career_button)
	var runbook_button := Button.new()
	runbook_button.text = "配置能力基线"
	runbook_button.custom_minimum_size = Vector2(270, 46)
	runbook_button.pressed.connect(_show_runbook)
	shortcuts.add_child(runbook_button)

	var cheat_panel := PanelContainer.new()
	cheat_panel.custom_minimum_size = Vector2(890, 64)
	cheat_panel.add_theme_stylebox_override("panel", _panel_style(Color("081923"), Color("28596a")))
	content_box.add_child(cheat_panel)
	var cheat_margin := MarginContainer.new()
	cheat_panel.add_child(cheat_margin)
	cheat_margin.add_theme_constant_override("margin_left", 14)
	cheat_margin.add_theme_constant_override("margin_right", 14)
	cheat_margin.add_theme_constant_override("margin_top", 9)
	cheat_margin.add_theme_constant_override("margin_bottom", 9)
	var cheat_row := HBoxContainer.new()
	cheat_row.add_theme_constant_override("separation", 10)
	cheat_margin.add_child(cheat_row)
	var cheat_label := _label("维护终端", 14, Color("70caff"))
	cheat_label.custom_minimum_size = Vector2(76, 40)
	cheat_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cheat_row.add_child(cheat_label)
	cheat_code_input = LineEdit.new()
	cheat_code_input.placeholder_text = "输入作弊码，按回车执行"
	cheat_code_input.custom_minimum_size = Vector2(260, 40)
	cheat_code_input.max_length = 32
	cheat_code_input.text_submitted.connect(_apply_cheat_code)
	cheat_row.add_child(cheat_code_input)
	var cheat_submit := Button.new()
	cheat_submit.text = "执行"
	cheat_submit.custom_minimum_size = Vector2(86, 40)
	cheat_submit.pressed.connect(_submit_cheat_code)
	cheat_row.add_child(cheat_submit)
	cheat_code_status = _label("权限验证待命", 13, Color("7897a5"))
	cheat_code_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cheat_code_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cheat_row.add_child(cheat_code_status)
	start_button.grab_focus()


func _submit_cheat_code() -> void:
	if cheat_code_input != null:
		_apply_cheat_code(cheat_code_input.text)


func _apply_cheat_code(raw_code: String) -> bool:
	if raw_code.strip_edges().to_lower() != UNLOCK_ALL_CHEAT_CODE:
		if cheat_code_status != null:
			cheat_code_status.text = "访问码无效"
			cheat_code_status.add_theme_color_override("font_color", Color("ff6b72"))
		if cheat_code_input != null:
			cheat_code_input.select_all()
		return false
	var newly_unlocked: Dictionary = ProfileStore.unlock_all_progression()
	if cheat_code_input != null:
		cheat_code_input.clear()
	if cheat_code_status != null:
		if int(newly_unlocked.get("careers", 0)) + int(newly_unlocked.get("difficulties", 0)) > 0:
			cheat_code_status.text = "ACCESS GRANTED · 已解锁全部职业与难度"
		else:
			cheat_code_status.text = "ACCESS GRANTED · 全职业与难度已解锁"
		cheat_code_status.add_theme_color_override("font_color", Color("65e890"))
	return true


func _show_careers() -> void:
	_clear_content()
	content_box.add_child(_section_title("职业档案", "职业横向解锁；锁定卡会公开显示履历条件"))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.custom_minimum_size = Vector2(900, 500)
	content_box.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(590, 500)
	body.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	var focus_button: Button
	for career in CareerCatalog.all():
		var unlocked := ProfileStore.is_career_unlocked(String(career["id"]))
		var button := Button.new()
		button.custom_minimum_size = Vector2(280, 108)
		button.text = "%s  %s\n%s\n%s" % [career["badge"], career["name"], career["domain"], "已解锁" if unlocked else "LOCKED · " + String(career["unlock"])]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.icon = CareerCatalog.sprite_texture(String(career["id"]))
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 68)
		button.add_theme_constant_override("h_separation", 8)
		if not unlocked:
			button.add_theme_color_override("icon_normal_color", Color(0.58, 0.64, 0.68, 0.62))
		button.add_theme_font_size_override("font_size", 13)
		button.add_theme_stylebox_override("normal", _panel_style(Color("0d1c28"), Color(String(career["color"])).darkened(0.25)))
		button.add_theme_stylebox_override("focus", _panel_style(Color("17303d"), Color(String(career["color"]))))
		button.pressed.connect(_show_career_detail.bind(String(career["id"])))
		grid.add_child(button)
		if focus_button == null or String(career["id"]) == selected_career_id:
			focus_button = button
	selected_detail_box = VBoxContainer.new()
	selected_detail_box.custom_minimum_size = Vector2(290, 500)
	selected_detail_box.add_theme_constant_override("separation", 8)
	body.add_child(selected_detail_box)
	_show_career_detail(selected_career_id)
	if focus_button != null:
		focus_button.grab_focus()


func _show_career_detail(career_id: String) -> void:
	selected_career_id = career_id
	if selected_detail_box == null:
		return
	for child in selected_detail_box.get_children():
		selected_detail_box.remove_child(child)
		child.queue_free()
	var career := CareerCatalog.get_by_id(career_id)
	var action_kit := ActionCatalog.get_by_id(career_id)
	var unlocked := ProfileStore.is_career_unlocked(career_id)
	selected_detail_box.add_child(_career_badge(career, Vector2(290, 132)))
	selected_detail_box.add_child(_label(String(career["name"]), 24, Color(String(career["color"]))))
	var description := _label(String(career["description"]), 14, Color("d3e2e7"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(290, 62)
	selected_detail_box.add_child(description)
	var mechanic := _label("固有 · %s\nQ / X · %s  CD %.0fs\nR / Y · %s  CD %.0fs" % [
		action_kit["signature"]["name"], action_kit["skill"]["name"], float(action_kit["skill"]["cooldown"]),
		action_kit["ultimate"]["name"], float(action_kit["ultimate"]["cooldown"]),
	], 13, Color("8fb6c5"))
	mechanic.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mechanic.custom_minimum_size = Vector2(290, 72)
	selected_detail_box.add_child(mechanic)
	var passive := _label(String(career["passive"]), 13, Color("ffd36a"))
	passive.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selected_detail_box.add_child(passive)
	var mastery_rank := ProfileStore.get_mastery_rank(career_id)
	var state_text := "职业履历  %d  ·  %s" % [int(mastery_rank["score"]), String(mastery_rank["title"])] if unlocked else "解锁条件\n%s" % career["unlock"]
	var state := _label(state_text, 13, Color("70caff") if unlocked else Color("ff9b72"))
	state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	state.custom_minimum_size = Vector2(290, 48)
	selected_detail_box.add_child(state)
	var action := Button.new()
	action.custom_minimum_size = Vector2(290, 48)
	action.text = "选择并查看值班简报" if unlocked else "尚未满足职业履历"
	action.disabled = not unlocked
	action.pressed.connect(_select_and_brief.bind(career_id))
	selected_detail_box.add_child(action)


func _select_and_brief(career_id: String) -> void:
	if ProfileStore.select_career(career_id):
		_show_brief(career_id)


func _show_brief(career_id: String, focus_event_id: String = "") -> void:
	if not ProfileStore.is_career_unlocked(career_id):
		return
	ProfileStore.select_career(career_id)
	_clear_content()
	var career := CareerCatalog.get_by_id(career_id)
	var action_kit := ActionCatalog.get_by_id(career_id)
	selected_event_id = _get_session_event_id()
	var selected_event := EventCatalog.get_by_id(selected_event_id)
	var selected_difficulty := DifficultyCatalog.get_by_id(ProfileStore.session_difficulty_id)
	content_box.add_child(_section_title("值班简报", "%s · %s难度 · 预计 06:00 · 选择本班次事件合同" % [career["name"], selected_difficulty["name"]]))

	brief_event_buttons.clear()
	brief_strategy_labels.clear()
	var contract_row := HBoxContainer.new()
	contract_row.alignment = BoxContainer.ALIGNMENT_CENTER
	contract_row.add_theme_constant_override("separation", 9)
	contract_row.custom_minimum_size = Vector2(890, 52)
	content_box.add_child(contract_row)
	for event_contract in EventCatalog.all():
		var event_id := String(event_contract["id"])
		var selected := event_id == selected_event_id
		var event_color := Color(String(event_contract["color"]))
		var contract_button := Button.new()
		contract_button.custom_minimum_size = Vector2(214, 52)
		contract_button.text = "%s  %s · %s\n%s" % ["●" if selected else "○", event_contract["badge"], event_contract["name"], event_contract["category"]]
		contract_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		contract_button.add_theme_font_size_override("font_size", 12)
		contract_button.add_theme_stylebox_override("normal", _panel_style(Color("162936") if selected else Color("0b1822"), event_color if selected else event_color.darkened(0.45)))
		contract_button.add_theme_stylebox_override("hover", _panel_style(Color("17303d"), event_color))
		contract_button.add_theme_stylebox_override("focus", _panel_style(Color("17303d"), event_color))
		contract_button.set_meta("event_id", event_id)
		contract_button.pressed.connect(_select_event_contract.bind(event_id, career_id))
		contract_row.add_child(contract_button)
		brief_event_buttons[event_id] = contract_button

	var briefing := PanelContainer.new()
	briefing.custom_minimum_size = Vector2(890, 326)
	briefing.add_theme_stylebox_override("panel", _panel_style(Color("0d202d"), Color(String(selected_event["color"]))))
	content_box.add_child(briefing)
	var margin := MarginContainer.new()
	briefing.add_child(margin)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 16)
	var briefing_columns := HBoxContainer.new()
	margin.add_child(briefing_columns)
	briefing_columns.add_theme_constant_override("separation", 18)

	var career_box := VBoxContainer.new()
	career_box.custom_minimum_size = Vector2(300, 286)
	career_box.add_theme_constant_override("separation", 7)
	briefing_columns.add_child(career_box)
	career_box.add_child(_label("当前职业  ·  %s  %s" % [career["badge"], career["name"]], 19, Color(String(career["color"]))))
	var starting_names: Array[String] = []
	for upgrade_id in career["starting_upgrades"]:
		starting_names.append(_upgrade_display_name(String(upgrade_id)))
	career_box.add_child(_label("固有攻击 · %s" % action_kit["signature"]["name"], 13, Color("d6e5e9")))
	var action_brief := _label("Q / X  %s  %.0fs\nR / Y  %s  %.0fs" % [action_kit["skill"]["name"], float(action_kit["skill"]["cooldown"]), action_kit["ultimate"]["name"], float(action_kit["ultimate"]["cooldown"])], 12, Color(String(career["color"])))
	action_brief.custom_minimum_size = Vector2(300, 38)
	career_box.add_child(action_brief)
	if not starting_names.is_empty():
		career_box.add_child(_label("起始方法论 · %s" % " + ".join(starting_names), 12, Color("9db6c0")))
	var passive := _label(String(career["passive"]), 13, Color("ffd36a"))
	passive.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	passive.custom_minimum_size = Vector2(300, 44)
	career_box.add_child(passive)
	career_box.add_child(HSeparator.new())
	brief_event_name_label = _label("%s  /  %s" % [selected_event["badge"], selected_event["name"]], 20, Color(String(selected_event["color"])))
	career_box.add_child(brief_event_name_label)
	var event_description := _label(String(selected_event["description"]), 13, Color("bcd0d7"))
	event_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_description.custom_minimum_size = Vector2(300, 58)
	career_box.add_child(event_description)
	career_box.add_child(_label("成功 +%d RP  ·  部分成功 +%d RP" % [int(selected_event["success_reward"]), int(selected_event["partial_reward"])], 13, Color("8fc9ff")))

	var event_box := VBoxContainer.new()
	event_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_box.custom_minimum_size = Vector2(540, 286)
	event_box.add_theme_constant_override("separation", 5)
	briefing_columns.add_child(event_box)
	event_box.add_child(_label("本班次目标", 17, Color("75f3df")))
	brief_event_objective_label = _label("▸ %s" % selected_event["objective"], 14, Color("d6e5e9"))
	brief_event_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brief_event_objective_label.custom_minimum_size = Vector2(540, 32)
	event_box.add_child(brief_event_objective_label)
	event_box.add_child(HSeparator.new())
	event_box.add_child(_label("三策略概览  ·  入场后择一执行", 15, Color("dbe9ec")))
	for strategy in selected_event.get("strategies", []):
		var strategy_text := _label("%s  ·  %s" % [strategy["name"], strategy["detail"]], 12, Color("a9c1cb"))
		strategy_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		strategy_text.custom_minimum_size = Vector2(540, 35)
		event_box.add_child(strategy_text)
		brief_strategy_labels.append(strategy_text)
	event_box.add_child(HSeparator.new())
	brief_career_bonus_label = _label("职业加成  ·  %s" % EventCatalog.bonus_for(selected_event_id, career_id), 13, Color(String(career["color"])))
	brief_career_bonus_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brief_career_bonus_label.custom_minimum_size = Vector2(540, 35)
	event_box.add_child(brief_career_bonus_label)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 14)
	content_box.add_child(actions)
	var back := Button.new()
	back.text = "返回职业档案"
	back.custom_minimum_size = Vector2(190, 50)
	back.pressed.connect(_show_careers)
	actions.add_child(back)
	brief_difficulty_option = OptionButton.new()
	brief_difficulty_option.custom_minimum_size = Vector2(250, 50)
	brief_difficulty_option.add_theme_font_size_override("font_size", 15)
	for difficulty in DifficultyCatalog.all():
		var difficulty_id := String(difficulty["id"])
		var unlocked := ProfileStore.is_difficulty_unlocked(difficulty_id)
		var item_index := brief_difficulty_option.item_count
		var item_text := "难度 · %s  /  %s" % [difficulty["name"], difficulty["badge"]] if unlocked else "LOCKED · %s · %s" % [difficulty["name"], difficulty["unlock"]]
		brief_difficulty_option.add_item(item_text)
		brief_difficulty_option.set_item_metadata(item_index, difficulty_id)
		brief_difficulty_option.set_item_disabled(item_index, not unlocked)
		brief_difficulty_option.set_item_tooltip(item_index, "%s\n%s\n胜利 RP ×%.2f" % [difficulty["description"], DifficultyCatalog.pressure_summary(difficulty_id), float(difficulty["reward_multiplier"])])
		if difficulty_id == ProfileStore.session_difficulty_id:
			brief_difficulty_option.select(item_index)
	brief_difficulty_option.add_theme_color_override("font_color", Color(String(selected_difficulty["color"])))
	brief_difficulty_option.item_selected.connect(_select_difficulty.bind(career_id))
	actions.add_child(brief_difficulty_option)
	var deploy := Button.new()
	deploy.text = "确认 %s · %s难度" % [selected_event["name"], selected_difficulty["name"]]
	deploy.custom_minimum_size = Vector2(340, 54)
	deploy.add_theme_font_size_override("font_size", 18)
	deploy.pressed.connect(_start_run)
	actions.add_child(deploy)
	if not focus_event_id.is_empty() and brief_event_buttons.has(focus_event_id):
		(brief_event_buttons[focus_event_id] as Button).grab_focus()
	else:
		deploy.grab_focus()


func _select_event_contract(event_id: String, career_id: String) -> void:
	if event_id not in EventCatalog.ids():
		return
	if not ProfileStore.select_event(event_id):
		return
	selected_event_id = event_id
	_show_brief(career_id, event_id)


func _select_difficulty(item_index: int, career_id: String) -> void:
	if brief_difficulty_option == null or item_index < 0 or item_index >= brief_difficulty_option.item_count:
		return
	var difficulty_id := String(brief_difficulty_option.get_item_metadata(item_index))
	if ProfileStore.select_difficulty(difficulty_id):
		_show_brief(career_id)


func _get_session_event_id() -> String:
	var event_id := String(ProfileStore.session_event_id)
	if event_id not in EventCatalog.ids():
		return "release"
	return event_id


func _show_runbook() -> void:
	_clear_content()
	content_box.add_child(_section_title("能力基线", "使用复盘点强化账号容错；职业解锁不消耗 RP"))
	var balance := _label("可用复盘点  %d RP" % ProfileStore.get_points(), 22, Color("ffd36a"))
	content_box.add_child(balance)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	content_box.add_child(grid)
	var levels := ProfileStore.get_permanent_upgrades()
	var focus_button: Button
	for definition in ProfileStore.upgrade_definitions():
		var upgrade_id := String(definition["id"])
		var current := int(levels.get(upgrade_id, 0))
		var maximum := int(definition["max"])
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(432, 180)
		card.add_theme_stylebox_override("panel", _panel_style(Color("0d1c28"), Color(String(definition["color"]))))
		grid.add_child(card)
		var margin := MarginContainer.new()
		card.add_child(margin)
		for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
			margin.add_theme_constant_override(side, 16)
		var box := VBoxContainer.new()
		margin.add_child(box)
		box.add_theme_constant_override("separation", 7)
		box.add_child(_label("%s  Lv.%d / %d" % [definition["name"], current, maximum], 19, Color(String(definition["color"]))))
		box.add_child(_label(String(definition["description"]), 14, Color("c9d8de")))
		var purchase := Button.new()
		var cost := ProfileStore.get_upgrade_cost(upgrade_id)
		purchase.text = "已达上限" if current >= maximum else "投入 %d RP" % cost
		purchase.disabled = current >= maximum or ProfileStore.get_points() < cost
		purchase.pressed.connect(_purchase_upgrade.bind(upgrade_id))
		box.add_child(purchase)
		if focus_button == null and not purchase.disabled:
			focus_button = purchase
	var note := _label("能力基线只提供约 10% 的长期容错，局内流派与走位仍决定主要强度。", 13, Color("7897a5"))
	content_box.add_child(note)
	if focus_button != null:
		focus_button.grab_focus()


func _purchase_upgrade(upgrade_id: String) -> void:
	if ProfileStore.purchase_upgrade(upgrade_id):
		_show_runbook()


func _show_museum(category: String = "") -> void:
	if not category.is_empty():
		museum_category = category
	if museum_category not in ["fault", "boss", "artifact"]:
		museum_category = "fault"
	_clear_content()
	var unlocks := ProfileStore.get_museum_unlocks()
	var total_unlocked := Array(unlocks.get("fault", [])).size() + Array(unlocks.get("boss", [])).size() + Array(unlocks.get("artifact", [])).size()
	var total_entries := FaultCatalog.ids().size() + ArtifactCatalog.ids().size()
	content_box.add_child(_section_title("故障博物馆", "遇见故障或 Boss、获得神器后永久解锁 · 已归档 %d / %d" % [total_unlocked, total_entries]))
	museum_category_buttons.clear()
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 10)
	content_box.add_child(tabs)
	for category_id in ["fault", "boss", "artifact"]:
		var entries := _museum_entries(category_id)
		var unlocked_count := Array(unlocks.get(category_id, [])).size()
		var tab := Button.new()
		tab.custom_minimum_size = Vector2(210, 42)
		tab.text = "%s  %d / %d" % [_museum_category_title(category_id), unlocked_count, entries.size()]
		var tab_color := Color("75f3df") if category_id == museum_category else Color("456878")
		tab.add_theme_stylebox_override("normal", _panel_style(Color("17303d") if category_id == museum_category else Color("0b1822"), tab_color))
		tab.add_theme_stylebox_override("hover", _panel_style(Color("17303d"), Color("75f3df")))
		tab.pressed.connect(_show_museum.bind(category_id))
		tabs.add_child(tab)
		museum_category_buttons[category_id] = tab

	var body := HBoxContainer.new()
	body.custom_minimum_size = Vector2(900, 424)
	body.add_theme_constant_override("separation", 14)
	content_box.add_child(body)
	var archive_scroll := ScrollContainer.new()
	archive_scroll.custom_minimum_size = Vector2(590, 424)
	body.add_child(archive_scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	archive_scroll.add_child(grid)
	museum_entry_buttons.clear()
	var first_entry_id := ""
	var first_unlocked_id := ""
	for definition in _museum_entries(museum_category):
		var entry_id := String(definition.get("id", ""))
		var unlocked := ProfileStore.is_museum_unlocked(museum_category, entry_id)
		if first_entry_id.is_empty():
			first_entry_id = entry_id
		if unlocked and first_unlocked_id.is_empty():
			first_unlocked_id = entry_id
		var button := Button.new()
		button.custom_minimum_size = Vector2(184, 108)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.icon = _museum_entry_texture(museum_category, entry_id)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 66)
		button.add_theme_constant_override("h_separation", 7)
		button.add_theme_font_size_override("font_size", 12)
		if unlocked:
			button.text = "%s\n%s\n已归档" % [definition.get("badge", "◆"), definition.get("name", entry_id)]
			button.add_theme_stylebox_override("normal", _panel_style(Color("0d1c28"), Color(String(definition.get("color", "75f3df"))).darkened(0.30)))
			button.add_theme_stylebox_override("focus", _panel_style(Color("17303d"), Color(String(definition.get("color", "75f3df")))))
		else:
			button.text = "LOCKED\n未识别记录\n等待遭遇"
			button.add_theme_color_override("icon_normal_color", Color(0.16, 0.20, 0.23, 0.72))
			button.add_theme_color_override("font_color", Color("657984"))
			button.add_theme_stylebox_override("normal", _panel_style(Color("08131b"), Color("263d48")))
		button.pressed.connect(_show_museum_detail.bind(museum_category, entry_id))
		grid.add_child(button)
		museum_entry_buttons[entry_id] = button

	var detail_scroll := ScrollContainer.new()
	detail_scroll.custom_minimum_size = Vector2(296, 424)
	body.add_child(detail_scroll)
	museum_detail_box = VBoxContainer.new()
	museum_detail_box.custom_minimum_size = Vector2(278, 410)
	museum_detail_box.add_theme_constant_override("separation", 8)
	detail_scroll.add_child(museum_detail_box)
	var initial_entry := first_unlocked_id if not first_unlocked_id.is_empty() else first_entry_id
	_show_museum_detail(museum_category, initial_entry)
	if museum_entry_buttons.has(initial_entry):
		museum_entry_buttons[initial_entry].grab_focus()


func _show_museum_detail(category: String, entry_id: String) -> void:
	if museum_detail_box == null:
		return
	for child in museum_detail_box.get_children():
		museum_detail_box.remove_child(child)
		child.queue_free()
	var definition := _museum_definition(category, entry_id)
	if definition.is_empty():
		return
	var unlocked := ProfileStore.is_museum_unlocked(category, entry_id)
	var accent := Color(String(definition.get("color", "75f3df")))
	var art_panel := PanelContainer.new()
	art_panel.custom_minimum_size = Vector2(278, 208)
	art_panel.add_theme_stylebox_override("panel", _panel_style(Color("07131e"), accent if unlocked else Color("304852")))
	museum_detail_box.add_child(art_panel)
	var art := TextureRect.new()
	art_panel.add_child(art)
	art.texture = _museum_entry_texture(category, entry_id)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.modulate = Color.WHITE if unlocked else Color(0.10, 0.13, 0.15, 0.78)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not unlocked:
		museum_detail_box.add_child(_label("未识别档案", 23, Color("718b96")))
		var lock_hint := "在值班中遭遇该目标后解锁完整记录。" if category != "artifact" else "在值班中拾取并安装该神器后解锁完整记录。"
		var locked_label := _label(lock_hint, 14, Color("7897a5"))
		locked_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		locked_label.custom_minimum_size = Vector2(278, 64)
		museum_detail_box.add_child(locked_label)
		return
	museum_detail_box.add_child(_label(String(definition.get("name", entry_id)), 22, accent.lightened(0.18)))
	var tier_text := String(definition.get("tier", "神器协议" if category == "artifact" else _museum_category_title(category)))
	museum_detail_box.add_child(_label("%s  ·  %s" % [definition.get("badge", "◆"), tier_text], 13, Color("8fb6c5")))
	var description := _label(String(definition.get("description", "")), 14, Color("d3e2e7"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(278, 62)
	museum_detail_box.add_child(description)
	var effect_text := String(definition.get("effect", definition.get("description", "")))
	var effect := _label("效果 / 行为\n%s" % effect_text, 13, Color("ffd36a") if category == "artifact" else Color("70caff"))
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect.custom_minimum_size = Vector2(278, 72)
	museum_detail_box.add_child(effect)


func _museum_entries(category: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if category == "artifact":
		return ArtifactCatalog.all()
	for definition in FaultCatalog.all():
		if String(definition.get("category", "fault")) == category:
			result.append(definition)
	return result


func _museum_definition(category: String, entry_id: String) -> Dictionary:
	return ArtifactCatalog.get_by_id(entry_id) if category == "artifact" else FaultCatalog.get_by_id(entry_id)


func _museum_entry_texture(category: String, entry_id: String) -> Texture2D:
	return ArtifactCatalog.icon_texture(entry_id) if category == "artifact" else FaultCatalog.sprite_texture(entry_id)


func _museum_category_title(category: String) -> String:
	match category:
		"fault": return "小怪与精英"
		"boss": return "Boss"
		"artifact": return "神器"
	return "档案"


func get_museum_ui_snapshot() -> Dictionary:
	return {
		"category": museum_category,
		"entry_count": museum_entry_buttons.size(),
		"category_count": museum_category_buttons.size(),
		"detail_visible": museum_detail_box != null,
	}


func _show_settings() -> void:
	_clear_content()
	content_box.add_child(_section_title("设置与操作", "跨平台输入与可读性选项"))
	var settings := ProfileStore.get_settings()
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(890, 500)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("0d1c28"), Color("5a8798")))
	content_box.add_child(panel)
	var margin := MarginContainer.new()
	panel.add_child(margin)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 22)
	var box := VBoxContainer.new()
	margin.add_child(box)
	box.add_theme_constant_override("separation", 9)
	var master_volume := _add_volume_slider(box, "主音量", "master_volume", float(settings.get("master_volume", 0.85)), Color("d8e6e9"))
	_add_volume_slider(box, "背景音乐", "music_volume", float(settings.get("music_volume", 0.76)), Color("70caff"))
	_add_volume_slider(box, "战斗与界面音效", "sfx_volume", float(settings.get("sfx_volume", 0.86)), Color("ffd36a"))
	var music_style_title := _label("BGM 曲风", 15, Color("77e6df"))
	box.add_child(music_style_title)
	settings_music_style_option = OptionButton.new()
	settings_music_style_option.custom_minimum_size = Vector2(700, 38)
	var selected_style := String(settings.get("music_style", "pulse"))
	var selected_index := 0
	for definition in AudioDirector.get_music_style_definitions():
		var style_id := String(definition.get("id", "pulse"))
		settings_music_style_option.add_item(String(definition.get("name", style_id)))
		var item_index := settings_music_style_option.item_count - 1
		settings_music_style_option.set_item_metadata(item_index, style_id)
		settings_music_style_option.set_item_tooltip(item_index, String(definition.get("description", "")))
		if style_id == selected_style:
			selected_index = item_index
	settings_music_style_option.select(selected_index)
	settings_music_style_option.item_selected.connect(func(index: int) -> void:
		var style_id := String(settings_music_style_option.get_item_metadata(index))
		ProfileStore.set_setting("music_style", style_id)
	)
	box.add_child(settings_music_style_option)
	var music_style_hint := _label("切换后立即以当前场景试听；战斗、事件、Boss 与恢复验证都会同步换曲。", 12, Color("89a8b4"))
	box.add_child(music_style_hint)
	var labels := CheckBox.new()
	labels.text = "显示故障标签（404 / 502 / OOM 等）"
	labels.button_pressed = bool(settings.get("fault_labels", true))
	labels.toggled.connect(func(value: bool) -> void: ProfileStore.set_setting("fault_labels", value))
	box.add_child(labels)
	var contrast := CheckBox.new()
	contrast.text = "高对比度 UI（切换场景后生效）"
	contrast.button_pressed = bool(settings.get("high_contrast", false))
	contrast.toggled.connect(func(value: bool) -> void: ProfileStore.set_setting("high_contrast", value))
	box.add_child(contrast)
	box.add_child(HSeparator.new())
	var controls := _label("移动：WASD / 方向键 / 左摇杆\n职业小技能：Q 或 Space / 手柄 X\n职业大招：R / 手柄 Y\n协作对齐：E / 手柄 A\n升级选择：鼠标 / 键盘焦点 / 手柄\n开发快捷键：U 升级 · P 事件 · O 精英 · B Boss · T +30秒", 15, Color("9db6c0"))
	controls.custom_minimum_size = Vector2(780, 110)
	box.add_child(controls)
	master_volume.grab_focus()


func _add_volume_slider(box: VBoxContainer, title: String, setting_id: String, current_value: float, color: Color) -> HSlider:
	var value_label := _label("%s  %d%%" % [title, roundi(current_value * 100.0)], 15, color)
	box.add_child(value_label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = current_value
	slider.custom_minimum_size = Vector2(700, 22)
	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = "%s  %d%%" % [title, roundi(value * 100.0)]
		ProfileStore.set_setting(setting_id, value)
	)
	box.add_child(slider)
	return slider


func _start_run() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/run.tscn")


func _refresh_header() -> void:
	if points_label != null:
		var unlocked := 0
		for career_id in CareerCatalog.ids():
			if ProfileStore.is_career_unlocked(career_id):
				unlocked += 1
		var unlocked_difficulties := 0
		for difficulty_id in DifficultyCatalog.ids():
			if ProfileStore.is_difficulty_unlocked(difficulty_id):
				unlocked_difficulties += 1
		points_label.text = "复盘点  %d RP    ·    职业 %d / %d    ·    难度 %d / %d" % [ProfileStore.get_points(), unlocked, CareerCatalog.ids().size(), unlocked_difficulties, DifficultyCatalog.ids().size()]
	if current_career_label != null:
		var current := CareerCatalog.get_by_id(ProfileStore.session_career_id)
		current_career_label.text = "当前岗位\n%s" % current["name"]
		current_career_label.add_theme_color_override("font_color", Color(String(current["color"])))


func _clear_content() -> void:
	selected_detail_box = null
	museum_detail_box = null
	brief_difficulty_option = null
	cheat_code_input = null
	cheat_code_status = null
	for child in content_box.get_children():
		content_box.remove_child(child)
		child.queue_free()


func _section_title(title_text: String, subtitle_text: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.add_child(_label(title_text, 28, Color("edf8fa")))
	box.add_child(_label(subtitle_text, 14, Color("7897a5")))
	return box


func _career_badge(career: Dictionary, minimum_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = minimum_size
	panel.add_theme_stylebox_override("panel", _panel_style(Color(String(career["color"])).darkened(0.72), Color(String(career["color"]))))
	var layers := Control.new()
	panel.add_child(layers)
	layers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sprite := CareerCatalog.sprite_texture(String(career["id"]))
	if sprite != null:
		var art := TextureRect.new()
		layers.add_child(art)
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.texture = sprite
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.modulate = Color(0.98, 0.99, 1.0, 1.0)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge := _label(String(career["badge"]), 32, Color(String(career["color"])))
	layers.add_child(badge)
	badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	badge.add_theme_constant_override("outline_size", 5)
	badge.add_theme_color_override("font_outline_color", Color("07131e"))
	return panel


func _career_emblem_texture(career_id: String) -> Texture2D:
	return CareerCatalog.emblem_texture(career_id)


func _nav_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(220, 48)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(callback)
	return button


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	return style


func _upgrade_display_name(upgrade_id: String) -> String:
	match upgrade_id:
		"bash": return "Bash 脚本"
		"ping": return "Ping 扫描"
		"firewall": return "防火墙领域"
		"log": return "日志采集器"
		"wrench": return "机柜扳手"
		"rule_chain": return "iptables 规则链"
		"lock_zone": return "慢查询锁域"
		"worker": return "Worker Pod"
		"idempotency": return "幂等性"
		"runbook": return "Runbook"
		"capacity": return "容量规划"
		"redundancy": return "冗余设计"
	return upgrade_id
