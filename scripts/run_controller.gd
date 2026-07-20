extends Node2D

const CareerCatalog := preload("res://scripts/career_catalog.gd")
const EventCatalog := preload("res://scripts/event_catalog.gd")
const DifficultyCatalog := preload("res://scripts/difficulty_catalog.gd")
const UI_FONT := preload("res://assets/fonts/NotoSansSC-VF.ttf")
const RUN_DURATION := 360.0
const MAX_GAMEPLAY_ENEMIES := 600
const REGULAR_COMBAT_SLOT_CAP := 4
const ARCHITECTURE_LEVELS: Array[int] = [3, 7]

@onready var player: CharacterBody2D = $Player
@onready var swarm: Node2D = $SwarmWorld
@onready var loot: Node2D = $LootWorld
@onready var combat: Node2D = $CombatSystem
@onready var career_actions: Node2D = $CareerActionSystem
@onready var projection: Node2D = $PressureProjection
@onready var hud: CanvasLayer = $HUD

var rng := RandomNumberGenerator.new()
var run_id := ""
var career_id := "ops"
var career: Dictionary = {}
var difficulty_id := "normal"
var difficulty: Dictionary = {}
var difficulty_spawn_rate := 1.0
var minimum_spawn_interval := 0.14
var gameplay_enemy_cap := MAX_GAMEPLAY_ENEMIES
var opening_wave_size := 16
var batch_start_time := 180.0
var batch_chance := 0.32
var batch_size := 2
var next_elite_wave_time := 90.0
var elite_wave_interval := 120.0
var elite_wave_index := 0
var boss_spawn_time := 270.0
var validation_duration := 12.0
var validation_enemy_limit := 18
var validation_cleanup_left := -1.0
var career_xp_multiplier := 1.0
var career_regen_per_second := 0.0
var career_magnet_base := 190.0
var career_damage_reduction := 0.0
var run_time := 0.0
var spawn_accumulator := 0.0
var spawn_multiplier := 1.0
var spawning_enabled := true
var ended := false

var level := 1
var xp := 0
var xp_fraction := 0.0
var current_xp_required := 18
var runbook_level := 0
var capacity_level := 0
var redundancy_level := 0
var redundancy_charges := 0
var capacity_regen_progress := 0.0
var combat_build_summary := "Bash ×1"

var spawned_502 := false
var spawned_oom := false
var release_prompted := false
var boss_spawned := false
var event_previewed := false

# The event director is authoritative. The legacy release fields below stay in
# sync for one save/test compatibility cycle, but rewards no longer parse text.
var event_id := "release"
var event_data: Dictionary = {}
var event_prompted := false
var event_active := false
var event_strategy_id := ""
var event_strategy: Dictionary = {}
var event_time_left := 0.0
var event_progress := 0
var event_required := 0
var event_outcome := "not_started"
var event_outcome_text := "未触发"
var event_started_at := -1.0
var event_ended_at := -1.0
var event_integrity := 0.0
var event_integrity_min := 0.0
var event_node_position := Vector2.ZERO
var event_stage := 0
var event_career_bonus_triggered := false
var boss_clue_discount := 0

var release_active := false
var release_choice := ""
var release_time_left := 0.0
var release_targets_closed := 0
var release_targets_required := 20
var release_outcome := "未触发"

var boss_clues := 0
var boss_clues_required := 8
var validation_left := -1.0
var performance_visible := false
var smoke_test_mode := false
var smoke_action_accumulator := 0.0
var pending_upgrades := 0
var pending_architecture_upgrades := 0
var architecture_choices_taken := 0
var architecture_signature_ids: Array[String] = []
var current_upgrade_is_architecture := false
var current_upgrade_choices: Array[Dictionary] = []
var reroll_charges := 2
var upgrade_modal_open := false
var enemies_closed := 0
var elites_closed := 0
var settlement_committed := false
var last_settlement: Dictionary = {}
var career_protocol_count := 0
var career_protocol_progress := 0.0
var career_protocol_cooldown := 0.0
var career_protocol_triggered := false
var career_protocol_completions := 0
var last_player_position := Vector2.ZERO
var last_player_health := 0.0
var next_radar_update := 0.0


func _ready() -> void:
	smoke_test_mode = OS.get_cmdline_user_args().has("--smoke-test")
	rng.seed = int(Time.get_unix_time_from_system())
	run_id = "%d-%d" % [Time.get_ticks_usec(), rng.randi()]
	career_id = "ops" if smoke_test_mode else String(ProfileStore.session_career_id)
	career = CareerCatalog.get_by_id(career_id)
	difficulty_id = "normal" if smoke_test_mode else String(ProfileStore.session_difficulty_id)
	if difficulty_id not in DifficultyCatalog.ids() or not smoke_test_mode and not ProfileStore.is_difficulty_unlocked(difficulty_id):
		difficulty_id = "normal"
	difficulty = DifficultyCatalog.get_by_id(difficulty_id)
	_apply_difficulty_config()
	event_id = "release" if smoke_test_mode else String(ProfileStore.get("session_event_id") if ProfileStore.get("session_event_id") != null else "release")
	if event_id not in EventCatalog.ids():
		event_id = "release"
	event_data = EventCatalog.get_by_id(event_id)
	swarm.call("configure", player, rng.seed)
	swarm.call("configure_difficulty", difficulty)
	loot.call("configure", player)
	projection.call("configure", player)
	combat.call("configure", player, swarm, projection)
	career_actions.call("configure", player, swarm, projection, combat)
	_ensure_action_input_map()
	_apply_profile_and_career()
	hud.call("configure_career", career)
	if hud.has_method("configure_difficulty"):
		hud.call("configure_difficulty", difficulty)
	last_player_position = player.global_position
	last_player_health = player.health
	_refresh_career_protocol()

	swarm.enemy_closed.connect(_on_enemy_closed)
	swarm.boss_status_changed.connect(_on_boss_status_changed)
	swarm.boss_defeated.connect(_on_boss_defeated)
	swarm.elite_skill_cast.connect(_on_enemy_skill_cast)
	loot.xp_collected.connect(_on_xp_collected)
	player.health_changed.connect(_on_health_changed)
	player.died.connect(_on_player_died)
	projection.shell_resolved.connect(_on_projection_shell_resolved)
	projection.ally_joined.connect(_on_ally_joined)
	combat.build_changed.connect(_on_build_changed)
	career_actions.action_feedback.connect(_on_career_action_feedback)
	hud.upgrade_selected.connect(_on_upgrade_selected)
	hud.upgrade_reroll_requested.connect(_on_upgrade_reroll_requested)
	if hud.has_signal("event_strategy_selected"):
		hud.connect("event_strategy_selected", _on_event_strategy_selected)
	else:
		hud.release_selected.connect(_on_release_selected)
	hud.restart_requested.connect(_restart)
	hud.main_menu_requested.connect(_return_to_menu.bind("home"))
	hud.career_select_requested.connect(_return_to_menu.bind("careers"))
	hud.pause_requested.connect(_pause_run)
	hud.resume_requested.connect(_resume_run)
	if hud.has_signal("career_skill_requested"):
		hud.connect("career_skill_requested", _on_career_skill_requested)
	if hud.has_signal("career_ultimate_requested"):
		hud.connect("career_ultimate_requested", _on_career_ultimate_requested)

	current_xp_required = _xp_required_for(level)
	if smoke_test_mode:
		# Keep automated validation focused on the complete event flow instead
		# of player survival while no movement input is available.
		player.max_health = 1_000_000.0
		player.health = player.max_health
	_spawn_opening_wave()
	_on_health_changed(player.health, player.max_health)
	_refresh_build_summary()
	hud.set_event_message("%s值班开始：%s" % [String(career["name"]), String(career["passive"])], Color(String(career["color"])))


func _apply_difficulty_config() -> void:
	difficulty_spawn_rate = maxf(0.01, float(difficulty.get("spawn_rate", 1.0)))
	minimum_spawn_interval = maxf(0.01, float(difficulty.get("minimum_spawn_interval", 0.14)))
	gameplay_enemy_cap = clampi(int(difficulty.get("enemy_cap", MAX_GAMEPLAY_ENEMIES)), 1, SwarmWorld.MAX_ENTITIES)
	opening_wave_size = maxi(1, int(difficulty.get("opening_wave", 16)))
	batch_start_time = float(difficulty.get("batch_start", 180.0))
	batch_chance = clampf(float(difficulty.get("batch_chance", 0.32)), 0.0, 1.0)
	batch_size = maxi(1, int(difficulty.get("batch_size", 2)))
	next_elite_wave_time = float(difficulty.get("elite_wave_start", 90.0))
	elite_wave_interval = maxf(1.0, float(difficulty.get("elite_wave_interval", 120.0)))
	elite_wave_index = 0
	boss_spawn_time = float(difficulty.get("boss_time", 270.0))
	validation_duration = maxf(1.0, float(difficulty.get("validation_duration", 12.0)))
	validation_enemy_limit = maxi(0, int(difficulty.get("validation_enemy_limit", 18)))


