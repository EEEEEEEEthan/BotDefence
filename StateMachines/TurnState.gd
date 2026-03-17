extends BaseState
class_name TurnState

## 瞬时设置 cardinal 与 preferred_rotation，等待 TURN_DURATION 后 callback
## 实际旋转由 BotMain 每帧插值

const TURN_DURATION := 0.2
const _CARDINAL_ANGLE := {
	Consts.Cardinal.NORTH: -TAU / 4,
	Consts.Cardinal.EAST: 0.0,
	Consts.Cardinal.SOUTH: TAU / 4,
	Consts.Cardinal.WEST: TAU / 2
}

var _callback: Callable
var _running := false
var _timer: Timer
var _previous_cardinal: Consts.Cardinal

func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(_on_timeout)

func start(new_cardinal: Consts.Cardinal, callback: Callable) -> void:
	_callback = callback
	_running = true
	_previous_cardinal = bot_main.cardinal
	bot_main.cardinal = new_cardinal
	bot_main.preferred_rotation = _CARDINAL_ANGLE[new_cardinal]
	_timer.start(TURN_DURATION)

func abort() -> void:
	_timer.stop()
	bot_main.cardinal = _previous_cardinal
	bot_main.preferred_rotation = _CARDINAL_ANGLE[_previous_cardinal]
	_finish(false)

func _on_timeout() -> void:
	_finish(true)

func _finish(result: bool) -> void:
	_running = false
	if _callback.is_valid():
		_callback.call(result)
		_callback = Callable()
