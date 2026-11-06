extends Node

const BodyQuery = preload("res://scripts/combat_body_query.gd")

var _query_scratch = preload("res://scripts/physics_query_scratch.gd").new()

signal enemy_hit(name: String, amount: float)
signal impact(position: Vector3, heavy: bool)
signal enemy_killed(name: String)
signal message(text: String)
signal contact_resolved(result: Dictionary)
signal contact_missed(result: Dictionary)

var _blade_owner_id := 0
var _blade_attack_id := -1
var _blade_hit_ids: Dictionary = {}
var _device_host: WeakRef
var _deployed_devices: Dictionary = {}
var _device_serial := 0
var _stone_ready_at := 0.0

func save_devices() -> Dictionary:
	return {"serial": _device_serial, "zones": _deployed_devices.duplicate(true), "stone_ready_at":_stone_ready_at}

func load_devices(value: Dictionary) -> void:
	_device_serial = maxi(0, int(value.get("serial", 0)))
	_stone_ready_at = maxf(0.0, float(value.get("stone_ready_at", 0.0)))
	if not is_finite(_stone_ready_at): _stone_ready_at = 0.0
	_deployed_devices.clear()
	var zones: Variant = value.get("zones", {})
	if not zones is Dictionary: return
	var seen: Dictionary = {}
	for zone: String in zones:
		if not zones[zone] is Array: continue
		var retained: Array = []
		for record: Variant in zones[zone]:
			if not record is Dictionary or str(record.get("kind", "")) != "trap": continue
			var position: Variant = record.get("position")
			if not position is Array or position.size() != 3: continue
			var valid := true
			for component in position:
				if not (component is float or component is int) or not is_finite(float(component)): valid = false
			var id := str(record.get("id", ""))
			var saved_yaw: Variant = record.get("yaw", 0.0)
			if not (saved_yaw is float or saved_yaw is int): continue
			var yaw := float(saved_yaw)
			if valid and is_finite(yaw) and id.is_valid_int() and int(id) > 0 and not seen.has(id) and retained.size() < 3:
				retained.append({"id": id, "kind": "trap", "position": position.duplicate(), "yaw": yaw})
				seen[id] = true
				_device_serial = maxi(_device_serial, int(id))
		_deployed_devices[zone] = retained

func activate_devices(host: Node) -> void:
	_device_host = weakref(host)
	var previous := host.zone_root.get_node_or_null("FieldDevices")
	if previous != null:
		host.zone_root.remove_child(previous)
		previous.queue_free()
	var root := Node3D.new()
	root.name = "FieldDevices"
	host.zone_root.add_child(root)
	for record: Dictionary in _deployed_devices.get(str(host.current_zone_id), []):
		var device := preload("res://scripts/field_device.gd").new()
		device.manager = weakref(self)
		device.zone = str(host.current_zone_id)
		device.device_id = str(record.id)
		root.add_child(device)
		device.position = Vector3(record.position[0], record.position[1], record.position[2])
		device.rotation.y = float(record.get("yaw", 0.0))
		# Keep unsupported legacy placements dormant; never move or refund them.
		device.set_meta("support_pending", true)

func device_can_tick(device: Node3D) -> bool:
	var host := _device_game()
	return host != null and str(device.zone) == str(host.current_zone_id) and device.get_parent().get_parent() == host.zone_root \
		and host.game_started and not host.zone_transition_pending and not host.get_tree().paused \
		and is_instance_valid(host.player) and host.player.can_control

func device_exclusions() -> Array[RID]:
	var host := _device_game()
	var excluded: Array[RID] = []
	if host != null and is_instance_valid(host.player): excluded.append(host.player.get_rid())
	return excluded

func _device_game() -> Node:
	return _device_host.get_ref() as Node if _device_host != null else null

