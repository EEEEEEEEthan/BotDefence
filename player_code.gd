extends RefCounted

## 玩家编写的控制逻辑，纯 GDScript 同步写法
## bot.move_to 会阻塞直到抵达，但不影响 Godot 主循环

func run(bot: Node2D) -> void:
	bot.move_to(100, 200)
	bot.move_to(400, 300)
	bot.move_to(200, 100)
