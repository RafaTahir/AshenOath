extends SceneTree

var failures := 0

func _initialize() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await _frames(2)
	game.settings.set_quality_preset("balanced")
	game.call("_new_game")
	await _frames(40)

	var quest_id := "main_hart_remembers"
	if not game.quests.is_active(quest_id):
		game.quests.unlocked[quest_id] = true
		game.quests.start_quest(quest_id)
	game.story_state.set_flag("confession_method", "witnesses")
	game.story_state.set_flag("final_choice_completed", false)
	game.story_state.set_flag("final_covenant", "")
	game.story_state.set_flag("halvern_fate", "witness")
	game.call("_load_zone", "hart_glade", Vector3(0, 1, 9))
	await _frames(20)
	game.call("_complete_ending", "bind")
	await _frames(20)

	var boss := _find_boss(game, "white_hart_avatar")
	_check(boss != null, "White Hart did not spawn for the duty encounter")
	if boss != null:
		_check(bool(boss.get("is_boss")), "White Hart is not marked as a boss")
		_check(float(boss.leash_radius) == 10.0, "White Hart leash is unsafe")
		_check(boss.find_child("BossEncounterController", true, false) != null, "White Hart controller is missing")
		_check(boss.find_child("WhiteHartMemoryHalo", true, false) != null, "White Hart memory halo is missing")
		_check(boss.find_child("WhiteHartOathMark", true, false) != null, "White Hart oath mark is missing")
		_check(boss.find_child("WhiteHartMemoryRingLeft", true, false) != null and boss.find_child("WhiteHartMemoryRingRight", true, false) != null, "White Hart memory rings are incomplete")
		_check(boss.find_child("WhiteHartAntlerHeadAttachment", true, false) != null, "White Hart antler attachment is missing")
		_check(boss.find_child("CharacterAnimationDriver", true, false) != null, "White Hart animation driver is missing")

		var controller: Node = boss.get_node_or_null("BossEncounterController")
		_check(controller != null and controller.can_peaceful_resolve(), "White Hart peaceful resolution contract is missing")
		var maximum: float = boss.health_component.max_health
		boss.apply_damage(maximum * 0.40, "boss_verifier")
		await _frames(3)
		_check(int(boss.get("boss_phase")) == 2, "White Hart did not enter the Mercy phase")
		var checkpoint: Dictionary = controller.save_state()
		_check(int(checkpoint.get("checkpoint", 0)) == 2, "White Hart phase-two checkpoint was not recorded")
		boss.apply_damage(maximum * 0.30, "boss_verifier")
		await _frames(3)
		_check(int(boss.get("boss_phase")) == 3, "White Hart did not enter the Debt phase")
		controller.load_state({"phase": 1, "checkpoint": 1, "health": {"health": maximum, "max_health": maximum, "dead": false}})
		await _frames(2)
		_check(int(boss.get("boss_phase")) == 1, "White Hart phase reset failed")
		controller.load_state(checkpoint)
		await _frames(2)
		_check(int(boss.get("boss_phase")) == 2, "White Hart checkpoint did not restore phase two")

		_check(controller.resolve_peaceful("mercy"), "White Hart Mercy resolution failed")
		await _frames(4)
		_check(str(game.story_state.get_flag("final_covenant", "")) == "mercy", "Mercy covenant was not persisted")
		_check(bool(game.story_state.get_flag("final_choice_completed", false)), "Final choice flag was not persisted")
		_check(game.quests.is_objective_done(quest_id, "final_choice") or game.quests.is_completed(quest_id), "Final choice objective did not complete")
		_check(not boss.is_encounter_active(), "Resolved White Hart remained active")
		game.call("_load_zone", "hart_glade", Vector3(0, 1, 9))
		await _frames(20)
		_check(_find_living_boss(game, "white_hart_avatar") == null, "Resolved White Hart respawned after reload")

	if game.has_method("prepare_resource_shutdown"):
		game.prepare_resource_shutdown()
		await _frames(int(game.ZONE_RETIRE_FRAMES) + 4)
	game.queue_free()
	await _frames(8)
	print("BOSS-007 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
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
