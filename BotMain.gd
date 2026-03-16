extends Node2D

## 主线程移动逻辑，无 Mutex
## 通过 call_deferred 接收 Bot 的 move 请求，抵达或取消时调用 callback

const BotScript := preload("res://Bot.gd")

const MOVE_SPEED := 200.0
const ARRIVAL_THRESHOLD := 5.0

var _current_target: Vector2
var _current_callback: Callable  # 抵达或取消时调用，null 表示无当前移动任务
var _cancelled := false


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	_process_movement(delta)


func get_bot_api() -> RefCounted:
	return BotScript.new(self)


func is_cancelled() -> bool:
	return _cancelled


## 由 Bot 通过 call_deferred 调用，抵达或取消时调用 callback
func move(target: Vector2, callback: Callable) -> void:
	_current_target = target
	_current_callback = callback


## 退出时调用，通知当前移动任务结束
func cancel() -> void:
	_cancelled = true
	if _current_callback.is_valid():
		_current_callback.call()
		_current_callback = Callable()


func _process_movement(delta: float) -> void:
	if not _current_callback.is_valid():
		return

	var direction := (_current_target - position).normalized()
	position += direction * MOVE_SPEED * delta
	if position.distance_to(_current_target) < ARRIVAL_THRESHOLD:
		position = _current_target
		_current_callback.call()
		_current_callback = Callable()
