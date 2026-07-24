extends Node2D

signal build_changed(summary: String)
signal attack_fired(weapon_id: String, world_position: Vector2, intensity: float)

const MAX_EFFECTS := 180
const SHAPE_GROWTH_LIMIT := 5
const RULE_CHAIN_DIRECT_NODE_LIMIT := 12

var player: Node2D
var swarm: Node2D
var projection: Node2D
var career_id := "ops"
var career_name := "运维工程师"
var career_damage_multiplier := 1.0
var career_cooldown_multiplier := 1.0
var career_area_multiplier := 1.0
var career_melee_multiplier := 1.0
var career_control_multiplier := 1.0
var career_summon_bonus := 0
var career_summon_damage_multiplier := 1.0
var temporary_damage_multiplier := 1.0
var artifact_damage_multiplier := 1.0
var artifact_cooldown_multiplier := 1.0

var bash_level := 1
var ping_level := 0
var firewall_level := 0
var log_level := 0
var idempotency_level := 0
var evolved_iac := false
var wrench_level := 0
var rule_chain_level := 0
var lock_zone_level := 0
var worker_level := 0

var oncall_arch_level := 0
var zero_trust_arch_level := 0
var query_arch_level := 0
var autoscale_arch_level := 0

var bash_timer := 0.15
var ping_timer := 2.2
var firewall_timer := 0.3
var log_timer := 1.4
var wrench_timer := 0.35
var rule_chain_timer := 0.2
var lock_place_timer := 1.0
var worker_timer := 0.55
var rule_chain_angle := 0.0
var worker_angle := 0.0
var wrench_flip := 1.0
var facing_direction := Vector2.RIGHT
var lock_zones: Array[Dictionary] = []
var effects: Array[Dictionary] = []


func configure(player_node: Node2D, swarm_node: Node2D, projection_node: Node2D) -> void:
	player = player_node
	swarm = swarm_node
	projection = projection_node
	_emit_build()


func configure_career(career: Dictionary) -> void:
	career_id = String(career.get("id", "ops"))
	career_name = String(career.get("name", "运维工程师"))
	var modifiers: Dictionary = career.get("combat", {})
	career_damage_multiplier = float(modifiers.get("damage", 1.0))
	career_cooldown_multiplier = float(modifiers.get("cooldown", 1.0))
	career_area_multiplier = float(modifiers.get("area", 1.0))
	career_melee_multiplier = float(modifiers.get("melee", 1.0))
	career_control_multiplier = float(modifiers.get("control", 1.0))
	career_summon_bonus = int(modifiers.get("summons", 0))
	career_summon_damage_multiplier = float(modifiers.get("summon_damage", 1.0))
	temporary_damage_multiplier = 1.0
	artifact_damage_multiplier = 1.0
	artifact_cooldown_multiplier = 1.0
	bash_level = 0
	ping_level = 0
	firewall_level = 0
	log_level = 0
	wrench_level = 0
	rule_chain_level = 0
	lock_zone_level = 0
	worker_level = 0
	idempotency_level = 0
	evolved_iac = false
	oncall_arch_level = 0
	zero_trust_arch_level = 0
	query_arch_level = 0
	autoscale_arch_level = 0
	lock_zones.clear()
	for upgrade_id in career.get("starting_upgrades", ["bash"]):
		if String(upgrade_id) in get_weapon_upgrade_ids() or String(upgrade_id) == "idempotency":
			apply_upgrade(String(upgrade_id))
	ping_timer = 0.0
	firewall_timer = 0.0
	log_timer = 0.0
	wrench_timer = 0.0
	rule_chain_timer = 0.0
	lock_place_timer = 0.0
	worker_timer = 0.0
	_emit_build()


func get_weapon_count() -> int:
	var total := 0
	for upgrade_id in get_weapon_upgrade_ids():
		if get_upgrade_level(upgrade_id) > 0:
			total += 1
	return total


func get_worker_count() -> int:
	return _worker_count(worker_level)


func set_temporary_damage_multiplier(value: float) -> void:
	temporary_damage_multiplier = clampf(value, 0.25, 3.0)


func set_artifact_modifiers(damage_value: float, cooldown_value: float) -> void:
	var previous_cooldown := artifact_cooldown_multiplier
	artifact_damage_multiplier = clampf(damage_value, 0.50, 2.0)
	artifact_cooldown_multiplier = clampf(cooldown_value, 0.55, 1.25)
	var timer_ratio := artifact_cooldown_multiplier / maxf(0.001, previous_cooldown)
	for timer_name in ["bash_timer", "ping_timer", "firewall_timer", "log_timer", "wrench_timer", "rule_chain_timer", "lock_place_timer", "worker_timer"]:
		set(timer_name, maxf(0.0, float(get(timer_name)) * timer_ratio))


func _global_damage_multiplier() -> float:
	return career_damage_multiplier * temporary_damage_multiplier * artifact_damage_multiplier


