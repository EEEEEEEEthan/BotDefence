extends Node2D

## 主线程移动逻辑，无 Mutex
## 通过 call_deferred 接收 Bot 的 move 请求，抵达后 post semaphore 回调

const BotScript := preload("res://Bot.gd")

const MOVE_SPEED := 200.0
const ARRIVAL_THRESHOLD := 5.0

var _current_target: Vector2
var _current_semaphore: Semaphore  # null 表示无当前移动任务
var _cancelled := false


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	_process_movement(delta)


func get_bot_api() -> RefCounted:
	return BotScript.new(self)


func is_cancelled() -> bool:
	return _cancelled


## 由 Bot 通过 call_deferred 调用，调用方同步等待，故无需队列
func move(target: Vector2, semaphore: Semaphore) -> void:
	_current_target = target
	_current_semaphore = semaphore


## 退出时调用，解除玩家线程的 semaphore 等待
func cancel() -> void:
	_cancelled = true
	if _current_semaphore != null:
		_current_semaphore.post()
		_current_semaphore = null


func _process_movement(delta: float) -> void:
	if _current_semaphore == null:
		return

	var direction := (_current_target - position).normalized()
	position += direction * MOVE_SPEED * delta
	if position.distance_to(_current_target) < ARRIVAL_THRESHOLD:
		position = _current_target
		_current_semaphore.post()
		_current_semaphore = null
