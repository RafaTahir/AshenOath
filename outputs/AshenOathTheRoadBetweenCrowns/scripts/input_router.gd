extends Node

signal device_changed(device: String)
signal pointer_mode_changed(mode: int)

const DEVICE_KEYBOARD_MOUSE := "keyboard_mouse"
const DEVICE_GAMEPAD := "gamepad"
const DEVICE_TOUCH := "touch"

const KEYBOARD_BINDINGS := {
	"move_forward": KEY_W,
	"move_back": KEY_S,
	"move_left": KEY_A,
	"move_right": KEY_D,
	"run": KEY_SHIFT,
	"dodge": KEY_SPACE,
	"jump": KEY_X,
	"block": KEY_Q,
	"interact": KEY_E,
	"use_potion": KEY_R,
	"throw_bomb": KEY_F,
	"oathfire_beam": KEY_C,
	"open_inventory": KEY_TAB,
	"pause": KEY_ESCAPE,
	"camera_left": KEY_LEFT,
	"camera_right": KEY_RIGHT,
	"camera_up": KEY_UP,
	"camera_down": KEY_DOWN,
	"camera_zoom_in": KEY_PAGEUP,
	"camera_zoom_out": KEY_PAGEDOWN,
}

const MOUSE_BINDINGS := {
	"light_attack": MOUSE_BUTTON_LEFT,
	"heavy_attack": MOUSE_BUTTON_RIGHT,
}

const GAMEPAD_BUTTON_BINDINGS := {
	"interact": JOY_BUTTON_A,
	"dodge": JOY_BUTTON_B,
	"jump": JOY_BUTTON_Y,
	"run": JOY_BUTTON_LEFT_STICK,
	"block": JOY_BUTTON_LEFT_SHOULDER,
	"light_attack": JOY_BUTTON_RIGHT_SHOULDER,
	"use_potion": JOY_BUTTON_DPAD_LEFT,
	"throw_bomb": JOY_BUTTON_DPAD_RIGHT,
	"open_inventory": JOY_BUTTON_BACK,
	"pause": JOY_BUTTON_START,
}

const GAMEPAD_AXIS_BINDINGS := {
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0],
	"move_forward": [JOY_AXIS_LEFT_Y, -1.0],
	"move_back": [JOY_AXIS_LEFT_Y, 1.0],
	"camera_left": [JOY_AXIS_RIGHT_X, -1.0],
	"camera_right": [JOY_AXIS_RIGHT_X, 1.0],
	"camera_up": [JOY_AXIS_RIGHT_Y, -1.0],
	"camera_down": [JOY_AXIS_RIGHT_Y, 1.0],
	"oathfire_beam": [JOY_AXIS_TRIGGER_LEFT, 1.0],
	"heavy_attack": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
}

const KEYBOARD_LABELS := {
	"interact": "E",
	"dodge": "Space",
	"jump": "X",
	"run": "Shift",
	"block": "Q",
	"light_attack": "Left Mouse",
	"heavy_attack": "Right Mouse",
	"oathfire_beam": "C",
	"use_potion": "R",
	"throw_bomb": "F",
	"open_inventory": "Tab",
	"pause": "Esc",
	"camera_zoom_in": "Page Up",
	"camera_zoom_out": "Page Down",
}

const GAMEPAD_LABELS := {
	"interact": "A",
	"dodge": "B",
	"jump": "Y",
	"run": "L3",
	"block": "LB",
	"light_attack": "RB",
	"heavy_attack": "RT",
	"oathfire_beam": "LT",
	"use_potion": "D-Pad Left",
	"throw_bomb": "D-Pad Right",
	"open_inventory": "View",
	"pause": "Menu",
	"camera_zoom_in": "D-Pad Up",
	"camera_zoom_out": "D-Pad Down",
}

const TOUCH_LABELS := {
	"interact": "Use",
	"dodge": "Dodge",
	"jump": "Jump",
	"run": "Stick",
	"block": "Guard",
	"light_attack": "Strike",
	"heavy_attack": "Heavy",
	"oathfire_beam": "Oath",
	"use_potion": "Potion",
	"throw_bomb": "Bomb",
	"open_inventory": "Journal",
	"pause": "Pause",
	"camera_zoom_in": "Pinch In",
	"camera_zoom_out": "Pinch Out",
}

