extends Node

const GamepadProfile = preload("res://scripts/gamepad_profile.gd")

signal device_changed(device: String)
signal pointer_mode_changed(mode: int)
signal gamepad_profile_changed(profile: Dictionary)
signal bindings_changed(bindings: Dictionary)
signal input_context_changed(context: String)
signal gamepad_disconnected(device_id: int)

const DEVICE_KEYBOARD_MOUSE := "keyboard_mouse"
const DEVICE_GAMEPAD := "gamepad"
const DEVICE_TOUCH := "touch"

const CONTEXT_MENU := "menu"
const CONTEXT_GAMEPLAY := "gameplay"
const CONTEXT_PAUSE := "pause"
const CONTEXT_DIALOGUE := "dialogue"
const CONTEXT_JOURNAL := "journal"
const CONTEXT_SETTINGS := "settings"
const CONTEXT_CONTROLS := "controls"
const CONTEXT_REMAP := "remap"
const CONTEXT_MINIGAME := "minigame"
const CONTEXT_DEATH := "death"
const CONTEXT_TRANSITION := "transition"
const UI_CONTEXTS := [
	CONTEXT_MENU, CONTEXT_PAUSE, CONTEXT_DIALOGUE, CONTEXT_JOURNAL,
	CONTEXT_SETTINGS, CONTEXT_CONTROLS, CONTEXT_REMAP, CONTEXT_MINIGAME,
	CONTEXT_DEATH, CONTEXT_TRANSITION,
]

var _web_pointer_capture_block_until := 0

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
	"target_lock": KEY_T,
	"target_next": KEY_Y,
	"target_previous": KEY_U,
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
	"target_lock": JOY_BUTTON_RIGHT_STICK,
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
	# These semantic actions share the right stick with camera look. The
	# camera consumes them only while a target is locked, so free look remains
	# unchanged and target switching is still discoverable/remappable.
	"target_previous": [JOY_AXIS_RIGHT_X, -1.0],
	"target_next": [JOY_AXIS_RIGHT_X, 1.0],
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
	"target_lock": "T",
	"target_next": "Y",
	"target_previous": "U",
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
	"target_lock": "R3",
	"target_next": "Right Stick Left/Right",
	"target_previous": "Right Stick Left/Right",
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
var active_gamepad_name := ""
var active_gamepad_family := "generic"
var gamepad_profile: Dictionary = {}
var gamepad_look_sensitivity := 1.0
var gamepad_deadzone := 0.16
var gamepad_invert_x := false
var gamepad_invert_y := false
var vibration_enabled := true
var rumble_strength := 1.0
var gamepad_calibration: Dictionary = {}
var settings_manager: Node
var settings_ref: Dictionary = {}
var default_bindings: Dictionary = {}
var gamepad_profiles: Dictionary = {}
var virtual_move := Vector2.ZERO
var virtual_look := Vector2.ZERO
var _virtual_actions: Dictionary = {}
var keyboard_labels: Dictionary = KEYBOARD_LABELS.duplicate()
var input_context := CONTEXT_MENU
var last_disconnected_gamepad_id := -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.connect(_on_joy_connection_changed)
	install_default_actions()
	var connected := Input.get_connected_joypads()
	if not connected.is_empty():
		_set_gamepad(int(connected[0]))
	else:
		_refresh_gamepad_profile()

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
	# Godot's built-in UI actions are not guaranteed to have keyboard events in
	# an exported project when the InputMap is assembled at runtime. Install the
	# familiar desktop bindings alongside the gamepad bindings so focused menu,
	# dialogue, journal, and remap controls work through the same action path.
	_add_key("ui_accept", KEY_ENTER)
	_add_key("ui_accept", KEY_KP_ENTER)
	_add_key("ui_accept", KEY_SPACE)
	_add_key("ui_cancel", KEY_ESCAPE)
	_add_key("ui_up", KEY_UP)
	_add_key("ui_down", KEY_DOWN)
	_add_key("ui_left", KEY_LEFT)
	_add_key("ui_right", KEY_RIGHT)
	_add_joy_button("camera_zoom_in", JOY_BUTTON_DPAD_UP)
	_add_joy_button("camera_zoom_out", JOY_BUTTON_DPAD_DOWN)
	_add_joy_button("ui_accept", JOY_BUTTON_A)
	_add_joy_button("ui_cancel", JOY_BUTTON_B)
	_add_joy_button("ui_up", JOY_BUTTON_DPAD_UP)
	_add_joy_button("ui_down", JOY_BUTTON_DPAD_DOWN)
	_add_joy_button("ui_left", JOY_BUTTON_DPAD_LEFT)
	_add_joy_button("ui_right", JOY_BUTTON_DPAD_RIGHT)
	if default_bindings.is_empty():
		_capture_default_bindings()

