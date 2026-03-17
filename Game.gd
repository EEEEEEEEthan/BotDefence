extends Node
class_name Game

## 每个 Bot 用各自保存的代码在子线程运行
## 点 Play 后统一启动所有 Bot 的脚本

@onready var play_button: Button = $Play
@onready var tilemap: TileMapLayer = $%TileMapLayer
var _player_threads: Array[Thread] = []
var _game_started := false

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)

func _on_play_pressed() -> void:
	if _game_started:
		return
	_game_started = true
	for child in get_children():
		if child.get_script() == preload("res://BotMain.gd"):
			child.set_process(true)
			# GDScript.reload() 和实例化必须在主线程
			var gdscript := GDScript.new()
			gdscript.source_code = child.code
			gdscript.reload()
			var instance: Object = gdscript.new()
			var bot_api: RefCounted = child.get_bot_api()
			var thread := Thread.new()
			thread.start(_run_bot_script.bind(instance, bot_api))
			_player_threads.append(thread)

func _run_bot_script(instance: Object, bot_api: RefCounted) -> void:
	instance.run(bot_api)

func _exit_tree() -> void:
	for child in get_children():
		if child.get_script() == preload("res://BotMain.gd"):
			child.cancel()
	for thread in _player_threads:
		if thread.is_started():
			thread.wait_to_finish()
