extends Node

## 玩家脚本在子线程运行，传入 bot 供其调用 move_to
## 点 Play 后统一启动所有脚本

const BotScript := preload("res://Bot.gd")

@onready var bot: Node2D = $Bot
@onready var play_button: Button = $Play

var _player_thread: Thread
var _game_started := false


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)


func _on_play_pressed() -> void:
	if _game_started:
		return
	_game_started = true
	for child in get_children():
		if child.get_script() == preload("res://BotInternal.gd"):
			child.set_process(true)
	_player_thread = Thread.new()
	_player_thread.start(_run_player_script)


func _run_player_script() -> void:
	var player_script: GDScript = load("res://player_code.gd") as GDScript
	var player_instance: Object = player_script.new()
	var bot_api: RefCounted = BotScript.new(bot)
	player_instance.run(bot_api)


func _exit_tree() -> void:
	for child in get_children():
		if child.get_script() == preload("res://BotInternal.gd"):
			child.cancel()
	if _player_thread != null and _player_thread.is_started():
		_player_thread.wait_to_finish()
