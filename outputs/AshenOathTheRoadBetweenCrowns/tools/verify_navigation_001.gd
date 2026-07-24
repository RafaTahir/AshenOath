extends SceneTree

var failures := 0

func _initialize() -> void:
	var scene = load("res://scenes/main.tscn")
	check(scene != null, "Main scene is missing")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_new_game")
	await _settle(8)
	await _verify_zone(game, "greyfen", Vector3(0, 0.9, 12.5), Vector3(0, 0.9, -12.5))
	var life = game.zone_root.find_child("GreyfenLifeController", true, false)
	check(life != null and life.actor_count() >= 7, "Greyfen must retain seven routed actors")
	if life != null:
		for entry in life.actors:
			check(entry.get("agent") is NavigationAgent3D, "Routine %s has no NavigationAgent3D" % entry.id)
			var points: Array = entry.path
			for index in range(points.size()):
				var route: Array = game.spatial_service.build_route(points[index], points[(index + 1) % points.size()], 0.58)
				check(not route.is_empty(), "Routine %s has an invalid route segment" % entry.id)
				check(_route_is_safe(game.spatial_service, route), "Routine %s enters excluded river space" % entry.id)
	var initial_positions := {}
	if life != null:
		for entry in life.actors:
			initial_positions[entry.id] = entry.node.global_position
			# Headless process frames can advance with effectively zero elapsed time.
			# Drive a short fixed-delta routine sample so this check measures routing,
			# not scheduler wall-clock timing or deliberate ambient pauses.
			entry.pause = 0.0
		for sample in range(8):
			for entry in life.actors:
				life._update_actor(entry, 0.25)
			await process_frame
	if life != null:
		var moved_count := 0
		for entry in life.actors:
			check(not game.spatial_service.is_river_excluded(entry.node.global_position, 0.25), "Routine %s entered the river" % entry.id)
			if entry.node.global_position.distance_to(initial_positions[entry.id]) > 0.02:
				moved_count += 1
		check(moved_count >= 4, "Fewer than four Greyfen routines moved under navigation")

	game.call("_load_zone", "wychwood", Vector3(0, 0.9, 12.5))
	await _settle(10)
	await _verify_zone(game, "wychwood", Vector3(0, 0.9, 12.5), Vector3(0, 0.9, -12.5))
	check(game.active_enemies.size() == 5, "Wychwood must contain five encounter enemies")
	for enemy in game.active_enemies:
		check(enemy.navigation_agent is NavigationAgent3D, "%s has no NavigationAgent3D" % enemy.enemy_id)
		check(enemy.spatial_service == game.spatial_service, "%s is bound to a stale spatial service" % enemy.enemy_id)
		var pursuit: Array = game.spatial_service.build_route(enemy.global_position, game.player.global_position, 0.5)
		check(not pursuit.is_empty() and _route_is_safe(game.spatial_service, pursuit), "%s cannot build a safe pursuit route" % enemy.enemy_id)
		var recovery: Vector3 = game.spatial_service.nearest_safe(Vector3(8.0, -1.0, 0.0), -1)
		check(game.spatial_service.bank_for(recovery) == -1, "Enemy recovery changed river bank")
		check(not game.spatial_service.is_river_excluded(recovery, 0.4), "Enemy recovery remained in water")

	var gate_route: Array = game.spatial_service.build_route(Vector3(0, 0.9, 12.5), Vector3(0, 0.9, 15.8), 0.8)
	check(not gate_route.is_empty() and _route_is_safe(game.spatial_service, gate_route), "Wychwood return gate corridor is not reserved and traversable")
	var migrated: Vector3 = game.call("_safe_loaded_position", "wychwood", Vector3(8.0, -1.0, 0.0))
	check(not game.spatial_service.is_river_excluded(migrated, 0.4), "Invalid saved position was not migrated")
	check(game.spatial_service.bank_for(migrated) == 1, "Saved-position migration changed the original bank")

	print("NAV-001 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _verify_zone(game, expected_zone: String, bank_a: Vector3, bank_b: Vector3) -> void:
	check(game.current_zone_id == expected_zone, "%s did not load" % expected_zone)
	var service = game.spatial_service
	check(service != null, "%s spatial service is missing" % expected_zone)
	check(game.zone_root.find_child("DeterministicNavigationRegion", false, false) is NavigationRegion3D, "%s navigation region is missing" % expected_zone)
	check(service.get_navigation_map().is_valid(), "%s navigation map is invalid" % expected_zone)
	var route: Array = service.build_route(bank_a, bank_b, 0.7)
	check(route.size() >= 5, "%s cross-bank route does not use bridge anchors" % expected_zone)
	check(_route_is_safe(service, route), "%s cross-bank route leaves legal navigation space" % expected_zone)
	var found_center := false
	for point in route:
		if absf(point.z - service.river_center) < 0.2 and absf(point.x) < 2.0:
			found_center = true
	check(found_center, "%s cross-bank route does not pass through the bridge" % expected_zone)
	var same_bank: Array = service.build_route(bank_a + Vector3(-4, 0, 0), bank_a + Vector3(4, 0, -1), 0.7)
	check(not same_bank.is_empty() and _route_is_safe(service, same_bank), "%s same-bank route is invalid" % expected_zone)

func _route_is_safe(service, route: Array) -> bool:
	for index in range(route.size()):
		if service.is_river_excluded(route[index], 0.25):
			return false
		if index > 0 and not service.validate_segment(route[index - 1], route[index], 0.25):
			return false
	return true

func _settle(count: int) -> void:
	for index in range(count):
		await process_frame

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
