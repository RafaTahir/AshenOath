extends SceneTree

var failures := 0

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("WORLD-013 requires graphical instance-transform verification; headless structural evidence is insufficient")
		quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_move_to_foreground()
	var scene := load("res://scenes/main.tscn") as PackedScene
	check(scene != null, "Main scene is unavailable")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.settings.set_quality_preset("balanced")
	game.call("_new_game")
	if not await _wait_for_zone(game, "greyfen"):
		await _shutdown(game)
		quit(1)
		return
	game.quests.start_quest("main_road_of_crows")
	game.call("_load_zone", "wychwood", Vector3(0, 1, 12.5))
	if not await _wait_for_zone(game, "wychwood"):
		await _shutdown(game)
		quit(1)
		return
	check(game.current_zone_id == "wychwood", "Wychwood did not load")
	var presentation: Node = game.zone_root.find_child("WychwoodAuthoredPresentation", true, false)
	check(presentation != null, "WORLD-013 presentation layer is missing")
	if presentation != null:
		check(str(presentation.get_meta("ticket", "")) == "WORLD-013", "WORLD-013 ticket metadata is missing")
		check(int(presentation.get_meta("canopy_layers", 0)) == 2, "Wychwood does not expose two canopy layers")
		check(bool(presentation.get_meta("combat_arena_authored", false)), "Wychwood combat arena is not authored")
	check(game.zone_root.find_child("WychwoodRootArchLintel", true, false) != null, "Wychwood route gate lacks root arch")
	var arch_root := game.zone_root.find_child("WychwoodRootArchLintel", true, false) as MeshInstance3D
	check(arch_root != null and arch_root.material_override is StandardMaterial3D and (arch_root.material_override as StandardMaterial3D).albedo_texture != null, "Wychwood route arch lacks textured timber")
	for arch_piece in game.zone_root.find_children("WychwoodRootArch*", "MeshInstance3D", true, false):
		check(is_equal_approx(arch_piece.visibility_range_begin, 2.8) and is_equal_approx(arch_piece.visibility_range_begin_margin, 0.5), "Wychwood root arch can occlude the near camera: %s" % arch_piece.name)
		if str(arch_piece.name).begins_with("WychwoodRootArchPost"):
			check(arch_piece.mesh is ArrayMesh and arch_piece.mesh.get_surface_count() == 2 and arch_piece.material_override == null, "Threshold tree lost its complete sourced bark/leaf surfaces")
			for point in arch_piece.mesh.get_faces():
				var local: Vector3 = arch_piece.transform * point
				check(absf(local.x) > 2.6, "Threshold tree visually invades the full-width route")
	var distant_batches: Array[Node] = game.zone_root.find_children("WychwoodDistantForest*", "MultiMeshInstance3D", true, false)
	var distant_count := 0
	check(distant_batches.size() == 2, "Distant forest lost its two approved tree silhouettes")
	for distant_node in distant_batches:
		var distant := distant_node as MultiMeshInstance3D
		check(distant.multimesh != null and distant.multimesh.mesh != null and distant.multimesh.mesh.get_surface_count() == 2, "Distant forest lost shared bark/leaf depth layers")
		if distant.multimesh == null or distant.multimesh.mesh == null:
			continue
		distant_count += distant.multimesh.instance_count
		for index in distant.multimesh.instance_count:
			var point: Vector3 = distant.multimesh.get_instance_transform(index) * Vector3(distant.multimesh.mesh.get_aabb().get_center().x, distant.multimesh.mesh.get_aabb().position.y, distant.multimesh.mesh.get_aabb().get_center().z)
			check(absf(point.x) > 22.0 or absf(point.z) > 17.0, "Distant forest enters playable space")
	check(distant_count == 32, "Distant forest changed the Balanced instance budget")
	for bank in game.zone_root.find_children("WychwoodForestBerm", "MeshInstance3D", true, false):
		var collider := bank.get_parent().get_child(0) as CollisionShape3D
		check(collider != null and collider.shape is BoxShape3D, "Forest boundary lost its authoritative collision")
		if collider != null:
			var size: Vector3 = collider.shape.size
			var bounds: AABB = bank.mesh.get_aabb()
			check(bounds.size.x <= size.x + 0.001 and bounds.size.z <= size.z + 0.001 and bounds.size.y <= size.y + 0.001, "Forest berm exceeds the original collision envelope")
	for canopy_name in ["WychwoodCanopyLower", "WychwoodCanopyUpper"]:
		var canopy := game.zone_root.find_child(canopy_name, true, false) as MultiMeshInstance3D
		check(canopy != null and canopy.multimesh != null and canopy.multimesh.mesh is ArrayMesh, "%s lacks imported foliage geometry" % canopy_name)
		if canopy != null and canopy.multimesh != null and canopy.multimesh.mesh != null:
			check(canopy.multimesh.instance_count <= 9, "%s exceeds the Balanced canopy budget" % canopy_name)
			check(canopy.multimesh.mesh.surface_get_material(0) != null, "%s lacks assigned foliage material" % canopy_name)
	for batch_name in ["WychwoodUnderstoryBatch", "WychwoodForestFloorDetail"]:
		var foliage_batch := game.zone_root.find_child(batch_name, true, false) as MultiMeshInstance3D
		check(foliage_batch != null and foliage_batch.multimesh != null and foliage_batch.multimesh.mesh is ArrayMesh, "%s lacks imported foliage geometry" % batch_name)
		if foliage_batch != null and foliage_batch.multimesh != null and foliage_batch.multimesh.mesh is ArrayMesh:
			check(foliage_batch.multimesh.mesh.surface_get_material(0) != null, "%s lacks foliage material" % batch_name)
	var route_bushes: Array[Node] = get_nodes_in_group("wychwood_route_bush_visual")
	check(route_bushes.size() == 12, "Wychwood route bush count changed: %d" % route_bushes.size())
	for bush in route_bushes:
		var visual := bush as MeshInstance3D
		check(visual != null and visual.mesh is ArrayMesh and visual.mesh.surface_get_material(0) != null, "Wychwood route bush uses proxy or unlit foliage")
	var path_edges: Array = game.zone_root.find_children("WychwoodPathFloorEdge*", "MeshInstance3D", true, false)
	check(path_edges.size() == 4, "Wychwood path needs four visual-only bank-side floor patches")
	for edge in path_edges:
		check(edge.mesh != null and edge.mesh.get_surface_count() == 1 and edge.material_override != null, "Wychwood path edge lacks rendered geometry or material")
	var path_rocks := game.zone_root.find_child("WychwoodPathRockBatch", true, false) as MeshInstance3D
	check(path_rocks != null and path_rocks.mesh is ArrayMesh and path_rocks.material_override is StandardMaterial3D and (path_rocks.material_override as StandardMaterial3D).albedo_texture != null, "Wychwood path rocks lack imported geometry or textured material")
	var integrated_ground: Array[Node] = game.zone_root.find_children("WychwoodIntegratedGround_*", "MeshInstance3D", true, false)
	check(integrated_ground.size() == 6, "Wychwood route, clearing, and layby must be authored into all six split-ground visuals")
	var path_color := 0.0
	var path_samples := 0
	var forest_color := 0.0
	var forest_samples := 0
	for ground in integrated_ground:
		var visual := ground as MeshInstance3D
		var material := visual.material_override as StandardMaterial3D
		check(visual.mesh is ArrayMesh and visual.mesh.get_surface_count() == 1, "Wychwood integrated ground lost its single textured surface")
		check(material != null and material.albedo_texture != null and material.vertex_color_use_as_albedo, "Wychwood integrated ground lost textured vertex coloration")
		if not visual.mesh is ArrayMesh:
			continue
		var arrays := visual.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		check(colors.size() == vertices.size() and colors.size() > 100, "Wychwood ground lost its authored road and forest samples")
		if colors.size() != vertices.size():
			continue
		var origin: Vector3 = visual.get_meta("split_ground_origin")
		for index in vertices.size():
			var world := vertices[index] + origin
			if world.z < 3.0 or world.z > 10.0:
				continue
			if absf(world.x) < 0.8:
				path_color += colors[index].r
				path_samples += 1
			elif absf(world.x) > 8.0:
				forest_color += colors[index].r
				forest_samples += 1
	check(path_samples > 20 and forest_samples > 20 and path_color / maxf(path_samples, 1) < forest_color / maxf(forest_samples, 1) - 0.15, "Wychwood ground does not carry a distinct blended route")
	check(game.zone_root.find_child("WychwoodWindingPath", true, false) == null and game.zone_root.find_child("WychwoodClearingMud", true, false) == null and game.zone_root.find_child("MudRoad", true, false) == null, "Wychwood still overlays pasted-on route or clearing slabs")
	var clearing_stones := game.zone_root.find_child("WychwoodClearingBoundaryStones", true, false) as MeshInstance3D
	check(clearing_stones != null and clearing_stones.mesh is ArrayMesh and clearing_stones.material_override is StandardMaterial3D and (clearing_stones.material_override as StandardMaterial3D).albedo_texture != null, "Clearing boundary reverted to primitive spheres")
	check(game.zone_root.find_child("BalancedWychwoodRoadDetail", true, false) == null, "Obsolete Wychwood road blobs returned")
	for id in ["corpse", "black_feathers", "oren_token", "claw_marks", "tracks"]:
		var area := game.zone_root.find_child(id, true, false) as Node3D
		var evidence := area.get_node_or_null("WychwoodInvestigationEvidence") as MeshInstance3D if area != null else null
		check(evidence != null and evidence.mesh is ArrayMesh, "Wychwood clue still uses a generic marker: " + id)
		if evidence != null:
			check(evidence.get_meta("clue_identity", "") == id and evidence.position.y >= 0.057, "Clue identity/support mismatch: " + id)
			check(area.find_children("*", "Skeleton3D", true, false).is_empty(), "Static clue retained a live skeleton: " + id)
	var sightlines: Node = game.zone_root.find_child("WychwoodClueSightlines", true, false)
	check(sightlines != null and sightlines.get_child_count() == 5, "Wychwood clue sightlines are incomplete")
	check(game.zone_root.find_child("WychwoodCombatClearingFrame", true, false) != null, "Combat clearing frame is missing")
	check(game.zone_root.find_child("WychwoodMemoryLandmark", true, false) != null, "Memory landmark is missing")
	check(game.zone_root.find_child("WychwoodMemoryWitnessTree", true, false) != null, "Imported memory-witness tree is missing")
	check(game.zone_root.find_children("WychwoodClearingAshStain*", "MeshInstance3D", true, false).size() == 3, "Clearing must retain three irregular ash stains")
	check(_route_clear(game.spatial_service, Vector3(0, 0.9, 12.5), Vector3(0, 0.9, -2.5)), "Authored route to clues is obstructed")
	check(_route_clear(game.spatial_service, Vector3(0, 0.9, -2.5), Vector3(0, 0.9, -9.5)), "Authored route to clearing is obstructed")
	check(_route_clear(game.spatial_service, Vector3(0, 0.9, -9.5), Vector3(0, 0.9, 12.5)), "Authored return route is obstructed")
	var nodes := _walk(game.zone_root).size()
	var meshes: int = game.zone_root.find_children("*", "MeshInstance3D", true, false).size()
	var multimeshes: int = game.zone_root.find_children("*", "MultiMeshInstance3D", true, false).size()
	var secondary_trees := game.zone_root.find_child("AuthoredTreeBatch_forest_tree_secondary", true, false) as MultiMeshInstance3D
	var twisted_trees := game.zone_root.find_child("AuthoredTreeBatch_forest_tree_variant", true, false) as MultiMeshInstance3D
	check(secondary_trees != null and secondary_trees.multimesh != null and secondary_trees.multimesh.instance_count > 0, "Wychwood secondary tree asset was not batched")
	check(twisted_trees != null and twisted_trees.multimesh != null and twisted_trees.multimesh.instance_count > 0, "Wychwood twisted landmark trees were lost")
	if twisted_trees != null and twisted_trees.multimesh != null:
		var tree_mesh := twisted_trees.multimesh.mesh
		check(tree_mesh != null and tree_mesh.get_surface_count() == 2, "Twisted trees lost separate bark and leaf surfaces")
		check(twisted_trees.material_override == null, "Tree batch override hides bark and leaf materials")
		if tree_mesh != null and tree_mesh.get_surface_count() == 2:
			check(tree_mesh.surface_get_name(0).begins_with("Bark_") and tree_mesh.surface_get_name(1).begins_with("Leaves_"), "Tree surfaces no longer match bark and leaves")
			check(tree_mesh.surface_get_material(0) != null and tree_mesh.surface_get_material(1) != null, "Tree surfaces are missing authored materials")
			var bark := tree_mesh.surface_get_material(0) as StandardMaterial3D
			var leaves := tree_mesh.surface_get_material(1) as StandardMaterial3D
			check(bark != null and leaves != null and bark.albedo_color != leaves.albedo_color and bark.roughness >= 0.8 and leaves.roughness >= 0.8, "Tree bark and leaves lost distinct matte treatments")
	check(game.zone_root.find_child("TreeTrunkBatch", true, false) == null and game.zone_root.find_child("TreeCrownBatch", true, false) == null, "Wychwood fell back to primitive tree batches")
	check(nodes <= 1450, "Wychwood exceeds WORLD-013 node budget: %d" % nodes)
	check(meshes <= 440, "Wychwood exceeds WORLD-013 mesh budget: %d" % meshes)
	check(multimeshes <= 20, "Wychwood exceeds WORLD-013 batch budget: %d" % multimeshes)
	print("WORLD-013 METRICS nodes=%d meshes=%d multimeshes=%d" % [nodes, meshes, multimeshes])
	print("WORLD-013 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	await _shutdown(game)
	quit(0 if failures == 0 else 1)

func _wait_for_zone(game: Node, id: String) -> bool:
	var deadline := Time.get_ticks_msec() + 45000
	while Time.get_ticks_msec() < deadline:
		var complete := id != "greyfen" or (game.zone_root != null and bool(game.zone_root.get_meta("opening_detail_complete", false)))
		if game.game_started and game.current_zone_id == id and not game.zone_transition_pending and not game.zone_load_request_pending and complete:
			return true
		await process_frame
	check(false, "Bounded complete Wychwood integration startup failed: " + id)
	return false

func _shutdown(game: Node) -> void:
	game.prepare_resource_shutdown()
	await _frames(int(game.ZONE_RETIRE_FRAMES) + 4)
	game.finalize_resource_shutdown()
	await _frames(12)
	print("VERIFIER_PHASE: SHUTDOWN")
	game.queue_free()
	await _frames(8)
	RenderingServer.force_sync()

func _route_clear(service, start: Vector3, destination: Vector3) -> bool:
	var route: Array = service.build_route(start, destination, 0.7)
	if route.is_empty():
		return false
	for index in range(1, route.size()):
		if not service.validate_segment(route[index - 1], route[index], 0.7):
			return false
	return true

func _walk(node: Node) -> Array:
	var result: Array = [node]
	for child in node.get_children():
		result.append_array(_walk(child))
	return result

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
