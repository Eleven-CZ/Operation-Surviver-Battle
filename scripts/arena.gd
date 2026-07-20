extends Node2D

const WORLD_SIZE := Vector2(2400.0, 1350.0)
const ARENA_TEXTURE := preload("res://assets/generated/arena_war_room_v2.png")


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	# AI-authored production arena: machinery is pushed to the perimeter so the
	# camera can stay high and several hundred enemies remain legible.
	draw_texture_rect(ARENA_TEXTURE, Rect2(Vector2.ZERO, WORLD_SIZE), false)
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("214658"), false, 3.0)
