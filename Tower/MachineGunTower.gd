@tool
extends Tower

const FIRE_INTERVAL_SECONDS := 0.1
const META_BULLET_SCENE := "bullet_scene"
const TowerBulletScript := preload("res://Tower/TowerBullet.gd")

@onready var _fire_timer: Timer = %FireTimer
@onready var _config: Node = %Config
@onready var _fire_origin: Node2D = %FireOrigin

var _bullet_scene: PackedScene


func _ready() -> void:
	super._ready()
	_fire_timer.wait_time = FIRE_INTERVAL_SECONDS
	if Engine.is_editor_hint():
		return
	_bullet_scene = _config.get_meta(META_BULLET_SCENE) as PackedScene
	if _bullet_scene == null:
		push_error("MachineGunTower: Config 节点缺少或无效的 metadata「%s」" % META_BULLET_SCENE)
		return
	_fire_timer.start()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var target_monster: Node2D = highest_priority_monster
	if target_monster == null:
		return
	var aim_point: Vector2 = _get_predicted_monster_position(target_monster)
	var look_direction: Vector2 = aim_point - global_position
	if look_direction.length_squared() <= 0.0001:
		return
	var target_angle: float = look_direction.angle()
	var blend: float = 1.0 - exp(-_ROTATION_LERP_SPEED * delta)
	rotation = lerp_angle(rotation, target_angle, blend)


func _get_predicted_monster_position(monster: Node2D) -> Vector2:
	var to_monster_from_muzzle: Vector2 = monster.global_position - _fire_origin.global_position
	var distance: float = to_monster_from_muzzle.length()
	if distance <= 0.0001:
		return monster.global_position
	var flight_time: float = distance / TowerBulletScript.MOVE_SPEED
	var monster_velocity: Vector2 = Vector2.ZERO
	if monster is RigidBody2D:
		monster_velocity = monster.linear_velocity
	return monster.global_position + monster_velocity * flight_time


func _on_fire_timer_timeout() -> void:
	var target_monster: Node2D = highest_priority_monster
	if target_monster == null:
		return
	_spawn_bullet_forward()


## 沿塔身正前方（本地 +X）发射，与枪口朝向一致。
func _spawn_bullet_forward() -> void:
	var direction: Vector2 = global_transform.x.normalized()
	if direction.length_squared() <= 0.0001:
		return
	var bullet: Node2D = _bullet_scene.instantiate() as Node2D
	get_parent().add_child(bullet)
	bullet.global_position = _fire_origin.global_position
	bullet.global_rotation = direction.angle()
