extends SceneTree

const SpatialSurfaceContract = preload("res://scripts/spatial_surface_contract.gd")
const ZoneSpatialService = preload("res://scripts/zone_spatial_service.gd")

var failures: Array[String] = []

func _initialize() -> void:
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
