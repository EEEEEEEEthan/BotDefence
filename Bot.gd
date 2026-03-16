extends RefCounted
class_name Bot

## 玩家可见的 Bot API，仅暴露 move_to
## 避免玩家通过 get_method_list 等窥探内部实现

var _bot_internal: Node2D


func _init(bot_internal: Node2D) -> void:
	_bot_internal = bot_internal


func move_to(target_x: float, target_y: float) -> void:
	_bot_internal.move_to(target_x, target_y)
