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
	game.quests.start_quest("main_road_of_crows")
	game.call("_load_zone", "wychwood", Vector3(0, 1, 12.5))
	await _frames(12)
	check(game.current_zone_id == "wychwood", "Wychwood did not load")
	var presentation: Node = game.zone_root.find_child("WychwoodAuthoredPresentation", true, false)
	check(presentation != null, "WORLD-013 presentation layer is missing")
	if presentation != null:
		check(str(presentation.get_meta("ticket", "")) == "WORLD-013", "WORLD-013 ticket metadata is missing")
		check(int(presentation.get_meta("canopy_layers", 0)) == 2, "Wychwood does not expose two canopy layers")
		check(bool(presentation.get_meta("combat_arena_authored", false)), "Wychwood combat arena is not authored")
	check(game.zone_root.find_child("WychwoodRootArchLintel", true, false) != null, "Wychwood route gate lacks root arch")
	check(game.zone_root.find_child("WychwoodCanopyLower", true, false) is MultiMeshInstance3D, "Lower canopy batch is missing")
	check(game.zone_root.find_child("WychwoodCanopyUpper", true, false) is MultiMeshInstance3D, "Upper canopy batch is missing")
	check(game.zone_root.find_child("WychwoodUnderstoryBatch", true, false) is MultiMeshInstance3D, "Understory batch is missing")
	check(game.zone_root.find_child("WychwoodForestFloorDetail", true, false) is MultiMeshInstance3D, "Forest-floor detail batch is missing")
	var sightlines: Node = game.zone_root.find_child("WychwoodClueSightlines", true, false)
	check(sightlines != null and sightlines.get_child_count() == 5, "Wychwood clue sightlines are incomplete")
	check(game.zone_root.find_child("WychwoodCombatClearingFrame", true, false) != null, "Combat clearing frame is missing")
	check(game.zone_root.find_child("WychwoodMemoryLandmark", true, false) != null, "Memory landmark is missing")
	check(_route_clear(game.spatial_service, Vector3(0, 0.9, 12.5), Vector3(0, 0.9, -2.5)), "Authored route to clues is obstructed")
	check(_route_clear(game.spatial_service, Vector3(0, 0.9, -2.5), Vector3(0, 0.9, -9.5)), "Authored route to clearing is obstructed")
	check(_route_clear(game.spatial_service, Vector3(0, 0.9, -9.5), Vector3(0, 0.9, 12.5)), "Authored return route is obstructed")
	var nodes := _walk(game.zone_root).size()
	var meshes: int = game.zone_root.find_children("*", "MeshInstance3D", true, false).size()
	var multimeshes: int = game.zone_root.find_children("*", "MultiMeshInstance3D", true, false).size()
	check(nodes <= 1450, "Wychwood exceeds WORLD-013 node budget: %d" % nodes)
	check(meshes <= 440, "Wychwood exceeds WORLD-013 mesh budget: %d" % meshes)
	check(multimeshes <= 20, "Wychwood exceeds WORLD-013 batch budget: %d" % multimeshes)
	print("WORLD-013 METRICS nodes=%d meshes=%d multimeshes=%d" % [nodes, meshes, multimeshes])
	print("WORLD-013 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
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
