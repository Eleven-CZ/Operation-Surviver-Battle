class_name AllySupportSystem
extends Node2D

signal ability_triggered(persona_id: String, ability_name: String, detail: String, color: Color)

const CoworkerCatalog := preload("res://scripts/coworker_catalog.gd")
const UI_FONT := preload("res://assets/fonts/NotoSansSC-VF.ttf")
const MAX_VISUALS := 72

var player: Node2D
var swarm: Node2D
var loot: Node2D
var projection: Node2D
var career_actions: Node2D
var active := false
var persona_id := "product"
var cooldown_left := 0.0
var run_level := 1
var trigger_count := 0
var last_detail := "等待对齐"
var last_trace: Dictionary = {}
var visuals: Array[Dictionary] = []


func configure(player_node: Node2D, swarm_node: Node2D, loot_node: Node2D, projection_node: Node2D, career_action_node: Node2D) -> void:
	player = player_node
	swarm = swarm_node
	loot = loot_node
	projection = projection_node
	career_actions = career_action_node


func activate(value: String) -> void:
	persona_id = value if value in CoworkerCatalog.ids() else "product"
	active = true
	trigger_count = 0
	last_detail = "能力接入"
	last_trace.clear()
	cooldown_left = minf(0.8, _current_cooldown() * 0.18)
	visuals.clear()
	_add_ring(_source_position(), 58.0, CoworkerCatalog.color_for(persona_id), 0.65)
	_add_text(_source_position() + Vector2(0, -78), "%s 已接入" % String(_kit().get("ability", "协作能力")), CoworkerCatalog.color_for(persona_id), 0.85)
	queue_redraw()


func deactivate() -> void:
	active = false
	cooldown_left = 0.0
	visuals.clear()
	queue_redraw()


func set_run_level(value: int) -> void:
	run_level = maxi(1, value)


func _physics_process(delta: float) -> void:
	_update_visuals(delta)
	if not active or player == null or swarm == null:
		return
	cooldown_left = maxf(0.0, cooldown_left - delta)
	if cooldown_left > 0.0:
		return
	if _cast_ability():
		cooldown_left = _current_cooldown()
	else:
		# Healing and target-dependent partners hold their proc instead of wasting
		# a full cooldown while the player is healthy or the arena is empty.
		cooldown_left = 0.30


func debug_trigger(value: String = "") -> Dictionary:
	if not value.is_empty():
		persona_id = value if value in CoworkerCatalog.ids() else "product"
	active = true
	cooldown_left = 0.0
	last_trace.clear()
	_cast_ability()
	return last_trace.duplicate(true)


func get_support_snapshot() -> Dictionary:
	var definition := _kit()
	return {
		"active": active,
		"persona_id": persona_id,
		"persona_name": String(definition.get("name", "协作伙伴")),
		"badge": String(definition.get("badge", "ALLY")),
		"role": String(definition.get("role", "协作")),
		"ability": String(definition.get("ability", "协作能力")),
		"description": String(definition.get("description", "")),
		"color": CoworkerCatalog.color_for(persona_id),
		"cooldown": _current_cooldown(),
		"remaining": cooldown_left,
		"ready": cooldown_left <= 0.01,
		"trigger_count": trigger_count,
		"power_scale": _power_scale(),
		"last_detail": last_detail,
	}


func _kit() -> Dictionary:
	return CoworkerCatalog.get_by_id(persona_id)


func _current_cooldown() -> float:
	var base := float(_kit().get("cooldown", 8.0))
	# Allies keep pace with a long run without collapsing into frame-rate attacks.
	var acceleration := 1.0 + minf(0.30, float(maxi(0, run_level - 1)) * 0.010)
	return maxf(1.20, base / acceleration)


func _power_scale() -> float:
	var growth_level := float(maxi(0, run_level - 1))
	return 1.0 + minf(1.75, growth_level * 0.035) + log(1.0 + maxf(0.0, growth_level - 50.0)) * 0.12


func _source_position() -> Vector2:
	if projection != null and bool(projection.get("ally")):
		return projection.global_position
	return player.global_position if player != null else Vector2.ZERO


