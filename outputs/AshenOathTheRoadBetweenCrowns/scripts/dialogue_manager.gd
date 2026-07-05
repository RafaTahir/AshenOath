extends Node

var dialogues = {}
var story_state

func setup(state) -> void:
	story_state = state

func load_dialogue(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_warning("Missing JSON: %s" % path)
		return
	var file = FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		dialogues.merge(parsed, true)

func get_dialogue(id: String) -> Dictionary:
	var base: Dictionary = dialogues.get(id, {
		"name": "Unknown",
		"greeting": "...",
		"lines": [],
		"actions": []
	}).duplicate(true)
	var candidates: Array = base.get("variants", [])
	candidates.sort_custom(func(a, b): return int(a.get("priority", 0)) > int(b.get("priority", 0)))
	for variant in candidates:
		if story_state == null or story_state.matches(variant.get("conditions", {})):
			for key in variant:
				if key not in ["conditions", "priority"]:
					base[key] = variant[key]
			break
	base.erase("variants")
	var visible_actions: Array = []
	for action in base.get("actions", []):
		if story_state == null or story_state.matches(action.get("conditions", {})):
			visible_actions.append(action)
	base["actions"] = visible_actions
	return base
