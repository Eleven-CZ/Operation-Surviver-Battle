extends Node

# Central, persistent audio director. Music survives scene changes, while a
# fixed voice pool prevents survivor-scale combat from creating audio nodes or
# turning thousands of hits into a wall of noise.

const AMBIENT_MUSIC_PATHS := {
	"menu": "res://assets/audio/bgm/bgm_noc_afterhours.ogg",
	"run": "res://assets/audio/bgm/bgm_packet_flow.ogg",
	"escalation": "res://assets/audio/bgm/bgm_pager_escalation.ogg",
	"boss": "res://assets/audio/bgm/bgm_incident_core.ogg",
	"recovery": "res://assets/audio/bgm/bgm_recovery_window.ogg",
}

const PULSE_MUSIC_PATHS := {
	"menu": "res://assets/audio/bgm/bgm_noc_afterhours_pulse.ogg",
	"run": "res://assets/audio/bgm/bgm_packet_flow_pulse.ogg",
	"escalation": "res://assets/audio/bgm/bgm_pager_escalation_pulse.ogg",
	"boss": "res://assets/audio/bgm/bgm_incident_core_pulse.ogg",
	"recovery": "res://assets/audio/bgm/bgm_recovery_window_pulse.ogg",
}

const SUNO_BGM01_PATHS := {
	"menu": "res://assets/audio/bgm/user/bgm01.ogg",
	"run": "res://assets/audio/bgm/user/bgm01.ogg",
	"escalation": "res://assets/audio/bgm/user/bgm01.ogg",
	"boss": "res://assets/audio/bgm/user/bgm01.ogg",
	"recovery": "res://assets/audio/bgm/user/bgm01.ogg",
}

const SUNO_BGM02_PATHS := {
	"menu": "res://assets/audio/bgm/user/bgm02.ogg",
	"run": "res://assets/audio/bgm/user/bgm02.ogg",
	"escalation": "res://assets/audio/bgm/user/bgm02.ogg",
	"boss": "res://assets/audio/bgm/user/bgm02.ogg",
	"recovery": "res://assets/audio/bgm/user/bgm02.ogg",
}

const MAXIMUM_BREACH_PATHS := {
	"menu": "res://assets/audio/bgm/user/maximum_breach.ogg",
	"run": "res://assets/audio/bgm/user/maximum_breach.ogg",
	"escalation": "res://assets/audio/bgm/user/maximum_breach.ogg",
	"boss": "res://assets/audio/bgm/user/maximum_breach.ogg",
	"recovery": "res://assets/audio/bgm/user/maximum_breach.ogg",
}

const TERMINAL_OVERWRITE_PATHS := {
	"menu": "res://assets/audio/bgm/user/terminal_overwrite.ogg",
	"run": "res://assets/audio/bgm/user/terminal_overwrite.ogg",
	"escalation": "res://assets/audio/bgm/user/terminal_overwrite.ogg",
	"boss": "res://assets/audio/bgm/user/terminal_overwrite.ogg",
	"recovery": "res://assets/audio/bgm/user/terminal_overwrite.ogg",
}

const UNAUTHORIZED_ENTRY_PATHS := {
	"menu": "res://assets/audio/bgm/user/unauthorized_entry.ogg",
	"run": "res://assets/audio/bgm/user/unauthorized_entry.ogg",
	"escalation": "res://assets/audio/bgm/user/unauthorized_entry.ogg",
	"boss": "res://assets/audio/bgm/user/unauthorized_entry.ogg",
	"recovery": "res://assets/audio/bgm/user/unauthorized_entry.ogg",
}

