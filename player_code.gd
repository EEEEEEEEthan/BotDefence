extends RefCounted

## 玩家编写的控制逻辑，纯 GDScript 同步写法
## bot.move 会阻塞直到抵达，但不影响 Godot 主循环

func run(bot) -> void:
	bot.move(Consts.NORTH)
	bot.move(Consts.EAST)
	bot.move(Consts.SOUTH)
	bot.move(Consts.WEST)
