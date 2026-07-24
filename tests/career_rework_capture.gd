extends SceneTree

var run: Node
var frame_count := 0
var career_id := "sre"


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--career="):
			career_id = argument.trim_prefix("--career=")
	call_deferred("_build")


func _build() -> void:
	var profile := get_root().get_node("ProfileStore")
	profile.reset_for_tests()
	profile.unlock_career(career_id)
	profile.select_career(career_id)
	run = load("res://scenes/run.tscn").instantiate()
	get_root().add_child(run)
	run.set_process(false)
	var player: CharacterBody2D = run.get_node("Player")
	var swarm: Node2D = run.get_node("SwarmWorld")
	var actions: Node2D = run.get_node("CareerActionSystem")
	player.set_physics_process(false)
	swarm.set_physics_process(false)
	actions.set_physics_process(false)
	actions.debug_disable_auto_signature = true
	run.get_node("LootWorld").set_physics_process(false)
	for node_name in ["CombatSystem", "PressureProjection", "AllySupportSystem"]:
		var system_node: Node = run.get_node(node_name)
		system_node.set_process(false)
		system_node.set_physics_process(false)
	swarm.call("clear_all")
	player.global_position = Vector2(1200, 675)
	if career_id == "delivery":
		_build_delivery(player, swarm, actions)
	elif career_id == "ai_infra":
		_build_ai_infra(player, swarm, actions)
	else:
		_build_sre(player, swarm, actions)
	var hud: CanvasLayer = run.get_node("HUD")
	hud.call("update_career_actions", actions.call("get_action_snapshot"))
	var headline := "SRE · 关键路径 Trace / 流量切换 / 全站多活"
	if career_id == "delivery":
		headline = "实施交付 · 全员到场 / 三轮借招 / 联合验收"
	elif career_id == "ai_infra":
		headline = "AI Infra · Tensor Pipeline / Pipeline Flush / 基础模型上线"
	hud.call("set_event_message", headline, Color(String(run.career.get("color", "65e890"))))
	run.call("_refresh_build_summary")


func _build_sre(player: CharacterBody2D, swarm: Node2D, actions: Node2D) -> void:
	var history: Array[Vector2] = []
	for index in range(60):
		var progress := float(index) / 59.0
		var bend := sin(progress * PI * 2.0) * 95.0
		history.append(Vector2(900.0 + progress * 600.0, 520.0 + bend))
	actions.set("sre_position_history", history)
	_spawn_faults(swarm, player.global_position, 34, 180.0, 505.0)
	actions.call("try_skill", Vector2.RIGHT)
	actions.call("debug_reset_cooldowns")
	actions.call("try_ultimate")
	actions.call("debug_advance_actions", 0.10)
	actions.call("debug_cast_signature")


func _build_delivery(player: CharacterBody2D, swarm: Node2D, actions: Node2D) -> void:
	_spawn_faults(swarm, player.global_position, 42, 175.0, 520.0)
	swarm.call("spawn_enemy", SwarmWorld.EnemyKind.ELITE_502, Vector2(935, 470), 3)
	swarm.call("spawn_enemy", SwarmWorld.EnemyKind.ELITE_OOM, Vector2(1510, 515), 5)
	swarm.call("spawn_enemy", SwarmWorld.EnemyKind.INCIDENT_CORE, Vector2(1515, 820))
	swarm.call("expose_boss")
	actions.call("try_ultimate")
	for _step in range(17):
		actions.call("debug_advance_actions", 0.10)


func _build_ai_infra(player: CharacterBody2D, swarm: Node2D, actions: Node2D) -> void:
	_spawn_faults(swarm, player.global_position, 54, 145.0, 610.0)
	actions.call("try_skill", Vector2.RIGHT)
	actions.call("try_ultimate")
	actions.call("debug_advance_actions", 0.34)
	actions.call("debug_cast_signature")


func _spawn_faults(swarm: Node2D, center: Vector2, count: int, minimum_radius: float, maximum_radius: float) -> void:
	var kinds := [
		SwarmWorld.EnemyKind.HTTP_404,
		SwarmWorld.EnemyKind.NXDOMAIN,
		SwarmWorld.EnemyKind.ENOSPC,
		SwarmWorld.EnemyKind.BUG,
		SwarmWorld.EnemyKind.TIMEOUT_408,
	]
	for index in range(count):
		var angle := TAU * float(index) / float(count) + float(index % 3) * 0.08
		var radius := lerpf(minimum_radius, maximum_radius, float(index % 7) / 6.0)
		var position_value := center + Vector2.from_angle(angle) * radius
		swarm.call("spawn_enemy", int(kinds[index % kinds.size()]), position_value)


func _process(_delta: float) -> bool:
	if run == null:
		return false
	frame_count += 1
	if frame_count < 20:
		return false
	var image := get_root().get_viewport().get_texture().get_image()
	if image == null:
		push_error("CAREER_REWORK_CAPTURE has no rendered framebuffer")
		quit(1)
		return true
	var output_path := "/private/tmp/it_battle_rework_%s.png" % career_id
	var save_error := image.save_png(output_path)
	print("CAREER_REWORK_CAPTURE %s size=%s error=%d" % [output_path, image.get_size(), save_error])
	quit(0 if save_error == OK else 1)
	return true