const MUSIC_STYLES := {
	"suno_01": SUNO_BGM01_PATHS,
	"suno_02": SUNO_BGM02_PATHS,
	"maximum_breach": MAXIMUM_BREACH_PATHS,
	"terminal_overwrite": TERMINAL_OVERWRITE_PATHS,
	"unauthorized_entry": UNAUTHORIZED_ENTRY_PATHS,
	"pulse": PULSE_MUSIC_PATHS,
	"ambient": AMBIENT_MUSIC_PATHS,
}
const MUSIC_STYLE_DEFINITIONS: Array[Dictionary] = [
	{"id": "suno_01", "name": "自定义 BGM 01（默认）", "description": "用户导入的主背景曲；所有战斗阶段默认使用这一首。"},
	{"id": "suno_02", "name": "自定义 BGM 02", "description": "用户导入的第二首背景曲，可在这里即时切换。"},
	{"id": "maximum_breach", "name": "Maximum Breach", "description": "用户导入的高压电子背景曲，适合故障升级与 Boss 战。"},
	{"id": "terminal_overwrite", "name": "Terminal Overwrite", "description": "用户导入的终端主题背景曲，可在所有场景循环播放。"},
	{"id": "unauthorized_entry", "name": "Unauthorized Entry", "description": "用户导入的入侵主题背景曲，可在所有场景循环播放。"},
	{"id": "pulse", "name": "脉冲值班（推荐）", "description": "节奏更清晰的低频律动；保留留白，不用持续高频镲片。"},
	{"id": "ambient", "name": "夜班氛围（原版）", "description": "原有的稀疏氛围电子乐，适合更安静的长时间值班。"},
]
const MUSIC_STYLE_GAINS_DB := {
	"suno_01": -5.0,
	"suno_02": -6.0,
	"maximum_breach": -7.0,
	"terminal_overwrite": -6.5,
	"unauthorized_entry": -7.0,
	"pulse": 0.0,
	"ambient": 0.0,
}
const DEFAULT_MUSIC_STYLE := "suno_01"

const SFX_PATHS := {
	"attack_bash": "res://assets/audio/sfx/attack_bash.wav",
	"attack_ping": "res://assets/audio/sfx/attack_ping.wav",
	"attack_firewall": "res://assets/audio/sfx/attack_firewall.wav",
	"attack_log": "res://assets/audio/sfx/attack_log.wav",
	"attack_wrench": "res://assets/audio/sfx/attack_wrench.wav",
	"attack_rule_chain": "res://assets/audio/sfx/attack_rule_chain.wav",
	"attack_lock_zone": "res://assets/audio/sfx/attack_lock_zone.wav",
	"attack_worker": "res://assets/audio/sfx/attack_worker.wav",
	"attack_database": "res://assets/audio/sfx/attack_database.wav",
	"attack_ticket": "res://assets/audio/sfx/attack_ticket.wav",
	"attack_script": "res://assets/audio/sfx/attack_script.wav",
	"attack_sre": "res://assets/audio/sfx/attack_sre.wav",
	"attack_delivery": "res://assets/audio/sfx/attack_delivery.wav",
	"skill_dash": "res://assets/audio/sfx/skill_dash.wav",
	"skill_scan": "res://assets/audio/sfx/skill_scan.wav",
	"skill_shield": "res://assets/audio/sfx/skill_shield.wav",
	"skill_heal": "res://assets/audio/sfx/skill_heal.wav",
	"skill_deploy": "res://assets/audio/sfx/skill_deploy.wav",
	"ultimate_ops": "res://assets/audio/sfx/ultimate_ops.wav",
	"ultimate_dba": "res://assets/audio/sfx/ultimate_dba.wav",
	"ultimate_network": "res://assets/audio/sfx/ultimate_network.wav",
	"ultimate_security": "res://assets/audio/sfx/ultimate_security.wav",
	"ultimate_infrastructure": "res://assets/audio/sfx/ultimate_infrastructure.wav",
	"ultimate_support": "res://assets/audio/sfx/ultimate_support.wav",
	"ultimate_deploy": "res://assets/audio/sfx/ultimate_deploy.wav",
	"ultimate_ai": "res://assets/audio/sfx/ultimate_ai.wav",
	"ultimate_sre": "res://assets/audio/sfx/ultimate_sre.wav",
	"ultimate_delivery": "res://assets/audio/sfx/ultimate_delivery.wav",
	"elite_fire_warning": "res://assets/audio/sfx/elite_fire_warning.wav",
	"elite_frost_warning": "res://assets/audio/sfx/elite_frost_warning.wav",
	"elite_teleport_warning": "res://assets/audio/sfx/elite_teleport_warning.wav",
	"elite_storm_warning": "res://assets/audio/sfx/elite_storm_warning.wav",
	"elite_volatile_warning": "res://assets/audio/sfx/elite_volatile_warning.wav",
	"elite_shield": "res://assets/audio/sfx/elite_shield.wav",
	"hazard_fire_hit": "res://assets/audio/sfx/hazard_fire_hit.wav",
	"hazard_frost_hit": "res://assets/audio/sfx/hazard_frost_hit.wav",
	"hazard_teleport_hit": "res://assets/audio/sfx/hazard_teleport_hit.wav",
	"hazard_storm_hit": "res://assets/audio/sfx/hazard_storm_hit.wav",
	"hazard_explosion_hit": "res://assets/audio/sfx/hazard_explosion_hit.wav",
	"boss_entrance": "res://assets/audio/sfx/boss_entrance.wav",
	"boss_expose": "res://assets/audio/sfx/boss_expose.wav",
	"boss_phase": "res://assets/audio/sfx/boss_phase.wav",
	"boss_defeat": "res://assets/audio/sfx/boss_defeat.wav",
	"player_hit": "res://assets/audio/sfx/player_hit.wav",
}

