extends RefCounted
var _router: Node
func _init(router: Node) -> void:
	_router = router
func apply_settings(current: Dictionary) -> void:
	_router.settings_ref = current
	if not _router.SettingsDelta.changed(_router._applied_setting_groups, "input", _router, current, ["block_mode", "sprint_mode", "gamepad_profiles", "gamepad_look_sensitivity", "gamepad_deadzone", "gamepad_invert_x", "gamepad_invert_y", "invert_y", "gamepad_vibration", "gamepad_rumble_strength", "control_preset", "custom_bindings"]):
		return
	_router.reset_transient_input("settings_changed")
	_router._toggle_modes = {"block": str(current.get("block_mode", "hold")), "run": str(current.get("sprint_mode", "hold"))}
	_router.reset_toggle_actions()
	_router.gamepad_profiles = current.get("gamepad_profiles", {}).duplicate(true) if typeof(current.get("gamepad_profiles", {})) == TYPE_DICTIONARY else {}
	var migrated_weapon_defaults: Variant = _router._migrate_legacy_weapon_defaults()
	if migrated_weapon_defaults:
		_router.settings_ref["gamepad_profiles"] = _router.gamepad_profiles.duplicate(true)
	_router.gamepad_look_sensitivity = clampf(float(current.get("gamepad_look_sensitivity", 1.0)), 0.55, 1.55)
	_router.gamepad_deadzone = clampf(float(current.get("gamepad_deadzone", 0.16)), 0.05, 0.35)
	_router.gamepad_invert_x = bool(current.get("gamepad_invert_x", false))
	_router.gamepad_invert_y = bool(current.get("gamepad_invert_y", current.get("invert_y", false)))
	_router.vibration_enabled = bool(current.get("gamepad_vibration", true))
	_router.rumble_strength = clampf(float(current.get("gamepad_rumble_strength", 1.0)), 0.0, 1.0)
	_router._restore_default_bindings()
	_router._apply_keyboard_preset(str(current.get("control_preset", "standard")))
	_router._apply_saved_global_bindings(current.get("custom_bindings", {}))
	_router._apply_active_gamepad_profile()
	_router._refresh_gamepad_profile()
	if migrated_weapon_defaults:
		_router._persist_settings()

func set_settings_manager(manager: Node) -> void:
	_router.settings_manager = manager
	if manager != null and manager.get("settings") != null:
		_router.settings_ref = manager.get("settings")

func get_action_bindings(action: String) -> Array[InputEvent]:
	if not InputMap.has_action(action):
		return []
	return InputMap.action_get_events(action)

func remap_action(action: String, event: InputEvent) -> Dictionary:
	if event == null: return {"ok":false,"reason":"unsupported_event"}
	var current: Dictionary = {}
	for key: StringName in InputMap.get_actions():
		current[str(key)] = []
		for existing: InputEvent in _router.get_action_bindings(str(key)): current[str(key)].append(_router._serialize_event(existing))
	_router.binding_model.load_bindings(current)
	var result: Dictionary = _router.binding_model.remap(action,_router._serialize_event(event))
	if not bool(result.ok): return result
	_router.reset_transient_input("binding_changed")
	for key: String in [action,str(result.conflict)]:
		if key == "": continue
		_router._erase_all_bindings(key)
		for record: Dictionary in _router.binding_model.bindings[key]: _router._add_event_once(key,_router._deserialize_event(record))
	_router._persist_binding_change(_router._binding_type(event))
	_router.bindings_changed.emit({"action":action,"event":_router._serialize_event(event),"conflict":str(result.conflict)})
	return result

func reset_bindings() -> void:
	_router.reset_transient_input("bindings_reset")
	if _router.default_bindings.is_empty():
		_router._capture_default_bindings()
	_router._restore_default_bindings()
	_router._apply_keyboard_preset(str(_router.settings_ref.get("control_preset", "standard")))
	if _router.settings_ref != null:
		_router.settings_ref["custom_bindings"] = {}
		_router.settings_ref["gamepad_profiles"] = {}
	_router.gamepad_profiles = {}
	_router._persist_settings()
	_router.bindings_changed.emit({"reset": true})

func format_binding(event: InputEvent) -> String:
	if event is InputEventKey:
		return OS.get_keycode_string((event as InputEventKey).keycode)
	if event is InputEventMouseButton:
		return "Left Mouse" if event.button_index == MOUSE_BUTTON_LEFT else ("Right Mouse" if event.button_index == MOUSE_BUTTON_RIGHT else "Mouse %d" % event.button_index)
	if event is InputEventJoypadButton:
		return _router._joy_button_label((event as InputEventJoypadButton).button_index)
	if event is InputEventJoypadMotion:
		return _router._joy_axis_label((event as InputEventJoypadMotion).axis, (event as InputEventJoypadMotion).axis_value)
	return "Unbound"

