extends SceneTree

const ArtifactCatalog := preload("res://scripts/artifact_catalog.gd")

var run: Node
var frame_count := 0


func _initialize() -> void:
	call_deferred("_build")


func _build() -> void:
	var profile := get_root().get_node("ProfileStore")
	profile.reset_for_tests()
	run = load("res://scenes/run.tscn").instantiate()
	get_root().add_child(run)
	var player: Node2D = run.get_node("Player")
	run.get_node("LootWorld").call("spawn_artifact", player.global_position + Vector2(540.0, 220.0), "rm_rf")
	var selected := ArtifactCatalog.get_by_id("drop_database_run")
	run.get_node("HUD").call("show_artifact_reel", selected, ArtifactCatalog.all())


func _process(_delta: float) -> bool:
	if run == null:
		return false
	frame_count += 1
	if frame_count == 4:
		run.get_node("HUD").call("_update_artifact_reel", 2.0)
	if frame_count < 12:
		return false
	if DisplayServer.get_name() == "headless":
		push_error("ARTIFACT_REEL_CAPTURE requires a rendering display; headless mode is unsupported")
		quit(1)
		return true
	var viewport_texture := get_root().get_viewport().get_texture()
	if viewport_texture == null:
		push_error("ARTIFACT_REEL_CAPTURE requires a rendering display; viewport texture is unavailable")
		quit(1)
		return true
	var image := viewport_texture.get_image()
	if image == null or image.is_empty():
		push_error("ARTIFACT_REEL_CAPTURE requires a rendering display; viewport image is unavailable")
		quit(1)
		return true
	var output_path := "/private/tmp/it_battle_artifact_reel.png"
	var save_error := image.save_png(output_path)
	print("ARTIFACT_REEL_CAPTURE %s size=%s error=%d" % [output_path, image.get_size(), save_error])
	quit(0 if save_error == OK else 1)
	return true
