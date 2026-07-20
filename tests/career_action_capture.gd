extends SceneTree

var run: Node
var frame_count := 0
var career_id := "network"


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--career="):
			career_id = argument.trim_prefix("--career=")
	call_deferred("_build")


func _build() -> void:
	var profile := get_root().get_node("ProfileStore")
	profile.reset_for_tests()
	if career_id != "ops":
		profile.unlock_career(career_id)
	profile.select_career(career_id)
	run = load("res://scenes/run.tscn").instantiate()
	get_root().add_child(run)
	run.set_process(false)
	var player: CharacterBody2D = run.get_node("Player")
	player.global_position = Vector2(1200, 675)
	player.set_physics_process(false)
	var swarm: Node2D = run.get_node("SwarmWorld")
	swarm.set_physics_process(false)
	swarm.call("clear_all")
	run.get_node("LootWorld").set_physics_process(false)
	for index in range(44):
		var angle := TAU * float(index) / 44.0
		var distance := 155.0 + float(index % 5) * 78.0
		var kind: int = int([SwarmWorld.EnemyKind.HTTP_404, SwarmWorld.EnemyKind.NXDOMAIN, SwarmWorld.EnemyKind.ENOSPC, SwarmWorld.EnemyKind.BUG, SwarmWorld.EnemyKind.TIMEOUT_408][index % 5])
		swarm.call("spawn_enemy", kind, player.global_position + Vector2.from_angle(angle) * distance)
	var actions: Node2D = run.get_node("CareerActionSystem")
	actions.set_physics_process(false)
	actions.debug_disable_auto_signature = true
	for _cast in range(2 if career_id == "ops" else 1):
		actions.call("debug_cast_signature")
	actions.call("try_skill", Vector2.RIGHT)
	player.global_position = Vector2(1200, 675)
	actions.call("try_ultimate")
	var hud: CanvasLayer = run.get_node("HUD")
	hud.call("update_career_actions", actions.call("get_action_snapshot"))
	hud.call("set_event_message", "%s · 固有攻击 / 小技能 / 大招" % String(run.career.get("name", career_id)), Color(String(run.career.get("color", "56e6dc"))))
	hud.call("update_radar", player.global_position, swarm.call("get_radar_snapshot", 72))
	run.call("_refresh_build_summary")


func _process(_delta: float) -> bool:
	if run == null:
		return false
	frame_count += 1
	if frame_count < 18:
		return false
	var image := get_root().get_viewport().get_texture().get_image()
	var output_path := "/private/tmp/it_battle_actions_%s.png" % career_id
	var save_error := image.save_png(output_path)
	print("CAREER_ACTION_CAPTURE %s size=%s error=%d" % [output_path, image.get_size(), save_error])
	quit(0 if save_error == OK else 1)
	return true
