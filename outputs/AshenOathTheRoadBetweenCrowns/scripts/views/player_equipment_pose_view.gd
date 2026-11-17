extends RefCounted
## player equipment pose view: scene-only responsibilities.

var _actor: CharacterBody3D

func _init(actor: CharacterBody3D) -> void:
	_actor = actor

func begin_companion_gesture(companion: Node3D, kind: String, duration: float) -> void:
	_actor.end_companion_gesture()
	if not is_instance_valid(companion) or _actor.animation_driver == null or _actor.equipment_loadout.is_drawn() or _actor.equipment_loadout.is_transitioning():
		return
	_actor.companion_gesture_target = weakref(companion)
	_actor.companion_gesture_kind = kind
	_actor.companion_gesture_time = 0.0
	_actor.companion_gesture_duration = duration
	var direction: Variant = companion.global_position - _actor.global_position
	_actor.rotation.y = atan2(-direction.x, -direction.z)
	if kind != "rest":
		_actor.animation_driver.trigger_action("story_offer", 1.0, 0.14, false, duration)
		if _actor.companion_hand_ik == null:
			var rig: Skeleton3D = _actor.animation_driver.get_skeleton()
			if rig != null:
				_actor.companion_hand_ik = _actor._make_arm_pose_ik(rig, "CompanionCareHand", &"upperarm_r", &"hand_r")

func end_companion_gesture(cancel_activity: bool = false) -> void:
	var companion: Node = _actor.companion_gesture_target.get_ref() if _actor.companion_gesture_target != null else null
	_actor.companion_gesture_target = null
	_actor.companion_gesture_kind = ""
	if _actor.companion_hand_ik != null:
		_actor.companion_hand_ik.influence = 0.0
		_actor.companion_hand_ik.stop()
	if _actor.animation_driver != null and _actor.animation_driver.current_state == "story_offer":
		_actor.animation_driver.stop_action("idle", 0.12)
	if cancel_activity and is_instance_valid(companion) and not companion.is_queued_for_deletion():
		companion.cancel_care()

func _update_companion_gesture(delta: float) -> void:
	if _actor.companion_gesture_kind == "":
		return
	var companion: Node3D = _actor.companion_gesture_target.get_ref() if _actor.companion_gesture_target != null else null
	if not is_instance_valid(companion) or companion.is_queued_for_deletion() or not _actor.can_control or _actor.transition_locked or _actor.locomotion_velocity.length_squared() > 0.02 or _actor.attack_anim_time > 0.0 or _actor.hurt_react_time > 0.0 or _actor.beam_cast_state != _actor.BEAM_STATE_IDLE or _actor.equipment_loadout.is_drawn() or _actor.equipment_loadout.is_transitioning():
		_actor.end_companion_gesture(true)
		return
	_actor.companion_gesture_time += delta
	if _actor.companion_gesture_time >= _actor.companion_gesture_duration:
		_actor.end_companion_gesture()
		return
	if _actor.companion_gesture_kind == "rest" or _actor.companion_hand_ik == null:
		return
	var blend: Variant = minf(clampf(_actor.companion_gesture_time / 0.3, 0.0, 1.0), clampf((_actor.companion_gesture_duration - _actor.companion_gesture_time) / 0.35, 0.0, 1.0))
	var point: Vector3 = companion.care_contact_point(_actor.companion_gesture_kind)
	if _actor.companion_gesture_kind == "pet":
		point += companion.global_basis.z * sin(_actor.companion_gesture_time * 6.0) * 0.045
	_actor.companion_hand_ik.target = Transform3D(Basis.IDENTITY, point)
	_actor.companion_hand_ik.influence = blend
	_actor.companion_hand_ik.start(true)

