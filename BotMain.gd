extends Node2D

## 主线程 Bot 逻辑，通过 call_deferred 接收 Bot 的 move 请求
## 移动功能由 BotTaskMove 组件封装
## 每个 Bot 在内存中保存自己的代码，默认与 player_code 相同

const DEFAULT_CODE_PATH := "res://player_code.gd"
const CancelFlagScript := preload("res://CancelFlag.gd")

var _move_task: BotTaskMove
var _cancel_flag: RefCounted

var code: String:
	get:
		if code.is_empty():
			var default_file := FileAccess.open(DEFAULT_CODE_PATH, FileAccess.READ)
			code = default_file.get_as_text()
		return code
	set(value):
		code = value
var _current_task: BotTask

var game: Game:
	get:
		if not game:
			game = get_parent()
		return game

func _ready() -> void:
	_cancel_flag = CancelFlagScript.new()
	_move_task = BotTaskMove.new(self)
	set_process(false)

func _process(delta: float) -> void:
	if _move_task.process(delta):
		_current_task = null

func get_bot_api() -> RefCounted:
	return Bot.new(self, _cancel_flag)

func is_cancelled() -> bool:
	return _move_task.aborted

## 由 Bot 通过 call_deferred 调用，direction 为 Consts.NORTH/SOUTH/EAST/WEST
func move(direction: Consts.Direction, callback: Callable) -> void:
	var offset := _direction_to_offset(direction)
	var target := position + offset * Bot.MOVE_STEP
	_current_task = _move_task
	_move_task.start(target, callback)

func _direction_to_offset(direction: Consts.Direction) -> Vector2:
	match direction:
		Consts.NORTH: return Vector2(0, -1)
		Consts.SOUTH: return Vector2(0, 1)
		Consts.EAST: return Vector2(1, 0)
		Consts.WEST: return Vector2(-1, 0)
		_: return Vector2.ZERO

## 退出时调用，中止当前任务
func cancel() -> void:
	_cancel_flag.aborted = true
	if _current_task:
		_current_task.abort()

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
	var inspector: Window = preload("res://BotInspector.tscn").instantiate()
	inspector.set_meta("bot_main", self)
	get_tree().root.add_child(inspector)
	inspector.popup_centered()
