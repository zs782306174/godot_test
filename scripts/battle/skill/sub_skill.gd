class_name SubSkill
var data: SubSkillData
var input: SkillInput
var finished: bool = false
func _init(_data: SubSkillData):
	data = _data
	input = _create_input(_data.input_type)

static func _create_input(type: SubSkillData.SkillInputType) -> SkillInput:
	match type:
		SubSkillData.SkillInputType.NoParam: return NoParamInput.new()
		SubSkillData.SkillInputType.Dir: return DirInput.new()
		SubSkillData.SkillInputType.StartPoint: return StartPointInput.new()
		SubSkillData.SkillInputType.StartAndDir: return StartAndDirInput.new()
	return SkillInput.new()
func start() -> void:
	finished = false
func update(delta: float):
	pass
func interrupt() -> void:
	finished = true
func is_finished() -> bool:
	return finished
