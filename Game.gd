extends Node
class_name Game

## 每个 Bot 用各自保存的代码在子线程运行
## 每个 Bot 通过自己的检视器 Play 按钮独立启动脚本

@onready var tilemap: TileMapLayer = $%TileMapLayer

func _exit_tree() -> void:
	for child in get_children():
		if child.get_script() == preload("res://BotMain.gd"):
			child.cancel()
