extends SceneTree

const Hud = preload("res://scripts/hud.gd")
var activations := 0
var selected_journeys: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var click_test := "--click" in OS.get_cmdline_user_args()
	if click_test and DisplayServer.get_name().to_lower() == "headless":
		push_error("Click proof requires graphical rendering")
		quit(1)
		return
	var hud := Hud.new()
	var saves = preload("res://scripts/save_manager.gd").new()
	root.add_child(saves)
	hud.set_runtime_services(null, saves)
	root.add_child(hud)
	hud.show_main_menu()
	for frame in range(3):
		await process_frame
	var buttons := hud.menu_layer.find_children("*", "Button", true, false)
	var focus: Button = buttons[2]
	focus.grab_focus()
	var status := hud.new_game_status_label
	for index in range(20):
		hud.set_new_game_status("Preparing Greyfen %d" % index)
		hud.set_new_game_ready(index % 2 == 0)
	await process_frame
	var passed := hud.menu_layer.find_children("*", "Button", true, false) == buttons
	passed = passed and not hud._gameplay_ui_ready and hud.dialogue_layer.get_child_count() == 0 and hud.inventory_layer.get_child_count() == 0
	passed = passed and status == hud.new_game_status_label and status.text == "Preparing Greyfen 19"
	passed = passed and root.gui_get_focus_owner() == focus
	var selected := {"slot_id":"auto", "source":"primary", "token":"earned-copy"}
	hud.set_journey_models({"continue":{"available":true, "selection":selected, "summary":{}}})
	hud.journey_load_requested.connect(func(selection: Dictionary): selected_journeys.append(selection))
	var continue_button := hud._journey_primary_button
	continue_button.pressed.emit()
	for frame in range(2):
		await process_frame
	passed = passed and selected_journeys.size() == 1 and selected_journeys[0] == selected
	print("MENU CONTINUE CALLBACK: selections=%d" % selected_journeys.size())
	saves.durability_changed.emit("pending", "Waiting for browser storage.")
	passed = passed and hud._save_durability_notice.visible and hud._save_durability_notice.text == "Waiting for browser storage."
	saves.durability_changed.emit("durable", "Confirmed in browser storage.")
	passed = passed and hud._save_durability_notice.text == "Confirmed in browser storage."
	saves.durability_changed.emit("failed", "Save again before closing.")
	passed = passed and hud._save_durability_notice.text == "Save again before closing."
	passed = passed and root.gui_get_focus_owner() == focus
	if click_test:
		hud.new_game_requested.connect(func(): activations += 1)
		var new_game: Button
		for button in buttons:
			if button.text == "New Game":
				new_game = button
		if new_game == null:
			passed = false
		else:
			await RenderingServer.frame_post_draw
			var point := root.get_final_transform() * new_game.get_global_rect().get_center()
			var motion := InputEventMouseMotion.new()
			motion.position = point
			Input.parse_input_event(motion)
			var press := InputEventMouseButton.new()
			press.position = point
			press.button_index = MOUSE_BUTTON_LEFT
			press.pressed = true
			Input.parse_input_event(press)
			await process_frame
			hud.set_new_game_status("Greyfen ready during mouse press")
			hud.set_new_game_ready(true)
			var release := InputEventMouseButton.new()
			release.position = point
			release.button_index = MOUSE_BUTTON_LEFT
			release.pressed = false
			Input.parse_input_event(release)
			await process_frame
			passed = passed and activations == 1
			print("MENU PRESS/UPDATE/RELEASE: activations=%d" % activations)
	hud.show_controls_menu("main")
	hud.set_new_game_status("Ready while controls are open")
	passed = passed and hud.active_menu != "main" and hud.new_game_status_label == null
	hud.prepare_gameplay_ui()
	var dialogue_surface := hud.dialogue_layer
	var inventory_surface := hud.inventory_layer
	var content_count := dialogue_surface.get_child_count() + inventory_surface.get_child_count()
	hud.prepare_gameplay_ui()
	passed = passed and hud._gameplay_ui_ready and hud.dialogue_text != null and hud.inventory_text != null
	passed = passed and dialogue_surface == hud.dialogue_layer and inventory_surface == hud.inventory_layer and content_count == dialogue_surface.get_child_count() + inventory_surface.get_child_count()
	hud.queue_free()
	saves.queue_free()
	for frame in range(3):
		await process_frame
	if not passed:
		push_error("Menu status update replaced controls or stole focus")
	print("MENU STATUS STABILITY: " + ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
