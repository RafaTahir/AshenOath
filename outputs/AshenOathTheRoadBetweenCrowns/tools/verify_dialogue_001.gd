extends SceneTree

const StoryState = preload("res://scripts/story_state.gd")
const DialogueManager = preload("res://scripts/dialogue_manager.gd")
var failures := 0

func _initialize() -> void:
	var state = StoryState.new()
	root.add_child(state)
	var manager = DialogueManager.new()
	root.add_child(manager)
	manager.setup(state)
	manager.load_dialogue("res://data/dialogue.json")
	if "--opening-purpose-only" in OS.get_cmdline_user_args():
		verify_opening_purpose(manager, state)
		print("OPENING PURPOSE: %s (clue order, omitted facts, report choices, consent, once-only completion, saved history, north-road guidance)" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
		quit(0 if failures == 0 else 1)
		return
	var speaker_names := {
		"Mira Fen": "mira", "Lord Edric Vargan": "edric", "Sir Halvern": "halvern",
		"The Returned Soldier": "returned_soldier", "Steward Merrow": "vargan_steward",
		"Tired Castle Servant": "vargan_servant", "Vargan Patrol Guard": "vargan_patrol",
		"Record Keeper Vale": "vargan_record_keeper", "Kael": "player",
		"Sister Anwen": "sister_anwen", "The White Hart": "white_hart",
	}
	for display_name: String in speaker_names:
		var binding_pages: Array = manager._build_pages({"name": display_name, "greeting": "Greeting", "lines": [display_name + ": Reply"]})
		check(binding_pages.all(func(page): return str(page.speaker_id) == str(speaker_names[display_name])), "Speaker binding changed between greeting/reply for " + display_name)
	if "--speaker-bindings-only" in OS.get_cmdline_user_args():
		print("DIALOGUE SPEAKER BINDINGS: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
		quit(0 if failures == 0 else 1)
		return
	var anwen: Dictionary = manager.get_dialogue("sister_anwen")
	var pages: Array = anwen.get("pages", [])
	check(pages.size() >= 4, "Anwen conversation has no complete speaker-aware page sequence")
	check(pages.any(func(page): return str(page.get("speaker", "")) == "Kael"), "Kael's reply is not attributed to Kael")
	check(pages.any(func(page): return str(page.get("speaker", "")) == "Sister Anwen"), "Anwen's reply is not attributed to Anwen")
	state.set_flag("evidence_report", "private")
	var report: Dictionary = manager.get_dialogue("sister_anwen")
	var expected: Dictionary = {}
	for variant in manager.dialogues.sister_anwen.variants:
		if variant.get("conditions", {}).get("evidence_report", "") == "private":
			expected = variant
	check(not expected.is_empty() and str(report.pages[0].text) == str(expected.greeting), "Highest-priority matching Anwen variant was not selected")
	var rook: Dictionary = manager.get_dialogue("rook")
	check(rook.actions.any(func(action): return action.get("sets_flags", {}).get("rook_supplies_taken", false) == true), "Rook's one-time supplies are unavailable initially")
	state.set_flag("rook_supplies_taken", true)
	rook = manager.get_dialogue("rook")
	check(not rook.actions.any(func(action): return action.get("sets_flags", {}).get("rook_supplies_taken", false) == true), "Rook's one-time supplies can be claimed repeatedly")
	var contract = JSON.parse_string(FileAccess.get_file_as_string("res://dialogue_contract.json"))
	check(typeof(contract) == TYPE_DICTIONARY and bool(contract.get("speaker_aware_pages", false)), "Dialogue contract is invalid")
	print("DIALOGUE-001 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func verify_opening_purpose(manager: Node, state: Node) -> void:
	const QuestManager = preload("res://scripts/quest_manager.gd")
	const Route = preload("res://scripts/story_route_catalog.gd")
	const Beat = preload("res://scripts/quest_beat_director.gd")
	const Presentation = preload("res://scripts/quest_presentation_state.gd")
	manager.load_dialogue("res://data/campaign_dialogue.json")
	manager.load_dialogue("res://data/interaction_scenes.json")
	var care: Dictionary = manager.get_dialogue("opening_care_invitation")
	check(str(care.actions[0].type) == "opening_care_account", "Road account is hidden behind optional care")
	check(care.actions.any(func(action): return str(action.type) == "opening_care_resume"), "Optional care was removed")
	var new_quests := QuestManager.new()
	root.add_child(new_quests)
	new_quests.load_quests("res://data/quests.json")
	manager.setup(state, new_quests)
	check(new_quests.quest_defs.size() == 57, "Opening change altered the quest count")
	new_quests.start_quest("main_road_of_crows")
	var intro: Dictionary = manager.get_dialogue("sister_anwen")
	check(intro.pages.any(func(page): return "north road into Wychwood" in str(page.text)), "Anwen does not name the route")
	check(not intro.actions.any(func(action): return str(action.get("type", "")) == "complete_objective"), "Already-earned interview still offers a disabled duplicate action")
	new_quests.complete_objective("main_road_of_crows", "speak_anwen")
	var beats := Beat.new()
	var presentation := Presentation.new()
	root.add_child(beats)
	root.add_child(presentation)
	beats.setup(new_quests, state)
	presentation.setup(new_quests, beats)
	presentation.set_zone("greyfen")
	var view: Dictionary = presentation.get_objective_view_model()
	check(str(view.next_action) == "Take the north road into Wychwood" and str(view.destination_zone) == "wychwood", "Tracker/compass lost the single northern destination")
	check(not new_quests.is_active("side_escort_01") and not bool(state.get_flag("opening_cup_delivered", false)), "Main route manufactured optional work")
	presentation.free()
	beats.free()
	new_quests.free()
	var all_clues := ["bram", "sella", "oren", "vargan_wire", "drag_marks"]
	var fragments := {"bram":"cart brake", "sella":"black feathers", "oren":"wooden crow", "vargan_wire":"Vargan wire", "drag_marks":"drag marks"}
	# Two complementary early-discovery routes exercise every optional fact,
	# including a complete report which never found either token or wire.
	for clues: Array in [["drag_marks", "bram", "sella"], ["vargan_wire", "oren", "bram"]]:
		for method: String in ["private", "public", "retained"]:
			state.load_state({})
			state.set_flag("rook_disclosure", "private")
			state.set_flag("witness_consent_anwen", "refused")
			var quests := QuestManager.new()
			root.add_child(quests)
			quests.load_quests("res://data/quests.json")
			manager.setup(state, quests)
			for clue: String in clues:
				quests.complete_evidence("main_road_of_crows", clue)
			quests.start_quest("main_road_of_crows")
			check(quests.is_objective_done("main_road_of_crows", "evidence_ready"), "Early/out-of-order evidence was not counted")
			quests.complete_objective("main_road_of_crows", "speak_anwen")
			quests.complete_objective("main_road_of_crows", "fight_ghoulkin")
			var report: Dictionary = manager.get_dialogue("report_decision")
			check(report.actions.size() == 3, "A legitimate report option became gated by optional evidence")
			for clue: String in all_clues:
				check(report.pages.any(func(page): return str(fragments[clue]) in str(page.text)) == clues.has(clue), "Report fabricated or omitted " + clue)
			var chosen: Dictionary = {}
			for action: Dictionary in report.actions:
				if str(action.sets_flags.evidence_report) == method: chosen = action
			check(not chosen.is_empty(), "Missing report choice " + method)
			for key: String in chosen.get("sets_flags", {}): state.set_flag(key, chosen.sets_flags[key])
			var completions: Array[String] = []
			quests.quest_completed.connect(func(id): completions.append(id))
			check(quests.complete_choice("main_road_of_crows", "return_village"), "Report did not complete")
			check(not quests.complete_choice("main_road_of_crows", "return_village"), "Stale report completed twice")
			check(completions.count("main_road_of_crows") == 1, "Once-only quest reward event repeated")
			check(quests.is_active("main_bell_beneath_greyfen"), "Report lost cemetery continuation")
			quests.load_state(quests.save_state())
			state.load_state(state.save_state())
			for clue: String in all_clues:
				check(quests.is_objective_done("main_road_of_crows", clue) == clues.has(clue), "Completed/loaded quest invented " + clue)
			check(str(state.get_flag("rook_disclosure", "")) == "private" and str(state.get_flag("witness_consent_anwen", "")) == "refused", "Report invented consent")
			check(manager.get_dialogue("report_decision").actions.is_empty(), "Loaded report permits duplicate rewards")
			state.flags.erase("witness_consent_anwen")
			var return_lines: String = JSON.stringify(manager.get_dialogue("sister_anwen").pages)
			if not clues.has("oren"): check("Oren's carving" not in return_lines and "refugee's token" not in return_lines, "Return assumes unobserved token")
			if not clues.has("vargan_wire"): check("Vargan wire" not in return_lines, "Return assumes unobserved wire")
			quests.free()
	manager.setup(state)
	check(manager._build_pages({"lines":[{"text":"secret", "conditions":{"objectives_done":[{"quest":"main_road_of_crows", "id":"oren"}]}}]}).is_empty(), "Missing quest authority reveals conditional evidence")

func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
