class_name SwarmWorld
extends Node2D

signal enemy_closed(world_position: Vector2, xp_value: int, enemy_kind: int, tier: int)
signal enemy_closed_by_source(source_id: String, world_position: Vector2, tier: int)
signal boss_status_changed(phase: int, health: float, maximum: float)
signal boss_defeated
signal elite_skill_cast(skill_name: String, world_position: Vector2, tier: int)
signal hazard_activated(kind: int, world_position: Vector2, tier: int)

enum EnemyKind {
	HTTP_404,
	NXDOMAIN,
	ENOSPC,
	BUG,
	TIMEOUT_408,
	ELITE_502,
	ELITE_OOM,
	INCIDENT_CORE,
}

enum HazardKind {
	FIRE_POOL,
	FROST_BURST,
	TELEPORT,
	LIGHTNING,
	VOLATILE_CORE,
	OVERLOAD_PULSE,
}

const MAX_ENTITIES := 2200
const MAX_HAZARDS := 96
const ELITE_CAST_RANGE := 920.0
const WORLD_RECT := Rect2(20.0, 180.0, 2360.0, 1140.0)
const BG_COLOR := Color("091522")
const FAULT_SPRITES := preload("res://assets/generated/fault_sprites_4x2.png")
const UI_FONT := preload("res://assets/fonts/NotoSansSC-VF.ttf")
const EliteAffixCatalog := preload("res://scripts/elite_affix_catalog.gd")
const FaultCatalog := preload("res://scripts/fault_catalog.gd")

var player: Node2D
var count := 0
var labels_enabled := true
var boss_phase := -1

var positions := PackedVector2Array()
var kinds := PackedInt32Array()
var health := PackedFloat32Array()
var maximum_health := PackedFloat32Array()
var speeds := PackedFloat32Array()
var radii := PackedFloat32Array()
var ages := PackedFloat32Array()
var timers := PackedFloat32Array()
var contact_timers := PackedFloat32Array()
var states := PackedFloat32Array()
var slow_timers := PackedFloat32Array()
var root_timers := PackedFloat32Array()
var vulnerability_timers := PackedFloat32Array()
var vulnerability_multipliers := PackedFloat32Array()
var entity_ids := PackedInt64Array()
var affix_masks := PackedInt32Array()
var affix_timers := PackedFloat32Array()
var affix_cursors := PackedInt32Array()
var shield_health := PackedFloat32Array()
var shield_maximum := PackedFloat32Array()
var shield_recharge_timers := PackedFloat32Array()

var rng := RandomNumberGenerator.new()
var next_entity_id := 1
var hazards: Array[Dictionary] = []
var global_elite_cast_left := 0.0
var difficulty_id := "normal"
var normal_health_multiplier := 1.0
var normal_damage_multiplier := 1.0
var normal_speed_multiplier := 1.0
var elite_health_multiplier := 1.0
var elite_damage_multiplier := 1.0
var elite_speed_multiplier := 1.0
var boss_health_multiplier := 1.0
var boss_damage_multiplier := 1.0
var boss_speed_multiplier := 1.0
var ability_cooldown_multiplier := 1.0
var affix_damage_multiplier := 1.0
var elite_summon_count := 1
var boss_summon_count := 1


func _ready() -> void:
	# Packed arrays use copy-on-write, so resize the members explicitly instead
	# of resizing temporary values stored in an Array.
	positions.resize(MAX_ENTITIES)
	kinds.resize(MAX_ENTITIES)
	health.resize(MAX_ENTITIES)
	maximum_health.resize(MAX_ENTITIES)
	speeds.resize(MAX_ENTITIES)
	radii.resize(MAX_ENTITIES)
	ages.resize(MAX_ENTITIES)
	timers.resize(MAX_ENTITIES)
	contact_timers.resize(MAX_ENTITIES)
	states.resize(MAX_ENTITIES)
	slow_timers.resize(MAX_ENTITIES)
	root_timers.resize(MAX_ENTITIES)
	vulnerability_timers.resize(MAX_ENTITIES)
	vulnerability_multipliers.resize(MAX_ENTITIES)
	entity_ids.resize(MAX_ENTITIES)
	affix_masks.resize(MAX_ENTITIES)
	affix_timers.resize(MAX_ENTITIES)
	affix_cursors.resize(MAX_ENTITIES)
	shield_health.resize(MAX_ENTITIES)
	shield_maximum.resize(MAX_ENTITIES)
	shield_recharge_timers.resize(MAX_ENTITIES)
	rng.seed = 0x1_7BA771E


func configure(player_node: Node2D, seed_value: int = 1) -> void:
	player = player_node
	rng.seed = seed_value


func configure_difficulty(config: Dictionary = {}) -> void:
	difficulty_id = String(config.get("id", "normal"))
	normal_health_multiplier = maxf(0.01, float(config.get("normal_health", 1.0)))
	normal_damage_multiplier = maxf(0.01, float(config.get("normal_damage", 1.0)))
	normal_speed_multiplier = maxf(0.01, float(config.get("normal_speed", 1.0)))
	elite_health_multiplier = maxf(0.01, float(config.get("elite_health", 1.0)))
	elite_damage_multiplier = maxf(0.01, float(config.get("elite_damage", 1.0)))
	elite_speed_multiplier = maxf(0.01, float(config.get("elite_speed", 1.0)))
	boss_health_multiplier = maxf(0.01, float(config.get("boss_health", 1.0)))
	boss_damage_multiplier = maxf(0.01, float(config.get("boss_damage", 1.0)))
	boss_speed_multiplier = maxf(0.01, float(config.get("boss_speed", 1.0)))
	ability_cooldown_multiplier = maxf(0.10, float(config.get("ability_cooldown", 1.0)))
	affix_damage_multiplier = maxf(0.10, float(config.get("affix_damage", 1.0)))
	elite_summon_count = maxi(1, int(config.get("elite_summon_count", 1)))
	boss_summon_count = maxi(1, int(config.get("boss_summon_count", 1)))


func get_difficulty_snapshot() -> Dictionary:
	return {
		"id": difficulty_id,
		"normal_health": normal_health_multiplier,
		"normal_damage": normal_damage_multiplier,
		"normal_speed": normal_speed_multiplier,
		"elite_health": elite_health_multiplier,
		"elite_damage": elite_damage_multiplier,
		"elite_speed": elite_speed_multiplier,
		"boss_health": boss_health_multiplier,
		"boss_damage": boss_damage_multiplier,
		"boss_speed": boss_speed_multiplier,
		"ability_cooldown": ability_cooldown_multiplier,
		"affix_damage": affix_damage_multiplier,
		"elite_summon_count": elite_summon_count,
		"boss_summon_count": boss_summon_count,
	}


