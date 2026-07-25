class_name CareerActionSystem
extends Node2D

signal action_used(action_kind: String, action_id: String)
signal action_feedback(title: String, detail: String, accent: Color)
signal career_metric(metric_id: String, amount: float)

const ActionCatalog := preload("res://scripts/career_action_catalog.gd")
const CAREER_SPRITES := preload("res://assets/generated/career_sprites_5x2.png")
const UI_FONT := preload("res://assets/fonts/NotoSansSC-VF.ttf")
const MAX_VISUALS := 140
const MAX_WALLS := 24
const MAX_ZONES := 18
const MAX_NODES := 16
const MAX_PENDING_ACTIONS := 72
const OPSDEV_TOOLCHAIN_BASE_CAP := 3
const OPSDEV_TOOLCHAIN_MAX_CAP := 7
const OPSDEV_HOT_RELOAD_DURATION := 10.0
const OPSDEV_HOT_RELOAD_EPOCH := 0.78
const AI_WORLD_RECT := Rect2(20.0, 180.0, 2360.0, 1140.0)
const AI_PIPELINE_STAGE_DAMAGE: Array[float] = [6.0, 10.0, 14.0, 22.0]
const AI_PIPELINE_STAGE_COLORS: Array[Color] = [Color("70caff"), Color("91ee70"), Color("d5ff74"), Color("ffffff")]
const AI_MODEL_DURATION := 8.40
const SIGNATURE_UPGRADE_IDS: Array[String] = ["signature_rate", "signature_quantity", "signature_damage", "signature_area"]
const DELIVERY_UPGRADE_IDS: Array[String] = ["delivery_sync_reserve", "delivery_sync_parallel", "delivery_release_burn_down"]
const OPSDEV_UPGRADE_IDS: Array[String] = ["opsdev_pipeline_capacity"]
const SECURITY_UPGRADE_IDS: Array[String] = ["security_cryo_acl", "security_storm_ids"]
const DELIVERY_Q_KILL_REDUCTION: Array[float] = [0.0, 0.12, 0.18, 0.24, 0.30, 0.36]
const DELIVERY_Q_CAST_REDUCTION_CAP: Array[float] = [0.0, 1.20, 1.80, 2.40, 3.00, 3.60]
const CAREER_ORDER: Array[String] = ["ops", "dba", "network", "security", "it_ops", "helpdesk", "opsdev", "sre", "delivery", "ai_infra"]
const DELIVERY_SUPPORT_ORDER: Array[String] = ["ops", "dba", "network", "security", "it_ops", "helpdesk", "opsdev", "sre", "ai_infra"]
const CAREER_COLORS := {
	"ops": Color("56e6dc"),
	"dba": Color("c68cff"),
	"network": Color("47c9f1"),
	"security": Color("ee6677"),
	"it_ops": Color("ffae62"),
	"helpdesk": Color("f0ca5a"),
	"opsdev": Color("9cff72"),
	"sre": Color("65e890"),
	"delivery": Color("ffce73"),
	"ai_infra": Color("91ee70"),
}
const OPSDEV_TOOL_NAMES := {
	"idempotent_script": "SCRIPT",
	"bash": "BASH",
	"ping": "PING",
	"firewall": "FW",
	"log": "LOG",
	"wrench": "WRENCH",
	"rule_chain": "CHAIN",
	"lock_zone": "LOCK",
	"worker": "POD",
}
const OPSDEV_TOOL_COLORS := {
	"idempotent_script": Color("9cff72"),
	"bash": Color("56e6dc"),
	"ping": Color("47c9f1"),
	"firewall": Color("efb23d"),
	"log": Color("ba77e8"),
	"wrench": Color("ffb454"),
	"rule_chain": Color("ee6677"),
	"lock_zone": Color("c68cff"),
	"worker": Color("91ee70"),
}
const OPSDEV_STAGE_MODIFIERS: Array[String] = ["FORK", "LOOP", "OPT", "FANOUT", "CACHE", "VECTOR", "JIT"]

var player: CharacterBody2D
var swarm: Node2D
var projection: Node2D
var combat: Node2D
var career_id := "ops"
var career: Dictionary = {}
var kit: Dictionary = {}
var accent := Color("56e6dc")
var damage_multiplier := 1.0
var signature_rate_level := 0
var signature_quantity_level := 0
var signature_damage_level := 0
var signature_area_level := 0
var skill_rate_level := 0
var ultimate_rate_level := 0
var artifact_skill_cooldown_multiplier := 1.0
var artifact_ultimate_cooldown_multiplier := 1.0
var artifact_damage_multiplier := 1.0
var artifact_signature_area_multiplier := 1.0

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
var sre_position_history: Array[Vector2] = []
var delivery_support_index := 0
var delivery_support_count := 0
var delivery_sync_reserve_level := 0
var delivery_sync_parallel_level := 0
var delivery_release_burn_down_level := 0
var delivery_skill_charge_timers: Array[float] = []
var delivery_q_cast_serial := 0
var opsdev_pipeline_capacity_level := 0
var security_cryo_acl_level := 0
var security_storm_ids_level := 0
var sre_replicas: Array[Dictionary] = []
var sre_failover_used := false
var opsdev_toolchain: Array[Dictionary] = []
var opsdev_hot_reload_seen: Dictionary = {}
var opsdev_hot_reload_epoch := 0
var opsdev_compile_serial := 0
var ai_model_decode_count := 0
var ai_model_eos_fired := false

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
	if combat != null and combat.has_signal("attack_fired") and not combat.is_connected("attack_fired", _on_combat_attack_fired):
		combat.connect("attack_fired", _on_combat_attack_fired)


func configure_career(career_data: Dictionary) -> void:
	career = career_data
	career_id = String(career.get("id", "ops"))
	kit = ActionCatalog.get_by_id(career_id)
	accent = Color(String(career.get("color", "56e6dc")))
	damage_multiplier = float(career.get("combat", {}).get("damage", 1.0))
	signature_rate_level = 0
	signature_quantity_level = 0
	signature_damage_level = 0
	signature_area_level = 0
	skill_rate_level = 0
	ultimate_rate_level = 0
	artifact_skill_cooldown_multiplier = 1.0
	artifact_ultimate_cooldown_multiplier = 1.0
	artifact_damage_multiplier = 1.0
	artifact_signature_area_multiplier = 1.0
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
	sre_position_history.clear()
	delivery_support_index = 0
	delivery_support_count = 0
	delivery_sync_reserve_level = 0
	delivery_sync_parallel_level = 0
	delivery_release_burn_down_level = 0
	delivery_skill_charge_timers.clear()
	delivery_q_cast_serial = 0
	opsdev_pipeline_capacity_level = 0
	security_cryo_acl_level = 0
	security_storm_ids_level = 0
	sre_replicas.clear()
	sre_failover_used = false
	opsdev_toolchain.clear()
	opsdev_hot_reload_seen.clear()
	opsdev_hot_reload_epoch = 0
	opsdev_compile_serial = 0
	ai_model_decode_count = 0
	ai_model_eos_fired = false
	if player != null and player.has_method("set_temporary_damage_reduction"):
		player.call("set_temporary_damage_reduction", 0.0)
	if combat != null and combat.has_method("set_temporary_damage_multiplier"):
		combat.call("set_temporary_damage_multiplier", 1.0)
	queue_redraw()


func set_meta_growth_levels(skill_level: int, ultimate_level: int) -> void:
	var old_skill_cooldown := _skill_cooldown()
	var old_ultimate_cooldown := _ultimate_cooldown()
	skill_rate_level = maxi(0, skill_level)
	ultimate_rate_level = maxi(0, ultimate_level)
	_rescale_active_cooldowns(old_skill_cooldown, old_ultimate_cooldown)


func set_artifact_modifiers(skill_cooldown: float, ultimate_cooldown: float, damage: float, signature_area: float) -> void:
	var old_skill_cooldown := _skill_cooldown()
	var old_ultimate_cooldown := _ultimate_cooldown()
	var old_signature_area := artifact_signature_area_multiplier
	artifact_skill_cooldown_multiplier = clampf(skill_cooldown, 0.50, 1.50)
	artifact_ultimate_cooldown_multiplier = clampf(ultimate_cooldown, 0.50, 1.50)
	artifact_damage_multiplier = clampf(damage, 0.25, 4.0)
	artifact_signature_area_multiplier = clampf(signature_area, 0.50, 1.50)
	_rescale_active_cooldowns(old_skill_cooldown, old_ultimate_cooldown)
	if not is_equal_approx(old_signature_area, artifact_signature_area_multiplier):
		play_signature_range_preview()


func reset_skill_cooldown() -> void:
	if career_id == "delivery":
		if not delivery_skill_charge_timers.is_empty():
			var ready_index := delivery_skill_charge_timers.find(delivery_skill_charge_timers.min())
			delivery_skill_charge_timers.remove_at(maxi(0, ready_index))
		_sync_delivery_skill_cooldown()
		return
	skill_cooldown_left = 0.0


func reduce_skill_cooldown(seconds: float) -> void:
	if career_id == "delivery":
		var reduction := maxf(0.0, seconds)
		for timer_index in range(delivery_skill_charge_timers.size() - 1, -1, -1):
			delivery_skill_charge_timers[timer_index] -= reduction
			if delivery_skill_charge_timers[timer_index] <= 0.0:
				delivery_skill_charge_timers.remove_at(timer_index)
		_sync_delivery_skill_cooldown()
		return
	skill_cooldown_left = maxf(0.0, skill_cooldown_left - maxf(0.0, seconds))


func reduce_ultimate_cooldown(seconds: float) -> void:
	ultimate_cooldown_left = maxf(0.0, ultimate_cooldown_left - maxf(0.0, seconds))


func _rescale_active_cooldowns(old_skill_cooldown: float, old_ultimate_cooldown: float) -> void:
	var new_skill_cooldown := _skill_cooldown()
	var new_ultimate_cooldown := _ultimate_cooldown()
	if career_id == "delivery" and old_skill_cooldown > 0.0:
		if delivery_skill_charge_timers.is_empty() and skill_cooldown_left > 0.0:
			delivery_skill_charge_timers.append(skill_cooldown_left)
		for timer_index in range(delivery_skill_charge_timers.size()):
			delivery_skill_charge_timers[timer_index] = minf(new_skill_cooldown, delivery_skill_charge_timers[timer_index] * new_skill_cooldown / old_skill_cooldown)
		_sync_delivery_skill_cooldown()
	elif skill_cooldown_left > 0.0 and old_skill_cooldown > 0.0:
		skill_cooldown_left = minf(new_skill_cooldown, skill_cooldown_left * new_skill_cooldown / old_skill_cooldown)
	if ultimate_cooldown_left > 0.0 and old_ultimate_cooldown > 0.0:
		ultimate_cooldown_left = minf(new_ultimate_cooldown, ultimate_cooldown_left * new_ultimate_cooldown / old_ultimate_cooldown)


func _skill_cooldown_for_level(level_value: int) -> float:
	var base_cooldown := float(kit.get("skill", {}).get("cooldown", 2.0))
	var growth_multiplier := 0.38 + 0.62 * pow(0.90, float(maxi(0, level_value)))
	return maxf(2.0, base_cooldown * growth_multiplier * artifact_skill_cooldown_multiplier)


func _ultimate_cooldown_for_level(level_value: int) -> float:
	var base_cooldown := float(kit.get("ultimate", {}).get("cooldown", 18.0))
	var growth_multiplier := 0.45 + 0.55 * pow(0.92, float(maxi(0, level_value)))
	return maxf(18.0, base_cooldown * growth_multiplier * artifact_ultimate_cooldown_multiplier)


func _skill_cooldown() -> float:
	return _skill_cooldown_for_level(skill_rate_level)


func _ultimate_cooldown() -> float:
	return _ultimate_cooldown_for_level(ultimate_rate_level)


func _delivery_skill_max_charges(level_value: int = -1) -> int:
	var resolved := delivery_sync_reserve_level if level_value < 0 else level_value
	return 2 + clampi(resolved, 0, 2)


func _delivery_skill_charges() -> int:
	return maxi(0, _delivery_skill_max_charges() - delivery_skill_charge_timers.size())


func _delivery_skill_silhouette_count(level_value: int = -1) -> int:
	var resolved := delivery_sync_parallel_level if level_value < 0 else level_value
	return 1 + clampi(resolved, 0, 3)


func _sync_delivery_skill_cooldown() -> void:
	skill_cooldown_left = 0.0 if delivery_skill_charge_timers.is_empty() else delivery_skill_charge_timers.min()


func _physics_process(delta: float) -> void:
	_advance_actions(delta, not debug_disable_auto_signature)


func _advance_actions(delta: float, allow_signature: bool) -> void:
	if player == null or swarm == null or kit.is_empty():
		return
	if career_id == "delivery":
		for timer_index in range(delivery_skill_charge_timers.size() - 1, -1, -1):
			delivery_skill_charge_timers[timer_index] -= delta
			if delivery_skill_charge_timers[timer_index] <= 0.0:
				delivery_skill_charge_timers.remove_at(timer_index)
		_sync_delivery_skill_cooldown()
	else:
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
	if player == null or kit.is_empty():
		return false
	if career_id == "delivery":
		if _delivery_skill_charges() <= 0:
			return false
	else:
		if skill_cooldown_left > 0.0:
			return false
	var resolved_direction := _resolved_direction(direction)
	var skill: Dictionary = kit["skill"]
	if career_id == "delivery":
		delivery_skill_charge_timers.append(_skill_cooldown())
		_sync_delivery_skill_cooldown()
	else:
		skill_cooldown_left = _skill_cooldown()
	match career_id:
		"ops": _skill_ops(resolved_direction)
		"dba": _skill_dba()
		"network": _skill_network()
		"security": _skill_security(resolved_direction)
		"it_ops": _skill_it_ops()
		"helpdesk": _skill_helpdesk()
		"opsdev": _skill_opsdev(resolved_direction)
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
	ultimate_cooldown_left = _ultimate_cooldown()
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
	signature["level"] = 1 + signature_rate_level + signature_quantity_level + signature_damage_level + signature_area_level
	signature["growth"] = get_signature_growth_snapshot()
	var skill: Dictionary = Dictionary(kit["skill"]).duplicate(true)
	var ultimate: Dictionary = Dictionary(kit["ultimate"]).duplicate(true)
	if career_id == "delivery":
		var next_support_id := DELIVERY_SUPPORT_ORDER[delivery_support_index % DELIVERY_SUPPORT_ORDER.size()]
		skill["name"] = "跨组联调 %d/%d · %s" % [_delivery_skill_charges(), _delivery_skill_max_charges(), _career_short_name(next_support_id)]
		skill["description"] = "每次召集 %d 位同事投放固有普攻；独立储备 %d 层；每三次支援完成一次联合验收。" % [_delivery_skill_silhouette_count(), _delivery_skill_max_charges()]
	elif career_id == "opsdev":
		var pipeline_label := _opsdev_pipeline_label()
		skill["name"] = "编译运行 %d/%d" % [opsdev_toolchain.size(), _opsdev_toolchain_cap()]
		skill["description"] = "当前工具链：%s。宽域编译全部槽位，按七级编译通道高速重放。" % pipeline_label
		ultimate["description"] = "10 秒进入 KERNEL HOT RELOAD；工具逐件上屏、连线并释放真实效果，每个 Epoch 自动执行整链，结束提交 650px MERGE COMBO。当前工具链：%s。" % pipeline_label
	skill["base_cooldown"] = float(kit["skill"].get("cooldown", 2.0))
	skill["cooldown"] = _skill_cooldown()
	skill["cooldown_level"] = skill_rate_level
	skill["remaining"] = skill_cooldown_left
	skill["ready"] = _delivery_skill_charges() > 0 if career_id == "delivery" else skill_cooldown_left <= 0.0
	if career_id == "delivery":
		skill["charges"] = _delivery_skill_charges()
		skill["max_charges"] = _delivery_skill_max_charges()
		skill["recharge_remaining"] = skill_cooldown_left
		skill["charge_timers"] = delivery_skill_charge_timers.duplicate()
	ultimate["base_cooldown"] = float(kit["ultimate"].get("cooldown", 18.0))
	ultimate["cooldown"] = _ultimate_cooldown()
	ultimate["cooldown_level"] = ultimate_rate_level
	ultimate["remaining"] = ultimate_cooldown_left
	ultimate["ready"] = ultimate_cooldown_left <= 0.0
	return {
		"career_id": career_id,
		"color": accent,
		"signature": signature,
		"skill": skill,
		"ultimate": ultimate,
		"meta_growth": {"skill_rate": skill_rate_level, "ultimate_rate": ultimate_rate_level},
		"active": ultimate_mode,
		"active_left": ultimate_left,
		"packet_capture_left": packet_capture_left,
		"walls": walls.size(),
		"zones": zones.size(),
		"nodes": nodes.size(),
		"pending": pending_actions.size(),
		"worker_count": _worker_count(),
		"opsdev_toolchain": _opsdev_toolchain_snapshot(),
		"opsdev_toolchain_capacity": _opsdev_toolchain_cap(),
		"opsdev_hot_reload_epoch": opsdev_hot_reload_epoch,
		"ai_token_count": _ai_token_count(),
		"ai_model_eos_fired": ai_model_eos_fired,
		"delivery_next_support": DELIVERY_SUPPORT_ORDER[delivery_support_index % DELIVERY_SUPPORT_ORDER.size()] if career_id == "delivery" else "",
		"delivery_q_cast_serial": delivery_q_cast_serial,
		"sre_replicas": sre_replicas.size(),
	}


