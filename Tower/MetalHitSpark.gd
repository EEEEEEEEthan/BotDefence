extends Node2D
class_name MetalHitSpark

var _bullet_direction: Vector2 = Vector2.RIGHT


func setup(hit_position: Vector2, bullet_direction: Vector2) -> void:
	global_position = hit_position
	_bullet_direction = bullet_direction.normalized()


func _ready() -> void:
	var particles := CPUParticles2D.new()
	add_child(particles)

	var spark_gradient := Gradient.new()
	spark_gradient.set_color(0, Color(1.0, 0.97, 0.88, 1.0))
	spark_gradient.set_color(1, Color(0.55, 0.58, 0.65, 0.0))
	particles.color_ramp = spark_gradient

	var dot_gradient := Gradient.new()
	dot_gradient.set_color(0, Color(1, 1, 1, 1))
	dot_gradient.set_color(1, Color(1, 1, 1, 0))
	var dot_texture := GradientTexture2D.new()
	dot_texture.gradient = dot_gradient
	dot_texture.width = 10
	dot_texture.height = 10
	dot_texture.fill = GradientTexture2D.FILL_RADIAL
	particles.texture = dot_texture

	particles.z_index = 5
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.92
	particles.randomness = 0.45
	particles.amount = 28
	particles.lifetime = 0.38
	particles.lifetime_randomness = 0.35
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 3.0
	particles.direction = Vector2(1, 0)
	particles.spread = 70.0
	particles.initial_velocity_min = 90.0
	particles.initial_velocity_max = 220.0
	particles.angular_velocity_min = -420.0
	particles.angular_velocity_max = 420.0
	particles.scale_amount_min = 0.35
	particles.scale_amount_max = 0.95
	particles.gravity = Vector2(0, 180)

	rotation = (-_bullet_direction).angle()

	particles.emitting = true
	var wait_seconds: float = particles.lifetime + 0.25
	await get_tree().create_timer(wait_seconds).timeout
	queue_free()
