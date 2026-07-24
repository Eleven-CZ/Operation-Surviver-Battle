class_name ArtifactCatalog
extends RefCounted


static func all() -> Array[Dictionary]:
	return [
		{
			"id": "rm_rf",
			"name": "RM -RF",
			"badge": "RM",
			"color": "ff6b5f",
			"icon_path": "res://assets/generated/artifacts/rm_rf.png",
			"description": "定时递归清理附近最多 24 个故障：普通故障直接删除，精英与事故核心只承受受控伤害。",
			"effects": {"trigger": "rm_rf", "interval": 22.0, "radius": 620.0, "targets": 24, "elite_damage": 80.0, "boss_damage": 24.0},
		},
		{
			"id": "delete_incidents",
			"name": "DELETE * FROM incidents",
			"badge": "SQL",
			"color": "ff9b62",
			"icon_path": "res://assets/generated/artifacts/delete_incidents.png",
			"description": "每 14 秒删除最多 4 条最近故障记录；精英会触发保护约束，不会被直接秒杀。",
			"effects": {"trigger": "delete_incidents", "interval": 14.0, "targets": 4, "range": 560.0, "elite_damage": 66.0, "boss_damage": 18.0},
		},
		{
			"id": "reinstall_os",
			"name": "重装系统",
			"badge": "OS",
			"color": "70caff",
			"icon_path": "res://assets/generated/artifacts/reinstall_os.png",
			"description": "每局一次：服务健康归零时重装恢复 55% 健康，获得 2.5 秒无敌并清空场上危险区。",
			"effects": {"trigger": "revive", "health_ratio": 0.55, "invulnerability": 2.5},
		},
		{
			"id": "reboot_device",
			"name": "重启设备",
			"badge": "RBT",
			"color": "55e7c2",
			"icon_path": "res://assets/generated/artifacts/reboot_device.png",
			"description": "使用职业小技能时有 22% 概率立即完成冷却；未触发时返还最多 2 秒，但至少保留 60% 本次冷却。",
			"effects": {"trigger": "skill_reboot", "chance": 0.22, "fallback_reduction": 2.0},
		},
		{
			"id": "drop_database_run",
			"name": "删库跑路",
			"badge": "RUN",
			"color": "ffcf5a",
			"icon_path": "res://assets/generated/artifacts/drop_database_run.png",
			"description": "移动速度 +18%、全部伤害 +12%，但最大健康 -10%。跑得快，交接单也来得快。",
			"effects": {"move_speed": 1.18, "damage_multiplier": 1.12, "max_health": 0.90},
		},
		{
			"id": "flush_dns",
			"name": "ipconfig /flushdns",
			"badge": "DNS",
			"color": "47c9f1",
			"icon_path": "res://assets/generated/artifacts/flush_dns.png",
			"description": "每 9 秒刷新一次解析缓存，电击并减速附近最多 7 个故障。毕竟最后总是 DNS。",
			"effects": {"trigger": "flush_dns", "interval": 9.0, "targets": 7, "range": 520.0, "damage": 38.0},
		},
		{
			"id": "kill_minus_9",
			"name": "kill -9",
			"badge": "K9",
			"color": "ef68d8",
			"icon_path": "res://assets/generated/artifacts/kill_minus_9.png",
			"description": "每 12 秒强制终止一个低健康非 Boss 故障；精英仅在 18% 健康以下可被终止。",
			"effects": {"trigger": "kill_minus_9", "interval": 12.0, "elite_threshold": 0.18, "fallback_damage": 54.0},
		},
		{
			"id": "rollback_previous",
			"name": "回滚上一版",
			"badge": "RB",
			"color": "c68cff",
			"icon_path": "res://assets/generated/artifacts/rollback_previous.png",
			"description": "单次受到至少 18 点伤害时回滚其中 50%，并清除减速；内部冷却 30 秒。",
			"effects": {"trigger": "damage_rollback", "threshold": 18.0, "heal_ratio": 0.50, "cooldown": 30.0},
		},
		{
			"id": "works_on_my_machine",
			"name": "在我机器上是好的",
			"badge": "OK",
			"color": "91ee70",
			"icon_path": "res://assets/generated/artifacts/works_on_my_machine.png",
			"description": "固有普攻范围 +12%，全部伤害 +10%。既然本机正常，问题一定在远端。",
			"effects": {"signature_area": 1.12, "damage_multiplier": 1.10},
		},
		{
			"id": "friday_freeze",
			"name": "周五禁止发布",
			"badge": "FRI",
			"color": "65e890",
			"icon_path": "res://assets/generated/artifacts/friday_freeze.png",
			"description": "伤害减免 +10%，大招冷却 -10%。把变更窗口关掉，终于能专心救火。",
			"effects": {"damage_reduction": 0.10, "ultimate_cooldown": 0.90},
		},
		{
			"id": "snapshot_backup",
			"name": "快照就是备份",
			"badge": "SNAP",
			"color": "ffd36a",
			"icon_path": "res://assets/generated/artifacts/snapshot_backup.png",
			"description": "关闭精英时额外恢复 6 健康并获得 8 遥测经验。请不要把这句话写进正式制度。",
			"effects": {"trigger": "elite_reward", "heal": 6.0, "xp": 8},
		},
		{
			"id": "sudo_bang_bang",
			"name": "sudo !!",
			"badge": "ROOT",
			"color": "ffe77a",
			"icon_path": "res://assets/generated/artifacts/sudo_bang_bang.png",
			"description": "立即获得 2 次重新评审；全部伤害 +6%，职业小技能与大招冷却 -6%。",
			"effects": {"damage_multiplier": 1.06, "skill_cooldown": 0.94, "ultimate_cooldown": 0.94, "rerolls": 2},
		},
	]


static func ids() -> Array[String]:
	var result: Array[String] = []
	for artifact in all():
		result.append(String(artifact["id"]))
	return result


static func get_by_id(artifact_id: String) -> Dictionary:
	for artifact in all():
		if String(artifact["id"]) == artifact_id:
			return artifact
	return {}


static func available_excluding(excluded_ids: Array[String]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for artifact in all():
		if String(artifact["id"]) not in excluded_ids:
			result.append(artifact)
	return result


static func icon_texture(artifact_id: String) -> Texture2D:
	var definition := get_by_id(artifact_id)
	var icon_path := String(definition.get("icon_path", ""))
	if icon_path.is_empty() or not ResourceLoader.exists(icon_path):
		return null
	return load(icon_path)