func _physics_process(delta: float) -> void:
	if player == null or swarm == null:
		return
	bash_timer -= delta
	ping_timer -= delta
	firewall_timer -= delta
	log_timer -= delta
	wrench_timer -= delta
	rule_chain_timer -= delta
	lock_place_timer -= delta
	worker_timer -= delta
	rule_chain_angle += delta * _rule_chain_speed(rule_chain_level)
	worker_angle -= delta * 0.72
	if player is CharacterBody2D:
		var player_body := player as CharacterBody2D
		if player_body.velocity.length_squared() > 4.0:
			facing_direction = player_body.velocity.normalized()

	if bash_level > 0 and bash_timer <= 0.0:
		_fire_bash()
		bash_timer = _bash_cooldown(bash_level)
	if ping_level > 0 and ping_timer <= 0.0:
		var ping_radius := _ping_radius(ping_level)
		var pulse_damage := _ping_damage(ping_level)
		var pulse_count := _ping_pulses(ping_level)
		for pulse_index in range(pulse_count):
			var pulse_ratio := float(pulse_index + 1) / float(pulse_count)
			var pulse_radius := ping_radius * lerpf(0.55, 1.0, pulse_ratio)
			var damage_scale := 1.0 if pulse_index == pulse_count - 1 else 0.28 + float(_shape_level(ping_level)) * 0.035
			swarm.call("damage_area", player.global_position, pulse_radius, pulse_damage * damage_scale)
			_add_ring(player.global_position, pulse_radius, Color("47c9f1"), 0.32 + pulse_ratio * 0.24)
		if projection != null and projection.call("is_targetable") and projection.global_position.distance_to(player.global_position) <= ping_radius:
			projection.call("take_shell_damage", pulse_damage * float(pulse_count) * 0.8)
		attack_fired.emit("ping", player.global_position, 1.0 + float(ping_level) * 0.16)
		ping_timer = _ping_cooldown(ping_level)
	if firewall_level > 0 and firewall_timer <= 0.0:
		var outer_radius := _firewall_radius(firewall_level)
		swarm.call("damage_area", player.global_position, outer_radius, _firewall_damage(firewall_level))
		for layer in range(1, _firewall_layers(firewall_level) + 1):
			var layer_radius := _firewall_layer_radius(layer, firewall_level)
			_add_ring(player.global_position, layer_radius, Color("efb23d"), 0.18 + float(layer) * 0.025)
		swarm.call("push_area", player.global_position, outer_radius, 10.0 + float(_shape_level(firewall_level)) * 4.0)
		attack_fired.emit("firewall", player.global_position, 1.0 + float(firewall_level) * 0.14)
		firewall_timer = _firewall_cooldown(firewall_level)
	if log_level > 0 and log_timer <= 0.0:
		var target_positions: Array[Vector2] = swarm.call("get_random_enemy_positions", _log_targets(log_level))
		for target_index in range(target_positions.size()):
			var target_position := target_positions[target_index]
			var damage_scale := 1.0 if target_index == 0 else _log_secondary_ratio(log_level)
			swarm.call("damage_area", target_position, _log_radius(log_level), _log_damage(log_level) * damage_scale)
			_add_blast(target_position, _log_radius(log_level), Color("ba77e8"), 0.46)
		if not target_positions.is_empty():
			attack_fired.emit("log", player.global_position, 1.0 + float(log_level) * 0.12)
		log_timer = _log_cooldown(log_level)
	if wrench_level > 0 and wrench_timer <= 0.0:
		_fire_wrench()
		wrench_timer = _wrench_cooldown(wrench_level)
	if rule_chain_level > 0 and rule_chain_timer <= 0.0:
		_tick_rule_chain()
		rule_chain_timer = _rule_chain_tick(rule_chain_level)
	if lock_zone_level > 0:
		if lock_place_timer <= 0.0:
			_place_lock_zone()
			lock_place_timer = _lock_zone_cooldown(lock_zone_level)
		_update_lock_zones(delta)
	if worker_level > 0 and worker_timer <= 0.0:
		_fire_worker_salvo()
		worker_timer = _worker_cooldown(worker_level)

	var effect_index := effects.size() - 1
	while effect_index >= 0:
		effects[effect_index]["ttl"] = float(effects[effect_index]["ttl"]) - delta
		if float(effects[effect_index]["ttl"]) <= 0.0:
			effects.remove_at(effect_index)
		effect_index -= 1
	queue_redraw()


func _fire_bash() -> void:
	var maximum_range := _bash_range(bash_level)
	var damage := _effective_bash_damage(bash_level)
	var target_count := _effective_bash_targets(bash_level)

	if projection != null and projection.call("is_targetable"):
		var projection_distance := player.global_position.distance_to(projection.global_position)
		if projection_distance <= maximum_range:
			projection.call("take_shell_damage", damage * (1.0 + float(target_count - 1) * 0.55))
			for bolt_index in range(target_count):
				var angle := TAU * float(bolt_index) / float(maxi(1, target_count))
				var offset := Vector2.from_angle(angle) * float(bolt_index) * 3.0
				_add_beam(player.global_position + offset, projection.global_position + offset * 0.35, Color("ef68d8"), 0.14 + float(bolt_index) * 0.025)
			attack_fired.emit("bash", player.global_position, 1.0 + float(bash_level) * 0.13)
			return

	var hit_positions: Array[Vector2] = swarm.call("damage_nearest_targets", player.global_position, maximum_range, damage, target_count, _bash_secondary_ratio(bash_level))
	for hit_position in hit_positions:
		_add_beam(player.global_position, hit_position, Color("56e6dc") if not evolved_iac else Color("9cff72"), 0.14)
		if evolved_iac:
			var splash_radius := 44.0
			swarm.call("damage_area", hit_position, splash_radius, damage * 0.35)
			_add_ring(hit_position, splash_radius, Color("9cff72") if evolved_iac else Color("56e6dc"), 0.18)
	if not hit_positions.is_empty():
		attack_fired.emit("bash", player.global_position, 1.0 + float(bash_level) * 0.13)


func _fire_wrench() -> void:
	var direction := facing_direction
	var target: Dictionary = swarm.call("get_nearest_target", player.global_position, _wrench_reach(wrench_level) + 34.0)
	if bool(target.get("hit", false)):
		direction = (Vector2(target["position"]) - player.global_position).normalized()
	var sweep_count := _wrench_sweeps(wrench_level)
	var half_angle := _wrench_half_angle(wrench_level)
	for sweep_index in range(sweep_count):
		var center_offset := (float(sweep_index) - float(sweep_count - 1) * 0.5) * 0.34
		var sweep_direction := direction.rotated(center_offset * wrench_flip)
		var damage_scale := 1.0 if sweep_index == 0 else 0.58
		swarm.call("damage_arc", player.global_position, sweep_direction, _wrench_reach(wrench_level), half_angle, _wrench_damage(wrench_level) * damage_scale)
		_add_arc(player.global_position, _wrench_reach(wrench_level), sweep_direction.angle() - half_angle, sweep_direction.angle() + half_angle, Color("ffb454"), 0.24 + float(sweep_index) * 0.04)
	attack_fired.emit("wrench", player.global_position, 1.0 + float(wrench_level) * 0.13)
	wrench_flip *= -1.0


func _tick_rule_chain() -> void:
	var node_positions := _rule_chain_positions()
	var total_hits := 0
	if node_positions.size() > RULE_CHAIN_DIRECT_NODE_LIMIT:
		var dense_scale := minf(2.0, 1.0 + log(float(node_positions.size()) / float(RULE_CHAIN_DIRECT_NODE_LIMIT)) * 0.28)
		total_hits = int(swarm.call("damage_ring", player.global_position, _rule_chain_radius(rule_chain_level), _rule_chain_hit_radius(rule_chain_level), _rule_chain_damage(rule_chain_level) * dense_scale))
		if total_hits > 0:
			for sample_index in range(RULE_CHAIN_DIRECT_NODE_LIMIT):
				var node_index := floori(float(sample_index) * float(node_positions.size()) / float(RULE_CHAIN_DIRECT_NODE_LIMIT))
				_add_ring(node_positions[mini(node_index, node_positions.size() - 1)], _rule_chain_hit_radius(rule_chain_level) + 4.0, Color("ee6677"), 0.14)
			attack_fired.emit("rule_chain", player.global_position, 1.0 + float(rule_chain_level) * 0.11)
		return
	for node_position in node_positions:
		var hits: int = swarm.call("damage_area", node_position, _rule_chain_hit_radius(rule_chain_level), _rule_chain_damage(rule_chain_level))
		total_hits += hits
		if hits > 0:
			_add_ring(node_position, _rule_chain_hit_radius(rule_chain_level) + 4.0, Color("ee6677"), 0.14)
	if total_hits > 0:
		attack_fired.emit("rule_chain", player.global_position, 1.0 + float(rule_chain_level) * 0.11)


