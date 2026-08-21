extends CharacterBody3D

signal blade_contact_requested(contact: Dictionary)
signal potion_requested
signal bomb_requested
signal beam_requested(charge_ratio: float, direction: Vector3)
signal beam_phase_changed(phase: String)
signal footstep
signal parried
signal blocked(amount: float)
signal hurt(amount: float)
signal stamina_exhausted(action: String)
signal died

const HealthComponent = preload("res://scripts/health_component.gd")
const StaminaComponent = preload("res://scripts/stamina_component.gd")
const AssetSpawnHelper = preload("res://scripts/asset_spawn_helper.gd")
const CharacterPresentation = preload("res://scripts/character_presentation.gd")
const CharacterRoleSpec = preload("res://scripts/character_role_spec.gd")
const CharacterAnimationDriver = preload("res://scripts/character_animation_driver.gd")

var walk_speed = 3.4
var run_speed = 5.3
var dodge_speed = 8.0
var gravity = 24.0
var jump_speed = 8.2
var acceleration = 17.0
var run_acceleration = 13.0
var deceleration = 21.0
var turn_speed = 11.0
var attack_cooldown = 0.0
var dodge_time = 0.0
var dodge_dir = Vector3.ZERO
var can_control = true
var transition_locked := false
var camera_controller
var input_source: Node
var health_component
var stamina_component
var visual_root: Node3D
var body_visual: MeshInstance3D
var body_base_color := Color(0.24, 0.27, 0.25)
var weapon_root: Node3D
var sword_visual: MeshInstance3D
var sword_hilt_visual: MeshInstance3D
var sword_trail_visual: MeshInstance3D
var rig_sword_visual: Node3D
var sword_attachment: BoneAttachment3D
var sword_equipment_pivot: Node3D
var slash_arc_root: Node3D
var slash_arc_primary: MeshInstance3D
var slash_arc_secondary: MeshInstance3D
var slash_arc_spark: MeshInstance3D
var left_arm_proxy: MeshInstance3D
var right_arm_proxy: MeshInstance3D
var left_leg_proxy: MeshInstance3D
var right_leg_proxy: MeshInstance3D
var cloak_motion_proxy: MeshInstance3D
var asset_helper
var animation_driver
var move_phase = 0.0
var step_phase = 0.0
var attack_anim_time = 0.0
var attack_anim_heavy = false
var pending_attack_damage := 0.0
var pending_attack_radius := 0.0
var pending_attack_heavy := false
var attack_sequence_id := 0
var attack_contact_emitted := false
var previous_blade_base := Vector3.ZERO
var previous_blade_tip := Vector3.ZERO
var visual_previous_blade_base := Vector3.ZERO
var visual_previous_blade_tip := Vector3.ZERO
var blade_base_marker: Node3D
var blade_tip_marker: Node3D
var hurt_flash_time = 0.0
var hurt_react_time = 0.0
var parry_window = 0.0
var buffered_attack := ""
var attack_buffer_time := 0.0
var block_pose_weight = 0.0
var grounded_weight = 0.0
var beam_charging = false
var beam_charge_time = 0.0
var beam_cooldown = 0.0
var beam_charge_visual: MeshInstance3D
var beam_left_hand_glow: MeshInstance3D
var beam_right_hand_glow: MeshInstance3D
var beam_left_hand_socket: BoneAttachment3D
var beam_right_hand_socket: BoneAttachment3D
var sheathed_sword_visual: Node3D
var beam_cast_state := ""
var beam_state_time := 0.0
var beam_locked_direction := Vector3.ZERO
var beam_pending_ratio := 0.0
var beam_release_elapsed := 0.0
var beam_release_emitted := false
var movement_state = "idle"
var movement_blend = 0.0
var strafe_blend = 0.0
var backward_blend = 0.0
var jump_pose_weight = 0.0
var landing_compression = 0.0
var smoothed_ground_normal = Vector3.UP
var left_foot_ground_offset = 0.0
var right_foot_ground_offset = 0.0
var contact_shadow: Node3D
var was_on_floor = false
var step_up_cooldown = 0.0
var progression

func _ready() -> void:
	add_to_group("player")
	health_component = HealthComponent.new()
	stamina_component = StaminaComponent.new()
	add_child(health_component)
	add_child(stamina_component)
	health_component.configure(125.0)
	health_component.died.connect(_on_died)
	_build_body()
	floor_snap_length = 0.34
	floor_max_angle = deg_to_rad(48.0)
	max_slides = 6
	safe_margin = 0.035
	contact_shadow = find_child("CharacterContactShadow", true, false) as Node3D
	was_on_floor = is_on_floor()

func _physics_process(delta: float) -> void:
	attack_cooldown = max(attack_cooldown - delta, 0.0)
	beam_cooldown = max(beam_cooldown - delta, 0.0)
	attack_anim_time = max(attack_anim_time - delta, 0.0)
	hurt_flash_time = max(hurt_flash_time - delta, 0.0)
	hurt_react_time = max(hurt_react_time - delta, 0.0)
	parry_window = max(parry_window - delta, 0.0)
	attack_buffer_time = max(attack_buffer_time - delta, 0.0)
	if attack_buffer_time <= 0.0:
		buffered_attack = ""
	step_up_cooldown = max(step_up_cooldown - delta, 0.0)
	_update_beam_sequence(delta)
	if transition_locked:
		velocity = Vector3.ZERO
		_animate_visuals(delta, Vector3.ZERO, false)
		_update_blade_contact()
		return
	if not can_control:
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		_apply_gravity(delta)
		move_and_slide()
		_animate_visuals(delta, Vector3.ZERO, false)
		_update_blade_contact()
		return
	_handle_combat_input()
	_handle_movement(delta)
	_update_blade_contact()

func set_transition_locked(locked: bool) -> void:
	transition_locked = locked
	if locked:
		can_control = false
		velocity = Vector3.ZERO
	elif health_component == null or health_component.health > 0.0:
		can_control = true

func set_progression(manager) -> void:
	if progression != null and progression.changed.is_connected(_apply_progression_stats):
		progression.changed.disconnect(_apply_progression_stats)
	progression = manager
	if progression != null and not progression.changed.is_connected(_apply_progression_stats):
		progression.changed.connect(_apply_progression_stats)
	_apply_progression_stats()

func _apply_progression_stats() -> void:
	if health_component == null:
		return
	var target_max := 125.0 + _progression_value("max_health_bonus", 0.0)
	var gained := maxf(target_max - health_component.max_health, 0.0)
	health_component.max_health = target_max
	health_component.health = clampf(health_component.health + gained, 1.0, target_max)
	health_component.changed.emit(health_component.health, health_component.max_health)

func _progression_value(effect_id: String, fallback: float) -> float:
	return progression.effect_value(effect_id, fallback) if progression != null else fallback

func get_dodge_stamina_cost() -> float:
	return maxf(1.0, 28.0 - _progression_value("dodge_cost_reduction", 0.0))

func get_oathfire_stamina_cost() -> float:
	return maxf(1.0, 40.0 - _progression_value("beam_cost_reduction", 0.0))

func get_oathfire_cooldown_duration() -> float:
	return maxf(0.5, 4.0 - _progression_value("beam_cooldown_reduction", 0.0))

func get_blade_attack_damage(heavy: bool = false) -> float:
	var base_damage := 42.0 if heavy else 24.0
	var multiplier := _progression_value("blade_damage_multiplier", 1.0)
	if heavy:
		multiplier *= _progression_value("heavy_damage_multiplier", 1.0)
	return base_damage * multiplier

func _movement_input() -> Vector2:
	if input_source != null and input_source.has_method("movement_vector"):
		return input_source.movement_vector()
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")

func _action_pressed(action: StringName) -> bool:
	if input_source != null and input_source.has_method("is_action_pressed"):
		return input_source.is_action_pressed(action)
	return Input.is_action_pressed(action)

func _action_just_pressed(action: StringName) -> bool:
	if input_source != null and input_source.has_method("is_action_just_pressed"):
		return input_source.is_action_just_pressed(action)
	return Input.is_action_just_pressed(action)

func _action_just_released(action: StringName) -> bool:
	if input_source != null and input_source.has_method("is_action_just_released"):
		return input_source.is_action_just_released(action)
	return Input.is_action_just_released(action)

