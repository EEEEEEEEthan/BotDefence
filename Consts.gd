extends RefCounted
class_name Consts

## 四向移动，用于 bot.move_forward、cardinal 等 API
## NORTH=上 EAST=右 SOUTH=下 WEST=左（顺时针）
enum Cardinal { NORTH, EAST, SOUTH, WEST }

const CARDINAL_OFFSETS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const OFFSET_TO_CARDINAL := {
	Vector2i(0, -1): Cardinal.SOUTH,
	Vector2i(1, 0): Cardinal.WEST,
	Vector2i(0, 1): Cardinal.NORTH,
	Vector2i(-1, 0): Cardinal.EAST,
}
const CARDINAL_TO_DIRECTION := {
	Cardinal.NORTH: Vector2(0, -1),
	Cardinal.EAST: Vector2(1, 0),
	Cardinal.SOUTH: Vector2(0, 1),
	Cardinal.WEST: Vector2(-1, 0),
}

## 相对方向，前右后左（顺时针）
enum Direction { FORWARD, RIGHT, BACKWARD, LEFT }