func get_signature_upgrade_ids() -> Array[String]:
	return SIGNATURE_UPGRADE_IDS.duplicate()


func get_career_upgrade_ids() -> Array[String]:
	match career_id:
		"delivery": return DELIVERY_UPGRADE_IDS.duplicate()
		"opsdev": return OPSDEV_UPGRADE_IDS.duplicate()
		"security": return SECURITY_UPGRADE_IDS.duplicate()
	return []


func is_career_upgrade(upgrade_id: String) -> bool:
	return (career_id == "delivery" and upgrade_id in DELIVERY_UPGRADE_IDS) or (career_id == "opsdev" and upgrade_id in OPSDEV_UPGRADE_IDS) or (career_id == "security" and upgrade_id in SECURITY_UPGRADE_IDS)


func get_career_upgrade_level(upgrade_id: String) -> int:
	match upgrade_id:
		"delivery_sync_reserve": return delivery_sync_reserve_level
		"delivery_sync_parallel": return delivery_sync_parallel_level
		"delivery_release_burn_down": return delivery_release_burn_down_level
		"opsdev_pipeline_capacity": return opsdev_pipeline_capacity_level
		"security_cryo_acl": return security_cryo_acl_level
		"security_storm_ids": return security_storm_ids_level
	return 0


func get_career_upgrade_cap(upgrade_id: String) -> int:
	match upgrade_id:
		"delivery_sync_reserve": return 2
		"delivery_sync_parallel": return 3
		"delivery_release_burn_down": return 5
		"opsdev_pipeline_capacity": return OPSDEV_TOOLCHAIN_MAX_CAP - OPSDEV_TOOLCHAIN_BASE_CAP
		"security_cryo_acl": return 3
		"security_storm_ids": return 3
	return 0


func apply_career_upgrade(upgrade_id: String) -> void:
	match upgrade_id:
		"delivery_sync_reserve":
			delivery_sync_reserve_level = mini(get_career_upgrade_cap(upgrade_id), delivery_sync_reserve_level + 1)
		"delivery_sync_parallel":
			delivery_sync_parallel_level = mini(get_career_upgrade_cap(upgrade_id), delivery_sync_parallel_level + 1)
		"delivery_release_burn_down":
			delivery_release_burn_down_level = mini(get_career_upgrade_cap(upgrade_id), delivery_release_burn_down_level + 1)
		"opsdev_pipeline_capacity":
			opsdev_pipeline_capacity_level = mini(get_career_upgrade_cap(upgrade_id), opsdev_pipeline_capacity_level + 1)
		"security_cryo_acl":
			security_cryo_acl_level = mini(get_career_upgrade_cap(upgrade_id), security_cryo_acl_level + 1)
		"security_storm_ids":
			security_storm_ids_level = mini(get_career_upgrade_cap(upgrade_id), security_storm_ids_level + 1)
	_sync_delivery_skill_cooldown()


func get_career_upgrade_card(upgrade_id: String) -> Dictionary:
	var current := get_career_upgrade_level(upgrade_id)
	var next := mini(get_career_upgrade_cap(upgrade_id), current + 1)
	match upgrade_id:
		"delivery_sync_reserve":
			return {
				"id": upgrade_id,
				"name": "联调排期  STACK %d → %d" % [current, next],
				"title": "跨组联调储备提升至 %d 次" % _delivery_skill_max_charges(next),
				"description": "Q 独立储备 %d → %d 次 · 每层分别计算 %.1fs 充能 · 可连续调度，不共享整段冷却" % [_delivery_skill_max_charges(current), _delivery_skill_max_charges(next), _skill_cooldown()],
				"color": Color("70caff"),
			}
		"delivery_sync_parallel":
			return {
				"id": upgrade_id,
				"name": "并行会签  STACK %d → %d" % [current, next],
				"title": "单次联调到场 %d 位剪影" % _delivery_skill_silhouette_count(next),
				"description": "每次 Q 到场剪影 %d → %d · 各自投放固有普攻 · 支援累计每满 3 次仍触发联合验收" % [_delivery_skill_silhouette_count(current), _delivery_skill_silhouette_count(next)],
				"color": Color("ffce73"),
			}
		"delivery_release_burn_down":
			return {
				"id": upgrade_id,
				"name": "发布燃尽  STACK %d → %d" % [current, next],
				"title": "联调关单加速 R · %.2fs/次" % delivery_q_kill_ultimate_reduction(next),
				"description": "Q 造成击杀时，大招剩余 CD -%.2fs → -%.2fs · 单次 Q 最多削减 %.1fs → %.1fs · 5 阶封顶" % [delivery_q_kill_ultimate_reduction(current), delivery_q_kill_ultimate_reduction(next), delivery_q_cast_ultimate_reduction_cap(current), delivery_q_cast_ultimate_reduction_cap(next)],
				"color": Color("ff8d6b"),
			}
		"opsdev_pipeline_capacity":
			return {
				"id": upgrade_id,
				"name": "流水线扩容  STACK %d → %d" % [current, next],
				"title": "Runtime Toolchain 扩容至 %d 槽" % (OPSDEV_TOOLCHAIN_BASE_CAP + next),
				"description": "工具链容量 %d → %d · Q 与 R 可额外编译一种不同武器 · 最高 7 槽，每个槽位独立继承武器几何与伤害" % [OPSDEV_TOOLCHAIN_BASE_CAP + current, OPSDEV_TOOLCHAIN_BASE_CAP + next],
				"color": Color("9cff72"),
			}
		"security_cryo_acl":
			return {
				"id": upgrade_id,
				"name": "冷冻 ACL  STACK %d → %d" % [current, next],
				"title": "墙体挂载 CRYO ACL %d" % next,
				"description": "所有职业墙附加冰冻策略 · 减速持续与冻结窗口提高 · 同时恢复部分墙体压力，CRYO + IDS 满配时回到原强度上限",
				"color": Color("70d8ff"),
			}
		"security_storm_ids":
			return {
				"id": upgrade_id,
				"name": "雷暴 IDS  STACK %d → %d" % [current, next],
				"title": "墙体挂载 STORM IDS %d" % next,
				"description": "每次墙体灼烧额外向附近故障释放 %d 道链式闪电 · 闪电伤害与层数同步提高 · 同时恢复部分墙体压力" % (1 + next),
				"color": Color("d6f36a"),
			}
	return {"id": upgrade_id, "name": upgrade_id, "title": "实施交付专精", "description": "", "color": accent}


func delivery_q_kill_ultimate_reduction(level_value: int = -1) -> float:
	var resolved := delivery_release_burn_down_level if level_value < 0 else level_value
	return DELIVERY_Q_KILL_REDUCTION[clampi(resolved, 0, DELIVERY_Q_KILL_REDUCTION.size() - 1)]


func delivery_q_cast_ultimate_reduction_cap(level_value: int = -1) -> float:
	var resolved := delivery_release_burn_down_level if level_value < 0 else level_value
	return DELIVERY_Q_CAST_REDUCTION_CAP[clampi(resolved, 0, DELIVERY_Q_CAST_REDUCTION_CAP.size() - 1)]


func is_signature_upgrade(upgrade_id: String) -> bool:
	return upgrade_id in SIGNATURE_UPGRADE_IDS


func get_signature_upgrade_level(upgrade_id: String) -> int:
	match upgrade_id:
		"signature_rate": return signature_rate_level
		"signature_quantity": return signature_quantity_level
		"signature_damage": return signature_damage_level
		"signature_area": return signature_area_level
	return 0


func apply_signature_upgrade(upgrade_id: String) -> void:
	match upgrade_id:
		"signature_rate": signature_rate_level += 1
		"signature_quantity": signature_quantity_level += 1
		"signature_damage": signature_damage_level += 1
		"signature_area": signature_area_level += 1
	prime_signature()
	_play_signature_upgrade_feedback(upgrade_id)


func get_signature_growth_snapshot() -> Dictionary:
	return {
		"levels": {
			"rate": signature_rate_level,
			"quantity": signature_quantity_level,
			"damage": signature_damage_level,
			"area": signature_area_level,
		},
		"total_level": signature_rate_level + signature_quantity_level + signature_damage_level + signature_area_level,
		"cooldown": _signature_cooldown(),
		"damage_multiplier": _signature_damage_multiplier(),
		"area_multiplier": _signature_area_multiplier(),
		"quantity": _signature_quantity_value(),
		"quantity_label": _signature_quantity_label(),
		"quantity_overflow_multiplier": _signature_quantity_overflow_multiplier(),
	}


func get_signature_upgrade_card(upgrade_id: String) -> Dictionary:
	var current := get_signature_upgrade_level(upgrade_id)
	var next := current + 1
	var signature_name := String(kit.get("signature", {}).get("name", "职业固有攻击"))
	match upgrade_id:
		"signature_rate":
			var before_cooldown := _signature_cooldown_for_level(current)
			var after_cooldown := _signature_cooldown_for_level(next)
			return {
				"id": upgrade_id,
				"name": "%s · 执行频率  STACK %d → %d" % [signature_name, current, next],
				"title": "固有普攻：执行频率 ×%d" % next,
				"description": "攻击间隔 %.2fs → %.2fs · 执行效率伤害 ×%.2f → ×%.2f · 无限叠加" % [before_cooldown, after_cooldown, _signature_rate_overclock_for_level(current), _signature_rate_overclock_for_level(next)],
				"color": Color("55e7c2"),
			}
		"signature_quantity":
			var before_quantity := _signature_quantity_value(current)
			var after_quantity := _signature_quantity_value(next)
			var overflow_before := _signature_quantity_overflow_multiplier_for_level(current)
			var overflow_after := _signature_quantity_overflow_multiplier_for_level(next)
			return {
				"id": upgrade_id,
				"name": "%s · 并发数量  STACK %d → %d" % [signature_name, current, next],
				"title": "固有普攻：并发数量 ×%d" % next,
				"description": "%s %d → %d · 实体预算满后协同伤害 ×%.2f → ×%.2f · 无限叠加" % [_signature_quantity_label(), before_quantity, after_quantity, overflow_before, overflow_after],
				"color": Color("70caff"),
			}
		"signature_damage":
			return {
				"id": upgrade_id,
				"name": "%s · 攻击强度  STACK %d → %d" % [signature_name, current, next],
				"title": "固有普攻：攻击力 ×%d" % next,
				"description": "伤害倍率 ×%.2f → ×%.2f · 无限叠加" % [_signature_damage_multiplier_for_level(current), _signature_damage_multiplier_for_level(next)],
				"color": Color("ff8c70"),
			}
		"signature_area":
			var area_description := "射程 / 半径 / 墙长 ×%.2f → ×%.2f · 无限叠加" % [_signature_area_multiplier_for_level(current), _signature_area_multiplier_for_level(next)]
			if career_id == "security":
				area_description = "墙长 / 阻断宽度 / 灼烧圈 ×%.2f → ×%.2f · STACK 5 恢复完整范围 · 无限叠加" % [_signature_area_multiplier_for_level(current), _signature_area_multiplier_for_level(next)]
			return {
				"id": upgrade_id,
				"name": "%s · 作用范围  STACK %d → %d" % [signature_name, current, next],
				"title": "固有普攻：范围 ×%d" % next,
				"description": area_description,
				"color": Color("c68cff"),
			}
	return {"id": upgrade_id, "name": upgrade_id, "title": "固有普攻成长", "description": "无限叠加", "color": accent}


func _signature_damage_multiplier_for_level(level_value: int) -> float:
	var resolved := maxi(0, level_value)
	# The first five selections are large, readable power spikes.  Later stacks
	# retain safe linear growth without adding attacks or persistent entities.
	return 1.0 + float(mini(resolved, 5)) * 0.28 + float(maxi(0, resolved - 5)) * 0.16


func _signature_damage_multiplier() -> float:
	# Rate levels keep producing value even after the practical animation-rate
	# limit: excess scheduling capacity becomes execution efficiency.
	return _signature_damage_multiplier_for_level(signature_damage_level) * _signature_rate_overclock_for_level(signature_rate_level) * _signature_quantity_overflow_multiplier()


func _signature_rate_overclock_for_level(level_value: int) -> float:
	var resolved := maxi(0, level_value)
	return 1.0 + float(mini(resolved, 5)) * 0.04 + float(maxi(0, resolved - 5)) * 0.022


func _signature_area_multiplier_for_level(level_value: int) -> float:
	var resolved := float(maxi(0, level_value))
	# L1 is immediately visible (+21%) and L5 reaches about +66%, then the
	# asymptote protects melee identity, draw fill-rate, and world scale.
	var growth_multiplier := 1.0 + 1.45 * resolved / (resolved + 6.0)
	# Security's blocking wall was oppressive before any area investment. It
	# starts as a compact checkpoint and recovers the previous full geometry at
	# authored STACK 5; overclock growth beyond that ceiling remains unchanged.
	if career_id == "security":
		growth_multiplier *= lerpf(0.45, 1.0, clampf(resolved / 5.0, 0.0, 1.0))
	return growth_multiplier * artifact_signature_area_multiplier


func _signature_area_multiplier() -> float:
	return _signature_area_multiplier_for_level(signature_area_level)


func _signature_rate_multiplier_for_level(level_value: int) -> float:
	# Roughly -12% interval on the first card and -44% by authored stack five.
	# The 0.24 asymptote and global 0.18s floor keep the scheduler bounded.
	return 0.24 + 0.76 * pow(0.84, float(maxi(0, level_value)))


func _signature_cooldown_for_level(level_value: int) -> float:
	var value := float(kit.get("signature", {}).get("cooldown", 1.0)) * _signature_rate_multiplier_for_level(level_value)
	match ultimate_mode:
		"ops_p1": value *= 0.46
		"helpdesk_sla": value *= 0.48
		"sre_multi_active": value *= 0.72
	return maxf(0.18, value)


func _signature_quantity_cap_level() -> int:
	match career_id:
		"ops": return 4
		"dba": return 3
		"network": return 4
		"security": return 3
		"it_ops": return 3
		"helpdesk": return 7
		"opsdev": return 4
		"sre": return 4
		"delivery": return 4
		"ai_infra": return 6
	return 4


func _signature_quantity_value(level_value: int = -1) -> int:
	var resolved := signature_quantity_level if level_value < 0 else level_value
	resolved = mini(maxi(0, resolved), _signature_quantity_cap_level())
	match career_id:
		"helpdesk": return 5 + resolved * 2
		"opsdev": return 2 + resolved
		"sre": return 3 + resolved
		"ai_infra": return 2 + resolved
	return 1 + resolved


func _signature_quantity_label() -> String:
	match career_id:
		"ops": return "连击回响"
		"dba": return "同步锁域"
		"network": return "平行探针"
		"security": return "并行墙体"
		"it_ops": return "同步节点"
		"helpdesk": return "弹跳工单"
		"opsdev": return "重复执行"
		"sre": return "Trace 节点"
		"delivery": return "发布包"
		"ai_infra": return "并行 Token"
	return "并发实例"


func _signature_quantity_overflow_multiplier_for_level(level_value: int) -> float:
	return 1.0 + float(maxi(0, level_value - _signature_quantity_cap_level())) * 0.14


func _signature_quantity_overflow_multiplier() -> float:
	return _signature_quantity_overflow_multiplier_for_level(signature_quantity_level)


func debug_cast_signature() -> Dictionary:
	_cast_signature()
	return last_action_trace.duplicate(true)


func debug_advance_actions(delta: float) -> void:
	_advance_actions(delta, false)


func debug_reset_cooldowns() -> void:
	delivery_skill_charge_timers.clear()
	skill_cooldown_left = 0.0
	ultimate_cooldown_left = 0.0


func prime_signature() -> void:
	signature_timer = 0.0


func play_signature_range_preview() -> void:
	if player == null or kit.is_empty():
		return
	# Selecting an area card can ask for a preview from both the growth system
	# and the run controller. Replace the prior guide instead of stacking two
	# identical full-screen effects.
	var visual_index := visuals.size() - 1
	while visual_index >= 0:
		if String(visuals[visual_index].get("type", "")).begins_with("range_preview_"):
			visuals.remove_at(visual_index)
		visual_index -= 1
	var area_scale := _signature_area_multiplier()
	var origin := player.global_position
	var direction := facing_direction.normalized()
	if direction.length_squared() < 0.01:
		direction = Vector2.RIGHT
	var lifetime := 0.70
	match career_id:
		"ops":
			_add_range_circle(origin, 128.0 * area_scale, lifetime)
		"dba":
			_add_range_circle(origin, 350.0 * area_scale, lifetime, 0.48)
			_add_range_circle(origin + direction * 155.0 * area_scale, 78.0 * area_scale, lifetime)
		"network":
			var line_count := _signature_quantity_value()
			for line_index in range(line_count):
				var centered := float(line_index) - float(line_count - 1) * 0.5
				var start := origin + direction.orthogonal() * centered * 22.0 * area_scale
				_add_range_line(start, start + direction * 640.0 * area_scale, 17.0 * area_scale, lifetime)
		"security":
			var center := origin + direction * 118.0 * area_scale
			var half_length := 100.0 * area_scale
			_add_range_line(center - direction.orthogonal() * half_length, center + direction.orthogonal() * half_length, 22.0 * area_scale, lifetime)
		"it_ops":
			_add_range_circle(origin - direction * 38.0, 104.0 * area_scale, lifetime)
		"helpdesk":
			_add_range_circle(origin, 440.0 * area_scale, lifetime)
		"opsdev":
			_add_range_circle(origin, 500.0 * area_scale, lifetime)
		"sre":
			var reach := 560.0 * area_scale
			for branch_index in range(mini(5, _signature_quantity_value())):
				var centered := float(branch_index) - float(mini(5, _signature_quantity_value()) - 1) * 0.5
				var branch_direction := direction.rotated(centered * 0.18)
				_add_range_line(origin, origin + branch_direction * reach, 9.0 * area_scale, lifetime)
		"delivery":
			_add_range_circle(origin, 460.0 * area_scale, lifetime, 0.48)
			_add_range_circle(origin + direction * 260.0 * area_scale, 96.0 * area_scale, lifetime)
		"ai_infra":
			var token_count := mini(5, _ai_token_count())
			var reach := 680.0 * area_scale
			for token_index in range(token_count):
				var centered := float(token_index) - float(token_count - 1) * 0.5
				var start := origin + direction.orthogonal() * centered * 34.0 * area_scale - direction * 34.0
				_add_range_line(start, start + direction * reach, 16.0 * area_scale, lifetime)
	queue_redraw()