func _cast_ability() -> bool:
	var source := _source_position()
	var accent := CoworkerCatalog.color_for(persona_id)
	var scale := _power_scale()
	var detail := ""
	var trace: Dictionary = {"persona_id": persona_id, "source": source, "power_scale": scale}
	match persona_id:
		"qa":
			if float(player.get("health")) >= float(player.get("max_health")) - 0.01:
				return false
			# Healing has its own growth cap so a late-run ally remains useful but
			# cannot erase attrition or out-heal an incident core by itself.
			var heal_scale := minf(1.35, scale)
			var heal_amount := maxf(1.4, float(player.get("max_health")) * 0.014) * heal_scale
			player.call("heal", heal_amount)
			_add_heal_cross(player.global_position, 42.0, accent, 0.62)
			_add_ring(player.global_position, 74.0, accent, 0.62)
			detail = "回归通过 · 健康 +%.1f" % heal_amount
			trace.merge({"type": "heal", "heal": heal_amount})
		"hr":
			var health_ratio := float(player.get("health")) / maxf(1.0, float(player.get("max_health")))
			if health_ratio > 0.45:
				return false
			var heal_amount := maxf(6.0, float(player.get("max_health")) * 0.06) * minf(1.30, scale)
			player.call("heal", heal_amount)
			player.call("grant_invulnerability", 1.20)
			_add_shield(player.global_position, 62.0, accent, 1.20)
			detail = "强制调休 · 健康 +%.1f · 1.2s 保护" % heal_amount
			trace.merge({"type": "shield", "heal": heal_amount, "invulnerability": 1.20})
		"finance":
			var targets: Array[Vector2] = swarm.call("damage_nearest_targets", source, 660.0, 22.0 * scale, 3, 0.88)
			if targets.is_empty():
				return false
			for target in targets:
				_add_beam(source, target, accent, 0.30)
			var recovered_xp := mini(4, 1 + floori(float(run_level) / 12.0))
			loot.call("spawn_xp", targets[0], recovered_xp, 1, 1.30)
			detail = "审计 %d 项 · 追回遥测 +%d" % [targets.size(), recovered_xp]
			trace.merge({"type": "resource", "hits": targets.size(), "xp": recovered_xp})
		"product":
			var radius := minf(340.0, 270.0 + float(run_level) * 2.0)
			if int(swarm.call("count_enemies_in_area", player.global_position, radius, true)) <= 0:
				return false
			var slowed: int = swarm.call("slow_area", player.global_position, radius, 2.8)
			swarm.call("push_area", player.global_position, radius, 34.0)
			swarm.call("damage_area", player.global_position, radius, 8.0 * scale)
			_add_freeze_field(player.global_position, radius, accent, 0.72)
			detail = "冻结需求 · 控制 %d 个故障" % slowed
			trace.merge({"type": "control", "hits": slowed, "radius": radius})
		"frontend":
			var targets: Array[Vector2] = swarm.call("damage_nearest_targets", source, 720.0, 16.0 * scale, 4, 0.82)
			if targets.is_empty():
				return false
			var previous := source
			for target in targets:
				_add_beam(previous, target, accent, 0.28)
				previous = target
			detail = "渲染告警链 · 穿透 %d 个目标" % targets.size()
			trace.merge({"type": "chain", "hits": targets.size(), "targets": targets})
		"backend":
			var target: Dictionary = swarm.call("get_nearest_target", source, 720.0)
			if not bool(target.get("hit", false)):
				return false
			var target_position := Vector2(target.get("position", source))
			var radius := minf(155.0, 116.0 + float(run_level) * 1.1)
			var hits: int = swarm.call("damage_area", target_position, radius, 34.0 * scale)
			_add_beam(source, target_position, accent, 0.25)
			_add_burst(target_position, radius, accent, 0.50)
			detail = "队列批处理 · 结算 %d 个故障" % hits
			trace.merge({"type": "area", "hits": hits, "radius": radius, "target": target_position})
		"leader":
			var radius := minf(410.0, 325.0 + float(run_level) * 2.2)
			if int(swarm.call("count_enemies_in_area", player.global_position, radius, true)) <= 0:
				return false
			var hits: int = swarm.call("damage_area", player.global_position, radius, 58.0 * scale)
			swarm.call("push_area", player.global_position, radius, 82.0)
			_add_burst(player.global_position, radius, accent, 0.72)
			detail = "拍板清障 · 处置 %d 个目标" % hits
			trace.merge({"type": "clear", "hits": hits, "radius": radius})
		"customer":
			var target: Dictionary = swarm.call("get_nearest_target", source, 780.0)
			if not bool(target.get("hit", false)):
				return false
			var target_position := Vector2(target.get("position", source))
			var damage := 72.0 * scale
			swarm.call("damage_index", int(target.get("index", -1)), damage)
			_add_beam(source, target_position, accent, 0.34)
			_add_target(target_position, 34.0, accent, 0.60)
			detail = "稳定复现 · 单体 %.0f 伤害" % damage
			trace.merge({"type": "single", "damage": damage, "target": target_position})
		"supervisor":
			if career_actions == null:
				return false
			career_actions.call("reduce_skill_cooldown", 2.4)
			if career_actions.has_method("reduce_ultimate_cooldown"):
				career_actions.call("reduce_ultimate_cooldown", 1.2)
			player.call("grant_invulnerability", 0.35)
			_add_clock(player.global_position, 52.0, accent, 0.65)
			detail = "重新排班 · 小技能 -2.4s · 大招 -1.2s"
			trace.merge({"type": "cooldown", "skill_reduction": 2.4, "ultimate_reduction": 1.2})
		_:
			return false
	trigger_count += 1
	last_detail = detail
	last_trace = trace
	_add_text(source + Vector2(0, -82), String(_kit().get("ability", "协作能力")), accent, 0.72)
	ability_triggered.emit(persona_id, String(_kit().get("ability", "协作能力")), detail, accent)
	queue_redraw()
	return true


