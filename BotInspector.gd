extends Window

## 点击 Bot 时弹出，用于编辑该 Bot 的代码
## CodeEdit 启用 Python 语法高亮和断点槽
## 实时校验 Python 语法并在 ErrorLabel 显示错误

const _python_syntax_highlighter := preload("res://PythonHighlighter.tres")

@onready var code_edit: CodeEdit = $%CodeEdit
@onready var error_label: RichTextLabel = $%ErrorLabel
@onready var console: RichTextLabel = $%Console
@onready var syntax_checker = $%PythonSyntaxChecker

var bot: Bot
var _poll_timer: Timer
var _closing: bool = false
var _executing_line_index: int = -1
var _dirty: bool = false
var _connector: Control

const _EXECUTING_LINE_BG := Color(0.98, 0.89, 0.27, 0.25)
const _CONNECTOR_LINE_COLOR := Color.WHITE
const _CONNECTOR_CIRCLE_RADIUS := 4.0

func _ready() -> void:
	_setup_connector()
	_update_title()
	code_edit.syntax_highlighter = _python_syntax_highlighter.duplicate()
	code_edit.delimiter_comments = PackedStringArray(["#"])
	_load_py_file()
	_update_switch_text()
	$%Switch.pressed.connect(_on_switch_pressed)
	$%Open.pressed.connect(_on_open_pressed)
	$%Save.pressed.connect(_on_save_pressed)
	$%SaveAs.pressed.connect(_on_save_as_pressed)
	$%FileDialog.file_selected.connect(_on_file_selected)
	$%SaveAsFileDialog.file_selected.connect(_on_save_as_file_selected)
	close_requested.connect(_on_close_requested)
	focus_entered.connect(_on_focus_entered)
	_poll_timer = Timer.new()
	_poll_timer.wait_time = 0.3
	_poll_timer.timeout.connect(_poll_python_process)
	add_child(_poll_timer)
	code_edit.text_changed.connect(_on_text_changed)
	if not bot.bridge.is_running:
		_apply_check_result()
	bot.log_added.connect(_on_log_added)
	bot.current_line_changed.connect(_on_current_line_changed)
	_display_all_logs()

func _setup_connector() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	var drawer := Control.new()
	drawer.set_anchors_preset(Control.PRESET_FULL_RECT)
	drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drawer.draw.connect(_draw_connector.bind(drawer))
	layer.add_child(drawer)
	get_tree().root.add_child(layer)
	_connector = drawer
	_connector.set_meta("_connector_layer", layer)

func _process(_delta: float) -> void:
	if is_instance_valid(_connector):
		_connector.queue_redraw()

func _draw_connector(drawer: Control) -> void:
	if not is_instance_valid(bot):
		return
	var bot_canvas_pos: Vector2 = bot.get_global_transform_with_canvas().origin
	var window_rect := Rect2(get_position(), get_size())
	var start_point := _window_center(window_rect)
	drawer.draw_line(start_point, bot_canvas_pos, _CONNECTOR_LINE_COLOR)
	drawer.draw_arc(bot_canvas_pos, _CONNECTOR_CIRCLE_RADIUS, 0.0, TAU, 16, _CONNECTOR_LINE_COLOR)
	drawer.draw_circle(bot_canvas_pos, _CONNECTOR_CIRCLE_RADIUS * 0.5, _CONNECTOR_LINE_COLOR)

func _window_center(window_rect: Rect2) -> Vector2:
	return window_rect.get_center()

func _display_all_logs() -> void:
	var bot_logs: Array = bot.logs
	var lines: PackedStringArray = []
	for entry in bot_logs:
		lines.append((entry as ConsoleLogEntry).to_bbcode_line())
	console.text = "\n".join(lines) + "\n"

func _on_log_added(_entry: ConsoleLogEntry) -> void:
	if bot.logs.size() >= Bot.MAX_LOG_LINES:
		_display_all_logs()
	else:
		console.append_text(_entry.to_bbcode_line() + "\n")

func _clear_executing_line_highlight() -> void:
	if _executing_line_index >= 0 and _executing_line_index < code_edit.get_line_count():
		code_edit.set_line_background_color(_executing_line_index, Color(0, 0, 0, 0))
	_executing_line_index = -1

func _on_current_line_changed(line_one_based: int) -> void:
	_clear_executing_line_highlight()
	var line_index: int = line_one_based - 1
	if line_index >= 0 and line_index < code_edit.get_line_count():
		code_edit.set_line_background_color(line_index, _EXECUTING_LINE_BG)
		_executing_line_index = line_index