func _play_signature_upgrade_feedback(upgrade_id: String) -> void:
	if player == null:
		return
	var origin := player.global_position
	if career_id == "sre":
		var direction := facing_direction.normalized()
		if direction.length_squared() < 0.01:
			direction = Vector2.RIGHT
		var points := PackedVector2Array([origin, origin + direction.rotated(-0.24) * 92.0, origin + direction.rotated(0.18) * 168.0, origin + direction * 246.0])
		_add_visual({"type": "trace_path", "points": points, "color": accent, "ttl": 0.72, "max": 0.72, "width": 5.0})
		for point_index in range(1, points.size()):
			_add_visual({"type": "span_marker", "center": points[point_index], "color": accent.lightened(0.12), "ttl": 0.72, "max": 0.72, "size": Vector2(34.0, 18.0)})
		queue_redraw()
		return
	_add_visual({"type": "blast", "center": origin, "radius": 68.0, "color": accent, "ttl": 0.50, "max": 0.50})
	match upgrade_id:
		"signature_rate":
			for ring_index in range(4):
				_add_visual({"type": "ring", "center": origin, "radius": 48.0 + float(ring_index) * 30.0, "color": accent, "ttl": 0.42 + float(ring_index) * 0.10, "max": 0.42 + float(ring_index) * 0.10})
		"signature_quantity":
			var shown_count := mini(8, _signature_quantity_value())
			for marker_index in range(shown_count):
				var marker_angle := TAU * float(marker_index) / float(maxi(1, shown_count))
				_add_visual({"type": "marker", "center": origin + Vector2.from_angle(marker_angle) * 92.0, "radius": 16.0, "color": accent, "ttl": 0.72, "max": 0.72})
		"signature_damage":
			_add_visual({"type": "blast", "center": origin, "radius": 116.0, "color": accent.lightened(0.18), "ttl": 0.68, "max": 0.68})
			for arc_index in range(3):
				var arc_start := facing_direction.angle() + TAU * float(arc_index) / 3.0 - 0.58
				_add_visual({"type": "arc", "center": origin, "radius": 104.0, "start": arc_start, "end": arc_start + 1.16, "color": accent, "ttl": 0.62, "max": 0.62})
		"signature_area":
			play_signature_range_preview()
	queue_redraw()


func _add_range_circle(center: Vector2, radius: float, lifetime: float, alpha_scale: float = 1.0) -> void:
	_add_visual({"type": "range_preview_circle", "center": center, "radius": radius, "color": accent, "ttl": lifetime, "max": lifetime, "alpha_scale": alpha_scale})


func _add_range_line(start: Vector2, finish: Vector2, half_width: float, lifetime: float) -> void:
	_add_visual({"type": "range_preview_line", "from": start, "to": finish, "half_width": half_width, "color": accent, "ttl": lifetime, "max": lifetime})


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
	while pending_actions.size() > MAX_PENDING_ACTIONS:
		pending_actions.remove_at(0)
	_damage_projection_from_signature(String(signature["archetype"]))
	last_action_trace = trace
	action_used.emit("signature", String(signature["id"]))


func _signature_cooldown() -> float:
	return _signature_cooldown_for_level(signature_rate_level)


func _signature_ops() -> int:
	combo_step = (combo_step + 1) % 3
	var area_scale := _signature_area_multiplier()
	var direction := _aim_direction(155.0 * area_scale)
	var echo_count := _signature_quantity_value()
	var total_hits := 0
	if ultimate_mode == "ops_p1" or combo_step == 0:
		var radius := (128.0 if ultimate_mode == "ops_p1" else 112.0) * area_scale
		for echo_index in range(echo_count):
			var echo_radius := radius * (1.0 + float(echo_index) * 0.055)
			var echo_damage := _signature_damage(30.0 if combo_step == 0 else 24.0) * (1.0 if echo_index == 0 else 0.58)
			total_hits += int(swarm.call("damage_area", player.global_position, echo_radius, echo_damage))
			_add_visual({"type": "ring", "center": player.global_position, "radius": echo_radius, "color": accent, "ttl": 0.28, "max": 0.28})
		swarm.call("push_area", player.global_position, radius, 28.0)
		return total_hits
	var reach := 118.0 * area_scale
	var half_angle := 1.12
	for echo_index in range(echo_count):
		var centered := float(echo_index) - float(echo_count - 1) * 0.5
		var echo_direction := direction.rotated(centered * 0.19)
		var echo_damage := _signature_damage(23.0) * (1.0 if echo_index == 0 else 0.72)
		total_hits += int(swarm.call("damage_arc", player.global_position, echo_direction, reach, half_angle, echo_damage))
		_add_visual({"type": "arc", "center": player.global_position, "radius": reach, "start": echo_direction.angle() - half_angle, "end": echo_direction.angle() + half_angle, "color": accent, "ttl": 0.22, "max": 0.22})
	return total_hits


func _signature_dba() -> String:
	var area_scale := _signature_area_multiplier()
	var target := _target_position(350.0 * area_scale, player.global_position + facing_direction * 155.0 * area_scale)
	var zone_count := _signature_quantity_value()
	for zone_index in range(zone_count):
		var centered := float(zone_index) - float(zone_count - 1) * 0.5
		var offset := facing_direction.orthogonal() * centered * 34.0 * area_scale
		_add_zone(target + offset, "lock", 78.0 * area_scale, 5.0, 0.48, true)
	while _count_zones("lock") > 2 + zone_count:
		_remove_oldest_zone("lock")
	return "lock_zone"


func _signature_network() -> int:
	var area_scale := _signature_area_multiplier()
	var direction := _aim_direction(650.0 * area_scale)
	var line_count := _signature_quantity_value()
	var total_hits := 0
	for line_index in range(line_count):
		var centered := float(line_index) - float(line_count - 1) * 0.5
		var start := player.global_position + direction.orthogonal() * centered * 22.0 * area_scale
		var finish := start + direction * 640.0 * area_scale
		var collision_half_width := 17.0 * area_scale
		var hits: Array[Vector2] = swarm.call("damage_line", start, finish, collision_half_width, _signature_damage(22.0), 5)
		total_hits += hits.size()
		_add_visual({"type": "beam", "from": start, "to": finish, "color": accent, "ttl": 0.18, "max": 0.18, "width": 4.0, "glow_width": collision_half_width * 2.0})
	return total_hits


func _signature_security() -> String:
	var area_scale := _signature_area_multiplier()
	var direction := _aim_direction(420.0 * area_scale)
	var wall_count := _signature_quantity_value()
	for wall_index in range(wall_count):
		var centered := float(wall_index) - float(wall_count - 1) * 0.5
		var center := player.global_position + direction * (152.0 * area_scale + centered * 42.0)
		var half_length := 152.0 * area_scale
		_add_wall(center - direction.orthogonal() * half_length, center + direction.orthogonal() * half_length, 5.8, "firewall", true, 34.0 * area_scale, 1.0, Color("ff6b45"), "security_signature")
	while _count_walls("firewall") > 1 + wall_count:
		_remove_oldest_wall("firewall")
	return "firewall"


func _signature_it_ops() -> String:
	var placement := player.global_position - facing_direction * 38.0
	var node_count := _signature_quantity_value()
	var area_scale := _signature_area_multiplier()
	for node_index in range(node_count):
		var offset := Vector2.ZERO if node_count == 1 else Vector2.from_angle(TAU * float(node_index) / float(node_count)) * 34.0
		_add_node(placement + offset, 13.0, "spare", true, 104.0 * area_scale)
	while nodes.size() > 2 + node_count:
		nodes.remove_at(0)
	return "spare_node"


func _signature_helpdesk() -> int:
	var target_count := _signature_quantity_value()
	if ultimate_mode == "helpdesk_sla":
		target_count += 7
	var hits: Array[Vector2] = swarm.call("damage_nearest_targets", player.global_position, 440.0 * _signature_area_multiplier(), _signature_damage(19.0), target_count, 0.72)
	var source := player.global_position
	for hit_position in hits:
		_add_visual({"type": "beam", "from": source, "to": hit_position, "color": accent, "ttl": 0.24, "max": 0.24, "width": 3.0})
		source = hit_position
	return hits.size()


func _signature_opsdev() -> int:
	if opsdev_toolchain.is_empty():
		_record_opsdev_snippet("idempotent_script", 1.0, false)
	var area_scale := _signature_area_multiplier()
	var target: Dictionary = swarm.call("get_nearest_target", player.global_position, 500.0 * area_scale)
	if not bool(target.get("hit", false)):
		return 0
	var target_index := int(target["index"])
	var target_position := Vector2(target["position"])
	swarm.call("damage_index", target_index, _signature_damage(18.0))
	_add_visual({"type": "beam", "from": player.global_position, "to": target_position, "color": accent, "ttl": 0.16, "max": 0.16, "width": 3.0})
	pending_actions.append({"type": "script_repeat", "delay": 0.42, "position": target_position, "damage": _signature_damage(14.0), "repeat": _signature_quantity_value(), "radius": 42.0 * area_scale})
	return 1


func _signature_sre() -> int:
	return _cast_sre_trace(player.global_position, 1.0, _signature_quantity_value(), _signature_area_multiplier())


func _signature_delivery() -> String:
	var area_scale := _signature_area_multiplier()
	var target := _target_position(460.0 * area_scale, player.global_position + facing_direction * 260.0 * area_scale)
	var package_count := _signature_quantity_value()
	for package_index in range(package_count):
		var offset := Vector2.ZERO if package_count == 1 else Vector2.from_angle(TAU * float(package_index) / float(package_count)) * 42.0 * area_scale
		var package_position := target + offset
		pending_actions.append({"type": "release_package", "delay": 0.55 + float(package_index) * 0.06, "position": package_position, "damage": _signature_damage(28.0), "radius": 96.0 * area_scale})
		_add_visual({"type": "marker", "center": package_position, "radius": 96.0 * area_scale, "color": accent, "ttl": 0.55, "max": 0.55})
	return "release_package"


func _signature_ai_infra() -> int:
	var token_count := _ai_token_count()
	var area_scale := _signature_area_multiplier()
	var targets := _select_priority_targets(player.global_position, 680.0 * area_scale, token_count * 2)
	if targets.is_empty():
		return 0
	var hits := 0
	for token_index in range(token_count):
		var target_ids: Array[int] = []
		for stage_index in range(AI_PIPELINE_STAGE_DAMAGE.size()):
			target_ids.append(int(targets[(token_index + stage_index) % targets.size()]["entity_id"]))
		var stage_action := {
			"type": "ai_tensor_stage",
			"stage": 0,
			"token": token_index,
			"target_ids": target_ids,
			"source": _ai_token_origin(token_index, token_count),
			"area_scale": area_scale,
			"source_id": "ai_infra_signature",
		}
		if _resolve_ai_tensor_stage(stage_action):
			hits += 1
	return hits


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
	var dash: Dictionary = player.call("perform_dash", direction, 245.0, 1.05)
	var start := Vector2(dash["start"])
	var finish := Vector2(dash["end"])
	var side := direction.orthogonal() * 76.0
	_add_wall(start + side, finish + side, 7.0, "corridor", false, 38.0, 1.45, Color("ff4d32"), "security_q")
	_add_wall(start - side, finish - side, 7.0, "corridor", false, 38.0, 1.45, Color("ff4d32"), "security_q")
	_add_wall(finish - side, finish + side, 7.0, "corridor", false, 42.0, 1.65, Color("ff9b42"), "security_q_gate")
	swarm.call("damage_line", start, finish, 92.0, _damage(48.0) * _security_action_damage_factor(), -1, "security_q_ignition")
	swarm.call("push_area", finish, 190.0, 58.0)
	_add_visual({"type": "security_ignition", "from": start, "to": finish, "color": Color("ff6b32"), "ttl": 0.72, "max": 0.72, "width": 92.0})
	player.call("grant_invulnerability", 0.75)


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


func _skill_opsdev(direction: Vector2) -> void:
	if opsdev_toolchain.is_empty():
		_record_opsdev_snippet("idempotent_script", 1.0, false)
	opsdev_compile_serial += 1
	_schedule_opsdev_toolchain(direction, "opsdev_q_%d" % opsdev_compile_serial, false)
	var compile_center := player.global_position + direction.normalized() * 300.0
	swarm.call("damage_area", compile_center, 320.0, _damage(42.0), "opsdev_q_link")
	if swarm.has_method("amplify_damage_area"):
		swarm.call("amplify_damage_area", compile_center, 360.0, 1.22, 2.4)
	_add_visual({"type": "opsdev_compile_burst", "center": compile_center, "radius": 360.0, "color": accent, "ttl": 0.68, "max": 0.68})
	signature_timer = 0.0
	_add_visual({"type": "opsdev_compile_frame", "center": player.global_position, "direction": direction, "color": accent, "ttl": 0.92, "max": 0.92, "slots": opsdev_toolchain.size()})


func _skill_sre(direction: Vector2) -> void:
	var dash: Dictionary = player.call("perform_dash", direction, 205.0, 1.05)
	var start := Vector2(dash["start"])
	var finish := Vector2(dash["end"])
	_add_wall(start, finish, 4.2, "traffic_link", false, 14.0, 1.0)
	player.call("heal", 7.0)
	signature_timer = 0.0
	_add_visual({"type": "site_marker", "center": start, "color": Color("65e890"), "ttl": 4.2, "max": 4.2, "label": "PRIMARY"})
	_add_visual({"type": "site_marker", "center": finish, "color": Color("70caff"), "ttl": 4.2, "max": 4.2, "label": "DR"})


func _skill_delivery(direction: Vector2) -> void:
	delivery_q_cast_serial += 1
	var source_id := "delivery_q_%d" % delivery_q_cast_serial
	var area_scale := 1.20
	var silhouette_count := _delivery_skill_silhouette_count()
	var targets := _select_priority_targets(player.global_position, 560.0, silhouette_count)
	for silhouette_index in range(silhouette_count):
		var support_id := DELIVERY_SUPPORT_ORDER[delivery_support_index % DELIVERY_SUPPORT_ORDER.size()]
		delivery_support_index = (delivery_support_index + 1) % DELIVERY_SUPPORT_ORDER.size()
		delivery_support_count += 1
		var centered := float(silhouette_index) - float(silhouette_count - 1) * 0.5
		var fallback_direction := direction.rotated(centered * 0.24)
		var target := player.global_position + fallback_direction * (250.0 + absf(centered) * 34.0)
		if not targets.is_empty():
			target = Vector2(targets[silhouette_index % targets.size()]["position"])
		var silhouette_direction := (target - player.global_position).normalized()
		if silhouette_direction.length_squared() < 0.01:
			silhouette_direction = fallback_direction
		var support_origin := target - silhouette_direction * (105.0 + centered * 10.0)
		_add_career_silhouette(support_id, support_origin, 1.35, 0.92)
		_cast_borrowed_signature(support_id, support_origin, target, area_scale, 0.85, source_id)
		if delivery_support_count % 3 == 0:
			var uat_radius := 132.0 * _signature_area_multiplier()
			swarm.call("damage_area", target, uat_radius, _damage(42.0), source_id)
			_add_zone(target, "uat", uat_radius, 5.0, 0.0, false, 1.0, Color.TRANSPARENT, source_id)
			_add_visual({"type": "acceptance_stamp", "center": target, "color": Color("ffce73"), "ttl": 0.82, "max": 0.82, "size": Vector2(176.0, 82.0)})


