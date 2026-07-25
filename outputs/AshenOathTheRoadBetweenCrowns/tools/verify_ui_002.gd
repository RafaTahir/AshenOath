extends SceneTree

const HUD = preload("res://scripts/hud.gd")

var failures := 0

func _initialize() -> void:
	var hud := HUD.new()
	root.add_child(hud)
	await process_frame
	hud.show_main_menu()
	await process_frame
	check(hud.active_menu == "main", "Main menu state is not authoritative")
	check(hud.get_window().content_scale_size == Vector2i(1920, 1080), "Menu canvas is not native 1080p")
	for label in ["New Game", "Continue", "Controls", "Settings", "Credits", "Exit Game"]:
		check(_button(hud.menu_layer, label) != null, "Main menu action is missing: %s" % label)
	check(_contains_label(hud.menu_layer, "Continue source:") or _contains_label(hud.menu_layer, "No journey has been saved"), "Continue state has no readable save status")
	hud.show_pause_menu()
	await process_frame
	for label in ["Resume", "Save", "Load", "Journal & Preparation", "Settings", "Controls", "Main Menu"]:
		check(_button(hud.menu_layer, label) != null, "Pause action is missing: %s" % label)
	hud.show_settings_menu("pause")
	await process_frame
	for label_prefix in ["Visual Preset", "Mouse Sensitivity", "Master Volume", "Subtitle Size", "Reduced Motion", "Back"]:
		check(_button_prefix(hud.menu_layer, label_prefix) != null, "Functional setting is missing: %s" % label_prefix)
	hud.show_loading("This must not block")
	check(not hud.loading_layer.visible and hud.loading_layer.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Ordinary loading overlay can still block the game")
	print("UI-002 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
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
