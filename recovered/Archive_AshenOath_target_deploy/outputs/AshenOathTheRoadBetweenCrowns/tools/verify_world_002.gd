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

	check(game.current_zone_id == "wychwood", "WORLD-002 did not load Wychwood")
	var section: Node = game.zone_root.find_child("AuthoredWychwoodSection", true, false)
	check(section != null and str(section.get_meta("ticket", "")) == "WORLD-002", "Authored Wychwood ownership is missing")
	check(game.zone_root.find_child("DeterministicNavigationRegion", true, false) is NavigationRegion3D, "Wychwood navigation region was lost")
	check(game.zone_root.find_child("WychwoodGateThreshold", true, false) != null, "Wychwood entrance composition is missing")
	check(game.zone_root.find_child("WychwoodInvestigationRoute", true, false) != null, "Investigation route composition is missing")
	check(game.zone_root.find_child("AuthoredWychwoodCombatArena", true, false) != null, "Combat clearing composition is missing")
	check(game.zone_root.find_child("LivingRiverSection", true, false) != null, "Wychwood river and bridge were lost")
	check(_group_count(game.zone_root, "wychwood_landmark_tree") >= 8, "Wychwood lacks full-tree landmarks")
	check(_group_count(game.zone_root, "wychwood_route_bush") >= 4, "Wychwood route understory is missing")

	check(_route_clear(game.spatial_service, Vector3(0, 0.9, 12.5), Vector3(0, 0.9, -2.5)), "Gate-to-bridge investigation route is obstructed")
	check(_route_clear(game.spatial_service, Vector3(0, 0.9, -2.5), Vector3(0, 0.9, -9.5)), "Combat clearing route is obstructed")
	check(_route_clear(game.spatial_service, Vector3(0, 0.9, -9.5), Vector3(0, 0.9, 12.5)), "Return-to-Greyfen route is obstructed")
	check(not game.spatial_service.is_river_excluded(Vector3(0, 0.9, 0), 0.5), "Bridge centre is incorrectly river-excluded")
	for clue_id in ["corpse", "claw_marks", "black_feathers", "tracks"]:
		var clue: Node3D = game.zone_root.find_child(clue_id, true, false) as Node3D
		check(clue != null, "Missing Road of Crows clue: %s" % clue_id)
		if clue != null:
			check(not game.spatial_service.is_river_excluded(clue.global_position, 0.7), "Clue intersects the river exclusion: %s" % clue_id)
	check(game.active_enemies.size() == 5, "Wychwood must stage exactly five Road of Crows enemies")

	var nodes := _walk(game.zone_root).size()
	var meshes: int = game.zone_root.find_children("*", "MeshInstance3D", true, false).size()
	var lights: int = game.zone_root.find_children("*", "Light3D", true, false).size()
	check(nodes <= 1350, "Wychwood exceeds the 1350-node budget: %d" % nodes)
	check(meshes <= 420, "Wychwood exceeds the 420-mesh budget: %d" % meshes)
	check(lights <= 8, "Wychwood exceeds the eight-light budget: %d" % lights)
	print("WORLD-002 METRICS nodes=%d meshes=%d lights=%d enemies=%d" % [nodes, meshes, lights, game.active_enemies.size()])
	print("WORLD-002 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
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