func _skill_ai_infra(direction: Vector2) -> void:
	var area_scale := minf(2.2, _signature_area_multiplier())
	var lane_length := 760.0 * area_scale
	var lane_spacing := 72.0 * area_scale
	var output_targets := _select_priority_targets(player.global_position, 980.0 * area_scale, 3)
	for lane_index in range(3):
		var centered := float(lane_index - 1)
		var start := player.global_position + direction.orthogonal() * centered * lane_spacing - direction * 36.0
		var finish := start + direction * lane_length
		_add_visual({"type": "pipeline_lane", "from": start, "to": finish, "color": AI_PIPELINE_STAGE_COLORS[lane_index], "ttl": 0.86, "max": 0.86, "width": 26.0 * area_scale})
		for stage_index in range(AI_PIPELINE_STAGE_DAMAGE.size()):
			var flush_action := {
				"type": "ai_pipeline_flush",
				"delay": float(stage_index) * 0.12 + float(lane_index) * 0.025,
				"stage": stage_index,
				"lane": lane_index,
				"from": start,
				"to": finish,
				"half_width": 26.0 * area_scale,
				"damage": _damage(24.0),
				"source_id": "ai_infra_q",
			}
			if stage_index == 0:
				_resolve_ai_pipeline_flush(flush_action)
			else:
				pending_actions.append(flush_action)
		var target_id := -1
		if not output_targets.is_empty():
			target_id = int(output_targets[lane_index % output_targets.size()]["entity_id"])
		pending_actions.append({
			"type": "ai_pipeline_output",
			"delay": 0.58 + float(lane_index) * 0.045,
			"origin": finish,
			"direction": direction,
			"target_id": target_id,
			"damage": _damage(72.0),
			"area_scale": area_scale,
			"source_id": "ai_infra_q",
		})
	_trim_pending_actions()
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
	ultimate_left = 9.0
	ultimate_tick = 0.0
	var hex_radius := 365.0
	var points: Array[Vector2] = []
	for index in range(6):
		points.append(player.global_position + Vector2.from_angle(TAU * float(index) / 6.0) * hex_radius)
	for index in range(6):
		_add_wall(points[index], points[(index + 1) % 6], 9.0, "lockdown", false, 44.0, 1.85, Color("ff3158"), "security_r_hex")
	swarm.call("damage_area", player.global_position, 520.0, _damage(86.0) * _security_action_damage_factor(), "security_r_boot")
	swarm.call("push_area", player.global_position, 520.0, 92.0)
	_add_visual({"type": "security_lockdown_boot", "center": player.global_position, "radius": 520.0, "color": Color("ff3158"), "ttl": 0.88, "max": 0.88})


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
	if opsdev_toolchain.is_empty():
		_record_opsdev_snippet("idempotent_script", 1.0, false)
	ultimate_mode = "opsdev_hot_reload"
	ultimate_left = OPSDEV_HOT_RELOAD_DURATION
	ultimate_tick = _opsdev_combo_duration() + 0.12
	opsdev_hot_reload_epoch = 0
	opsdev_hot_reload_seen.clear()
	_schedule_opsdev_combo_sequence("opsdev_r_boot", false)
	_add_visual({"type": "opsdev_hot_reload", "center": player.global_position, "color": accent, "ttl": 1.16, "max": 1.16})
	_add_visual({"type": "opsdev_world_compile", "center": player.global_position, "radius": 540.0, "color": accent, "ttl": 1.0, "max": 1.0})


func _ultimate_sre() -> void:
	ultimate_mode = "sre_multi_active"
	ultimate_left = 10.0
	ultimate_tick = 0.0
	sre_failover_used = false
	sre_replicas.clear()
	var fallback_side := facing_direction.orthogonal()
	if fallback_side.length_squared() < 0.01:
		fallback_side = Vector2.UP
	var local_position := _sre_history_position(2.2, player.global_position + fallback_side * 185.0)
	var remote_position := _sre_history_position(5.0, player.global_position - fallback_side * 235.0)
	sre_replicas.append({"position": local_position, "label": "AZ-B", "color": Color("70caff")})
	sre_replicas.append({"position": remote_position, "label": "AZ-C", "color": Color("65e890")})
	if player.has_method("set_temporary_damage_reduction"):
		player.call("set_temporary_damage_reduction", 0.30)
	_add_visual({"type": "failover_line", "from": local_position, "to": player.global_position, "color": Color("70caff"), "ttl": 0.75, "max": 0.75, "width": 5.0})
	_add_visual({"type": "failover_line", "from": remote_position, "to": player.global_position, "color": Color("65e890"), "ttl": 0.75, "max": 0.75, "width": 5.0})
	signature_timer = 0.0


func _ultimate_delivery() -> void:
	ultimate_mode = "delivery_all_hands"
	ultimate_left = 3.1
	var formation := _delivery_formation_positions(player.global_position)
	for support_index in range(DELIVERY_SUPPORT_ORDER.size()):
		_add_career_silhouette(DELIVERY_SUPPORT_ORDER[support_index], formation[support_index], 3.1, 0.96)
	for wave_index in range(3):
		pending_actions.append({"type": "delivery_all_hands_wave", "delay": 0.20 + float(wave_index) * 0.72, "wave": wave_index, "center": player.global_position, "formation": formation})


func _ultimate_ai_infra() -> void:
	ultimate_mode = "ai_foundation_model"
	ultimate_left = AI_MODEL_DURATION
	ultimate_tick = 0.0
	ai_model_decode_count = 0
	ai_model_eos_fired = false
	_add_visual({"type": "attention_matrix", "rect": AI_WORLD_RECT, "color": accent, "ttl": AI_MODEL_DURATION, "max": AI_MODEL_DURATION})
	for scan_index in range(6):
		var scan_y := AI_WORLD_RECT.position.y + (float(scan_index) + 0.5) * AI_WORLD_RECT.size.y / 6.0
		pending_actions.append({
			"type": "ai_prefill_scan",
			"delay": 0.10 + float(scan_index) * 0.24,
			"from": Vector2(AI_WORLD_RECT.position.x, scan_y),
			"to": Vector2(AI_WORLD_RECT.end.x, scan_y),
			"half_width": AI_WORLD_RECT.size.y / 12.0 + 4.0,
			"damage": _damage(45.0),
			"source_id": "ai_infra_r",
		})
	_trim_pending_actions()
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
		var start := Vector2(wall["start"])
		var finish := Vector2(wall["end"])
		var line_width := float(wall.get("width", 22.0))
		var kind := String(wall.get("kind", "firewall"))
		if kind != "traffic_link" and swarm.has_method("block_line"):
			swarm.call("block_line", start, finish, line_width * 0.62, player.global_position)
		if float(wall["tick"]) <= 0.0:
			var base_damage := 18.0
			match kind:
				"firewall": base_damage = 16.0
				"corridor": base_damage = 24.0
				"lockdown": base_damage = 29.0
			var wall_damage := (_signature_damage(base_damage) * _security_signature_damage_factor() if bool(wall.get("signature", false)) else _damage(base_damage) * _security_action_damage_factor()) * float(wall.get("effect_scale", 1.0))
			swarm.call("damage_line", start, finish, line_width, wall_damage, -1, String(wall.get("source_id", "")))
			var sample_count := 7 if kind != "traffic_link" else 5
			for sample_index in range(sample_count):
				var sample := start.lerp(finish, float(sample_index) / float(sample_count - 1))
				var is_compact_signature_wall := kind == "firewall" and bool(wall.get("signature", false))
				var effect_radius := maxf(12.0 if is_compact_signature_wall else 34.0, line_width * 1.55)
				swarm.call("slow_area", sample, effect_radius, 0.42 if kind == "traffic_link" else 0.72)
				if kind != "traffic_link":
					swarm.call("push_area", sample, effect_radius, 16.0 if kind == "firewall" else 24.0)
					_add_visual({"type": "security_flame", "center": sample, "radius": effect_radius, "color": Color(wall.get("color", Color("ff6b45"))), "ttl": 0.34, "max": 0.34})
					var frost_level := int(wall.get("frost_level", 0))
					if frost_level > 0:
						swarm.call("slow_area", sample, effect_radius * 1.18, 0.78 + float(frost_level) * 0.24)
						if swarm.has_method("root_area"):
							swarm.call("root_area", sample, effect_radius, 0.10 + float(frost_level) * 0.07)
						_add_visual({"type": "security_frost", "center": sample, "radius": effect_radius * 1.10, "color": Color("70d8ff"), "ttl": 0.42, "max": 0.42})
					var storm_level := int(wall.get("storm_level", 0))
					if storm_level > 0 and sample_index == sample_count / 2:
						var lightning_hits: Array[Vector2] = swarm.call("damage_nearest_targets", sample, 180.0 + float(storm_level) * 35.0, _damage(_security_storm_damage(storm_level)) * float(wall.get("effect_scale", 1.0)), 1 + storm_level, 0.72, String(wall.get("source_id", "security_storm")))
						var lightning_from := sample
						for lightning_hit in lightning_hits:
							_add_visual({"type": "security_lightning", "from": lightning_from, "to": lightning_hit, "color": Color("e8ff72"), "ttl": 0.22, "max": 0.22, "width": 4.0})
							lightning_from = lightning_hit
			wall["tick"] = 0.34 if kind == "traffic_link" else (0.20 if kind == "lockdown" else 0.24)
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
				var zone_damage := (_signature_damage(9.0) if bool(zone.get("signature", false)) else _damage(9.0)) * float(zone.get("effect_scale", 1.0))
				swarm.call("damage_area", position_value, radius, zone_damage, String(zone.get("source_id", "")))
				swarm.call("slow_area", position_value, radius, 0.75)
			elif kind == "heal" and player.global_position.distance_to(position_value) <= radius:
				player.call("heal", 1.1)
			elif kind == "uat":
				if swarm.has_method("amplify_damage_area"):
					swarm.call("amplify_damage_area", position_value, radius, 1.15, 0.76)
				swarm.call("damage_area", position_value, radius, _damage(4.0) * float(zone.get("effect_scale", 1.0)), String(zone.get("source_id", "")))
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
			var radius := float(node.get("radius", 128.0 if String(node["kind"]) == "rack" else 104.0))
			var base_damage := 18.0 if String(node["kind"]) == "rack" else 12.0
			var node_damage := (_signature_damage(base_damage) if bool(node.get("signature", false)) else _damage(base_damage)) * float(node.get("effect_scale", 1.0))
			swarm.call("damage_area", position_value, radius, node_damage, String(node.get("source_id", "")))
			_add_visual({"type": "ring", "center": position_value, "radius": radius, "color": accent, "ttl": 0.26, "max": 0.26})
			if player.global_position.distance_to(position_value) <= 76.0:
				player.call("heal", 0.7)
			node["tick"] = 1.0
		nodes[index] = node
		if float(node["ttl"]) <= 0.0:
			nodes.remove_at(index)
		index -= 1


func _on_combat_attack_fired(weapon_id: String, world_position: Vector2, intensity: float) -> void:
	if career_id != "opsdev" or not OPSDEV_TOOL_NAMES.has(weapon_id):
		return
	_record_opsdev_snippet(weapon_id, intensity, true)
	if ultimate_mode != "opsdev_hot_reload" or opsdev_hot_reload_seen.has(weapon_id):
		return
	opsdev_hot_reload_seen[weapon_id] = true
	pending_actions.append({
		"type": "opsdev_compiled_stage",
		"delay": 0.10,
		"weapon_id": weapon_id,
		"origin": world_position,
		"direction": _aim_direction(820.0),
		"modifier": _opsdev_hot_modifier(weapon_id),
		"damage_scale": 1.32 + minf(0.32, intensity * 0.06),
		"revision": _opsdev_snippet_revision(weapon_id),
		"source_id": "opsdev_r_hook",
	})
	_trim_pending_actions()


func _record_opsdev_snippet(weapon_id: String, intensity: float, rewrite_existing: bool) -> void:
	if not OPSDEV_TOOL_NAMES.has(weapon_id):
		return
	var existing_index := -1
	for index in range(opsdev_toolchain.size()):
		if String(opsdev_toolchain[index].get("id", "")) == weapon_id:
			existing_index = index
			break
	if existing_index >= 0 and not rewrite_existing:
		return
	var revision := 1
	if existing_index >= 0:
		revision = mini(5, int(opsdev_toolchain[existing_index].get("revision", 1)) + 1)
		opsdev_toolchain.remove_at(existing_index)
	opsdev_toolchain.append({
		"id": weapon_id,
		"name": String(OPSDEV_TOOL_NAMES[weapon_id]),
		"color": Color(OPSDEV_TOOL_COLORS[weapon_id]),
		"revision": revision,
		"intensity": maxf(1.0, intensity),
	})
	while opsdev_toolchain.size() > _opsdev_toolchain_cap():
		opsdev_toolchain.pop_front()
	_add_visual({"type": "opsdev_capture", "center": player.global_position + Vector2(0.0, -72.0), "color": Color(OPSDEV_TOOL_COLORS[weapon_id]), "ttl": 0.34, "max": 0.34, "slot": opsdev_toolchain.size() - 1})


func _opsdev_snippet_revision(weapon_id: String) -> int:
	for snippet in opsdev_toolchain:
		if String(snippet.get("id", "")) == weapon_id:
			return int(snippet.get("revision", 1))
	return 1


func _opsdev_toolchain_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(opsdev_toolchain.size()):
		var snippet := Dictionary(opsdev_toolchain[index]).duplicate(true)
		snippet["modifier"] = _opsdev_stage_label(index)
		result.append(snippet)
	return result


func _opsdev_pipeline_label() -> String:
	if opsdev_toolchain.is_empty():
		return "等待首个脚本"
	var labels: Array[String] = []
	for index in range(opsdev_toolchain.size()):
		var snippet: Dictionary = opsdev_toolchain[index]
		labels.append("%s[%s]" % [String(snippet.get("name", "JOB")), _opsdev_stage_label(index)])
	return " > ".join(labels)


func _opsdev_toolchain_cap() -> int:
	return mini(OPSDEV_TOOLCHAIN_MAX_CAP, OPSDEV_TOOLCHAIN_BASE_CAP + opsdev_pipeline_capacity_level)


func _opsdev_stage_label(index: int) -> String:
	return OPSDEV_STAGE_MODIFIERS[index % OPSDEV_STAGE_MODIFIERS.size()]


func _opsdev_stage_modifier(index: int) -> String:
	match _opsdev_stage_label(index):
		"FORK", "FANOUT": return "fork"
		"LOOP", "CACHE": return "loop"
		"OPT", "VECTOR": return "optimize"
		"JIT": return "merge"
	return "optimize"


func _schedule_opsdev_toolchain(direction: Vector2, source_id: String, hot_reload: bool) -> void:
	for index in range(opsdev_toolchain.size()):
		var snippet: Dictionary = opsdev_toolchain[index]
		var modifier := _opsdev_hot_modifier(String(snippet["id"])) if hot_reload else _opsdev_stage_modifier(index)
		var centered := float(index) - float(opsdev_toolchain.size() - 1) * 0.5
		pending_actions.append({
			"type": "opsdev_compiled_stage",
			"delay": 0.03 + float(index) * (0.075 if hot_reload else 0.13),
			"weapon_id": String(snippet["id"]),
			"origin": player.global_position,
			"direction": direction.normalized().rotated(centered * (0.22 if hot_reload else 0.16)),
			"modifier": modifier,
			"damage_scale": (1.28 if hot_reload else 1.36) * (1.0 + float(int(snippet.get("revision", 1)) - 1) * 0.12),
			"revision": int(snippet.get("revision", 1)),
			"source_id": source_id,
		})
	_trim_pending_actions()


func _opsdev_combo_duration() -> float:
	return 0.28 + float(maxi(1, opsdev_toolchain.size())) * 0.14


func _schedule_opsdev_combo_sequence(source_id: String, final_combo: bool) -> void:
	var slot_count := maxi(1, opsdev_toolchain.size())
	var combo_origin := player.global_position
	var previous_position := combo_origin
	for index in range(opsdev_toolchain.size()):
		var snippet: Dictionary = opsdev_toolchain[index]
		var centered := float(index) - float(slot_count - 1) * 0.5
		var tool_position := combo_origin + Vector2(centered * 72.0, -132.0 + absf(centered) * 10.0)
		var release_angle := lerpf(-PI * 0.82, PI * 0.82, float(index) / float(maxi(1, slot_count - 1)))
		var delay := 0.05 + float(index) * 0.14
		pending_actions.append({
			"type": "opsdev_combo_tool",
			"delay": delay,
			"weapon_id": String(snippet["id"]),
			"modifier": "merge" if final_combo else _opsdev_stage_modifier(index),
			"origin": combo_origin,
			"tool_position": tool_position,
			"previous_position": previous_position,
			"direction": Vector2.from_angle(release_angle),
			"damage_scale": (2.10 if final_combo else 1.02) * (1.0 + float(int(snippet.get("revision", 1)) - 1) * 0.12),
			"hold": _opsdev_combo_duration() - delay + 0.62,
			"index": index,
			"slots": slot_count,
			"final_combo": final_combo,
			"source_id": source_id,
		})
		previous_position = tool_position
	pending_actions.append({
		"type": "opsdev_combo_commit",
		"delay": _opsdev_combo_duration(),
		"center": combo_origin,
		"slots": slot_count,
		"final_combo": final_combo,
		"source_id": source_id,
	})
	_trim_pending_actions()


func _opsdev_hot_modifier(weapon_id: String) -> String:
	if weapon_id in ["bash", "worker", "idempotent_script"]:
		return "fork"
	if weapon_id in ["ping", "firewall", "log", "lock_zone"]:
		return "loop"
	return "optimize"


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
			var radius := float(pending.get("radius", 42.0))
			var source_id := String(pending.get("source_id", ""))
			swarm.call("damage_area", position_value, radius, float(pending["damage"]), source_id)
			_add_visual({"type": "blast", "center": position_value, "radius": radius, "color": Color(pending.get("color", accent)), "ttl": 0.26, "max": 0.26})
			var repeat := int(pending.get("repeat", 1))
			if repeat > 1:
				pending_actions.append({"type": "script_repeat", "delay": 0.34, "position": position_value, "damage": float(pending["damage"]) * 0.9, "repeat": repeat - 1, "radius": radius, "color": Color(pending.get("color", accent)), "source_id": source_id})
		"release_package":
			var position_value := Vector2(pending["position"])
			var radius := float(pending["radius"])
			var source_id := String(pending.get("source_id", ""))
			swarm.call("damage_area", position_value, radius, float(pending["damage"]), source_id)
			_add_visual({"type": "blast", "center": position_value, "radius": radius, "color": accent, "ttl": 0.48, "max": 0.48})
			_add_zone(position_value, "uat", radius * 0.82, 4.0, 0.0, false, 1.0, Color.TRANSPARENT, source_id)
		"opsdev_compiled_stage":
			_resolve_opsdev_compiled_stage(pending)
		"opsdev_combo_tool":
			_resolve_opsdev_combo_tool(pending)
		"opsdev_combo_commit":
			_resolve_opsdev_combo_commit(pending)
		"release_wave":
			var stage := int(pending["stage"])
			var radius := 220.0 + float(stage) * 150.0
			swarm.call("damage_area", player.global_position, radius, _damage(30.0 + float(stage) * 17.0))
			swarm.call("push_area", player.global_position, radius, 24.0 + float(stage) * 14.0)
			_add_visual({"type": "ring", "center": player.global_position, "radius": radius, "color": accent, "ttl": 0.60, "max": 0.60})
		"sre_trace_return":
			_resolve_sre_trace_return(pending)
		"sre_trace_hit":
			_resolve_sre_trace_hit(pending)
		"delivery_all_hands_wave":
			_resolve_delivery_all_hands_wave(pending)
		"ai_tensor_stage":
			_resolve_ai_tensor_stage(pending)
		"ai_pipeline_flush":
			_resolve_ai_pipeline_flush(pending)
		"ai_pipeline_output":
			_resolve_ai_pipeline_output(pending)
		"ai_prefill_scan":
			_resolve_ai_prefill_scan(pending)


