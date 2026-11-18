extends RefCounted
## enemy navigation view: scene-only responsibilities.
const FINAL_ROUTE_STOP_SQUARED := 0.002
# Reach the decision ring before the route's existing ~0.045 m stop tolerance.
const READY_APPROACH_MARGIN := 0.05

var _actor: CharacterBody3D

func _init(actor: CharacterBody3D) -> void:
	_actor = actor

func setup_navigation(service: Variant) -> void:
	_actor.spatial_service = service
	if _actor.navigation_agent == null:
		_actor.navigation_agent = NavigationAgent3D.new()
		_actor.navigation_agent.name = "NavigationAgent3D"
		_actor.navigation_agent.path_desired_distance = 0.28
		_actor.navigation_agent.target_desired_distance = 0.28
		_actor.navigation_agent.radius = 0.44
		_actor.navigation_agent.height = 1.75
		_actor.add_child(_actor.navigation_agent)
	_actor.navigation_agent.process_mode = Node.PROCESS_MODE_DISABLED
	var map_rid: RID = _actor.spatial_service.get_navigation_map() if _actor.spatial_service != null else RID()
	if map_rid.is_valid():
		_actor.navigation_agent.set_navigation_map(map_rid)
	_actor.navigation_route.clear()
	_actor.navigation_route_index = 0
	_actor.navigation_refresh_time = 0.0
	_actor.navigation_target = Vector3.INF

func set_encounter_peers(peers: Array, spatial_index: Variant = null) -> void:
	_actor.encounter_peers = peers
	_actor.encounter_spatial_index = spatial_index
	if not _actor._decision_phase_applied:
		_actor._decision_phase_applied = true
		var phase: Variant = float(absi((_actor.enemy_id + str(_actor.encounter_slot)).hash()) % 1000) / 1000.0
		_actor.perception_refresh_time = phase * 0.18
		_actor.navigation_refresh_time = phase * 0.35

func _navigation_direction(target: Vector3, force_refresh: bool = false) -> Vector3:
	if _actor.spatial_service == null or _actor.navigation_agent == null:
		return Vector3.ZERO
	var target_changed: Variant = _actor.navigation_target == Vector3.INF or _actor.navigation_target.distance_squared_to(target) > 1.56
	if force_refresh or target_changed or _actor.navigation_refresh_time <= 0.0 or _actor.navigation_route.is_empty():
		_actor.navigation_route = _actor.spatial_service.build_route(_actor.global_position, target, 0.62, _actor)
		_actor.navigation_route_index = 1 if _actor.navigation_route.size() > 1 else 0
		_actor.navigation_target = target
		_actor.navigation_refresh_time = 0.35
	if _actor.navigation_route.is_empty():
		return Vector3.ZERO
	var route_target: Variant = _actor.navigation_route[_actor.navigation_route_index]
	if _actor.global_position.distance_to(route_target) < 0.38 and _actor.navigation_route_index + 1 < _actor.navigation_route.size():
		_actor.navigation_route_index += 1
		route_target = _actor.navigation_route[_actor.navigation_route_index]
	var direction: Variant = route_target - _actor.global_position
	direction.y = 0.0
	if direction.length_squared() < FINAL_ROUTE_STOP_SQUARED:
		direction = route_target - _actor.global_position
		direction.y = 0.0
	return direction.normalized() if direction.length_squared() > FINAL_ROUTE_STOP_SQUARED else Vector3.ZERO

func _validated_step_direction(direction: Vector3, target: Vector3, step_distance: float) -> Vector3:
	var candidate: Variant = direction
	candidate.y = 0.0
	if candidate.length_squared() < 0.002:
		return Vector3.ZERO
	candidate = candidate.normalized()
	if _actor.spatial_service == null:
		return candidate
	var proposed: Variant = _actor.global_position + candidate * maxf(step_distance, 0.02)
	if _actor.spatial_service.validate_segment(_actor.global_position, proposed, 0.50):
		return candidate
	var rerouted: Variant = _actor._navigation_direction(target, true)
	if rerouted.length_squared() < 0.002:
		return Vector3.ZERO
	var reroute_position: Variant = _actor.global_position + rerouted * maxf(step_distance, 0.02)
	return rerouted if _actor.spatial_service.validate_segment(_actor.global_position, reroute_position, 0.50) else Vector3.ZERO

