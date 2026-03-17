extends RefCounted

## 注入用内部对象，仅用于执行行高亮，不暴露给玩家 API

var _bot_main: Object

func _init(bot_main: Object) -> void:
	_bot_main = bot_main

func report(line: int) -> void:
	_bot_main.call_deferred(&"_set_current_line", line)