func _resolve_opsdev_compiled_stage(pending: Dictionary) -> void:
	var weapon_id := String(pending.get("weapon_id", "idempotent_script"))
	var modifier := String(pending.get("modifier", "optimize"))
	var origin := Vector2(pending.get("origin", player.global_position))
	var direction := Vector2(pending.get("direction", facing_direction)).normalized()
	var damage_scale := float(pending.get("damage_scale", 0.78))
	var source_id := String(pending.get("source_id", "opsdev_compile"))
	var result: Dictionary = {}
	if weapon_id == "idempotent_script":
		result = _execute_compiled_idempotent(origin, direction, modifier, damage_scale, source_id)
	elif combat != null and combat.has_method("execute_compiled_weapon"):
		result = combat.call("execute_compiled_weapon", weapon_id, origin, direction, modifier, damage_scale, source_id)
	var result_position := Vector2(result.get("position", origin + direction * 220.0))
	var stage_color := Color(OPSDEV_TOOL_COLORS.get(weapon_id, accent))
	_add_visual({"type": "opsdev_bytecode", "from": origin, "to": result_position, "color": stage_color, "ttl": 0.38, "max": 0.38, "modifier": modifier})
	_add_visual({"type": "opsdev_stage", "center": result_position, "color": stage_color, "ttl": 0.46, "max": 0.46, "modifier": modifier})
	if modifier == "loop" and not bool(pending.get("looped", false)):
		var echo := pending.duplicate(true)
		echo["delay"] = 0.30
		echo["modifier"] = "loop_echo"
		echo["damage_scale"] = damage_scale * 0.82
		echo["looped"] = true
		pending_actions.append(echo)
	_trim_pending_actions()


func _resolve_opsdev_combo_tool(pending: Dictionary) -> void:
	var weapon_id := String(pending.get("weapon_id", "idempotent_script"))
	var tool_position := Vector2(pending.get("tool_position", player.global_position))
	var previous_position := Vector2(pending.get("previous_position", player.global_position))
	var tool_color := Color(OPSDEV_TOOL_COLORS.get(weapon_id, accent))
	_add_visual({
		"type": "opsdev_combo_tool",
		"center": tool_position,
		"from": previous_position,
		"weapon_id": weapon_id,
		"label": String(OPSDEV_TOOL_NAMES.get(weapon_id, "JOB")),
		"index": int(pending.get("index", 0)),
		"slots": int(pending.get("slots", 1)),
		"final_combo": bool(pending.get("final_combo", false)),
		"color": tool_color,
		"ttl": float(pending.get("hold", 0.72)),
		"max": float(pending.get("hold", 0.72)),
	})
	_resolve_opsdev_compiled_stage({
		"type": "opsdev_compiled_stage",
		"weapon_id": weapon_id,
		"modifier": String(pending.get("modifier", "optimize")),
		"origin": Vector2(pending.get("origin", player.global_position)),
		"direction": Vector2(pending.get("direction", facing_direction)),
		"damage_scale": float(pending.get("damage_scale", 1.0)),
		"source_id": String(pending.get("source_id", "opsdev_combo")),
	})


func _resolve_opsdev_combo_commit(pending: Dictionary) -> void:
	var center := Vector2(pending.get("center", player.global_position))
	var final_combo := bool(pending.get("final_combo", false))
	var radius := 650.0 if final_combo else 520.0
	var damage := _damage(95.0 if final_combo else 58.0)
	swarm.call("damage_area", center, radius, damage, String(pending.get("source_id", "opsdev_combo")))
	swarm.call("push_area", center, radius, 76.0 if final_combo else 48.0)
	_add_visual({"type": "opsdev_combo_commit", "center": center, "radius": radius, "slots": int(pending.get("slots", 1)), "final_combo": final_combo, "color": Color("f1ffd8") if final_combo else accent, "ttl": 1.05, "max": 1.05})
	if final_combo:
		_add_visual({"type": "opsdev_merge", "center": center, "color": Color("eaffd1"), "ttl": 1.12, "max": 1.12, "slots": int(pending.get("slots", 1))})


func _execute_compiled_idempotent(origin: Vector2, direction: Vector2, modifier: String, damage_scale: float, source_id: String) -> Dictionary:
	var forked := modifier in ["fork", "merge"]
	var optimized := modifier in ["optimize", "merge"]
	var target_count := 3 if forked else 1
	var targets := _select_priority_targets(origin, 680.0 * _signature_area_multiplier(), target_count)
	var fallback_position := origin + direction * 240.0
	if targets.is_empty():
		swarm.call("damage_area", fallback_position, 64.0, _signature_damage(16.0) * damage_scale, source_id)
		return {"executed": true, "hits": 0, "position": fallback_position}
	var repeat_count := 3 if modifier == "merge" else (2 if optimized else 1)
	var radius := (68.0 if optimized else 48.0) * _signature_area_multiplier()
	for target in targets:
		var entity_id := int(target["entity_id"])
		var target_position := Vector2(target["position"])
		_damage_entity_id(entity_id, _signature_damage(16.0) * damage_scale * (1.35 if optimized else 1.0), source_id)
		pending_actions.append({
			"type": "script_repeat",
			"delay": 0.18,
			"position": target_position,
			"damage": _signature_damage(14.0) * damage_scale,
			"repeat": repeat_count,
			"radius": radius,
			"color": Color(OPSDEV_TOOL_COLORS["idempotent_script"]),
			"source_id": source_id,
		})
	return {"executed": true, "hits": targets.size(), "position": Vector2(targets[0]["position"])}


func _update_ultimate(delta: float) -> void:
	if ultimate_left <= 0.0:
		if not ultimate_mode.is_empty():
			_finish_ultimate_mode(ultimate_mode)
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
				swarm.call("damage_area", player.global_position, 440.0, _damage(28.0) * _security_action_damage_factor(), "security_r_pulse")
				swarm.call("slow_area", player.global_position, 460.0, 1.1)
				if security_cryo_acl_level > 0 and swarm.has_method("root_area"):
					swarm.call("root_area", player.global_position, 430.0, 0.16 + float(security_cryo_acl_level) * 0.08)
				swarm.call("push_area", player.global_position, 460.0, 28.0)
				_add_visual({"type": "ring", "center": player.global_position, "radius": 440.0, "color": Color("ff3158"), "ttl": 0.38, "max": 0.38})
				ultimate_tick = 0.34
		"opsdev_hot_reload":
			if ultimate_tick <= 0.0:
				opsdev_hot_reload_epoch += 1
				opsdev_hot_reload_seen.clear()
				var epoch_direction := facing_direction.rotated(float(opsdev_hot_reload_epoch % 8) * TAU / 8.0)
				_schedule_opsdev_toolchain(epoch_direction, "opsdev_r_epoch_%d" % opsdev_hot_reload_epoch, true)
				swarm.call("damage_area", player.global_position, 610.0, _damage(24.0), "opsdev_r_epoch")
				if swarm.has_method("amplify_damage_area"):
					swarm.call("amplify_damage_area", player.global_position, 630.0, 1.16, OPSDEV_HOT_RELOAD_EPOCH + 0.18)
				_add_visual({"type": "opsdev_epoch", "center": player.global_position, "color": accent, "ttl": 0.52, "max": 0.52, "epoch": opsdev_hot_reload_epoch})
				ultimate_tick = OPSDEV_HOT_RELOAD_EPOCH
		"sre_multi_active":
			if not sre_failover_used and player.health / maxf(1.0, player.max_health) <= 0.20:
				_perform_sre_failover()
			if ultimate_tick <= 0.0:
				for replica in sre_replicas:
					_cast_sre_trace(Vector2(replica["position"]), 0.58, 3, _signature_area_multiplier())
				ultimate_tick = 0.82
		"ai_foundation_model":
			if not ai_model_eos_fired and ultimate_left <= 0.78:
				_fire_ai_eos()
				ai_model_eos_fired = true
				ultimate_tick = 99.0
			elif ultimate_left <= AI_MODEL_DURATION - 1.85 and ultimate_tick <= 0.0:
				_fire_ai_decode_volley()
				var decode_progress := clampf((AI_MODEL_DURATION - 1.85 - ultimate_left) / 5.75, 0.0, 1.0)
				ultimate_tick = lerpf(0.45, 0.12, decode_progress)
	if ultimate_left <= 0.0:
		_finish_ultimate_mode(ultimate_mode)


func _record_position_history(delta: float) -> void:
	history_tick -= delta
	if history_tick > 0.0:
		return
	history_tick = 0.10
	position_history.append(player.global_position)
	while position_history.size() > 11:
		position_history.remove_at(0)
	sre_position_history.append(player.global_position)
	while sre_position_history.size() > 64:
		sre_position_history.remove_at(0)


func _add_wall(start: Vector2, finish: Vector2, duration: float, kind: String, signature_source: bool = false, line_width: float = 22.0, effect_scale: float = 1.0, effect_color: Color = Color.TRANSPARENT, source_id: String = "") -> void:
	var resolved_color := accent if effect_color.a <= 0.0 else effect_color
	var is_security_wall := career_id == "security" and kind != "traffic_link"
	walls.append({"start": start, "end": finish, "ttl": duration, "tick": 0.0, "kind": kind, "signature": signature_source, "width": line_width, "effect_scale": effect_scale, "color": resolved_color, "source_id": source_id, "frost_level": security_cryo_acl_level if is_security_wall else 0, "storm_level": security_storm_ids_level if is_security_wall else 0})
	while walls.size() > MAX_WALLS:
		walls.remove_at(0)


func _count_walls(kind: String) -> int:
	var result := 0
	for wall in walls:
		if String(wall.get("kind", "")) == kind:
			result += 1
	return result


func _remove_oldest_wall(kind: String) -> void:
	for wall_index in range(walls.size()):
		if String(walls[wall_index].get("kind", "")) == kind:
			walls.remove_at(wall_index)
			return


func _add_zone(position_value: Vector2, kind: String, radius: float, duration: float, arm_time: float, signature_source: bool = false, effect_scale: float = 1.0, effect_color: Color = Color.TRANSPARENT, source_id: String = "") -> void:
	var resolved_color := accent if effect_color.a <= 0.0 else effect_color
	zones.append({"position": position_value, "kind": kind, "radius": radius, "ttl": duration, "arm": arm_time, "tick": 0.0, "signature": signature_source, "effect_scale": effect_scale, "color": resolved_color, "source_id": source_id})
	while zones.size() > MAX_ZONES:
		zones.remove_at(0)


func _add_node(position_value: Vector2, duration: float, kind: String, signature_source: bool = false, effect_radius: float = 0.0, effect_scale: float = 1.0, effect_color: Color = Color.TRANSPARENT, source_id: String = "") -> void:
	var default_radius := 128.0 if kind == "rack" else 104.0
	var resolved_color := accent if effect_color.a <= 0.0 else effect_color
	nodes.append({"position": position_value, "kind": kind, "ttl": duration, "tick": 0.0, "signature": signature_source, "radius": default_radius if effect_radius <= 0.0 else effect_radius, "effect_scale": effect_scale, "color": resolved_color, "source_id": source_id})
	while nodes.size() > MAX_NODES:
		nodes.remove_at(0)


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


func _career_short_name(resolved_career_id: String) -> String:
	match resolved_career_id:
		"ops": return "运维"
		"dba": return "DBA"
		"network": return "网络"
		"security": return "安全"
		"it_ops": return "IT 运维"
		"helpdesk": return "Helpdesk"
		"opsdev": return "运维开发"
		"sre": return "SRE"
		"delivery": return "实施交付"
		"ai_infra": return "AI Infra"
	return resolved_career_id


func _career_color(resolved_career_id: String) -> Color:
	return Color(CAREER_COLORS.get(resolved_career_id, accent))


func _add_career_silhouette(resolved_career_id: String, world_position: Vector2, duration: float, alpha_scale: float = 0.92) -> void:
	_add_visual({
		"type": "career_silhouette",
		"career_id": resolved_career_id,
		"center": world_position,
		"color": _career_color(resolved_career_id),
		"ttl": duration,
		"max": duration,
		"alpha_scale": alpha_scale,
	})


func _delivery_formation_positions(center: Vector2) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for index in range(DELIVERY_SUPPORT_ORDER.size()):
		var angle := -PI * 0.92 + PI * 1.84 * float(index) / float(maxi(1, DELIVERY_SUPPORT_ORDER.size() - 1))
		var radius := 225.0 + float(index % 2) * 42.0
		result.append(center + Vector2.from_angle(angle) * radius)
	return result


func _resolve_delivery_all_hands_wave(pending: Dictionary) -> void:
	var wave := int(pending.get("wave", 0))
	var center := Vector2(pending.get("center", player.global_position))
	var formation: Array = pending.get("formation", _delivery_formation_positions(center))
	var targets := _select_priority_targets(center, 980.0, 12)
	for support_index in range(DELIVERY_SUPPORT_ORDER.size()):
		var support_id := DELIVERY_SUPPORT_ORDER[support_index]
		var origin := Vector2(formation[support_index])
		var fallback_angle := TAU * float(support_index + wave * 3) / float(DELIVERY_SUPPORT_ORDER.size())
		var target := center + Vector2.from_angle(fallback_angle) * (240.0 + float(wave) * 70.0)
		if not targets.is_empty():
			target = Vector2(targets[(support_index + wave * 3) % targets.size()]["position"])
		_cast_borrowed_signature(support_id, origin, target, 1.50, 0.75, "delivery_r")
	var delivery_target := center + facing_direction * (190.0 + float(wave) * 65.0)
	if not targets.is_empty():
		delivery_target = Vector2(targets[(wave * 4 + 2) % targets.size()]["position"])
	_cast_borrowed_signature("delivery", center, delivery_target, 1.50, 0.75, "delivery_r")
	_add_visual({"type": "wave_banner", "center": center + Vector2(0.0, -138.0), "color": Color("ffce73"), "ttl": 0.58, "max": 0.58, "wave": wave + 1})
	if wave == 2:
		var final_target := delivery_target
		swarm.call("damage_area", final_target, 265.0, _damage(72.0))
		swarm.call("push_area", final_target, 285.0, 42.0)
		_add_zone(final_target, "uat", 210.0, 5.0, 0.0, false, 1.0, Color("ffce73"))
		_add_visual({"type": "acceptance_stamp", "center": final_target, "color": Color("ffce73"), "ttl": 1.05, "max": 1.05, "size": Vector2(390.0, 150.0)})


func _resolve_ai_tensor_stage(pending: Dictionary) -> bool:
	var stage := clampi(int(pending.get("stage", 0)), 0, AI_PIPELINE_STAGE_DAMAGE.size() - 1)
	var target_ids: Array = pending.get("target_ids", [])
	var target_id := -1
	if not target_ids.is_empty():
		target_id = int(target_ids[stage % target_ids.size()])
	var target_index := _find_entity_index_by_id(target_id)
	if target_index < 0:
		var reroute := _select_priority_targets(player.global_position, 720.0 * float(pending.get("area_scale", 1.0)), 1)
		if reroute.is_empty():
			return false
		target_id = int(reroute[0]["entity_id"])
		target_index = _find_entity_index_by_id(target_id)
	if target_index < 0:
		return false
	var source := Vector2(pending.get("source", player.global_position))
	var hit_position := Vector2(swarm.get("positions")[target_index])
	var stage_color := AI_PIPELINE_STAGE_COLORS[stage]
	_damage_entity_id(target_id, _signature_damage(AI_PIPELINE_STAGE_DAMAGE[stage]), String(pending.get("source_id", "ai_infra_signature")))
	_add_visual({"type": "tensor_beam", "from": source, "to": hit_position, "color": stage_color, "ttl": 0.24, "max": 0.24, "width": 3.0 + float(stage) * 1.4, "stage": stage})
	_add_visual({"type": "tensor_node", "center": hit_position, "color": stage_color, "ttl": 0.30, "max": 0.30, "stage": stage})
	var killed := _find_entity_index_by_id(target_id) < 0
	if stage == AI_PIPELINE_STAGE_DAMAGE.size() - 1 and killed:
		var residual_hits: Array[Vector2] = swarm.call("damage_nearest_targets", hit_position, 440.0 * float(pending.get("area_scale", 1.0)), _signature_damage(10.0), 3, 0.86, String(pending.get("source_id", "ai_infra_signature")))
		for residual_position in residual_hits:
			_add_visual({"type": "tensor_beam", "from": hit_position, "to": residual_position, "color": Color("d5ff74"), "ttl": 0.20, "max": 0.20, "width": 3.0, "stage": 4})
	if stage < AI_PIPELINE_STAGE_DAMAGE.size() - 1:
		pending_actions.append({
			"type": "ai_tensor_stage",
			"delay": 0.075 + float(stage) * 0.015,
			"stage": stage + 1,
			"token": int(pending.get("token", 0)),
			"target_ids": target_ids,
			"source": hit_position,
			"area_scale": float(pending.get("area_scale", 1.0)),
			"source_id": String(pending.get("source_id", "ai_infra_signature")),
		})
		_trim_pending_actions()
	return true


