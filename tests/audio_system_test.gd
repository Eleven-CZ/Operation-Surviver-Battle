extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var profile := get_root().get_node("ProfileStore")
	var director := get_root().get_node("AudioDirector")
	profile.call("reset_for_tests")
	profile.call("apply_audio_settings")
	_require(bool(director.call("set_music_style", "suno_01")), "the imported BGM01 style is selectable")

	var asset_paths: Dictionary = director.call("get_audio_asset_paths")
	var music_paths: Dictionary = asset_paths["music"]
	var music_styles: Dictionary = asset_paths["music_styles"]
	var sfx_paths: Dictionary = asset_paths["sfx"]
	_require(music_styles.size() == 7, "all five imported BGM tracks plus the two original suites are registered")
	_require(music_paths.size() == 5 and String(director.call("get_music_style")) == "suno_01", "BGM01 is the default five-context score")
	_require(sfx_paths.size() == 44, "the complete combat cue library is registered")
	for style_id in music_styles:
		var style_paths: Dictionary = music_styles[style_id]
		_require(style_paths.size() == 5, "%s supplies every music context" % style_id)
		for music_id in style_paths:
			var path := String(style_paths[music_id])
			_require(FileAccess.file_exists(path), "%s/%s music source exists" % [style_id, music_id])
			var stream: Resource = load(path)
			_require(stream is AudioStream and (stream as AudioStream).get_length() >= 28.0, "%s/%s is a full-length loadable loop" % [style_id, music_id])
	for imported_path in [
		"res://assets/audio/bgm/user/bgm01.ogg",
		"res://assets/audio/bgm/user/bgm02.ogg",
		"res://assets/audio/bgm/user/maximum_breach.ogg",
		"res://assets/audio/bgm/user/terminal_overwrite.ogg",
		"res://assets/audio/bgm/user/unauthorized_entry.ogg",
	]:
		var looped_stream: AudioStream = director.call("_load_music", imported_path)
		_require(looped_stream is AudioStreamOggVorbis and (looped_stream as AudioStreamOggVorbis).loop, "%s is configured as a looping OGG stream" % imported_path)
	for cue_id in sfx_paths:
		var path := String(sfx_paths[cue_id])
		_require(FileAccess.file_exists(path), "%s cue source exists" % cue_id)
		var stream: Resource = load(path)
		_require(stream is AudioStream and (stream as AudioStream).get_length() >= 0.18, "%s is a loadable audible cue" % cue_id)

	for bus_name in ["Master", "Music", "SFX", "UI"]:
		_require(AudioServer.get_bus_index(bus_name) >= 0, "%s audio bus exists" % bus_name)
	profile.call("set_setting", "master_volume", 0.65)
	profile.call("set_setting", "music_volume", 0.40)
	profile.call("set_setting", "sfx_volume", 0.55)
	_require(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))), 0.65), "master volume reaches its bus")
	_require(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))), 0.40), "music volume is independently adjustable")
	_require(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))), 0.55), "SFX volume is independently adjustable")
	_require(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("UI"))), 0.55), "UI feedback follows SFX volume")

	var run: Node = load("res://scenes/run.tscn").instantiate()
	get_root().add_child(run)
	var snapshot: Dictionary = director.call("get_audio_snapshot")
	_require(bool(snapshot["bound"]), "run combat, career actions and swarm are bound")
	_require(String(snapshot["current_track"]) == "run" and String(snapshot["current_music_style"]) == "suno_01", "entering a run selects BGM01 by default")
	_require(bool(director.call("set_music_style", "suno_02")), "BGM02 can be switched on at runtime")
	snapshot = director.call("get_audio_snapshot")
	_require(String(snapshot["current_track"]) == "run" and String(snapshot["current_music_style"]) == "suno_02", "style switching immediately preserves the current music context")
	_require(bool(director.call("set_music_style", "maximum_breach")), "Maximum Breach can be switched on at runtime")
	snapshot = director.call("get_audio_snapshot")
	_require(String(snapshot["current_track"]) == "run" and String(snapshot["current_music_style"]) == "maximum_breach", "new imported BGM switching preserves the current music context")
	_require(not bool(director.call("set_music_style", "unknown")), "unknown BGM styles are rejected safely")
	_require(bool(director.call("set_music_style", "suno_01")), "BGM01 can be restored at runtime")

	director.call("reset_debug_counts")
	var close_position: Vector2 = run.player.global_position + Vector2(28.0, 0.0)
	run.swarm.call("spawn_enemy", 0, close_position)
	run.combat.bash_level = maxi(1, int(run.combat.bash_level))
	run.combat.call("_fire_bash")
	var events: Dictionary = director.call("get_audio_snapshot")["events"]
	_require(int(events.get("requested:attack_bash", 0)) >= 1, "an actual automatic attack requests one aggregate cue")

	director.call("reset_debug_counts")
	run.career_actions.call("debug_cast_signature")
	run.career_actions.call("debug_reset_cooldowns")
	_require(bool(run.career_actions.call("try_skill")), "career skill can be exercised")
	run.career_actions.call("debug_reset_cooldowns")
	_require(bool(run.career_actions.call("try_ultimate")), "career ultimate can be exercised")
	events = director.call("get_audio_snapshot")["events"]
	_require(int(events.get("requested:attack_bash", 0)) >= 1, "career signature has an attack identity")
	_require(int(events.get("requested:skill_dash", 0)) == 1, "career skill has an activation cue")
	_require(int(events.get("requested:ultimate_ops", 0)) == 1, "career ultimate has a signature cue")

	director.call("reset_debug_counts")
	run.call("_spawn_boss")
	run.call("_spawn_boss")
	events = director.call("get_audio_snapshot")["events"]
	_require(int(events.get("requested:boss_entrance", 0)) == 1, "Boss entrance cue fires exactly once")
	_require(String(director.call("get_audio_snapshot")["current_track"]) == "boss", "Boss entrance switches to the incident-core score")
	run.swarm.call("expose_boss")
	events = director.call("get_audio_snapshot")["events"]
	_require(int(events.get("requested:boss_expose", 0)) == 1, "Boss root exposure has a distinct cue")
	var boss_index := int(run.swarm.call("_find_kind", 7))
	_require(boss_index >= 0, "Boss remains available for phase audio validation")
	run.swarm.health[boss_index] = run.swarm.maximum_health[boss_index] * 0.65
	run.swarm.boss_status_changed.emit(1, run.swarm.health[boss_index], run.swarm.maximum_health[boss_index])
	events = director.call("get_audio_snapshot")["events"]
	_require(int(events.get("requested:boss_phase", 0)) == 1, "Boss health-stage transition has a distinct cue")

	director.call("reset_debug_counts")
	run.swarm.elite_skill_cast.emit("冻结锁", run.player.global_position, 1)
	run.swarm.hazard_activated.emit(1, run.player.global_position, 1)
	events = director.call("get_audio_snapshot")["events"]
	_require(int(events.get("requested:elite_frost_warning", 0)) == 1, "elite affix telegraph is sonically identifiable")
	_require(int(events.get("requested:hazard_frost_hit", 0)) == 1, "hazard activation is separate from its telegraph")

	var child_count_before := director.get_child_count()
	director.call("reset_debug_counts")
	for ignored in range(1000):
		director.call("play_sfx", "attack_ping", 1)
	snapshot = director.call("get_audio_snapshot")
	_require(director.get_child_count() == child_count_before, "sound storms never allocate additional players")
	_require(int(snapshot["active_voices"]) <= int(snapshot["standard_pool"]) + int(snapshot["world_pool"]), "active voices stay inside the fixed pool")
	_require(int(Dictionary(snapshot["events"]).get("dropped:rate_limit", 0)) > 900, "repeated attacks are aggressively rate-limited")

	director.call("enter_menu")
	get_root().remove_child(run)
	run.free()
	profile.call("set_setting", "master_volume", 0.85)
	profile.call("set_setting", "music_volume", 0.76)
	profile.call("set_setting", "sfx_volume", 0.86)
	print("AUDIO_SYSTEM_TEST_PASS music=7x5 sfx=%d voices=%d+%d boss_once=true" % [sfx_paths.size(), snapshot["standard_pool"], snapshot["world_pool"]])
	quit(0)


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("AUDIO_SYSTEM_TEST_FAIL: " + message)
	quit(1)
