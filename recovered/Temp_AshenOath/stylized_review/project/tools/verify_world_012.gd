extends SceneTree

const BridgeSurfaceContract = preload("res://scripts/bridge_surface_contract.gd")

var failures: Array[String] = []

func _initialize() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	_assert(scene != null, "main scene is unavailable")
	if scene == null:
		_finish()
		return
	var game = scene.instantiate()
	root.add_child(game)
	await _frames(2)
	game.settings.set_quality_preset("balanced")
	game.call("_new_game")
	await _frames(12)
	var detail_deadline := Time.get_ticks_msec() + 30000
	while game.opening_detail_pending and Time.get_ticks_msec() < detail_deadline:
		await process_frame
	_assert(not game.opening_detail_pending, "Greyfen deferred detail did not finish within 30 seconds")

	_assert(str(game.current_zone_id) == "greyfen", "New Game did not start in Greyfen")
	var authored: Node = game.zone_root.find_child("GreyfenAuthoredDetailLayer", true, false)
	_assert(authored != null, "WORLD-012 authored detail layer is missing")
	if authored != null:
		_assert(str(authored.get_meta("ticket", "")) == "WORLD-012", "Greyfen detail layer ticket marker is wrong")
	_assert(_group_count(game.zone_root, "greyfen_house") == 4, "Greyfen route lost one of four houses")
	_assert(game.zone_root.find_child("GreyfenHorizonRidges", true, false) != null, "Greyfen has no bounded horizon depth layer")
	var authored_houses := 0
	var house_variants: Dictionary = {}
	for house in game.zone_root.find_children("*", "Node3D", true, false):
		if not house.is_in_group("greyfen_house"):
			continue
		authored_houses += 1
		house_variants[int(house.get_meta("house_variant", -1))] = true
		var visual := house.find_child("AuthoredHouse", true, false) as MeshInstance3D
		_assert(visual != null and visual.visible and visual.mesh != null, "%s lost its authored structure" % house.name)
		var camera_roof := house.find_child("CameraRoofCollision", true, false) as StaticBody3D
		_assert(camera_roof != null and camera_roof.collision_layer == 1 << 6 and camera_roof.collision_mask == 0,
			"%s lost its camera-only roof collision" % house.name)
		if visual != null and visual.mesh != null:
			_assert(visual.mesh.get_surface_count() == 6, "%s lost its structural material groups" % house.name)
			for surface_index in visual.mesh.get_surface_count():
				_assert(visual.mesh.surface_get_material(surface_index) != null and visual.get_active_material(surface_index) != null, "%s has an unassigned surface %d" % [house.name, surface_index])
	_assert(authored_houses == 4, "Greyfen lost an authored route house")
	_assert(house_variants.size() == 4, "Greyfen route houses have repeated silhouettes")
	var forge := game.zone_root.find_child("BlacksmithAuthoredForge", true, false) as MeshInstance3D
	_assert(forge != null and forge.mesh is ArrayMesh and forge.mesh.get_surface_count() == 6, "Greyfen blacksmith authored structure is missing")
	if forge != null and forge.mesh != null:
		_assert(forge.mesh.resource_path.ends_with("GreyfenForge_Authored.res"), "Greyfen blacksmith uses the wrong structure")
		for surface_index in forge.mesh.get_surface_count():
			_assert(forge.mesh.surface_get_material(surface_index) != null and forge.get_active_material(surface_index) != null, "Greyfen blacksmith has an unassigned surface %d" % surface_index)
	_assert(game.zone_root.find_child("BlacksmithStoneShopCollision", true, false) == null, "Greyfen blacksmith retained its closed block collision")
	_assert(game.zone_root.find_child("ForgeCollision", true, false) == null, "Greyfen forge retained its tall block collision")
	_assert(game.zone_root.find_child("ForgeHearthCollision", true, false) != null, "Greyfen forge lost its low hearth collision")
	var oathstone := game.zone_root.find_child("GreyfenAuthoredOathstone", true, false) as MeshInstance3D
	_assert(oathstone != null and oathstone.mesh is ArrayMesh and oathstone.mesh.get_surface_count() == 6, "Greyfen shrine lost its authored oathstone")
	if oathstone != null and oathstone.mesh != null:
		_assert(oathstone.mesh.resource_path.ends_with("GreyfenShrine_Authored.res"), "Greyfen shrine uses the wrong oathstone")
		for surface_index in oathstone.mesh.get_surface_count():
			_assert(oathstone.mesh.surface_get_material(surface_index) != null and oathstone.get_active_material(surface_index) != null, "Greyfen shrine has an unassigned surface %d" % surface_index)
			if oathstone.mesh.surface_get_name(surface_index) == "plaster":
				var normals: PackedVector3Array = oathstone.mesh.surface_get_arrays(surface_index)[Mesh.ARRAY_NORMAL]
				var has_front_face := false
				for normal in normals:
					if normal.z < -0.8:
						has_front_face = true
						break
				_assert(has_front_face, "Greyfen oathstone front face is backface-culled")
	var shrine_bench := game.zone_root.find_child("shrine_prayer_VisibleProp", true, false) as MeshInstance3D
	_assert(shrine_bench != null and shrine_bench.mesh is BoxMesh and (shrine_bench.mesh as BoxMesh).size.y <= 0.12, "Greyfen shrine bench is still a solid block")
	_assert(game.zone_root.find_child("ShrineBenchSupports", true, false) != null, "Greyfen shrine bench has no supports")
	var well := game.zone_root.find_child("village_well_VisibleProp", true, false) as MeshInstance3D
	_assert(well != null and well.mesh is ArrayMesh and well.mesh.get_surface_count() == 6, "Greyfen village well is still a solid proxy")
	if well != null and well.mesh is ArrayMesh:
		_assert(well.mesh.resource_path.ends_with("GreyfenWell_Authored.res"), "Greyfen village well uses the wrong mesh")
		for surface_index in well.mesh.get_surface_count():
			_assert(well.mesh.surface_get_material(surface_index) != null and well.get_active_material(surface_index) != null, "Greyfen village well has an unassigned surface %d" % surface_index)
			if well.mesh.surface_get_name(surface_index) == "plaster":
				var rim_vertices: PackedVector3Array = well.mesh.surface_get_arrays(surface_index)[Mesh.ARRAY_VERTEX]
				for vertex in rim_vertices:
					_assert(absf(vertex.y - 0.84) < 0.001, "Greyfen well pale rim material leaks onto an exterior wall")
	var well_collision := game.zone_root.find_child("GreyfenWellCollision", true, false) as CollisionShape3D
	_assert(well_collision != null and well_collision.shape is CylinderShape3D, "Greyfen village well lost fitted cylinder collision")
	for shape_name in ["ShrinePlinthCollision", "ShrineOathstoneCollision"]:
		_assert(game.zone_root.find_child(shape_name, true, false) != null, "Greyfen shrine lost fitted collision: " + shape_name)
	_assert(game.zone_root.find_child("ShrineBaseCollision", true, false) == null, "Greyfen shrine retained its box plinth")
	for interaction_id in ["forge_corner", "tor_forge"]:
		var proxy := game.zone_root.find_child("%s_VisibleProp" % interaction_id, true, false) as MeshInstance3D
		_assert(proxy == null, "Greyfen workshop retained a duplicate hidden mesh: " + interaction_id)
		_assert(game.zone_root.find_child(interaction_id, true, false) != null, "Greyfen workshop interaction is missing: " + interaction_id)
	for wall_name in ["BlacksmithRearWallCollision", "BlacksmithSideWallCollision"]:
		_assert(game.zone_root.find_child(wall_name, true, false) != null, "Greyfen blacksmith lost fitted wall collision: " + wall_name)
	var spawn_house := game.zone_root.find_child("DressedVillageHouse_SpawnFrame", true, false) as Node3D
	_assert(spawn_house != null, "Greyfen spawn-frame house is missing")
	if spawn_house != null:
		for x in [-2.1, 2.1]:
			for z in [-1.7, 1.7]:
				var corner := spawn_house.global_transform * Vector3(x, 0.0, z)
				_assert(corner.z > 4.5 + BridgeSurfaceContract.RIVER_HALF_SPAN + 0.3, "Greyfen house footprint overlaps the riverbank")
	var water := game.zone_root.find_child("FlowingRiverWater", true, false) as MeshInstance3D
	_assert(water != null and water.material_override is ShaderMaterial, "Greyfen river has no animated water material")
	if water != null and water.material_override is ShaderMaterial:
		_assert(str(water.get_meta("water_role", "WATER-002")) == "WATER-002", "Greyfen water role contract is missing")
	for name in ["GreyfenShrineStoneArch", "GreyfenForgeRack", "GreyfenMarketStall"]:
		_assert(_named_count(game.zone_root, name) > 0, "%s is missing" % name)
	var shrine_arch := game.zone_root.find_child("GreyfenShrineStoneArch", true, false) as Node3D
	if shrine_arch != null:
		var visible_arch := shrine_arch is MeshInstance3D and (shrine_arch as MeshInstance3D).mesh != null
		_assert(visible_arch or shrine_arch.find_children("*", "MeshInstance3D", true, false).size() > 0, "Greyfen shrine arch has no imported visible mesh")
	for planting_name in ["GreyfenShrineGardenWest", "GreyfenShrineGardenEast", "GreyfenShrineGardenFar"]:
		_assert(game.zone_root.find_child(planting_name, true, false) != null, "Greyfen shrine planting is missing: " + planting_name)
	var shrine_cloths := _named_count(game.zone_root, "HangingClothDrape_*")
	for _attempt in range(180):
		if shrine_cloths >= 2:
			break
		await process_frame
		shrine_cloths = _named_count(game.zone_root, "HangingClothDrape_*")
	_assert(shrine_cloths >= 2, "Greyfen shrine has fewer than two folded cloth drapes")
	var market_stall := game.zone_root.find_child("GreyfenMarketStall", true, false) as Node3D
	if market_stall != null:
		var visible_stall := market_stall is MeshInstance3D and (market_stall as MeshInstance3D).mesh != null
		_assert(visible_stall or market_stall.find_children("*", "MeshInstance3D", true, false).size() > 0, "Greyfen market stall has no imported visible mesh")
	_assert(_route_clear(game.spatial_service, Vector3(0, 0.9, 12.5), Vector3(0, 0.9, -12.5)), "Main Greyfen road is obstructed")
	_assert(_route_clear(game.spatial_service, Vector3(0, 0.9, 7.5), Vector3(6.0, 0.9, -6.0)), "Shrine approach is obstructed")
	_assert(_route_clear(game.spatial_service, Vector3(-8.5, 0.9, 8.5), Vector3(0, 0.9, 8.5)), "Spawn market approach is obstructed")
	_assert(_route_clear(game.spatial_service, Vector3(-6.5, 0.9, 1.8), Vector3(-6.5, 0.9, 2.3)), "North river bank route is obstructed")
	_assert(not game.spatial_service.is_river_excluded(Vector3(0, 0.9, 4.5), 0.5), "Bridge centre is excluded")
	_assert(game.zone_root.find_child("GreyfenCemeterySection", true, false) != null, "Cemetery landmark is missing")
	_assert(game.zone_root.find_child("GreyfenSpawnComposition", true, false) != null, "Spawn composition is missing")
	var nodes := _walk(game.zone_root).size()
	var meshes: int = game.zone_root.find_children("*", "MeshInstance3D", true, false).size()
	var lights: int = game.zone_root.find_children("*", "Light3D", true, false).size()
	_assert(nodes <= 1600, "Greyfen exceeds WORLD-012 node budget: %d" % nodes)
	_assert(meshes <= 520, "Greyfen exceeds WORLD-012 mesh budget: %d" % meshes)
	_assert(lights <= 8, "Greyfen exceeds eight-light budget: %d" % lights)
	print("WORLD-012 METRICS nodes=%d meshes=%d lights=%d" % [nodes, meshes, lights])
	await _finish(game)

func _route_clear(service: Node, start: Vector3, destination: Vector3) -> bool:
	var route: Array = service.build_route(start, destination, 0.7)
	if route.is_empty():
		return false
	for index in range(1, route.size()):
		if not service.validate_segment(route[index - 1], route[index], 0.7):
			return false
	return true

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

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)

func _finish(game = null) -> void:
	if failures.is_empty():
		print("WORLD-012 VERIFIER: PASS - authored Greyfen detail and route safety")
	else:
		print("WORLD-012 VERIFIER: FAIL (%d)" % failures.size())
		for failure in failures:
			print("- %s" % failure)
	await _shutdown_game(game)
	quit(0 if failures.is_empty() else 1)
