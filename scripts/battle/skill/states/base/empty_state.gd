class_name EmptyState extends FSM.State

## 进入状态时调用
func enter() -> void:
	if fsm.current_skill_index:
		fsm.wait_count_down = fsm.skill_data.wait_next_input_duration
	else:
		fsm.reset()

## 每帧更新时调用
func update(delta: float) -> void:
	if fsm.current_skill_index:
		fsm.wait_count_down -= delta
		if fsm.wait_count_down <= 0:
			fsm.set_state(Skill.StateName.COOLDOWN)
			return

	if fsm.input.is_active():
		fsm.set_state(Skill.StateName.INPUT)

## 退出状态时调用
func exit() -> void:
	fsm.wait_count_down = 0
	pass
