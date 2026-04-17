extends Resource

class_name PlayerData

@export var id: int
@export var name: String
@export var level: int
@export var exp: int
@export var character_list: Array[RoleData] = []

func _init(p_id: int = 0, p_name: String = "", p_level: int = 1, p_exp: int = 0):
	id = p_id
	name = p_name
	level = p_level
	exp = p_exp
