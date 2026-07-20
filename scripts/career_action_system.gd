class_name CareerActionSystem
extends Node2D

signal action_used(action_kind: String, action_id: String)
signal action_feedback(title: String, detail: String, accent: Color)

const ActionCatalog := preload("res://scripts/career_action_catalog.gd")
const MAX_VISUALS := 140

var player: CharacterBody2D
var swarm: Node2D
var projection: Node2D
var combat: Node2D
var career_id := "ops"
var career: Dictionary = {}
var kit: Dictionary = {}
var accent := Color("56e6dc")
var damage_multiplier := 1.0

var signature_timer := 0.12
var skill_cooldown_left := 0.0
var ultimate_cooldown_left := 0.0
var facing_direction := Vector2.RIGHT
var combo_step := 0
var worker_angle := 0.0
var packet_capture_left := 0.0
var packet_capture_position := Vector2.ZERO
var ultimate_mode := ""
var ultimate_left := 0.0
var ultimate_tick := 0.0
var history_tick := 0.0
var position_history: Array[Vector2] = []

var walls: Array[Dictionary] = []
var zones: Array[Dictionary] = []
var nodes: Array[Dictionary] = []
var pending_actions: Array[Dictionary] = []
var visuals: Array[Dictionary] = []
var last_action_trace: Dictionary = {}
var debug_disable_auto_signature := false


func configure(player_node: CharacterBody2D, swarm_node: Node2D, projection_node: Node2D, combat_node: Node2D) -> void:
	player = player_node
	swarm = swarm_node
	projection = projection_node
	combat = combat_node


func configure_career(career_data: Dictionary) -> void:
	career = career_data
	career_id = String(career.get("id", "ops"))
	kit = ActionCatalog.get_by_id(career_id)
	accent = Color(String(career.get("color", "56e6dc")))
	damage_multiplier = float(career.get("combat", {}).get("damage", 1.0))
	signature_timer = 0.12
	skill_cooldown_left = 0.0
	ultimate_cooldown_left = 0.0
	combo_step = 0
	packet_capture_left = 0.0
	ultimate_mode = ""
	ultimate_left = 0.0
	walls.clear()
	zones.clear()
	nodes.clear()
	pending_actions.clear()
	visuals.clear()
	position_history.clear()
	if combat != null and combat.has_method("set_temporary_damage_multiplier"):
		combat.call("set_temporary_damage_multiplier", 1.0)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_advance_actions(delta, not debug_disable_auto_signature)


func _advance_actions(delta: float, allow_signature: bool) -> void:
	if player == null or swarm == null or kit.is_empty():
		return
	skill_cooldown_left = maxf(0.0, skill_cooldown_left - delta)
	ultimate_cooldown_left = maxf(0.0, ultimate_cooldown_left - delta)
	signature_timer -= delta
	worker_angle -= delta * 0.82
	var velocity := player.velocity
	if velocity.length_squared() > 4.0:
		facing_direction = velocity.normalized()
	elif player.has_method("get_facing_direction"):
		facing_direction = Vector2(player.call("get_facing_direction"))
	_record_position_history(delta)
	_update_packet_capture(delta)
	_update_walls(delta)
	_update_zones(delta)
	_update_nodes(delta)
	_update_pending_actions(delta)
	_update_ultimate(delta)
	_update_visuals(delta)
	if allow_signature and signature_timer <= 0.0:
		_cast_signature()
		signature_timer = _signature_cooldown()
	queue_redraw()


func try_skill(direction: Vector2 = Vector2.ZERO) -> bool:
	if player == null or kit.is_empty() or skill_cooldown_left > 0.0:
		return false
	var resolved_direction := _resolved_direction(direction)
	var skill: Dictionary = kit["skill"]
	skill_cooldown_left = float(skill["cooldown"])
	match career_id:
		"ops": _skill_ops(resolved_direction)
		"dba": _skill_dba()
		"network": _skill_network()
		"security": _skill_security(resolved_direction)
		"it_ops": _skill_it_ops()
		"helpdesk": _skill_helpdesk()
		"opsdev": _skill_opsdev()
		"sre": _skill_sre(resolved_direction)
		"delivery": _skill_delivery(resolved_direction)
		"ai_infra": _skill_ai_infra(resolved_direction)
	last_action_trace = {"kind": "skill", "id": String(skill["id"]), "career_id": career_id}
	action_used.emit("skill", String(skill["id"]))
	action_feedback.emit(String(skill["name"]), String(skill["description"]), accent)
	queue_redraw()
	return true


