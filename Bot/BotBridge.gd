extends Node
class_name BotBridge

## 玩家可见的 Bot API，作为 BotMain 的子节点
## 子线程中通过 call_deferred 将操作交给 BotMain，完成后 callback 解除阻塞
## 返回 true=完成，false=被取消

var python_pid: int = -1
var stream: StreamPeerTCP = null

var cardinal: Consts.Cardinal:
	get: return get_parent().cardinal

func move_forward() -> bool:
	return _deferred_call("move_forward")

func turn_left() -> bool:
	return _deferred_call("turn_left")

func turn_right() -> bool:
	return _deferred_call("turn_right")

func print(_what: Variant) -> void:
	pass

func print_error(_what: Variant) -> void:
	pass

func attach_stream(peer: StreamPeerTCP) -> void:
	disconnect_stream()
	stream = peer

func disconnect_stream() -> void:
	if stream:
		stream.disconnect_from_host()
		stream = null

func _exit_tree() -> void:
	disconnect_stream()

func _deferred_call(method: StringName) -> bool:
	var semaphore := Semaphore.new()
	var result := [false]
	var on_done := func(done: bool):
		result[0] = done
		semaphore.post()
	owner.call_deferred(method, on_done)
	semaphore.wait()
	return result[0]