func spawn_enemy(kind: int, world_position: Vector2, forced_affix_mask: int = -1) -> bool:
	if count >= MAX_ENTITIES:
		return false
	positions[count] = world_position
	kinds[count] = kind
	maximum_health[count] = _base_health(kind) * _health_multiplier(kind)
	health[count] = maximum_health[count]
	speeds[count] = _base_speed(kind) * _speed_multiplier(kind)
	radii[count] = _base_radius(kind)
	ages[count] = 0.0
	timers[count] = rng.randf_range(0.4, 2.2) * ability_cooldown_multiplier
	contact_timers[count] = 0.0
	states[count] = 0.0
	slow_timers[count] = 0.0
	root_timers[count] = 0.0
	vulnerability_timers[count] = 0.0
	vulnerability_multipliers[count] = 1.0
	entity_ids[count] = next_entity_id
	next_entity_id += 1
	affix_masks[count] = 0
	affix_timers[count] = rng.randf_range(2.2, 3.6) * ability_cooldown_multiplier
	affix_cursors[count] = 0
	shield_health[count] = 0.0
	shield_maximum[count] = 0.0
	shield_recharge_timers[count] = 0.0
	if _tier(kind) == 1:
		var preferred: Array[int] = []
		if kind == EnemyKind.ELITE_502:
			preferred.assign([EliteAffixCatalog.Affix.STORMCALLER, EliteAffixCatalog.Affix.TELEPORTER])
		else:
			preferred.assign([EliteAffixCatalog.Affix.MOLTEN, EliteAffixCatalog.Affix.FROZEN])
		affix_masks[count] = forced_affix_mask if forced_affix_mask >= 0 else EliteAffixCatalog.roll_mask(rng, difficulty_id, preferred)
		_initialize_shield(count, 0.24)
	if kind == EnemyKind.INCIDENT_CORE:
		affix_masks[count] = (
			EliteAffixCatalog.Affix.MOLTEN
			| EliteAffixCatalog.Affix.FROZEN
			| EliteAffixCatalog.Affix.SHIELDED
			| EliteAffixCatalog.Affix.UNSTOPPABLE
			| EliteAffixCatalog.Affix.TELEPORTER
			| EliteAffixCatalog.Affix.STORMCALLER
		)
		affix_timers[count] = 1.8 * ability_cooldown_multiplier
		_initialize_shield(count, 0.18, false)
		boss_phase = 0
		boss_status_changed.emit(boss_phase, health[count], maximum_health[count])
	count += 1
	var profile_store := get_node_or_null("/root/ProfileStore")
	if profile_store != null and profile_store.has_method("discover_fault_kind"):
		profile_store.call("discover_fault_kind", kind)
	return true


func clear_all() -> void:
	count = 0
	boss_phase = -1
	next_entity_id = 1
	hazards.clear()
	global_elite_cast_left = 0.0
	queue_redraw()


func _initialize_shield(index: int, health_ratio: float, active: bool = true) -> void:
	if not EliteAffixCatalog.has(affix_masks[index], EliteAffixCatalog.Affix.SHIELDED):
		return
	shield_maximum[index] = maximum_health[index] * health_ratio
	shield_health[index] = shield_maximum[index] if active else 0.0


func _update_elite_shield(index: int) -> void:
	if not EliteAffixCatalog.has(affix_masks[index], EliteAffixCatalog.Affix.SHIELDED):
		return
	if shield_maximum[index] <= 0.0:
		_initialize_shield(index, 0.24)
	elif shield_health[index] <= 0.0 and shield_recharge_timers[index] <= 0.0:
		shield_health[index] = shield_maximum[index]
		shield_recharge_timers[index] = maxf(4.5, 11.0 * ability_cooldown_multiplier)
		states[index] = maxf(states[index], 0.3)
		elite_skill_cast.emit("变更护盾已恢复", positions[index], 1)


func _try_consume_elite_cast(distance_to_player: float) -> bool:
	if distance_to_player > ELITE_CAST_RANGE or global_elite_cast_left > 0.0:
		return false
	global_elite_cast_left = _global_elite_cast_spacing()
	return true


func _global_elite_cast_spacing() -> float:
	match difficulty_id:
		"advanced": return 0.78
		"abyss": return 0.66
		"impossible": return 0.55
	return 0.90


func _difficulty_rank() -> int:
	match difficulty_id:
		"advanced": return 1
		"abyss": return 2
		"impossible": return 3
	return 0


func _warning_duration(base_duration: float) -> float:
	var scale: float = float([1.0, 0.92, 0.82, 0.72][_difficulty_rank()])
	return maxf(0.72, base_duration * scale)


func _cast_elite_affix(index: int) -> void:
	var active_affixes := EliteAffixCatalog.active_from_mask(affix_masks[index])
	if active_affixes.is_empty():
		affix_timers[index] = 5.0 * ability_cooldown_multiplier
		return
	var affix := int(active_affixes[affix_cursors[index] % active_affixes.size()])
	affix_cursors[index] += 1
	var rank := _difficulty_rank()
	var owner_id := entity_ids[index]
	var player_velocity := Vector2(player.get("velocity"))
	var predicted_player_position := player.global_position + player_velocity * 0.28
	match affix:
		EliteAffixCatalog.Affix.MOLTEN:
			var pool_count := 1 + int(rank >= 2)
			var lateral := Vector2(-(player.global_position - positions[index]).normalized().y, (player.global_position - positions[index]).normalized().x)
			for pool_index in range(pool_count):
				var offset := lateral * (float(pool_index) - float(pool_count - 1) * 0.5) * 92.0
				_spawn_hazard(HazardKind.FIRE_POOL, predicted_player_position + offset, 76.0, _warning_duration(1.08), 4.2, 3.5 * affix_damage_multiplier, owner_id)
			affix_timers[index] = 8.0 * ability_cooldown_multiplier
		EliteAffixCatalog.Affix.FROZEN:
			var frost_radius := 132.0 + float(rank) * 9.0
			_spawn_hazard(HazardKind.FROST_BURST, predicted_player_position, frost_radius, _warning_duration(1.22), 0.55, 8.0 * affix_damage_multiplier, owner_id)
			affix_timers[index] = 9.0 * ability_cooldown_multiplier
		EliteAffixCatalog.Affix.TELEPORTER:
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var from_player := (positions[index] - player.global_position).normalized()
			if from_player.length_squared() < 0.01:
				from_player = Vector2.RIGHT
			var target_direction := from_player.rotated(side * PI * 0.48)
			var target := player.global_position + target_direction * (185.0 + float(rank) * 12.0)
			target.x = clampf(target.x, WORLD_RECT.position.x + radii[index], WORLD_RECT.end.x - radii[index])
			target.y = clampf(target.y, WORLD_RECT.position.y + radii[index], WORLD_RECT.end.y - radii[index])
			_spawn_hazard(HazardKind.TELEPORT, target, 66.0, _warning_duration(0.92), 0.45, 6.0 * affix_damage_multiplier, owner_id, positions[index])
			affix_timers[index] = 7.5 * ability_cooldown_multiplier
		EliteAffixCatalog.Affix.STORMCALLER:
			var strike_count := 1 + int(rank >= 1) + int(rank >= 3)
			for strike_index in range(strike_count):
				var angle := TAU * float(strike_index) / float(maxi(1, strike_count)) + rng.randf_range(-0.25, 0.25)
				var strike_position := predicted_player_position + Vector2.from_angle(angle) * float(strike_index) * 54.0
				_spawn_hazard(HazardKind.LIGHTNING, strike_position, 48.0, _warning_duration(0.92) + float(strike_index) * 0.18, 0.35, 9.0 * affix_damage_multiplier, owner_id)
			affix_timers[index] = 8.5 * ability_cooldown_multiplier
	var definition := EliteAffixCatalog.definition(affix)
	elite_skill_cast.emit(String(definition.get("name", "精英词条")), positions[index], 1)