func try_ultimate() -> bool:
	if player == null or kit.is_empty() or ultimate_cooldown_left > 0.0:
		return false
	var ultimate: Dictionary = kit["ultimate"]
	ultimate_cooldown_left = float(ultimate["cooldown"])
	match career_id:
		"ops": _ultimate_ops()
		"dba": _ultimate_dba()
		"network": _ultimate_network()
		"security": _ultimate_security()
		"it_ops": _ultimate_it_ops()
		"helpdesk": _ultimate_helpdesk()
		"opsdev": _ultimate_opsdev()
		"sre": _ultimate_sre()
		"delivery": _ultimate_delivery()
		"ai_infra": _ultimate_ai_infra()
	last_action_trace = {"kind": "ultimate", "id": String(ultimate["id"]), "career_id": career_id}
	action_used.emit("ultimate", String(ultimate["id"]))
	action_feedback.emit(String(ultimate["name"]), String(ultimate["description"]), accent.lightened(0.16))
	queue_redraw()
	return true


func get_action_snapshot() -> Dictionary:
	if kit.is_empty():
		return {}
	var signature: Dictionary = Dictionary(kit["signature"]).duplicate(true)
	var skill: Dictionary = Dictionary(kit["skill"]).duplicate(true)
	var ultimate: Dictionary = Dictionary(kit["ultimate"]).duplicate(true)
	skill["remaining"] = skill_cooldown_left
	skill["ready"] = skill_cooldown_left <= 0.0
	ultimate["remaining"] = ultimate_cooldown_left
	ultimate["ready"] = ultimate_cooldown_left <= 0.0
	return {
		"career_id": career_id,
		"color": accent,
		"signature": signature,
		"skill": skill,
		"ultimate": ultimate,
		"active": ultimate_mode,
		"active_left": ultimate_left,
		"packet_capture_left": packet_capture_left,
		"walls": walls.size(),
		"zones": zones.size(),
		"nodes": nodes.size(),
		"pending": pending_actions.size(),
		"worker_count": _worker_count(),
	}


func debug_cast_signature() -> Dictionary:
	_cast_signature()
	return last_action_trace.duplicate(true)


func debug_advance_actions(delta: float) -> void:
	_advance_actions(delta, false)


func debug_reset_cooldowns() -> void:
	skill_cooldown_left = 0.0
	ultimate_cooldown_left = 0.0


func prime_signature() -> void:
	signature_timer = 0.0


func get_worker_count() -> int:
	return _worker_count() if career_id == "ai_infra" else 0


func _cast_signature() -> void:
	if player == null or swarm == null:
		return
	var signature: Dictionary = kit["signature"]
	var trace := {"kind": "signature", "id": String(signature["id"]), "archetype": String(signature["archetype"]), "career_id": career_id, "hits": 0}
	match career_id:
		"ops": trace["hits"] = _signature_ops()
		"dba": trace["created"] = _signature_dba()
		"network": trace["hits"] = _signature_network()
		"security": trace["created"] = _signature_security()
		"it_ops": trace["created"] = _signature_it_ops()
		"helpdesk": trace["hits"] = _signature_helpdesk()
		"opsdev": trace["hits"] = _signature_opsdev()
		"sre": trace["hits"] = _signature_sre()
		"delivery": trace["created"] = _signature_delivery()
		"ai_infra": trace["hits"] = _signature_ai_infra()
	_damage_projection_from_signature(String(signature["archetype"]))
	last_action_trace = trace
	action_used.emit("signature", String(signature["id"]))


func _signature_cooldown() -> float:
	var value := float(kit.get("signature", {}).get("cooldown", 1.0))
	match ultimate_mode:
		"ops_p1": value *= 0.46
		"helpdesk_sla": value *= 0.48
		"ai_scale": value *= 0.42
	return maxf(0.18, value)


func _signature_ops() -> int:
	combo_step = (combo_step + 1) % 3
	var direction := _aim_direction(155.0)
	if ultimate_mode == "ops_p1" or combo_step == 0:
		var radius := 128.0 if ultimate_mode == "ops_p1" else 112.0
		var hits: int = swarm.call("damage_area", player.global_position, radius, _damage(30.0 if combo_step == 0 else 24.0))
		swarm.call("push_area", player.global_position, radius, 28.0)
		_add_visual({"type": "ring", "center": player.global_position, "radius": radius, "color": accent, "ttl": 0.28, "max": 0.28})
		return hits
	var reach := 118.0
	var half_angle := 1.12
	var hits: int = swarm.call("damage_arc", player.global_position, direction, reach, half_angle, _damage(23.0))
	_add_visual({"type": "arc", "center": player.global_position, "radius": reach, "start": direction.angle() - half_angle, "end": direction.angle() + half_angle, "color": accent, "ttl": 0.22, "max": 0.22})
	return hits


