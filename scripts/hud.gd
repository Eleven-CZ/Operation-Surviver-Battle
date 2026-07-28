extends CanvasLayer

const CareerCatalog := preload("res://scripts/career_catalog.gd")
const EventCatalog := preload("res://scripts/event_catalog.gd")
const DifficultyCatalog := preload("res://scripts/difficulty_catalog.gd")
const CoworkerCatalog := preload("res://scripts/coworker_catalog.gd")
const ArtifactCatalog := preload("res://scripts/artifact_catalog.gd")
const HUD_OVERLAY_TEXTURE := preload("res://assets/generated/combat_hud_overlay.png")
const HUD_OVERLAY_OPSDEV_TEXTURE := preload("res://assets/generated/combat_hud_overlay_opsdev.png")
const SKILL_ICON_TEXTURE := preload("res://assets/generated/skill_icons_5x2.png")
const COWORKER_SPRITE_TEXTURE := preload("res://assets/generated/coworker_sprites_4x2.png")
const MiniRadarScript := preload("res://scripts/mini_radar.gd")
const SKILL_ICON_ORDER: Array[String] = ["bash", "ping", "firewall", "log", "wrench", "rule_chain", "lock_zone", "worker", "runbook", "redundancy"]

signal upgrade_selected(upgrade_id: String)
signal upgrade_reroll_requested
signal event_strategy_selected(event_id: String, strategy_id: String)
signal release_selected(choice_id: String)
signal restart_requested
signal main_menu_requested
signal career_select_requested
signal pause_requested
signal resume_requested
signal career_skill_requested
signal career_ultimate_requested
signal artifact_reel_finished

var root_control: Control
var hud_art: TextureRect
var health_label: Label
var xp_label: Label
var time_label: Label
var health_bar: ProgressBar
var xp_bar: ProgressBar
var status_panel: PanelContainer
var career_protocol_label: Label
var event_label: Label
var build_label: Label
var performance_label: Label
var career_icon: TextureRect
var artifact_panel: PanelContainer
var artifact_count_label: Label
var artifact_slot_panels: Array[PanelContainer] = []
var artifact_slot_icons: Array[TextureRect] = []
var artifact_slot_badges: Array[Label] = []
var artifact_slot_names: Array[Label] = []
var artifact_slot_definitions: Array[Dictionary] = []
var artifact_reel_panel: PanelContainer
var artifact_reel_icon_frames: Array[PanelContainer] = []
var artifact_reel_icons: Array[TextureRect] = []
var artifact_reel_result: Label
var artifact_reel_detail: Label
var artifact_reel_pool: Array[Dictionary] = []
var artifact_reel_queue: Array[Dictionary] = []
var artifact_reel_displayed_ids: Array[String] = ["", "", ""]
var artifact_reel_selected: Dictionary = {}
var artifact_reel_selected_id := ""
var artifact_reel_phase := "idle"
var artifact_reel_elapsed := 0.0
var artifact_reel_step_left := 0.0
var artifact_reel_hold_left := 0.0
var artifact_reel_cursor := 0
var artifact_reel_duration := 1.65
var boss_panel: PanelContainer
var boss_label: Label
var boss_bar: ProgressBar
var event_objective_panel: PanelContainer
var event_objective_title: Label
var event_objective_time: Label
var event_objective_detail: Label
var event_objective_bar: ProgressBar
var event_objective_value: Label
var overlay: ColorRect
var modal_panel: PanelContainer
var modal_box: VBoxContainer
var feedback_flash: ColorRect
var feedback_panel: PanelContainer
var feedback_title: Label
var feedback_detail: Label
var feedback_left := 0.0
var feedback_duration := 2.2
var feedback_audio: AudioStreamPlayer
var modal_mode := ""
var skill_slots: Array[Control] = []
var skill_slot_backs: Array[ColorRect] = []
var skill_slot_icons: Array[TextureRect] = []
var skill_slot_levels: Array[Label] = []
var radar: Control
var ally_tracker: Control
var ally_panel: PanelContainer
var ally_portrait: TextureRect
var ally_badge: Label
var ally_title: Label
var ally_role: Label
var ally_skill: Label
var ally_cooldown: Label
var ally_status: Label
var ally_cast_flash_left := 0.0
var ally_cast_notice_cooldown := 0.0
var career_skill_slot: Control
var career_skill_icon: TextureRect
var career_skill_cover: ColorRect
var career_skill_cooldown: Label
var career_skill_name: Label
var career_skill_button: Button
var career_ultimate_slot: Control
var career_ultimate_icon: TextureRect
var career_ultimate_cover: ColorRect
var career_ultimate_cooldown: Label
var career_ultimate_name: Label
var career_ultimate_button: Button
var opsdev_toolchain_panel: Control
var opsdev_toolchain_frames: Array[PanelContainer] = []
var opsdev_toolchain_icons: Array[TextureRect] = []
var opsdev_toolchain_names: Array[Label] = []
var opsdev_toolchain_modifiers: Array[Label] = []
var opsdev_toolchain_revisions: Array[Label] = []
var career_action_accent := Color("56e6dc")
var last_skill_action_id := ""
var last_ultimate_action_id := ""
var difficulty_id := "normal"
var difficulty_name := "普通"
var difficulty_color := Color("65e890")
var career_protocol_text := "职业协议 · 初始化"
var build_summary_text := "Bash ×1"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hud()


func _build_hud() -> void:
	var high_contrast := bool(ProfileStore.get_settings().get("high_contrast", false))
	root_control = Control.new()
	add_child(root_control)
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# AI-authored border art supplies the dense pixel-metal visual hierarchy. All
	# live text/bars stay native controls above it for reliable localization.
	hud_art = TextureRect.new()
	root_control.add_child(hud_art)
	hud_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_art.texture = HUD_OVERLAY_TEXTURE
	hud_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hud_art.stretch_mode = TextureRect.STRETCH_SCALE
	hud_art.mouse_filter = Control.MOUSE_FILTER_IGNORE

	health_bar = ProgressBar.new()
	root_control.add_child(health_bar)
	health_bar.position = Vector2(65, 23)
	health_bar.size = Vector2(178, 17)
	health_bar.show_percentage = false
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_bar.add_theme_stylebox_override("background", _bar_style(Color(0.01, 0.05, 0.06, 0.82), Color("123a3b")))
	health_bar.add_theme_stylebox_override("fill", _bar_style(Color("35e998"), Color("7affc2")))
	xp_bar = ProgressBar.new()
	root_control.add_child(xp_bar)
	xp_bar.position = Vector2(44, 66)
	xp_bar.size = Vector2(162, 9)
	xp_bar.show_percentage = false
	xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_bar.add_theme_stylebox_override("background", _bar_style(Color(0.01, 0.04, 0.08, 0.82), Color("17394c")))
	xp_bar.add_theme_stylebox_override("fill", _bar_style(Color("2cb9ef"), Color("6adfff")))

	radar = MiniRadarScript.new()
	root_control.add_child(radar)
	radar.position = Vector2(1095, 34)
	radar.size = Vector2(145, 145)
	radar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ally_tracker()

	health_label = _make_label("100 / 100", 10, Color("dffdf3"))
	root_control.add_child(health_label)
	health_label.position = Vector2(65, 21)
	health_label.size = Vector2(178, 20)
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	health_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_label.add_theme_constant_override("outline_size", 1)
	health_label.add_theme_color_override("font_outline_color", Color("041019"))
	xp_label = _make_label("L1 · 0 / 20", 9, Color("d9f4ff"))
	root_control.add_child(xp_label)
	xp_label.position = Vector2(44, 61)
	xp_label.size = Vector2(162, 18)
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	xp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_label.add_theme_constant_override("outline_size", 1)
	xp_label.add_theme_color_override("font_outline_color", Color("041019"))

	status_panel = PanelContainer.new()
	root_control.add_child(status_panel)
	status_panel.position = Vector2(18, 92)
	status_panel.custom_minimum_size = Vector2(300, 70)
	status_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	status_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.015, 0.055, 0.08, 0.92 if high_contrast else 0.58), Color("79fff0") if high_contrast else Color(0.20, 0.82, 0.76, 0.38)))
	var status_margin := MarginContainer.new()
	status_panel.add_child(status_margin)
	status_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_margin.add_theme_constant_override("margin_left", 11)
	status_margin.add_theme_constant_override("margin_right", 11)
	status_margin.add_theme_constant_override("margin_top", 7)
	status_margin.add_theme_constant_override("margin_bottom", 7)
	var status_box := VBoxContainer.new()
	status_margin.add_child(status_box)
	status_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_box.add_theme_constant_override("separation", 2)
	time_label = _make_label("普通 · 00:00 / 06:00", 11, Color("e4edf3"))
	career_protocol_label = _make_label(career_protocol_text, 11, Color("ffd36a"))
	career_protocol_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	career_protocol_label.custom_minimum_size = Vector2(278, 34)
	career_protocol_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_box.add_child(time_label)
	status_box.add_child(career_protocol_label)
	# The full build is already represented by the bottom skill tray. Keep the
	# text available to tests and expose it on hover instead of covering combat.
	build_label = _make_label(build_summary_text, 11, Color("a9bdc9"))
	root_control.add_child(build_label)
	build_label.hide()
	career_icon = TextureRect.new()
	root_control.add_child(career_icon)
	career_icon.position = Vector2(0, 0)
	career_icon.size = Vector2(1, 1)
	career_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	career_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	career_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	career_icon.hide()
	_refresh_status_tooltip()
	_build_artifact_slots()

	event_label = _make_label("", 18, Color("ffd05a"))
	root_control.add_child(event_label)
	event_label.position = Vector2(487, 23)
	event_label.size = Vector2(306, 54)
	event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	boss_panel = PanelContainer.new()
	root_control.add_child(boss_panel)
	boss_panel.position = Vector2(475, 12)
	boss_panel.custom_minimum_size = Vector2(350, 72)
	boss_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.11, 0.025, 0.035, 0.94), Color("e34b3d")))
	var boss_margin := MarginContainer.new()
	boss_panel.add_child(boss_margin)
	boss_margin.add_theme_constant_override("margin_left", 12)
	boss_margin.add_theme_constant_override("margin_right", 12)
	boss_margin.add_theme_constant_override("margin_top", 8)
	boss_margin.add_theme_constant_override("margin_bottom", 8)
	var boss_box := VBoxContainer.new()
	boss_margin.add_child(boss_box)
	boss_label = _make_label("FATAL / INCIDENT CORE", 16, Color("ff8b7d"))
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_bar = ProgressBar.new()
	boss_bar.custom_minimum_size = Vector2(320, 18)
	boss_bar.show_percentage = false
	boss_box.add_child(boss_label)
	boss_box.add_child(boss_bar)
	boss_panel.hide()

	event_objective_panel = PanelContainer.new()
	root_control.add_child(event_objective_panel)
	event_objective_panel.anchor_left = 1.0
	event_objective_panel.anchor_right = 1.0
	event_objective_panel.offset_left = -322.0
	event_objective_panel.offset_top = 118.0
	event_objective_panel.offset_right = -18.0
	event_objective_panel.offset_bottom = 258.0
	event_objective_panel.custom_minimum_size = Vector2(304, 140)
	event_objective_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	event_objective_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.075, 0.11, 0.95), Color("ffd05a")))
	var event_objective_margin := MarginContainer.new()
	event_objective_panel.add_child(event_objective_margin)
	event_objective_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	event_objective_margin.add_theme_constant_override("margin_left", 12)
	event_objective_margin.add_theme_constant_override("margin_right", 12)
	event_objective_margin.add_theme_constant_override("margin_top", 9)
	event_objective_margin.add_theme_constant_override("margin_bottom", 9)
	var event_objective_box := VBoxContainer.new()
	event_objective_margin.add_child(event_objective_box)
	event_objective_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	event_objective_box.add_theme_constant_override("separation", 5)
	var event_objective_header := HBoxContainer.new()
	event_objective_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	event_objective_box.add_child(event_objective_header)
	event_objective_title = _make_label("EVENT · 特殊事件", 15, Color("ffd05a"))
	event_objective_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_objective_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	event_objective_header.add_child(event_objective_title)
	event_objective_time = _make_label("01:02", 15, Color("ffffff"))
	event_objective_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	event_objective_time.custom_minimum_size = Vector2(54, 0)
	event_objective_header.add_child(event_objective_time)
	event_objective_detail = _make_label("关闭事件故障", 13, Color("d4e2e8"))
	event_objective_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_objective_detail.custom_minimum_size = Vector2(280, 38)
	event_objective_box.add_child(event_objective_detail)
	var event_objective_progress := HBoxContainer.new()
	event_objective_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	event_objective_progress.add_theme_constant_override("separation", 8)
	event_objective_box.add_child(event_objective_progress)
	event_objective_bar = ProgressBar.new()
	event_objective_bar.custom_minimum_size = Vector2(204, 18)
	event_objective_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_objective_bar.show_percentage = false
	event_objective_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	event_objective_progress.add_child(event_objective_bar)
	event_objective_value = _make_label("0 / 0", 12, Color("b9cad1"))
	event_objective_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	event_objective_value.custom_minimum_size = Vector2(60, 0)
	event_objective_progress.add_child(event_objective_value)
	event_objective_panel.hide()

	_build_skill_tray()
	_build_career_action_slots()
	_build_opsdev_toolchain()

	var hint := _make_label("WASD 移动 · Q/Space 小技能 · R 大招 · E 对齐 · Esc 暂停", 11, Color("b6d7e3") if high_contrast else Color("7095a8"))
	root_control.add_child(hint)
	hint.position = Vector2(18, 684)
	hint.size = Vector2(430, 24)
	hint.visible = OS.get_cmdline_user_args().has("--debug-hints")

	performance_label = _make_label("", 13, Color("8eff86"))
	root_control.add_child(performance_label)
	performance_label.position = Vector2(1080, 28)
	performance_label.size = Vector2(166, 122)
	performance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	performance_label.hide()

	overlay = ColorRect.new()
	root_control.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.02, 0.035, 0.88 if high_contrast else 0.76)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_panel = PanelContainer.new()
	center.add_child(modal_panel)
	modal_panel.custom_minimum_size = Vector2(1160, 520)
	modal_panel.add_theme_stylebox_override("panel", _panel_style(Color("0b1c2a"), Color("35d6c4")))
	var modal_margin := MarginContainer.new()
	modal_panel.add_child(modal_margin)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		modal_margin.add_theme_constant_override(side, 18)
	modal_box = VBoxContainer.new()
	modal_margin.add_child(modal_box)
	modal_box.add_theme_constant_override("separation", 9)
	overlay.hide()

	feedback_flash = ColorRect.new()
	root_control.add_child(feedback_flash)
	feedback_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	feedback_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feedback_flash.hide()

	feedback_panel = PanelContainer.new()
	root_control.add_child(feedback_panel)
	feedback_panel.position = Vector2(300, 8)
	feedback_panel.custom_minimum_size = Vector2(680, 82)
	feedback_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var feedback_margin := MarginContainer.new()
	feedback_panel.add_child(feedback_margin)
	feedback_margin.add_theme_constant_override("margin_left", 20)
	feedback_margin.add_theme_constant_override("margin_right", 20)
	feedback_margin.add_theme_constant_override("margin_top", 9)
	feedback_margin.add_theme_constant_override("margin_bottom", 9)
	var feedback_box := VBoxContainer.new()
	feedback_margin.add_child(feedback_box)
	feedback_title = _make_label("STACK 已叠加", 22, Color("75f3df"))
	feedback_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_detail = _make_label("", 15, Color("d4e2e8"))
	feedback_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_detail.custom_minimum_size = Vector2(630, 30)
	feedback_box.add_child(feedback_title)
	feedback_box.add_child(feedback_detail)
	feedback_panel.hide()
	_build_artifact_reel()

	feedback_audio = AudioStreamPlayer.new()
	add_child(feedback_audio)
	feedback_audio.bus = &"UI"
	feedback_audio.stream = _build_upgrade_chime_stream()


