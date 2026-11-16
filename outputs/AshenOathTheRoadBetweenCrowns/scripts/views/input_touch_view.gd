extends RefCounted
var _router: Node
func _init(router: Node) -> void:
	_router = router
func set_virtual_axes(move_axis: Vector2, look_axis: Vector2) -> void:
	if not _router.is_gameplay_context():
		_router.virtual_move = Vector2.ZERO
		_router.clear_virtual_look()
		return
	if move_axis.length_squared() > 0.01 or look_axis.length_squared() > 0.01:
		_router._set_device(_router.DEVICE_TOUCH)
	_router.virtual_move = move_axis.limit_length(1.0)
	_router._pending_virtual_look = (_router._pending_virtual_look + look_axis).limit_length(1.0)

func clear_virtual_look() -> void:
	_router.virtual_look = Vector2.ZERO
	_router._pending_virtual_look = Vector2.ZERO
	_router._pending_touch_look_delta = Vector2.ZERO

func add_touch_look_delta(display_delta: Vector2) -> void:
	if _router.is_gameplay_context() and not _router.get_tree().paused and display_delta.is_finite():
		_router._pending_touch_look_delta += display_delta

func consume_touch_look_delta() -> Vector2:
	var result: Variant = _router._pending_touch_look_delta
	_router._pending_touch_look_delta = Vector2.ZERO
	return result if _router.is_gameplay_context() and _router.active_device == _router.DEVICE_TOUCH else Vector2.ZERO

func request_virtual_action(action: String, target_instance_id: int = 0) -> void:
	if action not in ["interact", "pause", "open_inventory", "touch_more", "companion_command"] or not _router.is_gameplay_context() or _router.get_tree().paused:
		return
	_router._set_device(_router.DEVICE_TOUCH)
	_router._virtual_requests.append({"action":action, "target_instance_id":target_instance_id, "context_generation":_router._context_generation, "transient_generation":_router._transient_generation})
	if not _router._virtual_request_flush_pending:
		_router._virtual_request_flush_pending = true
		_router.call_deferred("_flush_virtual_requests")

func _flush_virtual_requests() -> void:
	_router._virtual_request_flush_pending = false
	var pending: Array[Dictionary] = _router._virtual_requests.duplicate()
	_router._virtual_requests.clear()
	for request: Dictionary in pending:
		if int(request.context_generation) == _router._context_generation and int(request.transient_generation) == _router._transient_generation and _router.is_gameplay_context() and not _router.get_tree().paused:
			_router.gameplay_action_requested.emit(request)

func set_virtual_action(action: StringName, pressed: bool) -> void:
	if not InputMap.has_action(action) or (pressed and (not _router.is_gameplay_context() or _router.get_tree().paused)):
		return
	if pressed:
		_router._set_device(_router.DEVICE_TOUCH)
		if bool(_router._virtual_actions.get(action, false)):
			return
		_router._awaiting_release.erase(str(action))
		_router._virtual_actions[action] = true
		_router._pending_pressed[str(action)] = Time.get_ticks_msec()
	elif _router._virtual_actions.erase(action):
		_router._pending_released[str(action)] = Time.get_ticks_msec()

func cancel_virtual_action(action: StringName) -> void:
	_router.set_virtual_action(action, false)
	if action == &"fire_bow":
		_router._pending_released.erase(str(action))
	_router._toggle_actions.erase(str(action))
	_router._pending_pressed.erase(str(action))

func clear_virtual_input() -> void:
	_router.virtual_move = Vector2.ZERO
	_router.clear_virtual_look()
	for action in _router._virtual_actions.keys():
		if not _router._hardware_action_held(StringName(action)):
			Input.action_release(action)
			_router._awaiting_release.erase(str(action))
			_router._event_down.erase(str(action))
		_router._pending_pressed.erase(str(action))
		_router._pending_released.erase(str(action))
	_router._virtual_actions.clear()
	_router._action_snapshot.clear()
	_router._snapshot_frame = -1

func activate_touch() -> void:
	_router._set_device(_router.DEVICE_TOUCH)

func _track_companion_command(event: InputEvent) -> void:
	if not _router.companion_available or not _router.is_gameplay_context() or _router.get_tree().paused:
		_router._companion_press_msec = -1
		return
	if not _router._event_matches_active_device(event) or event.is_echo():
		return
	if event.is_action_pressed("companion_command") and not _router._awaiting_release.has("companion_command"):
		if event is InputEventJoypadButton and event.is_action_pressed("camera_zoom_out"):
			_router._companion_press_msec = Time.get_ticks_msec()
		else:
			_router._companion_menu_pending = true
	elif event.is_action_released("companion_command") and _router._companion_press_msec >= 0:
		_router._companion_menu_pending = Time.get_ticks_msec() - _router._companion_press_msec < 450
		_router._companion_press_msec = -1

func companion_zoom_reserved() -> bool:
	return _router.companion_available and _router._companion_press_msec >= 0 and Time.get_ticks_msec() - _router._companion_press_msec < 450

func consume_companion_menu_request() -> bool:
	var pending: Variant = _router._companion_menu_pending
	_router._companion_menu_pending = false
	return pending and _router.companion_available and _router.is_gameplay_context()

func focus_first_enabled(container: Node) -> Control:
	if container == null or not is_instance_valid(container):
		return null
	var candidates: Variant = container.find_children("*", "Button", true, false)
	for candidate in candidates:
		var button: Variant = candidate as Button
		if button != null and not button.disabled and button.focus_mode != Control.FOCUS_NONE:
			button.grab_focus()
			return button
	return null

func clear_focus() -> void:
	var focus_owner: Variant = _router.get_viewport().gui_get_focus_owner()
	if focus_owner != null and is_instance_valid(focus_owner):
		focus_owner.release_focus()
