extends SceneTree

const HUD = preload("res://scripts/hud.gd")

var failures := 0

func _initialize() -> void:
	var hud := HUD.new()
	root.add_child(hud)
	await process_frame
	hud.show_main_menu()
	await process_frame
	check(hud.get_window().content_scale_size == Vector2i(hud.GAMEPLAY_SIZE), "Menu changed the native gameplay render target")
	check(hud.menu_layer.size == hud.MENU_SIZE, "Native menu lost its authored 1080p layout")
	check((hud.menu_layer.size * hud.menu_layer.scale).is_equal_approx(Vector2(hud.GAMEPLAY_SIZE)), "Menu transform does not fit the gameplay viewport")
	check(_contains_label(hud.menu_layer, "ASHEN OATH"), "Menu title is missing")
	check(_contains_label(hud.menu_layer, hud.MENU_BUILD_LABEL), "Menu does not render its declared build identity")
	for label in ["New Game", "Continue", "Controls", "Settings", "Credits", "Quit"]:
		check(_button(hud.menu_layer, label) != null, "Main menu action is missing: %s" % label)
	check("RECOVERY-004" in hud.MENU_BUILD_LABEL and "PRE-ALPHA" in hud.MENU_BUILD_LABEL and "NATIVE 720P" in hud.MENU_BUILD_LABEL and not "RELEASE-003" in hud.MENU_BUILD_LABEL, "Menu build identity is stale")
	hud.show_exit_notice()
	check(_contains_label(hud.menu_layer, "cannot close a browser tab"), "Browser-safe exit notice is missing")
	hud.hide_menus()
	hud.set_tracker("Road of Crows\n- Speak with Sister Anwen")
	hud.set_prompt("E  Speak with Sister Anwen")
	hud._apply_hud_layout()
	check(hud.prompt_label.position.y >= 0.0, "Interaction prompt moved outside the viewport")
	check(hud.tracker_label.position.x >= 0.0, "Tracker moved outside the viewport")
	hud.toast("Sella's red thread. The knot is Anwen's. The feathers were tied here, not scattered by a bird.", 5.5)
	await process_frame
	check(hud.toast_label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "Clue observation cannot wrap")
	check(hud.toast_label.get_global_rect().end.x <= hud.GAMEPLAY_SIZE.x and hud.toast_label.get_global_rect().end.y <= hud.GAMEPLAY_SIZE.y, "Clue observation extends beyond the gameplay viewport")
	check(not hud.toast_label.get_global_rect().intersects(hud.prompt_label.get_global_rect()), "Clue observation overlaps the interaction prompt")
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
