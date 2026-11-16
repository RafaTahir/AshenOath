extends RefCounted
## player bow view: scene-only responsibilities.

var _actor: CharacterBody3D

func _init(actor: CharacterBody3D) -> void:
	_actor = actor

func get_selected_arrow_id() -> String:
	return _actor.selected_arrow_id

func select_arrow(item_id: String) -> bool:
	if _actor.inventory_ref == null or _actor.inventory_ref.get_item_type(item_id) != "ammo" or int(_actor.inventory_ref.items.get(item_id, 0)) <= 0:
		return false
	_actor.selected_arrow_id = item_id
	_actor.bow_draw_time = 0.0
	_actor.bow_drawing = false
	_actor.bow_requires_fire_release = _actor._action_pressed("fire_bow")
	if _actor.equipment_loadout != null:
		_actor.equipment_loadout.set_selected_arrow(item_id)
	return true

func get_selected_arrow_count() -> int:
	return int(_actor.inventory_ref.items.get(_actor.selected_arrow_id, 0)) if _actor.inventory_ref != null else 0

func _cycle_arrow_type() -> void:
	var arrow_ids: Variant = ["standard_arrow", "bodkin_arrow", "ashfire_arrow"]
	var start: Variant = arrow_ids.find(_actor.selected_arrow_id)
	for offset in range(1, arrow_ids.size() + 1):
		var candidate: String = arrow_ids[(start + offset) % arrow_ids.size()]
		if _actor.inventory_ref != null and int(_actor.inventory_ref.items.get(candidate, 0)) > 0:
			_actor.selected_arrow_id = candidate
			if _actor.equipment_loadout != null:
				_actor.equipment_loadout.set_selected_arrow(candidate)
			return
	_actor.selected_arrow_id = "standard_arrow"
	if _actor.equipment_loadout != null:
		_actor.equipment_loadout.set_selected_arrow(_actor.selected_arrow_id)

func _handle_bow_input() -> void:
	if not _actor.equipment_loadout.bow_drawn:
		if _actor._action_pressed("aim_bow") or _actor._action_pressed("fire_bow"):
			_actor.equipment_loadout.request_loadout("bow", _actor.get_selected_blade_id(), true)
		return
	if _actor._action_just_pressed("cycle_arrow"):
		_actor._cancel_bow()
		_actor._cycle_arrow_type()
	if _actor._action_just_pressed("fire_bow") and not _actor.bow_has_arrow():
		_actor._cycle_arrow_type()
	var model: RefCounted = _actor.bow_model
	var ammo: RefCounted = _ammo_snapshot()
	var frame: RefCounted = preload("res://scripts/core/input_frame.gd").new()
	frame.tick = _actor._simulation_tick
	frame.selected_slot = maxi(0, ammo.FAMILY_IDS.find(_actor.selected_arrow_id))
	if _actor._action_pressed("aim_bow"):
		frame.buttons |= model.AIM
	if _actor._action_pressed("fire_bow") or _actor._action_just_pressed("fire_bow"):
		frame.buttons |= model.FIRE
	if _actor._action_just_pressed("dodge") or _actor.dodge_time > 0.0 or _actor.hurt_react_time > 0.0:
		frame.buttons |= model.CANCEL
	_actor.bow_aiming = frame.buttons & (model.AIM | model.FIRE) != 0 or model.state == "drawing"
	_actor.equipment_loadout.set_bow_aiming(_actor.bow_aiming)
	_actor._update_bow_presentation(0.0)
	model.draw_duration = _actor.get_bow_draw_duration()
	model.recovery_duration = maxf(0.10, 0.24 * _actor._progression_value("bow_recovery_multiplier", 1.0) - _actor._progression_value("saga_bow_recovery_reduction", 0.0))
	model.training = _actor.is_bow_training_active()
	var range_owner: Node = _actor.training_range.get_ref() if model.training else null
	model.release_allowed = not model.training or range_owner.training_ready()
	model.clearance = not bool(_actor.bow_aim_solution.get("blocked", false))
	model.stamina = _actor.stamina_component.stamina
	var before_stamina: float = model.stamina
	var previous_draw: float = model.draw_time
	var effect: Dictionary = _actor.inventory_ref.item_defs.get(_actor.selected_arrow_id, {}).get("effect", {}) if _actor.inventory_ref != null else {}
	var events: RefCounted = preload("res://scripts/core/sim_event_bus.gd").new()
	model.step(frame, _actor._tick_delta, ammo, events, effect)
	if model.stamina < before_stamina:
		_actor.stamina_component.spend(before_stamina - model.stamina)
	_actor.bow_draw_time = model.draw_time
	_actor.bow_drawing = model.state == "drawing"
	_actor.bow_recovery = model.recovery
	_actor.bow_requires_fire_release = model.requires_release
	if previous_draw < model.draw_duration and model.draw_time >= model.draw_duration and _actor.input_source != null:
		_actor.input_source.rumble(0.12, 0.08, 0.05)
	for event: Dictionary in events.drain_events():
		if event.kind == "arrow_released":
			_publish_release(event.payload, ammo)
		elif event.kind == "arrow_unavailable":
			_actor.arrow_unavailable.emit()
		elif event.kind == "bow_obstructed":
			_actor.ability_hint.emit("The bow needs clearance.")
		elif event.kind == "stamina_exhausted":
			_actor.stamina_exhausted.emit("bow")

