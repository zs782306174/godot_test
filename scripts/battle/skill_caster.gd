## 技能释放器
## 负责：检测技能请求 → 激活输入 → 指示器瞄准 → 确认/取消
class_name SkillCaster extends Node3D

## IDLE: 空闲等待技能请求
## AIMING: 瞄准中（方向/目标点的第一阶段）
## AIMING_DIR: StartAndDir 的第二阶段，选完点后选方向
enum State { IDLE, AIMING, AIMING_DIR }

var skill: Skill
var state: State = State.IDLE
## 俯视角摄像机，用于鼠标射线投射
var camera: Camera3D
## 地面高度（y 轴），射线与 y=ground_y 平面求交
var ground_y: float = 0.0

## 指示器信号 —— 外部 UI/视觉系统监听这些信号来显示瞄准指示器
signal indicator_show(input_type: SubSkillData.SkillInputType)
signal indicator_update(aim_point: Vector3, aim_dir: Vector2)
signal indicator_hide()

func _process(delta: float) -> void:
	if skill == null or skill.get_current_state_name() != Skill.StateName.EMPTY:
		return
	match state:
		State.IDLE:
			_process_idle()
		State.AIMING:
			_process_aiming()
		State.AIMING_DIR:
			_process_aiming_dir()

# ---------------------------------------------------------------------------
# 输入读取
# ---------------------------------------------------------------------------

## 鼠标位置 → 摄像机射线 → 与地面平面求交 → 世界坐标
func get_aim_point() -> Vector3:
	if camera == null:
		return Vector3.ZERO
	var mouse_pos = camera.get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)
	# 射线近乎水平时无法与地面相交
	if absf(ray_dir.y) < 0.001:
		return Vector3.ZERO
	var t = (ground_y - ray_origin.y) / ray_dir.y
	return ray_origin + ray_dir * t

## 从 global_position 到瞄准点在 xz 平面上的归一化方向
func get_aim_direction() -> Vector2:
	var aim = get_aim_point()
	var diff = Vector2(aim.x - global_position.x, aim.z - global_position.z)
	if diff.length_squared() < 0.0001:
		return Vector2.ZERO
	return diff.normalized()

# ---------------------------------------------------------------------------
# 状态处理
# ---------------------------------------------------------------------------

## 空闲状态：检测技能键是否按下
func _process_idle() -> void:
	if not Input.is_action_just_pressed(skill.key):
		return
	if skill.get_current_state_name() != Skill.StateName.EMPTY:
		skill.input_cancel();
		return
	skill.input_active();
	_try_activate_skill()

## 尝试激活技能：调用 input.activate()，NoParam 直接走完，其他进入瞄准
func _try_activate_skill() -> void:
	var sub_skill = skill.sub_skills[skill.current_skill_index]
	var input = sub_skill.input
	input.activate()
	var input_type = sub_skill.data.input_type
	# NoParam 无需瞄准，activate 后 is_complete 立即为 true，FSM 自动推进
	if input_type == SubSkillData.SkillInputType.NoParam:
		return
	state = State.AIMING
	indicator_show.emit(input_type)

## 瞄准状态：持续更新指示器，处理确认/取消
func _process_aiming() -> void:
	var sub_skill = skill.sub_skills[skill.current_skill_index]
	var input = sub_skill.input
	var aim_point = get_aim_point()
	var aim_dir = get_aim_direction()
	indicator_update.emit(aim_point, aim_dir)

	# 右键取消：重置输入，InputState 检测到 !is_active() 会回退到 EMPTY
	if Input.is_action_just_pressed("cancel"):
		input.reset()
		_finish_aiming()
		return

	# 左键确认：根据输入类型填充数据
	if Input.is_action_just_pressed("confirm"):
		var input_type = sub_skill.data.input_type
		match input_type:
			SubSkillData.SkillInputType.Dir:
				(input as DirInput).set_direction(aim_dir)
				_finish_aiming()
			SubSkillData.SkillInputType.StartPoint:
				(input as StartPointInput).set_point(aim_point)
				_finish_aiming()
			SubSkillData.SkillInputType.StartAndDir:
				# 第一阶段完成（选点），进入第二阶段（选方向）
				(input as StartAndDirInput).set_point(aim_point)
				state = State.AIMING_DIR
				indicator_hide.emit()
				indicator_show.emit(input_type)

## StartAndDir 第二阶段：从已选定的点出发选择方向
func _process_aiming_dir() -> void:
	var sub_skill = skill.sub_skills[skill.current_skill_index]
	var input = sub_skill.input as StartAndDirInput
	var aim_point = get_aim_point()
	# 从已设定的起始点计算到当前鼠标位置的方向
	var from_point = Vector3(input.point.x, 0, input.point.y)
	var diff = Vector2(aim_point.x - from_point.x, aim_point.z - from_point.z)
	var aim_dir = diff.normalized() if diff.length_squared() > 0.0001 else Vector2.ZERO
	indicator_update.emit(aim_point, aim_dir)

	if Input.is_action_just_pressed("cancel"):
		input.reset()
		_finish_aiming()
		return

	if Input.is_action_just_pressed("confirm"):
		input.set_direction(aim_dir)
		_finish_aiming()

## 结束瞄准，回到空闲状态
func _finish_aiming() -> void:
	state = State.IDLE
	indicator_hide.emit()