func _build_artifact_reel() -> void:
	artifact_reel_panel = PanelContainer.new()
	root_control.add_child(artifact_reel_panel)
	artifact_reel_panel.position = Vector2(340, 154)
	artifact_reel_panel.custom_minimum_size = Vector2(600, 350)
	artifact_reel_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	artifact_reel_panel.pivot_offset = Vector2(300, 175)
	artifact_reel_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.038, 0.055, 0.98), Color("ffcf5a")))
	var margin := MarginContainer.new()
	artifact_reel_panel.add_child(margin)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 18)
	var box := VBoxContainer.new()
	margin.add_child(box)
	box.add_theme_constant_override("separation", 9)
	var marquee := _make_label("◆  JACKPOT · 神器协议掉落  ◆", 20, Color("ffe77a"))
	marquee.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(marquee)
	var lamps := _make_label("●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●", 11, Color("ff9b62"))
	lamps.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(lamps)
	var reel_row := HBoxContainer.new()
	reel_row.alignment = BoxContainer.ALIGNMENT_CENTER
	reel_row.add_theme_constant_override("separation", 12)
	box.add_child(reel_row)
	for slot_index in range(3):
		var frame := PanelContainer.new()
		reel_row.add_child(frame)
		frame.custom_minimum_size = Vector2(142, 142)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var border := Color("ffd36a") if slot_index == 1 else Color("5a7580")
		frame.add_theme_stylebox_override("panel", _panel_style(Color("050b10"), border))
		var frame_margin := MarginContainer.new()
		frame.add_child(frame_margin)
		for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
			frame_margin.add_theme_constant_override(side, 8)
		var icon := TextureRect.new()
		frame_margin.add_child(icon)
		icon.custom_minimum_size = Vector2(124, 124)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.pivot_offset = Vector2(62, 62)
		artifact_reel_icon_frames.append(frame)
		artifact_reel_icons.append(icon)
	var selector := _make_label("▲  最终协议  ▲", 12, Color("ffcf5a"))
	selector.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(selector)
	artifact_reel_result = _make_label("正在扫描精英掉落池……", 22, Color("fff1b8"))
	artifact_reel_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	artifact_reel_result.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(artifact_reel_result)
	artifact_reel_detail = _make_label("协议滚轮将在确认后停止", 13, Color("9db6c0"))
	artifact_reel_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	artifact_reel_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	artifact_reel_detail.custom_minimum_size = Vector2(540, 42)
	box.add_child(artifact_reel_detail)
	artifact_reel_panel.hide()


func _process(delta: float) -> void:
	ally_cast_notice_cooldown = maxf(0.0, ally_cast_notice_cooldown - delta)
	if ally_cast_flash_left > 0.0:
		ally_cast_flash_left = maxf(0.0, ally_cast_flash_left - delta)
		var pulse := 1.0 + sin(ally_cast_flash_left * 18.0) * 0.025
		ally_tracker.scale = Vector2.ONE * pulse
		if ally_cast_flash_left <= 0.0:
			ally_tracker.scale = Vector2.ONE
	_update_artifact_reel(delta)
	if feedback_left <= 0.0:
		return
	feedback_left = maxf(0.0, feedback_left - delta)
	var elapsed := feedback_duration - feedback_left
	var fade_in := clampf(elapsed / 0.12, 0.0, 1.0)
	var fade_out := clampf(feedback_left / 0.5, 0.0, 1.0)
	var alpha := minf(fade_in, fade_out)
	feedback_panel.modulate.a = alpha
	feedback_panel.scale = Vector2.ONE * lerpf(1.08, 1.0, fade_in)
	feedback_flash.color.a = 0.15 * clampf(1.0 - elapsed / 0.28, 0.0, 1.0)
	if feedback_left <= 0.0:
		feedback_panel.hide()
		feedback_flash.hide()


func _build_skill_tray() -> void:
	var start := Vector2(476, 635)
	for slot_index in range(8):
		var slot := Control.new()
		root_control.add_child(slot)
		slot.position = start + Vector2(slot_index * 70.0, 0)
		slot.size = Vector2(58, 58)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		skill_slots.append(slot)
		var slot_back := ColorRect.new()
		slot.add_child(slot_back)
		slot_back.position = Vector2(4, 4)
		slot_back.size = Vector2(50, 50)
		slot_back.color = Color(0.006, 0.025, 0.040, 0.88)
		slot_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		skill_slot_backs.append(slot_back)
		var icon := TextureRect.new()
		slot.add_child(icon)
		icon.position = Vector2(4, 4)
		icon.size = Vector2(50, 50)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.modulate = Color(0.45, 0.56, 0.61, 0.32)
		skill_slot_icons.append(icon)
		var level_label := _make_label("", 11, Color("ffffff"))
		slot.add_child(level_label)
		level_label.position = Vector2(31, 34)
		level_label.size = Vector2(23, 18)
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_label.add_theme_color_override("font_shadow_color", Color.BLACK)
		level_label.add_theme_constant_override("shadow_offset_x", 1)
		level_label.add_theme_constant_override("shadow_offset_y", 1)
		skill_slot_levels.append(level_label)
	_configure_skill_tray_layout(false)


func _configure_skill_tray_layout(expanded: bool) -> void:
	var visible_count := 8 if expanded else 5
	var start := Vector2(471, 642) if expanded else Vector2(476, 635)
	var spacing := 44.0 if expanded else 70.0
	var slot_size := Vector2(42, 42) if expanded else Vector2(58, 58)
	var icon_offset := Vector2(3, 3) if expanded else Vector2(4, 4)
	var icon_size := Vector2(36, 36) if expanded else Vector2(50, 50)
	for slot_index in range(skill_slots.size()):
		var slot := skill_slots[slot_index]
		slot.visible = slot_index < visible_count
		slot.position = start + Vector2(float(slot_index) * spacing, 0.0)
		slot.size = slot_size
		var slot_back := skill_slot_backs[slot_index]
		slot_back.position = icon_offset
		slot_back.size = icon_size
		var icon := skill_slot_icons[slot_index]
		icon.position = icon_offset
		icon.size = icon_size
		var level_label := skill_slot_levels[slot_index]
		level_label.position = Vector2(21, 24) if expanded else Vector2(31, 34)
		level_label.size = Vector2(19, 16) if expanded else Vector2(23, 18)