func _cast_boss_skill(index: int) -> void:
	var health_ratio := clampf(health[index] / maxf(1.0, maximum_health[index]), 0.0, 1.0)
	var combat_stage := 0 if health_ratio > 0.70 else (1 if health_ratio > 0.35 else 2)
	var sequence: Array[int]
	if combat_stage == 0:
		sequence = [EliteAffixCatalog.Affix.MOLTEN, EliteAffixCatalog.Affix.STORMCALLER, -1]
	elif combat_stage == 1:
		sequence = [EliteAffixCatalog.Affix.FROZEN, EliteAffixCatalog.Affix.TELEPORTER, EliteAffixCatalog.Affix.SHIELDED, EliteAffixCatalog.Affix.STORMCALLER]
	else:
		sequence = [EliteAffixCatalog.Affix.MOLTEN, EliteAffixCatalog.Affix.FROZEN, EliteAffixCatalog.Affix.TELEPORTER, EliteAffixCatalog.Affix.STORMCALLER, -1]
	var skill := int(sequence[affix_cursors[index] % sequence.size()])
	affix_cursors[index] += 1
	var rank := _difficulty_rank()
	var owner_id := entity_ids[index]
	var boss_damage := affix_damage_multiplier * 1.25
	var predicted_player_position := player.global_position + Vector2(player.get("velocity")) * 0.30
	var skill_name := "FATAL 脉冲"
	match skill:
		EliteAffixCatalog.Affix.MOLTEN:
			var pool_count := mini(5, 2 + combat_stage + int(rank >= 2))
			var forward := (player.global_position - positions[index]).normalized()
			var lateral := Vector2(-forward.y, forward.x)
			for pool_index in range(pool_count):
				var lane_offset := (float(pool_index) - float(pool_count - 1) * 0.5) * 94.0
				var lane_position := predicted_player_position + lateral * lane_offset + forward * float(pool_index % 2) * 72.0
				_spawn_hazard(HazardKind.FIRE_POOL, lane_position, 84.0, _warning_duration(1.10) + float(pool_index) * 0.08, 4.8, 4.2 * boss_damage, owner_id)
			skill_name = "FATAL 热失控"
		EliteAffixCatalog.Affix.FROZEN:
			_spawn_hazard(HazardKind.FROST_BURST, predicted_player_position, 166.0 + float(rank) * 8.0, _warning_duration(1.28), 0.65, 10.0 * boss_damage, owner_id)
			if combat_stage >= 2:
				_spawn_hazard(HazardKind.FROST_BURST, positions[index], 225.0, _warning_duration(1.42), 0.65, 8.0 * boss_damage, owner_id)
			skill_name = "FATAL 冻结窗口"
		EliteAffixCatalog.Affix.TELEPORTER:
			var angle := rng.randf() * TAU
			var target := player.global_position + Vector2.from_angle(angle) * (255.0 + float(rank) * 10.0)
			target.x = clampf(target.x, WORLD_RECT.position.x + radii[index], WORLD_RECT.end.x - radii[index])
			target.y = clampf(target.y, WORLD_RECT.position.y + radii[index], WORLD_RECT.end.y - radii[index])
			_spawn_hazard(HazardKind.TELEPORT, target, 118.0, _warning_duration(1.02), 0.55, 10.0 * boss_damage, owner_id, positions[index])
			skill_name = "FATAL 上游切换"
		EliteAffixCatalog.Affix.SHIELDED:
			shield_maximum[index] = maximum_health[index] * (0.12 + float(combat_stage) * 0.03)
			shield_health[index] = shield_maximum[index]
			skill_name = "FATAL 熔断护盾"
		EliteAffixCatalog.Affix.STORMCALLER:
			var strike_count := mini(7, 2 + combat_stage + rank)
			for strike_index in range(strike_count):
				var angle := TAU * float(strike_index) / float(strike_count) + rng.randf_range(-0.2, 0.2)
				var target := predicted_player_position + Vector2.from_angle(angle) * (42.0 + float(strike_index % 3) * 54.0)
				_spawn_hazard(HazardKind.LIGHTNING, target, 56.0, _warning_duration(0.96) + float(strike_index) * 0.14, 0.38, 11.0 * boss_damage, owner_id)
			skill_name = "FATAL 雷暴告警"
		-1:
			_spawn_hazard(HazardKind.OVERLOAD_PULSE, positions[index], 220.0 + float(combat_stage) * 28.0, _warning_duration(1.16), 0.55, 14.0 * boss_damage, owner_id)
			skill_name = "FATAL 核心脉冲"
	affix_timers[index] = maxf(3.2, (6.4 - float(combat_stage) * 0.75) * ability_cooldown_multiplier)
	elite_skill_cast.emit(skill_name, positions[index], 2)


func _spawn_hazard(kind: int, world_position: Vector2, radius_value: float, warmup: float, duration: float, damage: float, owner_id: int = 0, source_position: Vector2 = Vector2.INF) -> bool:
	if kind == HazardKind.FIRE_POOL:
		for hazard_index in range(hazards.size()):
			var existing := hazards[hazard_index]
			if int(existing["kind"]) == HazardKind.FIRE_POOL and Vector2(existing["position"]).distance_squared_to(world_position) < 42.0 * 42.0:
				existing["duration"] = maxf(float(existing["duration"]), duration)
				existing["damage"] = maxf(float(existing["damage"]), damage)
				hazards[hazard_index] = existing
				return true
	var owner_tier := _entity_tier(owner_id)
	if hazards.size() >= MAX_HAZARDS:
		if owner_tier < 2:
			return false
		var replaced := false
		for hazard_index in range(hazards.size()):
			if int(hazards[hazard_index].get("owner_tier", 0)) < 2:
				hazards.remove_at(hazard_index)
				replaced = true
				break
		if not replaced:
			hazards.pop_front()
	var resolved_position := Vector2(
		clampf(world_position.x, WORLD_RECT.position.x, WORLD_RECT.end.x),
		clampf(world_position.y, WORLD_RECT.position.y, WORLD_RECT.end.y)
	)
	hazards.append({
		"kind": kind,
		"position": resolved_position,
		"source_position": source_position,
		"radius": radius_value,
		"warmup": warmup,
		"warmup_total": maxf(0.01, warmup),
		"duration": duration,
		"duration_total": maxf(0.01, duration),
		"damage": damage,
		"tick_left": 0.0,
		"triggered": false,
		"owner_id": owner_id,
		"owner_tier": owner_tier,
	})
	return true


func _update_hazards(delta: float) -> void:
	for hazard_index in range(hazards.size() - 1, -1, -1):
		var hazard := hazards[hazard_index]
		hazard["warmup"] = float(hazard["warmup"]) - delta
		if float(hazard["warmup"]) > 0.0:
			hazards[hazard_index] = hazard
			continue
		if not bool(hazard["triggered"]):
			hazard["triggered"] = true
			_activate_hazard(hazard)
		hazard["duration"] = float(hazard["duration"]) - delta
		if int(hazard["kind"]) == HazardKind.FIRE_POOL:
			hazard["tick_left"] = float(hazard["tick_left"]) - delta
			if float(hazard["tick_left"]) <= 0.0 and _player_inside_hazard(hazard):
				player.call("take_damage", float(hazard["damage"]))
				hazard["tick_left"] = 0.52
		if float(hazard["duration"]) <= 0.0:
			hazards.remove_at(hazard_index)
		else:
			hazards[hazard_index] = hazard


func _activate_hazard(hazard: Dictionary) -> void:
	var kind := int(hazard["kind"])
	hazard_activated.emit(kind, Vector2(hazard["position"]), int(hazard.get("owner_tier", 0)))
	if kind == HazardKind.TELEPORT:
		var owner_index := _find_entity_id(int(hazard["owner_id"]))
		if owner_index >= 0:
			positions[owner_index] = Vector2(hazard["position"])
			states[owner_index] = maxf(states[owner_index], 0.28)
	if kind == HazardKind.FIRE_POOL or not _player_inside_hazard(hazard):
		return
	player.call("take_damage", float(hazard["damage"]))
	if kind == HazardKind.FROST_BURST and player.has_method("apply_slow"):
		player.call("apply_slow", 2.2, 0.58, "frost")


func _player_inside_hazard(hazard: Dictionary) -> bool:
	var radius_value := float(hazard["radius"])
	return player.global_position.distance_squared_to(Vector2(hazard["position"])) <= radius_value * radius_value


func _find_entity_id(wanted_id: int) -> int:
	for index in range(count):
		if entity_ids[index] == wanted_id:
			return index
	return -1


func _entity_tier(entity_id: int) -> int:
	var index := _find_entity_id(entity_id)
	return _tier(kinds[index]) if index >= 0 else 0


