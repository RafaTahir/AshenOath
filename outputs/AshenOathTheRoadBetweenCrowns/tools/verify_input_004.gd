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
	await _verify_hud_navigation(hud, router)
	await _verify_dialogue_physical_accept(hud, router)
	await _verify_reflow_shutdown(hud)

	var passed := failures.is_empty()
	print("INPUT-004 VERIFIER: %s" % ("PASS - glyph labels, remapping, conflict recovery, defaults, and focus navigation" if passed else "FAIL (%d)" % failures.size()))
	for failure in failures:
		print("- %s" % failure)
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

func _verify_hud_navigation(hud: Node, router: Node) -> void:
	router.active_device = router.DEVICE_GAMEPAD
	hud.set_input_device("gamepad")
	hud.show_controls_menu("main")
	await _wait_for_button_focus(hud.menu_layer)
	var controls_text := ""
	for label in hud.menu_layer.find_children("*", "Label", true, false):
		controls_text += str(label.text) + "\n"
	var guidance := controls_text.to_lower()
	_check(guidance.contains("left stick") and guidance.contains("look") and guidance.contains("right stick"), "controls page lost movement/look controller guidance")
	for action in ["interact", "light_attack", "dodge"]:
		var instruction := "%s: %s" % [str(action).replace("_", " ").capitalize(), router.describe_action(action).instruction]
		_check(guidance.contains(instruction.to_lower()), "controls page lost current controller instruction: " + instruction)
	var customize: Button = null
	for button in hud.menu_layer.find_children("*", "Button", true, false):
		if (button as Button).text == "Customize Controls":
			customize = button
			break
	_check(customize != null, "controls page has no Customize Controls entry")
	hud.show_remap_menu("main")
	var focused: Button = await _wait_for_button_focus(hud.menu_layer)
	_check(hud.active_menu == "remap", "remap menu did not open")
	_check(hud.menu_layer.find_children("*", "Button", true, false).size() >= 8, "remap menu is missing bindings or navigation controls")
	_check(focused != null and not focused.disabled and focused.focus_mode == Control.FOCUS_ALL, "remap menu did not focus an enabled controller-navigable button on the current surface")

func _verify_dialogue_physical_accept(hud: Node, router: Node) -> void:
	hud.hide_menus()
	hud.show_dialogue({
		"name": "Input Probe",
		"pages": [
			{"speaker": "Input Probe", "text": "First page."},
			{"speaker": "Input Probe", "text": "Second page."},
		],
	})
	var focused: Button = await _wait_for_button_focus(hud.dialogue_actions)
	_check(focused != null and focused.text == "Continue", "dialogue did not focus its Continue action")
	var enter := InputEventKey.new()
	enter.pressed = true
	enter.physical_keycode = KEY_ENTER
	var guarded_enter := InputEventKey.new()
	guarded_enter.keycode = KEY_ENTER
	guarded_enter.pressed = true
	router.guard_event_until_release(guarded_enter, "input004_held_accept")
	hud._input(enter)
	_check(str(hud.get("_dialogue_pending_source")) == "", "physical Enter bypassed the router's held-input guard")
	guarded_enter.pressed = false
	router._input(guarded_enter)
	hud._input(enter)
	_check(int(hud.get("dialogue_page_index")) == 0, "physical Enter activated before release")
	_check(enter.keycode == KEY_NONE, "physical Enter normalization mutated the caller's event")
	var echo := enter.duplicate() as InputEventKey
	echo.echo = true
	hud._input(echo)
	_check(int(hud.get("dialogue_page_index")) == 0, "physical Enter repeat advanced a dialogue page")
	var release := enter.duplicate() as InputEventKey
	release.pressed = false
	hud._input(release)
	_check(int(hud.get("dialogue_page_index")) == 1, "physical Enter release did not advance a focused dialogue page")
	hud._input(release)
	_check(int(hud.get("dialogue_page_index")) == 1 and hud.dialogue_layer.visible, "duplicate Enter release activated the next dialogue action")
	hud.hide_menus()

func _wait_for_button_focus(surface: Control) -> Button:
	# Menu focus is restored after deferred container layout and a process frame.
	# Bound the wait, and reject stale focus left on a different surface.
	for frame in range(6):
		await process_frame
		var focused: Control = surface.get_viewport().gui_get_focus_owner()
		if focused is Button and surface.is_ancestor_of(focused) and focused.is_visible_in_tree() and not (focused as Button).disabled:
			return focused as Button
	return null

func _verify_reflow_shutdown(hud: Node) -> void:
	# Let menu/dialogue rebuilds finish, then destroy the HUD with a next-frame
	# reflow deliberately pending. It must leave no resumable frame callback.
	for frame in range(3):
		await process_frame
	var before: int = process_frame.get_connections().size()
	hud._restore_reflow_state({}, int(hud.get("_layout_generation")), hud._responsive_surface_key())
	hud._restore_reflow_state({}, int(hud.get("_layout_generation")), hud._responsive_surface_key())
	_check(process_frame.get_connections().size() > before, "reflow did not defer its restoration to the next frame")
	hud.free()
	_check(process_frame.get_connections().size() <= before, "freed HUD retained a pending reflow callback")
	await process_frame

func _has_joy_button(action: String, button: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == button:
			return true
	return false

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
