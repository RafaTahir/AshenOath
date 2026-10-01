extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	_assert(scene != null, "Main scene is unavailable")
	if scene == null:
		_finish()
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.settings.set_quality_preset("balanced")
	game.call("_new_game")
	var deadline := Time.get_ticks_msec() + 45000
	while Time.get_ticks_msec() < deadline and (not game.game_started or game.zone_root == null or game.zone_transition_pending or not bool(game.zone_root.get_meta("opening_detail_complete", false))):
		await process_frame
	if not game.game_started or game.zone_root == null or game.zone_transition_pending or not bool(game.zone_root.get_meta("opening_detail_complete", false)):
		_assert(false, "Cemetery detail did not complete before its bounded contract check")
		await _finish(game)
		return
	game.quests.start_quest("side_widows_bell")
	# This builder contract needs the active Widow's Bell variant. Reload only
	# after startup completes, never concurrently with the queued New Game swap.
	game.call("_load_zone", "greyfen", Vector3(0, 0.9, 8))
	deadline = Time.get_ticks_msec() + 45000
	while Time.get_ticks_msec() < deadline and (game.zone_transition_pending or not _cemetery_complete(game)):
		await process_frame
	if game.zone_transition_pending or not _cemetery_complete(game):
		_assert(false, "Quest-specific cemetery construction did not complete")
		await _finish(game)
		return
	_assert(game.current_zone_id == "greyfen", "Greyfen did not load")
	_assert(game.call("_visual_role_for_interactable", "widow_elna") == "villager_female_human", "Elna's actor role must use the accepted female family, not the male hooded crowd role")
	var layer: Node = game.zone_root.find_child("CemeteryAuthoredPresentation", true, false)
	_assert(layer != null, "WORLD-014 cemetery presentation layer is missing")
	if layer != null:
		_assert(str(layer.get_meta("ticket", "")) == "WORLD-014", "WORLD-014 ticket metadata is missing")
		_assert(bool(layer.get_meta("bell_stateful", false)), "Bell state contract is missing")
		_assert(bool(layer.get_meta("chapel_stateful", false)), "Chapel state contract is missing")
		_assert(bool(layer.get_meta("crow_shrine_consequence", false)), "Crow Shrine consequence contract is missing")
	_assert(game.zone_root.find_child("CemeteryBellHouseHood", true, false) != null, "Bell house hood is missing")
	_assert(game.zone_root.find_child("CemeteryBellClapper", true, false) != null, "Bell clapper is missing")
	_assert(game.zone_root.find_child("CrowChapelMemoryWindow", true, false) != null, "Chapel focal window is missing")
	var architecture := game.zone_root.find_child("CrowChapelAuthoredArchitecture", true, false) as MeshInstance3D
	_assert(architecture != null, "Fitted chapel architecture is missing")
	if architecture != null:
		_assert(architecture.mesh is ArrayMesh and architecture.mesh.get_surface_count() == 3 and architecture.mesh.get_faces().size() / 3 == 2900, "Fitted chapel mesh is incomplete")
		for surface_index in architecture.mesh.get_surface_count():
			_assert(architecture.mesh.surface_get_material(surface_index) != null, "Fitted chapel material is missing")
	_assert(game.zone_root.find_child("CrowChapelImportedArch", true, false) == null and game.zone_root.find_child("CrowChapelPitchedRoof", true, false) == null, "Obsolete overlapping chapel shells were reintroduced")
	var fitted_bell := game.zone_root.find_child("CrowCemeteryBell", true, false) as MeshInstance3D
	_assert(fitted_bell != null and fitted_bell.mesh is ArrayMesh and fitted_bell.mesh.get_faces().size() / 3 == 432, "Hollow fitted cemetery bell is missing")
	var rows := game.zone_root.find_child("CemeteryFittedGraveRows", true, false) as MeshInstance3D
	_assert(rows != null and rows.mesh is ArrayMesh and rows.mesh.get_faces().size() / 3 == 216, "Grounded fitted grave rows are missing")
	_assert(game.zone_root.find_child("CemeteryGraveRowRhythm", true, false) != null, "Grave-row rhythm is missing")
	var headstones: Array[Node] = game.zone_root.find_children("CemeteryBeveledHeadstone_*", "MeshInstance3D", true, false)
	_assert(headstones.size() == 6, "Cemetery court must have six fitted headstones (found %d)" % headstones.size())
	for headstone in headstones:
		_assert(headstone.mesh is ArrayMesh and headstone.mesh.get_surface_count() == 1, "Cemetery headstone mesh is incomplete")
		_assert(headstone.material_override != null, "Cemetery headstone material is missing")
	_assert(game.zone_root.find_child("CrowShrineRoost", true, false) != null, "Crow Shrine roost is missing")
	_assert(game.zone_root.find_child("CemeteryStateAnchors", true, false) != null, "Cemetery state anchors are missing")
	for id in ["grave_bell", "grave_harl", "grave_child", "grave_soldier", "chapel_door"]:
		_assert(game.zone_root.find_child(id, true, false) != null, "Cemetery interaction is missing: %s" % id)
		var area: Node = game.zone_root.find_child(id, true, false)
		if area != null and id.begins_with("grave_"):
			_assert(area.get_node_or_null("CemeteryMemorialEvidence") != null, "Cemetery clue still uses a generic capsule: " + id)
	_assert(game.zone_root.find_child("CemeteryFittedBoundary", true, false) != null and game.zone_root.find_child("CemeteryFittedGraveEarth", true, false) != null, "Fitted courtyard soil or masonry is missing")
	for wall_id in ["CemeteryNorthWall", "CemeterySouthWall", "CemeteryEastWallNorth", "CemeteryEastWallSouth"]:
		var collision := game.zone_root.find_child(wall_id + "Collision", true, false) as CollisionShape3D
		var visual := game.zone_root.find_child(wall_id + "FittedVisual", true, false) as MeshInstance3D
		_assert((collision == null) == (visual == null), "Boundary art and reserved collision disagree: " + wall_id)
		if collision != null and visual != null:
			var bounds: AABB = visual.global_transform * visual.mesh.get_aabb()
			_assert(bounds.get_center().distance_to(collision.global_position) < 0.002 and bounds.size.distance_to(collision.shape.size) < 0.002, "River recovery separated boundary art/collision: " + wall_id)
	_assert(_route_clear(game.spatial_service, Vector3(8.8, 0.9, 8.0), Vector3(13.0, 0.9, 8.0)), "Cemetery entry route is obstructed")
	_assert(_route_clear(game.spatial_service, Vector3(13.0, 0.9, 8.0), Vector3(16.0, 0.9, 8.0)), "Grave-court route is obstructed")
	var nodes := _walk(game.zone_root).size()
	var meshes: int = game.zone_root.find_children("*", "MeshInstance3D", true, false).size()
	_assert(nodes <= 1150, "Greyfen cemetery route exceeds WORLD-014 node budget: %d" % nodes)
	_assert(meshes <= 340, "Greyfen cemetery route exceeds WORLD-014 mesh budget: %d" % meshes)
	print("WORLD-014 METRICS nodes=%d meshes=%d" % [nodes, meshes])
	await _finish(game)

