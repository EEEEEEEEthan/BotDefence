extends GPUParticles2D
class_name MetalHitSpark


func setup(hit_position: Vector2, bullet_direction: Vector2) -> void:
	global_position = hit_position
	rotation = (-bullet_direction.normalized()).angle()


func _on_ready() -> void:
	emitting = true


func _on_finished() -> void:
	queue_free()
