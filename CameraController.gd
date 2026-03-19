extends Camera2D

## 滚轮缩放、WASD 移动视野，使用插值平滑过渡
## 视野中心限制在 PathfindingField 范围内

@export var zoom_min: Vector2 = Vector2(0.25, 0.25)
@export var zoom_max: Vector2 = Vector2(3.0, 3.0)
@export var zoom_step: float = 0.15
@export var zoom_speed: float = 12.0
@export var move_speed: float = 400.0  ## 基准像素/秒，实际世界单位速度会按 zoom 反比调整
@export var move_lerp_speed: float = 12.0

var _target_zoom: Vector2 = Vector2.ONE
var _target_position: Vector2
var _move_up: bool = false
var _move_down: bool = false
var _move_left: bool = false
var _move_right: bool = false

@onready var _pathfinding_field: PathfindingField = get_parent().get_node("TileMapLayer/PathfindingField")


func _ready() -> void:
	_target_zoom = zoom
	_target_position = _clamp_to_bounds(position)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_move_up = false
		_move_down = false
		_move_left = false
		_move_right = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_zoom = (_target_zoom + Vector2(zoom_step, zoom_step)).clamp(zoom_min, zoom_max)
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_zoom = (_target_zoom - Vector2(zoom_step, zoom_step)).clamp(zoom_min, zoom_max)
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_W:
			_move_up = key_event.pressed
		elif key_event.keycode == KEY_S:
			_move_down = key_event.pressed
		elif key_event.keycode == KEY_A:
			_move_left = key_event.pressed
		elif key_event.keycode == KEY_D:
			_move_right = key_event.pressed


func _process(delta: float) -> void:
	var move_dir := Vector2.ZERO
	if _move_up:
		move_dir.y -= 1
	if _move_down:
		move_dir.y += 1
	if _move_left:
		move_dir.x -= 1
	if _move_right:
		move_dir.x += 1
	if move_dir != Vector2.ZERO:
		var effective_speed := move_speed / zoom.x  # zoom 越小(视野越大)移动越慢，保持屏幕像素速度一致
		_target_position = _clamp_to_bounds(_target_position + move_dir.normalized() * effective_speed * delta)

	var zoom_weight := 1.0 - exp(-zoom_speed * delta)
	zoom = zoom.lerp(_target_zoom, zoom_weight)

	var pos_weight := 1.0 - exp(-move_lerp_speed * delta)
	position = position.lerp(_target_position, pos_weight)


func _clamp_to_bounds(point: Vector2) -> Vector2:
	var bounds := _pathfinding_field.get_bounds_global()
	return Vector2(
		clampf(point.x, bounds.position.x, bounds.end.x),
		clampf(point.y, bounds.position.y, bounds.end.y)
	)
