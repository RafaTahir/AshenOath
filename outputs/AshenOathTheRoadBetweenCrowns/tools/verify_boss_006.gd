extends SceneTree

var failures := 0

func _initialize() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await _frames(2)
	game.settings.set_quality_preset("balanced")
	game.call("_new_game")
	await _frames(35)
	var quest_id := "main_last_witness"
	if not game.quests.is_active(quest_id):
		game.quests.unlocked[quest_id] = true
		game.quests.start_quest(quest_id)
	game.quests.complete_objective(quest_id, "reach_undercroft")
	game.story_state.set_flag("halvern_fate", "")
	game.story_state.set_flag("halvern_guard_broken", false)
	game.call("_load_zone", "undercroft", Vector3(0, 1, 12))
	await _frames(16)
	var boss = _find_boss(game, "halvern_boss")
	_check(boss != null, "Halvern did not spawn in the undercroft")
	if boss != null:
		_check(bool(boss.get("is_boss")), "Halvern is not marked as a boss")
		_check(boss.find_child("BossEncounterController", true, false) != null, "Halvern controller is missing")
		_check(boss.find_child("HalvernVarganCuirass", true, false) != null, "Halvern Vargan cuirass is missing")
		_check(boss.find_child("HalvernGraveSeal", true, false) != null, "Halvern grave seal is missing")
		_check(boss.find_child("HalvernShoulderLeft", true, false) != null and boss.find_child("HalvernShoulderRight", true, false) != null, "Halvern shoulder identity is incomplete")
		_check(boss.find_child("HalvernBrokenBanner", true, false) != null, "Halvern broken banner is missing")
		_check(boss.find_child("CharacterAnimationDriver", true, false) != null, "Halvern animation driver is missing")
		game.player.global_position = Vector3(0, 1.0, -4.0)
		game.player.velocity = Vector3.ZERO
		boss.global_position = Vector3(0, 1.0, -5.5)
		boss.windup_time = 0.48
		boss.attack_trace_start = boss.global_position + Vector3(0, 0.9, 0)
		boss.attack_trace_end = game.player.global_position + Vector3(0, 0.9, 0)
		game.player.parry_window = game.player.get_parry_window_duration()
		var player_health := float(game.player.health_component.health)
		boss.call("_resolve_attack")
		await _frames(2)
		_check(absf(float(game.player.health_component.health) - player_health) < 0.01, "Halvern parry still damaged Kael")
		_check(float(boss.get("parry_exposed_time")) > 0.0, "Halvern did not open a parry punish window")
		_check(bool(game.story_state.get_flag("halvern_guard_broken", false)), "Halvern guard break flag was not recorded")
		_check(game.quests.is_objective_done(quest_id, "break_halvern_guard"), "Halvern guard-break objective did not complete from a real parry")
		var maximum: float = boss.health_component.max_health
		boss.apply_damage(maximum * 0.55, "boss_verifier")
		await _frames(2)
		_check(int(boss.get("boss_phase")) == 2, "Halvern did not enter the refusal phase")
		var controller: Node = boss.get_node_or_null("BossEncounterController")
		var checkpoint: Dictionary = controller.save_state()
		_check(int(checkpoint.get("checkpoint", 0)) == 2, "Halvern phase two checkpoint was not recorded")
		var checkpoint_health := float(checkpoint.get("health", {}).get("health", 0.0))
		controller.load_state({"phase": 1, "checkpoint": 1, "health": {"health": maximum, "max_health": maximum, "dead": false}})
		await _frames(2)
		_check(int(boss.get("boss_phase")) == 1, "Halvern phase reset failed")
		controller.load_state(checkpoint)
		await _frames(2)
		_check(int(boss.get("boss_phase")) == 2, "Halvern checkpoint did not restore phase two")
		_check(absf(float(boss.health_component.health) - checkpoint_health) < 1.5, "Halvern checkpoint did not restore health")
		_check(controller.can_peaceful_resolve(), "Halvern does not expose a peaceful resolution contract")
		_check(controller.resolve_peaceful("testimony"), "Halvern testimony resolution failed")
		await _frames(3)
		_check(str(game.story_state.get_flag("halvern_fate", "")) == "witness", "Halvern testimony did not set witness fate")
		_check(not boss.is_encounter_active(), "Halvern remained active after testimony")
		game.call("_load_zone", "undercroft", Vector3(0, 1, 12))
		await _frames(16)
		_check(_find_living_boss(game, "halvern_boss") == null, "Resolved Halvern respawned after reload")
	if game.has_method("prepare_resource_shutdown"):
		game.prepare_resource_shutdown()
		await _frames(int(game.ZONE_RETIRE_FRAMES) + 4)
	game.queue_free()
	await _frames(8)
	print("BOSS-006 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
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
