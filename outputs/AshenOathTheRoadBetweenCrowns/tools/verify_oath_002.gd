extends SceneTree

var failures := 0
var release_count := 0
var released_direction := Vector3.ZERO

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	check(scene != null, "Main scene missing")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await settle(2)
	if game.settings != null:
		game.settings.set_quality_preset("balanced")
	game.call("_new_game")
	await settle(8)
	var player = game.player
	check(player != null, "Player missing")
	if player == null:
		await finish(game)
		quit(1)
		return
	player.beam_requested.connect(_on_beam_requested)

	# The first press owns the direction. Camera/player rotation after that
	# must not move the cast corridor.
	player.rotation.y = 0.0
	check(player.call("_begin_oathfire_cast"), "Oathfire did not enter sheathing")
	var locked: Vector3 = player.get_beam_locked_direction()
	check(locked.length() > 0.9, "Initial facing was not captured")
	player.rotation.y = PI * 0.5
	player.call("_update_beam_sequence", 0.05)
	check(player.get_beam_locked_direction().dot(locked) > 0.999, "Camera/player rotation changed locked direction")
	check((-player.global_transform.basis.z).dot(locked) > 0.98, "Player did not hold the initial cast orientation")

	# Charge presentation must be hand-based and sword-safe.
	player.beam_cast_state = "charging"
	player.beam_charging = true
	player.beam_charge_time = 1.05
	player.call("_update_beam_charge_visual")
	var state: Dictionary = player.get_oathfire_state()
	check(str(state.get("state", "")) == "charging", "Charge state is not reported")
	check(bool(state.get("sword_sheathed", false)), "Sword was not sheathed during charge")
	check(bool(state.get("charge_visible", false)), "Charge sphere is not visible")
	check(bool(state.get("hands_visible", false)), "Both hand charge effects are not visible")
	var origin: Vector3 = player.get_oathfire_origin()
	var left: Vector3 = player.beam_left_hand_glow.global_position
	var right: Vector3 = player.beam_right_hand_glow.global_position
	check(origin.distance_to(left.lerp(right, 0.5)) < 0.5, "Charge origin is disconnected from the hands")

	# Release uses the same locked direction and starts a cooldown.
	player.call("_commit_oathfire_release", 0.82)
	check(str(player.get_oathfire_state().get("state", "")) == "releasing", "Release state did not begin")
	await settle(7)
	check(release_count == 1, "Oathfire did not emit exactly once")
	check(released_direction.dot(locked) > 0.999, "Released beam differs from initial facing")
	check(float(player.get_oathfire_state().get("cooldown", 0.0)) > 0.0, "Release did not start cooldown")

	# A wall must clip the authoritative endpoint used for both damage and VFX.
	var wall := StaticBody3D.new()
	wall.name = "OathfireVerifierWall"
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(4.0, 3.0, 0.35)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	game.zone_root.add_child(wall)
	wall.global_position = player.global_position + locked * 3.0 + Vector3.UP * 1.3
	await physics_frame
	game.call("_on_player_beam", 1.0, locked)
	await settle(2)
	var cast: Dictionary = game.get_meta("last_oathfire_cast", {})
	check(not cast.is_empty(), "Game did not record the authoritative cast")
	if not cast.is_empty():
		var cast_origin: Vector3 = cast.get("origin", Vector3.ZERO)
		var endpoint: Vector3 = cast.get("endpoint", Vector3.ZERO)
		check((cast.get("direction", Vector3.ZERO) as Vector3).dot(locked) > 0.999, "Resolver direction differs from locked direction")
		check(cast_origin.distance_to(endpoint) < 4.0, "Beam endpoint ignored world collision")
		check(abs(float(cast.get("endpoint_distance", -1.0)) - cast_origin.distance_to(endpoint)) < 0.01, "Cast endpoint distance is stale")
	check(get_nodes_in_group("oathfire_runtime_effect").size() == 1, "Release did not create one coherent beam effect")

	# Transition lock is the authoritative cancellation path and restores the sword.
	await settle(32)
	player.beam_cooldown = 0.0
	check(player.call("_begin_oathfire_cast"), "Second cast could not begin after cooldown reset")
	player.set_transition_locked(true)
	state = player.get_oathfire_state()
	check(str(state.get("state", "")) == "", "Transition lock left Oathfire active")
	check(state.get("locked_direction", Vector3.ZERO) == Vector3.ZERO, "Transition cancellation retained direction")
	check(not bool(state.get("charge_visible", false)), "Transition cancellation left charge VFX visible")
	check(not bool(state.get("sword_sheathed", true)), "Transition cancellation left sword sheathed")
	check(str(state.get("cancel_reason", "")) == "transition", "Cancellation reason was not recorded")
	player.set_transition_locked(false)

	await settle(32)
	check(get_nodes_in_group("oathfire_runtime_effect").is_empty(), "Oathfire VFX survived recovery")
	print("OATH-002 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	var result_code := 0 if failures == 0 else 1
	await finish(game)
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
	push_error("OATH-002: %s" % message)

func finish(game: Node) -> void:
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