func _place_lock_zone() -> void:
	if lock_zones.size() >= _lock_zone_limit(lock_zone_level):
		lock_zones.remove_at(0)
	var side := float((lock_zones.size() % 3) - 1) * 34.0
	var placement := player.global_position - facing_direction * 34.0 + facing_direction.orthogonal() * side
	lock_zones.append({
		"position": placement,
		"ttl": 13.0,
		"arm": 0.45,
		"active": false,
		"active_left": 0.0,
		"tick": 0.0,
	})


func _update_lock_zones(delta: float) -> void:
	var index := lock_zones.size() - 1
	while index >= 0:
		var zone: Dictionary = lock_zones[index]
		zone["ttl"] = float(zone["ttl"]) - delta
		zone["arm"] = maxf(0.0, float(zone["arm"]) - delta)
		var zone_position := Vector2(zone["position"])
		if not bool(zone["active"]) and float(zone["arm"]) <= 0.0 and bool(swarm.call("has_enemy_in_area", zone_position, _lock_zone_radius(lock_zone_level))):
			zone["active"] = true
			zone["active_left"] = _lock_zone_duration(lock_zone_level)
			zone["tick"] = 0.0
			_add_ring(zone_position, _lock_zone_radius(lock_zone_level), Color("c68cff"), 0.36)
			attack_fired.emit("lock_zone", zone_position, 1.0 + float(lock_zone_level) * 0.12)
		if bool(zone["active"]):
			zone["active_left"] = float(zone["active_left"]) - delta
			zone["tick"] = float(zone["tick"]) - delta
			if float(zone["tick"]) <= 0.0:
				swarm.call("damage_area", zone_position, _lock_zone_radius(lock_zone_level), _lock_zone_damage(lock_zone_level))
				swarm.call("slow_area", zone_position, _lock_zone_radius(lock_zone_level), 0.82)
				_add_ring(zone_position, _lock_zone_radius(lock_zone_level), Color("c68cff"), 0.22)
				zone["tick"] = _lock_zone_tick(lock_zone_level)
		lock_zones[index] = zone
		if float(zone["ttl"]) <= 0.0 or (bool(zone["active"]) and float(zone["active_left"]) <= 0.0):
			lock_zones.remove_at(index)
		index -= 1


func _fire_worker_salvo() -> void:
	var worker_positions := _worker_positions()
	if worker_positions.is_empty():
		return
	var maximum_targets := worker_positions.size() * _worker_targets_per_unit(worker_level)
	var hit_positions: Array[Vector2] = swarm.call("damage_nearest_targets", player.global_position, _worker_range(worker_level), _worker_damage(worker_level), maximum_targets, 1.0)
	for hit_index in range(hit_positions.size()):
		var source := worker_positions[hit_index % worker_positions.size()]
		_add_beam(source, hit_positions[hit_index], Color("91ee70"), 0.18)
		_add_ring(hit_positions[hit_index], 16.0, Color("91ee70"), 0.14)
	if not hit_positions.is_empty():
		attack_fired.emit("worker", player.global_position, 1.0 + float(worker_level) * 0.10)


func apply_upgrade(upgrade_id: String) -> void:
	match upgrade_id:
		"bash": bash_level += 1
		"ping": ping_level += 1
		"firewall": firewall_level += 1
		"log": log_level += 1
		"wrench": wrench_level += 1
		"rule_chain": rule_chain_level += 1
		"lock_zone": lock_zone_level += 1
		"worker": worker_level += 1
		"idempotency": idempotency_level = mini(3, idempotency_level + 1)
		"iac": evolved_iac = true
		"arch_oncall":
			oncall_arch_level = mini(2, oncall_arch_level + 1)
			wrench_level = maxi(1, wrench_level)
		"arch_zero_trust":
			zero_trust_arch_level = mini(2, zero_trust_arch_level + 1)
			rule_chain_level = maxi(1, rule_chain_level)
		"arch_query":
			query_arch_level = mini(2, query_arch_level + 1)
			lock_zone_level = maxi(1, lock_zone_level)
		"arch_autoscale":
			autoscale_arch_level = mini(2, autoscale_arch_level + 1)
			worker_level = maxi(1, worker_level)
	_emit_build()


func can_evolve() -> bool:
	return bash_level >= 3 and idempotency_level >= 1 and not evolved_iac


func get_upgrade_level(upgrade_id: String) -> int:
	match upgrade_id:
		"bash": return bash_level
		"ping": return ping_level
		"firewall": return firewall_level
		"log": return log_level
		"wrench": return wrench_level
		"rule_chain": return rule_chain_level
		"lock_zone": return lock_zone_level
		"worker": return worker_level
		"idempotency": return idempotency_level
		"iac": return 1 if evolved_iac else 0
		"arch_oncall": return oncall_arch_level
		"arch_zero_trust": return zero_trust_arch_level
		"arch_query": return query_arch_level
		"arch_autoscale": return autoscale_arch_level
	return 0


func get_weapon_upgrade_ids() -> Array[String]:
	return ["bash", "ping", "firewall", "log", "wrench", "rule_chain", "lock_zone", "worker"]


func get_architecture_upgrade_ids() -> Array[String]:
	return ["arch_oncall", "arch_zero_trust", "arch_query", "arch_autoscale"]


