extends SceneTree

const WorldSectorManifest = preload("res://scripts/world_sector_manifest.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	_check(scene != null, "main scene is missing")
	if scene == null:
		quit(1)
		return
	var game := scene.instantiate()
	root.add_child(game)
	await _frames(4)
	game.call("_new_game")
	await _wait_for_zone(game, "greyfen")
	_check(game.seamless_world != null, "seam service was not installed")
	_check(game.current_zone_id == "greyfen", "New Game did not start in Greyfen")

	var outward := [
		["greyfen", "north", "wychwood"],
		["wychwood", "north", "deep_wood"],
		["deep_wood", "north", "old_mill"],
		["old_mill", "north", "burned_farmstead"],
		["burned_farmstead", "north", "marsh_crossing"],
		["marsh_crossing", "north", "bandit_road"],
		["bandit_road", "east", "vargan_approach"],
		["vargan_approach", "south", "greyfen"],
	]
	for route in outward:
		await _cross_boundary(game, str(route[0]), str(route[1]), str(route[2]))

	var return_route := [
		["greyfen", "east", "vargan_approach"],
		["vargan_approach", "west", "bandit_road"],
		["bandit_road", "south", "marsh_crossing"],
		["marsh_crossing", "south", "burned_farmstead"],
		["burned_farmstead", "south", "old_mill"],
		["old_mill", "south", "deep_wood"],
		["deep_wood", "south", "wychwood"],
		["wychwood", "south", "greyfen"],
	]
	for route in return_route:
		await _cross_boundary(game, str(route[0]), str(route[1]), str(route[2]))

	_check(game.seamless_world.transition_count >= 16, "complete exterior circuit did not use the seam service")
	_check(not game.hud.loading_layer.visible, "seam travel exposed the full-screen loading layer")
	_check(game.player.global_position.y >= 0.85, "final arrival is not grounded")
	_check(game.spatial_service != null, "final arrival has no spatial recovery service")
	game.call("_load_zone", "vargan_approach", Vector3(0, 0.95, 11.0))
	await _wait_for_zone(game, "vargan_approach")
	var door: Node = game.zone_root.find_child("InteriorDoorFrame", true, false)
	_check(door != null, "Vargan Approach has no physical interior door frame")
	var court_gate: Node = game.zone_root.find_child("gate_vargan_court", true, false)
	_check(court_gate != null and bool(court_gate.get_meta("interior_door", false)), "Castle courtyard gate is not marked as a physical door")
	_check(game.zone_root.find_children("*", "OathGatePortal", true, false).is_empty(), "Castle courtyard door still uses an exterior portal")

	if game.has_method("prepare_resource_shutdown"):
		game.prepare_resource_shutdown()
	await _frames(int(game.ZONE_RETIRE_FRAMES) + 6)
	if game.has_method("finalize_resource_shutdown"):
		game.finalize_resource_shutdown()
	await _frames(4)
	game.queue_free()
	await _frames(24)
	if is_instance_valid(game):
		game.free()
	await _frames(2)
	RenderingServer.force_sync()
	if failures.is_empty():
		print("SEAM-QA-001 VERIFIER: PASS (real boundary circuit, no portal/loading overlay, safe arrivals)")
	else:
		for failure in failures:
			push_error(failure)
		print("SEAM-QA-001 VERIFIER: FAIL (%d)" % failures.size())
	quit(0 if failures.is_empty() else 1)

func _cross_boundary(game: Node, source: String, edge_id: String, target: String) -> void:
	if game.current_zone_id != source:
		_check(false, "%s route started in %s instead of %s" % [edge_id, game.current_zone_id, source])
		return
	var edge: Dictionary = WorldSectorManifest.open_edges(source).get(edge_id, {})
	_check(not edge.is_empty(), "%s has no %s edge" % [source, edge_id])
	if edge.is_empty():
		return
	var half: Vector2 = game.get_zone_half_extents(source)
	var lane := float(edge.get("lane", 0.0))
	var position := Vector3(lane, 0.95, 0.0)
	match edge_id:
		"north": position = Vector3(lane, 0.95, -half.y + 0.30)
		"south": position = Vector3(lane, 0.95, half.y - 0.30)
		"west": position = Vector3(-half.x + 0.30, 0.95, lane)
		"east": position = Vector3(half.x - 0.30, 0.95, lane)
	game.player.global_position = position
	game.player.velocity = Vector3.ZERO
	game.call("_process", 0.25)
	await _wait_for_zone(game, target)
	_check(game.current_zone_id == target, "%s -> %s did not activate" % [source, target])
	_check(not game.zone_transition_pending, "%s -> %s left a transition lock" % [source, target])
	_check(not game.hud.loading_layer.visible, "%s -> %s showed a loading overlay" % [source, target])
	_check(game.player.global_position.y >= 0.85, "%s -> %s arrival is not grounded" % [source, target])
	_check(game.zone_root.find_children("*", "OathGatePortal", true, false).is_empty(), "%s -> %s retained a portal node" % [source, target])

func _wait_for_zone(game: Node, zone_id: String) -> void:
	for _index in range(420):
		await process_frame
		if game.current_zone_id == zone_id and not game.zone_transition_pending:
			return
	_check(false, "timed out waiting for %s" % zone_id)

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