func deploy_tool(host: Node, item_id: String, damage: float = 45.0) -> Dictionary:
	if item_id not in ["ash_bomb", "iron_trap", "loose_stone"]: return {"ok":false, "message":"That is not a field tool."}
	if host.get_tree().paused or not host.player.can_control or host.zone_transition_pending or not host.input_router.is_gameplay_context():
		return {"ok": false, "message": "Return to the road before using a field tool."}
	var player: Node3D = host.player
	if item_id == "loose_stone" and host.day_night.active_play_seconds < _stone_ready_at:
		return {"ok":false, "message":"Let the last sound settle before throwing another stone."}
	var aim: Dictionary = player.field_tool_aim()
	if bool(aim.get("blocked", false)):
		return {"ok": false, "message": "The tool needs clearance. Nothing was used."}
	var position: Vector3 = aim.origin
	var records: Array = _deployed_devices.get(str(host.current_zone_id), [])
	if item_id == "iron_trap":
		if records.size() >= 3:
			return {"ok": false, "message": "Three traps are already armed here. Nothing was used."}
		var ahead: Vector3 = player.global_position - player.global_basis.z * 1.25
		var query := PhysicsRayQueryParameters3D.create(ahead + Vector3.UP * 0.7, ahead - Vector3.UP * 0.8, 1)
		query.exclude = [player.get_rid()]
		query.collide_with_areas = false
		var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.normal.dot(Vector3.UP) < 0.85 or hit.collider is CharacterBody3D:
			return {"ok": false, "message": "Find clear, level ground for the trap. Nothing was used."}
		position = hit.position + Vector3.UP * 0.015
		var space := PhysicsShapeQueryParameters3D.new()
		var clearance := BoxShape3D.new()
		clearance.size = Vector3(0.55, 0.22, 0.55)
		space.shape = clearance
		space.transform.origin = position + Vector3.UP * 0.16
		space.collision_mask = 1
		space.exclude = [player.get_rid()]
		if not player.get_world_3d().direct_space_state.intersect_shape(space, 1).is_empty():
			return {"ok": false, "message": "The trap would overlap an obstacle. Nothing was used."}
		for record: Dictionary in records:
			if position.distance_to(host.zone_root.to_global(Vector3(record.position[0], record.position[1], record.position[2]))) < 0.8:
				return {"ok": false, "message": "Leave space between traps. Nothing was used."}
	if not host.inventory.consume(item_id): return {"ok": false, "message": "No field tool remains."}
	if _device_game() != host or host.zone_root.get_node_or_null("FieldDevices") == null: activate_devices(host)
	var device := preload("res://scripts/field_device.gd").new()
	device.manager = weakref(self)
	device.zone = str(host.current_zone_id)
	device.kind = "trap" if item_id == "iron_trap" else ("stone" if item_id == "loose_stone" else "bomb")
	_device_serial += 1
	device.device_id = str(_device_serial)
	device.set_meta("damage", damage)
	host.zone_root.get_node("FieldDevices").add_child(device)
	device.global_position = position
	device.rotation.y = player.rotation.y
	if device.kind in ["bomb", "stone"]:
		device.velocity = (aim.direction as Vector3) * 13.0 + Vector3.UP * 2.4
		if device.kind == "stone": _stone_ready_at = host.day_night.active_play_seconds + 8.0
	else:
		var local: Vector3 = host.zone_root.to_local(position)
		records.append({"id": device.device_id, "kind": "trap", "position": [local.x, local.y, local.z], "yaw": device.rotation.y})
		_deployed_devices[str(host.current_zone_id)] = records
	return {"ok": true, "message": "Iron Trap armed." if device.kind == "trap" else ("Stone thrown." if device.kind == "stone" else "Ash Bomb thrown.")}

