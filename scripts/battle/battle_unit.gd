extends Node3D

class_name BattleUnit
@export var shape: Shape3D
func init(args):
	pass

func trigger_enter(other: BattleUnit):
	pass

func trigger_stay(other: BattleUnit):
	pass

func trigger_exit(other: BattleUnit):
	pass

func dispose():
	pass
