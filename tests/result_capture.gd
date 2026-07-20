extends SceneTree

const CareerCatalog := preload("res://scripts/career_catalog.gd")

var run: Node
var frame_count := 0


func _initialize() -> void:
	run = load("res://scenes/run.tscn").instantiate()
	get_root().add_child(run)


func _show_mock_result() -> void:
	paused = true
	var settlement := {
		"total": 106,
		"mastery": 19,
		"mastery_total": 22,
		"mastery_rank": {"tier": 1, "title": "独立值班", "score": 22, "next_threshold": 60},
		"rank_up": true,
		"balance": 143,
		"unlocks": ["dba", "helpdesk"],
		"breakdown": [
			{"label": "完成值班记录", "value": 8},
			{"label": "遥测与闭环", "value": 30},
			{"label": "精英故障", "value": 12},
			{"label": "War Room 协作", "value": 8},
			{"label": "发布窗口", "value": 8},
			{"label": "岗位协议执行", "value": 8},
			{"label": "恢复验证", "value": 32},
		],
	}
	run.get_node("HUD").call("show_result", true, "发布：成功：金丝雀指标稳定\n职业：运维工程师  ·  等级：12\n事故核心已关闭并完成恢复验证。", settlement, CareerCatalog.get_by_id("ops"))


func _process(_delta: float) -> bool:
	frame_count += 1
	if frame_count == 3:
		_show_mock_result()
	if frame_count < 12:
		return false
	var image := get_root().get_viewport().get_texture().get_image()
	var output_path := "/private/tmp/it_battle_result.png"
	var save_error := image.save_png(output_path)
	print("RESULT_CAPTURE %s size=%s error=%d" % [output_path, image.get_size(), save_error])
	quit(0 if save_error == OK else 1)
	return true
