extends Node
class_name Game

## 每个 Bot 用各自保存的代码在子线程运行
## 每个 Bot 通过自己的检视器 Play 按钮独立启动脚本
## 游戏启动时在可用端口启动 TCP 服务器，供 bot 连接

var bot_server_port: int = -1

var _tcp_server: TCPServer

@onready var tilemap: TileMapLayer = $%TileMapLayer

## 根据 target_bot 查找对应的 BotBridge
func get_bridge_for_bot(bot_node: Bot) -> BotBridge:
	for child in get_children():
		if child is BotBridge and child.target_bot == bot_node:
			return child as BotBridge
	return null

## BotBridge 收到握手后调用，绑定 bridge 到对应 bot_id 的 Bot
func assign_bridge_to_bot(bridge: BotBridge, bot_id: int) -> void:
	for child in get_children():
		if child is Bot and child.bot_id == bot_id:
			bridge.target_bot = child
			bridge.python_pid = child.python_pid
			print("Bot %d 已连接" % bot_id)
			return
	push_error("未找到 bot_id=%d 的 Bot" % bot_id)
	bridge.queue_free()

func _ready() -> void:
	_start_bot_server()

func _process(_delta: float) -> void:
	_accept_bot_connections()

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
	var bridge: BotBridge = BotBridge.new()
	bridge.name = "BotBridge"
	add_child(bridge)
	bridge.attach_stream(peer)