func _apply_profile_and_career() -> void:
	var stats: Dictionary = career.get("stats", {})
	var permanent := ProfileStore.get_permanent_upgrades()
	player.call("configure_career", career)
	projection.call("configure_career", career)
	combat.call("configure_career", career)
	career_actions.call("configure_career", career)
	player.max_health = 100.0 * float(stats.get("health", 1.0)) + float(permanent.get("health", 0)) * 6.0
	player.health = player.max_health
	player.move_speed = 260.0 * float(stats.get("move_speed", 1.0)) * (1.0 + float(permanent.get("mobility", 0)) * 0.02)
	career_damage_reduction = float(stats.get("damage_reduction", 0.0))
	player.damage_reduction = career_damage_reduction
	career_xp_multiplier = float(stats.get("xp", 1.0)) * (1.0 + float(permanent.get("telemetry", 0)) * 0.03)
	career_regen_per_second = float(stats.get("regen", 0.0))
	career_magnet_base = 190.0 * float(stats.get("magnet", 1.0))
	loot.call("set_magnet_radius", career_magnet_base)
	reroll_charges = 2 + int(permanent.get("reroll", 0))
	var settings := ProfileStore.get_settings()
	swarm.labels_enabled = bool(settings.get("fault_labels", true))
	for starting_upgrade in career.get("starting_upgrades", []):
		match String(starting_upgrade):
			"runbook": runbook_level = maxi(1, runbook_level)
			"capacity": capacity_level = maxi(1, capacity_level)
			"redundancy":
				redundancy_level = maxi(1, redundancy_level)
				redundancy_charges = maxi(1, redundancy_charges)
	loot.call("set_magnet_radius", career_magnet_base + float(runbook_level) * 30.0)
	combat_build_summary = String(combat.call("get_build_summary"))


func _process(delta: float) -> void:
	if ended:
		_update_hud()
		return
	run_time += delta
	_update_timeline()
	_update_spawning(delta)
	_update_passives(delta)
	_update_career_protocol(delta)
	if smoke_test_mode:
		_update_smoke_test(delta)
	_update_special_event(delta)
	_update_validation(delta)
	_update_hud()
	if run_time >= RUN_DURATION and validation_left < 0.0:
		_end_run(false, "班次结束，但事故核心尚未完成恢复验证。")


func _update_timeline() -> void:
	var elite_wave_end := minf(RUN_DURATION, float(difficulty.get("elite_wave_end", RUN_DURATION)))
	while run_time >= next_elite_wave_time and next_elite_wave_time < elite_wave_end:
		_spawn_difficulty_elite_wave()
		next_elite_wave_time += elite_wave_interval
	if run_time >= 105.0 and not event_previewed:
		event_previewed = true
		hud.set_event_message("值班事件预告：%s · %s" % [String(event_data["name"]), String(event_data["objective"])], Color(String(event_data["color"])))
	if run_time >= 135.0 and not event_prompted:
		_start_event_prompt()
	if run_time >= boss_spawn_time and not boss_spawned:
		_spawn_boss()


func _spawn_difficulty_elite_wave() -> void:
	var kind := SwarmWorld.EnemyKind.ELITE_502 if elite_wave_index % 2 == 0 else SwarmWorld.EnemyKind.ELITE_OOM
	var scheduled_time := next_elite_wave_time
	var wave_size := int(difficulty.get("elite_wave_size", 1))
	if scheduled_time >= float(difficulty.get("elite_wave_late_time", 9999.0)):
		wave_size = int(difficulty.get("elite_wave_late_size", wave_size))
	if scheduled_time >= float(difficulty.get("elite_wave_final_time", 9999.0)):
		wave_size = int(difficulty.get("elite_wave_final_size", wave_size))
	wave_size = maxi(1, wave_size)
	for ignored in range(wave_size):
		_spawn_elite(kind)
	if kind == SwarmWorld.EnemyKind.ELITE_502:
		spawned_502 = true
	else:
		spawned_oom = true
	elite_wave_index += 1
	var elite_name := "502 UPSTREAM" if kind == SwarmWorld.EnemyKind.ELITE_502 else "OOM 137"
	hud.set_event_message("精英编队：%s ×%d" % [elite_name, wave_size], Color("49d9e7") if kind == SwarmWorld.EnemyKind.ELITE_502 else Color("63e890"))


func _update_spawning(delta: float) -> void:
	if not spawning_enabled or swarm.count >= gameplay_enemy_cap:
		return
	var interval := _effective_spawn_interval(run_time)
	spawn_accumulator += delta
	while spawn_accumulator >= interval and swarm.count < gameplay_enemy_cap:
		spawn_accumulator -= interval
		var batch := batch_size if run_time > batch_start_time and rng.randf() < batch_chance else 1
		for ignored in range(batch):
			if swarm.count >= gameplay_enemy_cap:
				break
			swarm.call("spawn_enemy", _choose_normal_kind(), _spawn_position())


func _effective_spawn_interval(at_time: float, event_pressure: float = -1.0) -> float:
	var active_event_pressure := spawn_multiplier if event_pressure < 0.0 else event_pressure
	return maxf(minimum_spawn_interval, (0.68 - at_time * 0.00115) / maxf(0.01, difficulty_spawn_rate * active_event_pressure))


func _choose_normal_kind() -> int:
	var roll := rng.randf()
	if run_time >= 210.0 and roll < 0.14:
		return SwarmWorld.EnemyKind.ENOSPC
	if run_time >= 75.0 and roll < 0.28:
		return SwarmWorld.EnemyKind.TIMEOUT_408
	if run_time >= 40.0 and roll < 0.47:
		return SwarmWorld.EnemyKind.NXDOMAIN
	if roll < 0.70:
		return SwarmWorld.EnemyKind.BUG
	return SwarmWorld.EnemyKind.HTTP_404


func _spawn_position() -> Vector2:
	var angle := rng.randf() * TAU
	var distance := rng.randf_range(610.0, 790.0)
	var position_value := player.global_position + Vector2.from_angle(angle) * distance
	position_value.x = clampf(position_value.x, 48.0, 2352.0)
	position_value.y = clampf(position_value.y, 205.0, 1290.0)
	return position_value


func _spawn_opening_wave() -> void:
	for index in range(opening_wave_size):
		var kind := SwarmWorld.EnemyKind.BUG if index % 4 == 0 else SwarmWorld.EnemyKind.HTTP_404
		swarm.call("spawn_enemy", kind, player.global_position + Vector2.from_angle(TAU * float(index) / float(opening_wave_size)) * rng.randf_range(360.0, 560.0))


func _spawn_elite(kind: int) -> void:
	swarm.call("spawn_enemy", kind, _spawn_position())


func _start_event_prompt() -> void:
	if event_prompted or ended:
		return
	event_prompted = true
	release_prompted = true
	if smoke_test_mode:
		_on_event_strategy_selected(String(event_data["strategies"][0]["id"]))
		return
	get_tree().paused = true
	if hud.has_method("show_event_choices"):
		hud.call("show_event_choices", event_data)
	else:
		hud.show_release_choices()


func _on_event_strategy_selected(selected_event_id: String, strategy_id: String = "") -> void:
	# New HUDs emit (event_id, strategy_id); the optional second argument keeps
	# the one-argument legacy/test hook working.
	if strategy_id.is_empty():
		strategy_id = selected_event_id
		selected_event_id = event_id
	if selected_event_id != event_id:
		return
	if event_active:
		return
	event_strategy_id = strategy_id
	event_strategy = EventCatalog.get_strategy(event_id, strategy_id)
	event_active = true
	event_outcome = "active"
	event_started_at = run_time
	event_time_left = float(event_strategy.get("duration", 60.0))
	event_progress = 0
	event_required = int(event_strategy.get("targets", 1))
	event_integrity = float(event_strategy.get("integrity_start", 0.0))
	event_integrity_min = float(event_strategy.get("integrity_min", 0.0))
	event_stage = 0
	event_career_bonus_triggered = false
	_apply_event_career_bonus()
	spawn_multiplier = float(event_strategy.get("spawn_multiplier", 1.0))
	_sync_legacy_release_state()
	hud.hide_modal()
	get_tree().paused = false
	# Every event contains a different human pressure projection. Combat breaks
	# the pressure shell; alignment turns that colleague into a War Room ally.
	var persona_id := _event_persona_id()
	projection.call("set_persona", persona_id)
	var projection_position := player.global_position + Vector2(260, -85)
	projection_position.x = clampf(projection_position.x, 72.0, 2328.0)
	projection_position.y = clampf(projection_position.y, 225.0, 1260.0)
	projection.call("start_projection", projection_position)
	if hud.has_method("show_pressure_persona"):
		hud.call("show_pressure_persona", persona_id, String(projection.call("get_persona_name")), false)
	if event_id == "backup_restore":
		event_node_position = player.global_position + Vector2(215.0, -70.0)
		event_node_position.x = clampf(event_node_position.x, 130.0, 2270.0)
		event_node_position.y = clampf(event_node_position.y, 270.0, 1220.0)
		queue_redraw()
	_spawn_event_wave()
	hud.set_event_message("%s：%s" % [String(event_data["name"]), String(event_strategy["name"])], Color(String(event_data["color"])))
	_update_event_objective_hud()