func apply_settings(current: Dictionary) -> void:
	settings_ref = current
	gamepad_profiles = current.get("gamepad_profiles", {}).duplicate(true) if typeof(current.get("gamepad_profiles", {})) == TYPE_DICTIONARY else {}
	gamepad_look_sensitivity = clampf(float(current.get("gamepad_look_sensitivity", 1.0)), 0.55, 1.55)
	gamepad_deadzone = clampf(float(current.get("gamepad_deadzone", 0.16)), 0.05, 0.35)
	gamepad_invert_x = bool(current.get("gamepad_invert_x", false))
	gamepad_invert_y = bool(current.get("gamepad_invert_y", current.get("invert_y", false)))
	vibration_enabled = bool(current.get("gamepad_vibration", true))
	rumble_strength = clampf(float(current.get("gamepad_rumble_strength", 1.0)), 0.0, 1.0)
	_restore_default_bindings()
	_apply_keyboard_preset(str(current.get("control_preset", "standard")))
	_apply_saved_global_bindings(current.get("custom_bindings", {}))
	_apply_active_gamepad_profile()
	_refresh_gamepad_profile()

func set_settings_manager(manager: Node) -> void:
	settings_manager = manager
	if manager != null and manager.get("settings") != null:
		settings_ref = manager.get("settings")

func set_context(context: String) -> void:
	var normalized := context.strip_edges().to_lower()
	if normalized not in UI_CONTEXTS and normalized != CONTEXT_GAMEPLAY:
		normalized = CONTEXT_MENU
	var changed := input_context != normalized
	input_context = normalized
	if normalized == CONTEXT_GAMEPLAY:
		restore_gameplay_pointer()
	else:
		show_pointer()
	if changed:
		input_context_changed.emit(input_context)

func set_gameplay_context() -> void:
	set_context(CONTEXT_GAMEPLAY)

func set_ui_context(context: String = CONTEXT_MENU) -> void:
	set_context(context)

func get_context() -> String:
	return input_context

func is_gameplay_context() -> bool:
	return input_context == CONTEXT_GAMEPLAY

func focus_first_enabled(container: Node) -> Control:
	if container == null or not is_instance_valid(container):
		return null
	var candidates := container.find_children("*", "Button", true, false)
	for candidate in candidates:
		var button := candidate as Button
		if button != null and not button.disabled and button.focus_mode != Control.FOCUS_NONE:
			button.grab_focus()
			return button
	return null

func clear_focus() -> void:
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner != null and is_instance_valid(focus_owner):
		focus_owner.release_focus()

func get_action_bindings(action: String) -> Array[InputEvent]:
	if not InputMap.has_action(action):
		return []
	return InputMap.action_get_events(action)

