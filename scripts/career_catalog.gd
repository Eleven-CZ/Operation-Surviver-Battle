class_name CareerCatalog
extends RefCounted

const EMBLEM_ATLAS_PATH := "res://assets/generated/career_emblems_5x2.png"
const SPRITE_ATLAS_PATH := "res://assets/generated/career_sprites_5x2.png"


static func all() -> Array[Dictionary]:
	return [
		{
			"id": "ops",
			"name": "运维工程师",
			"badge": "OPS",
			"domain": "通才 / 值班响应",
			"description": "贴身抢修通才，以扳手三连击和 sudo 震地清理近身故障，构筑自由度最高。",
			"mechanic": "终端重击：130° 近战横扫，第三击全向震地；抢修突进可穿过故障群。",
			"passive": "全栈值守 · 近战固有攻击，拾取范围 +20%，三工具触发跨域联动",
			"starting_upgrades": [],
			"stats": {"health": 1.0, "move_speed": 1.04, "damage_reduction": 0.0, "xp": 1.0, "magnet": 1.20, "regen": 0.0, "projection": 1.0},
			"combat": {"damage": 1.0, "cooldown": 1.0, "area": 1.0, "melee": 1.0, "control": 1.0, "summons": 0},
			"color": "56e6dc",
			"unlock": "初始职业",
		},
		{
			"id": "dba",
			"name": "DBA",
			"badge": "DB",
			"domain": "数据基础设施 / 事务治理",
			"description": "用慢查询锁域建立阵地，先控制事务范围，再集中清算。",
			"mechanic": "慢查询锁域：延迟布置事务区；ROLLBACK 回位，全库 COMMIT 同时清算。",
			"passive": "一致性优先 · 控制持续 +28%，区域 +12%，18 次关闭触发 COMMIT",
			"starting_upgrades": [],
			"stats": {"health": 1.06, "move_speed": 0.95, "damage_reduction": 0.03, "xp": 1.0, "magnet": 1.0, "regen": 0.0, "projection": 1.0},
			"combat": {"damage": 1.0, "cooldown": 1.04, "area": 1.12, "melee": 1.0, "control": 1.28, "summons": 0},
			"color": "c68cff",
			"unlock": "单局将慢查询锁域叠至 STACK 3",
		},
		{
			"id": "network",
			"name": "网络工程师",
			"badge": "NET",
			"domain": "网络 / 链路收敛",
			"description": "以远距离 ICMP 贯穿探针建立外圈优势，保持移动维持链路覆盖。",
			"mechanic": "抓包：建立 8 秒分析区，区内总攻击 +15%；网络风暴执行大范围多段 AOE。",
			"passive": "低延迟路径 · 640px 固有射程，冷却 -9%，移动触发链路收敛",
			"starting_upgrades": [],
			"stats": {"health": 0.92, "move_speed": 1.10, "damage_reduction": 0.0, "xp": 1.0, "magnet": 1.0, "regen": 0.0, "projection": 1.0},
			"combat": {"damage": 0.97, "cooldown": 0.91, "area": 1.08, "melee": 0.92, "control": 1.0, "summons": 0},
			"color": "47c9f1",
			"unlock": "单局将 Ping 扫描叠至 STACK 3",
		},
		{
			"id": "security",
			"name": "安全运维",
			"badge": "SOC",
			"domain": "安全 / 纵深防御",
			"description": "持续部署线性零信任防火墙，用隔离走廊切割敌群并保护安全空间。",
			"mechanic": "范围墙：灼烧、减速并推回越界故障；大招生成六边形全域封禁。",
			"passive": "最小权限 · 固有持续墙，伤害减免 10%，受击自动隔离",
			"starting_upgrades": [],
			"stats": {"health": 1.12, "move_speed": 0.96, "damage_reduction": 0.10, "xp": 1.0, "magnet": 1.0, "regen": 0.0, "projection": 1.0},
			"combat": {"damage": 0.96, "cooldown": 1.05, "area": 1.06, "melee": 1.0, "control": 1.12, "summons": 0},
			"color": "ee6677",
			"unlock": "单局将防火墙叠至 STACK 3",
		},
		{
			"id": "it_ops",
			"name": "IT 运维",
			"badge": "IT",
			"domain": "终端 / 机房现场",
			"description": "围绕可修复服务并周期放电的备件节点作战，建立机房现场阵地。",
			"mechanic": "备件节点：最多部署三台；热插拔同步放电，机房总控投放重型机柜。",
			"passive": "备件随身 · 健康度 +18%，节点附近持续修复，近身六连关单恢复",
			"starting_upgrades": [],
			"stats": {"health": 1.18, "move_speed": 0.98, "damage_reduction": 0.04, "xp": 0.96, "magnet": 0.95, "regen": 0.0, "projection": 1.0},
			"combat": {"damage": 1.02, "cooldown": 0.98, "area": 1.04, "melee": 1.22, "control": 1.0, "summons": 0},
			"color": "ffae62",
			"unlock": "单局将机柜扳手叠至 STACK 3",
		},
		{
			"id": "helpdesk",
			"name": "Helpdesk",
			"badge": "SLA",
			"domain": "用户支持 / SLA",
			"description": "更快获得处置经验，也更擅长化解压力投影并将同事转为盟友。",
			"mechanic": "工单分派：自动在多目标间弹跳；远程协助批量标记并削弱压力外壳。",
			"passive": "首问负责 · 经验 +14%，协作对齐 +100%，十二单形成 SLA 批次",
			"starting_upgrades": [],
			"stats": {"health": 0.96, "move_speed": 1.04, "damage_reduction": 0.02, "xp": 1.14, "magnet": 1.10, "regen": 0.0, "projection": 2.0},
			"combat": {"damage": 0.94, "cooldown": 0.96, "area": 1.0, "melee": 1.0, "control": 1.0, "summons": 0},
			"color": "f0ca5a",
			"unlock": "成功化解一次产品压力投影",
		},
		{
			"id": "opsdev",
			"name": "运维开发",
			"badge": "DEV",
			"domain": "自动化 / 工具开发",
			"description": "固有幂等脚本会在命中位置重复执行，最早形成自动化流水线，但健康度较低。",
			"mechanic": "幂等重试：命中自动复刻；CI Runner 重放任务，IaC Apply 执行三阶段全场变更。",
			"passive": "减少手工操作 · 伤害 +9%，冷却 -6%，十四次关闭触发重试",
			"starting_upgrades": ["idempotency"],
			"stats": {"health": 0.86, "move_speed": 1.02, "damage_reduction": 0.0, "xp": 1.0, "magnet": 1.0, "regen": 0.0, "projection": 1.0},
			"combat": {"damage": 1.09, "cooldown": 0.94, "area": 1.0, "melee": 0.96, "control": 1.0, "summons": 0},
			"color": "9cff72",
			"unlock": "完成一次基础设施即代码进化",
		},
		{
			"id": "sre",
			"name": "SRE",
			"badge": "SLO",
			"domain": "可靠性 / 错误预算",
			"description": "自适应 SLO 扩张环会根据健康度切换伤害或恢复，偏向稳定运行和事故闭环。",
			"mechanic": "预算环：健康时高伤、危急时击退恢复；流量切换与预算冻结提供止损窗口。",
			"passive": "稳定窗口 · 每秒恢复 0.35 健康，减伤 5%，错误预算自动止损",
			"starting_upgrades": ["runbook"],
			"stats": {"health": 1.04, "move_speed": 1.0, "damage_reduction": 0.05, "xp": 1.04, "magnet": 1.0, "regen": 0.35, "projection": 1.0},
			"combat": {"damage": 0.95, "cooldown": 0.96, "area": 1.04, "melee": 1.0, "control": 1.10, "summons": 0},
			"color": "65e890",
			"unlock": "恢复验证通过且剩余健康度不低于 50%",
		},
		{
			"id": "delivery",
			"name": "实施交付",
			"badge": "UAT",
			"domain": "部署 / 验收交接",
			"description": "投放延迟爆发的发布包并留下 UAT 验收区，以灰度节奏完成交付闭环。",
			"mechanic": "蓝绿切换同时位移、爆破与恢复；全量上线按 10% / 30% / 100% 三段扩张。",
			"passive": "验收留痕 · Runbook ×1，协作对齐 +35%，发布闭环触发评审",
			"starting_upgrades": ["runbook"],
			"stats": {"health": 0.98, "move_speed": 1.03, "damage_reduction": 0.02, "xp": 1.06, "magnet": 1.08, "regen": 0.0, "projection": 1.35},
			"combat": {"damage": 0.94, "cooldown": 0.96, "area": 1.06, "melee": 0.92, "control": 1.05, "summons": 0},
			"color": "ffce73",
			"unlock": "成功完成一次线上发布窗口",
		},
		{
			"id": "ai_infra",
			"name": "AI Infra",
			"badge": "GPU",
			"domain": "GPU 集群 / 弹性训练",
			"description": "Worker Pod 召唤开局，以副本数量换取覆盖面和自主输出。",
			"mechanic": "自主编队：Pod 从独立位置齐射；Pod 迁移重定位，GPU 扩容临时增加六个 Worker。",
			"passive": "期望副本 · Worker +1，召唤伤害 +8%，二十次关闭刷新齐射",
			"starting_upgrades": [],
			"stats": {"health": 0.90, "move_speed": 0.94, "damage_reduction": 0.0, "xp": 1.0, "magnet": 1.0, "regen": 0.0, "projection": 1.0},
			"combat": {"damage": 1.0, "cooldown": 1.02, "area": 1.0, "melee": 0.90, "control": 1.0, "summons": 1, "summon_damage": 1.08},
			"color": "91ee70",
			"unlock": "单局将 Worker Pod 叠至 STACK 3",
		},
	]