func try_trigger_trap(device: Node3D) -> void:
	if not device_can_tick(device) or device.consumed: return
	var host := _device_game()
	if bool(device.get_meta("support_pending", false)):
		var support_query := PhysicsRayQueryParameters3D.create(device.global_position + Vector3.UP * 0.15, device.global_position - Vector3.UP * 0.2, 1)
		support_query.exclude = device_exclusions()
		var support := device.get_world_3d().direct_space_state.intersect_ray(support_query)
		if support.is_empty() or support.normal.dot(Vector3.UP) < 0.85 or support.collider is CharacterBody3D: return
		device.set_meta("support_pending", false)
	for enemy in host.active_enemies:
		if not is_instance_valid(enemy) or enemy.dead or (enemy.has_method("is_encounter_active") and not enemy.is_encounter_active()): continue
		if enemy.global_position.distance_to(device.global_position) > 0.8: continue
		var query := PhysicsRayQueryParameters3D.create(device.global_position + Vector3.UP * 0.15, enemy.global_position + Vector3.UP * 0.25, 1)
		query.exclude = device_exclusions()
		var obstruction := device.get_world_3d().direct_space_state.intersect_ray(query)
		if not obstruction.is_empty() and obstruction.collider != enemy and not enemy.is_ancestor_of(obstruction.collider): continue
		device.consumed = true
		var records: Array = _deployed_devices.get(device.zone, [])
		for index in range(records.size() - 1, -1, -1):
			if str(records[index].id) == device.device_id: records.remove_at(index)
		enemy.slow(4.0)
		host.audio.play_spatial_event("block", device.global_position, host.player.global_position, 14.0, 0.0, 0.0)
		message.emit("%s is caught in the iron trap." % enemy.display_name)
		host.story_save_pending = true
		host.call_deferred("_persist_story_action")
		device.queue_free()
		return

func explode_device(device: Node3D) -> void:
	if not device_can_tick(device): device.queue_free(); return
	var host := _device_game()
	var center := device.global_position
	if device.kind == "stone":
		# Only the existing sound-perception path hears a harmless landing.
		host.audio.play_spatial_event("stone_contact", center, host.player.global_position, 12.0, 0.0, 0.0)
		host.audio.perception_cue.emit(center, 9.0, false)
		device.queue_free()
		return
	var targets: Array = []
	for enemy in host.active_enemies:
		if not is_instance_valid(enemy) or enemy.dead or (enemy.has_method("is_encounter_active") and not enemy.is_encounter_active()): continue
		if enemy.global_position.distance_to(center) > 6.0: continue
		var query := PhysicsRayQueryParameters3D.create(center, BodyQuery.aim_point_for(enemy), 1)
		query.exclude = device_exclusions()
		query.collide_with_areas = false
		var wall := device.get_world_3d().direct_space_state.intersect_ray(query)
		if not wall.is_empty() and wall.collider != enemy and not enemy.is_ancestor_of(wall.collider): continue
		targets.append(enemy)
	for enemy in targets:
		enemy.apply_damage(float(device.get_meta("damage", 45.0)), "ash_bomb")
		impact.emit(enemy.global_position + Vector3.UP, true)
		if is_instance_valid(enemy) and not enemy.dead and str(enemy.enemy_id) == "bog_wretch": host._expose_bog_core(enemy, "Ash Bomb")
	for person: Node3D in host._civilian_contact_candidates(center, 6.0):
		var sight := PhysicsRayQueryParameters3D.create(center, BodyQuery.aim_point_for(person), 1)
		sight.exclude = device_exclusions()
		sight.collide_with_areas = false
		var wall := device.get_world_3d().direct_space_state.intersect_ray(sight)
		if not wall.is_empty() and wall.collider != person and not person.is_ancestor_of(wall.collider): continue
		var response: Callable = person.get_meta("civilian_contact", Callable())
		if response.is_valid(): response.call({"source_tag": "ash_bomb", "point": center, "damage": 0.0})
	host.audio.play_spatial_event("bomb", center, host.player.global_position, 24.0, 0.0, 0.0)
	preload("res://scripts/combat_feedback.gd").impact_burst(host.zone_root, center, true, Color(0.68, 0.48, 0.25))
	if center.distance_to(host.player.global_position) < 10.0 and host.camera_rig != null: host.camera_rig.shake(0.12)
	device.queue_free()

