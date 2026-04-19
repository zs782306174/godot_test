class_name SubSkill
var data: SubSkillData
var input: SkillInput
var finished: bool = false
func _init(_data: SubSkillData):
	data = _data
	input = SkillInput.new()
func start() -> void:
	finished = false
func update(delta: float):
	pass
func interrupt() -> void:
	finished = true
func is_finished() -> bool:
	return finished
