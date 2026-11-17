extends RefCounted
## player locomotion view: scene-only responsibilities.

var _actor: CharacterBody3D

func _init(actor: CharacterBody3D) -> void:
	_actor = actor

func _movement_input() -> Vector2:
	if _actor.input_source != null and (_actor.input_source != null):
		var frame: Variant = _actor.input_source.get("input_frame")
		if frame != null: return Vector2(frame.move_x, frame.move_y)
		return _actor.input_source.movement_vector()
	# Character fixtures and portrait captures can instantiate the controller
	# before InputRouter has installed its actions. Missing actions are neutral
	# input, not an engine error.
	for action in ["move_left", "move_right", "move_forward", "move_back"]:
		if not InputMap.has_action(action):
			return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")

func _action_pressed(action: StringName) -> bool:
	if _actor.input_source != null and (_actor.input_source != null):
		return _actor.input_source.is_action_pressed(action)
	if not InputMap.has_action(action):
		return false
	return Input.is_action_pressed(action)

func _action_just_pressed(action: StringName) -> bool:
	if not _actor._first_substep:
		return false
	return _actor._pending_pressed.has(action)

func _action_just_released(action: StringName) -> bool:
	if not _actor._first_substep:
		return false
	return _actor._pending_released.has(action)

func capture_input_edges() -> void:
	for action: StringName in [&"weapon_cycle", &"weapon_sheath", &"weapon_bow", &"weapon_sword", &"weapon_oathblade", &"use_potion", &"throw_bomb", &"light_attack", &"heavy_attack", &"block", &"oathfire_beam", &"aim_bow", &"fire_bow", &"cycle_arrow", &"jump", &"dodge"]:
		var pressed: bool = _actor.input_source.is_action_just_pressed(action) if _actor.input_source != null else InputMap.has_action(action) and Input.is_action_just_pressed(action)
		var released: bool = _actor.input_source.is_action_just_released(action) if _actor.input_source != null else InputMap.has_action(action) and Input.is_action_just_released(action)
		if pressed:
			_actor._pending_pressed[action] = true
		if released:
			_actor._pending_released[action] = true

func _handle_movement(delta: float) -> void:
	var input_vec: Vector2 = _actor._movement_input()
	var move_dir: Variant = _actor._movement_direction(input_vec)
	if _actor.dodge_time > 0.0:
		_actor.dodge_time -= delta
		var dodge_ratio: float = clampf(_actor.dodge_time / 0.30, 0.0, 1.0)
		var dodge_velocity: float = _actor.combat_model.dodge_velocity(_actor.dodge_time, _actor.dodge_speed)
		_actor.velocity.x = _actor.dodge_dir.x * dodge_velocity
		_actor.velocity.z = _actor.dodge_dir.z * dodge_velocity
		_actor.movement_state = "dodge"
	else:
		var wants_run: bool = _actor._action_pressed("run") and input_vec.length() > 0.1
		var is_running: bool = wants_run and _actor.stamina_component.spend(10.0 * _actor._entitlement_value("saga_sprint_multiplier", 1.0) * delta)
		var action_locked: bool = _actor.beam_cast_state != "" or _actor.attack_anim_time > 0.0
		var body_forward: Variant = -_actor.global_basis.z.normalized()
		if action_locked:
			# A committed blade/cast keeps its direction; do not play a reverse
			# stride or change the attack endpoint to satisfy conflicting movement.
			move_dir = body_forward * maxf(0.0, body_forward.dot(move_dir))
		var planar_velocity: Variant = Vector3(_actor.velocity.x, 0.0, _actor.velocity.z)
		var braking_turn: bool = not action_locked and move_dir.length_squared() > 0.01 and planar_velocity.length_squared() > 0.0225 and planar_velocity.normalized().dot(move_dir) < -0.35
		if not braking_turn and move_dir.length_squared() > 0.01 and not action_locked:
			var target_yaw: Variant = atan2(-move_dir.x, -move_dir.z)
			_actor._set_movement_facing(lerp_angle(_actor.rotation.y, target_yaw, 1.0 - exp(-_actor.turn_speed * delta)))
		elif (_actor.bow_aiming or _actor._uses_first_person_camera()) and _actor.camera_controller != null and not action_locked:
			var aim_forward: Vector3 = _actor.camera_controller.get_flat_forward()
			if aim_forward.length_squared() > 0.5:
				var aim_yaw: float = atan2(-aim_forward.x, -aim_forward.z)
				_actor.rotation.y = lerp_angle(_actor.rotation.y, aim_yaw, 1.0 - exp(-_actor.turn_speed * delta))
		_actor.velocity = _actor.combat_model.horizontal_velocity(_actor.velocity, move_dir, -_actor.global_basis.z.normalized(), delta, is_running, _actor.bow_aiming, action_locked, _actor.is_on_floor(), {
			"walk_speed": _actor.walk_speed, "run_speed": _actor.run_speed, "acceleration": _actor.acceleration,
			"run_acceleration": _actor.run_acceleration, "deceleration": _actor.deceleration, "casting": _actor.beam_cast_state != ""})
		if _actor._action_just_pressed("jump"):
			_actor.try_jump()
		if _actor._action_just_pressed("dodge") and not _actor.beam_charging:
			if _actor.stamina_component.spend(_actor.get_dodge_stamina_cost()):
				_actor._cancel_bow()
				_actor._cancel_equipment_action()
				_actor.dodge_dir = move_dir if move_dir.length() > 0.1 else -_actor.global_transform.basis.z
				_actor.dodge_time = 0.30
			else:
				_actor.stamina_exhausted.emit("dodge")
	_actor._try_step_up(move_dir)
	_actor._apply_gravity(delta)
	_actor.MotionStep.slide(_actor, delta)
	_actor._capture_locomotion_motion(delta)
	_actor._update_ground_adaptation(delta)
	_actor._animate_visuals(delta)

