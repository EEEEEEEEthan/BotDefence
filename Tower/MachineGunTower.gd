@tool
extends Tower

const FIRE_INTERVAL_SECONDS := 0.1
const META_BULLET_SCENE := "bullet_scene"

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


func _on_fire_timer_timeout() -> void:
	var target_monster: Node2D = highest_priority_monster
	if target_monster == null:
		return
	_spawn_bullet_toward(target_monster)


func _spawn_bullet_toward(target_monster: Node2D) -> void:
	var direction: Vector2 = target_monster.global_position - _fire_origin.global_position
	if direction.length_squared() <= 0.0001:
		return
	var bullet: Node2D = _bullet_scene.instantiate() as Node2D
	get_parent().add_child(bullet)
	bullet.global_position = _fire_origin.global_position
	bullet.global_rotation = direction.angle()