func resolve_player_blade_contact(player: Node3D, enemies: Array, contact: Dictionary, active_oil: String, civilians: Array = []) -> Dictionary:
	if not is_instance_valid(player) or not player.has_method("is_blade_ready") or not player.is_blade_ready():
		return {"hit": false, "reason": "blade_not_ready"}
	var attack_id := int(contact.get("attack_id", -1))
	var owner_id := player.get_instance_id()
	if owner_id != _blade_owner_id:
		_blade_owner_id = owner_id
		_blade_attack_id = -1
		_blade_hit_ids.clear()
	if attack_id < 0 or attack_id < _blade_attack_id or float(contact.get("damage", 0.0)) <= 0.0:
		return {"hit": false, "reason": "expired_contact"}
	if attack_id != _blade_attack_id:
		_blade_attack_id = attack_id
		_blade_hit_ids.clear()
	var blade_id := EquipmentLoadout.normalized_blade_id(str(player.get_selected_blade_id()))
	if str(contact.get("blade_id", blade_id)) != blade_id:
		return {"hit": false, "reason": "stale_blade"}
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
	for enemy in enemies + civilians:
		if not is_instance_valid(enemy) or enemy.get("dead") == true or _blade_hit_ids.has(enemy.get_instance_id()) or bool(enemy.get_meta("story_surrender_protected", false)) or (enemy.has_method("is_encounter_active") and not enemy.is_encounter_active()):
			continue
		var cylinder := BodyQuery.cylinder_for(enemy)
		var target: Vector3 = cylinder.global_position if cylinder != null else enemy.global_position + Vector3(0, 0.9, 0)
		if target.distance_to(player.global_position + Vector3(0, 0.9, 0)) > reach + 0.85:
			continue
		var closest := blade_tip
		var contact_distance := INF
		if cylinder != null:
			var hit := BodyQuery.sweep_hit(cylinder, previous_base, previous_tip, blade_base, blade_tip, 0.78 if heavy else 0.66)
			if not hit.is_empty():
				contact_distance = float(hit.distance)
				closest = hit.body_point
		else:
			for height in [0.35, 0.72, 1.08, 1.42]:
				var body_point: Vector3 = enemy.global_position + Vector3(0, height, 0)
				var candidate := _closest_sweep_point(body_point, previous_base, previous_tip, blade_base, blade_tip)
				var candidate_distance: float = body_point.distance_to(candidate)
				if candidate_distance < contact_distance:
					contact_distance = candidate_distance
					closest = candidate
		if contact_distance <= (0.78 if heavy else 0.66) and _has_contact_line(player, enemy, closest):
			candidates.append({"enemy": enemy, "point": closest, "contact_distance": contact_distance, "score": contact_distance + player.global_position.distance_to(target) * 0.08})
	candidates.sort_custom(func(a, b): return float(a.score) < float(b.score))
	if candidates.is_empty():
		var environment := _resolve_environment_contact(player, contact, enemies + civilians)
		if not environment.is_empty(): return environment
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
		if bool(contact.get("final_sample", true)) and _blade_hit_ids.is_empty():
			contact_missed.emit(miss)
		return miss
	var resolved: Dictionary = candidates[0]
	var struck_enemy: Node = resolved.enemy
	var civilian: bool = struck_enemy.has_meta("civilian_contact")
	var source_tag := ""
	if active_oil == "moon_oil":
		source_tag = "spirit"
	elif active_oil == "rot_oil":
		source_tag = "undead"
	var affinity := 1.0 if civilian else EquipmentLoadout.blade_damage_multiplier(blade_id, str(struck_enemy.get("tag")))
	damage *= affinity
	# Reserve before damage: death/phase signals can re-enter the resolver.
	_blade_hit_ids[struck_enemy.get_instance_id()] = true
	if not civilian:
		struck_enemy.apply_damage(damage, source_tag)
		enemy_hit.emit(struck_enemy.display_name, damage)
	var hit_result := {
		"hit": true,
		"enemy": null if civilian else struck_enemy,
		"actor": struck_enemy,
		"kind": "civilian" if civilian else "enemy",
		"surface": _actor_surface(struck_enemy),
		"direction": (blade_tip - previous_tip).normalized(),
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
		"blade_id": blade_id,
		"affinity_multiplier": affinity,
		"contact_distance": float(resolved.get("contact_distance", INF)),
		"blade_contact_distance": float(resolved.get("contact_distance", INF)),
		"contact_phase": contact_phase,
		"sweep_length": sweep_length,
		"blade_direction": blade_direction,
	}
	if civilian:
		var reaction: Callable = struck_enemy.get_meta("civilian_contact")
		if reaction.is_valid(): reaction.call(hit_result)
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
	var query: PhysicsRayQueryParameters3D = _query_scratch.ray(origin, contact_point, 1)
	query.exclude = [player.get_rid()]
	query.collide_with_areas = false
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == enemy or enemy.is_ancestor_of(hit.get("collider"))

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
		var cylinder := BodyQuery.cylinder_for(enemy)
		var target: Vector3
		if cylinder != null:
			var hit := BodyQuery.cast_hit(cylinder, origin, endpoint, width)
			if hit.is_empty():
				continue
			target = hit.body_point
		else:
			var body := _body_segment(enemy)
			var points := Geometry3D.get_closest_points_between_segments(origin, endpoint, body.start, body.end)
			target = points[1]
			var offset: Vector3 = target - origin
			var along = offset.dot(forward)
			if along <= 0.0 or along > beam_length:
				continue
			var nearest = origin + forward * along
			if target.distance_to(nearest) > width + float(body.radius):
				continue
		enemy.apply_damage(damage, "oathfire")
		enemy_hit.emit(enemy.display_name, damage)
		impact.emit(target, true)
		hits.append(enemy)
	message.emit("Oathfire tears through %d foe%s." % [hits.size(), "" if hits.size() == 1 else "s"] if not hits.is_empty() else "Oathfire burns into the mist.")
	return hits

