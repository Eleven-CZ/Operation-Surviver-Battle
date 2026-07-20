extends Node2D

signal xp_collected(value: int)

const MAX_ORBS := 900

var player: Node2D
var positions: Array[Vector2] = []
var values: Array[int] = []
var magnet_radius := 190.0


func configure(player_node: Node2D) -> void:
	player = player_node


func set_magnet_radius(radius: float) -> void:
	magnet_radius = maxf(40.0, radius)


func spawn_xp(world_position: Vector2, value: int) -> void:
	if positions.size() >= MAX_ORBS:
		xp_collected.emit(value)
		return
	positions.append(world_position)
	values.append(value)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if player == null:
		return
	var index := 0
	while index < positions.size():
		var distance := positions[index].distance_to(player.global_position)
		if distance < magnet_radius:
			var speed := lerpf(95.0, 620.0, 1.0 - distance / magnet_radius)
			positions[index] = positions[index].move_toward(player.global_position, speed * delta)
		if distance < 22.0:
			xp_collected.emit(values[index])
			positions[index] = positions.back()
			values[index] = values.back()
			positions.pop_back()
			values.pop_back()
			continue
		index += 1
	queue_redraw()


func _draw() -> void:
	for index in range(positions.size()):
		var size := 4.0 + minf(3.0, float(values[index]) * 0.12)
		draw_rect(Rect2(positions[index] - Vector2.ONE * size, Vector2.ONE * size * 2.0), Color("43e6d1"))
		draw_rect(Rect2(positions[index] - Vector2.ONE * (size + 2.0), Vector2.ONE * (size + 2.0) * 2.0), Color(0.2, 0.95, 0.85, 0.25), false, 1.0)
