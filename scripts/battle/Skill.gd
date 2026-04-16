extends Node

class_name Skill

var skill_data: SkillData
var current_cooldown: float = 0.0

func _init(data: SkillData):
	skill_data = data
	current_cooldown = 0.0

func can_use() -> bool:
	return current_cooldown <= 0.0

func use() -> void:
	current_cooldown = skill_data.cooldown

func update(delta: float) -> void:
	if current_cooldown > 0.0:
		current_cooldown -= delta
		if current_cooldown < 0.0:
			current_cooldown = 0.0

func get_cooldown_progress() -> float:
	if skill_data.cooldown > 0.0:
		return 1.0 - (current_cooldown / skill_data.cooldown)
	return 1.0
