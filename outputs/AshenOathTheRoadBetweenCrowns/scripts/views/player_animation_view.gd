extends RefCounted
## player animation view: scene-only responsibilities.

var _actor: CharacterBody3D

func _init(actor: CharacterBody3D) -> void:
	_actor = actor

func _add_slash_arc_visuals() -> void:
	_actor.slash_arc_root = Node3D.new()
	_actor.slash_arc_root.name = "visible_sword_slash_arc_root"
	_actor.slash_arc_root.position = Vector3(0.48, 1.18, -0.78)
	_actor.slash_arc_root.visible = false
	_actor.visual_root.add_child(_actor.slash_arc_root)
	_actor.slash_arc_primary = _actor._add_slash_panel("visible_sword_slash_arc_primary", Vector3.ZERO, Vector3(0.045, 0.10, 1.0), Color(1.0, 0.84, 0.52, 0.34))
	_actor.slash_arc_secondary = _actor._add_slash_panel("visible_sword_slash_arc_secondary", Vector3(0.07, -0.04, 0.05), Vector3(0.16, 0.08, 0.90), Color(0.70, 0.32, 0.12, 0.58))
	_actor.slash_arc_spark = _actor._add_slash_panel("visible_sword_slash_impact_edge", Vector3(0.0, 0.0, -0.48), Vector3(0.20, 0.22, 0.16), Color(1.0, 0.80, 0.34, 0.92))

