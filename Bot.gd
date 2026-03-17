extends Node
class_name Bot

## 玩家可见的 Bot API，暴露 move，作为 BotMain 的子节点
## 子线程中通过 call_deferred 将移动交给 BotMain，抵达后 callback 解除阻塞
## 返回 true=抵达目标，false=被取消

func move(direction: int) -> bool:
	var semaphore := Semaphore.new()
	var result := [false]
	var on_arrived := func(arrived: bool):
		result[0] = arrived
		semaphore.post()
	get_parent().call_deferred(&"move", direction, on_arrived)
	semaphore.wait()
	return result[0]