func get_upgrade_card(upgrade_id: String) -> Dictionary:
	var current := get_upgrade_level(upgrade_id)
	var next := current + 1
	if upgrade_id == "idempotency":
		next = mini(3, current + 1)
	elif upgrade_id.begins_with("arch_"):
		next = mini(2, current + 1)
	match upgrade_id:
		"bash":
			return {
				"id": upgrade_id,
				"name": "Bash 脚本  %s %d → %d" % [_stack_mode_label(next), current, next],
				"title": _stack_upgrade_title("Bash 脚本", next),
				"description": "伤害 %d→%d · 并发 %d→%d · 范围 %d→%dpx · 冷却 %.2f→%.2fs" % [
					int(round(_effective_bash_damage(current))), int(round(_effective_bash_damage(next))), _effective_bash_targets(current), _effective_bash_targets(next),
					int(_bash_range(current)), int(_bash_range(next)), _bash_cooldown(current), _bash_cooldown(next),
				] + _overclock_card_note(next),
				"color": Color("56e6dc"),
			}
		"ping":
			var ping_description := "脉冲数 %d→%d · 半径 %d→%dpx · 单次伤害 %d→%d · 冷却 %.2f→%.2fs" % [
				_ping_pulses(current), _ping_pulses(next), int(_ping_radius(current)), int(_ping_radius(next)), int(_ping_damage(current)), int(_ping_damage(next)),
				_ping_cooldown(current), _ping_cooldown(next),
			]
			if current == 0:
				ping_description = "解锁 1 重扫描脉冲 · 半径 %dpx · 伤害 %d · 冷却 %.2fs" % [int(_ping_radius(next)), int(_ping_damage(next)), _ping_cooldown(next)]
			ping_description += _overclock_card_note(next)
			return {
				"id": upgrade_id,
				"name": "Ping 扫描  %s %d → %d" % [_stack_mode_label(next), current, next],
				"title": _stack_upgrade_title("Ping 扫描", next),
				"description": ping_description,
				"color": Color("47c9f1"),
			}
		"firewall":
			var firewall_description := "规则环 %d→%d · 外圈 %d→%dpx · 每跳伤害 %.0f→%.0f · 击退同步增强" % [
				_firewall_layers(current), _firewall_layers(next), int(_firewall_radius(current)), int(_firewall_radius(next)), _firewall_damage(current), _firewall_damage(next),
			]
			if current == 0:
				firewall_description = "解锁持续规则环 · 半径 %dpx · 每跳伤害 %.0f · 自动击退近身故障" % [int(_firewall_radius(next)), _firewall_damage(next)]
			firewall_description += _overclock_card_note(next)
			return {
				"id": upgrade_id,
				"name": "防火墙规则  %s %d → %d" % [_stack_mode_label(next), current, next],
				"title": _stack_upgrade_title("防火墙", next),
				"description": firewall_description,
				"color": Color("efb23d"),
			}
		"log":
			var log_description := "并行落点 %d→%d · 爆破半径 %d→%dpx · 每点伤害 %d→%d · 冷却 %.2f→%.2fs" % [
				_log_targets(current), _log_targets(next), int(_log_radius(current)), int(_log_radius(next)),
				int(_log_damage(current)), int(_log_damage(next)), _log_cooldown(current), _log_cooldown(next),
			]
			if current == 0:
				log_description = "解锁 1 个日志落点 · 爆破半径 %dpx · 伤害 %d · 冷却 %.2fs" % [int(_log_radius(next)), int(_log_damage(next)), _log_cooldown(next)]
			log_description += _overclock_card_note(next)
			return {
				"id": upgrade_id,
				"name": "日志采集器  %s %d → %d" % [_stack_mode_label(next), current, next],
				"title": _stack_upgrade_title("日志采集", next),
				"description": log_description,
				"color": Color("ba77e8"),
			}
		"wrench":
			var wrench_description := "横扫 %d→%d 重 · 近战伤害 %d→%d · 距离 %d→%dpx · 冷却 %.2f→%.2fs" % [
				_wrench_sweeps(current), _wrench_sweeps(next), int(_wrench_damage(current)), int(_wrench_damage(next)),
				int(_wrench_reach(current)), int(_wrench_reach(next)), _wrench_cooldown(current), _wrench_cooldown(next),
			]
			if current == 0:
				wrench_description = "解锁贴身扇形横扫 · %d 伤害 · %dpx 距离 · 自动朝最近故障挥击" % [int(_wrench_damage(next)), int(_wrench_reach(next))]
			wrench_description += _overclock_card_note(next)
			return {
				"id": upgrade_id,
				"name": "机柜扳手  %s %d → %d" % [_stack_mode_label(next), current, next],
				"title": _stack_upgrade_title("机柜扳手", next),
				"description": wrench_description,
				"color": Color("ffb454"),
			}
		"rule_chain":
			var chain_description := "规则节点 %d→%d · 轨道 %d→%dpx · 单节点范围 %d→%dpx · 接触伤害 %.0f→%.0f" % [
				_rule_chain_nodes(current), _rule_chain_nodes(next), int(_rule_chain_radius(current)), int(_rule_chain_radius(next)),
				int(_rule_chain_hit_radius(current)), int(_rule_chain_hit_radius(next)),
				_rule_chain_damage(current), _rule_chain_damage(next),
			]
			if current == 0:
				chain_description = "解锁实体环绕规则链 · %d 个 ACL 节点 · 轨道 %dpx · 单节点范围 %dpx · 后续每阶节点与双重范围都扩大" % [_rule_chain_nodes(next), int(_rule_chain_radius(next)), int(_rule_chain_hit_radius(next))]
			chain_description += " · 超频继续每阶 +1 ACL 节点并扩大双重范围" if next > SHAPE_GROWTH_LIMIT else ""
			return {
				"id": upgrade_id,
				"name": "iptables 规则链  %s %d → %d" % [_stack_mode_label(next), current, next],
				"title": _stack_upgrade_title("规则链", next),
				"description": chain_description,
				"color": Color("ee6677"),
			}
		"lock_zone":
			var lock_description := "锁域上限 %d→%d · 半径 %d→%dpx · 持续 %.1f→%.1fs · 每跳伤害 %.0f→%.0f" % [
				_lock_zone_limit(current), _lock_zone_limit(next), int(_lock_zone_radius(current)), int(_lock_zone_radius(next)),
				_lock_zone_duration(current), _lock_zone_duration(next), _lock_zone_damage(current), _lock_zone_damage(next),
			]
			if current == 0:
				lock_description = "解锁地面慢查询锁域 · 敌人进入后持续减速并承受多次伤害"
			lock_description += _overclock_card_note(next)
			return {
				"id": upgrade_id,
				"name": "慢查询锁域  %s %d → %d" % [_stack_mode_label(next), current, next],
				"title": _stack_upgrade_title("慢查询锁域", next),
				"description": lock_description,
				"color": Color("c68cff"),
			}
		"worker":
			var worker_description := "Worker %d→%d · 每机目标 %d→%d · 伤害 %d→%d · 齐射 %.2f→%.2fs" % [
				_worker_count(current), _worker_count(next), _worker_targets_per_unit(current), _worker_targets_per_unit(next),
				int(_worker_damage(current)), int(_worker_damage(next)), _worker_cooldown(current), _worker_cooldown(next),
			]
			if current == 0:
				worker_description = "解锁自主 Worker Pod · 召唤物环绕编队并从独立位置自动齐射"
			worker_description += _overclock_card_note(next)
			return {
				"id": upgrade_id,
				"name": "Worker Pod  %s %d → %d" % [_stack_mode_label(next), current, next],
				"title": _stack_upgrade_title("Worker Pod", next),
				"description": worker_description,
				"color": Color("91ee70"),
			}
		"idempotency":
			return {
				"id": upgrade_id,
				"name": "幂等性  STACK %d → %d" % [current, next],
				"title": "幂等性叠加至 %d 层" % next,
				"description": "Bash 伤害倍率 %d%%→%d%% · 冷却缩短 %d%%→%d%% · 总并发 %d→%d · STACK 1 解锁 IaC" % [
					100 + current * 12, 100 + next * 12,
					current * 4, next * 4,
					_bash_targets(bash_level) + floori(float(current) / 2.0) + (1 if evolved_iac else 0),
					_bash_targets(bash_level) + floori(float(next) / 2.0) + (1 if evolved_iac else 0),
				],
				"color": Color("9cff72"),
			}
		"iac":
			return {
				"id": upgrade_id,
				"name": "进化：基础设施即代码",
				"title": "EVOLUTION · 基础设施即代码",
				"description": "保留全部 Bash 叠层 · 并发 +1 · 伤害 ×1.35 · 冷却 -12% · 范围 +60px · 获得 44px 闭环溅射",
				"color": Color("b8ff74"),
			}
		"arch_oncall":
			return {
				"id": upgrade_id,
				"name": "现场值守协议  %s" % ("部署" if current == 0 else "I → II"),
				"title": "ARCHITECTURE · 现场值守",
				"description": "签名技能：机柜扳手 · 扳手伤害每阶 +18%% · II 阶额外增加一重横扫",
				"color": Color("ffb454"),
			}
		"arch_zero_trust":
			return {
				"id": upgrade_id,
				"name": "零信任边界  %s" % ("部署" if current == 0 else "I → II"),
				"title": "ARCHITECTURE · 零信任边界",
				"description": "签名技能：iptables 规则链 · 每阶 +2 环绕节点 · 轨道 +12px · 单节点范围 +3px · 接触伤害 +18%",
				"color": Color("ee6677"),
			}
		"arch_query":
			return {
				"id": upgrade_id,
				"name": "查询治理协议  %s" % ("部署" if current == 0 else "I → II"),
				"title": "ARCHITECTURE · 查询治理",
				"description": "签名技能：慢查询锁域 · 每阶扩大锁域并延长批量执行窗口",
				"color": Color("c68cff"),
			}
		"arch_autoscale":
			return {
				"id": upgrade_id,
				"name": "弹性训练集群  %s" % ("部署" if current == 0 else "I → II"),
				"title": "ARCHITECTURE · 弹性训练集群",
				"description": "签名技能：Worker Pod · 每阶 +1 Worker，并提高自主齐射伤害",
				"color": Color("91ee70"),
			}
	return {"id": upgrade_id, "name": upgrade_id, "title": "能力已叠加", "description": "", "color": Color("75f3df")}


