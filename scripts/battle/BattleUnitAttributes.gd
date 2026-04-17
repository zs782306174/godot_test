   
class_name BattleUnitAttributes

enum AttributeID{
	BASE_HP = 0,
	ADDITION_HP = 1,
	MUL_HP = 2,
	CURRENT_HP = 3,
	MAX_HP = 4,

	BASE_MP = 5,
	ADDITION_MP = 6,
	MUL_MP = 7,
	CURRENT_MP = 8,
	MAX_MP = 9,

	BASE_ATK = 10,
	ADDITION_ATK = 11,
	MUL_ATK = 12,
	CURRENT_ATK = 13,

	BASE_SPEED = 15,
	ADDITION_SPEED = 16,
	MUL_SPEED = 17,
	CURRENT_SPEED = 18,
	
	BASE_ATTACK_RANGE = 20,
	ADDITION_ATTACK_RANGE = 21,
	MUL_ATTACK_RANGE = 22,
	CURRENT_ATTACK_RANGE = 23,

	ID = 25,
	DESCRIPTION = 26,
	ATTACK_TYPE = 27,
	SKILL1_ID = 28,
	SKILL2_ID = 29,
	SKILL3_ID = 30,
	SKILL4_ID = 31,
}
	

enum AttackType{
	 DIRECT = 0,
	COLLISION = 1
}

var attribute_map: Dictionary[AttributeID, Variant] = {}

func init_attribute(data: BattleUnitData) -> void:
	for key in AttributeID:
		var value = data[key] || 0
		var base_id = AttributeID[key]
		attribute_map[base_id] = value
		if base_id <= AttributeID.BASE_ATTACK_RANGE:
			var add_id = base_id + 1
			var mul_id = base_id + 2
			var current_id = base_id + 3
			var max_id = base_id + 4
			attribute_map[add_id] = 0
			attribute_map[mul_id] = 0
			attribute_map[current_id] = value
			if base_id <= AttributeID.BASE_MP:
				attribute_map[max_id] = value
		
	

func set_attribute(attr_id: AttributeID, value: Variant) -> void:
	attribute_map[attr_id] = value
	calculate_attribute(attr_id)

func get_attribute(attr_id: AttributeID) -> Variant:
	return attribute_map[attr_id]

func calculate_attribute(attr_id: AttributeID) -> void:
	var base_id = attr_id / 5;
	var add_id = base_id + 1
	var mul_id = base_id + 2
	var current_id = base_id + 3
	var max_id = base_id + 4

	if base_id <= AttributeID.BASE_MP:
		var before_current_value = attribute_map[current_id]
		attribute_map[max_id] = (attribute_map[base_id] + attribute_map[add_id]) * attribute_map[mul_id]
		if attribute_map[max_id] <= before_current_value:
			attribute_map[current_id] = attribute_map[max_id]
	else:
		attribute_map[current_id] = (attribute_map[base_id] + attribute_map[add_id]) * attribute_map[mul_id]