const WEAPON_CUES := {
	"bash": "attack_bash",
	"ping": "attack_ping",
	"firewall": "attack_firewall",
	"log": "attack_log",
	"wrench": "attack_wrench",
	"rule_chain": "attack_rule_chain",
	"lock_zone": "attack_lock_zone",
	"worker": "attack_worker",
}

const SIGNATURE_CUES := {
	"terminal_combo": "attack_bash",
	"slow_query_lock": "attack_database",
	"icmp_probe": "attack_ping",
	"zero_trust_wall": "attack_firewall",
	"spare_node": "skill_deploy",
	"ticket_dispatch": "attack_ticket",
	"idempotent_script": "attack_script",
	"slo_budget_ring": "attack_sre",
	"critical_path_trace": "attack_sre",
	"release_package": "attack_delivery",
	"worker_formation": "attack_worker",
	"tensor_pipeline": "attack_worker",
}

const SKILL_CUES := {
	"emergency_dash": "skill_dash",
	"transaction_rollback": "skill_heal",
	"packet_capture": "skill_scan",
	"isolation_corridor": "skill_shield",
	"hot_swap": "skill_deploy",
	"remote_assist": "skill_heal",
	"compile_run": "skill_scan",
	"traffic_shift": "skill_dash",
	"blue_green_switch": "skill_dash",
	"cross_team_sync": "skill_deploy",
	"pod_migration": "skill_dash",
	"pipeline_flush": "skill_scan",
}

const ULTIMATE_CUES := {
	"p1_response": "ultimate_ops",
	"global_commit": "ultimate_dba",
	"network_storm": "ultimate_network",
	"global_block": "ultimate_security",
	"datacenter_control": "ultimate_infrastructure",
	"sla_fast_lane": "ultimate_support",
	"runtime_hot_reload": "ultimate_deploy",
	"budget_freeze": "ultimate_sre",
	"active_active_takeover": "ultimate_sre",
	"full_release": "ultimate_delivery",
	"all_hands_delivery": "ultimate_delivery",
	"gpu_scale_out": "ultimate_ai",
	"foundation_model_online": "ultimate_ai",
}

