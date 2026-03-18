extends Node
class_name BotBridge

## 玩家可见的 Bot API，作为 BotMain 的子节点
## 子线程中通过 call_deferred 将操作交给 BotMain，完成后 callback 解除阻塞
## 返回 true=完成，false=被取消
## 持有 stream 并负责收协议

var python_pid: int = -1
var stream: StreamPeerTCP = null
var _receive_buffer: PackedByteArray = PackedByteArray()
const _LENGTH_SIZE := 4
## 协议头：1=打印字符串，其余待定
const _PROTOCOL_PRINT := 1

var cardinal: Consts.Cardinal:
	get: return get_parent().cardinal

func move_forward() -> bool:
	return _deferred_call("move_forward")

func turn_left() -> bool:
	return _deferred_call("turn_left")

func turn_right() -> bool:
	return _deferred_call("turn_right")

func print_error(_what: Variant) -> void:
	pass

func attach_stream(peer: StreamPeerTCP) -> void:
	disconnect_stream()
	stream = peer

func disconnect_stream() -> void:
	if stream:
		stream.disconnect_from_host()
		stream = null
	_receive_buffer.clear()

func _process(_delta: float) -> void:
	_receive_protocol()

func _receive_protocol() -> void:
	if not stream or stream.get_status() != StreamPeerTCP.STATUS_CONNECTED:
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

func _handle_protocol_message(payload: PackedByteArray) -> void:
	if payload.size() < 1:
		return
	var reader := PacketReader.new(payload)
	var header: int = reader.read_byte()
	if header == _PROTOCOL_PRINT:
		var on_done := func() -> void:
			if stream and stream.get_status() == StreamPeerTCP.STATUS_CONNECTED:
				var writer := PacketWriter.new()
				writer.send(stream)
		owner.call_deferred("print_with_delay", reader.read_string(), on_done)

func _exit_tree() -> void:
	disconnect_stream()

func _deferred_call(method: StringName) -> bool:
	var semaphore := Semaphore.new()
	var result := [false]
	var on_done := func(done: bool):
		result[0] = done
		semaphore.post()
	owner.call_deferred(method, on_done)
	semaphore.wait()
	return result[0]
