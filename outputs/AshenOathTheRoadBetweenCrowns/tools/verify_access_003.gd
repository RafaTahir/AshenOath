extends SceneTree

const SettingsManager = preload("res://scripts/settings_manager.gd")
const InputRouter = preload("res://scripts/input_router.gd")
const HUD = preload("res://scripts/hud.gd")

var failures := 0

func _initialize() -> void:
	var settings := SettingsManager.new()
	root.add_child(settings)
	var input := InputRouter.new()
	root.add_child(input)
	var hud := HUD.new()
	root.add_child(hud)
	await process_frame
	settings.settings["high_contrast"] = true
	settings.settings["reduced_motion"] = true
	settings.settings["subtitle_scale"] = 1.2
	settings.settings["gamepad_deadzone"] = 0.22
	input.apply_settings(settings.settings)
	hud.apply_accessibility(settings.settings)
	check(hud.high_contrast and hud.reduced_motion, "Accessibility toggles did not reach HUD")
	check(hud.dialogue_text.get_theme_font_size("normal_font_size") >= 28, "Subtitle scale is below the accessible target")
	check(float(input.gamepad_deadzone) == 0.22, "Gamepad deadzone setting was not applied")
	check(input.get_gamepad_profile().has("glyph_theme"), "Generic gamepad profile has no glyph theme")
	check(hud.has_method("set_gamepad_profile"), "HUD has no gamepad profile update contract")
	check("gamepad_disconnected" in input, "Input router has no disconnect recovery signal")
	var remap := InputEventKey.new()
	remap.keycode = KEY_O
	var result := input.remap_action("interact", remap)
	check(bool(result.get("ok", false)), "Keyboard remapping rejected a valid key")
	check(input.action_label("interact") == "O", "Remapped action label is not visible")
	input.reset_bindings()
	check(input.action_label("interact") != "O", "Reset bindings did not restore defaults")
	input._set_device(InputRouter.DEVICE_GAMEPAD)
	input.active_gamepad_id = 0
	input._on_joy_connection_changed(0, false)
	check(input.active_device == InputRouter.DEVICE_KEYBOARD_MOUSE, "Disconnected controller did not fall back to keyboard/mouse")
	check(bool(input.get_disconnect_state().get("fallback_ready", false)), "Disconnect fallback state is not ready")
	input.clear_virtual_input()
	check(input.virtual_move == Vector2.ZERO and input.virtual_look == Vector2.ZERO, "Disconnect cleanup left virtual input active")
	print("ACCESS-003 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