func _update_switch_text() -> void:
	var running: bool = bot.bridge.is_running
	$%Switch.text = "🛑" if running else "▶"
	$%Open.visible = not running
	$%Save.visible = not running
	$%SaveAs.visible = not running
	code_edit.editable = not running

func _poll_python_process() -> void:
	var bridge: BotBridge = bot.bridge
	if not bridge.is_running and bridge.python_pid >= 0:
		bridge.close()
		_poll_timer.stop()
		_clear_executing_line_highlight()
	_update_switch_text()

func _get_relative_py_path() -> String:
	return bot.py_path.path_relative_to_user.trim_prefix("scripts/")

func _is_file_deleted() -> bool:
	var path: String = bot.py_path.resolved_py_path
	return not path.is_empty() and not FileAccess.file_exists(path)

func _update_title() -> void:
	var base_name: String = _get_relative_py_path()
	if _is_file_deleted() or base_name.is_empty():
		title = "[未命名文件]"
	elif _dirty:
		title = "[*] " + base_name
	else:
		title = base_name

func _load_py_file() -> void:
	bot.ensure_py_file_exists()
	var path: String = bot.py_path.resolved_py_path
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	code_edit.text = file.get_as_text() if file else ""

func _save_py_file() -> bool:
	var path: String = bot.py_path.resolved_py_path
	if path.is_empty():
		return false
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
	if not bot.bridge.is_running:
		_apply_check_result()

func _on_focus_entered() -> void:
	if not _dirty and not _is_file_deleted():
		_load_py_file()
	else:
		_update_title()

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and key_event.ctrl_pressed and key_event.keycode == KEY_S:
			_try_save()
			get_viewport().set_input_as_handled()

func _try_save() -> void:
	if _is_file_deleted() or bot.py_path.resolved_py_path.is_empty():
		_on_save_as_pressed()
	else:
		_save_py_file()
		if not bot.bridge.is_running:
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

func _on_switch_pressed() -> void:
	var bridge: BotBridge = bot.bridge
	if bridge.is_running:
		bridge.close()
		_poll_timer.stop()
		_clear_executing_line_highlight()
		_update_switch_text()
		return
	if bot.bot_id < 0:
		push_error("Bot 的 bot_id 未设置")
		return
	bot.logs.clear()
	console.text = ""
	if bridge.start_process():
		_poll_timer.start()
	_update_switch_text()


func _on_open_pressed() -> void:
	$%FileDialog.popup_centered()


func _on_file_selected(selected_path: String) -> void:
	var normalized: String = selected_path.replace("\\", "/")
	var prefix: String = "user://scripts/"
	if not normalized.begins_with(prefix):
		push_error("请选择 user://scripts/ 目录下的脚本")
		return
	var relative: String = normalized.substr(prefix.length()).trim_prefix("/")
	bot.py_path.path_relative_to_scripts = relative
	_dirty = false
	_update_title()
	_load_py_file()
	if not bot.bridge.is_running:
		_apply_check_result()


func _on_save_as_pressed() -> void:
	$%SaveAsFileDialog.current_file = bot.py_path.resolved_py_path.get_file()
	$%SaveAsFileDialog.popup_centered()


func _on_save_as_file_selected(selected_path: String) -> void:
	var normalized: String = selected_path.replace("\\", "/")
	var prefix: String = "user://scripts/"
	if not normalized.begins_with(prefix):
		push_error("请保存到 user://scripts/ 目录下")
		return
	var relative: String = normalized.substr(prefix.length()).trim_prefix("/")
	bot.py_path.path_relative_to_scripts = relative
	var dir_path: String = selected_path.get_base_dir()
	if dir_path.begins_with("user://"):
		dir_path = ProjectSettings.globalize_path(dir_path)
	DirAccess.make_dir_recursive_absolute(dir_path)
	var file: FileAccess = FileAccess.open(selected_path, FileAccess.WRITE)
	if file:
		file.store_string(code_edit.text)
		file.close()
	_dirty = false
	_update_title()
	if not bot.bridge.is_running:
		_apply_check_result()


func _on_close_requested() -> void:
	_save_and_close()


func _save_and_close() -> void:
	_closing = true
	syntax_checker.set_closing(true)
	if not _is_file_deleted() and not bot.py_path.resolved_py_path.is_empty():
		_save_py_file()
	if _connector and _connector.has_meta("_connector_layer"):
		_connector.get_meta("_connector_layer").queue_free()
	queue_free()
