extends Node
class_name Game

## 每个 Bot 用各自保存的代码在子线程运行
## 每个 Bot 通过自己的检视器 Play 按钮独立启动脚本
## 游戏启动时在可用端口启动 TCP 服务器，供 bot 连接

var bot_server_port: int = -1

var _tcp_server: TCPServer

@onready var tilemap: TileMapLayer = $%TileMapLayer

var pending_bridges: Array[BotBridge] = []

## 根据 bot_id 查找 Bot，供 BotBridge 握手后绑定
func get_bot(bot_id: int) -> Bot:
	for child in get_children():
		if child is Bot and child.bot_id == bot_id:
			return child as Bot
	return null

func _ready() -> void:
	_start_bot_server()

func _process(_delta: float) -> void:
	_accept_bot_connections()
	for bridge in pending_bridges.duplicate():
		bridge.poll()

func _start_bot_server() -> void:
	_tcp_server = TCPServer.new()
	var err := _tcp_server.listen(0)
	if err != OK:
		push_error("Bot 服务器启动失败: %d" % err)
		return
	bot_server_port = _tcp_server.get_local_port()
	print("Bot 服务器已启动，端口: ", bot_server_port)

func _accept_bot_connections() -> void:
	if not _tcp_server:
		return
	var peer: StreamPeerTCP = _tcp_server.take_connection()
	if not peer:
		return
	var bridge: BotBridge = BotBridge.new(peer, self)
	pending_bridges.append(bridge)
