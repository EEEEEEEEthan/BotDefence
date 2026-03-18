extends Window

## 点击 Bot 时弹出，用于编辑该 Bot 的代码
## CodeEdit 启用 GDScript 语法高亮和断点槽
## 实时校验 Python 语法并在 ErrorLabel 显示错误

const HIGHLIGHTER := preload("res://GDScriptHighlighter.tres")
const VALIDATE_DEBOUNCE_SEC := 0.5

@onready var code_edit: CodeEdit = $%CodeEdit
@onready var error_label: Label = $%ErrorLabel
@onready var console: RichTextLabel = $%Console

var bot: Node2D
var _validate_timer: Timer
var _poll_timer: Timer
var _closing: bool = false
var _validate_version: int = 0

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
	_update_switch_text()

func _on_text_changed() -> void:
	_validate_timer.start(VALIDATE_DEBOUNCE_SEC)

func _validate_syntax() -> void:
	bot.code = code_edit.text
	if not (bot is Bot) or (bot as Bot).code_language != "python":
		_apply_syntax_result({"message": "", "lines": []})
		return
	_validate_version += 1
	var version: int = _validate_version
	var thread := Thread.new()
	thread.start(_thread_check_syntax.bind(code_edit.text, version))

func _thread_check_syntax(source: String, version: int) -> void:
	var result: Dictionary = _check_python_syntax_impl(source)
	call_deferred("_on_check_done", result, version)

func _on_check_done(result: Dictionary, version: int) -> void:
	if _closing or version != _validate_version:
		return
	_apply_syntax_result(result)

func _apply_syntax_result(result: Dictionary) -> void:
	var text: String = result.message
	if not text:
		error_label.visible = false
	else:
		error_label.visible = true
		error_label.text = result.message
	code_edit.clear_bookmarked_lines()
	var lines: Array[int] = []
	for item in result.get("lines", []):
		lines.append(int(item))
	if lines.is_empty() and result.message:
		var parsed_line: int = _parse_error_line(result.message)
		if parsed_line >= 0:
			lines.append(parsed_line + 1)  ## 0-based → 1-based 用于 bookmark
	for line_one_based in lines:
		var line_index: int = line_one_based - 1
		if line_index >= 0 and line_index < code_edit.get_line_count():
			code_edit.set_line_as_bookmarked(line_index, true)

func _check_python_syntax_impl(source: String) -> Dictionary:
	var empty_lines: Array[int] = []
	var empty: Dictionary = {"message": "", "lines": empty_lines}
	if source.is_empty():
		return empty
	var temp_path: String = OS.get_cache_dir().path_join("bot_inspector_check.py")
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if not file:
		return {"message": "无法创建临时文件", "lines": empty_lines}
	file.store_string(source)
	file.close()
	var output: Array = []
	var exit_code: int = OS.execute("python", PackedStringArray(["-m", "py_compile", temp_path]), output, true, true)
	if exit_code == 0:
		return empty
	var parts: PackedStringArray = PackedStringArray()
	for item in output:
		parts.append(str(item))
	var err_text: String = "\n".join(parts) if parts.size() > 0 else ""
	if err_text.is_empty():
		err_text = "编译失败"
	err_text = err_text.strip_edges()
	var parsed_line: int = _parse_error_line(err_text)
	if parsed_line >= 0:
		return {"message": err_text, "lines": [parsed_line + 1]}
	return {"message": err_text, "lines": empty_lines}

func _parse_error_line(msg: String) -> int:
	var regex := RegEx.new()
	regex.compile("(?:at |行 ?|line )?(\\d+)")
	var result := regex.search(msg)
	return int(result.get_string(1)) - 1 if result else -1


func _on_switch_pressed() -> void:
	if not (bot is Bot):
		return
	var bridge: BotBridge = (bot as Bot).bridge
	if bridge.is_running:
		bridge.close()
		_poll_timer.stop()
		_update_switch_text()
		return
	var game: Game = bot.get_parent() as Game
	if not game or game.bot_server_port < 0:
		push_error("Bot 服务器未就绪")
		return
	if bot.bot_id < 0:
		push_error("Bot 的 bot_id 未设置")
		return
	(bot as Bot).logs.clear()
	console.text = ""
	if bridge.start_process(game.bot_server_port):
		_poll_timer.start()
	_update_switch_text()


func _on_close_requested() -> void:
	_save_and_close()


func _save_and_close() -> void:
	_closing = true
	bot.code = code_edit.text
	queue_free()