func get_build_summary() -> String:
	var parts: Array[String] = []
	if bash_level > 0: parts.append("Bash ×%d" % bash_level)
	if ping_level > 0: parts.append("Ping ×%d" % ping_level)
	if firewall_level > 0: parts.append("防火墙 ×%d" % firewall_level)
	if log_level > 0: parts.append("日志 ×%d" % log_level)
	if wrench_level > 0: parts.append("扳手 ×%d" % wrench_level)
	if rule_chain_level > 0: parts.append("规则链 ×%d" % rule_chain_level)
	if lock_zone_level > 0: parts.append("锁域 ×%d" % lock_zone_level)
	if worker_level > 0: parts.append("Worker ×%d" % worker_level)
	if idempotency_level > 0: parts.append("幂等 ×%d" % idempotency_level)
	if evolved_iac: parts.append("IaC 进化")
	if parts.is_empty(): parts.append("未安装主动工具")
	var architecture: Array[String] = []
	if oncall_arch_level > 0: architecture.append("现场值守 %s" % _roman_level(oncall_arch_level))
	if zero_trust_arch_level > 0: architecture.append("零信任 %s" % _roman_level(zero_trust_arch_level))
	if query_arch_level > 0: architecture.append("查询治理 %s" % _roman_level(query_arch_level))
	if autoscale_arch_level > 0: architecture.append("弹性集群 %s" % _roman_level(autoscale_arch_level))
	var summary := "  |  ".join(parts)
	if not architecture.is_empty():
		summary += "\n架构：" + "  |  ".join(architecture)
	return summary


func play_upgrade_burst(upgrade_id: String, accent: Color = Color(0.0, 0.0, 0.0, 0.0), stack_override: int = 0) -> void:
	if player == null:
		return
	var card := get_upgrade_card(upgrade_id)
	var color: Color = accent if accent.a > 0.0 else card.get("color", Color("75f3df"))
	# Runbook / Capacity / Redundancy live in the run controller, so their
	# current stack is passed in explicitly to keep the burst count honest.
	var stack_count := maxi(1, stack_override if stack_override > 0 else get_upgrade_level(upgrade_id))
	var ring_count := 6 if upgrade_id == "iac" else mini(5, 2 + stack_count)
	_add_blast(player.global_position, 62.0 + float(mini(stack_count, 5)) * 7.0, color, 0.54)
	for ring_index in range(ring_count):
		_add_ring(player.global_position, 52.0 + float(ring_index) * 30.0, color, 0.48 + float(ring_index) * 0.09, 4.0 + float(ring_index) * 0.45)
	var preview_radius := _upgrade_preview_radius(upgrade_id)
	if preview_radius > 0.0:
		# The outer wave uses the weapon's real post-upgrade geometry.  Besides
		# making the selection celebratory, this lets range stacks read directly
		# on the battlefield instead of only as a number on the card.
		_add_ring(player.global_position, preview_radius, color, 0.92, 7.0)
		_add_ring(player.global_position, preview_radius * 0.72, Color(color, 0.72), 0.78, 3.5)
		if upgrade_id == "wrench":
			_add_arc(player.global_position, preview_radius, facing_direction.angle() - _wrench_half_angle(wrench_level), facing_direction.angle() + _wrench_half_angle(wrench_level), color, 0.72)


func _upgrade_preview_radius(upgrade_id: String) -> float:
	match upgrade_id:
		"bash", "idempotency", "iac": return _bash_range(bash_level)
		"ping": return _ping_radius(ping_level)
		"firewall": return _firewall_radius(firewall_level)
		"log": return _log_radius(log_level)
		"wrench", "arch_oncall": return _wrench_reach(wrench_level)
		"rule_chain", "arch_zero_trust": return _rule_chain_radius(rule_chain_level) + _rule_chain_hit_radius(rule_chain_level)
		"lock_zone", "arch_query": return _lock_zone_radius(lock_zone_level)
		"worker", "arch_autoscale": return _worker_range(worker_level)
	return 0.0


func prime_upgraded_skill(upgrade_id: String) -> void:
	# Resume with one immediate cast so the new stack is demonstrated instead
	# of making the player wait through the old cooldown.
	match upgrade_id:
		"bash", "idempotency", "iac": bash_timer = 0.0
		"ping": ping_timer = 0.0
		"firewall": firewall_timer = 0.0
		"log": log_timer = 0.0
		"wrench", "arch_oncall": wrench_timer = 0.0
		"rule_chain", "arch_zero_trust": rule_chain_timer = 0.0
		"lock_zone", "arch_query": lock_place_timer = 0.0
		"worker", "arch_autoscale": worker_timer = 0.0


