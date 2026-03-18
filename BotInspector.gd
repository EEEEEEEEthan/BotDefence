extends Window

## 点击 Bot 时弹出，用于编辑该 Bot 的代码
## CodeEdit 启用 GDScript 语法高亮和断点槽
## 实时校验 Python 语法并在 ErrorLabel 显示错误

const HIGHLIGHTER := preload("res://GDScriptHighlighter.tres")

@onready var code_edit: CodeEdit = $%CodeEdit
@onready var error_label: Label = $%ErrorLabel
@onready var console: RichTextLabel = $%Console
@onready var syntax_checker = $%PythonSyntaxChecker

var bot: Node2D
var _poll_timer: Timer
var _closing: bool = false

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
	syntax_checker.set_targets(code_edit, error_label)
	code_edit.text_changed.connect(_on_text_changed)
	syntax_checker.check_now(code_edit.text, _is_python_bot())
	bot.log_added.connect(_on_log_added)
	_display_all_logs()

func _is_python_bot() -> bool:
	return bot is Bot and (bot as Bot).code_language == "python"

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
	bot.code = code_edit.text
	syntax_checker.request_check(code_edit.text, _is_python_bot())

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
	syntax_checker.set_closing(true)
	bot.code = code_edit.text
	queue_free()
