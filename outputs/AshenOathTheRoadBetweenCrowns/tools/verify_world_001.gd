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

	check(game.current_zone_id == "greyfen", "New Game did not open Greyfen")
	var section: Node = game.zone_root.find_child("AuthoredGreyfenSection", true, false)
	check(section != null and str(section.get_meta("ticket", "")) == "WORLD-001", "Authored Greyfen section ownership is missing")
	check(game.zone_root.find_child("DeterministicNavigationRegion", true, false) is NavigationRegion3D, "Greyfen navigation region was lost")
	check(_group_count(game.zone_root, "greyfen_house") == 4, "Greyfen must contain four authored route houses")
	check(_named_count(game.zone_root, "ModularTileRoof") == 4, "Modular tile roofs are missing")
	check(_named_count(game.zone_root, "ModularDoorFacade") == 4, "Modular door facades are missing")
	check(_named_count(game.zone_root, "ModularWindowFacade") == 4, "Modular window facades are missing")
	check(_named_count(game.zone_root, "ModularChimney") == 4, "Modular chimneys are missing")

	var paving := game.zone_root.find_child("BalancedPavedRoadDetail", true, false) as MultiMeshInstance3D
	check(paving != null and paving.multimesh != null and paving.multimesh.instance_count >= 140, "Greyfen paving is not a dense staggered surface")
	check(_route_clear(game.spatial_service, Vector3(0, 0.9, 12.5), Vector3(0, 0.9, -12.5)), "Spawn-to-Wychwood route is obstructed")
	check(_route_clear(game.spatial_service, Vector3(0, 0.9, 7.5), Vector3(6.0, 0.9, -6.0)), "Shrine route is obstructed")
	check(not game.spatial_service.is_river_excluded(Vector3(0, 0.9, 4.5), 0.5), "Bridge centre is incorrectly excluded")
	check(game.zone_root.find_child("GreyfenCemeterySection", true, false) != null, "Cemetery landmark was lost")
	check(game.zone_root.find_child("GreyfenSpawnComposition", true, false) != null, "Spawn composition was lost")

	var nodes := _walk(game.zone_root).size()
	var meshes: int = game.zone_root.find_children("*", "MeshInstance3D", true, false).size()
	var lights: int = game.zone_root.find_children("*", "Light3D", true, false).size()
	check(nodes <= 1350, "Greyfen exceeds the 1350-node budget: %d" % nodes)
	check(meshes <= 420, "Greyfen exceeds the 420-mesh budget: %d" % meshes)
	check(lights <= 8, "Greyfen exceeds the eight-light budget: %d" % lights)
	print("WORLD-001 METRICS nodes=%d meshes=%d lights=%d" % [nodes, meshes, lights])
	print("WORLD-001 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _route_clear(service, start: Vector3, destination: Vector3) -> bool:
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

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