func _event_persona_id() -> String:
	match event_id:
		"release": return "product"
		"version_update": return "backend"
		"troubleshoot": return "customer"
		"backup_restore": return "finance"
	return "supervisor"


func _apply_event_career_bonus() -> void:
	match event_id:
		"release":
			if career_id == "delivery":
				event_required = maxi(1, event_required - 4)
				event_career_bonus_triggered = true
			elif career_id == "opsdev":
				event_time_left += 8.0
				event_career_bonus_triggered = true
			elif career_id == "sre":
				event_strategy["spawn_multiplier"] = float(event_strategy.get("spawn_multiplier", 1.0)) * 0.90
				event_career_bonus_triggered = true
			elif career_id == "helpdesk":
				event_career_bonus_triggered = true
		"version_update":
			if career_id == "it_ops":
				event_required = maxi(1, event_required - 4)
				event_career_bonus_triggered = true
			elif career_id == "delivery":
				event_required = maxi(1, event_required - 3)
				event_career_bonus_triggered = true
			elif career_id == "opsdev":
				event_time_left += 8.0
				event_career_bonus_triggered = true
			elif career_id == "sre":
				event_strategy["spawn_multiplier"] = float(event_strategy.get("spawn_multiplier", 1.0)) * 0.90
				event_career_bonus_triggered = true
		"troubleshoot":
			if career_id == "sre":
				event_time_left += 8.0
				event_career_bonus_triggered = true
			elif career_id in ["dba", "network", "opsdev"]:
				event_career_bonus_triggered = true
		"backup_restore":
			if career_id == "delivery":
				event_required = maxi(1, event_required - 3)
				event_career_bonus_triggered = true
			elif career_id in ["dba", "sre", "it_ops"]:
				event_career_bonus_triggered = true


func _spawn_event_wave() -> void:
	var wave: Array = event_strategy.get("wave", [])
	if wave.is_empty():
		return
	var wave_count := ceili(float(event_strategy.get("wave_count", 10)) * float(difficulty.get("event_wave_multiplier", 1.0)))
	for index in range(wave_count):
		var kind := _enemy_kind_from_id(String(wave[index % wave.size()]))
		var origin := event_node_position if event_id == "backup_restore" else player.global_position
		var angle := TAU * float(index) / float(maxi(1, wave_count)) + rng.randf_range(-0.12, 0.12)
		var position_value := origin + Vector2.from_angle(angle) * rng.randf_range(310.0, 520.0)
		position_value.x = clampf(position_value.x, 48.0, 2352.0)
		position_value.y = clampf(position_value.y, 205.0, 1290.0)
		swarm.call("spawn_enemy", kind, position_value)


func _enemy_kind_from_id(kind_id: String) -> int:
	match kind_id:
		"BUG": return SwarmWorld.EnemyKind.BUG
		"NXDOMAIN": return SwarmWorld.EnemyKind.NXDOMAIN
		"ENOSPC": return SwarmWorld.EnemyKind.ENOSPC
		"TIMEOUT_408": return SwarmWorld.EnemyKind.TIMEOUT_408
	return SwarmWorld.EnemyKind.HTTP_404


func _enemy_kind_id(kind: int) -> String:
	match kind:
		SwarmWorld.EnemyKind.BUG: return "BUG"
		SwarmWorld.EnemyKind.NXDOMAIN: return "NXDOMAIN"
		SwarmWorld.EnemyKind.ENOSPC: return "ENOSPC"
		SwarmWorld.EnemyKind.TIMEOUT_408: return "TIMEOUT_408"
	return "HTTP_404"


func _update_special_event(delta: float) -> void:
	if not event_active:
		return
	event_time_left = maxf(0.0, event_time_left - delta)
	match event_id:
		"release":
			if event_progress >= event_required and projection.ally:
				_complete_special_event("success", "验收标准对齐，产品加入 War Room")
		"version_update":
			var next_stage := mini(3, int(floor(float(event_progress) / float(maxi(1, event_required)) * 3.0)))
			if next_stage > event_stage and event_progress < event_required:
				event_stage = next_stage
				hud.set_event_message("更新批次 %d / 3 已通过健康检查" % event_stage, Color(String(event_data["color"])))
			if event_progress >= event_required:
				_complete_special_event("success", "全部生产节点完成更新与健康检查")
		"troubleshoot":
			if event_progress >= event_required:
				boss_clue_discount = 2
				_complete_special_event("success", "根因假设已验证，最终分诊线索 -2")
		"backup_restore":
			var nearby := int(swarm.call("count_enemies_in_area", event_node_position, 205.0, true))
			var decay_scale := 0.65 if career_id == "dba" else (0.75 if career_id == "sre" else 1.0)
			var decay := float(event_strategy.get("decay_rate", 0.6)) * (1.0 + float(nearby) * 0.22) * decay_scale
			event_integrity = maxf(0.0, event_integrity - delta * decay)
			queue_redraw()
			if event_integrity <= 0.0:
				_complete_special_event("failed", "恢复节点被校验故障击穿")
			elif event_progress >= event_required and event_integrity >= event_integrity_min:
				_complete_special_event("success", "恢复完成，完整性校验通过")
	_update_event_objective_hud()
	_sync_legacy_release_state()
	if event_active and event_time_left <= 0.0:
		_resolve_event_timeout()


func _resolve_event_timeout() -> void:
	var ratio := float(event_progress) / float(maxi(1, event_required))
	var partial := ratio >= 0.60
	if event_id == "release" and bool(event_strategy.get("partial_on_timeout", false)):
		partial = ratio >= 0.35 or projection.ally
	elif event_id == "backup_restore":
		partial = ratio >= 0.50 and event_integrity > 0.0
	elif event_id == "troubleshoot":
		partial = ratio >= 0.50
	if partial:
		if event_id == "troubleshoot":
			boss_clue_discount = 1
		_complete_special_event("partial", _partial_event_text())
	else:
		_complete_special_event("failed", _failed_event_text())


func _partial_event_text() -> String:
	match event_id:
		"release": return "回滚点生效，服务降级运行"
		"version_update": return "部分节点已更新，其余保持旧版本"
		"troubleshoot": return "形成高概率假设，最终分诊线索 -1"
		"backup_restore": return "恢复完成但存在少量 RPO / 完整性缺口"
	return "事件完成部分目标"


func _failed_event_text() -> String:
	match event_id:
		"release": return "发布窗口超时，触发变更冻结"
		"version_update": return "兼容性回归未关闭，自动终止更新"
		"troubleshoot": return "证据链不足，根因仍未定位"
		"backup_restore": return "RTO 超时，恢复演练未通过"
	return "事件窗口超时"


func _complete_special_event(outcome: String, detail: String) -> void:
	if not event_active:
		return
	event_active = false
	event_outcome = outcome
	event_outcome_text = detail
	event_ended_at = run_time
	spawn_multiplier = 1.0
	match outcome:
		"success":
			player.heal(14.0 if event_id == "release" else (10.0 if event_id == "troubleshoot" else 8.0))
			if event_id == "release":
				_complete_delivery_milestone()
			elif event_id == "version_update":
				for weapon_id in combat.call("get_weapon_upgrade_ids"):
					combat.call("prime_upgraded_skill", String(weapon_id))
			elif event_id == "backup_restore":
				redundancy_charges += 1
		"partial":
			player.heal(6.0)
		"failed":
			player.take_damage(15.0)
	if hud.has_method("hide_event_objective"):
		hud.call("hide_event_objective")
	queue_redraw()
	_sync_legacy_release_state()
	var prefix: String = String({"success": "成功", "partial": "部分成功", "failed": "失败"}.get(outcome, "已结束"))
	hud.set_event_message("%s · %s：%s" % [String(event_data["name"]), prefix, detail], Color("5ce8bd") if outcome == "success" else Color("ffca58") if outcome == "partial" else Color("ff7e6d"))


func _update_event_objective_hud() -> void:
	if not event_active or not hud.has_method("update_event_objective"):
		return
	var detail := "剩余 %.0fs" % event_time_left
	if event_id == "release":
		detail += " · 产品%s" % ("已加入" if projection.ally else "待对齐")
	elif event_id == "version_update":
		detail += " · 批次 %d / 3" % mini(3, event_stage + 1)
	elif event_id == "backup_restore":
		detail += " · 完整性 %.0f%% / %.0f%%" % [event_integrity, event_integrity_min]
	if event_id != "release":
		detail += " · 协作%s" % ("已对齐" if projection.ally else "待化解")
	hud.call("update_event_objective", {
		"event_id": event_id,
		"title": String(event_strategy.get("name", event_data["name"])),
		"badge": String(event_data["badge"]),
		"objective": detail,
		"current": event_progress,
		"required": event_required,
		"time_left": event_time_left,
		"color": String(event_data["color"]),
	})


