extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	# Saved-state integration fixture, not real-input route evidence.
	for covenant in ["duty", "ash"]:
		game.story_state.set_flag("final_covenant", covenant)
		game.story_state.set_flag("final_choice_completed", false)
		game.load_world_state({"pending_ending": "bind" if covenant == "duty" else "kill", "boss_states": {"white_hart_avatar": {"phase": 2, "checkpoint": 2, "checkpoint_health_ratio": 0.55, "outcome": ""}}})
		game._load_zone("hart_glade", Vector3(0, 1, 9))
		for frame in 8:
			await process_frame
		var bosses: Array = []
		for enemy in game.active_enemies:
			if is_instance_valid(enemy) and enemy.enemy_id == "white_hart_avatar":
				bosses.append(enemy)
		check(bosses.size() == 1, "Pending " + covenant + " must restore exactly one Hart")
		if bosses.size() == 1:
			check(bosses[0].get_node("BossEncounterController").phase == 2, "Checkpoint phase must restore")
			var health = bosses[0].health_component
			check(is_equal_approx(health.health / health.max_health, 0.55), "Compact checkpoint must restore its saved health ratio")
			var controller = bosses[0].get_node("BossEncounterController")
			var saved: Dictionary = controller.save_state()
			saved.health.health = health.max_health * 0.43
			controller.load_state(saved)
			check(is_equal_approx(health.health / health.max_health, 0.43), "Full health snapshot must take precedence over phase checkpoint")
		check(game.zone_root.find_child("WhiteHartWitnessDisplay", true, false) == null, "Pending fight must not retain peaceful double")
	for covenant in ["witness", "mercy", "duty", "ash"]:
		game.story_state.set_flag("final_covenant", covenant)
		game.story_state.set_flag("final_choice_completed", true)
		game.load_world_state({"pending_ending": "", "boss_states": {}})
		game._load_zone("hart_glade", Vector3(0, 1, 9))
		for frame in 8:
			await process_frame
		check(game.active_enemies.is_empty(), "Completed " + covenant + " must not restart the boss")
		check(game.zone_root.find_child("WhiteHartWitnessDisplay", true, false) == null, "Completed covenant must display aftermath")
	game.prepare_resource_shutdown()
	for frame in int(game.ZONE_RETIRE_FRAMES) + 4:
		await process_frame
	game.queue_free()
	for frame in 8:
		await process_frame
	print("HART PENDING RELOAD: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
