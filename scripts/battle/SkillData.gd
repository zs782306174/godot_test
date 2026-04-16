extends Resource

class_name SkillData

@export var id: int
@export var name: String
@export var desc: String
@export var damage: int
@export var range: float
@export var cooldown: float
@export var mana_cost: int

func _init(p_id: int = 0, p_name: String = "", p_desc: String = "", p_damage: int = 0, p_range: float = 5.0, p_cooldown: float = 1.0, p_mana_cost: int = 10):
	id = p_id
	name = p_name
	desc = p_desc
	damage = p_damage
	range = p_range
	cooldown = p_cooldown
	mana_cost = p_mana_cost
