extends SceneTree

const DialogueManager = preload("res://scripts/dialogue_manager.gd")
const QuestManager = preload("res://scripts/quest_manager.gd")
const StoryState = preload("res://scripts/story_state.gd")
var failures := 0

func _initialize() -> void:
	var quests = JSON.parse_string(FileAccess.get_file_as_string("res://data/quests.json"))
	var dialogue = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign_dialogue.json"))
	var base_dialogue = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue.json"))
	var game_source := FileAccess.get_file_as_string("res://scripts/game.gd")
	var dialogue_source := FileAccess.get_file_as_string("res://scripts/dialogue_manager.gd")
	for quest_id in ["side_widows_bell", "side_iron_remembers", "side_bitter_roots", "side_black_dog", "side_empty_grave"]:
		check(quests.has(quest_id), "Missing side quest: %s" % quest_id)
	check(dialogue.has("side_contracts"), "Side contract board dialogue is missing")
	check(int(dialogue.side_contracts.actions.size()) >= 5, "Side contract board does not offer five authored requests")
	for action in dialogue.side_contracts.actions:
		check(str(action.get("quest", "")).begins_with("side_"), "Side board action is not quest-backed")
	var side_contacts: Array = [
		{"npc": "widow_elna", "quest": "side_widows_bell", "step": "find_bell", "choice": "widow_choice"},
		{"npc": "blacksmith_tor", "quest": "side_iron_remembers", "step": "recover_iron", "choice": "tor_choice"},
		{"npc": "mira", "quest": "side_bitter_roots", "step": "collect_roots", "choice": "mira_choice"},
		{"npc": "farmer_toma", "quest": "side_black_dog", "step": "find_dog", "choice": "dog_choice"},
		{"npc": "returned_soldier", "quest": "side_empty_grave", "step": "follow_empty_grave", "choice": "walker_choice"}
	]
	for contract in side_contacts:
		_verify_side_action_conditions(base_dialogue, contract, dialogue)
	check("_dialogue_action_available" in game_source, "Runtime stale-dialogue guard is missing")
	check("_story_choice_prerequisites_done" in game_source, "Story choice prerequisite guard is missing")
	check("quest_active" in dialogue_source and "objectives_done" in dialogue_source, "Dialogue manager lacks quest-aware conditions")
	await _verify_runtime_action_filtering()
	print("SIDE-003 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _verify_runtime_action_filtering() -> void:
	var state := StoryState.new()
	var quests := QuestManager.new()
	root.add_child(state)
	root.add_child(quests)
	quests.load_quests("res://data/quests.json")
	var manager := DialogueManager.new()
	root.add_child(manager)
	manager.load_dialogue("res://data/dialogue.json")
	manager.load_dialogue("res://data/campaign_dialogue.json")
	manager.setup(state, quests)
	for contract in [
		{"npc": "widow_elna", "quest": "side_widows_bell", "step": "find_bell", "choice": "widow_choice"},
		{"npc": "blacksmith_tor", "quest": "side_iron_remembers", "step": "recover_iron", "choice": "tor_choice"},
		{"npc": "mira", "quest": "side_bitter_roots", "step": "collect_roots", "choice": "mira_choice"},
		{"npc": "farmer_toma", "quest": "side_black_dog", "step": "find_dog", "choice": "dog_choice"}
	]:
		var npc_id := str(contract["npc"])
		var quest_id := str(contract["quest"])
		var before: Dictionary = manager.get_dialogue(npc_id)
		check(_find_action(before.get("actions", []), "story_choice", str(contract["choice"])).is_empty(), "%s exposes its choice before the quest" % npc_id)
		check(quests.start_quest(quest_id), "%s failed to start" % quest_id)
		var started: Dictionary = manager.get_dialogue(npc_id)
		check(not _find_action(started.get("actions", []), "complete_objective", str(contract["step"])).is_empty(), "%s hides its progress handoff" % npc_id)
		check(_find_action(started.get("actions", []), "story_choice", str(contract["choice"])).is_empty(), "%s exposes its choice before the clue" % npc_id)
		quests.complete_objective(quest_id, str(contract["step"]))
		var ready: Dictionary = manager.get_dialogue(npc_id)
		check(not _find_action(ready.get("actions", []), "story_choice", str(contract["choice"])).is_empty(), "%s hides its ready choice" % npc_id)
		quests.complete_objective(quest_id, str(contract["choice"]))
		var settled: Dictionary = manager.get_dialogue(npc_id)
		check(_find_action(settled.get("actions", []), "story_choice", str(contract["choice"])).is_empty(), "%s choice remains after completion" % npc_id)
	# The returned soldier is spawned only after the grave-track clue, so it
	# starts at the choice-ready state rather than exposing a duplicate step.
	check(quests.start_quest("side_empty_grave"), "Returned-soldier quest failed to start")
	quests.complete_objective("side_empty_grave", "follow_empty_grave")
	var returned_ready: Dictionary = manager.get_dialogue("returned_soldier")
	check(not _find_action(returned_ready.get("actions", []), "story_choice", "walker_choice").is_empty(), "Returned soldier choice is not available after the clue")
	quests.complete_objective("side_empty_grave", "walker_choice")
	var returned_settled: Dictionary = manager.get_dialogue("returned_soldier")
	check(_find_action(returned_settled.get("actions", []), "story_choice", "walker_choice").is_empty(), "Returned soldier choice remains after completion")
	manager.queue_free()
	quests.queue_free()
	state.queue_free()
	await _frames(2)

func _find_action(actions: Array, action_type: String, objective_id: String) -> Dictionary:
	for action in actions:
		if str(action.get("type", "")) == action_type and str(action.get("objective", "")) == objective_id:
			return action
	return {}

func _verify_side_action_conditions(base_dialogue: Dictionary, contract: Dictionary, campaign_dialogue: Dictionary) -> void:
	var npc_id := str(contract.get("npc", ""))
	# The returned soldier is defined in the base dialogue file; the other
	# selected side-quest contacts are there as well. Keep this lookup explicit
	# so a later campaign merge cannot silently remove their gated actions.
	var entry: Dictionary = base_dialogue.get(npc_id, {})
	if entry.is_empty():
		check(false, "Missing side-quest contact dialogue: %s" % npc_id)
		return
	var actions: Array = entry.get("actions", [])
	var found_step := false
	var found_choice := false
	for action in actions:
		var quest_id := str(action.get("quest", ""))
		if quest_id != str(contract.get("quest", "")):
			continue
		var conditions: Dictionary = action.get("conditions", {})
		var objective_id := str(action.get("objective", ""))
		if objective_id == str(contract.get("step", "")):
			found_step = true
			check(conditions.get("quest_active", "") == quest_id, "%s step is not quest-gated" % npc_id)
			check(conditions.has("objectives_not_done"), "%s step lacks duplicate-completion guard" % npc_id)
		if objective_id == str(contract.get("choice", "")):
			found_choice = true
			check(conditions.get("quest_active", "") == quest_id, "%s choice is not quest-gated" % npc_id)
			check(conditions.has("objectives_done"), "%s choice lacks prerequisite objective" % npc_id)
			check(conditions.has("objectives_not_done"), "%s choice lacks one-shot guard" % npc_id)
	if npc_id != "returned_soldier":
		check(found_step, "%s has no gated completion action" % npc_id)
	check(found_choice, "%s has no gated consequence choice" % npc_id)

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