func _clear_hazards_for_tier(tier_value: int) -> void:
	for hazard_index in range(hazards.size() - 1, -1, -1):
		if int(hazards[hazard_index].get("owner_tier", 0)) == tier_value:
			hazards.remove_at(hazard_index)


func get_elite_affix_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(count):
		if _tier(kinds[index]) != 1:
			continue
		result.append({
			"entity_id": entity_ids[index],
			"kind": kinds[index],
			"mask": affix_masks[index],
			"names": EliteAffixCatalog.names_from_mask(affix_masks[index]),
			"shield": shield_health[index],
			"shield_maximum": shield_maximum[index],
		})
	return result


func get_hazard_snapshot() -> Array[Dictionary]:
	return hazards.duplicate(true)


func get_boss_combat_snapshot() -> Dictionary:
	var index := _find_kind(EnemyKind.INCIDENT_CORE)
	if index < 0:
		return {"active": false}
	var health_ratio := clampf(health[index] / maxf(1.0, maximum_health[index]), 0.0, 1.0)
	return {
		"active": true,
		"combat_stage": 0 if health_ratio > 0.70 else (1 if health_ratio > 0.35 else 2),
		"shield": shield_health[index],
		"shield_maximum": shield_maximum[index],
		"hazards": hazards.size(),
	}


func _physics_process(delta: float) -> void:
	if player == null:
		return
	global_elite_cast_left = maxf(0.0, global_elite_cast_left - delta)
	_update_hazards(delta)
	if count <= 0:
		queue_redraw()
		return
	var index := 0
	while index < count:
		ages[index] += delta
		timers[index] -= delta
		affix_timers[index] -= delta
		contact_timers[index] = maxf(0.0, contact_timers[index] - delta)
		states[index] = maxf(0.0, states[index] - delta)
		slow_timers[index] = maxf(0.0, slow_timers[index] - delta)
		root_timers[index] = maxf(0.0, root_timers[index] - delta)
		vulnerability_timers[index] = maxf(0.0, vulnerability_timers[index] - delta)
		if vulnerability_timers[index] <= 0.0:
			vulnerability_multipliers[index] = 1.0
		shield_recharge_timers[index] = maxf(0.0, shield_recharge_timers[index] - delta)

		var offset := player.global_position - positions[index]
		var distance := maxf(offset.length(), 0.001)
		var direction := offset / distance
		var move_direction := direction
		var speed_scale := 1.0

		match kinds[index]:
			EnemyKind.HTTP_404:
				move_direction = direction
			EnemyKind.BUG:
				move_direction = direction.rotated(sin(ages[index] * 7.0 + float(index)) * 0.42)
				speed_scale = 1.18
			EnemyKind.NXDOMAIN:
				if timers[index] <= 0.0 and distance > 100.0:
					var tangent := Vector2(-direction.y, direction.x)
					positions[index] += tangent * rng.randf_range(-72.0, 72.0) + direction * 34.0
					timers[index] = rng.randf_range(2.6, 4.0) * ability_cooldown_multiplier
					states[index] = 0.35
			EnemyKind.TIMEOUT_408:
				speed_scale = 0.82
				if timers[index] <= 0.0:
					states[index] = 0.55
					if distance < 185.0 and player.has_method("apply_slow"):
						player.call("apply_slow", 1.25, 0.58)
					timers[index] = rng.randf_range(4.0, 5.2) * ability_cooldown_multiplier
			EnemyKind.ENOSPC:
				radii[index] = minf(24.0, _base_radius(EnemyKind.ENOSPC) + ages[index] * 0.26)
				speed_scale = maxf(0.45, 1.0 - ages[index] * 0.008)
			EnemyKind.ELITE_502:
				speed_scale = 0.48
				if timers[index] <= 0.0 and _try_consume_elite_cast(distance):
					for summon_index in range(elite_summon_count):
						var summon_angle := rng.randf() * TAU + TAU * float(summon_index) / float(elite_summon_count)
						spawn_enemy(EnemyKind.HTTP_404, positions[index] + Vector2.from_angle(summon_angle) * rng.randf_range(62.0, 88.0))
					timers[index] = 4.2 * ability_cooldown_multiplier
					states[index] = 1.2
					elite_skill_cast.emit("502 告警扇出", positions[index], 1)
			EnemyKind.ELITE_OOM:
				speed_scale = 0.38
				if timers[index] <= 0.0 and _try_consume_elite_cast(distance):
					_spawn_hazard(HazardKind.OVERLOAD_PULSE, positions[index], 155.0, 0.90, 0.45, 12.0 * affix_damage_multiplier, entity_ids[index])
					timers[index] = 5.0 * ability_cooldown_multiplier
					elite_skill_cast.emit("OOM 过载脉冲", positions[index], 1)
			EnemyKind.INCIDENT_CORE:
				speed_scale = 0.16 if boss_phase == 1 else 0.06
				if timers[index] <= 0.0 and boss_phase < 2:
					for summon_index in range(boss_summon_count):
						var summon_angle := rng.randf() * TAU + TAU * float(summon_index) / float(boss_summon_count)
						spawn_enemy(EnemyKind.HTTP_404, positions[index] + Vector2.from_angle(summon_angle) * rng.randf_range(96.0, 132.0))
					timers[index] = (2.8 if boss_phase == 1 else 4.0) * ability_cooldown_multiplier
				if boss_phase == 1 and affix_timers[index] <= 0.0:
					_cast_boss_skill(index)

		if _tier(kinds[index]) == 1:
			_update_elite_shield(index)
			if affix_timers[index] <= 0.0 and _try_consume_elite_cast(distance):
				_cast_elite_affix(index)

		if slow_timers[index] > 0.0:
			speed_scale *= 0.48
		if root_timers[index] > 0.0:
			speed_scale = 0.0

		positions[index] += move_direction * speeds[index] * speed_scale * delta
		positions[index].x = clampf(positions[index].x, WORLD_RECT.position.x, WORLD_RECT.end.x)
		positions[index].y = clampf(positions[index].y, WORLD_RECT.position.y, WORLD_RECT.end.y)

		var contact_distance := radii[index] + 17.0
		var is_validating_boss := kinds[index] == EnemyKind.INCIDENT_CORE and boss_phase == 2
		if distance < contact_distance and contact_timers[index] <= 0.0 and not is_validating_boss:
			if player.has_method("take_damage"):
				player.call("take_damage", _contact_damage(kinds[index]))
			contact_timers[index] = 0.7
		index += 1
	queue_redraw()


func get_nearest_target(origin: Vector2, maximum_range: float) -> Dictionary:
	var best_index := -1
	var best_distance_squared := maximum_range * maximum_range
	for index in range(count):
		if kinds[index] == EnemyKind.INCIDENT_CORE and boss_phase != 1:
			continue
		var distance_squared := origin.distance_squared_to(positions[index])
		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			best_index = index
	if best_index < 0:
		return {"hit": false}
	return {
		"hit": true,
		"index": best_index,
		"position": positions[best_index],
		"kind": kinds[best_index],
		"tier": _tier(kinds[best_index]),
	}


func damage_index(index: int, amount: float, source_id: String = "") -> bool:
	if index < 0 or index >= count:
		return false
	var kind := kinds[index]
	if kind == EnemyKind.INCIDENT_CORE and boss_phase != 1:
		return false
	amount *= maxf(1.0, vulnerability_multipliers[index])
	if shield_health[index] > 0.0:
		var absorbed := minf(shield_health[index], amount)
		shield_health[index] -= absorbed
		amount -= absorbed
		states[index] = maxf(states[index], 0.16)
		if shield_health[index] <= 0.0:
			shield_recharge_timers[index] = maxf(4.5, 11.0 * ability_cooldown_multiplier)
			if _tier(kind) == 1:
				slow_timers[index] = maxf(slow_timers[index], 1.2)
				affix_timers[index] += 1.2
		if amount <= 0.0:
			return true
	health[index] -= amount
	states[index] = maxf(states[index], 0.12)
	if kind == EnemyKind.INCIDENT_CORE:
		boss_status_changed.emit(boss_phase, maxf(0.0, health[index]), maximum_health[index])
		if health[index] <= 0.0:
			health[index] = 0.1
			boss_phase = 2
			shield_health[index] = 0.0
			_clear_hazards_for_tier(2)
			boss_status_changed.emit(boss_phase, 0.0, maximum_health[index])
			boss_defeated.emit()
		return true
	if health[index] <= 0.0:
		_close_enemy(index, source_id)
	return true