func _update_oathfire_arm_pose() -> void:
	var enabled: Variant = _actor.beam_cast_state in [_actor.BEAM_STATE_CHARGING, _actor.BEAM_STATE_RELEASING]
	if enabled and _actor.beam_left_arm_ik != null and _actor.beam_right_arm_ik != null:
		var forward: Variant = -_actor.global_basis.z.normalized()
		var right: Variant = _actor.global_basis.x.normalized()
		var center: Variant = _actor.global_position + Vector3.UP * 1.18 + forward * 0.43
		_actor.beam_left_arm_ik.target = Transform3D(Basis.IDENTITY, center - right * 0.12)
		_actor.beam_right_arm_ik.target = Transform3D(Basis.IDENTITY, center + right * 0.12)
		_actor.beam_left_arm_ik.influence = 1.0
		_actor.beam_right_arm_ik.influence = 1.0
		_actor.beam_left_arm_ik.start(true)
		_actor.beam_right_arm_ik.start(true)
		_actor.beam_arm_pose_applied = true
	elif _actor.beam_arm_pose_applied:
		if _actor.beam_left_arm_ik != null:
			_actor.beam_left_arm_ik.influence = 0.0
			_actor.beam_left_arm_ik.stop()
		if _actor.beam_right_arm_ik != null:
			_actor.beam_right_arm_ik.influence = 0.0
			_actor.beam_right_arm_ik.stop()
		_actor.beam_arm_pose_applied = false

func _update_sword_equipment_pose(windup: float, strike: float, recovery: float, heavy: bool, attacking: bool) -> void:
	if _actor.sword_equipment_pivot == null or _actor.sword_attachment == null:
		return
	var skeleton: Variant = _actor.sword_attachment.get_parent() as Skeleton3D
	var native_grip: Variant = skeleton != null and _actor.sword_attachment.bone_name == &"hand_r"
	var grip_allowed: Variant = native_grip and _actor.can_control and not _actor.transition_locked and not _actor.sword_sheathed and _actor.beam_cast_state in [_actor.BEAM_STATE_IDLE, _actor.BEAM_STATE_REDRAWING] and _actor.weapon_mode == "sword"
	_actor._update_sword_hand_grip(skeleton, grip_allowed)
	var equipment_pose: Variant = _actor._equipment_reach_pose()
	var sword_reach: Variant = not equipment_pose.is_empty() and _actor.weapon_mode == "sword"
	_actor._update_bow_equipment_reach(equipment_pose)
	if _actor.guard_arm_ik != null:
		var guard_allowed: Variant = _actor.can_control and not _actor.transition_locked and not attacking and not _actor.sword_sheathed and _actor.beam_cast_state == "" and _actor.weapon_mode == "sword"
		var weight: Variant = clampf(_actor.block_pose_weight, 0.0, 1.0) if guard_allowed else 0.0
		if _actor.parry_window > 0.0 and guard_allowed:
			weight = 1.0
		if sword_reach:
			weight = float(equipment_pose.weight)
		if weight > 0.01:
			var target: Variant = _actor.global_position + Vector3.UP * 1.12 + _actor.global_basis.x.normalized() * 0.28 - _actor.global_basis.z.normalized() * 0.34
			if sword_reach:
				target = equipment_pose.position
			_actor.guard_arm_ik.target = Transform3D(Basis.IDENTITY, target)
			_actor.guard_arm_ik.influence = weight
			_actor.guard_arm_ik.start(true)
			_actor.guard_arm_applied = true
		elif _actor.guard_arm_applied:
			_actor.guard_arm_ik.influence = 0.0
			_actor.guard_arm_ik.stop()
			_actor.guard_arm_applied = false
	var forward: Variant = -_actor.global_transform.basis.z.normalized()
	var right: Variant = _actor.global_transform.basis.x.normalized()
	# BoneAttachment3D publishes its transform after the skeleton update. Reading
	# its global transform here leaves equipment one animation frame behind the
	# hand during fast strikes. Derive the live hand frame from the skeleton pose
	# directly, then express the weapon in the attachment's next local space.
	var hand_world: Variant = _actor.sword_attachment.global_transform
	if skeleton != null and _actor.sword_attachment.bone_idx >= 0:
		hand_world = skeleton.global_transform * skeleton.get_bone_global_pose(_actor.sword_attachment.bone_idx)
	var hand_basis: Variant = hand_world.basis.orthonormalized()
	if not _actor.sword_grip_calibrated and absf(hand_basis.determinant()) > 0.1:
		# Universal characters use different bind-pose hand axes across imported
		# revisions. Record the correction in hand-local space once, then let the
		# live bone animation carry the weapon through every pose.
		var calibration_direction: Variant = (Vector3.DOWN * 0.78 + right * 0.54).normalized()
		var local_calibration_direction: Variant = (hand_basis.inverse() * calibration_direction).normalized()
		_actor.sword_grip_basis = Basis(Quaternion(Vector3.DOWN, local_calibration_direction)).orthonormalized()
		_actor.sword_grip_calibrated = true
	# Keep the ready blade down and outside the torso instead of crossing the
	# chest. The attack states still own the full swing arc below.
	var idle_direction: Variant = (Vector3.DOWN * 0.78 + right * 0.54).normalized()
	var blade_direction: Variant = idle_direction
	if not attacking:
		var guard_weight: Variant = 1.0 if _actor.parry_window > 0.0 else clampf(_actor.block_pose_weight, 0.0, 1.0)
		var guard_direction: Variant = (Vector3.UP * 0.90 + forward * 0.42 - right * 0.18).normalized()
		blade_direction = idle_direction.slerp(guard_direction, guard_weight)
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
	# Start from the current hand frame, rather than reconstructing a world
	# rotation from the actor root. The minimal direction correction keeps the
	# calibrated blade readable during the authored attack arc while preserving
	# wrist/elbow motion from the active animation clip.
	var hand_weapon_basis: Variant = (hand_basis * _actor.sword_grip_basis).orthonormalized()
	var current_blade_direction: Variant = (hand_weapon_basis * Vector3.DOWN).normalized()
	var direction_correction: Variant = Quaternion(current_blade_direction, blade_direction)
	var blade_basis: Variant = (Basis(direction_correction) * hand_weapon_basis).orthonormalized()
	if sword_reach:
		blade_basis = blade_basis.slerp(equipment_pose.basis, float(equipment_pose.weight))
	var hand_offset: Variant = hand_basis * Vector3(0.018, 0.012, 0.0)
	var hand_position: Variant = hand_world.origin + hand_offset
	if grip_allowed:
		# Anchor the hilt inside the curled native fingers on every axis. Ignoring
		# the blade-axis component preserved nominal reach but left the sword
		# visibly floating away from the hand during attack clips. Contact markers
		# share this pivot, so rendered and physical reach remain identical.
		var grip_center: Variant = _actor._sword_grip_center_world(skeleton)
		var provisional: Variant = Transform3D(blade_basis, hand_position)
		var local_grip: Variant = provisional.affine_inverse() * grip_center
		hand_position += blade_basis * local_grip
	var desired_world: Variant = Transform3D(blade_basis, hand_position)
	var equipment_space: Variant = _actor.sword_equipment_pivot.get_parent() as Node3D
	if equipment_space != null and equipment_space.get_parent() == _actor.sword_attachment:
		var expected_parent_world: Variant = hand_world * equipment_space.transform
		_actor.sword_equipment_pivot.transform = expected_parent_world.affine_inverse() * desired_world
	else:
		_actor.sword_equipment_pivot.global_transform = desired_world

