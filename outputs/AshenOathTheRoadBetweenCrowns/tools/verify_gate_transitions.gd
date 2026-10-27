extends SceneTree

const WorldSectorManifest = preload("res://scripts/world_sector_manifest.gd")
const WAYPOINT_TIMEOUT_MS := 12000
const WAYPOINT_FRAME_LIMIT := 720

var failures := 0
var aborted := false

func _initialize() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	check(scene != null, "Main scene is unavailable")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	_verify_reciprocal_arrival_lanes()
	await _settle(6)
	if game.hud != null and str(game.hud.get("active_menu")) == "launch":
		if game.hud.has_method("restore_input_focus"):
			game.hud.restore_input_focus()
		await _send_action("ui_accept")
		await _settle(4)
	if game.hud != null and game.hud.has_method("restore_input_focus"):
		game.hud.restore_input_focus()
	await _wait_for_opening_ready(game)
	var new_game_started := Time.get_ticks_msec()
	game.hud.new_game_requested.emit()
	await wait_for_zone(game, "greyfen")
	var click_to_play_ms := Time.get_ticks_msec() - new_game_started
	if DisplayServer.get_name().to_lower() != "headless":
		check(click_to_play_ms < 1500, "Prewarmed New Game exceeded 1500 ms: %d ms" % click_to_play_ms)
	print("NEW GAME HANDOFF: %d ms (headless is not rendered startup certification)" % click_to_play_ms)
	var route := [
		"deep_wood", "old_mill", "burned_farmstead", "marsh_crossing", "bandit_road",
		"vargan_approach", "vargan_court", "record_hall", "vargan_court", "vargan_approach",
		"bandit_road", "marsh_crossing", "burned_farmstead", "old_mill", "deep_wood",
		"wychwood", "greyfen", "vargan_approach", "vargan_court", "vargan_approach"
	]
	if "--castle-return-only" in OS.get_cmdline_user_args():
		route = ["vargan_approach", "vargan_court", "vargan_approach"]
		print("GATE SCOPE: targeted Greyfen/Castle immediate-return recheck, not the full route")
	for target in route:
		if aborted:
			break
		await use_gate(game, str(target))
	if not aborted:
		check(not game.zone_transition_pending, "Final gate left the loading state active")
		check(game.player != null and game.player.can_control, "Final gate did not restore player control")
	print("GATE TRANSITION VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	print("VERIFIER_PHASE: SHUTDOWN")
	# The route builds and retires enough sectors that synchronous destruction of
	# the whole game tree can block the verifier after a valid pass. Use the
	# runtime's staged finalizer, then let SceneTree process the queued owner.
	if game.has_method("finalize_resource_shutdown"):
		game.finalize_resource_shutdown()
	elif game.has_method("prepare_resource_shutdown"):
		game.prepare_resource_shutdown()
	await _frames(game.ZONE_RETIRE_FRAMES + 8)
	# Remove the verifier-owned root explicitly after staged retirement. Queueing
	# the root and quitting eight frames later can leave service children and a
	# suspended RefCounted state in ObjectDB even though the route passed.
	if is_instance_valid(game):
		if game.is_inside_tree():
			root.remove_child(game)
		game.free()
	RenderingServer.force_sync()
	await _frames(60)
	RenderingServer.force_sync()
	quit(0 if failures == 0 else 1)

func _wait_for_opening_ready(game) -> void:
	# Prewarming is intentionally hidden behind the menu. Do not fold that cold
	# work into the warm New Game handoff measurement, but do keep a hard bound so
	# a stuck pack/build path cannot make this verifier wait forever.
	var started_ms := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started_ms <= 15000:
		var ready := game.hud != null and bool(game.hud.get("new_game_ready"))
		var cached: bool = game.route_zone_cache.has("greyfen")
		if ready and cached:
			return
		await process_frame
	check(false, "Greyfen did not become ready behind the menu within 15 seconds; menu=%s started=%s cached=%s" % [
		str(game.hud.get("active_menu")) if game.hud != null else "missing",
		str(game.game_started), str(game.route_zone_cache.has("greyfen")),
	])

func use_gate(game, target: String) -> void:
	var source := WorldSectorManifest.canonical(str(game.current_zone_id))
	var bounds := WorldSectorManifest.bounds(source)
	if absf(game.player.position.x) > bounds.x or absf(game.player.position.z) > bounds.y:
		# A continuous arrival is in the far half of the bent connector, not a
		# teleported interior spawn. Follow its centerline back into the sector
		# before asking the sector-local route service for an onward route.
		var entry: PackedVector3Array
		var entry_normal := Vector3.ZERO
		var nearest := INF
		for edge: Dictionary in WorldSectorManifest.connections(source):
			var points := WorldSectorManifest.connector_points(edge)
			var distance := Vector2(points[-1].x - game.player.position.x, points[-1].z - game.player.position.z).length()
			if distance < nearest:
				nearest = distance
				entry = points
				entry_normal = WorldSectorManifest.direction(str(edge.id))
		check(not entry.is_empty() and nearest < 4.0, "Arrival is not on an authored connector")
		if aborted: return
		for index in range(entry.size() - 2, -1, -1):
			if not await _walk_player_to(game, entry[index]): return
		if not await _walk_player_to(game, entry[0] - entry_normal * 4.0): return
		if source in ["deep_wood", "old_mill", "burned_farmstead", "marsh_crossing"]:
			if not await _walk_player_to(game, Vector3(0, 0, game.player.position.z)): return
	# Exterior sectors use the seamless-world boundary contract. Their former
	# Area3D markers remain in the scene for save compatibility, but are
	# intentionally non-interactable. Drive the player to the registered edge so
	# this release gate exercises the same route the shipped game uses.
	if game.seamless_world != null and not WorldSectorManifest.connection_between(source, target).is_empty():
		await use_seamless_boundary(game, source, target)
		return
	var gate = find_gate(game.zone_root, target)
	check(gate != null, "Missing real gate from %s to %s" % [game.current_zone_id, target])
	if gate == null:
		return
	var outward := Vector3(gate.global_position.x, 0.0, gate.global_position.z).normalized()
	if outward.length_squared() < 0.1:
		outward = Vector3.FORWARD
	var far_position: Vector3 = game.player.global_position
	var near_position: Vector3 = gate.global_position - outward * 1.7 + Vector3.UP * 0.95
	var gate_corridor_clear := _corridor_clear(game, far_position, near_position)
	check(gate_corridor_clear, "%s gate approach has a player-sized collision blocker" % target)
	if not gate_corridor_clear:
		return
	if not await _walk_player_to(game, near_position):
		return
	var toward_gate: Vector3 = gate.global_position - game.player.global_position
	toward_gate.y = 0.0
	game.camera_rig.yaw = atan2(-toward_gate.normalized().x, -toward_gate.normalized().z)
	await _settle(10)
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
	await _send_action("interact")
	await wait_for_zone(game, target)

func use_seamless_boundary(game, source: String, target: String) -> void:
	var edge := WorldSectorManifest.edge_between(source, target)
	var connection := WorldSectorManifest.connection_between(source, target)
	if not connection.is_empty():
		edge = connection
	check(not edge.is_empty(), "Missing manifest edge from %s to %s" % [source, target])
	if edge.is_empty():
		return
	var bounds := WorldSectorManifest.bounds(source)
	var outward := _edge_outward(str(edge.get("id", "")))
	var lane := float(edge.get("lane", 0.0))
	var edge_position := _edge_position(str(edge.get("id", "")), lane, bounds)
	var near_position := edge_position + Vector3.UP * 0.95
	if not connection.is_empty():
		near_position = WorldSectorManifest.connector_points(connection)[0] - outward * 4.0
	# Some authored sectors intentionally bend their road around clues, arena
	# dressing, or terrain. Audit the declared road legs instead of requiring an
	# empty diagonal across the whole zone.
	var approach_points: Array[Vector3] = []
	if source == "vargan_court":
		# The south service entrance runs west of the gatehouse and corner
		# tower. The direct diagonal is masonry, not the authored walking lane.
		if target == "record_hall":
			approach_points.append_array([Vector3(-12.8, 0, 13.8), Vector3(-12.8, 0, 7), Vector3(-4, 0, 7), Vector3(0, 0, 7)])
		elif target == "vargan_approach" and game.player.position.z < 12.8:
			approach_points.append_array([Vector3(-4, 0, 7), Vector3(-12.8, 0, 7), Vector3(-12.8, 0, 13.8)])
	if source in ["deep_wood", "old_mill", "burned_farmstead", "marsh_crossing"] and str(edge.id) in ["north", "south"]:
		approach_points.append(Vector3(0, 0, near_position.z))
	for raw_point in edge.get("approach", []):
		if raw_point is Array and raw_point.size() >= 3:
			approach_points.append(Vector3(float(raw_point[0]), float(raw_point[1]), float(raw_point[2])))
	approach_points.append(near_position)
	if not connection.is_empty():
		var connector := WorldSectorManifest.connector_points(connection)
		for point in connector:
			approach_points.append(point)
	for approach_point in approach_points:
		var seamless_corridor_clear := _corridor_clear(game, game.player.global_position, approach_point)
		check(seamless_corridor_clear, "%s seamless approach leg to %s has a player-sized collision blocker" % [target, approach_point])
		if not seamless_corridor_clear:
			return
		if not await _walk_player_to(game, approach_point):
			return
		if game.current_zone_id == target:
			await wait_for_zone(game, target)
			return
	var yaw := atan2(-outward.x, -outward.z)
	if game.camera_rig != null:
		_face_camera(game.camera_rig, yaw)
	# The player must reach and cross the sector edge through normal movement.
	_move_forward(true)
	var reached := false
	for _frame in range(150):
		await physics_frame
		await process_frame
		if game.current_zone_id == target:
			# Release on the first activated frame. Waiting for the next frame can
			# apply one more movement tick after the arrival has already reset the
			# player, which obscures a real transition result with test input.
			_move_forward(false)
			reached = true
			break
	_move_forward(false)
	Input.action_release("move_back")
	Input.action_release("move_left")
	Input.action_release("move_right")
	check(reached, "Player never crossed the %s seamless boundary" % target)
	if reached:
		# Let the destination's two-frame grounding handoff finish after the
		# movement action is released before checking arrival state.
		for _frame in range(3):
			await physics_frame
			await process_frame
		await wait_for_zone(game, target)

func _edge_outward(edge_id: String) -> Vector3:
	match edge_id:
		"north": return Vector3(0.0, 0.0, -1.0)
		"south": return Vector3(0.0, 0.0, 1.0)
		"west": return Vector3(-1.0, 0.0, 0.0)
		"east": return Vector3(1.0, 0.0, 0.0)
	return Vector3.FORWARD

func _edge_position(edge_id: String, lane: float, bounds: Vector2) -> Vector3:
	# Keep the test capsule inside the authored boundary wall. The old 0.25 m
	# inset placed the actor inside the wall's collision envelope at the same
	# time that the runtime edge detector already accepted a 0.85 m margin.
	var edge_clearance := 1.75
	match edge_id:
		"north": return Vector3(lane, 0.95, -bounds.y + edge_clearance)
		"south": return Vector3(lane, 0.95, bounds.y - edge_clearance)
		"west": return Vector3(-bounds.x + edge_clearance, 0.95, lane)
		"east": return Vector3(bounds.x - edge_clearance, 0.95, lane)
	return Vector3(lane, 0.95, 0.0)

func _verify_reciprocal_arrival_lanes() -> void:
	for source in WorldSectorManifest.all_ids():
		for source_edge_id in WorldSectorManifest.open_edges(str(source)).keys():
			var source_edge: Dictionary = WorldSectorManifest.open_edges(str(source)).get(source_edge_id, {})
			var target := WorldSectorManifest.canonical(str(source_edge.get("target", "")))
			var reciprocal := WorldSectorManifest.edge_between(target, str(source))
			if reciprocal.is_empty():
				continue
			var raw_arrival: Array = source_edge.get("arrival", [])
			check(raw_arrival.size() >= 3, "%s %s edge has no destination arrival" % [source, source_edge_id])
			if raw_arrival.size() < 3:
				continue
			var arrival := Vector3(float(raw_arrival[0]), float(raw_arrival[1]), float(raw_arrival[2]))
			var target_edge_id := str(reciprocal.get("id", ""))
			var target_lane := float(reciprocal.get("lane", 0.0))
			var raw_trigger: Array = reciprocal.get("trigger", [])
			if raw_trigger.size() >= 3:
				var trigger := Vector3(float(raw_trigger[0]), float(raw_trigger[1]), float(raw_trigger[2]))
				var trigger_radius := maxf(float(reciprocal.get("trigger_radius", 1.35)), 1.35)
				check(Vector2(arrival.x - trigger.x, arrival.z - trigger.z).length() > trigger_radius + 0.50, "%s to %s arrival overlaps target trigger" % [source, target])
			match target_edge_id:
				"north":
					check(absf(arrival.x - target_lane) < 0.05 and arrival.z < 0.0, "%s to %s arrival misses target north lane" % [source, target])
				"south":
					check(absf(arrival.x - target_lane) < 0.05 and arrival.z > 0.0, "%s to %s arrival misses target south lane" % [source, target])
				"west":
					check(absf(arrival.z - target_lane) < 0.05 and arrival.x < 0.0, "%s to %s arrival misses target west lane" % [source, target])
				"east":
					check(absf(arrival.z - target_lane) < 0.05 and arrival.x > 0.0, "%s to %s arrival misses target east lane" % [source, target])

func _corridor_clear(game: Node, start: Vector3, destination: Vector3) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.52
	shape.height = 1.78
	var route: Array = [start, destination]
	var connector_leg := _at_connector(game, start) and _at_connector(game, destination)
	if not connector_leg and game.spatial_service != null and game.spatial_service.has_method("build_route"):
		var built: Array = game.spatial_service.build_route(start, destination, 0.52)
		if built.is_empty():
			return false
		if Vector2(built.back().x - destination.x, built.back().z - destination.z).length() > 0.5:
			print("GATE ROUTE REDIRECT: start=%s requested=%s built=%s" % [start, destination, built])
			return false
		route = built
	for leg_index in range(route.size() - 1):
		var leg_start: Vector3 = route[leg_index]
		var leg_end: Vector3 = route[leg_index + 1]
		var distance := leg_start.distance_to(leg_end)
		var samples := maxi(3, ceili(distance / 0.35))
		for index in range(samples + 1):
			var point: Vector3 = leg_start.lerp(leg_end, float(index) / float(samples))
			point.y = 0.95
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = shape
			query.transform = Transform3D(Basis.IDENTITY, point)
			query.collision_mask = 1
			query.collide_with_areas = false
			query.collide_with_bodies = true
			query.exclude = [game.player.get_rid()]
			var hits: Array[Dictionary] = game.get_world_3d().direct_space_state.intersect_shape(query, 16)
			# A readiness leaf is an intentional dynamic barrier, not scenery.
			# The following real movement must still open/cross it normally; this
			# static corridor probe must not reject the cold route in advance.
			hits = hits.filter(func(hit: Dictionary):
				var body: Node = hit.get("collider")
				return body == null or not str(body.get_path()).contains("/TravelGate/")
			)
			if not hits.is_empty():
				print("GATE ROUTE: zone=%s start=%s requested=%s route=%s" % [game.current_zone_id, start, destination, route])
				var hit_names: Array[String] = []
				for hit in hits:
					var collider = hit.get("collider")
					if collider is Node:
						var detail := str(collider.get_path())
						var shape_index := int(hit.get("shape", -1))
						if shape_index >= 0 and collider is CollisionObject3D:
							var shapes: Array = collider.find_children("*", "CollisionShape3D", true, false)
							if shape_index < shapes.size():
								var shape_node := shapes[shape_index] as CollisionShape3D
								if shape_node != null:
									detail += " shape=%d local=%s" % [shape_index, str(shape_node.position)]
									if shape_node.shape is BoxShape3D:
										detail += " size=%s" % str((shape_node.shape as BoxShape3D).size)
						hit_names.append(detail)
					else:
						hit_names.append(str(hit.get("rid", "unknown")))
				print("GATE COLLISION: point=%s colliders=%s" % [point, ", ".join(hit_names)])
				return false
	return true

func find_gate(scope: Node, target: String):
	for node in scope.find_children("*", "Area3D", true, false):
		if str(node.get("interaction_type")) == "zone" and str(node.get("zone_target")) == target:
			return node
	return null

func wait_for_zone(game, target: String) -> void:
	if not await preload("res://tools/runtime_fixture.gd").ready(game, target):
		aborted = true
		check(false, "Destination did not become playable: " + target)
		return
	for _frame in range(90):
		if game.current_zone_id == target and not game.zone_transition_pending and game.player != null:
			check(game.player.global_position.y > -2.0, "%s arrival left Kael below the world" % target)
			check(absf(game.player.velocity.x) < 0.05 and absf(game.player.velocity.z) < 0.05, "%s arrival retained lateral velocity" % target)
			check(not game.hud.loading_layer.visible, "%s arrival left the loading overlay visible" % target)
			return
		await process_frame
	check(false, "%s did not become playable within 90 frames" % target)

func _walk_player_to(game, target: Vector3) -> bool:
	var start_zone := str(game.current_zone_id)
	var route: Array = [target]
	var connector_leg := _at_connector(game, game.player.global_position) and _at_connector(game, target)
	if not connector_leg and game.spatial_service != null and game.spatial_service.has_method("build_route"):
		var built: Array = game.spatial_service.build_route(game.player.global_position, target, 0.52)
		if not built.is_empty():
			if Vector2(built.back().x - target.x, built.back().z - target.z).length() > 0.5:
				check(false, "Route to %s redirected to %s" % [target, built.back()])
				return false
			route = built
	for raw_point in route:
		var point: Vector3 = raw_point
		point.y = 0.95
		var reached := false
		var waypoint_started := Time.get_ticks_msec()
		_move_forward(true)
		for _frame in range(WAYPOINT_FRAME_LIMIT):
			if str(game.current_zone_id) != start_zone:
				_move_forward(false)
				return true
			var delta: Vector3 = point - game.player.global_position
			delta.y = 0.0
			if delta.length() <= 0.85:
				reached = true
				break
			if game.camera_rig != null:
				_face_camera(game.camera_rig, atan2(-delta.normalized().x, -delta.normalized().z))
			if Time.get_ticks_msec() - waypoint_started > WAYPOINT_TIMEOUT_MS:
				break
			await physics_frame
			await process_frame
		_move_forward(false)
		if not reached:
			print("ROUTE STOP: position=%s velocity=%s control=%s input=%s context=%s yaw=%s" % [game.player.global_position, game.player.velocity, game.player.can_control, game.input_router.movement_vector(), game.input_router.input_context, game.camera_rig.yaw])
			check(false, "Player could not physically reach route waypoint %s" % str(point))
			return false
	_move_forward(false)
	var final_delta := Vector2(game.player.global_position.x - target.x, game.player.global_position.z - target.z).length()
	check(final_delta <= 0.85, "Player stopped %.2f m from requested waypoint %s" % [final_delta, target])
	return final_delta <= 0.85

func _send_action(action: String) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	await physics_frame
	await process_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)

func _move_forward(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_W
	event.physical_keycode = KEY_W
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _face_camera(camera: Node, heading: float) -> void:
	var turn := angle_difference(float(camera.yaw), heading)
	if absf(turn) > 0.0001:
		camera._apply_mouse_motion(Vector2(-turn / maxf(float(camera.sensitivity) * float(camera._bow_aim_sensitivity()), 0.0001), 0))

func _at_connector(game: Node, point: Vector3) -> bool:
	var zone := str(game.current_zone_id)
	if game.seamless_world != null and game.seamless_world.contains_resident_passage(point): return true
	if WorldSectorManifest.connector_contains(zone, point): return true
	for edge: Dictionary in WorldSectorManifest.connections(zone):
		var start := WorldSectorManifest.connector_points(edge)[0]
		if Vector2(point.x - start.x, point.z - start.z).length() <= 0.9: return true
	return false

func _settle(count: int) -> void:
	for _index in range(count):
		await physics_frame
		await process_frame

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		aborted = true
		push_error(message)
