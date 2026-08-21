extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	check(scene != null, "Main scene is missing")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await settle(2)
	game.call("_new_game")
	await settle(5)
	game.call("_load_zone", "wychwood", Vector3(0, 0.9, 8.0))
	await settle(10)

	check(game.current_zone_id == "wychwood", "Wychwood did not load")
	check(game.active_enemies.size() == 5, "Wychwood tactical pack must contain five enemies")
	var profiles: Dictionary = {}
	var engagement_targets: Array[Vector3] = []
	for enemy in game.active_enemies:
		profiles[enemy.behavior_profile] = true
		check(enemy.navigation_agent is NavigationAgent3D, "%s lacks NavigationAgent3D" % enemy.display_name)
		check(enemy.animation_driver != null and enemy.animation_driver.is_valid(), "%s lacks a valid animated rig" % enemy.display_name)
		check(enemy.attack_contact_bone >= 0, "%s has no skeleton contact bone" % enemy.display_name)
		enemy.call("_attack_contact_point")
		check(enemy.attack_trace_uses_skeleton, "%s attack contact is not skeleton-authored" % enemy.display_name)
		var tactical: Dictionary = enemy.get_tactical_state()
		check(float(tactical.get("preferred_distance", 0.0)) >= 2.0, "%s has no readable engagement distance" % enemy.display_name)
		check(float(tactical.get("leash_radius", 0.0)) >= 10.0, "%s has no bounded leash" % enemy.display_name)
		check(bool(tactical.get("route_safe", true)), "%s retained an unsafe navigation route" % enemy.display_name)
		var route: Array = game.spatial_service.build_route(enemy.global_position, enemy.call("_engagement_target"), 0.55)
		check(not route.is_empty(), "%s cannot route to its engagement lane" % enemy.display_name)
		check(_route_is_safe(game.spatial_service, route), "%s engagement route enters reserved space" % enemy.display_name)
		engagement_targets.append(enemy.call("_engagement_target"))
	check(profiles.has("skirmisher") and profiles.has("flanker") and profiles.has("feinter") and profiles.has("brute"), "Wychwood roles are not behaviorally distinct")
	var distinct_targets: Dictionary = {}
	for target in engagement_targets:
		distinct_targets["%0.1f:%0.1f" % [target.x, target.z]] = true
	check(distinct_targets.size() >= 3, "Enemy roles collapsed into fewer than three engagement lanes")

	# Staging keeps the pack dormant until the authored reveal.
	var active_count := 0
	for enemy in game.active_enemies:
		active_count += 1 if enemy.encounter_active else 0
	check(active_count == 0, "Wychwood enemies activate before the reveal trigger")
	game.player.global_position = Vector3(0, 0.9, 0.0)
	game.call("_update_tutorial_prompts")
	await settle(3)
	active_count = 0
	for enemy in game.active_enemies:
		active_count += 1 if enemy.encounter_active else 0
	check(active_count == 1, "Wychwood reveal activated more than one enemy")
	for enemy in game.active_enemies:
		enemy.set_encounter_active(true)

	# Live pursuit must preserve spacing, bridge-only river rules, and one attack token.
	var smallest_spacing := INF
	var maximum_attackers := 0
	for _frame in range(90):
		await physics_frame
		var attackers := 0
		for first_index in range(game.active_enemies.size()):
			var first = game.active_enemies[first_index]
			attackers += 1 if first.owns_attack_token else 0
			check(not game.spatial_service.is_river_excluded(first.global_position, 0.3), "%s entered river space during pursuit" % first.display_name)
			var live_state: Dictionary = first.get_tactical_state()
			check(bool(live_state.get("route_safe", true)), "%s pursued on an unsafe route" % first.display_name)
			for second_index in range(first_index + 1, game.active_enemies.size()):
				smallest_spacing = minf(smallest_spacing, first.global_position.distance_to(game.active_enemies[second_index].global_position))
		maximum_attackers = maxi(maximum_attackers, attackers)
	check(maximum_attackers <= 1, "Multiple enemies owned the attack token during live pursuit")
	check(smallest_spacing >= 0.72, "Enemy formation collapsed into a readable-combat pileup")

	# Attack reservations and lane clearance remain separate contracts.
	var first = game.active_enemies[0]
	var second = game.active_enemies[1]
	for enemy in game.active_enemies:
		enemy.set_physics_process(false)
	game.player.set_physics_process(false)
	first.global_position = Vector3(0, 0.9, 1.2)
	second.global_position = Vector3(0, 0.9, 2.0)
	game.player.global_position = Vector3(0, 0.9, 0.0)
	check(not second.call("_attack_lane_clear"), "Rear enemy can attack through an ally")
	second.global_position = Vector3(1.6, 0.9, 1.8)
	check(second.call("_attack_lane_clear"), "Clear side attack lane is incorrectly blocked")
	check(game.call("_enemy_attack_token", first, true), "First attacker cannot claim attack token")
	check(not game.call("_enemy_attack_token", second, true), "Two enemies can attack simultaneously")
	game.call("_enemy_attack_token", first, false)

	print("AI-003 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	var result_code := 0 if failures == 0 else 1
	await finish(game)
	quit(result_code)

func _route_is_safe(service, route: Array) -> bool:
	for index in range(route.size()):
		var point: Vector3 = route[index]
		if service.is_river_excluded(point, 0.25):
			return false
		if index > 0 and not service.validate_segment(route[index - 1], point, 0.25):
			return false
	return true

func settle(frames: int) -> void:
	for _index in range(frames):
		await process_frame
		await physics_frame

func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("AI-003: %s" % message)

func finish(game: Node) -> void:
	if game != null and is_instance_valid(game):
		if game.has_method("finalize_resource_shutdown"):
			game.finalize_resource_shutdown()
		elif game.has_method("prepare_resource_shutdown"):
			game.prepare_resource_shutdown()
		await settle(int(game.ZONE_RETIRE_FRAMES) + 4)
		game.queue_free()
	await settle(24)
	if is_instance_valid(game):
		game.free()
		await settle(2)
	RenderingServer.force_sync()
