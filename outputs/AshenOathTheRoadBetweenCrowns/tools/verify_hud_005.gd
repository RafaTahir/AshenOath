extends SceneTree

const HUD = preload("res://scripts/hud.gd")

var failures := 0

func _initialize() -> void:
	var hud := HUD.new()
	root.add_child(hud)
	await process_frame
	hud.show_main_menu()
	await process_frame
	check(hud.get_window().content_scale_size == Vector2i(1920, 1080), "Menu canvas is not responsive 1080p")
	check(_contains_label(hud.menu_layer, "ASHEN OATH"), "Menu title is missing")
	check(_contains_label(hud.menu_layer, "SOUL REBUILD"), "Menu build identity is stale")
	for label in ["New Game", "Continue", "Controls", "Settings", "Credits", "Quit"]:
		check(_button(hud.menu_layer, label) != null, "Main menu action is missing: %s" % label)
	check("DEVELOPMENT CANDIDATE" in hud.MENU_BUILD_LABEL, "Development menu identity is stale")
	hud.show_exit_notice()
	check(_contains_label(hud.menu_layer, "cannot close a browser tab"), "Browser-safe exit notice is missing")
	hud.hide_menus()
	hud.set_tracker("Road of Crows\n- Speak with Sister Anwen")
	hud.set_prompt("E  Speak with Sister Anwen")
	hud._apply_hud_layout()
	check(hud.prompt_label.position.y >= 0.0, "Interaction prompt moved outside the viewport")
	check(hud.tracker_label.position.x >= 0.0, "Tracker moved outside the viewport")
	hud.show_settings_menu("main", 0)
	await process_frame
	check(_button_prefix(hud.menu_layer, "Back") != null, "Settings has no visible Back action")
	check(_button_prefix(hud.menu_layer, "Next Page") != null, "Settings pagination is missing")
	hud.apply_accessibility({"high_contrast": true, "reduced_motion": true, "subtitle_scale": 1.2})
	check(hud.high_contrast and hud.reduced_motion, "Accessibility state was not retained")
	check(hud.dialogue_text.get_theme_font_size("normal_font_size") >= 28, "Subtitle scaling did not apply")
	print("HUD-005 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _button(scope: Node, text: String) -> Button:
	for node in scope.find_children("*", "Button", true, false):
		if str(node.text) == text:
			return node as Button
	return null

func _button_prefix(scope: Node, text: String) -> Button:
	for node in scope.find_children("*", "Button", true, false):
		if str(node.text).begins_with(text):
			return node as Button
	return null

func _contains_label(scope: Node, text: String) -> bool:
	for node in scope.find_children("*", "Label", true, false):
		if str(node.text).contains(text):
			return true
	return false

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
