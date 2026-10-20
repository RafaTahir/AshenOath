extends SceneTree

const SpatialSurfaceContract = preload("res://scripts/spatial_surface_contract.gd")
const ZoneSpatialService = preload("res://scripts/zone_spatial_service.gd")

var failures: Array[String] = []

func _initialize() -> void:
	if "--live-routes-only" in OS.get_cmdline_user_args():
		call_deferred("_check_live_routes")
		return
	_check(is_equal_approx(SpatialSurfaceContract.river_center("greyfen"), 4.5), "Greyfen river center drifted")
	_check(is_equal_approx(SpatialSurfaceContract.river_center("wychwood"), 0.0), "Wychwood river center drifted")
	_check(SpatialSurfaceContract.river_center("record_hall") >= SpatialSurfaceContract.NO_RIVER, "Interior unexpectedly owns a river")
	_check(SpatialSurfaceContract.zone_half_extents("greyfen") == Vector2(21.0, 17.0), "Greyfen bounds drifted")
	_check(SpatialSurfaceContract.zone_half_extents("record_hall") == Vector2(17.0, 15.0), "Record Hall bounds drifted")

	var service := ZoneSpatialService.new()
	service.configure("greyfen", -500.0, Vector2.ONE)
	_check(is_equal_approx(service.river_center, 4.5), "Service ignored authoritative river center")
	_check(service.half_extents == Vector2(21.0, 17.0), "Service ignored authoritative zone bounds")
	_check(service.is_on_bridge(Vector3(0.0, 0.0, 4.5)), "Bridge center is not legal")
	_check(not service.is_river_excluded(Vector3(0.0, 0.0, 4.5)), "Bridge center is classified as water")
	_check(service.is_river_excluded(Vector3(4.0, 0.0, 4.5)), "Open river is not excluded")
	_check(service.bank_for(Vector3(0.0, 0.0, 0.0)) == -1, "North-bank identity is wrong")
	_check(service.bank_for(Vector3(0.0, 0.0, 9.0)) == 1, "South-bank identity is wrong")

	var route := service.build_route(Vector3(5.0, 0.0, 11.0), Vector3(-5.0, 0.0, -2.0), 0.55)
	_check(route.size() >= 5, "Cross-bank route did not use bridge anchors")
	_check(_route_visits_bridge(service, route), "Cross-bank route does not pass through bridge bounds")
	for index in range(1, route.size()):
		_check(service.validate_segment(route[index - 1], route[index], 0.55), "Built route contains an invalid segment")

	var game_source := FileAccess.get_file_as_string("res://scripts/game.gd")
	_check("return SpatialSurfaceContract.river_center(zone)" in game_source, "Game still owns independent river-center rules")
	_check("return SpatialSurfaceContract.zone_half_extents(zone_id)" in game_source, "Game still owns independent zone bounds")
	_check("validator.validate_path(points, margin)" in game_source, "Fallback paths bypass ZoneSpatialService")
	for source_path in [
		"res://scripts/enemy_ai.gd",
		"res://scripts/greyfen_life_controller.gd",
	]:
		var source := FileAccess.get_file_as_string(source_path)
		_check("spatial_service" in source, "%s does not consume the shared spatial service" % source_path)
	var ambient_source := FileAccess.get_file_as_string("res://scripts/npc_ambient.gd")
	_check("global_position =" not in ambient_source, "NpcAmbient acquired horizontal movement authority")
	_check("move_and_slide" not in ambient_source, "NpcAmbient bypasses the route controller")

	service.free()
	if failures.is_empty():
		print("SPAT-001 VERIFIER: PASS")
	else:
		print("SPAT-001 VERIFIER: FAIL (%d)" % failures.size())
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _route_visits_bridge(service: Node, route: Array[Vector3]) -> bool:
	for point in route:
		if service.is_on_bridge(point, 0.0):
			return true
	return false

func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)

