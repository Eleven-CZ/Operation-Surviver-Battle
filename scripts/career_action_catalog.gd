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
			"signature": {"id": "zero_trust_wall", "name": "零信任防火墙", "archetype": "persistent_wall", "description": "部署长效高温实体墙；初始是小型检查点，范围卡会同步扩大墙长、阻断宽度与灼烧圈。", "cooldown": 1.85, "icon": "firewall"},
			"skill": {"id": "isolation_corridor", "name": "烈焰隔离通道", "description": "突进点燃双侧墙与前置闸门，宽域灼烧、击退并阻挡普通故障。", "cooldown": 9.5, "icon": "rule_chain"},
			"ultimate": {"id": "global_block", "name": "全域封禁", "description": "建立九秒六边形硬封锁区；边界持续灼烧，内部高频扫描、冻结并击退全部故障。", "cooldown": 50.0, "icon": "firewall"},
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
			"skill": {"id": "compile_run", "name": "Compile & Run", "description": "宽域编译当前 3–7 槽工具链，应用七级编译通道并高速重放全部真实武器几何。", "cooldown": 8.5, "icon": "bash"},
			"ultimate": {"id": "runtime_hot_reload", "name": "Runtime Hot Reload", "description": "十秒 KERNEL 热重载：工具逐件上屏并串联真实武器效果，每个 Epoch 自动执行整链，结束提交 650px MERGE COMBO。", "cooldown": 48.0, "icon": "bash"},
		},
		{
			"career_id": "sre",
			"signature": {"id": "critical_path_trace", "name": "关键路径 Trace", "archetype": "trace_replay", "description": "锁定高威胁故障，先采样留下 SPAN，再沿原路径反向回滚并重击根因。", "cooldown": 1.35, "icon": "log"},
			"skill": {"id": "traffic_shift", "name": "流量切换", "description": "切换到容灾端点，以持续数据链路切割故障并立即触发一次 Trace。", "cooldown": 10.0, "icon": "rule_chain"},
			"ultimate": {"id": "active_active_takeover", "name": "全站多活", "description": "10 秒启用主站与两处历史容灾站，并行回放 Trace，危急时自动故障转移。", "cooldown": 58.0, "icon": "redundancy"},
		},
		{
			"career_id": "delivery",
			"signature": {"id": "release_package", "name": "发布包", "archetype": "delayed_aoe", "description": "向敌群投放延迟爆发并留下 UAT 验收区的发布包。", "cooldown": 1.75, "icon": "log"},
			"skill": {"id": "cross_team_sync", "name": "跨组联调", "description": "默认独立储备 2 次，轮换召集职业剪影投放固有普攻；储备与到场人数均可专项升级。", "cooldown": 10.0, "icon": "runbook"},
			"ultimate": {"id": "all_hands_delivery", "name": "全员到场", "description": "完整十职业阵容到场，三轮投放各自固有普攻，所有作用范围扩大 50%。", "cooldown": 58.0, "icon": "runbook"},
		},
		{
			"career_id": "ai_infra",
			"signature": {"id": "tensor_pipeline", "name": "Tensor Pipeline", "archetype": "tensor_pipeline", "description": "并行 Token 依次经过 Embedding、Attention、FFN 与 Output；击杀后残差射线自动转交。", "cooldown": 0.90, "icon": "worker"},
			"skill": {"id": "pipeline_flush", "name": "Pipeline Flush", "description": "冲刷三条并行数据通道，连续执行四阶段贯穿，最后发射三枚 Output Head。", "cooldown": 10.0, "icon": "worker"},
			"ultimate": {"id": "foundation_model_online", "name": "基础模型上线", "description": "以 Prefill 扫描、加速 Decode 与 EOS 清算完成一次全屏推理，并回收全部经验。", "cooldown": 60.0, "icon": "worker"},
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
