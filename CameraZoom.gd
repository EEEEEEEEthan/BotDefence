extends Camera2D

## 滚轮缩放相机，使用插值平滑过渡

@export var zoom_min: Vector2 = Vector2(0.25, 0.25)
@export var zoom_max: Vector2 = Vector2(3.0, 3.0)
@export var zoom_step: float = 0.15
@export var zoom_speed: float = 12.0

var _target_zoom: Vector2 = Vector2.ONE


func _ready() -> void:
	_target_zoom = zoom


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_zoom = (_target_zoom + Vector2(zoom_step, zoom_step)).clamp(zoom_min, zoom_max)
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_zoom = (_target_zoom - Vector2(zoom_step, zoom_step)).clamp(zoom_min, zoom_max)


func _process(delta: float) -> void:
	var weight := 1.0 - exp(-zoom_speed * delta)
	zoom = zoom.lerp(_target_zoom, weight)
