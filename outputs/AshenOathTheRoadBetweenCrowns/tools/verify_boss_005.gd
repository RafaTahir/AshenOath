extends SceneTree

var failures := 0

func _initialize() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await _frames(2)
	game.settings.set_quality_preset("balanced")
	game.call("_new_game")
	await _frames(35)
	var quest_id := "main_ash_at_the_mill"
	if not game.quests.is_active(quest_id):
		game.quests.unlocked[quest_id] = true
		game.quests.start_quest(quest_id)
	for objective_id in ["reach_mill", "inspect_millstones", "mill_encounter"]:
		game.quests.complete_objective(quest_id, objective_id)
	game.story_state.set_flag("ashwing_spawned", false)
	game.story_state.set_flag("ashwing_defeated", false)
	game.call("_load_zone", "old_mill", Vector3(0, 0, 12))
	await _frames(16)
	var boss = _find_boss(game, "ashwing")
	_check(boss != null, "Ashwing did not spawn after the ash-bound mill encounter")
	if boss != null:
		_check(bool(boss.get("is_boss")), "Ashwing is not marked as a boss")
		_check(boss.has_method("setup") and boss.has_method("apply_damage"), "Ashwing lost its runtime actor contract")
		_check(boss.find_child("BossEncounterController", true, false) != null, "Ashwing controller is missing")
		_check(boss.find_child("AshwingBurntHarness", true, false) != null, "Ashwing burnt harness is missing")
		_check(boss.find_child("AshwingAshCore", true, false) != null, "Ashwing ash core is missing")
		_check(boss.find_child("AshwingScorchedWingRootLeft", true, false) != null and boss.find_child("AshwingScorchedWingRootRight", true, false) != null, "Ashwing scorched wing roots are incomplete")
		_check(boss.find_child("CharacterAnimationDriver", true, false) != null, "Ashwing animation driver is missing")
		game.player.global_position = Vector3(0, 1.0, -5.8)
		game.player.velocity = Vector3.ZERO
		boss.global_position = Vector3(0, 1.0, -9.0)
		boss.windup_time = 1.0
		game.call("_on_player_beam", 1.0, Vector3(0, 0, -1))
		await _frames(2)
		_check(float(boss.get("windup_time")) <= 0.0, "Oathfire did not cancel Ashwing breath windup")
		_check(float(boss.get("stagger_time")) > 0.0, "Ashwing did not enter stagger after Oathfire interruption")
		_check(str(boss.get_meta("last_boss_interrupt", "")) == "oathfire", "Ashwing interruption did not record Oathfire reason")
		var maximum: float = boss.health_component.max_health
		# The cast above is an oathfire weakness hit, so its 15-point bonus is
		# intentionally included before the phase checkpoint damage.
		boss.apply_damage(maximum * 0.18, "boss_verifier")
		await _frames(2)
		_check(int(boss.get("boss_phase")) == 2, "Ashwing did not enter phase two")
		var controller: Node = boss.get_node_or_null("BossEncounterController")
		var checkpoint: Dictionary = controller.save_state()
		_check(int(checkpoint.get("checkpoint", 0)) == 2, "Ashwing phase two checkpoint was not recorded")
		_check(typeof(checkpoint.get("health", {})) == TYPE_DICTIONARY and not checkpoint.get("health", {}).is_empty(), "Ashwing checkpoint omitted health")
		boss.apply_damage(maximum * 0.25, "boss_verifier")
		await _frames(2)
		_check(int(boss.get("boss_phase")) == 3, "Ashwing did not enter phase three")
		var phase_three: Dictionary = controller.save_state()
		controller.load_state(checkpoint)
		await _frames(2)
		_check(int(boss.get("boss_phase")) == 2, "Ashwing checkpoint did not restore phase two")
		var checkpoint_health := float(checkpoint.get("health", {}).get("health", 0.0))
		_check(absf(float(boss.health_component.health) - checkpoint_health) < 1.5, "Ashwing checkpoint did not restore health")
		controller.load_state(phase_three)
		boss.apply_damage(9999.0, "boss_verifier")
		await _frames(6)
		_check(bool(game.story_state.get_flag("ashwing_defeated", false)), "Ashwing aftermath flag was not saved")
		game.call("_load_zone", "old_mill", Vector3(0, 0, 12))
		await _frames(16)
		_check(_find_living_boss(game, "ashwing") == null, "Defeated Ashwing respawned")
	if game.has_method("prepare_resource_shutdown"):
		game.prepare_resource_shutdown()
		await _frames(int(game.ZONE_RETIRE_FRAMES) + 4)
	game.queue_free()
	await _frames(8)
	print("BOSS-005 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _find_boss(game: Node, id: String) -> Node:
	for enemy in game.active_enemies:
		if is_instance_valid(enemy) and str(enemy.get("enemy_id")) == id and not bool(enemy.get("dead")):
			return enemy
	return null

func _find_living_boss(game: Node, id: String) -> Node:
	return _find_boss(game, id)

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
