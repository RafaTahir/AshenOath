extends SceneTree

var failures := 0

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	check(scene != null, "Main scene missing")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_new_game")
	await settle(4)
	game.call("_load_zone", "wychwood", Vector3(0, 0.9, 8.0))
	await settle(8)

	check(game.active_enemies.size() == 5, "Wychwood encounter must contain five enemies")
	var profiles := {}
	var active_count := 0
	for enemy in game.active_enemies:
		profiles[enemy.behavior_profile] = true
		active_count += 1 if enemy.encounter_active else 0
		check(enemy.navigation_agent is NavigationAgent3D, "%s lacks navigation" % enemy.display_name)
		check(enemy.preferred_distance >= 2.0, "%s has no authored engagement radius" % enemy.display_name)
		check(enemy.animation_driver != null and enemy.animation_driver.is_valid(), "%s lacks a valid animated rig" % enemy.display_name)
		check(enemy.attack_contact_bone >= 0, "%s has no rig contact source" % enemy.display_name)
		enemy.call("_attack_contact_point")
		check(enemy.attack_trace_uses_skeleton, "%s attack contact does not come from its skeleton" % enemy.display_name)
		var route: Array = game.spatial_service.build_route(enemy.global_position, enemy.call("_engagement_target"), 0.55)
		check(not route.is_empty(), "%s cannot route to its engagement lane" % enemy.display_name)
	check(profiles.has("skirmisher") and profiles.has("flanker") and profiles.has("feinter") and profiles.has("brute"), "Wychwood roles are not visibly distinct")
	check(active_count == 0, "Wychwood enemies activate before Kael reaches the authored reveal")
	game.player.global_position = Vector3(0, 0.9, 0.0)
	game.call("_update_tutorial_prompts")
	await settle(2)
	active_count = 0
	for enemy in game.active_enemies:
		active_count += 1 if enemy.encounter_active else 0
	check(active_count == 1, "Wychwood reveal must activate one enemy, not a five-enemy pileup")
	for enemy in game.active_enemies:
		enemy.set_encounter_active(true)
	var smallest_spacing := INF
	var maximum_attackers := 0
	for _frame in range(90):
		await physics_frame
		var attackers := 0
		for first_index in range(game.active_enemies.size()):
			var sampled = game.active_enemies[first_index]
			attackers += 1 if sampled.owns_attack_token else 0
			check(not game.spatial_service.is_river_excluded(sampled.global_position, 0.3), "%s entered river space during pursuit" % sampled.display_name)
			for second_index in range(first_index + 1, game.active_enemies.size()):
				smallest_spacing = minf(smallest_spacing, sampled.global_position.distance_to(game.active_enemies[second_index].global_position))
		maximum_attackers = maxi(maximum_attackers, attackers)
	check(maximum_attackers <= 1, "Multiple enemies owned the attack token during live pursuit")
	check(smallest_spacing >= 0.72, "Enemy formation collapsed into an unreadable pileup")

	var first = game.active_enemies[0]
	var second = game.active_enemies[1]
	first.set_encounter_active(true)
	second.set_encounter_active(true)
	first.set_physics_process(false)
	second.set_physics_process(false)
	game.player.set_physics_process(false)
	if game.active_enemy_attacker != null:
		game.call("_enemy_attack_token", game.active_enemy_attacker, false)
	game.player.global_position = Vector3(0, 0.9, 0)
	first.global_position = Vector3(0, 0.9, 1.2)
	second.global_position = Vector3(0, 0.9, 2.0)
	check(not second.call("_attack_lane_clear"), "Rear enemy can attack through an ally")
	second.global_position = Vector3(1.6, 0.9, 1.8)
	check(second.call("_attack_lane_clear"), "Clear side attack lane is incorrectly blocked")
	check(game.call("_enemy_attack_token", first, true), "First attacker cannot claim the attack token")
	check(not game.call("_enemy_attack_token", second, true), "Two enemies can attack simultaneously")
	game.call("_enemy_attack_token", first, false)

	first.look_at(Vector3(game.player.global_position.x, first.global_position.y, game.player.global_position.z), Vector3.UP)
	first.attack_trace_start = first.call("_attack_contact_point")
	var animation_player: AnimationPlayer = first.animation_driver.get_animation_player()
	var attack_clip: StringName = first.animation_driver.get_clip_for_state("attack")
	check(attack_clip != StringName(), "Enemy attack clip is unresolved")
	if animation_player != null and attack_clip != StringName():
		animation_player.stop()
		animation_player.play(attack_clip)
		# Manual animation players do not reliably apply an advance immediately
		# after play in a headless tick. Seek samples the same authored clip at a
		# deterministic windup time without changing gameplay timing.
		animation_player.seek(0.0, true)
		animation_player.seek(0.18, true)
	first.attack_trace_end = first.call("_attack_contact_point")
	var trace: Dictionary = first.get_attack_trace()
	var trace_start: Vector3 = trace.get("start", Vector3.ZERO)
	var trace_end: Vector3 = trace.get("end", Vector3.ZERO)
	check(bool(trace.get("uses_skeleton", false)), "Enemy trace is not skeleton-authored")
	check(trace_start.distance_to(trace_end) > 0.04, "Enemy attack clip produces no measured hand motion")

	print("AI-001 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func settle(count: int) -> void:
	for _index in range(count):
		await process_frame

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
