extends Area3D

signal interaction_availability_changed(enabled: bool)

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
var interaction_enabled := true

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
	# Written evidence uses the dialogue presentation system, not spoken action.
	if interaction_type == "dialogue" and prompt.begins_with("Read "):
		verb = "Read"
	return "%s — %s" % [verb, display_name]

func set_interaction_enabled(enabled: bool) -> void:
	if interaction_enabled == enabled:
		return
	interaction_enabled = enabled
	set_deferred("monitoring", enabled)
	set_deferred("monitorable", enabled)
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", not enabled)
	interaction_availability_changed.emit(enabled)

func is_interaction_enabled() -> bool:
	return interaction_enabled and is_inside_tree() and is_visible_in_tree() and not is_queued_for_deletion()

func get_prompt_model() -> Dictionary:
	var verb := str({"dialogue":"Speak", "clue":"Inspect", "herb":"Gather", "zone":"Travel", "blocked_zone":"Read", "minigame":"Play", "village_place":"Use", "vendor":"Shop", "story_activity":"Act", "covenant":"Keep your promise"}.get(interaction_type, "Interact"))
	if interaction_type == "dialogue" and prompt.begins_with("Read "):
		verb = "Read"
	return {"target_id":interaction_id, "verb":verb, "subject":display_name, "state":state_label, "available":is_interaction_enabled(), "legacy_text":get_context_prompt(), "action":"interact"}

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
