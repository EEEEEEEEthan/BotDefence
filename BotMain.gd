extends Node2D

## 主线程 Bot 逻辑，通过 call_deferred 接收 Bot 的 move 请求
## 移动功能由 BotTaskMove 组件封装

var _move_task: BotTaskMove


func _ready() -> void:
	_move_task = BotTaskMove.new(self)
	set_process(false)


func _process(delta: float) -> void:
	_move_task.process(delta)


func get_bot_api() -> RefCounted:
	return Bot.new(self)


func is_cancelled() -> bool:
	return _move_task.is_aborted()


## 由 Bot 通过 call_deferred 调用，抵达或取消时调用 callback
func move(target: Vector2, callback: Callable) -> void:
	_move_task.start(target, callback)


## 退出时调用，通知当前移动任务结束
func cancel() -> void:
	_move_task.abort()
