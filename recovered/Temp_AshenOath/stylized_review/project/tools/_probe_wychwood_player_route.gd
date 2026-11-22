extends SceneTree

## One-shot native reproduction for the Wychwood bridge-to-clearing report.
## This deliberately uses the real CharacterBody3D/InputRouter path and also
## records every capsule-query owner along the corridor before/after movement.

var failures: Array[String] = []
var game: Node
var player: CharacterBody3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	_assert(packed != null, "main scene did not load")
	if packed == null:
		_finish()
		return
	game = packed.instantiate()
	root.add_child(game)
	await _frames(3)
	_assert(game.has_method("_new_game"), "main scene has no _new_game")
	if not game.has_method("_new_game"):
		_finish()
		return
	game.call("_new_game")
	await _wait_for_player("greyfen", 900)
	if player == null:
		_finish()
		return
	var telemetry_script = load("res://scripts/qa_browser_telemetry.gd")
	var telemetry = telemetry_script.new() if telemetry_script != null else null
	_assert(telemetry != null, "native telemetry serialization fixture unavailable")
	if telemetry != null:
		root.add_child(telemetry)
		var greyfen_snapshot: Dictionary = telemetry.snapshot_for_game(game)
		var greyfen_json := JSON.stringify(greyfen_snapshot)
		_assert(JSON.parse_string(greyfen_json) is Dictionary, "Greyfen telemetry snapshot did not round-trip as JSON")
		print("PROBE greyfen_snapshot_json bytes=%d" % greyfen_json.to_utf8_buffer().size())
	# Exercise the same physical bridge path that the browser stopped on. This
	# uses the real InputMap action and CharacterBody3D physics, not a transform
	# assignment or QA staging command.
	player.global_position = Vector3(0.0, 0.95, 12.5)
	player.velocity = Vector3.ZERO
	var greyfen_camera := game.get("camera_rig") as Node
	if greyfen_camera != null:
		greyfen_camera.set("yaw", 0.0)
		greyfen_camera.set("pitch", 0.30)
	var greyfen_cross_start := player.global_position
	Input.action_press("move_forward")
	await _physics_frames(200)
	Input.action_release("move_forward")
	await _physics_frames(4)
	var greyfen_cross_end := player.global_position
	print("PROBE greyfen_bridge_cross start=%s end=%s delta=%s floor=%s wall=%s" % [
		greyfen_cross_start, greyfen_cross_end, greyfen_cross_end - greyfen_cross_start,
		str(player.is_on_floor()), str(player.is_on_wall())
	])
	_print_slide_collisions("greyfen_bridge_cross", player)
	_assert(greyfen_cross_end.z < 3.0, "native Greyfen bridge crossing stopped before the south bank")
	if telemetry != null:
		var greyfen_cross_snapshot: Dictionary = telemetry.snapshot_for_game(game)
		var greyfen_cross_json := JSON.stringify(greyfen_cross_snapshot)
		_assert(JSON.parse_string(greyfen_cross_json) is Dictionary, "Greyfen post-crossing telemetry snapshot did not round-trip as JSON")
		print("PROBE greyfen_cross_snapshot_json bytes=%d" % greyfen_cross_json.to_utf8_buffer().size())
	# Exercise the same key-event state that the browser's raw movement path is
	# expected to feed into InputRouter. This is a native proof of the event
	# contract, without using a transform assignment or QA route command.
	player.global_position = Vector3(0.0, 0.95, 12.5)
	player.velocity = Vector3.ZERO
	_parse_key_event(KEY_W, true)
	await _physics_frames(200)
	_parse_key_event(KEY_W, false)
	await _physics_frames(4)
	var greyfen_key_event_end := player.global_position
	print("PROBE greyfen_key_event_cross end=%s delta=%s floor=%s wall=%s" % [
		greyfen_key_event_end, greyfen_key_event_end - greyfen_cross_start,
		str(player.is_on_floor()), str(player.is_on_wall())
	])
	_print_slide_collisions("greyfen_key_event_cross", player)
	_assert(greyfen_key_event_end.z < 3.0, "native InputEventKey bridge crossing stopped before the south bank")

	# Enter Wychwood through the normal builder so the probe sees the same
	# runtime collision tree as the reported browser route.
	game.call("_load_zone", "wychwood", Vector3(0.0, 0.95, 0.531))
	await _wait_for_player("wychwood", 1200)
	if player == null:
		_finish()
		return

	var start := Vector3(0.0, 0.95, 0.531)
	player.global_position = start
	player.velocity = Vector3.ZERO
	var camera := game.get("camera_rig") as Node
	if camera != null:
		camera.set("yaw", 0.0)
		camera.set("pitch", 0.30)
	var router := game.get("input_router") as Node
	if router != null and router.has_method("set_gameplay_context"):
		router.set_gameplay_context()
	await _physics_frames(3)

	print("PROBE route_start zone=%s position=%s can_control=%s locked=%s input_context=%s" % [
		str(game.get("current_zone_id")), player.global_position,
		str(player.get("can_control")), str(player.get("transition_locked")),
		str(router.get("input_context") if router != null else "none")
	])
	var spatial = game.get("spatial_service")
	_assert(spatial != null, "native route probe has no spatial service")
	if spatial != null:
		var route_started := Time.get_ticks_usec()
		var corpse_route: Array[Vector3] = spatial.build_route(player.global_position, Vector3(-0.9, 0.0, 9.0), 0.55)
		print("PROBE corpse_route elapsed_ms=%.2f points=%d route=%s" % [
			float(Time.get_ticks_usec() - route_started) / 1000.0,
			corpse_route.size(), corpse_route
		])
		_assert(not corpse_route.is_empty(), "native corpse route was empty")
	var corpse: Area3D
	var next_clue: Area3D
	var cached_interactions: Array = game.get("interaction_area_cache")
	for candidate in cached_interactions:
		if candidate is Area3D and is_instance_valid(candidate) and str(candidate.get("interaction_id")) == "corpse":
			corpse = candidate
		if candidate is Area3D and is_instance_valid(candidate) and str(candidate.get("interaction_id")) == "black_feathers":
			next_clue = candidate
	_assert(telemetry != null and corpse != null and next_clue != null, "native post-clue route fixture unavailable")
	if telemetry != null and corpse != null and next_clue != null:
		var original_candidates: Array = game.get("interaction_candidates").duplicate()
		# Exercise the exact post-clue path reported by the browser: the real corpse
		# handler queues its Area3D, then the next frame publishes telemetry and a
		# route request for the next clue after deferred deletion has settled.
		game.set("interaction_candidates", [corpse])
		game.set("active_interactable", corpse)
		game.call("_handle_interaction", corpse)
		await _frames(1)
		var post_interaction_snapshot: Dictionary = telemetry.snapshot_for_game(game)
		var post_candidates: Array = post_interaction_snapshot.get("focus_candidates", [])
		var corpse_valid := is_instance_valid(corpse) and not corpse.is_queued_for_deletion() and corpse.is_inside_tree()
		print("PROBE post_clue corpse_valid=%s cache_count=%d candidates=%d focus_candidates=%d" % [
			str(corpse_valid), (game.get("interaction_area_cache") as Array).size(),
			(game.get("interaction_candidates") as Array).size(), post_candidates.size()
		])
		_assert(not corpse_valid, "corpse remained valid after deferred interaction deletion")
		_assert(post_candidates.is_empty(), "interacted corpse leaked into telemetry focus candidates")
		var spatial_after_clue = game.get("spatial_service")
		_assert(spatial_after_clue != null, "post-clue spatial service unavailable")
		var route_started := Time.get_ticks_usec()
		var next_route: Array[Vector3] = spatial_after_clue.build_route(player.global_position, next_clue.global_position, 0.55) if spatial_after_clue != null else []
		print("PROBE post_clue_route target=black_feathers elapsed_ms=%.2f points=%d route=%s" % [
			float(Time.get_ticks_usec() - route_started) / 1000.0, next_route.size(), next_route
		])
		_assert(not next_route.is_empty(), "post-clue route to black_feathers was empty")
		var post_json := JSON.stringify(post_interaction_snapshot)
		_assert(JSON.parse_string(post_json) is Dictionary, "post-clue telemetry snapshot did not round-trip as JSON")
		print("PROBE post_clue_snapshot_json bytes=%d" % post_json.to_utf8_buffer().size())
		game.set("interaction_candidates", original_candidates)
		root.remove_child(telemetry)
		telemetry.free()
	_print_corridor_owners(start, -8.5, 0.25)

	var forward_start := player.global_position
	Input.action_press("move_forward")
	await _physics_frames(240)
	Input.action_release("move_forward")
	await _physics_frames(4)
	var forward_end := player.global_position
	print("PROBE forward_result start=%s end=%s delta=%s velocity=%s floor=%s wall=%s" % [
		forward_start, forward_end, forward_end - forward_start,
		player.velocity, str(player.is_on_floor()), str(player.is_on_wall())
	])
	_print_slide_collisions("forward", player)

	var backward_start := player.global_position
	Input.action_press("move_back")
	await _physics_frames(180)
	Input.action_release("move_back")
	await _physics_frames(4)
	var backward_end := player.global_position
	print("PROBE backward_result start=%s end=%s delta=%s velocity=%s floor=%s wall=%s" % [
		backward_start, backward_end, backward_end - backward_start,
		player.velocity, str(player.is_on_floor()), str(player.is_on_wall())
	])
	_print_slide_collisions("backward", player)

	if forward_end.z > -5.3:
		failures.append("native forward route stopped before clearing: z=%.3f" % forward_end.z)
	if backward_end.z < forward_end.z + 1.0:
		failures.append("native backward route did not return along the corridor: z=%.3f" % backward_end.z)

	if failures.is_empty():
		print("WYCHWOOD PLAYER ROUTE PROBE: PASS")
	else:
		print("WYCHWOOD PLAYER ROUTE PROBE: FAIL")
		for failure in failures:
			print("- %s" % failure)
	_finish()

