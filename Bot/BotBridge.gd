extends Node
class_name BotBridge

## Bot 的固定子节点，通过 stdio 行协议与 Python 子进程交互
## 代码通过临时文件传递，命令/响应通过 BOT: 前缀行

var python_pid: int = -1
var _stdio_pipe: FileAccess = null
var _stderr_pipe: FileAccess = null
var target_bot: Bot = null
var _stdout_buffer: String = ""
var _stderr_buffer: String = ""
const _CMD_PREFIX := "BOT:"

var cardinal: Consts.Cardinal:
	get: return target_bot.cardinal if target_bot else Consts.Cardinal.NORTH

var is_running: bool:
	get: return python_pid >= 0 and OS.is_process_running(python_pid)

func _ready() -> void:
	target_bot = owner as Bot

## 清理所有资源：终结进程、关闭管道、重置状态
func close() -> void:
	if python_pid >= 0 and OS.is_process_running(python_pid):
		OS.kill(python_pid)
	if _stdio_pipe:
		_stdio_pipe.close()
		_stdio_pipe = null
	if _stderr_pipe:
		_stderr_pipe.close()
		_stderr_pipe = null
	_stdout_buffer = ""
	_stderr_buffer = ""
	python_pid = -1

## 启动 Python 进程，需 target_bot 已就绪。直接运行存档目录下的 py 文件
func start_process(_bot_server_port: int = -1) -> bool:
	if not target_bot:
		return false
	if not target_bot.ensure_py_file_exists():
		return false
	var project_root: String = ProjectSettings.globalize_path("res://").trim_suffix("/")
	var runner_path: String = project_root + "/.bot/runner.py"
	var py_path: String = target_bot.py_path.resolved_py_path
	var result: Dictionary = OS.execute_with_pipe("python", PackedStringArray([runner_path, py_path, str(target_bot.bot_id)]), false)
	if result.is_empty():
		return false
	python_pid = result.get("pid", -1)
	_stdio_pipe = result.get("stdio", null)
	_stderr_pipe = result.get("stderr", null)
	return python_pid >= 0

func poll() -> void:
	_poll_stdio()

var _last_buffer: String = ""

func _poll_stdio() -> void:
	if not target_bot:
		return
	_poll_pipe(_stdio_pipe, _stdout_buffer, _on_stdout_line)
	_stdout_buffer = _last_buffer
	_poll_pipe(_stderr_pipe, _stderr_buffer, func(msg: String) -> void: target_bot.log_stderr(msg))
	_stderr_buffer = _last_buffer

func _on_stdout_line(line: String) -> void:
	if line.begins_with(_CMD_PREFIX):
		var cmd: String = line.substr(_CMD_PREFIX.length())
		_handle_command(cmd)
	else:
		target_bot.log_stdout(line)

func _poll_pipe(pipe: FileAccess, buffer: String, on_line: Callable) -> void:
	_last_buffer = buffer
	if not pipe or not pipe.is_open():
		return
	var chunk: PackedByteArray = pipe.get_buffer(4096)
	if chunk.size() == 0:
		return
	_last_buffer += chunk.get_string_from_utf8()
	var lines: PackedStringArray = _last_buffer.split("\n")
	if lines.size() > 0:
		_last_buffer = lines[lines.size() - 1]
		lines.resize(lines.size() - 1)
	for line in lines:
		var trimmed: String = line.strip_edges()
		if not trimmed.is_empty():
			on_line.call(trimmed)

func _handle_command(cmd: String) -> void:
	if cmd.begins_with("line:"):
		var line_str: String = cmd.substr(5)
		var line_one_based: int = line_str.to_int()
		if line_one_based > 0 and target_bot:
			target_bot.notify_current_line(line_one_based)
		return
	match cmd:
		"move_forward":
			_handle_move_forward()
		"turn_left":
			_handle_turn_left()
		"turn_right":
			_handle_turn_right()
		_:
			_send_bool_response(false)

func _handle_move_forward() -> void:
	var on_done := func(arrived: bool) -> void:
		_send_bool_response(arrived)
	target_bot.move_forward(on_done)

func _handle_turn_left() -> void:
	var on_done := func(done: bool) -> void:
		_send_bool_response(done)
	target_bot.turn_left(on_done)

func _handle_turn_right() -> void:
	var on_done := func(done: bool) -> void:
		_send_bool_response(done)
	target_bot.turn_right(on_done)

func _send_bool_response(value: bool) -> void:
	if _stdio_pipe and _stdio_pipe.is_open():
		_stdio_pipe.store_line("true" if value else "false")
