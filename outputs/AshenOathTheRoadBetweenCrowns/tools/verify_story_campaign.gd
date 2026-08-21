extends SceneTree

const StoryState = preload("res://scripts/story_state.gd")
const QuestManager = preload("res://scripts/quest_manager.gd")
const DialogueManager = preload("res://scripts/dialogue_manager.gd")

var failures := 0

func _initialize() -> void:
	var state = StoryState.new(); root.add_child(state)
	state.adjust_value("anwen_trust", 99); state.adjust_value("greyfen_fear", -99); state.adjust_value("hart_debt", 99)
	check(state.values == {"anwen_trust":3,"greyfen_fear":0,"hart_debt":6}, "Story values do not clamp")
	state.set_flag("names_policy", "published")
	check(state.matches({"names_policy":"published","anwen_trust":{"min":2}}), "Story conditions do not match")
	var saved := state.save_state(); var restored = StoryState.new(); root.add_child(restored); restored.load_state(saved)
	check(restored.get_flag("names_policy") == "published" and restored.values == state.values, "Story state round trip failed")

	var quests = QuestManager.new(); root.add_child(quests); quests.load_quests("res://data/quests.json")
	check(quests.quest_defs.size() == 20, "Expected ten main and ten side quests")
	var main_count := 0; var side_count := 0
	for id in quests.quest_defs:
		if quests.quest_defs[id].get("type") == "main": main_count += 1
		else: side_count += 1
	check(main_count == 10 and side_count == 10, "Quest type counts are wrong")
	for id in quests.quest_defs:
		quests.unlocked[id] = true
		if str(quests.quest_defs[id].get("type", "")) == "side" and not quests.is_runtime_content_ready(str(id)):
			check(not quests.start_quest(str(id)), "%s started before runtime support" % id)
			continue
		if not quests.is_active(id) and not quests.is_completed(id): quests.start_quest(id)
		if quests.is_active(id):
			for objective in quests.active[id]["objectives"].duplicate(true): quests.complete_objective(id, str(objective["id"]))
		check(quests.is_completed(id), "%s cannot complete" % id)

	var dialogue = DialogueManager.new(); root.add_child(dialogue); dialogue.setup(state)
	dialogue.load_dialogue("res://data/dialogue.json"); dialogue.load_dialogue("res://data/campaign_dialogue.json")
	for id in ["captain_senn","halvern","edric_campaign","assembly_choice","white_hart","crow_shrine_choice"]:
		check(dialogue.dialogues.has(id), "Missing campaign dialogue: %s" % id)
	check(dialogue.get_dialogue("white_hart").get("actions", []).size() == 4, "Four endings are not offered")

	var scene = load("res://scenes/main.tscn"); var game = scene.instantiate(); root.add_child(game)
	await process_frame; game.call("_new_game"); await process_frame
	for zone in ["deep_wood","old_mill","burned_farmstead","marsh_crossing","bandit_road","vargan_approach","vargan_court","record_hall","undercroft","assembly","hart_glade"]:
		game.call("_load_zone",zone,Vector3(0,1,12)); await process_frame
		var marker = game.zone_root.find_child("CampaignSection_%s" % zone,true,false)
		if zone == "vargan_approach": marker = game.zone_root.find_child("CastleVargan_Approach",true,false)
		elif zone == "vargan_court": marker = game.zone_root.find_child("CastleVargan_OuterCourtyard",true,false)
		elif zone == "record_hall": marker = game.zone_root.find_child("CastleVargan_RecordHall",true,false)
		check(game.current_zone_id == zone and marker != null, "Campaign zone failed: %s" % zone)

	print("STORY CAMPAIGN VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
