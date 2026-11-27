extends RefCounted
## player action view: scene-only responsibilities.

var _actor: CharacterBody3D

func _init(actor: CharacterBody3D) -> void:
	_actor = actor

func set_transition_locked(locked: bool) -> void:
	if locked:
		_actor._field_tool_pressed = false
		_actor.field_tool_aiming = false
		_actor._cancel_equipment_action()
		_actor._cancel_bow()
	if locked and _actor.beam_cast_state != _actor.BEAM_STATE_IDLE:
		_actor.cancel_beam_charge("transition")
	_actor.transition_locked = locked
	if locked:
		_actor.can_control = false
		_actor.velocity = Vector3.ZERO
		_actor.locomotion_velocity = Vector3.ZERO
	elif _actor.health_component == null or _actor.health_component.health > 0.0:
		_actor.can_control = true

func cancel_buffered_input(reason: String = "context") -> void:
	_actor._pending_pressed.clear()
	_actor._pending_released.clear()
	_actor._field_tool_pressed = false
	_actor.field_tool_aiming = false
	_actor._movement_frame_active = false
	_actor.end_companion_gesture(true)
	_actor._cancel_equipment_action()
	_actor.buffered_attack = ""
	_actor.attack_buffer_time = 0.0
	_actor.pending_attack_damage = 0.0
	_actor.pending_attack_radius = 0.0
	_actor.attack_contact_emitted = true
	_actor.attack_anim_time = 0.0
	_actor.parry_window = 0.0
	_actor._cancel_bow()
	_actor.dodge_time = 0.0
	_actor.velocity.x = 0.0
	_actor.velocity.z = 0.0
	_actor.locomotion_velocity = Vector3.ZERO
	if _actor.beam_cast_state != _actor.BEAM_STATE_IDLE or _actor.beam_charging:
		_actor.cancel_beam_charge(reason)
	elif _actor.animation_driver != null and (_actor.animation_driver != null):
		_actor.animation_driver.stop_action("idle", 0.12)
	if _actor.slash_arc_root != null:
		_actor.slash_arc_root.visible = false

func bind_inventory(value: Variant, story: Node = null) -> void:
	if story != null: preload("res://scripts/views/novel/bow_custody.gd").bind(_actor,story)
	_actor.inventory_ref = value
	if _actor.inventory_ref != null and int(_actor.inventory_ref.items.get(_actor.selected_arrow_id, 0)) <= 0:
		_actor._cycle_arrow_type()

func get_weapon_mode() -> String:
	return _actor.weapon_mode

func get_selected_blade_id() -> String:
	return _actor.equipment_loadout.selected_blade_id

func get_selected_weapon_name() -> String:
	return _actor.equipment_loadout.selected_weapon_name()

func _set_weapon_mode(next_mode: String) -> void:
	var normalized: Variant = "bow" if next_mode == "bow" else "sword"
	if _actor.weapon_mode == normalized:
		return
	_actor._cancel_bow()
	_actor.weapon_mode = normalized
	_actor._set_sword_sheathed(true)

func _select_blade(blade_id: String) -> void:
	_actor._request_equipment("sword", blade_id, true)

func _request_equipment(mode: String, blade_id: String, drawn: bool) -> void:
	if mode == "bow" and not _actor.equipment_loadout.bow_available:
		_actor.ability_hint.emit("The hunting bow went into the river. A spare hangs at the east landing.")
		return
	_actor._cancel_bow()
	_actor.equipment_pending_attack = ""
	_actor.buffered_attack = ""
	_actor.attack_buffer_time = 0.0
	_actor.parry_window = 0.0
	_actor.pending_attack_damage = 0.0
	_actor.pending_attack_radius = 0.0
	_actor.equipment_loadout.request_loadout(mode, blade_id, drawn)
	_actor.previous_blade_base = Vector3.ZERO
	_actor.previous_blade_tip = Vector3.ZERO
	_actor.visual_previous_blade_base = Vector3.ZERO
	_actor.visual_previous_blade_tip = Vector3.ZERO

func _cycle_weapon() -> void:
	if _actor.weapon_mode == "bow":
		_actor._select_blade("steel")
	elif _actor.get_selected_blade_id() == "steel":
		_actor._select_blade("oathblade")
	elif _actor.equipment_loadout.bow_available:
		_actor._request_equipment("bow", _actor.get_selected_blade_id(), true)
	else:
		_actor._select_blade("steel")

