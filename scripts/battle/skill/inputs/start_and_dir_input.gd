## 起始点+方向输入：两阶段采集，先选点再选方向
## 用于从指定位置向某方向释放的技能（如定点方向 AOE）
class_name StartAndDirInput extends SkillInput

## 起始点坐标（xz 平面）
var point: Vector2 = Vector2.ZERO
## 归一化后的方向向量
var direction: Vector2 = Vector2.ZERO
var _point_set: bool = false
var _dir_set: bool = false

## 设置起始点（第一阶段）
func set_point(pos: Vector2) -> void:
	point = pos
	_point_set = true

## 设置方向（第二阶段），自动归一化
func set_direction(dir: Vector2) -> void:
	direction = dir.normalized()
	_dir_set = true

## 两者都设置后才算完成
func is_complete() -> bool:
	return _point_set and _dir_set

func reset() -> void:
	super.reset()
	point = Vector2.ZERO
	direction = Vector2.ZERO
	_point_set = false
	_dir_set = false