var active_device := DEVICE_KEYBOARD_MOUSE
var active_gamepad_id := 0
var gamepad_look_sensitivity := 1.0
var vibration_enabled := true
var virtual_move := Vector2.ZERO
var virtual_look := Vector2.ZERO
var _virtual_actions: Dictionary = {}
var keyboard_labels: Dictionary = KEYBOARD_LABELS.duplicate()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	install_default_actions()

func install_default_actions() -> void:
	for action in KEYBOARD_BINDINGS:
		_add_key(str(action), int(KEYBOARD_BINDINGS[action]))
	for action in MOUSE_BINDINGS:
		_add_mouse(str(action), int(MOUSE_BINDINGS[action]))
	for action in GAMEPAD_BUTTON_BINDINGS:
		_add_joy_button(str(action), int(GAMEPAD_BUTTON_BINDINGS[action]))
	for action in GAMEPAD_AXIS_BINDINGS:
		var binding: Array = GAMEPAD_AXIS_BINDINGS[action]
		_add_joy_axis(str(action), int(binding[0]), float(binding[1]))
	_add_joy_button("camera_zoom_in", JOY_BUTTON_DPAD_UP)
	_add_joy_button("camera_zoom_out", JOY_BUTTON_DPAD_DOWN)
	_add_joy_button("ui_accept", JOY_BUTTON_A)
	_add_joy_button("ui_cancel", JOY_BUTTON_B)
	_add_joy_button("ui_up", JOY_BUTTON_DPAD_UP)
	_add_joy_button("ui_down", JOY_BUTTON_DPAD_DOWN)
	_add_joy_button("ui_left", JOY_BUTTON_DPAD_LEFT)
	_add_joy_button("ui_right", JOY_BUTTON_DPAD_RIGHT)

func apply_settings(current: Dictionary) -> void:
	gamepad_look_sensitivity = clampf(float(current.get("gamepad_look_sensitivity", 1.0)), 0.55, 1.55)
	vibration_enabled = bool(current.get("gamepad_vibration", true))
	_apply_keyboard_preset(str(current.get("control_preset", "standard")))

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		active_gamepad_id = maxi(event.device, 0)
		_set_device(DEVICE_GAMEPAD)
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.32:
		active_gamepad_id = maxi(event.device, 0)
		_set_device(DEVICE_GAMEPAD)
	elif event is InputEventKey and event.pressed and not event.echo:
		_set_device(DEVICE_KEYBOARD_MOUSE)
	elif event is InputEventMouseButton and event.pressed:
		_set_device(DEVICE_KEYBOARD_MOUSE)
	elif event is InputEventMouseMotion and event.relative.length_squared() > 9.0:
		_set_device(DEVICE_KEYBOARD_MOUSE)

func movement_vector() -> Vector2:
	var physical := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	return physical if physical.length_squared() >= virtual_move.length_squared() else virtual_move

func look_vector() -> Vector2:
	var physical := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	var selected := physical if physical.length_squared() >= virtual_look.length_squared() else virtual_look
	return selected * gamepad_look_sensitivity if active_device == DEVICE_GAMEPAD else selected

func is_action_pressed(action: StringName) -> bool:
	if active_device == DEVICE_TOUCH and action == &"run" and virtual_move.length() > 0.82:
		return true
	return Input.is_action_pressed(action)

func is_action_just_pressed(action: StringName) -> bool:
	return Input.is_action_just_pressed(action)

func is_action_just_released(action: StringName) -> bool:
	return Input.is_action_just_released(action)

func action_axis(negative: StringName, positive: StringName) -> float:
	return Input.get_axis(negative, positive)

func action_label(action: String) -> String:
	if active_device == DEVICE_GAMEPAD:
		return str(GAMEPAD_LABELS.get(action, action.capitalize()))
	if active_device == DEVICE_TOUCH:
		return str(TOUCH_LABELS.get(action, action.capitalize()))
	return str(keyboard_labels.get(action, action.capitalize()))

