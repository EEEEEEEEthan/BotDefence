extends Window

## 点击 Bot 时弹出，用于编辑该 Bot 的代码
## CodeEdit 启用 GDScript 语法高亮和断点槽
## 实时校验 Python 语法并在 ErrorLabel 显示错误

@onready var code_edit: CodeEdit = $%CodeEdit
@onready var error_label: RichTextLabel = $%ErrorLabel
@onready var console: RichTextLabel = $%Console
@onready var syntax_checker = $%PythonSyntaxChecker

var bot: Node2D
var _poll_timer: Timer
var _closing: bool = false

func _ready() -> void:
	code_edit.text = bot.code
	_update_switch_text()
	$%Switch.pressed.connect(_on_switch_pressed)
	close_requested.connect(_on_close_requested)
	_poll_timer = Timer.new()
	_poll_timer.wait_time = 0.3
	_poll_timer.timeout.connect(_poll_python_process)
	add_child(_poll_timer)
	code_edit.text_changed.connect(_on_text_changed)
	if not (bot as Bot).bridge.is_running:
		_apply_check_result()
	bot.log_added.connect(_on_log_added)
	(bot as Bot).current_line_changed.connect(_on_current_line_changed)
	_display_all_logs()

func _display_all_logs() -> void:
	var bot_logs: Array = (bot as Bot).logs
	var lines: PackedStringArray = []
	for entry in bot_logs:
		lines.append((entry as ConsoleLogEntry).to_bbcode_line())
	console.text = "\n".join(lines) + "\n"

func _on_log_added(entry: ConsoleLogEntry) -> void:
	console.append_text(entry.to_bbcode_line() + "\n")

func _on_current_line_changed(line_one_based: int) -> void:
	code_edit.clear_executing_lines()
	var line_index: int = line_one_based - 1
	if line_index >= 0 and line_index < code_edit.get_line_count():
		code_edit.set_line_as_executing(line_index, true)
		code_edit.set_caret_line(line_index)

func _update_switch_text() -> void:
	var bridge: BotBridge = (bot as Bot).bridge if bot is Bot else null
	var running: bool = bridge and bridge.is_running
	$%Switch.text = "🛑" if running else "▶"

func _poll_python_process() -> void:
	if not (bot is Bot):
		return
	var bridge: BotBridge = (bot as Bot).bridge
	if not bridge.is_running and bridge.python_pid >= 0:
		bridge.close()
		_poll_timer.stop()
		code_edit.clear_executing_lines()
	_update_switch_text()

func _on_text_changed() -> void:
	bot.code = code_edit.text
	if not (bot as Bot).bridge.is_running:
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

func _parse_error_line(msg: String) -> int:
	var regex := RegEx.new()
	regex.compile("(?:line|行)\\s*(\\d+)")
	var search_result := regex.search(msg)
	return int(search_result.get_string(1)) - 1 if search_result else -1

func _on_switch_pressed() -> void:
	if not (bot is Bot):
		return
	var bridge: BotBridge = (bot as Bot).bridge
	if bridge.is_running:
		bridge.close()
		_poll_timer.stop()
		code_edit.clear_executing_lines()
		_update_switch_text()
		return
	if bot.bot_id < 0:
		push_error("Bot 的 bot_id 未设置")
		return
	(bot as Bot).logs.clear()
	console.text = ""
	if bridge.start_process():
		_poll_timer.start()
	_update_switch_text()


func _on_close_requested() -> void:
	_save_and_close()


func _save_and_close() -> void:
	_closing = true
	syntax_checker.set_closing(true)
	bot.code = code_edit.text
	queue_free()