func _resolve_ai_pipeline_flush(pending: Dictionary) -> void:
	var stage := clampi(int(pending.get("stage", 0)), 0, AI_PIPELINE_STAGE_DAMAGE.size() - 1)
	var start := Vector2(pending.get("from", player.global_position))
	var finish := Vector2(pending.get("to", player.global_position + facing_direction * 760.0))
	var half_width := float(pending.get("half_width", 26.0))
	var stage_color := AI_PIPELINE_STAGE_COLORS[stage]
	swarm.call("damage_line", start, finish, half_width, float(pending.get("damage", _damage(24.0))), -1, String(pending.get("source_id", "ai_infra_q")))
	_add_visual({"type": "tensor_beam", "from": start, "to": finish, "color": stage_color, "ttl": 0.28, "max": 0.28, "width": 5.0 + float(stage), "glow_width": half_width * 2.0, "stage": stage})


func _resolve_ai_pipeline_output(pending: Dictionary) -> void:
	var origin := Vector2(pending.get("origin", player.global_position))
	var direction := Vector2(pending.get("direction", facing_direction)).normalized()
	var target_id := int(pending.get("target_id", -1))
	var target_index := _find_entity_index_by_id(target_id)
	if target_index < 0:
		var reroute := _select_priority_targets(player.global_position, 1020.0 * float(pending.get("area_scale", 1.0)), 1)
		if not reroute.is_empty():
			target_id = int(reroute[0]["entity_id"])
			target_index = _find_entity_index_by_id(target_id)
	if target_index >= 0:
		var hit_position := Vector2(swarm.get("positions")[target_index])
		_damage_entity_id(target_id, float(pending.get("damage", _damage(72.0))), String(pending.get("source_id", "ai_infra_q")))
		_add_visual({"type": "tensor_beam", "from": origin, "to": hit_position, "color": Color("ffffff"), "ttl": 0.42, "max": 0.42, "width": 10.0, "glow_width": 34.0, "stage": 4})
		_add_visual({"type": "tensor_node", "center": hit_position, "color": Color("ffffff"), "ttl": 0.48, "max": 0.48, "stage": 4})
		return
	var finish := origin + direction * 280.0
	swarm.call("damage_line", origin, finish, 34.0, float(pending.get("damage", _damage(72.0))), -1, String(pending.get("source_id", "ai_infra_q")))
	_add_visual({"type": "tensor_beam", "from": origin, "to": finish, "color": Color("ffffff"), "ttl": 0.42, "max": 0.42, "width": 10.0, "glow_width": 34.0, "stage": 4})


func _resolve_ai_prefill_scan(pending: Dictionary) -> void:
	var start := Vector2(pending.get("from", AI_WORLD_RECT.position))
	var finish := Vector2(pending.get("to", AI_WORLD_RECT.end))
	var half_width := float(pending.get("half_width", 96.0))
	swarm.call("damage_line", start, finish, half_width, float(pending.get("damage", _damage(45.0))), -1, String(pending.get("source_id", "ai_infra_r")))
	_add_visual({"type": "prefill_scan", "from": start, "to": finish, "color": Color("b9ff85"), "ttl": 0.46, "max": 0.46, "width": 7.0, "glow_width": half_width * 2.0})


func _fire_ai_decode_volley() -> void:
	var token_count := _ai_token_count()
	var targets := _select_priority_targets(AI_WORLD_RECT.get_center(), 1800.0, token_count)
	if targets.is_empty():
		return
	for token_index in range(token_count):
		var target := targets[token_index % targets.size()]
		var target_id := int(target["entity_id"])
		var target_index := _find_entity_index_by_id(target_id)
		if target_index < 0:
			continue
		var hit_position := Vector2(swarm.get("positions")[target_index])
		var source := _ai_stage_core_position((token_index + ai_model_decode_count) % 4)
		var convergence_scale := 1.0 if token_index < targets.size() else 0.72
		_damage_entity_id(target_id, _damage(35.0) * convergence_scale, "ai_infra_r")
		_add_visual({"type": "tensor_beam", "from": source, "to": hit_position, "color": AI_PIPELINE_STAGE_COLORS[(token_index + ai_model_decode_count) % 4], "ttl": 0.22, "max": 0.22, "width": 4.5, "glow_width": 15.0, "stage": 5})
	ai_model_decode_count += 1


func _fire_ai_eos() -> void:
	var enemy_snapshots: Array[Dictionary] = []
	var entity_count := int(swarm.get("count"))
	var ids_value: PackedInt64Array = swarm.get("entity_ids")
	var kinds_value: PackedInt32Array = swarm.get("kinds")
	var health_value: PackedFloat32Array = swarm.get("health")
	var maximum_value: PackedFloat32Array = swarm.get("maximum_health")
	var shield_value: PackedFloat32Array = swarm.get("shield_health")
	for enemy_index in range(entity_count):
		enemy_snapshots.append({
			"entity_id": int(ids_value[enemy_index]),
			"tier": _enemy_tier(int(kinds_value[enemy_index])),
			"health": float(health_value[enemy_index]),
			"maximum": float(maximum_value[enemy_index]),
			"shield": float(shield_value[enemy_index]),
		})
	for enemy in enemy_snapshots:
		var entity_id := int(enemy["entity_id"])
		var tier := int(enemy["tier"])
		if tier == 0:
			var health_ratio := float(enemy["health"]) / maxf(1.0, float(enemy["maximum"]))
			if health_ratio <= 0.35:
				_damage_entity_id(entity_id, float(enemy["health"]) + float(enemy["shield"]) + 1.0, "ai_infra_r")
			else:
				_damage_entity_id(entity_id, _damage(180.0), "ai_infra_r")
		else:
			_damage_entity_id(entity_id, _damage(650.0), "ai_infra_r")
	if swarm.has_method("amplify_damage_area"):
		swarm.call("amplify_damage_area", AI_WORLD_RECT.get_center(), 1800.0, 1.20, 6.0)
	var loot_node := get_parent().get_node_or_null("LootWorld")
	if loot_node != null and loot_node.has_method("collect_all_xp"):
		loot_node.call("collect_all_xp")
	_add_visual({"type": "eos_frame", "rect": AI_WORLD_RECT, "color": Color("eaffd1"), "ttl": 0.90, "max": 0.90})
	if projection != null and projection.call("is_targetable"):
		projection.call("take_shell_damage", _damage(650.0))


func _trim_pending_actions() -> void:
	while pending_actions.size() > MAX_PENDING_ACTIONS:
		pending_actions.remove_at(0)


func _cast_borrowed_signature(borrowed_id: String, origin: Vector2, target: Vector2, area_scale: float, borrowed_damage_scale: float, source_id: String = "") -> void:
	var color := _career_color(borrowed_id)
	var direction := (target - origin).normalized()
	if direction.length_squared() < 0.01:
		direction = Vector2.RIGHT
	match borrowed_id:
		"ops":
			var radius := 118.0 * area_scale
			swarm.call("damage_area", target, radius, _damage(26.0) * borrowed_damage_scale, source_id)
			swarm.call("push_area", target, radius, 22.0)
			_add_visual({"type": "blast", "center": target, "radius": radius, "color": color, "ttl": 0.34, "max": 0.34})
		"dba":
			_add_zone(target, "lock", 78.0 * area_scale, 3.8, 0.30, false, borrowed_damage_scale, color, source_id)
		"network":
			var finish := origin + direction * 640.0 * area_scale
			var width := 17.0 * area_scale
			swarm.call("damage_line", origin, finish, width, _damage(22.0) * borrowed_damage_scale, 8, source_id)
			_add_visual({"type": "beam", "from": origin, "to": finish, "color": color, "ttl": 0.24, "max": 0.24, "width": 4.0, "glow_width": width * 2.0})
		"security":
			var half_length := 100.0 * area_scale
			var side := direction.orthogonal() * half_length
			_add_wall(target - side, target + side, 3.5, "firewall", false, 22.0 * area_scale, borrowed_damage_scale, color, source_id)
		"it_ops":
			_add_node(target, 4.6, "spare", false, 104.0 * area_scale, borrowed_damage_scale, color, source_id)
		"helpdesk":
			var hits: Array[Vector2] = swarm.call("damage_nearest_targets", target, 310.0 * area_scale, _damage(19.0) * borrowed_damage_scale, 7, 0.76, source_id)
			var source := origin
			for hit_position in hits:
				_add_visual({"type": "beam", "from": source, "to": hit_position, "color": color, "ttl": 0.28, "max": 0.28, "width": 3.0})
				source = hit_position
		"opsdev":
			pending_actions.append({"type": "script_repeat", "delay": 0.18, "position": target, "damage": _damage(17.0) * borrowed_damage_scale, "repeat": 2, "radius": 42.0 * area_scale, "color": color, "source_id": source_id})
		"sre":
			_cast_sre_trace(origin, borrowed_damage_scale * 0.82, 3, area_scale, source_id)
		"delivery":
			var release_radius := 96.0 * area_scale
			pending_actions.append({"type": "release_package", "delay": 0.34, "position": target, "damage": _damage(28.0) * borrowed_damage_scale, "radius": release_radius, "source_id": source_id})
			_add_visual({"type": "marker", "center": target, "radius": release_radius, "color": color, "ttl": 0.34, "max": 0.34})
		"ai_infra":
			var worker_hits: Array[Vector2] = swarm.call("damage_nearest_targets", target, 360.0 * area_scale, _damage(13.0) * borrowed_damage_scale, 5, 0.90, source_id)
			for hit_index in range(worker_hits.size()):
				var pod_offset := direction.orthogonal() * (float(hit_index) - float(worker_hits.size() - 1) * 0.5) * 28.0
				_add_visual({"type": "beam", "from": origin + pod_offset, "to": worker_hits[hit_index], "color": color, "ttl": 0.24, "max": 0.24, "width": 3.0})


func _cast_sre_trace(origin: Vector2, trace_damage_scale: float, requested_nodes: int, area_scale: float, source_id: String = "") -> int:
	var node_count := clampi(requested_nodes, 1, 7)
	var targets := _select_priority_targets(origin, 560.0 * area_scale, node_count)
	if targets.is_empty():
		return 0
	# Build the path from lower-impact symptoms toward the highest-priority
	# incident so the reverse replay opens by striking the actual root cause.
	targets.reverse()
	var target_ids: Array[int] = []
	var points := PackedVector2Array()
	points.append(origin)
	for target_index in range(targets.size()):
		var target: Dictionary = targets[target_index]
		var entity_id := int(target["entity_id"])
		var target_position := Vector2(target["position"])
		target_ids.append(entity_id)
		points.append(target_position)
		_damage_entity_id(entity_id, _signature_damage(11.0) * trace_damage_scale * (1.0 if target_index == targets.size() - 1 else 0.80), source_id)
		_add_visual({"type": "span_marker", "center": target_position, "color": Color("ff765f") if int(target["tier"]) > 0 else accent, "ttl": 0.72, "max": 0.72, "size": Vector2(38.0 + float(target_index) * 4.0, 18.0), "priority": target_index})
	_add_visual({"type": "trace_path", "points": points, "color": Color("a6ffe0"), "ttl": 0.72, "max": 0.72, "width": 3.0})
	pending_actions.append({
		"type": "sre_trace_return",
		"delay": 0.64,
		"origin": origin,
		"target_ids": target_ids,
		"points": points,
		"damage": _signature_damage(25.0) * trace_damage_scale,
		"root_bonus": _signature_damage(10.0) * trace_damage_scale,
		"color": Color("65e890"),
		"source_id": source_id,
	})
	return targets.size()


func _resolve_sre_trace_return(pending: Dictionary) -> void:
	var points := PackedVector2Array(pending.get("points", PackedVector2Array()))
	var reverse_points := PackedVector2Array()
	for point_index in range(points.size() - 1, -1, -1):
		reverse_points.append(points[point_index])
	if reverse_points.size() >= 2:
		_add_visual({"type": "trace_path", "points": reverse_points, "color": Color(pending.get("color", accent)), "ttl": 0.48, "max": 0.48, "width": 7.0})
	var target_ids: Array = pending.get("target_ids", [])
	for return_index in range(target_ids.size()):
		var source_index := target_ids.size() - 1 - return_index
		var damage := float(pending.get("damage", _signature_damage(15.0)))
		var is_root := return_index == 0
		if is_root:
			damage += float(pending.get("root_bonus", 0.0)) * float(maxi(0, target_ids.size() - 1))
		pending_actions.append({
			"type": "sre_trace_hit",
			"delay": float(return_index) * 0.075,
			"entity_id": int(target_ids[source_index]),
			"fallback_origin": Vector2(points[source_index + 1]) if source_index + 1 < points.size() else Vector2(pending.get("origin", player.global_position)),
			"damage": damage,
			"root": is_root,
			"reserved_ids": target_ids,
			"color": Color(pending.get("color", accent)),
			"source_id": String(pending.get("source_id", "")),
		})


func _resolve_sre_trace_hit(pending: Dictionary) -> void:
	var entity_id := int(pending.get("entity_id", -1))
	var entity_index := _find_entity_index_by_id(entity_id)
	if entity_index < 0:
		var reroute := _select_priority_targets(Vector2(pending.get("fallback_origin", player.global_position)), 640.0 * _signature_area_multiplier(), 1, Array(pending.get("reserved_ids", [])))
		if reroute.is_empty():
			return
		entity_id = int(reroute[0]["entity_id"])
		entity_index = _find_entity_index_by_id(entity_id)
	if entity_index < 0:
		return
	var hit_position := Vector2(swarm.get("positions")[entity_index])
	var was_root := bool(pending.get("root", false))
	_damage_entity_id(entity_id, float(pending.get("damage", 0.0)), String(pending.get("source_id", "")))
	_add_visual({"type": "span_hit", "center": hit_position, "color": Color(pending.get("color", accent)), "ttl": 0.32, "max": 0.32, "size": Vector2(62.0, 26.0) if was_root else Vector2(42.0, 18.0)})
	if was_root and _find_entity_index_by_id(entity_id) < 0:
		career_metric.emit("sre_root_closed", 10.0)


func _select_priority_targets(origin: Vector2, maximum_range: float, wanted: int, excluded_ids: Array = []) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var entity_count := int(swarm.get("count"))
	var positions_value: PackedVector2Array = swarm.get("positions")
	var kinds_value: PackedInt32Array = swarm.get("kinds")
	var health_value: PackedFloat32Array = swarm.get("health")
	var maximum_value: PackedFloat32Array = swarm.get("maximum_health")
	var ids_value: PackedInt64Array = swarm.get("entity_ids")
	var maximum_squared := maximum_range * maximum_range
	for index in range(entity_count):
		var entity_id := int(ids_value[index])
		if entity_id in excluded_ids:
			continue
		var kind := int(kinds_value[index])
		var tier := _enemy_tier(kind)
		if tier == 2 and int(swarm.get("boss_phase")) != 1:
			continue
		var distance_squared := origin.distance_squared_to(positions_value[index])
		if distance_squared > maximum_squared:
			continue
		var distance := sqrt(distance_squared)
		var health_ratio := float(health_value[index]) / maxf(1.0, float(maximum_value[index]))
		var score := float(tier) * 100000.0 + float(maximum_value[index]) * 8.0 + health_ratio * 500.0 - distance * 0.18
		candidates.append({"entity_id": entity_id, "position": positions_value[index], "tier": tier, "score": score})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) > float(b["score"]))
	if candidates.size() > maxi(0, wanted):
		candidates.resize(maxi(0, wanted))
	return candidates


func _enemy_tier(kind: int) -> int:
	if kind == 7:
		return 2
	if kind == 5 or kind == 6:
		return 1
	return 0


func _find_entity_index_by_id(entity_id: int) -> int:
	if entity_id < 0:
		return -1
	var entity_count := int(swarm.get("count"))
	var ids_value: PackedInt64Array = swarm.get("entity_ids")
	for index in range(entity_count):
		if int(ids_value[index]) == entity_id:
			return index
	return -1


func _damage_entity_id(entity_id: int, amount: float, source_id: String = "") -> bool:
	var index := _find_entity_index_by_id(entity_id)
	if index < 0:
		return false
	return bool(swarm.call("damage_index", index, amount, source_id))


func _sre_history_position(seconds_ago: float, fallback: Vector2) -> Vector2:
	if sre_position_history.is_empty():
		return fallback
	var samples_ago := maxi(1, roundi(seconds_ago / 0.10))
	var history_index := clampi(sre_position_history.size() - 1 - samples_ago, 0, sre_position_history.size() - 1)
	var resolved := sre_position_history[history_index]
	if resolved.distance_to(player.global_position) < 96.0:
		return fallback
	return resolved