func damage_area(center: Vector2, area_radius: float, amount: float, source_id: String = "") -> int:
	var hit_count := 0
	var index := 0
	var radius_squared := area_radius * area_radius
	while index < count:
		if positions[index].distance_squared_to(center) <= radius_squared:
			var old_count := count
			if damage_index(index, amount, source_id):
				hit_count += 1
			if count < old_count:
				continue
		index += 1
	return hit_count


func damage_ring(center: Vector2, orbit_radius: float, band_radius: float, amount: float, source_id: String = "") -> int:
	var hit_count := 0
	var index := 0
	while index < count:
		if kinds[index] == EnemyKind.INCIDENT_CORE and boss_phase != 1:
			index += 1
			continue
		var distance := positions[index].distance_to(center)
		var allowed_band := band_radius + radii[index] * 0.35
		if absf(distance - orbit_radius) <= allowed_band:
			var old_count := count
			if damage_index(index, amount, source_id):
				hit_count += 1
			if count < old_count:
				continue
		index += 1
	return hit_count


func damage_arc(center: Vector2, forward: Vector2, area_radius: float, half_angle: float, amount: float) -> int:
	var hit_count := 0
	var index := 0
	var radius_squared := area_radius * area_radius
	var normalized_forward := forward.normalized()
	var minimum_dot := cos(half_angle)
	while index < count:
		var offset := positions[index] - center
		var distance_squared := offset.length_squared()
		var inside_arc := distance_squared <= radius_squared
		if inside_arc and distance_squared > 0.001:
			inside_arc = normalized_forward.dot(offset / sqrt(distance_squared)) >= minimum_dot
		if inside_arc:
			var old_count := count
			if damage_index(index, amount):
				hit_count += 1
			if count < old_count:
				continue
		index += 1
	return hit_count


func damage_line(start: Vector2, end: Vector2, half_width: float, amount: float, maximum_targets: int = -1, source_id: String = "") -> Array[Vector2]:
	var segment := end - start
	var segment_length_squared := maxf(0.001, segment.length_squared())
	var candidates: Array[Dictionary] = []
	for index in range(count):
		if kinds[index] == EnemyKind.INCIDENT_CORE and boss_phase != 1:
			continue
		var offset := positions[index] - start
		var along := clampf(offset.dot(segment) / segment_length_squared, 0.0, 1.0)
		var closest := start + segment * along
		var allowed_width := half_width + radii[index] * 0.35
		if positions[index].distance_squared_to(closest) <= allowed_width * allowed_width:
			candidates.append({"index": index, "along": along, "position": positions[index]})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["along"]) < float(b["along"]))
	if maximum_targets >= 0 and candidates.size() > maximum_targets:
		candidates.resize(maximum_targets)
	var hit_positions: Array[Vector2] = []
	var selected_indices: Array[int] = []
	for candidate in candidates:
		hit_positions.append(Vector2(candidate["position"]))
		selected_indices.append(int(candidate["index"]))
	selected_indices.sort()
	selected_indices.reverse()
	for selected_index in selected_indices:
		damage_index(selected_index, amount, source_id)
	return hit_positions


func has_enemy_in_area(center: Vector2, area_radius: float) -> bool:
	var radius_squared := area_radius * area_radius
	for index in range(count):
		if kinds[index] == EnemyKind.INCIDENT_CORE and boss_phase != 1:
			continue
		if positions[index].distance_squared_to(center) <= radius_squared:
			return true
	return false


func count_enemies_in_area(center: Vector2, area_radius: float, include_elites: bool = true) -> int:
	var nearby := 0
	var radius_squared := area_radius * area_radius
	for index in range(count):
		if kinds[index] == EnemyKind.INCIDENT_CORE:
			continue
		if not include_elites and _tier(kinds[index]) > 0:
			continue
		if positions[index].distance_squared_to(center) <= radius_squared:
			nearby += 1
	return nearby


func slow_area(center: Vector2, area_radius: float, duration: float) -> int:
	var slowed := 0
	var radius_squared := area_radius * area_radius
	for index in range(count):
		if positions[index].distance_squared_to(center) > radius_squared:
			continue
		var has_unstoppable := EliteAffixCatalog.has(affix_masks[index], EliteAffixCatalog.Affix.UNSTOPPABLE)
		var resistance := 0.15 if has_unstoppable else (0.35 if _tier(kinds[index]) == 2 else (0.60 if _tier(kinds[index]) == 1 else 1.0))
		slow_timers[index] = maxf(slow_timers[index], duration * resistance)
		slowed += 1
	return slowed


func root_area(center: Vector2, area_radius: float, duration: float) -> int:
	var rooted := 0
	var radius_squared := area_radius * area_radius
	for index in range(count):
		if positions[index].distance_squared_to(center) > radius_squared:
			continue
		var has_unstoppable := EliteAffixCatalog.has(affix_masks[index], EliteAffixCatalog.Affix.UNSTOPPABLE)
		var resistance := 0.05 if has_unstoppable else (0.10 if _tier(kinds[index]) == 2 else (0.28 if _tier(kinds[index]) == 1 else 1.0))
		root_timers[index] = maxf(root_timers[index], duration * resistance)
		states[index] = maxf(states[index], minf(0.36, duration * resistance))
		rooted += 1
	return rooted


func block_line(start: Vector2, end: Vector2, half_width: float, protected_position: Vector2) -> int:
	var segment := end - start
	var segment_length_squared := maxf(0.001, segment.length_squared())
	var line_normal := segment.normalized().orthogonal()
	var protected_side := signf((protected_position - start).dot(line_normal))
	if is_zero_approx(protected_side):
		protected_side = 1.0
	var blocked := 0
	for index in range(count):
		if _tier(kinds[index]) > 0:
			continue
		var offset := positions[index] - start
		var along := clampf(offset.dot(segment) / segment_length_squared, 0.0, 1.0)
		var closest := start + segment * along
		var clearance := half_width + radii[index] * 0.72
		if positions[index].distance_squared_to(closest) > clearance * clearance:
			continue
		var enemy_side := signf((positions[index] - start).dot(line_normal))
		var blocked_side := -protected_side
		if not is_zero_approx(enemy_side) and enemy_side != protected_side:
			blocked_side = enemy_side
		positions[index] = closest + line_normal * blocked_side * clearance
		slow_timers[index] = maxf(slow_timers[index], 0.18)
		states[index] = maxf(states[index], 0.12)
		blocked += 1
	return blocked


func amplify_damage_area(center: Vector2, area_radius: float, multiplier: float, duration: float) -> int:
	var amplified := 0
	var radius_squared := area_radius * area_radius
	var resolved_multiplier := clampf(multiplier, 1.0, 2.0)
	for index in range(count):
		if kinds[index] == EnemyKind.INCIDENT_CORE and boss_phase != 1:
			continue
		if positions[index].distance_squared_to(center) > radius_squared:
			continue
		vulnerability_timers[index] = maxf(vulnerability_timers[index], duration)
		vulnerability_multipliers[index] = maxf(vulnerability_multipliers[index], resolved_multiplier)
		amplified += 1
	return amplified


