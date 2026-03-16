extends RefCounted

## 线程桥接，供玩家脚本在子线程中同步调用 move_to
## 通过 call_deferred 将移动交给 BotMain，抵达后 semaphore.post 回调解除阻塞

var _bot_main: Node2D


func _init(bot_main: Node2D) -> void:
	_bot_main = bot_main


## 供 Bot 封装调用，子线程中阻塞直到抵达
func move_to(target_x: float, target_y: float) -> void:
	if _bot_main.is_cancelled():
		return
	var semaphore := Semaphore.new()
	_bot_main.call_deferred("add_move", Vector2(target_x, target_y), semaphore)
	if _bot_main.is_cancelled():
		return
	semaphore.wait()
