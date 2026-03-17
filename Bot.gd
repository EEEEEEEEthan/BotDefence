extends Node
class_name Bot

## 玩家可见的 Bot API，作为 BotMain 的子节点
## 子线程中通过 call_deferred 将操作交给 BotMain，完成后 callback 解除阻塞
## 返回 true=完成，false=被取消

var cardinal: Consts.Cardinal:
	get: return get_parent().cardinal

func move_forward() -> bool:
	return _deferred_call("move_forward")

func turn_left() -> bool:
	return _deferred_call("turn_left")

func turn_right() -> bool:
	return _deferred_call("turn_right")

func _deferred_call(method: StringName) -> bool:
	var semaphore := Semaphore.new()
	var result := [false]
	var on_done := func(done: bool):
		result[0] = done
		semaphore.post()
	owner.call_deferred(method, on_done)
	semaphore.wait()
	return result[0]
