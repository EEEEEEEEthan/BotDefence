extends Node2D
class_name MonsterSpawnPoint

## 按 MonsterSpawnConfig 定时生成怪物；每次 spawn_with_config 为独立协程，可并行多条配置

@export var monsters_parent: Node

func spawn_with_config(config: MonsterSpawnConfig) -> void:
	_spawn_async(config)


func _spawn_async(config: MonsterSpawnConfig) -> void:
	if config == null or config.monster_scene == null:
		push_warning("MonsterSpawnPoint: config 或 monster_scene 为空")
		return
	var total_count: int = config.spawn_count
	if total_count <= 0:
		return

	var parent_node: Node = monsters_parent if monsters_parent else get_parent()

	for spawn_index in range(total_count):
		if not is_inside_tree():
			return
		var monster: Node = config.monster_scene.instantiate()
		parent_node.add_child(monster)
		monster.global_position = global_position

		var is_last: bool = spawn_index >= total_count - 1
		if is_last:
			break
		if config.spawn_interval_seconds > 0.0:
			await get_tree().create_timer(config.spawn_interval_seconds).timeout