func _signature_dba() -> String:
	var target := _target_position(350.0, player.global_position + facing_direction * 155.0)
	_add_zone(target, "lock", 78.0, 5.0, 0.48)
	while _count_zones("lock") > 3:
		_remove_oldest_zone("lock")
	return "lock_zone"


func _signature_network() -> int:
	var direction := _aim_direction(650.0)
	var start := player.global_position
	var finish := start + direction * 640.0
	var hits: Array[Vector2] = swarm.call("damage_line", start, finish, 17.0, _damage(22.0), 5)
	_add_visual({"type": "beam", "from": start, "to": finish, "color": accent, "ttl": 0.18, "max": 0.18, "width": 4.0})
	return hits.size()


func _signature_security() -> String:
	var direction := _aim_direction(280.0)
	var center := player.global_position + direction * 118.0
	_add_wall(center - direction.orthogonal() * 100.0, center + direction.orthogonal() * 100.0, 3.4, "firewall")
	while walls.size() > 2:
		walls.remove_at(0)
	return "firewall"


func _signature_it_ops() -> String:
	var placement := player.global_position - facing_direction * 38.0
	_add_node(placement, 13.0, "spare")
	while nodes.size() > 3:
		nodes.remove_at(0)
	return "spare_node"


func _signature_helpdesk() -> int:
	var target_count := 12 if ultimate_mode == "helpdesk_sla" else 5
	var hits: Array[Vector2] = swarm.call("damage_nearest_targets", player.global_position, 440.0, _damage(19.0), target_count, 0.72)
	var source := player.global_position
	for hit_position in hits:
		_add_visual({"type": "beam", "from": source, "to": hit_position, "color": accent, "ttl": 0.24, "max": 0.24, "width": 3.0})
		source = hit_position
	return hits.size()


func _signature_opsdev() -> int:
	var target: Dictionary = swarm.call("get_nearest_target", player.global_position, 500.0)
	if not bool(target.get("hit", false)):
		return 0
	var target_index := int(target["index"])
	var target_position := Vector2(target["position"])
	swarm.call("damage_index", target_index, _damage(18.0))
	_add_visual({"type": "beam", "from": player.global_position, "to": target_position, "color": accent, "ttl": 0.16, "max": 0.16, "width": 3.0})
	pending_actions.append({"type": "script_repeat", "delay": 0.42, "position": target_position, "damage": _damage(14.0), "repeat": 2})
	return 1


func _signature_sre() -> int:
	var health_ratio: float = player.health / maxf(1.0, player.max_health)
	var radius := 150.0 if health_ratio >= 0.65 else 125.0
	var damage := _damage(19.0 if health_ratio >= 0.65 else 10.0)
	var hits: int = swarm.call("damage_area", player.global_position, radius, damage)
	if health_ratio < 0.45:
		swarm.call("push_area", player.global_position, radius, 32.0)
		player.call("heal", 1.5)
	_add_visual({"type": "ring", "center": player.global_position, "radius": radius, "color": Color("65e890") if health_ratio < 0.45 else accent, "ttl": 0.34, "max": 0.34})
	return hits


func _signature_delivery() -> String:
	var target := _target_position(460.0, player.global_position + facing_direction * 260.0)
	pending_actions.append({"type": "release_package", "delay": 0.55, "position": target, "damage": _damage(28.0), "radius": 96.0})
	_add_visual({"type": "marker", "center": target, "radius": 96.0, "color": accent, "ttl": 0.55, "max": 0.55})
	return "release_package"


func _signature_ai_infra() -> int:
	var pod_positions := _worker_positions()
	var hits: Array[Vector2] = swarm.call("damage_nearest_targets", player.global_position, 470.0, _damage(11.0), pod_positions.size(), 0.92)
	for hit_index in range(hits.size()):
		_add_visual({"type": "beam", "from": pod_positions[hit_index % pod_positions.size()], "to": hits[hit_index], "color": accent, "ttl": 0.20, "max": 0.20, "width": 3.0})
	return hits.size()


