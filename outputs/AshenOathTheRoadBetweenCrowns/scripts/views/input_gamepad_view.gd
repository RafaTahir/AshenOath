extends RefCounted
var _router: Node
func _init(router: Node) -> void:
	_router = router
func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		_router._set_gamepad(device)
		return
	if device != _router.active_gamepad_id:
		return
	_router.reset_transient_input("controller_disconnected")
	var remaining: Variant = Input.get_connected_joypads()
	if remaining.is_empty():
		_router.clear_virtual_input()
		_router._profile_device_id = -1
		_router.last_disconnected_gamepad_id = device
		_router.active_gamepad_name = ""
		_router.active_gamepad_family = "generic"
		_router._set_device(_router.DEVICE_KEYBOARD_MOUSE)
		_router._refresh_gamepad_profile()
		_router.clear_focus()
		if _router.input_context in _router.UI_CONTEXTS:
			_router.show_pointer()
		else:
			_router.restore_gameplay_pointer()
		_router.gamepad_disconnected.emit(device)
	else:
		_router._set_gamepad(int(remaining[0]))
		_router.gamepad_disconnected.emit(device)

func _set_gamepad(device: int) -> bool:
	var selected_id: Variant = maxi(device, 0)
	var detected_name: Variant = Input.get_joy_name(selected_id)
	if _router._profile_device_id == selected_id and _router.active_gamepad_name == detected_name:
		return false
	if _router._profile_device_id >= 0:
		_router.reset_transient_input("controller_changed")
	_router.active_gamepad_id = maxi(device, 0)
	_router._profile_device_id = _router.active_gamepad_id
	_router.active_gamepad_name = detected_name
	_router.active_gamepad_family = _router.GamepadProfile.family_for_name(_router.active_gamepad_name)
	_router._apply_active_gamepad_profile()
	_router._refresh_gamepad_profile()
	return true

func _restore_profile_switch_event(event: InputEvent) -> void:
	for action in InputMap.get_actions():
		if event.is_action_pressed(action):
			Input.action_press(action, event.get_action_strength(action))

func _refresh_gamepad_profile() -> void:
	var connected: Variant = _router.active_gamepad_id in Input.get_connected_joypads()
	_router.gamepad_profile = _router.GamepadProfile.from_device(_router.active_gamepad_id, _router.active_gamepad_name, connected, {
		"gamepad_deadzone": _router.gamepad_deadzone,
		"gamepad_invert_x": _router.gamepad_invert_x,
		"gamepad_invert_y": _router.gamepad_invert_y,
		"invert_y": _router.gamepad_invert_y,
		"gamepad_look_sensitivity": _router.gamepad_look_sensitivity,
		"gamepad_rumble_strength": _router.rumble_strength,
	})
	_router.gamepad_profile["family"] = _router.active_gamepad_family
	_router.gamepad_profile["vibration"] = _router.vibration_enabled
	_router.gamepad_profile_changed.emit(_router.gamepad_profile.duplicate(true))

func _set_device(device: String) -> void:
	if _router.active_device == device:
		return
	_router.reset_transient_input("device_changed")
	_router.active_device = device
	if _router.active_device == _router.DEVICE_TOUCH:
		_router.show_pointer()
	_router.device_changed.emit(_router.active_device)

func rumble(weak: float, strong: float, duration: float = 0.12) -> void:
	if _router.active_device != _router.DEVICE_GAMEPAD or not _router.vibration_enabled:
		return
	if _router.active_gamepad_id not in Input.get_connected_joypads() or not bool(_router.gamepad_profile.get("vibration_capability", false)):
		return
	var cap: Variant = clampf(_router.rumble_strength, 0.0, 1.0)
	Input.start_joy_vibration(_router.active_gamepad_id, clampf(weak, 0.0, 1.0) * cap, clampf(strong, 0.0, 1.0) * cap, clampf(duration, 0.0, 0.5))

