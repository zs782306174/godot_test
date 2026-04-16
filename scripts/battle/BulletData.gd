
class_name BulletData

@export var id: int
@export var name: String
@export var damage: int
@export var speed: float
@export var lifetime: float

func _init(p_id: int = 0, p_name: String = "", p_damage: int = 10, p_speed: float = 20.0, p_lifetime: float = 3.0):
	id = p_id
	name = p_name
	damage = p_damage
	speed = p_speed
	lifetime = p_lifetime
