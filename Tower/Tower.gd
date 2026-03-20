@tool
extends Node2D

const GROUP_TOWER_DEBUG_PICK: String = "tower_debug_pick"

## 索敌半径（与 `intersect_shape` 的圆形查询一致）
@export var detection_radius: float = 600.0
## 单次查询最多返回的碰撞体数量，应不小于场上怪物数量
@export var max_monster_query_results: int = 128

@export_group("调试绘制")
## 开启后才会执行绘制逻辑（运行时还可受「仅聚焦时」限制）
@export var debug_draw_enabled: bool = false
## 运行时：仅在被鼠标点选聚焦后绘制；编辑器无法获知场景树选中，请用「编辑器中显示」
@export var debug_draw_only_when_focused: bool = true
## 在编辑器中显示索敌圆与连线（不依赖运行游戏）
@export var debug_show_in_editor: bool = false
## 左键点选塔的判定半径（世界单位）
@export var debug_pick_radius: float = 80.0

## 怪物刚体在 `Monster.tscn` 中设为 collision_layer = 2
const MONSTER_COLLISION_MASK: int = 2

var _circle_shape: CircleShape2D
var _shape_query: PhysicsShapeQueryParameters2D

var _closest_monster: CollisionObject2D = null
var _closest_distance: float = 0.0
var _debug_focused: bool = false
var _drew_debug_last_frame: bool = false


func _ready() -> void:
	_circle_shape = CircleShape2D.new()
	_shape_query = PhysicsShapeQueryParameters2D.new()
	_shape_query.shape = _circle_shape
	_shape_query.collision_mask = MONSTER_COLLISION_MASK
	_shape_query.collide_with_areas = false
	_shape_query.collide_with_bodies = true
	add_to_group(GROUP_TOWER_DEBUG_PICK)
	set_process_unhandled_input(true)
	set_process(Engine.is_editor_hint())


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	if debug_draw_enabled and debug_show_in_editor:
		_refresh_closest_monster()
	if _drew_debug_last_frame or (debug_draw_enabled and debug_show_in_editor):
		queue_redraw()


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if debug_draw_enabled and (not debug_draw_only_when_focused or _debug_focused):
		_refresh_closest_monster()
	if _drew_debug_last_frame or _should_draw_debug():
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if not debug_draw_enabled or not debug_draw_only_when_focused:
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_button_event: InputEventMouseButton = event
	if not mouse_button_event.pressed:
		return
	if mouse_button_event.button_index != MOUSE_BUTTON_LEFT:
		return

	var mouse_global: Vector2 = get_global_mouse_position()
	var pick_radius_squared: float = debug_pick_radius * debug_pick_radius
	var towers: Array[Node] = get_tree().get_nodes_in_group(GROUP_TOWER_DEBUG_PICK)

	var focused_tower: Node2D = null
	var closest_pick_distance_squared: float = INF

	for tower_node in towers:
		if not tower_node is Node2D:
			continue
		var tower_transform_node: Node2D = tower_node as Node2D
		var distance_squared: float = tower_transform_node.global_position.distance_squared_to(mouse_global)
		if distance_squared <= pick_radius_squared and distance_squared < closest_pick_distance_squared:
			closest_pick_distance_squared = distance_squared
			focused_tower = tower_transform_node

	for tower_node in towers:
		if not tower_node.has_method("_apply_debug_focus"):
			continue
		tower_node._apply_debug_focus(focused_tower == tower_node)


func _apply_debug_focus(is_focused: bool) -> void:
	_debug_focused = is_focused
	if _drew_debug_last_frame or _should_draw_debug():
		queue_redraw()


func _should_draw_debug() -> bool:
	if not debug_draw_enabled:
		return false
	if Engine.is_editor_hint():
		return debug_show_in_editor
	if debug_draw_only_when_focused:
		return _debug_focused
	return true


func _draw() -> void:
	var should_draw: bool = _should_draw_debug()
	if should_draw:
		var range_color: Color = Color(0.95, 0.85, 0.2, 0.85)
		draw_arc(Vector2.ZERO, detection_radius, 0.0, TAU, 96, range_color, 2.0, true)

		if _closest_monster != null and is_instance_valid(_closest_monster):
			var monster_local: Vector2 = to_local(_closest_monster.global_position)
			draw_line(Vector2.ZERO, monster_local, Color(1.0, 0.35, 0.25, 0.95), 2.0, true)
			var distance_label: String = "%.1f" % _closest_distance
			_draw_centered_debug_label(distance_label, Vector2(0.0, -detection_radius - 18.0), 14)
		else:
			_draw_centered_debug_label("无目标", Vector2(0.0, -detection_radius - 18.0), 14)

	_drew_debug_last_frame = should_draw


func _draw_centered_debug_label(label_text: String, label_position: Vector2, font_size: int) -> void:
	var label_font: Font = ThemeDB.fallback_font
	var text_width: float = label_font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var adjusted_position: Vector2 = label_position - Vector2(text_width * 0.5, 0.0)
	draw_string(label_font, adjusted_position, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)


func _refresh_closest_monster() -> void:
	_circle_shape.radius = detection_radius
	_shape_query.transform = global_transform

	var world_2d: World2D = get_world_2d()
	if world_2d == null:
		_closest_monster = null
		_closest_distance = 0.0
		return

	var direct_space_state: PhysicsDirectSpaceState2D = world_2d.direct_space_state
	var intersection_results: Array = direct_space_state.intersect_shape(_shape_query, max_monster_query_results)

	var tower_position: Vector2 = global_position
	var closest: CollisionObject2D = null
	var closest_distance_squared: float = INF

	for intersection_entry in intersection_results:
		var collider: Variant = intersection_entry.get("collider", null)
		if collider == null or not collider is CollisionObject2D:
			continue
		var collision_object: CollisionObject2D = collider
		var distance_squared: float = tower_position.distance_squared_to(collision_object.global_position)
		if distance_squared < closest_distance_squared:
			closest_distance_squared = distance_squared
			closest = collision_object

	_closest_monster = closest
	if closest == null:
		_closest_distance = 0.0
	else:
		_closest_distance = sqrt(closest_distance_squared)
