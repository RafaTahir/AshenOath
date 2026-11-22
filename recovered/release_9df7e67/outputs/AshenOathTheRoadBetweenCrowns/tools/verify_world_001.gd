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
	game.settings.set_quality_preset("balanced")
	game.call("_new_game")
	await _frames(10)
	var detail_deadline := Time.get_ticks_msec() + 30000
	while game.opening_detail_pending and Time.get_ticks_msec() < detail_deadline:
		await process_frame
	check(not game.opening_detail_pending, "Greyfen deferred detail did not finish within 30 seconds")

	check(game.current_zone_id == "greyfen", "New Game did not open Greyfen")
	var section: Node = game.zone_root.find_child("AuthoredGreyfenSection", true, false)
	check(section != null and str(section.get_meta("ticket", "")) == "WORLD-001", "Authored Greyfen section ownership is missing")
	check(game.zone_root.find_child("DeterministicNavigationRegion", true, false) is NavigationRegion3D, "Greyfen navigation region was lost")
	check(_group_count(game.zone_root, "greyfen_house") == 4, "Greyfen must contain four authored route houses")
	var authored_houses := 0
	var variants: Dictionary = {}
	for house in game.zone_root.find_children("*", "Node3D", true, false):
		if not house.is_in_group("greyfen_house"):
			continue
		authored_houses += 1
		var variant := int(house.get_meta("house_variant", -1))
		variants[variant] = true
		check(variant >= 0 and variant <= 3, "%s has no authored variant" % house.name)
		check(str(house.get_meta("roof_treatment", "")) == "authored_mesh", "%s lost its authored roof" % house.name)
		var visual := house.find_child("AuthoredHouse", true, false) as MeshInstance3D
		check(visual != null and visual.visible and visual.material_override == null, "%s has no visible authored mesh" % house.name)
		if visual != null and visual.mesh != null:
			var expected_file := "GreyfenHouse_Authored.res" if variant == 0 else "GreyfenHouse_Authored_%d.res" % variant
			check(visual.mesh.resource_path.ends_with(expected_file), "%s uses the wrong house mesh" % house.name)
			var size := visual.mesh.get_aabb().size * visual.scale.abs()
			check(size.x >= 4.5 and size.x <= 5.0 and size.y >= 3.4 and size.y <= 3.9 and size.z >= 4.0 and size.z <= 4.7, "%s has incorrect house bounds: %s" % [house.name, size])
			check(visual.mesh.get_surface_count() == 6, "%s lost structural material groups" % house.name)
			for surface_index in visual.mesh.get_surface_count():
				check(visual.mesh.surface_get_material(surface_index) != null and visual.get_active_material(surface_index) != null, "%s has a null surface material %d" % [house.name, surface_index])
			if house.name == "DressedVillageHouse_EastLane":
				var footprint := _world_footprint(visual)
				check(footprint.end.y <= 1.5, "East-lane house extends into the Greyfen riverbank: %s" % footprint)
				check(footprint.end.x <= 8.15, "East-lane house crowds the forge and its canopy: %s" % footprint)
		var body := house.find_child("HouseCollision", true, false) as StaticBody3D
		check(body != null and body.get_child_count() > 0 and body.get_child(0) is CollisionShape3D, "%s lost its collision body" % house.name)
		if variant == 1 and body != null:
			check(body.get_child_count() == 3, "%s has porch posts without matching collision" % house.name)
	check(authored_houses == 4, "Expected four authored Greyfen houses, found %d" % authored_houses)
	check(variants.size() == 4, "Greyfen houses repeat an authored variant")

	for road_name in ["PavedRoadMain", "PavedRoadVillage", "PavedRoadCastle"]:
		var road := game.zone_root.find_child(road_name, true, false) as MeshInstance3D
		check(road != null and road.mesh is ArrayMesh and road.material_override != null and road.material_override.albedo_texture != null, "%s lacks textured paving" % road_name)
		if road != null and road.mesh != null:
			check(road.mesh.get_aabb().size.x > 3.0 and road.mesh.get_aabb().size.z > 2.5, "%s has invalid paved bounds" % road_name)
	check(_route_clear(game.spatial_service, Vector3(0, 0.9, 12.5), Vector3(0, 0.9, -12.5)), "Spawn-to-Wychwood route is obstructed")
	check(_route_clear(game.spatial_service, Vector3(0, 0.9, 7.5), Vector3(6.0, 0.9, -6.0)), "Shrine route is obstructed")
	check(not game.spatial_service.is_river_excluded(Vector3(0, 0.9, 4.5), 0.5), "Bridge centre is incorrectly excluded")
	check(game.zone_root.find_child("GreyfenCemeterySection", true, false) != null, "Cemetery landmark was lost")
	check(game.zone_root.find_child("GreyfenSpawnComposition", true, false) != null, "Spawn composition was lost")
	check(game.zone_root.find_child("WorldPropAnchor_Cart", true, false) != null, "Greyfen cart interaction anchor was lost")
	check(game.zone_root.find_child("BrokenCartBed", true, false) == null, "Greyfen still draws a duplicate cart over the imported stall")
	var frontages := game.zone_root.find_child("GreyfenAuthoredFrontages", true, false) as MeshInstance3D
	var forge_work := game.zone_root.find_child("BlacksmithFittedWork", true, false) as MeshInstance3D
	check(forge_work != null and forge_work.mesh != null, "Greyfen forge has no fitted working tools or stock")
	if forge_work != null and forge_work.mesh != null:
		check(forge_work.mesh.get_surface_count() == 2, "Forge work material ownership drift")
		check(forge_work.mesh.get_aabb().position.y >= -0.001, "Forge equipment floats below its ground support")
		for surface in forge_work.mesh.get_surface_count():
			check(forge_work.get_active_material(surface) != null, "Forge equipment has a null active material")
	check(game.zone_root.find_child("ForgeCoalCollision", true, false) != null, "Forge fuel lost its existing physical collision")
	check(frontages != null and frontages.mesh != null, "Greyfen shop/door/work-area surfaces are missing")
	if frontages != null and frontages.mesh != null:
		check(frontages.mesh.get_surface_count() == 3, "Greyfen frontages lost paving, work earth or drainage materials")
		check(frontages.find_children("*", "CollisionObject3D", true, false).is_empty(), "Frontage art changes physical traversal")
		for point in frontages.mesh.get_faces():
			check(point.is_finite() and (point.z < 2.48 or point.z > 6.52), "Frontage surface overlaps the river or bridge-only crossing")
		for surface in frontages.mesh.get_surface_count():
			var material := frontages.get_active_material(surface) as StandardMaterial3D
			check(material != null and material.albedo_texture != null, "Frontage surface lacks an active authored texture")
			for normal in frontages.mesh.surface_get_arrays(surface)[Mesh.ARRAY_NORMAL]:
				check(normal.y > 0.9, "Frontage paving is backface-culled or wall-facing")
	for berm_name in ["NorthBermWest", "NorthBermEast", "SouthBerm", "WestBermNorth", "WestBermSouth", "EastBermNorth", "EastBermSouth"]:
		var berm := game.zone_root.find_child(berm_name, true, false) as StaticBody3D
		check(berm != null, "Greyfen boundary collision is missing: " + berm_name)
		if berm != null:
			check(berm.find_child("CollisionShape3D", false, false) is CollisionShape3D, "Greyfen boundary lost its shape: " + berm_name)
			var berm_surface := berm.find_child("Surface", false, false) as MeshInstance3D
			check(berm_surface != null and not berm_surface.visible, "Greyfen boundary exposes a box wall: " + berm_name)

	var nodes := _walk(game.zone_root).size()
	var meshes: int = game.zone_root.find_children("*", "MeshInstance3D", true, false).size()
	var lights: int = game.zone_root.find_children("*", "Light3D", true, false).size()
	check(nodes <= 1350, "Greyfen exceeds the 1350-node budget: %d" % nodes)
	check(meshes <= 420, "Greyfen exceeds the 420-mesh budget: %d" % meshes)
	check(lights <= 8, "Greyfen exceeds the eight-light budget: %d" % lights)
	print("WORLD-001 METRICS nodes=%d meshes=%d lights=%d" % [nodes, meshes, lights])
	print("WORLD-001 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	await _shutdown_game(game)
	quit(0 if failures == 0 else 1)

func _route_clear(service, start: Vector3, destination: Vector3) -> bool:
	var route: Array = service.build_route(start, destination, 0.7)
	if route.is_empty():
		return false
	for index in range(1, route.size()):
		if not service.validate_segment(route[index - 1], route[index], 0.7):
			return false
	return true

func _world_footprint(visual: MeshInstance3D) -> Rect2:
	var bounds := visual.mesh.get_aabb()
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for x in [bounds.position.x, bounds.end.x]:
		for z in [bounds.position.z, bounds.end.z]:
			var point := visual.global_transform * Vector3(x, 0.0, z)
			low = low.min(Vector2(point.x, point.z))
			high = high.max(Vector2(point.x, point.z))
	return Rect2(low, high - low)

func _group_count(scope: Node, group_name: String) -> int:
	var count := 0
	for node in get_nodes_in_group(group_name):
		if scope.is_ancestor_of(node):
			count += 1
	return count

func _named_count(scope: Node, node_name: String) -> int:
	return scope.find_children(node_name, "Node3D", true, false).size()

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

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