func _check_live_routes() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var spatial := ZoneSpatialService.new()
	world.add_child(spatial)
	spatial.configure("greyfen", 4.5, Vector2(21, 17))
	var player := CharacterBody3D.new()
	var capsule := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.65
	capsule.shape = shape
	capsule.position.y = shape.height * 0.5
	player.add_child(capsule)
	world.add_child(player)
	var observer := preload("res://scripts/production_observation_bridge.gd").new()
	_box(world, Vector3(0, -0.1, 0), Vector3(50, 0.2, 50))
	_box(world, Vector3(-5, 1.2, -3), Vector3(4.2, 2.4, 3.4), deg_to_rad(8.0))
	for x in [-0.98, 0.98]:
		var local := Basis(Vector3.UP, deg_to_rad(8.0)) * Vector3(x, 0.95, -2.36)
		_box(world, Vector3(-5, 0, -3) + local, Vector3(0.12, 1.6, 0.12), deg_to_rad(8.0))
	var well := StaticBody3D.new()
	well.position = Vector3(-8, 0.42, -0.5)
	var well_shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.87
	cylinder.height = 0.84
	well_shape.shape = cylinder
	well.add_child(well_shape)
	world.add_child(well)
	_box(world, Vector3(-4.6, 0.5, 9), Vector3(1.3, 1, 1.3))
	_box(world, Vector3(0, 0.06, 4.5), Vector3(5.4, 0.12, 6.4))
	await physics_frame
	await physics_frame
	var before := player.transform
	var house_points: Array[Vector3] = [Vector3(-7.260718, 0, -1.467437), Vector3(0, 0, -1.467437)]
	var house: Array[Vector3] = observer.physical_route_for_points(player, spatial, house_points)
	_assert_sweeps(player, house, "WestLane house/well", true)
	spatial.configure("wychwood", 0, Vector2(22, 17))
	var rock_points: Array[Vector3] = [Vector3(-7.29818, 0, 9.13616), Vector3(8, 0, 7.8)]
	var rock: Array[Vector3] = observer.physical_route_for_points(player, spatial, rock_points)
	_assert_sweeps(player, rock, "Wychwood rock", true)
	spatial.configure("greyfen", 4.5, Vector2(21, 17))
	var bridge: Array[Vector3] = observer.physical_route_for_points(player, spatial,
		spatial.build_route(Vector3(0, 0, 0), Vector3(0, 0, 9), 0.55))
	_assert_sweeps(player, bridge, "Authored bridge", false)
	_check(_route_visits_bridge(spatial, bridge), "Live route bypassed the legal bridge")
	var wall := _box(world, Vector3(0, 1.2, 11), Vector3(1, 2.4, 40))
	await physics_frame
	await physics_frame
	var sealed_points: Array[Vector3] = [Vector3(-6, 0, 11), Vector3(6, 0, 11)]
	_check(observer.physical_route_for_points(player, spatial, sealed_points).is_empty(), "Sealed route invented a passable path")
	_check(player.transform == before, "Read-only planning moved the player")
	wall.queue_free()
	observer.free()
	world.queue_free()
	await process_frame
	await process_frame
	for failure in failures:
		push_error(failure)
	print("LIVE ROUTE CAPSULE VERIFIER: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func _box(parent: Node, position: Vector3, size: Vector3, yaw: float = 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = position
	body.rotation.y = yaw
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	return body

func _assert_sweeps(player: CharacterBody3D, route: Array[Vector3], label: String, needs_detour: bool) -> void:
	_check(route.size() >= (3 if needs_detour else 2), label + " has no complete physical route")
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = player.get_child(0).shape
	query.exclude = [player.get_rid()]
	query.collision_mask = 1
	query.collide_with_areas = false
	query.margin = 0.01
	for index in range(1, route.size()):
		query.transform = Transform3D(Basis.IDENTITY, route[index - 1] + Vector3(0, 0.885, 0))
		query.motion = route[index] - route[index - 1]
		var fractions := player.get_world_3d().direct_space_state.cast_motion(query)
		_check(fractions.size() == 2 and fractions[0] >= 0.9999, label + " has a blocked capsule sweep")
	print("LIVE ROUTE: %s points=%d" % [label, route.size()])