func _toggle_weapon_draw() -> void:
	_actor._request_equipment(_actor.weapon_mode, _actor.get_selected_blade_id(), not _actor.equipment_loadout.is_drawn())

func _handle_equipment_input() -> void:
	var available: bool = _actor.beam_cast_state == _actor.BEAM_STATE_IDLE and _actor.attack_anim_time <= 0.0 and _actor.dodge_time <= 0.0 and _actor.hurt_react_time <= 0.0 and not _actor.equipment_loadout.is_transitioning()
	if _actor._action_just_pressed("weapon_cycle"):
		_actor.weapon_cycle_armed = available
		_actor.weapon_cycle_held = false
		_actor.weapon_cycle_elapsed = 0.0
	if _actor.weapon_cycle_armed and _actor._action_pressed("weapon_cycle"):
		_actor.weapon_cycle_elapsed += _actor._tick_delta
		if _actor.weapon_cycle_elapsed >= 0.45 and not _actor.weapon_cycle_held:
			_actor.weapon_cycle_held = true
			if available:
				_actor._toggle_weapon_draw()
	if _actor.weapon_cycle_armed and _actor._action_just_released("weapon_cycle"):
		if not _actor.weapon_cycle_held and available:
			_actor._cycle_weapon()
		_actor.weapon_cycle_armed = false
	if not available or _actor.equipment_loadout.is_transitioning():
		return
	if _actor._action_just_pressed("weapon_sheath"):
		_actor._toggle_weapon_draw()
	elif _actor._action_just_pressed("weapon_bow"):
		_actor._request_equipment("bow", _actor.get_selected_blade_id(), true)
	elif _actor._action_just_pressed("weapon_sword"):
		_actor._select_blade("steel")
	elif _actor._action_just_pressed("weapon_oathblade"):
		_actor._select_blade("oathblade")

func _on_equipment_transition_started(action: String, duration: float) -> void:
	# Keep locomotion clips running while moving; the existing arm IK supplies
	# the reach. Stationary transfers can use the compatible retained clip.
	if _actor.animation_driver != null and _actor.locomotion_velocity.length_squared() < 0.04:
		_actor.animation_driver.trigger_action(action, 1.0, 0.08, false, duration)

func _on_equipment_transition_finished() -> void:
	if _actor.animation_driver != null and _actor.animation_driver.current_state in ["draw", "sheath"]:
		_actor.animation_driver.stop_action("idle", 0.08)

func _cancel_equipment_action() -> void:
	var was_transitioning: Variant = _actor.equipment_loadout.is_transitioning()
	_actor.equipment_loadout.cancel_transition()
	_actor.equipment_pending_attack = ""
	_actor.weapon_cycle_armed = false
	_actor.weapon_cycle_held = false
	_actor.weapon_cycle_elapsed = 0.0
	if was_transitioning and _actor.guard_arm_ik != null:
		_actor.guard_arm_ik.stop()
		_actor.guard_arm_applied = false
	if _actor.equipment_left_arm_ik != null:
		_actor.equipment_left_arm_ik.stop()

func set_progression(manager: Variant) -> void:
	if _actor.progression != null and _actor.progression.changed.is_connected(_actor._apply_progression_stats):
		_actor.progression.changed.disconnect(_actor._apply_progression_stats)
	_actor.progression = manager
	if _actor.progression != null and not _actor.progression.changed.is_connected(_actor._apply_progression_stats):
		_actor.progression.changed.connect(_actor._apply_progression_stats)
	_actor._apply_progression_stats()

func _apply_progression_stats() -> void:
	if _actor.health_component == null:
		return
	var target_max: Variant = 125.0 + _actor._progression_value("max_health_bonus", 0.0) + _actor._progression_value("saga_max_health_bonus", 0.0)
	_actor.health_component.max_health = target_max
	# Learning, refunding or receiving XP must not heal Kael or revive a dead body.
	_actor.health_component.health = clampf(_actor.health_component.health, 0.0, target_max)
	_actor.health_component.changed.emit(_actor.health_component.health, _actor.health_component.max_health)
	if _actor.stamina_component != null:
		_actor.stamina_component.max_stamina = 100.0 + _actor._progression_value("saga_max_stamina_bonus", 0.0)
		_actor.stamina_component.stamina = minf(_actor.stamina_component.stamina, _actor.stamina_component.max_stamina)
		_actor.stamina_component.changed.emit(_actor.stamina_component.stamina, _actor.stamina_component.max_stamina)