func _update_visuals(delta: float) -> void:
	var changed := false
	for index in range(visuals.size() - 1, -1, -1):
		visuals[index]["ttl"] = float(visuals[index].get("ttl", 0.0)) - delta
		if float(visuals[index]["ttl"]) <= 0.0:
			visuals.remove_at(index)
		changed = true
	if changed:
		queue_redraw()


func _append_visual(value: Dictionary) -> void:
	if visuals.size() >= MAX_VISUALS:
		visuals.pop_front()
	visuals.append(value)
	queue_redraw()


func _add_ring(center: Vector2, radius: float, color: Color, ttl: float) -> void:
	_append_visual({"type": "ring", "center": center, "radius": radius, "color": color, "ttl": ttl, "max_ttl": ttl})


func _add_beam(from: Vector2, to: Vector2, color: Color, ttl: float) -> void:
	_append_visual({"type": "beam", "from": from, "to": to, "color": color, "ttl": ttl, "max_ttl": ttl})


func _add_burst(center: Vector2, radius: float, color: Color, ttl: float) -> void:
	_append_visual({"type": "burst", "center": center, "radius": radius, "color": color, "ttl": ttl, "max_ttl": ttl})


func _add_shield(center: Vector2, radius: float, color: Color, ttl: float) -> void:
	_append_visual({"type": "shield", "center": center, "radius": radius, "color": color, "ttl": ttl, "max_ttl": ttl})


func _add_heal_cross(center: Vector2, radius: float, color: Color, ttl: float) -> void:
	_append_visual({"type": "heal", "center": center, "radius": radius, "color": color, "ttl": ttl, "max_ttl": ttl})


func _add_freeze_field(center: Vector2, radius: float, color: Color, ttl: float) -> void:
	_append_visual({"type": "freeze", "center": center, "radius": radius, "color": color, "ttl": ttl, "max_ttl": ttl})


func _add_target(center: Vector2, radius: float, color: Color, ttl: float) -> void:
	_append_visual({"type": "target", "center": center, "radius": radius, "color": color, "ttl": ttl, "max_ttl": ttl})