func _handle_movement(delta: float) -> void:
	var input_vec := _movement_input()
	var forward = Vector3.FORWARD
	var right = Vector3.RIGHT
	if camera_controller != null:
		forward = camera_controller.get_flat_forward()
		right = camera_controller.get_flat_right()
	var move_dir = (right * input_vec.x + forward * -input_vec.y).normalized()
	if dodge_time > 0.0:
		dodge_time -= delta
		var dodge_ratio = clamp(dodge_time / 0.30, 0.0, 1.0)
		var dodge_velocity = dodge_speed * (0.62 + 0.38 * sin(dodge_ratio * PI))
		velocity.x = dodge_dir.x * dodge_velocity
		velocity.z = dodge_dir.z * dodge_velocity
		movement_state = "dodge"
	else:
		var wants_run := _action_pressed("run") and input_vec.length() > 0.1
		var is_running = wants_run and stamina_component.spend(10.0 * delta)
		var speed = run_speed if is_running else walk_speed
		if input_vec.y > 0.15:
			speed *= 0.68
		if beam_cast_state != "":
			speed *= 0.4
		var target_velocity = move_dir * speed
		var response = run_acceleration if is_running else acceleration
		if move_dir.length() <= 0.1:
			response = deceleration
		velocity.x = move_toward(velocity.x, target_velocity.x, response * delta)
		velocity.z = move_toward(velocity.z, target_velocity.z, response * delta)
		var intentional_backpedal := input_vec.y > 0.15
		if move_dir.length() > 0.1 and beam_cast_state == "" and not intentional_backpedal:
			var target_yaw = atan2(-move_dir.x, -move_dir.z)
			rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))
		movement_state = "run" if is_running else ("backward" if input_vec.y > 0.15 else ("strafe" if abs(input_vec.x) > 0.55 else ("walk" if move_dir.length() > 0.1 else "idle")))
		if _action_just_pressed("jump"):
			try_jump()
		if _action_just_pressed("dodge") and not beam_charging:
			if stamina_component.spend(get_dodge_stamina_cost()):
				dodge_dir = move_dir if move_dir.length() > 0.1 else -global_transform.basis.z
				dodge_time = 0.30
			else:
				stamina_exhausted.emit("dodge")
	_try_step_up(move_dir)
	_apply_gravity(delta)
	move_and_slide()
	_update_ground_adaptation(delta)
	_animate_visuals(delta, move_dir, input_vec.length() > 0.1)

func try_jump() -> bool:
	if not can_control or not is_on_floor() or beam_charging or attack_anim_time > 0.0 or dodge_time > 0.0:
		return false
	velocity.y = jump_speed
	jump_pose_weight = 1.0
	movement_state = "jump"
	if animation_driver != null:
		animation_driver.trigger_action("jump")
	return true

func _try_step_up(move_dir: Vector3) -> void:
	if step_up_cooldown > 0.0 or move_dir.length() < 0.1 or not is_on_floor() or not is_on_wall():
		return
	var probe = global_position + move_dir * 0.46
	var query = PhysicsRayQueryParameters3D.create(probe + Vector3.UP * 0.42, probe - Vector3.UP * 0.08)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var step_height = float(hit.position.y - global_position.y)
	if step_height > 0.04 and step_height <= 0.30 and not test_move(global_transform, Vector3.UP * (step_height + 0.035)):
		global_position.y += step_height + 0.035
		step_up_cooldown = 0.12

func _update_ground_adaptation(delta: float) -> void:
	var on_floor = is_on_floor()
	if on_floor and not was_on_floor:
		landing_compression = clamp(abs(velocity.y) / 9.0, 0.45, 1.0)
	jump_pose_weight = move_toward(jump_pose_weight, 0.0 if on_floor else 1.0, delta * (6.0 if on_floor else 3.0))
	landing_compression = move_toward(landing_compression, 0.0, delta * 5.5)
	var normal = get_floor_normal() if on_floor else Vector3.UP
	smoothed_ground_normal = smoothed_ground_normal.lerp(normal, 1.0 - exp(-9.0 * delta)).normalized()
	left_foot_ground_offset = _sample_foot_offset(-0.18, delta, left_foot_ground_offset) if on_floor else move_toward(left_foot_ground_offset, 0.0, delta * 3.0)
	right_foot_ground_offset = _sample_foot_offset(0.18, delta, right_foot_ground_offset) if on_floor else move_toward(right_foot_ground_offset, 0.0, delta * 3.0)
	if contact_shadow != null:
		contact_shadow.visible = global_position.y > -4.0
		var shadow_weight = 1.0 - clamp(abs(velocity.y) / 10.0, 0.0, 0.52)
		contact_shadow.scale = Vector3(0.95 * shadow_weight, 0.014, 0.66 * shadow_weight)
	was_on_floor = on_floor

func _sample_foot_offset(side: float, delta: float, current: float) -> float:
	var local_probe = global_transform.basis.x * side + global_transform.basis.z * 0.04
	var start = global_position + local_probe + Vector3.UP * 0.42
	var query = PhysicsRayQueryParameters3D.create(start, start - Vector3.UP * 0.72)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	var target = 0.0
	if not hit.is_empty():
		target = clamp(float(hit.position.y - global_position.y), -0.16, 0.16)
	return lerp(current, target, 1.0 - exp(-12.0 * delta))

func _handle_combat_input() -> void:
	_handle_beam_input()
	if beam_cast_state != "":
		return
	var light_pressed := _action_just_pressed("light_attack")
	var heavy_pressed := _action_just_pressed("heavy_attack")
	if attack_cooldown > 0.0:
		if light_pressed or heavy_pressed:
			buffered_attack = "heavy" if heavy_pressed else "light"
			attack_buffer_time = 0.18
		return
	if buffered_attack != "":
		light_pressed = buffered_attack == "light"
		heavy_pressed = buffered_attack == "heavy"
		buffered_attack = ""
		attack_buffer_time = 0.0
	if light_pressed:
		attack_cooldown = 0.38
		attack_anim_time = 0.34
		attack_anim_heavy = false
		if animation_driver != null:
			animation_driver.trigger_action("attack_light", 1.22, 0.06)
		_begin_blade_attack(get_blade_attack_damage(false), 2.0, false)
	elif heavy_pressed:
		if stamina_component.spend(22.0):
			attack_cooldown = 0.7
			attack_anim_time = 0.52
			attack_anim_heavy = true
			if animation_driver != null:
				animation_driver.trigger_action("attack_heavy", 0.76, 0.08)
			_begin_blade_attack(get_blade_attack_damage(true), 2.25, true)
		else:
			stamina_exhausted.emit("heavy attack")
	if _action_just_pressed("use_potion"):
		potion_requested.emit()
	if _action_just_pressed("throw_bomb"):
		bomb_requested.emit()
	if _action_just_pressed("block"):
		parry_window = get_parry_window_duration()
		if animation_driver != null:
			animation_driver.trigger_action("parry")

func _begin_blade_attack(damage: float, radius: float, heavy: bool) -> void:
	attack_sequence_id += 1
	attack_contact_emitted = false
	pending_attack_damage = damage
	pending_attack_radius = radius
	pending_attack_heavy = heavy
	var segment: Dictionary = get_blade_world_segment()
	previous_blade_base = segment.get("base", global_position + Vector3(0, 1.0, 0))
	previous_blade_tip = segment.get("tip", previous_blade_base)

func _update_blade_contact() -> void:
	if not can_control:
		pending_attack_damage = 0.0
		pending_attack_radius = 0.0
		return
	if pending_attack_damage <= 0.0:
		return
	var segment: Dictionary = get_blade_world_segment()
	var blade_base: Vector3 = segment.get("base", Vector3.ZERO)
	var blade_tip: Vector3 = segment.get("tip", Vector3.ZERO)
	var duration: float = 0.52 if pending_attack_heavy else 0.34
	var progress: float = clampf(1.0 - attack_anim_time / duration, 0.0, 1.0)
	var contact_phase: float = 0.46 if pending_attack_heavy else 0.35
	if not attack_contact_emitted and progress >= contact_phase:
		attack_contact_emitted = true
		blade_contact_requested.emit({
			"attack_id": attack_sequence_id,
			"base": blade_base,
			"tip": blade_tip,
			"previous_base": previous_blade_base,
			"previous_tip": previous_blade_tip,
			"damage": pending_attack_damage,
			"reach": pending_attack_radius,
			"heavy": pending_attack_heavy,
			"contact_phase": progress,
			"sweep_length": maxf(previous_blade_tip.distance_to(blade_tip), previous_blade_base.distance_to(blade_base)),
			"blade_direction": (blade_tip - blade_base).normalized() if blade_tip.distance_to(blade_base) > 0.001 else Vector3.ZERO
		})
		pending_attack_damage = 0.0
		pending_attack_radius = 0.0
	previous_blade_base = blade_base
	previous_blade_tip = blade_tip

