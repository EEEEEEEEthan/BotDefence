@tool
extends Node2D

@onready var range_node: Node2D = %Range

## 索敌半径（世界单位）
@export var detection_radius: float = 200.0:
	set(value):
		detection_radius = max(value, 0.0)
		if is_node_ready():
			_refresh_range_visual()


func _ready() -> void:
	_refresh_range_visual()


func _refresh_range_visual() -> void:
	## `Range` 使用 Circle 资源，直径与 scale 对应，因此使用半径 * 2
	var range_diameter: float = detection_radius * 2.0
	range_node.scale = Vector2(range_diameter, range_diameter)