func _skill_ops(direction: Vector2) -> void:
	var dash: Dictionary = player.call("perform_dash", direction, 225.0, 0.58)
	var start := Vector2(dash["start"])
	var finish := Vector2(dash["end"])
	swarm.call("damage_line", start, finish, 34.0, _damage(35.0), -1)
	swarm.call("push_area", finish, 125.0, 42.0)
	swarm.call("damage_arc", finish, direction, 132.0, 1.2, _damage(26.0))
	_add_visual({"type": "beam", "from": start, "to": finish, "color": accent, "ttl": 0.32, "max": 0.32, "width": 12.0})


func _skill_dba() -> void:
	var start := player.global_position
	var destination := position_history[0] if not position_history.is_empty() else start
	player.global_position = destination
	player.call("grant_invulnerability", 0.65)
	player.call("heal", player.max_health * 0.10)
	swarm.call("damage_area", start, 105.0, _damage(20.0))
	swarm.call("damage_area", destination, 105.0, _damage(20.0))
	_add_visual({"type": "beam", "from": start, "to": destination, "color": accent, "ttl": 0.42, "max": 0.42, "width": 8.0})


func _skill_network() -> void:
	packet_capture_position = player.global_position
	packet_capture_left = 8.0
	_add_visual({"type": "ring", "center": packet_capture_position, "radius": 210.0, "color": accent, "ttl": 0.55, "max": 0.55})


func _skill_security(direction: Vector2) -> void:
	var dash: Dictionary = player.call("perform_dash", direction, 165.0, 0.85)
	var start := Vector2(dash["start"])
	var finish := Vector2(dash["end"])
	var side := direction.orthogonal() * 48.0
	_add_wall(start + side, finish + side, 4.2, "corridor")
	_add_wall(start - side, finish - side, 4.2, "corridor")


func _skill_it_ops() -> void:
	if nodes.is_empty():
		_add_node(player.global_position, 13.0, "spare")
	for node in nodes:
		var position_value := Vector2(node["position"])
		swarm.call("damage_area", position_value, 135.0, _damage(32.0))
		_add_visual({"type": "ring", "center": position_value, "radius": 135.0, "color": accent, "ttl": 0.35, "max": 0.35})
	player.call("heal", 8.0)


func _skill_helpdesk() -> void:
	var hits: Array[Vector2] = swarm.call("damage_nearest_targets", player.global_position, 360.0, _damage(13.0), 8, 0.78)
	for hit_position in hits:
		_add_visual({"type": "beam", "from": player.global_position, "to": hit_position, "color": accent, "ttl": 0.28, "max": 0.28, "width": 2.0})
	player.call("heal", 6.0)
	if projection != null and projection.call("is_targetable"):
		projection.call("take_shell_damage", 28.0)


func _skill_opsdev() -> void:
	signature_timer = 0.0
	var positions: Array[Vector2] = swarm.call("get_random_enemy_positions", 3)
	for index in range(positions.size()):
		pending_actions.append({"type": "script_repeat", "delay": 0.18 + float(index) * 0.16, "position": positions[index], "damage": _damage(20.0), "repeat": 1})


func _skill_sre(direction: Vector2) -> void:
	var dash: Dictionary = player.call("perform_dash", direction, 205.0, 1.05)
	_add_zone(Vector2(dash["start"]), "heal", 82.0, 3.4, 0.0)
	_add_zone(Vector2(dash["end"]), "heal", 82.0, 3.4, 0.0)


func _skill_delivery(direction: Vector2) -> void:
	var dash: Dictionary = player.call("perform_dash", direction, 235.0, 0.72)
	var start := Vector2(dash["start"])
	var finish := Vector2(dash["end"])
	swarm.call("damage_area", start, 112.0, _damage(34.0))
	_add_visual({"type": "blast", "center": start, "radius": 112.0, "color": Color("70caff"), "ttl": 0.42, "max": 0.42})
	_add_zone(finish, "heal", 92.0, 4.0, 0.0)


func _skill_ai_infra(direction: Vector2) -> void:
	var dash: Dictionary = player.call("perform_dash", direction, 190.0, 0.70)
	var finish := Vector2(dash["end"])
	swarm.call("damage_area", finish, 155.0, _damage(32.0))
	_add_visual({"type": "ring", "center": finish, "radius": 155.0, "color": accent, "ttl": 0.38, "max": 0.38})
	signature_timer = 0.0


func _ultimate_ops() -> void:
	ultimate_mode = "ops_p1"
	ultimate_left = 8.0
	swarm.call("damage_area", player.global_position, 310.0, _damage(58.0))
	swarm.call("push_area", player.global_position, 330.0, 55.0)
	_add_visual({"type": "ring", "center": player.global_position, "radius": 310.0, "color": accent, "ttl": 0.70, "max": 0.70})


