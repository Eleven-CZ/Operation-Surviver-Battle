extends Control

signal direction_changed(direction: Vector2)

const DEAD_ZONE := 0.12

var direction := Vector2.ZERO
var touch_index := -1
var mouse_dragging := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and touch_index < 0:
			touch_index = event.index
			_update_direction(event.position)
			accept_event()
		elif not event.pressed and event.index == touch_index:
			reset()
			accept_event()
		return
	if event is InputEventScreenDrag and event.index == touch_index:
		_update_direction(event.position)
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_dragging = event.pressed
		if mouse_dragging:
			_update_direction(event.position)
		else:
			reset()
		accept_event()
		return
	if event is InputEventMouseMotion and mouse_dragging:
		_update_direction(event.position)
		accept_event()


func reset() -> void:
	touch_index = -1
	mouse_dragging = false
	_set_direction(Vector2.ZERO)


func _update_direction(local_position: Vector2) -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.34
	var offset := (local_position - center).limit_length(radius)
	var next_direction := offset / maxf(1.0, radius)
	if next_direction.length() < DEAD_ZONE:
		next_direction = Vector2.ZERO
	_set_direction(next_direction)


func _set_direction(value: Vector2) -> void:
	if direction.is_equal_approx(value):
		return
	direction = value
	direction_changed.emit(direction)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var base_radius := minf(size.x, size.y) * 0.43
	var travel_radius := minf(size.x, size.y) * 0.34
	var knob_center := center + direction * travel_radius
	draw_circle(center, base_radius, Color(0.01, 0.045, 0.065, 0.58))
	draw_arc(center, base_radius, 0.0, TAU, 48, Color(0.35, 0.95, 0.88, 0.62), 3.0)
	for axis in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		draw_line(center + axis * (base_radius - 18.0), center + axis * (base_radius - 8.0), Color(0.50, 0.85, 0.86, 0.58), 3.0)
	draw_circle(knob_center, minf(size.x, size.y) * 0.20, Color(0.08, 0.38, 0.40, 0.88))
	draw_arc(knob_center, minf(size.x, size.y) * 0.20, 0.0, TAU, 32, Color("79fff0"), 3.0)
