extends RefCounted
class_name PendingConnection

## 握手前持有 peer，解析到 handshake 后分发给对应 Bot 的 BotBridge

var stream: StreamPeerTCP
var _game: Game
var _receive_buffer: PackedByteArray = PackedByteArray()
const _LENGTH_SIZE := 4
const _PROTOCOL_HANDSHAKE := 2

func _init(peer: StreamPeerTCP, game: Game) -> void:
	stream = peer
	_game = game

func poll() -> bool:
	if not stream or stream.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return false
	var available: int = stream.get_available_bytes()
	if available <= 0:
		return true
	var result: Array = stream.get_partial_data(available)
	if result[0] != OK:
		return false
	_receive_buffer.append_array(result[1] as PackedByteArray)
	if _receive_buffer.size() < _LENGTH_SIZE:
		return true
	var payload_length: int = _receive_buffer.decode_u32(0)
	if _receive_buffer.size() < _LENGTH_SIZE + payload_length:
		return true
	var payload: PackedByteArray = _receive_buffer.slice(_LENGTH_SIZE, _LENGTH_SIZE + payload_length)
	var reader := PacketReader.new(payload)
	var header: int = reader.read_byte()
	if header != _PROTOCOL_HANDSHAKE:
		return false
	var bot_id: int = reader.read_int()
	var bot: Bot = _game.get_bot(bot_id)
	var writer := PacketWriter.new()
	if bot:
		writer.write_string(bot.code)
	else:
		push_error("未找到 bot_id=%d 的 Bot" % bot_id)
		writer.write_string("")
	writer.send(stream)
	if not bot:
		stream.disconnect_from_host()
		return false
	var bridge: BotBridge = bot.get_node("BotBridge") as BotBridge
	if bridge:
		bridge.attach_stream(stream)
		print("Bot %d 已连接" % bot_id)
	return false
