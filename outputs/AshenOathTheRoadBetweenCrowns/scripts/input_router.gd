extends Node
const Defaults = preload("res://scripts/core/input_defaults.gd")
const BindingModel = preload("res://scripts/models/input_binding_model.gd")
const Frame = preload("res://scripts/core/input_frame.gd")
const SimClock = preload("res://scripts/core/sim_clock.gd")
var binding_model: BindingModel = BindingModel.new()
var frame_clock: SimClock = preload("res://scripts/core/sim_clock.gd").new()
var input_frame: Frame = Frame.new()
var web_pointer_bridge = preload("res://scripts/views/web_pointer_bridge.gd").new(self)
var input_touch_view = preload("res://scripts/views/input_touch_view.gd").new(self)
var input_gamepad_view = preload("res://scripts/views/input_gamepad_view.gd").new(self)
var input_binding_adapter_view = preload("res://scripts/views/input_binding_adapter_view.gd").new(self)
var input_hardware_view = preload("res://scripts/views/input_hardware_view.gd").new(self)
const GamepadProfile = preload("res://scripts/gamepad_profile.gd")
signal device_changed(device: String)
signal pointer_mode_changed(mode: int)
signal gamepad_profile_changed(profile: Dictionary)
signal bindings_changed(bindings: Dictionary)
signal input_context_changed(context: String)
signal gamepad_disconnected(device_id: int)
signal transient_input_reset(reason: String)
signal gameplay_action_requested(request: Dictionary)
const DEVICE_KEYBOARD_MOUSE = Defaults.DEVICE_KEYBOARD_MOUSE
const DEVICE_GAMEPAD = Defaults.DEVICE_GAMEPAD
const DEVICE_TOUCH = Defaults.DEVICE_TOUCH
const CONTEXT_MENU = Defaults.CONTEXT_MENU
const CONTEXT_GAMEPLAY = Defaults.CONTEXT_GAMEPLAY
const CONTEXT_PAUSE = Defaults.CONTEXT_PAUSE
const CONTEXT_DIALOGUE = Defaults.CONTEXT_DIALOGUE
const CONTEXT_JOURNAL = Defaults.CONTEXT_JOURNAL
const CONTEXT_SETTINGS = Defaults.CONTEXT_SETTINGS
const CONTEXT_CONTROLS = Defaults.CONTEXT_CONTROLS
const CONTEXT_REMAP = Defaults.CONTEXT_REMAP
const CONTEXT_MINIGAME = Defaults.CONTEXT_MINIGAME
const CONTEXT_DEATH = Defaults.CONTEXT_DEATH
const CONTEXT_TRANSITION = Defaults.CONTEXT_TRANSITION
const UI_CONTEXTS = Defaults.UI_CONTEXTS
const KEYBOARD_BINDINGS = Defaults.KEYBOARD_BINDINGS
const MOUSE_BINDINGS = Defaults.MOUSE_BINDINGS
const GAMEPAD_BUTTON_BINDINGS = Defaults.GAMEPAD_BUTTON_BINDINGS
const GAMEPAD_AXIS_BINDINGS = Defaults.GAMEPAD_AXIS_BINDINGS
const KEYBOARD_LABELS = Defaults.KEYBOARD_LABELS
const GAMEPAD_LABELS = Defaults.GAMEPAD_LABELS
const TOUCH_LABELS = Defaults.TOUCH_LABELS
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
var input_context: String:
	get: return binding_model.context()
	set(value): binding_model.set_context(value)
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
var _applied_setting_groups: Dictionary = {}
const SettingsDelta = preload("res://scripts/settings_delta.gd")
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -100
	_install_web_pointer_fallback()
	if not Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.connect(_on_joy_connection_changed)
	install_default_actions()
	var connected := Input.get_connected_joypads()
	if not connected.is_empty():
		_set_gamepad(int(connected[0]))
	else:
		_refresh_gamepad_profile()

func _physics_process(delta: float) -> void:
	frame_clock.consume(delta)
	_ensure_action_snapshot()
	input_frame = binding_model.emit_frame(frame_clock.tick, movement_vector(), look_vector(), _action_snapshot)

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

func apply_settings(current: Dictionary) -> void: input_binding_adapter_view.apply_settings(current)
func set_settings_manager(manager: Node) -> void: input_binding_adapter_view.set_settings_manager(manager)
func set_context(context: String) -> void:
	begin_context(context)

func begin_context(context: String, opening_event: InputEvent = null) -> void:
	var normalized := binding_model.normalize_context(context)
	var changed := input_context != normalized
	if changed:
		_context_generation += 1
		reset_transient_input("context:" + normalized)
	if opening_event != null:
		_guard_event(opening_event, "context:" + normalized)
	binding_model.set_context(normalized)
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