func _build_artifact_slots() -> void:
	artifact_panel = PanelContainer.new()
	root_control.add_child(artifact_panel)
	artifact_panel.position = Vector2(18, 170)
	artifact_panel.custom_minimum_size = Vector2(300, 76)
	artifact_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.045, 0.055, 0.88), Color(0.72, 0.52, 0.18, 0.68)))
	var margin := MarginContainer.new()
	artifact_panel.add_child(margin)
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 7)
	var box := VBoxContainer.new()
	margin.add_child(box)
	box.add_theme_constant_override("separation", 4)
	artifact_count_label = _make_label("神器协议  0 / 2", 10, Color("d7b45b"))
	box.add_child(artifact_count_label)
	var row := HBoxContainer.new()
	box.add_child(row)
	row.add_theme_constant_override("separation", 8)
	for slot_index in range(2):
		var slot_panel := PanelContainer.new()
		row.add_child(slot_panel)
		slot_panel.custom_minimum_size = Vector2(135, 42)
		slot_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		slot_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.032, 0.042, 0.94), Color("425d68")))
		var slot_margin := MarginContainer.new()
		slot_panel.add_child(slot_margin)
		slot_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_margin.add_theme_constant_override("margin_left", 8)
		slot_margin.add_theme_constant_override("margin_right", 8)
		slot_margin.add_theme_constant_override("margin_top", 5)
		slot_margin.add_theme_constant_override("margin_bottom", 5)
		var slot_row := HBoxContainer.new()
		slot_margin.add_child(slot_row)
		slot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_row.add_theme_constant_override("separation", 7)
		var icon := TextureRect.new()
		slot_row.add_child(icon)
		icon.custom_minimum_size = Vector2(30, 30)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = Color(0.45, 0.56, 0.61, 0.28)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var badge := _make_label("◇", 16, Color("607986"))
		slot_row.add_child(badge)
		badge.custom_minimum_size = Vector2.ZERO
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.hide()
		var name := _make_label("空神器槽", 10, Color("718b96"))
		slot_row.add_child(name)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_panel.tooltip_text = "神器槽 %d\n尚未接入神器" % (slot_index + 1)
		artifact_slot_panels.append(slot_panel)
		artifact_slot_icons.append(icon)
		artifact_slot_badges.append(badge)
		artifact_slot_names.append(name)


func _build_career_action_slots() -> void:
	var skill_parts := _make_career_action_slot(Vector2(382, 618), Vector2(80, 78), Color("56e6dc"), "Q / X")
	career_skill_slot = skill_parts["slot"]
	career_skill_icon = skill_parts["icon"]
	career_skill_cover = skill_parts["cover"]
	career_skill_cooldown = skill_parts["cooldown"]
	career_skill_name = skill_parts["name"]
	career_skill_button = skill_parts["button"]
	career_skill_button.pressed.connect(func() -> void: career_skill_requested.emit())

	var ultimate_parts := _make_career_action_slot(Vector2(826, 610), Vector2(88, 86), Color("ffd36a"), "R / Y")
	career_ultimate_slot = ultimate_parts["slot"]
	career_ultimate_icon = ultimate_parts["icon"]
	career_ultimate_cover = ultimate_parts["cover"]
	career_ultimate_cooldown = ultimate_parts["cooldown"]
	career_ultimate_name = ultimate_parts["name"]
	career_ultimate_button = ultimate_parts["button"]
	career_ultimate_button.pressed.connect(func() -> void: career_ultimate_requested.emit())


func _build_opsdev_toolchain() -> void:
	opsdev_toolchain_panel = Control.new()
	root_control.add_child(opsdev_toolchain_panel)
	opsdev_toolchain_panel.position = Vector2(471, 558)
	opsdev_toolchain_panel.size = Vector2(340, 48)
	opsdev_toolchain_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := _make_label("RUNTIME TOOLCHAIN", 10, Color("9cff72"))
	opsdev_toolchain_panel.add_child(title)
	title.position = Vector2(0, -18)
	title.size = Vector2(340, 17)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 4)
	title.add_theme_color_override("font_outline_color", Color("041019"))
	var stage_labels: Array[String] = ["FORK", "LOOP", "OPT", "FAN", "CACHE", "VEC", "JIT"]
	for slot_index in range(7):
		var frame := PanelContainer.new()
		opsdev_toolchain_panel.add_child(frame)
		frame.position = Vector2(float(slot_index) * 48.0 + 2.0, 0.0)
		frame.size = Vector2(44, 44)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_theme_stylebox_override("panel", _panel_style(Color(0.006, 0.025, 0.04, 0.92), Color("425d68")))
		var content := Control.new()
		frame.add_child(content)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := TextureRect.new()
		content.add_child(icon)
		icon.position = Vector2(10, 12)
		icon.size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.modulate = Color(0.38, 0.50, 0.56, 0.25)
		var modifier := _make_label(stage_labels[slot_index], 7, Color("7899a5"))
		content.add_child(modifier)
		modifier.position = Vector2(2, -1)
		modifier.size = Vector2(40, 13)
		modifier.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var revision := _make_label("", 8, Color("d9ffb7"))
		content.add_child(revision)
		revision.position = Vector2(25, 9)
		revision.size = Vector2(16, 12)
		revision.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var name := _make_label("EMPTY", 7, Color("607986"))
		content.add_child(name)
		name.position = Vector2(1, 32)
		name.size = Vector2(42, 11)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		opsdev_toolchain_frames.append(frame)
		opsdev_toolchain_icons.append(icon)
		opsdev_toolchain_names.append(name)
		opsdev_toolchain_modifiers.append(modifier)
		opsdev_toolchain_revisions.append(revision)
	opsdev_toolchain_panel.hide()


func _make_career_action_slot(position_value: Vector2, slot_size: Vector2, border: Color, key_text: String) -> Dictionary:
	var slot := Control.new()
	root_control.add_child(slot)
	slot.position = position_value
	slot.size = slot_size
	var panel := PanelContainer.new()
	slot.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.006, 0.025, 0.04, 0.94), border))
	panel.set_meta("action_frame", true)
	var icon := TextureRect.new()
	slot.add_child(icon)
	icon.position = Vector2(8, 8)
	icon.size = slot_size - Vector2(16, 16)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cover := ColorRect.new()
	slot.add_child(cover)
	cover.position = Vector2(7, 7)
	cover.size = slot_size - Vector2(14, 14)
	cover.color = Color(0.01, 0.02, 0.035, 0.76)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.hide()
	var cooldown := _make_label("READY", 14, Color("ffffff"))
	slot.add_child(cooldown)
	cooldown.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cooldown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cooldown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cooldown.add_theme_constant_override("outline_size", 5)
	cooldown.add_theme_color_override("font_outline_color", Color("041019"))
	var key := _make_label(key_text, 9, border.lightened(0.18))
	slot.add_child(key)
	key.position = Vector2(4, 2)
	key.size = Vector2(slot_size.x - 8, 15)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	key.add_theme_constant_override("outline_size", 3)
	key.add_theme_color_override("font_outline_color", Color("041019"))
	var name := _make_label("职业动作", 11, border)
	slot.add_child(name)
	name.position = Vector2(-28, -22)
	name.size = Vector2(slot_size.x + 56, 20)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.add_theme_constant_override("outline_size", 4)
	name.add_theme_color_override("font_outline_color", Color("041019"))
	var button := Button.new()
	slot.add_child(button)
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return {"slot": slot, "icon": icon, "cover": cover, "cooldown": cooldown, "name": name, "button": button}


func _build_ally_tracker() -> void:
	ally_tracker = Control.new()
	root_control.add_child(ally_tracker)
	ally_tracker.position = Vector2(1018, 267)
	ally_tracker.size = Vector2(244, 174)
	ally_tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ally_panel = PanelContainer.new()
	ally_tracker.add_child(ally_panel)
	ally_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ally_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ally_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.015, 0.055, 0.075, 0.95), Color("4e7c88")))
	ally_portrait = TextureRect.new()
	ally_tracker.add_child(ally_portrait)
	ally_portrait.position = Vector2(166, 9)
	ally_portrait.size = Vector2(70, 102)
	ally_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ally_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ally_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ally_badge = _make_label("PM", 11, Color("ef74dd"))
	ally_tracker.add_child(ally_badge)
	ally_badge.position = Vector2(174, 7)
	ally_badge.size = Vector2(54, 20)
	ally_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ally_badge.add_theme_constant_override("outline_size", 4)
	ally_badge.add_theme_color_override("font_outline_color", Color("061018"))
	ally_title = _make_label("协作席位", 10, Color("b7d1d8"))
	ally_tracker.add_child(ally_title)
	ally_title.position = Vector2(12, 10)
	ally_title.size = Vector2(145, 24)
	ally_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ally_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ally_title.add_theme_constant_override("outline_size", 3)
	ally_title.add_theme_color_override("font_outline_color", Color("061018"))
	ally_role = _make_label("协作能力待接入", 10, Color("8eaab5"))
	ally_tracker.add_child(ally_role)
	ally_role.position = Vector2(12, 37)
	ally_role.size = Vector2(145, 39)
	ally_role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ally_role.add_theme_constant_override("outline_size", 3)
	ally_role.add_theme_color_override("font_outline_color", Color("061018"))
	ally_skill = _make_label("能力待对齐", 12, Color("ef74dd"))
	ally_tracker.add_child(ally_skill)
	ally_skill.position = Vector2(12, 82)
	ally_skill.size = Vector2(145, 38)
	ally_skill.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ally_skill.add_theme_constant_override("outline_size", 3)
	ally_skill.add_theme_color_override("font_outline_color", Color("061018"))
	ally_cooldown = _make_label("化解后自动施放", 10, Color("7899a5"))
	ally_tracker.add_child(ally_cooldown)
	ally_cooldown.position = Vector2(12, 128)
	ally_cooldown.size = Vector2(145, 26)
	ally_cooldown.add_theme_constant_override("outline_size", 3)
	ally_cooldown.add_theme_color_override("font_outline_color", Color("061018"))
	ally_status = _make_label("", 10, Color("ef74dd"))
	ally_tracker.add_child(ally_status)
	ally_status.position = Vector2(164, 126)
	ally_status.size = Vector2(72, 30)
	ally_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ally_status.add_theme_constant_override("outline_size", 3)
	ally_status.add_theme_color_override("font_outline_color", Color("061018"))
	ally_tracker.hide()


func update_status(health: float, maximum_health: float, level: int, xp: int, xp_required: int, run_time: float, duration: float) -> void:
	health_label.text = "%d / %d" % [ceili(health), ceili(maximum_health)]
	health_label.modulate = Color("ff786c") if health / maximum_health < 0.3 else Color.WHITE
	xp_label.text = "L%d · %d / %d" % [level, xp, xp_required]
	time_label.text = "%s · %s / %s" % [difficulty_name, _format_time(run_time), _format_time(duration)]
	time_label.add_theme_color_override("font_color", difficulty_color)
	health_bar.max_value = maxf(1.0, maximum_health)
	health_bar.value = health
	xp_bar.max_value = maxf(1.0, float(xp_required))
	xp_bar.value = xp