func resolve_arrow_shot(enemies: Array, cast: Dictionary) -> Dictionary:
	var origin: Vector3 = cast.get("origin", Vector3.ZERO)
	var endpoint: Vector3 = cast.get("endpoint", origin)
	var direction: Vector3 = cast.get("direction", endpoint - origin)
	var width := float(cast.get("width", 0.34))
	var damage := float(cast.get("damage", 28.0))
	var forward := direction.normalized()
	var length := origin.distance_to(endpoint)
	var best_enemy: Node = null
	var best_along := INF
	var best_point := endpoint
	if length <= 0.05 or forward.length_squared() < 0.5:
		return {"hit": false, "endpoint": endpoint, "enemy": null, "point": endpoint}
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.get("dead") == true or (enemy.has_method("is_encounter_active") and not enemy.is_encounter_active()):
			continue
		var cylinder := BodyQuery.cylinder_for(enemy)
		var target: Vector3
		var along: float
		if cylinder != null:
			var hit := BodyQuery.cast_hit(cylinder, origin, endpoint, width)
			if hit.is_empty():
				continue
			target = hit.body_point
			along = float(hit.along)
			if along >= best_along:
				continue
		else:
			var body := _body_segment(enemy)
			var points := Geometry3D.get_closest_points_between_segments(origin, endpoint, body.start, body.end)
			target = points[1]
			var offset := target - origin
			along = offset.dot(forward)
			if along <= 0.0 or along > length or along >= best_along:
				continue
			var nearest := origin + forward * along
			if target.distance_to(nearest) > width + float(body.radius):
				continue
		best_enemy = enemy
		best_along = along
		best_point = target
	if best_enemy == null:
		if bool(cast.get("report_miss", true)):
			message.emit("The arrow disappears into the dark.")
		return {"hit": false, "endpoint": endpoint, "enemy": null, "point": endpoint}
	var civilian := best_enemy.has_meta("civilian_contact")
	var result := {"hit":true,"endpoint":endpoint,"enemy":null if civilian else best_enemy,"actor":best_enemy,"point":best_point,"damage":damage,"surface":_actor_surface(best_enemy),"kind":"civilian" if civilian else "enemy","direction":forward,"source_tag":str(cast.get("source_tag", "arrow"))}
	if civilian:
		var reaction: Callable = best_enemy.get_meta("civilian_contact")
		if reaction.is_valid(): reaction.call(result)
	else:
		best_enemy.apply_damage(damage, str(cast.get("source_tag", "arrow")))
		enemy_hit.emit(best_enemy.display_name, damage)
	return result

