extends RefCounted
## enemy presence view: scene-only responsibilities.

var _actor: CharacterBody3D
var has_hunt_performance := false
var _close_pose := false

func _init(actor: CharacterBody3D) -> void:
	_actor = actor

func update_hunt_pose_rate(distance: float) -> void:
	if not has_hunt_performance:
		return
	# Two thresholds keep a hunter pacing at the edge from restarting its timer.
	var close := distance < (10.0 if _close_pose else 8.0)
	if close != _close_pose:
		_close_pose = close
		_actor.animation_driver.set_update_rate_hz(30.0 if close else 12.0)

func _update_native_ambient(delta: float, achieved: Vector3) -> void:
	if not _actor.native_ambient_authored: return
	# Physics, perception, actions and terminal state keep their existing
	# authority. Ambient clips never move the root or delay an attack.
	var eligible: bool = not _actor.dead and _actor.encounter_active and _actor.is_on_floor() and achieved.length_squared() <= 0.0064 \
		and not _actor.can_see_player and _actor.perception_memory_time <= 0.0 and _actor.pending_attack_time <= 0.0 \
		and _actor.attack_recovery_time <= 0.0 and _actor.stagger_time <= 0.0 and not _actor.animation_driver.has_active_action() \
		and not _actor.animation_driver.story_dialogue_active and not _actor.animation_driver.distance_suspended
	if not eligible:
		_actor.animation_driver.clear_observation_clip()
		_actor.native_ambient_elapsed = 0.0
		_actor.native_ambient_phase = -1
		return
	_actor.native_ambient_elapsed += delta
	var phase: Variant = floori(_actor.native_ambient_elapsed / 8.0) % 4
	if phase == _actor.native_ambient_phase and str(_actor.animation_driver.presentation_state) == "ecology": return
	var clip: Variant = _actor.native_ambient_clip(_actor.enemy_id, phase, _actor.is_boss, _actor.tag)
	if _actor.animation_driver.set_observation_clip(clip) or _actor.animation_driver.set_observation_clip("Idle"):
		_actor.native_ambient_phase = phase

func _update_ambient_life(delta: float) -> void:
	# Existing perception and attack reservations take precedence over all habits.
	_actor.ambient_elapsed += delta
	_actor.ambient_remaining = maxf(_actor.ambient_remaining - delta, 0.0)
	if _actor.ambient_remaining <= 0.0:
		_actor.ambient_cycle += 1
		var phase: Variant = float(absi((_actor.enemy_id + str(_actor.encounter_slot)).hash()) % 628) * 0.01
		if _actor.had_player_contact and _actor.last_known_player_position != Vector3.INF and _actor.last_known_player_position.distance_to(_actor.home_position) < minf(_actor.leash_radius - 1.0, 8.0):
			_actor.ambient_state = "searching"
			_actor.ambient_target = _actor.last_known_player_position
			_actor.ambient_remaining = 2.4
			_actor.had_player_contact = false
		elif _actor.global_position.distance_to(_actor.home_position) > 3.2:
			_actor.ambient_state = "returning"
			_actor.ambient_target = _actor.home_position
			_actor.ambient_remaining = 5.0
		elif _actor.ambient_cycle % 3 == 0:
			_actor.ambient_state = "scavenging" if _actor.behavior_profile not in ["brute", "duelist"] and _actor.tag not in ["human", "undead"] else "watching"
			_actor.ambient_target = Vector3.INF
			_actor.ambient_remaining = 3.0 + phase * 0.25
		else:
			_actor.ambient_target = _actor._ambient_landmark_destination()
			_actor.ambient_state = ("stalking" if _actor.behavior_profile == "flanker" else "patrolling") if _actor.ambient_target != _actor.home_position else "watching"
			_actor.ambient_remaining = 4.0 + phase * 0.2
		_actor.navigation_target = Vector3.INF
		_actor.navigation_refresh_time = 0.0
		if not is_instance_valid(_actor.native_face) and _actor.visual_root != null:
			_actor.native_face = _actor.visual_root.find_child("CharacterFaceDriver", true, false)
	var direction: Variant = Vector3.ZERO
	if _actor.ambient_target != Vector3.INF and _actor.global_position.distance_to(_actor.ambient_target) > 0.30:
		direction = _actor._navigation_direction(_actor.ambient_target)
		direction = _actor._validated_step_direction(direction, _actor.ambient_target, _actor.move_speed * 0.4 * delta)
	var pace: Variant = 0.34 if _actor.behavior_profile == "flanker" else 0.43
	_actor.velocity.x = move_toward(_actor.velocity.x, direction.x * _actor.move_speed * pace, delta * 4.0)
	_actor.velocity.z = move_toward(_actor.velocity.z, direction.z * _actor.move_speed * pace, delta * 4.0)
	if direction.length_squared() > 0.01:
		_actor.look_at(_actor.global_position + direction, Vector3.UP)
	elif _actor.animation_driver != null:
		if not _actor.native_ambient_authored:
			_actor.animation_driver.set_life_activity("scavenge" if _actor.ambient_state == "scavenging" else "watch")
		if is_instance_valid(_actor.native_face) and _actor.ambient_state == "scavenging" and fmod(_actor.ambient_elapsed, 2.8) < delta:
			_actor.native_face.play_story_gesture("remember")