func get_parry_window_duration() -> float:
	return 0.30

func get_attack_buffer_duration() -> float:
	return 0.18

func get_blade_world_segment() -> Dictionary:
	if blade_base_marker != null and blade_tip_marker != null and is_instance_valid(blade_base_marker) and is_instance_valid(blade_tip_marker):
		return {"base": blade_base_marker.global_position, "tip": blade_tip_marker.global_position}
	var forward := -global_transform.basis.z.normalized()
	var base := global_position + Vector3(0, 1.05, 0) + forward * 0.35
	return {"base": base, "tip": base + forward * 1.25}

func _configure_blade_markers(parent: Node3D, base_position: Vector3, tip_position: Vector3, fit_rendered_bounds: bool = false) -> void:
	if parent == null:
		return
	if fit_rendered_bounds:
		var fitted: Dictionary = _blade_axis_from_rendered_bounds(parent)
		base_position = fitted.get("base", base_position)
		tip_position = fitted.get("tip", tip_position)
	blade_base_marker = Node3D.new()
	blade_base_marker.name = "BladeContactBase"
	blade_base_marker.position = base_position
	parent.add_child(blade_base_marker)
	blade_tip_marker = Node3D.new()
	blade_tip_marker.name = "BladeContactTip"
	blade_tip_marker.position = tip_position
	parent.add_child(blade_tip_marker)

func _blade_axis_from_rendered_bounds(parent: Node3D) -> Dictionary:
	var bounds := AABB()
	var has_bounds := false
	var inverse_parent := parent.global_transform.affine_inverse()
	for child in parent.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var local_transform: Transform3D = inverse_parent * mesh_instance.global_transform
		var local_bounds: AABB = local_transform * mesh_instance.mesh.get_aabb()
		bounds = bounds.merge(local_bounds) if has_bounds else local_bounds
		has_bounds = true
	if not has_bounds:
		return {}
	var axis := 0
	if bounds.size.y > bounds.size.x and bounds.size.y >= bounds.size.z:
		axis = 1
	elif bounds.size.z > bounds.size.x and bounds.size.z > bounds.size.y:
		axis = 2
	var first := bounds.get_center()
	var second := bounds.get_center()
	first[axis] = bounds.position[axis]
	second[axis] = bounds.end[axis]
	var base := first if first.length_squared() <= second.length_squared() else second
	var tip := second if base == first else first
	return {"base": base, "tip": tip}

func _handle_beam_input() -> void:
	if _action_just_pressed("oathfire_beam") and beam_cooldown <= 0.0 and beam_cast_state == "" and dodge_time <= 0.0:
		_begin_oathfire_cast()
	if beam_cast_state == "charging" and _action_pressed("oathfire_beam"):
		beam_charge_time = min(beam_charge_time + get_physics_process_delta_time(), 1.25)
		_update_beam_charge_visual()
	if beam_cast_state == "charging" and _action_just_released("oathfire_beam"):
		var ratio: float = clampf((beam_charge_time - 0.35) / 0.90, 0.0, 1.0)
		if beam_charge_time >= 0.35 and stamina_component.spend(get_oathfire_stamina_cost()):
			_commit_oathfire_release(ratio)
		elif beam_charge_time >= 0.35:
			stamina_exhausted.emit("Oathfire Beam")
			_begin_beam_redraw()
		else:
			_begin_beam_redraw()
	elif beam_cast_state == "sheathing" and _action_just_released("oathfire_beam"):
		_begin_beam_redraw()

func _begin_oathfire_cast() -> void:
	beam_cast_state = "sheathing"
	beam_phase_changed.emit("sheathing")
	beam_state_time = 0.24
	beam_charging = true
	beam_charge_time = 0.0
	beam_pending_ratio = 0.0
	beam_release_elapsed = 0.0
	beam_release_emitted = false
	_lock_beam_direction()
	_set_sword_sheathed(true)

func _commit_oathfire_release(ratio: float) -> void:
	beam_pending_ratio = clampf(ratio, 0.0, 1.0)
	beam_release_elapsed = 0.0
	beam_release_emitted = false
	beam_cooldown = get_oathfire_cooldown_duration()
	attack_cooldown = 0.75
	beam_charging = false
	beam_cast_state = "releasing"
	beam_phase_changed.emit("releasing")
	beam_state_time = 0.34
	_update_beam_charge_visual()

func _update_beam_sequence(delta: float) -> void:
	if beam_cast_state == "":
		return
	if beam_locked_direction.length_squared() > 0.5:
		face_target(global_position + beam_locked_direction * 4.0)
	beam_state_time = max(beam_state_time - delta, 0.0)
	if beam_cast_state == "sheathing" and beam_state_time <= 0.0:
		if _action_pressed("oathfire_beam"):
			beam_cast_state = "charging"
			beam_phase_changed.emit("charging")
			beam_state_time = 0.0
			if animation_driver != null:
				animation_driver.trigger_action("beam_cast")
			_update_beam_charge_visual()
		else:
			_begin_beam_redraw()
	elif beam_cast_state == "releasing":
		beam_release_elapsed += delta
		_update_beam_charge_visual()
		if not beam_release_emitted and beam_release_elapsed >= 0.11:
			beam_release_emitted = true
			beam_requested.emit(beam_pending_ratio, beam_locked_direction)
			_hide_beam_charge_visuals()
		if beam_state_time <= 0.0:
			_begin_beam_redraw()
	elif beam_cast_state == "redrawing" and beam_state_time <= 0.0:
		beam_cast_state = ""
		beam_charging = false
		beam_charge_time = 0.0
		beam_locked_direction = Vector3.ZERO
		beam_pending_ratio = 0.0
		beam_release_elapsed = 0.0
		beam_release_emitted = false
		_set_sword_sheathed(false)

func _begin_beam_redraw() -> void:
	beam_charging = false
	beam_cast_state = "redrawing"
	beam_phase_changed.emit("redrawing")
	beam_state_time = 0.24
	_hide_beam_charge_visuals()
	if animation_driver != null and animation_driver.has_method("stop_action"):
		animation_driver.stop_action("idle", 0.12)

func cancel_beam_charge() -> void:
	beam_charging = false
	beam_charge_time = 0.0
	beam_cast_state = ""
	beam_phase_changed.emit("cancelled")
	beam_state_time = 0.0
	beam_locked_direction = Vector3.ZERO
	beam_pending_ratio = 0.0
	beam_release_elapsed = 0.0
	beam_release_emitted = false
	_hide_beam_charge_visuals()
	if animation_driver != null and animation_driver.has_method("stop_action"):
		animation_driver.stop_action("idle", 0.12)
	_set_sword_sheathed(false)

func _lock_beam_direction() -> Vector3:
	beam_locked_direction = -global_transform.basis.z
	beam_locked_direction.y = 0.0
	if beam_locked_direction.length_squared() < 0.5:
		beam_locked_direction = Vector3.FORWARD
	beam_locked_direction = beam_locked_direction.normalized()
	return beam_locked_direction

func get_beam_locked_direction() -> Vector3:
	return beam_locked_direction

func get_oathfire_origin() -> Vector3:
	var left: Vector3 = beam_left_hand_glow.global_position if beam_left_hand_glow != null else global_position + Vector3(-0.16, 1.28, -0.48)
	var right: Vector3 = beam_right_hand_glow.global_position if beam_right_hand_glow != null else global_position + Vector3(0.16, 1.28, -0.48)
	var direction: Vector3 = beam_locked_direction if beam_locked_direction.length_squared() > 0.5 else -global_transform.basis.z.normalized()
	return left.lerp(right, 0.5) + direction * 0.24

func _update_beam_charge_visual() -> void:
	if beam_charge_visual == null:
		return
	beam_charge_visual.visible = true
	var ratio: float = beam_pending_ratio if beam_cast_state == "releasing" else clampf(beam_charge_time / 1.25, 0.0, 1.0)
	var pulse: float = 1.0 + sin(Time.get_ticks_msec() * 0.018) * 0.07
	beam_charge_visual.scale = Vector3.ONE * lerpf(0.12, 0.42, ratio) * pulse
	beam_charge_visual.global_position = get_oathfire_origin()
	if beam_left_hand_glow != null:
		beam_left_hand_glow.visible = true
		beam_left_hand_glow.scale = Vector3.ONE * lerpf(0.65, 1.25, ratio)
	if beam_right_hand_glow != null:
		beam_right_hand_glow.visible = true
		beam_right_hand_glow.scale = Vector3.ONE * lerpf(0.65, 1.25, ratio)

