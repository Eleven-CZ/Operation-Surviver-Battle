extends Node2D

signal xp_collected(value: int)
signal artifact_collected(artifact_id: String)

const MAX_ORBS := 900
const MAX_WORLD_ARTIFACTS := 2
const GOLDEN_ANGLE := 2.399963229728653
const ArtifactCatalog := preload("res://scripts/artifact_catalog.gd")


class ArtifactVisualLayer:
	extends Node2D

	var loot_world: Node


	func _draw() -> void:
		if loot_world != null:
			loot_world.call("_draw_artifacts", self)

var player: Node2D
var positions: Array[Vector2] = []
var values: Array[int] = []
var qualities: Array[int] = []
var scales: Array[float] = []
var artifact_positions: Array[Vector2] = []
var artifact_ids: Array[String] = []
var magnet_radius := 190.0
var burst_sequence := 0
var artifact_visual_layer: Node2D
var artifact_icon_cache: Dictionary = {}


func _ready() -> void:
	# Rare drops need to remain legible inside a dense swarm. A dedicated absolute
	# z layer keeps artifacts above enemies without lifting up to 900 XP crystals.
	artifact_visual_layer = ArtifactVisualLayer.new()
	artifact_visual_layer.name = "ArtifactVisualLayer"
	artifact_visual_layer.z_as_relative = false
	artifact_visual_layer.z_index = 25
	artifact_visual_layer.loot_world = self
	add_child(artifact_visual_layer)


func configure(player_node: Node2D) -> void:
	player = player_node


func set_magnet_radius(radius: float) -> void:
	magnet_radius = maxf(40.0, radius)


func spawn_xp(world_position: Vector2, value: int, quality: int = 0, visual_scale: float = 1.0) -> void:
	if value <= 0:
		return
	if positions.size() >= MAX_ORBS:
		xp_collected.emit(value)
		return
	_append_xp(world_position, value, quality, visual_scale)
	queue_redraw()


func spawn_xp_burst(world_position: Vector2, total_value: int, crystal_count: int, quality: int = 1, visual_scale: float = 1.5) -> int:
	if total_value <= 0:
		return 0
	var available_slots := maxi(0, MAX_ORBS - positions.size())
	if available_slots == 0:
		xp_collected.emit(total_value)
		return 0
	# Never create zero-value crystals. If the pool is almost full, concentrate the
	# complete reward into the remaining slots instead of silently losing XP.
	var actual_count := mini(mini(maxi(1, crystal_count), available_slots), total_value)
	var value_per_crystal := total_value / actual_count
	var remainder := total_value % actual_count
	var base_angle := fmod(float(burst_sequence) * GOLDEN_ANGLE, TAU)
	burst_sequence += 1
	for crystal_index in range(actual_count):
		var offset := Vector2.ZERO
		if crystal_index > 0:
			var satellite_index := crystal_index - 1
			var spread_progress := float(satellite_index) / float(maxi(1, actual_count - 2))
			var spread_radius := lerpf(14.0, 38.0, sqrt(spread_progress))
			var angle := base_angle + float(satellite_index) * GOLDEN_ANGLE
			offset = Vector2.from_angle(angle) * spread_radius
		var crystal_value := value_per_crystal + (1 if crystal_index < remainder else 0)
		_append_xp(world_position + offset, crystal_value, quality, visual_scale)
	queue_redraw()
	return actual_count


func spawn_artifact(world_position: Vector2, artifact_id: String) -> bool:
	var resolved_id := artifact_id.strip_edges()
	if resolved_id.is_empty() or artifact_positions.size() >= MAX_WORLD_ARTIFACTS:
		return false
	_artifact_icon_texture(resolved_id)
	artifact_positions.append(world_position)
	artifact_ids.append(resolved_id)
	_queue_artifact_redraw()
	return true


func get_artifact_snapshot() -> Dictionary:
	return {
		"count": artifact_positions.size(),
		"capacity": MAX_WORLD_ARTIFACTS,
		"positions": artifact_positions.duplicate(),
		"ids": artifact_ids.duplicate(),
	}


