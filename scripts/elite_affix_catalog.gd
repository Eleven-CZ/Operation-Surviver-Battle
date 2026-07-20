class_name EliteAffixCatalog
extends RefCounted


enum Affix {
	MOLTEN = 1,
	FROZEN = 2,
	SHIELDED = 4,
	UNSTOPPABLE = 8,
	TELEPORTER = 16,
	VOLATILE = 32,
	STORMCALLER = 64,
}

const ORDER: Array[int] = [
	Affix.MOLTEN,
	Affix.FROZEN,
	Affix.SHIELDED,
	Affix.UNSTOPPABLE,
	Affix.TELEPORTER,
	Affix.VOLATILE,
	Affix.STORMCALLER,
]
const ACTIVE_AFFIXES: Array[int] = [Affix.MOLTEN, Affix.FROZEN, Affix.TELEPORTER, Affix.STORMCALLER]
const PASSIVE_AFFIXES: Array[int] = [Affix.SHIELDED, Affix.UNSTOPPABLE, Affix.VOLATILE]
const DEFINITIONS := {
	Affix.MOLTEN: {
		"id": "molten",
		"name": "熔火日志",
		"badge": "FIRE",
		"color": "ff6b3d",
		"role": "地面压制",
		"description": "在玩家路径附近写入持续燃烧的故障地板，死亡时仍可能留下危险区。",
	},
	Affix.FROZEN: {
		"id": "frozen",
		"name": "冻结锁",
		"badge": "FROST",
		"color": "68d8ff",
		"role": "控场",
		"description": "预警后触发冻结脉冲，造成伤害并显著降低移动速度。",
	},
	Affix.SHIELDED: {
		"id": "shielded",
		"name": "变更护盾",
		"badge": "SHIELD",
		"color": "45f0e2",
		"role": "防御",
		"description": "获得可视化护盾并周期性恢复，必须先击穿护盾才能伤及本体。",
	},
	Affix.UNSTOPPABLE: {
		"id": "unstoppable",
		"name": "霸体进程",
		"badge": "ROOT",
		"color": "ffb347",
		"role": "防御",
		"description": "免疫减速与击退，但不会免疫伤害。与变更护盾互斥。",
	},
	Affix.TELEPORTER: {
		"id": "teleporter",
		"name": "链路漂移",
		"badge": "BLINK",
		"color": "df78ff",
		"role": "位移",
		"description": "标记落点后瞬移到玩家侧翼，落地会产生小范围冲击。",
	},
	Affix.VOLATILE: {
		"id": "volatile",
		"name": "崩溃自爆",
		"badge": "PANIC",
		"color": "ff4057",
		"role": "死亡威胁",
		"description": "被关闭后进入延迟爆炸，红色倒计时结束时造成高额范围伤害。",
	},
	Affix.STORMCALLER: {
		"id": "stormcaller",
		"name": "雷暴告警",
		"badge": "STORM",
		"color": "ffe45c",
		"role": "远程压制",
		"description": "锁定玩家当前位置投放雷击十字标记，短暂预警后落雷。",
	},
}


static func count_for_difficulty(difficulty_id: String) -> int:
	return 1 if difficulty_id == "normal" else 2


static func roll_mask(rng: RandomNumberGenerator, difficulty_id: String, preferred_active: Array[int] = []) -> int:
	var wanted := count_for_difficulty(difficulty_id)
	var result := 0
	var active_pool := preferred_active.duplicate()
	if active_pool.is_empty():
		active_pool = ACTIVE_AFFIXES.duplicate()
	result |= active_pool[rng.randi_range(0, active_pool.size() - 1)]
	var candidates := PASSIVE_AFFIXES.duplicate()
	while bit_count(result) < wanted and not candidates.is_empty():
		var candidate_index := rng.randi_range(0, candidates.size() - 1)
		var candidate := int(candidates.pop_at(candidate_index))
		if has(result, candidate) or _conflicts(result, candidate):
			continue
		result |= candidate
	return result


static func has(mask: int, affix: int) -> bool:
	return (mask & affix) != 0


static func bit_count(mask: int) -> int:
	var value := mask
	var result := 0
	while value > 0:
		result += value & 1
		value >>= 1
	return result


static func active_from_mask(mask: int) -> Array[int]:
	var result: Array[int] = []
	for affix in ACTIVE_AFFIXES:
		if has(mask, affix):
			result.append(affix)
	return result


static func names_from_mask(mask: int) -> Array[String]:
	var result: Array[String] = []
	for affix in ORDER:
		if has(mask, affix):
			result.append(String(DEFINITIONS[affix]["name"]))
	return result


static func definition(affix: int) -> Dictionary:
	return Dictionary(DEFINITIONS.get(affix, {}))


static func _conflicts(mask: int, candidate: int) -> bool:
	return (
		candidate == Affix.SHIELDED and has(mask, Affix.UNSTOPPABLE)
		or candidate == Affix.UNSTOPPABLE and has(mask, Affix.SHIELDED)
		or candidate == Affix.VOLATILE and has(mask, Affix.MOLTEN)
	)
