extends RefCounted
const RookPerformance = preload("res://scripts/views/novel_rook_performance.gd")
var _life: Node
func _init(life: Node) -> void:
	_life = life
func _update_actor(entry: Dictionary, delta: float) -> void:
	var node: Node3D = entry.node
	if not is_instance_valid(node): return
	if not is_instance_valid(entry.driver) or not entry.driver.is_valid():
		entry.motion_speed = 0.0
		entry.travel_direction = Vector3.ZERO
		return
	var hurt_rook := RookPerformance.injured(entry)
	if entry.has("rib_walk_metres"): RookPerformance.reconcile(_life, entry, hurt_rook)
	if entry.driver.get("dead") == true:
		_life._cancel_greeting(entry, false)
		_life._release_activity(entry, false)
		entry.motion_speed = 0.0
		entry.travel_direction = Vector3.ZERO
		return
	if entry.has("table_restore"):
		entry.table_seconds = float(entry.get("table_seconds",120.0)) - delta
		if float(entry.table_seconds) <= 0.0 or _life.player.global_position.distance_to(entry.get("table_point",node.global_position)) > 9.0:
			entry.pending_routine = entry.table_restore
			entry.erase("table_restore")
			_life._release_activity(entry)
			_life._apply_pending_routine(entry)
	if str(_life.read_tag(node, "locomotion_owner", "")) not in ["", "greyfen_life"]:
		_life._cancel_greeting(entry, false)
		_life._release_activity(entry, false)
		return
	if not node.is_visible_in_tree() or node.get_node_or_null("Person") != null and not node.get_node("Person").visible:
		_life._release_activity(entry)
		return
	entry.bark_cooldown = maxf(float(entry.get("bark_cooldown", 0.0)) - delta, 0.0)
	if _life.Presence.protected(node):
		_life._cancel_greeting(entry, false)
		_life._release_activity(entry, false)
		entry.social_time = 0.0
		_life.Presence.release(node, "social", _life.get_instance_id())
		entry.motion_speed = 0.0
		entry.travel_direction = Vector3.ZERO
		return
	if float(entry.get("reaction_time", 0.0)) > 0.0:
		_life._cancel_greeting(entry)
		_life._release_activity(entry)
		var threat: Vector3 = entry.get("threat_position", _life.player.global_position)
		if _life._seek_safety(entry, threat, delta):
			return
		if float(entry.motion_speed) > 0.05:
			_life._brake_actor(entry, delta)
		if float(entry.motion_speed) <= 0.05:
			_life._face(node, threat, delta)
			if entry.driver != null:
				entry.driver.set_life_activity("fear" if str(entry.get("reaction", "")) == "fear" else "watch")
			if is_instance_valid(entry.get("face")):
				entry.face.set_attention("point", null, threat + Vector3.UP * 1.4)
		return
	entry.social_time = maxf(float(entry.get("social_time", 0.0)) - delta, 0.0)
	if float(entry.social_time) > 0.0:
		return
	if node.has_meta("cast_social_owner"):
		_life.Presence.release(node, "social", _life.get_instance_id())
		if is_instance_valid(entry.get("face")):
			entry.face.set_focus_target(null)
	if bool(_life.read_tag(node, "bell_eater_evacuated", false)):
		_life._release_awake_seat(entry)
		entry.motion_speed = 0.0
		_life._set_motion(entry, 0.0)
		return
	if not entry.pending_routine.is_empty() and bool(entry.profile.get("scheduled", false)):
		_life._cancel_greeting(entry)
		if bool(entry.get("activity_active", false)):
			_life._end_activity(entry)
		elif float(entry.motion_speed) > 0.05:
			_life._brake_actor(entry, delta)
			return
	if not bool(entry.get("activity_active", false)) and float(entry.get("motion_speed", 0.0)) < 0.05:
		_life._apply_pending_routine(entry)
	if _life._tick_greeting(entry, delta):
		return
	if bool(entry.get("activity_active", false)):
		_life._update_activity(entry, delta)
		return
	if float(entry.pause) > 0.0:
		entry.pause = float(entry.pause) - delta
		_life._brake_actor(entry, delta)
		return
	if entry.path.is_empty():
		_life._brake_actor(entry, delta)
		return
	entry.target = int(entry.target) % entry.path.size()
	if entry.route.is_empty():
		var final_target: Vector3 = _life.host.validate_walkable_position(entry.path[int(entry.target)])
		entry.route = _life._routine_route(entry, final_target)
		entry.route_index = 1 if entry.route.size() > 1 else 0
		entry.erase("carry_route_scope")
		var scope: Variant = _life._reviewed_c11_carry_leg(entry)
		if not scope.is_empty(): entry.carry_route_scope = scope
		_life._set_agent_target(entry)
	if entry.route.is_empty():
		_life._brake_actor(entry, delta)
		return
	var target: Vector3 = entry.route[int(entry.route_index)]
	var offset: Variant = target - node.global_position
	offset.y = 0.0
	var distance: float = offset.length()
	if distance < 0.38 and int(entry.route_index) + 1 < entry.route.size():
		var onward: Vector3 = entry.route[int(entry.route_index) + 1] - node.global_position
		onward.y = 0.0
		if onward.length_squared() > 0.01 and offset.normalized().dot(onward.normalized()) > 0.75:
			entry.route_index = int(entry.route_index) + 1
			return
	if distance <= _life.ARRIVAL_DISTANCE + 0.015 and float(entry.motion_speed) < 0.12:
		entry.motion_speed = 0.0
		if not entry.has("rib_breath_left"): _life._set_motion(entry, 0.0)
		if hurt_rook and RookPerformance.pause_at_arrival(entry, delta): return
		entry.route_index = int(entry.route_index) + 1
		if int(entry.route_index) < entry.route.size():
			_life._set_agent_target(entry)
			return
		entry.route = []
		entry.arrived_target = int(entry.target)
		entry.target = (int(entry.target) + 1) % entry.path.size()
		_life._begin_activity(entry)
		return
	var direction: Vector3 = offset.normalized()
	var wanted_yaw: float = _life._wanted_yaw(node, direction)
	var turn_error: float = absf(wrapf(wanted_yaw - node.rotation.y, -PI, PI))
	if turn_error > deg_to_rad(65.0) and float(entry.motion_speed) > 0.05:
		_life._brake_actor(entry, delta)
		return
	_life._face(node, node.global_position + direction, delta, true)
	turn_error = absf(wrapf(wanted_yaw - node.rotation.y, -PI, PI))
	var turn_pace: float = clampf((deg_to_rad(65.0) - turn_error) / deg_to_rad(48.0), 0.0, 1.0)
	var arrival_pace: float = sqrt(2.0 * _life.WALK_BRAKING * maxf(distance - _life.ARRIVAL_DISTANCE, 0.0))
	var ordinary_pace: float = float(entry.speed) * RookPerformance.WALK_SCALE if hurt_rook else float(entry.speed)
	var desired_speed: float = minf(ordinary_pace * turn_pace, arrival_pace)
	var crowd_pace: Variant = _life._crowd_pace(entry, direction, delta)
	if not is_equal_approx(crowd_pace, 1.0): entry.erase("carry_route_scope")
	desired_speed *= crowd_pace
	var current_speed: float = float(entry.motion_speed)
	var rate: float = _life.WALK_ACCELERATION if desired_speed > current_speed else _life.WALK_BRAKING
	entry.motion_speed = move_toward(current_speed, desired_speed, rate * delta)
	var heading: Vector3 = entry.driver.get_visible_forward() if is_instance_valid(entry.driver) else -node.global_basis.z
	heading.y = 0.0
	heading = heading.normalized()
	entry.travel_direction = heading
	var step_start := node.global_position
	_life._move_actor(entry, heading, float(entry.motion_speed), delta, maxf(distance - _life.ARRIVAL_DISTANCE, 0.0))
	if hurt_rook: RookPerformance.record_step(entry, step_start)

