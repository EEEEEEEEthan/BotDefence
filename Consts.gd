extends RefCounted
class_name Consts

## 四向移动，用于 bot.move() 等 API
## NORTH=上 EAST=右 SOUTH=下 WEST=左（顺时针）
enum Cardinal { NORTH, EAST, SOUTH, WEST }

## 相对方向，前右后左（顺时针）
enum Direction { FORWARD, RIGHT, BACKWARD, LEFT }
