extends SceneTree

var failures := 0

func _initialize() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	check(packed != null, "Main scene is missing")
	var game = packed.instantiate(); root.add_child(game)
	if not await preload("res://tools/runtime_fixture.gd").start(game):
		quit(1)
		return
	check(game.quests.quest_defs.size() == 57, "Complete 57-quest campaign is missing")
	check(game.dialogue.get_dialogue("white_hart").get("actions", []).size() == 4, "Four ending choices are missing")
	check(game.settings.settings.has("subtitle_scale") and game.settings.settings.has("camera_shake") and game.settings.settings.has("reduced_motion"), "Accessibility settings are incomplete")
	game.hud.show_inventory(game.inventory, game.quests, game.story_state)
	var sections := preload("res://scripts/story_journal.gd").sections(game.quests, game.story_state, "greyfen")
	var ids: Array = sections.map(func(section): return str(section.id))
	check("creatures" in ids and "work" in ids, "Creature and consequence journal integration is incomplete")
	game.hud._close_inventory()
	var anwen = game.zone_root.find_child("sister_anwen", true, false)
	check(anwen != null and anwen.get_context_prompt().begins_with("Speak —"), "Context interaction language is missing")
	game.call("_load_zone", "wychwood", Vector3(0,1,4))
	if not await preload("res://tools/runtime_fixture.gd").ready(game, "wychwood"):
		quit(1)
		return
	check(game.active_enemies.size() == 5, "Wychwood encounter is incomplete")
	if game.active_enemies.size() >= 2:
		check(game._enemy_attack_token(game.active_enemies[0], true), "First enemy cannot claim attack token")
		check(not game._enemy_attack_token(game.active_enemies[1], true), "Two enemies can attack simultaneously")
		game._enemy_attack_token(game.active_enemies[0], false)
	check(game.player.has_method("get_beam_locked_direction"), "Oathfire direction contract is missing")
	game.minigames.open_game("draughts")
	check(game.minigames.board_grid.get_child_count() == 36, "Playable draughts board is incomplete")
	game.minigames.close_game()
	var result_code := 0 if failures == 0 else 1
	await _shutdown_game(game)
	print("MASTER-002 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(result_code)

func _shutdown_game(game: Node) -> void:
	if is_instance_valid(game) and game.has_method("prepare_resource_shutdown"):
		game.prepare_resource_shutdown()
		await _frames(20)
	if is_instance_valid(game) and game.has_method("finalize_resource_shutdown"):
		game.finalize_resource_shutdown()
		await _frames(12)
	print("VERIFIER_PHASE: SHUTDOWN")
	if is_instance_valid(game):
		game.queue_free()
		await _frames(8)
	RenderingServer.force_sync()
	await _frames(4)

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