func _crowd_pace(entry: Dictionary, direction: Vector3, delta: float) -> float:
	var pace: Variant = 1.0
	var obstruction: Node3D
	var obstruction_distance: Variant = INF
	for other: Dictionary in _life._crowd_index.nearby(entry.node.global_position, 1.62):
		if other == entry or not is_instance_valid(other.node): continue
		if not other.node.is_visible_in_tree(): continue
		var person: Variant = other.node.get_node_or_null("Person") as Node3D
		if person != null and not person.is_visible_in_tree(): continue
		var offset: Vector3 = other.node.global_position - entry.node.global_position
		offset.y = 0.0
		var ahead: Variant = offset.dot(direction)
		if ahead <= 0.0 or ahead > 1.5: continue
		var lateral: Variant = (offset - direction * ahead).length()
		if lateral < 0.60:
			pace = minf(pace, smoothstep(0.60, 1.5, ahead))
			if ahead < obstruction_distance and (str(entry.id) > str(other.id) or float(other.get("motion_speed", 0.0)) < 0.05 or bool(other.get("activity_active", false)) or float(other.get("pause", 0.0)) > 0.0):
				obstruction = other.node
				obstruction_distance = ahead
	if _life._player_shares_height(entry.node.global_position):
		var offset: Vector3 = _life.player.global_position - entry.node.global_position
		offset.y = 0.0
		var ahead: Variant = offset.dot(direction)
		var lateral: Variant = (offset - direction * ahead).length()
		if ahead > 0.0 and ahead < 1.65 and lateral < 0.72:
			pace = minf(pace, smoothstep(0.82, 1.65, ahead))
			if ahead < obstruction_distance:
				obstruction = _life.player
	entry.yield_time = float(entry.get("yield_time", 0.0)) + delta if pace < 0.15 else 0.0
	if float(entry.yield_time) > 1.2 and is_instance_valid(obstruction) and _life.spatial_service != null and not entry.route.is_empty():
		entry.yield_time = -1.5
		var side: Variant = direction.cross(Vector3.UP).normalized()
		var reconnect: Vector3 = entry.route[int(entry.route_index)]
		for sign_value: float in [1.0, -1.0]:
			var step_aside: Vector3 = entry.node.global_position + side * sign_value * 0.95
			var pass_point: Vector3 = obstruction.global_position + side * sign_value * 0.95 + direction * 0.85
			pass_point.y = entry.node.global_position.y
			if _life._clear_detour_segment(entry.node.global_position, step_aside) and _life._clear_detour_segment(step_aside, pass_point) and _life._clear_detour_segment(pass_point, reconnect):
				entry.route.insert(int(entry.route_index), pass_point)
				entry.route.insert(int(entry.route_index), step_aside)
				break
	return pace

