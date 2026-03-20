extends Node
## 临时：_ready 时触发 MonsterSpawnPoint。测完删掉本节点与此脚本。

func _ready() -> void:
	var spawn_point: MonsterSpawnPoint = get_parent().get_node("MonsterSpawnPoint") as MonsterSpawnPoint
	if spawn_point == null:
		push_error("TempAutoSpawnTrigger: 未找到 MonsterSpawnPoint")
		return
	var config := MonsterSpawnConfig.new()
	config.monster_scene = preload("res://Monster.tscn")
	config.spawn_count = 100

	config.spawn_interval_seconds = 0.1
	spawn_point.spawn_with_config(config)
