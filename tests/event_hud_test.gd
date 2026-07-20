extends SceneTree

const EventCatalog := preload("res://scripts/event_catalog.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var hud_script: Script = load("res://scripts/hud.gd")
	var hud: CanvasLayer = hud_script.new()
	get_root().add_child(hud)
	await process_frame

	var captured := {"event_id": "", "strategy_id": "", "release_id": ""}
	hud.event_strategy_selected.connect(func(event_id: String, strategy_id: String) -> void:
		captured["event_id"] = event_id
		captured["strategy_id"] = strategy_id
	)
	hud.release_selected.connect(func(strategy_id: String) -> void:
		captured["release_id"] = strategy_id
	)

	hud.show_event_choices(EventCatalog.get_by_id("version_update"))
	await process_frame
	var cards := _event_cards(hud)
	_require(cards.size() == 3, "generic event chooser renders three horizontal strategy cards")
	_require(cards[0].global_position.x < cards[1].global_position.x and cards[1].global_position.x < cards[2].global_position.x, "event cards are laid out horizontally")
	cards[1].emit_signal("pressed")
	_require(captured["event_id"] == "version_update", "generic selection emits the event id")
	_require(captured["strategy_id"] == "in_place", "generic selection emits the strategy id")
	_require(captured["release_id"].is_empty(), "non-release event does not emit the legacy release signal")

	hud.show_release_choices()
	await process_frame
	cards = _event_cards(hud)
	_require(cards.size() == 3, "release wrapper uses the generic three-card chooser")
	cards[0].emit_signal("pressed")
	_require(captured["event_id"] == "release" and captured["strategy_id"] == "canary", "release wrapper emits the generic event signal")
	_require(captured["release_id"] == "canary", "release wrapper preserves the legacy release signal")

	hud.hide_modal()
	hud.update_event_objective({
		"event_id": "troubleshoot",
		"title": "线上救火",
		"badge": "P1",
		"objective": "收集根因证据",
		"current": 4,
		"required": 8,
		"time_left": 42.0,
		"color": "ff9b72",
	})
	hud.update_boss(1, 75.0, 100.0)
	await process_frame
	_require(hud.event_objective_panel.visible, "event objective tracker is persistent outside the modal")
	_require(is_equal_approx(hud.event_objective_bar.value, 4.0), "event objective tracker displays current progress")
	_require(hud.event_objective_value.text == "4 / 8", "event objective tracker displays the target")
	_require(not hud.event_objective_panel.get_global_rect().intersects(hud.boss_panel.get_global_rect()), "event objective tracker does not overlap the boss panel at 1280x720")
	hud.hide_event_objective()
	_require(not hud.event_objective_panel.visible, "event objective tracker can be hidden")

	hud.show_result(true, "事故核心已关闭。", {
		"total": 20,
		"balance": 20,
		"events": [
			{"event_id": "version_update", "strategy_id": "rolling", "status": "partial"},
		],
	}, {})
	await process_frame
	var found_event_result := false
	for node in hud.modal_box.find_children("*", "Label", true, false):
		if String(node.text).contains("事件复盘 · 版本更新 / 滚动更新：部分成功"):
			found_event_result = true
			break
	_require(found_event_result, "result screen renders the actual event outcome from settlement.events")

	print("EVENT_HUD_TEST_PASS cards=3 objective=4/8 result=partial")
	quit(0)


func _event_cards(hud: Node) -> Array:
	var cards: Array = []
	for node in hud.modal_box.find_children("*", "Button", true, false):
		if node.has_meta("event_strategy_card"):
			cards.append(node)
	return cards


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("EVENT_HUD_TEST_FAIL: " + message)
	quit(1)
