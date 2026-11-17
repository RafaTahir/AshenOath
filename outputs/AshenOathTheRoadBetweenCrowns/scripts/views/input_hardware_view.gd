extends RefCounted
var _router: Node
func _init(router: Node) -> void:
	_router = router
func _is_emulated_mouse(event: InputEvent) -> bool:
	return (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == -1

func _event_matches_active_device(event: InputEvent) -> bool:
	if event is InputEventAction:
		return true
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return _router.active_device == _router.DEVICE_GAMEPAD
	if event is InputEventKey or event is InputEventMouseButton:
		return _router.active_device == _router.DEVICE_KEYBOARD_MOUSE and not _router._is_emulated_mouse(event)
	return false

func _track_action_event(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		return
	var echo: bool = event is InputEventKey and event.echo
	var now: Variant = Time.get_ticks_msec()
	for raw_action in InputMap.get_actions():
		var action: Variant = str(raw_action)
		if event.is_action_released(raw_action):
			_router._event_down.erase(action)
			if _router._awaiting_release.erase(action):
				continue
			if _router._event_matches_active_device(event):
				_router._pending_released[action] = now
		elif event.is_action_pressed(raw_action) and not echo and _router._event_matches_active_device(event):
			var repeated_axis: Variant = event is InputEventJoypadMotion and bool(_router._event_down.get(action, false))
			_router._event_down[action] = true
			if str(_router._awaiting_release.get(action, "")) in ["focus_lost", "device_changed"] and (event is InputEventKey or event is InputEventMouseButton):
				_router._awaiting_release.erase(action)
			if _router._awaiting_release.has(action):
				if action.begins_with("ui_"):
					_router.get_viewport().set_input_as_handled()
				continue
			if not repeated_axis:
				_router._pending_pressed[action] = now
		if event is InputEventJoypadMotion and _router._awaiting_release.has(action) and not _router._physical_action_held(raw_action):
			_router._awaiting_release.erase(action)

func _normalize_browser_keycode(code: int) -> int:
	match code:
		37:
			return KEY_LEFT
		38:
			return KEY_UP
		39:
			return KEY_RIGHT
		40:
			return KEY_DOWN
		33:
			return KEY_PAGEUP
		34:
			return KEY_PAGEDOWN
		_:
			return code

func movement_vector() -> Vector2:
	if not _router.is_gameplay_context():
		return Vector2.ZERO
	if _router.active_device == _router.DEVICE_TOUCH:
		return _router.virtual_move
	var physical: Variant = Vector2(_router._action_strength("move_right") - _router._action_strength("move_left"), _router._action_strength("move_back") - _router._action_strength("move_forward")).limit_length(1.0)
	var raw_keyboard: Variant = Vector2.ZERO
	if not _router._awaiting_release.has("move_left") and _router._raw_action_pressed(&"move_left"):
		raw_keyboard.x -= 1.0
	if not _router._awaiting_release.has("move_right") and _router._raw_action_pressed(&"move_right"):
		raw_keyboard.x += 1.0
	if not _router._awaiting_release.has("move_forward") and _router._raw_action_pressed(&"move_forward"):
		raw_keyboard.y -= 1.0
	if not _router._awaiting_release.has("move_back") and _router._raw_action_pressed(&"move_back"):
		raw_keyboard.y += 1.0
	if raw_keyboard.length_squared() > physical.length_squared():
		physical = raw_keyboard.limit_length(1.0)
	if _router.active_device == _router.DEVICE_GAMEPAD:
		physical = _router._shape_stick(physical, _router.gamepad_deadzone, false)
	return physical if physical.length_squared() >= _router.virtual_move.length_squared() else _router.virtual_move

func look_vector() -> Vector2:
	if not _router.is_gameplay_context():
		return Vector2.ZERO
	if _router.active_device == _router.DEVICE_TOUCH:
		_router._ensure_action_snapshot()
		return _router.virtual_look
	var physical: Variant = Vector2(_router._action_strength("camera_right") - _router._action_strength("camera_left"), _router._action_strength("camera_down") - _router._action_strength("camera_up")).limit_length(1.0)
	var raw_keyboard: Variant = Vector2.ZERO
	if not _router._awaiting_release.has("camera_left") and _router._raw_action_pressed(&"camera_left"):
		raw_keyboard.x -= 1.0
	if not _router._awaiting_release.has("camera_right") and _router._raw_action_pressed(&"camera_right"):
		raw_keyboard.x += 1.0
	if not _router._awaiting_release.has("camera_up") and _router._raw_action_pressed(&"camera_up"):
		raw_keyboard.y -= 1.0
	if not _router._awaiting_release.has("camera_down") and _router._raw_action_pressed(&"camera_down"):
		raw_keyboard.y += 1.0
	if raw_keyboard.length_squared() > physical.length_squared():
		physical = raw_keyboard.limit_length(1.0)
	if _router.active_device == _router.DEVICE_GAMEPAD:
		physical = _router._shape_stick(physical, _router.gamepad_deadzone, true)
	var selected: Variant = physical if physical.length_squared() >= _router.virtual_look.length_squared() else _router.virtual_look
	return selected * _router.gamepad_look_sensitivity if _router.active_device == _router.DEVICE_GAMEPAD else selected

func _shape_stick(value: Vector2, deadzone: float, apply_inversion: bool) -> Vector2:
	var calibrated: Vector2 = value
	var calibration: Variant = _router.gamepad_calibration.get(str(_router.active_gamepad_id), {})
	if typeof(calibration) == TYPE_DICTIONARY:
		var center_key: Variant = "look_center" if apply_inversion else "move_center"
		var center: Variant = calibration.get(center_key, Vector2.ZERO)
		if center is Vector2:
			calibrated -= center
	var magnitude: Variant = calibrated.length()
	if magnitude <= deadzone:
		return Vector2.ZERO
	var remapped: Variant = clampf((magnitude - deadzone) / maxf(1.0 - deadzone, 0.001), 0.0, 1.0)
	var result: Variant = calibrated.normalized() * remapped
	if apply_inversion:
		if _router.gamepad_invert_x:
			result.x = -result.x
		if _router.gamepad_invert_y:
			result.y = -result.y
	return result

func is_action_pressed(action: StringName) -> bool:
	_router._ensure_action_snapshot()
	return bool(_router._action_snapshot.get(str(action), {}).get("held", false))

func _physical_action_held(action: StringName) -> bool:
	if not InputMap.has_action(action):
		return false
	if _router.active_device == _router.DEVICE_TOUCH:
		return bool(_router._virtual_actions.get(action, false))
	return Input.is_action_pressed(action) or _router._raw_action_pressed(action) or _router._raw_mouse_action_pressed(action) or bool(_router._virtual_actions.get(action, false))

func _hardware_action_held(action: StringName) -> bool:
	if _router._raw_action_pressed(action) or _router._raw_mouse_action_pressed(action):
		return true
	if not InputMap.has_action(action):
		return false
	for binding: InputEvent in InputMap.action_get_events(action):
		if not (binding is InputEventJoypadButton or binding is InputEventJoypadMotion):
			continue
		for device: int in Input.get_connected_joypads():
			if binding.device >= 0 and binding.device != device:
				continue
			if binding is InputEventJoypadButton and Input.is_joy_button_pressed(device, binding.button_index):
				return true
			if binding is InputEventJoypadMotion:
				var value: float = Input.get_joy_axis(device, binding.axis)
				if value * signf(binding.axis_value) > maxf(_router.gamepad_deadzone, InputMap.action_get_deadzone(action)):
					return true
	return false

func _action_strength(action: StringName) -> float:
	if not InputMap.has_action(action) or _router._awaiting_release.has(str(action)) or _router._suppressed_frame == Engine.get_physics_frames():
		return 0.0
	return Input.get_action_strength(action)

func _raw_action_pressed(action: StringName) -> bool:
	if not InputMap.has_action(action):
		return false
	for event in InputMap.action_get_events(action):
		if not event is InputEventKey:
			continue
		var key_event: Variant = event as InputEventKey
		var keycode: Variant = _router._normalize_browser_keycode(key_event.keycode)
		if keycode > 0 and bool(_router._keyboard_pressed.get(keycode, false)):
			return true
		var physical_keycode: Variant = _router._normalize_browser_keycode(key_event.physical_keycode)
		if physical_keycode > 0 and bool(_router._keyboard_pressed.get(physical_keycode, false)):
			return true
	return false

func debug_keyboard_state() -> Dictionary:
	return _router._keyboard_pressed.duplicate()

func is_action_just_pressed(action: StringName) -> bool:
	_router._ensure_action_snapshot()
	return bool(_router._action_snapshot.get(str(action), {}).get("pressed", false))

func is_action_just_released(action: StringName) -> bool:
	_router._ensure_action_snapshot()
	return bool(_router._action_snapshot.get(str(action), {}).get("released", false))

func _raw_mouse_action_pressed(action: StringName) -> bool:
	if not InputMap.has_action(action):
		return false
	for event in InputMap.action_get_events(action):
		if event is InputEventMouseButton and bool(_router._mouse_pressed.get(int(event.button_index), false)):
			return true
	return false

func _consume_mouse_edge(action: StringName, edges: Dictionary) -> bool:
	if not InputMap.has_action(action):
		return false
	var now: Variant = Time.get_ticks_msec()
	for event in InputMap.action_get_events(action):
		if not event is InputEventMouseButton:
			continue
		var button: Variant = int(event.button_index)
		var stamp: Variant = int(edges.get(button, -1))
		if stamp < 0:
			continue
		edges.erase(button)
		return now - stamp <= 500
	return false

func action_axis(negative: StringName, positive: StringName) -> float:
	return _router._action_strength(positive) - _router._action_strength(negative) if _router.is_gameplay_context() else 0.0

func describe_action(action: String) -> Dictionary:
	var mode: Variant = _router._action_mode(action)
	var binding: Variant = _router.action_label(action)
	var name: Variant = str({"block":"guard", "run":"sprint", "aim_bow":"aim", "fire_bow":"draw; release to loose", "oathfire_beam":"charge Oathfire"}.get(action, action.replace("_", " ")))
	var instruction: Variant = "Press %s to %s" % [binding, name]
	if mode == "hold":
		instruction = "Hold %s to %s" % [binding, name]
	elif mode == "toggle":
		instruction = "Press %s to toggle %s" % [binding, name]
	var active: Variant = bool(_router._toggle_actions.get(action, false)) if mode == "toggle" else (_router._physical_action_held(StringName(action)) and _router.is_gameplay_context() and not _router._awaiting_release.has(action))
	return {"action":action, "binding":binding, "mode":mode, "instruction":instruction, "active":active, "device":_router.active_device}

func _action_mode(action: String) -> String:
	if action == "aim_bow" and _router.active_device == _router.DEVICE_TOUCH:
		return str(_router.settings_ref.get("touch_aim_mode", "toggle"))
	return str(_router._toggle_modes.get(action, "hold" if action in ["aim_bow", "fire_bow", "oathfire_beam"] else "press"))

func action_label(action: String) -> String:
	if _router.active_device == _router.DEVICE_GAMEPAD:
		return _router.gamepad_action_label(action)
	if _router.active_device == _router.DEVICE_TOUCH:
		return str(_router.TOUCH_LABELS.get(action, action.capitalize()))
	var keyboard_binding: Variant = _router._first_binding_of_type(action, "key")
	if keyboard_binding != null:
		return _router.format_binding(keyboard_binding)
	var mouse_binding: Variant = _router._first_binding_of_type(action, "mouse")
	if mouse_binding != null:
		return _router.format_binding(mouse_binding)
	return str(_router.keyboard_labels.get(action, action.capitalize()))

func _ensure_action(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.22)
	else:
		InputMap.action_set_deadzone(action, minf(InputMap.action_get_deadzone(action), 0.22))

func _add_key(action: String, keycode: int) -> void:
	_router._ensure_action(action)
	var event: Variant = InputEventKey.new()
	event.keycode = keycode
	_router._add_event_once(action, event)

func _add_mouse(action: String, button: int) -> void:
	_router._ensure_action(action)
	var event: Variant = InputEventMouseButton.new()
	event.button_index = button
	_router._add_event_once(action, event)

func _add_joy_button(action: String, button: int) -> void:
	_router._ensure_action(action)
	var event: Variant = InputEventJoypadButton.new()
	event.button_index = button
	_router._add_event_once(action, event)

func _add_joy_axis(action: String, axis: int, value: float) -> void:
	_router._ensure_action(action)
	var event: Variant = InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	_router._add_event_once(action, event)

func _add_event_once(action: String, event: InputEvent) -> void:
	for existing in InputMap.action_get_events(action):
		if existing.is_match(event):
			return
	InputMap.action_add_event(action, event)
