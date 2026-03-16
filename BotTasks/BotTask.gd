extends RefCounted
class_name BotTask

## Bot 任务基类，子类实现具体逻辑
## 开放 API: abort() 用于取消任务

func abort() -> void:
	pass
