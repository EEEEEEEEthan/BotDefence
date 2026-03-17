extends Node
class_name TurnState

## 转向状态，立即更新 cardinal，无动画
## 完成时调用 callback(success: bool)，success 恒为 true

var _callback: Callable
var _running := false

func _ready() -> void:
	pass

func start(new_cardinal: Consts.Cardinal, callback: Callable) -> void:
	_callback = callback
	_running = true
	var bot_main: Node = get_parent()
	bot_main.cardinal = new_cardinal
	_finish(true)

func abort() -> void:
	_finish(false)

func _finish(result: bool) -> void:
	_running = false
	if _callback.is_valid():
		_callback.call(result)
		_callback = Callable()