func _ultimate_dba() -> void:
	if _count_zones("lock") <= 0:
		for index in range(3):
			_add_zone(player.global_position + Vector2.from_angle(TAU * float(index) / 3.0) * 145.0, "lock", 86.0, 4.0, 0.0)
	for zone in zones:
		if String(zone["kind"]) != "lock":
			continue
		var position_value := Vector2(zone["position"])
		swarm.call("damage_area", position_value, float(zone["radius"]) * 1.65, _damage(72.0))
		swarm.call("slow_area", position_value, float(zone["radius"]) * 1.65, 4.0)
		_add_visual({"type": "blast", "center": position_value, "radius": float(zone["radius"]) * 1.65, "color": accent, "ttl": 0.70, "max": 0.70})
	zones = zones.filter(func(zone: Dictionary) -> bool: return String(zone["kind"]) != "lock")


func _ultimate_network() -> void:
	ultimate_mode = "network_storm"
	ultimate_left = 6.0
	ultimate_tick = 0.0


func _ultimate_security() -> void:
	ultimate_mode = "security_lockdown"
	ultimate_left = 7.0
	ultimate_tick = 0.0


func _ultimate_it_ops() -> void:
	for index in range(4):
		_add_node(player.global_position + Vector2.from_angle(TAU * float(index) / 4.0) * 175.0, 10.0, "rack")
	ultimate_mode = "it_control"
	ultimate_left = 10.0


func _ultimate_helpdesk() -> void:
	ultimate_mode = "helpdesk_sla"
	ultimate_left = 8.0
	signature_timer = 0.0


func _ultimate_opsdev() -> void:
	for index in range(3):
		pending_actions.append({"type": "iac_wave", "delay": float(index) * 0.48, "stage": index, "center": player.global_position})


func _ultimate_sre() -> void:
	ultimate_mode = "sre_budget"
	ultimate_left = 6.0
	ultimate_tick = 0.0


func _ultimate_delivery() -> void:
	for index in range(3):
		pending_actions.append({"type": "release_wave", "delay": float(index) * 0.52, "stage": index, "center": player.global_position})


func _ultimate_ai_infra() -> void:
	ultimate_mode = "ai_scale"
	ultimate_left = 10.0
	signature_timer = 0.0


func _update_packet_capture(delta: float) -> void:
	packet_capture_left = maxf(0.0, packet_capture_left - delta)
	var buff_active := packet_capture_left > 0.0 and player.global_position.distance_to(packet_capture_position) <= 210.0
	if combat != null and combat.has_method("set_temporary_damage_multiplier"):
		combat.call("set_temporary_damage_multiplier", 1.15 if buff_active else 1.0)


func _update_walls(delta: float) -> void:
	var index := walls.size() - 1
	while index >= 0:
		var wall: Dictionary = walls[index]
		wall["ttl"] = float(wall["ttl"]) - delta
		wall["tick"] = float(wall["tick"]) - delta
		if float(wall["tick"]) <= 0.0:
			var start := Vector2(wall["start"])
			var finish := Vector2(wall["end"])
			swarm.call("damage_line", start, finish, 22.0, _damage(8.0), -1)
			for sample_index in range(5):
				var sample := start.lerp(finish, float(sample_index) / 4.0)
				swarm.call("slow_area", sample, 34.0, 0.55)
				swarm.call("push_area", sample, 36.0, 11.0)
			wall["tick"] = 0.32
		walls[index] = wall
		if float(wall["ttl"]) <= 0.0:
			walls.remove_at(index)
		index -= 1


func _update_zones(delta: float) -> void:
	var index := zones.size() - 1
	while index >= 0:
		var zone: Dictionary = zones[index]
		zone["ttl"] = float(zone["ttl"]) - delta
		zone["arm"] = maxf(0.0, float(zone["arm"]) - delta)
		zone["tick"] = float(zone["tick"]) - delta
		if float(zone["arm"]) <= 0.0 and float(zone["tick"]) <= 0.0:
			var kind := String(zone["kind"])
			var position_value := Vector2(zone["position"])
			var radius := float(zone["radius"])
			if kind == "lock":
				swarm.call("damage_area", position_value, radius, _damage(9.0))
				swarm.call("slow_area", position_value, radius, 0.75)
			elif kind == "heal" and player.global_position.distance_to(position_value) <= radius:
				player.call("heal", 1.1)
			zone["tick"] = 0.58
		zones[index] = zone
		if float(zone["ttl"]) <= 0.0:
			zones.remove_at(index)
		index -= 1


