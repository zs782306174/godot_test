class_name InterruptState extends FSM.State

## 进入状态时调用
func enter() -> void:
	pass

## 每帧更新时调用
func update(delta: float) -> void:
	if condition:
		pass

## 退出状态时调用
func exit() -> void:
	pass
