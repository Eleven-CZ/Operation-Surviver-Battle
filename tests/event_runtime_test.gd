extends SceneTree

const EventCatalog := preload("res://scripts/event_catalog.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var profile := get_root().get_node("ProfileStore")
	profile.reset_for_tests()
	for event_definition in EventCatalog.all():
		var event_id := String(event_definition["id"])
		_require(profile.select_event(event_id), "%s can be selected" % event_id)
		var run: Node = load("res://scenes/run.tscn").instantiate()
		get_root().add_child(run)
		run.set_process(false)
		run.get_node("SwarmWorld").set_physics_process(false)
		run.get_node("Player").set_physics_process(false)
		run.get_node("CombatSystem").set_process(false)
		_require(String(run.event_id) == event_id, "%s reaches the event director" % event_id)
		_require(String(run.event_data["name"]) == String(event_definition["name"]), "%s loads its catalog record" % event_id)
		var first_strategy: Dictionary = event_definition["strategies"][0]
		run.call("_start_event_prompt")
		_require(bool(run.event_prompted), "%s opens once" % event_id)
		run.call("_on_event_strategy_selected", event_id, String(first_strategy["id"]))
		_require(bool(run.event_active), "%s starts its strategy" % event_id)
		_require(int(run.event_required) > 0 and float(run.event_time_left) > 0.0, "%s has a real target and timer" % event_id)
		run.event_progress = int(run.event_required)
		if event_id == "release":
			run.get_node("PressureProjection").ally = true
		elif event_id == "backup_restore":
			run.event_integrity = maxf(float(run.event_integrity_min) + 10.0, 80.0)
		run.call("_update_special_event", 0.01)
		_require(String(run.event_outcome) == "success", "%s has an enum-backed success path" % event_id)
		var result: Dictionary = run.call("_build_run_result", false)
		var events: Array = result.get("events", [])
		_require(events.size() == 1, "%s writes one structured event result" % event_id)
		_require(String(events[0]["event_id"]) == event_id and String(events[0]["outcome"]) == "success", "%s result is authoritative" % event_id)
		_require(bool(result["release_success"]) == (event_id == "release"), "legacy release flag never aliases another event")
		paused = false
		get_root().remove_child(run)
		run.free()
	_require(EventCatalog.ids() == ["release", "version_update", "troubleshoot", "backup_restore"], "the four named events stay in the contract pool")
	print("EVENT_RUNTIME_TEST_PASS events=4 strategies=12")
	quit(0)


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("EVENT_RUNTIME_TEST_FAIL: " + message)
	paused = false
	quit(1)