func player_contact_distance() -> float:
	return _actor.player.global_position.distance_to(_actor.global_position) if _actor.player != null else INF

func _has_attack_line() -> bool:
	var origin: Variant = _actor.global_position+Vector3(0,0.9,0)
	var target: Vector3 = _actor.player.global_position+Vector3(0,0.9,0)
	var query: PhysicsRayQueryParameters3D = _actor._query_scratch.ray(origin, target, 1)
	query.exclude = [_actor.get_rid(),_actor.player.get_rid()]
	query.collide_with_areas = false
	return _actor.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _crowd_separation() -> Vector3:
	var separation: Variant = Vector3.ZERO
	var neighbors: Array = _actor.encounter_spatial_index.nearby(_actor.global_position, 1.55) if _actor.encounter_spatial_index != null else _actor.encounter_peers
	for other in neighbors:
		if other == _actor or not is_instance_valid(other) or bool(other.get("dead")) or not bool(other.get("encounter_active")):
			continue
		var offset: Vector3 = _actor.global_position-other.global_position
		offset.y = 0.0
		var distance: Variant = offset.length()
		if distance > 0.01 and distance < 1.55:
			var urgency: Variant = (1.55-distance)/1.55
			if distance < _actor.MIN_COMBAT_SPACING:
				urgency += ((_actor.MIN_COMBAT_SPACING-distance)/_actor.MIN_COMBAT_SPACING) * 1.8
			separation += offset.normalized() * urgency
	return separation.normalized() if separation.length_squared() > 0.01 else Vector3.ZERO

func _apply_peer_spacing(delta: float) -> void:
	"""Steer away from combat peers before physics resolves the move.

	CharacterBody3D owns the final collision response. Keeping separation in
	velocity avoids the old post-slide global-position correction, which could
	teleport an enemy through a wall, tree, river barrier, or another actor.
	"""
	if _actor.dead or _actor.pending_attack_time > 0.0 or _actor.stagger_time > 0.0:
		return
	var separation: Variant = _actor._crowd_separation()
	if separation.length_squared() < 0.01:
		return
	var current: Variant = Vector3(_actor.velocity.x, 0.0, _actor.velocity.z)
	var speed: Variant = clampf(current.length(), _actor.move_speed * 0.45, _actor.move_speed)
	var desired: Variant = separation * speed
	if current.length_squared() > 0.01:
		desired = current.normalized().lerp(separation, 0.45).normalized() * speed
	var desired_direction: Variant = desired.normalized()
	var step_distance: Variant = maxf(desired.length() * delta, 0.02)
	if _actor.spatial_service != null and not _actor.spatial_service.validate_segment(
		_actor.global_position, _actor.global_position + desired_direction * step_distance, 0.50
	):
		return
	_actor.velocity.x = desired.x
	_actor.velocity.z = desired.z

func _engagement_target(target_position: Vector3 = Vector3.INF) -> Vector3:
	var focus: Vector3 = _actor.player.global_position if target_position == Vector3.INF else target_position
	var radial: Vector3 = _actor.global_position - focus
	radial.y = 0.0
	if radial.length_squared() < 0.01:
		radial = Vector3.FORWARD
	var side: Variant = _actor.flank_sign
	if _actor.encounter_slot > 0:
		side = -1.0 if _actor.encounter_slot % 2 == 0 else 1.0
	var angle: Variant = deg_to_rad(_actor.approach_angle_degrees * side)
	var desired: Vector3 = radial.normalized().rotated(Vector3.UP, angle)
	var radius: float = _actor.tactics.engagement_radius(_actor.preferred_distance, _actor.attack_range, _actor.can_see_player, _actor.attack_cooldown, _actor.attack_recovery_time, READY_APPROACH_MARGIN)
	return focus + desired * radius