const MIN_INTERVALS := {
	"attack_bash": 0.10,
	"attack_ping": 0.12,
	"attack_firewall": 0.18,
	"attack_log": 0.16,
	"attack_wrench": 0.11,
	"attack_rule_chain": 0.14,
	"attack_lock_zone": 0.22,
	"attack_worker": 0.13,
	"attack_ticket": 0.14,
	"attack_script": 0.12,
	"attack_sre": 0.18,
	"attack_delivery": 0.18,
	"player_hit": 0.34,
}

const STANDARD_VOICE_COUNT := 8
const WORLD_VOICE_COUNT := 4
const SILENT_DB := -60.0

var music_players: Array[AudioStreamPlayer] = []
var standard_players: Array[AudioStreamPlayer] = []
var world_players: Array[AudioStreamPlayer2D] = []
var standard_busy_until: Array[float] = []
var world_busy_until: Array[float] = []
var standard_priorities: Array[int] = []
var world_priorities: Array[int] = []
var stream_cache: Dictionary = {}
var last_cue_times: Dictionary = {}
var event_counts: Dictionary = {}
var rng := RandomNumberGenerator.new()

var audio_clock := 0.0
var current_music_id := ""
var music_style := DEFAULT_MUSIC_STYLE
var current_music_style := ""
var current_music_index := -1
var fade_from_index := -1
var fade_to_index := -1
var fade_elapsed := 0.0
var fade_duration := 1.2
var duck_left := 0.0
var duck_amount_db := 0.0
var headless_audio := false
var run_combat: Node
var run_actions: Node
var run_swarm: Node
var last_boss_phase := -1
var last_boss_stage := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.seed = 0xA0D10
	headless_audio = DisplayServer.get_name() == "headless" and not OS.get_cmdline_user_args().has("--force-audio-playback-test")
	_build_players()
	if ProfileStore.has_method("apply_audio_settings"):
		ProfileStore.call("apply_audio_settings")
	if ProfileStore.has_method("get_settings"):
		set_music_style(String(ProfileStore.call("get_settings").get("music_style", DEFAULT_MUSIC_STYLE)), 0.01)
	enter_menu()


func _process(delta: float) -> void:
	audio_clock += delta
	duck_left = maxf(0.0, duck_left - delta)
	if duck_left <= 0.0:
		duck_amount_db = move_toward(duck_amount_db, 0.0, delta * 10.0)
	_update_music_fade(delta)


func _build_players() -> void:
	for ignored in range(2):
		var music_player := AudioStreamPlayer.new()
		music_player.bus = &"Music"
		music_player.volume_db = SILENT_DB
		add_child(music_player)
		music_players.append(music_player)
	for ignored in range(STANDARD_VOICE_COUNT):
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		standard_players.append(player)
		standard_busy_until.append(0.0)
		standard_priorities.append(0)
	for ignored in range(WORLD_VOICE_COUNT):
		var player := AudioStreamPlayer2D.new()
		player.bus = &"SFX"
		player.max_distance = 1050.0
		player.attenuation = 1.15
		player.panning_strength = 0.72
		add_child(player)
		world_players.append(player)
		world_busy_until.append(0.0)
		world_priorities.append(0)


func enter_menu() -> void:
	_unbind_run()
	last_boss_phase = -1
	last_boss_stage = -1
	play_music("menu", 1.4)


func bind_run(combat_node: Node, actions_node: Node, swarm_node: Node) -> void:
	_unbind_run()
	run_combat = combat_node
	run_actions = actions_node
	run_swarm = swarm_node
	if is_instance_valid(run_combat) and run_combat.has_signal("attack_fired"):
		run_combat.connect("attack_fired", _on_weapon_fired)
	if is_instance_valid(run_actions) and run_actions.has_signal("action_used"):
		run_actions.connect("action_used", _on_career_action)
	if is_instance_valid(run_swarm):
		if run_swarm.has_signal("elite_skill_cast"):
			run_swarm.connect("elite_skill_cast", _on_elite_skill_cast)
		if run_swarm.has_signal("hazard_activated"):
			run_swarm.connect("hazard_activated", _on_hazard_activated)
		if run_swarm.has_signal("boss_status_changed"):
			run_swarm.connect("boss_status_changed", _on_boss_status_changed)
	last_boss_phase = -1
	last_boss_stage = -1
	play_music("run", 1.15)


