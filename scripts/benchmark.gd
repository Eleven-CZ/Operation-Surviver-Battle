extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var swarm: Node2D = $SwarmWorld

var display_label: Label
var target_count := 500
var labels_visible := true


func _ready() -> void:
	player.max_health = 1_000_000.0
	player.health = player.max_health
	swarm.call("configure", player, 20260719)
	_build_overlay()
	_fill(target_count)


func _build_overlay() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	display_label = Label.new()
	canvas.add_child(display_label)
	display_label.position = Vector2(18, 18)
	display_label.add_theme_font_size_override("font_size", 18)
	display_label.add_theme_color_override("font_color", Color("7fffdc"))


func _fill(amount: int) -> void:
	target_count = amount
	swarm.call("clear_all")
	var rng := RandomNumberGenerator.new()
	rng.seed = amount
	for index in range(amount):
		var angle := rng.randf() * TAU
		var radius := rng.randf_range(80.0, 680.0)
		var position_value := player.global_position + Vector2.from_angle(angle) * radius
		position_value.x = clampf(position_value.x, 48.0, 2352.0)
		position_value.y = clampf(position_value.y, 205.0, 1290.0)
		swarm.call("spawn_enemy", index % 5, position_value)


func _process(_delta: float) -> void:
	display_label.text = "Swarm Benchmark\n敌人 %d  FPS %d\nF1 200  F2 500  F3 1000  F4 2000  L 标签" % [swarm.count, Engine.get_frames_per_second()]


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F1: _fill(200)
		KEY_F2: _fill(500)
		KEY_F3: _fill(1000)
		KEY_F4: _fill(2000)
		KEY_L:
			labels_visible = not labels_visible
			swarm.labels_enabled = labels_visible

