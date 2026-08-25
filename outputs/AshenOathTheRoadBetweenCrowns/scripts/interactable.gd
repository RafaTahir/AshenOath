extends Area3D

var prompt = "Interact"
var interaction_id = ""
var interaction_type = "dialogue"
var quest_id = ""
var objective_id = ""
var zone_target = ""
var ingredients = {}
var dialogue_id = ""
var display_name = ""
var state_label = ""

func setup(id: String, type: String, prompt_text: String) -> void:
	name = id
	interaction_id = id
	interaction_type = type
	prompt = prompt_text
	display_name = _extract_display_name(prompt_text, id)
	if dialogue_id == "":
		dialogue_id = id

func get_context_prompt() -> String:
	if state_label != "":
		return "%s — %s" % [state_label, display_name]
	var verb: String = str({
		"dialogue": "Speak",
		"clue": "Inspect",
		"herb": "Gather",
		"zone": "Travel",
		"blocked_zone": "Locked",
		"minigame": "Play",
		"village_place": "Use",
		"vendor": "Shop",
	}.get(interaction_type, "Interact"))
	return "%s — %s" % [verb, display_name]

func _extract_display_name(prompt_text: String, fallback_id: String) -> String:
	var cleaned := prompt_text.strip_edges()
	for prefix in ["Talk to ", "Speak to ", "Inspect ", "Search ", "Read ", "Gather ", "Play ", "Enter ", "Use ", "Open ", "Back to "]:
		if cleaned.begins_with(prefix):
			cleaned = cleaned.trim_prefix(prefix)
			break
	return cleaned if cleaned != "" else fallback_id.replace("_", " ").capitalize()

func build_collision(radius: float = 1.4) -> void:
	var shape = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	add_child(shape)
