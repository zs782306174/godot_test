extends Node

class_name CollisionDetection

var battle_units: Array[BattleUnit] = []
var bullets: Array[Bullet] = []

func add_battle_unit(unit: BattleUnit) -> void:
	if unit not in battle_units:
		battle_units.append(unit)

func remove_battle_unit(unit: BattleUnit) -> void:
	if unit in battle_units:
		battle_units.erase(unit)

func add_bullet(bullet: Bullet) -> void:
	if bullet not in bullets:
		bullets.append(bullet)

func remove_bullet(bullet: Bullet) -> void:
	if bullet in bullets:
		bullets.erase(bullet)

func check_collisions() -> void:
	for bullet in bullets:
		if not bullet.is_active:
			continue
		
		for unit in battle_units:
			if not unit.is_alive:
				continue
			
			if bullet.get_owner_id() == unit.unit_data.id:
				continue
			
			if is_colliding(bullet, unit):
				handle_collision(bullet, unit)
				break

func is_colliding(bullet: Bullet, unit: BattleUnit) -> bool:
	var distance = bullet.global_position.distance_to(unit.global_position)
	var collision_threshold = 1.0
	return distance < collision_threshold

func handle_collision(bullet: Bullet, unit: BattleUnit) -> void:
	unit.take_damage(bullet.get_damage())
	bullet.deactivate()
	bullet.emit_signal("bullet_hit", unit)

func update(delta: float) -> void:
	check_collisions()
	
	var expired_bullets: Array[Bullet] = []
	for bullet in bullets:
		if not bullet.is_active:
			expired_bullets.append(bullet)
	
	for bullet in expired_bullets:
		remove_bullet(bullet)
	
	var dead_units: Array[BattleUnit] = []
	for unit in battle_units:
		if not unit.is_alive:
			dead_units.append(unit)
	
	for unit in dead_units:
		remove_battle_unit(unit)

func clear_all() -> void:
	battle_units.clear()
	bullets.clear()
