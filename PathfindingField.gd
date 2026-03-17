# todo: 改成 C# 版本（Queue/HashSet 性能更好）
extends RefCounted
class_name PathfindingField

const _CARDINAL := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]

var parent_map: Dictionary = {}
var _space: PathfindingSpace
var _open_list: Array[Vector2i] = []
var _close_set: Dictionary = {}
var _current: Vector2i

func _init(space: PathfindingSpace, source_list: Array[Vector2i]) -> void:
	_space = space
	for source in source_list:
		parent_map[source] = Vector2i(-0x80000000, -0x80000000)
	_open_list.assign(source_list)

func _iter_init(_arg = null) -> bool:
	if _open_list.is_empty():
		return false
	_current = _open_list.pop_front()
	_close_set[_current] = true
	_expand(_current)
	return true

func _iter_next(_arg = null) -> bool:
	while not _open_list.is_empty():
		_current = _open_list.pop_front()
		if _current in _close_set:
			continue
		_close_set[_current] = true
		_expand(_current)
		return true
	return false

func _iter_get(_arg = null) -> Vector2i:
	return _current

func _expand(cell: Vector2i) -> void:
	for direction in _CARDINAL:
		var neighbor: Vector2i = cell + direction
		if neighbor in _close_set or neighbor in parent_map:
			continue
		if neighbor not in _space.traversable_cells:
			continue
		parent_map[neighbor] = cell
		_open_list.append(neighbor)

func get_path(destination: Vector2i) -> Array[Vector2i]:
	var path_stack: Array[Vector2i] = []
	var current := destination
	while current in parent_map:
		var parent: Vector2i = parent_map[current]
		path_stack.append(current)
		if parent.x == -0x80000000:
			break
		current = parent
	path_stack.reverse()
	return path_stack
