extends Node
class_name MoveForwardState

## 向前移动状态，沿当前 cardinal 方向移动一格
## 抵达或 abort 时调用 callback(success: bool)

const MOVE_SPEED := 200.0
const ARRIVAL_THRESHOLD := 5.0

var _target: Vector2
var _callback: Callable
var _running := false

func _ready() -> void:
	set_process(false)

func start(target: Vector2, callback: Callable) -> void:
	_target = target
	_callback = callback
	_running = true
	set_process(true)

func abort() -> void:
	_finish(false)

func _process(delta: float) -> void:
	if not _running:
		return
	var host: Node2D = get_parent()
	var direction := (_target - host.position).normalized()
	host.position += direction * MOVE_SPEED * delta
	if host.position.distance_to(_target) < ARRIVAL_THRESHOLD:
		host.position = _target
		_finish(true)

func _finish(result: bool) -> void:
	_running = false
	if _callback.is_valid():
		_callback.call(result)
		_callback = Callable()
