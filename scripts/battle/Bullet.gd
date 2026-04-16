extends Node3D

class_name Bullet

var bullet_data: BulletData
var direction: Vector3
var owner_id: int
var lifetime: float
var is_active: bool = true

signal bullet_hit(target: BattleUnit)
signal bullet_expired()

func _init(data: BulletData, bullet_direction: Vector3, owner: int):
	bullet_data = data
	direction = bullet_direction.normalized()
	owner_id = owner
	lifetime = data.lifetime
	is_active = true

func _process(delta):
	if not is_active:
		return
	
	lifetime -= delta
	
	if lifetime <= 0.0:
		is_active = false
		emit_signal("bullet_expired")
		queue_free()
		return
	
	global_position += direction * bullet_data.speed * delta

func get_damage() -> int:
	return bullet_data.damage

func get_owner_id() -> int:
	return owner_id

func deactivate():
	is_active = false
	queue_free()
