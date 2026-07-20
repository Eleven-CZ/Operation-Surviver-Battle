extends SceneTree

var run: Node
var frame_count := 0


func _initialize() -> void:
	call_deferred("_build_run")


func _build_run() -> void:
	var profile := get_root().get_node("ProfileStore")
	profile.reset_for_tests()
	profile.unlock_career("network")
	profile.select_career("network")
	run = load("res://scenes/run.tscn").instantiate()
	get_root().add_child(run)


func _process(_delta: float) -> bool:
	if run == null:
		return false
	frame_count += 1
	if frame_count < 18:
		return false
	var image := get_root().get_viewport().get_texture().get_image()
	var output_path := "/private/tmp/it_battle_run_network.png"
	var save_error := image.save_png(output_path)
	print("RUN_CAPTURE %s size=%s error=%d" % [output_path, image.get_size(), save_error])
	quit(0 if save_error == OK else 1)
	return true