func _wait_for_player(zone: String, max_frames: int) -> void:
	for _i in range(max_frames):
		await process_frame
		var candidate := game.get("player") as CharacterBody3D
		if candidate != null and str(game.get("current_zone_id")) == zone:
			player = candidate
			if not bool(player.get("transition_locked")) and bool(player.get("can_control")):
				return
	_assert(false, "timed out waiting for playable %s" % zone)

func _print_corridor_owners(start: Vector3, end_z: float, step: float) -> void:
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.65
	capsule.radius = 0.32
	var seen: Dictionary = {}
	var z := start.z
	while z >= end_z:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.transform = Transform3D(Basis.IDENTITY, Vector3(start.x, 0.90, z))
		query.collision_mask = 0xFFFFFFFF
		query.collide_with_bodies = true
		query.collide_with_areas = false
		query.exclude = [player.get_rid()]
		var hits: Array[Dictionary] = space.intersect_shape(query, 32)
		var owners: Array[String] = []
		for hit in hits:
			var collider := hit.get("collider") as Node
			if collider == null:
				continue
			var path := str(collider.get_path())
			if not seen.has(path):
				seen[path] = true
			owners.append("%s <%s>" % [path, collider.get_class()])
		if not owners.is_empty():
			print("PROBE corridor z=%.2f owners=%s" % [z, "; ".join(owners)])
		z -= step
	print("PROBE corridor_unique_owners count=%d" % seen.size())