func _unbind_run() -> void:
	_disconnect_if_needed(run_combat, "attack_fired", _on_weapon_fired)
	_disconnect_if_needed(run_actions, "action_used", _on_career_action)
	_disconnect_if_needed(run_swarm, "elite_skill_cast", _on_elite_skill_cast)
	_disconnect_if_needed(run_swarm, "hazard_activated", _on_hazard_activated)
	_disconnect_if_needed(run_swarm, "boss_status_changed", _on_boss_status_changed)
	run_combat = null
	run_actions = null
	run_swarm = null


func _disconnect_if_needed(source: Variant, signal_name: StringName, callback: Callable) -> void:
	# A persistent autoload can outlive the scene node stored in this Variant.
	# Validate before casting so a previously-freed Object never crosses a typed
	# Node argument boundary during rapid restarts or test scene churn.
	if not is_instance_valid(source):
		return
	var source_node := source as Node
	if source_node.has_signal(signal_name) and source_node.is_connected(signal_name, callback):
		source_node.disconnect(signal_name, callback)


func set_music_context(context_id: String) -> void:
	if context_id in _active_music_paths():
		play_music(context_id, 1.15 if context_id != "boss" else 1.6)


func set_music_style(style_id: String, transition_duration: float = 0.75) -> bool:
	if style_id not in MUSIC_STYLES:
		return false
	if music_style == style_id and current_music_style == style_id:
		return true
	music_style = style_id
	var context := current_music_id if not current_music_id.is_empty() else "menu"
	play_music(context, transition_duration, true)
	return true


func get_music_style() -> String:
	return music_style


func get_music_style_definitions() -> Array[Dictionary]:
	return MUSIC_STYLE_DEFINITIONS.duplicate(true)


func _active_music_paths() -> Dictionary:
	return Dictionary(MUSIC_STYLES.get(music_style, SUNO_BGM01_PATHS))


func _music_style_gain_db() -> float:
	# The imported MP3s peak much hotter than the project's original loops.
	# Normalize at the player so the setting's Music volume remains consistent.
	return float(MUSIC_STYLE_GAINS_DB.get(music_style, 0.0))


func play_music(music_id: String, transition_duration: float = 1.2, force: bool = false) -> void:
	var music_paths := _active_music_paths()
	if (not force and music_id == current_music_id and current_music_style == music_style) or music_id not in music_paths:
		return
	if headless_audio:
		current_music_id = music_id
		current_music_style = music_style
		current_music_index = 0
		fade_from_index = -1
		fade_to_index = -1
		_record_event("music:" + music_id)
		return
	var stream := _load_music(String(music_paths[music_id]))
	if stream == null:
		return
	var next_index := 0 if current_music_index != 0 else 1
	var next_player := music_players[next_index]
	next_player.stop()
	next_player.stream = stream
	next_player.volume_db = SILENT_DB
	next_player.play()
	fade_from_index = current_music_index
	fade_to_index = next_index
	fade_elapsed = 0.0
	fade_duration = maxf(0.05, transition_duration)
	current_music_index = next_index
	current_music_id = music_id
	current_music_style = music_style
	_record_event("music:" + music_id)


