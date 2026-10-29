extends SceneTree

const WorldSectorManifest = preload("res://scripts/world_sector_manifest.gd")
const Fixture = preload("res://tools/runtime_fixture.gd")

class GateFacts extends RefCounted:
	var earned := false
	func is_unlocked(_id: String) -> bool: return earned
	func is_active(_id: String) -> bool: return earned
	func is_completed(_id: String) -> bool: return earned
	func is_objective_done(_quest: String, _objective: String) -> bool: return earned
	func get_flag(_id: String, _fallback: Variant = false) -> bool: return earned

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
	if "--support-contract-only" in OS.get_cmdline_user_args():
		await _support_contract()
		quit(0 if failures.is_empty() else 1)
		return
	if "--campaign-construction-only" in OS.get_cmdline_user_args():
		await _campaign_construction_contract()
		quit(0 if failures.is_empty() else 1)
		return
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
	if not await Fixture.start(game):
		_check(false,"Greyfen did not become playable")
	else:
		var observer = preload("res://scripts/production_observation_bridge.gd").new()
		game.add_child(observer)
		var route: Dictionary = observer.route_for_id(game, "gate_wychwood")
		_check(bool(route.get("physical_connection", false)) and bool(route.ok), "Read-only route did not follow the physical Greyfen/Wychwood connector")
		if not route.points.is_empty():
			_check(float(route.points.back().z) < -20.0 and absf(float(route.points.back().x) - 6.0) < 0.1, "Route stopped at the obsolete gate instead of the real dogleg")
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

func _campaign_construction_contract() -> void:
	var game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	if await Fixture.start(game):
		var service = game.seamless_world
		service.cancel_preparation()
		service._foreground = true
		paused = true
		for zone: String in ["deep_wood", "old_mill", "burned_farmstead", "marsh_crossing", "bandit_road", "vargan_approach", "vargan_court", "record_hall", "undercroft", "assembly", "hart_glade"]:
			var source_root: Node3D = game.zone_root
			var source_enemies: Array = game.active_enemies.duplicate()
			var source_spatial: Node = game.spatial_service
			var story_before: Dictionary = game.story_state.save_state().duplicate(true)
			service._begin_neighbor(zone)
			var deadline := Time.get_ticks_msec() + 30000
			while service._neighbor_scope != null and service._neighbor_state == "building" and Time.get_ticks_msec() < deadline:
				service._advance_preparation()
				_check(game.zone_root == source_root and game.spatial_service == source_spatial and game.active_enemies == source_enemies and game.current_zone_id == "greyfen" and not game.neighbor_building, "Prepared step leaked active-world ownership: %s/%d" % [zone, service._neighbor_step])
				if service._neighbor_scope == null: break
				await process_frame
			_check(service._neighbor_state == "ready", "Campaign preparation failed: %s %s" % [zone, service.preparation_snapshot()])
			_check(game.story_state.save_state() == story_before, "Unvisited prepared destination changed durable story: " + zone)
			var prepared_root: Node3D = service._neighbor_scope.owned_root if service._neighbor_scope != null else null
			service.cancel_preparation()
			await _frames(3)
			_check(not is_instance_valid(prepared_root), "Cancelled destination retained its scene tree: " + zone)
			print("CAMPAIGN CONSTRUCTION: %s ready/cancel checked" % zone)
		service._begin_neighbor("old_mill")
		service._advance_preparation()
		var partial: Node3D = service._neighbor_scope.owned_root if service._neighbor_scope != null else null
		service.cancel_preparation()
		await _frames(3)
		_check(not is_instance_valid(partial), "Partial preparation cancellation retained its root")
		service._foreground = false
		paused = false
	else:
		_check(false, "Greyfen did not become playable for construction checks")
	for failure: String in failures: push_error(failure)
	print("CAMPAIGN CONSTRUCTION CONTRACT: %s (construction/cancellation only; not route or story acceptance)" % ("PASS" if failures.is_empty() else "FAIL"))
	game.prepare_resource_shutdown()
	await _frames(int(game.ZONE_RETIRE_FRAMES) + 6)
	game.finalize_resource_shutdown()
	game.queue_free()
	await _frames(24)

