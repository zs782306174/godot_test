class_name CooldownState extends FSM.State

## 进入状态时调用
func enter() -> void:
	var f = fsm as Skill
	f.current_cooldown = f.skill_data.cooldown

## 每帧更新时调用
func update(delta: float) -> void:
	fsm.current_cooldown -= delta
	if(fsm.current_cooldown <= 0.0):
		fsm.set_state(Skill.StateName.EMPTY)

## 退出状态时调用
func exit() -> void:
	fsm.current_skill_index = 0
	fsm.current_cooldown = 0