func _load_music(path: String) -> AudioStream:
	var loaded: Resource = load(path)
	if not loaded is AudioStream:
		return null
	var stream := loaded as AudioStream
	if stream is AudioStreamOggVorbis:
		var looping_stream := stream.duplicate() as AudioStreamOggVorbis
		looping_stream.loop = true
		return looping_stream
	if stream is AudioStreamWAV:
		var looping_wav := stream.duplicate() as AudioStreamWAV
		looping_wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		looping_wav.loop_end = int(looping_wav.get_length() * float(looping_wav.mix_rate))
		return looping_wav
	if stream is AudioStreamMP3:
		var looping_mp3 := stream.duplicate() as AudioStreamMP3
		looping_mp3.loop = true
		return looping_mp3
	return stream


func _update_music_fade(delta: float) -> void:
	if headless_audio:
		return
	var pause_duck := 3.0 if get_tree().paused else 0.0
	var total_duck := duck_amount_db + pause_duck
	var music_gain := _music_style_gain_db()
	if fade_to_index < 0:
		if current_music_index >= 0:
			music_players[current_music_index].volume_db = music_gain - total_duck
		return
	fade_elapsed += delta
	var ratio := clampf(fade_elapsed / fade_duration, 0.0, 1.0)
	var fade_in_linear := sin(ratio * PI * 0.5)
	var fade_out_linear := cos(ratio * PI * 0.5)
	music_players[fade_to_index].volume_db = linear_to_db(maxf(0.001, fade_in_linear)) + music_gain - total_duck
	if fade_from_index >= 0:
		music_players[fade_from_index].volume_db = linear_to_db(maxf(0.001, fade_out_linear)) + music_gain - total_duck
	if ratio >= 1.0:
		if fade_from_index >= 0:
			music_players[fade_from_index].stop()
			music_players[fade_from_index].stream = null
		music_players[fade_to_index].volume_db = music_gain - total_duck
		fade_from_index = -1
		fade_to_index = -1


func duck_music(amount_db: float = 4.0, duration: float = 0.8) -> void:
	duck_amount_db = maxf(duck_amount_db, clampf(amount_db, 0.0, 10.0))
	duck_left = maxf(duck_left, duration)


func play_sfx(cue_id: String, priority: int = 1, world_position: Vector2 = Vector2.INF, force: bool = false) -> bool:
	if cue_id not in SFX_PATHS:
		return false
	_record_event("requested:" + cue_id)
	var minimum_interval := float(MIN_INTERVALS.get(cue_id, 0.06))
	if not force and audio_clock - float(last_cue_times.get(cue_id, -999.0)) < minimum_interval:
		_record_event("dropped:rate_limit")
		return false
	last_cue_times[cue_id] = audio_clock
	if headless_audio:
		var accepted_headless := _reserve_headless_voice(cue_id, priority, world_position, force)
		if accepted_headless:
			_record_event("played:" + cue_id)
		else:
			_record_event("dropped:voice_pool")
		return accepted_headless
	var stream := _load_sfx(cue_id)
	if stream == null:
		return false
	var use_world_pool := world_position.is_finite() and priority < 4
	var accepted := _play_world_voice(stream, cue_id, world_position, priority, force) if use_world_pool else _play_standard_voice(stream, cue_id, priority, force)
	if accepted:
		_record_event("played:" + cue_id)
	else:
		_record_event("dropped:voice_pool")
	return accepted


func _reserve_headless_voice(cue_id: String, priority: int, world_position: Vector2, force: bool) -> bool:
	var use_world_pool := world_position.is_finite() and priority < 4
	var busy_until := world_busy_until if use_world_pool else standard_busy_until
	var priorities := world_priorities if use_world_pool else standard_priorities
	var voice_index := _choose_voice(busy_until, priorities, priority, force)
	if voice_index < 0:
		return false
	var duration := 2.8 if cue_id.begins_with("boss_") else (1.6 if cue_id.begins_with("ultimate_") else 0.55)
	busy_until[voice_index] = audio_clock + duration
	priorities[voice_index] = priority
	return true


