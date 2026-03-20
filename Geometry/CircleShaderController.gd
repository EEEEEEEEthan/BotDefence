@tool
extends Node

@export var target_canvas_item: CanvasItem

@export var fill_color: Color = Color(0.22, 0.62, 1.0, 1.0):
	set(value):
		fill_color = value
		_apply_fill_color()

@export var outline_color: Color = Color(1.0, 1.0, 1.0, 1.0):
	set(value):
		outline_color = value
		_apply_outline_color()

@export_range(0.0, 0.5, 0.001) var outline_width: float = 0.06:
	set(value):
		outline_width = clampf(value, 0.0, 0.5)
		_apply_outline_width()

@export_range(0.0, 0.5, 0.001) var outline_soft: float = 0.06:
	set(value):
		outline_soft = clampf(value, 0.0, 0.5)
		_apply_outline_soft()

func _ready() -> void:
	_apply_all_parameters()

func _apply_all_parameters() -> void:
	_apply_fill_color()
	_apply_outline_color()
	_apply_outline_width()
	_apply_outline_soft()

func _apply_fill_color() -> void:
	var canvas_item: CanvasItem = _resolve_target_canvas_item()
	if canvas_item == null:
		return
	canvas_item.set_instance_shader_parameter(&"fill_color", fill_color)

func _apply_outline_color() -> void:
	var canvas_item: CanvasItem = _resolve_target_canvas_item()
	if canvas_item == null:
		return
	canvas_item.set_instance_shader_parameter(&"outline_color", outline_color)

func _apply_outline_width() -> void:
	var canvas_item: CanvasItem = _resolve_target_canvas_item()
	if canvas_item == null:
		return
	canvas_item.set_instance_shader_parameter(&"outline_width", outline_width)

func _apply_outline_soft() -> void:
	var canvas_item: CanvasItem = _resolve_target_canvas_item()
	if canvas_item == null:
		return
	canvas_item.set_instance_shader_parameter(&"outline_soft", outline_soft)

func _resolve_target_canvas_item() -> CanvasItem:
	if target_canvas_item != null:
		return target_canvas_item
	var current_node: Node = self
	if current_node is CanvasItem:
		return current_node as CanvasItem
	if get_parent() is CanvasItem:
		return get_parent() as CanvasItem
	return null
