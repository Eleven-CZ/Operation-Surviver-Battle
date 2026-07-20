extends SceneTree

const UI_FONT := preload("res://assets/fonts/NotoSansSC-VF.ttf")
const REQUIRED_TEXT := "远程协助稳定窗口按住对齐财务伙伴产品经理"
const SOURCE_ROOTS: Array[String] = ["res://scripts", "res://scenes"]
const SOURCE_EXTENSIONS: Array[String] = ["gd", "tscn", "tres"]

var failures: Array[String] = []
var first_source_by_codepoint: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_project_setting()
	_collect_required_characters()
	_check_font_coverage(UI_FONT, "bundled font")
	_check_control_theme()
	if failures.is_empty():
		print("FONT_COVERAGE_TEST_PASS cjk=%d font=NotoSansSC-VF.ttf" % first_source_by_codepoint.size())
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check_project_setting() -> void:
	var configured_path := String(ProjectSettings.get_setting("gui/theme/custom_font", ""))
	if configured_path != "res://assets/fonts/NotoSansSC-VF.ttf":
		failures.append("gui/theme/custom_font is not wired to the bundled CJK font: %s" % configured_path)


func _collect_required_characters() -> void:
	_record_text(REQUIRED_TEXT, "required sentinel")
	for root_path in SOURCE_ROOTS:
		_collect_directory(root_path)


func _collect_directory(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		failures.append("Unable to scan font source directory: %s" % path)
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var entry_path := path.path_join(entry)
			if directory.current_is_dir():
				_collect_directory(entry_path)
			elif entry.get_extension().to_lower() in SOURCE_EXTENSIONS:
				_record_text(FileAccess.get_file_as_string(entry_path), entry_path)
		entry = directory.get_next()
	directory.list_dir_end()


func _record_text(text: String, source_path: String) -> void:
	for character in text:
		var codepoint := character.unicode_at(0)
		if _is_cjk_codepoint(codepoint) and not first_source_by_codepoint.has(codepoint):
			first_source_by_codepoint[codepoint] = source_path


func _check_font_coverage(font: Font, context: String) -> void:
	var missing: Array[String] = []
	var codepoints := first_source_by_codepoint.keys()
	codepoints.sort()
	for codepoint_value in codepoints:
		var codepoint := int(codepoint_value)
		if not font.has_char(codepoint):
			missing.append("%s(U+%04X from %s)" % [String.chr(codepoint), codepoint, first_source_by_codepoint[codepoint]])
	if not missing.is_empty():
		failures.append("%s is missing CJK glyphs: %s" % [context, ", ".join(missing)])


func _check_control_theme() -> void:
	var label := Label.new()
	label.text = REQUIRED_TEXT
	get_root().add_child(label)
	var effective_font := label.get_theme_font("font")
	_check_font_coverage(effective_font, "effective Label theme font")
	label.queue_free()


func _is_cjk_codepoint(codepoint: int) -> bool:
	return (
		(codepoint >= 0x3400 and codepoint <= 0x4DBF)
		or (codepoint >= 0x4E00 and codepoint <= 0x9FFF)
		or (codepoint >= 0xF900 and codepoint <= 0xFAFF)
		or (codepoint >= 0x20000 and codepoint <= 0x2FA1F)
	)