func _load_sfx(cue_id: String) -> AudioStream:
	if stream_cache.has(cue_id):
		return stream_cache[cue_id] as AudioStream
	var resource: Resource = load(String(SFX_PATHS[cue_id]))
	if not resource is AudioStream:
		return null
	stream_cache[cue_id] = resource
	return resource as AudioStream


func _play_standard_voice(stream: AudioStream, cue_id: String, priority: int, force: bool) -> bool:
	var voice_index := _choose_voice(standard_busy_until, standard_priorities, priority, force)
	if voice_index < 0:
		return false
	var player := standard_players[voice_index]
	player.stop()
	player.stream = stream
	player.pitch_scale = rng.randf_range(0.975, 1.025) if priority <= 2 else 1.0
	player.volume_db = _cue_volume(cue_id)
	player.play()
	standard_busy_until[voice_index] = audio_clock + stream.get_length() / maxf(0.1, player.pitch_scale)
	standard_priorities[voice_index] = priority
	return true


func _play_world_voice(stream: AudioStream, cue_id: String, world_position: Vector2, priority: int, force: bool) -> bool:
	var voice_index := _choose_voice(world_busy_until, world_priorities, priority, force)
	if voice_index < 0:
		return false
	var player := world_players[voice_index]
	player.stop()
	player.stream = stream
	player.global_position = world_position
	player.pitch_scale = rng.randf_range(0.97, 1.03)
	player.volume_db = _cue_volume(cue_id)
	player.play()
	world_busy_until[voice_index] = audio_clock + stream.get_length() / maxf(0.1, player.pitch_scale)
	world_priorities[voice_index] = priority
	return true


func _choose_voice(busy_until: Array[float], priorities: Array[int], requested_priority: int, force: bool) -> int:
	for voice_index in range(busy_until.size()):
		if busy_until[voice_index] <= audio_clock:
			return voice_index
	var lowest_index := 0
	for voice_index in range(1, priorities.size()):
		if priorities[voice_index] < priorities[lowest_index] or priorities[voice_index] == priorities[lowest_index] and busy_until[voice_index] < busy_until[lowest_index]:
			lowest_index = voice_index
	if force or requested_priority > priorities[lowest_index]:
		return lowest_index
	return -1


func _cue_volume(cue_id: String) -> float:
	if cue_id.begins_with("boss_"):
		return -1.5
	if cue_id.begins_with("ultimate_"):
		return -3.0
	if cue_id.begins_with("elite_"):
		return -4.0
	if cue_id.begins_with("hazard_"):
		return -4.5
	if cue_id == "player_hit":
		return -5.0
	return -7.0


func _on_weapon_fired(weapon_id: String, world_position: Vector2, intensity: float) -> void:
	var cue_id := String(WEAPON_CUES.get(weapon_id, ""))
	if not cue_id.is_empty():
		play_sfx(cue_id, 1 + int(intensity >= 1.5), world_position)


func _on_career_action(action_kind: String, action_id: String) -> void:
	var cue_id := ""
	var priority := 1
	match action_kind:
		"signature": cue_id = String(SIGNATURE_CUES.get(action_id, "attack_bash"))
		"skill":
			cue_id = String(SKILL_CUES.get(action_id, "skill_scan"))
			priority = 2
		"ultimate":
			cue_id = String(ULTIMATE_CUES.get(action_id, "ultimate_ops"))
			priority = 4
	if cue_id.is_empty():
		return
	play_sfx(cue_id, priority, Vector2.INF, priority >= 4)
	if priority >= 4:
		duck_music(3.5, 1.15)


func _on_elite_skill_cast(skill_name: String, world_position: Vector2, tier: int) -> void:
	var cue_id := _elite_warning_cue(skill_name)
	var priority := 4 if tier >= 2 else 3
	play_sfx(cue_id, priority, world_position, tier >= 2)
	if tier >= 2:
		duck_music(2.5, 0.55)


