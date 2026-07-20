extends SceneTree

var menu: Control
var frame_count := 0
var requested_tab := "home"
var requested_difficulty := ""


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-tab="):
			requested_tab = argument.trim_prefix("--capture-tab=")
		elif argument.begins_with("--capture-difficulty="):
			requested_difficulty = argument.trim_prefix("--capture-difficulty=")
	menu = load("res://scenes/main_menu.tscn").instantiate()
	get_root().add_child(menu)


func _process(_delta: float) -> bool:
	frame_count += 1
	if frame_count == 1:
		get_root().get_node("ProfileStore").reset_for_tests()
		menu.call("_show_home")
	if frame_count == 3:
		match requested_tab:
			"careers": menu.call("_show_careers")
			"runbook": menu.call("_show_runbook")
			"settings": menu.call("_show_settings")
			"brief":
				if not requested_difficulty.is_empty():
					var profile := get_root().get_node("ProfileStore")
					profile.unlock_all_progression()
					profile.select_difficulty(requested_difficulty)
				menu.call("_show_brief", "ops")
	if frame_count < 10:
		return false
	var image := get_root().get_viewport().get_texture().get_image()
	var output_path := "/private/tmp/it_battle_menu_%s.png" % requested_tab
	var save_error := image.save_png(output_path)
	print("MENU_CAPTURE %s size=%s error=%d" % [output_path, image.get_size(), save_error])
	quit(0 if save_error == OK else 1)
	return true
