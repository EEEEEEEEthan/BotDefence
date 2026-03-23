extends Area2D

const MOVE_SPEED: float = 720.0

const MetalHitSparkScene := preload("res://Tower/MetalHitSpark.tscn")


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += Vector2.RIGHT.rotated(global_rotation) * MOVE_SPEED * delta


func _on_body_entered(body: Node2D) -> void:
	_spawn_metal_hit_spark()
	if body.has_method("get_remaining_path_distance"):
		body.queue_free()
	queue_free()


func _spawn_metal_hit_spark() -> void:
	var spark: MetalHitSpark = MetalHitSparkScene.instantiate() as MetalHitSpark
	var bullet_direction: Vector2 = Vector2.RIGHT.rotated(global_rotation)
	spark.setup(global_position, bullet_direction)
	get_parent().add_child(spark)