func _apply_keyboard_preset(preset: String) -> void:
	var bindings: Dictionary = _router.KEYBOARD_BINDINGS.duplicate()
	var mouse: Dictionary = _router.MOUSE_BINDINGS.duplicate()
	_router.keyboard_labels = _router.KEYBOARD_LABELS.duplicate()
	if preset == "left_handed":
		bindings.merge({
			"move_forward": KEY_I, "move_back": KEY_K, "move_left": KEY_J, "move_right": KEY_L,
			"dodge": KEY_N, "jump": KEY_M, "block": KEY_U, "interact": KEY_O,
			"use_potion": KEY_P, "throw_bomb": KEY_H,
		}, true)
		mouse["light_attack"] = MOUSE_BUTTON_RIGHT
		mouse["heavy_attack"] = MOUSE_BUTTON_LEFT
		_router.keyboard_labels.merge({
			"interact": "O", "dodge": "N", "jump": "M", "block": "U",
			"light_attack": "Right Mouse", "heavy_attack": "Left Mouse",
			"use_potion": "P", "throw_bomb": "H",
		}, true)
	for action in bindings:
		_router._replace_physical_event(str(action), InputEventKey, int(bindings[action]))
	for action in mouse:
		_router._replace_physical_event(str(action), InputEventMouseButton, int(mouse[action]))

func _replace_physical_event(action: String, event_type: Variant, code: int) -> void:
	_router._ensure_action(action)
	for existing in InputMap.action_get_events(action):
		if is_instance_of(existing, event_type):
			InputMap.action_erase_event(action, existing)
	if event_type == InputEventKey:
		_router._add_key(action, code)
	else:
		_router._add_mouse(action, code)

func _capture_default_bindings() -> void:
	_router.default_bindings.clear()
	for action in InputMap.get_actions():
		var action_name: Variant = str(action)
		var serialized: Array = []
		for event in InputMap.action_get_events(action_name):
			var record: Variant = _router._serialize_event(event)
			if not record.is_empty():
				serialized.append(record)
		_router.default_bindings[action_name] = serialized

func _restore_default_bindings() -> void:
	if _router.default_bindings.is_empty():
		return
	for action in _router.default_bindings:
		_router._erase_all_bindings(str(action))
		for record in _router.default_bindings[action]:
			var event: Variant = _router._deserialize_event(record)
			if event != null:
				_router._add_event_once(str(action), event)

func _apply_saved_global_bindings(saved: Variant) -> void:
	if typeof(saved) != TYPE_DICTIONARY:
		return
	for action in saved:
		var records = saved[action]
		if typeof(records) != TYPE_ARRAY or not InputMap.has_action(str(action)):
			continue
		var restored_types: Variant = {}
		for record in records:
			var event: Variant = _router._deserialize_event(record)
			if event == null or event is InputEventJoypadButton or event is InputEventJoypadMotion:
				continue
			var event_type: Variant = _router._binding_type(event)
			if not restored_types.has(event_type):
				_router._erase_bindings_of_type(str(action), event_type)
				restored_types[event_type] = true
			for added_action in ["weapon_oathblade", "weapon_sheath", "companion_command"]:
				if str(action) != added_action and not saved.has(added_action):
					for added_event in InputMap.action_get_events(added_action):
						if added_event.is_match(event):
							InputMap.action_erase_event(added_action, added_event)
			_router._add_event_once(str(action), event)

func _persist_binding_change(event_type: String) -> void:
	if _router.settings_ref == null:
		return
	if event_type == "joy_button" or event_type == "joy_motion":
		var profiles: Dictionary = _router.settings_ref.get("gamepad_profiles", {}).duplicate(true) if typeof(_router.settings_ref.get("gamepad_profiles", {})) == TYPE_DICTIONARY else {}
		var profile: Dictionary = profiles.get(_router._profile_key(), {}) if typeof(profiles.get(_router._profile_key(), {})) == TYPE_DICTIONARY else {}
		profile["deadzone"] = _router.gamepad_deadzone
		profile["invert_x"] = _router.gamepad_invert_x
		profile["invert_y"] = _router.gamepad_invert_y
		profile["look_sensitivity"] = _router.gamepad_look_sensitivity
		profile["bindings"] = _router._serialize_current_gamepad_bindings()
		profiles[_router._profile_key()] = profile
		_router.settings_ref["gamepad_profiles"] = profiles
	else:
		var custom: Dictionary = _router.settings_ref.get("custom_bindings", {}).duplicate(true) if typeof(_router.settings_ref.get("custom_bindings", {})) == TYPE_DICTIONARY else {}
		custom = _router._serialize_current_global_bindings(custom)
		_router.settings_ref["custom_bindings"] = custom
	_router._persist_settings()