func _emit_build() -> void:
	build_changed.emit(get_build_summary())


func _add_beam(from: Vector2, to: Vector2, color: Color, lifetime: float) -> void:
	_append_effect({"type": "beam", "from": from, "to": to, "color": color, "ttl": lifetime, "max": lifetime})


func _add_ring(center: Vector2, radius: float, color: Color, lifetime: float, width: float = 3.0) -> void:
	_append_effect({"type": "ring", "center": center, "radius": radius, "color": color, "ttl": lifetime, "max": lifetime, "width": width})


func _add_blast(center: Vector2, radius: float, color: Color, lifetime: float) -> void:
	_append_effect({"type": "blast", "center": center, "radius": radius, "color": color, "ttl": lifetime, "max": lifetime})


func _add_arc(center: Vector2, radius: float, start_angle: float, end_angle: float, color: Color, lifetime: float) -> void:
	_append_effect({"type": "arc", "center": center, "radius": radius, "start": start_angle, "end": end_angle, "color": color, "ttl": lifetime, "max": lifetime})


func _append_effect(effect: Dictionary) -> void:
	effects.append(effect)
	while effects.size() > MAX_EFFECTS:
		effects.remove_at(0)


func _draw() -> void:
	if player != null and firewall_level > 0:
		var phase := float(Time.get_ticks_msec()) * 0.0024
		for layer in range(1, _firewall_layers(firewall_level) + 1):
			var radius := _firewall_layer_radius(layer, firewall_level)
			var direction := -1.0 if layer % 2 == 0 else 1.0
			for segment in range(4):
				var start_angle := phase * direction + TAU * float(segment) / 4.0
				draw_arc(player.global_position, radius, start_angle, start_angle + 0.72, 10, Color(0.94, 0.70, 0.24, 0.72), 2.0)
	if player != null and rule_chain_level > 0:
		var chain_positions := _rule_chain_positions()
		for chain_index in range(chain_positions.size()):
			var current := chain_positions[chain_index]
			var next := chain_positions[(chain_index + 1) % chain_positions.size()]
			draw_line(current, next, Color(0.92, 0.28, 0.38, 0.36), 2.0)
			draw_circle(current, 9.0, Color("401c2c"))
			draw_rect(Rect2(current - Vector2(6, 4), Vector2(12, 8)), Color("ee6677"), false, 2.0)
	if player != null and worker_level > 0:
		for worker_position in _worker_positions():
			draw_line(worker_position, player.global_position, Color(0.38, 0.75, 0.39, 0.20), 1.0)
			draw_rect(Rect2(worker_position - Vector2(9, 7), Vector2(18, 14)), Color("173d31"), true)
			draw_rect(Rect2(worker_position - Vector2(9, 7), Vector2(18, 14)), Color("91ee70"), false, 2.0)
			draw_line(worker_position + Vector2(0, -7), worker_position + Vector2(4, -13), Color("91ee70"), 2.0)
			draw_circle(worker_position + Vector2(4, -13), 2.0, Color("d9ffb7"))
	for zone in lock_zones:
		var zone_position := Vector2(zone["position"])
		var zone_radius := _lock_zone_radius(lock_zone_level)
		var active := bool(zone["active"])
		var zone_color := Color("c68cff") if active else Color("704e88")
		draw_circle(zone_position, 8.0, Color("281a38"))
		draw_arc(zone_position, zone_radius, 0.0, TAU, 28, Color(zone_color, 0.72 if active else 0.38), 2.0)
		draw_line(zone_position + Vector2(-zone_radius * 0.62, 0), zone_position + Vector2(zone_radius * 0.62, 0), Color(zone_color, 0.45), 1.0)
		draw_line(zone_position + Vector2(0, -zone_radius * 0.62), zone_position + Vector2(0, zone_radius * 0.62), Color(zone_color, 0.45), 1.0)
	for effect in effects:
		var alpha := clampf(float(effect["ttl"]) / float(effect["max"]), 0.0, 1.0)
		var color: Color = effect["color"]
		color.a *= alpha
		match String(effect["type"]):
			"beam":
				draw_line(Vector2(effect["from"]), Vector2(effect["to"]), color, 3.0)
			"arc":
				var arc_center := Vector2(effect["center"])
				var arc_radius := float(effect["radius"]) * (1.08 - alpha * 0.08)
				draw_arc(arc_center, arc_radius, float(effect["start"]), float(effect["end"]), 20, color, 6.0)
				draw_arc(arc_center, arc_radius * 0.72, float(effect["start"]), float(effect["end"]), 16, Color(color, color.a * 0.55), 3.0)
			"blast":
				var center := Vector2(effect["center"])
				var radius := float(effect["radius"]) * (1.18 - alpha * 0.18)
				draw_arc(center, radius, 0.0, TAU, 32, color, 3.0)
				draw_line(center + Vector2(-radius, 0), center + Vector2(radius, 0), color, 2.0)
				draw_line(center + Vector2(0, -radius), center + Vector2(0, radius), color, 2.0)
			_:
				draw_arc(Vector2(effect["center"]), float(effect["radius"]) * (1.1 - alpha * 0.1), 0.0, TAU, 48, color, float(effect.get("width", 3.0)))


func _shape_level(level: int) -> int:
	return clampi(level, 0, SHAPE_GROWTH_LIMIT)


func _overclock_level(level: int) -> int:
	return maxi(0, level - SHAPE_GROWTH_LIMIT)


func _overclock_curve(level: int) -> float:
	return log(1.0 + float(_overclock_level(level)))


func _overclock_damage_multiplier(level: int) -> float:
	# Damage remains linear after the authored five shape tiers.  Unlike
	# spawning more nodes/projectiles, this has constant runtime cost.
	return 1.0 + float(_overclock_level(level)) * 0.10


func _authored_power_multiplier(level: int) -> float:
	# The five authored stacks are deliberately front-loaded: each selection is
	# a build-changing jump, while post-five OVERCLOCK retains the prior safe,
	# constant-cost infinite curve.
	return 1.0 + float(maxi(0, _shape_level(level) - 1)) * 0.12


func _overclock_area_multiplier(level: int) -> float:
	# Logarithmic coverage keeps every stack meaningful without eventually
	# turning every local weapon into a map-wide effect.
	return 1.0 + _overclock_curve(level) * 0.06


func _overclock_rate_multiplier(level: int) -> float:
	return 1.0 + _overclock_curve(level) * 0.10


func _scaled_cooldown(base_cooldown: float, minimum_cooldown: float, level: int) -> float:
	if base_cooldown <= 0.0:
		return 0.0
	return maxf(minimum_cooldown, base_cooldown * artifact_cooldown_multiplier / _overclock_rate_multiplier(level))