func _sync_legacy_release_state() -> void:
	release_prompted = event_prompted
	release_active = event_active if event_id == "release" else false
	release_choice = event_strategy_id if event_id == "release" else ""
	release_time_left = event_time_left if event_id == "release" else 0.0
	release_targets_closed = event_progress if event_id == "release" else 0
	release_targets_required = event_required if event_id == "release" else 0
	release_outcome = event_outcome_text if event_id == "release" else "未触发"


# Compatibility wrappers for old debug hooks and tests.
func _start_release_prompt() -> void:
	_start_event_prompt()


func _on_release_selected(choice_id: String) -> void:
	_on_event_strategy_selected(choice_id)


func _update_release_event(delta: float) -> void:
	_update_special_event(delta)


func _try_finish_release() -> void:
	if event_id == "release" and event_active and event_progress >= event_required and projection.ally:
		_complete_special_event("success", "验收标准对齐，产品加入 War Room")


func _spawn_boss() -> void:
	if boss_spawned:
		return
	boss_spawned = true
	boss_clues = 0
	var base_clues := maxi(3, (5 if projection.ally else 8) - boss_clue_discount)
	boss_clues_required = maxi(3, ceili(float(base_clues) * float(difficulty.get("boss_clue_multiplier", 1.0))))
	swarm.call("spawn_enemy", SwarmWorld.EnemyKind.INCIDENT_CORE, player.global_position + Vector2(420, -230))
	hud.set_event_message("P0：关闭症状以暴露 UPSTREAM 根因", Color("ff6c5d"))


func _on_enemy_closed(world_position: Vector2, xp_value: int, enemy_kind: int, tier: int) -> void:
	enemies_closed += 1
	if tier == 1:
		elites_closed += 1
	loot.call("spawn_xp", world_position, xp_value)
	if event_active and tier == 0:
		match event_id:
			"release", "version_update":
				event_progress += 1
			"troubleshoot":
				var evidence: Array = event_strategy.get("evidence", [])
				var kind_id := _enemy_kind_id(enemy_kind)
				if kind_id in evidence:
					var contribution := 1
					if (career_id == "dba" and event_strategy_id == "metrics") or (career_id == "network" and event_strategy_id == "traces") or (career_id == "opsdev" and event_strategy_id == "logs"):
						contribution += 1
					event_progress += contribution
			"backup_restore":
				event_progress += 1
				if world_position.distance_to(event_node_position) <= 235.0:
					var repair := 3.0 if career_id == "it_ops" else 1.5
					event_integrity = minf(100.0, event_integrity + repair)
		_sync_legacy_release_state()
		_update_event_objective_hud()
	if boss_spawned and swarm.boss_phase == 0 and tier == 0:
		boss_clues += 1
		if boss_clues >= boss_clues_required:
			swarm.call("expose_boss")
			hud.set_event_message("根因已暴露：UPSTREAM", Color("ffca58"))
	_career_on_enemy_closed(world_position, tier)


func _on_xp_collected(value: int) -> void:
	var exact_gain := float(value) * (1.0 + float(runbook_level) * 0.08) * career_xp_multiplier + xp_fraction
	var whole_gain := floori(exact_gain)
	xp_fraction = exact_gain - float(whole_gain)
	xp += whole_gain
	while xp >= current_xp_required and not ended:
		xp -= current_xp_required
		level += 1
		current_xp_required = _xp_required_for(level)
		pending_upgrades += 1
		if level in ARCHITECTURE_LEVELS:
			pending_architecture_upgrades += 1
	if pending_upgrades > 0 and not upgrade_modal_open and not ended:
		_open_upgrade()


func _open_upgrade() -> void:
	upgrade_modal_open = true
	current_upgrade_is_architecture = pending_architecture_upgrades > 0
	var choices := _build_architecture_choices() if current_upgrade_is_architecture else _build_upgrade_choices()
	current_upgrade_choices = choices
	if smoke_test_mode:
		_on_upgrade_selected(_pick_smoke_upgrade(choices))
		return
	get_tree().paused = true
	hud.show_upgrade(choices, _upgrade_build_context(), reroll_charges, architecture_choices_taken + 1 if current_upgrade_is_architecture else 0)


func _build_upgrade_choices() -> Array[Dictionary]:
	var upgrade_ids: Array[String] = combat.call("get_weapon_upgrade_ids")
	upgrade_ids.append_array(["idempotency", "runbook", "capacity", "redundancy"])
	var pool: Array[Dictionary] = []
	for id in upgrade_ids:
		if _get_upgrade_level(id) >= _get_upgrade_cap(id):
			continue
		if _is_combat_weapon(id) and _get_upgrade_level(id) == 0 and _regular_combat_slot_count() >= REGULAR_COMBAT_SLOT_CAP:
			continue
		pool.append(_decorate_upgrade_card(_get_upgrade_card(id)))
	pool.shuffle()
	var choices: Array[Dictionary] = []
	# Evolution is always shown when ready; the other slots still preserve one
	# stackable owned skill and one new direction whenever possible.
	if combat.call("can_evolve"):
		choices.append(_decorate_upgrade_card(_get_upgrade_card("iac")))
	elif smoke_test_mode and int(combat.call("get_upgrade_level", "bash")) < 3:
		# The automated full-flow run also keeps the legacy Bash → IaC path
		# deterministic while exercising the two architecture decisions.
		choices.append(_decorate_upgrade_card(_get_upgrade_card("bash")))
	elif int(combat.call("get_upgrade_level", "bash")) >= 2 and int(combat.call("get_upgrade_level", "idempotency")) == 0:
		# Once the player commits to Bash, surface its first real synergy instead
		# of allowing pure RNG to postpone the evolution path until the run ends.
		choices.append(_decorate_upgrade_card(_get_upgrade_card("idempotency")))
	var owned: Array[Dictionary] = []
	var owned_combat: Array[Dictionary] = []
	var career_fit: Array[Dictionary] = []
	var fresh: Array[Dictionary] = []
	for card in pool:
		if String(card["id"]) in _career_affinity_ids():
			career_fit.append(card)
		if _get_upgrade_level(String(card["id"])) > 0:
			owned.append(card)
			if _is_combat_weapon(String(card["id"])):
				owned_combat.append(card)
		else:
			fresh.append(card)
	owned.shuffle()
	owned_combat.shuffle()
	career_fit.shuffle()
	fresh.shuffle()
	if choices.size() < 3:
		for card in owned_combat:
			if not _choices_contain(choices, String(card["id"])):
				choices.append(card)
				break
	if choices.size() < 3:
		for card in career_fit:
			if not _choices_contain(choices, String(card["id"])):
				choices.append(card)
				break
	if choices.size() < 3:
		for card in fresh:
			if not _choices_contain(choices, String(card["id"])):
				choices.append(card)
				break
	for card in pool:
		if choices.size() >= 3:
			break
		if not _choices_contain(choices, String(card["id"])):
			choices.append(card)
	return choices


func _build_architecture_choices() -> Array[Dictionary]:
	var ids: Array[String] = combat.call("get_architecture_upgrade_ids")
	var owned: Array[String] = []
	var available: Array[String] = []
	for id in ids:
		if _get_upgrade_level(id) >= 2:
			continue
		available.append(id)
		if _get_upgrade_level(id) > 0:
			owned.append(id)
	available.shuffle()
	owned.shuffle()
	var choices: Array[Dictionary] = []
	if not owned.is_empty():
		choices.append(_decorate_architecture_card(_get_upgrade_card(owned[0])))
	var preferred_architecture := _career_architecture_id()
	if preferred_architecture in available and not _choices_contain(choices, preferred_architecture):
		choices.append(_decorate_architecture_card(_get_upgrade_card(preferred_architecture)))
	for id in available:
		if choices.size() >= 3:
			break
		if not _choices_contain(choices, id):
			choices.append(_decorate_architecture_card(_get_upgrade_card(id)))
	return choices


