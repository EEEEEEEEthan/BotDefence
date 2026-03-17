extends Node
class_name MoveState

## 移动状态，BotMain 的子节点，封装主线程移动逻辑
## 抵达或 abort 时调用 callback(success: bool)，success=true 表示抵达，false 表示 abort

const MOVE_SPEED := 200.0
const ARRIVAL_THRESHOLD := 5.0

var _target: Vector2
var _callback: Callable
var _running := false

var running: bool:
	get:
		return _running

func _ready() -> void:
	set_process(false)

func start(target: Vector2, callback: Callable) -> void:
	_target = target
	_callback = callback
	_running = true
	set_process(true)

func abort() -> void:
	_running = false
	_finish()

func _process(delta: float) -> void:
	if not _running:
		return
	var host: Node2D = get_parent()
	var direction := (_target - host.position).normalized()
	host.position += direction * MOVE_SPEED * delta
	if host.position.distance_to(_target) < ARRIVAL_THRESHOLD:
		host.position = _target
		_finish()

func _finish() -> void:
	set_process(false)
	if _callback.is_valid():
		_callback.call(not _aborted)
		_callback = Callable()