func _execution_compression(base_cooldown: float, minimum_cooldown: float, level: int) -> float:
	# Once a weapon reaches its safe scheduling floor, the executions that
	# would have fitted below that floor are folded into the current payload.
	# This preserves infinite throughput growth without unbounded per-frame
	# loops or audio/visual spam.
	if level <= SHAPE_GROWTH_LIMIT or base_cooldown <= 0.0:
		return 1.0
	var requested_cooldown := base_cooldown * artifact_cooldown_multiplier / _overclock_rate_multiplier(level)
	return maxf(1.0, minimum_cooldown / maxf(0.001, requested_cooldown))


func _stack_mode_label(next_level: int) -> String:
	return "OVERCLOCK" if next_level > SHAPE_GROWTH_LIMIT else "STACK"


func _stack_upgrade_title(tool_name: String, next_level: int) -> String:
	return "%s超频至 %d 层" % [tool_name, next_level] if next_level > SHAPE_GROWTH_LIMIT else "%s叠加至 %d 层" % [tool_name, next_level]


func _overclock_card_note(next_level: int) -> String:
	if next_level <= SHAPE_GROWTH_LIMIT:
		return ""
	return " · 超频继续提升伤害 / 覆盖 / 吞吐，实体数量保持稳定"


func _bash_base_cooldown(level: int) -> float:
	var shape := _shape_level(level)
	if shape <= 0:
		return 0.0
	var value := (0.64 - float(shape) * 0.07) * (1.0 - float(idempotency_level) * 0.04)
	if evolved_iac:
		value *= 0.88
	return value * career_cooldown_multiplier


func _bash_damage(level: int) -> float:
	var shape := _shape_level(level)
	if shape <= 0:
		return 0.0
	return (16.0 + float(shape) * 4.0) * _authored_power_multiplier(level) * _global_damage_multiplier() * _overclock_damage_multiplier(level) * _execution_compression(_bash_base_cooldown(level), 0.16, level)


func _effective_bash_damage(level: int) -> float:
	var value := _bash_damage(level) * (1.0 + float(idempotency_level) * 0.12)
	return value * (1.35 if evolved_iac else 1.0)


func _effective_bash_targets(level: int) -> int:
	return _bash_targets(level) + floori(float(idempotency_level) / 2.0) + (1 if evolved_iac else 0)


func _bash_cooldown(level: int) -> float:
	return _scaled_cooldown(_bash_base_cooldown(level), 0.16, level)


func _bash_range(level: int) -> float:
	var shape := _shape_level(level)
	return 0.0 if shape <= 0 else (360.0 + float(shape) * 44.0 + (60.0 if evolved_iac else 0.0)) * career_area_multiplier * _overclock_area_multiplier(level)


func _bash_targets(level: int) -> int:
	var shape := _shape_level(level)
	return 0 if shape <= 0 else 1 + floori(float(shape) * 0.60)


func _bash_secondary_ratio(level: int) -> float:
	match _shape_level(level):
		2: return 0.25
		3: return 0.40
		4: return 0.40
		5: return 0.45
	return 0.0


func _ping_pulses(level: int) -> int:
	return _shape_level(level)


func _ping_radius(level: int) -> float:
	var shape := _shape_level(level)
	return 0.0 if shape <= 0 else (115.0 + float(shape) * 35.0) * career_area_multiplier * _overclock_area_multiplier(level)


func _ping_damage(level: int) -> float:
	var shape := _shape_level(level)
	if shape <= 0:
		return 0.0
	var base_cooldown := (4.55 - float(shape) * 0.55) * career_cooldown_multiplier
	return (15.0 + float(shape) * 3.0) * _authored_power_multiplier(level) * _global_damage_multiplier() * _overclock_damage_multiplier(level) * _execution_compression(base_cooldown, 1.8, level)


func _ping_cooldown(level: int) -> float:
	var shape := _shape_level(level)
	return 0.0 if shape <= 0 else _scaled_cooldown((4.55 - float(shape) * 0.55) * career_cooldown_multiplier, 1.8, level)


func _firewall_layers(level: int) -> int:
	return _shape_level(level)


func _firewall_radius(level: int) -> float:
	var shape := _shape_level(level)
	return 0.0 if shape <= 0 else (56.0 + float(shape) * 18.0) * career_area_multiplier * _overclock_area_multiplier(level)


func _firewall_layer_radius(layer: int, total_level: int) -> float:
	var layer_shape := clampi(layer, 1, SHAPE_GROWTH_LIMIT)
	return (56.0 + float(layer_shape) * 18.0) * career_area_multiplier * _overclock_area_multiplier(total_level)


func _firewall_damage(level: int) -> float:
	var shape := _shape_level(level)
	if shape <= 0:
		return 0.0
	var base_cooldown := (0.80 - float(shape) * 0.084) * career_cooldown_multiplier
	return (6.75 + float(shape) * 2.25) * _authored_power_multiplier(level) * _global_damage_multiplier() * _overclock_damage_multiplier(level) * _execution_compression(base_cooldown, 0.38, level)


func _firewall_cooldown(level: int) -> float:
	var shape := _shape_level(level)
	return 0.0 if shape <= 0 else _scaled_cooldown((0.80 - float(shape) * 0.084) * career_cooldown_multiplier, 0.38, level)


func _log_targets(level: int) -> int:
	var shape := _shape_level(level)
	return 0 if shape <= 0 else 1 + floori(float(shape) * 0.80)


func _log_radius(level: int) -> float:
	var shape := _shape_level(level)
	return 0.0 if shape <= 0 else (48.0 + float(shape) * 14.0) * career_area_multiplier * _overclock_area_multiplier(level)


func _log_damage(level: int) -> float:
	var shape := _shape_level(level)
	if shape <= 0:
		return 0.0
	var base_cooldown := (3.45 - float(shape) * 0.33) * career_cooldown_multiplier
	return (22.0 + float(shape) * 4.0) * _authored_power_multiplier(level) * _global_damage_multiplier() * _overclock_damage_multiplier(level) * _execution_compression(base_cooldown, 1.8, level)


func _log_cooldown(level: int) -> float:
	var shape := _shape_level(level)
	return 0.0 if shape <= 0 else _scaled_cooldown((3.45 - float(shape) * 0.33) * career_cooldown_multiplier, 1.8, level)


func _log_secondary_ratio(level: int) -> float:
	return 0.30 + float(_shape_level(level)) * 0.03


func _wrench_sweeps(level: int) -> int:
	var shape := _shape_level(level)
	if shape <= 0:
		return 0
	return 1 + floori(float(shape) / 2.0) + (1 if oncall_arch_level >= 2 else 0)