func _clear_detour_segment(start: Vector3, destination: Vector3) -> bool:
	var offset: Variant = destination - start
	offset.y = 0.0
	var distance: Variant = offset.length()
	return _life._player_clear_step(start, offset.normalized(), distance) >= distance and _life.spatial_service.validate_runtime_segment(start, destination, 0.58)

func _player_clear_step(start: Vector3, direction: Vector3, step: float) -> float:
	if not _life._player_shares_height(start): return step
	var offset: Variant = start - _life.player.global_position
	offset.y = 0.0
	var planar: Variant = Vector3(direction.x, 0.0, direction.z)
	var length_squared: Variant = planar.length_squared()
	if length_squared < 0.000001: return step
	var approach: Variant = offset.dot(planar)
	var clearance: Variant = offset.length_squared() - 0.72 * 0.72
	if clearance <= 0.0:
		return step if approach >= 0.0 else 0.0
	if approach >= 0.0: return step
	var discriminant: Variant = approach * approach - length_squared * clearance
	if discriminant <= 0.0: return step
	var contact_step: Variant = (-approach - sqrt(discriminant)) / length_squared
	return minf(step, maxf(contact_step - 0.005, 0.0))

func _player_shares_height(position: Vector3) -> bool:
	if not is_instance_valid(_life.player): return false
	var spec: Dictionary = _life.read_tag(_life.player, "character_role_spec", {})
	var height: Variant = maxf(1.72, float(spec.get("height", 1.72))) + 0.3
	return absf(position.y - _life.player.global_position.y) <= height

