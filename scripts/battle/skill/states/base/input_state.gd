class_name InputState extends FSM.State

## 进入状态时调用
func enter() -> void:
	pass

## 每帧更新时调用
func update(delta: float) -> void:
	if not fsm.input.is_active():
		fsm.set_state(Skill.StateName.EMPTY)
	if not fsm.input.is_complete():
		fsm.set_state(Skill.StateName.EXECUTE)

## 退出状态时调用
func exit() -> void:
	pass
