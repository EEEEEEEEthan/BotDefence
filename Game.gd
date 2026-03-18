extends Node
class_name Game

## 每个 Bot 用各自保存的代码在子线程运行
## 每个 Bot 通过自己的检视器 Play 按钮独立启动脚本
## 游戏启动时在可用端口启动 TCP 服务器，供 bot 连接

var bot_server_port: int = -1

var _tcp_server: TCPServer
var _pending_bot_apis: Array[Node] = []

@onready var tilemap: TileMapLayer = $%TileMapLayer

## BotInspector 启动 runner 前调用，将下一个到达的连接分配给该 BotBridge
func request_connection_for(bot_api: Node) -> void:
	_pending_bot_apis.append(bot_api)

## BotInspector 停止 runner 时调用，取消未完成的连接请求
func cancel_connection_request(bot_api: Node) -> void:
	_pending_bot_apis.erase(bot_api)

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
	if _pending_bot_apis.is_empty():
		peer.disconnect_from_host()
		return
	var bot_api: Node = _pending_bot_apis.pop_front()
	bot_api.attach_stream(peer)
	print("Bot 已连接")
