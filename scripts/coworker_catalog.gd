class_name CoworkerCatalog
extends RefCounted


static func all() -> Array[Dictionary]:
	return [
		{
			"id": "hr",
			"name": "HR 伙伴",
			"badge": "HR",
			"role": "保护 / 救急",
			"ability": "心理安全网",
			"description": "健康低于 45% 时强制调休：恢复健康并提供短暂无敌窗口。",
			"cooldown": 26.0,
			"color": "ff86c8",
			"sprite_index": 0,
		},
		{
			"id": "finance",
			"name": "财务伙伴",
			"badge": "FIN",
			"role": "资源 / 多目标",
			"ability": "成本审计",
			"description": "审计多个故障并追回额外遥测水晶。",
			"cooldown": 8.5,
			"color": "ffd45e",
			"sprite_index": 1,
		},
		{
			"id": "product",
			"name": "产品经理",
			"badge": "PM",
			"role": "控场 / 击退",
			"ability": "需求冻结",
			"description": "冻结范围内的需求变更，使故障群减速并后退。",
			"cooldown": 9.0,
			"color": "ef74dd",
			"sprite_index": 2,
		},
		{
			"id": "frontend",
			"name": "前端开发",
			"badge": "FE",
			"role": "远程 / 穿透",
			"ability": "告警可视化",
			"description": "持续绘制告警链路，自动贯穿多名近距离故障。",
			"cooldown": 2.4,
			"color": "50d9ff",
			"sprite_index": 3,
		},
		{
			"id": "backend",
			"name": "后端开发",
			"badge": "BE",
			"role": "爆发 / 范围",
			"ability": "异步队列",
			"description": "把最近的故障批量入队，在目标位置执行范围结算。",
			"cooldown": 4.2,
			"color": "8f8cff",
			"sprite_index": 4,
		},
		{
			"id": "qa",
			"name": "测试工程师",
			"badge": "QA",
			"role": "持续治疗",
			"ability": "回归绿灯",
			"description": "只在健康受损时运行回归，每隔数秒缓慢恢复约 1.4% 最大健康。",
			"cooldown": 3.8,
			"color": "68f2a2",
			# The current coworker sheet is 4x2. QA temporarily shares the tablet
			# silhouette, then receives a unique QA badge and green regression FX.
			"sprite_index": 3,
		},
		{
			"id": "leader",
			"name": "业务领导",
			"badge": "LEAD",
			"role": "清场 / 解围",
			"ability": "拍板清障",
			"description": "周期性拍板一次，造成大范围高额伤害和强力击退。",
			"cooldown": 13.0,
			"color": "ff8b67",
			"sprite_index": 5,
		},
		{
			"id": "customer",
			"name": "客户代表",
			"badge": "USER",
			"role": "单体 / 点杀",
			"ability": "稳定复现",
			"description": "锁定最近的高优故障，稳定复现并造成高额单体伤害。",
			"cooldown": 5.2,
			"color": "ff657e",
			"sprite_index": 6,
		},
		{
			"id": "supervisor",
			"name": "技术主管",
			"badge": "TL",
			"role": "调度 / 冷却",
			"ability": "值班调度",
			"description": "重新安排值班队列，推进职业小技能与大招冷却。",
			"cooldown": 8.0,
			"color": "66e8d1",
			"sprite_index": 7,
		},
	]


static func ids() -> Array[String]:
	var result: Array[String] = []
	for definition in all():
		result.append(String(definition.get("id", "")))
	return result


static func get_by_id(persona_id: String) -> Dictionary:
	for definition in all():
		if String(definition.get("id", "")) == persona_id:
			return definition
	return all()[2]


static func color_for(persona_id: String) -> Color:
	return Color(String(get_by_id(persona_id).get("color", "55e7c2")))
