extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	_check(scene != null, "main scene is missing")
	if scene == null:
		_finish()
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	var router = game.input_router
	_check(router != null, "runtime input router is missing")
	if router == null:
		game.queue_free()
		_finish()
		return
	_verify_bindings()
	_verify_device_switch(router)
	await _verify_hud(game.hud, router)
	await _verify_minigame(game.minigames)
	_verify_virtual_interface(router)
	_verify_settings(game.settings)
	game.call("_new_game")
	await _settle(8)
	_check(game.player != null and game.player.input_source == router, "player does not use the input router")
	_check(game.camera_rig != null and game.camera_rig.input_source == router, "camera does not use the input router")
	_check(router.has_method("set_virtual_axes") and router.has_method("set_virtual_action"), "future touch interface is incomplete")
	router.clear_virtual_input()
	game.queue_free()
	await _settle(2)
	_finish()

func _verify_bindings() -> void:
	var required := [
		"move_forward", "move_back", "move_left", "move_right", "run", "dodge",
		"jump", "light_attack", "heavy_attack", "block", "interact", "use_potion",
		"throw_bomb", "oathfire_beam", "open_inventory", "pause",
		"camera_left", "camera_right", "camera_up", "camera_down",
		"camera_zoom_in", "camera_zoom_out",
	]
	for action in required:
		_check(InputMap.has_action(action), "missing semantic action %s" % action)
		_check(_has_gamepad_event(action), "%s has no gamepad binding" % action)
	_check(_has_key("move_forward", KEY_W), "W keyboard movement binding was lost")
	_check(_has_mouse("light_attack", MOUSE_BUTTON_LEFT), "mouse light-attack binding was lost")
	_check(_has_joy_button("interact", JOY_BUTTON_A), "A is not bound to interact")
	_check(_has_joy_button("dodge", JOY_BUTTON_B), "B is not bound to dodge")
	_check(_has_joy_button("light_attack", JOY_BUTTON_RIGHT_SHOULDER), "RB is not bound to light attack")
	_check(_has_joy_axis("heavy_attack", JOY_AXIS_TRIGGER_RIGHT, 1.0), "RT is not bound to heavy attack")
	_check(_has_joy_axis("oathfire_beam", JOY_AXIS_TRIGGER_LEFT, 1.0), "LT is not bound to Oathfire")
	_check(_has_joy_axis("camera_right", JOY_AXIS_RIGHT_X, 1.0), "right stick does not control camera")
	_check(_has_joy_button("ui_accept", JOY_BUTTON_A), "gamepad cannot accept focused UI")
	_check(_has_joy_button("ui_cancel", JOY_BUTTON_B), "gamepad cannot cancel UI")

func _verify_device_switch(router: Node) -> void:
	var joy := InputEventJoypadButton.new()
	joy.device = 2
	joy.button_index = JOY_BUTTON_A
	joy.pressed = true
	router._input(joy)
	_check(router.active_device == "gamepad" and router.active_gamepad_id == 2, "gamepad activity did not switch active device")
	_check(router.action_label("interact") == "A", "gamepad interaction label is wrong")
	var key := InputEventKey.new()
	key.keycode = KEY_E
	key.pressed = true
	router._input(key)
	_check(router.active_device == "keyboard_mouse", "keyboard activity did not restore keyboard/mouse mode")
	_check(router.action_label("interact") == "E", "keyboard interaction label is wrong")

