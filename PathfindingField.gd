@tool
extends Node2D
class_name PathfindingField

## 寻路场：烘焙每个格子的移动方向（flow field）
## 烘焙范围在编辑器中可见；根据 TileMapLayer 的瓦片类型判定可走/终点

## 烘焙范围（瓦片坐标）
@export var bake_range: Rect2i = Rect2i(0, 0, 16, 16):
	set(value):
		bake_range = value
		if Engine.is_editor_hint():
			queue_redraw()

@export var _bake_preview: bool = false:
	set(value):
		if value:
			bake()

## 有 custom_data platform 的格子为不可走；有 custom_data target 的格子为终点
## 烘焙结果：瓦片坐标 -> 移动方向（Consts.Cardinal）
var flow_map: Dictionary = {}
func _ready() -> void:
	if Engine.is_editor_hint():
		bake()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var tilemap_layer = owner.get_node("%TileMapLayer") as TileMapLayer
	if not tilemap_layer:
		return
	# bake_range 为格子单位；map_to_local 不包含 scale，需用 tile_set.tile_size
	var tile_set: TileSet = tilemap_layer.tile_set
	if not tile_set:
		return
	var cell_size: Vector2 = Vector2(tile_set.tile_size)
	# 格子 -> TileMapLayer 本地坐标（未缩放）
	var rect_origin: Vector2 = tilemap_layer.map_to_local(bake_range.position) - cell_size / 2
	var rect_size: Vector2 = Vector2(bake_range.size) * cell_size
	# PathfindingField 为 TileMapLayer 子节点且 scale=0.125，需放大以抵消自身缩放
	var inv_scale: float = 1.0 / scale.x
	rect_origin *= inv_scale
	rect_size *= inv_scale
	draw_rect(Rect2(rect_origin, rect_size), Color(1, 0.5, 0, 0.4), true)
	draw_rect(Rect2(rect_origin, rect_size), Color(1, 0.5, 0, 0.8), false)
	# 在每个格子中心绘制流场方向
	var arrow_length: float = cell_size.x * 0.35 * inv_scale
	var head_length: float = arrow_length * 0.4
	var head_width: float = arrow_length * 0.35
	var arrow_color: Color = Color(1, 0.5, 0, 0.9)
	for tile_coords in flow_map:
		var cardinal: Consts.Cardinal = flow_map[tile_coords]
		var direction: Vector2 = Consts.CARDINAL_TO_DIRECTION[cardinal]
		var center: Vector2 = tilemap_layer.map_to_local(tile_coords) * inv_scale
		var tip: Vector2 = center + direction * arrow_length
		draw_line(center, tip, arrow_color)
		var ortho: Vector2 = direction.orthogonal()
		var base_left: Vector2 = tip - direction * head_length + ortho * head_width * 0.5
		var base_right: Vector2 = tip - direction * head_length - ortho * head_width * 0.5
		draw_colored_polygon(PackedVector2Array([tip, base_left, base_right]), arrow_color)


func bake() -> void:
	flow_map.clear()
	var tilemap_layer = owner.get_node("%TileMapLayer") as TileMapLayer
	var cost_map: Dictionary = {}

	# 收集终点（sources），初始化 cost
	var sources: Array[Vector2i] = []
	var open_list: Array[Dictionary] = []
	var closed_set: Dictionary = {}
	for x in range(bake_range.position.x, bake_range.position.x + bake_range.size.x):
		for y in range(bake_range.position.y, bake_range.position.y + bake_range.size.y):
			var coords := Vector2i(x, y)
			if not _is_walkable(tilemap_layer, coords):
				continue
			if _is_destination(tilemap_layer, coords):
				cost_map[coords] = 0
				sources.append(coords)
				var heuristic := _heuristic_to_sources(coords, sources)
				open_list.append({"pos": coords, "f": heuristic})
			else:
				cost_map[coords] = -1

	# A* 扩散，启发函数为到最近 source 的欧氏距离
	while open_list.size() > 0:
		var best_idx := 0
		for idx in range(1, open_list.size()):
			if open_list[idx]["f"] < open_list[best_idx]["f"]:
				best_idx = idx
		var current_entry: Dictionary = open_list[best_idx]
		open_list.remove_at(best_idx)
		var current: Vector2i = current_entry["pos"]
		if current in closed_set:
			continue
		closed_set[current] = true
		var current_cost: int = cost_map[current]
		for offset in Consts.CARDINAL_OFFSETS:
			var neighbor: Vector2i = current + offset
			if not bake_range.has_point(neighbor):
				continue
			if neighbor in closed_set:
				continue
			if not _is_walkable(tilemap_layer, neighbor):
				continue
			var tentative_cost: int = current_cost + 1
			if neighbor in cost_map and cost_map[neighbor] >= 0 and cost_map[neighbor] <= tentative_cost:
				continue
			cost_map[neighbor] = tentative_cost
			flow_map[neighbor] = Consts.OFFSET_TO_CARDINAL[offset]
			var neighbor_heuristic := _heuristic_to_sources(neighbor, sources)
			open_list.append({"pos": neighbor, "f": tentative_cost + neighbor_heuristic})
	if Engine.is_editor_hint():
		queue_redraw()


func get_flow_at(tile_coords: Vector2i) -> Variant:
	return flow_map.get(tile_coords, null)


func get_bounds_global() -> Rect2:
	var tilemap_layer := get_parent() as TileMapLayer
	if not tilemap_layer or not tilemap_layer.tile_set:
		return Rect2(0, 0, 0, 0)
	var cell_size := Vector2(tilemap_layer.tile_set.tile_size)
	var origin_local := tilemap_layer.map_to_local(bake_range.position) - cell_size / 2
	var size_local := Vector2(bake_range.size) * cell_size
	var min_point := tilemap_layer.to_global(origin_local)
	var max_point := tilemap_layer.to_global(origin_local + size_local)
	return Rect2(min_point, max_point - min_point)


func _heuristic_to_sources(cell: Vector2i, sources: Array[Vector2i]) -> float:
	var min_dist := INF
	for source in sources:
		var dist := Vector2(cell).distance_to(Vector2(source))
		if dist < min_dist:
			min_dist = dist
	return min_dist


func _is_walkable(tilemap_layer: TileMapLayer, coords: Vector2i) -> bool:
	var tile_data: TileData = tilemap_layer.get_cell_tile_data(coords)
	if not tile_data:
		return true  # 空可走
	return tile_data.get_custom_data("platform") != true


func _is_destination(tilemap_layer: TileMapLayer, coords: Vector2i) -> bool:
	var tile_data: TileData = tilemap_layer.get_cell_tile_data(coords)
	if not tile_data:
		return false
	return tile_data.get_custom_data("target") == true