func _progression_value(effect_id: String, fallback: float) -> float:
	return _actor.progression.effect_value(effect_id, fallback) if _actor.progression != null else fallback

func get_bow_aim_sensitivity() -> float:
	return _actor._progression_value("bow_aim_sensitivity_multiplier", 1.0)

func _entitlement_value(id: String, fallback: float) -> float:
	return _actor.progression.entitlement_effect(id, fallback) if _actor.progression != null else fallback

func get_bow_draw_duration() -> float:
	return _actor.BOW_MAX_DRAW * _actor._entitlement_value("saga_draw_multiplier", 1.0)

func get_oathfire_charge_multiplier() -> float:
	return _actor._progression_value("saga_charge_multiplier", 1.0)

func get_dodge_stamina_cost() -> float:
	return maxf(1.0, 28.0 + float(_actor.difficulty_profile.get("dodge_cost_modifier", 0.0)) - _actor._progression_value("dodge_cost_reduction", 0.0))

func apply_difficulty_profile(profile: Dictionary) -> void:
	_actor.difficulty_profile = {
		"incoming_damage_multiplier": clampf(float(profile.get("incoming_damage_multiplier", 1.0)), 0.25, 2.0),
		"parry_window": clampf(float(profile.get("parry_window", 0.30)), 0.15, 0.50),
		"dodge_cost_modifier": clampf(float(profile.get("dodge_cost_modifier", 0.0)), -10.0, 10.0),
		"attack_buffer": clampf(float(profile.get("attack_buffer", 0.18)), 0.10, 0.30),
	}

func get_oathfire_stamina_cost() -> float:
	return maxf(1.0, 40.0 - _actor._progression_value("beam_cost_reduction", 0.0) - _actor._progression_value("saga_beam_cost_reduction", 0.0))

func get_oathfire_cooldown_duration() -> float:
	return maxf(0.5, 4.0 - _actor._progression_value("beam_cooldown_reduction", 0.0) - _actor._entitlement_value("saga_cooldown_reduction", 0.0))

func get_blade_attack_damage(heavy: bool = false) -> float:
	var base_damage: Variant = 42.0 if heavy else 24.0
	var multiplier: Variant = _actor._progression_value("blade_damage_multiplier", 1.0)
	if heavy:
		multiplier *= _actor._progression_value("heavy_damage_multiplier", 1.0)
	var forge_bonus: float = _actor.inventory_ref.blade_upgrade_bonus(_actor.get_selected_blade_id()) if _actor.inventory_ref != null else 0.0
	return base_damage * multiplier + forge_bonus

