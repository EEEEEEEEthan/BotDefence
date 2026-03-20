extends Node2D

## 索敌半径（与 `intersect_shape` 的圆形查询一致）
@export var detection_radius: float = 600.0
## 单次查询最多返回的碰撞体数量，应不小于场上怪物数量
@export var max_monster_query_results: int = 128

## 怪物刚体在 `Monster.tscn` 中设为 collision_layer = 2
const MONSTER_COLLISION_MASK: int = 2

var _circle_shape: CircleShape2D
var _shape_query: PhysicsShapeQueryParameters2D


func _ready() -> void:
	_circle_shape = CircleShape2D.new()
	_shape_query = PhysicsShapeQueryParameters2D.new()
	_shape_query.shape = _circle_shape
	_shape_query.collision_mask = MONSTER_COLLISION_MASK
	_shape_query.collide_with_areas = false
	_shape_query.collide_with_bodies = true


func _physics_process(_delta: float) -> void:
	_circle_shape.radius = detection_radius
	_shape_query.transform = global_transform

	var direct_space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var intersection_results: Array = direct_space_state.intersect_shape(_shape_query, max_monster_query_results)

	var tower_position: Vector2 = global_position
	var closest_monster: CollisionObject2D = null
	var closest_distance_squared: float = INF

	for intersection_entry in intersection_results:
		var collider: Variant = intersection_entry.get("collider", null)
		if collider == null or not collider is CollisionObject2D:
			continue
		var collision_object: CollisionObject2D = collider
		var distance_squared: float = tower_position.distance_squared_to(collision_object.global_position)
		if distance_squared < closest_distance_squared:
			closest_distance_squared = distance_squared
			closest_monster = collision_object

	if closest_monster == null:
		print("[%s] 索敌范围内无怪物" % name)
	else:
		var distance: float = sqrt(closest_distance_squared)
		print("[%s] 最近怪物: %s 距离: %.1f" % [name, closest_monster.name, distance])
