extends SceneTree

var failures := 0
var release_count := 0
var released_direction := Vector3.ZERO

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	check(scene != null, "Main scene missing")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.settings.set_quality_preset("balanced")
	game.call("_new_game")
	await settle(5)
	var player = game.player
	check(player != null, "Player missing")
	check(player.beam_left_hand_socket is BoneAttachment3D, "Left Oathfire glow is not attached to the hand skeleton")
	check(player.beam_right_hand_socket is BoneAttachment3D, "Right Oathfire glow is not attached to the hand skeleton")
	player.beam_requested.connect(_on_beam_requested)

	player.rotation.y = 0.0
	player.call("_begin_oathfire_cast")
	var locked: Vector3 = player.get_beam_locked_direction()
	player.rotation.y = PI * 0.5
	player.call("_update_beam_sequence", 0.05)
	check(player.get_beam_locked_direction().dot(locked) > 0.999, "Camera/player motion changed the locked cast direction")
	check((-player.global_transform.basis.z).dot(locked) > 0.98, "Kael did not remain oriented to the locked cast direction")

	player.beam_cast_state = "charging"
	player.beam_charge_time = 1.1
	player.call("_update_beam_charge_visual")
	var origin: Vector3 = player.get_oathfire_origin()
	var hand_midpoint: Vector3 = player.beam_left_hand_glow.global_position.lerp(player.beam_right_hand_glow.global_position, 0.5)
	check(origin.distance_to(hand_midpoint) < 0.5, "Charge origin is disconnected from Kael's hands")
	check(player.sheathed_sword_visual != null and player.sheathed_sword_visual.visible, "Sword is not sheathed during Oathfire charge")

	player.call("_commit_oathfire_release", 0.8)
	player.call("_update_beam_sequence", 0.08)
	check(release_count == 0, "Oathfire released before the hand-thrust contact frame")
	player.call("_update_beam_sequence", 0.04)
	check(release_count == 1, "Oathfire did not release exactly at the contact frame")
	player.call("_update_beam_sequence", 0.08)
	check(release_count == 1, "Oathfire emitted more than once")
	check(released_direction.dot(locked) > 0.999, "Released beam differs from the initially locked direction")

	await settle(2)
	var cast: Dictionary = game.get_meta("last_oathfire_cast", {})
	check(not cast.is_empty(), "Game did not record an authoritative Oathfire cast")
	if not cast.is_empty():
		check((cast.get("origin", Vector3.ZERO) as Vector3).distance_to(origin) < 0.6, "Damage and hand VFX origins disagree")
		check((cast.get("direction", Vector3.ZERO) as Vector3).dot(locked) > 0.999, "Damage resolver direction differs from the locked direction")
		check((cast.get("endpoint", Vector3.ZERO) as Vector3).distance_to(cast.get("origin", Vector3.ZERO)) <= 12.01, "Beam exceeded its authored range")
	var effects: Array[Node] = get_nodes_in_group("oathfire_runtime_effect")
	check(effects.size() == 1, "Oathfire must create one coherent runtime beam effect")
	if not effects.is_empty():
		check(effects[0].find_child("OathfireBeamCore", true, false) != null, "Potato-safe beam core missing")
		check(effects[0].find_child("OathfireBeamHotCore", true, false) != null, "Authored hot core missing in Balanced mode")

	game.call("_load_zone", "greyfen", Vector3(0, 1, 7))
	await settle(3)
	check(get_nodes_in_group("oathfire_runtime_effect").is_empty(), "Oathfire VFX survived a zone transition")
	check(player.beam_cast_state == "" and player.get_beam_locked_direction() == Vector3.ZERO, "Oathfire state survived cancellation/zone transition")
	var result_code := 0 if failures == 0 else 1
	print("OATH-001 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	await _finish(game)
	quit(result_code)

func _on_beam_requested(_ratio: float, direction: Vector3) -> void:
	release_count += 1
	released_direction = direction

func settle(frames: int) -> void:
	for _index in range(frames):
		await process_frame
		await physics_frame

func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("OATH-001: %s" % message)

func _finish(game: Node) -> void:
	if game != null and is_instance_valid(game):
		if game.has_method("finalize_resource_shutdown"):
			game.finalize_resource_shutdown()
		elif game.has_method("prepare_resource_shutdown"):
			game.prepare_resource_shutdown()
		await settle(int(game.ZONE_RETIRE_FRAMES) + 4)
		game.queue_free()
	await settle(24)
	if is_instance_valid(game):
		game.free()
		await settle(2)
	RenderingServer.force_sync()