func _equipment_anchor_world(node: Node3D) -> Transform3D:
	var local: Variant = node.transform
	var ancestor: Variant = node.get_parent()
	while ancestor is Node3D:
		if ancestor is BoneAttachment3D and ancestor.get_parent() is Skeleton3D:
			var rig: Variant = ancestor.get_parent() as Skeleton3D
			return rig.global_transform * rig.get_bone_global_pose((ancestor as BoneAttachment3D).bone_idx) * local
		local = (ancestor as Node3D).transform * local
		ancestor = ancestor.get_parent()
	return node.global_transform

func _equipment_reach_pose() -> Dictionary:
	if not _actor.equipment_loadout.is_transitioning():
		return {}
	var anchor: Node3D = _actor.bow_back_visual if _actor.weapon_mode == "bow" else _actor.blade_scabbards.get(_actor.get_selected_blade_id()) as Node3D
	if not is_instance_valid(anchor):
		return {}
	var frame: Variant = _actor._equipment_anchor_world(anchor)
	var phase: Variant = _actor.equipment_loadout.transition_progress()
	var contact: Variant = _actor.EquipmentLoadout.CONTACT_FRACTION
	var approach: Variant = smoothstep(0.0, contact - 0.04, phase)
	var release: Variant = 1.0 - smoothstep(contact + 0.08, 1.0, phase)
	var target: Variant = frame.origin
	if _actor.equipment_loadout.transition == "draw" and phase > contact:
		var withdrawal: Variant = sin(clampf((phase - contact) / (1.0 - contact), 0.0, 1.0) * PI)
		target += frame.basis.y.normalized() * 0.24 * withdrawal
	return {"position": target, "basis": frame.basis.orthonormalized(), "weight": approach * release}

