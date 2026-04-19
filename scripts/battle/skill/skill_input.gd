## 技能输入基类
## 定义输入采集的通用接口，子类根据不同输入类型实现具体逻辑。
## EmptyState 通过 is_active() 检测激活，InputState 通过 is_complete() 判断采集完成。
class_name SkillInput

var _active: bool = false

## 激活输入采集，由外部（SkillCaster / AI）调用
func activate() -> void:
	_active = true

## 输入是否处于激活状态
func is_active() -> bool:
	return _active

## 输入数据是否采集完成（基类默认立即完成）
func is_complete() -> bool:
	return true

## 重置输入状态，用于取消或技能循环复用
func reset() -> void:
	_active = false
