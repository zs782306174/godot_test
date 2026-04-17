extends FSM


class_name Skill


enum StateName {
	EMPTY = 0,
	INPUT = 1,
	EXECUTE = 2,
	INTERRUPT = 3,
	COOLDOWN = 4,
}
var skill_data: SkillData
var current_cooldown: float = 0.0
var wait_count_down: float = 0.0
var current_skill_index: int = 0
var skill_count: int = 0;
var input: SkillInput
var sub_skills: Array[SubSkill]
func _init(data: SkillData):
	skill_data = data
	for sub in skill_data.:
		pass
	current_cooldown = 0.0
	current_skill_index = 0
	skill_count = data.sub_skills.size()
	wait_count_down = 0
	add_state(StateName.EMPTY, EmptyState.new(self ))
	add_state(StateName.INPUT, InputState.new(self ))
	add_state(StateName.EXECUTE, ExecuteState.new(self ))
	add_state(StateName.INTERRUPT, InterruptState.new(self ))
	add_state(StateName.COOLDOWN, CooldownState.new(self ))
	set_state(StateName.EMPTY);
