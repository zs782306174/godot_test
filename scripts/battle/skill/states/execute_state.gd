class_name ExecuteState extends SkillState

var current_sub_skill: SubSkill

func enter() -> void:
	current_sub_skill = skill.sub_skills[skill.current_skill_index]
	current_sub_skill.start()

func update(delta: float) -> void:
	current_sub_skill.update(delta)
	if current_sub_skill.is_finished():
		skill.current_skill_index += 1
		if skill.current_skill_index >= skill.skill_count:
			skill.set_state(Skill.StateName.COOLDOWN)
		else:
			skill.set_state(Skill.StateName.EMPTY)

func exit() -> void:
	current_sub_skill = null
