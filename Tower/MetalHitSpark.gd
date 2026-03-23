extends GPUParticles2D
class_name MetalHitSpark


func setup(hit_position: Vector2, bullet_direction: Vector2) -> void:
	global_position = hit_position
	rotation = (-bullet_direction.normalized()).angle()


func _ready() -> void:
	emitting = true
	await get_tree().create_timer(lifetime + 0.25).timeout
	queue_free()


func _on_ready() -> void:
	pass # Replace with function body.
