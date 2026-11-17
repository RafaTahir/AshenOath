extends RefCounted
## player oathfire view: scene-only responsibilities.

var _actor: CharacterBody3D

func _init(actor: CharacterBody3D) -> void:
	_actor = actor

func _handle_beam_input() -> void:
	if _actor._action_just_pressed("oathfire_beam") and _actor.beam_cooldown <= 0.0 and _actor.beam_cast_state == _actor.BEAM_STATE_IDLE and _actor.dodge_time <= 0.0:
		_actor._begin_oathfire_cast()
	if _actor.beam_cast_state == _actor.BEAM_STATE_CHARGING and _actor._action_pressed("oathfire_beam"):
		_actor.beam_charge_time = min(_actor.beam_charge_time + _actor._tick_delta / _actor.get_oathfire_charge_multiplier(), 1.25)
		_actor._update_beam_charge_visual()
	if _actor.beam_cast_state == _actor.BEAM_STATE_CHARGING and _actor._action_just_released("oathfire_beam"):
		var ratio: float = clampf((_actor.beam_charge_time - 0.35) / 0.90, 0.0, 1.0)
		if _actor.beam_charge_time >= 0.35 and _actor.stamina_component.spend(_actor.get_oathfire_stamina_cost()):
			_actor._commit_oathfire_release(ratio)
		elif _actor.beam_charge_time >= 0.35:
			_actor.stamina_exhausted.emit("Oathfire Beam")
			_actor._begin_beam_redraw()
		else:
			_actor._begin_beam_redraw()
	elif _actor.beam_cast_state == _actor.BEAM_STATE_SHEATHING and _actor._action_just_released("oathfire_beam"):
		_actor._begin_beam_redraw()

func _set_beam_state(next_state: String, duration: float = -1.0) -> void:
	if _actor.beam_cast_state == next_state:
		if duration >= 0.0:
			_actor.beam_state_time = duration
		return
	_actor.beam_cast_state = next_state
	_actor.beam_state_sequence += 1
	if duration >= 0.0:
		_actor.beam_state_time = duration
	if next_state != _actor.BEAM_STATE_IDLE:
		_actor.beam_phase_changed.emit(next_state)

func _begin_oathfire_cast() -> bool:
	if _actor.transition_locked or not _actor.can_control or _actor.beam_cooldown > 0.0 or _actor.dodge_time > 0.0 or _actor.beam_cast_state != _actor.BEAM_STATE_IDLE:
		return false
	var captured: Variant = _actor._lock_beam_direction()
	if captured.length_squared() < 0.5:
		return false
	_actor.beam_restore_equipment = _actor.equipment_loadout.save_state()
	_actor._cancel_equipment_action()
	_actor._cancel_bow()
	_actor.parry_window = 0.0
	_actor._set_beam_state(_actor.BEAM_STATE_SHEATHING, 0.24)
	_actor.beam_charging = true
	_actor.beam_charge_time = 0.0
	_actor.beam_pending_ratio = 0.0
	_actor.beam_release_elapsed = 0.0
	_actor.beam_release_emitted = false
	_actor.beam_cancel_reason = ""
	_actor.beam_release_direction = Vector3.ZERO
	_actor.equipment_loadout.stow_all()
	return true

func _commit_oathfire_release(ratio: float) -> void:
	if _actor.beam_locked_direction.length_squared() < 0.5:
		_actor._lock_beam_direction()
	_actor.beam_locked_direction.y = 0.0
	_actor.beam_locked_direction = _actor.beam_locked_direction.normalized()
	_actor.beam_pending_ratio = clampf(ratio, 0.0, 1.0)
	_actor.beam_release_elapsed = 0.0
	_actor.beam_release_emitted = false
	_actor.beam_release_direction = _actor.beam_locked_direction
	_actor.beam_cooldown = _actor.get_oathfire_cooldown_duration()
	_actor.attack_cooldown = 0.75
	_actor.beam_charging = false
	_actor._set_beam_state(_actor.BEAM_STATE_RELEASING, 0.34)
	_actor._update_beam_charge_visual()

