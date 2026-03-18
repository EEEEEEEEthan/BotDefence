extends Window

## 点击 Bot 时弹出，用于编辑该 Bot 的代码
## CodeEdit 启用 GDScript 语法高亮和断点槽
## 实时校验语法并在 ErrorLabel 显示错误

const HIGHLIGHTER := preload("res://GDScriptHighlighter.tres")
const VALIDATE_DEBOUNCE_SEC := 0.3

class ParseErrorCapture extends Logger:
	var errors: Array[Dictionary] = []
	var _mutex: Mutex = Mutex.new()

	func _log_error(_function: String, _file: String, error_line: int, code: String, rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array) -> void:
		_mutex.lock()
		var msg: String = rationale if rationale else code
		errors.append({"message": msg, "line": error_line})
		_mutex.unlock()

@onready var code_edit: CodeEdit = $%CodeEdit
@onready var error_label: Label = $%ErrorLabel
@onready var console: RichTextLabel = $%Console

var bot: Node2D
var _validate_timer: Timer
var _poll_timer: Timer

func _ready() -> void:
	code_edit.text = bot.code
	code_edit.syntax_highlighter = HIGHLIGHTER.duplicate()
	_update_switch_text()
	$%Switch.pressed.connect(_on_switch_pressed)
	close_requested.connect(_on_close_requested)
	_poll_timer = Timer.new()
	_poll_timer.wait_time = 0.3
	_poll_timer.timeout.connect(_poll_python_process)
	add_child(_poll_timer)
	code_edit.text_changed.connect(_on_text_changed)
	_validate_timer = Timer.new()
	_validate_timer.one_shot = true
	_validate_timer.timeout.connect(_validate_syntax)
	add_child(_validate_timer)
	_validate_syntax()
	bot.log_added.connect(_on_log_added)
	_display_all_logs()

func _display_all_logs() -> void:
	var bot_logs: Array = (bot as Bot).logs
	var lines: PackedStringArray = []
	for entry in bot_logs:
		lines.append((entry as ConsoleLogEntry).to_bbcode_line())
	console.text = "\n".join(lines) + "\n"

func _on_log_added(entry: ConsoleLogEntry) -> void:
	console.append_text(entry.to_bbcode_line() + "\n")

func _update_switch_text() -> void:
	var running: bool = bot.python_pid >= 0 and OS.is_process_running(bot.python_pid)
	$%Switch.text = "🛑" if running else "▶"

func _poll_python_process() -> void:
	if bot.python_pid < 0:
		return
	if not OS.is_process_running(bot.python_pid):
		bot.python_pid = -1
		_poll_timer.stop()
		if bot is Bot:
			(bot as Bot).bridge = null
	_update_switch_text()

func _on_text_changed() -> void:
	_validate_timer.start(VALIDATE_DEBOUNCE_SEC)

func _validate_syntax() -> void:
	bot.code = code_edit.text
	var result := _check_syntax(code_edit.text)
	var text: String = result.message
	if not text:
		error_label.visible = false
	else:
		error_label.visible = true
		error_label.text = result.message
	code_edit.clear_bookmarked_lines()
	var lines: Array[int] = result.lines
	if lines.is_empty() and result.message:
		var parsed_line: int = _parse_error_line(result.message)
		if parsed_line >= 0:
			lines.append(parsed_line + 1)  ## 0-based → 1-based 用于 bookmark
	for line_one_based in lines:
		var line_index: int = line_one_based - 1
		if line_index >= 0 and line_index < code_edit.get_line_count():
			code_edit.set_line_as_bookmarked(line_index, true)

func _check_syntax(source: String) -> Dictionary:
	var empty_lines: Array[int] = []
	var empty: Dictionary = {"message": "", "lines": empty_lines}
	if source.is_empty():
		return empty
	var capture: ParseErrorCapture = ParseErrorCapture.new()
	OS.add_logger(capture)
	var gdscript := GDScript.new()
	gdscript.source_code = source
	var err := gdscript.reload()
	OS.remove_logger(capture)
	if err == OK:
		return empty
	if err == ERR_PARSE_ERROR:
		var lines: Array[int] = []
		var msg_parts: Array[String] = []
		var cap_errors: Array[Dictionary] = capture.errors
		for err_item in cap_errors:
			var item_msg: String = err_item.get("message", "")
			var item_line: int = err_item.get("line", -1)
			if item_msg:
				msg_parts.append("第%d行: %s" % [item_line, item_msg] if item_line > 0 else item_msg)
			if item_line > 0:
				lines.append(item_line)
		if msg_parts.is_empty():
			msg_parts.append("语法错误")
		return {"message": "\n".join(msg_parts), "lines": lines}
	return {"message": "加载失败 (错误码 %d)" % err, "lines": empty_lines}

func _parse_error_line(msg: String) -> int:
	var regex := RegEx.new()
	regex.compile("(?:at |行 ?|line )?(\\d+)")
	var result := regex.search(msg)
	return int(result.get_string(1)) - 1 if result else -1


func _on_switch_pressed() -> void:
	if bot.python_pid >= 0 and OS.is_process_running(bot.python_pid):
		OS.kill(bot.python_pid)
		bot.python_pid = -1
		_poll_timer.stop()
		if bot is Bot:
			(bot as Bot).bridge = null
		_update_switch_text()
		return
	var game: Game = bot.get_parent() as Game
	if not game or game.bot_server_port < 0:
		push_error("Bot 服务器未就绪")
		return
	if bot.bot_id < 0:
		push_error("Bot 的 bot_id 未设置")
		return
	if bot is Bot:
		(bot as Bot).logs.clear()
		console.text = ""
	var project_root: String = ProjectSettings.globalize_path("res://").trim_suffix("/")
	var script_path: String = project_root + "/.bot/runner.py"
	bot.python_pid = OS.create_process("python", PackedStringArray([script_path, str(game.bot_server_port), str(bot.bot_id)]))
	_poll_timer.start()
	_update_switch_text()


func _on_close_requested() -> void:
	_save_and_close()


func _save_and_close() -> void:
	bot.code = code_edit.text
	queue_free()
