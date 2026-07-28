extends Node2D

signal shell_resolved
signal ally_joined

const CoworkerCatalog := preload("res://scripts/coworker_catalog.gd")
const COWORKER_SPRITES := preload("res://assets/generated/coworker_sprites_4x2.png")
const UI_FONT := preload("res://assets/fonts/NotoSansSC-VF.ttf")

var player: Node2D
var active := false
var shell_broken := false
var ally := false
var shell_health := 160.0
var shell_maximum := 160.0
var interaction_progress := 0.0
var debug_auto_interact := false
var interaction_speed_multiplier := 1.0
var persona_id := "product"
var touch_interact := false


func configure(player_node: Node2D) -> void:
	player = player_node


func configure_career(career: Dictionary) -> void:
	var stats: Dictionary = career.get("stats", {})
	interaction_speed_multiplier = float(stats.get("projection", 1.0))


func set_persona(value: String) -> void:
	persona_id = value if value in CoworkerCatalog.ids() else "product"
	queue_redraw()


func get_persona_name() -> String:
	return String(CoworkerCatalog.get_by_id(persona_id).get("name", "协作伙伴"))


func get_persona_definition() -> Dictionary:
	return CoworkerCatalog.get_by_id(persona_id).duplicate(true)


func start_projection(world_position: Vector2) -> void:
	global_position = world_position
	active = true
	shell_broken = false
	ally = false
	shell_health = shell_maximum
	interaction_progress = 0.0
	queue_redraw()


func is_targetable() -> bool:
	return active and not shell_broken and not ally


func take_shell_damage(amount: float) -> bool:
	if not is_targetable():
		return false
	shell_health = maxf(0.0, shell_health - amount)
	if shell_health <= 0.0:
		shell_broken = true
		shell_resolved.emit()
	queue_redraw()
	return true


func _physics_process(delta: float) -> void:
	if not active or player == null:
		return
	if shell_broken and not ally:
		var close_enough := global_position.distance_to(player.global_position) < 92.0
		var joy_interact := false
		var joypads := Input.get_connected_joypads()
		if joypads.size() > 0:
			joy_interact = Input.is_joy_button_pressed(joypads[0], JOY_BUTTON_A)
		var interacting := debug_auto_interact or touch_interact or Input.is_key_pressed(KEY_E) or joy_interact
		if close_enough and interacting:
			interaction_progress = minf(1.2, interaction_progress + delta * interaction_speed_multiplier)
		else:
			interaction_progress = maxf(0.0, interaction_progress - delta * 0.45)
		if interaction_progress >= 1.2:
			ally = true
			ally_joined.emit()
	if ally:
		global_position = global_position.lerp(player.global_position + Vector2(74, -58), minf(1.0, delta * 4.0))
	queue_redraw()


func set_touch_interact(active_value: bool) -> void:
	touch_interact = active_value


func _draw() -> void:
	if not active:
		return
	_draw_pixel_ellipse(Vector2(0, 25), Vector2(20, 7), Color(0.0, 0.0, 0.0, 0.46))
	var cell_size := Vector2(float(COWORKER_SPRITES.get_width()) / 4.0, float(COWORKER_SPRITES.get_height()) / 2.0)
	var definition := CoworkerCatalog.get_by_id(persona_id)
	var persona_index := clampi(int(definition.get("sprite_index", 2)), 0, 7)
	var source := Rect2(Vector2(float(persona_index % 4), floor(float(persona_index) / 4.0)) * cell_size, cell_size)
	var destination := Rect2(Vector2(-43, -65), Vector2(86, 121))
	draw_texture_rect_region(COWORKER_SPRITES, destination, source, Color(0.72, 1.0, 0.90, 1.0) if ally else Color.WHITE)
	if persona_id == "qa":
		# QA shares the current tablet silhouette but remains unmistakable in play.
		var badge_color := CoworkerCatalog.color_for(persona_id)
		draw_rect(Rect2(Vector2(-31, -58), Vector2(28, 17)), Color(0.02, 0.11, 0.09, 0.92), true)
		draw_rect(Rect2(Vector2(-31, -58), Vector2(28, 17)), badge_color, false, 2.0)
		draw_string(UI_FONT, Vector2(-27, -45), "QA", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, badge_color)
	if not shell_broken:
		var ratio := shell_health / shell_maximum
		draw_circle(Vector2(0, -3), 47.0, Color(0.75, 0.2, 0.72, 0.16))
		draw_arc(Vector2(0, -3), 47.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 40, Color("ef69df"), 4.0)
		for shard in range(8):
			var angle := TAU * float(shard) / 8.0
			draw_line(Vector2(0, -3) + Vector2.from_angle(angle) * 32.0, Vector2(0, -3) + Vector2.from_angle(angle + 0.12) * 45.0, Color("c94fbd"), 2.0)
	elif not ally:
		draw_arc(Vector2(0, -3), 34.0, 0.0, TAU * (interaction_progress / 1.2), 32, Color("f0ca5a"), 4.0)
		_draw_centered_text(Vector2(0, -73), "%s · 按住 E / A 对齐" % get_persona_name(), Color("ffe08a"), 12)
	else:
		draw_arc(Vector2(0, -3), 31.0, 0.0, TAU, 32, Color("43e8c7"), 2.0)
		draw_line(Vector2(22, -3), Vector2(46, -13), Color("43e8c7"), 2.0)


func _draw_pixel_ellipse(center: Vector2, radius_value: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for point_index in range(24):
		var angle := TAU * float(point_index) / 24.0
		points.append(center + Vector2(cos(angle) * radius_value.x, sin(angle) * radius_value.y))
	draw_colored_polygon(points, color)


func _draw_centered_text(center: Vector2, text: String, color: Color, font_size: int) -> void:
	var size := UI_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(UI_FONT, center - Vector2(size.x * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
