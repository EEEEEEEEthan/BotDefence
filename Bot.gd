extends RefCounted
class_name Bot

## 玩家可见的 Bot API，暴露 move
## 子线程中通过 call_deferred 将移动交给 BotMain，抵达后 callback 解除阻塞
## 返回 true=抵达目标，false=被取消

var _bot_main: Object
var _move_task: BotTaskMove

func _init(bot_main: Object, move_task: BotTaskMove) -> void:
	_bot_main = bot_main
	_move_task = move_task

func move(direction: int) -> bool:
	if _move_task.aborted:
		return false
	var semaphore := Semaphore.new()
	var result := [false]
	var on_arrived := func(arrived: bool):
		result[0] = arrived
		semaphore.post()
	_bot_main.call_deferred(&"move", direction, on_arrived)
	if _move_task.aborted:
		return false
	semaphore.wait()
	return result[0]
