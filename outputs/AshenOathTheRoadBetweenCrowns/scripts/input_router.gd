extends Node

const GamepadProfile = preload("res://scripts/gamepad_profile.gd")

signal device_changed(device: String)
signal pointer_mode_changed(mode: int)
signal gamepad_profile_changed(profile: Dictionary)
signal bindings_changed(bindings: Dictionary)
signal input_context_changed(context: String)
signal gamepad_disconnected(device_id: int)
signal transient_input_reset(reason: String)
signal gameplay_action_requested(request: Dictionary)

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
	"weapon_sword": KEY_1,
	"weapon_bow": KEY_2,
	"weapon_oathblade": KEY_3,
	"weapon_sheath": KEY_H,
	"companion_command": KEY_V,
	"cycle_arrow": KEY_Z,
}

const MOUSE_BINDINGS := {
	"light_attack": MOUSE_BUTTON_LEFT,
	"heavy_attack": MOUSE_BUTTON_RIGHT,
	"aim_bow": MOUSE_BUTTON_RIGHT,
	"fire_bow": MOUSE_BUTTON_LEFT,
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
	"weapon_cycle": JOY_BUTTON_X,
	"cycle_arrow": JOY_BUTTON_DPAD_UP,
	"companion_command": JOY_BUTTON_DPAD_DOWN,
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
	"aim_bow": [JOY_AXIS_TRIGGER_LEFT, 1.0],
	"fire_bow": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
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
	"weapon_sword": "1",
	"weapon_bow": "2",
	"weapon_oathblade": "3",
	"weapon_sheath": "H",
	"companion_command": "V",
	"cycle_arrow": "Z",
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
	"weapon_cycle": "X",
	"weapon_sword": "Unbound",
	"weapon_bow": "Unbound",
	"weapon_oathblade": "Unbound",
	"weapon_sheath": "Unbound",
	"companion_command": "D-Pad Down",
	"cycle_arrow": "D-Pad Up",
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
	"use_potion": "Remedy",
	"throw_bomb": "Tool",
	"open_inventory": "Journal",
	"pause": "Pause",
	"camera_zoom_in": "Zoom In",
	"camera_zoom_out": "Zoom Out",
	"aim_bow": "Aim",
	"fire_bow": "Fire",
	"cycle_arrow": "Arrows",
	"target_lock": "Lock",
	"target_next": "Next Target",
	"target_previous": "Previous Target",
	"weapon_sword": "Steel",
	"weapon_oathblade": "Oathblade",
	"weapon_bow": "Bow",
	"weapon_sheath": "Draw / Sheathe",
	"companion_command": "Bracken",
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
var _pending_virtual_look := Vector2.ZERO
var _pending_touch_look_delta := Vector2.ZERO
var _virtual_requests: Array[Dictionary] = []
var _virtual_request_flush_pending := false
var _transient_generation := 0
var _virtual_actions: Dictionary = {}
var _keyboard_pressed: Dictionary = {}
var _mouse_pressed: Dictionary = {}
var _mouse_just_pressed: Dictionary = {}
var _mouse_just_released: Dictionary = {}
var keyboard_labels: Dictionary = KEYBOARD_LABELS.duplicate()
var input_context := CONTEXT_MENU
var last_disconnected_gamepad_id := -1
var _profile_device_id := -1
var _toggle_modes: Dictionary = {}
var _toggle_actions: Dictionary = {}
var _toggle_physical_down: Dictionary = {}
var _awaiting_release: Dictionary = {}
var _pending_pressed: Dictionary = {}
var _pending_released: Dictionary = {}
var _action_snapshot: Dictionary = {}
var companion_available := false
var _companion_press_msec := -1
var _companion_menu_pending := false
var _snapshot_frame := -1
var _suppressed_frame := -1
var _last_accepted_event := 0
var _context_generation := 0
var _event_down: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -100
	if not Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.connect(_on_joy_connection_changed)
	install_default_actions()
	var connected := Input.get_connected_joypads()
	if not connected.is_empty():
		_set_gamepad(int(connected[0]))
	else:
		_refresh_gamepad_profile()

func _physics_process(_delta: float) -> void:
	_ensure_action_snapshot()

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
	reset_transient_input("settings_changed")
	settings_ref = current
	_toggle_modes = {"block": str(current.get("block_mode", "hold")), "run": str(current.get("sprint_mode", "hold"))}
	reset_toggle_actions()
	gamepad_profiles = current.get("gamepad_profiles", {}).duplicate(true) if typeof(current.get("gamepad_profiles", {})) == TYPE_DICTIONARY else {}
	var migrated_weapon_defaults := _migrate_legacy_weapon_defaults()
	if migrated_weapon_defaults:
		settings_ref["gamepad_profiles"] = gamepad_profiles.duplicate(true)
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
	if migrated_weapon_defaults:
		_persist_settings()

func set_settings_manager(manager: Node) -> void:
	settings_manager = manager
	if manager != null and manager.get("settings") != null:
		settings_ref = manager.get("settings")

func set_context(context: String) -> void:
	begin_context(context)

func begin_context(context: String, opening_event: InputEvent = null) -> void:
	var normalized := context.strip_edges().to_lower()
	if normalized not in UI_CONTEXTS and normalized != CONTEXT_GAMEPLAY:
		normalized = CONTEXT_MENU
	var changed := input_context != normalized
	if changed:
		_context_generation += 1
		reset_transient_input("context:" + normalized)
	if opening_event != null:
		_guard_event(opening_event, "context:" + normalized)
	input_context = normalized
	if normalized == CONTEXT_GAMEPLAY:
		restore_gameplay_pointer()
	else:
		show_pointer()
	if changed:
		input_context_changed.emit(input_context)

func accept_event(event: InputEvent, action: StringName, context: String) -> bool:
	if event == null or input_context != context or not InputMap.has_action(action):
		return false
	if _is_emulated_mouse(event):
		return false
	if event is InputEventKey and event.echo:
		return false
	if not event.is_action_pressed(action) or _awaiting_release.has(str(action)):
		return false
	if _last_accepted_event == event.get_instance_id():
		return false
	_last_accepted_event = event.get_instance_id()
	return true

func suspend_gameplay(reason: String) -> void:
	reset_transient_input(reason)
	begin_context(CONTEXT_TRANSITION)

func reset_transient_input(reason: String) -> void:
	_transient_generation += 1
	_virtual_requests.clear()
	_companion_press_msec = -1
	_companion_menu_pending = false
	# Remember held controls before clearing software queues. A handoff is not
	# a synthetic release followed by another press of the same physical key.
	for raw_action in InputMap.get_actions():
		var action := str(raw_action)
		if _physical_action_held(raw_action):
			_awaiting_release[action] = reason
	reset_toggle_actions()
	clear_virtual_input()
	_mouse_just_pressed.clear()
	_mouse_just_released.clear()
	_pending_pressed.clear()
	_pending_released.clear()
	_action_snapshot.clear()
	_snapshot_frame = -1
	_suppressed_frame = Engine.get_physics_frames()
	transient_input_reset.emit(reason)

func _guard_event(event: InputEvent, reason: String) -> void:
	for action in InputMap.get_actions():
		if event.is_action_pressed(action):
			_awaiting_release[str(action)] = reason

func guard_event_until_release(event: InputEvent, reason: String = "pointer_capture") -> void:
	if _is_emulated_mouse(event):
		return
	_guard_event(event, reason)
	for action in InputMap.get_actions():
		if event.is_action_pressed(action):
			_pending_pressed.erase(str(action))
			_pending_released.erase(str(action))
	_action_snapshot.clear()
	_snapshot_frame = -1

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
	var conflicts := _find_binding_conflicts(action, event)
	if conflicts.size() > 1:
		return {"ok":false, "reason":"multiple_conflicts", "conflicts":conflicts, "message":"This control already serves several actions. Choose another control or move those actions first."}
	var conflict_action := str(conflicts[0]) if not conflicts.is_empty() else ""
	reset_transient_input("binding_changed")
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
	reset_transient_input("bindings_reset")
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
	# Touch-generated mouse events still reach Godot's native GUI controls.
	# They are not another physical device or a second combat press.
	if _is_emulated_mouse(event):
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_set_device(DEVICE_TOUCH)
		return
	if event is InputEventScreenDrag:
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			_set_device(DEVICE_KEYBOARD_MOUSE)
		# Web pointer capture can clear Godot's action cache while a physical key
		# is still held. Retain the raw key state so movement and held actions do
		# not stop after the first captured frame.
		if key_event.keycode > 0:
			_keyboard_pressed[_normalize_browser_keycode(key_event.keycode)] = key_event.pressed
		if key_event.physical_keycode > 0:
			_keyboard_pressed[_normalize_browser_keycode(key_event.physical_keycode)] = key_event.pressed
		if key_event.pressed and not key_event.echo:
			if is_gameplay_context() and not get_tree().paused:
				for action in ["move_forward", "move_back", "move_left", "move_right", "camera_left", "camera_right", "camera_up", "camera_down"]:
					if key_event.is_action_pressed(action):
						capture_pointer(true)
						break
	elif event is InputEventJoypadButton and event.pressed:
		if _set_gamepad(maxi(event.device, 0)):
			_restore_profile_switch_event(event)
		_set_device(DEVICE_GAMEPAD)
	elif event is InputEventJoypadMotion and absf(event.axis_value) > maxf(gamepad_deadzone, 0.16):
		if _set_gamepad(maxi(event.device, 0)):
			_restore_profile_switch_event(event)
		_set_device(DEVICE_GAMEPAD)
	elif event is InputEventMouseButton and event.pressed:
		var mouse_event := event as InputEventMouseButton
		var button := int(mouse_event.button_index)
		_set_device(DEVICE_KEYBOARD_MOUSE)
		# A Web pointer-lock or focus handoff can drop mouse-up while the next
		# physical mouse-down still arrives. Treat every delivered mouse-down as
		# a fresh edge; real mouse holds do not emit repeated mouse-down events,
		# while this also re-arms the action after a lost release.
		_mouse_just_pressed[button] = Time.get_ticks_msec()
		_mouse_pressed[button] = true
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		var button := int(mouse_event.button_index)
		_mouse_pressed.erase(button)
		_mouse_just_released[button] = Time.get_ticks_msec()
	elif event is InputEventMouseMotion and event.relative.length_squared() > 9.0:
		_set_device(DEVICE_KEYBOARD_MOUSE)
	_track_action_event(event)
	_track_companion_command(event)

func _track_companion_command(event: InputEvent) -> void:
	if not companion_available or not is_gameplay_context() or get_tree().paused:
		_companion_press_msec = -1
		return
	if not _event_matches_active_device(event) or event.is_echo():
		return
	if event.is_action_pressed("companion_command") and not _awaiting_release.has("companion_command"):
		if event is InputEventJoypadButton and event.is_action_pressed("camera_zoom_out"):
			_companion_press_msec = Time.get_ticks_msec()
		else:
			_companion_menu_pending = true
	elif event.is_action_released("companion_command") and _companion_press_msec >= 0:
		_companion_menu_pending = Time.get_ticks_msec() - _companion_press_msec < 450
		_companion_press_msec = -1

func companion_zoom_reserved() -> bool:
	return companion_available and _companion_press_msec >= 0 and Time.get_ticks_msec() - _companion_press_msec < 450

func consume_companion_menu_request() -> bool:
	var pending := _companion_menu_pending
	_companion_menu_pending = false
	return pending and companion_available and is_gameplay_context()

func _is_emulated_mouse(event: InputEvent) -> bool:
	return (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == -1

func _event_matches_active_device(event: InputEvent) -> bool:
	if event is InputEventAction:
		return true
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return active_device == DEVICE_GAMEPAD
	if event is InputEventKey or event is InputEventMouseButton:
		return active_device == DEVICE_KEYBOARD_MOUSE and not _is_emulated_mouse(event)
	return false

func _track_action_event(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		return
	var echo: bool = event is InputEventKey and event.echo
	var now := Time.get_ticks_msec()
	for raw_action in InputMap.get_actions():
		var action := str(raw_action)
		if event.is_action_released(raw_action):
			_event_down.erase(action)
			if _awaiting_release.erase(action):
				continue
			if _event_matches_active_device(event):
				_pending_released[action] = now
		elif event.is_action_pressed(raw_action) and not echo and _event_matches_active_device(event):
			var repeated_axis := event is InputEventJoypadMotion and bool(_event_down.get(action, false))
			_event_down[action] = true
			# After a focus loss, a new mouse/key down is proof of a fresh
			# physical press even if the browser swallowed the old release.
			if str(_awaiting_release.get(action, "")) in ["focus_lost", "device_changed"] and (event is InputEventKey or event is InputEventMouseButton):
				_awaiting_release.erase(action)
			if _awaiting_release.has(action):
				if action.begins_with("ui_"):
					get_viewport().set_input_as_handled()
				continue
			if not repeated_axis:
				_pending_pressed[action] = now
		# A centred stick is the release for an axis binding. It must rearm
		# without inventing a button press from a held trigger on resume.
		if event is InputEventJoypadMotion and _awaiting_release.has(action) and not _physical_action_held(raw_action):
			_awaiting_release.erase(action)

func _normalize_browser_keycode(code: int) -> int:
	# Chromium/Edge Web exports can surface DOM arrow virtual-key values (37-40)
	# instead of Godot's extended Key constants. WASD is unaffected, but camera
	# actions otherwise miss the InputMap entry while the same physical key is
	# visibly held. Normalize only the browser-compatible navigation values.
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
	if not is_gameplay_context():
		return Vector2.ZERO
	if active_device == DEVICE_TOUCH:
		return virtual_move
	var physical := Vector2(_action_strength("move_right") - _action_strength("move_left"), _action_strength("move_back") - _action_strength("move_forward")).limit_length(1.0)
	var raw_keyboard := Vector2.ZERO
	if not _awaiting_release.has("move_left") and _raw_action_pressed(&"move_left"):
		raw_keyboard.x -= 1.0
	if not _awaiting_release.has("move_right") and _raw_action_pressed(&"move_right"):
		raw_keyboard.x += 1.0
	if not _awaiting_release.has("move_forward") and _raw_action_pressed(&"move_forward"):
		raw_keyboard.y -= 1.0
	if not _awaiting_release.has("move_back") and _raw_action_pressed(&"move_back"):
		raw_keyboard.y += 1.0
	if raw_keyboard.length_squared() > physical.length_squared():
		physical = raw_keyboard.limit_length(1.0)
	if active_device == DEVICE_GAMEPAD:
		physical = _shape_stick(physical, gamepad_deadzone, false)
	return physical if physical.length_squared() >= virtual_move.length_squared() else virtual_move

func look_vector() -> Vector2:
	if not is_gameplay_context():
		return Vector2.ZERO
	if active_device == DEVICE_TOUCH:
		_ensure_action_snapshot()
		return virtual_look
	var physical := Vector2(_action_strength("camera_right") - _action_strength("camera_left"), _action_strength("camera_down") - _action_strength("camera_up")).limit_length(1.0)
	# Chromium can drop the Input singleton's held-key state while the Web
	# canvas owns pointer capture. Movement already merges the retained raw
	# keyboard state; camera look must use the same path or browser route tools
	# can rotate the camera visually without the gameplay camera receiving it.
	var raw_keyboard := Vector2.ZERO
	if not _awaiting_release.has("camera_left") and _raw_action_pressed(&"camera_left"):
		raw_keyboard.x -= 1.0
	if not _awaiting_release.has("camera_right") and _raw_action_pressed(&"camera_right"):
		raw_keyboard.x += 1.0
	if not _awaiting_release.has("camera_up") and _raw_action_pressed(&"camera_up"):
		raw_keyboard.y -= 1.0
	if not _awaiting_release.has("camera_down") and _raw_action_pressed(&"camera_down"):
		raw_keyboard.y += 1.0
	if raw_keyboard.length_squared() > physical.length_squared():
		physical = raw_keyboard.limit_length(1.0)
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
	_ensure_action_snapshot()
	return bool(_action_snapshot.get(str(action), {}).get("held", false))

func _physical_action_held(action: StringName) -> bool:
	if not InputMap.has_action(action):
		return false
	if active_device == DEVICE_TOUCH:
		return bool(_virtual_actions.get(action, false))
	return Input.is_action_pressed(action) or _raw_action_pressed(action) or _raw_mouse_action_pressed(action) or bool(_virtual_actions.get(action, false))

func _hardware_action_held(action: StringName) -> bool:
	if _raw_action_pressed(action) or _raw_mouse_action_pressed(action):
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
				if value * signf(binding.axis_value) > maxf(gamepad_deadzone, InputMap.action_get_deadzone(action)):
					return true
	return false

func _action_strength(action: StringName) -> float:
	if not InputMap.has_action(action) or _awaiting_release.has(str(action)):
		return 0.0
	return Input.get_action_strength(action)

func _ensure_action_snapshot() -> void:
	var frame := Engine.get_physics_frames()
	if frame == _snapshot_frame:
		return
	_snapshot_frame = frame
	_action_snapshot.clear()
	virtual_look = _pending_virtual_look.limit_length(1.0)
	_pending_virtual_look = Vector2.ZERO
	var now := Time.get_ticks_msec()
	for raw_action in InputMap.get_actions():
		var action := str(raw_action)
		var allowed := action.begins_with("ui_") or is_gameplay_context()
		var guarded := _awaiting_release.has(action) or (_suppressed_frame == frame and not action.begins_with("ui_"))
		var held := _physical_action_held(raw_action) and allowed and not guarded
		var singleton_edges: bool = active_device != DEVICE_TOUCH
		var pressed: bool = ((singleton_edges and Input.is_action_just_pressed(raw_action)) or now - int(_pending_pressed.get(action, -1000)) <= 500) and allowed and not guarded
		var released: bool = ((singleton_edges and Input.is_action_just_released(raw_action)) or now - int(_pending_released.get(action, -1000)) <= 500) and allowed and not guarded
		if _action_mode(action) == "toggle" and is_gameplay_context():
			var previous := bool(_toggle_actions.get(action, false))
			if pressed:
				_toggle_actions[action] = not previous
			if action == "run" and movement_vector().length_squared() < 0.01:
				_toggle_actions[action] = false
			held = bool(_toggle_actions.get(action, false)) and not guarded
			# Toggle-off drops guard; only toggle-on grants a fresh parry.
			pressed = held and not previous
			released = previous and not held
		if active_device == DEVICE_TOUCH and action == "run" and is_gameplay_context() and virtual_move.length() > 0.82 and not guarded:
			held = true
		_action_snapshot[action] = {"held":held, "pressed":pressed, "released":released}
		# A fresh tap after Resume may share its suppressed physics frame. Keep
		# that edge for the next frame; old context/held-input edges still expire.
		if _suppressed_frame != frame or _awaiting_release.has(action) or not allowed:
			_pending_pressed.erase(action)
			_pending_released.erase(action)
	_mouse_just_pressed.clear()
	_mouse_just_released.clear()

func reset_toggle_actions() -> void:
	_toggle_actions.clear()
	_toggle_physical_down.clear()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		reset_transient_input("focus_lost")
		_keyboard_pressed.clear()
		_mouse_pressed.clear()
		_event_down.clear()

func _raw_action_pressed(action: StringName) -> bool:
	if not InputMap.has_action(action):
		return false
	for event in InputMap.action_get_events(action):
		if not event is InputEventKey:
			continue
		var key_event := event as InputEventKey
		var keycode := _normalize_browser_keycode(key_event.keycode)
		if keycode > 0 and bool(_keyboard_pressed.get(keycode, false)):
			return true
		var physical_keycode := _normalize_browser_keycode(key_event.physical_keycode)
		if physical_keycode > 0 and bool(_keyboard_pressed.get(physical_keycode, false)):
			return true
	return false

func debug_keyboard_state() -> Dictionary:
	return _keyboard_pressed.duplicate()

func is_action_just_pressed(action: StringName) -> bool:
	_ensure_action_snapshot()
	return bool(_action_snapshot.get(str(action), {}).get("pressed", false))

func is_action_just_released(action: StringName) -> bool:
	_ensure_action_snapshot()
	return bool(_action_snapshot.get(str(action), {}).get("released", false))

func _raw_mouse_action_pressed(action: StringName) -> bool:
	if not InputMap.has_action(action):
		return false
	for event in InputMap.action_get_events(action):
		if event is InputEventMouseButton and bool(_mouse_pressed.get(int(event.button_index), false)):
			return true
	return false

func _consume_mouse_edge(action: StringName, edges: Dictionary) -> bool:
	if not InputMap.has_action(action):
		return false
	var now := Time.get_ticks_msec()
	for event in InputMap.action_get_events(action):
		if not event is InputEventMouseButton:
			continue
		var button := int(event.button_index)
		var stamp := int(edges.get(button, -1))
		if stamp < 0:
			continue
		edges.erase(button)
		# Web input can arrive between sparse physics frames. Keep an edge only
		# briefly so a delayed click is delivered once without becoming stale.
		return now - stamp <= 500
	return false

func action_axis(negative: StringName, positive: StringName) -> float:
	return _action_strength(positive) - _action_strength(negative) if is_gameplay_context() else 0.0

func describe_action(action: String) -> Dictionary:
	var mode := _action_mode(action)
	var binding := action_label(action)
	var name := str({"block":"guard", "run":"sprint", "aim_bow":"aim", "oathfire_beam":"charge Oathfire"}.get(action, action.replace("_", " ")))
	var instruction := "Press %s to %s" % [binding, name]
	if mode == "hold":
		instruction = "Hold %s to %s" % [binding, name]
	elif mode == "toggle":
		instruction = "Press %s to toggle %s" % [binding, name]
	var active := bool(_toggle_actions.get(action, false)) if mode == "toggle" else (_physical_action_held(StringName(action)) and is_gameplay_context() and not _awaiting_release.has(action))
	return {"action":action, "binding":binding, "mode":mode, "instruction":instruction, "active":active, "device":active_device}

func _action_mode(action: String) -> String:
	if action == "aim_bow" and active_device == DEVICE_TOUCH:
		return str(settings_ref.get("touch_aim_mode", "toggle"))
	return str(_toggle_modes.get(action, "hold" if action in ["aim_bow", "oathfire_beam"] else "press"))

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
	if not is_gameplay_context():
		virtual_move = Vector2.ZERO
		clear_virtual_look()
		return
	if move_axis.length_squared() > 0.01 or look_axis.length_squared() > 0.01:
		_set_device(DEVICE_TOUCH)
	virtual_move = move_axis.limit_length(1.0)
	_pending_virtual_look = (_pending_virtual_look + look_axis).limit_length(1.0)

func clear_virtual_look() -> void:
	virtual_look = Vector2.ZERO
	_pending_virtual_look = Vector2.ZERO
	_pending_touch_look_delta = Vector2.ZERO

func add_touch_look_delta(display_delta: Vector2) -> void:
	if is_gameplay_context() and not get_tree().paused and display_delta.is_finite():
		_pending_touch_look_delta += display_delta

func consume_touch_look_delta() -> Vector2:
	var result := _pending_touch_look_delta
	_pending_touch_look_delta = Vector2.ZERO
	return result if is_gameplay_context() and active_device == DEVICE_TOUCH else Vector2.ZERO

func request_virtual_action(action: String, target_instance_id: int = 0) -> void:
	if action not in ["interact", "pause", "open_inventory", "touch_more", "companion_command"] or not is_gameplay_context() or get_tree().paused:
		return
	_set_device(DEVICE_TOUCH)
	_virtual_requests.append({"action":action, "target_instance_id":target_instance_id, "context_generation":_context_generation, "transient_generation":_transient_generation})
	if not _virtual_request_flush_pending:
		_virtual_request_flush_pending = true
		call_deferred("_flush_virtual_requests")

func _flush_virtual_requests() -> void:
	_virtual_request_flush_pending = false
	var pending: Array[Dictionary] = _virtual_requests.duplicate()
	_virtual_requests.clear()
	for request: Dictionary in pending:
		if int(request.context_generation) == _context_generation and int(request.transient_generation) == _transient_generation and is_gameplay_context() and not get_tree().paused:
			gameplay_action_requested.emit(request)

func set_virtual_action(action: StringName, pressed: bool) -> void:
	if not InputMap.has_action(action) or (pressed and (not is_gameplay_context() or get_tree().paused)):
		return
	if pressed:
		_set_device(DEVICE_TOUCH)
		if bool(_virtual_actions.get(action, false)):
			return
		_awaiting_release.erase(str(action))
		_virtual_actions[action] = true
		_pending_pressed[str(action)] = Time.get_ticks_msec()
	elif _virtual_actions.erase(action):
		_pending_released[str(action)] = Time.get_ticks_msec()

func cancel_virtual_action(action: StringName) -> void:
	set_virtual_action(action, false)
	_toggle_actions.erase(str(action))
	_pending_pressed.erase(str(action))

func clear_virtual_input() -> void:
	virtual_move = Vector2.ZERO
	clear_virtual_look()
	for action in _virtual_actions.keys():
		# Cancelling a screen finger must not release a real held controller or
		# keyboard binding which happens to serve the same semantic action.
		if not _hardware_action_held(StringName(action)):
			Input.action_release(action)
			_awaiting_release.erase(str(action))
			_event_down.erase(str(action))
		_pending_pressed.erase(str(action))
		_pending_released.erase(str(action))
	_virtual_actions.clear()
	_action_snapshot.clear()
	_snapshot_frame = -1

func activate_touch() -> void:
	_set_device(DEVICE_TOUCH)

func show_pointer() -> void:
	if OS.has_feature("web"):
		# Keep the menu-closing click from being reinterpreted as a deferred
		# pointer-lock request by the gameplay camera.
		_web_pointer_capture_block_until = Time.get_ticks_msec() + 350
	_set_pointer_mode(Input.MOUSE_MODE_VISIBLE)

func capture_pointer(keyboard_gesture: bool = false) -> void:
	if active_device == DEVICE_TOUCH:
		show_pointer()
		return
	if OS.has_feature("web") and not keyboard_gesture and Time.get_ticks_msec() < _web_pointer_capture_block_until:
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
		# the pointer visible until the next gameplay key or real mouse click.
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
		return
	if device != active_gamepad_id:
		return
	reset_transient_input("controller_disconnected")
	var remaining := Input.get_connected_joypads()
	if remaining.is_empty():
		clear_virtual_input()
		_profile_device_id = -1
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

func _set_gamepad(device: int) -> bool:
	var selected_id := maxi(device, 0)
	var detected_name := Input.get_joy_name(selected_id)
	if _profile_device_id == selected_id and active_gamepad_name == detected_name:
		return false
	if _profile_device_id >= 0:
		reset_transient_input("controller_changed")
	active_gamepad_id = maxi(device, 0)
	_profile_device_id = active_gamepad_id
	active_gamepad_name = detected_name
	active_gamepad_family = GamepadProfile.family_for_name(active_gamepad_name)
	_apply_active_gamepad_profile()
	_refresh_gamepad_profile()
	return true

func _restore_profile_switch_event(event: InputEvent) -> void:
	# Replacing InputMap events clears their action state. Preserve the physical
	# event that selected a different controller, without replaying GUI input.
	for action in InputMap.get_actions():
		if event.is_action_pressed(action):
			Input.action_press(action, event.get_action_strength(action))

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
		var restored_types := {}
		for record in records:
			var event := _deserialize_event(record)
			if event == null or event is InputEventJoypadButton or event is InputEventJoypadMotion:
				continue
			var event_type := _binding_type(event)
			if not restored_types.has(event_type):
				_erase_bindings_of_type(str(action), event_type)
				restored_types[event_type] = true
			# Existing remaps take precedence over this newly introduced default.
			for added_action in ["weapon_oathblade", "weapon_sheath", "companion_command"]:
				if str(action) != added_action and not saved.has(added_action):
					for added_event in InputMap.action_get_events(added_action):
						if added_event.is_match(event):
							InputMap.action_erase_event(added_action, added_event)
			_add_event_once(str(action), event)

func _migrate_legacy_weapon_defaults() -> bool:
	var migrated := false
	for profile_id in gamepad_profiles:
		var profile: Variant = gamepad_profiles[profile_id]
		if not profile is Dictionary or not profile.get("bindings") is Dictionary:
			continue
		var bindings: Dictionary = profile["bindings"]
		if bindings.has("weapon_cycle"):
			continue
		var old_sword := [{"type": "joy_button", "button": JOY_BUTTON_Y}]
		var old_bow := [{"type": "joy_button", "button": JOY_BUTTON_X}]
		if bindings.get("weapon_sword") != old_sword or bindings.get("weapon_bow") != old_bow:
			continue
		# Only migrate the known old default pair; explicit custom bindings remain.
		bindings["weapon_sword"] = []
		bindings["weapon_bow"] = []
		bindings["weapon_cycle"] = old_bow
		migrated = true
	return migrated

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
				if str(action) != "companion_command" and not str(action).begins_with("ui_") and not bindings.has("companion_command") and not _can_share_binding(str(action), "companion_command", _binding_type(event)):
					for added_event in InputMap.action_get_events("companion_command"):
						if added_event.is_match(event):
							InputMap.action_erase_event("companion_command", added_event)
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
	var conflicts := _find_binding_conflicts(action, event)
	return str(conflicts[0]) if not conflicts.is_empty() else ""

func _find_binding_conflicts(action: String, event: InputEvent) -> Array[String]:
	var conflicts: Array[String] = []
	var event_type := _binding_type(event)
	for candidate in InputMap.get_actions():
		var candidate_name := str(candidate)
		if candidate_name == action or candidate_name.begins_with("ui_"):
			continue
		if _can_share_binding(action, candidate_name, event_type):
			continue
		for existing in InputMap.action_get_events(candidate_name):
			if _binding_type(existing) == event_type and existing.is_match(event):
				conflicts.append(candidate_name)
				break
	return conflicts

func _can_share_binding(first: String, second: String, event_type: String) -> bool:
	var pairs: Array = []
	if event_type == "mouse":
		pairs = [["light_attack", "fire_bow"], ["heavy_attack", "aim_bow"]]
	elif event_type == "joy_motion":
		pairs = [["heavy_attack", "fire_bow"], ["oathfire_beam", "aim_bow"], ["camera_left", "target_previous"], ["camera_right", "target_next"]]
	elif event_type == "joy_button":
		pairs = [["cycle_arrow", "camera_zoom_in"], ["companion_command", "camera_zoom_out"]]
	for pair in pairs:
		if first in pair and second in pair:
			return true
	return false

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
	reset_transient_input("device_changed")
	active_device = device
	if active_device == DEVICE_TOUCH:
		show_pointer()
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
