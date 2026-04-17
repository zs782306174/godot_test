
class_name Buff

var buff_data: BuffData
var remaining_time: float

func _init(data: BuffData):
	buff_data = data
	remaining_time = data.duration

func update(delta: float) -> bool:
	remaining_time -= delta
	return remaining_time <= 0.0

func is_expired() -> bool:
	return remaining_time <= 0.0

func get_remaining_time() -> float:
	return remaining_time
