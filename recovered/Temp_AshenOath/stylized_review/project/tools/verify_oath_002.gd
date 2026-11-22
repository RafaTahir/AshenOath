extends SceneTree

var failures := 0
var release_count := 0
var released_direction := Vector3.ZERO

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("OATH-001 rendered verification requires a graphical renderer")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
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
	player.call("_animate_visuals", 1.0 / 30.0, Vector3.ZERO, false)
	await process_frame
	var state: Dictionary = player.get_oathfire_state()
	check(str(state.get("state", "")) == "charging", "Charge state is not reported")
	check(bool(state.get("sword_sheathed", false)), "Sword was not sheathed during charge")
	check(bool(state.get("charge_visible", false)), "Charge sphere is not visible")
	check(bool(state.get("hands_visible", false)), "Both hand charge effects are not visible")
	var origin: Vector3 = player.get_oathfire_origin()
	var left: Vector3 = player.beam_left_hand_glow.global_position
	var right: Vector3 = player.beam_right_hand_glow.global_position
	var left_bone := _live_socket_origin(player.beam_left_hand_socket)
	var right_bone := _live_socket_origin(player.beam_right_hand_socket)
	print("OATH HAND ALIGNMENT ", JSON.stringify({"left_glow": str(left), "right_glow": str(right), "left_bone": str(left_bone), "right_bone": str(right_bone), "charge": str(player.beam_charge_visual.global_position)}))
	check(origin.distance_to(left.lerp(right, 0.5)) < 0.5, "Charge origin is disconnected from the hands")
	check(left.distance_to(left_bone) < 0.12 and right.distance_to(right_bone) < 0.12, "Hand effects are disconnected from the live hand bones")
	check(left.lerp(right, 0.5).y - player.global_position.y > 0.75, "Oathfire charge is below Kael's hands")
	check(player.beam_charge_visual.global_position.distance_to(left.lerp(right, 0.5) + locked * 0.24) < 0.12, "Charge sphere is disconnected from the current hand midpoint")
	var camera := root.get_viewport().get_camera_3d()
	if camera != null:
		var hand_screen := camera.unproject_position(left.lerp(right, 0.5))
		var charge_screen := camera.unproject_position(player.beam_charge_visual.global_position)
		var screen_separation := hand_screen.distance_to(charge_screen)
		print("OATH SCREEN ALIGNMENT ", JSON.stringify({"hands": str(hand_screen), "charge": str(charge_screen), "separation_px": screen_separation}))
		check(screen_separation <= 36.0, "Charge sphere is visually disconnected from Kael's hands")
	check(player.beam_arm_pose_applied, "Two-hand charge pose is not active")
	check(left.distance_to(right) <= 0.45, "Charge hands did not converge around Oathfire")
	check((left.lerp(right, 0.5) - player.global_position).dot(-player.global_basis.z) > 0.25, "Charge hands are not in front of Kael")
	check(player.beam_charge_visual.get_aabb().size.x * player.beam_charge_visual.global_basis.get_scale().x <= 0.34, "Charge sphere is oversized")
	await _capture_frame("D:/Temp/AshenOath/oath001_charge.png")

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
	var effects := get_nodes_in_group("oathfire_runtime_effect")
	if effects.size() == 1:
		var effect := effects[0] as Node3D
		var core := effect.find_child("OathfireBeamCore", true, false) as MeshInstance3D
		check(core != null and core.mesh is CylinderMesh, "Release has no authoritative beam core")
		if core != null and core.mesh is CylinderMesh and not cast.is_empty():
			var endpoint: Vector3 = cast.get("endpoint", Vector3.ZERO)
			var cast_origin: Vector3 = cast.get("origin", Vector3.ZERO)
			check(effect.global_position.distance_to(cast_origin.lerp(endpoint, 0.5)) < 0.03, "Beam visual midpoint differs from the cast")
			check(absf((core.mesh as CylinderMesh).height - cast_origin.distance_to(endpoint)) < 0.03, "Beam visual length differs from the cast")
	var endpoint_visual := game.zone_root.find_child("OathfireImpactEndpoint", true, false) as Node3D
	check(endpoint_visual != null, "Collision endpoint has no rendered impact")
	if endpoint_visual != null and not cast.is_empty():
		check(endpoint_visual.global_position.distance_to(cast.get("endpoint", Vector3.ZERO)) < 0.03, "Rendered impact differs from the authoritative endpoint")
	await _capture_frame("D:/Temp/AshenOath/oath001_release.png")

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
	player.call("_update_oathfire_arm_pose")
	check(not player.beam_arm_pose_applied, "Transition cancellation retained the two-hand arm pose")
	check(get_nodes_in_group("oathfire_runtime_effect").is_empty(), "Transition cancellation retained a release effect")
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

func _capture_frame(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image != null and image.get_size() == Vector2i(1280, 720), "Rendered evidence has the wrong dimensions")
	if image != null:
		var bright_samples := 0
		for y in range(0, image.get_height(), 12):
			for x in range(0, image.get_width(), 12):
				var pixel := image.get_pixel(x, y)
				if pixel.r + pixel.g + pixel.b > 0.18:
					bright_samples += 1
		check(bright_samples >= 24, "Rendered evidence is blank")
		image.save_png(path)
		print("OATH-001 IMAGE ", path)

func _live_socket_origin(socket: BoneAttachment3D) -> Vector3:
	if socket == null:
		return Vector3.INF
	var skeleton := socket.get_parent() as Skeleton3D
	if skeleton == null or socket.bone_idx < 0:
		return socket.global_position
	return (skeleton.global_transform * skeleton.get_bone_global_pose(socket.bone_idx)).origin

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
