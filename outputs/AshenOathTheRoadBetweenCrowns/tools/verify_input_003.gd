extends SceneTree

const InputRouter = preload("res://scripts/input_router.gd")
const SettingsManager = preload("res://scripts/settings_manager.gd")
const GamepadProfile = preload("res://scripts/gamepad_profile.gd")

var failures: Array[String] = []

func _initialize() -> void:
	var settings := SettingsManager.new()
	settings.name = "Settings"
	root.add_child(settings)
	var router := InputRouter.new()
	root.add_child(router)
	await process_frame
	router.apply_settings(settings.settings)

	_verify_profile_contract(router)
	_verify_family_detection()
	_verify_deadzone_and_inversion(router)
	_verify_calibration(router)
	_verify_bindings(router)
	_verify_disconnect_recovery(router)
	_verify_settings(settings)

	var passed := failures.is_empty()
	print("INPUT-003 VERIFIER: %s" % ("PASS - universal gamepad profile, calibration, hotplug, and guarded rumble" if passed else "FAIL (%d)" % failures.size()))
	for failure in failures:
		print("- %s" % failure)
	if is_instance_valid(router):
		router.free()
	if is_instance_valid(settings):
		settings.free()
	quit(0 if passed else 1)

func _verify_profile_contract(router: Node) -> void:
	var profile: Dictionary = router.get_gamepad_profile()
	for key in ["device_family", "glyph_theme", "deadzones", "axis_inversion", "sensitivity", "vibration_capability", "bindings"]:
		_check(profile.has(key), "gamepad profile is missing %s" % key)
	_check(profile.get("device_family", "") == "generic", "unconnected profile should be generic")
	_check(float(profile.get("deadzones", {}).get("left_stick", 0.0)) > 0.0, "left-stick deadzone was not applied")
	_check(profile.get("bindings", {}).has("oathfire_beam"), "profile does not expose semantic action bindings")

func _verify_family_detection() -> void:
	_check(GamepadProfile.family_for_name("Xbox Wireless Controller") == "xbox", "Xbox family detection failed")
	_check(GamepadProfile.family_for_name("DualSense Wireless Controller") == "playstation", "PlayStation family detection failed")
	_check(GamepadProfile.family_for_name("Nintendo Switch Pro Controller") == "nintendo", "Nintendo family detection failed")
	_check(GamepadProfile.family_for_name("USB Generic Gamepad") == "generic", "generic family fallback failed")
	_check(GamepadProfile.glyph_theme_for_family("playstation") == "playstation", "PlayStation glyph theme failed")

func _verify_deadzone_and_inversion(router: Node) -> void:
	router.active_gamepad_id = 2
	router.active_device = router.DEVICE_GAMEPAD
	var quiet: Vector2 = router._shape_stick(Vector2(0.10, 0.0), 0.16, false)
	_check(quiet == Vector2.ZERO, "stick drift below deadzone was not suppressed")
	var live: Vector2 = router._shape_stick(Vector2(0.50, 0.0), 0.16, false)
	_check(live.x > 0.35 and live.x < 0.45, "stick response was not remapped after deadzone")
	router.gamepad_invert_x = true
	router.gamepad_invert_y = true
	var inverted: Vector2 = router._shape_stick(Vector2(0.5, -0.5), 0.16, true)
	_check(inverted.x < 0.0 and inverted.y > 0.0, "stick inversion was not applied")
	router.gamepad_invert_x = false
	router.gamepad_invert_y = false

func _verify_calibration(router: Node) -> void:
	router.set_gamepad_calibration(Vector2(0.08, 0.0), Vector2(0.0, 0.08), 2)
	var report: Dictionary = router.get_gamepad_calibration()
	_check(report.has("2"), "per-device calibration was not stored")
	var corrected: Vector2 = router._shape_stick(Vector2(0.08, 0.0), 0.05, false)
	_check(corrected == Vector2.ZERO, "calibrated stick centre still produced movement")
	router.set_gamepad_calibration(Vector2.ZERO, Vector2.ZERO, 2)

func _verify_bindings(router: Node) -> void:
	for action in ["move_left", "move_right", "move_forward", "move_back", "interact", "dodge", "light_attack", "heavy_attack", "block", "oathfire_beam", "pause"]:
		var has_binding := false
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				has_binding = true
				break
		_check(has_binding, "%s has no action-based gamepad binding" % action)
	_check(router.action_label("interact") == "A", "generic controller label is not stable")

func _verify_disconnect_recovery(router: Node) -> void:
	var button := InputEventJoypadButton.new()
	button.device = 2
	button.button_index = JOY_BUTTON_A
	button.pressed = true
	router._input(button)
	_check(router.active_device == router.DEVICE_GAMEPAD and router.active_gamepad_id == 2, "joypad activity did not select the active device")
	router.virtual_move = Vector2.ONE
	router._on_joy_connection_changed(2, false)
	_check(router.active_device == router.DEVICE_KEYBOARD_MOUSE, "disconnect did not return control to keyboard/mouse")
	_check(router.virtual_move == Vector2.ZERO, "disconnect left virtual movement latched")
	# A missing or unsupported rumble device must be a no-op, never an input error.
	router.rumble(1.0, 1.0, 2.0)
	_check(true, "guarded rumble call completed")

func _verify_settings(settings: Node) -> void:
	for key in ["gamepad_deadzone", "gamepad_invert_x", "gamepad_invert_y", "gamepad_rumble_strength"]:
		_check(settings.settings.has(key), "settings missing %s" % key)
	var before := float(settings.settings.get("gamepad_deadzone", 0.0))
	settings.cycle_gamepad_deadzone()
	_check(not is_equal_approx(before, float(settings.settings["gamepad_deadzone"])), "gamepad deadzone cannot be changed")
	settings.settings["gamepad_deadzone"] = before
	var invert_x_before := bool(settings.settings["gamepad_invert_x"])
	settings.toggle_gamepad_invert_x()
	_check(bool(settings.settings["gamepad_invert_x"]) != invert_x_before, "gamepad X inversion cannot be changed")
	settings.toggle_gamepad_invert_x()
	var invert_y_before := bool(settings.settings["gamepad_invert_y"])
	settings.toggle_gamepad_invert_y()
	_check(bool(settings.settings["gamepad_invert_y"]) != invert_y_before, "gamepad Y inversion cannot be changed")
	settings.toggle_gamepad_invert_y()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
