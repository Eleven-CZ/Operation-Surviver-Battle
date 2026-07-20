extends SceneTree

var run: Node
var frame_count := 0


func _initialize() -> void:
	call_deferred("_build_showcase")


func _build_showcase() -> void:
	var profile := get_root().get_node("ProfileStore")
	profile.reset_for_tests()
	profile.unlock_career("security")
	profile.select_career("security")
	profile.select_event("backup_restore")
	run = load("res://scenes/run.tscn").instantiate()
	get_root().add_child(run)
	run.set_process(false)
	var player: Node2D = run.get_node("Player")
	player.global_position = Vector2(1200, 675)
	player.set_physics_process(false)
	var career_actions: Node2D = run.get_node("CareerActionSystem")
	career_actions.set_physics_process(false)
	career_actions.debug_disable_auto_signature = true
	var swarm: Node = run.get_node("SwarmWorld")
	swarm.set_physics_process(false)
	swarm.call("clear_all")
	run.get_node("LootWorld").set_physics_process(false)
	var normal_kinds := [
		SwarmWorld.EnemyKind.HTTP_404,
		SwarmWorld.EnemyKind.NXDOMAIN,
		SwarmWorld.EnemyKind.ENOSPC,
		SwarmWorld.EnemyKind.BUG,
		SwarmWorld.EnemyKind.TIMEOUT_408,
	]
	for index in range(35):
		var angle := TAU * float(index) / 35.0
		var distance := 185.0 + float(index % 4) * 62.0
		swarm.call("spawn_enemy", normal_kinds[index % normal_kinds.size()], player.global_position + Vector2.from_angle(angle) * distance)
	swarm.call("spawn_enemy", SwarmWorld.EnemyKind.ELITE_502, Vector2(835, 545))
	swarm.call("spawn_enemy", SwarmWorld.EnemyKind.ELITE_OOM, Vector2(1575, 565))
	# Keep the complete FATAL silhouette below the native Boss alert panel so the
	# hierarchy can be judged in one screenshot instead of clipping its crown.
	swarm.call("spawn_enemy", SwarmWorld.EnemyKind.INCIDENT_CORE, Vector2(1215, 455))
	var projection: Node2D = run.get_node("PressureProjection")
	projection.set_physics_process(false)
	projection.call("set_persona", "product")
	projection.call("start_projection", Vector2(1455, 795))
	projection.call("take_shell_damage", 90.0)
	var hud: CanvasLayer = run.get_node("HUD")
	hud.call("show_pressure_persona", "product", "产品经理", false)
	hud.call("set_event_message", "P0 演示 · 普通故障 / 精英 / FATAL 层级验收", Color("ff9b72"))
	hud.call("update_event_objective", {
		"event_id": "backup_restore",
		"title": "时间点恢复",
		"badge": "RTO",
		"objective": "保护 RESTORE NODE · 完整性 78%",
		"current": 12,
		"required": 18,
		"time_left": 38.0,
		"color": "65e890",
	})
	hud.call("update_boss", 0, 1600.0, 1600.0, 3, 8)
	var showcase_loadout: Array[Dictionary] = [
		{"id": "bash", "level": 4, "name": "Bash"},
		{"id": "ping", "level": 3, "name": "Ping"},
		{"id": "firewall", "level": 3, "name": "Firewall"},
		{"id": "lock_zone", "level": 2, "name": "Lock Zone"},
		{"id": "worker", "level": 2, "name": "Worker"},
	]
	hud.call("update_skill_loadout", showcase_loadout)
	career_actions.call("debug_cast_signature")
	career_actions.call("try_skill", Vector2.RIGHT)
	player.global_position = Vector2(1200, 675)
	career_actions.call("try_ultimate")
	hud.call("update_career_actions", career_actions.call("get_action_snapshot"))
	hud.call("update_radar", player.global_position, swarm.call("get_radar_snapshot", 72))


func _process(_delta: float) -> bool:
	if run == null:
		return false
	frame_count += 1
	if frame_count < 18:
		return false
	var image := get_root().get_viewport().get_texture().get_image()
	var output_path := "/private/tmp/it_battle_visual_showcase.png"
	var save_error := image.save_png(output_path)
	print("VISUAL_SHOWCASE_CAPTURE %s size=%s error=%d" % [output_path, image.get_size(), save_error])
	quit(0 if save_error == OK else 1)
	return true
