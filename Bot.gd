extends RefCounted
class_name Bot

## 玩家可见的 Bot API，仅暴露 move_to
## 子线程中通过 call_deferred 将移动交给 BotMain，抵达后 semaphore.post 解除阻塞

var _bot_main: Object


func _init(bot_main: Object) -> void:
	_bot_main = bot_main


func move_to(target_x: float, target_y: float) -> void:
	if _bot_main.is_cancelled():
		return
	var semaphore := Semaphore.new()
	_bot_main.call_deferred("move", Vector2(target_x, target_y), semaphore)
	if _bot_main.is_cancelled():
		return
	semaphore.wait()