func remap_action(action: String, event: InputEvent) -> Dictionary:
	if not InputMap.has_action(action) or event == null:
		return {"ok": false, "reason": "unknown_action"}
	if not (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return {"ok": false, "reason": "unsupported_event"}
	var event_type := _binding_type(event)
	if event_type == "":
		return {"ok": false, "reason": "unsupported_event"}
	var conflict_action := _find_binding_conflict(action, event)
	var displaced: InputEvent = _first_binding_of_type(action, event_type)
	if conflict_action != "":
		_erase_bindings_of_type(conflict_action, event_type)
		if displaced != null:
			_add_event_once(conflict_action, displaced)
	_erase_bindings_of_type(action, event_type)
	_add_event_once(action, event.duplicate())
	_persist_binding_change(event_type)
	bindings_changed.emit({"action": action, "event": _serialize_event(event), "conflict": conflict_action})
	return {"ok": true, "conflict": conflict_action}

func reset_bindings() -> void:
	if default_bindings.is_empty():
		_capture_default_bindings()
	_restore_default_bindings()
	_apply_keyboard_preset(str(settings_ref.get("control_preset", "standard")))
	if settings_ref != null:
		settings_ref["custom_bindings"] = {}
		settings_ref["gamepad_profiles"] = {}
	gamepad_profiles = {}
	_persist_settings()
	bindings_changed.emit({"reset": true})

func format_binding(event: InputEvent) -> String:
	if event is InputEventKey:
		return OS.get_keycode_string((event as InputEventKey).keycode)
	if event is InputEventMouseButton:
		return "Left Mouse" if event.button_index == MOUSE_BUTTON_LEFT else ("Right Mouse" if event.button_index == MOUSE_BUTTON_RIGHT else "Mouse %d" % event.button_index)
	if event is InputEventJoypadButton:
		return _joy_button_label((event as InputEventJoypadButton).button_index)
	if event is InputEventJoypadMotion:
		return _joy_axis_label((event as InputEventJoypadMotion).axis, (event as InputEventJoypadMotion).axis_value)
	return "Unbound"

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		active_gamepad_id = maxi(event.device, 0)
		_set_gamepad(active_gamepad_id)
		_set_device(DEVICE_GAMEPAD)
	elif event is InputEventJoypadMotion and absf(event.axis_value) > maxf(gamepad_deadzone * 0.5, 0.06):
		active_gamepad_id = maxi(event.device, 0)
		_set_gamepad(active_gamepad_id)
		_set_device(DEVICE_GAMEPAD)
	elif event is InputEventKey and event.pressed and not event.echo:
		_set_device(DEVICE_KEYBOARD_MOUSE)
	elif event is InputEventMouseButton and event.pressed:
		_set_device(DEVICE_KEYBOARD_MOUSE)
	elif event is InputEventMouseMotion and event.relative.length_squared() > 9.0:
		_set_device(DEVICE_KEYBOARD_MOUSE)

func movement_vector() -> Vector2:
	var physical := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if active_device == DEVICE_GAMEPAD:
		physical = _shape_stick(physical, gamepad_deadzone, false)
	return physical if physical.length_squared() >= virtual_move.length_squared() else virtual_move

func look_vector() -> Vector2:
	var physical := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	if active_device == DEVICE_GAMEPAD:
		physical = _shape_stick(physical, gamepad_deadzone, true)
	var selected := physical if physical.length_squared() >= virtual_look.length_squared() else virtual_look
	return selected * gamepad_look_sensitivity if active_device == DEVICE_GAMEPAD else selected

func _shape_stick(value: Vector2, deadzone: float, apply_inversion: bool) -> Vector2:
	var calibrated: Vector2 = value
	var calibration: Variant = gamepad_calibration.get(str(active_gamepad_id), {})
	if typeof(calibration) == TYPE_DICTIONARY:
		var center_key := "look_center" if apply_inversion else "move_center"
		var center: Variant = calibration.get(center_key, Vector2.ZERO)
		if center is Vector2:
			calibrated -= center
	var magnitude := calibrated.length()
	if magnitude <= deadzone:
		return Vector2.ZERO
	var remapped := clampf((magnitude - deadzone) / maxf(1.0 - deadzone, 0.001), 0.0, 1.0)
	var result := calibrated.normalized() * remapped
	if apply_inversion:
		if gamepad_invert_x:
			result.x = -result.x
		if gamepad_invert_y:
			result.y = -result.y
	return result

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
		return gamepad_action_label(action)
	if active_device == DEVICE_TOUCH:
		return str(TOUCH_LABELS.get(action, action.capitalize()))
	var keyboard_binding := _first_binding_of_type(action, "key")
	if keyboard_binding != null:
		return format_binding(keyboard_binding)
	var mouse_binding := _first_binding_of_type(action, "mouse")
	if mouse_binding != null:
		return format_binding(mouse_binding)
	return str(keyboard_labels.get(action, action.capitalize()))

func gamepad_action_label(action: String) -> String:
	var current := _first_gamepad_binding(action)
	if current != null:
		return format_binding(current)
	var generic := str(GAMEPAD_LABELS.get(action, action.capitalize()))
	if active_gamepad_family == "playstation":
		return {
			"interact": "Cross", "dodge": "Circle", "jump": "Triangle",
			"run": "L3", "block": "L1", "light_attack": "R1", "heavy_attack": "R2",
			"oathfire_beam": "L2", "open_inventory": "Touchpad", "pause": "Options"
		}.get(action, generic)
	if active_gamepad_family == "nintendo":
		return {
			"interact": "B", "dodge": "A", "jump": "X", "run": "L3",
			"block": "L", "light_attack": "R", "heavy_attack": "ZR",
			"oathfire_beam": "ZL", "open_inventory": "-", "pause": "+"
		}.get(action, generic)
	return generic

func get_gamepad_profile() -> Dictionary:
	_refresh_gamepad_profile()
	return gamepad_profile.duplicate(true)

func get_gamepad_calibration() -> Dictionary:
	return gamepad_calibration.duplicate(true)

func set_gamepad_calibration(move_center: Vector2, look_center: Vector2, device_id: int = -1) -> void:
	var selected_id := active_gamepad_id if device_id < 0 else device_id
	gamepad_calibration[str(selected_id)] = {
		"move_center": move_center.clamp(Vector2(-0.35, -0.35), Vector2(0.35, 0.35)),
		"look_center": look_center.clamp(Vector2(-0.35, -0.35), Vector2(0.35, 0.35)),
	}
	_refresh_gamepad_profile()

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
	if OS.has_feature("web"):
		_web_pointer_capture_block_until = Time.get_ticks_msec() + 120
	_set_pointer_mode(Input.MOUSE_MODE_VISIBLE)

func capture_pointer() -> void:
	if active_device == DEVICE_TOUCH:
		show_pointer()
		return
	if OS.has_feature("web") and Time.get_ticks_msec() < _web_pointer_capture_block_until:
		return
	_set_pointer_mode(Input.MOUSE_MODE_CAPTURED)

func release_pointer() -> void:
	show_pointer()

func restore_gameplay_pointer() -> void:
	if active_device == DEVICE_TOUCH:
		show_pointer()
	elif OS.has_feature("web"):
		# Browsers only grant pointer lock inside a direct user gesture. Dialogue
		# and menu callbacks may finish after that event has propagated, so leave
		# the pointer visible until CameraController receives the next real click.
		show_pointer()
	else:
		capture_pointer()

func is_pointer_captured() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func rumble(weak: float, strong: float, duration: float = 0.12) -> void:
	if active_device != DEVICE_GAMEPAD or not vibration_enabled:
		return
	if active_gamepad_id not in Input.get_connected_joypads() or not bool(gamepad_profile.get("vibration_capability", false)):
		return
	var cap := clampf(rumble_strength, 0.0, 1.0)
	Input.start_joy_vibration(active_gamepad_id, clampf(weak, 0.0, 1.0) * cap, clampf(strong, 0.0, 1.0) * cap, clampf(duration, 0.0, 0.5))

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		_set_gamepad(device)
		_set_device(DEVICE_GAMEPAD)
		return
	if device != active_gamepad_id:
		return
	var remaining := Input.get_connected_joypads()
	if remaining.is_empty():
		clear_virtual_input()
		last_disconnected_gamepad_id = device
		active_gamepad_name = ""
		active_gamepad_family = "generic"
		_set_device(DEVICE_KEYBOARD_MOUSE)
		_refresh_gamepad_profile()
		clear_focus()
		if input_context in UI_CONTEXTS:
			show_pointer()
		else:
			restore_gameplay_pointer()
		gamepad_disconnected.emit(device)
	else:
		_set_gamepad(int(remaining[0]))
		gamepad_disconnected.emit(device)

func get_disconnect_state() -> Dictionary:
	return {
		"last_device_id": last_disconnected_gamepad_id,
		"active_device": active_device,
		"fallback_ready": active_device == DEVICE_KEYBOARD_MOUSE or active_device == DEVICE_TOUCH,
		"context": input_context,
	}

func _set_gamepad(device: int) -> void:
	active_gamepad_id = maxi(device, 0)
	active_gamepad_name = Input.get_joy_name(active_gamepad_id)
	active_gamepad_family = GamepadProfile.family_for_name(active_gamepad_name)
	_apply_active_gamepad_profile()
	_refresh_gamepad_profile()

func _capture_default_bindings() -> void:
	default_bindings.clear()
	for action in InputMap.get_actions():
		var action_name := str(action)
		var serialized: Array = []
		for event in InputMap.action_get_events(action_name):
			var record := _serialize_event(event)
			if not record.is_empty():
				serialized.append(record)
		default_bindings[action_name] = serialized

func _restore_default_bindings() -> void:
	if default_bindings.is_empty():
		return
	for action in default_bindings:
		_erase_all_bindings(str(action))
		for record in default_bindings[action]:
			var event := _deserialize_event(record)
			if event != null:
				_add_event_once(str(action), event)

func _apply_saved_global_bindings(saved: Variant) -> void:
	if typeof(saved) != TYPE_DICTIONARY:
		return
	for action in saved:
		var records = saved[action]
		if typeof(records) != TYPE_ARRAY or not InputMap.has_action(str(action)):
			continue
		for record in records:
			var event := _deserialize_event(record)
			if event == null or event is InputEventJoypadButton or event is InputEventJoypadMotion:
				continue
			_erase_bindings_of_type(str(action), _binding_type(event))
			_add_event_once(str(action), event)

func _apply_active_gamepad_profile() -> void:
	_restore_default_gamepad_bindings()
	var profile: Variant = gamepad_profiles.get(_profile_key(), {})
	if typeof(profile) != TYPE_DICTIONARY:
		return
	gamepad_deadzone = clampf(float(profile.get("deadzone", gamepad_deadzone)), 0.05, 0.35)
	gamepad_invert_x = bool(profile.get("invert_x", gamepad_invert_x))
	gamepad_invert_y = bool(profile.get("invert_y", gamepad_invert_y))
	gamepad_look_sensitivity = clampf(float(profile.get("look_sensitivity", gamepad_look_sensitivity)), 0.55, 1.55)
	var bindings: Variant = profile.get("bindings", {})
	if typeof(bindings) != TYPE_DICTIONARY:
		return
	for action in bindings:
		if not InputMap.has_action(str(action)) or typeof(bindings[action]) != TYPE_ARRAY:
			continue
		_erase_bindings_of_type(str(action), "joy_button")
		_erase_bindings_of_type(str(action), "joy_motion")
		for record in bindings[action]:
			var event := _deserialize_event(record)
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				_add_event_once(str(action), event)

func _restore_default_gamepad_bindings() -> void:
	for action in default_bindings:
		_erase_bindings_of_type(str(action), "joy_button")
		_erase_bindings_of_type(str(action), "joy_motion")
		for record in default_bindings[action]:
			var event := _deserialize_event(record)
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				_add_event_once(str(action), event)

func _persist_binding_change(event_type: String) -> void:
	if settings_ref == null:
		return
	if event_type == "joy_button" or event_type == "joy_motion":
		var profiles: Dictionary = settings_ref.get("gamepad_profiles", {}).duplicate(true) if typeof(settings_ref.get("gamepad_profiles", {})) == TYPE_DICTIONARY else {}
		var profile: Dictionary = profiles.get(_profile_key(), {}) if typeof(profiles.get(_profile_key(), {})) == TYPE_DICTIONARY else {}
		profile["deadzone"] = gamepad_deadzone
		profile["invert_x"] = gamepad_invert_x
		profile["invert_y"] = gamepad_invert_y
		profile["look_sensitivity"] = gamepad_look_sensitivity
		profile["bindings"] = _serialize_current_gamepad_bindings()
		profiles[_profile_key()] = profile
		settings_ref["gamepad_profiles"] = profiles
	else:
		var custom: Dictionary = settings_ref.get("custom_bindings", {}).duplicate(true) if typeof(settings_ref.get("custom_bindings", {})) == TYPE_DICTIONARY else {}
		custom = _serialize_current_global_bindings(custom)
		settings_ref["custom_bindings"] = custom
	_persist_settings()

func _serialize_current_gamepad_bindings() -> Dictionary:
	var result := {}
	for action in InputMap.get_actions():
		var records: Array = []
		for event in InputMap.action_get_events(str(action)):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				var record := _serialize_event(event)
				if not record.is_empty():
					records.append(record)
		if not records.is_empty():
			result[str(action)] = records
	return result

func _serialize_current_global_bindings(existing: Dictionary) -> Dictionary:
	var result := existing.duplicate(true)
	for action in InputMap.get_actions():
		var records: Array = []
		for event in InputMap.action_get_events(str(action)):
			if event is InputEventKey or event is InputEventMouseButton:
				var record := _serialize_event(event)
				if not record.is_empty():
					records.append(record)
		if not records.is_empty():
			result[str(action)] = records
	return result

func _persist_settings() -> void:
	if settings_manager != null and settings_manager.has_method("save_now"):
		settings_manager.save_now()

func _profile_key() -> String:
	var raw := active_gamepad_name.strip_edges().to_lower()
	return raw if raw != "" else active_gamepad_family

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
	var event_type := _binding_type(event)
	for candidate in InputMap.get_actions():
		var candidate_name := str(candidate)
		if candidate_name == action or candidate_name.begins_with("ui_"):
			continue
		for existing in InputMap.action_get_events(candidate_name):
			if _binding_type(existing) == event_type and existing.is_match(event):
				return candidate_name
	return ""

func _first_binding_of_type(action: String, event_type: String) -> InputEvent:
	for existing in InputMap.action_get_events(action):
		if _binding_type(existing) == event_type:
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
		if _binding_type(existing) == event_type:
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
	var type := str(record.get("type", ""))
	match type:
		"key":
			var key := InputEventKey.new()
			key.keycode = int(record.get("keycode", 0))
			return key
		"mouse":
			var mouse := InputEventMouseButton.new()
			mouse.button_index = int(record.get("button", 0))
			return mouse
		"joy_button":
			var button := InputEventJoypadButton.new()
			button.button_index = int(record.get("button", -1))
			return button
		"joy_motion":
			var motion := InputEventJoypadMotion.new()
			motion.axis = int(record.get("axis", -1))
			motion.axis_value = float(record.get("value", 0.0))
			return motion
	return null

func _joy_button_label(button: int) -> String:
	var family := active_gamepad_family
	var face := {
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

func _joy_axis_label(axis: int, value: float) -> String:
	var suffix := "+" if value >= 0.0 else "-"
	match axis:
		JOY_AXIS_LEFT_X: return "Left Stick X%s" % suffix
		JOY_AXIS_LEFT_Y: return "Left Stick Y%s" % suffix
		JOY_AXIS_RIGHT_X: return "Right Stick X%s" % suffix
		JOY_AXIS_RIGHT_Y: return "Right Stick Y%s" % suffix
		JOY_AXIS_TRIGGER_LEFT: return "LT/L2/ZL"
		JOY_AXIS_TRIGGER_RIGHT: return "RT/R2/ZR"
	return "Axis %d%s" % [axis, suffix]

func _refresh_gamepad_profile() -> void:
	var connected := active_gamepad_id in Input.get_connected_joypads()
	gamepad_profile = GamepadProfile.from_device(active_gamepad_id, active_gamepad_name, connected, {
		"gamepad_deadzone": gamepad_deadzone,
		"gamepad_invert_x": gamepad_invert_x,
		"gamepad_invert_y": gamepad_invert_y,
		"invert_y": gamepad_invert_y,
		"gamepad_look_sensitivity": gamepad_look_sensitivity,
		"gamepad_rumble_strength": rumble_strength,
	})
	gamepad_profile["family"] = active_gamepad_family
	gamepad_profile["vibration"] = vibration_enabled
	gamepad_profile_changed.emit(gamepad_profile.duplicate(true))

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