func _perform_sre_failover() -> void:
	if sre_replicas.is_empty():
		return
	var selected_index := 0
	var best_clearance := -1.0
	for replica_index in range(sre_replicas.size()):
		var candidate_position := Vector2(sre_replicas[replica_index]["position"])
		var clearance := _distance_to_nearest_enemy(candidate_position)
		if clearance > best_clearance:
			best_clearance = clearance
			selected_index = replica_index
	var start := player.global_position
	var destination := Vector2(sre_replicas[selected_index]["position"])
	player.global_position = destination
	player.call("grant_invulnerability", 0.85)
	player.call("heal", player.max_health * 0.12)
	swarm.call("damage_line", start, destination, 30.0, _damage(38.0), -1)
	_add_visual({"type": "failover_line", "from": start, "to": destination, "color": Color("d8fff1"), "ttl": 0.72, "max": 0.72, "width": 12.0})
	sre_replicas.remove_at(selected_index)
	sre_failover_used = true


func _distance_to_nearest_enemy(origin: Vector2) -> float:
	var nearest := 9999.0
	var entity_count := int(swarm.get("count"))
	var positions_value: PackedVector2Array = swarm.get("positions")
	for index in range(entity_count):
		nearest = minf(nearest, origin.distance_to(positions_value[index]))
	return nearest


func _finish_ultimate_mode(mode: String) -> void:
	if mode == "opsdev_hot_reload":
		_schedule_opsdev_combo_sequence("opsdev_r_merge", true)
		_add_visual({"type": "opsdev_world_compile", "center": player.global_position, "radius": 650.0, "color": Color("eaffd1"), "ttl": 1.24, "max": 1.24})
		opsdev_hot_reload_seen.clear()
	if mode == "sre_multi_active":
		for replica in sre_replicas:
			var replica_position := Vector2(replica["position"])
			_cast_sre_trace(replica_position, 0.85, 4, _signature_area_multiplier())
			_add_visual({"type": "failover_line", "from": replica_position, "to": player.global_position, "color": Color(replica["color"]), "ttl": 0.62, "max": 0.62, "width": 7.0})
		sre_replicas.clear()
		if player.has_method("set_temporary_damage_reduction"):
			player.call("set_temporary_damage_reduction", 0.0)
	if mode == "ai_foundation_model":
		ai_model_decode_count = 0
	ultimate_mode = ""
	ultimate_left = 0.0


func _worker_count() -> int:
	return _ai_token_count()


func _ai_token_count() -> int:
	return mini(8, _signature_quantity_value()) if career_id == "ai_infra" else 0


func _ai_stage_core_position(stage: int) -> Vector2:
	var offsets: Array[Vector2] = [Vector2(-58.0, -34.0), Vector2(18.0, -52.0), Vector2(62.0, 12.0), Vector2(-16.0, 50.0)]
	return player.global_position + offsets[clampi(stage, 0, offsets.size() - 1)]


func _ai_token_origin(token_index: int, token_count: int) -> Vector2:
	var core := _ai_stage_core_position(token_index % 4)
	var layer := token_index / 4
	var centered := float(token_index) - float(token_count - 1) * 0.5
	return core + facing_direction.orthogonal() * centered * 4.0 - facing_direction * float(layer) * 14.0


func _worker_positions() -> Array[Vector2]:
	var result: Array[Vector2] = []
	var count := _ai_token_count()
	for index in range(count):
		result.append(_ai_token_origin(index, count))
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
	var area_scale := _signature_area_multiplier()
	var amount := _signature_damage(13.0)
	match archetype:
		"melee_combo":
			can_hit = distance <= 132.0 * area_scale
			amount = _signature_damage(24.0)
		"piercing_projectile":
			can_hit = distance <= 650.0 * area_scale
			amount = _signature_damage(22.0)
		"persistent_wall", "deployable_node":
			can_hit = distance <= 180.0 * area_scale
		"trace_replay":
			can_hit = distance <= 560.0 * area_scale
			amount = _signature_damage(20.0)
		"delayed_zone", "delayed_aoe":
			can_hit = distance <= 390.0 * area_scale
		"chain_bounce", "delayed_repeat":
			can_hit = distance <= 470.0 * area_scale
		"tensor_pipeline":
			can_hit = distance <= 720.0 * area_scale
			amount = _signature_damage(34.0)
	if can_hit:
		projection.call("take_shell_damage", amount)


func _resolved_direction(direction: Vector2) -> Vector2:
	if direction.length_squared() > 0.04:
		return direction.normalized()
	return _aim_direction(420.0)


func _security_signature_damage_factor(level_value: int = -1) -> float:
	if career_id != "security":
		return 1.0
	var resolved := signature_damage_level if level_value < 0 else level_value
	return lerpf(0.50, 1.0, clampf(float(resolved) / 5.0, 0.0, 1.0))


func _security_action_damage_factor(cryo_level: int = -1, storm_level: int = -1) -> float:
	if career_id != "security":
		return 1.0
	var resolved_cryo := security_cryo_acl_level if cryo_level < 0 else cryo_level
	var resolved_storm := security_storm_ids_level if storm_level < 0 else storm_level
	return lerpf(0.50, 1.0, clampf(float(resolved_cryo + resolved_storm) / 6.0, 0.0, 1.0))


func _security_storm_damage(level_value: int) -> float:
	return [0.0, 7.0, 12.0, 19.0][clampi(level_value, 0, 3)]


func _damage(base_damage: float) -> float:
	var packet_multiplier := 1.15 if packet_capture_left > 0.0 and player.global_position.distance_to(packet_capture_position) <= 210.0 else 1.0
	return base_damage * damage_multiplier * packet_multiplier * artifact_damage_multiplier


func _signature_damage(base_damage: float) -> float:
	return _damage(base_damage) * _signature_damage_multiplier()


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


func _career_sprite_region(resolved_career_id: String) -> Rect2:
	var career_index := maxi(0, CAREER_ORDER.find(resolved_career_id))
	var cell_size := Vector2(float(CAREER_SPRITES.get_width()) / 5.0, float(CAREER_SPRITES.get_height()) / 2.0)
	return Rect2(Vector2(float(career_index % 5), float(career_index / 5)) * cell_size, cell_size)


func _draw_career_silhouette(resolved_career_id: String, center: Vector2, silhouette_color: Color, alpha: float) -> void:
	var destination := Rect2(center - Vector2(37.0, 78.0), Vector2(74.0, 104.0))
	var dark_tint := Color(silhouette_color.r * 0.28, silhouette_color.g * 0.28, silhouette_color.b * 0.28, clampf(alpha, 0.0, 1.0))
	draw_texture_rect_region(CAREER_SPRITES, destination, _career_sprite_region(resolved_career_id), dark_tint)
	draw_line(center + Vector2(-28.0, 30.0), center + Vector2(28.0, 30.0), Color(silhouette_color, alpha), 4.0)
	draw_rect(Rect2(center + Vector2(-18.0, 36.0), Vector2(36.0, 5.0)), Color(silhouette_color, alpha * 0.55), true)


