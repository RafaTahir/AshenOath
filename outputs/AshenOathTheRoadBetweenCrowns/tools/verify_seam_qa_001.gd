extends SceneTree

const WorldSectorManifest = preload("res://scripts/world_sector_manifest.gd")

class ArrivalHost extends Node:
	var game_started := false
	var requests := 0
	func get_zone_half_extents(zone_id: String) -> Vector2:
		return WorldSectorManifest.bounds(zone_id)
	func request_seamless_boundary_transition(_zone: String, _arrival: Vector3, _edge: String) -> bool:
		requests += 1
		return true

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if "--connected-greyfen-only" in OS.get_cmdline_user_args():
		await _connected_greyfen_contract()
		quit(0 if failures.is_empty() else 1)
		return
	if "--arrival-contract-only" in OS.get_cmdline_user_args():
		await _arrival_contract()
		quit(0 if failures.is_empty() else 1)
		return
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
	var castle_bounds := Vector2(23.0, 19.0)
	_check(WorldSectorManifest.edge_for_position("vargan_approach", Vector3(-16.0, 0.9, 16.0), castle_bounds).is_empty(), "Castle arrival immediately triggers the return edge")
	_check(WorldSectorManifest.edge_for_position("vargan_approach", Vector3(-7.0, 0.9, 16.0), castle_bounds).is_empty(), "Castle inward approach triggers the return edge")
	_check(str(WorldSectorManifest.edge_for_position("vargan_approach", Vector3(-22.3, 0.9, 16.0), castle_bounds).get("target", "")) == "bandit_road", "Castle west boundary no longer permits the return route")

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

func _connected_greyfen_contract() -> void:
	var game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await _frames(4)
	game.call("_new_game")
	if not await _wait_connected_playable(game,"greyfen"):
		_check(false,"Greyfen did not become playable")
	else:
		for target: String in ["wychwood","deep_wood","vargan_approach"]:
			if not await _connected_crossing(game,"greyfen",target): break
			if not await _connected_crossing(game,target,"greyfen"): break
	for failure: String in failures: push_error(failure)
	print("CONNECTED GREYFEN: %s (%d failures; native collision/build check, not browser input proof)" % ["PASS" if failures.is_empty() else "FAIL",failures.size()])
	game.prepare_resource_shutdown()
	await _frames(int(game.ZONE_RETIRE_FRAMES)+6)
	game.finalize_resource_shutdown()
	game.queue_free()
	await _frames(24)

func _wait_connected_playable(game: Node, target: String) -> bool:
	var deadline := Time.get_ticks_msec()+180000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if game.current_zone_id == target and is_instance_valid(game.player) and game.player.can_control and not game.zone_transition_pending and not game.neighbor_crossing_pending and not game.neighbor_arrival_pending:
			if game.opening_scene_pending or bool(game.zone_root.get_meta("opening_scene_active",false)): continue
			return true
	return false