func get_disconnect_state() -> Dictionary:
	return {
		"last_device_id": _router.last_disconnected_gamepad_id,
		"active_device": _router.active_device,
		"fallback_ready": _router.active_device == _router.DEVICE_KEYBOARD_MOUSE or _router.active_device == _router.DEVICE_TOUCH,
		"context": _router.input_context,
	}

func _apply_active_gamepad_profile() -> void:
	_router._restore_default_gamepad_bindings()
	var defaults: Dictionary = _router.settings_ref
	_router.gamepad_deadzone = clampf(float(defaults.get("gamepad_deadzone", 0.16)), 0.05, 0.35)
	_router.gamepad_invert_x = bool(defaults.get("gamepad_invert_x", false))
	_router.gamepad_invert_y = bool(defaults.get("gamepad_invert_y", defaults.get("invert_y", false)))
	_router.gamepad_look_sensitivity = clampf(float(defaults.get("gamepad_look_sensitivity", 1.0)), 0.55, 1.55)
	var profile: Variant = _router.gamepad_profiles.get(_router._profile_key(), {})
	if typeof(profile) != TYPE_DICTIONARY:
		return
	_router.gamepad_deadzone = clampf(float(profile.get("deadzone", _router.gamepad_deadzone)), 0.05, 0.35)
	_router.gamepad_invert_x = bool(profile.get("invert_x", _router.gamepad_invert_x))
	_router.gamepad_invert_y = bool(profile.get("invert_y", _router.gamepad_invert_y))
	_router.gamepad_look_sensitivity = clampf(float(profile.get("look_sensitivity", _router.gamepad_look_sensitivity)), 0.55, 1.55)
	var bindings: Variant = profile.get("bindings", {})
	if typeof(bindings) != TYPE_DICTIONARY:
		return
	for action in bindings:
		if not InputMap.has_action(str(action)) or typeof(bindings[action]) != TYPE_ARRAY:
			continue
		_router._erase_bindings_of_type(str(action), "joy_button")
		_router._erase_bindings_of_type(str(action), "joy_motion")
		for record in bindings[action]:
			var event: Variant = _router._deserialize_event(record)
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				if str(action) != "companion_command" and not str(action).begins_with("ui_") and not bindings.has("companion_command") and not _router._can_share_binding(str(action), "companion_command", _router._binding_type(event)):
					for added_event in InputMap.action_get_events("companion_command"):
						if added_event.is_match(event):
							InputMap.action_erase_event("companion_command", added_event)
				_router._add_event_once(str(action), event)

func _restore_default_gamepad_bindings() -> void:
	for action in _router.default_bindings:
		_router._erase_bindings_of_type(str(action), "joy_button")
		_router._erase_bindings_of_type(str(action), "joy_motion")
		for record in _router.default_bindings[action]:
			var event: Variant = _router._deserialize_event(record)
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				_router._add_event_once(str(action), event)

func _migrate_legacy_weapon_defaults() -> bool:
	var migrated: Variant = false
	for profile_id in _router.gamepad_profiles:
		var profile: Variant = _router.gamepad_profiles[profile_id]
		if not profile is Dictionary or not profile.get("bindings") is Dictionary:
			continue
		var bindings: Dictionary = profile["bindings"]
		if bindings.has("weapon_cycle"):
			continue
		var old_sword: Variant = [{"type": "joy_button", "button": JOY_BUTTON_Y}]
		var old_bow: Variant = [{"type": "joy_button", "button": JOY_BUTTON_X}]
		if bindings.get("weapon_sword") != old_sword or bindings.get("weapon_bow") != old_bow:
			continue
		bindings["weapon_sword"] = []
		bindings["weapon_bow"] = []
		bindings["weapon_cycle"] = old_bow
		migrated = true
	return migrated

func set_gamepad_calibration(move_center: Vector2, look_center: Vector2, device_id: int = -1) -> void:
	var selected_id: Variant = _router.active_gamepad_id if device_id < 0 else device_id
	_router.gamepad_calibration[str(selected_id)] = {
		"move_center": move_center.clamp(Vector2(-0.35, -0.35), Vector2(0.35, 0.35)),
		"look_center": look_center.clamp(Vector2(-0.35, -0.35), Vector2(0.35, 0.35)),
	}
	_router._refresh_gamepad_profile()