func _wrench_reach(level: int) -> float:
	var shape := _shape_level(level)
	return 0.0 if shape <= 0 else (72.0 + float(shape) * 18.0) * career_area_multiplier * _overclock_area_multiplier(level)


func _wrench_half_angle(level: int) -> float:
	var shape := _shape_level(level)
	return 0.0 if shape <= 0 else 0.68 + float(shape) * 0.035


func _wrench_damage(level: int) -> float:
	var shape := _shape_level(level)
	if shape <= 0:
		return 0.0
	var base_cooldown := (1.02 - float(shape) * 0.13) * career_cooldown_multiplier
	return (27.0 + float(shape) * 7.0) * _authored_power_multiplier(level) * (1.0 + float(oncall_arch_level) * 0.18) * _global_damage_multiplier() * career_melee_multiplier * _overclock_damage_multiplier(level) * _execution_compression(base_cooldown, 0.36, level)


func _wrench_cooldown(level: int) -> float:
	var shape := _shape_level(level)
	return 0.0 if shape <= 0 else _scaled_cooldown((1.02 - float(shape) * 0.13) * career_cooldown_multiplier, 0.36, level)


func _rule_chain_nodes(level: int) -> int:
	var shape := _shape_level(level)
	if shape <= 0:
		return 0
	return 2 + maxi(1, level) + zero_trust_arch_level * 2


func _rule_chain_radius(level: int) -> float:
	var shape := _shape_level(level)
	return 0.0 if shape <= 0 else (72.0 + float(shape) * 20.0 + float(zero_trust_arch_level) * 12.0) * career_area_multiplier * _overclock_area_multiplier(level)


func _rule_chain_hit_radius(level: int) -> float:
	var shape := _shape_level(level)
	return 0.0 if shape <= 0 else (18.0 + float(shape) * 4.0 + float(zero_trust_arch_level) * 3.0) * career_area_multiplier * _overclock_area_multiplier(level)


func _rule_chain_damage(level: int) -> float:
	var shape := _shape_level(level)
	if shape <= 0:
		return 0.0
	var base_tick := (0.37 - float(shape) * 0.042) * career_cooldown_multiplier
	return (5.5 + float(shape) * 2.4) * _authored_power_multiplier(level) * (1.0 + float(zero_trust_arch_level) * 0.18) * _global_damage_multiplier() * _overclock_damage_multiplier(level) * _execution_compression(base_tick, 0.16, level)


func _rule_chain_tick(level: int) -> float:
	var shape := _shape_level(level)
	return 0.0 if shape <= 0 else _scaled_cooldown((0.37 - float(shape) * 0.042) * career_cooldown_multiplier, 0.16, level)


func _rule_chain_speed(level: int) -> float:
	var shape := _shape_level(level)
	return 0.0 if shape <= 0 else (1.20 + float(shape) * 0.18) * _overclock_rate_multiplier(level)


func _rule_chain_positions() -> Array[Vector2]:
	var result: Array[Vector2] = []
	if player == null or rule_chain_level <= 0:
		return result
	var node_count := _rule_chain_nodes(rule_chain_level)
	for node_index in range(node_count):
		var angle := rule_chain_angle + TAU * float(node_index) / float(node_count)
		result.append(player.global_position + Vector2.from_angle(angle) * _rule_chain_radius(rule_chain_level))
	return result


func _lock_zone_limit(level: int) -> int:
	var shape := _shape_level(level)
	return 0 if shape <= 0 else 1 + floori(float(shape) / 2.0)


func _lock_zone_radius(level: int) -> float:
	var shape := _shape_level(level)
	return 0.0 if shape <= 0 else (52.0 + float(shape) * 16.0 + float(query_arch_level) * 10.0) * career_area_multiplier * _overclock_area_multiplier(level)


func _lock_zone_duration(level: int) -> float:
	var shape := _shape_level(level)
	return 0.0 if shape <= 0 else (2.45 + float(shape) * 0.52 + float(query_arch_level) * 0.70) * career_control_multiplier


func _lock_zone_damage(level: int) -> float:
	var shape := _shape_level(level)
	if shape <= 0:
		return 0.0
	var base_cooldown := (5.15 - float(shape) * 0.60) * career_cooldown_multiplier
	return (5.5 + float(shape) * 2.5) * _authored_power_multiplier(level) * _global_damage_multiplier() * _overclock_damage_multiplier(level) * _execution_compression(base_cooldown, 2.15, level)


func _lock_zone_tick(level: int) -> float:
	var shape := _shape_level(level)
	return 0.0 if shape <= 0 else maxf(0.40, 0.62 - float(shape) * 0.025)


func _lock_zone_cooldown(level: int) -> float:
	var shape := _shape_level(level)
	return 0.0 if shape <= 0 else _scaled_cooldown((5.15 - float(shape) * 0.60) * career_cooldown_multiplier, 2.15, level)


func _worker_count(level: int) -> int:
	var shape := _shape_level(level)
	if shape <= 0:
		return 0
	return 1 + floori(float(shape) / 2.0) + autoscale_arch_level + career_summon_bonus


func _worker_targets_per_unit(level: int) -> int:
	var shape := _shape_level(level)
	return 0 if shape <= 0 else 1 + (1 if shape >= 3 else 0)


func _worker_range(level: int) -> float:
	var shape := _shape_level(level)
	return 0.0 if shape <= 0 else (250.0 + float(shape) * 45.0) * career_area_multiplier * _overclock_area_multiplier(level)


func _worker_damage(level: int) -> float:
	var shape := _shape_level(level)
	if shape <= 0:
		return 0.0
	var base_cooldown := (1.08 - float(shape) * 0.115) * career_cooldown_multiplier
	return (8.0 + float(shape) * 3.5) * _authored_power_multiplier(level) * (1.0 + float(autoscale_arch_level) * 0.12) * _global_damage_multiplier() * career_summon_damage_multiplier * _overclock_damage_multiplier(level) * _execution_compression(base_cooldown, 0.50, level)


func _worker_cooldown(level: int) -> float:
	var shape := _shape_level(level)
	return 0.0 if shape <= 0 else _scaled_cooldown((1.08 - float(shape) * 0.115) * career_cooldown_multiplier, 0.50, level)


func _worker_positions() -> Array[Vector2]:
	var result: Array[Vector2] = []
	if player == null or worker_level <= 0:
		return result
	var unit_count := _worker_count(worker_level)
	var formation_radius := (112.0 + float(_shape_level(worker_level)) * 3.0) * _overclock_area_multiplier(worker_level)
	for unit_index in range(unit_count):
		var angle := worker_angle + TAU * float(unit_index) / float(unit_count)
		result.append(player.global_position + Vector2.from_angle(angle) * formation_radius)
	return result


func _roman_level(level: int) -> String:
	return "II" if level >= 2 else "I"