func _handle_combat_input() -> void:
	_actor._handle_equipment_input()
	if _actor.beam_cast_state != _actor.BEAM_STATE_IDLE:
		_actor._handle_beam_input()
		return
	if _actor.beam_cast_state == _actor.BEAM_STATE_IDLE:
		if _actor._action_just_pressed("use_potion"):
			_actor.potion_requested.emit()
		if _actor._handle_field_tool(): return
	if _actor.weapon_mode == "bow":
		# LT is bow aim in this weapon context, not an Oathfire cast. A separately
		# bound Oathfire press stows the bow until the cast restores its prior intent.
		if _actor._action_just_pressed("oathfire_beam") and not _actor._action_just_pressed("aim_bow"):
			_actor._handle_beam_input()
		elif not _actor.equipment_loadout.is_transitioning():
			_actor._handle_bow_input()
		return
	_actor._handle_beam_input()
	if _actor.beam_cast_state != "" or _actor.equipment_loadout.is_transitioning():
		return
	var light_pressed: Variant = _actor._action_just_pressed("light_attack") or _actor.equipment_pending_attack == "light"
	var heavy_pressed: Variant = _actor._action_just_pressed("heavy_attack") or _actor.equipment_pending_attack == "heavy"
	_actor.equipment_pending_attack = ""
	if light_pressed or heavy_pressed:
		_actor._face_attack_direction()
	if _actor.sword_sheathed and (light_pressed or heavy_pressed or _actor._action_pressed("block")):
		_actor.equipment_pending_attack = "heavy" if heavy_pressed else ("light" if light_pressed else "")
		_actor._draw_sword_for_combat()
		return
	var model: RefCounted = _actor.combat_model
	model.tick = _actor._simulation_tick
	model.attack_cooldown = _actor.attack_cooldown
	model.attack_time = _actor.attack_anim_time
	model.attack_heavy = _actor.attack_anim_heavy
	model.buffered_attack = _actor.buffered_attack
	model.buffer_time = _actor.attack_buffer_time
	model.beam_state = _actor.beam_cast_state
	model.dodge_time = _actor.dodge_time
	model.stamina = _actor.stamina_component.stamina
	model.difficulty = _actor.difficulty_profile
	model.configuration = {"heavy_cost_reduction": _actor._progression_value("saga_heavy_cost_reduction", 0.0), "light_recovery_multiplier": _actor._progression_value("saga_light_recovery_multiplier", 1.0)}
	var sequence: int = model.attack_sequence
	var before_stamina: float = model.stamina
	var events: RefCounted = preload("res://scripts/core/sim_event_bus.gd").new()
	model._step_melee((model.LIGHT if light_pressed else 0) | (model.HEAVY if heavy_pressed else 0), events)
	_actor.attack_cooldown = model.attack_cooldown
	_actor.attack_anim_time = model.attack_time
	_actor.attack_anim_heavy = model.attack_heavy
	_actor.buffered_attack = model.buffered_attack
	_actor.attack_buffer_time = model.buffer_time
	if before_stamina > model.stamina:
		_actor.stamina_component.spend(before_stamina - model.stamina)
	for event: Dictionary in events.drain_events():
		if event.kind == "stamina_exhausted":
			_actor.stamina_exhausted.emit(str(event.payload.action))
	if sequence != model.attack_sequence:
		_actor._face_attack_direction()
		if _actor.animation_driver != null:
			_actor.animation_driver.trigger_action("attack_heavy" if model.attack_heavy else "attack_light", 0.76 if model.attack_heavy else 1.22, 0.08 if model.attack_heavy else 0.06, false, model.attack_time)
		_actor._begin_blade_attack(_actor.get_blade_attack_damage(model.attack_heavy), 2.25 if model.attack_heavy else 2.0, model.attack_heavy)
	if _actor._action_just_pressed("block"):
		_actor.parry_window = _actor.get_parry_window_duration()
		if _actor.animation_driver != null:
			_actor.animation_driver.trigger_action("parry")

func take_damage(amount: float) -> bool:
	var resolution: Dictionary = _actor.combat_model.damage_resolution(amount, _actor.dodge_time, _actor.parry_window, _actor.is_blocking(), _actor.stamina_component.stamina, _actor.difficulty_profile, _actor._entitlement_value("saga_guard_multiplier", 1.0))
	amount = float(resolution.damage)
	if _actor.dodge_time > 0.0:
		return false
	if resolution.kind == "parried" and _actor.stamina_component.spend(float(resolution.cost)):
		_actor.parry_window = 0.0
		_actor.hurt_flash_time = 0.0
		_actor.hurt_react_time = 0.0
		if _actor.animation_driver != null:
			_actor.animation_driver.trigger_action("parry", 1.0, 0.04, true)
		_actor.parried.emit()
		return true
	var guarded: Variant = _actor.is_blocking()
	_actor._cancel_bow()
	_actor._cancel_equipment_action()
	if _actor.beam_cast_state != _actor.BEAM_STATE_IDLE:
		_actor.cancel_beam_charge("hit")
	if resolution.kind == "blocked" and _actor.stamina_component.spend(float(resolution.cost)):
		var reduced: float = amount
		_actor.health_component.damage(reduced)
		_actor.hurt_flash_time = 0.10
		_actor.hurt_react_time = 0.13
		if _actor.animation_driver != null:
			_actor.animation_driver.trigger_action("hit")
		_actor.blocked.emit(reduced)
	else:
		_actor.health_component.damage(amount)
		_actor.hurt_flash_time = 0.18
		_actor.hurt_react_time = 0.20
		if _actor.animation_driver != null:
			_actor.animation_driver.trigger_action("hit")
		_actor.hurt.emit(amount)
	return false

func _on_died() -> void:
	_actor._cancel_bow()
	_actor._cancel_equipment_action()
	_actor.cancel_beam_charge("death")
	_actor.equipment_loadout.stow_all()
	_actor.can_control = false
	if _actor.animation_driver != null:
		_actor.animation_driver.set_dead()
	_actor.died.emit()
