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
	game.quests.start_quest("side_widows_bell")
	game.call("_load_zone", "greyfen", Vector3(0, 0.9, 8))
	await _frames(10)
	check(game.current_zone_id == "greyfen", "Greyfen did not load")
	var layer: Node = game.zone_root.find_child("CemeteryAuthoredPresentation", true, false)
	check(layer != null, "WORLD-014 cemetery presentation layer is missing")
	if layer != null:
		check(str(layer.get_meta("ticket", "")) == "WORLD-014", "WORLD-014 ticket metadata is missing")
		check(bool(layer.get_meta("bell_stateful", false)), "Bell state contract is missing")
		check(bool(layer.get_meta("chapel_stateful", false)), "Chapel state contract is missing")
		check(bool(layer.get_meta("crow_shrine_consequence", false)), "Crow Shrine consequence contract is missing")
	check(game.zone_root.find_child("CemeteryBellHouseHood", true, false) != null, "Bell house hood is missing")
	check(game.zone_root.find_child("CemeteryBellClapper", true, false) != null, "Bell clapper is missing")
	check(game.zone_root.find_child("CrowChapelMemoryWindow", true, false) != null, "Chapel focal window is missing")
	check(game.zone_root.find_child("CemeteryGraveRowRhythm", true, false) != null, "Grave-row rhythm is missing")
	check(game.zone_root.find_child("CrowShrineRoost", true, false) != null, "Crow Shrine roost is missing")
	check(game.zone_root.find_child("CemeteryStateAnchors", true, false) != null, "Cemetery state anchors are missing")
	for id in ["grave_bell", "grave_harl", "grave_child", "grave_soldier", "chapel_door"]:
		check(game.zone_root.find_child(id, true, false) != null, "Cemetery interaction is missing: %s" % id)
	check(_route_clear(game.spatial_service, Vector3(8.8, 0.9, 8.0), Vector3(13.0, 0.9, 8.0)), "Cemetery entry route is obstructed")
	check(_route_clear(game.spatial_service, Vector3(13.0, 0.9, 8.0), Vector3(16.0, 0.9, 8.0)), "Grave-court route is obstructed")
	var nodes := _walk(game.zone_root).size()
	var meshes: int = game.zone_root.find_children("*", "MeshInstance3D", true, false).size()
	check(nodes <= 1150, "Greyfen cemetery route exceeds WORLD-014 node budget: %d" % nodes)
	check(meshes <= 340, "Greyfen cemetery route exceeds WORLD-014 mesh budget: %d" % meshes)
	print("WORLD-014 METRICS nodes=%d meshes=%d" % [nodes, meshes])
	print("WORLD-014 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

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