func _hide_beam_charge_visuals() -> void:
	for glow in [beam_charge_visual, beam_left_hand_glow, beam_right_hand_glow]:
		if glow != null:
			glow.visible = false

func _set_sword_sheathed(sheathed: bool) -> void:
	if weapon_root != null:
		weapon_root.visible = not sheathed
	if rig_sword_visual != null:
		rig_sword_visual.visible = not sheathed
	if sheathed_sword_visual != null:
		sheathed_sword_visual.visible = sheathed

func is_blocking() -> bool:
	return _action_pressed("block") and stamina_component.stamina > 8.0

func take_damage(amount: float) -> bool:
	if dodge_time > 0.0:
		return false
	if parry_window > 0.0 and stamina_component.spend(10.0):
		parry_window = 0.0
		hurt_flash_time = 0.08
		hurt_react_time = 0.14
		if animation_driver != null:
			animation_driver.trigger_action("hit")
		parried.emit()
		return true
	if is_blocking() and stamina_component.spend(12.0):
		var reduced = amount * 0.25
		health_component.damage(reduced)
		hurt_flash_time = 0.10
		hurt_react_time = 0.13
		if animation_driver != null:
			animation_driver.trigger_action("hit")
		blocked.emit(reduced)
	else:
		health_component.damage(amount)
		hurt_flash_time = 0.18
		hurt_react_time = 0.20
		if animation_driver != null:
			animation_driver.trigger_action("hit")
		hurt.emit(amount)
	return false

func face_target(target_pos: Vector3) -> void:
	var flat = Vector3(target_pos.x, global_position.y, target_pos.z)
	if flat.distance_to(global_position) > 0.1:
		look_at(flat, Vector3.UP)

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y <= 0.0:
		velocity.y = -0.1

func _on_died() -> void:
	cancel_beam_charge()
	can_control = false
	if animation_driver != null:
		animation_driver.set_dead()
	died.emit()

func _build_body() -> void:
	visual_root = Node3D.new()
	add_child(visual_root)
	var collision = CollisionShape3D.new()
	var capsule_shape = CapsuleShape3D.new()
	capsule_shape.height = CharacterRoleSpec.collision_height("player_human", 1.65)
	capsule_shape.radius = CharacterRoleSpec.collision_radius("player_human", 0.32)
	collision.shape = capsule_shape
	collision.position.y = capsule_shape.height * 0.5 + capsule_shape.radius * 0.18
	add_child(collision)
	if _try_build_mapped_body():
		CharacterPresentation.apply_player(self, visual_root)
		_add_beam_charge_visual()
		return

	var cloak = MeshInstance3D.new()
	var cloak_mesh = BoxMesh.new()
	cloak_mesh.size = Vector3(0.74, 1.08, 0.18)
	cloak.mesh = cloak_mesh
	cloak.position = Vector3(0, 1.0, 0.22)
	cloak.rotation_degrees.x = -6
	cloak.material_override = _mat(Color(0.10, 0.11, 0.10))
	visual_root.add_child(cloak)

	var body = MeshInstance3D.new()
	var mesh = CapsuleMesh.new()
	mesh.height = 1.45
	mesh.radius = 0.34
	body.mesh = mesh
	body.position.y = 0.92
	body.material_override = _mat(Color(0.24, 0.27, 0.25))
	visual_root.add_child(body)
	body_visual = body

	var chest = MeshInstance3D.new()
	var chest_mesh = BoxMesh.new()
	chest_mesh.size = Vector3(0.72, 0.42, 0.24)
	chest.mesh = chest_mesh
	chest.position = Vector3(0, 1.25, -0.02)
	chest.material_override = _mat(Color(0.17, 0.18, 0.17))
	visual_root.add_child(chest)

	var head = MeshInstance3D.new()
	head.mesh = SphereMesh.new()
	head.scale = Vector3(0.34, 0.28, 0.34)
	head.position.y = 1.78
	head.material_override = _mat(Color(0.72, 0.66, 0.57))
	visual_root.add_child(head)

	var scar = MeshInstance3D.new()
	var scar_mesh = BoxMesh.new()
	scar_mesh.size = Vector3(0.03, 0.2, 0.01)
	scar.mesh = scar_mesh
	scar.position = Vector3(0.11, 1.81, -0.31)
	scar.rotation_degrees.z = 18
	scar.material_override = _mat(Color(0.45, 0.09, 0.07))
	visual_root.add_child(scar)

	_add_weapon_visuals(Vector3(0.43, 0.86, -0.38))
	CharacterPresentation.apply_player(self, visual_root)
	_add_beam_charge_visual()

func _add_beam_charge_visual() -> void:
	beam_charge_visual = MeshInstance3D.new()
	beam_charge_visual.name = "OathfireChargeSphere"
	beam_charge_visual.mesh = SphereMesh.new()
	beam_charge_visual.material_override = _beam_material(Color(0.35, 0.88, 1.0, 0.92))
	beam_charge_visual.visible = false
	add_child(beam_charge_visual)
	var skeleton := _find_skeleton(visual_root)
	beam_left_hand_glow = _make_oathfire_hand("OathfireLeftHand", skeleton, ["LeftHand", "Hand.L", "lefthand", "leftwrist"], Vector3(-0.28, 1.22, -0.42))
	beam_right_hand_glow = _make_oathfire_hand("OathfireRightHand", skeleton, ["RightHand", "Hand.R", "righthand", "rightwrist"], Vector3(0.28, 1.22, -0.42))
	_build_sheathed_sword()

func _make_oathfire_hand(node_name: String, skeleton: Skeleton3D, aliases: Array[String], fallback_position: Vector3) -> MeshInstance3D:
	var glow := MeshInstance3D.new()
	glow.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = 0.10
	mesh.height = 0.20
	glow.mesh = mesh
	glow.material_override = _beam_material(Color(0.38, 0.82, 1.0, 0.58))
	glow.visible = false
	var socket_parent: Node3D = visual_root
	if skeleton != null:
		var hand_index := _find_bone_index(skeleton, aliases)
		if hand_index < 0:
			var wants_left := node_name.contains("Left")
			for bone_index in range(skeleton.get_bone_count()):
				var bone_name := str(skeleton.get_bone_name(bone_index)).to_lower()
				var is_hand := bone_name.contains("hand") or bone_name.contains("wrist")
				var is_side := bone_name.contains("left") or bone_name.contains("_l") or bone_name.ends_with(".l") if wants_left else bone_name.contains("right") or bone_name.contains("_r") or bone_name.ends_with(".r")
				if is_hand and is_side:
					hand_index = bone_index
					break
		if hand_index >= 0:
			var attachment := BoneAttachment3D.new()
			attachment.name = "%sSocket" % node_name
			attachment.bone_idx = hand_index
			attachment.bone_name = skeleton.get_bone_name(hand_index)
			skeleton.add_child(attachment)
			# Imported rigs carry source-scale transforms on their skeleton. Cancel
			# that scale before adding the glow so a 20 cm hand effect cannot become
			# a multi-metre object or corrupt the rendered character bounds.
			socket_parent = _create_equipment_space(attachment, "%sEquipmentSpace" % node_name)
			if node_name.contains("Left"):
				beam_left_hand_socket = attachment
			else:
				beam_right_hand_socket = attachment
	socket_parent.add_child(glow)
	if socket_parent == visual_root:
		glow.position = fallback_position
	return glow

func _build_sheathed_sword() -> void:
	# The imported sword has an inconsistent source scale. Reuse the authored
	# Oathblade mesh so the hand and back versions have identical proportions.
	var socket_parent: Node3D = visual_root
	var skeleton := _find_skeleton(visual_root)
	if skeleton != null:
		var back_index := _find_bone_index(skeleton, ["Spine2", "Chest", "Torso", "Spine"])
		if back_index >= 0:
			var attachment := BoneAttachment3D.new()
			attachment.name = "KaelBackSwordSocket"
			attachment.bone_idx = back_index
			attachment.bone_name = skeleton.get_bone_name(back_index)
			skeleton.add_child(attachment)
			socket_parent = _create_equipment_space(attachment, "KaelBackSwordEquipmentSpace")
	sheathed_sword_visual = _build_oathblade_visual(socket_parent)
	sheathed_sword_visual.name = "OathfireSheathedSword"
	sheathed_sword_visual.position = Vector3(-0.22, 0.10, 0.15) if socket_parent != visual_root else Vector3(-0.24, 1.46, 0.22)
	sheathed_sword_visual.rotation_degrees = Vector3(-8, 4, -18)
	sheathed_sword_visual.scale = Vector3.ONE * 0.92
	sheathed_sword_visual.visible = false

