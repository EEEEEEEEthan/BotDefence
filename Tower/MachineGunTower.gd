@tool
extends Tower

const FIRE_INTERVAL_SECONDS := 0.1

@export var bullet_scene: PackedScene = preload("res://Tower/TowerBullet.tscn")

@onready var _fire_timer: Timer = %FireTimer


func _ready() -> void:
	super._ready()
	_fire_timer.wait_time = FIRE_INTERVAL_SECONDS
	if Engine.is_editor_hint():
		return
	_fire_timer.timeout.connect(_on_fire_timer_timeout)
	_fire_timer.start()


func _on_fire_timer_timeout() -> void:
	var target_monster: Node2D = highest_priority_monster
	if target_monster == null:
		return
	_spawn_bullet_toward(target_monster)


func _spawn_bullet_toward(target_monster: Node2D) -> void:
	var direction: Vector2 = target_monster.global_position - global_position
	if direction.length_squared() <= 0.0001:
		return
	var bullet: Node2D = bullet_scene.instantiate() as Node2D
	get_parent().add_child(bullet)
	bullet.global_position = global_position
	bullet.global_rotation = direction.angle()
