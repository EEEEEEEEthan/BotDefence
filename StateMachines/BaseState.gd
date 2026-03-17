extends Node
class_name BaseState

## 状态机基类，子节点 owner 为 BotMain
## 仅开放 bot_main 供子类访问

var bot_main: Node:
	get: return owner
