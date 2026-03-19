extends Sprite2D

## 游戏开始后沿导航网格移动到目标点，仅在 terrain 可行走区域移动

const MOVE_SPEED: float = 200.0

@onready var nav_agent: NavigationAgent2D = $NavigationAgent

func _ready() -> void:
	nav_agent.target_position = Vector2(565, 679)
	# NavigationAgent 需等一帧才能获取有效路径
	await get_tree().process_frame


func _physics_process(delta: float) -> void:
	if nav_agent.is_navigation_finished():
		return
	var next_position: Vector2 = nav_agent.get_next_path_position()
	global_position = global_position.move_toward(next_position, MOVE_SPEED * delta)
