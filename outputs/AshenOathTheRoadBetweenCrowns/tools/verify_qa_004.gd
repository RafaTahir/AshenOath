extends SceneTree

const StoryState = preload("res://scripts/story_state.gd")
const EpilogueResolver = preload("res://scripts/epilogue_resolver.gd")
var failures := 0

func _initialize() -> void:
	var matrix = JSON.parse_string(FileAccess.get_file_as_string("res://qa_004_choice_matrix.json"))
	check(typeof(matrix) == TYPE_DICTIONARY, "QA-004 matrix is invalid")
	if typeof(matrix) != TYPE_DICTIONARY:
		quit(1)
		return
	var axes: Dictionary = matrix["axes"]
	var expected := int(matrix.get("expected_permutations", 0))
	var calculated := 1
	for axis in axes.values():
		calculated *= axis.size()
	check(calculated == expected, "Matrix count does not match declared permutations")

	var state = StoryState.new()
	root.add_child(state)
	var clone = StoryState.new()
	root.add_child(clone)
	var combinations := 0
	var ending_counts := {"expose": 0, "free": 0, "bind": 0, "kill": 0}
	for report in axes["evidence_report"]:
		for shrine in axes["crow_shrine_state"]:
			for names in axes["names_policy"]:
				for senn in axes["senn_fate"]:
					for ledger in axes["vargan_ledger_choice"]:
						for edric in axes["edric_stance"]:
							for halvern in axes["halvern_fate"]:
								for confession in axes["confession_method"]:
									for ending in axes["ending"]:
										_apply_case(state, report, shrine, names, senn, ledger, edric, halvern, confession)
										var cards: Array[String] = EpilogueResolver.resolve(ending, state)
										check(cards.size() >= 5, "Epilogue omitted a consequence card")
										check(str(cards[0]).length() > 20, "Ending card is empty")
										var saved := state.save_state()
										clone.load_state(saved)
										check(str(clone.get_flag("edric_stance", "")) == str(edric), "Story flag mutated on save round-trip")
										check(str(clone.get_flag("halvern_fate", "")) == str(halvern), "Halvern choice mutated on save round-trip")
										combinations += 1
										ending_counts[ending] += 1
	check(combinations == expected, "QA-004 did not execute every declared permutation")
	for ending in ending_counts:
		check(int(ending_counts[ending]) == expected / 4, "Ending coverage is uneven: %s" % ending)
	_verify_dialogue_actions()
	print("QA-004 MATRIX: %s (%d permutations)" % ["PASS" if failures == 0 else "FAIL (%d)" % failures, combinations])
	quit(0 if failures == 0 else 1)

func _apply_case(state, report, shrine, names, senn, ledger, edric, halvern, confession) -> void:
	state.flags.clear()
	state.values = {"anwen_trust": 0, "greyfen_fear": 0, "hart_debt": 0}
	state.set_flag("evidence_report", report)
	state.set_flag("crow_shrine_state", shrine)
	state.set_flag("names_policy", names)
	state.set_flag("senn_fate", senn)
	state.set_flag("vargan_ledger_choice", ledger)
	state.set_flag("edric_stance", edric)
	state.set_flag("halvern_fate", halvern)
	state.set_flag("confession_method", confession)

func _verify_dialogue_actions() -> void:
	for path in ["res://data/dialogue.json", "res://data/campaign_dialogue.json"]:
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		check(typeof(parsed) == TYPE_DICTIONARY, "Dialogue data failed to parse: %s" % path)
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		for id in parsed:
			for action in parsed[id].get("actions", []):
				if str(action.get("type", "")) != "story_choice":
					continue
				check(action.has("sets_flags"), "Story choice has no consequence flag: %s" % id)
				if action.has("quest"):
					check(str(action.get("objective", "")) != "", "Quest choice has no objective: %s" % id)

func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	if failures <= 20:
		push_error(message)