static func get_by_id(career_id: String) -> Dictionary:
	for career in all():
		if String(career["id"]) == career_id:
			return career
	return all()[0]


static func ids() -> Array[String]:
	var result: Array[String] = []
	for career in all():
		result.append(String(career["id"]))
	return result


static func emblem_texture(career_id: String) -> Texture2D:
	if not ResourceLoader.exists(EMBLEM_ATLAS_PATH):
		return null
	var source: Texture2D = load(EMBLEM_ATLAS_PATH)
	var career_index := ids().find(career_id)
	if source == null or career_index < 0:
		return null
	var column := career_index % 5
	var row := floori(float(career_index) / 5.0)
	var x0 := floori(float(source.get_width()) * float(column) / 5.0)
	var x1 := floori(float(source.get_width()) * float(column + 1) / 5.0)
	var y0 := floori(float(source.get_height()) * float(row) / 2.0)
	var y1 := floori(float(source.get_height()) * float(row + 1) / 2.0)
	var cell_width := x1 - x0
	var cell_height := y1 - y0
	var side := mini(cell_width, cell_height)
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(x0, y0 + (cell_height - side) / 2, side, side)
	atlas.filter_clip = true
	return atlas


static func sprite_texture(career_id: String) -> Texture2D:
	if not ResourceLoader.exists(SPRITE_ATLAS_PATH):
		return emblem_texture(career_id)
	var source: Texture2D = load(SPRITE_ATLAS_PATH)
	var career_index := ids().find(career_id)
	if source == null or career_index < 0:
		return null
	var column := career_index % 5
	var row := floori(float(career_index) / 5.0)
	var x0 := floori(float(source.get_width()) * float(column) / 5.0)
	var x1 := floori(float(source.get_width()) * float(column + 1) / 5.0)
	var y0 := floori(float(source.get_height()) * float(row) / 2.0)
	var y1 := floori(float(source.get_height()) * float(row + 1) / 2.0)
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(x0, y0, x1 - x0, y1 - y0)
	atlas.filter_clip = true
	return atlas
