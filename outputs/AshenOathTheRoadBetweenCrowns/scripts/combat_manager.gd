extends Node

signal enemy_hit(name: String, amount: float)
signal impact(position: Vector3, heavy: bool)
signal enemy_killed(name: String)
signal message(text: String)

func resolve_player_attack(player: Node3D, enemies: Array, damage: float, radius: float, heavy: bool, active_oil: String) -> void:
	var forward = -player.global_transform.basis.z.normalized()
	var hit_any = false
	for enemy in enemies:
		if enemy == null or enemy.dead:
			continue
		var offset: Vector3 = enemy.global_position - player.global_position
		var distance = offset.length()
		if distance <= radius + 0.8 and forward.dot(offset.normalized()) > -0.15:
			var source_tag = ""
			if active_oil == "moon_oil":
				source_tag = "spirit"
			elif active_oil == "rot_oil":
				source_tag = "undead"
			enemy.apply_damage(damage, source_tag)
			enemy_hit.emit(enemy.display_name, damage)
			impact.emit(enemy.global_position + Vector3(0, 1.0, 0), heavy)
			hit_any = true
			break
	if not hit_any:
		message.emit("Your blade cuts only mist.")

func throw_bomb(player: Node3D, enemies: Array, damage: float) -> bool:
	var hit = false
	for enemy in enemies:
		if enemy == null or enemy.dead:
			continue
		if enemy.global_position.distance_to(player.global_position) <= 6.0:
			enemy.apply_damage(damage, "ash_bomb")
			impact.emit(enemy.global_position + Vector3(0, 1.0, 0), true)
			hit = true
	if hit:
		message.emit("Ash Bomb bursts hot and white.")
	else:
		message.emit("The bomb scatters ash across empty ground.")
	return hit

func place_trap(player: Node3D, enemies: Array) -> bool:
	for enemy in enemies:
		if enemy == null or enemy.dead:
			continue
		if enemy.global_position.distance_to(player.global_position) <= 4.0:
			enemy.slow(4.0)
			message.emit("%s is caught in the iron trap." % enemy.display_name)
			return true
	message.emit("Trap set, but nothing steps into it.")
	return false
