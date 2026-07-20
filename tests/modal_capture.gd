extends SceneTree

var run: Node
var frame_count := 0
var modal_kind := "upgrade"


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--modal="):
			modal_kind = argument.trim_prefix("--modal=")
	call_deferred("_build")


func _build() -> void:
	var profile := get_root().get_node("ProfileStore")
	profile.reset_for_tests()
	profile.select_event("version_update")
	run = load("res://scenes/run.tscn").instantiate()
	get_root().add_child(run)
	if modal_kind == "event":
		run.call("_start_event_prompt")
	else:
		run.call("_on_xp_collected", int(run.current_xp_required))


func _process(_delta: float) -> bool:
	if run == null:
		return false
	frame_count += 1
	if frame_count < 16:
		return false
	var image := get_root().get_viewport().get_texture().get_image()
	var output_path := "/private/tmp/it_battle_modal_%s.png" % modal_kind
	var save_error := image.save_png(output_path)
	print("MODAL_CAPTURE %s size=%s error=%d" % [output_path, image.get_size(), save_error])
	paused = false
	quit(0 if save_error == OK else 1)
	return true