func _try_build_mapped_body() -> bool:
	asset_helper = AssetSpawnHelper.new()
	add_child(asset_helper)
	var mapped: Node3D = null
	if asset_helper.has_method("has_visual_role") and asset_helper.has_method("spawn_visual_role") and asset_helper.has_visual_role("player_human"):
		mapped = asset_helper.spawn_visual_role("player_human", "characters")
	if mapped == null or mapped.name.ends_with("_placeholder"):
		if mapped != null:
			mapped.queue_free()
		mapped = asset_helper.spawn_character("player_kael")
	if mapped == null or mapped.name.ends_with("_placeholder"):
		if mapped != null:
			mapped.queue_free()
		return false
	mapped.name = "player_kael_visual"
	visual_root.add_child(mapped)
	var imported_sword := mapped.find_child("Warrior_Sword", true, false) as Node3D
	if imported_sword != null:
		imported_sword.visible = false
	rig_sword_visual = _attach_rig_sword(mapped)
	if rig_sword_visual != null:
		# Oathblade geometry is authored along local -Y. Keep the contact
		# contract on that same axis so the damage sweep and the rendered blade
		# cannot diverge into the old detached-pole presentation.
		_configure_blade_markers(rig_sword_visual, Vector3(0, -0.08, 0), Vector3(0, -1.04, 0), true)
		# Establish the authored ready pose before the first physics tick. Capture
		# tools and dialogue staging can sample the rig before _animate_visuals runs;
		# leaving the imported hand axis untouched makes the sword read as a pole.
		_update_sword_equipment_pose(0.0, 0.0, 0.0, false, false)
	body_visual = _find_first_mesh(mapped)
	_apply_visible_material_fallbacks(mapped, _mat(Color(0.18, 0.20, 0.18)))
	if body_visual != null and body_visual.material_override is StandardMaterial3D:
		body_base_color = (body_visual.material_override as StandardMaterial3D).albedo_color
	animation_driver = CharacterAnimationDriver.new()
	animation_driver.name = "CharacterAnimationDriver"
	mapped.add_child(animation_driver)
	var animated: bool = bool(animation_driver.configure(mapped, {
		"idle": "Idle_Loop", "walk": "Zombie_Walk_Fwd", "walk_back": "Zombie_Walk_Back",
		"strafe": "Walk_Carry", "run": "Walk_Carry",
		"jump": "NinjaJump_Start", "attack_light": "Sword_Regular_A",
		"attack_heavy": "Sword_Regular_B", "dodge": "Slide",
		"parry": "Sword_Block", "beam_cast": "Idle_Shield", "hit": "Hit_Knockback", "death": "Hit_Knockback"
	}))
	if not animated:
		_add_mapped_weapon_visuals()
	else:
		animation_driver.set_update_rate_hz(30.0)
		_add_slash_arc_visuals()
	return true

func _attach_rig_sword(mapped: Node3D) -> Node3D:
	var skeleton := _find_skeleton(mapped)
	if skeleton == null:
		return null
	var hand_index := skeleton.find_bone("RightHand")
	if hand_index < 0:
		hand_index = skeleton.find_bone("Hand.R")
	if hand_index < 0:
		hand_index = skeleton.find_bone("hand_r")
	if hand_index < 0:
		for bone_index in range(skeleton.get_bone_count()):
			var bone_name := str(skeleton.get_bone_name(bone_index)).to_lower()
			if bone_name.contains("right") and (bone_name.contains("hand") or bone_name.contains("wrist")):
				hand_index = bone_index
				break
	if hand_index < 0:
		for bone_index in range(skeleton.get_bone_count()):
			var bone_name := str(skeleton.get_bone_name(bone_index)).to_lower()
			if bone_name.contains("hand") or bone_name.contains("wrist"):
				hand_index = bone_index
				break
	if hand_index < 0:
		return null
	var attachment := BoneAttachment3D.new()
	attachment.name = "KaelSwordSocket"
	attachment.bone_idx = hand_index
	attachment.bone_name = skeleton.get_bone_name(hand_index)
	skeleton.add_child(attachment)
	sword_attachment = attachment
	var equipment_space := _create_equipment_space(attachment, "KaelSwordEquipmentSpace")
	sword_equipment_pivot = Node3D.new()
	sword_equipment_pivot.name = "KaelSwordGripPivot"
	equipment_space.add_child(sword_equipment_pivot)
	# Follow the hand position, but own the blade orientation so imported wrist axes
	# cannot turn the weapon into an upright pole.
	sword_equipment_pivot.top_level = true
	# The imported FBX had null Compatibility surfaces and was hidden
	# immediately. Use the validated Web-safe weapon directly.
	return _build_oathblade_visual(sword_equipment_pivot)

func _build_oathblade_visual(parent: Node3D) -> Node3D:
	var oathblade := Node3D.new()
	oathblade.name = "KaelOathblade"
	# Keep the blade readable at gameplay distance without letting a one-metre
	# local mesh read as a pole beside a 1.78 m character. The hand, markers,
	# slash ribbon, and collision all use this same normalized weapon scale.
	oathblade.scale = Vector3.ONE * 0.92
	parent.add_child(oathblade)
	var steel := _metal_mat(Color(0.84, 0.88, 0.92))
	steel.metallic = 0.72
	steel.roughness = 0.20
	steel.emission_enabled = true
	steel.emission = Color(0.055, 0.065, 0.075)
	steel.emission_energy_multiplier = 0.22
	steel.emission_enabled = false
	steel.cull_mode = BaseMaterial3D.CULL_DISABLED
	var blade := MeshInstance3D.new()
	blade.name = "OathbladeSteel"
	blade.mesh = _build_oathblade_mesh()
	blade.material_override = steel
	oathblade.add_child(blade)
	var guard := MeshInstance3D.new()
	guard.name = "OathbladeGuard"
	var guard_mesh := BoxMesh.new()
	guard_mesh.size = Vector3(0.34, 0.060, 0.082)
	guard.mesh = guard_mesh
	guard.position = Vector3(0.0, -0.075, 0.0)
	guard.material_override = _metal_mat(Color(0.64, 0.43, 0.17))
	oathblade.add_child(guard)
	var grip := MeshInstance3D.new()
	grip.name = "OathbladeGrip"
	var grip_mesh := CylinderMesh.new()
	grip_mesh.top_radius = 0.033
	grip_mesh.bottom_radius = 0.038
	grip_mesh.height = 0.22
	grip_mesh.radial_segments = 8
	grip.mesh = grip_mesh
	grip.position = Vector3(0.0, 0.065, 0.0)
	grip.material_override = _mat(Color(0.18, 0.07, 0.035))
	oathblade.add_child(grip)
	var pommel := MeshInstance3D.new()
	pommel.name = "OathbladePommel"
	var pommel_mesh := SphereMesh.new()
	pommel_mesh.radius = 0.055
	pommel_mesh.height = 0.11
	pommel.mesh = pommel_mesh
	pommel.position = Vector3(0.0, 0.18, 0.0)
	pommel.material_override = _metal_mat(Color(0.52, 0.34, 0.15))
	oathblade.add_child(pommel)
	return oathblade

func _build_oathblade_mesh() -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	var vertices := [
		Vector3(-0.112, -0.09, 0.035), Vector3(0.112, -0.09, 0.035), Vector3(0.0, -0.98, 0.022),
		Vector3(-0.112, -0.09, -0.035), Vector3(0.112, -0.09, -0.035), Vector3(0.0, -0.98, -0.022)
	]
	var faces := [[0, 2, 1], [3, 4, 5], [0, 1, 4], [0, 4, 3], [0, 3, 5], [0, 5, 2], [1, 2, 5], [1, 5, 4]]
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in faces:
		var a: Vector3 = vertices[face[0]]
		var b: Vector3 = vertices[face[1]]
		var c: Vector3 = vertices[face[2]]
		var normal := (b - a).cross(c - a).normalized()
		mesh.surface_set_normal(normal)
		mesh.surface_add_vertex(a)
		mesh.surface_set_normal(normal)
		mesh.surface_add_vertex(b)
		mesh.surface_set_normal(normal)
		mesh.surface_add_vertex(c)
	mesh.surface_end()
	return mesh

