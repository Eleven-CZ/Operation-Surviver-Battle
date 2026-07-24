class_name EventCatalog
extends RefCounted


static func all() -> Array[Dictionary]:
	return [
		{
			"id": "release",
			"name": "线上发布",
			"badge": "DEPLOY",
			"category": "变更",
			"color": "ef74dd",
			"description": "在发布窗口中处理回归故障，并把产品压力投影化解为 War Room 盟友。",
			"objective": "关闭回归故障，并完成验收标准对齐",
			"success_reward": 8,
			"partial_reward": 4,
			"career_bonuses": {
				"delivery": "验收清单：目标数 -4",
				"opsdev": "流水线自动化：窗口 +8 秒",
				"helpdesk": "首问负责：压力对齐速度 ×2",
				"sre": "变更守护：敌群压力 -10%",
			},
			"strategies": [
				{"id": "canary", "name": "金丝雀发布", "detail": "敌群 -20% · 关闭 18 个回归故障 · 标准奖励", "persona_id": "product", "spawn_multiplier": 0.80, "targets": 18, "duration": 62.0, "risk_bonus": 0, "wave_count": 10, "wave": ["BUG", "HTTP_404", "TIMEOUT_408"]},
				{"id": "full", "name": "直接全量", "detail": "敌群 +35% · 关闭 28 个回归故障 · 成功额外 +12 RP", "persona_id": "leader", "spawn_multiplier": 1.35, "targets": 28, "duration": 62.0, "risk_bonus": 12, "wave_count": 16, "wave": ["BUG", "HTTP_404", "TIMEOUT_408"]},
				{"id": "rollback", "name": "先建回滚点", "detail": "标准敌群 · 关闭 22 个故障 · 超时保留部分结果", "persona_id": "qa", "spawn_multiplier": 1.00, "targets": 22, "duration": 62.0, "risk_bonus": 0, "partial_on_timeout": true, "wave_count": 12, "wave": ["BUG", "HTTP_404", "TIMEOUT_408"]},
			],
		},
		{
			"id": "version_update",
			"name": "版本更新",
			"badge": "UPDATE",
			"category": "变更",
			"color": "70caff",
			"description": "更新生产节点并清理兼容性回归；策略决定并发范围、健康检查窗口和风险奖励。",
			"objective": "关闭兼容性回归，并通过更新后健康检查",
			"success_reward": 8,
			"partial_reward": 4,
			"career_bonuses": {
				"it_ops": "兼容矩阵：目标数 -4",
				"opsdev": "自动升级：窗口 +8 秒",
				"sre": "健康检查：敌群压力 -10%",
				"delivery": "现场验收：目标数 -3",
			},
			"strategies": [
				{"id": "rolling", "name": "滚动更新", "detail": "逐批替换节点 · 压力 -10% · 关闭 20 个回归故障", "persona_id": "frontend", "spawn_multiplier": 0.90, "targets": 20, "duration": 60.0, "risk_bonus": 0, "wave_count": 12, "wave": ["BUG", "HTTP_404", "NXDOMAIN"]},
				{"id": "in_place", "name": "原地升级", "detail": "窗口最短 · 压力 +30% · 成功额外 +8 RP", "persona_id": "backend", "spawn_multiplier": 1.30, "targets": 28, "duration": 55.0, "risk_bonus": 8, "wave_count": 18, "wave": ["BUG", "HTTP_404", "TIMEOUT_408"]},
				{"id": "blue_green", "name": "蓝绿切换", "detail": "双环境校验 · 压力 +5% · 成功额外 +4 RP", "persona_id": "supervisor", "spawn_multiplier": 1.05, "targets": 22, "duration": 65.0, "risk_bonus": 4, "wave_count": 14, "wave": ["BUG", "NXDOMAIN", "TIMEOUT_408"]},
			],
		},
		{
			"id": "troubleshoot",
			"name": "线上救火",
			"badge": "P1",
			"category": "诊断",
			"color": "ff9b72",
			"description": "从指标、日志或链路入手，关闭匹配症状来收集根因证据；成功会降低最终事故的分诊成本。",
			"objective": "收集根因证据，并形成可验证的故障假设",
			"success_reward": 8,
			"partial_reward": 4,
			"career_bonuses": {
				"dba": "指标研判：指标证据 +1",
				"network": "链路追踪：链路证据 +1",
				"opsdev": "日志检索：日志证据 +1",
				"sre": "事故指挥：诊断窗口 +8 秒",
			},
			"strategies": [
				{"id": "metrics", "name": "指标优先", "detail": "关注容量与超时 · 收集 8 份证据", "persona_id": "supervisor", "spawn_multiplier": 1.00, "targets": 8, "duration": 60.0, "risk_bonus": 0, "wave_count": 15, "wave": ["ENOSPC", "TIMEOUT_408", "HTTP_404"], "evidence": ["ENOSPC", "TIMEOUT_408"]},
				{"id": "logs", "name": "日志下钻", "detail": "关注异常与回归 · 窗口更短 · 成功额外 +4 RP", "persona_id": "hr", "spawn_multiplier": 1.08, "targets": 8, "duration": 56.0, "risk_bonus": 4, "wave_count": 15, "wave": ["BUG", "HTTP_404", "ENOSPC"], "evidence": ["BUG", "HTTP_404"]},
				{"id": "traces", "name": "链路追踪", "detail": "关注 DNS 与超时路径 · 压力 +18% · 成功额外 +8 RP", "persona_id": "customer", "spawn_multiplier": 1.18, "targets": 10, "duration": 52.0, "risk_bonus": 8, "wave_count": 17, "wave": ["NXDOMAIN", "TIMEOUT_408", "HTTP_404"], "evidence": ["NXDOMAIN", "TIMEOUT_408"]},
			],
		},
		{
			"id": "backup_restore",
			"name": "备份恢复演练",
			"badge": "RTO",
			"category": "演练",
			"color": "65e890",
			"description": "保护恢复节点、清理校验故障并在 RTO 内恢复数据；恢复完成但完整性不足只算部分成功。",
			"objective": "守住恢复节点，在 RTO 内完成恢复与完整性校验",
			"success_reward": 8,
			"partial_reward": 4,
			"career_bonuses": {
				"dba": "一致性校验：完整性衰减 -35%",
				"sre": "恢复编排：完整性衰减 -25%",
				"it_ops": "现场备件：每次近点关单恢复更多完整性",
				"delivery": "恢复验收：目标数 -3",
			},
			"strategies": [
				{"id": "snapshot", "name": "快照恢复", "detail": "RTO 最短 · 起始完整性 75 · 关闭 14 个校验故障", "persona_id": "finance", "spawn_multiplier": 0.90, "targets": 14, "duration": 52.0, "risk_bonus": 0, "integrity_start": 75.0, "integrity_min": 42.0, "decay_rate": 0.70, "wave_count": 13, "wave": ["ENOSPC", "BUG", "HTTP_404"]},
				{"id": "pitr", "name": "时间点恢复", "detail": "平衡 RPO / RTO · 起始完整性 90 · 成功额外 +4 RP", "persona_id": "qa", "spawn_multiplier": 1.05, "targets": 18, "duration": 60.0, "risk_bonus": 4, "integrity_start": 90.0, "integrity_min": 50.0, "decay_rate": 0.58, "wave_count": 16, "wave": ["ENOSPC", "TIMEOUT_408", "BUG"]},
				{"id": "full_restore", "name": "全量恢复", "detail": "数据最完整 · 敌群 +25% · 成功额外 +8 RP", "persona_id": "leader", "spawn_multiplier": 1.25, "targets": 24, "duration": 66.0, "risk_bonus": 8, "integrity_start": 100.0, "integrity_min": 60.0, "decay_rate": 0.48, "wave_count": 20, "wave": ["ENOSPC", "TIMEOUT_408", "NXDOMAIN"]},
			],
		},
	]


static func ids() -> Array[String]:
	var result: Array[String] = []
	for event in all():
		result.append(String(event["id"]))
	return result


static func get_by_id(event_id: String) -> Dictionary:
	for event in all():
		if String(event["id"]) == event_id:
			return event
	return all()[0]


static func get_strategy(event_id: String, strategy_id: String) -> Dictionary:
	var event := get_by_id(event_id)
	for strategy in event.get("strategies", []):
		if String(strategy["id"]) == strategy_id:
			return strategy
	return Dictionary(event["strategies"][0])


static func bonus_for(event_id: String, career_id: String) -> String:
	var bonuses: Dictionary = get_by_id(event_id).get("career_bonuses", {})
	return String(bonuses.get(career_id, "本岗位无额外合同修正，仍可正常完成事件"))