func _update_bow_equipment_reach(pose: Dictionary) -> void:
	if _actor.equipment_left_arm_ik == null:
		return
	var reaching: Variant = _actor.weapon_mode == "bow" and not pose.is_empty()
	if not reaching:
		_actor.equipment_left_arm_ik.influence = 0.0
		_actor.equipment_left_arm_ik.stop()
		# The archery modifier owns the held bow, including its local rotation.
		if _actor.bow_visual != null and not _actor.is_bow_pose_active():
			_actor.bow_visual.rotation_degrees = Vector3(0.0, 8.0, -12.0)
		return
	_actor.equipment_left_arm_ik.target = Transform3D(Basis.IDENTITY, pose.position)
	_actor.equipment_left_arm_ik.influence = float(pose.weight)
	_actor.equipment_left_arm_ik.start(true)
	if _actor.bow_visual != null:
		var parent_frame: Variant = _actor._equipment_anchor_world(_actor.bow_visual.get_parent() as Node3D)
		var resting: Variant = Basis.from_euler(Vector3(0.0, deg_to_rad(8.0), deg_to_rad(-12.0)))
		var target_basis: Basis = parent_frame.basis.orthonormalized().inverse() * (pose.basis as Basis)
		_actor.bow_visual.basis = resting.slerp(target_basis, float(pose.weight))

func _sword_grip_center_world(skeleton: Skeleton3D) -> Vector3:
	var center: Variant = Vector3.ZERO
	var count: Variant = 0
	for bone_name in ["index_02_r", "middle_02_r", "ring_02_r", "pinky_02_r"]:
		var bone_index: Variant = skeleton.find_bone(bone_name)
		if bone_index >= 0:
			center += (skeleton.global_transform * skeleton.get_bone_global_pose(bone_index)).origin
			count += 1
	return center / float(count) if count > 0 else _actor.sword_attachment.global_position

func _update_sword_hand_grip(skeleton: Skeleton3D, enabled: bool) -> void:
	if skeleton == null:
		return
	if _actor.sword_grip_bones.is_empty():
		for finger in ["index", "middle", "ring", "pinky"]:
			for joint in [2, 3]:
				var bone_name: Variant = "%s_0%s_r" % [finger, joint]
				var bone_index: Variant = skeleton.find_bone(bone_name)
				if bone_index >= 0:
					_actor.sword_grip_bones[bone_index] = Quaternion(Vector3.RIGHT, 0.70)
		for joint in [2, 3]:
			var bone_name: Variant = "thumb_0%s_r" % joint
			var bone_index: Variant = skeleton.find_bone(bone_name)
			if bone_index >= 0:
				_actor.sword_grip_bones[bone_index] = Quaternion(Vector3.FORWARD, -0.35)
	if _actor.sword_grip_bones.is_empty():
		return
	var changed: Variant = false
	for bone_index in _actor.sword_grip_bones:
		var current: Variant = skeleton.get_bone_pose_rotation(bone_index)
		var base: Variant = current
		if _actor.sword_grip_pose_applied and _actor.sword_grip_applied_rotations.has(bone_index) and current.is_equal_approx(_actor.sword_grip_applied_rotations[bone_index]):
			base = _actor.sword_grip_base_rotations.get(bone_index, current)
		if enabled:
			var applied: Quaternion = (base * (_actor.sword_grip_bones[bone_index] as Quaternion)).normalized()
			_actor.sword_grip_base_rotations[bone_index] = base
			_actor.sword_grip_applied_rotations[bone_index] = applied
			skeleton.set_bone_pose_rotation(bone_index, applied)
			changed = true
		elif _actor.sword_grip_pose_applied and current.is_equal_approx(_actor.sword_grip_applied_rotations.get(bone_index, current)):
			skeleton.set_bone_pose_rotation(bone_index, base)
			changed = true
	_actor.sword_grip_pose_applied = enabled
	if not enabled:
		_actor.sword_grip_base_rotations.clear()
		_actor.sword_grip_applied_rotations.clear()
	if changed:
		skeleton.force_update_all_bone_transforms()
