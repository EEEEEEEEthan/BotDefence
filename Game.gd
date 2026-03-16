extends Node2D

## 玩家脚本在子线程运行，传入 bot 供其调用 move_to

@onready var bot: Node2D = $Bot

var _player_thread: Thread


func _ready() -> void:
	_player_thread = Thread.new()
	_player_thread.start(_run_player_script)


func _run_player_script() -> void:
	var player_script: GDScript = load("res://player_code.gd") as GDScript
	var player_instance: Object = player_script.new()
	player_instance.run(bot)


func _exit_tree() -> void:
	if _player_thread.is_started():
		_player_thread.wait_to_finish()
