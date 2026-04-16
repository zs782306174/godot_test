extends Resource

class_name BuffData

@export var id: int
@export var name: String
@export var desc: String
@export var duration: float
@export var type: String

func _init(p_id: int = 0, p_name: String = "", p_desc: String = "", p_duration: float = 5.0, p_type: String = "buff"):
	id = p_id
	name = p_name
	desc = p_desc
	duration = p_duration
	type = p_type
