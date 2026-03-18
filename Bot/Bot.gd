extends Node2D
class_name Bot

## 主线程 Bot 逻辑，通过 call_deferred 接收 Bot 的 move_forward/turn 请求
## 移动与转向由 MoveForwardState、TurnState 子节点封装
## 移动/转向瞬时修改 preferred_position/preferred_rotation，等待后 callback，BotMain 每帧插值

const DEFAULT_CODE_PATH := "res://player_code.gd"

@export var bot_id: int = -1

@onready var _bot_api: Node = $%BotApi
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

@export_multiline
var code: String

func _ready() -> void:
	_preferred_position = position
	_preferred_rotation = _CARDINAL_ANGLE[cardinal]
	rotation = _preferred_rotation

func _process(delta: float) -> void:
	position = position.lerp(_preferred_position, 1.0 - exp(-_POSITION_LERP_SPEED * delta))
	rotation = lerp_angle(rotation, _preferred_rotation, 1.0 - exp(-_ROTATION_LERP_SPEED * delta))

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

## 由 BotBridge 通过协议 1 触发，输出到 Godot 控制台，延迟后回调
func print_with_delay(what: Variant, on_done: Callable) -> void:
	print_rich(str(what))
	var timer := get_tree().create_timer(1.0)
	timer.timeout.connect(on_done)

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
	var sprite: Sprite2D = $Sprite2D
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
