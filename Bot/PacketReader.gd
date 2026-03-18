extends RefCounted
class_name PacketReader
## 协议包接收封装，从 payload 中顺序读取 read_byte/read_int/read_string

var _buffer: PackedByteArray
var _position: int = 0

func _init(payload: PackedByteArray) -> void:
	_buffer = payload

func read_byte() -> int:
	## 读取 1 字节，返回 0-255
	var value: int = _buffer[_position]
	_position += 1
	return value

func read_int() -> int:
	## 读取 4 字节 int32 小端
	var value: int = _buffer.decode_s32(_position)
	_position += 4
	return value

func read_string() -> String:
	## 读取 4 字节长度 + UTF-8 字节
	var length: int = _buffer.decode_u32(_position)
	_position += 4
	var utf8_bytes: PackedByteArray = _buffer.slice(_position, _position + length)
	_position += length
	var text: String = utf8_bytes.get_string_from_utf8()
	if text.is_empty() and length > 0:
		return "<invalid utf-8>"
	return text

func read_bool() -> bool:
	## 读取 1 字节，0=false，非 0=true
	var value: int = _buffer[_position]
	_position += 1
	return value != 0
