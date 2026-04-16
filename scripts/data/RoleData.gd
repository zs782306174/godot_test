extends Resource

class_name RoleData

@export var id: int
@export var name: String
@export var level: int
@export var exp: int
@export var hp: int
@export var mp: int
@export var atk: int
@export var speed: float
@export var attack_range: float
@export var skill_ids: Array[int] = []

func _init(p_id: int = 0, p_name: String = "", p_level: int = 1, p_exp: int = 0, p_hp: int = 100, p_mp: int = 100, p_atk: int = 10, p_speed: float = 5.0, p_attack_range: float = 2.0):
	id = p_id
	name = p_name
	level = p_level
	exp = p_exp
	hp = p_hp
	mp = p_mp
	atk = p_atk
	speed = p_speed
	attack_range = p_attack_range
