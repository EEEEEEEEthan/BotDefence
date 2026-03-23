extends Node2D
class_name MetalHitSpark

var _bullet_direction: Vector2 = Vector2.RIGHT


func setup(hit_position: Vector2, bullet_direction: Vector2) -> void:
	global_position = hit_position
	_bullet_direction = bullet_direction.normalized()


func _ready() -> void:
	var particles := GPUParticles2D.new()
	var material := ParticleProcessMaterial.new()
	particles.process_material = material
	add_child(particles)

	material.particle_flag_disable_z = true

	var spark_gradient := Gradient.new()
	spark_gradient.set_color(0, Color(1.0, 0.97, 0.88, 1.0))
	spark_gradient.set_color(1, Color(0.55, 0.58, 0.65, 0.0))
	var color_ramp_texture := GradientTexture1D.new()
	color_ramp_texture.gradient = spark_gradient
	material.color_ramp = color_ramp_texture

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
	particles.fixed_fps = 0
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.92
	particles.randomness = 0.45
	particles.amount = 28
	particles.lifetime = 0.38

	material.lifetime_randomness = 0.35
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 3.0
	material.direction = Vector3(1, 0, 0)
	material.spread = 70.0
	material.initial_velocity_min = 90.0
	material.initial_velocity_max = 220.0
	material.angular_velocity_min = -420.0
	material.angular_velocity_max = 420.0
	material.scale_min = 0.35
	material.scale_max = 0.95
	material.gravity = Vector3(0, 180, 0)

	rotation = (-_bullet_direction).angle()

	particles.emitting = true
	var wait_seconds: float = particles.lifetime + 0.25
	await get_tree().create_timer(wait_seconds).timeout
	queue_free()
