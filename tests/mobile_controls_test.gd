extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var profile := get_root().get_node("ProfileStore")
	profile.reset_for_tests()
	var run: Node = load("res://scenes/run.tscn").instantiate()
	get_root().add_child(run)
	var hud: CanvasLayer = run.get_node("HUD")
	var player: CharacterBody2D = run.get_node("Player")
	var projection: Node2D = run.get_node("PressureProjection")
	var snapshot: Dictionary = hud.call("get_mobile_controls_snapshot")
	var ios_icon: Texture2D = load("res://assets/icons/ios_app_icon.png")
	_require(ios_icon != null and ios_icon.get_width() == 1024 and ios_icon.get_height() == 1024, "iOS export icon is present at 1024x1024")
	_require(bool(snapshot.get("visible", false)), "mobile controls are visible with the mobile test feature")
	_require(bool(snapshot.get("joystick", false)), "mobile HUD exposes a virtual joystick")
	_require(bool(snapshot.get("interact", false)), "mobile HUD exposes hold-to-align interaction")
	_require(bool(snapshot.get("pause", false)), "mobile HUD exposes a pause button")
	_require(Rect2(snapshot.get("joystick_rect", Rect2())).position.x >= 40.0, "virtual joystick keeps a landscape safe-area margin")
	_require(Rect2(snapshot.get("pause_rect", Rect2())).end.x <= 1240.0, "pause control keeps a landscape safe-area margin")

	hud.emit_signal("mobile_movement_changed", Vector2(0.75, -0.25))
	_require(Vector2(player.touch_input_vector).is_equal_approx(Vector2(0.75, -0.25)), "virtual joystick reaches player movement")
	hud.emit_signal("mobile_interaction_changed", true)
	_require(bool(projection.touch_interact), "touch interaction reaches pressure projection alignment")
	hud.call("reset_mobile_controls")
	_require(Vector2(player.touch_input_vector).is_zero_approx(), "reset releases virtual movement")
	_require(not bool(projection.touch_interact), "reset releases touch interaction")

	get_root().remove_child(run)
	run.free()
	print("MOBILE_CONTROLS_TEST_PASS joystick=ok interaction=ok pause=ok")
	quit(0)


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("MOBILE_CONTROLS_TEST_FAIL: " + message)
	paused = false
	quit(1)
