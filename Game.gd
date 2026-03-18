extends Node
class_name Game

## 每个 Bot 用各自保存的代码在子进程运行
## 每个 Bot 通过自己的检视器 Play 按钮独立启动脚本
## 通过 stdio 行协议与 Python 子进程交互，无需 TCP 服务器

@onready var tilemap: TileMapLayer = $%TileMapLayer
