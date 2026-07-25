extends SceneTree

const SettingsManager = preload("res://scripts/settings_manager.gd")
const InputRouter = preload("res://scripts/input_router.gd")
const HUD = preload("res://scripts/hud.gd")

var failures := 0

func _initialize() -> void:
	var settings := SettingsManager.new()
	settings.name = "Settings"
	root.add_child(settings)
	var input := InputRouter.new()
	root.add_child(input)
	var hud := HUD.new()
	root.add_child(hud)
	await process_frame
	settings.settings["control_preset"] = "left_handed"
	settings.settings["high_contrast"] = true
	settings.settings["reduced_motion"] = true
	settings.settings["subtitle_scale"] = 1.2
	input.apply_settings(settings.settings)
	hud.apply_accessibility(settings.settings)
	check(input.action_label("interact") == "O", "Left-handed interaction label was not remapped")
	check(input.action_label("light_attack") == "Right Mouse", "Left-handed attack label was not remapped")
	check(_has_key("move_forward", KEY_I), "Left-handed movement binding was not installed")
	check(_has_key("interact", KEY_O), "Left-handed interaction binding was not installed")
	check(hud.reduced_motion and hud.high_contrast, "HUD accessibility state was not applied")
	check(hud.dialogue_text.get_theme_font_size("normal_font_size") >= 28, "Subtitle scaling did not reach the dialogue text")
	hud.show_main_menu()
	await process_frame
	for button in hud.menu_layer.find_children("*", "Button", true, false):
		check((button as Button).focus_mode == Control.FOCUS_ALL, "Menu button cannot receive keyboard/gamepad focus: %s" % button.text)
	settings.cycle_control_preset()
	input.apply_settings(settings.settings)
	check(input.action_label("interact") == "E" and _has_key("interact", KEY_E), "Standard controls were not restored")
	print("ACCESS-001 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _has_key(action: String, keycode: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).keycode == keycode:
			return true
	return false

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
