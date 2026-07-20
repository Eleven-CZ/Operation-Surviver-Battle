class_name CareerActionCatalog
extends RefCounted


static func all() -> Array[Dictionary]:
	return [
		{
			"career_id": "ops",
			"signature": {"id": "terminal_combo", "name": "终端重击", "archetype": "melee_combo", "description": "贴身 130° 扳手横扫，第三击触发 sudo 震地。", "cooldown": 0.72, "icon": "wrench"},
			"skill": {"id": "emergency_dash", "name": "抢修突进", "description": "向当前方向突进，沿途关单并击退，终点追加一次横扫。", "cooldown": 6.0, "icon": "wrench"},
			"ultimate": {"id": "p1_response", "name": "P1 一级响应", "description": "8 秒全向重击、攻速提升并持续吸附近身故障。", "cooldown": 46.0, "icon": "runbook"},
		},
		{
			"career_id": "dba",
			"signature": {"id": "slow_query_lock", "name": "慢查询锁域", "archetype": "delayed_zone", "description": "在故障密集处布置延迟激活的事务锁域。", "cooldown": 2.45, "icon": "lock_zone"},
			"skill": {"id": "transaction_rollback", "name": "ROLLBACK", "description": "回到约一秒前的位置，恢复少量健康并清理两端压力。", "cooldown": 12.0, "icon": "redundancy"},
			"ultimate": {"id": "global_commit", "name": "全库事务 COMMIT", "description": "扩张并清算全部锁域，冻结大范围事务故障。", "cooldown": 50.0, "icon": "lock_zone"},
		},
		{
			"career_id": "network",
			"signature": {"id": "icmp_probe", "name": "ICMP 探针", "archetype": "piercing_projectile", "description": "640px 窄直线探针，贯穿多层网络故障。", "cooldown": 0.86, "icon": "ping"},
			"skill": {"id": "packet_capture", "name": "抓包", "description": "建立 8 秒抓包区；站在范围内时全部攻击力 +15%。", "cooldown": 14.0, "icon": "log"},
			"ultimate": {"id": "network_storm", "name": "网络风暴", "description": "6 秒大范围拓扑风暴，多段 AOE 并持续链路减速。", "cooldown": 48.0, "icon": "ping"},
		},
		{
			"career_id": "security",
			"signature": {"id": "zero_trust_wall", "name": "零信任防火墙", "archetype": "persistent_wall", "description": "面向威胁部署持续墙，灼烧、减速并推回越界故障。", "cooldown": 2.35, "icon": "firewall"},
			"skill": {"id": "isolation_corridor", "name": "隔离通道", "description": "沿移动方向生成双侧临时墙，并获得短时隔离护盾。", "cooldown": 11.0, "icon": "rule_chain"},
			"ultimate": {"id": "global_block", "name": "全域封禁", "description": "生成六边形封禁区，持续扫描并抑制区域内全部故障。", "cooldown": 52.0, "icon": "firewall"},
		},
		{
			"career_id": "it_ops",
			"signature": {"id": "spare_node", "name": "备件节点", "archetype": "deployable_node", "description": "部署可修复服务并周期电击周边故障的现场节点。", "cooldown": 3.0, "icon": "wrench"},
			"skill": {"id": "hot_swap", "name": "整机热插拔", "description": "刷新全部备件节点并触发同步放电，同时恢复健康。", "cooldown": 10.0, "icon": "redundancy"},
			"ultimate": {"id": "datacenter_control", "name": "机房总控", "description": "投放四个重型机柜，建立持续修复与范围电击阵地。", "cooldown": 54.0, "icon": "wrench"},
		},
		{
			"career_id": "helpdesk",
			"signature": {"id": "ticket_dispatch", "name": "工单分派", "archetype": "chain_bounce", "description": "自动追踪并在不同故障间弹跳的 SLA 工单。", "cooldown": 1.30, "icon": "runbook"},
			"skill": {"id": "remote_assist", "name": "远程协助", "description": "批量标记邻近工单、恢复健康并削弱压力外壳。", "cooldown": 12.0, "icon": "runbook"},
			"ultimate": {"id": "sla_fast_lane", "name": "SLA 绿色通道", "description": "8 秒提高弹跳上限与频率，清单批次产生额外遥测。", "cooldown": 49.0, "icon": "redundancy"},
		},
		{
			"career_id": "opsdev",
			"signature": {"id": "idempotent_script", "name": "幂等脚本", "archetype": "delayed_repeat", "description": "命中后在原位置自动重复执行两次。", "cooldown": 0.96, "icon": "bash"},
			"skill": {"id": "ci_runner", "name": "CI Runner", "description": "立即刷新脚本，并让 Runner 复刻最近三次执行。", "cooldown": 10.0, "icon": "bash"},
			"ultimate": {"id": "iac_apply", "name": "全量 IaC Apply", "description": "按 PLAN、APPLY、VERIFY 三阶段轰击全场并刷新工具。", "cooldown": 51.0, "icon": "bash"},
		},
		{
			"career_id": "sre",
			"signature": {"id": "slo_budget_ring", "name": "SLO 预算环", "archetype": "adaptive_ring", "description": "健康时高伤扩张；低健康时切换为恢复与击退。", "cooldown": 1.65, "icon": "redundancy"},
			"skill": {"id": "traffic_shift", "name": "流量切换", "description": "快速侧移并在起终点留下短时服务保护区。", "cooldown": 11.0, "icon": "rule_chain"},
			"ultimate": {"id": "budget_freeze", "name": "错误预算冻结", "description": "6 秒冻结失败扩散、持续恢复并强力减速全场。", "cooldown": 56.0, "icon": "redundancy"},
		},
		{
			"career_id": "delivery",
			"signature": {"id": "release_package", "name": "发布包", "archetype": "delayed_aoe", "description": "向敌群投放延迟爆发并留下 UAT 验收区的发布包。", "cooldown": 1.75, "icon": "log"},
			"skill": {"id": "blue_green_switch", "name": "蓝绿切换", "description": "位移到绿环境；旧蓝环境爆破，新环境提供恢复。", "cooldown": 12.0, "icon": "redundancy"},
			"ultimate": {"id": "full_release", "name": "全量上线", "description": "10%、30%、100% 三道发布波逐次扩大并横扫全场。", "cooldown": 52.0, "icon": "log"},
		},
		{
			"career_id": "ai_infra",
			"signature": {"id": "worker_formation", "name": "Worker Pod", "archetype": "autonomous_summon", "description": "自主 Pod 环绕编队，并从各自位置同步齐射。", "cooldown": 0.92, "icon": "worker"},
			"skill": {"id": "pod_migration", "name": "Pod 迁移", "description": "迁移到新算力节点，所有 Pod 收拢并触发爆破。", "cooldown": 11.0, "icon": "worker"},
			"ultimate": {"id": "gpu_scale_out", "name": "GPU 集群扩容", "description": "10 秒临时增加六个 Worker，并持续执行同步扇形齐射。", "cooldown": 55.0, "icon": "worker"},
		},
	]


static func get_by_id(career_id: String) -> Dictionary:
	for kit in all():
		if String(kit["career_id"]) == career_id:
			return kit
	return all()[0]


static func ids() -> Array[String]:
	var result: Array[String] = []
	for kit in all():
		result.append(String(kit["career_id"]))
	return result
