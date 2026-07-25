extends SceneTree

const QuestManager = preload("res://scripts/quest_manager.gd")
const StoryState = preload("res://scripts/story_state.gd")
var failures := 0

func _initialize() -> void:
	var quests = QuestManager.new()
	root.add_child(quests)
	quests.load_quests("res://data/quests.json")
	quests.unlocked["main_names_they_burned"] = true
	check(quests.start_quest("main_names_they_burned"), "The Names They Burned cannot start")
	for fragment in ["fragment_mira", "fragment_anwen", "fragment_rook"]:
		check(quests.complete_evidence("main_names_they_burned", fragment), "Register fragment failed: %s" % fragment)
	check(quests.is_objective_done("main_names_they_burned", "reconstruct_register"), "Three out-of-order fragments do not reconstruct the register")
	check(quests.complete_objective("main_names_they_burned", "names_choice"), "Names choice cannot complete")
	check(quests.is_active("main_ash_at_the_mill"), "Ash at the Mill did not unlock and start")
	for objective in ["reach_mill", "inspect_millstones", "mill_encounter", "mill_choice"]:
		check(quests.complete_objective("main_ash_at_the_mill", objective), "Mill objective failed: %s" % objective)
	check(quests.is_active("main_soldier_without_banner"), "A Soldier Without a Banner did not unlock and start")
	var dialogue = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign_dialogue.json"))
	check(dialogue.miller_record.actions.size() == 3, "The mill does not offer preserve, burn, and expose")
	check(dialogue.captain_senn.actions.size() == 3, "Senn does not offer testimony, exile, and punishment")
	var contract = JSON.parse_string(FileAccess.get_file_as_string("res://ash_and_banner_contract.json"))
	check(typeof(contract) == TYPE_DICTIONARY and int(contract.register_required) == 3, "Ash and Banner contract is invalid")
	var game_source := FileAccess.get_file_as_string("res://scripts/game.gd")
	check("ash_mill_enemy" in game_source and "senn_guard" in game_source, "Encounter completion hooks are missing")
	print("QUEST-003 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