func _brake_actor(entry: Dictionary, delta: float) -> void:
	entry.motion_speed = move_toward(float(entry.get("motion_speed", 0.0)), 0.0, _life.WALK_BRAKING * delta)
	var direction: Vector3 = entry.get("travel_direction", Vector3.ZERO)
	_life._move_actor(entry, direction, float(entry.motion_speed), delta)

func _move_actor(entry: Dictionary, direction: Vector3, speed: float, delta: float, remaining_distance: float = INF) -> void:
	var node: Node3D = entry.node
	var start: Vector3 = node.global_position
	if entry.has("table_approach") and start.distance_to(entry.table_approach) < 0.55:
		entry.erase("table_approach")
	var requested_step: Variant = minf(speed * delta, remaining_distance)
	var step: float = _life._player_clear_step(start, direction, requested_step)
	if not is_equal_approx(step, requested_step): entry.erase("carry_route_scope")
	if direction.length_squared() < 0.001 or step <= 0.00001:
		entry.motion_speed = 0.0
		_life._set_motion(entry, 0.0)
		return
	var destination: Vector3 = start + direction * step
	if _life.spatial_service != null and not _life.spatial_service.validate_runtime_segment(start, destination, 0.58):
		entry.route = []
		entry.pause = 0.5
		entry.motion_speed = 0.0
		_life._set_motion(entry, 0.0)
		return
	node.global_position = destination
	var alias: Node3D = entry.get("alias_anchor")
	if is_instance_valid(alias):
		alias.global_position = node.global_position
	var achieved_velocity: Vector3 = (node.global_position - start) / maxf(delta, 0.001)
	achieved_velocity.y = 0.0
	if achieved_velocity.length_squared() > 0.000001:
		entry.travel_direction = achieved_velocity.normalized()
	_life._set_motion(entry, achieved_velocity.length(), achieved_velocity.normalized())

func _walk_scripted_step(entry: Dictionary, point: Vector3, speed_limit: float, turn_threshold: float, arrival_radius: float, delta: float) -> void:
	var node: Node3D = entry.node
	var offset: Variant = point - node.global_position
	offset.y = 0.0
	var direction: Variant = offset.normalized()
	var wanted_yaw: Variant = _life._wanted_yaw(node, direction)
	var turn_error: Variant = absf(wrapf(wanted_yaw - node.rotation.y, -PI, PI))
	if turn_error > turn_threshold and float(entry.motion_speed) > 0.05:
		_life._brake_actor(entry, delta)
		return
	_life._face(node, point, delta, true)
	turn_error = absf(wrapf(wanted_yaw - node.rotation.y, -PI, PI))
	if turn_error > turn_threshold:
		_life._brake_actor(entry, delta)
		return
	var remaining_distance: Variant = offset.length()
	var desired_speed: Variant = speed_limit
	if arrival_radius > 0.0:
		remaining_distance = maxf(remaining_distance - arrival_radius, 0.0)
		desired_speed = minf(desired_speed, sqrt(2.0 * _life.WALK_BRAKING * remaining_distance))
	var current_speed: Variant = float(entry.motion_speed)
	var rate: Variant = _life.WALK_ACCELERATION if desired_speed > current_speed else _life.WALK_BRAKING
	entry.motion_speed = move_toward(current_speed, desired_speed, rate * delta)
	var heading: Vector3 = entry.driver.get_visible_forward() if is_instance_valid(entry.driver) else -node.global_basis.z
	heading.y = 0.0
	_life._move_actor(entry, heading.normalized(), float(entry.motion_speed), delta, remaining_distance)

func _face(node: Node3D, target: Vector3, delta: float, walking: bool = false) -> void:
	var offset: Variant = target - node.global_position
	offset.y = 0.0
	if offset.length() < 0.05: return
	var wanted: Variant = _life._wanted_yaw(node, offset)
	var turn_error: float = wrapf(wanted - node.rotation.y, -PI, PI)
	var turn_limit: float = (_life.ROUTE_TURN_RATE if walking else _life.ATTENTION_TURN_RATE) * delta
	node.rotation.y += clampf(turn_error, -turn_limit, turn_limit)

func _wanted_yaw(node: Node3D, direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)-float(_life.read_tag(node, "cast_forward_offset", 0.0))
