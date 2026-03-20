extends RigidBody2D

const MOVE_PUSH_FORCE: float = 900.0
const ROTATE_SMOOTH: float = 12.0
const GOAL_REPLAN_DISTANCE: float = 32.0
const DIRECTION_EPSILON_SQ: float = 0.0004
const GOAL_CENTER: Vector2 = Vector2(565, 679)
const REMAINING_PATH_DISTANCE_CACHE_DURATION_MSEC: int = 200

@onready var nav_agent: NavigationAgent2D = $%NavigationAgent2D

var remaining_path_distance_cache: float = INF
var remaining_path_distance_cache_expire_time_msec: int = 0


func _physics_process(delta: float) -> void:
	nav_agent.target_position = GOAL_CENTER
	var next_position: Vector2 = nav_agent.get_next_path_position()
	var to_next: Vector2 = next_position - global_position
	var direction: Vector2 = Vector2.ZERO
	if to_next.length_squared() >= DIRECTION_EPSILON_SQ:
		direction = to_next.normalized()
		apply_central_force(direction * MOVE_PUSH_FORCE)

	var face: Vector2 = Vector2.ZERO
	if direction != Vector2.ZERO:
		face = direction
	elif linear_velocity.length_squared() >= DIRECTION_EPSILON_SQ:
		face = linear_velocity.normalized()
	if face != Vector2.ZERO:
		rotation = lerp_angle(rotation, face.angle(), ROTATE_SMOOTH * delta)

	if Time.get_ticks_msec() >= remaining_path_distance_cache_expire_time_msec:
		remaining_path_distance_cache = INF


func get_remaining_path_distance() -> float:
	var now_time_msec: int = Time.get_ticks_msec()
	if now_time_msec >= remaining_path_distance_cache_expire_time_msec:
		remaining_path_distance_cache = _calculate_remaining_path_distance()
		remaining_path_distance_cache_expire_time_msec = now_time_msec + REMAINING_PATH_DISTANCE_CACHE_DURATION_MSEC
	return remaining_path_distance_cache


func _calculate_remaining_path_distance() -> float:
	var current_navigation_path: PackedVector2Array = nav_agent.get_current_navigation_path()
	if current_navigation_path.is_empty():
		return INF

	var current_path_index: int = nav_agent.get_current_navigation_path_index()
	var clamped_path_index: int = clampi(current_path_index, 0, current_navigation_path.size() - 1)
	var remaining_path_distance: float = global_position.distance_to(current_navigation_path[clamped_path_index])
	for path_point_index in range(clamped_path_index, current_navigation_path.size() - 1):
		var from_path_point: Vector2 = current_navigation_path[path_point_index]
		var to_path_point: Vector2 = current_navigation_path[path_point_index + 1]
		remaining_path_distance += from_path_point.distance_to(to_path_point)
	return remaining_path_distance
