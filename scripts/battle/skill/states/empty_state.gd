class_name EmptyState extends SkillState

func enter() -> void:
	if skill.current_skill_index:
		skill.wait_count_down = skill.skill_data.wait_next_input_duration
	else:
		skill.reset()

func update(delta: float) -> void:
	if skill.current_skill_index:
		skill.wait_count_down -= delta
		if skill.wait_count_down <= 0:
			skill.set_state(Skill.StateName.COOLDOWN)
			return

	if skill.sub_skills[skill.current_skill_index].input.is_active():
		skill.set_state(Skill.StateName.INPUT)

func exit() -> void:
	skill.wait_count_down = 0