func _update_nodes(delta: float) -> void:
	var index := nodes.size() - 1
	while index >= 0:
		var node: Dictionary = nodes[index]
		node["ttl"] = float(node["ttl"]) - delta
		node["tick"] = float(node["tick"]) - delta
		if float(node["tick"]) <= 0.0:
			var position_value := Vector2(node["position"])
			var radius := 128.0 if String(node["kind"]) == "rack" else 104.0
			swarm.call("damage_area", position_value, radius, _damage(18.0 if String(node["kind"]) == "rack" else 12.0))
			_add_visual({"type": "ring", "center": position_value, "radius": radius, "color": accent, "ttl": 0.26, "max": 0.26})
			if player.global_position.distance_to(position_value) <= 76.0:
				player.call("heal", 0.7)
			node["tick"] = 1.0
		nodes[index] = node
		if float(node["ttl"]) <= 0.0:
			nodes.remove_at(index)
		index -= 1


func _update_pending_actions(delta: float) -> void:
	var index := pending_actions.size() - 1
	while index >= 0:
		var pending: Dictionary = pending_actions[index]
		pending["delay"] = float(pending["delay"]) - delta
		if float(pending["delay"]) <= 0.0:
			_resolve_pending(pending)
			pending_actions.remove_at(index)
		else:
			pending_actions[index] = pending
		index -= 1


func _resolve_pending(pending: Dictionary) -> void:
	var type := String(pending["type"])
	match type:
		"script_repeat":
			var position_value := Vector2(pending["position"])
			swarm.call("damage_area", position_value, 42.0, float(pending["damage"]))
			_add_visual({"type": "blast", "center": position_value, "radius": 42.0, "color": accent, "ttl": 0.26, "max": 0.26})
			var repeat := int(pending.get("repeat", 1))
			if repeat > 1:
				pending_actions.append({"type": "script_repeat", "delay": 0.34, "position": position_value, "damage": float(pending["damage"]) * 0.9, "repeat": repeat - 1})
		"release_package":
			var position_value := Vector2(pending["position"])
			var radius := float(pending["radius"])
			swarm.call("damage_area", position_value, radius, float(pending["damage"]))
			_add_visual({"type": "blast", "center": position_value, "radius": radius, "color": accent, "ttl": 0.48, "max": 0.48})
			_add_zone(position_value, "uat", radius * 0.82, 4.0, 0.0)
		"iac_wave":
			var stage := int(pending["stage"])
			var radius := 360.0 + float(stage) * 230.0
			swarm.call("damage_area", player.global_position, radius, _damage(26.0 + float(stage) * 12.0))
			_add_visual({"type": "ring", "center": player.global_position, "radius": radius, "color": accent, "ttl": 0.62, "max": 0.62})
			if stage == 2 and combat != null:
				for upgrade_id in combat.call("get_weapon_upgrade_ids"):
					combat.call("prime_upgraded_skill", String(upgrade_id))
		"release_wave":
			var stage := int(pending["stage"])
			var radius := 220.0 + float(stage) * 150.0
			swarm.call("damage_area", player.global_position, radius, _damage(30.0 + float(stage) * 17.0))
			swarm.call("push_area", player.global_position, radius, 24.0 + float(stage) * 14.0)
			_add_visual({"type": "ring", "center": player.global_position, "radius": radius, "color": accent, "ttl": 0.60, "max": 0.60})


func _update_ultimate(delta: float) -> void:
	if ultimate_left <= 0.0:
		ultimate_mode = ""
		return
	ultimate_left = maxf(0.0, ultimate_left - delta)
	ultimate_tick -= delta
	match ultimate_mode:
		"network_storm":
			if ultimate_tick <= 0.0:
				swarm.call("damage_area", player.global_position, 485.0, _damage(21.0))
				swarm.call("slow_area", player.global_position, 485.0, 0.8)
				_add_visual({"type": "ring", "center": player.global_position, "radius": 485.0, "color": accent, "ttl": 0.52, "max": 0.52})
				ultimate_tick = 0.58
		"security_lockdown":
			if ultimate_tick <= 0.0:
				swarm.call("damage_area", player.global_position, 275.0, _damage(15.0))
				swarm.call("slow_area", player.global_position, 285.0, 0.9)
				swarm.call("push_area", player.global_position, 285.0, 15.0)
				ultimate_tick = 0.42
		"sre_budget":
			player.call("grant_invulnerability", 0.24)
			player.call("heal", delta * 3.8)
			if ultimate_tick <= 0.0:
				swarm.call("slow_area", player.global_position, 720.0, 1.0)
				swarm.call("damage_area", player.global_position, 310.0, _damage(12.0))
				_add_visual({"type": "ring", "center": player.global_position, "radius": 310.0, "color": accent, "ttl": 0.48, "max": 0.48})
				ultimate_tick = 0.55
	if ultimate_left <= 0.0:
		ultimate_mode = ""


