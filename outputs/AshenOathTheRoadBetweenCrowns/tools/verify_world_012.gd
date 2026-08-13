extends SceneTree

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

	_assert(str(game.current_zone_id) == "greyfen", "New Game did not start in Greyfen")
	var authored: Node = game.zone_root.find_child("GreyfenAuthoredDetailLayer", true, false)
	_assert(authored != null, "WORLD-012 authored detail layer is missing")
	if authored != null:
		_assert(str(authored.get_meta("ticket", "")) == "WORLD-012", "Greyfen detail layer ticket marker is wrong")
	_assert(_group_count(game.zone_root, "greyfen_house") == 4, "Greyfen route lost one of four houses")
	var modular_roofs := _named_count(game.zone_root, "ModularTileRoof")
	var fallback_roofs := _named_count(game.zone_root, "LeftRoofSlope") + _named_count(game.zone_root, "RightRoofSlope")
	var roof_contracts := 0
	for house in game.zone_root.find_children("*", "Node3D", true, false):
		if house.is_in_group("greyfen_house") and str(house.get_meta("roof_treatment", "")) != "":
			roof_contracts += 1
	_assert(modular_roofs >= 4 or fallback_roofs >= 8 or roof_contracts >= 4, "Greyfen houses have no authored roof treatment")
	_assert(_named_count(game.zone_root, "ModularDoorFacade") >= 4, "Balanced houses did not receive modular door assets")
	_assert(_named_count(game.zone_root, "ModularWindowFacade") >= 4, "Balanced houses did not receive modular window assets")
	_assert(_named_count(game.zone_root, "ModularChimney") >= 4, "Balanced houses did not receive modular chimney assets")
	for name in ["GreyfenShrineArchLintel", "GreyfenForgeCanopy", "GreyfenForgeRack", "GreyfenMarketAwning"]:
		_assert(_named_count(game.zone_root, name) > 0, "%s is missing" % name)
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
	_finish(game)

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

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)

func _finish(game = null) -> void:
	if game != null and is_instance_valid(game):
		game.free()
	if failures.is_empty():
		print("WORLD-012 VERIFIER: PASS - authored Greyfen detail and route safety")
		quit(0)
		return
	print("WORLD-012 VERIFIER: FAIL (%d)" % failures.size())
	for failure in failures:
		print("- %s" % failure)
	quit(1)