func configure_difficulty(config: Dictionary) -> void:
	difficulty_id = String(config.get("id", "normal"))
	difficulty_name = String(config.get("name", "普通"))
	difficulty_color = Color(String(config.get("color", "65e890")))


func update_build(summary: String) -> void:
	build_summary_text = summary
	build_label.text = summary
	_refresh_status_tooltip()


func _refresh_status_tooltip() -> void:
	if status_panel == null:
		return
	status_panel.tooltip_text = "%s\n\n当前构筑\n%s" % [career_protocol_text, build_summary_text]


func update_artifact_slots(definitions: Array) -> void:
	artifact_slot_definitions.clear()
	for value in definitions:
		if artifact_slot_definitions.size() >= 2:
			break
		if value is Dictionary:
			artifact_slot_definitions.append(Dictionary(value).duplicate(true))
	artifact_count_label.text = "神器协议  %d / 2" % artifact_slot_definitions.size()
	for slot_index in range(artifact_slot_panels.size()):
		var panel := artifact_slot_panels[slot_index]
		var icon := artifact_slot_icons[slot_index]
		var badge := artifact_slot_badges[slot_index]
		var name := artifact_slot_names[slot_index]
		if slot_index >= artifact_slot_definitions.size():
			icon.texture = null
			icon.modulate = Color(0.45, 0.56, 0.61, 0.28)
			badge.text = "◇"
			badge.add_theme_color_override("font_color", Color("607986"))
			name.text = "空神器槽"
			name.add_theme_color_override("font_color", Color("718b96"))
			panel.tooltip_text = "神器槽 %d\n尚未接入神器" % (slot_index + 1)
			panel.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.032, 0.042, 0.94), Color("425d68")))
			continue
		var definition := artifact_slot_definitions[slot_index]
		var color_value: Variant = definition.get("color", "ffd45e")
		var accent: Color = color_value if color_value is Color else Color(String(color_value))
		var artifact_name := String(definition.get("name", definition.get("id", "未命名神器")))
		var artifact_badge := String(definition.get("badge", definition.get("icon", "◆")))
		var description := String(definition.get("description", definition.get("effect", definition.get("summary", "神器效果已生效"))))
		icon.texture = ArtifactCatalog.icon_texture(String(definition.get("id", "")))
		icon.modulate = Color.WHITE
		badge.text = artifact_badge if not artifact_badge.is_empty() else "◆"
		badge.add_theme_color_override("font_color", accent.lightened(0.16))
		name.text = artifact_name
		name.add_theme_color_override("font_color", Color("fff2c2"))
		panel.tooltip_text = "%s  ·  %s\n%s" % [badge.text, artifact_name, description]
		panel.add_theme_stylebox_override("panel", _panel_style(Color(0.09, 0.065, 0.018, 0.96), accent))


func get_artifact_ui_snapshot() -> Dictionary:
	var slots: Array[Dictionary] = []
	for slot_index in range(artifact_slot_panels.size()):
		var occupied := slot_index < artifact_slot_definitions.size()
		slots.append({
			"occupied": occupied,
			"id": String(artifact_slot_definitions[slot_index].get("id", "")) if occupied else "",
			"name": artifact_slot_names[slot_index].text,
			"badge": artifact_slot_badges[slot_index].text,
			"tooltip": artifact_slot_panels[slot_index].tooltip_text,
		})
	return {
		"visible": artifact_panel != null and artifact_panel.visible,
		"count": artifact_slot_definitions.size(),
		"capacity": artifact_slot_panels.size(),
		"position": artifact_panel.position if artifact_panel != null else Vector2.ZERO,
		"size": artifact_panel.size if artifact_panel != null else Vector2.ZERO,
		"slots": slots,
	}


func update_skill_loadout(loadout: Array[Dictionary]) -> void:
	for slot_index in range(skill_slot_icons.size()):
		var icon := skill_slot_icons[slot_index]
		var level_label := skill_slot_levels[slot_index]
		if slot_index >= loadout.size():
			icon.texture = null
			icon.modulate = Color(0.45, 0.56, 0.61, 0.30)
			level_label.text = ""
			continue
		var entry: Dictionary = loadout[slot_index]
		var skill_id := String(entry.get("id", ""))
		icon.texture = _skill_icon(skill_id)
		icon.modulate = Color.WHITE
		level_label.text = "×%d" % int(entry.get("level", 1))
		icon.tooltip_text = String(entry.get("name", skill_id))


func update_career_actions(snapshot: Dictionary) -> void:
	if snapshot.is_empty() or career_skill_slot == null or career_ultimate_slot == null:
		return
	var skill: Dictionary = snapshot.get("skill", {})
	var ultimate: Dictionary = snapshot.get("ultimate", {})
	var skill_id := String(skill.get("id", ""))
	var ultimate_id := String(ultimate.get("id", ""))
	if skill_id != last_skill_action_id:
		last_skill_action_id = skill_id
		career_skill_icon.texture = _skill_icon(String(skill.get("icon", "wrench")))
	if ultimate_id != last_ultimate_action_id:
		last_ultimate_action_id = ultimate_id
		career_ultimate_icon.texture = CareerCatalog.emblem_texture(String(snapshot.get("career_id", "ops")))
	career_skill_name.text = String(skill.get("name", "职业小技能"))
	career_ultimate_name.text = String(ultimate.get("name", "职业大招"))
	_update_opsdev_toolchain(snapshot.get("opsdev_toolchain", []), int(snapshot.get("opsdev_toolchain_capacity", 3)))
	# Cooldown growth and artifacts can change the effective values without
	# changing the action id, so refresh both tooltips every frame.
	career_skill_button.tooltip_text = "%s\n%s\n当前冷却 %.1f 秒" % [skill.get("name", "职业小技能"), skill.get("description", ""), float(skill.get("cooldown", 0.0))]
	career_ultimate_button.tooltip_text = "%s\n%s\n当前冷却 %.1f 秒" % [ultimate.get("name", "职业大招"), ultimate.get("description", ""), float(ultimate.get("cooldown", 0.0))]
	var maximum_charges := int(skill.get("max_charges", 1))
	if maximum_charges > 1:
		var charges := int(skill.get("charges", 0))
		var recharge_remaining := float(skill.get("recharge_remaining", 0.0))
		career_skill_button.tooltip_text += "\n储备 %d / %d%s" % [charges, maximum_charges, " · 下一层 %.1fs" % recharge_remaining if recharge_remaining > 0.01 else ""]
		_update_action_charges(career_skill_slot, career_skill_cover, career_skill_cooldown, career_skill_button, charges, maximum_charges, recharge_remaining, float(skill.get("cooldown", 1.0)), career_action_accent)
	else:
		_update_action_cooldown(career_skill_slot, career_skill_cover, career_skill_cooldown, career_skill_button, float(skill.get("remaining", 0.0)), float(skill.get("cooldown", 1.0)), career_action_accent)
	_update_action_cooldown(career_ultimate_slot, career_ultimate_cover, career_ultimate_cooldown, career_ultimate_button, float(ultimate.get("remaining", 0.0)), float(ultimate.get("cooldown", 1.0)), Color("ffd36a"))


func _update_opsdev_toolchain(toolchain_value: Variant, capacity: int = 3) -> void:
	if opsdev_toolchain_panel == null:
		return
	var toolchain: Array = toolchain_value if toolchain_value is Array else []
	var stage_labels: Array[String] = ["FORK", "LOOP", "OPT", "FAN", "CACHE", "VEC", "JIT"]
	for slot_index in range(opsdev_toolchain_frames.size()):
		var frame := opsdev_toolchain_frames[slot_index]
		var icon := opsdev_toolchain_icons[slot_index]
		var name := opsdev_toolchain_names[slot_index]
		var modifier := opsdev_toolchain_modifiers[slot_index]
		var revision := opsdev_toolchain_revisions[slot_index]
		if slot_index >= capacity:
			frame.add_theme_stylebox_override("panel", _panel_style(Color(0.004, 0.012, 0.018, 0.82), Color("26343a")))
			icon.texture = null
			icon.modulate = Color(0.22, 0.28, 0.31, 0.20)
			name.text = "LOCKED"
			name.add_theme_color_override("font_color", Color("42545c"))
			modifier.text = "LOCK"
			modifier.add_theme_color_override("font_color", Color("42545c"))
			revision.text = ""
			continue
		if slot_index >= toolchain.size():
			frame.add_theme_stylebox_override("panel", _panel_style(Color(0.006, 0.025, 0.04, 0.88), Color("425d68")))
			icon.texture = null
			icon.modulate = Color(0.38, 0.50, 0.56, 0.25)
			name.text = "EMPTY"
			name.add_theme_color_override("font_color", Color("607986"))
			modifier.text = stage_labels[slot_index]
			modifier.add_theme_color_override("font_color", Color("7899a5"))
			revision.text = ""
			continue
		var snippet: Dictionary = toolchain[slot_index]
		var snippet_id := String(snippet.get("id", ""))
		var snippet_color := Color(snippet.get("color", Color("9cff72")))
		frame.add_theme_stylebox_override("panel", _panel_style(Color(0.006, 0.025, 0.04, 0.94), snippet_color))
		icon.texture = _skill_icon("bash" if snippet_id == "idempotent_script" else snippet_id)
		icon.modulate = Color.WHITE
		name.text = String(snippet.get("name", snippet_id)).to_upper()
		name.add_theme_color_override("font_color", snippet_color.lightened(0.12))
		modifier.text = String(snippet.get("modifier", stage_labels[slot_index]))
		modifier.add_theme_color_override("font_color", snippet_color)
		var revision_value := int(snippet.get("revision", 1))
		revision.text = "r%d" % revision_value if revision_value > 1 else ""


func _update_action_cooldown(slot: Control, cover: ColorRect, label: Label, button: Button, remaining: float, maximum: float, ready_color: Color) -> void:
	var inner_height := slot.size.y - 14.0
	var ratio := clampf(remaining / maxf(0.001, maximum), 0.0, 1.0)
	cover.position = Vector2(7, 7 + inner_height * (1.0 - ratio))
	cover.size = Vector2(slot.size.x - 14.0, inner_height * ratio)
	cover.visible = remaining > 0.01
	label.text = str(ceili(remaining)) if remaining > 0.01 else "READY"
	label.add_theme_color_override("font_color", Color("d9e7eb") if remaining > 0.01 else ready_color.lightened(0.18))
	button.disabled = remaining > 0.01


func _update_action_charges(slot: Control, cover: ColorRect, label: Label, button: Button, charges: int, maximum_charges: int, remaining: float, maximum: float, ready_color: Color) -> void:
	var inner_height := slot.size.y - 14.0
	var ratio := clampf(remaining / maxf(0.001, maximum), 0.0, 1.0)
	cover.position = Vector2(7, 7 + inner_height * (1.0 - ratio))
	cover.size = Vector2(slot.size.x - 14.0, inner_height * ratio)
	cover.visible = charges <= 0 and remaining > 0.01
	label.text = "%d/%d" % [charges, maximum_charges]
	label.add_theme_color_override("font_color", ready_color.lightened(0.18) if charges > 0 else Color("d9e7eb"))
	button.disabled = charges <= 0