func clear_artifacts() -> void:
	artifact_positions.clear()
	artifact_ids.clear()
	_queue_artifact_redraw()


func get_loot_snapshot() -> Dictionary:
	_ensure_metadata_alignment()
	var stored_value := 0
	var elite_count := 0
	for index in range(values.size()):
		stored_value += values[index]
		if qualities[index] > 0:
			elite_count += 1
	return {
		"count": positions.size(),
		"stored_value": stored_value,
		"elite_count": elite_count,
		"capacity": MAX_ORBS,
		"at_capacity": positions.size() >= MAX_ORBS,
		"positions": positions.duplicate(),
		"values": values.duplicate(),
		"qualities": qualities.duplicate(),
		"scales": scales.duplicate(),
	}


func collect_all_xp() -> int:
	_ensure_metadata_alignment()
	var total_value := 0
	for value in values:
		total_value += value
	positions.clear()
	values.clear()
	qualities.clear()
	scales.clear()
	if total_value > 0:
		xp_collected.emit(total_value)
	queue_redraw()
	return total_value


func _append_xp(world_position: Vector2, value: int, quality: int, visual_scale: float) -> void:
	_ensure_metadata_alignment()
	positions.append(world_position)
	values.append(value)
	qualities.append(maxi(0, quality))
	scales.append(clampf(visual_scale, 0.5, 2.5))


func _ensure_metadata_alignment() -> void:
	while qualities.size() < positions.size():
		qualities.append(0)
	while scales.size() < positions.size():
		scales.append(1.0)
	while qualities.size() > positions.size():
		qualities.pop_back()
	while scales.size() > positions.size():
		scales.pop_back()


func _crystal_size(index: int) -> float:
	var quality := qualities[index]
	if quality <= 0:
		return (4.0 + minf(3.0, float(values[index]) * 0.12)) * scales[index]
	var elite_base_size := 5.4 + minf(2.2, float(values[index]) * 0.18)
	return elite_base_size * scales[index]


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_ensure_metadata_alignment()
	var index := 0
	while index < positions.size():
		var distance := positions[index].distance_to(player.global_position)
		if distance < magnet_radius:
			var speed := lerpf(95.0, 620.0, 1.0 - distance / magnet_radius)
			positions[index] = positions[index].move_toward(player.global_position, speed * delta)
		var pickup_radius := 22.0 + maxf(0.0, _crystal_size(index) - 4.5)
		if distance < pickup_radius:
			xp_collected.emit(values[index])
			positions[index] = positions.back()
			values[index] = values.back()
			qualities[index] = qualities.back()
			scales[index] = scales.back()
			positions.pop_back()
			values.pop_back()
			qualities.pop_back()
			scales.pop_back()
			continue
		index += 1
	_update_artifact_pickups(delta)
	queue_redraw()
	_queue_artifact_redraw()


func _update_artifact_pickups(delta: float) -> void:
	var index := 0
	var artifact_magnet_radius := maxf(260.0, magnet_radius * 1.30)
	while index < artifact_positions.size():
		var distance := artifact_positions[index].distance_to(player.global_position)
		if distance < artifact_magnet_radius:
			var speed := lerpf(130.0, 780.0, 1.0 - distance / artifact_magnet_radius)
			artifact_positions[index] = artifact_positions[index].move_toward(player.global_position, speed * delta)
		if distance < 30.0:
			var collected_id := artifact_ids[index]
			var last_index := artifact_positions.size() - 1
			if index != last_index:
				artifact_positions[index] = artifact_positions[last_index]
				artifact_ids[index] = artifact_ids[last_index]
			artifact_positions.pop_back()
			artifact_ids.pop_back()
			_queue_artifact_redraw()
			artifact_collected.emit(collected_id)
			continue
		index += 1