func _serialize_current_gamepad_bindings() -> Dictionary:
	var result: Variant = {}
	for action in InputMap.get_actions():
		var records: Array = []
		for event in InputMap.action_get_events(str(action)):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				var record: Variant = _router._serialize_event(event)
				if not record.is_empty():
					records.append(record)
		if not records.is_empty():
			result[str(action)] = records
	return result

func _serialize_current_global_bindings(existing: Dictionary) -> Dictionary:
	var result: Variant = existing.duplicate(true)
	for action in InputMap.get_actions():
		var records: Array = []
		for event in InputMap.action_get_events(str(action)):
			if event is InputEventKey or event is InputEventMouseButton:
				var record: Variant = _router._serialize_event(event)
				if not record.is_empty():
					records.append(record)
		if not records.is_empty():
			result[str(action)] = records
	return result

func _persist_settings() -> void:
	if _router.settings_manager != null and _router.supports(_router.settings_manager, "save_now"):
		_router.settings_manager.save_now()

func _profile_key() -> String:
	var raw: Variant = _router.active_gamepad_name.strip_edges().to_lower()
	return raw if raw != "" else _router.active_gamepad_family

func _binding_type(event: InputEvent) -> String:
	if event is InputEventKey:
		return "key"
	if event is InputEventMouseButton:
		return "mouse"
	if event is InputEventJoypadButton:
		return "joy_button"
	if event is InputEventJoypadMotion:
		return "joy_motion"
	return ""

func _find_binding_conflict(action: String, event: InputEvent) -> String:
	var conflicts: Variant = _router._find_binding_conflicts(action, event)
	return str(conflicts[0]) if not conflicts.is_empty() else ""

func _find_binding_conflicts(action: String, event: InputEvent) -> Array[String]:
	var conflicts: Array[String] = []
	var event_type: Variant = _router._binding_type(event)
	for candidate in InputMap.get_actions():
		var candidate_name: Variant = str(candidate)
		if candidate_name == action or candidate_name.begins_with("ui_"):
			continue
		if _router._can_share_binding(action, candidate_name, event_type):
			continue
		for existing in InputMap.action_get_events(candidate_name):
			if _router._binding_type(existing) == event_type and existing.is_match(event):
				conflicts.append(candidate_name)
				break
	return conflicts

func _can_share_binding(first: String, second: String, event_type: String) -> bool:
	return _router.binding_model.can_share(first,second,event_type)

func _first_binding_of_type(action: String, event_type: String) -> InputEvent:
	for existing in InputMap.action_get_events(action):
		if _router._binding_type(existing) == event_type:
			return existing.duplicate()
	return null

func _first_gamepad_binding(action: String) -> InputEvent:
	for existing in InputMap.action_get_events(action):
		if existing is InputEventJoypadButton or existing is InputEventJoypadMotion:
			return existing
	return null

func _erase_bindings_of_type(action: String, event_type: String) -> void:
	if not InputMap.has_action(action):
		return
	for existing in InputMap.action_get_events(action).duplicate():
		if _router._binding_type(existing) == event_type:
			InputMap.action_erase_event(action, existing)

func _erase_all_bindings(action: String) -> void:
	if not InputMap.has_action(action):
		return
	for existing in InputMap.action_get_events(action).duplicate():
		InputMap.action_erase_event(action, existing)

func _serialize_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		return {"type": "key", "keycode": (event as InputEventKey).keycode}
	if event is InputEventMouseButton:
		return {"type": "mouse", "button": (event as InputEventMouseButton).button_index}
	if event is InputEventJoypadButton:
		return {"type": "joy_button", "button": (event as InputEventJoypadButton).button_index}
	if event is InputEventJoypadMotion:
		return {"type": "joy_motion", "axis": (event as InputEventJoypadMotion).axis, "value": (event as InputEventJoypadMotion).axis_value}
	return {}

func _deserialize_event(record: Variant) -> InputEvent:
	if typeof(record) != TYPE_DICTIONARY:
		return null
	var type: Variant = str(record.get("type", ""))
	match type:
		"key":
			var key: Variant = InputEventKey.new()
			key.keycode = int(record.get("keycode", 0))
			return key
		"mouse":
			var mouse: Variant = InputEventMouseButton.new()
			mouse.button_index = int(record.get("button", 0))
			return mouse
		"joy_button":
			var button: Variant = InputEventJoypadButton.new()
			button.button_index = int(record.get("button", -1))
			return button
		"joy_motion":
			var motion: Variant = InputEventJoypadMotion.new()
			motion.axis = int(record.get("axis", -1))
			motion.axis_value = float(record.get("value", 0.0))
			return motion
	return null