func _verify_hud(hud: Node, router: Node) -> void:
	router._set_device("gamepad")
	hud.set_input_device("gamepad")
	hud.set_prompt("E - Speak to Sister Anwen")
	_check(hud.prompt_label.text.begins_with("[A]"), "interaction prompt did not switch to gamepad")
	hud.set_guidance_hint("Left click strike | Space dodge | Tap Q parry | Hold Q block", 5.0)
	_check(hud.hint_label.text.contains("[RB]") and hud.hint_label.text.contains("[B]") and hud.hint_label.text.contains("[LB]"), "combat guidance did not switch to gamepad")
	hud.update_equipment(2, 1, "Moon Oil")
	_check(hud.equipment_label.text.contains("D-Pad Left") and hud.equipment_label.text.contains("D-Pad Right"), "equipment shortcuts did not switch to gamepad")
	hud.show_controls_menu("main")
	await process_frame
	await process_frame
	var control_text := ""
	for label in hud.menu_layer.find_children("*", "Label", true, false):
		control_text += str(label.text) + "\n"
	_check(control_text.contains("Right Stick look") and control_text.contains("Hold LT Oathfire Beam"), "controls screen lacks gamepad layout")
	_check(root.get_viewport().gui_get_focus_owner() is Button, "gamepad menu focus was not assigned")
	hud.show_dialogue({"name": "Anwen", "greeting": "Stay a moment.", "lines": [], "actions": []})
	await process_frame
	await process_frame
	var focus = root.get_viewport().gui_get_focus_owner()
	_check(focus is Button and focus.text == "Close", "dialogue did not assign gamepad focus")
	hud.dialogue_layer.visible = false
	hud.set_input_device("keyboard_mouse")
	hud.set_prompt("E - Speak to Sister Anwen")
	_check(hud.prompt_label.text.begins_with("[E]"), "keyboard prompt did not restore")
	router._set_device("keyboard_mouse")

func _verify_virtual_interface(router: Node) -> void:
	router.set_virtual_axes(Vector2(0.7, -0.4), Vector2(-0.5, 0.25))
	_check(router.active_device == "touch", "virtual axes did not select touch input")
	_check(router.movement_vector().distance_to(Vector2(0.7, -0.4)) < 0.01, "virtual movement vector is incorrect")
	router.set_virtual_action("interact", true)
	_check(Input.is_action_pressed("interact"), "virtual action press did not reach semantic action")
	router.set_virtual_action("interact", false)
	_check(not Input.is_action_pressed("interact"), "virtual action release remained stuck")
	router.clear_virtual_input()
	_check(router.virtual_move == Vector2.ZERO and router.virtual_look == Vector2.ZERO, "virtual axes did not clear")

func _verify_minigame(minigames: Node) -> void:
	minigames.open_game("tic_tac_toe")
	await process_frame
	await process_frame
	_check(root.get_viewport().gui_get_focus_owner() is Button, "minigame board did not assign gamepad focus")
	minigames.close_game()

func _verify_settings(settings: Node) -> void:
	_check(settings.settings.has("gamepad_look_sensitivity"), "controller sensitivity is not persisted")
	_check(settings.settings.has("gamepad_vibration"), "controller vibration is not persisted")
	var original := float(settings.settings["gamepad_look_sensitivity"])
	settings.cycle_gamepad_look_sensitivity()
	_check(not is_equal_approx(float(settings.settings["gamepad_look_sensitivity"]), original), "controller sensitivity cannot be changed")
	var vibration := bool(settings.settings["gamepad_vibration"])
	settings.toggle_gamepad_vibration()
	_check(bool(settings.settings["gamepad_vibration"]) != vibration, "controller vibration cannot be changed")

func _has_gamepad_event(action: String) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			return true
	return false

func _has_key(action: String, keycode: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.keycode == keycode:
			return true
	return false

func _has_mouse(action: String, button: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventMouseButton and event.button_index == button:
			return true
	return false

func _has_joy_button(action: String, button: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and event.button_index == button:
			return true
	return false

func _has_joy_axis(action: String, axis: int, direction: float) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion and event.axis == axis and signf(event.axis_value) == signf(direction):
			return true
	return false

func _settle(frames: int) -> void:
	for _index in range(frames):
		await process_frame
		await physics_frame

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("INPUT-001: %s" % message)

func _finish() -> void:
	if failures.is_empty():
		print("INPUT-001 VERIFIER: PASS (keyboard, gamepad, focus, prompts, settings, virtual input)")
		quit()
	else:
		print("INPUT-001 VERIFIER: FAIL (%d)" % failures.size())
		quit(1)
