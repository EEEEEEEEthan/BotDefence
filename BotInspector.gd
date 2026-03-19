extends Window

## 点击 Bot 时弹出，用于编辑该 Bot 的代码
## CodeEdit 启用 Python 语法高亮和断点槽
## 实时校验 Python 语法并在 ErrorLabel 显示错误

@onready var code_edit: CodeEdit = $%CodeEdit
@onready var error_label: RichTextLabel = $%ErrorLabel
@onready var console: RichTextLabel = $%Console
@onready var syntax_checker = $%PythonSyntaxChecker

var bot: Bot
var _poll_timer: Timer
var _closing: bool = false
var _executing_line_index: int = -1

const _EXECUTING_LINE_BG := Color(0.98, 0.89, 0.27, 0.25)

func _ready() -> void:
	title = _get_relative_py_path()
	code_edit.syntax_highlighter = _create_python_highlighter()
	code_edit.delimiter_comments = PackedStringArray(["#"])
	_load_py_file()
	_update_switch_text()
	$%Switch.pressed.connect(_on_switch_pressed)
	close_requested.connect(_on_close_requested)
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

func _display_all_logs() -> void:
	var bot_logs: Array = bot.logs
	var lines: PackedStringArray = []
	for entry in bot_logs:
		lines.append((entry as ConsoleLogEntry).to_bbcode_line())
	console.text = "\n".join(lines) + "\n"

func _on_log_added(entry: ConsoleLogEntry) -> void:
	console.append_text(entry.to_bbcode_line() + "\n")

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

func _load_py_file() -> void:
	bot.ensure_py_file_exists()
	var path: String = bot.py_path.resolved_py_path
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	code_edit.text = file.get_as_text() if file else ""

func _save_py_file() -> void:
	var path: String = bot.py_path.resolved_py_path
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(code_edit.text)
		file.close()

func _on_text_changed() -> void:
	_save_py_file()
	if not bot.bridge.is_running:
		_apply_check_result()

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

func _create_python_highlighter() -> CodeHighlighter:
	var highlighter := CodeHighlighter.new()
	highlighter.add_color_region("#", "", Color(0.4, 0.6, 0.4, 1), true)
	highlighter.add_color_region("\"", "\"", Color(0.8, 0.5, 0.2, 1), false)
	highlighter.add_color_region("'", "'", Color(0.8, 0.5, 0.2, 1), false)
	highlighter.add_color_region("\"\"\"", "\"\"\"", Color(0.6, 0.7, 0.5, 1), false)
	highlighter.add_color_region("'''", "'''", Color(0.6, 0.7, 0.5, 1), false)
	highlighter.function_color = Color(0.2, 0.5, 0.9, 1)
	highlighter.member_variable_color = Color(0.4, 0.6, 0.2, 1)
	highlighter.number_color = Color(0.6, 0.4, 0.2, 1)
	highlighter.symbol_color = Color(0.5, 0.5, 0.5, 1)
	var keyword_color := Color(0.8, 0.4, 0.2, 1)
	var builtin_color := Color(0.6, 0.2, 0.8, 1)
	var def_color := Color(0.2, 0.5, 0.9, 1)
	var class_color := Color(0.6, 0.2, 0.8, 1)
	var keywords := ["and", "as", "assert", "async", "await", "break", "continue", "del",
		"elif", "else", "except", "finally", "for", "from", "global", "if", "import",
		"in", "is", "lambda", "nonlocal", "not", "or", "pass", "raise", "return",
		"try", "while", "with", "yield"]
	for keyword in keywords:
		highlighter.add_keyword_color(keyword, keyword_color)
	highlighter.add_keyword_color("def", def_color)
	highlighter.add_keyword_color("class", class_color)
	highlighter.add_keyword_color("True", builtin_color)
	highlighter.add_keyword_color("False", builtin_color)
	highlighter.add_keyword_color("None", builtin_color)
	return highlighter

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


func _on_close_requested() -> void:
	_save_and_close()


func _save_and_close() -> void:
	_closing = true
	syntax_checker.set_closing(true)
	_save_py_file()
	queue_free()
