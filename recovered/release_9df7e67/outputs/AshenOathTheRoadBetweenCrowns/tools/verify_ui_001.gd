extends SceneTree

var failures := 0

func _initialize() -> void:
	if "--inventory-input-only" in OS.get_cmdline_user_args():
		await _verify_inventory_input()
		print("UI-001 INVENTORY INPUT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
		quit(0 if failures == 0 else 1)
		return
	if "--dialogue-input-only" in OS.get_cmdline_user_args():
		await _verify_dialogue_input()
		print("UI-001 DIALOGUE INPUT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
		quit(0 if failures == 0 else 1)
		return
	var scene: PackedScene = load("res://scenes/main.tscn")
	check(scene != null, "Main scene missing")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_new_game")
	await settle(6)

	var hud = game.hud
	check(hud != null, "HUD missing")
	hud.update_health(125.0, 125.0)
	check(not hud.is_processing(), "Healthy HUD still polls every frame")
	hud.arm_loading("Checking the road")
	check(hud.is_processing(), "Loading delay did not wake HUD processing")
	await create_timer(0.80).timeout
	check(hud.loading_layer.visible and not hud.is_processing(), "Loading reveal kept idle HUD processing active")
	hud.hide_loading()
	hud.apply_accessibility({"reduced_motion": false})
	hud.update_health(25.0, 125.0)
	check(hud.is_processing(), "Low-health pulse did not wake HUD processing")
	hud.apply_accessibility({"reduced_motion": true})
	check(not hud.is_processing(), "Reduced motion did not stop the health pulse")
	hud.update_health(125.0, 125.0)
	hud.apply_accessibility({"reduced_motion": false})
	check(not hud.is_processing(), "Restored health left idle HUD processing active")
	hud.set_input_device("keyboard_mouse")
	var vitals = hud.find_child("VitalsBackdrop", true, false)
	var tracker = hud.find_child("QuestTrackerBackdrop", true, false)
	var compass = hud.find_child("CompassBackdrop", true, false)
	check(vitals != null and vitals.size.x <= 270.0 and vitals.size.y <= 95.0, "Vitals panel is not compact")
	check(tracker != null and tracker.size.x <= 340.0 and tracker.size.y <= 115.0, "Quest tracker is not compact")
	check(compass != null and compass.size.y <= 34.0, "Compass consumes too much vertical space")
	check(compass != null and not compass.visible, "Compass still has a wide opaque backdrop")

	hud.set_prompt("E - Talk to Sister Anwen")
	check(hud.prompt_label.text.begins_with("[E]"), "Interaction prompt lacks a readable key treatment")
	hud.set_compass("Sister Anwen | 4m")
	check(not hud.compass_label.text.contains(" | "), "Compass still uses debug-style separators")
	hud.set_tracker("Road of Crows\nSpeak to Sister Anwen at the shrine")
	check(hud.tracker_label.text.contains("ROAD OF CROWS"), "Tracked quest hierarchy missing")

	var anwen = game.zone_root.find_child("sister_anwen", true, false)
	check(anwen != null, "Sister Anwen missing from Greyfen")
	if anwen != null:
		game.player.global_position = anwen.global_position + Vector3(0.0, 0.0, 2.4)
		game.player.velocity = Vector3.ZERO
		await settle(24)
		check(_anwen_faces_player(anwen, game.player), "Sister Anwen turns her visible body away when Kael approaches")
		game.call("_handle_interaction", anwen)
		await settle(4)
		var dialogue = hud.find_child("DialogueLowerThird", true, false)
		check(dialogue != null and dialogue.visible, "Dialogue lower third did not open")
		if dialogue != null:
			check(dialogue.position.y >= 420.0 and dialogue.size.y <= 270.0, "Dialogue panel still obscures too much of the play view")
		check(not hud.prompt_label.visible, "Interaction prompt overlaps dialogue")
		check(not hud.toast_label.visible, "Quest toast overlaps dialogue")
		check(not hud.hint_label.visible, "Guidance hint overlaps dialogue")
		hud.set_prompt("E - Talk to Sister Anwen")
		hud.toast("Dialogue should suppress this toast")
		check(not hud.prompt_label.visible and not hud.toast_label.visible, "Gameplay notices reappeared during dialogue")
		check(hud.find_children("DialogueSpeakerName", "Label", true, false).size() == 1, "Dialogue speaker name is duplicated")
		check(hud.dialogue_page_label != null and hud.dialogue_page_label.text.contains("/"), "Dialogue page progress missing")
		check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Dialogue did not release the mouse")
		check(_anwen_faces_player(anwen, game.player), "Sister Anwen faces away during dialogue")
		game.call("_refresh_tracker")
		print("UI-001 tracker: %s | compass: %s" % [hud.tracker_label.text.replace("\n", " / "), hud.compass_label.text])
		check(not hud.compass_label.text.contains("hidden register"), "Compass contradicts the current tracked objective")
		check(hud.compass_label.text.contains("Wychwood"), "Compass still points to Greyfen after Anwen assigns the Wychwood route")
		game.interaction_focus_dirty = false
		game.interaction_focus_cache_valid = true
		check(hud._close_dialogue_surface(), "Dialogue did not close cleanly")
		hud.dialogue_closed.emit()
		check(game.interaction_focus_dirty and not game.interaction_focus_cache_valid, "Closing dialogue did not refresh interaction focus")
		hud.set_prompt("E - Talk to Sister Anwen")
		check(hud.prompt_label.visible, "Interaction prompt remains suppressed after dialogue closes")

	game.prepare_resource_shutdown()
	await settle(game.ZONE_RETIRE_FRAMES + 6)
	game.finalize_resource_shutdown()
	await settle(8)
	root.remove_child(game)
	game.free()
	RenderingServer.force_sync()
	print("UI-001 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _verify_dialogue_input() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var hud = load("res://scripts/hud.gd").new()
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(hud)
	await settle(3)
	var selected: Array[String] = []
	hud.action_selected.connect(func(action: Dictionary): selected.append(str(action.id)))
	var actions: Array = [
		{"label": "Cleanse the shrine", "id": "cleanse"},
		{"label": "Disturb it for memory", "id": "disturb"},
		{"label": "Bind it and leave", "id": "bind"},
	]
	var data := {"name": "Kael", "pages": [
		{"speaker": "Kael", "text": "What happens next?"},
		{"speaker": "Kael", "text": "Innocence was never on offer. Only what happens next."},
	], "actions": actions}
	var observer = load("res://scripts/production_observation_bridge.gd").new()
	paused = true
	for choice in range(actions.size()):
		hud.show_dialogue(data)
		await settle(3)
		await _dialogue_key(KEY_ENTER)
		check(hud.dialogue_page_index == 1, "Enter advanced more than one dialogue page")
		check(hud.dialogue_actions.get_child_count() == 3, "Previous page buttons remain in the rebuilt choices")
		var buttons: Array = hud.dialogue_actions.get_children()
		check(buttons[0].has_focus(), "Rebuilt page focused a deleted Continue button")
		for button in buttons:
			var rect: Rect2 = button.get_global_rect()
			check(rect.position.y >= 0 and rect.end.y <= 720 and rect.end.x <= 1280, "Dialogue choice is clipped outside the viewport")
		check(observer._visible_menu_buttons(hud).size() == 3, "Read-only UI observation omits dialogue hit bounds")
		await _dialogue_pointer(Vector2(12, 12))
		check(hud.dialogue_layer.visible and selected.size() == choice, "Outside click activated a dialogue choice")
		await _dialogue_pointer(buttons[choice].get_global_rect().get_center())
		check(selected.size() == choice + 1 and selected.back() == actions[choice].id, "Pointer activated the focused choice instead of its actual hit target")
	for choice in range(actions.size()):
		hud.show_dialogue(data)
		await settle(3)
		await _dialogue_key(KEY_ENTER)
		for step in range(choice):
			await _dialogue_key(KEY_DOWN)
		await _dialogue_key(KEY_ENTER)
		check(selected.size() == actions.size() + choice + 1 and selected.back() == actions[choice].id, "Keyboard dialogue selection selected the wrong action")
	paused = false
	observer.free()
	root.remove_child(hud)
	hud.free()
	await settle(6)
	RenderingServer.force_sync()

func _verify_inventory_input() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var hud = load("res://scripts/hud.gd").new()
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(hud)
	var inventory = load("res://scripts/inventory_manager.gd").new()
	inventory.load_items("res://data/items.json")
	var quests = load("res://scripts/quest_manager.gd").new()
	var progression = load("res://scripts/progression_manager.gd").new()
	progression.load_definitions()
	progression.award_for_quest("main_road_of_crows", "main")
	var refresh_preparation := func(): hud.show_inventory(inventory, quests, null, progression)
	inventory.changed.connect(refresh_preparation)
	hud.craft_requested.connect(func(id: String): inventory.craft(id))
	await settle(3)
	paused = true
	hud.show_inventory(inventory, quests, null, progression)
	await settle(4)
	var craft: Button = null
	for button in hud.craft_buttons.get_children():
		if button.text == "Craft Redroot Potion":
			craft = button
	check(craft != null and not craft.disabled, "Redroot crafting control missing")
	var before := int(inventory.items.redroot_potion)
	if craft != null:
		await _dialogue_pointer(craft.get_global_rect().get_center())
	check(int(inventory.items.redroot_potion) == before + 1, "Physical crafting click did not produce one potion")
	var focused := root.gui_get_focus_owner()
	check(focused is Button and not focused.is_queued_for_deletion() and hud.craft_buttons.is_ancestor_of(focused), "Inventory rebuild lost live keyboard focus")
	check(hud.inventory_layer.get_global_rect().end.y <= 720, "Preparation panel exceeds 720p viewport")
	for _step in range(hud.craft_buttons.get_child_count() + 2):
		focused = root.gui_get_focus_owner()
		if focused is Button and focused.text == "Close":
			break
		await _dialogue_key(KEY_DOWN)
	focused = root.gui_get_focus_owner()
	check(focused is Button and focused.text == "Close", "Keyboard navigation cannot reach Close after crafting")
	if focused is Button and focused.text == "Close":
		var rect := focused.get_global_rect()
		check(rect.position.y >= 0 and rect.end.y <= 720 and rect.end.x <= 1280, "Focused Close is clipped outside viewport")
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--inventory-capture="):
				var capture_path := argument.trim_prefix("--inventory-capture=")
				await RenderingServer.frame_post_draw
				check(root.get_texture().get_image().save_png(capture_path) == OK, "Preparation capture failed")
		await _dialogue_key(KEY_ENTER)
		check(not hud.inventory_layer.visible and not paused, "Keyboard Close failed to restore gameplay")
	inventory.changed.disconnect(refresh_preparation)
	var vendor = load("res://scripts/vendor_service.gd").new()
	vendor.load_vendors("res://data/vendors.json")
	vendor.changed.connect(func(): hud.show_vendor("mira_apothecary", vendor, inventory, quests))
	hud.vendor_purchase_requested.connect(func(id: String, item: String, count: int): vendor.buy(id, item, count, inventory, null, quests))
	paused = true
	hud.show_vendor("mira_apothecary", vendor, inventory, quests)
	await settle(4)
	var coin_before := int(inventory.coin)
	var potions_before := int(inventory.items.redroot_potion)
	await _dialogue_key(KEY_ENTER)
	await settle(4)
	check(int(inventory.items.redroot_potion) == potions_before + 1 and int(inventory.coin) == coin_before - 6, "Physical vendor purchase did not spend earned coin")
	focused = root.gui_get_focus_owner()
	check(focused is Button and not focused.is_queued_for_deletion() and hud.craft_buttons.is_ancestor_of(focused), "Vendor rebuild lost live keyboard focus")
	for _step in range(hud.craft_buttons.get_child_count() + 2):
		focused = root.gui_get_focus_owner()
		if focused is Button and focused.text == "Close":
			break
		await _dialogue_key(KEY_DOWN)
	await _dialogue_key(KEY_ENTER)
	check(not hud.inventory_layer.visible and not paused, "Vendor keyboard Close failed")
	paused = false
	root.remove_child(hud)
	hud.free()
	inventory.free()
	quests.free()
	progression.free()
	vendor.free()
	await settle(6)
	RenderingServer.force_sync()

func _dialogue_key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await settle(2)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await settle(2)

func _dialogue_pointer(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	await settle(2)
	event = event.duplicate()
	event.button_mask = 0
	event.pressed = false
	Input.parse_input_event(event)
	await settle(2)

func _anwen_faces_player(anwen: Node3D, player: Node3D) -> bool:
	var to_player := player.global_position - anwen.global_position
	to_player.y = 0.0
	if to_player.length() < 0.1:
		return false
	# The interactable is only the gameplay wrapper. The imported humanoid is
	# rotated inside it by the character-role normalization contract, so measure
	# the rendered actor rather than the wrapper's forward axis.
	var visible_actor: Node3D = null
	for candidate in anwen.find_children("*", "Node3D", true, false):
		var node := candidate as Node3D
		if node != null and bool(node.get_meta("source_forward_positive_z", false)):
			visible_actor = node
			break
	if visible_actor == null:
		visible_actor = anwen
	var visible_forward := visible_actor.global_basis.z
	visible_forward.y = 0.0
	return visible_forward.normalized().dot(to_player.normalized()) > 0.90

func settle(frames: int) -> void:
	for _index in range(frames):
		await process_frame
		await physics_frame

func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("UI-001: %s" % message)
