extends SceneTree

var failures := 0

func _initialize() -> void:
	var scene = load("res://scenes/main.tscn")
	check(scene != null, "Main scene is missing")
	if scene == null: quit(1); return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	# Castle population coverage is defined for the Balanced release preset, not a
	# player's persisted Potato preference.
	game.settings.set_quality_preset("balanced")
	game.call("_new_game")
	await settle(4)
	check(game.quests.quest_defs.has("main_blood_under_stone"), "Blood Under Stone quest is missing")
	var required := ["reach_castle", "speak_guard", "enter_courtyard", "castle_evidence_ready", "locate_record_hall", "recover_ledger", "ledger_choice", "survive_haunting", "last_witness_hook"]
	var ids: Array = []
	for objective in game.quests.quest_defs["main_blood_under_stone"]["objectives"]: ids.append(str(objective["id"]))
	for id in required: check(id in ids, "Missing Blood Under Stone objective: %s" % id)

	game.call("_load_zone", "greyfen", Vector3(0, 1, 7))
	await settle(3)
	var fresh_gate = game.zone_root.find_child("gate_vargan_approach", true, false)
	check(fresh_gate != null, "Fresh New Game castle route is missing")
	if fresh_gate != null: game.call("_handle_interaction", fresh_gate)
	await settle(3)
	check(game.current_zone_id == "vargan_approach", "Fresh New Game could not enter Castle Vargan")
	check(game.quests.is_active("main_blood_under_stone"), "Castle entry did not start Blood Under Stone")

	check(game.zone_root.find_child("CastleVargan_Approach", true, false) != null, "Castle Approach is missing")
	check(game.zone_root.find_child("VarganGatehouse", true, false) != null, "Outer gatehouse is missing")
	for id in ["vargan_mile_marker", "vargan_supply_cart"]:
		var evidence = game.zone_root.find_child(id, true, false)
		check(evidence != null, "Missing approach evidence: %s" % id)
		if evidence != null: game.call("_handle_interaction", evidence)

	game.call("_load_zone", "vargan_court", Vector3(0, 1, 12))
	await settle(3)
	check(game.zone_root.find_child("CastleVargan_OuterCourtyard", true, false) != null, "Outer Courtyard is missing")
	for id in ["vargan_gate_guard", "vargan_steward", "vargan_gate_notice", "vargan_iron_binding"]: check(game.zone_root.find_child(id, true, false) != null, "Missing courtyard actor/evidence: %s" % id)
	check(game.zone_root.find_child("CastleGuardPatrolRoutine", true, false) != null, "Castle patrol routine is missing in Balanced mode")
	game.call("_handle_dialogue_action", game.dialogue.get_dialogue("vargan_gate_guard")["actions"][0])
	for id in ["vargan_gate_notice", "vargan_iron_binding"]:
		var evidence = game.zone_root.find_child(id, true, false)
		if evidence != null: game.call("_handle_interaction", evidence)

	game.call("_load_zone", "record_hall", Vector3(0, 1, 12))
	await settle(3)
	check(game.zone_root.find_child("CastleVargan_RecordHall", true, false) != null, "Record Hall is missing")
	for id in ["vargan_record_keeper", "edric_castle", "vargan_ledger_choice"]: check(game.zone_root.find_child(id, true, false) != null, "Missing record-hall interaction: %s" % id)
	for id in ["vargan_gate_guard", "vargan_steward", "vargan_servant", "vargan_patrol", "vargan_record_keeper", "edric_castle", "vargan_ledger_choice"]: check(game.dialogue.dialogues.has(id), "Missing castle dialogue: %s" % id)

	var ledger = game.dialogue.get_dialogue("vargan_ledger_choice")
	check(ledger.get("actions", []).size() == 3, "Ledger must expose three choices")
	var ledger_area = game.zone_root.find_child("vargan_ledger_choice", true, false)
	if ledger_area != null:
		game.call("_handle_interaction", ledger_area)
	game.call("_handle_dialogue_action", ledger["actions"][1])
	await settle(4)
	check(bool(game.story_state.get_flag("vargan_ledger_hidden", false)), "Ledger choice flag was not stored")
	check(bool(game.story_state.get_flag("vargan_ledger_choice_made", false)), "Ledger choice completion flag was not stored")
	var haunting = game.zone_root.find_child("RecordHallHaunting", true, false)
	check(haunting != null, "Record Hall haunting did not spawn after ledger choice")
	if haunting != null:
		haunting.apply_damage(9999.0, "verifier")
		await settle(4)
	check(bool(game.story_state.get_flag("castle_haunting_cleared", false)), "Haunting completion was not saved")
	check(game.quests.is_completed("main_blood_under_stone"), "Blood Under Stone did not complete")
	check(game.quests.is_active("main_last_witness") or game.quests.is_completed("main_last_witness"), "The Last Witness did not unlock")

	var saved: Dictionary = game.story_state.save_state()
	game.story_state.load_state(saved)
	check(bool(game.story_state.get_flag("castle_haunting_cleared", false)), "Castle state failed save/load round-trip")
	print("CASTLE VARGAN VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func settle(count: int) -> void:
	for i in range(count): await process_frame

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