func _on_upgrade_selected(upgrade_id: String) -> void:
	var feedback_card := _get_upgrade_card(upgrade_id)
	var is_architecture := upgrade_id.begins_with("arch_")
	match upgrade_id:
		"runbook":
			runbook_level = mini(3, runbook_level + 1)
			player.heal(10.0)
			loot.call("set_magnet_radius", career_magnet_base + float(runbook_level) * 30.0)
		"capacity":
			capacity_level = mini(3, capacity_level + 1)
			player.max_health += 15.0
			player.health += 15.0
			player.damage_reduction = career_damage_reduction + float(capacity_level) * 0.06
			player.health_changed.emit(player.health, player.max_health)
		"redundancy":
			redundancy_level = mini(2, redundancy_level + 1)
			redundancy_charges += 1
			player.max_health += 8.0
			player.health += 8.0
			player.health_changed.emit(player.health, player.max_health)
		_:
			combat.call("apply_upgrade", upgrade_id)
	if is_architecture:
		pending_architecture_upgrades = maxi(0, pending_architecture_upgrades - 1)
		architecture_choices_taken += 1
		var signature_id := _architecture_signature(upgrade_id)
		if not signature_id.is_empty() and signature_id not in architecture_signature_ids:
			architecture_signature_ids.append(signature_id)
	combat.call("play_upgrade_burst", upgrade_id, Color(feedback_card["color"]), _get_upgrade_level(upgrade_id))
	combat.call("prime_upgraded_skill", upgrade_id)
	hud.show_stack_feedback(String(feedback_card["title"]), String(feedback_card["description"]), Color(feedback_card["color"]))
	_refresh_build_summary()
	_evaluate_career_milestones()
	pending_upgrades = maxi(0, pending_upgrades - 1)
	upgrade_modal_open = false
	if pending_upgrades > 0:
		_open_upgrade()
		return
	current_upgrade_is_architecture = false
	current_upgrade_choices.clear()
	hud.hide_modal()
	get_tree().paused = false


func _on_upgrade_reroll_requested() -> void:
	if not upgrade_modal_open or reroll_charges <= 0 or smoke_test_mode:
		return
	reroll_charges -= 1
	var choices := _build_architecture_choices() if current_upgrade_is_architecture else _build_upgrade_choices()
	current_upgrade_choices = choices
	hud.show_upgrade(choices, _upgrade_build_context(), reroll_charges, architecture_choices_taken + 1 if current_upgrade_is_architecture else 0)


func _on_projection_shell_resolved() -> void:
	hud.set_event_message("压力外壳已化解：靠近并按住 E 对齐验收标准", Color("ffe271"))


func _on_ally_joined() -> void:
	if boss_spawned and swarm.boss_phase == 0:
		var allied_base_clues := maxi(3, 5 - boss_clue_discount)
		var allied_scaled_clues := maxi(3, ceili(float(allied_base_clues) * float(difficulty.get("boss_clue_multiplier", 1.0))))
		boss_clues_required = mini(boss_clues_required, allied_scaled_clues)
	var ally_name := String(projection.call("get_persona_name")) if projection.has_method("get_persona_name") else "协作伙伴"
	if hud.has_method("set_pressure_persona_allied"):
		hud.call("set_pressure_persona_allied", true)
	hud.set_event_message("%s已加入 War Room：真实处置目标已标记" % ally_name, Color("55e7c2"))
	_try_finish_release()


func _on_boss_status_changed(phase: int, boss_health: float, maximum: float) -> void:
	var combat_snapshot: Dictionary = swarm.call("get_boss_combat_snapshot")
	hud.update_boss(phase, boss_health, maximum, boss_clues, boss_clues_required, int(combat_snapshot.get("combat_stage", -1)), float(combat_snapshot.get("shield", 0.0)), float(combat_snapshot.get("shield_maximum", 0.0)))


func _on_enemy_skill_cast(skill_name: String, _world_position: Vector2, tier: int) -> void:
	if tier == 2:
		hud.set_event_message("BOSS 施法：%s" % skill_name, Color("ff765f"))
	elif skill_name == "崩溃自爆":
		hud.set_event_message("PANIC：精英关闭后即将自爆", Color("ff4057"))


func _on_boss_defeated() -> void:
	validation_left = validation_duration
	validation_cleanup_left = maxf(validation_duration, float(difficulty.get("validation_cleanup_time", 45.0)))
	spawning_enabled = false
	hud.set_event_message("恢复验证：残余故障 ≤%d 后稳定 %.0f 秒" % [validation_enemy_limit, validation_duration], Color("58e8c7"))


func _update_validation(delta: float) -> void:
	if validation_left < 0.0:
		return
	validation_cleanup_left = maxf(0.0, validation_cleanup_left - delta)
	if swarm.call("count_non_boss") <= validation_enemy_limit:
		validation_left = maxf(0.0, validation_left - delta)
		hud.set_event_message("恢复验证 %.1f 秒" % validation_left, Color("58e8c7"))
	else:
		hud.set_event_message("恢复验证等待：残余故障 %d / %d · 清场 %.0fs" % [swarm.call("count_non_boss"), validation_enemy_limit, validation_cleanup_left], Color("ffca58"))
		if validation_cleanup_left <= 0.0:
			_end_run(false, "恢复验证失败：残余故障未在清场窗口内降至 %d。" % validation_enemy_limit)
			return
	if validation_left <= 0.0:
		swarm.call("finish_boss")
		_end_run(true, "%s：%s\n职业：%s  ·  等级：%d\n事故核心已关闭并完成恢复验证。" % [String(event_data["name"]), event_outcome_text, String(career["name"]), level])


func _on_health_changed(current: float, _maximum: float) -> void:
	_career_on_health_changed(current)
	_update_hud()


func _on_player_died() -> void:
	if redundancy_charges > 0:
		redundancy_charges -= 1
		player.health = player.max_health * (0.35 if redundancy_level <= 1 else 0.45)
		player.invulnerability_left = 2.0 + float(redundancy_level) * 0.35
		player.health_changed.emit(player.health, player.max_health)
		_refresh_build_summary()
		hud.set_event_message("冗余设计触发：服务已自动恢复", Color("8cff83"))
		return
	_end_run(false, "%s：%s\n职业：%s  ·  等级：%d\n服务健康度归零。" % [String(event_data["name"]), event_outcome_text, String(career["name"]), level])


func _end_run(victory: bool, summary: String) -> void:
	if ended:
		return
	ended = true
	spawning_enabled = false
	player.input_enabled = false
	if smoke_test_mode:
		var upgrade_flow_valid: bool = int(combat.call("get_upgrade_level", "bash")) >= 3 and int(combat.call("get_upgrade_level", "idempotency")) >= 1 and int(combat.call("get_upgrade_level", "iac")) == 1
		var architecture_flow_valid := architecture_choices_taken >= 2 and not architecture_signature_ids.is_empty()
		var smoke_passed: bool = victory and bool(projection.ally) and event_outcome == "success" and upgrade_flow_valid and architecture_flow_valid
		print("SMOKE_TEST_PASS" if smoke_passed else "SMOKE_TEST_FAIL", " | time=%.1f | level=%d | ally=%s | build=%s | %s" % [run_time, level, projection.ally, String(combat.call("get_build_summary")), summary.replace("\n", " ")])
		get_tree().quit(0 if smoke_passed else 1)
		return
	if not settlement_committed:
		last_settlement = ProfileStore.award_run(_build_run_result(victory))
		settlement_committed = true
	get_tree().paused = true
	hud.show_result(victory, summary, last_settlement, career)


func _build_run_result(victory: bool) -> Dictionary:
	var build: Dictionary = {}
	for upgrade_id in combat.call("get_weapon_upgrade_ids"):
		build[String(upgrade_id)] = int(combat.call("get_upgrade_level", String(upgrade_id)))
	build["idempotency"] = int(combat.call("get_upgrade_level", "idempotency"))
	build["iac"] = int(combat.call("get_upgrade_level", "iac")) == 1
	var structured_event := {
		"instance_id": "%s-0" % event_id,
		"event_id": event_id,
		"title": String(event_data.get("name", event_id)),
		"category": String(event_data.get("category", "事件")),
		"scheduled_at": 135.0,
		"started_at": event_started_at,
		"ended_at": event_ended_at,
		"strategy_id": event_strategy_id,
		"strategy_name": String(event_strategy.get("name", "未选择")),
		"outcome": event_outcome,
		"outcome_text": event_outcome_text,
		"progress_current": event_progress,
		"progress_required": event_required,
		"remaining_time": event_time_left,
		"risk_bonus": int(event_strategy.get("risk_bonus", 0)),
		"career_bonus_triggered": event_career_bonus_triggered,
		"objective_integrity": event_integrity / 100.0 if event_id == "backup_restore" else 1.0,
		"reward_eligible": not smoke_test_mode,
	}
	return {
		"run_id": run_id,
		"career_id": career_id,
		"difficulty_id": difficulty_id,
		"victory": victory,
		"duration": run_time,
		"level": level,
		"closed": enemies_closed,
		"elites": elites_closed,
		"ally": bool(projection.ally),
		"event_id": event_id,
		"event_strategy": event_strategy_id,
		"event_status": event_outcome,
		"event_success": event_outcome == "success",
		"event_partial": event_outcome == "partial",
		"events": [structured_event],
		"release_success": event_id == "release" and event_outcome == "success",
		"release_choice": event_strategy_id if event_id == "release" else "",
		"release_outcome": event_outcome_text if event_id == "release" else "未触发",
		"health_ratio": player.health / maxf(1.0, player.max_health),
		"protocol_completions": career_protocol_completions,
		"architectures": architecture_signature_ids.duplicate(),
		"build": build,
	}