func _update_perception(delta: float, player_distance: float) -> void:
	_actor.perception_refresh_time = maxf(_actor.perception_refresh_time - delta, 0.0)
	_actor.perception_memory_time = maxf(_actor.perception_memory_time - delta, 0.0)
	if _actor.perception_refresh_time > 0.0:
		return
	_actor.perception_refresh_time = 0.18
	_actor.can_see_player = player_distance <= _actor.sense_range and _actor._has_perception_line()
	if _actor.can_see_player:
		_actor.last_known_player_position = _actor.player.global_position
		_actor.perception_memory_time = _actor.perception_memory_duration

func _has_perception_line() -> bool:
	if not _actor.is_inside_tree() or _actor.player == null or not _actor.player.is_inside_tree():
		return false
	var origin: Variant = _actor.global_position + Vector3(0, 1.20, 0)
	var target: Vector3 = _actor.player.global_position + Vector3(0, 1.05, 0)
	var key: Variant = [Engine.get_physics_frames(), origin, target, _actor.player.get_instance_id()]
	if key == _actor._perception_query_key:
		return _actor._perception_query_result
	var query: PhysicsRayQueryParameters3D = _actor._query_scratch.ray(origin, target, 1)
	query.exclude = [_actor.get_rid()]
	query.collide_with_areas = false
	var hit: Variant = _actor.get_world_3d().direct_space_state.intersect_ray(query)
	_actor._perception_query_key = key
	_actor._perception_query_result = hit.is_empty() or hit.get("collider") == _actor.player
	return _actor._perception_query_result

func _attack_lane_clear() -> bool:
	var start: Variant = _actor.global_position
	var finish: Vector3 = _actor.player.global_position
	var neighbors: Array = _actor.encounter_spatial_index.nearby((start + finish) * 0.5, start.distance_to(finish) * 0.5 + 0.72) if _actor.encounter_spatial_index != null else _actor.encounter_peers
	for other in neighbors:
		if other == _actor or not is_instance_valid(other) or bool(other.get("dead")) or not bool(other.get("encounter_active")):
			continue
		var other_pos: Vector3 = other.global_position
		var closest: Variant = Geometry3D.get_closest_point_to_segment(other_pos, start, finish)
		if other_pos.distance_to(closest) < 0.72 and start.distance_to(other_pos) < start.distance_to(finish):
			return false
	return true

func _attack_contact_point() -> Vector3:
	if _actor.animation_driver != null and _actor.animation_driver.is_valid():
		var skeleton: Skeleton3D = _actor.animation_driver.get_skeleton()
		if skeleton != null and _actor.attack_contact_bone >= 0:
			_actor.attack_trace_uses_skeleton = true
			var contact_pose: Variant = skeleton.get_bone_global_pose(_actor.attack_contact_bone)
			return skeleton.global_transform * (contact_pose * _actor.attack_contact_local_offset)
	_actor.attack_trace_uses_skeleton = false
	return _actor.global_position + Vector3(0.0, 1.05, 0.0)


func choose_tactical_mode() -> String:
	var model: RefCounted = _actor.tactics
	model.position = _actor.global_position
	model.home_position = _actor.home_position
	model.last_known = _actor.last_known_player_position
	model.boss = _actor.is_boss
	model.leash_radius = _actor.leash_radius
	model.attack_range = _actor.attack_range
	model.attack_cooldown = _actor.attack_cooldown
	model.pending_attack_time = _actor.pending_attack_time
	model.stagger_time = _actor.stagger_time
	model.memory_time = _actor.perception_memory_time
	model.recovery_time = _actor.attack_recovery_time
	model.identity = _actor.enemy_id
	model.health_ratio = _actor.health_component.health / maxf(_actor.health_component.max_health, 1.0)
	model.mode = model.choose_mode(_actor.player.global_position, _actor.can_see_player, _actor.encounter_active)
	return model.mode
