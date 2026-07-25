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
	var anwen: Dictionary = manager.get_dialogue("sister_anwen")
	var pages: Array = anwen.get("pages", [])
	check(pages.size() >= 4, "Anwen conversation has no complete speaker-aware page sequence")
	check(pages.any(func(page): return str(page.get("speaker", "")) == "Kael"), "Kael's reply is not attributed to Kael")
	check(pages.any(func(page): return str(page.get("speaker", "")) == "Sister Anwen"), "Anwen's reply is not attributed to Anwen")
	state.set_flag("evidence_report", "private")
	var report: Dictionary = manager.get_dialogue("sister_anwen")
	check(str(report.pages[0].text).contains("token"), "Highest-priority matching Anwen variant was not selected")
	var rook: Dictionary = manager.get_dialogue("rook")
	check(rook.actions.size() == 1, "Rook's one-time supplies are unavailable initially")
	state.set_flag("rook_supplies_taken", true)
	rook = manager.get_dialogue("rook")
	check(rook.actions.is_empty(), "Rook's one-time supplies can be claimed repeatedly")
	var contract = JSON.parse_string(FileAccess.get_file_as_string("res://dialogue_contract.json"))
	check(typeof(contract) == TYPE_DICTIONARY and bool(contract.get("speaker_aware_pages", false)), "Dialogue contract is invalid")
	print("DIALOGUE-001 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