func _update_hud() -> void:
	if hud == null or player == null:
		return
	hud.update_status(player.health, player.max_health, level, xp, current_xp_required, run_time, RUN_DURATION)
	if hud.has_method("update_career_actions"):
		hud.call("update_career_actions", career_actions.call("get_action_snapshot"))
	if run_time >= next_radar_update and hud.has_method("update_radar"):
		next_radar_update = run_time + 0.18
		hud.call("update_radar", player.global_position, swarm.call("get_radar_snapshot", 72))
	if boss_spawned and swarm.boss_phase >= 0:
		var boss_index: int = swarm.call("_find_kind", SwarmWorld.EnemyKind.INCIDENT_CORE)
		var boss_health := 0.0
		var boss_maximum := 1.0
		if boss_index >= 0:
			boss_health = swarm.health[boss_index]
			boss_maximum = swarm.maximum_health[boss_index]
		var combat_snapshot: Dictionary = swarm.call("get_boss_combat_snapshot")
		hud.update_boss(swarm.boss_phase, boss_health, boss_maximum, boss_clues, boss_clues_required, int(combat_snapshot.get("combat_stage", -1)), float(combat_snapshot.get("shield", 0.0)), float(combat_snapshot.get("shield_maximum", 0.0)))
	else:
		hud.update_boss(-1, 0.0, 1.0)
	if performance_visible:
		hud.set_performance("FPS %d\n敌人 %d / %d\n经验球 %d" % [Engine.get_frames_per_second(), swarm.count, gameplay_enemy_cap, loot.positions.size()], true)


func get_difficulty_runtime_snapshot() -> Dictionary:
	return {
		"id": difficulty_id,
		"spawn_rate": difficulty_spawn_rate,
		"minimum_spawn_interval": minimum_spawn_interval,
		"enemy_cap": gameplay_enemy_cap,
		"opening_wave": opening_wave_size,
		"batch_size": batch_size,
		"elite_wave_start": float(difficulty.get("elite_wave_start", 90.0)),
		"elite_wave_interval": elite_wave_interval,
		"elite_wave_end": float(difficulty.get("elite_wave_end", RUN_DURATION)),
		"elite_wave_size": int(difficulty.get("elite_wave_size", 1)),
		"elite_wave_late_size": int(difficulty.get("elite_wave_late_size", 1)),
		"elite_wave_final_size": int(difficulty.get("elite_wave_final_size", 1)),
		"boss_time": boss_spawn_time,
		"boss_clue_multiplier": float(difficulty.get("boss_clue_multiplier", 1.0)),
		"event_wave_multiplier": float(difficulty.get("event_wave_multiplier", 1.0)),
		"validation_duration": validation_duration,
		"validation_enemy_limit": validation_enemy_limit,
		"spawn_interval_start": _effective_spawn_interval(0.0, 1.0),
		"spawn_interval_end": _effective_spawn_interval(RUN_DURATION, 1.0),
	}


func _xp_required_for(target_level: int) -> int:
	return 10 + target_level * 8


func _update_passives(delta: float) -> void:
	var regen_rate := career_regen_per_second + float(capacity_level) * 0.4
	if regen_rate <= 0.0 or player.health >= player.max_health:
		return
	capacity_regen_progress += delta * regen_rate
	if capacity_regen_progress >= 1.0:
		var heal_amount := floorf(capacity_regen_progress)
		capacity_regen_progress -= heal_amount
		player.heal(heal_amount)


func _update_career_protocol(delta: float) -> void:
	career_protocol_cooldown = maxf(0.0, career_protocol_cooldown - delta)
	match career_id:
		"network":
			career_protocol_progress += player.global_position.distance_to(last_player_position)
			while career_protocol_progress >= 900.0:
				career_protocol_progress -= 900.0
				career_protocol_count += 1
				career_protocol_completions += 1
				career_actions.call("prime_signature")
				combat.call("play_upgrade_burst", "ping", Color("47c9f1"), 1)
		"sre":
			var health_ratio: float = player.health / maxf(1.0, player.max_health)
			if health_ratio >= 0.65 and career_protocol_cooldown <= 0.0:
				career_protocol_progress = minf(100.0, career_protocol_progress + delta * 4.5)
			if health_ratio < 0.40 and career_protocol_progress >= 50.0 and career_protocol_cooldown <= 0.0:
				career_protocol_progress -= 50.0
				career_protocol_cooldown = 12.0
				career_protocol_completions += 1
				player.heal(18.0)
				hud.show_stack_feedback("错误预算回收", "消耗 50 预算，自动恢复 18 服务健康度", Color("65e890"))
	last_player_position = player.global_position
	_refresh_career_protocol()


func _career_on_enemy_closed(world_position: Vector2, tier: int) -> void:
	if tier != 0:
		return
	match career_id:
		"dba":
			career_protocol_count += 1
			if career_protocol_count >= 18:
				career_protocol_count -= 18
				career_protocol_completions += 1
				call_deferred("_trigger_dba_commit")
		"it_ops":
			if world_position.distance_to(player.global_position) <= 175.0:
				career_protocol_count += 1
				if career_protocol_count >= 6:
					career_protocol_count -= 6
					career_protocol_completions += 1
					player.heal(4.0)
					combat.call("play_upgrade_burst", "wrench", Color("ffae62"), maxi(1, int(combat.call("get_upgrade_level", "wrench"))))
		"helpdesk":
			career_protocol_count += 1
			if career_protocol_count >= 12:
				career_protocol_count -= 12
				career_protocol_completions += 1
				loot.call("spawn_xp", world_position, 6)
		"opsdev":
			career_protocol_count += 1
			if career_protocol_count >= 14:
				career_protocol_count -= 14
				career_protocol_completions += 1
				career_actions.call("prime_signature")
				combat.call("play_upgrade_burst", "bash", Color("9cff72"), 1)
		"ai_infra":
			career_protocol_count += 1
			if career_protocol_count >= 20:
				career_protocol_count -= 20
				career_protocol_completions += 1
				career_actions.call("prime_signature")
				combat.call("play_upgrade_burst", "worker", Color("91ee70"), 1)
	_refresh_career_protocol()


func _career_on_health_changed(current: float) -> void:
	var took_damage := current < last_player_health - 0.01
	last_player_health = current
	if career_id == "security" and took_damage and career_protocol_cooldown <= 0.0:
		career_protocol_cooldown = 8.0
		career_protocol_completions += 1
		call_deferred("_trigger_security_quarantine")
	_refresh_career_protocol()


func _trigger_dba_commit() -> void:
	if ended:
		return
	swarm.call("damage_area", player.global_position, 250.0, 36.0)
	swarm.call("push_area", player.global_position, 250.0, 24.0)
	combat.call("play_upgrade_burst", "lock_zone", Color("c68cff"), maxi(1, int(combat.call("get_upgrade_level", "lock_zone"))))


func _trigger_security_quarantine() -> void:
	if ended:
		return
	swarm.call("damage_area", player.global_position, 190.0, 18.0)
	swarm.call("push_area", player.global_position, 210.0, 38.0)
	combat.call("play_upgrade_burst", "firewall", Color("ee6677"), maxi(1, int(combat.call("get_upgrade_level", "firewall"))))


func _evaluate_career_milestones() -> void:
	if career_id == "ops" and not career_protocol_triggered and int(combat.call("get_weapon_count")) >= 3:
		career_protocol_triggered = true
		career_protocol_completions += 1
		reroll_charges += 1
		hud.show_stack_feedback("跨域联动已启用", "安装三类工具，额外获得 1 次重新评审", Color("56e6dc"))
	_refresh_career_protocol()


func _complete_delivery_milestone() -> void:
	if career_id != "delivery" or career_protocol_triggered:
		return
	career_protocol_triggered = true
	career_protocol_completions += 1
	reroll_charges += 1
	hud.show_stack_feedback("验收里程碑已签署", "线上发布完成，额外获得 1 次重新评审", Color("ffce73"))
	_refresh_career_protocol()


