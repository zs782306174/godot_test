extends Resource

class_name SubSkillData

enum SkillInputType {
	NoParam,
	Dir,
	StartPoint,
	StartAndDir,
}

@export var input_type: SkillInputType
@export var prefab: String
@export var view_delay: float
@export var logic_delay: float
@export var skill_type: Script