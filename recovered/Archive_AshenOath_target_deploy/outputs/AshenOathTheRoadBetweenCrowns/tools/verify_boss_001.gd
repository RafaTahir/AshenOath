extends SceneTree

var failures := 0

func _initialize() -> void:
	var contract = JSON.parse_string(FileAccess.get_file_as_string("res://white_hart_encounter_contract.json"))
	check(typeof(contract) == TYPE_DICTIONARY, "BOSS-001 contract is invalid")
	check(contract.get("combat_endings", []).size() == 2, "Boss contract must have two combat endings")
	check(contract.get("peaceful_endings", []).size() == 2, "Boss contract must preserve two peaceful endings")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.settings.set_quality_preset("balanced")
	game.call("_new_game")
	await settle(3)
	game.quests.unlocked["main_hart_remembers"] = true
	game.quests.start_quest("main_hart_remembers")
	game.story_state.set_flag("confession_method", "witnesses")
	game.call("_load_zone", "hart_glade", Vector3(0, 1, 9))
	await settle(3)
	game.call("_complete_ending", "bind")
	await settle(3)
	var boss = game.zone_root.find_child("WhiteHartFinalEncounter", true, false)
	check(boss != null, "Duty ending did not create the White Hart encounter")
	check(str(game.pending_ending) == "bind", "Combat ending handoff was not retained")
	if boss != null:
		check(boss.leash_radius == 10.0, "White Hart leash is unsafe")
		var maximum: float = boss.health_component.max_health
		boss.apply_damage(maximum * 0.40, "boss_verifier")
		await settle(2)
		check(boss.boss_phase == 2, "White Hart did not enter phase two")
		boss.apply_damage(maximum * 0.30, "boss_verifier")
		await settle(2)
		check(boss.boss_phase == 3, "White Hart did not enter phase three")
		boss.apply_damage(9999.0, "boss_verifier")
		await settle(4)
	check(str(game.story_state.get_flag("final_covenant", "")) == "duty", "Duty covenant was not persisted")
	check(game.quests.is_completed("main_hart_remembers"), "Boss victory did not complete the finale")
	check(str(game.pending_ending) == "", "Pending ending was not cleaned up")
	print("BOSS-001 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func settle(count: int) -> void:
	for _index in range(count):
		await process_frame

func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
