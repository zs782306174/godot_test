class_name InputState extends SkillState

func enter() -> void:
	pass

func update(delta: float) -> void:
	var input = skill.sub_skills[skill.current_skill_index].input
	if not input.is_active():
		skill.set_state(Skill.StateName.EMPTY)
		return
	if input.is_complete():
		skill.set_state(Skill.StateName.EXECUTE)

func exit() -> void:
	pass