func _ammo_snapshot() -> RefCounted:
	var ammo: RefCounted = preload("res://scripts/models/ammo_loadout_model.gd").new()
	ammo.load_inventory(_actor.inventory_ref.save_state() if _actor.inventory_ref != null else {"items": {}})
	ammo.selected_family = _actor.selected_arrow_id
	return ammo

func _publish_release(payload: Dictionary, ammo: RefCounted) -> void:
	var training: bool = bool(payload.get("training", false))
	var range_owner: Node = _actor.training_range.get_ref() if training and _actor.training_range != null else null
	if training and not is_instance_valid(range_owner):
		return
	if not training:
		_actor.inventory_ref.items.merge(ammo.counts, true)
		_actor.inventory_ref.changed.emit()
	_actor._update_bow_presentation(0.0)
	var request: Dictionary = payload.duplicate(true)
	request.merge({"training": training, "training_owner": range_owner.get_instance_id() if training else 0,
		"origin": _actor.get_arrow_origin(), "direction": _actor.bow_aim_solution.get("direction", -_actor.global_basis.z),
		"arrow_id": str(payload.arrow_family_id), "draw_ratio": float(payload.charge_ratio),
		"range": _actor.BOW_RANGE, "width": 0.34}, true)
	_actor.arrow_requested.emit(request)
	if _actor.bow_presentation != null:
		_actor.bow_presentation.on_release(float(payload.charge_ratio))
	if _actor.input_source != null:
		_actor.input_source.rumble(0.16, 0.10, 0.07)

func _handle_field_tool() -> bool:
	if _actor.attack_anim_time > 0.0 or _actor.dodge_time > 0.0 or _actor.hurt_react_time > 0.0 or _actor.equipment_loadout.is_transitioning():
		_actor._field_tool_pressed = false
		_actor.field_tool_aiming = false
		return false
	if _actor._action_just_pressed("throw_bomb"):
		_actor._cancel_bow()
		_actor._field_tool_pressed = true
		_actor.field_tool_aiming = true
	if not _actor._field_tool_pressed: return false
	if _actor._action_just_pressed("dodge") or _actor._action_just_pressed("aim_bow"):
		_actor._field_tool_pressed = false
		_actor.field_tool_aiming = false
		return false
	if not _actor._action_pressed("throw_bomb"):
		_actor._field_tool_pressed = false
		_actor.bomb_requested.emit()
		_actor.field_tool_aiming = false
	return true

func field_tool_aim() -> Dictionary:
	var origin: Variant = _actor.global_position + Vector3.UP * 1.15
	var direction: Variant = -_actor.global_basis.z
	var solution: Dictionary = {"direction": direction, "point": origin + direction * 18.0}
	if _actor.camera_controller != null:
		solution = _actor.camera_controller.bow_aim_solution(origin, 18.0, false)
	solution["origin"] = origin
	return solution