func _connected_crossing(game: Node, source: String, target: String) -> bool:
	var edge := WorldSectorManifest.connection_between(source,target)
	_check(not edge.is_empty(),"missing connection %s -> %s" % [source,target])
	if edge.is_empty(): return false
	var points := WorldSectorManifest.connector_points(edge)
	var normal := WorldSectorManifest.direction(str(edge.id))
	var warm: bool = game.seamless_world.has_prepared(target)
	var frame := WorldSectorManifest.crossing_frame(edge)
	points[-1] -= normal*(0.7 if warm else 1.45)
	for index in range(points.size()-1):
		var parameters := PhysicsTestMotionParameters3D.new()
		parameters.from = Transform3D(Basis.IDENTITY,points[index]+Vector3.UP*0.15)
		parameters.motion = points[index+1]-points[index]
		parameters.margin = 0.01
		parameters.max_collisions = 8
		var result := PhysicsTestMotionResult3D.new()
		if PhysicsServer3D.body_test_motion(game.player.get_rid(),parameters,result):
			for hit in result.get_collision_count():
				if absf(result.get_collision_normal(hit).y) < 0.5:
					_check(false,"blocked passage %s -> %s segment %d: %s" % [source,target,index,result.get_collider(hit)])
		var ray := PhysicsRayQueryParameters3D.create(points[index]+Vector3.UP*2.0,points[index]+Vector3.DOWN*2.0,1,[game.player.get_rid()])
		_check(not game.player.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"missing passage floor %s -> %s segment %d" % [source,target,index])
	# Fixture placement is explicit: sweep the real body first, then exercise
	# the crossing owner. This is not represented as an earned gameplay run.
	game.player.global_position = frame.origin+normal*(0.06 if warm else -1.15)+Vector3.UP*0.15
	game.player.velocity = normal*2.0
	game.seamless_world.cooldown = 0.0
	game.call("_process",0.25)
	var ready := await _wait_connected_playable(game,target)
	_check(ready,"connection did not become playable: %s -> %s (%s)" % [source,target,game.seamless_world.preparation_snapshot()])
	if not ready: return false
	_check(game.zone_root.has_node("ConnectedRoads/RoadTo_"+source),"missing return passage in "+target)
	_check(not game.player.transition_locked,"retained player lock in "+target)
	_check(game.player.global_position.y > -0.2,"unsupported arrival in "+target)
	print("CONNECTED CROSSING: %s -> %s ready=%s position=%s" % [source,target,ready,game.player.global_position])
	return true

func _arrival_contract() -> void:
	var count := 0
	for source in WorldSectorManifest.all_ids():
		for edge_id in WorldSectorManifest.open_edges(source):
			var edge: Dictionary = WorldSectorManifest.open_edges(source)[edge_id]
			var raw: Array = edge.arrival
			var arrival := Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
			var target := str(edge.target)
			_check(WorldSectorManifest.edge_for_position(target, arrival, WorldSectorManifest.bounds(target), 0.85).is_empty(),
				"%s/%s arrival immediately exits %s" % [source, edge_id, target])
			count += 1
	var host := ArrivalHost.new()
	var actor := Node3D.new()
	var service := preload("res://scripts/seamless_world_service.gd").new()
	root.add_child(host)
	root.add_child(actor)
	root.add_child(service)
	service.configure(host, null)
	for sign in [-1.0, 1.0]:
		host.requests = 0
		var old_arrival := Vector3(0, 0.9, 13 * sign)
		_check(not WorldSectorManifest.edge_for_position("marsh_crossing", old_arrival,
			WorldSectorManifest.bounds("marsh_crossing"), 0.85).is_empty(), "Old marsh bounce was not reproduced")
		actor.position = Vector3(0, 0.9, 11 * sign)
		service.on_zone_activated("marsh_crossing", actor.position)
		_check(not service.update_player(actor, "marsh_crossing", 1.0), "Stationary arrival re-crossed after cooldown")
		_check(host.requests == 0, "Arrival requested an unintended zone")
		_check(not WorldSectorManifest.edge_for_position("marsh_crossing", Vector3(0, 0, 14 * sign),
			WorldSectorManifest.bounds("marsh_crossing"), 0.85).is_empty(), "Legitimate marsh return exit was disabled")
		actor.position = old_arrival
		service.on_zone_activated("marsh_crossing", actor.position)
		_check(not service.update_player(actor, "marsh_crossing", 1.0), "Legacy saved arrival bounced after cooldown")
		actor.position = Vector3(0, 0.9, 11 * sign)
		_check(not service.update_player(actor, "marsh_crossing", 0.1), "Leaving the entry trigger caused a transition")
		actor.position = Vector3(0, 0.9, 14 * sign)
		_check(service.update_player(actor, "marsh_crossing", 0.1) and host.requests == 1,
			"Leaving and deliberately re-entering did not restore the return exit")
	service.queue_free()
	actor.queue_free()
	host.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("SEAM ARRIVAL CONTRACT: %s (%d edges; both marsh arrivals and return exits)" % ["PASS" if failures.is_empty() else "FAIL", count])

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