func _ambient_landmark_destination() -> Vector3:
	if _actor.spatial_service == null:
		return _actor.home_position
	var radius: Variant = minf(1.35 if _actor.behavior_profile == "brute" else 2.5, maxf(0.5, _actor.leash_radius - 1.0))
	var kinds: Array[String] = []
	kinds.assign(["camp", "watch", "shelter"] if _actor.tag == "human" else (["shelter", "scavenge"] if _actor.behavior_profile == "flanker" else ["scavenge", "shelter", "watch"]))
	for kind: String in kinds:
		var points: Array[Vector3] = _actor.spatial_service.presence_destinations(kind, _actor.home_position, radius, 0.55)
		for offset in points.size():
			var candidate: Vector3 = points[(_actor.encounter_slot + _actor.ambient_cycle + offset) % points.size()]
			if _actor.spatial_service.validate_runtime_segment(_actor.global_position, candidate, 0.55, _actor):
				return candidate
	return _actor.home_position

func _update_boss_presence(delta: float) -> void:
	_actor.presence_clock += delta
	_actor.velocity.x = move_toward(_actor.velocity.x, 0.0, delta*5.0)
	_actor.velocity.z = move_toward(_actor.velocity.z, 0.0, delta*5.0)
	var sweep: Variant = 0.0
	match _actor.enemy_id:
		"bell_eater":
			_actor.ambient_state = "listening"
			sweep = sin(_actor.presence_clock*0.40)*0.14
		"bog_wretch":
			_actor.ambient_state = "territorial"
			var target: Vector3 = _actor.home_position + Vector3(cos(_actor.presence_clock*0.12),0,sin(_actor.presence_clock*0.12))*1.2
			if _actor.spatial_service != null and _actor.spatial_service.bank_for(target) == _actor.spatial_service.bank_for(_actor.home_position) and _actor.spatial_service.validate_runtime_segment(_actor.global_position, target, _actor.contact_radius, _actor):
				var direction: Variant = _actor._navigation_direction(target)
				_actor.velocity.x = direction.x*_actor.move_speed*0.25
				_actor.velocity.z = direction.z*_actor.move_speed*0.25
		"rootbound_colossus":
			_actor.ambient_state = "warding"
			sweep = sin(_actor.presence_clock*0.22)*0.04
		"ashwing":
			_actor.ambient_state = "watching"
			sweep = sin(_actor.presence_clock*0.28)*0.08
		"halvern_boss":
			_actor.ambient_state = "keeping_watch"
			sweep = sin(_actor.presence_clock*0.18)*0.025
		"white_hart_avatar":
			_actor.ambient_state = "attentive"
			sweep = sin(_actor.presence_clock*0.20)*0.035
	_actor.rotation.y = lerp_angle(_actor.rotation.y, _actor.presence_home_yaw+sweep, minf(delta*1.2,1.0))
	if _actor.animation_driver != null and Vector2(_actor.velocity.x,_actor.velocity.z).length_squared() < 0.01:
		if not _actor.native_ambient_authored: _actor.animation_driver.set_life_activity("watch")

func get_attack_trace() -> Dictionary:
	return {"start":_actor.attack_trace_start, "end":_actor.attack_trace_end, "contact":_actor.last_attack_contact, "uses_skeleton":_actor.attack_trace_uses_skeleton}

func get_behavior_state() -> Dictionary:
	return {"profile":_actor.behavior_profile,"windup":_actor.pending_attack_time,"stagger":_actor.stagger_time,"recovery":_actor.attack_recovery_time,"owns_attack_token":_actor.owns_attack_token,"can_see_player":_actor.can_see_player,"memory":_actor.perception_memory_time,"last_known":_actor.last_known_player_position}

func get_tactical_state() -> Dictionary:
	var route_safe: Variant = true
	for index in range(_actor.navigation_route.size()):
		if _actor.spatial_service != null:
			var point: Vector3 = _actor.navigation_route[index]
			# Route points are evaluated against authored spatial rules here. Occupancy
			# is intentionally left to movement-time steering so an enemy does not
			# reject its own current position (or a temporary combat peer) as unsafe.
			if _actor.spatial_service.is_river_excluded(point, 0.50):
				route_safe = false
				break
		if index > 0 and _actor.spatial_service != null and not _actor.spatial_service.validate_segment(_actor.navigation_route[index - 1], _actor.navigation_route[index], 0.50):
			route_safe = false
			break
	return {
		"enemy_id": _actor.enemy_id,
		"profile": _actor.behavior_profile,
		"preferred_distance": _actor.preferred_distance,
		"approach_angle": _actor.approach_angle_degrees,
		"flank_sign": _actor.flank_sign,
		"encounter_slot": _actor.encounter_slot,
		"leash_radius": _actor.leash_radius,
		"route_points": _actor.navigation_route.size(),
		"route_safe": route_safe,
		"navigation_refresh_time": _actor.navigation_refresh_time,
		"owns_attack_token": _actor.owns_attack_token,
		"attack_lane_clear": _actor._attack_lane_clear() if _actor.player != null else false,
		"perception": _actor.can_see_player,
		"memory": _actor.perception_memory_time,
		"windup": _actor.pending_attack_time,
		"attack_recovery": _actor.attack_recovery_time,
	}
