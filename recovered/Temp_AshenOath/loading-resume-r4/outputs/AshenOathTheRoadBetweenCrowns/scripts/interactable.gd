extends Area3D

signal interaction_availability_changed(enabled: bool)
signal interaction_position_changed

func _enter_tree() -> void:
	set_notify_transform(true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		interaction_position_changed.emit()

const PROMPT_VERBS := {
	"Knock at ": "Knock", "Lift ": "Lift", "Lower ": "Lower", "Check ": "Check",
	"Fold ": "Fold", "Demonstrate ": "Demonstrate", "Work ": "Work",
	"Talk to ": "Speak", "Speak to ": "Speak", "Speak with ": "Speak",
	"Speak ": "Speak", "Hear ": "Hear", "Meet ": "Meet", "Hail ": "Hail",
	"Confront ": "Confront", "Approach ": "Approach", "Inspect ": "Inspect",
	"Search ": "Search", "Read ": "Read", "Gather ": "Gather", "Play ": "Play",
	"Enter ": "Enter", "Use ": "Use", "Open ": "Open", "Return to ": "Return to",
	"Back to ": "Return to", "Travel ": "Travel", "Take ": "Take", "Set ": "Set",
	"Recover ": "Recover", "Identify ": "Identify", "Examine ": "Examine",
	"Keep ": "Keep", "Choose ": "Choose", "Report ": "Report", "Follow ": "Follow",
	"Walk ": "Walk", "Visit ": "Visit", "Name ": "Name", "Lay down ": "Lay down", "Confess ": "Confess",
	"Sit at ": "Sit at", "Draw from ": "Draw from", "Buy ": "Buy"
}

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
	var verb := str({"dialogue":"Speak", "clue":"Inspect", "herb":"Gather", "zone":"Travel", "blocked_zone":"Read", "minigame":"Play", "village_place":"Use", "vendor":"Shop", "story_activity":"Use", "encounter":"Enter", "covenant":"Keep your promise"}.get(interaction_type, "Interact"))
	var subject: String = display_name
	for prefix: String in PROMPT_VERBS:
		if prompt.begins_with(prefix):
			verb = PROMPT_VERBS[prefix]
			subject = prompt.trim_prefix(prefix)
			break
	if interaction_id == "sister_anwen":
		verb = "Speak"
		subject = "Sister Anwen"
	return {"target_id":interaction_id, "verb":verb, "subject":subject, "state":state_label, "available":is_interaction_enabled(), "legacy_text":get_context_prompt(), "action":"interact"}

func _extract_display_name(prompt_text: String, fallback_id: String) -> String:
	var cleaned := prompt_text.strip_edges()
	for prefix: String in PROMPT_VERBS:
		if cleaned.begins_with(prefix):
			cleaned = cleaned.trim_prefix(prefix)
			break
	return cleaned if cleaned != "" else fallback_id.replace("_", " ").capitalize()

func build_collision(radius: float = 1.4) -> void:
	var shape = CollisionShape3D.new()
	var sphere = preload("res://scripts/immutable_collision_shapes.gd").sphere(radius)
	shape.shape = sphere
	add_child(shape)