func _draw() -> void:
	_ensure_metadata_alignment()
	for index in range(positions.size()):
		var size := _crystal_size(index)
		if qualities[index] <= 0:
			draw_rect(Rect2(positions[index] - Vector2.ONE * size, Vector2.ONE * size * 2.0), Color("43e6d1"))
			draw_rect(Rect2(positions[index] - Vector2.ONE * (size + 2.0), Vector2.ONE * (size + 2.0) * 2.0), Color(0.2, 0.95, 0.85, 0.25), false, 1.0)
			continue
		_draw_elite_crystal(positions[index], size, qualities[index])


func _draw_elite_crystal(center: Vector2, size: float, quality: int) -> void:
	var half_width := size * 0.72
	var diamond := PackedVector2Array([
		center + Vector2(0.0, -size),
		center + Vector2(half_width, 0.0),
		center + Vector2(0.0, size),
		center + Vector2(-half_width, 0.0),
	])
	var fill_color := Color("63ffe2") if quality == 1 else Color("ff8b7d")
	var outline_color := Color("ffca58") if quality == 1 else Color("fff1a8")
	draw_colored_polygon(diamond, Color(fill_color, 0.30))
	var outline := diamond.duplicate()
	outline.append(diamond[0])
	draw_polyline(outline, outline_color, 2.0, false)
	var core_size := maxf(2.0, floorf(size * 0.34))
	draw_rect(Rect2(center - Vector2.ONE * core_size, Vector2.ONE * core_size * 2.0), fill_color)
	draw_line(center + Vector2(0.0, -size * 0.62), center + Vector2(0.0, size * 0.62), Color(fill_color, 0.75), 1.0)


func _queue_artifact_redraw() -> void:
	if artifact_visual_layer != null:
		artifact_visual_layer.queue_redraw()


func _artifact_icon_texture(artifact_id: String) -> Texture2D:
	if artifact_icon_cache.has(artifact_id):
		return artifact_icon_cache.get(artifact_id) as Texture2D
	var icon := ArtifactCatalog.icon_texture(artifact_id)
	artifact_icon_cache[artifact_id] = icon
	return icon


func _draw_artifacts(canvas: Node2D) -> void:
	var pulse_time := float(Time.get_ticks_msec() % 1200) / 1200.0
	var pulse := 0.5 + sin(pulse_time * TAU) * 0.5
	for index in range(artifact_positions.size()):
		var center := artifact_positions[index]
		var size := 18.0 + pulse * 1.5
		# A tall beacon stays readable even if the drop lands under an elite corpse.
		canvas.draw_rect(Rect2(center + Vector2(-2.0, -54.0), Vector2(4.0, 34.0)), Color(1.0, 0.73, 0.18, 0.12 + pulse * 0.10))
		canvas.draw_rect(Rect2(center + Vector2(-7.0, -46.0), Vector2(14.0, 2.0)), Color(1.0, 0.83, 0.30, 0.40))
		canvas.draw_circle(center, size + 8.0, Color(1.0, 0.65, 0.08, 0.10 + pulse * 0.08))
		var icon := _artifact_icon_texture(artifact_ids[index])
		if icon != null:
			var icon_size := Vector2.ONE * (size * 2.0)
			canvas.draw_rect(Rect2(center - icon_size * 0.5 - Vector2.ONE * 3.0, icon_size + Vector2.ONE * 6.0), Color("fff0a6"), false, 3.0)
			canvas.draw_texture_rect(icon, Rect2(center - icon_size * 0.5, icon_size), false, Color.WHITE)
		else:
			var half_width := size * 0.78
			var diamond := PackedVector2Array([
				center + Vector2(0.0, -size),
				center + Vector2(half_width, 0.0),
				center + Vector2(0.0, size),
				center + Vector2(-half_width, 0.0),
			])
			canvas.draw_colored_polygon(diamond, Color("ffbd3f"))
			var outline := diamond.duplicate()
			outline.append(diamond[0])
			canvas.draw_polyline(outline, Color("fff0a6"), 3.0, false)
		canvas.draw_rect(Rect2(center + Vector2(-size - 8.0, -2.0), Vector2(4.0, 4.0)), Color("ffcf55"))
		canvas.draw_rect(Rect2(center + Vector2(size + 4.0, 4.0), Vector2(4.0, 4.0)), Color("ffcf55"))
