extends RefCounted
class_name PacketWriter
## 协议包发送封装，提供 write_byte/write_int/write_string，send 时发送 4 字节长度 + payload

var _buffer: PackedByteArray = PackedByteArray()

const _LENGTH_SIZE := 4

func write_byte(value: int) -> void:
	## 写入 1 字节，value 范围 0-255
	_buffer.append(value & 0xFF)

func write_int(value: int) -> void:
	## 写入 4 字节 int32 小端
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(4)
	bytes.encode_s32(0, value)
	_buffer.append_array(bytes)

func write_string(value: String) -> void:
	## 写入 4 字节长度 + UTF-8 字节
	var utf8_bytes: PackedByteArray = value.to_utf8_buffer()
	var length_bytes: PackedByteArray = PackedByteArray()
	length_bytes.resize(4)
	length_bytes.encode_u32(0, utf8_bytes.size())
	_buffer.append_array(length_bytes)
	_buffer.append_array(utf8_bytes)

func send(stream: StreamPeer) -> void:
	## 发送 4 字节长度 + payload，发送后清空 buffer
	var length_bytes: PackedByteArray = PackedByteArray()
	length_bytes.resize(4)
	length_bytes.encode_u32(0, _buffer.size())
	stream.put_data(length_bytes)
	stream.put_data(_buffer)
	_buffer.clear()
