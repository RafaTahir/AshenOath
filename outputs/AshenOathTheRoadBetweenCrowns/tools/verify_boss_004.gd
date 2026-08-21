extends SceneTree

var failures := 0

func _initialize() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await _frames(2)
	game.settings.set_quality_preset("balanced")
	game.call("_new_game")
	await _frames(35)
	var quest_id := "main_names_they_burned"
	if not game.quests.is_active(quest_id):
		game.quests.unlocked[quest_id] = true
		game.quests.start_quest(quest_id)
	for objective_id in ["fragment_anwen", "fragment_rook", "fragment_tor", "fragment_mira", "reconstruct_register"]:
		game.quests.complete_objective(quest_id, objective_id)
	game.story_state.set_flag("rootbound_colossus_spawned", false)
	game.call("_load_zone", "deep_wood", Vector3(0, 0, 12))
	await _frames(12)
	var boss = _find_boss(game, "rootbound_colossus")
	_check(boss != null, "Rootbound Colossus did not spawn after register reconstruction")
	if boss != null:
		_check(bool(boss.get("is_boss")), "Rootbound Colossus is not marked as a boss")
		_check(boss.has_method("setup") and boss.has_method("apply_damage"), "Rootbound spawn lost its runtime actor contract")
		_check(boss.find_child("BossEncounterController", true, false) != null, "Rootbound controller is missing")
		_check(boss.find_child("RootboundBarkHarness", true, false) != null, "Rootbound bark harness is missing")
		_check(boss.find_child("RootboundHeart", true, false) != null, "Rootbound exposed heart is missing")
		_check(boss.find_child("RootboundRootArmLeft", true, false) != null and boss.find_child("RootboundRootArmRight", true, false) != null, "Rootbound root arms are incomplete")
		var controller: Node = boss.get_node_or_null("BossEncounterController")
		var maximum: float = boss.health_component.max_health
		boss.apply_damage(maximum * 0.40, "boss_verifier")
		await _frames(2)
		_check(int(boss.get("boss_phase")) == 2, "Rootbound did not enter phase two")
		var checkpoint: Dictionary = controller.save_state()
		_check(int(checkpoint.get("checkpoint", 0)) == 2, "Rootbound phase two checkpoint was not recorded")
		_check(typeof(checkpoint.get("health", {})) == TYPE_DICTIONARY and not checkpoint.get("health", {}).is_empty(), "Rootbound checkpoint omitted health")
		boss.apply_damage(maximum * 0.30, "boss_verifier")
		await _frames(2)
		_check(int(boss.get("boss_phase")) == 3, "Rootbound did not enter phase three")
		var phase_three: Dictionary = controller.save_state()
		controller.load_state(checkpoint)
		await _frames(2)
		_check(int(boss.get("boss_phase")) == 2, "Rootbound checkpoint did not restore phase two")
		_check(absf(float(boss.health_component.health) - maximum * 0.60) < 1.5, "Rootbound checkpoint did not restore health")
		controller.load_state(phase_three)
		boss.apply_damage(9999.0, "boss_verifier")
		await _frames(6)
		_check(bool(game.story_state.get_flag("rootbound_colossus_defeated", false)), "Rootbound aftermath flag was not saved")
		game.call("_load_zone", "deep_wood", Vector3(0, 0, 12))
		await _frames(12)
		_check(_find_living_boss(game, "rootbound_colossus") == null, "Defeated Rootbound respawned")
	if game.has_method("prepare_resource_shutdown"):
		game.prepare_resource_shutdown()
		await _frames(int(game.ZONE_RETIRE_FRAMES) + 4)
	game.queue_free()
	await _frames(8)
	print("BOSS-004 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _find_boss(game: Node, id: String) -> Node:
	for enemy in game.active_enemies:
		if is_instance_valid(enemy) and str(enemy.get("enemy_id")) == id:
			return enemy
	return null

func _find_living_boss(game: Node, id: String) -> Node:
	var boss := _find_boss(game, id)
	return boss if boss != null and not bool(boss.get("dead")) else null

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
