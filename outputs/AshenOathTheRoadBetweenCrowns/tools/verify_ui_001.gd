extends SceneTree

var failures := 0

func _initialize() -> void:
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
	hud.set_input_device("keyboard_mouse")
	var vitals = hud.find_child("VitalsBackdrop", true, false)
	var tracker = hud.find_child("QuestTrackerBackdrop", true, false)
	var compass = hud.find_child("CompassBackdrop", true, false)
	check(vitals != null and vitals.size.x <= 270.0 and vitals.size.y <= 95.0, "Vitals panel is not compact")
	check(tracker != null and tracker.size.x <= 340.0 and tracker.size.y <= 115.0, "Quest tracker is not compact")
	check(compass != null and compass.size.y <= 34.0, "Compass consumes too much vertical space")

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
		check(hud.find_children("DialogueSpeakerName", "Label", true, false).size() == 1, "Dialogue speaker name is duplicated")
		check(hud.dialogue_page_label != null and hud.dialogue_page_label.text.contains("/"), "Dialogue page progress missing")
		check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Dialogue did not release the mouse")
		check(_anwen_faces_player(anwen, game.player), "Sister Anwen faces away during dialogue")
		game.call("_refresh_tracker")
		print("UI-001 tracker: %s | compass: %s" % [hud.tracker_label.text.replace("\n", " / "), hud.compass_label.text])
		check(not hud.compass_label.text.contains("hidden register"), "Compass contradicts the current tracked objective")

	print("UI-001 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	game.queue_free()
	await settle(3)
	quit(0 if failures == 0 else 1)

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
