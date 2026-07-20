class_name MiniRadar
extends Control

const WORLD_SIZE := Vector2(2400.0, 1350.0)

var player_world := Vector2(1200, 675)
var normal_points := PackedVector2Array()
var elite_points := PackedVector2Array()
var boss_points := PackedVector2Array()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func set_snapshot(player_position: Vector2, snapshot: Dictionary) -> void:
	player_world = player_position
	normal_points = snapshot.get("normal", PackedVector2Array())
	elite_points = snapshot.get("elite", PackedVector2Array())
	boss_points = snapshot.get("boss", PackedVector2Array())
	queue_redraw()


func _draw() -> void:
	var bounds := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	draw_rect(bounds, Color(0.008, 0.025, 0.040, 0.90), true)
	for index in range(1, 4):
		var ratio := float(index) / 4.0
		draw_line(Vector2(bounds.position.x + bounds.size.x * ratio, bounds.position.y), Vector2(bounds.position.x + bounds.size.x * ratio, bounds.end.y), Color(0.10, 0.35, 0.43, 0.28), 1.0)
		draw_line(Vector2(bounds.position.x, bounds.position.y + bounds.size.y * ratio), Vector2(bounds.end.x, bounds.position.y + bounds.size.y * ratio), Color(0.10, 0.35, 0.43, 0.28), 1.0)
	for point in normal_points:
		draw_circle(_world_to_radar(point, bounds), 1.4, Color("ef5b4d"))
	for point in elite_points:
		draw_circle(_world_to_radar(point, bounds), 3.0, Color("ffb543"))
	for point in boss_points:
		var radar_point := _world_to_radar(point, bounds)
		draw_circle(radar_point, 5.0, Color(0.95, 0.16, 0.12, 0.32))
		draw_arc(radar_point, 5.0, 0.0, TAU, 16, Color("ff5848"), 2.0)
	var player_point := _world_to_radar(player_world, bounds)
	var player_triangle := PackedVector2Array([
		player_point + Vector2(0, -5),
		player_point + Vector2(-4, 4),
		player_point + Vector2(4, 4),
	])
	draw_colored_polygon(player_triangle, Color("76fff1"))
	draw_arc(player_point, 8.0, 0.0, TAU, 24, Color(0.27, 0.95, 0.84, 0.42), 1.0)
	draw_rect(bounds, Color("21a3b7"), false, 1.0)


func _world_to_radar(world_position: Vector2, bounds: Rect2) -> Vector2:
	var ratio := Vector2(clampf(world_position.x / WORLD_SIZE.x, 0.0, 1.0), clampf(world_position.y / WORLD_SIZE.y, 0.0, 1.0))
	return bounds.position + ratio * bounds.size