func get_action_ui_snapshot() -> Dictionary:
	return {
		"skill_visible": career_skill_slot != null and career_skill_slot.visible,
		"ultimate_visible": career_ultimate_slot != null and career_ultimate_slot.visible,
		"skill_name": career_skill_name.text if career_skill_name != null else "",
		"ultimate_name": career_ultimate_name.text if career_ultimate_name != null else "",
		"skill_cooldown": career_skill_cooldown.text if career_skill_cooldown != null else "",
		"ultimate_cooldown": career_ultimate_cooldown.text if career_ultimate_cooldown != null else "",
		"opsdev_toolchain_visible": opsdev_toolchain_panel != null and opsdev_toolchain_panel.visible,
		"opsdev_overlay_active": hud_art != null and hud_art.texture == HUD_OVERLAY_OPSDEV_TEXTURE,
		"opsdev_toolchain_names": opsdev_toolchain_names.map(func(label: Label) -> String: return label.text),
		"skill_position": career_skill_slot.position if career_skill_slot != null else Vector2.ZERO,
		"ultimate_position": career_ultimate_slot.position if career_ultimate_slot != null else Vector2.ZERO,
	}


func update_radar(player_position: Vector2, snapshot: Dictionary) -> void:
	if radar != null and radar.has_method("set_snapshot"):
		radar.call("set_snapshot", player_position, snapshot)


func show_pressure_persona(persona_id: String, display_name: String, allied: bool = false) -> void:
	var definition := CoworkerCatalog.get_by_id(persona_id)
	var accent := CoworkerCatalog.color_for(persona_id)
	ally_portrait.texture = _coworker_portrait(persona_id)
	ally_title.text = display_name
	ally_badge.text = String(definition.get("badge", "ALLY"))
	ally_badge.add_theme_color_override("font_color", accent)
	ally_role.text = String(definition.get("role", "协作"))
	ally_skill.text = String(definition.get("ability", "协作能力"))
	ally_skill.add_theme_color_override("font_color", accent)
	ally_cooldown.text = "自动施放 · CD %.1fs" % float(definition.get("cooldown", 8.0)) if allied else "化解后自动施放"
	ally_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.015, 0.055, 0.075, 0.95), accent.darkened(0.18)))
	ally_tracker.tooltip_text = "%s · %s\n%s" % [definition.get("role", "协作"), definition.get("ability", "协作能力"), definition.get("description", "")]
	ally_portrait.modulate = Color(0.70, 1.0, 0.86, 1.0) if allied else Color(1.0, 0.78, 0.98, 1.0)
	ally_status.text = "● 盟友" if allied else "◆ 压力"
	ally_status.add_theme_color_override("font_color", Color("58efc0") if allied else Color("ef74dd"))
	ally_tracker.show()


func set_pressure_persona_allied(allied: bool) -> void:
	if not ally_tracker.visible:
		return
	ally_portrait.modulate = Color(0.70, 1.0, 0.86, 1.0) if allied else Color(1.0, 0.78, 0.98, 1.0)
	ally_status.text = "● 盟友" if allied else "◆ 压力"
	ally_status.add_theme_color_override("font_color", Color("58efc0") if allied else Color("ef74dd"))


func update_ally_support(snapshot: Dictionary) -> void:
	if snapshot.is_empty() or not bool(snapshot.get("active", false)) or not ally_tracker.visible:
		return
	var accent_value: Variant = snapshot.get("color", Color("55e7c2"))
	var accent: Color = accent_value if accent_value is Color else Color(String(accent_value))
	ally_skill.text = String(snapshot.get("ability", "协作能力"))
	ally_skill.add_theme_color_override("font_color", accent)
	if ally_cast_flash_left <= 0.0:
		ally_role.text = "%s · 威力 ×%.2f" % [String(snapshot.get("role", "协作")), float(snapshot.get("power_scale", 1.0))]
	var remaining := float(snapshot.get("remaining", 0.0))
	var cooldown := maxf(0.01, float(snapshot.get("cooldown", 1.0)))
	ally_cooldown.text = "READY" if remaining <= 0.01 else "冷却 %.1fs / %.1fs" % [remaining, cooldown]
	ally_cooldown.add_theme_color_override("font_color", accent.lightened(0.18) if remaining <= 0.01 else Color("9ab3bd"))
	ally_status.text = "● 盟友\n触发 ×%d" % int(snapshot.get("trigger_count", 0))
	ally_status.add_theme_color_override("font_color", Color("58efc0"))
	ally_tracker.tooltip_text = "%s · %s\n%s\n最近：%s" % [snapshot.get("role", "协作"), snapshot.get("ability", "协作能力"), snapshot.get("description", ""), snapshot.get("last_detail", "待命")]


func show_ally_ability(ability_name: String, detail: String, color: Color) -> void:
	if not ally_tracker.visible or ally_cast_notice_cooldown > 0.0:
		return
	ally_skill.text = "触发 · " + ability_name
	ally_skill.add_theme_color_override("font_color", color.lightened(0.18))
	ally_role.text = detail
	ally_role.add_theme_color_override("font_color", Color("ecf9f4"))
	ally_cast_flash_left = 1.35
	ally_cast_notice_cooldown = 3.2


func get_ally_ui_snapshot() -> Dictionary:
	return {
		"visible": ally_tracker != null and ally_tracker.visible,
		"title": ally_title.text if ally_title != null else "",
		"badge": ally_badge.text if ally_badge != null else "",
		"role": ally_role.text if ally_role != null else "",
		"ability": ally_skill.text if ally_skill != null else "",
		"cooldown": ally_cooldown.text if ally_cooldown != null else "",
		"status": ally_status.text if ally_status != null else "",
		"tooltip": ally_tracker.tooltip_text if ally_tracker != null else "",
	}


func configure_career(career: Dictionary) -> void:
	var career_id := String(career.get("id", "ops"))
	if hud_art != null:
		hud_art.texture = HUD_OVERLAY_OPSDEV_TEXTURE if career_id == "opsdev" else HUD_OVERLAY_TEXTURE
	career_icon.texture = CareerCatalog.emblem_texture(career_id)
	career_icon.modulate = Color(0.96, 0.98, 1.0, 0.92)
	career_action_accent = Color(String(career.get("color", "56e6dc")))
	last_skill_action_id = ""
	last_ultimate_action_id = ""
	_configure_skill_tray_layout(career_id == "opsdev")
	if opsdev_toolchain_panel != null:
		opsdev_toolchain_panel.visible = career_id == "opsdev"
	if career_skill_slot != null:
		for child in career_skill_slot.get_children():
			if child is PanelContainer and child.has_meta("action_frame"):
				child.add_theme_stylebox_override("panel", _panel_style(Color(0.006, 0.025, 0.04, 0.94), career_action_accent))


func update_career_protocol(text: String, color: Color = Color("ffd36a")) -> void:
	career_protocol_text = text
	career_protocol_label.text = text
	career_protocol_label.add_theme_color_override("font_color", color)
	_refresh_status_tooltip()


func show_artifact_reel(selected_definition: Dictionary, pool_values: Array) -> void:
	if selected_definition.is_empty():
		return
	var pool: Array[Dictionary] = []
	for value in pool_values:
		if value is Dictionary:
			pool.append(Dictionary(value).duplicate(true))
	var selected_id := String(selected_definition.get("id", ""))
	var contains_selected := false
	for definition in pool:
		if String(definition.get("id", "")) == selected_id:
			contains_selected = true
			break
	if not contains_selected:
		pool.append(selected_definition.duplicate(true))
	var package := {
		"selected": selected_definition.duplicate(true),
		"pool": pool,
	}
	if artifact_reel_phase != "idle":
		artifact_reel_queue.append(package)
		return
	_start_artifact_reel(package)


func _start_artifact_reel(package: Dictionary) -> void:
	artifact_reel_selected = Dictionary(package.get("selected", {})).duplicate(true)
	artifact_reel_selected_id = String(artifact_reel_selected.get("id", ""))
	artifact_reel_pool.clear()
	for value in package.get("pool", []):
		if value is Dictionary:
			artifact_reel_pool.append(Dictionary(value).duplicate(true))
	if artifact_reel_pool.is_empty():
		artifact_reel_pool.append(artifact_reel_selected.duplicate(true))
	artifact_reel_phase = "spinning"
	artifact_reel_elapsed = 0.0
	artifact_reel_step_left = 0.0
	artifact_reel_hold_left = 0.0
	artifact_reel_cursor = 0
	artifact_reel_result.text = "正在扫描精英掉落池……"
	artifact_reel_result.add_theme_color_override("font_color", Color("fff1b8"))
	artifact_reel_detail.text = "协议滚轮高速轮询中"
	var accent := Color(String(artifact_reel_selected.get("color", "ffd36a")))
	artifact_reel_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.038, 0.055, 0.98), accent))
	artifact_reel_panel.modulate = Color.WHITE
	artifact_reel_panel.scale = Vector2.ONE * 0.92
	artifact_reel_panel.show()
	_update_artifact_reel_icons()


func _update_artifact_reel(delta: float) -> void:
	if artifact_reel_phase == "idle" or artifact_reel_panel == null:
		return
	if artifact_reel_phase == "spinning":
		artifact_reel_elapsed += delta
		artifact_reel_step_left -= delta
		var progress := clampf(artifact_reel_elapsed / artifact_reel_duration, 0.0, 1.0)
		artifact_reel_panel.scale = Vector2.ONE * lerpf(0.92, 1.0, clampf(progress / 0.16, 0.0, 1.0))
		if artifact_reel_step_left <= 0.0:
			artifact_reel_cursor += 1
			artifact_reel_step_left = lerpf(0.055, 0.22, pow(progress, 1.8))
			_update_artifact_reel_icons()
		for slot_index in range(artifact_reel_icons.size()):
			var stagger := sin(artifact_reel_elapsed * 22.0 + float(slot_index) * 1.7)
			artifact_reel_icons[slot_index].scale = Vector2(1.0, 0.90 + absf(stagger) * 0.10)
			artifact_reel_icons[slot_index].modulate.a = 0.66 + absf(stagger) * 0.34
		if artifact_reel_elapsed >= artifact_reel_duration:
			_finalize_artifact_reel()
		return
	artifact_reel_hold_left = maxf(0.0, artifact_reel_hold_left - delta)
	var center_pulse := 1.0 + sin(artifact_reel_hold_left * 14.0) * 0.025
	artifact_reel_icons[1].scale = Vector2.ONE * center_pulse
	if artifact_reel_hold_left > 0.0:
		return
	artifact_reel_panel.hide()
	artifact_reel_phase = "idle"
	if not artifact_reel_queue.is_empty():
		var next_package: Dictionary = artifact_reel_queue.pop_front()
		_start_artifact_reel(next_package)
		return
	artifact_reel_finished.emit()


