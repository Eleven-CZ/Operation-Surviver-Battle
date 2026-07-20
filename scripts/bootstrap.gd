extends Node


func _ready() -> void:
	get_tree().paused = false
	var target := "res://scenes/run.tscn" if OS.get_cmdline_user_args().has("--smoke-test") else "res://scenes/main_menu.tscn"
	get_tree().call_deferred("change_scene_to_file", target)
