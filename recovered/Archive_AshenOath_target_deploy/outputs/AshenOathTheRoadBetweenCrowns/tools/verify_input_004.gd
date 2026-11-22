extends SceneTree

const InputRouter = preload("res://scripts/input_router.gd")
const SettingsManager = preload("res://scripts/settings_manager.gd")
const HUD = preload("res://scripts/hud.gd")

var failures: Array[String] = []

func _initialize() -> void:
	var settings := SettingsManager.new()
	settings.name = "Settings"
	root.add_child(settings)
	var router := InputRouter.new()
	router.name = "InputRouter"
	root.add_child(router)
	router.set_settings_manager(settings)
	var hud := HUD.new()
	root.add_child(hud)
	await process_frame
	router.apply_settings(settings.settings)
	hud.set_input_source(router)

	_verify_remap_contract(router)
	_verify_conflict_swap_and_reset(router)
	_verify_keyboard_remap(router, settings)
	await _verify_hud_navigation(hud)

	var passed := failures.is_empty()
	print("INPUT-004 VERIFIER: %s" % ("PASS - glyph labels, remapping, conflict recovery, defaults, and focus navigation" if passed else "FAIL (%d)" % failures.size()))
	for failure in failures:
		print("- %s" % failure)
	hud.free()
	router.free()
	settings.free()
	quit(0 if passed else 1)

func _verify_remap_contract(router: Node) -> void:
	_check(router.has_method("remap_action"), "router lacks remap_action")
	_check(router.has_method("reset_bindings"), "router lacks reset_bindings")
	_check(router.has_method("format_binding"), "router lacks format_binding")
	_check(router.action_label("interact") == "E", "default keyboard glyph label is wrong")
	var profile: Dictionary = router.get_gamepad_profile()
	_check(str(profile.get("glyph_theme", "")) == "generic", "generic glyph theme is not selected")

func _verify_conflict_swap_and_reset(router: Node) -> void:
	var joy_x := InputEventJoypadButton.new()
	joy_x.button_index = JOY_BUTTON_Y
	var result: Dictionary = router.remap_action("interact", joy_x)
	_check(bool(result.get("ok", false)), "controller remap was rejected")
	_check(str(result.get("conflict", "")) == "jump", "controller conflict was not identified")
	router.active_device = router.DEVICE_GAMEPAD
	_check(router.action_label("interact") == "Y", "custom controller glyph was not displayed")
	_check(_has_joy_button("jump", JOY_BUTTON_A), "conflict resolution did not preserve displaced binding")
	router.reset_bindings()
	_check(_has_joy_button("interact", JOY_BUTTON_A), "reset did not restore interaction default")
	_check(_has_joy_button("jump", JOY_BUTTON_Y), "reset did not restore jump default")

func _verify_keyboard_remap(router: Node, settings: Node) -> void:
	router.active_device = router.DEVICE_KEYBOARD_MOUSE
	var key := InputEventKey.new()
	key.keycode = KEY_O
	var result: Dictionary = router.remap_action("interact", key)
	_check(bool(result.get("ok", false)), "keyboard remap was rejected")
	_check(router.action_label("interact") == "O", "custom keyboard label was not displayed")
	_check(typeof(settings.settings.get("custom_bindings", {})) == TYPE_DICTIONARY, "custom keyboard bindings were not persisted")
	router.reset_bindings()
	_check(router.action_label("interact") == "E", "keyboard reset did not restore E")

func _verify_hud_navigation(hud: Node) -> void:
	hud.set_input_device("gamepad")
	hud.show_controls_menu("main")
	await process_frame
	var controls_text := ""
	for label in hud.menu_layer.find_children("*", "Label", true, false):
		controls_text += str(label.text) + "\n"
	_check(controls_text.contains("Right Stick look"), "controls page lost controller guidance")
	var customize: Button = null
	for button in hud.menu_layer.find_children("*", "Button", true, false):
		if (button as Button).text == "Customize Controls":
			customize = button
			break
	_check(customize != null, "controls page has no Customize Controls entry")
	hud.show_remap_menu("main")
	await process_frame
	_check(hud.active_menu == "remap", "remap menu did not open")
	_check(hud.menu_layer.find_children("*", "Button", true, false).size() >= 8, "remap menu is missing bindings or navigation controls")
	_check(hud.menu_layer.get_viewport().gui_get_focus_owner() is Button, "remap menu did not focus a controller-navigable button")

func _has_joy_button(action: String, button: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == button:
			return true
	return false

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
