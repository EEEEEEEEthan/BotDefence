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


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var target_monster: Node2D = _find_highest_priority_monster()
	if target_monster == null:
		return
	var look_direction: Vector2 = target_monster.global_position - global_position
	if look_direction.length_squared() <= 0.0001:
		return
	rotation = look_direction.angle()


func _find_highest_priority_monster() -> Node2D:
	var direct_space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var range_shape: CircleShape2D = CircleShape2D.new()
	range_shape.radius = detection_radius

	var shape_query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	shape_query.shape = range_shape
	shape_query.transform = Transform2D(0.0, global_position)
	shape_query.collision_mask = 1 << 1
	shape_query.collide_with_areas = false
	shape_query.collide_with_bodies = true

	var query_results: Array = direct_space_state.intersect_shape(shape_query, 64)
	var selected_monster: Node2D = null
	var best_remaining_path_distance: float = INF
	for query_result in query_results:
		var collider: Object = query_result["collider"]
		if not collider is Node2D:
			continue
		var monster: Node2D = collider
		if not monster.has_method("get_remaining_path_distance"):
			continue
		var remaining_path_distance: float = monster.call("get_remaining_path_distance")
		if remaining_path_distance < best_remaining_path_distance:
			best_remaining_path_distance = remaining_path_distance
			selected_monster = monster
	return selected_monster


func _refresh_range_visual() -> void:
	## `Range` 使用 Circle 资源，直径与 scale 对应，因此使用半径 * 2
	var range_diameter: float = detection_radius * 2.0
	range_node.scale = Vector2(range_diameter, range_diameter)
