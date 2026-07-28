extends CharacterBody2D

signal health_changed(current: float, maximum: float)
signal died

const WORLD_RECT := Rect2(24.0, 190.0, 2352.0, 1120.0)
const CAREER_SPRITES := preload("res://assets/generated/career_sprites_5x2.png")
const CAREER_ORDER: Array[String] = ["ops", "dba", "network", "security", "it_ops", "helpdesk", "opsdev", "sre", "delivery", "ai_infra"]

@export var move_speed := 260.0
@export var max_health := 100.0

var health := 100.0
var invulnerability_left := 0.0
var slow_left := 0.0
var slow_multiplier := 1.0
var slow_source := ""
var input_enabled := true
var damage_reduction := 0.0
var temporary_damage_reduction := 0.0
var career_id := "ops"
var career_badge := "OPS"
var career_accent := Color("22d7d0")
var facing_direction := Vector2.RIGHT
var touch_input_vector := Vector2.ZERO


func _ready() -> void:
	health = max_health
	queue_redraw()


func _physics_process(delta: float) -> void:
	invulnerability_left = maxf(0.0, invulnerability_left - delta)
	slow_left = maxf(0.0, slow_left - delta)
	if slow_left <= 0.0:
		slow_multiplier = 1.0
		slow_source = ""

	var input_vector := Vector2.ZERO
	if input_enabled:
		input_vector.x = float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
		input_vector.y = float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
		if touch_input_vector.length_squared() > 0.01:
			input_vector = touch_input_vector
		var joypads := Input.get_connected_joypads()
		if joypads.size() > 0:
			var joypad_id: int = joypads[0]
			var joy_vector := Vector2(Input.get_joy_axis(joypad_id, JOY_AXIS_LEFT_X), Input.get_joy_axis(joypad_id, JOY_AXIS_LEFT_Y))
			if joy_vector.length() > 0.22:
				input_vector = joy_vector
	if input_vector.length_squared() > 0.04:
		facing_direction = input_vector.normalized()
	velocity = input_vector.normalized() * move_speed * slow_multiplier
	position += velocity * delta
	position = Vector2(
		clampf(position.x, WORLD_RECT.position.x, WORLD_RECT.end.x),
		clampf(position.y, WORLD_RECT.position.y, WORLD_RECT.end.y)
	)
	queue_redraw()


func set_touch_input(direction: Vector2) -> void:
	touch_input_vector = direction.limit_length(1.0)


func take_damage(amount: float) -> bool:
	if invulnerability_left > 0.0 or health <= 0.0:
		return false
	var resolved_damage := amount * (1.0 - clampf(damage_reduction + temporary_damage_reduction, 0.0, 0.75))
	health = maxf(0.0, health - resolved_damage)
	invulnerability_left = 0.42
	health_changed.emit(health, max_health)
	if health <= 0.0:
		died.emit()
	queue_redraw()
	return true


func heal(amount: float) -> void:
	health = minf(max_health, health + amount)
	health_changed.emit(health, max_health)


func apply_slow(duration: float, multiplier: float, source: String = "latency") -> void:
	slow_left = maxf(slow_left, duration)
	slow_multiplier = minf(slow_multiplier, multiplier)
	if source == "frost" or slow_source.is_empty():
		slow_source = source
	queue_redraw()


func get_facing_direction() -> Vector2:
	return facing_direction


func grant_invulnerability(duration: float) -> void:
	invulnerability_left = maxf(invulnerability_left, duration)


func set_temporary_damage_reduction(amount: float) -> void:
	temporary_damage_reduction = clampf(amount, 0.0, 0.50)


func perform_dash(direction: Vector2, distance: float, invulnerability: float = 0.45) -> Dictionary:
	var resolved_direction := direction.normalized()
	if resolved_direction.length_squared() < 0.01:
		resolved_direction = facing_direction
	var start := global_position
	global_position += resolved_direction * distance
	global_position = Vector2(
		clampf(global_position.x, WORLD_RECT.position.x, WORLD_RECT.end.x),
		clampf(global_position.y, WORLD_RECT.position.y, WORLD_RECT.end.y)
	)
	facing_direction = resolved_direction
	grant_invulnerability(invulnerability)
	queue_redraw()
	return {"start": start, "end": global_position, "direction": resolved_direction}


func configure_career(career: Dictionary) -> void:
	career_id = String(career.get("id", "ops"))
	career_badge = String(career.get("badge", "OPS"))
	career_accent = Color(String(career.get("color", "22d7d0")))
	queue_redraw()


func _draw() -> void:
	var blink := invulnerability_left > 0.0 and int(Time.get_ticks_msec() / 70) % 2 == 0
	if blink:
		return
	var moving := velocity.length_squared() > 10.0
	var bob := sin(float(Time.get_ticks_msec()) * 0.012) * 1.8 if moving else 0.0
	_draw_pixel_ellipse(Vector2(0, 25), Vector2(21, 7), Color(0.0, 0.0, 0.0, 0.48))
	var cell_size := Vector2(float(CAREER_SPRITES.get_width()) / 5.0, float(CAREER_SPRITES.get_height()) / 2.0)
	var career_index := maxi(0, CAREER_ORDER.find(career_id))
	var source := Rect2(Vector2(float(career_index % 5), float(career_index / 5)) * cell_size, cell_size)
	var destination := Rect2(Vector2(-43.0, -66.0 + bob), Vector2(86.0, 121.0))
	draw_texture_rect_region(CAREER_SPRITES, destination, source)
	# A small career-colored locator remains readable when the swarm is dense.
	draw_arc(Vector2(0, 25), 25.0, 0.0, TAU, 32, Color(career_accent, 0.75), 2.0)
	if slow_left > 0.0:
		var slow_color := Color("68d8ff") if slow_source == "frost" else Color("e9b949")
		draw_arc(Vector2(0, 2), 31.0, 0.0, TAU, 32, slow_color, 2.0)
		if slow_source == "frost":
			for spoke_index in range(6):
				var direction := Vector2.from_angle(TAU * float(spoke_index) / 6.0)
				draw_line(direction * 25.0 + Vector2(0, 2), direction * 35.0 + Vector2(0, 2), slow_color, 2.0)


func _draw_pixel_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(24):
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
