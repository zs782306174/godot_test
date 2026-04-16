extends Resource

class_name AchievementData

enum Status {
	LOCKED,
	IN_PROGRESS,
	COMPLETED
}

@export var id: int
@export var name: String
@export var desc: String
@export var reward: int
@export var status: Status = Status.LOCKED

func _init(p_id: int = 0, p_name: String = "", p_desc: String = "", p_reward: int = 0, p_status: Status = Status.LOCKED):
	id = p_id
	name = p_name
	desc = p_desc
	reward = p_reward
	status = p_status
