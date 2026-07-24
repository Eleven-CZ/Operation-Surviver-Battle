class_name FaultCatalog
extends RefCounted


const FAULT_SPRITES := preload("res://assets/generated/fault_sprites_4x2.png")


static func all() -> Array[Dictionary]:
	return [
		{
			"id": "http_404",
			"kind": 0,
			"name": "404 NOT FOUND",
			"badge": "404",
			"category": "fault",
			"tier": "普通故障",
			"color": "ff8678",
			"description": "最常见的缺失资源故障，会沿最短路径直接追踪值班工程师。",
			"effect": "基础生命 18 · 基础移速 74 · 接触伤害 5",
			"cell": Vector2i(0, 0),
		},
		{
			"id": "nxdomain",
			"kind": 1,
			"name": "NXDOMAIN",
			"badge": "DNS",
			"category": "fault",
			"tier": "普通故障",
			"color": "6eefff",
			"description": "解析失败故障，周期性横向漂移并向玩家方向跳步，容易突然切入侧翼。",
			"effect": "基础生命 26 · 基础移速 58 · 每 2.6–4.0 秒链路漂移",
			"cell": Vector2i(1, 0),
		},
		{
			"id": "enospc",
			"kind": 2,
			"name": "ENOSPC",
			"badge": "DISK",
			"category": "fault",
			"tier": "普通故障",
			"color": "e8c455",
			"description": "磁盘空间耗尽故障，存活越久体积越大、移动越慢，会逐渐封锁走位空间。",
			"effect": "基础生命 64 · 基础移速 36 · 击杀经验 4",
			"cell": Vector2i(2, 0),
		},
		{
			"id": "bug",
			"kind": 3,
			"name": "BUG",
			"badge": "BUG",
			"category": "fault",
			"tier": "普通故障",
			"color": "ff9c48",
			"description": "高速游走的代码缺陷，以蛇形轨迹逼近，是最容易穿过火力空隙的普通故障。",
			"effect": "基础生命 14 · 基础移速 118 · 额外移动倍率 ×1.18",
			"cell": Vector2i(3, 0),
		},
		{
			"id": "timeout_408",
			"kind": 4,
			"name": "408 TIMEOUT",
			"badge": "408",
			"category": "fault",
			"tier": "普通故障",
			"color": "ffe274",
			"description": "延迟故障，靠近后会周期性施加超时减速，打乱撤离节奏。",
			"effect": "基础生命 34 · 基础移速 50 · 185 范围内施加 1.25 秒减速",
			"cell": Vector2i(0, 1),
		},
		{
			"id": "elite_502",
			"kind": 5,
			"name": "502 UPSTREAM",
			"badge": "502",
			"category": "fault",
			"tier": "精英故障",
			"color": "3ee6ef",
			"description": "上游网关精英，携带随机词缀和可恢复护盾，并持续扇出新的 404 故障。",
			"effect": "基础生命 420 · 每 4.2 秒召唤 404 · 击杀可掉落神器",
			"cell": Vector2i(1, 1),
		},
		{
			"id": "elite_oom",
			"kind": 6,
			"name": "OOM 137",
			"badge": "OOM",
			"category": "fault",
			"tier": "精英故障",
			"color": "65e890",
			"description": "内存溢出精英，携带随机词缀和可恢复护盾，周期性释放过载冲击区。",
			"effect": "基础生命 520 · 每 5 秒释放过载脉冲 · 击杀可掉落神器",
			"cell": Vector2i(2, 1),
		},
		{
			"id": "incident_core",
			"kind": 7,
			"name": "FATAL / INCIDENT CORE",
			"badge": "FATAL",
			"category": "boss",
			"tier": "事故核心",
			"color": "ff6558",
			"description": "本次事故的根因核心。先收集线索解除隔离，再击穿护盾和本体，最后完成恢复验证。",
			"effect": "基础生命 1600 · 召唤 404 · 熔火、冻结、漂移、雷击、护盾与霸体全协议",
			"cell": Vector2i(3, 1),
		},
	]


static func ids() -> Array[String]:
	var result: Array[String] = []
	for definition in all():
		result.append(String(definition["id"]))
	return result


static func fault_ids() -> Array[String]:
	var result: Array[String] = []
	for definition in all():
		if String(definition.get("category", "fault")) == "fault":
			result.append(String(definition["id"]))
	return result


static func boss_ids() -> Array[String]:
	var result: Array[String] = []
	for definition in all():
		if String(definition.get("category", "fault")) == "boss":
			result.append(String(definition["id"]))
	return result


static func get_by_id(fault_id: String) -> Dictionary:
	for definition in all():
		if String(definition["id"]) == fault_id:
			return definition
	return {}


static func id_for_kind(kind: int) -> String:
	for definition in all():
		if int(definition["kind"]) == kind:
			return String(definition["id"])
	return ""


static func category_for_kind(kind: int) -> String:
	var definition := get_by_id(id_for_kind(kind))
	return String(definition.get("category", "fault"))


static func sprite_texture(fault_id: String) -> Texture2D:
	var definition := get_by_id(fault_id)
	if definition.is_empty():
		return null
	var cell_size := Vector2(float(FAULT_SPRITES.get_width()) / 4.0, float(FAULT_SPRITES.get_height()) / 2.0)
	var cell := Vector2(definition.get("cell", Vector2i.ZERO))
	var texture := AtlasTexture.new()
	texture.atlas = FAULT_SPRITES
	texture.region = Rect2(cell * cell_size + Vector2(2, 2), cell_size - Vector2(4, 4))
	return texture