func _print_slide_collisions(label: String, body: CharacterBody3D) -> void:
	var values: Array[String] = []
	for index in body.get_slide_collision_count():
		var collision := body.get_slide_collision(index)
		var collider := collision.get_collider() as Node
		values.append("%s normal=%s travel=%s" % [
			str(collider.get_path()) if collider != null else "unknown",
			collision.get_normal(), collision.get_travel()
		])
	print("PROBE %s_slide_collisions count=%d %s" % [label, values.size(), "; ".join(values)])

func _parse_key_event(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.unicode = keycode
	event.pressed = pressed
	event.echo = false
	Input.parse_input_event(event)

func _frames(count: int) -> void:
	for _i in range(count):
		await process_frame

func _physics_frames(count: int) -> void:
	for _i in range(count):
		await physics_frame

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		print("PROBE ASSERT: %s" % message)

func _finish() -> void:
	Input.action_release("move_forward")
	Input.action_release("move_back")
	if is_instance_valid(game):
		if game.has_method("finalize_resource_shutdown"):
			game.call("finalize_resource_shutdown")
		await _frames(8)
		if game.is_inside_tree():
			root.remove_child(game)
		if is_instance_valid(game):
			game.free()
	await _frames(2)
	quit(1 if not failures.is_empty() else 0)
