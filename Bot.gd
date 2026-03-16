extends RefCounted
class_name Bot

## 玩家可见的 Bot API，仅暴露 move_to
## 避免玩家通过 get_method_list 等窥探内部实现

var _raw_bot

func _init(raw_bot) -> void:
	_raw_bot = raw_bot

func move_to(target_x: float, target_y: float) -> void:
	_raw_bot.move_to(target_x, target_y)
