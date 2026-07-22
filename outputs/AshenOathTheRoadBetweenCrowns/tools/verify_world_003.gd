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
	await _frames(12)

	check(game.current_zone_id == "greyfen", "WORLD-003 did not load Greyfen")
	var section: Node = game.zone_root.find_child("GreyfenCemeterySection", true, false)
	check(section != null and str(section.get_meta("ticket", "")) == "WORLD-003", "Authored cemetery ownership is missing")
	for required in [
		"AuthoredCemeteryApproach", "AuthoredGraveCourt", "AuthoredCrowChapel",
		"CemeteryBellFrame", "CrowCemeteryBell", "OssuarySealedDoorCollision", "CemeteryCrowShrineCollision",
	]:
		check(game.zone_root.find_child(required, true, false) != null, "WORLD-003 landmark is missing: %s" % required)
	for interaction_id in ["grave_bell", "grave_harl", "grave_child", "grave_soldier", "chapel_door"]:
		var interaction: Node3D = game.zone_root.find_child(interaction_id, true, false) as Node3D
		check(interaction != null, "Cemetery interaction was lost: %s" % interaction_id)
		if interaction != null:
			check(interaction.global_position.x >= 10.0 and interaction.global_position.x <= 17.2, "Cemetery interaction left authored bounds: %s" % interaction_id)

	check(_route_clear(game.spatial_service, Vector3(8.8, 0.9, 8.0), Vector3(13.0, 0.9, 8.0)), "Cemetery entry route is obstructed")
	check(_route_clear(game.spatial_service, Vector3(13.0, 0.9, 8.0), Vector3(16.0, 0.9, 8.0)), "Grave-court to chapel route is obstructed")

	var castle_gate = game.zone_root.find_child("gate_vargan_approach", true, false)
	check(castle_gate != null, "Greyfen Castle Vargan gateway is missing")
	check(game.zone_root.find_child("GreyfenCastleRoad", true, false) != null, "Authored Castle Vargan road is missing")
	check(game.zone_root.find_child("BlockedRoadBerm", true, false) == null, "Collapsed-road blocker still covers the Castle Vargan gateway")
	check(_castle_corridor_has_clearance(game.zone_root), "A solid prop still blocks the Castle Vargan approach corridor")
	check(game.spatial_service.gates.has("castle_gate"), "Castle gateway is not reserved by ZoneSpatialService")
	check(_route_clear(game.spatial_service, Vector3(12.5, 0.9, 0), Vector3(17.0, 0.9, 0)), "Spatial route to Castle Vargan is obstructed")
	if castle_gate != null:
		game.player.global_position = Vector3(16.0, 0.9, 0)
		game.call("_handle_interaction", castle_gate)
		await _frames(8)
		check(game.current_zone_id == "vargan_approach", "Castle Vargan gateway did not transition from Greyfen")
		check(game.player.global_position.distance_to(Vector3(0, 1, 14)) < 3.0, "Castle arrival position is unsafe or incorrect")

	print("WORLD-003 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _castle_corridor_has_clearance(scope: Node) -> bool:
	for shape_node in scope.find_children("*", "CollisionShape3D", true, false):
		var collision := shape_node as CollisionShape3D
		if not (collision.shape is BoxShape3D):
			continue
		var size: Vector3 = (collision.shape as BoxShape3D).size
		var centre: Vector3 = collision.global_position
		if size.y < 0.45:
			continue
		var overlaps_x := centre.x + size.x * 0.5 > 12.45 and centre.x - size.x * 0.5 < 18.7
		var overlaps_z := centre.z + size.z * 0.5 > -1.35 and centre.z - size.z * 0.5 < 1.35
		if overlaps_x and overlaps_z:
			push_error("Castle corridor collider: %s at %s size %s" % [collision.name, centre, size])
			return false
	return true

func _route_clear(service, start: Vector3, destination: Vector3) -> bool:
	var route: Array = service.build_route(start, destination, 0.7)
	if route.is_empty():
		return false
	for index in range(1, route.size()):
		if not service.validate_segment(route[index - 1], route[index], 0.7):
			return false
	return true

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
