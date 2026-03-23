extends Area2D

const MOVE_SPEED: float = 720.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += Vector2.RIGHT.rotated(global_rotation) * MOVE_SPEED * delta


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("get_remaining_path_distance"):
		body.queue_free()
	queue_free()
