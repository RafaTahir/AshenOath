extends SceneTree

var failures := 0

func _initialize() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	check(scene != null, "Main scene is unavailable")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_on_launch_accepted")
	await process_frame
	await process_frame
	var new_game_started := Time.get_ticks_msec()
	game.call("_new_game")
	await wait_for_zone(game, "greyfen")
	var click_to_play_ms := Time.get_ticks_msec() - new_game_started
	check(click_to_play_ms < 1500, "Prewarmed New Game exceeded 1500 ms: %d ms" % click_to_play_ms)
	print("NEW GAME CLICK-TO-PLAY: %d ms" % click_to_play_ms)
	await use_gate(game, "deep_wood")
	await use_gate(game, "old_mill")
	await use_gate(game, "burned_farmstead")
	await use_gate(game, "marsh_crossing")
	await use_gate(game, "bandit_road")
	await use_gate(game, "vargan_approach")
	await use_gate(game, "vargan_court")
	await use_gate(game, "record_hall")
	await use_gate(game, "vargan_court")
	await use_gate(game, "vargan_approach")
	await use_gate(game, "bandit_road")
	await use_gate(game, "marsh_crossing")
	await use_gate(game, "burned_farmstead")
	await use_gate(game, "old_mill")
	await use_gate(game, "deep_wood")
	await use_gate(game, "wychwood")
	await use_gate(game, "greyfen")
	await use_gate(game, "vargan_approach")
	await use_gate(game, "vargan_court")
	await use_gate(game, "vargan_approach")
	check(not game.zone_transition_pending, "Final gate left the loading state active")
	check(game.player != null and game.player.can_control, "Final gate did not restore player control")
	print("GATE TRANSITION VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	if game.has_method("prepare_resource_shutdown"):
		game.prepare_resource_shutdown()
	await _frames(game.ZONE_RETIRE_FRAMES + 4)
	game.free()
	await _frames(8)
	quit(0 if failures == 0 else 1)

func use_gate(game, target: String) -> void:
	var gate = find_gate(game.zone_root, target)
	check(gate != null, "Missing real gate from %s to %s" % [game.current_zone_id, target])
	if gate == null:
		return
	var outward := Vector3(gate.global_position.x, 0.0, gate.global_position.z).normalized()
	if outward.length_squared() < 0.1:
		outward = Vector3.FORWARD
	var far_position: Vector3 = gate.global_position - outward * 4.5 + Vector3.UP * 0.95
	var near_position: Vector3 = gate.global_position - outward * 1.7 + Vector3.UP * 0.95
	check(_corridor_clear(game, far_position, near_position), "%s gate approach has a player-sized collision blocker" % target)
	game.player.global_position = far_position
	game.player.velocity = Vector3.ZERO
	for step in range(1, 15):
		game.player.global_position = far_position.lerp(near_position, float(step) / 14.0)
		game.player.velocity = Vector3.ZERO
		await physics_frame
		await process_frame
	var toward_gate: Vector3 = gate.global_position - game.player.global_position
	toward_gate.y = 0.0
	game.camera_rig.yaw = atan2(-toward_gate.normalized().x, -toward_gate.normalized().z)
	for _frame in range(4):
		await physics_frame
		await process_frame
		game.call("_update_interaction_focus")
	if gate not in game.interaction_candidates:
		print("GATE DEBUG: target=%s player=%s gate=%s distance=%.2f overlaps=%s" % [
			target, game.player.global_position, gate.global_position,
			game.player.global_position.distance_to(gate.global_position),
			gate.get_overlapping_bodies(),
		])
	check(gate in game.interaction_candidates, "Player never entered the %s gate trigger" % target)
	check(game.active_interactable == gate, "Normal focus did not select the %s gate" % target)
	check(game.call("_interaction_target_valid", gate), "Gate %s failed normal line-of-sight validation" % target)
	if game.active_interactable != gate:
		return
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	game.call("_unhandled_input", event)
	await wait_for_zone(game, target)

func _corridor_clear(game: Node, start: Vector3, destination: Vector3) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.52
	shape.height = 1.78
	var distance := start.distance_to(destination)
	var samples := maxi(3, ceili(distance / 0.35))
	for index in range(samples + 1):
		var point := start.lerp(destination, float(index) / float(samples))
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis.IDENTITY, point)
		query.collision_mask = 1
		query.collide_with_areas = false
		query.collide_with_bodies = true
		query.exclude = [game.player.get_rid()]
		if not game.get_world_3d().direct_space_state.intersect_shape(query, 16).is_empty():
			return false
	return true

func find_gate(scope: Node, target: String):
	for node in scope.find_children("*", "Area3D", true, false):
		if str(node.get("interaction_type")) == "zone" and str(node.get("zone_target")) == target:
			return node
	return null

func wait_for_zone(game, target: String) -> void:
	for _frame in range(90):
		if game.current_zone_id == target and not game.zone_transition_pending and game.player != null:
			check(game.player.global_position.y > -2.0, "%s arrival left Kael below the world" % target)
			check(absf(game.player.velocity.x) < 0.05 and absf(game.player.velocity.z) < 0.05, "%s arrival retained lateral velocity" % target)
			check(not game.hud.loading_layer.visible, "%s arrival left the loading overlay visible" % target)
			return
		await process_frame
	check(false, "%s did not become playable within 90 frames" % target)

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
