extends Node

class_name BuffManager

var active_buffs: Array[Buff] = []

func add_buff(buff: Buff) -> void:
	active_buffs.append(buff)

func remove_buff(buff: Buff) -> void:
	if buff in active_buffs:
		active_buffs.erase(buff)

func update(delta: float) -> void:
	var expired_buffs: Array[Buff] = []
	
	for buff in active_buffs:
		buff.update(delta)
		if buff.is_expired():
			expired_buffs.append(buff)
	
	for buff in expired_buffs:
		remove_buff(buff)

func has_buff(buff_id: int) -> bool:
	for buff in active_buffs:
		if buff.buff_data.id == buff_id:
			return true
	return false

func get_buff(buff_id: int) -> Buff:
	for buff in active_buffs:
		if buff.buff_data.id == buff_id:
			return buff
	return null

func clear_all_buffs() -> void:
	active_buffs.clear()
