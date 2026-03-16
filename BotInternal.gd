extends Node2D

## 内部实现，供玩家脚本在子线程中同步调用 move_to
## 初始不运行，点 Play 后由 Game 统一启动

const MOVE_SPEED := 200.0
const ARRIVAL_THRESHOLD := 5.0

var _move_queue: Array[Dictionary] = []
var _move_mutex := Mutex.new()
var _current_target: Vector2
var _current_semaphore: Semaphore  # null 表示无当前移动任务
var _cancelled := false


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	_process_movement(delta)


## 供 Bot 封装调用，子线程中阻塞直到抵达
func move_to(target_x: float, target_y: float) -> void:
	if _cancelled:
		return
	var semaphore := Semaphore.new()
	_move_mutex.lock()
	_move_queue.append({"target": Vector2(target_x, target_y), "semaphore": semaphore})
	_move_mutex.unlock()
	if _cancelled:
		return
	semaphore.wait()


## 退出时调用，解除玩家线程的 semaphore 等待，避免关游戏死锁
func cancel() -> void:
	_move_mutex.lock()
	_cancelled = true
	var sem := _current_semaphore
	_current_semaphore = null
	var queue_copy: Array[Dictionary] = []
	queue_copy.assign(_move_queue)
	_move_queue.clear()
	_move_mutex.unlock()
	if sem != null:
		sem.post()
	for move_data in queue_copy:
		move_data.semaphore.post()


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