func get_gamepad_profile() -> Dictionary:
	_router._refresh_gamepad_profile()
	return _router.gamepad_profile.duplicate(true)

func get_gamepad_calibration() -> Dictionary:
	return _router.gamepad_calibration.duplicate(true)

func gamepad_action_label(action: String) -> String:
	var current: Variant = _router._first_gamepad_binding(action)
	if current != null:
		return _router.format_binding(current)
	var generic: Variant = str(_router.GAMEPAD_LABELS.get(action, action.capitalize()))
	if _router.active_gamepad_family == "playstation":
		return {
			"interact": "Cross", "dodge": "Circle", "jump": "Triangle",
			"run": "L3", "block": "L1", "light_attack": "R1", "heavy_attack": "R2",
			"oathfire_beam": "L2", "open_inventory": "Touchpad", "pause": "Options"
		}.get(action, generic)
	if _router.active_gamepad_family == "nintendo":
		return {
			"interact": "B", "dodge": "A", "jump": "X", "run": "L3",
			"block": "L", "light_attack": "R", "heavy_attack": "ZR",
			"oathfire_beam": "ZL", "open_inventory": "-", "pause": "+"
		}.get(action, generic)
	return generic

func _joy_axis_label(axis: int, value: float) -> String:
	var suffix: Variant = "+" if value >= 0.0 else "-"
	match axis:
		JOY_AXIS_LEFT_X: return "Left Stick X%s" % suffix
		JOY_AXIS_LEFT_Y: return "Left Stick Y%s" % suffix
		JOY_AXIS_RIGHT_X: return "Right Stick X%s" % suffix
		JOY_AXIS_RIGHT_Y: return "Right Stick Y%s" % suffix
		JOY_AXIS_TRIGGER_LEFT: return "LT/L2/ZL"
		JOY_AXIS_TRIGGER_RIGHT: return "RT/R2/ZR"
	return "Axis %d%s" % [axis, suffix]

func _joy_button_label(button: int) -> String:
	var family: Variant = _router.active_gamepad_family
	var face: Variant = {
		"xbox": {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y"},
		"generic": {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y"},
		"playstation": {JOY_BUTTON_A: "Cross", JOY_BUTTON_B: "Circle", JOY_BUTTON_X: "Square", JOY_BUTTON_Y: "Triangle"},
		"nintendo": {JOY_BUTTON_A: "B", JOY_BUTTON_B: "A", JOY_BUTTON_X: "Y", JOY_BUTTON_Y: "X"},
	}
	if face.has(family) and face[family].has(button):
		return str(face[family][button])
	if button == JOY_BUTTON_LEFT_SHOULDER:
		return "LB" if family == "xbox" else ("L1" if family == "playstation" else "L")
	if button == JOY_BUTTON_RIGHT_SHOULDER:
		return "RB" if family == "xbox" else ("R1" if family == "playstation" else "R")
	if button == JOY_BUTTON_LEFT_STICK:
		return "L3"
	if button == JOY_BUTTON_RIGHT_STICK:
		return "R3"
	if button == JOY_BUTTON_BACK:
		return "View" if family == "xbox" else ("Touchpad" if family == "playstation" else "-")
	if button == JOY_BUTTON_START:
		return "Menu" if family == "xbox" else ("Options" if family == "playstation" else "+")
	if button == JOY_BUTTON_DPAD_LEFT:
		return "D-Pad Left"
	if button == JOY_BUTTON_DPAD_RIGHT:
		return "D-Pad Right"
	if button == JOY_BUTTON_DPAD_UP:
		return "D-Pad Up"
	if button == JOY_BUTTON_DPAD_DOWN:
		return "D-Pad Down"
	return "Button %d" % button
