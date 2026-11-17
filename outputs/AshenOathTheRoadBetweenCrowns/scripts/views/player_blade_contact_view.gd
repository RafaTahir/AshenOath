extends RefCounted
## player blade contact view: scene-only responsibilities.

var _actor: CharacterBody3D

func _init(actor: CharacterBody3D) -> void:
	_actor = actor

func _begin_blade_attack(damage: float, radius: float, heavy: bool) -> void:
	_actor.attack_sequence_id += 1
	_actor.attack_contact_emitted = false
	_actor.previous_contact_progress = 0.0
	_actor.pending_attack_damage = damage
	_actor.pending_attack_radius = radius
	_actor.pending_attack_heavy = heavy
	var segment: Dictionary = _actor.get_blade_world_segment()
	_actor.previous_blade_base = segment.get("base", _actor.global_position + Vector3(0, 1.0, 0))
	_actor.previous_blade_tip = segment.get("tip", _actor.previous_blade_base)

func _update_blade_contact() -> void:
	if not _actor.is_blade_ready():
		_actor.pending_attack_damage = 0.0
		_actor.pending_attack_radius = 0.0
		return
	if _actor.pending_attack_damage <= 0.0:
		return
	var segment: Dictionary = _actor.get_blade_world_segment()
	var blade_base: Vector3 = segment.get("base", Vector3.ZERO)
	var blade_tip: Vector3 = segment.get("tip", Vector3.ZERO)
	var duration: float = 0.52 if _actor.pending_attack_heavy else 0.34
	var progress: float = clampf(1.0 - _actor.attack_anim_time / duration, 0.0, 1.0)
	if progress <= _actor.previous_contact_progress:
		return
	var strike_start: Variant = 0.30 if _actor.pending_attack_heavy else 0.18
	var strike_end: Variant = 0.64 if _actor.pending_attack_heavy else 0.42
	if progress >= strike_start and _actor.previous_contact_progress < strike_end:
		# Clip the measured frame sweep to the damaging part of the animation.
		var span: Variant = progress - _actor.previous_contact_progress
		var from_weight: Variant = clampf((strike_start - _actor.previous_contact_progress) / span, 0.0, 1.0)
		var to_weight: Variant = clampf((strike_end - _actor.previous_contact_progress) / span, 0.0, 1.0)
		var first_sample: Variant = not _actor.attack_contact_emitted
		_actor.attack_contact_emitted = true
		_actor.blade_contact_requested.emit({
			"attack_id": _actor.attack_sequence_id,
			"blade_id": _actor.get_selected_blade_id(),
			"base": _actor.previous_blade_base.lerp(blade_base, to_weight),
			"tip": _actor.previous_blade_tip.lerp(blade_tip, to_weight),
			"previous_base": _actor.previous_blade_base.lerp(blade_base, from_weight),
			"previous_tip": _actor.previous_blade_tip.lerp(blade_tip, from_weight),
			"damage": _actor.pending_attack_damage,
			"reach": _actor.pending_attack_radius,
			"heavy": _actor.pending_attack_heavy,
			"contact_phase": progress,
			"sweep_length": maxf(_actor.previous_blade_tip.distance_to(blade_tip), _actor.previous_blade_base.distance_to(blade_base)),
			"blade_direction": (blade_tip - blade_base).normalized() if blade_tip.distance_to(blade_base) > 0.001 else Vector3.ZERO,
			"first_sample": first_sample,
			"final_sample": progress >= strike_end
		})
	if progress >= strike_end:
		_actor.pending_attack_damage = 0.0
		_actor.pending_attack_radius = 0.0
	_actor.previous_contact_progress = progress
	_actor.previous_blade_base = blade_base
	_actor.previous_blade_tip = blade_tip

func confirm_blade_contact(attack_id: int, hit: bool) -> void:
	if hit and attack_id == _actor.attack_sequence_id:
		_actor.pending_attack_damage = 0.0
		_actor.pending_attack_radius = 0.0

func get_parry_window_duration() -> float:
	return float(_actor.difficulty_profile.get("parry_window", 0.30))

func get_attack_buffer_duration() -> float:
	return float(_actor.difficulty_profile.get("attack_buffer", 0.18))

func is_blade_ready() -> bool:
	return _actor.can_control and not _actor.transition_locked and _actor.weapon_mode == "sword" and not _actor.sword_sheathed and not _actor.equipment_loadout.is_transitioning() and _actor.beam_cast_state == _actor.BEAM_STATE_IDLE and _actor.dodge_time <= 0.0 and _actor.hurt_react_time <= 0.0 and is_instance_valid(_actor.blade_base_marker) and is_instance_valid(_actor.blade_tip_marker)

func get_blade_world_segment() -> Dictionary:
	if _actor.blade_base_marker != null and _actor.blade_tip_marker != null and is_instance_valid(_actor.blade_base_marker) and is_instance_valid(_actor.blade_tip_marker):
		return {"base": _actor.blade_base_marker.global_position, "tip": _actor.blade_tip_marker.global_position}
	var forward: Variant = -_actor.global_transform.basis.z.normalized()
	var base: Variant = _actor.global_position + Vector3(0, 1.05, 0) + forward * 0.35
	return {"base": base, "tip": base + forward * 1.25}