func _actor_surface(actor: Node) -> String:
	if actor.has_meta("civilian_contact"): return "flesh"
	if str(actor.get("enemy_id")) == "rootbound_colossus": return "wood"
	return "spirit" if str(actor.get("tag")) == "spirit" else "flesh"

func environment_contact(hit: Dictionary) -> Dictionary:
	var collider: Node = hit.get("collider") as Node
	var surface := "stone"
	var cursor := collider
	while is_instance_valid(cursor):
		var explicit := str(cursor.get_meta("impact_surface", ""))
		if explicit in ["wood", "foliage", "metal", "stone"]:
			surface = explicit
			break
		var label := str(cursor.name).to_lower()
		if ["tree", "trunk", "timber", "door", "fence", "wood"].any(func(word): return label.contains(word)):
			surface = "wood"
		elif ["anvil", "metal", "iron"].any(func(word): return label.contains(word)):
			surface = "metal"
		elif ["bush", "leaf", "foliage"].any(func(word): return label.contains(word)):
			surface = "foliage"
		cursor = cursor.get_parent()
	return {"hit":true,"kind":"scenery","enemy":null,"surface":surface,"point":hit.get("position",Vector3.ZERO),"contact_point":hit.get("position",Vector3.ZERO),"normal":hit.get("normal",Vector3.UP)}

func foot_surface(player: Node3D, fallback: String) -> String:
	var query := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP * 0.18, player.global_position - Vector3.UP * 0.45, 1)
	query.exclude = [player.get_rid()]
	query.collide_with_areas = false
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	var node: Node = hit.get("collider")
	while is_instance_valid(node):
		var authored := str(node.get_meta("footstep_surface", node.get_meta("impact_surface", "")))
		if authored in ["wood", "stone", "forest", "mud", "road"]: return authored
		var label := str(node.name).to_lower()
		if ["bridge", "plank", "board", "timber"].any(func(word): return label.contains(word)): return "wood"
		if ["cobble", "masonry", "stonefloor", "stairs"].any(func(word): return label.contains(word)): return "stone"
		node = node.get_parent()
	return fallback

func _resolve_environment_contact(player: Node3D, contact: Dictionary, actors: Array) -> Dictionary:
	var base: Vector3 = contact.get("base", player.global_position)
	var tip: Vector3 = contact.get("tip", base)
	var previous: Vector3 = contact.get("previous_tip", tip)
	for segment: Array in [[previous, tip], [base, tip]]:
		if (segment[1] as Vector3).distance_squared_to(segment[0]) < 0.0001: continue
		var query := PhysicsRayQueryParameters3D.create(segment[0], segment[1], 1)
		query.exclude = [player.get_rid()]
		query.collide_with_areas = false
		var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty(): continue
		var collider: Node = hit.get("collider") as Node
		if collider == null: continue
		var actor_hit := false
		for actor in actors:
			if is_instance_valid(actor) and (collider == actor or actor.is_ancestor_of(collider)):
				actor_hit = true
				break
		if actor_hit: continue
		var key := "surface:" + str(collider.get_instance_id())
		if _blade_hit_ids.has(key): continue
		_blade_hit_ids[key] = true
		var result := environment_contact(hit)
		result.merge({"blade_base":base,"blade_tip":tip,"previous_base":contact.get("previous_base",base),"previous_tip":previous,"heavy":bool(contact.get("heavy",false)),"attack_id":contact.get("attack_id",-1),"direction":(tip-previous).normalized()},true)
		contact_resolved.emit(result)
		return result
	return {}

func _body_segment(enemy: Node3D) -> Dictionary:
	for raw in enemy.get_children():
		if raw is CollisionShape3D and raw.shape is CapsuleShape3D:
			var capsule: CapsuleShape3D = raw.shape
			var extent := maxf(0.0, capsule.height * 0.5 - capsule.radius)
			var scale: Vector3 = raw.global_basis.get_scale()
			return {"start": raw.global_transform * Vector3(0, -extent, 0), "end": raw.global_transform * Vector3(0, extent, 0), "radius": capsule.radius * maxf(absf(scale.x), absf(scale.z))}
	var point := enemy.global_position + Vector3.UP * 0.92
	return {"start": point, "end": point, "radius": 0.0}
