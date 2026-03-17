extends BaseState
class_name MoveForwardState

## 瞬时设置 preferred_position，等待 MOVE_DURATION 后 callback
## 实际位置由 BotMain 每帧插值

const MOVE_DURATION := 0.3

var _callback: Callable
var _running := false
var _timer: Timer
var _previous_preferred_position: Vector2

func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(_on_timeout)

func start(target: Vector2, callback: Callable) -> void:
	_callback = callback
	_running = true
	_previous_preferred_position = bot_main.preferred_position
	bot_main.preferred_position = target
	_timer.start(MOVE_DURATION)

func abort() -> void:
	_timer.stop()
	bot_main.preferred_position = _previous_preferred_position
	_finish(false)

func _on_timeout() -> void:
	_finish(true)

func _finish(result: bool) -> void:
	_running = false
	if _callback.is_valid():
		_callback.call(result)
		_callback = Callable()