func _add_clock(center: Vector2, radius: float, color: Color, ttl: float) -> void:
	_append_visual({"type": "clock", "center": center, "radius": radius, "color": color, "ttl": ttl, "max_ttl": ttl})


func _add_text(center: Vector2, value: String, color: Color, ttl: float) -> void:
	_append_visual({"type": "text", "center": center, "text": value, "color": color, "ttl": ttl, "max_ttl": ttl})


func _draw() -> void:
	for visual in visuals:
		var ttl := float(visual.get("ttl", 0.0))
		var maximum := maxf(0.001, float(visual.get("max_ttl", 1.0)))
		var fade := clampf(ttl / maximum, 0.0, 1.0)
		var color: Color = visual.get("color", Color.WHITE)
		color.a *= fade
		var center := Vector2(visual.get("center", Vector2.ZERO))
		var radius := float(visual.get("radius", 24.0))
		match String(visual.get("type", "")):
			"ring":
				draw_arc(center, radius * (1.12 - fade * 0.12), 0.0, TAU, 42, color, 3.0 + fade * 2.0)
			"beam":
				var from := Vector2(visual.get("from", Vector2.ZERO))
				var to := Vector2(visual.get("to", Vector2.ZERO))
				draw_line(from, to, Color(color, color.a * 0.28), 8.0 * fade)
				draw_line(from, to, color, 2.0 + 2.0 * fade)
			"burst":
				draw_circle(center, radius * (1.0 - fade * 0.18), Color(color, color.a * 0.12))
				draw_arc(center, radius * (1.05 - fade * 0.10), 0.0, TAU, 56, color, 5.0)
				for spoke in range(12):
					var direction := Vector2.from_angle(TAU * float(spoke) / 12.0)
					draw_line(center + direction * radius * 0.32, center + direction * radius * (0.82 + 0.12 * fade), color, 2.0)
			"shield":
				draw_circle(center, radius, Color(color, color.a * 0.10))
				for side in range(8):
					var start_angle := TAU * float(side) / 8.0 + PI * 0.125
					draw_arc(center, radius, start_angle, start_angle + TAU / 11.0, 5, color, 5.0)
			"heal":
				draw_circle(center, radius, Color(color, color.a * 0.10))
				draw_rect(Rect2(center + Vector2(-7, -radius * 0.52), Vector2(14, radius * 1.04)), color)
				draw_rect(Rect2(center + Vector2(-radius * 0.52, -7), Vector2(radius * 1.04, 14)), color)
			"freeze":
				draw_circle(center, radius, Color(color, color.a * 0.075))
				draw_arc(center, radius, 0.0, TAU, 64, color, 4.0)
				for spoke in range(10):
					var direction := Vector2.from_angle(TAU * float(spoke) / 10.0)
					draw_line(center + direction * radius * 0.68, center + direction * radius, color, 3.0)
			"target":
				draw_arc(center, radius, 0.0, TAU, 24, color, 3.0)
				draw_line(center + Vector2(-radius * 1.35, 0), center + Vector2(-radius * 0.55, 0), color, 3.0)
				draw_line(center + Vector2(radius * 0.55, 0), center + Vector2(radius * 1.35, 0), color, 3.0)
				draw_line(center + Vector2(0, -radius * 1.35), center + Vector2(0, -radius * 0.55), color, 3.0)
				draw_line(center + Vector2(0, radius * 0.55), center + Vector2(0, radius * 1.35), color, 3.0)
			"clock":
				draw_circle(center, radius, Color(color, color.a * 0.08))
				draw_arc(center, radius, 0.0, TAU, 36, color, 4.0)
				draw_line(center, center + Vector2(0, -radius * 0.58), color, 4.0)
				draw_line(center, center + Vector2(radius * 0.42, 0), color, 4.0)
			"text":
				var text_value := String(visual.get("text", ""))
				var text_size := UI_FONT.get_string_size(text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
				draw_string(UI_FONT, center - Vector2(text_size.x * 0.5, 0), text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