func _add_slash_panel(node_name: String, local_pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var panel = MeshInstance3D.new()
	panel.name = node_name
	var mesh = BoxMesh.new()
	mesh.size = size
	panel.mesh = mesh
	panel.position = local_pos
	panel.material_override = _actor._trail_mat(color)
	_actor.slash_arc_root.add_child(panel)
	return panel

func _animate_visuals(delta: float) -> void:
	if _actor.visual_root == null:
		return
	_actor._update_locomotion_state()
	var horizontal_speed: float = _actor.locomotion_velocity.length()
	var moving: bool = horizontal_speed > 0.15
	var running: bool = _actor.movement_state in ["run", "run_back"]
	var rigged_motion: bool = _actor.animation_driver != null and _actor.animation_driver.is_valid()
	if rigged_motion:
		if (_actor.animation_driver != null):
			_actor.animation_driver.set_locomotion_motion(_actor.locomotion_velocity, _actor.is_on_floor(), _actor.run_speed, _actor.movement_state == "run")
		else:
			_actor.animation_driver.set_locomotion(horizontal_speed / maxf(_actor.run_speed, 0.1), _actor.locomotion_velocity.normalized(), _actor.is_on_floor())
		if moving and _actor.equipment_loadout.is_transitioning() and _actor.animation_driver.current_state in ["draw", "sheath"]:
			_actor.animation_driver.stop_action("walk", 0.08)
		if (_actor.animation_driver != null):
			_actor.animation_driver.set_relaxed_idle(_actor._relaxed_idle_eligible())
		_actor.animation_driver.advance_external(delta)
		if _actor.movement_state == "dodge" and _actor.animation_driver.current_state != "dodge":
			_actor.animation_driver.trigger_action("dodge")
	if moving:
		# The fallback body's small weight shift advances with distance too;
		# imported rigs own their own continuous foot-contact phase.
		_actor.move_phase += delta * horizontal_speed * (8.7 / maxf(_actor.run_speed, 0.1) if running else 6.2 / maxf(_actor.walk_speed, 0.1))
		if not _actor.animation_step_signal_bound:
			_actor._update_distance_footsteps(delta, running)
	else:
		_actor.move_phase += delta * 1.45
		_actor.footstep_distance = 0.0
	var speed_factor: float = clampf(horizontal_speed / maxf(_actor.run_speed, 0.1), 0.0, 1.0)
	_actor.movement_blend = lerp(_actor.movement_blend, speed_factor, 1.0 - exp(-10.0 * delta))
	_actor.strafe_blend = lerp(_actor.strafe_blend, 1.0 if _actor.movement_state == "strafe" else 0.0, 1.0 - exp(-9.0 * delta))
	_actor.backward_blend = lerp(_actor.backward_blend, 1.0 if _actor.movement_state in ["backward", "run_back"] else 0.0, 1.0 - exp(-9.0 * delta))
	_actor.grounded_weight = lerp(_actor.grounded_weight, _actor.movement_blend, 1.0 - exp(-8.0 * delta))
	_actor.block_pose_weight = lerp(_actor.block_pose_weight, 1.0 if _actor.is_blocking() else 0.0, 1.0 - exp(-14.0 * delta))
	var dodge_weight = clamp(_actor.dodge_time / 0.30, 0.0, 1.0)
	var hurt_weight = clamp(_actor.hurt_react_time / 0.20, 0.0, 1.0)
	var combat_swing_weight = 0.0
	var combat_windup_weight = 0.0
	# Walk/Sprint clips already move the pelvis and shoulders. A second full
	# bob/roll on the entire rig made feet float and the torso rock like a prop.
	var additive_gait_weight: float = 0.16 if rigged_motion else 1.0
	var bob: float = (0.030 * sin(_actor.move_phase) * _actor.grounded_weight if moving else 0.009 * sin(_actor.move_phase)) * additive_gait_weight
	var idle_breath: float = sin(_actor.move_phase * 0.72) * (1.0 - _actor.grounded_weight) * additive_gait_weight
	var pelvis_offset: float = (_actor.left_foot_ground_offset + _actor.right_foot_ground_offset) * 0.22
	_actor.visual_root.position.y = bob + pelvis_offset - 0.018 * _actor.grounded_weight * additive_gait_weight - 0.030 * hurt_weight - 0.10 * _actor.landing_compression
	var body_basis: Basis = _actor.global_basis.orthonormalized()
	var local_velocity: Vector3 = body_basis.inverse() * _actor.locomotion_velocity
	var lateral_lean: float = clampf(-local_velocity.x * (0.10 if rigged_motion else 0.22), -1.5, 1.5)
	var local_normal: Vector3 = body_basis.inverse() * _actor.smoothed_ground_normal
	var slope_pitch: float = rad_to_deg(atan2(local_normal.z, maxf(local_normal.y, 0.25)))
	var slope_roll: float = -rad_to_deg(atan2(local_normal.x, maxf(local_normal.y, 0.25)))
	var signed_forward_weight: float = clampf(-local_velocity.z / maxf(horizontal_speed, 0.15), -1.0, 1.0)
	var forward_lean: float = (-3.5 if running else -2.3) * _actor.grounded_weight * signed_forward_weight * additive_gait_weight if moving else 0.9 * idle_breath
	forward_lean += slope_pitch * (0.26 if rigged_motion else 0.45) + 8.0 * _actor.jump_pose_weight - 11.0 * _actor.landing_compression
	forward_lean += -7.0 * dodge_weight + 5.0 * hurt_weight - 3.5 * _actor.block_pose_weight
	var local_dodge: Vector3 = body_basis.inverse() * _actor.dodge_dir
	var root_z: float = lateral_lean + slope_roll * (0.22 if rigged_motion else 0.35) + 0.65 * sin(_actor.move_phase) * _actor.grounded_weight * additive_gait_weight + 9.0 * dodge_weight * signf(local_dodge.x) - 3.0 * _actor.block_pose_weight
	_actor.visual_root.rotation_degrees.z = lerpf(_actor.visual_root.rotation_degrees.z, root_z, 1.0 - exp(-9.0 * delta))
	_actor.visual_root.rotation_degrees.x = lerpf(_actor.visual_root.rotation_degrees.x, forward_lean, 1.0 - exp(-9.0 * delta))
	if _actor.attack_anim_time > 0.0:
		var duration = 0.52 if _actor.attack_anim_heavy else 0.34
		var t = 1.0 - _actor.attack_anim_time / duration
		var windup = clamp(t / (0.38 if _actor.attack_anim_heavy else 0.24), 0.0, 1.0)
		var strike = clamp((t - (0.30 if _actor.attack_anim_heavy else 0.18)) / (0.34 if _actor.attack_anim_heavy else 0.24), 0.0, 1.0)
		var recovery = clamp((t - (0.64 if _actor.attack_anim_heavy else 0.52)) / (0.36 if _actor.attack_anim_heavy else 0.34), 0.0, 1.0)
		var strike_arc = sin(strike * PI)
		combat_swing_weight = strike_arc
		combat_windup_weight = windup
		var windup_angle = 34.0 if _actor.attack_anim_heavy else 18.0
		var swing = -188.0 * strike_arc if _actor.attack_anim_heavy else -124.0 * strike_arc
		var root_y = lerp(windup_angle, -18.0 if _actor.attack_anim_heavy else -10.0, strike)
		root_y = lerp(root_y, 0.0, recovery)
		_actor.visual_root.rotation_degrees.y = root_y
		_actor.visual_root.rotation_degrees.x = lerp(_actor.visual_root.rotation_degrees.x, forward_lean - (15.0 if _actor.attack_anim_heavy else 5.5) * strike_arc + (8.0 if _actor.attack_anim_heavy else 3.0) * windup, 12.0 * delta)
		if _actor.weapon_root != null:
			var weapon_pose = Vector3(38.0 - strike_arc * (68.0 if _actor.attack_anim_heavy else 48.0), swing, 20.0 + windup * (68.0 if _actor.attack_anim_heavy else 42.0) + strike_arc * (110.0 if _actor.attack_anim_heavy else 82.0))
			_actor.weapon_root.rotation_degrees = weapon_pose
			_actor.weapon_root.position = _actor.weapon_root.position.lerp(Vector3(0.42, 0.84, -0.42) + Vector3(0.20 * strike_arc, 0.08 * windup, -0.26 * strike_arc), 14.0 * delta)
			# The old fallback box trail detached from the hand and read as a
			# second oversized sword. The measured blade ribbon below is the only
			# attack trail now.
			if _actor.sword_trail_visual != null:
				_actor.sword_trail_visual.visible = false
		_actor._update_sword_equipment_pose(windup, strike, recovery, _actor.attack_anim_heavy, true)
		_actor._animate_slash_arc(strike, strike_arc, recovery, _actor.attack_anim_heavy)
	else:
		_actor.visual_root.rotation_degrees.y = lerp(_actor.visual_root.rotation_degrees.y, 0.0, 10.0 * delta)
		var ready_pose = Vector3(14.0 - _actor.block_pose_weight * 20.0, _actor.block_pose_weight * -22.0, 8.0 + _actor.block_pose_weight * 18.0)
		if _actor.weapon_root != null:
			_actor.weapon_root.rotation_degrees = _actor.weapon_root.rotation_degrees.lerp(ready_pose, 12.0 * delta)
			_actor.weapon_root.position = _actor.weapon_root.position.lerp(Vector3(0.42, 0.84, -0.42), 10.0 * delta)
		if _actor.sword_trail_visual != null:
			_actor.sword_trail_visual.visible = false
		if _actor.slash_arc_root != null:
			_actor.slash_arc_root.visible = false
		_actor._update_sword_equipment_pose(0.0, 0.0, 0.0, false, false)
	if _actor.beam_cast_state != "":
		var cast_weight: Variant = 1.0 if _actor.beam_cast_state in ["charging", "releasing"] else 0.55
		_actor.visual_root.rotation_degrees.x = lerp(_actor.visual_root.rotation_degrees.x, -4.0 * cast_weight, 12.0 * delta)
		_actor.visual_root.rotation_degrees.y = lerp(_actor.visual_root.rotation_degrees.y, 0.0, 12.0 * delta)
		if _actor.slash_arc_root != null:
			_actor.slash_arc_root.visible = false
	_actor._update_oathfire_arm_pose()
	_actor._update_companion_gesture(delta)
	_actor._update_bow_presentation(delta)
	# Arm IK changes the hand pose after the regular beam-state tick. Refresh the
	# charge from the live bones now so the sphere, eventual beam origin, and
	# rendered hands cannot diverge by one animation frame.
	if _actor.beam_cast_state in [_actor.BEAM_STATE_CHARGING, _actor.BEAM_STATE_RELEASING]:
		_actor._update_beam_charge_visual()
	_actor._update_hurt_overlay()

func _relaxed_idle_eligible() -> bool:
	return _actor.can_control and not _actor.transition_locked and _actor.is_on_floor() and _actor.locomotion_velocity.length_squared() <= 0.0064 \
		and not _actor.equipment_loadout.is_drawn() and not _actor.equipment_loadout.is_transitioning() and not _actor.field_tool_aiming \
		and not _actor.bow_aiming and not _actor.bow_drawing and _actor.beam_cast_state == _actor.BEAM_STATE_IDLE and _actor.companion_gesture_time <= 0.0 \
		and _actor.attack_anim_time <= 0.0 and _actor.dodge_time <= 0.0 and _actor.hurt_react_time <= 0.0

func _update_hurt_overlay() -> void:
	if _actor.hurt_flash_time > 0.0 and _actor._hurt_overlay_bindings.is_empty() and is_instance_valid(_actor._mapped_body):
		if _actor._hurt_overlay == null:
			_actor._hurt_overlay = StandardMaterial3D.new()
			_actor._hurt_overlay.albedo_color = Color(0.72, 0.12, 0.06, 0.28)
			_actor._hurt_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_actor._hurt_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		for mesh in _actor._mapped_body.find_children("*", "MeshInstance3D", true, false):
			if mesh.skin == null or mesh.mesh == null:
				continue
			_actor._hurt_overlay_bindings.append({"mesh": weakref(mesh), "overlay": mesh.material_overlay})
			mesh.material_overlay = _actor._hurt_overlay
	elif _actor.hurt_flash_time <= 0.0 and not _actor._hurt_overlay_bindings.is_empty():
		for binding in _actor._hurt_overlay_bindings:
			var mesh: MeshInstance3D = binding.mesh.get_ref()
			if is_instance_valid(mesh) and mesh.material_overlay == _actor._hurt_overlay:
				mesh.material_overlay = binding.overlay
		_actor._hurt_overlay_bindings.clear()

func _on_animation_locomotion_step(_side: StringName) -> void:
	# Animation contact is authoritative for rigged bodies. Gate it against
	# actual movement so a blocked actor cannot produce a stream of footsteps
	# while its clip is still blending out.
	if _actor.movement_state not in ["walk", "backward", "strafe", "run", "run_back"]:
		return
	if not _actor.is_on_floor() or _actor.locomotion_velocity.length() < 0.18:
		return
	_actor.footstep.emit()

func _update_distance_footsteps(delta: float, running: bool) -> void:
	if not _actor.is_on_floor():
		return
	var horizontal_speed: float = _actor.locomotion_velocity.length()
	if horizontal_speed < 0.18:
		return
	_actor.footstep_distance += horizontal_speed * delta
	var step_distance: Variant = 1.52 if running else (1.22 if _actor.movement_state == "backward" else 1.34)
	while _actor.footstep_distance >= step_distance:
		_actor.footstep_distance -= step_distance
		_actor.footstep.emit()

func _animate_slash_arc(strike: float, strike_arc: float, recovery: float, heavy: bool) -> void:
	if _actor.slash_arc_root == null:
		return
	var visible = _actor.is_blade_ready() and strike > 0.08 and strike < 0.94 and recovery < 0.86
	_actor.slash_arc_root.visible = visible
	if not visible:
		_actor.visual_previous_blade_base = Vector3.ZERO
		_actor.visual_previous_blade_tip = Vector3.ZERO
		return
	var segment: Dictionary = _actor.get_blade_world_segment()
	var blade_base: Vector3 = segment.get("base", _actor.global_position + Vector3(0, 1.0, 0))
	var blade_tip: Vector3 = segment.get("tip", blade_base)
	var old_base: Vector3 = _actor.visual_previous_blade_base if _actor.visual_previous_blade_base.length_squared() > 0.01 else blade_base
	var old_tip: Vector3 = _actor.visual_previous_blade_tip if _actor.visual_previous_blade_tip.length_squared() > 0.01 else blade_tip
	if old_tip.distance_to(blade_tip) > 1.10:
		old_base = blade_base
		old_tip = blade_tip
	_actor.slash_arc_root.global_transform = Transform3D.IDENTITY
	if _actor.slash_arc_primary != null:
		_actor.slash_arc_primary.visible = true
		_actor.slash_arc_primary.position = Vector3.ZERO
		_actor.slash_arc_primary.rotation = Vector3.ZERO
		_actor.slash_arc_primary.scale = Vector3.ONE
		_actor.slash_arc_primary.mesh = _actor._build_blade_ribbon(old_base, old_tip, blade_base, blade_tip)
	if _actor.slash_arc_secondary != null:
		_actor.slash_arc_secondary.visible = false
	if _actor.slash_arc_spark != null:
		_actor.slash_arc_spark.visible = false
	_actor.visual_previous_blade_base = blade_base
	_actor.visual_previous_blade_tip = blade_tip

func _build_blade_ribbon(old_base: Vector3, old_tip: Vector3, blade_base: Vector3, blade_tip: Vector3) -> ImmediateMesh:
	var ribbon: Variant = ImmediateMesh.new()
	var width_axis: Variant = Vector3.RIGHT
	var camera: Variant = _actor.get_viewport().get_camera_3d()
	if camera != null:
		width_axis = camera.global_transform.basis.x.normalized()
	var width: Variant = width_axis * 0.012
	# A full base-to-tip sweep renders the previous blade as a second floating
	# sword. Keep the effect on the outer third of the measured blade instead:
	# it still follows both authored base/tip transforms, but reads as a tapered
	# contact arc rather than duplicate weapon geometry.
	var old_inner: Variant = old_base.lerp(old_tip, 0.68)
	var current_inner: Variant = blade_base.lerp(blade_tip, 0.68)
	ribbon.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	# Build two thin screen-facing strips around the measured outer-blade sweep.
	for side in [-1.0, 1.0]:
		var offset: Vector3 = width * side
		ribbon.surface_add_vertex(old_inner + offset)
		ribbon.surface_add_vertex(old_tip + offset)
		ribbon.surface_add_vertex(blade_tip + offset)
		ribbon.surface_add_vertex(old_inner + offset)
		ribbon.surface_add_vertex(blade_tip + offset)
		ribbon.surface_add_vertex(current_inner + offset)
	ribbon.surface_end()
	return ribbon