func _update_artifact_reel_icons() -> void:
	if artifact_reel_pool.is_empty():
		return
	for slot_index in range(artifact_reel_icons.size()):
		var definition := artifact_reel_pool[(artifact_reel_cursor + slot_index * 3) % artifact_reel_pool.size()]
		_set_artifact_reel_icon(slot_index, definition, false)


func _finalize_artifact_reel() -> void:
	artifact_reel_phase = "result"
	artifact_reel_hold_left = 1.75
	var selected_index := 0
	for index in range(artifact_reel_pool.size()):
		if String(artifact_reel_pool[index].get("id", "")) == artifact_reel_selected_id:
			selected_index = index
			break
	var left_index := (selected_index - 1 + artifact_reel_pool.size()) % artifact_reel_pool.size()
	var right_index := (selected_index + 1) % artifact_reel_pool.size()
	_set_artifact_reel_icon(0, artifact_reel_pool[left_index], false)
	_set_artifact_reel_icon(1, artifact_reel_selected, true)
	_set_artifact_reel_icon(2, artifact_reel_pool[right_index], false)
	var accent := Color(String(artifact_reel_selected.get("color", "ffd36a")))
	artifact_reel_result.text = String(artifact_reel_selected.get("name", artifact_reel_selected_id))
	artifact_reel_result.add_theme_color_override("font_color", accent.lightened(0.18))
	artifact_reel_detail.text = "%s\n靠近拾取 · 每局最多安装 2 件神器" % String(artifact_reel_selected.get("description", "神器协议已确认"))
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().has("--smoke-test"):
		_play_upgrade_chime()


func _set_artifact_reel_icon(slot_index: int, definition: Dictionary, selected: bool) -> void:
	if slot_index < 0 or slot_index >= artifact_reel_icons.size():
		return
	var artifact_id := String(definition.get("id", ""))
	var accent := Color(String(definition.get("color", "ffd36a")))
	artifact_reel_displayed_ids[slot_index] = artifact_id
	artifact_reel_icons[slot_index].texture = ArtifactCatalog.icon_texture(artifact_id)
	artifact_reel_icons[slot_index].modulate = Color.WHITE if selected else Color(0.76, 0.82, 0.86, 0.78)
	artifact_reel_icons[slot_index].scale = Vector2.ONE
	artifact_reel_icon_frames[slot_index].add_theme_stylebox_override(
		"panel",
		_panel_style(Color("050b10"), Color("fff1a8") if selected else accent.darkened(0.38))
	)


func get_artifact_reel_snapshot() -> Dictionary:
	return {
		"visible": artifact_reel_panel != null and artifact_reel_panel.visible,
		"phase": artifact_reel_phase,
		"selected_id": artifact_reel_selected_id,
		"displayed_ids": artifact_reel_displayed_ids.duplicate(),
		"queue": artifact_reel_queue.size(),
		"result": artifact_reel_result.text if artifact_reel_result != null else "",
	}


func show_stack_feedback(title: String, detail: String, accent: Color) -> void:
	feedback_title.text = title
	feedback_title.add_theme_color_override("font_color", accent)
	feedback_detail.text = detail
	feedback_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.08, 0.12, 0.96), accent))
	feedback_flash.color = Color(accent.r, accent.g, accent.b, 0.15)
	feedback_panel.modulate = Color.WHITE
	feedback_panel.scale = Vector2(1.08, 1.08)
	feedback_left = feedback_duration
	feedback_flash.show()
	feedback_panel.show()
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().has("--smoke-test"):
		_play_upgrade_chime()


func _play_upgrade_chime() -> void:
	if feedback_audio.playing:
		return
	feedback_audio.play()


func _build_upgrade_chime_stream() -> AudioStreamWAV:
	var sample_rate := 22050
	var frame_count := int(float(sample_rate) * 0.34)
	var data := PackedByteArray()
	data.resize(frame_count * 2)
	for frame_index in range(frame_count):
		var time := float(frame_index) / float(sample_rate)
		var envelope := minf(1.0, time / 0.018) * clampf((0.34 - time) / 0.16, 0.0, 1.0)
		var frequency := 660.0 if time < 0.13 else (880.0 if time < 0.24 else 1100.0)
		var signed_sample := clampi(int(round(sin(TAU * frequency * time) * envelope * 0.16 * 32767.0)), -32768, 32767)
		var encoded_sample := signed_sample if signed_sample >= 0 else signed_sample + 65536
		data[frame_index * 2] = encoded_sample & 0xff
		data[frame_index * 2 + 1] = (encoded_sample >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream


func _exit_tree() -> void:
	if feedback_audio != null:
		feedback_audio.stop()
		feedback_audio.stream = null


func set_event_message(message: String, color: Color = Color("ffd05a")) -> void:
	event_label.text = message
	event_label.add_theme_color_override("font_color", color)


func update_event_objective(
	event_or_title: Variant,
	objective: String = "",
	current: float = 0.0,
	required: float = 1.0,
	time_left: float = -1.0,
	accent: Color = Color("ffd05a")
) -> void:
	var title := ""
	var badge := "EVENT"
	if event_or_title is Dictionary:
		var state: Dictionary = event_or_title
		var event_id := String(state.get("event_id", state.get("id", "")))
		title = String(state.get("title", state.get("event_name", state.get("name", _event_name(event_id)))))
		badge = String(state.get("badge", "EVENT"))
		objective = String(state.get("objective", state.get("detail", objective)))
		current = float(state.get("current", state.get("progress", current)))
		required = float(state.get("required", state.get("target", required)))
		time_left = float(state.get("time_left", state.get("remaining_time", time_left)))
		var state_color: Variant = state.get("color", accent)
		accent = state_color if state_color is Color else Color(String(state_color))
	else:
		title = String(event_or_title)
	if title.is_empty():
		title = "特殊事件"
	event_objective_title.text = "%s · %s" % [badge, title]
	event_objective_title.add_theme_color_override("font_color", accent)
	event_objective_detail.text = objective if not objective.is_empty() else "完成事件处置目标"
	event_objective_time.text = _format_time(time_left) if time_left >= 0.0 else "--:--"
	event_objective_time.add_theme_color_override("font_color", Color("ff786c") if time_left >= 0.0 and time_left <= 10.0 else Color("ffffff"))
	var has_progress := required > 0.0
	event_objective_bar.visible = has_progress
	event_objective_value.visible = has_progress
	if has_progress:
		event_objective_bar.max_value = maxf(1.0, required)
		event_objective_bar.value = clampf(current, 0.0, event_objective_bar.max_value)
		event_objective_value.text = "%s / %s" % [_format_objective_value(current), _format_objective_value(required)]
	event_objective_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.075, 0.11, 0.95), accent))
	event_objective_panel.show()


func hide_event_objective() -> void:
	event_objective_panel.hide()


func update_boss(phase: int, health: float, maximum: float, clues: int = 0, required: int = 0, combat_stage: int = -1, shield: float = 0.0, shield_maximum: float = 0.0) -> void:
	if phase < 0:
		boss_panel.hide()
		event_label.show()
		return
	event_label.hide()
	boss_panel.show()
	boss_bar.max_value = maxf(1.0, maximum)
	boss_bar.value = health
	match phase:
		0:
			boss_label.text = "FATAL / 分诊中  根因线索 %d / %d" % [clues, required]
			boss_bar.value = 0.0
		1:
			var stage_name := "UPSTREAM 根因已暴露"
			if combat_stage >= 0:
				var stage_names: Array[String] = ["P1 告警扩散", "P2 依赖雪崩", "P3 FATAL 核心"]
				stage_name = stage_names[clampi(combat_stage, 0, stage_names.size() - 1)]
			var shield_text := ""
			if shield > 0.0 and shield_maximum > 0.0:
				shield_text = "  ·  护盾 %.0f / %.0f" % [shield, shield_maximum]
			boss_label.text = "FATAL / %s%s" % [stage_name, shield_text]
		2:
			boss_label.text = "恢复验证中"