func _refresh_career_protocol() -> void:
	var text := ""
	match career_id:
		"ops":
			text = "跨域联动 · 已启用 · 评审 +1" if career_protocol_triggered else "跨域联动 · 工具 %d / 3" % int(combat.call("get_weapon_count"))
		"dba": text = "事务 COMMIT · 日志 %d / 18" % career_protocol_count
		"network": text = "链路收敛 · %d / 900px · 完成 %d" % [int(career_protocol_progress), career_protocol_count]
		"security": text = "自动隔离 · READY" if career_protocol_cooldown <= 0.0 else "自动隔离 · 冷却 %.1fs" % career_protocol_cooldown
		"it_ops": text = "现场处置 · 近身关单 %d / 6" % career_protocol_count
		"helpdesk": text = "SLA 批次 · %d / 12 · 协作 ×2" % career_protocol_count
		"opsdev": text = "幂等重试 · 关闭 %d / 14" % career_protocol_count
		"sre": text = "错误预算 · %d / 100 · 50 自动恢复" % int(career_protocol_progress)
		"delivery": text = "验收里程碑 · 已签署 · 评审 +1" if career_protocol_triggered else "验收里程碑 · 等待发布闭环"
		"ai_infra": text = "自动扩缩容 · 关闭 %d / 20 · Worker %d" % [career_protocol_count, int(career_actions.call("get_worker_count"))]
		_: text = "职业协议 · 运行中"
	hud.call("update_career_protocol", text, Color(String(career.get("color", "ffd36a"))))


func _get_upgrade_level(upgrade_id: String) -> int:
	match upgrade_id:
		"runbook": return runbook_level
		"capacity": return capacity_level
		"redundancy": return redundancy_level
	return int(combat.call("get_upgrade_level", upgrade_id))


func _get_upgrade_cap(upgrade_id: String) -> int:
	match upgrade_id:
		"idempotency", "runbook", "capacity": return 3
		"redundancy": return 2
		"arch_oncall", "arch_zero_trust", "arch_query", "arch_autoscale": return 2
		"iac": return 1
	return 5


func _get_upgrade_card(upgrade_id: String) -> Dictionary:
	if _is_combat_weapon(upgrade_id) or upgrade_id in ["idempotency", "iac", "arch_oncall", "arch_zero_trust", "arch_query", "arch_autoscale"]:
		return combat.call("get_upgrade_card", upgrade_id)
	var current := _get_upgrade_level(upgrade_id)
	var next := mini(_get_upgrade_cap(upgrade_id), current + 1)
	match upgrade_id:
		"runbook":
			return {
				"id": upgrade_id,
				"name": "Runbook  STACK %d → %d" % [current, next],
				"title": "Runbook 叠加至 %d 层" % next,
				"description": "遥测收益 +%d%%→+%d%% · 吸附半径 %d→%dpx · 立即恢复 10 健康" % [current * 8, next * 8, 190 + current * 30, 190 + next * 30],
				"color": Color("70caff"),
			}
		"capacity":
			return {
				"id": upgrade_id,
				"name": "容量规划  STACK %d → %d" % [current, next],
				"title": "容量规划叠加至 %d 层" % next,
				"description": "最大健康 +15 · 伤害减免 %d%%→%d%% · 每层每秒恢复 0.4 健康" % [current * 6, next * 6],
				"color": Color("65e890"),
			}
		"redundancy":
			return {
				"id": upgrade_id,
				"name": "冗余设计  STACK %d → %d" % [current, next],
				"title": "冗余设计叠加至 %d 层" % next,
				"description": "自动恢复次数 +1 · 最大健康 +8 · 恢复比例 %d%%" % [35 if next <= 1 else 45],
				"color": Color("8cff83"),
			}
	return {"id": upgrade_id, "name": upgrade_id, "title": "能力已叠加", "description": "", "color": Color("75f3df")}


func _decorate_upgrade_card(source: Dictionary) -> Dictionary:
	var card := source.duplicate()
	var upgrade_id := String(card["id"])
	var meta := _upgrade_meta(upgrade_id)
	for key in meta:
		card[key] = meta[key]
	var current := _get_upgrade_level(upgrade_id)
	var rarity_tier := 0
	if upgrade_id == "iac":
		rarity_tier = 3
	elif current >= 4:
		rarity_tier = 2
	elif current >= 2:
		rarity_tier = 1
	card["rarity_tier"] = rarity_tier
	card["rarity"] = ["标准变更", "高级变更", "核心变更", "进化协议"][rarity_tier]
	card["choice_kind"] = "evolution" if upgrade_id == "iac" else ("weapon" if _is_combat_weapon(upgrade_id) else "method")
	card["is_new"] = _is_combat_weapon(upgrade_id) and current == 0
	card["slot_text"] = "新技能 · 占用常规槽" if bool(card["is_new"]) else ("已安装 · 继续叠层" if _is_combat_weapon(upgrade_id) else "方法论 · 全局生效")
	if upgrade_id in _career_affinity_ids():
		card["career_fit"] = true
		card["rarity"] = "%s · 岗位专精" % card["rarity"]
		card["slot_text"] = "岗位适配 · " + String(card["slot_text"])
	return card


func _decorate_architecture_card(source: Dictionary) -> Dictionary:
	var card := _decorate_upgrade_card(source)
	var rarity_tier := 1 if architecture_choices_taken == 0 else 2
	card["rarity_tier"] = rarity_tier
	card["rarity"] = "标准架构" if rarity_tier == 1 else "核心架构"
	card["choice_kind"] = "architecture"
	card["is_new"] = false
	card["slot_text"] = "签名技能 · 不占常规槽"
	if bool(card.get("career_fit", false)):
		card["rarity"] = "%s · 岗位专精" % card["rarity"]
		card["slot_text"] = "岗位适配 · 签名技能不占槽位"
	return card


func _upgrade_meta(upgrade_id: String) -> Dictionary:
	match upgrade_id:
		"bash": return {"route": "运维开发", "archetype": "远程 / 连锁", "icon": "$_", "synergy": "叠加幂等性后可进化为 IaC 闭环"}
		"ping": return {"route": "网络工程", "archetype": "脉冲 / 全域", "icon": "ICMP", "synergy": "适合外圈清场，与规则链形成双层防线"}
		"firewall": return {"route": "安全运维", "archetype": "领域 / 击退", "icon": "WAF", "synergy": "靠近敌群收益最高，容量规划提高容错"}
		"log": return {"route": "SRE / NOC", "archetype": "间接 / 爆破", "icon": "LOG", "synergy": "随机覆盖密集故障，适合根因清场"}
		"wrench": return {"route": "IT 运维", "archetype": "近战 / 横扫", "icon": "TOOL", "synergy": "必须贴身走位；现场值守协议强化连击"}
		"rule_chain": return {"route": "安全运维", "archetype": "环绕 / 碰撞", "icon": "ACL", "synergy": "用环绕实体切割敌群；零信任边界增加节点"}
		"lock_zone": return {"route": "DBA", "archetype": "陷阱 / 控场", "icon": "SQL", "synergy": "边移动边布点，把敌群引入慢查询锁域"}
		"worker": return {"route": "AI Infra", "archetype": "召唤 / 自主", "icon": "POD", "synergy": "Worker 独立编队齐射；弹性集群增加副本"}
		"idempotency": return {"route": "运维开发", "archetype": "策略 / 进化", "icon": "IDEM", "synergy": "Bash STACK 3 + 幂等性可触发 IaC"}
		"iac": return {"route": "运维开发", "archetype": "进化 / 闭环", "icon": "IaC", "synergy": "保留全部 Bash 层数并改变攻击形态"}
		"runbook": return {"route": "SRE", "archetype": "成长 / 恢复", "icon": "BOOK", "synergy": "更快获取后续构筑选择"}
		"capacity": return {"route": "容量管理", "archetype": "生存 / 续航", "icon": "CAP", "synergy": "适合扳手、防火墙等贴身流派"}
		"redundancy": return {"route": "SRE", "archetype": "容灾 / 复活", "icon": "HA", "synergy": "为高风险近身和陷阱走位提供兜底"}
		"arch_oncall": return {"route": "IT 运维", "archetype": "构筑核心 / 近战", "icon": "P1", "synergy": "签名技能：机柜扳手；推荐防火墙 + 容量规划"}
		"arch_zero_trust": return {"route": "安全运维", "archetype": "构筑核心 / 环绕", "icon": "403", "synergy": "签名技能：iptables 规则链；推荐 Ping + 冗余"}
		"arch_query": return {"route": "DBA", "archetype": "构筑核心 / 阵地", "icon": "TX", "synergy": "签名技能：慢查询锁域；推荐日志 + 防火墙"}
		"arch_autoscale": return {"route": "AI Infra", "archetype": "构筑核心 / 召唤", "icon": "K8S", "synergy": "签名技能：Worker Pod；推荐 Bash + IaC"}
	return {"route": "通用运维", "archetype": "通用", "icon": "OPS", "synergy": "补强当前构筑"}


func _is_combat_weapon(upgrade_id: String) -> bool:
	var ids: Array[String] = combat.call("get_weapon_upgrade_ids")
	return upgrade_id in ids


func _regular_combat_slot_count() -> int:
	var total := 0
	var ids: Array[String] = combat.call("get_weapon_upgrade_ids")
	for id in ids:
		if _get_upgrade_level(id) > 0 and id not in architecture_signature_ids:
			total += 1
	return total


func _upgrade_build_context() -> String:
	return "%s\n常规技能槽 %d / %d" % [combat_build_summary, _regular_combat_slot_count(), REGULAR_COMBAT_SLOT_CAP]


