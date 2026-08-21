extends Node

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

var quest_manager: Node
var zone_id := "greyfen"

func setup(manager: Node) -> void:
	quest_manager = manager

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

func set_tracked_quest(id: String) -> void:
	if quest_manager != null and quest_manager.has_method("set_tracked_quest"):
		quest_manager.set_tracked_quest(id)

func get_active_objective_id(quest_id: String = "") -> String:
	var requested := quest_id if quest_id != "" else get_tracked_quest()
	if quest_manager == null or requested == "" or not quest_manager.active.has(requested):
		return ""
	var grouped: Dictionary = {}
	for objective in quest_manager.active[requested].get("objectives", []):
		var group_id: String = str(objective.get("group", ""))
		if group_id == "":
			continue
		if not grouped.has(group_id):
			grouped[group_id] = {"required": 1, "done": 0, "summary_id": ""}
		var group_state: Dictionary = grouped[group_id]
		group_state["required"] = maxi(int(group_state.get("required", 1)), int(objective.get("required_count", 1)))
		if bool(objective.get("optional", false)) and bool(objective.get("done", false)):
			group_state["done"] = int(group_state.get("done", 0)) + 1
		elif not bool(objective.get("optional", false)):
			group_state["summary_id"] = str(objective.get("id", ""))
		grouped[group_id] = group_state
	for group_id in grouped:
		var group_state: Dictionary = grouped[group_id]
		if int(group_state.get("done", 0)) < int(group_state.get("required", 1)) and str(group_state.get("summary_id", "")) != "":
			return str(group_state.get("summary_id", ""))
	for objective in quest_manager.active[requested].get("objectives", []):
		if not bool(objective.get("done", false)) and not bool(objective.get("optional", false)):
			return str(objective.get("id", ""))
	for objective in quest_manager.active[requested].get("objectives", []):
		if not bool(objective.get("done", false)):
			return str(objective.get("id", ""))
	return ""

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
	return str(quest_manager.get_tracker_text()) if quest_manager != null else "No objective in this area."

func get_contextual_objective() -> String:
	if quest_manager == null:
		return ""
	var tracker := get_tracker_text()
	if tracker == "All tracked objectives complete.":
		return ""
	var lines := tracker.split("\n", false)
	return str(lines[lines.size() - 1]).trim_prefix("- ").strip_edges()

func save_state() -> Dictionary:
	return {"zone_id": zone_id}

func load_state(state: Dictionary) -> void:
	var requested := str(state.get("zone_id", zone_id)).strip_edges().to_lower()
	zone_id = requested if ZONE_LABELS.has(requested) else "greyfen"
