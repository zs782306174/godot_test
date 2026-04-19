## 目标点输入：需要提供一个位置坐标，用于指定位置施法（如 AOE）
class_name StartPointInput extends SkillInput

## 目标点坐标（xz 平面）
var point: Vector2 = Vector2.ZERO
var _completed: bool = false

## 设置目标点并标记完成
func set_point(pos: Vector2) -> void:
	point = pos
	_completed = true

func is_complete() -> bool:
	return _completed

func reset() -> void:
	super.reset()
	point = Vector2.ZERO
	_completed = false
