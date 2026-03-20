extends Resource
class_name MonsterSpawnConfig

## 单次召唤序列使用的数据；可保存为 .tres 在多处复用

@export var monster_scene: PackedScene
@export var spawn_count: int = 1
@export var spawn_interval_seconds: float = 1.0
