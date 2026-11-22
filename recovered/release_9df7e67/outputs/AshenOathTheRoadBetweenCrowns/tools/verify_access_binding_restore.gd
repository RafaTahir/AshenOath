extends SceneTree

const InputRouter = preload("res://scripts/input_router.gd")
const HUD = preload("res://scripts/hud.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var router := InputRouter.new()
	root.add_child(router)
	await process_frame
	var legacy := {"generic": {"bindings": {
		"weapon_sword": [{"type": "joy_button", "button": JOY_BUTTON_Y}],
		"weapon_bow": [{"type": "joy_button", "button": JOY_BUTTON_X}],
		"use_potion": [{"type": "joy_button", "button": JOY_BUTTON_DPAD_LEFT}],
	}}}
	var settings := {"gamepad_profiles": legacy, "custom_bindings": {"ui_accept": [
		{"type": "key", "keycode": KEY_ENTER}, {"type": "key", "keycode": KEY_SPACE},
	]}}
	router.apply_settings(settings)
	_check(_has_key("ui_accept", KEY_ENTER) and _has_key("ui_accept", KEY_SPACE), "Saved multi-key bindings lose Enter during restore")
	_check(not _has_button("weapon_sword", JOY_BUTTON_Y), "Legacy default profile reintroduces jump/sword collision")
	_check(not _has_button("weapon_bow", JOY_BUTTON_X), "Legacy default profile overrides weapon toggle")
	_check(_has_button("weapon_cycle", JOY_BUTTON_X), "Legacy default profile did not receive the weapon toggle")
	_check(_has_button("use_potion", JOY_BUTTON_DPAD_LEFT), "Profile migration changed unrelated potion binding")
	router.gamepad_profiles = {"generic": {"bindings": {
		"weapon_sword": [{"type": "joy_button", "button": JOY_BUTTON_RIGHT_STICK}],
		"weapon_bow": [{"type": "joy_button", "button": JOY_BUTTON_X}],
	}}}
	settings["gamepad_profiles"] = router.gamepad_profiles.duplicate(true)
	router.apply_settings(settings)
	_check(_has_button("weapon_sword", JOY_BUTTON_RIGHT_STICK), "Explicit non-default weapon binding was discarded")
	var hud := HUD.new()
	root.add_child(hud)
	hud.set_input_source(router)
	await process_frame
	hud.update_equipment(3, 2, "", 24, "Standard")
	hud.set_input_device("gamepad")
	_check(hud.last_arrow_count == 24 and hud.equipment_label.text.contains("Standard x24"), "Glyph switching discards ammunition state")
	hud.set_input_device("keyboard_mouse")
	var remap_text := ""
	for page in range(6):
		hud.show_remap_menu("main", page)
		await process_frame
		for button in hud.menu_layer.find_children("*", "Button", true, false):
			remap_text += str(button.text) + "\n"
	for label in ["Move forward", "Camera zoom out", "Aim bow", "Fire bow", "Weapon cycle", "Target previous"]:
		_check(remap_text.to_lower().contains(label.to_lower()), "Visible remap pages omit " + label)
	hud.show_remap_menu("main", 4)
	await process_frame
	await process_frame
	for button in hud.menu_layer.find_children("*", "Button", true, false):
		if str(button.text).to_lower().begins_with("weapon bow"):
			button.grab_focus()
	_key(KEY_ENTER, true)
	await process_frame
	_key(KEY_ENTER, false)
	await process_frame
	_check(hud.remap_waiting, "Keyboard activation consumes itself as the new binding")
	_key(KEY_H, true)
	await process_frame
	_key(KEY_H, false)
	await process_frame
	_check(not hud.remap_waiting and _has_key("weapon_bow", KEY_H), "Visible keyboard remapping did not assign the next input")
	hud.free()
	router.free()
	print("ACCESS BINDING RESTORE: %s - saved keys, legacy defaults, custom profiles, full action pages" % ("PASS" if failures.is_empty() else "FAIL"))
	for failure in failures:
		print("- " + failure)
	quit(0 if failures.is_empty() else 1)

func _has_key(action: String, code: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.keycode == code:
			return true
	return false

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _has_button(action: String, button: JoyButton) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and event.button_index == button:
			return true
	return false

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
