extends Node

const ObjectiveViewModelContract = preload("res://scripts/objective_view_model.gd")

## Single presentation-facing view of quest state.
## QuestManager remains authoritative for progression; this node owns the
## zone-aware selection and display labels consumed by the HUD and compass.

const ZONE_LABELS := {
	"greyfen": "Greyfen",
	"wychwood": "Wychwood",
	"cemetery": "Greyfen Cemetery",
	"deep_wood": "Deep Wychwood",
	"old_mill": "Old Mill",
	"burned_farmstead": "Burned Farmstead",
	"marsh_crossing": "Marsh Crossing",
	"bandit_road": "Bandit Road",
	"vargan_approach": "Castle Vargan Approach",
	"vargan_court": "Castle Vargan Courtyard",
	"record_hall": "Vargan Record Hall",
	"undercroft": "Vargan Undercroft",
	"assembly": "Greyfen Assembly",
	"hart_glade": "White Hart Glade",
	"ruins": "Old Ruins",
}

# A completed finale quest still needs a clear route home. This is a system
# objective rather than a quest mutation, so it remains available after the
# ending choice without reopening or altering story state.
const ZONE_FALLBACK_OBJECTIVES := {
	"hart_glade": {
		"title": "RETURN ROUTE",
		"text": "Follow the road to Greyfen's assembly",
		"next": "Follow the road to Greyfen's assembly",
	},
}

var quest_manager: Node
var quest_beats: Node
var zone_id := "greyfen"

func setup(manager: Node, beats: Node = null) -> void:
	quest_manager = manager
	quest_beats = beats

func set_zone(id: String) -> void:
	zone_id = id.strip_edges().to_lower()
	if quest_manager != null and quest_manager.has_method("set_tracked_quest_for_zone"):
		quest_manager.set_tracked_quest_for_zone(zone_id)

func get_zone_id() -> String:
	return zone_id

func get_zone_display_name(id: String = "") -> String:
	var requested := id.strip_edges().to_lower() if id != "" else zone_id
	return str(ZONE_LABELS.get(requested, requested.replace("_", " ").capitalize()))

func get_tracked_quest() -> String:
	return str(quest_manager.get_tracked_quest()) if quest_manager != null else ""

func set_tracked_quest(id: String) -> bool:
	if quest_manager != null and quest_manager.has_method("set_tracked_quest"):
		return bool(quest_manager.set_tracked_quest(id))
	return false

func get_active_objective_id(quest_id: String = "") -> String:
	var requested := quest_id if quest_id != "" else get_tracked_quest()
	if quest_manager == null or requested == "" or not quest_manager.has_method("get_active_objective_id"):
		return ""
	return str(quest_manager.get_active_objective_id(requested))

func get_active_objective_text(quest_id: String = "", objective_id: String = "") -> String:
	var requested := quest_id if quest_id != "" else get_tracked_quest()
	var requested_objective := objective_id if objective_id != "" else get_active_objective_id(requested)
	if quest_manager == null or requested == "" or not quest_manager.active.has(requested):
		return "Follow the road"
	for objective in quest_manager.active[requested].get("objectives", []):
		if str(objective.get("id", "")) == requested_objective:
			return str(objective.get("text", "Follow the road")).trim_suffix(".")
	return "Follow the road"

func get_tracker_text() -> String:
	return str(get_objective_view_model().get("tracker_text", "No objective in this area."))

func get_contextual_objective() -> String:
	return str(get_objective_view_model().get("contextual_text", ""))

func get_objective_view_model() -> Dictionary:
	var view := ObjectiveViewModelContract.new()
	view.zone_id = zone_id
	view.zone_name = get_zone_display_name()
	if quest_manager == null:
		view.tracker_text = "No objective in this area."
		return view.to_dictionary()
	view.quest_id = get_tracked_quest()
	view.objective_id = get_active_objective_id(view.quest_id)
	view.objective_text = get_active_objective_text(view.quest_id, view.objective_id)
	if view.quest_id != "" and quest_manager.quest_defs.has(view.quest_id):
		view.quest_title = str(quest_manager.quest_defs[view.quest_id].get("title", view.quest_id))
	var base_tracker := str(quest_manager.get_tracker_text())
	if quest_beats != null and quest_beats.has_method("get_current_beat"):
		var beat: Dictionary = quest_beats.get_current_beat()
		if str(beat.get("quest_id", "")) == view.quest_id and str(beat.get("objective_id", "")) == view.objective_id:
			view.next_action = str(beat.get("next", "")).trim_suffix(".")
	if view.next_action != "":
		var lines := base_tracker.split("\n", false)
		if lines.size() >= 2:
			lines[1] = "- " + view.next_action
			base_tracker = "\n".join(lines)
	view.tracker_text = base_tracker
	view.contextual_text = view.next_action if view.next_action != "" else view.objective_text
	if view.tracker_text == "All tracked objectives complete.":
		view.contextual_text = ""
	if view.objective_id == "":
		var fallback: Dictionary = ZONE_FALLBACK_OBJECTIVES.get(zone_id, {})
		if not fallback.is_empty():
			view.quest_id = ""
			view.quest_title = str(fallback.get("title", "RETURN ROUTE"))
			view.objective_id = "return_to_assembly"
			view.objective_text = str(fallback.get("text", "Follow the road home"))
			view.next_action = str(fallback.get("next", view.objective_text))
			view.tracker_text = "%s\n- %s" % [view.quest_title, view.next_action]
			view.contextual_text = view.next_action
	return view.to_dictionary()

func save_state() -> Dictionary:
	return {"zone_id": zone_id}

func load_state(state: Dictionary) -> void:
	var requested := str(state.get("zone_id", zone_id)).strip_edges().to_lower()
	zone_id = requested if ZONE_LABELS.has(requested) else "greyfen"