func _elite_warning_cue(skill_name: String) -> String:
	if "护盾" in skill_name:
		return "elite_shield"
	if "冻结" in skill_name or "冰" in skill_name:
		return "elite_frost_warning"
	if "切换" in skill_name or "漂移" in skill_name:
		return "elite_teleport_warning"
	if "雷暴" in skill_name or "502" in skill_name:
		return "elite_storm_warning"
	if "自爆" in skill_name or "OOM" in skill_name or "过载" in skill_name or "脉冲" in skill_name:
		return "elite_volatile_warning"
	return "elite_fire_warning"


func _on_hazard_activated(kind: int, world_position: Vector2, tier: int) -> void:
	var cue_id := "hazard_explosion_hit"
	match kind:
		0: cue_id = "hazard_fire_hit"
		1: cue_id = "hazard_frost_hit"
		2: cue_id = "hazard_teleport_hit"
		3: cue_id = "hazard_storm_hit"
		4, 5: cue_id = "hazard_explosion_hit"
	play_sfx(cue_id, 3 if tier >= 2 else 2, world_position)


func _on_boss_status_changed(phase: int, _health: float, _maximum: float) -> void:
	var snapshot: Dictionary = {}
	if is_instance_valid(run_swarm) and run_swarm.has_method("get_boss_combat_snapshot"):
		snapshot = run_swarm.call("get_boss_combat_snapshot")
	var combat_stage := int(snapshot.get("combat_stage", -1))
	if phase == 0 and last_boss_phase != 0:
		play_music("boss", 1.6)
		play_sfx("boss_entrance", 5, Vector2.INF, true)
		duck_music(5.0, 2.6)
	elif phase == 1 and last_boss_phase != 1:
		play_sfx("boss_expose", 5, Vector2.INF, true)
		duck_music(4.0, 1.25)
	elif phase == 1 and combat_stage > last_boss_stage and last_boss_stage >= 0:
		play_sfx("boss_phase", 5, Vector2.INF, true)
		duck_music(3.5, 0.9)
	elif phase == 2 and last_boss_phase != 2:
		play_sfx("boss_defeat", 5, Vector2.INF, true)
		duck_music(5.0, 2.2)
		play_music("recovery", 1.8)
	last_boss_phase = phase
	last_boss_stage = combat_stage


func play_player_hit() -> void:
	play_sfx("player_hit", 2)


func _record_event(event_id: String) -> void:
	event_counts[event_id] = int(event_counts.get(event_id, 0)) + 1


func _exit_tree() -> void:
	_unbind_run()
	for player in music_players:
		player.stop()
		player.stream = null
	for player in standard_players:
		player.stop()
		player.stream = null
	for player in world_players:
		player.stop()
		player.stream = null
	stream_cache.clear()


func reset_debug_counts() -> void:
	event_counts.clear()
	last_cue_times.clear()


func get_audio_asset_paths() -> Dictionary:
	var styles: Dictionary = {}
	for style_id in MUSIC_STYLES:
		styles[style_id] = Dictionary(MUSIC_STYLES[style_id]).duplicate()
	return {"music": _active_music_paths().duplicate(), "music_styles": styles, "sfx": SFX_PATHS.duplicate()}


func get_audio_snapshot() -> Dictionary:
	var active_standard := 0
	for busy_until in standard_busy_until:
		active_standard += int(busy_until > audio_clock)
	var active_world := 0
	for busy_until in world_busy_until:
		active_world += int(busy_until > audio_clock)
	return {
		"music_tracks": _active_music_paths().size(),
		"music_style": music_style,
		"current_music_style": current_music_style,
		"sfx_cues": SFX_PATHS.size(),
		"current_track": current_music_id,
		"standard_pool": standard_players.size(),
		"world_pool": world_players.size(),
		"active_voices": active_standard + active_world,
		"duck_left": duck_left,
		"events": event_counts.duplicate(true),
		"bound": is_instance_valid(run_combat) and is_instance_valid(run_actions) and is_instance_valid(run_swarm),
	}