func focus_first_enabled(container: Node) -> Control: return input_touch_view.focus_first_enabled(container)
func clear_focus() -> void: input_touch_view.clear_focus()
func get_action_bindings(action: String) -> Array[InputEvent]: return input_binding_adapter_view.get_action_bindings(action)
func remap_action(action: String, event: InputEvent) -> Dictionary: return input_binding_adapter_view.remap_action(action, event)
func reset_bindings() -> void: input_binding_adapter_view.reset_bindings()
func format_binding(event: InputEvent) -> String: return input_binding_adapter_view.format_binding(event)
func _input(event: InputEvent) -> void:
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

func _track_companion_command(event: InputEvent) -> void: input_touch_view._track_companion_command(event)
func companion_zoom_reserved() -> bool: return input_touch_view.companion_zoom_reserved()
func consume_companion_menu_request() -> bool: return input_touch_view.consume_companion_menu_request()
func _is_emulated_mouse(event: InputEvent) -> bool: return input_hardware_view._is_emulated_mouse(event)
func _event_matches_active_device(event: InputEvent) -> bool: return input_hardware_view._event_matches_active_device(event)
func _track_action_event(event: InputEvent) -> void: input_hardware_view._track_action_event(event)
func _normalize_browser_keycode(code: int) -> int: return input_hardware_view._normalize_browser_keycode(code)
func movement_vector() -> Vector2: return input_hardware_view.movement_vector()
func look_vector() -> Vector2: return input_hardware_view.look_vector()
func _shape_stick(value: Vector2, deadzone: float, apply_inversion: bool) -> Vector2: return input_hardware_view._shape_stick(value, deadzone, apply_inversion)
func is_action_pressed(action: StringName) -> bool: return input_hardware_view.is_action_pressed(action)
func _physical_action_held(action: StringName) -> bool: return input_hardware_view._physical_action_held(action)
func _hardware_action_held(action: StringName) -> bool: return input_hardware_view._hardware_action_held(action)
func _action_strength(action: StringName) -> float: return input_hardware_view._action_strength(action)
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
		var allowed := binding_model.allows_action(action)
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
			pressed = held and not previous
			released = previous and not held
		if active_device == DEVICE_TOUCH and action == "run" and is_gameplay_context() and virtual_move.length() > 0.82 and not guarded:
			held = true
		_action_snapshot[action] = {"held":held, "pressed":pressed, "released":released}
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