func _update_beam_sequence(delta: float) -> void:
	if _actor.beam_cast_state == _actor.BEAM_STATE_IDLE:
		return
	if _actor.beam_locked_direction.length_squared() > 0.5:
		_actor.face_target(_actor.global_position + _actor.beam_locked_direction * 4.0)
	var sequence: Dictionary = _actor.combat_model.cast_sequence(_actor.beam_cast_state, _actor.beam_state_time, _actor.beam_release_elapsed, _actor.beam_release_emitted, _actor._action_pressed("oathfire_beam"), _actor.equipment_loadout.is_transitioning(), delta)
	_actor.beam_state_time = float(sequence.remaining)
	_actor.beam_release_elapsed = float(sequence.elapsed)
	if _actor.beam_cast_state == _actor.BEAM_STATE_SHEATHING and _actor.beam_state_time <= 0.0:
		if sequence.command == "charge":
			_actor._set_beam_state(_actor.BEAM_STATE_CHARGING, 0.0)
			if _actor.animation_driver != null:
				_actor.animation_driver.trigger_action("beam_cast")
			_actor._update_beam_charge_visual()
		else:
			_actor._begin_beam_redraw()
	elif _actor.beam_cast_state == _actor.BEAM_STATE_RELEASING:
		_actor._update_beam_charge_visual()
		if bool(sequence.release):
			_actor.beam_release_emitted = true
			_actor.beam_requested.emit(_actor.beam_pending_ratio, _actor.beam_release_direction if _actor.beam_release_direction.length_squared() > 0.5 else _actor.beam_locked_direction)
			_actor._hide_beam_charge_visuals()
		if _actor.beam_state_time <= 0.0:
			_actor._begin_beam_redraw()
	elif _actor.beam_cast_state == _actor.BEAM_STATE_REDRAWING and _actor.beam_state_time <= 0.0 and not _actor.equipment_loadout.is_transitioning():
		_actor._set_beam_state(_actor.BEAM_STATE_IDLE)
		_actor.beam_charging = false
		_actor.beam_charge_time = 0.0
		_actor.beam_locked_direction = Vector3.ZERO
		_actor.beam_pending_ratio = 0.0
		_actor.beam_release_elapsed = 0.0
		_actor.beam_release_emitted = false
		_actor.beam_release_direction = Vector3.ZERO
		_actor._restore_oathfire_equipment()

func _begin_beam_redraw() -> void:
	_actor.beam_charging = false
	var restored_mode: Variant = str(_actor.beam_restore_equipment.get("active_weapon", _actor.weapon_mode))
	var drawn: Variant = bool(_actor.beam_restore_equipment.get("bow_drawn" if restored_mode == "bow" else "sword_drawn", false))
	_actor._set_beam_state(_actor.BEAM_STATE_REDRAWING, _actor.EquipmentLoadout.DRAW_SECONDS if drawn else 0.14)
	_actor._hide_beam_charge_visuals()
	if _actor.animation_driver != null and (_actor.animation_driver != null):
		_actor.animation_driver.stop_action("idle", 0.12)
	_actor.equipment_loadout.request_loadout(restored_mode, str(_actor.beam_restore_equipment.get("selected_blade_id", _actor.get_selected_blade_id())), drawn)

func _restore_oathfire_equipment() -> void:
	if _actor.beam_restore_equipment.is_empty():
		return
	var saved: Variant = _actor.beam_restore_equipment.duplicate(true)
	_actor.beam_restore_equipment.clear()
	_actor.equipment_loadout.load_state(saved)
	_actor.selected_arrow_id = _actor.equipment_loadout.selected_arrow_id

func _draw_sword_for_combat() -> void:
	if _actor.sword_sheathed:
		_actor.equipment_loadout.request_loadout("sword", _actor.get_selected_blade_id(), true)

func cancel_beam_charge(reason: String = "cancelled") -> void:
	var was_active: Variant = _actor.beam_cast_state != _actor.BEAM_STATE_IDLE or _actor.beam_charging or _actor.beam_locked_direction.length_squared() > 0.5
	_actor.beam_charging = false
	_actor.beam_charge_time = 0.0
	_actor._set_beam_state(_actor.BEAM_STATE_IDLE)
	_actor.beam_state_time = 0.0
	_actor.beam_locked_direction = Vector3.ZERO
	_actor.beam_pending_ratio = 0.0
	_actor.beam_release_elapsed = 0.0
	_actor.beam_release_emitted = false
	_actor.beam_release_direction = Vector3.ZERO
	_actor.beam_cancel_reason = reason if was_active else ""
	if was_active:
		_actor.beam_phase_changed.emit("cancelled")
	_actor._hide_beam_charge_visuals()
	if _actor.animation_driver != null and (_actor.animation_driver != null):
		_actor.animation_driver.stop_action("idle", 0.12)
	_actor._restore_oathfire_equipment()

