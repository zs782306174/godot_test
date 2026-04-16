extends Node3D

class_name BattleUnit

var attribute: BattleUnitAttributes




func _init(data:BattleUnitData):
	attribute.init_attributes(data)
	global_position = position



func update(delta: float) -> void:
	pass