func _cancel_bow() -> void:
	_actor.bow_model.cancel(_actor._action_pressed("fire_bow"))
	_actor.bow_aiming = false
	_actor.bow_drawing = false
	_actor.bow_draw_time = 0.0
	_actor.bow_requires_fire_release = _actor._action_pressed("fire_bow")
	_actor.equipment_loadout.set_bow_aiming(false)

func bow_has_arrow() -> bool:
	return (_actor.training_range != null and is_instance_valid(_actor.training_range.get_ref())) or _actor.get_selected_arrow_count() > 0

func is_bow_training_active() -> bool:
	return _actor.training_range != null and is_instance_valid(_actor.training_range.get_ref())

func is_bow_pose_active() -> bool:
	if _actor.input_source != null and not _actor.input_source.is_gameplay_context(): return false
	return _actor.can_control and not _actor.transition_locked and _actor.weapon_mode == "bow" and _actor.equipment_loadout.bow_drawn and not _actor.equipment_loadout.is_transitioning() and _actor.beam_cast_state == _actor.BEAM_STATE_IDLE and _actor.dodge_time <= 0.0 and _actor.hurt_react_time <= 0.0

func _update_bow_presentation(delta: float) -> void:
	var aiming: Variant = _actor.is_bow_pose_active() and _actor.bow_aiming
	_actor.bow_pose_aim = move_toward(_actor.bow_pose_aim, 1.0 if aiming else 0.0, delta * 7.0)
	if _actor.bow_pose_aim <= 0.0 and not aiming:
		_actor.bow_pose_direction = -_actor.global_basis.z
		_actor.bow_aim_solution.clear()
		return
	var origin: Variant = _actor.get_arrow_origin()
	if _actor.camera_controller != null and (_actor.camera_controller != null):
		_actor.bow_aim_solution = _actor.camera_controller.bow_aim_solution(origin, _actor.BOW_RANGE)
		_actor.bow_pose_direction = _actor.bow_aim_solution.get("direction", -_actor.global_basis.z)
	else:
		_actor.bow_pose_direction = -_actor.global_basis.z
		_actor.bow_aim_solution = {"point": origin + _actor.bow_pose_direction * _actor.BOW_RANGE, "direction": _actor.bow_pose_direction}
	_actor.bow_aim_solution["draw"] = clampf(_actor.bow_draw_time / _actor.get_bow_draw_duration(), 0.0, 1.0)
	_actor.bow_aim_solution["ammo"] = _actor.bow_has_arrow()

func _release_bow() -> void:
	var ammo: RefCounted = _ammo_snapshot()
	var model: RefCounted = _actor.bow_model
	model.active_family = _actor.selected_arrow_id
	model.training = _actor.is_bow_training_active()
	model.draw_duration = _actor.get_bow_draw_duration()
	model.draw_time = _actor.bow_draw_time
	_actor._update_bow_presentation(0.0)
	model.clearance = not bool(_actor.bow_aim_solution.get("blocked", false))
	var events: RefCounted = preload("res://scripts/core/sim_event_bus.gd").new()
	var effect: Dictionary = _actor.inventory_ref.item_defs.get(_actor.selected_arrow_id, {}).get("effect", {}) if _actor.inventory_ref != null else {}
	model.release(_actor._simulation_tick, ammo, events, effect, model.tension())
	for event: Dictionary in events.drain_events():
		if event.kind == "arrow_released":
			_publish_release(event.payload, ammo)
		elif event.kind == "arrow_unavailable":
			_actor.arrow_unavailable.emit()
	_actor.bow_draw_time = 0.0
	_actor.bow_recovery = model.recovery

func get_arrow_origin() -> Vector3:
	# SkeletonModifier poses are restored after publication. Keep the rendered
	# arrow rest in actor-local space so physics uses it, including after relocation.
	if _actor.bow_pose_valid and _actor.is_bow_pose_active():
		return _actor.global_transform * _actor.bow_pose_local_origin
	if _actor.bow_attachment != null and is_instance_valid(_actor.bow_attachment):
		var frame: Variant = _actor._equipment_anchor_world(_actor.bow_visual)
		return frame.origin + frame.basis.y.normalized() * 0.045 + frame.basis.x.normalized() * 0.012
	var forward: Variant = -_actor.global_transform.basis.z.normalized()
	return _actor.global_position + Vector3.UP * 1.30 + forward * 0.48