func _support_contract() -> void:
	var game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	if not await Fixture.start(game):
		_check(false, "Greyfen did not become playable for support checks")
		await Fixture.shutdown(game)
		return
	game.seamless_world.cancel_preparation()
	game.seamless_world._foreground = true
	game.set_process(false)
	game.player.set_physics_process(false)
	var coordinator = game.zone_runtime_coordinator
	var source: Node3D = game.zone_root
	var source_spatial: Node = game.spatial_service
	var source_position: Vector3 = game.player.global_position
	var before: Dictionary = game.story_state.save_state().duplicate(true)
	# A neighboring/preview floor cannot certify the destination's support.
	var foreign := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(4, 1, 4)
	foreign.add_child(shape)
	game.add_child(foreign)
	foreign.position = Vector3(100, 0, 100)
	await physics_frame
	await process_frame
	_check(game._grounded_spawn_position(Vector3(100, 1, 100)) == null, "Foreign floor certified destination support")
	before = game.story_state.save_state().duplicate(true)
	coordinator.begin_transition("greyfen", "greyfen", source_position)
	coordinator._support_deadline_msec = Time.get_ticks_msec() + 2000
	game.pending_spawn_position = Vector3(100, 1, 100)
	game.zone_transition_pending = true
	game.zone_transition_frames = 0
	game.player.set_transition_locked(true)
	for index in 3: coordinator.advance_transition()
	_check(game.zone_transition_pending and game.player.transition_locked, "Unsupported arrival unlocked before recovery")
	_check(game.story_state.save_state() == before, "Unsupported arrival published story changes")
	coordinator.advance_transition()
	_check(not game.zone_transition_pending and not game.player.transition_locked and coordinator._arrival_recovered, "Supported nearest-safe recovery did not finish")
	_check(game._grounded_spawn_position(game.player.global_position) != null, "Nearest-safe recovery was not re-probed")
	foreign.queue_free()
	# Inject a missing destination without manufacturing any quest facts. The
	# real rollback owner must preserve the source tree, spatial owner and save.
	for same_zone: bool in [false, true]:
		var target := "greyfen" if same_zone else "wychwood"
		before = game.story_state.save_state().duplicate(true)
		coordinator.begin_transition(target, "greyfen", source_position)
		if same_zone:
			game.zone_residency.suspend_runtime(source)
			source.visible = false
			source.position.y = -1000
			source.process_mode = Node.PROCESS_MODE_DISABLED
		else:
			game._cache_route_zone("greyfen", source, game.active_enemies, game.active_zone_signature)
			game._cache_route_spatial_service("greyfen", source_spatial)
		game.zone_root = Node3D.new()
		game.zone_root.name = "UnsupportedDestination"
		game.add_child(game.zone_root)
		game.zone_root.set_meta("prepared_story_flags", {"unsupported_arrival_must_not_commit": true})
		game.zone_root.set_meta("arrival_support_pending", true)
		_check(game.save_manager._save_is_gated(game), "Unsupported destination allowed save capture")
		game.spatial_service = game.ZoneSpatialService.new()
		game.add_child(game.spatial_service)
		game.spatial_service.configure(target, game._river_center(target), game._zone_half_extents(target))
		game.current_zone_id = target
		game.pending_spawn_position = Vector3(100, 1, 100)
		game.player.set_transition_locked(true)
		game.zone_transition_pending = true
		game.zone_transition_frames = 3
		coordinator._support_deadline_msec = Time.get_ticks_msec() - 1
		coordinator.advance_transition()
		_check(game.zone_root == source and game.spatial_service == source_spatial and game.current_zone_id == "greyfen", "Failed destination lost its source: same_zone=%s" % same_zone)
		_check(game.player.transition_locked, "Rollback skipped source support confirmation")
		_check(game.save_manager._save_is_gated(game), "Unconfirmed source rollback allowed save capture")
		await physics_frame
		await process_frame
		coordinator.advance_transition()
		coordinator.advance_transition()
		_check(not game.zone_transition_pending and not game.player.transition_locked, "Source did not resume after confirmed support")
		_check(not bool(source.get_meta("arrival_support_pending", false)), "Confirmed source retained its save gate")
		_check(game.story_state.save_state() == before, "Failed destination committed story or arrival facts")
		_check(not source_spatial.is_queued_for_deletion(), "Rollback destroyed source spatial ownership")
	await _connector_support_contract(game)
	for failure: String in failures: push_error(failure)
	print("SEAM SUPPORT CONTRACT: %s (owned support, delayed/re-probed fallback, failed destination and same-zone rollback; isolated fixture, not earned journey)" % ("PASS" if failures.is_empty() else "FAIL"))
	await Fixture.shutdown(game)

func _connector_support_contract(game: Node) -> void:
	var pairs: Dictionary = {}
	var facts := GateFacts.new()
	for source: String in WorldSectorManifest.all_ids():
		if WorldSectorManifest.connections(source).is_empty(): continue
		var view := SubViewport.new()
		view.own_world_3d = true
		view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		root.add_child(view)
		var destination := Node3D.new()
		view.add_child(destination)
		var spatial: Node3D = game.ZoneSpatialService.new()
		destination.add_child(spatial)
		spatial.configure(source, game._river_center(source), game._zone_half_extents(source))
		var context := ZoneBuildContext.new(game, source)
		context.own(destination, spatial)
		_check(context.run_step(func(scope: ZoneBuildContext): preload("res://scripts/connected_route_geometry.gd").install(scope); return true), "Connector geometry construction failed: " + source)
		await physics_frame
		await process_frame
		for edge: Dictionary in WorldSectorManifest.connections(source):
			var target := str(edge.target)
			var key := "|".join([source, target] if source < target else [target, source])
			pairs[key] = true
			_check(not WorldSectorManifest.connection_between(target, source).is_empty(), "Missing reciprocal connector: " + key)
			facts.earned = false
			if edge.has("requires_flag") or edge.has("requires_objective") or edge.has("requires_unlocked_quest"):
				_check(not WorldSectorManifest.edge_available(edge, facts, facts), "Unmet gate was opened: %s -> %s" % [source, target])
			facts.earned = true
			_check(WorldSectorManifest.edge_available(edge, facts, facts), "Satisfied isolated gate stayed closed: %s -> %s" % [source, target])
			var points := WorldSectorManifest.connector_points(edge)
			for segment in range(points.size() - 1):
				var samples := maxi(1, ceili(points[segment].distance_to(points[segment + 1])))
				for step in range(samples + 1):
					# Probe inside the strip, not its zero-area triangle boundary.
					var fraction := clampf(float(step) / float(samples), 0.0001, 0.9999)
					var point := points[segment].lerp(points[segment + 1], fraction)
					var hit := SpatialSurfaceContract.support_hit(destination.get_world_3d().direct_space_state, point + Vector3.UP * 2, point + Vector3.DOWN * 2, [], destination)
					_check(not hit.is_empty(), "Unsupported connector strip: %s -> %s segment=%d sample=%d" % [source, target, segment, step])
		context.cancel()
		view.queue_free()
		await process_frame
	_check(pairs.size() == 14, "Expected all 14 physical connector pairs, got %d" % pairs.size())
	print("CONNECTOR SUPPORT: %d pairs checked in both directions (isolated geometry/gate contracts, not campaign traversal)" % pairs.size())

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
