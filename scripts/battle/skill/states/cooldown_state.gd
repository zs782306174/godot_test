class_name CooldownState extends SkillState

func enter() -> void:
	skill.current_cooldown = skill.skill_data.cooldown

func update(delta: float) -> void:
	skill.current_cooldown -= delta
	if skill.current_cooldown <= 0.0:
		skill.set_state(Skill.StateName.EMPTY)

func exit() -> void:
	skill.current_skill_index = 0
	skill.current_cooldown = 0