func _update_sword_equipment_pose(windup: float, strike: float, recovery: float, heavy: bool, attacking: bool) -> void:
	if sword_equipment_pivot == null or sword_attachment == null:
		return
	var forward := -global_transform.basis.z.normalized()
	var right := global_transform.basis.x.normalized()
	# Keep the ready blade down and outside the torso instead of crossing the
	# chest. The attack states still own the full swing arc below.
	var idle_direction := (Vector3.DOWN * 0.78 + right * 0.54).normalized()
	var blade_direction := idle_direction
	if attacking:
		var windup_direction: Vector3
		var strike_direction: Vector3
		if heavy:
			windup_direction = (Vector3.UP * 0.90 - forward * 0.25 + right * 0.34).normalized()
			strike_direction = (Vector3.DOWN * 0.72 + forward * 0.62 - right * 0.24).normalized()
		else:
			windup_direction = (right * 0.82 + Vector3.UP * 0.40 - forward * 0.24).normalized()
			strike_direction = (-right * 0.62 + Vector3.DOWN * 0.12 + forward * 0.90).normalized()
		blade_direction = idle_direction.slerp(windup_direction, smoothstep(0.0, 1.0, windup))
		if strike > 0.0:
			blade_direction = windup_direction.slerp(strike_direction, smoothstep(0.0, 1.0, strike))
		if recovery > 0.0:
			blade_direction = strike_direction.slerp(idle_direction, smoothstep(0.0, 1.0, recovery))
	var hand_position := sword_attachment.global_position + right * 0.018 + Vector3.UP * 0.012
	var blade_basis := Basis(Quaternion(Vector3.DOWN, blade_direction)).orthonormalized()
	sword_equipment_pivot.global_transform = Transform3D(blade_basis, hand_position)

func _make_sword_readable(sword: Node3D) -> void:
	var blade_material := _metal_mat(Color(0.72, 0.78, 0.82))
	blade_material.metallic = 0.72
	blade_material.roughness = 0.30
	var found_mesh := false
	for child in sword.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		found_mesh = true
		mesh_instance.visible = true
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mesh_instance.material_override = blade_material
	if found_mesh:
		return
	var blade := MeshInstance3D.new()
	blade.name = "KaelReadableSwordBlade"
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.065, 1.02, 0.035)
	blade.mesh = blade_mesh
	blade.position = Vector3(0.0, -0.53, 0.0)
	blade.material_override = blade_material
	sword.add_child(blade)
	var guard := MeshInstance3D.new()
	guard.name = "KaelReadableSwordGuard"
	var guard_mesh := BoxMesh.new()
	guard_mesh.size = Vector3(0.28, 0.055, 0.055)
	guard.mesh = guard_mesh
	guard.position = Vector3(0.0, -0.02, 0.0)
	guard.material_override = _metal_mat(Color(0.42, 0.32, 0.18))
	sword.add_child(guard)

func _create_equipment_space(attachment: BoneAttachment3D, space_name: String) -> Node3D:
	var equipment_space := Node3D.new()
	equipment_space.name = space_name
	attachment.add_child(equipment_space)
	var inherited_scale := attachment.global_basis.get_scale()
	equipment_space.scale = Vector3(
		1.0 / max(abs(inherited_scale.x), 0.0001),
		1.0 / max(abs(inherited_scale.y), 0.0001),
		1.0 / max(abs(inherited_scale.z), 0.0001)
	)
	return equipment_space

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

func _find_bone_index(skeleton: Skeleton3D, aliases: Array[String]) -> int:
	for alias in aliases:
		var exact := skeleton.find_bone(alias)
		if exact >= 0:
			return exact
	for bone_index in range(skeleton.get_bone_count()):
		var normalized := str(skeleton.get_bone_name(bone_index)).to_lower().replace("_", "").replace(".", "").replace(" ", "")
		for alias in aliases:
			var wanted := alias.to_lower().replace("_", "").replace(".", "").replace(" ", "")
			if normalized.contains(wanted):
				return bone_index
	return -1

func _find_first_mesh(root: Node) -> MeshInstance3D:
	if root is MeshInstance3D:
		return root
	for child in root.get_children():
		var found = _find_first_mesh(child)
		if found != null:
			return found
	return null

func _add_mapped_weapon_visuals() -> void:
	_add_weapon_visuals(Vector3(0.42, 0.84, -0.42))

func _add_weapon_visuals(local_pos: Vector3) -> void:
	weapon_root = Node3D.new()
	weapon_root.name = "visible_sword_root"
	weapon_root.position = local_pos
	weapon_root.rotation_degrees = _weapon_ready_pose()
	visual_root.add_child(weapon_root)

	var sword = MeshInstance3D.new()
	sword.name = "visible_sword_blade"
	var sword_mesh = BoxMesh.new()
	sword_mesh.size = Vector3(0.105, 0.060, 1.78)
	sword.mesh = sword_mesh
	sword.position = Vector3(0.0, 0.28, -0.66)
	sword.material_override = _metal_mat(Color(0.68, 0.70, 0.68))
	weapon_root.add_child(sword)
	sword_visual = sword
	_configure_blade_markers(weapon_root, Vector3(0.0, 0.25, 0.02), Vector3(0.0, 0.28, -1.56))

	var hilt = MeshInstance3D.new()
	hilt.name = "visible_sword_hilt"
	var hilt_mesh = BoxMesh.new()
	hilt_mesh.size = Vector3(0.42, 0.080, 0.095)
	hilt.mesh = hilt_mesh
	hilt.position = Vector3(0.0, -0.04, 0.03)
	hilt.material_override = _mat(Color(0.13, 0.08, 0.045))
	weapon_root.add_child(hilt)
	sword_hilt_visual = hilt

	var pommel = MeshInstance3D.new()
	pommel.name = "visible_sword_pommel"
	var pommel_mesh = BoxMesh.new()
	pommel_mesh.size = Vector3(0.13, 0.13, 0.13)
	pommel.mesh = pommel_mesh
	pommel.position = Vector3(0.0, -0.15, 0.14)
	pommel.material_override = _metal_mat(Color(0.37, 0.34, 0.28))
	weapon_root.add_child(pommel)

	var trail = MeshInstance3D.new()
	trail.name = "visible_sword_swing_trail"
	var trail_mesh = BoxMesh.new()
	trail_mesh.size = Vector3(0.24, 0.16, 2.45)
	trail.mesh = trail_mesh
	trail.position = Vector3(0.30, 0.34, -0.92)
	trail.rotation_degrees.z = -24.0
	trail.material_override = _trail_mat(Color(1.0, 0.78, 0.36, 0.88))
	trail.visible = false
	weapon_root.add_child(trail)
	sword_trail_visual = trail
	_add_slash_arc_visuals()

func _weapon_ready_pose() -> Vector3:
	return Vector3(18, 0, 8)

func _add_motion_proxy_parts() -> void:
	left_arm_proxy = _add_proxy_box("left_motion_arm", Vector3(-0.43, 1.16, -0.04), Vector3(0.12, 0.64, 0.13), Color(0.10, 0.11, 0.10))
	right_arm_proxy = _add_proxy_box("right_weapon_arm", Vector3(0.43, 1.13, -0.04), Vector3(0.12, 0.58, 0.13), Color(0.11, 0.10, 0.085))
	left_leg_proxy = _add_proxy_box("left_motion_leg", Vector3(-0.16, 0.52, -0.01), Vector3(0.14, 0.70, 0.14), Color(0.075, 0.070, 0.065))
	right_leg_proxy = _add_proxy_box("right_motion_leg", Vector3(0.16, 0.52, -0.01), Vector3(0.14, 0.70, 0.14), Color(0.075, 0.070, 0.065))
	cloak_motion_proxy = _add_proxy_box("cloak_motion_read", Vector3(0.0, 0.98, 0.26), Vector3(0.68, 0.98, 0.12), Color(0.055, 0.065, 0.055))