func damage_nearest_targets(origin: Vector2, maximum_range: float, amount: float, maximum_targets: int, secondary_damage_scale: float = 1.0, source_id: String = "") -> Array[Vector2]:
	var wanted := maxi(0, maximum_targets)
	var selected_indices: Array[int] = []
	var selected_distances: Array[float] = []
	var selected_positions: Array[Vector2] = []
	var maximum_distance_squared := maximum_range * maximum_range
	for index in range(count):
		if kinds[index] == EnemyKind.INCIDENT_CORE and boss_phase != 1:
			continue
		var distance_squared := origin.distance_squared_to(positions[index])
		if distance_squared > maximum_distance_squared or wanted <= 0:
			continue
		var insertion_index := selected_distances.size()
		for selected_index in range(selected_distances.size()):
			if distance_squared < selected_distances[selected_index]:
				insertion_index = selected_index
				break
		if insertion_index >= wanted:
			continue
		selected_indices.insert(insertion_index, index)
		selected_distances.insert(insertion_index, distance_squared)
		selected_positions.insert(insertion_index, positions[index])
		if selected_indices.size() > wanted:
			selected_indices.pop_back()
			selected_distances.pop_back()
			selected_positions.pop_back()
	var hit_positions: Array[Vector2] = []
	for position_value in selected_positions:
		hit_positions.append(position_value)
	# Removing a packed entity swaps in the last item. Resolve from the highest
	# index downward so every selected target remains stable for this cast.
	var damage_order: Array[int] = []
	for selected_index in range(selected_indices.size()):
		damage_order.append(selected_index)
	damage_order.sort_custom(func(a: int, b: int) -> bool: return selected_indices[a] > selected_indices[b])
	for selected_index in damage_order:
		var damage_scale := 1.0 if selected_index == 0 else secondary_damage_scale
		damage_index(selected_indices[selected_index], amount * damage_scale, source_id)
	return hit_positions


func push_area(center: Vector2, area_radius: float, push_distance: float) -> int:
	var pushed := 0
	var radius_squared := area_radius * area_radius
	for index in range(count):
		var offset := positions[index] - center
		var distance_squared := offset.length_squared()
		if distance_squared <= 0.001 or distance_squared > radius_squared:
			continue
		var distance := sqrt(distance_squared)
		var falloff := 1.0 - distance / area_radius
		var has_unstoppable := EliteAffixCatalog.has(affix_masks[index], EliteAffixCatalog.Affix.UNSTOPPABLE)
		var tier_scale := 0.05 if has_unstoppable else (0.18 if _tier(kinds[index]) == 2 else (0.45 if _tier(kinds[index]) == 1 else 1.0))
		positions[index] += offset / distance * push_distance * maxf(0.25, falloff) * tier_scale
		positions[index].x = clampf(positions[index].x, WORLD_RECT.position.x, WORLD_RECT.end.x)
		positions[index].y = clampf(positions[index].y, WORLD_RECT.position.y, WORLD_RECT.end.y)
		pushed += 1
	return pushed


func get_random_enemy_position() -> Vector2:
	if count <= 0:
		return Vector2.INF
	return positions[rng.randi_range(0, count - 1)]


