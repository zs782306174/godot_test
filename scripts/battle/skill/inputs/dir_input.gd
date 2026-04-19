## 方向输入：需要提供一个方向向量，用于冲刺、方向性攻击等技能
class_name DirInput extends SkillInput

## 归一化后的方向向量
var direction: Vector2 = Vector2.ZERO
var _completed: bool = false

## 设置方向，自动归一化并标记完成
func set_direction(dir: Vector2) -> void:
	direction = dir.normalized()
	_completed = true

func is_complete() -> bool:
	return _completed

func reset() -> void:
	super.reset()
	direction = Vector2.ZERO
	_completed = false
