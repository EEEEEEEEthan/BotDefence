extends Node2D
class_name Bot

## 主线程 Bot 逻辑，通过 call_deferred 接收 Bot 的 move_forward/turn 请求
## 移动与转向由 MoveForwardState、TurnState 子节点封装
## 移动/转向瞬时修改 preferred_position/preferred_rotation，等待后 callback，BotMain 每帧插值

const _TEMPLATE_PY := """
count: int = 0
while True:
    count += 1
    bot.move_forward()
    bot.turn_right()
    print("count", count)
"""

@export var bot_id: int = -1
@export var py_path: BotScriptPath = BotScriptPath.new()
@onready var bridge: BotBridge = $%BotBridge
@onready var sprite: Sprite2D = $%Sprite

var cardinal: Consts.Cardinal = Consts.Cardinal.NORTH

var preferred_position: Vector2:
	get: return _preferred_position
	set(value): _preferred_position = value
var _preferred_position: Vector2

var preferred_rotation: float:
	get: return _preferred_rotation
	set(value): _preferred_rotation = value
var _preferred_rotation: float

const _POSITION_LERP_SPEED := 8.0
const _ROTATION_LERP_SPEED := 12.0
const _CARDINAL_ANGLE := {
	Consts.Cardinal.NORTH: 0.0,
	Consts.Cardinal.EAST: TAU / 4,
	Consts.Cardinal.SOUTH: TAU / 2,
	Consts.Cardinal.WEST: -TAU / 4
}
var _current_state: Object  ## MoveForwardState 或 TurnState，均有 abort()

## 日志列表，每项为 ConsoleLogEntry
var logs: Array[ConsoleLogEntry] = []

signal log_added(entry: ConsoleLogEntry)
signal current_line_changed(line_one_based: int)

func _ready() -> void:
	_preferred_position = position
	_preferred_rotation = _CARDINAL_ANGLE[cardinal]
	rotation = _preferred_rotation

## 若 py 文件不存在则创建模板，返回是否成功
func ensure_py_file_exists() -> bool:
	var path: String = py_path.resolved_py_path
	if FileAccess.file_exists(path):
		return true
	var dir_path: String = path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("无法创建玩家脚本: %s" % path)
		return false
	file.store_string(_TEMPLATE_PY)
	file.close()
	return true

func _process(delta: float) -> void:
	position = position.lerp(_preferred_position, 1.0 - exp(-_POSITION_LERP_SPEED * delta))
	rotation = lerp_angle(rotation, _preferred_rotation, 1.0 - exp(-_ROTATION_LERP_SPEED * delta))
	sprite.running = bridge.is_running
	bridge.poll()

## 由 Bot 通过 call_deferred 调用，仅转发给 MoveForwardState
func move_forward(callback: Callable) -> void:
	var wrapped := func(arrived: bool):
		_current_state = null
		callback.call(arrived)
	_current_state = $%MoveForwardState
	_current_state.start(cardinal, wrapped)

const _CARDINAL_ORDER := [Consts.Cardinal.NORTH, Consts.Cardinal.EAST, Consts.Cardinal.SOUTH, Consts.Cardinal.WEST]

func turn_left(callback: Callable) -> void:
	var idx: int = _CARDINAL_ORDER.find(cardinal)
	var new_cardinal: Consts.Cardinal = _CARDINAL_ORDER[(idx + 3) % 4]
	var wrapped := func(arrived: bool):
		_current_state = null
		callback.call(arrived)
	_current_state = $%TurnState
	_current_state.start(new_cardinal, wrapped)

func turn_right(callback: Callable) -> void:
	var idx: int = _CARDINAL_ORDER.find(cardinal)
	var new_cardinal: Consts.Cardinal = _CARDINAL_ORDER[(idx + 1) % 4]
	var wrapped := func(arrived: bool):
		_current_state = null
		callback.call(arrived)
	_current_state = $%TurnState
	_current_state.start(new_cardinal, wrapped)

func _add_log(log_type: String, message: String) -> void:
	var entry_type: ConsoleLogEntry.Type = ConsoleLogEntry.Type.ERROR if log_type == "error" else ConsoleLogEntry.Type.LOG
	var entry := ConsoleLogEntry.new(int(Time.get_unix_time_from_system()), entry_type, message)
	logs.append(entry)
	log_added.emit(entry)

func log_error(message: String) -> void:
	_add_log("error", message)

## 由 BotBridge 从 stdout 捕获后调用
func log_stdout(message: String) -> void:
	_add_log("log", message)

## 由 BotBridge 从 stderr 捕获后调用
func log_stderr(message: String) -> void:
	_add_log("error", message)

## 由 BotBridge 在收到 Python 行号报告时调用
func notify_current_line(line_one_based: int) -> void:
	current_line_changed.emit(line_one_based)

## 退出时调用，中止当前任务
func abort() -> void:
	if _current_state:
		_current_state.abort()
		_current_state = null

func _exit_tree() -> void:
	abort()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var rect: Rect2 = sprite.get_rect()
	var global_rect := Rect2(
		sprite.global_position + rect.position * sprite.global_scale,
		rect.size * sprite.global_scale
	)
	if global_rect.has_point(get_global_mouse_position()):
		_open_inspector()

func _open_inspector() -> void:
	var placeholder: InstancePlaceholder = $BotInspector
	var inspector: Window = load(placeholder.get_instance_path()).instantiate()
	inspector.bot = self
	get_tree().root.add_child(inspector)
	inspector.popup_centered()
