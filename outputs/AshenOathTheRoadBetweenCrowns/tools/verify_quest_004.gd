extends SceneTree

var failures := 0

func _initialize() -> void:
	var contract = JSON.parse_string(FileAccess.get_file_as_string("res://blood_under_stone_contract.json"))
	check(typeof(contract) == TYPE_DICTIONARY, "QUEST-004 contract is invalid")
	check(int(contract.get("evidence_group", {}).get("required", 0)) == 3, "Castle evidence threshold must be three")
	var scene = load("res://scenes/main.tscn")
	check(scene != null, "Main scene is missing")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.settings.set_quality_preset("balanced")
	game.call("_new_game")
	await settle(3)
	game.call("_load_zone", "vargan_approach", Vector3(0, 1, 8))
	await settle(3)
	check(game.quests.is_active("main_blood_under_stone"), "Blood Under Stone did not start")

	for id in ["evidence_supply_cart", "evidence_mile_marker"]:
		game.quests.complete_evidence("main_blood_under_stone", id)
	check(not game.quests.is_objective_done("main_blood_under_stone", "castle_evidence_ready"), "Castle evidence completed before threshold")
	game.quests.complete_evidence("main_blood_under_stone", "evidence_gate_notice")
	check(game.quests.is_objective_done("main_blood_under_stone", "castle_evidence_ready"), "Castle evidence did not complete at threshold")

	game.call("_load_zone", "vargan_court", Vector3(0, 1, 8))
	await settle(3)
	var guard_dialogue = game.dialogue.get_dialogue("vargan_gate_guard")
	game.call("_handle_dialogue_action", guard_dialogue["actions"][0])
	await settle(2)
	game.call("_load_zone", "record_hall", Vector3(0, 1, 8))
	await settle(3)
	var ledger = game.dialogue.get_dialogue("vargan_ledger_choice")
	check(ledger.get("actions", []).size() == 3, "Ledger does not offer three choices")
	var ledger_area = game.zone_root.find_child("vargan_ledger_choice", true, false)
	if ledger_area != null:
		game.call("_handle_interaction", ledger_area)
	game.call("_handle_dialogue_action", ledger["actions"][2])
	await settle(3)
	check(bool(game.story_state.get_flag("vargan_ledger_left_copied", false)), "Ledger copy choice was not persisted")
	var haunting = game.zone_root.find_child("RecordHallHaunting", true, false)
	check(haunting != null, "Ledger choice did not awaken the Record Hall haunting")
	if haunting != null:
		haunting.apply_damage(9999.0, "quest_004_verifier")
		await settle(5)
	check(game.quests.is_objective_done("main_blood_under_stone", "survive_haunting"), "Haunting victory did not update the quest")
	check(not game.quests.is_completed("main_blood_under_stone"), "Quest completed before Edric's explicit choice")
	var edric = game.zone_root.find_child("edric_campaign", true, false)
	check(edric != null, "Edric confrontation did not appear after the haunting")
	var answer = game.dialogue.get_dialogue("edric_campaign")
	check(answer.get("actions", []).size() == 3, "Edric does not offer three consequence choices")
	game.call("_handle_dialogue_action", answer["actions"][0])
	await settle(3)
	check(str(game.story_state.get_flag("edric_stance", "")) == "cooperate", "Edric stance was not stored")
	check(game.quests.is_completed("main_blood_under_stone"), "Blood Under Stone did not complete after Edric's answer")
	check(game.quests.is_active("main_last_witness") or game.quests.is_unlocked("main_last_witness"), "The Last Witness did not unlock")
	print("QUEST-004 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func settle(count: int) -> void:
	for _index in range(count):
		await process_frame

func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