func _movement_direction(input_vec: Vector2) -> Vector3:
	if input_vec.length_squared() < 0.0001:
		_actor._movement_frame_active = false
		return Vector3.ZERO
	if _actor.camera_controller == null:
		return Vector3(input_vec.x, 0.0, input_vec.y).normalized()
	if not _actor.bow_aiming and not _actor._uses_first_person_camera() and not _actor._movement_frame_active:
		return (_actor.camera_controller.get_flat_right() * input_vec.x - _actor.camera_controller.get_flat_forward() * input_vec.y).normalized()
	var manual_yaw: float = _actor.camera_controller.get_manual_look_yaw()
	if not _actor._movement_frame_active or _actor._movement_frame_camera != _actor.camera_controller:
		_actor._movement_reference_yaw = float(_actor.camera_controller.yaw)
		_actor._movement_manual_yaw = manual_yaw
		_actor._movement_frame_camera = _actor.camera_controller
		_actor._movement_frame_active = true
		if _actor.beam_cast_state == "" and _actor.attack_anim_time <= 0.0:
			_actor.rotation.y = _actor._movement_reference_yaw
	else:
		# Only deliberate look input changes the held-input reference. Camera
		# follow rotations must never feed back and repeatedly reverse it.
		var manual_delta: Variant = manual_yaw - _actor._movement_manual_yaw
		_actor._movement_reference_yaw = wrapf(_actor._movement_reference_yaw + manual_delta, -PI, PI)
		if (_actor.bow_aiming or _actor._uses_first_person_camera()) and _actor.beam_cast_state == "" and _actor.attack_anim_time <= 0.0:
			_actor.rotation.y = wrapf(_actor.rotation.y + manual_delta, -PI, PI)
		_actor._movement_manual_yaw = manual_yaw
	var frame: Variant = Basis(Vector3.UP, _actor._movement_reference_yaw)
	return (frame.x * input_vec.x + frame.z * input_vec.y).normalized()

func _set_movement_facing(heading: float) -> void:
	_actor.rotation.y = wrapf(heading, -PI, PI)
	if _actor.camera_controller != null and (_actor.bow_aiming or _actor._uses_first_person_camera()):
		_actor.camera_controller.follow_movement_heading(_actor.rotation.y)

func _capture_locomotion_motion(delta: float) -> void:
	# Collision sliding, acceleration, dodges and the final coasting step all
	# have one movement sample. Desired input is never used as a gait direction.
	var achieved_velocity: Vector3 = _actor.get_position_delta() / maxf(delta, 0.000001)
	_actor.locomotion_velocity = Vector3(achieved_velocity.x, 0.0, achieved_velocity.z)

func _update_locomotion_state() -> void:
	if _actor.dodge_time > 0.0:
		_actor.movement_state = "dodge"
		return
	if not _actor.is_on_floor():
		_actor.movement_state = "jump"
		return
	var horizontal_speed: float = _actor.locomotion_velocity.length()
	if horizontal_speed < 0.15:
		_actor.movement_state = "idle"
		return
	if horizontal_speed > _actor.walk_speed * 1.04:
		_actor.movement_state = "run"
	else:
		_actor.movement_state = "walk"

func _face_attack_direction() -> void:
	var input_vec: Variant = _actor._movement_input()
	if _actor._uses_first_person_camera() and input_vec.length_squared() < 0.0001:
		var view_forward: Vector3 = _actor.camera_controller.get_flat_forward()
		_actor.rotation.y = atan2(-view_forward.x, -view_forward.z)
		return
	var move_dir: Variant = _actor._movement_direction(input_vec)
	if move_dir.length_squared() <= 0.01:
		if _actor.camera_controller != null and (_actor.camera_controller != null):
			var assisted: Vector3 = _actor.camera_controller.assist_attack_direction(_actor.global_position, -_actor.global_basis.z, 4.0)
			if assisted.length_squared() > 0.01:
				_actor.rotation.y = atan2(-assisted.x, -assisted.z)
		# A locked attack has a live combat target even when Kael is standing
		# still. Face that target at the attack edge so the hand-driven blade
		# sweep and the visible lock-on direction agree.
		if _actor.camera_controller != null and (_actor.camera_controller != null):
			var locked_target: Node3D = _actor.camera_controller.get_locked_combat_target()
			if locked_target != null and is_instance_valid(locked_target):
				var target_offset: Variant = locked_target.global_position - _actor.global_position
				target_offset.y = 0.0
				if target_offset.length_squared() > 0.01:
					_actor.rotation.y = atan2(-target_offset.x, -target_offset.z)
		return
	# Combat input is evaluated before movement in the physics tick. Apply the
	# same target yaw immediately at the attack edge so the blade starts from
	# the direction the player is visibly moving toward.
	_actor._set_movement_facing(atan2(-move_dir.x, -move_dir.z))

