extends "res://tools/verify_opening_real_input_native.gd"

var shots: Array[Dictionary] = []

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		_fail("Graphical input proof requires a rendered viewport")
		_finish()
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_move_to_foreground()
	var game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await _frames(3)
	if await _activate("New Game"):
		var deadline := Time.get_ticks_msec() + 60000
		while Time.get_ticks_msec() < deadline and not (game.game_started and game.player != null and game.player.can_control and not game.zone_transition_pending):
			await process_frame
		if game.player == null or not game.player.can_control or game.zone_transition_pending:
			_fail("Visible New Game did not reach controllable Greyfen")
		else:
			await _verify_weapons(game)
			if failures.is_empty():
				await _verify_remapping(game)
	for button in [JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_DPAD_UP]:
		_joy_button(button, false)
	for axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
		_joy_axis(axis, 0.0)
	for key in [KEY_1, KEY_2, KEY_ESCAPE, KEY_ENTER, KEY_TAB, KEY_H]:
		_key(key, false)
	game.prepare_resource_shutdown()
	await _frames(3)
	game.free()
	await _frames(3)
	print("ACCESS CONTEXT REAL INPUT: %s; physical devices=%d; synthetic controller events do not certify hardware" % ["PASS" if failures.is_empty() else "FAIL", Input.get_connected_joypads().size()])
	_finish()

func _verify_weapons(game: Node) -> void:
	await _frames(12)
	game.player.arrow_requested.connect(func(request: Dictionary): shots.append(request.duplicate(true)))
	await _tap(KEY_2)
	_check(game.player.weapon_mode == "bow", "Keyboard 2 did not equip the real bow")
	_joy_button(JOY_BUTTON_Y, true)
	await _frames(6)
	_check(game.player.weapon_mode == "bow", "Controller jump changed the active weapon")
	_joy_button(JOY_BUTTON_Y, false)
	await _frames(60)
	_joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	await _frames(12)
	_check(game.player.weapon_mode == "bow" and game.player.bow_aiming, "LT did not keep the real bow aimed")
	_check(game.player.beam_cast_state == "", "Bow aim activated Oathfire")
	await _capture("access001_real_bow_aim")
	var arrow_id: String = game.player.selected_arrow_id
	var arrows: int = game.inventory.items.get(arrow_id, 0)
	_check(arrows > 0, "New Game has no real arrows for the input test")
	_joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await _frames(8)
	_joy_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	_joy_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_check(shots.size() == 1 and int(game.inventory.items.get(arrow_id, 0)) == arrows - 1, "RT did not emit exactly one real shot and consume one arrow")
	await _frames(20)
	var camera_distance: float = game.camera_rig.distance
	_joy_button(JOY_BUTTON_DPAD_UP, true)
	await _frames(8)
	_joy_button(JOY_BUTTON_DPAD_UP, false)
	_check(is_equal_approx(camera_distance, game.camera_rig.distance), "Arrow cycling also zoomed the real camera")
	await _frames(6)
	_joy_button(JOY_BUTTON_X, true)
	await _frames(8)
	_joy_button(JOY_BUTTON_X, false)
	_check(game.player.weapon_mode == "sword", "X could not return from bow to sword")
	await _frames(6)
	_joy_button(JOY_BUTTON_X, true)
	await _frames(8)
	_joy_button(JOY_BUTTON_X, false)
	_check(game.player.weapon_mode == "bow", "Second X press did not select bow")
	await _tap(KEY_1)
	_check(game.player.weapon_mode == "sword", "Keyboard sword selection failed after controller input")
	print("REAL_INPUT actual_weapon_context=%s shots=%d ammo_before=%d ammo_after=%d" % ["PASS" if failures.is_empty() else "FAIL", shots.size(), arrows, int(game.inventory.items.get(arrow_id, 0))])

func _verify_remapping(game: Node) -> void:
	await _tap(KEY_ESCAPE)
	_check(paused and game.hud.menu_layer.visible, "Escape did not open a visible paused menu")
	if not await _activate("Controls") or not await _activate("Customize Controls"):
		return
	for page in range(6):
		_check(game.hud.active_menu == "remap" and game.hud.remap_page == page, "Remap page is not reachable through visible controls")
		if page == 4:
			if not await _activate("Weapon Bow", true):
				return
			_check(game.hud.remap_waiting, "Visible Weapon Bow row did not begin remapping")
			await _tap(KEY_H)
			_check(not game.hud.remap_waiting and InputMap.action_has_event("weapon_bow", _key_event(KEY_H, true)), "Keyboard remapping did not persist in InputMap")
			await _capture("access001_real_remap_weapons")
		if page < 5 and not await _activate("Next Page"):
			return
	await _capture("access001_real_remap_targets")
	# This is the OS/Godot notification path, not certification of a physical device.
	_joy_axis(JOY_AXIS_RIGHT_X, 0.2)
	await _frames(3)
	Input.joy_connection_changed.emit(0, false)
	await _frames(3)
	_check(game.input_router.active_device == "keyboard_mouse" and paused, "Disconnect lost menu context or keyboard fallback")
	if not await _activate("Back") or not await _activate("Resume"):
		return
	_check(not paused and game.player.can_control, "Remapping menu did not resume real gameplay")
	await _tap(KEY_H)
	_check(game.player.weapon_mode == "bow", "Remapped H did not equip bow in gameplay")
	await _tap(KEY_ESCAPE)
	if not await _activate("Controls") or not await _activate("Customize Controls") or not await _activate("Reset Defaults"):
		return
	if not await _activate("Back") or not await _activate("Resume"):
		return
	await _tap(KEY_1)
	await _tap(KEY_2)
	_check(game.player.weapon_mode == "bow", "Reset Defaults did not restore keyboard 2")
	print("REAL_INPUT remap_pages=6 visible_remap_and_reset=true logical_disconnect=true resume=%s" % ("PASS" if failures.is_empty() else "FAIL"))

func _activate(label: String, prefix: bool = false) -> bool:
	for _index in range(48):
		var button := root.gui_get_focus_owner() as Button
		if button != null and button.is_visible_in_tree() and not button.disabled and (button.text.to_lower().begins_with(label.to_lower()) if prefix else button.text == label):
			await _tap(KEY_ENTER)
			return true
		await _tap(KEY_TAB)
	_fail("Visible keyboard action is unreachable: " + label)
	return false

func _tap(code: Key) -> void:
	_key(code, true)
	await _frames(2)
	_key(code, false)
	await _frames(4)

func _joy_button(button: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _joy_axis(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _key_event(code: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	return event

func _capture(stem: String) -> void:
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("D:/Temp/AshenOath/%s.png" % stem)
	_check(error == OK, "Could not save changed-view evidence: " + stem)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)
