extends Node

## 每个 Bot 用各自保存的代码在子线程运行
## 点 Play 后统一启动所有 Bot 的脚本

@onready var play_button: Button = $Play

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
			var thread := Thread.new()
			thread.start(_run_bot_script.bind(child))
			_player_threads.append(thread)


func _run_bot_script(bot_main: Node2D) -> void:
	var gdscript := GDScript.new()
	gdscript.source_code = bot_main.get_code()
	gdscript.reload()
	var instance: Object = gdscript.new()
	instance.run(bot_main.get_bot_api())


func _exit_tree() -> void:
	for child in get_children():
		if child.get_script() == preload("res://BotMain.gd"):
			child.cancel()
	for thread in _player_threads:
		if thread.is_started():
			thread.wait_to_finish()