func _record_position_history(delta: float) -> void:
	history_tick -= delta
	if history_tick > 0.0:
		return
	history_tick = 0.10
	position_history.append(player.global_position)
	while position_history.size() > 11:
		position_history.remove_at(0)


func _add_wall(start: Vector2, finish: Vector2, duration: float, kind: String) -> void:
	walls.append({"start": start, "end": finish, "ttl": duration, "tick": 0.0, "kind": kind})


func _add_zone(position_value: Vector2, kind: String, radius: float, duration: float, arm_time: float) -> void:
	zones.append({"position": position_value, "kind": kind, "radius": radius, "ttl": duration, "arm": arm_time, "tick": 0.0})


func _add_node(position_value: Vector2, duration: float, kind: String) -> void:
	nodes.append({"position": position_value, "kind": kind, "ttl": duration, "tick": 0.0})


func _count_zones(kind: String) -> int:
	var result := 0
	for zone in zones:
		if String(zone["kind"]) == kind:
			result += 1
	return result


func _remove_oldest_zone(kind: String) -> void:
	for index in range(zones.size()):
		if String(zones[index]["kind"]) == kind:
			zones.remove_at(index)
			return


func _worker_count() -> int:
	return 8 if ultimate_mode == "ai_scale" else 2


func _worker_positions() -> Array[Vector2]:
	var result: Array[Vector2] = []
	var count := _worker_count()
	for index in range(count):
		result.append(player.global_position + Vector2.from_angle(worker_angle + TAU * float(index) / float(count)) * (108.0 if count <= 2 else 142.0))
	return result


func _target_position(maximum_range: float, fallback: Vector2) -> Vector2:
	var target: Dictionary = swarm.call("get_nearest_target", player.global_position, maximum_range)
	return Vector2(target["position"]) if bool(target.get("hit", false)) else fallback


func _aim_direction(maximum_range: float) -> Vector2:
	if projection != null and projection.call("is_targetable"):
		var projection_offset := projection.global_position - player.global_position
		if projection_offset.length() <= maximum_range and projection_offset.length_squared() > 0.01:
			return projection_offset.normalized()
	var target: Dictionary = swarm.call("get_nearest_target", player.global_position, maximum_range)
	if bool(target.get("hit", false)):
		var offset := Vector2(target["position"]) - player.global_position
		if offset.length_squared() > 0.01:
			return offset.normalized()
	return facing_direction


func _damage_projection_from_signature(archetype: String) -> void:
	if projection == null or not projection.call("is_targetable"):
		return
	var offset := projection.global_position - player.global_position
	var distance := offset.length()
	var can_hit := false
	var amount := _damage(13.0)
	match archetype:
		"melee_combo":
			can_hit = distance <= 132.0
			amount = _damage(24.0)
		"piercing_projectile":
			can_hit = distance <= 650.0
			amount = _damage(22.0)
		"persistent_wall", "deployable_node", "adaptive_ring":
			can_hit = distance <= 180.0
		"delayed_zone", "delayed_aoe":
			can_hit = distance <= 390.0
		"chain_bounce", "delayed_repeat", "autonomous_summon":
			can_hit = distance <= 470.0
	if can_hit:
		projection.call("take_shell_damage", amount)


func _resolved_direction(direction: Vector2) -> Vector2:
	if direction.length_squared() > 0.04:
		return direction.normalized()
	return _aim_direction(420.0)


func _damage(base_damage: float) -> float:
	var packet_multiplier := 1.15 if packet_capture_left > 0.0 and player.global_position.distance_to(packet_capture_position) <= 210.0 else 1.0
	return base_damage * damage_multiplier * packet_multiplier


func _add_visual(effect: Dictionary) -> void:
	visuals.append(effect)
	while visuals.size() > MAX_VISUALS:
		visuals.remove_at(0)


func _update_visuals(delta: float) -> void:
	var index := visuals.size() - 1
	while index >= 0:
		visuals[index]["ttl"] = float(visuals[index]["ttl"]) - delta
		if float(visuals[index]["ttl"]) <= 0.0:
			visuals.remove_at(index)
		index -= 1


