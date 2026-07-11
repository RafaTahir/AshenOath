extends Node

signal enemy_hit(name: String, amount: float)
signal impact(position: Vector3, heavy: bool)
signal enemy_killed(name: String)
signal message(text: String)

func resolve_player_attack(player: Node3D, enemies: Array, damage: float, radius: float, heavy: bool, active_oil: String) -> void:
	var forward = -player.global_transform.basis.z.normalized()
	var candidates: Array = []
	for enemy in enemies:
		if enemy == null or enemy.dead or (enemy.has_method("is_encounter_active") and not enemy.is_encounter_active()):
			continue
		var offset: Vector3 = enemy.global_position - player.global_position
		var distance = offset.length()
		if distance <= radius+0.55 and offset.length_squared() > 0.01:
			var facing := forward.dot(offset.normalized())
			if facing >= (0.18 if heavy else 0.34) and _has_weapon_line(player,enemy):
				candidates.append({"enemy":enemy,"score":distance-facing*0.65})
	candidates.sort_custom(func(a,b): return float(a.score)<float(b.score))
	if candidates.is_empty():
		message.emit("Your blade cuts only mist.")
		return
	var target = candidates[0].enemy
	var source_tag = ""
	if active_oil == "moon_oil": source_tag = "spirit"
	elif active_oil == "rot_oil": source_tag = "undead"
	target.apply_damage(damage,source_tag)
	enemy_hit.emit(target.display_name,damage)
	impact.emit(target.global_position+Vector3(0,1.0,0),heavy)

func _has_weapon_line(player: Node3D, enemy: Node3D) -> bool:
	var origin := player.global_position+Vector3(0,1.0,0)
	var target := enemy.global_position+Vector3(0,0.9,0)
	var query := PhysicsRayQueryParameters3D.create(origin,target)
	query.exclude = [player.get_rid()]
	query.collide_with_areas = false
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == enemy

func throw_bomb(player: Node3D, enemies: Array, damage: float) -> bool:
	var hit = false
	for enemy in enemies:
		if enemy == null or enemy.dead or (enemy.has_method("is_encounter_active") and not enemy.is_encounter_active()):
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
		if enemy == null or enemy.dead or (enemy.has_method("is_encounter_active") and not enemy.is_encounter_active()):
			continue
		if enemy.global_position.distance_to(player.global_position) <= 4.0:
			enemy.slow(4.0)
			message.emit("%s is caught in the iron trap." % enemy.display_name)
			return true
	message.emit("Trap set, but nothing steps into it.")
	return false

func resolve_energy_beam(player: Node3D, enemies: Array, direction: Vector3, endpoint: Vector3, width: float, damage: float) -> Array:
	var hits: Array = []
	var origin = player.global_position + Vector3(0, 1.05, 0)
	var beam_length = origin.distance_to(endpoint)
	var forward = direction.normalized()
	for enemy in enemies:
		if enemy == null or enemy.dead or (enemy.has_method("is_encounter_active") and not enemy.is_encounter_active()):
			continue
		var target = enemy.global_position + Vector3(0, 0.9, 0)
		var offset: Vector3 = target - origin
		var along = offset.dot(forward)
		if along <= 0.0 or along > beam_length:
			continue
		var nearest = origin + forward * along
		if target.distance_to(nearest) > width:
			continue
		enemy.apply_damage(damage, "oathfire")
		enemy_hit.emit(enemy.display_name, damage)
		impact.emit(target, true)
		hits.append(enemy)
	message.emit("Oathfire tears through %d foe%s." % [hits.size(), "" if hits.size() == 1 else "s"] if not hits.is_empty() else "Oathfire burns into the mist.")
	return hits
