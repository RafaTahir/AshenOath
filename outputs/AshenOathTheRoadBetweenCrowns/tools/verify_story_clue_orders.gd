extends SceneTree

const GameScript = preload("res://scripts/game.gd")
const QuestScript = preload("res://scripts/quest_manager.gd")
const StoryScript = preload("res://scripts/story_state.gd")
const InteractableScript = preload("res://scripts/interactable.gd")
const ROAD := "main_road_of_crows"
const EVIDENCE := ["bram", "sella", "oren", "vargan_wire", "drag_marks"]
const CLUE_IDS := {
	"bram": "corpse", "sella": "black_feathers", "oren": "oren_token",
	"vargan_wire": "claw_marks", "drag_marks": "tracks",
}

class QuietHud:
	extends RefCounted
	var last_toast := ""
	var last_hint := ""
	func toast(message: String) -> void:
		last_toast = message
	func set_guidance_hint(message: String, _seconds: float) -> void:
		last_hint = message

func _initialize() -> void:
	var game = GameScript.new()
	game.hud = QuietHud.new()
	var cases := 0
	var failure := ""
	for a in EVIDENCE:
		for b in EVIDENCE:
			if b == a:
				continue
			for c in EVIDENCE:
				if c == a or c == b:
					continue
				var remaining: Array[String] = []
				for candidate in EVIDENCE:
					if candidate not in [a, b, c]:
						remaining.append(candidate)
				for reverse in [false, true]:
					var order: Array[String] = [a, b, c]
					order.append_array(remaining.duplicate() if not reverse else [remaining[1], remaining[0]])
					failure = _verify_order(game, order, true)
					cases += 1
					if failure != "":
						break
				if failure != "":
					break
			if failure != "":
				break
		if failure != "":
			break
	if failure == "":
		var pre_fight_order: Array[String] = []
		for evidence_id in EVIDENCE:
			pre_fight_order.append(evidence_id)
		failure = _verify_order(game, pre_fight_order, false)
		cases += 1
	game.zone_residency.free()
	game.free()
	if failure != "":
		push_error("STORY CLUE ORDER: FAIL case=%d %s" % [cases, failure])
		quit(1)
	else:
		print("STORY CLUE ORDER: PASS permutations=%d five_real_clues=true no_ghost_credit=true" % cases)
		quit(0)

func _verify_order(game: Node, order: Array[String], fight_after_three: bool) -> String:
	var quests = QuestScript.new()
	quests.load_quests("res://data/quests.json")
	var story = StoryScript.new()
	game.hud = QuietHud.new()
	game.quests = quests
	game.story_state = story
	if not quests.start_quest(ROAD) or not quests.complete_objective(ROAD, "speak_anwen"):
		var setup_error := "Road quest fixture did not open"
		game.quests = null
		game.story_state = null
		quests.free()
		story.free()
		return setup_error
	var found: Array[String] = []
	var failure := ""
	for index in order.size():
		if index == 3 and fight_after_three and not quests.complete_objective(ROAD, "fight_ghoulkin"):
			failure = "Five-enemy objective could not complete after three clues"
			break
		var clue = InteractableScript.new()
		clue.interaction_id = CLUE_IDS[order[index]]
		game._handle_road_of_crows_clue(clue)
		clue.free()
		found.append(order[index])
		for evidence_id in EVIDENCE:
			if quests.is_objective_done(ROAD, evidence_id) != (evidence_id in found):
				failure = "uninspected evidence credited: order=%s step=%d evidence=%s" % [order, index, evidence_id]
				break
		if failure != "":
			break
		if quests.is_objective_done(ROAD, "evidence_ready") != (found.size() >= 3):
			failure = "three-clue progression threshold changed: order=%s step=%d" % [order, index]
			break
		if bool(story.get_flag("all_road_evidence", false)) != (found.size() == 5):
			failure = "all-evidence payoff does not match five inspections: order=%s step=%d" % [order, index]
			break
	if failure == "" and ((fight_after_three and game.hud.last_hint != "") or (not fight_after_three and not game.hud.last_hint.contains("marked edge"))):
		failure = "all-evidence hint used the wrong fight phase: order=%s post_fight=%s hint=%s" % [order, fight_after_three, game.hud.last_hint]
	game.quests = null
	game.story_state = null
	quests.free()
	story.free()
	return failure
