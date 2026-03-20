extends Window

## 通用 Python 脚本编辑器，与 Bot 解耦
## 支持打开、编辑、另存为，实时 Python 语法校验

@onready var code_edit: CodeEdit = $%CodeEdit
@onready var error_label: RichTextLabel = $%ErrorLabel
@onready var syntax_checker = $%PythonSyntaxChecker

var _current_file_path: String = ""
var _closing: bool = false
var _dirty: bool = false

func _get_scripts_root() -> String:
	return ProjectSettings.globalize_path("user://scripts").replace("\\", "/")

func _is_path_under_scripts(path: String) -> bool:
	var normalized: String = ProjectSettings.globalize_path(path).replace("\\", "/")
	return normalized.begins_with(_get_scripts_root())

const _python_syntax_highlighter := preload("res://PythonHighlighter.tres")

func _ready() -> void:
	_update_title()
	code_edit.syntax_highlighter = _python_syntax_highlighter.duplicate()
	code_edit.delimiter_comments = PackedStringArray(["#"])
	$%Open.pressed.connect(_on_open_pressed)
	$%Save.pressed.connect(_on_save_pressed)
	$%SaveAs.pressed.connect(_on_save_as_pressed)
	$%FileDialog.file_selected.connect(_on_file_selected)
	$%SaveAsFileDialog.file_selected.connect(_on_save_as_file_selected)
	close_requested.connect(_on_close_requested)
	focus_entered.connect(_on_focus_entered)
	code_edit.text_changed.connect(_on_text_changed)
	_apply_check_result()

func _get_display_title() -> String:
	if _current_file_path.is_empty():
		return "未命名"
	var scripts_root: String = _get_scripts_root()
	var normalized: String = ProjectSettings.globalize_path(_current_file_path).replace("\\", "/")
	if normalized.begins_with(scripts_root):
		return normalized.substr(scripts_root.length()).trim_prefix("/")
	return _current_file_path.get_file()

func _is_file_deleted() -> bool:
	return not _current_file_path.is_empty() and not FileAccess.file_exists(_current_file_path)

func _update_title() -> void:
	var base_name: String = _get_display_title()
	if _is_file_deleted() or _current_file_path.is_empty():
		title = "[未命名文件]"
	elif _dirty:
		title = "[*] " + base_name
	else:
		title = base_name

func _load_file(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	code_edit.text = file.get_as_text() if file else ""

func _save_to_path(path: String) -> bool:
	var dir_path: String = path.get_base_dir()
	if dir_path.begins_with("user://"):
		dir_path = ProjectSettings.globalize_path(dir_path)
	DirAccess.make_dir_recursive_absolute(dir_path)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(code_edit.text)
		file.close()
		_dirty = false
		_update_title()
		return true
	return false

func _on_text_changed() -> void:
	_dirty = true
	_update_title()
	_apply_check_result()

func _on_focus_entered() -> void:
	if not _dirty and not _current_file_path.is_empty() and not _is_file_deleted():
		_load_file(_current_file_path)
	else:
		_update_title()

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and key_event.ctrl_pressed and key_event.keycode == KEY_S:
			_try_save()
			get_viewport().set_input_as_handled()

func _try_save() -> void:
	if _is_file_deleted() or _current_file_path.is_empty():
		_on_save_as_pressed()
	else:
		_save_to_path(_current_file_path)
		_apply_check_result()

func _on_save_pressed() -> void:
	_try_save()

func _apply_check_result() -> void:
	var result: Dictionary = await syntax_checker.check(code_edit.text)
	if _closing:
		return
	_apply_syntax_result(result)

func _apply_syntax_result(result: Dictionary) -> void:
	var text: String = result.message
	if text.is_empty():
		error_label.visible = false
	else:
		error_label.visible = true
		error_label.text = result.message
	code_edit.clear_bookmarked_lines()
	var lines: Array[int] = []
	for item in result.get("lines", []):
		lines.append(int(item))
	if lines.is_empty() and not result.message.is_empty():
		var parsed_line: int = _parse_error_line(result.message)
		if parsed_line >= 0:
			lines.append(parsed_line + 1)
	for line_one_based in lines:
		var line_index: int = line_one_based - 1
		if line_index >= 0 and line_index < code_edit.get_line_count():
			code_edit.set_line_as_bookmarked(line_index, true)

func _parse_error_line(msg: String) -> int:
	var regex := RegEx.new()
	regex.compile("(?:line|行)\\s*(\\d+)")
	var search_result := regex.search(msg)
	return int(search_result.get_string(1)) - 1 if search_result else -1

func _on_open_pressed() -> void:
	$%FileDialog.popup_centered()

func open_file(path: String) -> void:
	if not _is_path_under_scripts(path):
		push_error("请选择 user://scripts/ 目录下的脚本")
		return
	_current_file_path = path.replace("\\", "/")
	_dirty = false
	_update_title()
	_load_file(_current_file_path)
	_apply_check_result()
	popup_centered()

func _on_file_selected(selected_path: String) -> void:
	open_file(selected_path)

func _on_save_as_pressed() -> void:
	$%SaveAsFileDialog.current_file = _current_file_path.get_file() if not _current_file_path.is_empty() else "script.py"
	$%SaveAsFileDialog.popup_centered()

func _on_save_as_file_selected(selected_path: String) -> void:
	if not _is_path_under_scripts(selected_path):
		push_error("请保存到 user://scripts/ 目录下")
		return
	var normalized: String = selected_path.replace("\\", "/")
	_save_to_path(normalized)
	_current_file_path = normalized
	_apply_check_result()

func _on_close_requested() -> void:
	_closing = true
	syntax_checker.set_closing(true)
	if not _is_file_deleted() and not _current_file_path.is_empty():
		_save_to_path(_current_file_path)
	queue_free()