func _add_slash_arc_visuals() -> void:
	slash_arc_root = Node3D.new()
	slash_arc_root.name = "visible_sword_slash_arc_root"
	slash_arc_root.position = Vector3(0.48, 1.18, -0.78)
	slash_arc_root.visible = false
	visual_root.add_child(slash_arc_root)
	slash_arc_primary = _add_slash_panel("visible_sword_slash_arc_primary", Vector3.ZERO, Vector3(0.045, 0.10, 1.0), Color(1.0, 0.84, 0.52, 0.34))
	slash_arc_secondary = _add_slash_panel("visible_sword_slash_arc_secondary", Vector3(0.07, -0.04, 0.05), Vector3(0.16, 0.08, 0.90), Color(0.70, 0.32, 0.12, 0.58))
	slash_arc_spark = _add_slash_panel("visible_sword_slash_impact_edge", Vector3(0.0, 0.0, -0.48), Vector3(0.20, 0.22, 0.16), Color(1.0, 0.80, 0.34, 0.92))

func _add_slash_panel(node_name: String, local_pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var panel = MeshInstance3D.new()
	panel.name = node_name
	var mesh = BoxMesh.new()
	mesh.size = size
	panel.mesh = mesh
	panel.position = local_pos
	panel.material_override = _trail_mat(color)
	slash_arc_root.add_child(panel)
	return panel

func _add_proxy_box(node_name: String, local_pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var proxy = MeshInstance3D.new()
	proxy.name = node_name
	var mesh = BoxMesh.new()
	mesh.size = size
	proxy.mesh = mesh
	proxy.position = local_pos
	proxy.material_override = _mat(color)
	visual_root.add_child(proxy)
	return proxy

func _animate_visuals(delta: float, move_dir: Vector3, moving: bool) -> void:
	if visual_root == null:
		return
	var running = movement_state == "run" or (_action_pressed("run") and moving)
	if animation_driver != null and animation_driver.is_valid():
		animation_driver.set_locomotion(Vector2(velocity.x, velocity.z).length() / max(run_speed, 0.1), move_dir, is_on_floor())
		if movement_state == "dodge" and animation_driver.current_state != "dodge":
			animation_driver.trigger_action("dodge")
	if moving:
		move_phase += delta * (8.7 if running else 6.2)
		step_phase += delta * (3.05 if running else 2.15)
		if step_phase >= 1.0:
			step_phase = 0.0
			footstep.emit()
	else:
		move_phase += delta * 1.45
	var speed_factor = clamp(Vector2(velocity.x, velocity.z).length() / max(run_speed, 0.1), 0.0, 1.0)
	movement_blend = lerp(movement_blend, speed_factor, 1.0 - exp(-10.0 * delta))
	strafe_blend = lerp(strafe_blend, 1.0 if movement_state == "strafe" else 0.0, 1.0 - exp(-9.0 * delta))
	backward_blend = lerp(backward_blend, 1.0 if movement_state == "backward" else 0.0, 1.0 - exp(-9.0 * delta))
	grounded_weight = lerp(grounded_weight, movement_blend, 1.0 - exp(-8.0 * delta))
	block_pose_weight = lerp(block_pose_weight, 1.0 if is_blocking() else 0.0, 14.0 * delta)
	var dodge_weight = clamp(dodge_time / 0.30, 0.0, 1.0)
	var hurt_weight = clamp(hurt_react_time / 0.20, 0.0, 1.0)
	var combat_swing_weight = 0.0
	var combat_windup_weight = 0.0
	var bob = 0.030 * sin(move_phase) * grounded_weight if moving else 0.009 * sin(move_phase)
	var idle_breath = sin(move_phase * 0.72) * (1.0 - grounded_weight)
	var pelvis_offset = (left_foot_ground_offset + right_foot_ground_offset) * 0.22
	visual_root.position.y = bob + pelvis_offset - 0.018 * grounded_weight - 0.030 * hurt_weight - 0.10 * landing_compression
	var lateral_lean = clamp(-velocity.x * 0.85, -4.0, 4.0)
	var local_normal = global_transform.basis.inverse() * smoothed_ground_normal
	var slope_pitch = rad_to_deg(atan2(local_normal.z, max(local_normal.y, 0.25)))
	var slope_roll = -rad_to_deg(atan2(local_normal.x, max(local_normal.y, 0.25)))
	var forward_lean = (-6.5 if running else -4.2) * grounded_weight if moving else 0.9 * idle_breath
	forward_lean += slope_pitch * 0.45 + 8.0 * jump_pose_weight - 11.0 * landing_compression
	forward_lean += -7.0 * dodge_weight + 5.0 * hurt_weight - 3.5 * block_pose_weight
	var root_z = lateral_lean + slope_roll * 0.50 + 4.5 * sin(move_phase) * grounded_weight + 9.0 * dodge_weight * sign(dodge_dir.x) - 3.0 * block_pose_weight
	visual_root.rotation_degrees.z = lerp(visual_root.rotation_degrees.z, root_z, 9.0 * delta)
	visual_root.rotation_degrees.x = lerp(visual_root.rotation_degrees.x, forward_lean, 9.0 * delta)
	if attack_anim_time > 0.0:
		var duration = 0.52 if attack_anim_heavy else 0.34
		var t = 1.0 - attack_anim_time / duration
		var windup = clamp(t / (0.38 if attack_anim_heavy else 0.24), 0.0, 1.0)
		var strike = clamp((t - (0.30 if attack_anim_heavy else 0.18)) / (0.34 if attack_anim_heavy else 0.24), 0.0, 1.0)
		var recovery = clamp((t - (0.64 if attack_anim_heavy else 0.52)) / (0.36 if attack_anim_heavy else 0.34), 0.0, 1.0)
		var strike_arc = sin(strike * PI)
		combat_swing_weight = strike_arc
		combat_windup_weight = windup
		var windup_angle = 34.0 if attack_anim_heavy else 18.0
		var swing = -188.0 * strike_arc if attack_anim_heavy else -124.0 * strike_arc
		var root_y = lerp(windup_angle, -18.0 if attack_anim_heavy else -10.0, strike)
		root_y = lerp(root_y, 0.0, recovery)
		visual_root.rotation_degrees.y = root_y
		visual_root.rotation_degrees.x = lerp(visual_root.rotation_degrees.x, forward_lean - (15.0 if attack_anim_heavy else 5.5) * strike_arc + (8.0 if attack_anim_heavy else 3.0) * windup, 12.0 * delta)
		if weapon_root != null:
			var weapon_pose = Vector3(38.0 - strike_arc * (68.0 if attack_anim_heavy else 48.0), swing, 20.0 + windup * (68.0 if attack_anim_heavy else 42.0) + strike_arc * (110.0 if attack_anim_heavy else 82.0))
			weapon_root.rotation_degrees = weapon_pose
			weapon_root.position = weapon_root.position.lerp(Vector3(0.42, 0.84, -0.42) + Vector3(0.20 * strike_arc, 0.08 * windup, -0.26 * strike_arc), 14.0 * delta)
			# The old fallback box trail detached from the hand and read as a
			# second oversized sword. The measured blade ribbon below is the only
			# attack trail now.
			if sword_trail_visual != null:
				sword_trail_visual.visible = false
		_update_sword_equipment_pose(windup, strike, recovery, attack_anim_heavy, true)
		_animate_slash_arc(strike, strike_arc, recovery, attack_anim_heavy)
	else:
		visual_root.rotation_degrees.y = lerp(visual_root.rotation_degrees.y, 0.0, 10.0 * delta)
		var ready_pose = Vector3(14.0 - block_pose_weight * 20.0, block_pose_weight * -22.0, 8.0 + block_pose_weight * 18.0)
		if weapon_root != null:
			weapon_root.rotation_degrees = weapon_root.rotation_degrees.lerp(ready_pose, 12.0 * delta)
			weapon_root.position = weapon_root.position.lerp(Vector3(0.42, 0.84, -0.42), 10.0 * delta)
		if sword_trail_visual != null:
			sword_trail_visual.visible = false
		if slash_arc_root != null:
			slash_arc_root.visible = false
		_update_sword_equipment_pose(0.0, 0.0, 0.0, false, false)
	if beam_cast_state != "":
		var cast_weight := 1.0 if beam_cast_state in ["charging", "releasing"] else 0.55
		visual_root.rotation_degrees.x = lerp(visual_root.rotation_degrees.x, -4.0 * cast_weight, 12.0 * delta)
		visual_root.rotation_degrees.y = lerp(visual_root.rotation_degrees.y, 0.0, 12.0 * delta)
		if slash_arc_root != null:
			slash_arc_root.visible = false
	_animate_motion_proxies(delta, moving, movement_blend, dodge_weight, hurt_weight, block_pose_weight, combat_windup_weight, combat_swing_weight)
	if body_visual != null:
		var mat = body_visual.material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_color = body_base_color.lerp(Color(0.72, 0.22, 0.12), 0.72) if hurt_flash_time > 0.0 else body_base_color

func _animate_motion_proxies(delta: float, moving: bool, speed_factor: float, dodge_weight: float, hurt_weight: float, block_weight: float, windup_weight: float, swing_weight: float) -> void:
	var gait = sin(move_phase)
	var stride = clamp(speed_factor * 1.25, 0.0, 1.0)
	var idle_weight = 1.0 - stride
	var idle_breath = sin(move_phase * 0.72)
	var arm_amount = (68.0 if movement_state == "run" else 52.0) * stride
	var leg_amount = (62.0 if movement_state == "run" else 48.0) * stride
	var strafe_twist = strafe_blend * sign(velocity.x) * 18.0
	var backward_sign = lerp(1.0, -0.72, backward_blend)
	if left_arm_proxy != null:
		left_arm_proxy.rotation_degrees.x = lerp(left_arm_proxy.rotation_degrees.x, -gait * arm_amount * backward_sign - 12.0 * block_weight + 10.0 * hurt_weight + idle_breath * 4.0 * idle_weight, 12.0 * delta)
		left_arm_proxy.rotation_degrees.z = lerp(left_arm_proxy.rotation_degrees.z, -10.0 - 12.0 * block_weight - 14.0 * swing_weight, 12.0 * delta)
	if right_arm_proxy != null:
		right_arm_proxy.rotation_degrees.x = lerp(right_arm_proxy.rotation_degrees.x, gait * arm_amount * 0.60 * backward_sign - 34.0 * windup_weight - 54.0 * swing_weight - 20.0 * block_weight, 13.0 * delta)
		right_arm_proxy.rotation_degrees.z = lerp(right_arm_proxy.rotation_degrees.z, 12.0 + 38.0 * swing_weight + 12.0 * block_weight, 13.0 * delta)
	if left_leg_proxy != null:
		left_leg_proxy.rotation_degrees.x = lerp(left_leg_proxy.rotation_degrees.x, gait * leg_amount * backward_sign - 24.0 * dodge_weight - 16.0 * jump_pose_weight, 13.0 * delta)
		left_leg_proxy.rotation_degrees.z = lerp(left_leg_proxy.rotation_degrees.z, strafe_twist, 11.0 * delta)
		left_leg_proxy.position.y = lerp(left_leg_proxy.position.y, 0.52 + left_foot_ground_offset + max(0.0, -gait) * 0.10 * stride + 0.08 * jump_pose_weight, 14.0 * delta)
	if right_leg_proxy != null:
		right_leg_proxy.rotation_degrees.x = lerp(right_leg_proxy.rotation_degrees.x, -gait * leg_amount * backward_sign - 24.0 * dodge_weight + 16.0 * jump_pose_weight, 13.0 * delta)
		right_leg_proxy.rotation_degrees.z = lerp(right_leg_proxy.rotation_degrees.z, strafe_twist, 11.0 * delta)
		right_leg_proxy.position.y = lerp(right_leg_proxy.position.y, 0.52 + right_foot_ground_offset + max(0.0, gait) * 0.10 * stride + 0.08 * jump_pose_weight, 14.0 * delta)
	if cloak_motion_proxy != null:
		var cloak_sway = (9.0 * gait * stride) + 15.0 * dodge_weight + strafe_twist * 0.35
		cloak_motion_proxy.rotation_degrees.x = lerp(cloak_motion_proxy.rotation_degrees.x, -5.0 - 10.0 * stride - 10.0 * jump_pose_weight + 15.0 * dodge_weight + 11.0 * swing_weight + 2.0 * idle_breath * idle_weight, 9.0 * delta)
		cloak_motion_proxy.rotation_degrees.z = lerp(cloak_motion_proxy.rotation_degrees.z, cloak_sway, 9.0 * delta)

func _animate_slash_arc(strike: float, strike_arc: float, recovery: float, heavy: bool) -> void:
	if slash_arc_root == null:
		return
	var visible = strike > 0.08 and strike < 0.94 and recovery < 0.86
	slash_arc_root.visible = visible
	if not visible:
		visual_previous_blade_base = Vector3.ZERO
		visual_previous_blade_tip = Vector3.ZERO
		return
	var segment: Dictionary = get_blade_world_segment()
	var blade_base: Vector3 = segment.get("base", global_position + Vector3(0, 1.0, 0))
	var blade_tip: Vector3 = segment.get("tip", blade_base)
	var old_base: Vector3 = visual_previous_blade_base if visual_previous_blade_base.length_squared() > 0.01 else blade_base
	var old_tip: Vector3 = visual_previous_blade_tip if visual_previous_blade_tip.length_squared() > 0.01 else blade_tip
	if old_tip.distance_to(blade_tip) > 1.10:
		old_base = blade_base
		old_tip = blade_tip
	slash_arc_root.global_transform = Transform3D.IDENTITY
	if slash_arc_primary != null:
		slash_arc_primary.visible = true
		slash_arc_primary.position = Vector3.ZERO
		slash_arc_primary.rotation = Vector3.ZERO
		slash_arc_primary.scale = Vector3.ONE
		slash_arc_primary.mesh = _build_blade_ribbon(old_base, old_tip, blade_base, blade_tip)
	if slash_arc_secondary != null:
		slash_arc_secondary.visible = false
	if slash_arc_spark != null:
		slash_arc_spark.visible = false
	visual_previous_blade_base = blade_base
	visual_previous_blade_tip = blade_tip

func _build_blade_ribbon(old_base: Vector3, old_tip: Vector3, blade_base: Vector3, blade_tip: Vector3) -> ImmediateMesh:
	var ribbon := ImmediateMesh.new()
	var width_axis := Vector3.RIGHT
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		width_axis = camera.global_transform.basis.x.normalized()
	var width := width_axis * 0.028
	ribbon.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	# Build two thin screen-facing strips around the measured blade sweep. This
	# keeps the slash readable when the real sword moves almost edge-on to the
	# camera, while preserving the actual blade base/tip path.
	for side in [-1.0, 1.0]:
		var offset: Vector3 = width * side
		ribbon.surface_add_vertex(old_base + offset)
		ribbon.surface_add_vertex(old_tip + offset)
		ribbon.surface_add_vertex(blade_tip + offset)
		ribbon.surface_add_vertex(old_base + offset)
		ribbon.surface_add_vertex(blade_tip + offset)
		ribbon.surface_add_vertex(blade_base + offset)
	ribbon.surface_end()
	return ribbon

func _mat(color: Color) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	return material

func _metal_mat(color: Color) -> StandardMaterial3D:
	var material = _mat(color)
	material.metallic = 0.38
	material.roughness = 0.48
	return material

func _trail_mat(color: Color) -> StandardMaterial3D:
	var material = _mat(color)
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.emission_enabled = true
	material.emission = Color(1.0, 0.76, 0.42)
	material.emission_energy_multiplier = 0.24
	return material

func _beam_material(color: Color) -> StandardMaterial3D:
	var material = _trail_mat(color)
	material.emission = Color(0.25, 0.82, 1.0)
	material.emission_energy_multiplier = 2.2
	return material

func _apply_visible_material_fallbacks(root: Node, fallback: Material) -> void:
	if root is MeshInstance3D:
		var mesh_instance = root as MeshInstance3D
		if _mesh_needs_visible_material(mesh_instance):
			mesh_instance.material_override = fallback
	for child in root.get_children():
		_apply_visible_material_fallbacks(child, fallback)

func _mesh_needs_visible_material(mesh_instance: MeshInstance3D) -> bool:
	if mesh_instance.material_override != null:
		return _is_bad_white_material(mesh_instance.material_override)
	if mesh_instance.mesh == null:
		return true
	var saw_material = false
	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		var material = mesh_instance.mesh.surface_get_material(surface_index)
		if material == null:
			continue
		saw_material = true
		if _is_bad_white_material(material):
			return true
	return not saw_material

func _is_bad_white_material(material: Material) -> bool:
	if material == null:
		return true
	if material is StandardMaterial3D:
		var standard = material as StandardMaterial3D
		var color = standard.albedo_color
		return standard.albedo_texture == null and color.r > 0.85 and color.g > 0.85 and color.b > 0.85
	return false
