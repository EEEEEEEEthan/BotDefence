extends Node
class_name BotBridge

## Bot 的固定子节点，持有 stream 并负责收协议
## 通过 attach_stream 绑定连接，通过 close() 清理资源

var python_pid: int = -1
var stream: StreamPeerTCP = null
var _stdio_pipe: FileAccess = null
var _stderr_pipe: FileAccess = null
var target_bot: Bot = null
var _receive_buffer: PackedByteArray = PackedByteArray()
var _stdout_buffer: String = ""
var _stderr_buffer: String = ""
const _LENGTH_SIZE := 4
const _PROTOCOL_HANDSHAKE := 2
const _PROTOCOL_MOVE_FORWARD := 3
const _PROTOCOL_TURN_LEFT := 5
const _PROTOCOL_TURN_RIGHT := 6

var cardinal: Consts.Cardinal:
	get: return target_bot.cardinal if target_bot else Consts.Cardinal.NORTH

var is_running: bool:
	get: return python_pid >= 0 and OS.is_process_running(python_pid)

func _ready() -> void:
	target_bot = owner as Bot

func attach_stream(peer: StreamPeerTCP) -> void:
	disconnect_stream()
	stream = peer

func disconnect_stream() -> void:
	if stream:
		stream.disconnect_from_host()
		stream = null
	_receive_buffer.clear()

## 清理所有资源：终结进程、断开连接、关闭管道、重置状态
func close() -> void:
	if python_pid >= 0 and OS.is_process_running(python_pid):
		OS.kill(python_pid)
	disconnect_stream()
	if _stdio_pipe:
		_stdio_pipe.close()
		_stdio_pipe = null
	if _stderr_pipe:
		_stderr_pipe.close()
		_stderr_pipe = null
	_stdout_buffer = ""
	_stderr_buffer = ""
	python_pid = -1

## 启动 Python 进程，需 target_bot 已就绪。使用 execute_with_pipe 捕获 stdout/stderr 写入 Bot 日志
func start_process(bot_server_port: int) -> bool:
	if not target_bot:
		return false
	var project_root: String = ProjectSettings.globalize_path("res://").trim_suffix("/")
	var script_path: String = project_root + "/.bot/runner.py"
	var result: Dictionary = OS.execute_with_pipe("python", PackedStringArray([script_path, str(bot_server_port), str(target_bot.bot_id)]), false)
	if result.is_empty():
		return false
	python_pid = result.get("pid", -1)
	_stdio_pipe = result.get("stdio", null)
	_stderr_pipe = result.get("stderr", null)
	return python_pid >= 0

func poll() -> void:
	_receive_protocol()
	_poll_stdio()

func _receive_protocol() -> void:
	if not stream:
		return
	if stream.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		close()
		return
	var available: int = stream.get_available_bytes()
	if available <= 0:
		return
	var result: Array = stream.get_partial_data(available)
	if result[0] != OK:
		return
	var chunk: PackedByteArray = result[1] as PackedByteArray
	_receive_buffer.append_array(chunk)
	_parse_buffer()

func _parse_buffer() -> void:
	while _receive_buffer.size() >= _LENGTH_SIZE:
		var payload_length: int = _receive_buffer.decode_u32(0)
		if _receive_buffer.size() < _LENGTH_SIZE + payload_length:
			return
		var payload: PackedByteArray = _receive_buffer.slice(_LENGTH_SIZE, _LENGTH_SIZE + payload_length)
		_receive_buffer = _receive_buffer.slice(_LENGTH_SIZE + payload_length)
		_handle_protocol_message(payload)

func _poll_stdio() -> void:
	if not target_bot:
		return
	_poll_pipe(_stdio_pipe, _stdout_buffer, func(msg: String) -> void: target_bot.log_stdout(msg))
	_stdout_buffer = _last_buffer
	_poll_pipe(_stderr_pipe, _stderr_buffer, func(msg: String) -> void: target_bot.log_stderr(msg))
	_stderr_buffer = _last_buffer

var _last_buffer: String = ""

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

func _handle_move_forward(_reader: PacketReader) -> void:
	var on_done := func(arrived: bool) -> void:
		_send_bool_response(arrived)
	target_bot.move_forward(on_done)

func _handle_turn_left(_reader: PacketReader) -> void:
	var on_done := func(done: bool) -> void:
		_send_bool_response(done)
	target_bot.turn_left(on_done)

func _handle_turn_right(_reader: PacketReader) -> void:
	var on_done := func(done: bool) -> void:
		_send_bool_response(done)
	target_bot.turn_right(on_done)

func _send_bool_response(value: bool) -> void:
	if stream and stream.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		var writer := PacketWriter.new()
		writer.write_bool(value)
		writer.send(stream)

func _handle_protocol_message(payload: PackedByteArray) -> void:
	if payload.size() < 1:
		return
	var reader := PacketReader.new(payload)
	var header: int = reader.read_byte()
	if header == _PROTOCOL_HANDSHAKE:
		pass  ## 握手由 PendingConnection 处理
	elif header == _PROTOCOL_MOVE_FORWARD:
		_handle_move_forward(reader)
	elif header == _PROTOCOL_TURN_LEFT:
		_handle_turn_left(reader)
	elif header == _PROTOCOL_TURN_RIGHT:
		_handle_turn_right(reader)
