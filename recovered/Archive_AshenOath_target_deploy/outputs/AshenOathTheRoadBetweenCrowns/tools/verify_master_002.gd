extends SceneTree

var failures := 0

func _initialize() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	check(packed != null, "Main scene is missing")
	var game = packed.instantiate(); root.add_child(game)
	await process_frame; game.call("_new_game"); await process_frame
	check(game.quests.quest_defs.size() == 20, "Complete campaign quest set is missing")
	check(game.dialogue.get_dialogue("white_hart").get("actions", []).size() == 4, "Four ending choices are missing")
	check(game.settings.settings.has("subtitle_scale") and game.settings.settings.has("camera_shake") and game.settings.settings.has("reduced_motion"), "Accessibility settings are incomplete")
	game.hud.show_inventory(game.inventory, game.quests, game.story_state)
	check(game.hud.inventory_text.text.contains("BESTIARY") and game.hud.inventory_text.text.contains("CONSEQUENCES"), "Journal integration is incomplete")
	game.hud.inventory_layer.visible = false
	var anwen = game.zone_root.find_child("sister_anwen", true, false)
	check(anwen != null and anwen.get_context_prompt().begins_with("Speak —"), "Context interaction language is missing")
	game.call("_load_zone", "wychwood", Vector3(0,1,4)); await process_frame
	check(game.active_enemies.size() == 5, "Wychwood encounter is incomplete")
	if game.active_enemies.size() >= 2:
		check(game._enemy_attack_token(game.active_enemies[0], true), "First enemy cannot claim attack token")
		check(not game._enemy_attack_token(game.active_enemies[1], true), "Two enemies can attack simultaneously")
		game._enemy_attack_token(game.active_enemies[0], false)
	check(game.player.has_method("get_beam_locked_direction"), "Oathfire direction contract is missing")
	check(game.minigames.overlay.size.x >= 700 and game.minigames.overlay.size.y >= 680, "1080p minigame presentation is missing")
	print("MASTER-002 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
