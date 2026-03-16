extends Node2D

## 暴露 move_to API，供玩家脚本在子线程中同步调用
## 初始不运行，点 Play 后由 Game 统一启动

const MOVE_SPEED := 200.0
const ARRIVAL_THRESHOLD := 5.0

var _move_queue: Array[Dictionary] = []
var _move_mutex := Mutex.new()
var _current_target: Vector2
var _current_semaphore: Semaphore  # null 表示无当前移动任务


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	_process_movement(delta)


## 供玩家脚本调用，子线程中阻塞直到抵达
func move_to(target_x: float, target_y: float) -> void:
	var semaphore := Semaphore.new()
	_move_mutex.lock()
	_move_queue.append({"target": Vector2(target_x, target_y), "semaphore": semaphore})
	_move_mutex.unlock()
	semaphore.wait()


func _process_movement(delta: float) -> void:
	if _current_semaphore == null:
		_move_mutex.lock()
		if _move_queue.size() > 0:
			var move_data: Dictionary = _move_queue.pop_front()
			_move_mutex.unlock()
			_current_target = move_data.target
			_current_semaphore = move_data.semaphore
		else:
			_move_mutex.unlock()
			return

	var direction := (_current_target - position).normalized()
	position += direction * MOVE_SPEED * delta
	if position.distance_to(_current_target) < ARRIVAL_THRESHOLD:
		position = _current_target
		_current_semaphore.post()
		_current_semaphore = null