func _apply_keyboard_preset(preset: String) -> void:
	var bindings: Dictionary = KEYBOARD_BINDINGS.duplicate()
	var mouse: Dictionary = MOUSE_BINDINGS.duplicate()
	keyboard_labels = KEYBOARD_LABELS.duplicate()
	if preset == "left_handed":
		bindings.merge({
			"move_forward": KEY_I, "move_back": KEY_K, "move_left": KEY_J, "move_right": KEY_L,
			"dodge": KEY_N, "jump": KEY_M, "block": KEY_U, "interact": KEY_O,
			"use_potion": KEY_P, "throw_bomb": KEY_H,
		}, true)
		mouse["light_attack"] = MOUSE_BUTTON_RIGHT
		mouse["heavy_attack"] = MOUSE_BUTTON_LEFT
		keyboard_labels.merge({
			"interact": "O", "dodge": "N", "jump": "M", "block": "U",
			"light_attack": "Right Mouse", "heavy_attack": "Left Mouse",
			"use_potion": "P", "throw_bomb": "H",
		}, true)
	for action in bindings:
		_replace_physical_event(str(action), InputEventKey, int(bindings[action]))
	for action in mouse:
		_replace_physical_event(str(action), InputEventMouseButton, int(mouse[action]))

func _replace_physical_event(action: String, event_type, code: int) -> void:
	_ensure_action(action)
	for existing in InputMap.action_get_events(action):
		if is_instance_of(existing, event_type):
			InputMap.action_erase_event(action, existing)
	if event_type == InputEventKey:
		_add_key(action, code)
	else:
		_add_mouse(action, code)

func set_virtual_axes(move_axis: Vector2, look_axis: Vector2) -> void:
	virtual_move = move_axis.limit_length(1.0)
	virtual_look = look_axis.limit_length(1.0)
	if virtual_move.length_squared() > 0.01 or virtual_look.length_squared() > 0.01:
		_set_device(DEVICE_TOUCH)

func set_virtual_action(action: StringName, pressed: bool) -> void:
	if pressed:
		_virtual_actions[action] = true
		Input.action_press(action)
		_set_device(DEVICE_TOUCH)
	elif _virtual_actions.erase(action):
		Input.action_release(action)

func clear_virtual_input() -> void:
	virtual_move = Vector2.ZERO
	virtual_look = Vector2.ZERO
	for action in _virtual_actions.keys():
		Input.action_release(action)
	_virtual_actions.clear()

func activate_touch() -> void:
	_set_device(DEVICE_TOUCH)

func show_pointer() -> void:
	_set_pointer_mode(Input.MOUSE_MODE_VISIBLE)

func capture_pointer() -> void:
	if active_device == DEVICE_TOUCH:
		show_pointer()
		return
	_set_pointer_mode(Input.MOUSE_MODE_CAPTURED)

func release_pointer() -> void:
	show_pointer()

func restore_gameplay_pointer() -> void:
	if active_device == DEVICE_TOUCH:
		show_pointer()
	else:
		capture_pointer()

func is_pointer_captured() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func rumble(weak: float, strong: float, duration: float = 0.12) -> void:
	if active_device != DEVICE_GAMEPAD or not vibration_enabled:
		return
	Input.start_joy_vibration(active_gamepad_id, clampf(weak, 0.0, 1.0), clampf(strong, 0.0, 1.0), maxf(duration, 0.0))

func _set_device(device: String) -> void:
	if active_device == device:
		return
	active_device = device
	device_changed.emit(active_device)

func _set_pointer_mode(mode: int) -> void:
	if Input.mouse_mode == mode:
		return
	Input.mouse_mode = mode
	pointer_mode_changed.emit(mode)

func _ensure_action(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.22)
	else:
		InputMap.action_set_deadzone(action, minf(InputMap.action_get_deadzone(action), 0.22))

func _add_key(action: String, keycode: int) -> void:
	_ensure_action(action)
	var event := InputEventKey.new()
	event.keycode = keycode
	_add_event_once(action, event)

func _add_mouse(action: String, button: int) -> void:
	_ensure_action(action)
	var event := InputEventMouseButton.new()
	event.button_index = button
	_add_event_once(action, event)

func _add_joy_button(action: String, button: int) -> void:
	_ensure_action(action)
	var event := InputEventJoypadButton.new()
	event.button_index = button
	_add_event_once(action, event)

func _add_joy_axis(action: String, axis: int, value: float) -> void:
	_ensure_action(action)
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	_add_event_once(action, event)

func _add_event_once(action: String, event: InputEvent) -> void:
	for existing in InputMap.action_get_events(action):
		if existing.is_match(event):
			return
	InputMap.action_add_event(action, event)
