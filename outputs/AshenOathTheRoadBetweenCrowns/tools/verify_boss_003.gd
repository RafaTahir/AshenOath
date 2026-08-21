extends SceneTree

var failures := 0

func _initialize() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await _frames(2)
	game.settings.set_quality_preset("balanced")
	game.call("_new_game")
	await _frames(35)
	var quest_id := "main_bell_beneath_greyfen"
	if not game.quests.is_active(quest_id):
		game.quests.unlocked[quest_id] = true
		game.quests.start_quest(quest_id)
	for objective_id in ["meet_anwen_gate", "grave_harl", "grave_child", "grave_truth", "cemetery_ambush", "open_chapel"]:
		game.quests.complete_objective(quest_id, objective_id)
	game.story_state.set_flag("crow_chapel_opened", true)
	game.current_zone_id = "greyfen"
	game.call("_ensure_bell_eater")
	await _frames(8)
	var boss = _find_boss(game, "bell_eater")
	_check(boss != null, "Bell-Eater did not spawn after the chapel was opened")
	if boss != null:
		_check(bool(boss.get("is_boss")), "Bell-Eater is not marked as a boss")
		_check(boss.name == "BellEaterEncounter", "Bell-Eater encounter identity is missing")
		_check(boss.get_node_or_null("BossEncounterController") != null, "Bell-Eater controller is missing")
		_check(boss.find_child("BellEaterHarnessBand", true, false) != null, "Bell-Eater harness presentation is missing")
		_check(boss.find_child("BellEaterChestBell", true, false) != null, "Bell-Eater chest bell is missing")
		_check(boss.find_child("BellEaterEyeLeft", true, false) != null and boss.find_child("BellEaterEyeRight", true, false) != null, "Bell-Eater face lights are incomplete")
		var controller: Node = boss.get_node_or_null("BossEncounterController")
		var maximum: float = boss.health_component.max_health
		boss.apply_damage(maximum * 0.40, "boss_verifier")
		await _frames(2)
		_check(int(boss.get("boss_phase")) == 2, "Bell-Eater did not enter phase two")
		var checkpoint: Dictionary = controller.save_state()
		_check(int(checkpoint.get("checkpoint", 0)) == 2, "Phase two checkpoint was not recorded")
		_check(typeof(checkpoint.get("health", {})) == TYPE_DICTIONARY and not checkpoint.get("health", {}).is_empty(), "Checkpoint omitted boss health")
		boss.apply_damage(maximum * 0.30, "boss_verifier")
		await _frames(2)
		_check(int(boss.get("boss_phase")) == 3, "Bell-Eater did not enter phase three")
		var phase_three: Dictionary = controller.save_state()
		controller.load_state(checkpoint)
		await _frames(2)
		_check(int(boss.get("boss_phase")) == 2, "Bell-Eater checkpoint did not restore phase two")
		_check(absf(float(boss.health_component.health) - maximum * 0.60) < 1.5, "Bell-Eater checkpoint did not restore health")
		controller.load_state(phase_three)
		boss.apply_damage(9999.0, "boss_verifier")
		await _frames(6)
		_check(bool(game.story_state.get_flag("bell_eater_defeated", false)), "Bell-Eater aftermath flag was not saved")
		game.call("_ensure_bell_eater")
		await _frames(2)
		_check(_find_living_boss(game, "bell_eater") == null, "Defeated Bell-Eater respawned")
	if game.has_method("prepare_resource_shutdown"):
		game.prepare_resource_shutdown()
		await _frames(int(game.ZONE_RETIRE_FRAMES) + 4)
	game.queue_free()
	await _frames(8)
	print("BOSS-003 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
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