func show_upgrade(choices: Array[Dictionary], build_summary: String = "", rerolls: int = 0, architecture_step: int = 0) -> void:
	_clear_modal()
	modal_mode = "upgrade"
	var is_architecture := architecture_step > 0
	var eyebrow := _make_label("ARCHITECTURE DECISION  %d / 2" % architecture_step if is_architecture else "CHANGE WINDOW  ·  全池随机三选一", 13, Color("8aa9bb"))
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_box.add_child(eyebrow)
	var title := _make_label("选择岗位架构" if is_architecture else "选择一项变更", 27, Color("ffd36a") if is_architecture else Color("75f3df"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_box.add_child(title)
	var build_text := build_summary.replace("\n", "  ·  ")
	var subtitle := _make_label("当前构筑  ·  %s" % build_text, 12, Color("8fa8b5"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.custom_minimum_size = Vector2(1080, 25)
	modal_box.add_child(subtitle)

	var card_row := HBoxContainer.new()
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	card_row.add_theme_constant_override("separation", 16)
	card_row.custom_minimum_size = Vector2(1100, 306)
	modal_box.add_child(card_row)
	var first_button: Button
	for choice in choices:
		var button := _make_upgrade_card(choice)
		card_row.add_child(button)
		if first_button == null:
			first_button = button

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 18)
	modal_box.add_child(footer)
	var reroll_button := Button.new()
	reroll_button.text = "重新评审三项  ×%d" % rerolls
	reroll_button.custom_minimum_size = Vector2(220, 38)
	reroll_button.disabled = rerolls <= 0
	reroll_button.pressed.connect(func() -> void: upgrade_reroll_requested.emit())
	footer.add_child(reroll_button)
	var footer_hint := _make_label("新工具受常规槽限制；固有普攻成长与架构签名不占槽位", 12, Color("738f9d"))
	footer.add_child(footer_hint)
	overlay.show()
	if first_button != null:
		first_button.grab_focus()


func show_event_choices(event_data: Dictionary) -> void:
	_clear_modal()
	modal_mode = "event"
	modal_panel.custom_minimum_size = Vector2(1160, 520)
	var event_id := String(event_data.get("id", "release"))
	var accent := _event_color(event_data)
	var eyebrow := _make_label("%s  ·  %s事件  ·  三选一处置策略" % [event_data.get("badge", "EVENT"), event_data.get("category", "特殊")], 13, accent)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_box.add_child(eyebrow)
	var title := _make_label("%s：选择策略" % event_data.get("name", "特殊事件"), 27, Color("f2f8f9"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_box.add_child(title)
	var description := _make_label(String(event_data.get("description", event_data.get("objective", "完成事件处置目标"))), 13, Color("a9bdc9"))
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(1080, 42)
	modal_box.add_child(description)

	var card_row := HBoxContainer.new()
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	card_row.add_theme_constant_override("separation", 16)
	card_row.custom_minimum_size = Vector2(1100, 286)
	modal_box.add_child(card_row)
	var first_button: Button
	var strategies: Array = event_data.get("strategies", [])
	for strategy_value in strategies.slice(0, 3):
		var strategy: Dictionary = strategy_value
		var button := _make_event_strategy_card(event_data, strategy)
		card_row.add_child(button)
		if first_button == null:
			first_button = button
	var footer := _make_label("主目标 · %s    成功 +%d RP  /  部分成功 +%d RP" % [event_data.get("objective", "完成事件目标"), int(event_data.get("success_reward", 0)), int(event_data.get("partial_reward", 0))], 12, Color("809eaa"))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	footer.custom_minimum_size = Vector2(1080, 20)
	modal_box.add_child(footer)
	overlay.show()
	if first_button != null:
		first_button.grab_focus()


func show_release_choices() -> void:
	show_event_choices(EventCatalog.get_by_id("release"))
	modal_mode = "release"


func show_result(victory: bool, summary: String, settlement: Dictionary = {}, career: Dictionary = {}) -> void:
	_clear_modal()
	modal_mode = "result"
	var title := _make_label("事故已恢复" if victory else "值班中断 · 已生成复盘", 30, Color("66f2cf") if victory else Color("ff9b72"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_box.add_child(title)
	var columns := HBoxContainer.new()
	columns.alignment = BoxContainer.ALIGNMENT_CENTER
	columns.add_theme_constant_override("separation", 22)
	columns.custom_minimum_size = Vector2(1080, 310)
	modal_box.add_child(columns)

	var report_panel := PanelContainer.new()
	report_panel.custom_minimum_size = Vector2(510, 300)
	report_panel.add_theme_stylebox_override("panel", _panel_style(Color("101f2b"), Color(String(career.get("color", "56e6dc")))))
	columns.add_child(report_panel)
	var report_margin := MarginContainer.new()
	report_panel.add_child(report_margin)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		report_margin.add_theme_constant_override(side, 16)
	var report_box := VBoxContainer.new()
	report_margin.add_child(report_box)
	report_box.add_theme_constant_override("separation", 8)
	var career_title := _make_label("%s  ·  %s  ·  %s难度" % [career.get("badge", "OPS"), career.get("name", "运维工程师"), difficulty_name], 20, difficulty_color)
	report_box.add_child(career_title)
	var body := _make_label(summary, 15, Color("d4e2e8"))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(470, 102)
	report_box.add_child(body)
	if settlement.has("events"):
		var event_result_text := _event_results_summary(settlement.get("events", []))
		if not event_result_text.is_empty():
			var event_result := _make_label("事件复盘 · " + event_result_text, 14, _event_results_color(settlement.get("events", [])))
			event_result.custom_minimum_size = Vector2(470, 24)
			event_result.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			event_result.tooltip_text = event_result.text
			report_box.add_child(event_result)
	var mastery_rank: Dictionary = settlement.get("mastery_rank", {})
	var mastery_text := "职业履历  +%d  ·  %s" % [int(settlement.get("mastery", 0)), String(mastery_rank.get("title", "见习观察"))]
	if int(mastery_rank.get("next_threshold", -1)) > 0:
		mastery_text += "  %d / %d" % [int(mastery_rank.get("score", 0)), int(mastery_rank["next_threshold"])]
	if bool(settlement.get("rank_up", false)):
		mastery_text = "职级晋升  ·  " + mastery_text
	var mastery := _make_label(mastery_text, 15, Color("ffd36a") if bool(settlement.get("rank_up", false)) else Color("8fc9ff"))
	report_box.add_child(mastery)
	var unlock_ids: Array = settlement.get("unlocks", [])
	var unlock_names: Array[String] = []
	for career_id in unlock_ids:
		unlock_names.append(String(CareerCatalog.get_by_id(String(career_id))["name"]))
	var unlock_lines: Array[String] = []
	if not unlock_names.is_empty():
		unlock_lines.append("新职业解锁 · %s" % " / ".join(unlock_names))
	var difficulty_unlock_names: Array[String] = []
	for unlocked_difficulty_id in settlement.get("difficulty_unlocks", []):
		difficulty_unlock_names.append(String(DifficultyCatalog.get_by_id(String(unlocked_difficulty_id))["name"]))
	if not difficulty_unlock_names.is_empty():
		unlock_lines.append("新难度解锁 · %s" % " / ".join(difficulty_unlock_names))
	var unlock_text := "\n".join(unlock_lines) if not unlock_lines.is_empty() else "职业与难度进度已记录到档案"
	var unlock_label := _make_label(unlock_text, 15, Color("ffd36a") if not unlock_lines.is_empty() else Color("7896a5"))
	unlock_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report_box.add_child(unlock_label)

	var reward_panel := PanelContainer.new()
	reward_panel.custom_minimum_size = Vector2(510, 300)
	reward_panel.add_theme_stylebox_override("panel", _panel_style(Color("101f2b"), Color("ffd36a")))
	columns.add_child(reward_panel)
	var reward_margin := MarginContainer.new()
	reward_panel.add_child(reward_margin)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		reward_margin.add_theme_constant_override(side, 16)
	var reward_box := VBoxContainer.new()
	reward_margin.add_child(reward_box)
	reward_box.add_theme_constant_override("separation", 5)
	var reward_title := _make_label("复盘点 RP  +%d" % int(settlement.get("total", 0)), 22, Color("ffd36a"))
	reward_box.add_child(reward_title)
	for item in settlement.get("breakdown", []):
		var row := HBoxContainer.new()
		var label := _make_label(String(item.get("label", "奖励")), 14, Color("b9cad1"))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value := _make_label("+%d" % int(item.get("value", 0)), 14, Color("f4d77a"))
		row.add_child(label)
		row.add_child(value)
		reward_box.add_child(row)
	var balance := _make_label("当前余额  %d RP" % int(settlement.get("balance", 0)), 15, Color("ffffff"))
	reward_box.add_child(balance)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	modal_box.add_child(actions)
	var retry_button := Button.new()
	retry_button.text = "同职业再来一局"
	retry_button.custom_minimum_size = Vector2(250, 46)
	retry_button.pressed.connect(func() -> void: restart_requested.emit())
	actions.add_child(retry_button)
	var career_button := Button.new()
	career_button.text = "更换职业"
	career_button.custom_minimum_size = Vector2(250, 46)
	career_button.pressed.connect(func() -> void: career_select_requested.emit())
	actions.add_child(career_button)
	var menu_button := Button.new()
	menu_button.text = "返回值班大厅"
	menu_button.custom_minimum_size = Vector2(250, 46)
	menu_button.pressed.connect(func() -> void: main_menu_requested.emit())
	actions.add_child(menu_button)
	overlay.show()
	retry_button.grab_focus()


func show_pause_menu(career: Dictionary, build_summary: String) -> void:
	_clear_modal()
	modal_mode = "pause"
	modal_panel.custom_minimum_size = Vector2(720, 450)
	var eyebrow := _make_label("CHANGE FREEZE  ·  生产环境已暂停", 13, Color("8aa9bb"))
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_box.add_child(eyebrow)
	var title := _make_label("值班菜单", 30, Color(String(career.get("color", "56e6dc"))))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_box.add_child(title)
	var career_label := _make_label("%s  ·  %s  ·  %s难度" % [career.get("badge", "OPS"), career.get("name", "运维工程师"), difficulty_name], 18, difficulty_color)
	career_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_box.add_child(career_label)
	var build := _make_label(build_summary, 13, Color("86a8b7"))
	build.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	build.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	build.custom_minimum_size = Vector2(640, 72)
	modal_box.add_child(build)
	var resume_button := Button.new()
	resume_button.text = "继续处理事故"
	resume_button.custom_minimum_size = Vector2(520, 50)
	resume_button.pressed.connect(func() -> void: resume_requested.emit())
	modal_box.add_child(resume_button)
	var restart_button := Button.new()
	restart_button.text = "重新开始本班次"
	restart_button.custom_minimum_size = Vector2(520, 46)
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	modal_box.add_child(restart_button)
	var lobby_button := Button.new()
	lobby_button.text = "放弃本班次并返回大厅  ·  本局不结算"
	lobby_button.custom_minimum_size = Vector2(520, 46)
	lobby_button.pressed.connect(func() -> void: main_menu_requested.emit())
	modal_box.add_child(lobby_button)
	overlay.show()
	resume_button.grab_focus()


func hide_modal() -> void:
	modal_mode = ""
	modal_panel.custom_minimum_size = Vector2(1160, 520)
	overlay.hide()


func _unhandled_input(event: InputEvent) -> void:
	var keyboard_pause: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE
	var controller_pause: bool = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START
	if not keyboard_pause and not controller_pause:
		return
	if modal_mode == "pause":
		resume_requested.emit()
	elif modal_mode.is_empty() and not overlay.visible:
		pause_requested.emit()
	get_viewport().set_input_as_handled()


func set_performance(text: String, visible: bool) -> void:
	performance_label.text = text
	performance_label.visible = visible


func _on_upgrade_button(upgrade_id: String) -> void:
	upgrade_selected.emit(upgrade_id)


func _on_event_strategy_button(event_id: String, strategy_id: String) -> void:
	event_strategy_selected.emit(event_id, strategy_id)
	if event_id == "release":
		release_selected.emit(strategy_id)


func _on_release_button(choice_id: String) -> void:
	_on_event_strategy_button("release", choice_id)


func _clear_modal() -> void:
	for child in modal_box.get_children():
		modal_box.remove_child(child)
		# A selected button can still be signal-locked while the next queued
		# upgrade opens, so defer destruction until the frame is complete.
		child.queue_free()


func _make_event_strategy_card(event_data: Dictionary, strategy: Dictionary) -> Button:
	var event_id := String(event_data.get("id", "release"))
	var strategy_id := String(strategy.get("id", ""))
	var accent := _event_color(event_data)
	var risk_tier := _event_risk_tier(strategy)
	var risk_color := _event_risk_color(risk_tier)
	var button := Button.new()
	button.set_meta("event_strategy_card", true)
	button.set_meta("event_id", event_id)
	button.set_meta("strategy_id", strategy_id)
	button.custom_minimum_size = Vector2(342, 310)
	button.clip_contents = true
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", _upgrade_card_style(Color("101c28"), risk_color, 2))
	button.add_theme_stylebox_override("hover", _upgrade_card_style(Color("172a38"), accent.lightened(0.12), 3))
	button.add_theme_stylebox_override("focus", _upgrade_card_style(Color("172a38"), accent.lightened(0.22), 4))
	button.add_theme_stylebox_override("pressed", _upgrade_card_style(Color("0b151f"), accent, 4))
	button.pressed.connect(_on_event_strategy_button.bind(event_id, strategy_id))
	var persona := CoworkerCatalog.get_by_id(String(strategy.get("persona_id", "product")))
	button.tooltip_text = "%s\n%s\n协作对象：%s / %s" % [strategy.get("name", strategy_id), strategy.get("detail", event_data.get("objective", "")), persona.get("name", "协作伙伴"), persona.get("ability", "协作能力")]

	var margin := MarginContainer.new()
	button.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 11)
	margin.add_theme_constant_override("margin_bottom", 11)
	var box := VBoxContainer.new()
	margin.add_child(box)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)

	var risk := _make_label(_event_risk_label(risk_tier), 12, risk_color)
	risk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(risk)
	var badge := _make_label("[ %s ]" % event_data.get("badge", "EVENT"), 19, accent)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.custom_minimum_size = Vector2(300, 25)
	box.add_child(badge)
	var name := _make_label(String(strategy.get("name", strategy_id)), 18, Color("edf7f8"))
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.custom_minimum_size = Vector2(300, 36)
	box.add_child(name)
	var detail := _make_label(String(strategy.get("detail", "选择该策略处置事件")), 13, Color("c7d8df"))
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size = Vector2(300, 58)
	box.add_child(detail)
	var collaborator_color := CoworkerCatalog.color_for(String(persona.get("id", "product")))
	var collaborator := _make_label("协作对象 · %s / %s" % [persona.get("name", "协作伙伴"), persona.get("ability", "协作能力")], 12, collaborator_color)
	collaborator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	collaborator.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	collaborator.custom_minimum_size = Vector2(300, 24)
	box.add_child(collaborator)
	var divider := HSeparator.new()
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(divider)
	var objective_text := String(strategy.get("objective", event_data.get("objective", "完成事件目标")))
	if strategy.has("targets"):
		objective_text += " · %d 个目标" % int(strategy.get("targets", 0))
	var objective := _make_label("目标 · " + objective_text, 12, Color("a9bdc9"))
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective.custom_minimum_size = Vector2(300, 38)
	box.add_child(objective)
	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 20)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(stats)
	var multiplier := _make_label("敌群 ×%.2f" % float(strategy.get("spawn_multiplier", 1.0)), 12, accent.lightened(0.12))
	stats.add_child(multiplier)
	var duration := _make_label("窗口 %d 秒" % int(round(float(strategy.get("duration", 60.0)))), 12, Color("d5e4e8"))
	stats.add_child(duration)
	var risk_bonus := int(strategy.get("risk_bonus", 0))
	var reward_text := "额外风险回报 +%d RP" % risk_bonus if risk_bonus > 0 else "标准事件回报"
	var reward := _make_label(reward_text, 12, Color("ffd36a") if risk_bonus > 0 else Color("7896a5"))
	reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(reward)
	return button


func _event_color(event_data: Dictionary) -> Color:
	var value: Variant = event_data.get("color", Color("75f3df"))
	return value if value is Color else Color(String(value))


func _event_risk_tier(strategy: Dictionary) -> int:
	var risk_bonus := int(strategy.get("risk_bonus", 0))
	var pressure := float(strategy.get("spawn_multiplier", 1.0))
	if risk_bonus >= 8 or pressure >= 1.20:
		return 3
	if risk_bonus >= 4 or pressure > 1.0:
		return 2
	return 1


func _event_risk_color(tier: int) -> Color:
	match tier:
		3: return Color("ff786c")
		2: return Color("ffd36a")
	return Color("65e890")


func _event_risk_label(tier: int) -> String:
	match tier:
		3: return "风险 Ⅲ  ·  高压变更"
		2: return "风险 Ⅱ  ·  审慎推进"
	return "风险 Ⅰ  ·  受控处置"


func _format_objective_value(value: float) -> String:
	return "%d" % int(round(value)) if is_equal_approx(value, round(value)) else "%.1f" % value


func _event_name(event_id: String) -> String:
	for event in EventCatalog.all():
		if String(event.get("id", "")) == event_id:
			return String(event.get("name", event_id))
	return event_id if not event_id.is_empty() else "特殊事件"


func _event_strategy_name(event_id: String, strategy_id: String) -> String:
	for event in EventCatalog.all():
		if String(event.get("id", "")) != event_id:
			continue
		for strategy in event.get("strategies", []):
			if String(strategy.get("id", "")) == strategy_id:
				return String(strategy.get("name", strategy_id))
	return strategy_id


func _event_result_entries(events: Variant) -> Array:
	if events is Array:
		return events
	if events is Dictionary:
		var event_dictionary: Dictionary = events
		if event_dictionary.has("event_id") or event_dictionary.has("id") or event_dictionary.has("status"):
			return [event_dictionary]
		var entries: Array = []
		for event_id_value in event_dictionary:
			var value: Variant = event_dictionary[event_id_value]
			if value is Dictionary:
				var entry: Dictionary = value.duplicate()
				if not entry.has("event_id"):
					entry["event_id"] = String(event_id_value)
				entries.append(entry)
			else:
				entries.append({"event_id": String(event_id_value), "status": String(value)})
		return entries
	if events is String and not String(events).is_empty():
		return [String(events)]
	return []


func _event_results_summary(events: Variant) -> String:
	var summaries: Array[String] = []
	for value in _event_result_entries(events):
		if value is String:
			summaries.append(String(value))
			continue
		if not value is Dictionary:
			continue
		var event: Dictionary = value
		var event_id := String(event.get("event_id", event.get("id", "")))
		var event_name := String(event.get("event_name", event.get("name", _event_name(event_id))))
		var strategy_id := String(event.get("strategy_id", event.get("strategy", "")))
		var strategy_name := String(event.get("strategy_name", _event_strategy_name(event_id, strategy_id)))
		var status := String(event.get("status", event.get("event_status", event.get("outcome", event.get("result", "已记录")))))
		if status == "已记录" and event.has("success"):
			status = "success" if bool(event.get("success", false)) else "failure"
		var outcome_text := String(event.get("outcome_text", ""))
		var result_text := outcome_text if not outcome_text.is_empty() else _localized_event_status(status)
		var label := event_name
		if not strategy_name.is_empty():
			label += " / " + strategy_name
		summaries.append("%s：%s" % [label, result_text])
	return "  ｜  ".join(summaries)


func _localized_event_status(status: String) -> String:
	match status.to_lower():
		"success", "succeeded", "complete", "completed": return "成功"
		"partial", "partial_success": return "部分成功"
		"failure", "failed", "fail": return "失败"
	return status


func _event_results_color(events: Variant) -> Color:
	var has_partial := false
	for value in _event_result_entries(events):
		if not value is Dictionary:
			continue
		var event: Dictionary = value
		var status := String(event.get("status", event.get("event_status", event.get("outcome", event.get("result", ""))))).to_lower()
		if status in ["failure", "failed", "fail"]:
			return Color("ff8b7d")
		if status in ["partial", "partial_success"]:
			has_partial = true
	return Color("ffd36a") if has_partial else Color("65e890")


func _make_upgrade_card(choice: Dictionary) -> Button:
	var accent: Color = choice.get("color", Color("75f3df"))
	var rarity_tier := int(choice.get("rarity_tier", 0))
	var rarity_color := _rarity_color(rarity_tier)
	var button := Button.new()
	button.set_meta("upgrade_card", true)
	button.custom_minimum_size = Vector2(342, 306)
	button.clip_contents = true
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", _upgrade_card_style(Color("101c28"), rarity_color, 2))
	button.add_theme_stylebox_override("hover", _upgrade_card_style(Color("172a38"), accent.lightened(0.12), 3))
	button.add_theme_stylebox_override("focus", _upgrade_card_style(Color("172a38"), accent.lightened(0.22), 4))
	button.add_theme_stylebox_override("pressed", _upgrade_card_style(Color("0b151f"), accent, 4))
	button.pressed.connect(_on_upgrade_button.bind(String(choice["id"])))
	button.tooltip_text = "%s\n%s" % [choice.get("title", choice.get("name", "")), choice.get("description", "")]

	var margin := MarginContainer.new()
	button.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	var box := VBoxContainer.new()
	margin.add_child(box)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)

	var rarity := _make_label("%s   ·   %s" % [choice.get("rarity", "标准变更"), choice.get("route", "通用运维")], 12, rarity_color)
	rarity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(rarity)
	var skill_texture := _skill_icon(String(choice.get("id", "")))
	if skill_texture != null:
		var icon_center := CenterContainer.new()
		icon_center.custom_minimum_size = Vector2(300, 58)
		icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon_center)
		var icon_image := TextureRect.new()
		icon_center.add_child(icon_image)
		icon_image.texture = skill_texture
		icon_image.custom_minimum_size = Vector2(56, 56)
		icon_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		var icon := _make_label(String(choice.get("icon", "OPS")), 22, accent)
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.custom_minimum_size = Vector2(300, 27)
		box.add_child(icon)
	var name := _make_label(String(choice.get("name", choice.get("id", ""))), 18, Color("edf7f8"))
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.custom_minimum_size = Vector2(300, 42)
	box.add_child(name)
	var archetype := _make_label("[ %s ]" % choice.get("archetype", "通用"), 12, accent.lightened(0.12))
	archetype.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(archetype)
	var description := _make_label(String(choice.get("description", "")), 13, Color("c7d8df"))
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(300, 62)
	box.add_child(description)
	var synergy := _make_label("协同提示 · %s" % choice.get("synergy", "补强当前构筑"), 11, Color("8fb5c2"))
	synergy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	synergy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	synergy.custom_minimum_size = Vector2(300, 32)
	box.add_child(synergy)
	var slot := _make_label(String(choice.get("slot_text", "能力叠加")), 11, Color("698b99"))
	slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(slot)
	return button


func _rarity_color(tier: int) -> Color:
	match tier:
		1: return Color("5aa7ff")
		2: return Color("c276ff")
		3: return Color("ffd45e")
	return Color("5ed7cb")


func _skill_icon(skill_id: String) -> Texture2D:
	var resolved_id := skill_id
	match skill_id:
		"idempotency", "iac", "arch_autoscale": resolved_id = "bash"
		"capacity", "arch_oncall": resolved_id = "wrench"
		"arch_zero_trust": resolved_id = "rule_chain"
		"arch_query": resolved_id = "lock_zone"
	var index := SKILL_ICON_ORDER.find(resolved_id)
	if index < 0:
		return null
	var columns := 5
	var cell_size := Vector2(float(SKILL_ICON_TEXTURE.get_width()) / float(columns), float(SKILL_ICON_TEXTURE.get_height()) / 2.0)
	var atlas := AtlasTexture.new()
	atlas.atlas = SKILL_ICON_TEXTURE
	atlas.region = Rect2(Vector2(float(index % columns), floor(float(index) / float(columns))) * cell_size + Vector2(2, 2), cell_size - Vector2(4, 4))
	return atlas


func _coworker_portrait(persona_id: String) -> Texture2D:
	var index := clampi(int(CoworkerCatalog.get_by_id(persona_id).get("sprite_index", 2)), 0, 7)
	var columns := 4
	var cell_size := Vector2(float(COWORKER_SPRITE_TEXTURE.get_width()) / float(columns), float(COWORKER_SPRITE_TEXTURE.get_height()) / 2.0)
	var atlas := AtlasTexture.new()
	atlas.atlas = COWORKER_SPRITE_TEXTURE
	atlas.region = Rect2(Vector2(float(index % columns), floor(float(index) / float(columns))) * cell_size + Vector2(2, 2), cell_size - Vector2(4, 4))
	return atlas


func _upgrade_card_style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 9
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = 7
	return style


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style


func _bar_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	return style


func _format_time(seconds: float) -> String:
	var total := maxi(0, int(seconds))
	return "%02d:%02d" % [total / 60, total % 60]