func try_jump() -> bool:
	if not _actor.can_control or not _actor.is_on_floor() or _actor.beam_charging or _actor.attack_anim_time > 0.0 or _actor.dodge_time > 0.0:
		return false
	_actor.velocity.y = _actor.jump_speed
	_actor.jump_pose_weight = 1.0
	_actor.movement_state = "jump"
	if _actor.animation_driver != null:
		_actor.animation_driver.trigger_action("jump")
	return true

func _try_step_up(move_dir: Vector3) -> void:
	if _actor.step_up_cooldown > 0.0 or move_dir.length() < 0.1 or not _actor.is_on_floor() or not _actor.is_on_wall():
		return
	var probe = _actor.global_position + move_dir * 0.46
	var query = PhysicsRayQueryParameters3D.create(probe + Vector3.UP * 0.42, probe - Vector3.UP * 0.08, 1)
	query.exclude = [_actor.get_rid()]
	query.collide_with_areas = false
	var hit = _actor.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var step_height = float(hit.position.y - _actor.global_position.y)
	if step_height > 0.04 and step_height <= 0.30 and not _actor.test_move(_actor.global_transform, Vector3.UP * (step_height + 0.035)):
		_actor.global_position.y += step_height + 0.035
		_actor.step_up_cooldown = 0.12

func _update_ground_adaptation(delta: float) -> void:
	var on_floor = _actor.is_on_floor()
	_actor.ground_adaptation_accumulator += delta
	if on_floor and not _actor.was_on_floor:
		_actor.landing_compression = clamp(abs(_actor.velocity.y) / 9.0, 0.45, 1.0)
	_actor.jump_pose_weight = move_toward(_actor.jump_pose_weight, 0.0 if on_floor else 1.0, delta * (6.0 if on_floor else 3.0))
	_actor.landing_compression = move_toward(_actor.landing_compression, 0.0, delta * 5.5)
	var normal = _actor.get_floor_normal() if on_floor else Vector3.UP
	_actor.smoothed_ground_normal = _actor.smoothed_ground_normal.lerp(normal, 1.0 - exp(-9.0 * delta)).normalized()
	if on_floor and _actor.ground_adaptation_accumulator >= _actor.GROUND_ADAPTATION_INTERVAL:
		var probe_delta: Variant = _actor.ground_adaptation_accumulator
		_actor.ground_adaptation_accumulator = 0.0
		_actor.left_foot_ground_offset = _actor._sample_foot_offset(-0.18, probe_delta, _actor.left_foot_ground_offset)
		_actor.right_foot_ground_offset = _actor._sample_foot_offset(0.18, probe_delta, _actor.right_foot_ground_offset)
	elif not on_floor:
		_actor.ground_adaptation_accumulator = 0.0
		_actor.left_foot_ground_offset = move_toward(_actor.left_foot_ground_offset, 0.0, delta * 3.0)
		_actor.right_foot_ground_offset = move_toward(_actor.right_foot_ground_offset, 0.0, delta * 3.0)
	if _actor.contact_shadow != null:
		_actor.contact_shadow.visible = _actor.global_position.y > -4.0
		var shadow_weight = 1.0 - clamp(abs(_actor.velocity.y) / 10.0, 0.0, 0.52)
		_actor.contact_shadow.scale = Vector3(0.95 * shadow_weight, 0.014, 0.66 * shadow_weight)
	_actor.was_on_floor = on_floor

func _sample_foot_offset(side: float, delta: float, current: float) -> float:
	var local_probe = _actor.global_transform.basis.x * side + _actor.global_transform.basis.z * 0.04
	var start = _actor.global_position + local_probe + Vector3.UP * 0.42
	var query = PhysicsRayQueryParameters3D.create(start, start - Vector3.UP * 0.72, 1)
	query.exclude = [_actor.get_rid()]
	query.collide_with_areas = false
	var hit = _actor.get_world_3d().direct_space_state.intersect_ray(query)
	var target = 0.0
	if not hit.is_empty():
		target = clamp(float(hit.position.y - _actor.global_position.y), -0.16, 0.16)
	return lerp(current, target, 1.0 - exp(-12.0 * delta))

func face_target(target_pos: Vector3) -> void:
	var flat = Vector3(target_pos.x, _actor.global_position.y, target_pos.z)
	if flat.distance_to(_actor.global_position) > 0.1:
		_actor.look_at(flat, Vector3.UP)

func _apply_gravity(delta: float) -> void:
	if not _actor.is_on_floor():
		_actor.velocity.y -= _actor.gravity * delta
	elif _actor.velocity.y <= 0.0:
		_actor.velocity.y = -0.1