func get_random_enemy_positions(maximum_positions: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if count <= 0 or maximum_positions <= 0:
		return result
	var wanted := mini(maximum_positions, count)
	var used := {}
	var attempts := 0
	while result.size() < wanted and attempts < wanted * 8:
		var index := rng.randi_range(0, count - 1)
		if not used.has(index):
			used[index] = true
			result.append(positions[index])
		attempts += 1
	if result.size() < wanted:
		for index in range(count):
			if result.size() >= wanted:
				break
			if not used.has(index):
				result.append(positions[index])
	return result


func expose_boss() -> void:
	if boss_phase != 0:
		return
	boss_phase = 1
	var boss_index := _find_kind(EnemyKind.INCIDENT_CORE)
	if boss_index >= 0:
		shield_health[boss_index] = shield_maximum[boss_index]
		affix_timers[boss_index] = 1.6
		boss_status_changed.emit(boss_phase, health[boss_index], maximum_health[boss_index])


func finish_boss() -> void:
	_clear_hazards_for_tier(2)
	var boss_index := _find_kind(EnemyKind.INCIDENT_CORE)
	if boss_index >= 0:
		_remove_at(boss_index)
	boss_phase = -1
	queue_redraw()


func has_boss() -> bool:
	return _find_kind(EnemyKind.INCIDENT_CORE) >= 0


func count_non_boss() -> int:
	return count - (1 if has_boss() else 0)


func get_radar_snapshot(maximum_normal: int = 72) -> Dictionary:
	var normal := PackedVector2Array()
	var elite := PackedVector2Array()
	var boss := PackedVector2Array()
	var normal_total := maxi(1, count_non_boss())
	var sample_step := maxi(1, ceili(float(normal_total) / float(maxi(1, maximum_normal))))
	var normal_seen := 0
	for index in range(count):
		var tier_value := _tier(kinds[index])
		if tier_value == 2:
			boss.append(positions[index])
		elif tier_value == 1:
			elite.append(positions[index])
		else:
			if normal_seen % sample_step == 0 and normal.size() < maximum_normal:
				normal.append(positions[index])
			normal_seen += 1
	return {"normal": normal, "elite": elite, "boss": boss}


func _close_enemy(index: int, source_id: String = "") -> void:
	var closed_position := positions[index]
	var closed_kind := kinds[index]
	var xp_value := _xp_value(closed_kind)
	var tier_value := _tier(closed_kind)
	if tier_value == 1 and EliteAffixCatalog.has(affix_masks[index], EliteAffixCatalog.Affix.VOLATILE):
		_spawn_hazard(HazardKind.VOLATILE_CORE, closed_position, 118.0, maxf(1.0, _warning_duration(1.35)), 0.55, 24.0 * affix_damage_multiplier, entity_ids[index])
		elite_skill_cast.emit("崩溃自爆", closed_position, 1)
	_remove_at(index)
	enemy_closed.emit(closed_position, xp_value, closed_kind, tier_value)
	if not source_id.is_empty():
		enemy_closed_by_source.emit(source_id, closed_position, tier_value)


func _remove_at(index: int) -> void:
	count -= 1
	if index == count:
		return
	positions[index] = positions[count]
	kinds[index] = kinds[count]
	health[index] = health[count]
	maximum_health[index] = maximum_health[count]
	speeds[index] = speeds[count]
	radii[index] = radii[count]
	ages[index] = ages[count]
	timers[index] = timers[count]
	contact_timers[index] = contact_timers[count]
	states[index] = states[count]
	slow_timers[index] = slow_timers[count]
	root_timers[index] = root_timers[count]
	vulnerability_timers[index] = vulnerability_timers[count]
	vulnerability_multipliers[index] = vulnerability_multipliers[count]
	entity_ids[index] = entity_ids[count]
	affix_masks[index] = affix_masks[count]
	affix_timers[index] = affix_timers[count]
	affix_cursors[index] = affix_cursors[count]
	shield_health[index] = shield_health[count]
	shield_maximum[index] = shield_maximum[count]
	shield_recharge_timers[index] = shield_recharge_timers[count]


func _find_kind(kind: int) -> int:
	for index in range(count):
		if kinds[index] == kind:
			return index
	return -1


func _base_health(kind: int) -> float:
	match kind:
		EnemyKind.HTTP_404: return 18.0
		EnemyKind.BUG: return 14.0
		EnemyKind.NXDOMAIN: return 26.0
		EnemyKind.TIMEOUT_408: return 34.0
		EnemyKind.ENOSPC: return 64.0
		EnemyKind.ELITE_502: return 420.0
		EnemyKind.ELITE_OOM: return 520.0
		EnemyKind.INCIDENT_CORE: return 1600.0
	return 20.0


func _base_speed(kind: int) -> float:
	match kind:
		EnemyKind.HTTP_404: return 74.0
		EnemyKind.BUG: return 118.0
		EnemyKind.NXDOMAIN: return 58.0
		EnemyKind.TIMEOUT_408: return 50.0
		EnemyKind.ENOSPC: return 36.0
		EnemyKind.ELITE_502: return 42.0
		EnemyKind.ELITE_OOM: return 34.0
		EnemyKind.INCIDENT_CORE: return 28.0
	return 60.0


func _base_radius(kind: int) -> float:
	match kind:
		EnemyKind.HTTP_404: return 10.0
		EnemyKind.BUG: return 9.0
		EnemyKind.NXDOMAIN: return 11.0
		EnemyKind.TIMEOUT_408: return 12.0
		EnemyKind.ENOSPC: return 14.0
		EnemyKind.ELITE_502: return 58.0
		EnemyKind.ELITE_OOM: return 62.0
		EnemyKind.INCIDENT_CORE: return 125.0
	return 10.0


func _contact_damage(kind: int) -> float:
	var base_damage := 5.0
	match _tier(kind):
		1: base_damage = 12.0
		2: base_damage = 18.0
	return base_damage * _damage_multiplier(kind)


func _health_multiplier(kind: int) -> float:
	match _tier(kind):
		1: return elite_health_multiplier
		2: return boss_health_multiplier
	return normal_health_multiplier


func _damage_multiplier(kind: int) -> float:
	match _tier(kind):
		1: return elite_damage_multiplier
		2: return boss_damage_multiplier
	return normal_damage_multiplier


func _speed_multiplier(kind: int) -> float:
	match _tier(kind):
		1: return elite_speed_multiplier
		2: return boss_speed_multiplier
	return normal_speed_multiplier


func _xp_value(kind: int) -> int:
	match _tier(kind):
		1: return 18
		2: return 0
	return 2 if kind != EnemyKind.ENOSPC else 4


func _tier(kind: int) -> int:
	if kind == EnemyKind.INCIDENT_CORE:
		return 2
	if kind == EnemyKind.ELITE_502 or kind == EnemyKind.ELITE_OOM:
		return 1
	return 0


func _draw() -> void:
	_draw_hazards()
	for index in range(count):
		_draw_enemy(index)


func _draw_hazards() -> void:
	for hazard in hazards:
		var kind := int(hazard["kind"])
		var position_value := Vector2(hazard["position"])
		var radius_value := float(hazard["radius"])
		var warmup := float(hazard["warmup"])
		var color := _hazard_color(kind)
		if warmup > 0.0:
			var warning_progress := clampf(1.0 - warmup / float(hazard["warmup_total"]), 0.0, 1.0)
			draw_circle(position_value, radius_value, Color(color, 0.08))
			draw_arc(position_value, radius_value, -PI * 0.5, -PI * 0.5 + TAU * warning_progress, 48, color, 4.0)
			draw_arc(position_value, maxf(8.0, radius_value * (0.24 + warning_progress * 0.62)), 0.0, TAU, 32, Color(color, 0.72), 2.0)
			_draw_hazard_glyph(position_value, radius_value, kind, color)
			if kind == HazardKind.TELEPORT:
				var source_position := Vector2(hazard["source_position"])
				if source_position.is_finite():
					_draw_dashed_connection(source_position, position_value, Color(color, 0.72))
			if player != null and player.global_position.distance_squared_to(position_value) < 680.0 * 680.0:
				_draw_label(position_value + Vector2(0, -radius_value - 8.0), _hazard_label(kind), color, 10)
			continue
		var life_ratio := clampf(float(hazard["duration"]) / float(hazard["duration_total"]), 0.0, 1.0)
		if kind == HazardKind.FIRE_POOL:
			draw_circle(position_value, radius_value, Color(Color("5c1d15"), 0.72))
			draw_arc(position_value, radius_value, 0.0, TAU, 48, Color(Color("ff5b35"), 0.90), 3.0)
			for ember_index in range(8):
				var angle := TAU * float(ember_index) / 8.0 + float(Time.get_ticks_msec()) * 0.0015
				var ember_position := position_value + Vector2.from_angle(angle) * radius_value * (0.28 + 0.08 * float(ember_index % 3))
				draw_rect(Rect2(ember_position - Vector2(3, 3), Vector2(6, 6)), Color(Color("ffb43b"), 0.75))
		else:
			draw_circle(position_value, radius_value * (1.0 - life_ratio * 0.18), Color(color, 0.10 * life_ratio))
			draw_arc(position_value, radius_value * (1.0 - life_ratio * 0.18), 0.0, TAU, 48, Color(color, life_ratio), 4.0)
			_draw_hazard_glyph(position_value, radius_value, kind, Color(color, life_ratio))


func _draw_hazard_glyph(center: Vector2, radius_value: float, kind: int, color: Color) -> void:
	match kind:
		HazardKind.FROST_BURST:
			for spoke_index in range(6):
				var direction := Vector2.from_angle(TAU * float(spoke_index) / 6.0)
				draw_line(center + direction * radius_value * 0.18, center + direction * radius_value * 0.68, color, 3.0)
		HazardKind.LIGHTNING:
			draw_line(center + Vector2(-radius_value * 0.65, 0), center + Vector2(radius_value * 0.65, 0), color, 2.0)
			draw_line(center + Vector2(0, -radius_value * 0.65), center + Vector2(0, radius_value * 0.65), color, 2.0)
			draw_rect(Rect2(center - Vector2(6, 6), Vector2(12, 12)), color)
		HazardKind.TELEPORT:
			var extent := radius_value * 0.55
			draw_line(center + Vector2(0, -extent), center + Vector2(extent, 0), color, 3.0)
			draw_line(center + Vector2(extent, 0), center + Vector2(0, extent), color, 3.0)
			draw_line(center + Vector2(0, extent), center + Vector2(-extent, 0), color, 3.0)
			draw_line(center + Vector2(-extent, 0), center + Vector2(0, -extent), color, 3.0)
		HazardKind.VOLATILE_CORE, HazardKind.OVERLOAD_PULSE:
			for spoke_index in range(4):
				var direction := Vector2.from_angle(TAU * float(spoke_index) / 4.0 + PI * 0.25)
				draw_line(center + direction * radius_value * 0.20, center + direction * radius_value * 0.64, color, 4.0)


func _draw_dashed_connection(start: Vector2, end: Vector2, color: Color) -> void:
	var segment := end - start
	var length := segment.length()
	if length <= 0.1:
		return
	var direction := segment / length
	var cursor := 0.0
	while cursor < length:
		var dash_end := minf(length, cursor + 14.0)
		draw_line(start + direction * cursor, start + direction * dash_end, color, 2.0)
		cursor += 24.0


func _hazard_color(kind: int) -> Color:
	match kind:
		HazardKind.FIRE_POOL: return Color("ff6b3d")
		HazardKind.FROST_BURST: return Color("68d8ff")
		HazardKind.TELEPORT: return Color("df78ff")
		HazardKind.LIGHTNING: return Color("ffe45c")
		HazardKind.VOLATILE_CORE: return Color("ff4057")
		HazardKind.OVERLOAD_PULSE: return Color("ff7ae5")
	return Color.WHITE


func _hazard_label(kind: int) -> String:
	match kind:
		HazardKind.FIRE_POOL: return "FIRE / 熔火"
		HazardKind.FROST_BURST: return "FROST / 冻结"
		HazardKind.TELEPORT: return "BLINK / 漂移"
		HazardKind.LIGHTNING: return "STORM / 雷击"
		HazardKind.VOLATILE_CORE: return "PANIC / 自爆"
		HazardKind.OVERLOAD_PULSE: return "OOM / 过载"
	return "ALERT"


func _draw_enemy(index: int) -> void:
	var position_value := positions[index]
	var kind := kinds[index]
	var flash := states[index] > 0.0 and int(Time.get_ticks_msec() / 55) % 2 == 0
	var tier := _tier(kind)
	var float_offset := Vector2(0.0, sin(ages[index] * (5.5 if kind == EnemyKind.BUG else 2.8) + float(index)) * (1.0 if tier == 0 else 1.8))
	var draw_size := _fault_draw_size(kind)
	var shadow_size := Vector2(draw_size.x * 0.28, maxf(4.0, draw_size.y * 0.07))
	_draw_shadow(position_value, shadow_size)
	var destination := Rect2(position_value + float_offset - draw_size * Vector2(0.5, 0.60), draw_size)
	var modulate := Color(1.0, 0.72, 0.72, 1.0) if flash else Color.WHITE
	draw_texture_rect_region(FAULT_SPRITES, destination, _fault_source_region(kind), modulate)

	if tier == 0 and _should_draw_normal_label(index):
		var label_data := _normal_fault_label(kind)
		_draw_label(position_value + Vector2(0, -draw_size.y * 0.34), String(label_data[0]), Color(String(label_data[1])), 8)
	elif tier == 1:
		var health_ratio := clampf(health[index] / maxf(1.0, maximum_health[index]), 0.0, 1.0)
		var accent := Color("3ee6ef") if kind == EnemyKind.ELITE_502 else Color("65e890")
		draw_arc(position_value + Vector2(0, 5), draw_size.x * 0.42, -PI * 0.5, -PI * 0.5 + TAU * health_ratio, 40, accent, 3.0)
		if shield_maximum[index] > 0.0 and shield_health[index] > 0.0:
			var shield_ratio := clampf(shield_health[index] / shield_maximum[index], 0.0, 1.0)
			draw_circle(position_value + Vector2(0, 4), draw_size.x * 0.50, Color(Color("45f0e2"), 0.08))
			draw_arc(position_value + Vector2(0, 4), draw_size.x * 0.50, -PI * 0.5, -PI * 0.5 + TAU * shield_ratio, 40, Color("45f0e2"), 4.0)
		_draw_affix_badges(index, position_value, draw_size)
	elif kind == EnemyKind.INCIDENT_CORE:
		if shield_maximum[index] > 0.0 and shield_health[index] > 0.0:
			var shield_ratio := clampf(shield_health[index] / shield_maximum[index], 0.0, 1.0)
			draw_circle(position_value, draw_size.x * 0.49, Color(Color("45f0e2"), 0.06))
			draw_arc(position_value, draw_size.x * 0.49, -PI * 0.5, -PI * 0.5 + TAU * shield_ratio, 56, Color("45f0e2"), 5.0)
		if boss_phase == 0:
			draw_arc(position_value, draw_size.x * 0.46, 0.0, TAU, 56, Color("e34b3d"), 4.0)
		elif boss_phase == 2:
			draw_arc(position_value, draw_size.x * 0.50, 0.0, TAU, 56, Color("32e0c4"), 4.0)


func _draw_affix_badges(index: int, center: Vector2, draw_size: Vector2) -> void:
	var active_affixes: Array[int] = []
	for affix in EliteAffixCatalog.ORDER:
		if EliteAffixCatalog.has(affix_masks[index], affix):
			active_affixes.append(affix)
	var badge_width := 15.0
	var badge_start := -float(active_affixes.size() - 1) * badge_width * 0.5
	for badge_index in range(active_affixes.size()):
		var definition := EliteAffixCatalog.definition(active_affixes[badge_index])
		var badge_color := Color(String(definition.get("color", "ffffff")))
		var badge_position := center + Vector2(badge_start + float(badge_index) * badge_width, -draw_size.y * 0.38)
		draw_rect(Rect2(badge_position - Vector2(5, 5), Vector2(10, 10)), Color("061018"))
		draw_rect(Rect2(badge_position - Vector2(4, 4), Vector2(8, 8)), badge_color)
	if EliteAffixCatalog.has(affix_masks[index], EliteAffixCatalog.Affix.UNSTOPPABLE):
		var corner := draw_size.x * 0.43
		for side in [-1.0, 1.0]:
			draw_line(center + Vector2(side * corner, -16), center + Vector2(side * (corner + 10), -6), Color("ffb347"), 4.0)
			draw_line(center + Vector2(side * corner, 16), center + Vector2(side * (corner + 10), 6), Color("ffb347"), 4.0)
	if player != null and player.global_position.distance_squared_to(center) <= 720.0 * 720.0:
		var names := EliteAffixCatalog.names_from_mask(affix_masks[index])
		_draw_label(center + Vector2(0, -draw_size.y * 0.48), " · ".join(names), Color("f2f8fa"), 10)


func _fault_source_region(kind: int) -> Rect2:
	var cell_size := Vector2(float(FAULT_SPRITES.get_width()) / 4.0, float(FAULT_SPRITES.get_height()) / 2.0)
	var cell := Vector2.ZERO
	match kind:
		EnemyKind.HTTP_404: cell = Vector2(0, 0)
		EnemyKind.NXDOMAIN: cell = Vector2(1, 0)
		EnemyKind.ENOSPC: cell = Vector2(2, 0)
		EnemyKind.BUG: cell = Vector2(3, 0)
		EnemyKind.TIMEOUT_408: cell = Vector2(0, 1)
		EnemyKind.ELITE_502: cell = Vector2(1, 1)
		EnemyKind.ELITE_OOM: cell = Vector2(2, 1)
		EnemyKind.INCIDENT_CORE: cell = Vector2(3, 1)
	return Rect2(cell * cell_size + Vector2(2, 2), cell_size - Vector2(4, 4))


func _fault_draw_size(kind: int) -> Vector2:
	match kind:
		EnemyKind.HTTP_404: return Vector2(62, 70)
		EnemyKind.NXDOMAIN: return Vector2(64, 64)
		EnemyKind.ENOSPC: return Vector2(72, 61)
		EnemyKind.BUG: return Vector2(64, 58)
		EnemyKind.TIMEOUT_408: return Vector2(64, 74)
		EnemyKind.ELITE_502: return Vector2(200, 184)
		EnemyKind.ELITE_OOM: return Vector2(198, 192)
		EnemyKind.INCIDENT_CORE: return Vector2(390, 358)
	return Vector2(56, 56)


func _normal_fault_label(kind: int) -> Array[String]:
	match kind:
		EnemyKind.HTTP_404: return ["404", "ff8678"]
		EnemyKind.NXDOMAIN: return ["NXDOMAIN", "6eefff"]
		EnemyKind.ENOSPC: return ["ENOSPC", "e8c455"]
		EnemyKind.BUG: return ["BUG", "ff9c48"]
		EnemyKind.TIMEOUT_408: return ["408", "ffe274"]
	return ["ERROR", "ffffff"]


func _draw_shadow(center: Vector2, radius_value: Vector2) -> void:
	_draw_ellipse(center + Vector2(0, radius_value.y + 10), radius_value, Color(0.0, 0.0, 0.0, 0.42))


func _should_draw_normal_label(index: int) -> bool:
	if not labels_enabled:
		return false
	if count <= 80:
		return true
	if player == null or positions[index].distance_squared_to(player.global_position) > 540.0 * 540.0:
		return false
	# A stable one-in-three sample near the player keeps labels readable in a
	# dense wave. Elite and Boss labels remain visible at all times.
	return index % 3 == 0


func _draw_ellipse(center: Vector2, radius_value: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for point_index in range(24):
		var angle := TAU * float(point_index) / 24.0
		points.append(center + Vector2(cos(angle) * radius_value.x, sin(angle) * radius_value.y))
	draw_colored_polygon(points, color)


func _draw_label(center: Vector2, text: String, color: Color, font_size: int) -> void:
	var text_size := UI_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(UI_FONT, center - Vector2(text_size.x * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