func _draw() -> void:
	if player == null:
		return
	if packet_capture_left > 0.0:
		draw_circle(packet_capture_position, 210.0, Color(accent, 0.055))
		draw_arc(packet_capture_position, 210.0, 0.0, TAU, 64, Color(accent, 0.82), 3.0)
		draw_arc(packet_capture_position, 154.0, 0.0, TAU, 48, Color(accent, 0.36), 1.0)
	for wall in walls:
		var start := Vector2(wall["start"])
		var finish := Vector2(wall["end"])
		draw_line(start, finish, Color(0.03, 0.08, 0.10, 0.92), 18.0)
		draw_line(start, finish, Color(accent, 0.88), 8.0)
		for node_index in range(7):
			var point := start.lerp(finish, float(node_index) / 6.0)
			draw_rect(Rect2(point - Vector2(4, 4), Vector2(8, 8)), accent, false, 2.0)
	for zone in zones:
		var position_value := Vector2(zone["position"])
		var radius := float(zone["radius"])
		var kind := String(zone["kind"])
		var color := Color("c68cff") if kind == "lock" else (Color("65e890") if kind == "heal" else Color("ffce73"))
		draw_circle(position_value, radius, Color(color, 0.045))
		draw_arc(position_value, radius, 0.0, TAU, 42, Color(color, 0.76), 2.0)
		draw_line(position_value + Vector2(-radius * 0.65, 0), position_value + Vector2(radius * 0.65, 0), Color(color, 0.34), 1.0)
	for node in nodes:
		var position_value := Vector2(node["position"])
		var is_rack := String(node["kind"]) == "rack"
		var size := Vector2(34, 42) if is_rack else Vector2(26, 30)
		draw_rect(Rect2(position_value - size * 0.5, size), Color("13272e"), true)
		draw_rect(Rect2(position_value - size * 0.5, size), accent, false, 3.0)
		draw_circle(position_value + Vector2(0, -5), 3.0, Color("d6fff1"))
	if career_id == "ai_infra":
		for worker_position in _worker_positions():
			draw_line(player.global_position, worker_position, Color(accent, 0.18), 1.0)
			draw_circle(worker_position, 10.0, Color("173d31"))
			draw_rect(Rect2(worker_position - Vector2(8, 6), Vector2(16, 12)), accent, false, 2.0)
	if ultimate_mode == "security_lockdown":
		var points := PackedVector2Array()
		for index in range(6):
			points.append(player.global_position + Vector2.from_angle(TAU * float(index) / 6.0) * 275.0)
		for index in range(6):
			draw_line(points[index], points[(index + 1) % 6], Color(accent, 0.86), 8.0)
	if ultimate_mode in ["ops_p1", "network_storm", "sre_budget", "helpdesk_sla", "ai_scale"]:
		var aura_radius: float = float({"ops_p1": 145.0, "network_storm": 485.0, "sre_budget": 310.0, "helpdesk_sla": 185.0, "ai_scale": 165.0}.get(ultimate_mode, 160.0))
		draw_arc(player.global_position, float(aura_radius), 0.0, TAU, 64, Color(accent, 0.55), 3.0)
	for effect in visuals:
		var alpha := clampf(float(effect["ttl"]) / maxf(0.001, float(effect["max"])), 0.0, 1.0)
		var color := Color(effect["color"])
		color.a *= alpha
		match String(effect["type"]):
			"beam": draw_line(Vector2(effect["from"]), Vector2(effect["to"]), color, float(effect.get("width", 3.0)))
			"arc": draw_arc(Vector2(effect["center"]), float(effect["radius"]), float(effect["start"]), float(effect["end"]), 28, color, 7.0)
			"blast":
				draw_circle(Vector2(effect["center"]), float(effect["radius"]) * (1.0 - alpha * 0.15), Color(color, color.a * 0.10))
				draw_arc(Vector2(effect["center"]), float(effect["radius"]), 0.0, TAU, 42, color, 4.0)
			"marker":
				draw_arc(Vector2(effect["center"]), float(effect["radius"]), 0.0, TAU, 32, color, 2.0)
				draw_line(Vector2(effect["center"]) + Vector2(-12, 0), Vector2(effect["center"]) + Vector2(12, 0), color, 2.0)
			_:
				draw_arc(Vector2(effect["center"]), float(effect["radius"]), 0.0, TAU, 48, color, 3.0)


func _exit_tree() -> void:
	if combat != null and combat.has_method("set_temporary_damage_multiplier"):
		combat.call("set_temporary_damage_multiplier", 1.0)