func _architecture_signature(upgrade_id: String) -> String:
	match upgrade_id:
		"arch_oncall": return "wrench"
		"arch_zero_trust": return "rule_chain"
		"arch_query": return "lock_zone"
		"arch_autoscale": return "worker"
	return ""


func _career_affinity_ids() -> Array[String]:
	match career_id:
		"dba": return ["lock_zone", "log", "capacity", "arch_query"]
		"network": return ["ping", "rule_chain", "runbook", "arch_zero_trust"]
		"security": return ["firewall", "rule_chain", "redundancy", "arch_zero_trust"]
		"it_ops": return ["wrench", "capacity", "redundancy", "arch_oncall"]
		"helpdesk": return ["rule_chain", "runbook", "redundancy", "ping"]
		"opsdev": return ["bash", "idempotency", "iac", "log"]
		"sre": return ["firewall", "log", "runbook", "capacity", "redundancy"]
		"delivery": return ["log", "runbook", "idempotency", "redundancy"]
		"ai_infra": return ["worker", "bash", "capacity", "arch_autoscale"]
	return ["bash", "ping", "runbook", "capacity"]


func _career_architecture_id() -> String:
	match career_id:
		"dba": return "arch_query"
		"network", "security", "helpdesk": return "arch_zero_trust"
		"it_ops": return "arch_oncall"
		"ai_infra": return "arch_autoscale"
		"opsdev", "delivery": return "arch_autoscale"
		"sre": return "arch_query"
	return "arch_oncall"


func _choices_contain(choices: Array[Dictionary], upgrade_id: String) -> bool:
	for choice in choices:
		if String(choice["id"]) == upgrade_id:
			return true
	return false


func _update_smoke_test(delta: float) -> void:
	smoke_action_accumulator += delta
	if smoke_action_accumulator < 0.45:
		return
	smoke_action_accumulator = 0.0
	# Exercise the real close/damage callbacks while making the accelerated
	# run deterministic enough for CI and local verification.
	swarm.call("damage_area", player.global_position, 3000.0, 420.0)
	if projection.active and not projection.ally:
		projection.call("take_shell_damage", 10_000.0)
		projection.debug_auto_interact = true
		projection.global_position = player.global_position + Vector2(58.0, 0.0)
	if level < 10:
		_on_xp_collected(current_xp_required)


func _pick_smoke_upgrade(choices: Array[Dictionary]) -> String:
	var preference: Array[String] = []
	if combat.call("get_upgrade_level", "bash") < 3:
		preference.append("bash")
	if combat.call("get_upgrade_level", "idempotency") < 1:
		preference.append("idempotency")
	if combat.call("can_evolve"):
		preference.append("iac")
	preference.append_array(["ping", "firewall", "log", "runbook", "capacity", "redundancy"])
	for preferred_id in preference:
		for choice in choices:
			if String(choice["id"]) == preferred_id:
				return preferred_id
	return String(choices[0]["id"])


func _on_build_changed(summary: String) -> void:
	combat_build_summary = summary
	_refresh_build_summary()


func _refresh_build_summary() -> void:
	var methods: Array[String] = []
	if runbook_level > 0: methods.append("Runbook ×%d" % runbook_level)
	if capacity_level > 0: methods.append("容量 ×%d" % capacity_level)
	if redundancy_level > 0: methods.append("冗余 ×%d（剩余%d次）" % [redundancy_level, redundancy_charges])
	var action_snapshot: Dictionary = career_actions.call("get_action_snapshot")
	var signature_name := String(action_snapshot.get("signature", {}).get("name", "职业固有攻击"))
	var summary := "%s · %s\n固有攻击 · %s\n%s" % [String(career.get("name", "运维工程师")), String(career.get("badge", "OPS")), signature_name, combat_build_summary]
	if not methods.is_empty():
		summary += "\n" + "  |  ".join(methods)
	hud.update_build(summary)
	if hud.has_method("update_skill_loadout"):
		hud.call("update_skill_loadout", _skill_loadout_for_hud())


func _skill_loadout_for_hud() -> Array[Dictionary]:
	var loadout: Array[Dictionary] = []
	var action_snapshot: Dictionary = career_actions.call("get_action_snapshot")
	var signature: Dictionary = action_snapshot.get("signature", {})
	if not signature.is_empty():
		loadout.append({"id": String(signature.get("icon", "wrench")), "level": 1, "name": "固有攻击 · %s" % String(signature.get("name", "职业攻击")), "signature": true})
	for upgrade_id in combat.call("get_weapon_upgrade_ids"):
		var level_value := int(combat.call("get_upgrade_level", String(upgrade_id)))
		if level_value <= 0:
			continue
		var card: Dictionary = combat.call("get_upgrade_card", String(upgrade_id))
		loadout.append({"id": String(upgrade_id), "level": level_value, "name": String(card.get("title", card.get("name", upgrade_id)))})
		if loadout.size() >= 5:
			return loadout
	for method in [
		{"id": "runbook", "level": runbook_level, "name": "Runbook"},
		{"id": "redundancy", "level": redundancy_level, "name": "冗余设计"},
	]:
		if int(method["level"]) > 0 and loadout.size() < 5:
			loadout.append(method)
	return loadout


func _ensure_action_input_map() -> void:
	_add_action_mapping("career_skill", [KEY_Q, KEY_SPACE], JOY_BUTTON_X)
	_add_action_mapping("career_ultimate", [KEY_R], JOY_BUTTON_Y)


func _add_action_mapping(action_name: StringName, keys: Array, joy_button: JoyButton) -> void:
	if InputMap.has_action(action_name):
		return
	InputMap.add_action(action_name)
	for keycode_value in keys:
		var key_event := InputEventKey.new()
		key_event.physical_keycode = int(keycode_value)
		InputMap.action_add_event(action_name, key_event)
	var joy_event := InputEventJoypadButton.new()
	joy_event.button_index = joy_button
	InputMap.action_add_event(action_name, joy_event)


func _can_use_career_action() -> bool:
	return not ended and not upgrade_modal_open and not get_tree().paused


func _on_career_skill_requested() -> void:
	if not _can_use_career_action():
		return
	career_actions.call("try_skill", Vector2(player.call("get_facing_direction")))


func _on_career_ultimate_requested() -> void:
	if not _can_use_career_action():
		return
	career_actions.call("try_ultimate")


func _on_career_action_feedback(title: String, detail: String, color: Color) -> void:
	hud.show_stack_feedback(title, detail, color)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("career_skill"):
		_on_career_skill_requested()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("career_ultimate"):
		if ended:
			_restart()
		else:
			_on_career_ultimate_requested()
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F3:
			performance_visible = not performance_visible
			hud.set_performance("", performance_visible)
		KEY_P:
			if not event_prompted: _start_event_prompt()
		KEY_O:
			if not spawned_oom:
				spawned_oom = true
				_spawn_elite(SwarmWorld.EnemyKind.ELITE_OOM)
		KEY_B:
			if not boss_spawned: _spawn_boss()
		KEY_T:
			run_time = minf(RUN_DURATION - 1.0, run_time + 30.0)
		KEY_U:
			if not ended: _on_xp_collected(current_xp_required)
		KEY_R:
			if ended: _restart()


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _pause_run() -> void:
	if ended or upgrade_modal_open or event_prompted and not event_active and event_outcome == "not_started":
		return
	get_tree().paused = true
	hud.show_pause_menu(career, combat_build_summary)


func _resume_run() -> void:
	if ended:
		return
	hud.hide_modal()
	get_tree().paused = false


func _return_to_menu(tab: String) -> void:
	get_tree().paused = false
	ProfileStore.requested_menu_tab = tab
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _draw() -> void:
	if event_id != "backup_restore" or event_node_position == Vector2.ZERO or event_outcome not in ["active", "success", "partial"]:
		return
	var color := Color(String(event_data.get("color", "65e890")))
	var integrity_ratio := clampf(event_integrity / 100.0, 0.0, 1.0)
	draw_circle(event_node_position + Vector2(0, 18), 28.0, Color(0.0, 0.0, 0.0, 0.28))
	draw_rect(Rect2(event_node_position + Vector2(-25, -22), Vector2(50, 46)), Color("142d2b"), true)
	draw_rect(Rect2(event_node_position + Vector2(-18, -14), Vector2(36, 7)), color, true)
	draw_rect(Rect2(event_node_position + Vector2(-18, 0), Vector2(36 * integrity_ratio, 10)), color, true)
	draw_rect(Rect2(event_node_position + Vector2(-18, 0), Vector2(36, 10)), Color(color, 0.65), false, 2.0)
	draw_arc(event_node_position, 64.0, 0.0, TAU, 40, Color(color, 0.50), 2.0)
	var label := "RESTORE NODE  %.0f%%" % event_integrity
	var text_size := UI_FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	draw_string(UI_FONT, event_node_position + Vector2(-text_size.x * 0.5, -34), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
