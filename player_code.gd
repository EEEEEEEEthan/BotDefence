extends RefCounted

## 玩家编写的控制逻辑，纯 GDScript 同步写法
## bot.move_forward/turn 会阻塞直到完成，但不影响 Godot 主循环

func run(bot) -> void:
	bot.move_forward()
	bot.turn_right()
	bot.move_forward()
	bot.turn_right()
	bot.move_forward()
	bot.turn_right()
	bot.move_forward()
