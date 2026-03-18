extends RefCounted
class_name BotBridge

## 玩家可见的 Bot API，作为 Bot 的字段
## 主线程运行，持有 stream 并负责收协议
## 赋值为 null 即解引用，NOTIFICATION_PREDELETE 时自动 disconnect_stream

var python_pid: int = -1
var stream: StreamPeerTCP = null
var target_bot: Bot = null
var _receive_buffer: PackedByteArray = PackedByteArray()
const _LENGTH_SIZE := 4
const _PROTOCOL_HANDSHAKE := 2
const _PROTOCOL_PRINT := 1
const _PROTOCOL_MOVE_FORWARD := 3
const _PROTOCOL_PRINT_ERROR := 4

var cardinal: Consts.Cardinal:
	get: return target_bot.cardinal

var _game: Game = null

func _init(peer: StreamPeerTCP = null, game: Game = null) -> void:
	if peer:
		stream = peer
	_game = game

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if stream:
			stream.disconnect_from_host()
			stream = null
		_receive_buffer.clear()

func attach_stream(peer: StreamPeerTCP) -> void:
	disconnect_stream()
	stream = peer

func disconnect_stream() -> void:
	if stream:
		stream.disconnect_from_host()
		stream = null
	_receive_buffer.clear()

func poll() -> void:
	_receive_protocol()

func _receive_protocol() -> void:
	if not stream:
		return
	if stream.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		if target_bot == null and _game:
			_game.pending_bridges.erase(self)
		elif target_bot:
			target_bot.python_pid = -1
			target_bot.bridge = null  ## 解引用，NOTIFICATION_PREDELETE 时 disconnect_stream
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

func _handle_handshake(reader: PacketReader) -> void:
	var bot_id: int = reader.read_int()
	if not _game:
		return
	_game.pending_bridges.erase(self)
	if not stream or stream.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return
	var bot: Bot = _game.get_bot(bot_id)
	var writer := PacketWriter.new()
	if bot:
		target_bot = bot
		python_pid = bot.python_pid
		print("Bot %d 已连接" % bot_id)
		bot.bridge = self
		writer.write_string(bot.code)
	else:
		push_error("未找到 bot_id=%d 的 Bot" % bot_id)
		writer.write_string("")
	writer.send(stream)

func _handle_print(reader: PacketReader) -> void:
	var message: String = reader.read_string()
	await target_bot.print_with_delay(message)
	if stream and stream.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		var writer := PacketWriter.new()
		writer.send(stream)

func _handle_print_error(reader: PacketReader) -> void:
	var message: String = reader.read_string()
	await target_bot.print_error_with_delay(message)
	if stream and stream.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		var writer := PacketWriter.new()
		writer.send(stream)

func _handle_move_forward(_reader: PacketReader) -> void:
	var on_done := func(arrived: bool) -> void:
		_send_bool_response(arrived)
	target_bot.move_forward(on_done)

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
		_handle_handshake(reader)
	elif header == _PROTOCOL_PRINT:
		_handle_print(reader)
	elif header == _PROTOCOL_PRINT_ERROR:
		_handle_print_error(reader)
	elif header == _PROTOCOL_MOVE_FORWARD:
		_handle_move_forward(reader)

func _deferred_call(method: StringName) -> bool:
	var semaphore := Semaphore.new()
	var result := [false]
	var on_done := func(done: bool):
		result[0] = done
		semaphore.post()
	target_bot.get_parent().call_deferred(method, on_done)
	semaphore.wait()
	return result[0]
