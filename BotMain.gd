extends Node2D

## 主线程 Bot 逻辑，通过 call_deferred 接收 Bot 的 move 请求
## 移动功能由 BotTaskMove 组件封装

var _move_task: BotTaskMove
var _current_task: BotTask

func _ready() -> void:
	_move_task = BotTaskMove.new(self)
	set_process(false)

func _process(delta: float) -> void:
	if _move_task.process(delta):
		_current_task = null

func get_bot_api() -> RefCounted:
	return Bot.new(self)

func is_cancelled() -> bool:
	return _move_task.aborted

## 由 Bot 通过 call_deferred 调用，抵达或取消时调用 callback
func move(target: Vector2, callback: Callable) -> void:
	_current_task = _move_task
	_move_task.start(target, callback)

## 退出时调用，中止当前任务
func cancel() -> void:
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
		print("Bot 被点击")
