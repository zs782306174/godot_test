class_name InterruptState extends SkillState

func enter() -> void:
	var current_sub_skill = skill.sub_skills[skill.current_skill_index]
	current_sub_skill.interrupt()
	skill.set_state(Skill.StateName.COOLDOWN)

func update(delta: float) -> void:
	pass

func exit() -> void:
	fsm.current_skill_index = 0
