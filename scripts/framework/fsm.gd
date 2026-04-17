class_name FSM

## 有限状态机
## 通用状态机框架，管理状态的注册、切换与更新。


## 状态基类，自定义状态需继承此类并重写 enter/update/exit。
class State:
	var fsm: FSM
	var context
	func _init(f: FSM):
		fsm = f
	## 进入状态时调用
	func enter() -> void:
		pass

	## 每帧更新时调用
	func update(delta: float) -> void:
		pass

	## 退出状态时调用
	func exit() -> void:
		pass

var _states: Dictionary[int, State] = {}
var _current_state: State = null
var _current_state_name: int = -1


## 添加状态
func add_state(state_name: int, state: State) -> void:
	state.fsm = self
	_states[state_name] = state


## 移除状态
func remove_state(state_name: int) -> void:
	if _current_state_name == state_name:
		_current_state.exit()
		_current_state = null
		_current_state_name = -1
	_states.erase(state_name)


## 切换状态
func set_state(state_name: int) -> void:
	if _current_state_name == state_name:
		return
	if _current_state:
		_current_state.exit()
	_current_state_name = state_name
	_current_state = _states.get(state_name)
	if _current_state:
		_current_state.enter()


## 更新当前状态
func update(delta: float) -> void:
	if _current_state:
		_current_state.update(delta)


## 获取当前状态名
func get_current_state_name() -> int:
	return _current_state_name


## 获取当前状态实例
func get_current_state() -> State:
	return _current_state


## 是否包含指定状态
func has_state(state_name: int) -> bool:
	return _states.has(state_name)