func _lock_beam_direction() -> Vector3:
	_actor.beam_locked_direction = -_actor.global_transform.basis.z
	_actor.beam_locked_direction.y = 0.0
	if _actor.beam_locked_direction.length_squared() < 0.5:
		_actor.beam_locked_direction = Vector3.FORWARD
	_actor.beam_locked_direction = _actor.beam_locked_direction.normalized()
	return _actor.beam_locked_direction

func get_beam_locked_direction() -> Vector3:
	return _actor.beam_locked_direction

func get_oathfire_state() -> Dictionary:
	var charge_ratio: Variant = _actor.beam_pending_ratio if _actor.beam_cast_state == _actor.BEAM_STATE_RELEASING else clampf(_actor.beam_charge_time / 1.25, 0.0, 1.0)
	return {
		"state": _actor.beam_cast_state,
		"state_sequence": _actor.beam_state_sequence,
		"charge_ratio": charge_ratio,
		"charge_time": _actor.beam_charge_time,
		"cooldown": _actor.beam_cooldown,
		"locked_direction": _actor.beam_locked_direction,
		"release_direction": _actor.beam_release_direction,
		"sword_sheathed": _actor.sword_sheathed,
		"charge_visible": _actor.beam_charge_visual != null and _actor.beam_charge_visual.visible,
		"hands_visible": _actor.beam_left_hand_glow != null and _actor.beam_left_hand_glow.visible and _actor.beam_right_hand_glow != null and _actor.beam_right_hand_glow.visible,
		"release_emitted": _actor.beam_release_emitted,
		"cancel_reason": _actor.beam_cancel_reason,
	}

func get_oathfire_origin() -> Vector3:
	var left: Variant = _actor._live_oathfire_hand_origin(_actor.beam_left_hand_socket, _actor.beam_left_hand_glow, _actor.global_position + Vector3(-0.16, 1.28, -0.48))
	var right: Variant = _actor._live_oathfire_hand_origin(_actor.beam_right_hand_socket, _actor.beam_right_hand_glow, _actor.global_position + Vector3(0.16, 1.28, -0.48))
	var direction: Vector3 = _actor.beam_locked_direction if _actor.beam_locked_direction.length_squared() > 0.5 else -_actor.global_transform.basis.z.normalized()
	return left.lerp(right, 0.5) + direction * 0.24

func _live_oathfire_hand_origin(socket: BoneAttachment3D, glow: MeshInstance3D, fallback: Vector3) -> Vector3:
	if socket != null:
		var skeleton: Variant = socket.get_parent() as Skeleton3D
		if skeleton != null and socket.bone_idx >= 0:
			return (skeleton.global_transform * skeleton.get_bone_global_pose(socket.bone_idx)).origin
	if glow != null:
		return glow.global_position
	return fallback

func _update_beam_charge_visual() -> void:
	if _actor.beam_charge_visual == null:
		return
	_actor.beam_charge_visual.visible = true
	var ratio: float = _actor.beam_pending_ratio if _actor.beam_cast_state == "releasing" else clampf(_actor.beam_charge_time / 1.25, 0.0, 1.0)
	var pulse: float = 1.0 + sin(Time.get_ticks_msec() * 0.018) * 0.07
	_actor.beam_charge_visual.scale = Vector3.ONE * lerpf(0.08, 0.28, ratio) * pulse
	_actor.beam_charge_visual.global_position = _actor.get_oathfire_origin()
	if _actor.beam_left_hand_glow != null:
		_actor.beam_left_hand_glow.visible = true
		_actor.beam_left_hand_glow.scale = Vector3.ONE * lerpf(0.55, 0.95, ratio)
	if _actor.beam_right_hand_glow != null:
		_actor.beam_right_hand_glow.visible = true
		_actor.beam_right_hand_glow.scale = Vector3.ONE * lerpf(0.55, 0.95, ratio)

func _hide_beam_charge_visuals() -> void:
	for glow in [_actor.beam_charge_visual, _actor.beam_left_hand_glow, _actor.beam_right_hand_glow]:
		if glow != null:
			glow.visible = false

func _set_sword_sheathed(sheathed: bool) -> void:
	_actor.sword_sheathed = sheathed
	if sheathed and _actor.slash_arc_root != null:
		_actor.slash_arc_root.visible = false

func is_blocking() -> bool:
	return not _actor.field_tool_aiming and _actor.weapon_mode == "sword" and not _actor.sword_sheathed and not _actor.equipment_loadout.is_transitioning() and _actor._action_pressed("block") and _actor.stamina_component.stamina > 8.0