func _raw_action_pressed(action: StringName) -> bool: return input_hardware_view._raw_action_pressed(action)
func debug_keyboard_state() -> Dictionary: return input_hardware_view.debug_keyboard_state()
func is_action_just_pressed(action: StringName) -> bool: return input_hardware_view.is_action_just_pressed(action)
func is_action_just_released(action: StringName) -> bool: return input_hardware_view.is_action_just_released(action)
func _raw_mouse_action_pressed(action: StringName) -> bool: return input_hardware_view._raw_mouse_action_pressed(action)
func _consume_mouse_edge(action: StringName, edges: Dictionary) -> bool: return input_hardware_view._consume_mouse_edge(action, edges)
func action_axis(negative: StringName, positive: StringName) -> float: return input_hardware_view.action_axis(negative, positive)
func describe_action(action: String) -> Dictionary: return input_hardware_view.describe_action(action)
func _action_mode(action: String) -> String: return input_hardware_view._action_mode(action)
func action_label(action: String) -> String: return input_hardware_view.action_label(action)
func gamepad_action_label(action: String) -> String: return input_gamepad_view.gamepad_action_label(action)
func get_gamepad_profile() -> Dictionary: return input_gamepad_view.get_gamepad_profile()
func get_gamepad_calibration() -> Dictionary: return input_gamepad_view.get_gamepad_calibration()
func set_gamepad_calibration(move_center: Vector2, look_center: Vector2, device_id: int = -1) -> void: input_gamepad_view.set_gamepad_calibration(move_center, look_center, device_id)
func _apply_keyboard_preset(preset: String) -> void: input_binding_adapter_view._apply_keyboard_preset(preset)
func _replace_physical_event(action: String, event_type: Variant, code: int) -> void: input_binding_adapter_view._replace_physical_event(action, event_type, code)
func set_virtual_axes(move_axis: Vector2, look_axis: Vector2) -> void: input_touch_view.set_virtual_axes(move_axis, look_axis)
func clear_virtual_look() -> void: input_touch_view.clear_virtual_look()
func add_touch_look_delta(display_delta: Vector2) -> void: input_touch_view.add_touch_look_delta(display_delta)
func consume_touch_look_delta() -> Vector2: return input_touch_view.consume_touch_look_delta()
func request_virtual_action(action: String, target_instance_id: int = 0) -> void: input_touch_view.request_virtual_action(action, target_instance_id)
func _flush_virtual_requests() -> void: input_touch_view._flush_virtual_requests()
func set_virtual_action(action: StringName, pressed: bool) -> void: input_touch_view.set_virtual_action(action, pressed)
func cancel_virtual_action(action: StringName) -> void: input_touch_view.cancel_virtual_action(action)
func clear_virtual_input() -> void: input_touch_view.clear_virtual_input()
func activate_touch() -> void: input_touch_view.activate_touch()
func show_pointer() -> void: web_pointer_bridge.show_pointer()
func capture_pointer(keyboard_gesture: bool = false) -> void: web_pointer_bridge.capture_pointer(keyboard_gesture)
func _install_web_pointer_fallback() -> void: web_pointer_bridge._install_web_pointer_fallback()
func _on_web_pointer_capture_denied(_arguments: Array) -> void: web_pointer_bridge._on_web_pointer_capture_denied(_arguments)
func _exit_tree() -> void: web_pointer_bridge._exit_tree()
func release_pointer() -> void: web_pointer_bridge.release_pointer()
func restore_gameplay_pointer() -> void: web_pointer_bridge.restore_gameplay_pointer()
func is_pointer_captured() -> bool: return web_pointer_bridge.is_pointer_captured()
func rumble(weak: float, strong: float, duration: float = 0.12) -> void: input_gamepad_view.rumble(weak, strong, duration)
func _on_joy_connection_changed(device: int, connected: bool) -> void: input_gamepad_view._on_joy_connection_changed(device, connected)
func get_disconnect_state() -> Dictionary: return input_gamepad_view.get_disconnect_state()
func _set_gamepad(device: int) -> bool: return input_gamepad_view._set_gamepad(device)
func _restore_profile_switch_event(event: InputEvent) -> void: input_gamepad_view._restore_profile_switch_event(event)
func _capture_default_bindings() -> void: input_binding_adapter_view._capture_default_bindings()
func _restore_default_bindings() -> void: input_binding_adapter_view._restore_default_bindings()
func _apply_saved_global_bindings(saved: Variant) -> void: input_binding_adapter_view._apply_saved_global_bindings(saved)
func _migrate_legacy_weapon_defaults() -> bool: return input_gamepad_view._migrate_legacy_weapon_defaults()
func _apply_active_gamepad_profile() -> void: input_gamepad_view._apply_active_gamepad_profile()
func _restore_default_gamepad_bindings() -> void: input_gamepad_view._restore_default_gamepad_bindings()
func _persist_binding_change(event_type: String) -> void: input_binding_adapter_view._persist_binding_change(event_type)
func _serialize_current_gamepad_bindings() -> Dictionary: return input_binding_adapter_view._serialize_current_gamepad_bindings()
func _serialize_current_global_bindings(existing: Dictionary) -> Dictionary: return input_binding_adapter_view._serialize_current_global_bindings(existing)
func _persist_settings() -> void: input_binding_adapter_view._persist_settings()
func _profile_key() -> String: return input_binding_adapter_view._profile_key()
func _binding_type(event: InputEvent) -> String: return input_binding_adapter_view._binding_type(event)
func _find_binding_conflict(action: String, event: InputEvent) -> String: return input_binding_adapter_view._find_binding_conflict(action, event)
func _find_binding_conflicts(action: String, event: InputEvent) -> Array[String]: return input_binding_adapter_view._find_binding_conflicts(action, event)
func _can_share_binding(first: String, second: String, event_type: String) -> bool: return input_binding_adapter_view._can_share_binding(first, second, event_type)
func _first_binding_of_type(action: String, event_type: String) -> InputEvent: return input_binding_adapter_view._first_binding_of_type(action, event_type)
func _first_gamepad_binding(action: String) -> InputEvent: return input_binding_adapter_view._first_gamepad_binding(action)
func _erase_bindings_of_type(action: String, event_type: String) -> void: input_binding_adapter_view._erase_bindings_of_type(action, event_type)
func _erase_all_bindings(action: String) -> void: input_binding_adapter_view._erase_all_bindings(action)
func _serialize_event(event: InputEvent) -> Dictionary: return input_binding_adapter_view._serialize_event(event)
func _deserialize_event(record: Variant) -> InputEvent: return input_binding_adapter_view._deserialize_event(record)
func _joy_button_label(button: int) -> String: return input_gamepad_view._joy_button_label(button)
func _joy_axis_label(axis: int, value: float) -> String: return input_gamepad_view._joy_axis_label(axis, value)
func _refresh_gamepad_profile() -> void: input_gamepad_view._refresh_gamepad_profile()
func _set_device(device: String) -> void: input_gamepad_view._set_device(device)
func _set_pointer_mode(mode: int) -> void: web_pointer_bridge._set_pointer_mode(mode)
func _ensure_action(action: String) -> void: input_hardware_view._ensure_action(action)
func _add_key(action: String, keycode: int) -> void: input_hardware_view._add_key(action, keycode)
func _add_mouse(action: String, button: int) -> void: input_hardware_view._add_mouse(action, button)
func _add_joy_button(action: String, button: int) -> void: input_hardware_view._add_joy_button(action, button)
func _add_joy_axis(action: String, axis: int, value: float) -> void: input_hardware_view._add_joy_axis(action, axis, value)
func _add_event_once(action: String, event: InputEvent) -> void: input_hardware_view._add_event_once(action, event)
func supports(node: Object, method: StringName) -> bool: return is_instance_valid(node) and node.has_method(method)
func get_input_frame() -> Frame: return input_frame
