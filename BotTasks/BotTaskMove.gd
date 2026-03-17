extends BotTask
class_name BotTaskMove

## 移动任务组件，封装主线程移动逻辑
## 由 BotMain 持有并每帧 process，抵达或 abort 时调用 callback(success: bool)，success=true 表示抵达，false 表示 abort

const MOVE_SPEED := 200.0
const ARRIVAL_THRESHOLD := 5.0

var _host: Node2D
var _target: Vector2
var _callback: Callable
var _aborted := false

var aborted: bool:
	get:
		return _aborted

func _init(host: Node2D) -> void:
	_host = host

func start(target: Vector2, callback: Callable) -> void:
	_target = target
	_callback = callback
	_aborted = false

func reset_aborted() -> void:
	_aborted = false

func abort() -> void:
	_aborted = true
	_finish()

## 每帧调用，返回 true 表示任务已结束（抵达或取消）
func process(delta: float) -> bool:
	if _aborted or not _callback.is_valid():
		return true

	var direction := (_target - _host.position).normalized()
	_host.position += direction * MOVE_SPEED * delta
	if _host.position.distance_to(_target) < ARRIVAL_THRESHOLD:
		_host.position = _target
		_finish()
		return true
	return false

func _finish() -> void:
	if _callback.is_valid():
		_callback.call(not _aborted)  # true=抵达, false=abort
		_callback = Callable()