func _draw_sre_site(center: Vector2, label: String, site_color: Color, alpha: float) -> void:
	var resolved_alpha := clampf(alpha, 0.0, 1.0)
	var body_rect := Rect2(center - Vector2(27.0, 35.0), Vector2(54.0, 70.0))
	draw_rect(body_rect, Color(0.035, 0.09, 0.12, 0.78 * resolved_alpha), true)
	draw_rect(body_rect, Color(site_color, resolved_alpha), false, 3.0)
	for slot_index in range(3):
		var slot_y := body_rect.position.y + 12.0 + float(slot_index) * 16.0
		draw_line(Vector2(body_rect.position.x + 8.0, slot_y), Vector2(body_rect.end.x - 8.0, slot_y), Color(site_color, resolved_alpha * (0.45 + float(slot_index) * 0.18)), 4.0)
	var label_width := 34.0 + float(label.length()) * 3.0
	draw_rect(Rect2(center + Vector2(-label_width * 0.5, 42.0), Vector2(label_width, 7.0)), Color(site_color, resolved_alpha * 0.82), true)


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
		var wall_color := Color(wall.get("color", accent))
		var visual_width := clampf(float(wall.get("width", 22.0)) / 22.0, 1.0, 2.8)
		var wall_direction := (finish - start).normalized()
		var wall_normal := wall_direction.orthogonal()
		var wall_phase := float(Time.get_ticks_msec()) * 0.004
		draw_line(start, finish, Color(0.03, 0.01, 0.025, 0.94), 22.0 * visual_width)
		draw_line(start, finish, Color(wall_color, 0.22), 15.0 * visual_width)
		draw_line(start, finish, Color(wall_color, 0.94), 7.0 * visual_width)
		for node_index in range(7):
			var point := start.lerp(finish, float(node_index) / 6.0)
			draw_rect(Rect2(point - Vector2(5, 5), Vector2(10, 10)), Color("13070b"), true)
			draw_rect(Rect2(point - Vector2(5, 5), Vector2(10, 10)), wall_color, false, 2.0)
			if String(wall.get("kind", "")) != "traffic_link":
				var flame_height := 13.0 + sin(wall_phase + float(node_index) * 1.7) * 6.0
				draw_colored_polygon(PackedVector2Array([point - wall_direction * 7.0, point + wall_direction * 7.0, point + wall_normal * flame_height]), Color("ff7b32"))
				if int(wall.get("frost_level", 0)) > 0:
					draw_line(point - wall_normal * 12.0, point + wall_normal * 12.0, Color("9cecff"), 3.0)
					draw_line(point - wall_direction * 7.0 - wall_normal * 7.0, point + wall_direction * 7.0 + wall_normal * 7.0, Color("d8f8ff"), 2.0)
				if int(wall.get("storm_level", 0)) > 0 and node_index < 6:
					var next_point := start.lerp(finish, float(node_index + 1) / 6.0)
					var midpoint := point.lerp(next_point, 0.5) + wall_normal * sin(wall_phase * 1.8 + float(node_index)) * 7.0
					draw_polyline(PackedVector2Array([point, midpoint, next_point]), Color("eaff72"), 3.0, true)
	for zone in zones:
		var position_value := Vector2(zone["position"])
		var radius := float(zone["radius"])
		var kind := String(zone["kind"])
		var color := Color(zone.get("color", Color("c68cff") if kind == "lock" else (Color("65e890") if kind == "heal" else Color("ffce73"))))
		draw_circle(position_value, radius, Color(color, 0.045))
		draw_arc(position_value, radius, 0.0, TAU, 42, Color(color, 0.76), 2.0)
		draw_line(position_value + Vector2(-radius * 0.65, 0), position_value + Vector2(radius * 0.65, 0), Color(color, 0.34), 1.0)
	for node in nodes:
		var position_value := Vector2(node["position"])
		var is_rack := String(node["kind"]) == "rack"
		var node_color := Color(node.get("color", accent))
		if bool(node.get("signature", false)):
			var effect_radius := float(node.get("radius", 104.0))
			draw_arc(position_value, effect_radius, 0.0, TAU, 32, Color(node_color, 0.18), 1.5)
		var size := Vector2(34, 42) if is_rack else Vector2(26, 30)
		draw_rect(Rect2(position_value - size * 0.5, size), Color("13272e"), true)
		draw_rect(Rect2(position_value - size * 0.5, size), node_color, false, 3.0)
		draw_circle(position_value + Vector2(0, -5), 3.0, Color("d6fff1"))
	if career_id == "ai_infra":
		var pipeline_points := PackedVector2Array()
		for stage_index in range(4):
			pipeline_points.append(_ai_stage_core_position(stage_index))
		for stage_index in range(4):
			var core_position := pipeline_points[stage_index]
			var next_position := pipeline_points[(stage_index + 1) % 4]
			draw_line(core_position, next_position, Color(AI_PIPELINE_STAGE_COLORS[stage_index], 0.30), 2.0)
			var core_rect := Rect2(core_position - Vector2(13.0, 10.0), Vector2(26.0, 20.0))
			draw_rect(core_rect, Color("102c29"), true)
			draw_rect(core_rect, AI_PIPELINE_STAGE_COLORS[stage_index], false, 2.5)
			for pin_index in range(3):
				var pin_x := core_rect.position.x + 6.0 + float(pin_index) * 7.0
				draw_line(Vector2(pin_x, core_rect.position.y - 4.0), Vector2(pin_x, core_rect.position.y), AI_PIPELINE_STAGE_COLORS[stage_index], 1.5)
		var token_count := _ai_token_count()
		for token_index in range(token_count):
			var token_position := player.global_position + Vector2(-float(token_count - 1) * 5.0 + float(token_index) * 10.0, 72.0)
			draw_rect(Rect2(token_position - Vector2(3.5, 3.5), Vector2(7.0, 7.0)), Color(accent, 0.82), true)
	if ultimate_mode == "security_lockdown":
		var points := PackedVector2Array()
		for index in range(6):
			points.append(player.global_position + Vector2.from_angle(TAU * float(index) / 6.0) * 365.0)
		draw_colored_polygon(points, Color(accent, 0.035))
		for index in range(6):
			draw_line(points[index], points[(index + 1) % 6], Color(accent, 0.30), 20.0)
			draw_line(points[index], points[(index + 1) % 6], Color(accent, 0.92), 7.0)
	if ultimate_mode == "sre_multi_active":
		_draw_sre_site(player.global_position, "AZ-A", Color("d8fff1"), 0.94)
		for replica in sre_replicas:
			var replica_position := Vector2(replica["position"])
			draw_line(player.global_position, replica_position, Color(Color(replica["color"]), 0.22), 2.0)
			_draw_sre_site(replica_position, String(replica["label"]), Color(replica["color"]), 0.72)
	if ultimate_mode == "opsdev_hot_reload":
		var reload_phase := float(Time.get_ticks_msec()) * 0.004
		for reload_index in range(_opsdev_toolchain_cap()):
			var reload_radius := 68.0 + float(reload_index) * 15.0
			draw_arc(player.global_position, reload_radius, reload_phase + float(reload_index) * 1.7, reload_phase + float(reload_index) * 1.7 + 1.05, 20, Color(accent, 0.48), 3.0)
	if ultimate_mode in ["ops_p1", "network_storm", "helpdesk_sla"]:
		var aura_radius: float = float({"ops_p1": 145.0, "network_storm": 485.0, "helpdesk_sla": 185.0}.get(ultimate_mode, 160.0))
		draw_arc(player.global_position, float(aura_radius), 0.0, TAU, 64, Color(accent, 0.55), 3.0)
	for effect in visuals:
		var alpha := clampf(float(effect["ttl"]) / maxf(0.001, float(effect["max"])), 0.0, 1.0)
		var color := Color(effect["color"])
		color.a *= alpha
		match String(effect["type"]):
			"career_silhouette":
				var silhouette_center := Vector2(effect["center"])
				var silhouette_alpha := alpha * float(effect.get("alpha_scale", 0.92))
				var silhouette_color := Color(effect["color"])
				_draw_career_silhouette(String(effect["career_id"]), silhouette_center, silhouette_color, silhouette_alpha)
			"beam":
				var beam_start := Vector2(effect["from"])
				var beam_finish := Vector2(effect["to"])
				var glow_width := float(effect.get("glow_width", 0.0))
				if glow_width > 0.0:
					draw_line(beam_start, beam_finish, Color(color, color.a * 0.20), glow_width)
				draw_line(beam_start, beam_finish, color, float(effect.get("width", 3.0)))
			"opsdev_bytecode":
				var code_start := Vector2(effect["from"])
				var code_finish := Vector2(effect["to"])
				draw_line(code_start, code_finish, Color(color, color.a * 0.14), 13.0)
				draw_line(code_start, code_finish, color, 3.5)
				var code_direction := (code_finish - code_start).normalized()
				if code_direction.length_squared() > 0.01:
					for packet_index in range(4):
						var packet_position := code_start.lerp(code_finish, 0.18 + float(packet_index) * 0.21)
						var packet_side := code_direction.orthogonal() * 4.0
						draw_colored_polygon(PackedVector2Array([packet_position + code_direction * 7.0, packet_position - code_direction * 4.0 + packet_side, packet_position - code_direction * 4.0 - packet_side]), color)
			"opsdev_capture":
				var capture_center := Vector2(effect["center"])
				var capture_rect := Rect2(capture_center - Vector2(17.0, 10.0), Vector2(34.0, 20.0))
				draw_rect(capture_rect, Color(color, color.a * 0.12), true)
				draw_rect(capture_rect, color, false, 2.0)
				draw_line(capture_rect.position + Vector2(5.0, 6.0), capture_rect.end - Vector2(9.0, 14.0), color, 2.0)
				draw_line(capture_rect.position + Vector2(5.0, 13.0), capture_rect.end - Vector2(15.0, 7.0), color, 2.0)
			"opsdev_compile_frame":
				var frame_center := Vector2(effect["center"])
				var frame_direction := Vector2(effect.get("direction", facing_direction)).normalized()
				var slot_count := int(effect.get("slots", 1))
				for slot_index in range(slot_count):
					var slot_position := frame_center + frame_direction * (64.0 + float(slot_index) * 46.0)
					var frame_rect := Rect2(slot_position - Vector2(16.0, 12.0), Vector2(32.0, 24.0))
					draw_rect(frame_rect, Color(color, color.a * 0.10), true)
					draw_rect(frame_rect, color, false, 2.5)
					if slot_index + 1 < slot_count:
						draw_line(slot_position + frame_direction * 18.0, slot_position + frame_direction * 30.0, color, 3.0)
			"opsdev_stage":
				var stage_center := Vector2(effect["center"])
				var stage_rect := Rect2(stage_center - Vector2(22.0, 15.0), Vector2(44.0, 30.0))
				draw_rect(stage_rect, Color(color, color.a * 0.09), true)
				draw_rect(stage_rect, color, false, 3.0)
				var modifier := String(effect.get("modifier", "optimize"))
				if modifier == "fork" or modifier == "merge":
					draw_line(stage_center + Vector2(-12.0, 0.0), stage_center + Vector2(0.0, 0.0), color, 3.0)
					draw_line(stage_center, stage_center + Vector2(12.0, -8.0), color, 3.0)
					draw_line(stage_center, stage_center + Vector2(12.0, 8.0), color, 3.0)
				elif modifier.begins_with("loop"):
					draw_arc(stage_center, 9.0, -PI * 0.35, PI * 1.25, 18, color, 3.0)
					draw_colored_polygon(PackedVector2Array([stage_center + Vector2(-7.0, -8.0), stage_center + Vector2(-1.0, -9.0), stage_center + Vector2(-4.0, -3.0)]), color)
				else:
					draw_colored_polygon(PackedVector2Array([stage_center + Vector2(0.0, -10.0), stage_center + Vector2(10.0, 0.0), stage_center + Vector2(0.0, 10.0), stage_center + Vector2(-10.0, 0.0)]), Color(color, color.a * 0.35))
			"opsdev_combo_tool":
				var combo_tool_center := Vector2(effect["center"])
				var combo_tool_from := Vector2(effect.get("from", combo_tool_center))
				var combo_final := bool(effect.get("final_combo", false))
				if combo_tool_from.distance_squared_to(combo_tool_center) > 4.0:
					draw_line(combo_tool_from, combo_tool_center, Color(color, color.a * 0.18), 13.0)
					draw_line(combo_tool_from, combo_tool_center, color, 4.0 if combo_final else 2.5)
				var combo_rect := Rect2(combo_tool_center - Vector2(31.0, 20.0), Vector2(62.0, 40.0))
				draw_rect(combo_rect, Color(0.01, 0.035, 0.045, color.a * 0.94), true)
				draw_rect(combo_rect, color, false, 4.0 if combo_final else 2.5)
				if combo_final:
					draw_arc(combo_tool_center, 37.0 + (1.0 - alpha) * 8.0, 0.0, TAU, 24, Color(color, color.a * 0.55), 3.0)
				var combo_label := String(effect.get("label", "JOB"))
				var combo_text_size := UI_FONT.get_string_size(combo_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
				draw_string(UI_FONT, combo_tool_center + Vector2(-combo_text_size.x * 0.5, 4.0), combo_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(color, color.a))
				var combo_index := int(effect.get("index", 0))
				for pip_index in range(int(effect.get("slots", 1))):
					var pip_position := combo_tool_center + Vector2((float(pip_index) - float(int(effect.get("slots", 1)) - 1) * 0.5) * 6.0, 14.0)
					draw_circle(pip_position, 1.7, Color(color, color.a if pip_index <= combo_index else color.a * 0.18))
			"opsdev_combo_commit":
				var combo_center := Vector2(effect["center"])
				var combo_radius := float(effect.get("radius", 520.0)) * (0.88 + (1.0 - alpha) * 0.12)
				var combo_slots := int(effect.get("slots", 1))
				draw_circle(combo_center, combo_radius, Color(color, color.a * 0.035))
				draw_arc(combo_center, combo_radius, 0.0, TAU, 72, color, 10.0)
				draw_arc(combo_center, combo_radius * 0.72, 0.0, TAU, 64, Color(color, color.a * 0.46), 5.0)
				for combo_ray_index in range(combo_slots):
					var combo_ray := Vector2.from_angle(TAU * float(combo_ray_index) / float(maxi(1, combo_slots)))
					draw_line(combo_center + combo_ray * 52.0, combo_center + combo_ray * combo_radius, Color(color, color.a * 0.48), 5.0)
				var combo_text := "MERGE COMBO ×%d" % combo_slots
				var combo_commit_text_size := UI_FONT.get_string_size(combo_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
				var combo_badge_center := combo_center + Vector2(0.0, -68.0)
				var combo_badge_size := combo_commit_text_size + Vector2(34.0, 24.0)
				var combo_badge_rect := Rect2(combo_badge_center - combo_badge_size * 0.5, combo_badge_size)
				draw_rect(combo_badge_rect, Color(0.008, 0.025, 0.034, color.a * 0.92), true)
				draw_rect(combo_badge_rect, color, false, 3.0)
				draw_string(UI_FONT, combo_badge_center + Vector2(-combo_commit_text_size.x * 0.5, 7.0), combo_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, color)
			"opsdev_hot_reload":
				var reload_center := Vector2(effect["center"])
				var phase := (1.0 - alpha) * TAU * 2.0
				for arc_index in range(3):
					var reload_radius := 72.0 + float(arc_index) * 16.0
					draw_arc(reload_center, reload_radius, phase + float(arc_index) * 1.6, phase + float(arc_index) * 1.6 + 1.15, 22, Color(color, color.a * 0.52), 3.0)
			"opsdev_compile_burst", "opsdev_world_compile":
				var compile_center := Vector2(effect["center"])
				var compile_radius := float(effect.get("radius", 360.0)) * (1.08 - alpha * 0.08)
				draw_circle(compile_center, compile_radius, Color(color, color.a * 0.035))
				draw_arc(compile_center, compile_radius, 0.0, TAU, 64, color, 7.0)
				for grid_index in range(-4, 5):
					var grid_offset := float(grid_index) * compile_radius / 4.0
					draw_line(compile_center + Vector2(-compile_radius, grid_offset), compile_center + Vector2(compile_radius, grid_offset), Color(color, color.a * 0.12), 1.5)
					draw_line(compile_center + Vector2(grid_offset, -compile_radius), compile_center + Vector2(grid_offset, compile_radius), Color(color, color.a * 0.12), 1.5)
			"opsdev_epoch":
				var epoch_center := Vector2(effect["center"])
				var epoch_radius := 74.0 + (1.0 - alpha) * 68.0
				draw_arc(epoch_center, epoch_radius, 0.0, TAU, 40, color, 4.0)
				for tick_index in range(8):
					var tick_direction := Vector2.from_angle(TAU * float(tick_index) / 8.0)
					draw_line(epoch_center + tick_direction * (epoch_radius - 7.0), epoch_center + tick_direction * (epoch_radius + 7.0), color, 2.0)
			"opsdev_merge":
				var merge_center := Vector2(effect["center"])
				var merge_slots := int(effect.get("slots", 1))
				var merge_radius := 62.0 + (1.0 - alpha) * 96.0
				draw_arc(merge_center, merge_radius, 0.0, TAU, 48, color, 8.0)
				for merge_index in range(merge_slots):
					var merge_direction := Vector2.from_angle(TAU * float(merge_index) / float(maxi(1, merge_slots)))
					draw_line(merge_center, merge_center + merge_direction * merge_radius, color, 6.0)
			"security_ignition":
				var ignition_start := Vector2(effect["from"])
				var ignition_end := Vector2(effect["to"])
				var ignition_width := float(effect.get("width", 92.0))
				draw_line(ignition_start, ignition_end, Color(color, color.a * 0.10), ignition_width)
				draw_line(ignition_start, ignition_end, Color("ffd36a", color.a * 0.78), 12.0)
				for flame_index in range(9):
					var flame_point := ignition_start.lerp(ignition_end, float(flame_index) / 8.0)
					draw_circle(flame_point, 18.0 + (1.0 - alpha) * 18.0, Color("ff5a2f", color.a * 0.18))
			"security_flame":
				var flame_center := Vector2(effect["center"])
				var flame_radius := float(effect.get("radius", 42.0))
				draw_circle(flame_center, flame_radius * (1.12 - alpha * 0.12), Color(color, color.a * 0.11))
				draw_arc(flame_center, flame_radius, 0.0, TAU, 18, color, 5.0)
			"security_frost":
				var frost_center := Vector2(effect["center"])
				var frost_radius := float(effect.get("radius", 48.0))
				draw_arc(frost_center, frost_radius, 0.0, TAU, 20, color, 4.0)
				for frost_index in range(6):
					var frost_direction := Vector2.from_angle(TAU * float(frost_index) / 6.0)
					draw_line(frost_center, frost_center + frost_direction * frost_radius, Color(color, color.a * 0.58), 2.0)
			"security_lightning":
				var lightning_start := Vector2(effect["from"])
				var lightning_end := Vector2(effect["to"])
				var lightning_mid := lightning_start.lerp(lightning_end, 0.5) + (lightning_end - lightning_start).normalized().orthogonal() * 12.0
				draw_polyline(PackedVector2Array([lightning_start, lightning_mid, lightning_end]), color, float(effect.get("width", 4.0)), true)
			"security_lockdown_boot":
				var lockdown_center := Vector2(effect["center"])
				var lockdown_radius := float(effect.get("radius", 520.0)) * (1.10 - alpha * 0.10)
				draw_circle(lockdown_center, lockdown_radius, Color(color, color.a * 0.05))
				draw_arc(lockdown_center, lockdown_radius, 0.0, TAU, 72, color, 12.0)
			"tensor_beam", "prefill_scan":
				var tensor_start := Vector2(effect["from"])
				var tensor_finish := Vector2(effect["to"])
				var tensor_glow := float(effect.get("glow_width", 0.0))
				if tensor_glow > 0.0:
					draw_line(tensor_start, tensor_finish, Color(color, color.a * 0.13), tensor_glow)
				draw_line(tensor_start, tensor_finish, Color(0.90, 1.0, 0.88, color.a * 0.46), float(effect.get("width", 4.0)) + 4.0)
				draw_line(tensor_start, tensor_finish, color, float(effect.get("width", 4.0)))
				var tensor_direction := (tensor_finish - tensor_start).normalized()
				if tensor_direction.length_squared() > 0.01:
					for packet_index in range(3):
						var packet_position := tensor_start.lerp(tensor_finish, 0.26 + float(packet_index) * 0.23)
						var packet_side := tensor_direction.orthogonal() * 5.0
						draw_colored_polygon(PackedVector2Array([packet_position + tensor_direction * 8.0, packet_position - tensor_direction * 5.0 + packet_side, packet_position - tensor_direction * 5.0 - packet_side]), color)
			"tensor_node":
				var tensor_center := Vector2(effect["center"])
				var tensor_size := 15.0 + float(mini(4, int(effect.get("stage", 0)))) * 2.0
				var tensor_rect := Rect2(tensor_center - Vector2.ONE * tensor_size * 0.5, Vector2.ONE * tensor_size)
				draw_rect(tensor_rect, Color(color, color.a * 0.12), true)
				draw_rect(tensor_rect, color, false, 2.0)
				draw_line(tensor_rect.position + Vector2(3.0, tensor_rect.size.y * 0.5), tensor_rect.end - Vector2(3.0, tensor_rect.size.y * 0.5), color, 1.5)
			"pipeline_lane":
				var lane_start := Vector2(effect["from"])
				var lane_finish := Vector2(effect["to"])
				var lane_width := float(effect.get("width", 26.0))
				draw_line(lane_start, lane_finish, Color(color, color.a * 0.08), lane_width * 2.0)
				draw_line(lane_start, lane_finish, Color(color, color.a * 0.50), 2.0)
			"attention_matrix":
				var matrix_rect := Rect2(effect.get("rect", AI_WORLD_RECT))
				draw_rect(matrix_rect, Color(color, color.a * 0.035), true)
				draw_rect(matrix_rect, Color(color, color.a * 0.45), false, 3.0)
				for matrix_x in range(1, 9):
					var x := matrix_rect.position.x + matrix_rect.size.x * float(matrix_x) / 9.0
					draw_line(Vector2(x, matrix_rect.position.y), Vector2(x, matrix_rect.end.y), Color(color, color.a * 0.13), 1.0)
				for matrix_y in range(1, 6):
					var y := matrix_rect.position.y + matrix_rect.size.y * float(matrix_y) / 6.0
					draw_line(Vector2(matrix_rect.position.x, y), Vector2(matrix_rect.end.x, y), Color(color, color.a * 0.18), 1.5)
			"eos_frame":
				var eos_rect := Rect2(effect.get("rect", AI_WORLD_RECT))
				draw_rect(eos_rect, Color(color, color.a * 0.10), true)
				draw_rect(eos_rect.grow(-10.0), color, false, 10.0)
				draw_line(eos_rect.position, eos_rect.end, Color(color, color.a * 0.82), 8.0)
				draw_line(Vector2(eos_rect.end.x, eos_rect.position.y), Vector2(eos_rect.position.x, eos_rect.end.y), Color(color, color.a * 0.82), 8.0)
			"failover_line":
				var line_start := Vector2(effect["from"])
				var line_finish := Vector2(effect["to"])
				var segment_count := 12
				for segment_index in range(segment_count):
					if segment_index % 2 != 0:
						continue
					var segment_start := line_start.lerp(line_finish, float(segment_index) / float(segment_count))
					var segment_finish := line_start.lerp(line_finish, float(segment_index + 1) / float(segment_count))
					draw_line(segment_start, segment_finish, color, float(effect.get("width", 5.0)))
			"trace_path":
				var trace_points := PackedVector2Array(effect.get("points", PackedVector2Array()))
				if trace_points.size() >= 2:
					draw_polyline(trace_points, Color(color, color.a * 0.22), float(effect.get("width", 3.0)) + 7.0, true)
					draw_polyline(trace_points, color, float(effect.get("width", 3.0)), true)
					for trace_index in range(1, trace_points.size()):
						var segment_direction := (trace_points[trace_index] - trace_points[trace_index - 1]).normalized()
						var arrow_position := trace_points[trace_index - 1].lerp(trace_points[trace_index], 0.72)
						var arrow_side := segment_direction.orthogonal() * 6.0
						draw_colored_polygon(PackedVector2Array([arrow_position + segment_direction * 8.0, arrow_position - segment_direction * 5.0 + arrow_side, arrow_position - segment_direction * 5.0 - arrow_side]), color)
			"span_marker", "span_hit":
				var marker_center := Vector2(effect["center"])
				var marker_size := Vector2(effect.get("size", Vector2(42.0, 18.0))) * (0.78 + alpha * 0.22)
				var marker_rect := Rect2(marker_center - marker_size * 0.5, marker_size)
				draw_rect(marker_rect, Color(color, color.a * 0.10), true)
				draw_rect(marker_rect, color, false, 2.0)
				draw_line(marker_rect.position + Vector2(5.0, marker_rect.size.y * 0.50), marker_rect.end - Vector2(5.0, marker_rect.size.y * 0.50), color, 2.0)
			"site_marker":
				_draw_sre_site(Vector2(effect["center"]), String(effect.get("label", "AZ")), color, alpha)
			"acceptance_stamp":
				var stamp_center := Vector2(effect["center"])
				var stamp_size := Vector2(effect.get("size", Vector2(210.0, 90.0))) * (0.86 + alpha * 0.14)
				var stamp_rect := Rect2(stamp_center - stamp_size * 0.5, stamp_size)
				draw_rect(stamp_rect, Color(color, color.a * 0.06), true)
				draw_rect(stamp_rect, color, false, 7.0)
				draw_line(stamp_center + Vector2(-stamp_size.x * 0.24, 0.0), stamp_center + Vector2(-stamp_size.x * 0.06, stamp_size.y * 0.20), color, 8.0)
				draw_line(stamp_center + Vector2(-stamp_size.x * 0.06, stamp_size.y * 0.20), stamp_center + Vector2(stamp_size.x * 0.27, -stamp_size.y * 0.25), color, 8.0)
			"wave_banner":
				var banner_center := Vector2(effect["center"])
				var wave := int(effect.get("wave", 1))
				for bar_index in range(3):
					var bar_rect := Rect2(banner_center + Vector2(float(bar_index - 1) * 34.0 - 11.0, -8.0), Vector2(22.0, 16.0))
					draw_rect(bar_rect, Color(color, color.a * (0.92 if bar_index < wave else 0.18)), true)
			"arc": draw_arc(Vector2(effect["center"]), float(effect["radius"]), float(effect["start"]), float(effect["end"]), 28, color, 7.0)
			"blast":
				draw_circle(Vector2(effect["center"]), float(effect["radius"]) * (1.0 - alpha * 0.15), Color(color, color.a * 0.10))
				draw_arc(Vector2(effect["center"]), float(effect["radius"]), 0.0, TAU, 42, color, 4.0)
			"marker":
				draw_arc(Vector2(effect["center"]), float(effect["radius"]), 0.0, TAU, 32, color, 2.0)
				draw_line(Vector2(effect["center"]) + Vector2(-12, 0), Vector2(effect["center"]) + Vector2(12, 0), color, 2.0)
			"range_preview_circle":
				var preview_center := Vector2(effect["center"])
				var preview_radius := float(effect["radius"])
				var preview_alpha := float(effect.get("alpha_scale", 1.0))
				var preview_color := Color(color, color.a * preview_alpha)
				draw_arc(preview_center, preview_radius, 0.0, TAU, 48, preview_color, 3.0)
				for tick_index in range(8):
					var tick_direction := Vector2.from_angle(TAU * float(tick_index) / 8.0)
					draw_line(preview_center + tick_direction * (preview_radius - 8.0), preview_center + tick_direction * (preview_radius + 8.0), preview_color, 2.0)
			"range_preview_line":
				var preview_start := Vector2(effect["from"])
				var preview_finish := Vector2(effect["to"])
				var preview_width := float(effect["half_width"]) * 2.0
				draw_line(preview_start, preview_finish, Color(color, color.a * 0.16), preview_width)
				draw_line(preview_start, preview_finish, color, 3.0)
			_:
				draw_arc(Vector2(effect["center"]), float(effect["radius"]), 0.0, TAU, 48, color, 3.0)


func _exit_tree() -> void:
	if combat != null and combat.has_method("set_temporary_damage_multiplier"):
		combat.call("set_temporary_damage_multiplier", 1.0)
	if player != null and player.has_method("set_temporary_damage_reduction"):
		player.call("set_temporary_damage_reduction", 0.0)