func _route_clear(service, start: Vector3, destination: Vector3) -> bool:
	var route: Array = service.build_route(start, destination, 0.7)
	if route.is_empty():
		return false
	for index in range(1, route.size()):
		if not service.validate_segment(route[index - 1], route[index], 0.7):
			return false
	return true

func _cemetery_complete(game: Node) -> bool:
	if game.zone_root == null:
		return false
	var section: Node = game.zone_root.find_child("GreyfenCemeterySection", true, false)
	return section != null and bool(section.get_meta("cemetery_build_complete", false))

func _walk(node: Node) -> Array:
	var result: Array = [node]
	for child in node.get_children():
		result.append_array(_walk(child))
	return result

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _shutdown_game(game: Node) -> void:
	if is_instance_valid(game) and game.has_method("prepare_resource_shutdown"):
		game.prepare_resource_shutdown()
		await _frames(20)
	if is_instance_valid(game) and game.has_method("finalize_resource_shutdown"):
		game.finalize_resource_shutdown()
		await _frames(12)
	print("VERIFIER_PHASE: SHUTDOWN")
	if is_instance_valid(game):
		game.queue_free()
		await _frames(8)
	RenderingServer.force_sync()
	await _frames(4)

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)

func _finish(game = null) -> void:
	if failures.is_empty():
		print("WORLD-014 VERIFIER: PASS")
	else:
		print("WORLD-014 VERIFIER: FAIL (%d)" % failures.size())
		for failure in failures:
			print("- %s" % failure)
	await _shutdown_game(game)
	quit(0 if failures.is_empty() else 1)
