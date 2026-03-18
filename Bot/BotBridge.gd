extends Node
class_name BotBridge

## Bot 的固定子节点，持有 stream 并负责收协议
## 通过 attach_stream 绑定连接，通过 close() 清理资源

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
	get: return target_bot.cardinal if target_bot else Consts.Cardinal.NORTH

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

## 清理所有资源，断开连接并重置状态
func close() -> void:
	disconnect_stream()
	python_pid = -1

func poll() -> void:
	_receive_protocol()

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
		pass  ## 握手由 PendingConnection 处理
	elif header == _PROTOCOL_PRINT:
		_handle_print(reader)
	elif header == _PROTOCOL_PRINT_ERROR:
		_handle_print_error(reader)
	elif header == _PROTOCOL_MOVE_FORWARD:
		_handle_move_forward(reader)
