extends Node

signal enemy_hit(name: String, amount: float)
signal impact(position: Vector3, heavy: bool)
signal enemy_killed(name: String)
signal message(text: String)
signal contact_resolved(result: Dictionary)
signal contact_missed(result: Dictionary)

func resolve_player_blade_contact(player: Node3D, enemies: Array, contact: Dictionary, active_oil: String) -> Dictionary:
	var blade_base: Vector3 = contact.get("base", Vector3.ZERO)
	var blade_tip: Vector3 = contact.get("tip", blade_base)
	var previous_base: Vector3 = contact.get("previous_base", blade_base)
	var previous_tip: Vector3 = contact.get("previous_tip", blade_tip)
	var reach := float(contact.get("reach", 2.0))
	var heavy := bool(contact.get("heavy", false))
	var damage := float(contact.get("damage", 0.0))
	var contact_phase := float(contact.get("contact_phase", 0.0))
	var sweep_length := maxf(previous_tip.distance_to(blade_tip), previous_base.distance_to(blade_base))
	var blade_direction := (blade_tip - blade_base).normalized() if blade_tip.distance_to(blade_base) > 0.001 else Vector3.ZERO
	var candidates: Array = []
	for enemy in enemies:
		if enemy == null or enemy.dead or (enemy.has_method("is_encounter_active") and not enemy.is_encounter_active()):
			continue
		var target: Vector3 = enemy.global_position + Vector3(0, 0.9, 0)
		if target.distance_to(player.global_position + Vector3(0, 0.9, 0)) > reach + 0.85:
			continue
		var closest := blade_tip
		var contact_distance := INF
		for height in [0.35, 0.72, 1.08, 1.42]:
			var body_point: Vector3 = enemy.global_position + Vector3(0, height, 0)
			var candidate := _closest_sweep_point(body_point, previous_base, previous_tip, blade_base, blade_tip)
			var candidate_distance: float = body_point.distance_to(candidate)
			if candidate_distance < contact_distance:
				contact_distance = candidate_distance
				closest = candidate
		if contact_distance <= (0.78 if heavy else 0.66) and _has_contact_line(player, enemy, closest):
			candidates.append({"enemy": enemy, "point": closest, "score": contact_distance + player.global_position.distance_to(target) * 0.08})
	candidates.sort_custom(func(a, b): return float(a.score) < float(b.score))
	if candidates.is_empty():
		message.emit("Your blade cuts only mist.")
		var miss := {
			"hit": false,
			"point": blade_tip,
			"contact_point": blade_tip,
			"blade_base": blade_base,
			"blade_tip": blade_tip,
			"previous_base": previous_base,
			"previous_tip": previous_tip,
			"heavy": heavy,
			"damage": damage,
			"attack_id": str(contact.get("attack_id", "")),
			"source_tag": active_oil,
			"contact_distance": INF,
			"blade_contact_distance": INF,
			"contact_phase": contact_phase,
			"sweep_length": sweep_length,
			"blade_direction": blade_direction,
		}
		contact_missed.emit(miss)
		return miss
	var resolved: Dictionary = candidates[0]
	var struck_enemy: Node = resolved.enemy
	var source_tag := ""
	if active_oil == "moon_oil":
		source_tag = "spirit"
	elif active_oil == "rot_oil":
		source_tag = "undead"
	struck_enemy.apply_damage(damage, source_tag)
	enemy_hit.emit(struck_enemy.display_name, damage)
	impact.emit(resolved.point, heavy)
	var hit_result := {
		"hit": true,
		"enemy": struck_enemy,
		"point": resolved.point,
		"contact_point": resolved.point,
		"blade_base": blade_base,
		"blade_tip": blade_tip,
		"previous_base": previous_base,
		"previous_tip": previous_tip,
		"heavy": heavy,
		"damage": damage,
		"attack_id": str(contact.get("attack_id", "")),
		"source_tag": source_tag,
		"contact_distance": float(resolved.score),
		"blade_contact_distance": float(resolved.get("contact_distance", INF)),
		"contact_phase": contact_phase,
		"sweep_length": sweep_length,
		"blade_direction": blade_direction,
	}
	contact_resolved.emit(hit_result)
	return hit_result

func _closest_sweep_point(point: Vector3, previous_base: Vector3, previous_tip: Vector3, blade_base: Vector3, blade_tip: Vector3) -> Vector3:
	var segments := [
		[previous_base, previous_tip], [blade_base, blade_tip],
		[previous_base, blade_base], [previous_tip, blade_tip],
		[previous_base, blade_tip], [previous_tip, blade_base]
	]
	var closest := blade_tip
	var best_distance := INF
	for segment in segments:
		var candidate := _closest_point_on_segment(point, segment[0], segment[1])
		var distance := point.distance_squared_to(candidate)
		if distance < best_distance:
			best_distance = distance
			closest = candidate
	return closest

func _closest_point_on_segment(point: Vector3, start: Vector3, finish: Vector3) -> Vector3:
	var segment := finish - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.000001:
		return start
	return start + segment * clamp((point - start).dot(segment) / length_squared, 0.0, 1.0)

func _has_contact_line(player: Node3D, enemy: Node3D, contact_point: Vector3) -> bool:
	var origin := player.global_position + Vector3(0, 1.0, 0)
	var query := PhysicsRayQueryParameters3D.create(origin, contact_point)
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
	var origin: Vector3 = player.global_position + Vector3(0, 1.05, 0)
	return resolve_oathfire_cast(enemies, {
		"origin": origin,
		"direction": direction,
		"endpoint": endpoint,
		"width": width,
		"damage": damage
	})

func resolve_oathfire_cast(enemies: Array, cast: Dictionary) -> Array:
	var hits: Array = []
	var origin: Vector3 = cast.get("origin", Vector3.ZERO)
	var endpoint: Vector3 = cast.get("endpoint", origin)
	var direction: Vector3 = cast.get("direction", endpoint - origin)
	var width: float = float(cast.get("width", 1.2))
	var damage: float = float(cast.get("damage", 35.0))
	var beam_length: float = origin.distance_to(endpoint)
	var forward: Vector3 = direction.normalized()
	if beam_length <= 0.05 or forward.length_squared() < 0.5:
		return hits
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
