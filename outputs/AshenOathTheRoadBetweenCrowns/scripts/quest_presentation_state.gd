extends Node

const ObjectiveViewModelContract = preload("res://scripts/objective_view_model.gd")
const RouteCatalog = preload("res://scripts/story_route_catalog.gd")
const StoryActivities = preload("res://scripts/story_activity_director.gd")

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
var quest_beats: Node
var story_state: Node
var zone_id := "greyfen"

func setup(manager: Node, beats: Node = null, state: Node = null) -> void:
	quest_manager = manager
	quest_beats = beats
	story_state = state

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
	var continuation: Dictionary = RouteCatalog.ending_continuation(story_state, zone_id)
	if not continuation.is_empty():
		view.objective_id = str(continuation.get("id", ""))
		view.quest_title = str(continuation.get("title", "THE ROAD HOME"))
		view.objective_text = str(continuation.get("action", ""))
		view.next_action = view.objective_text
		_apply_route(view, continuation)
		view.tracker_text = "%s\n- %s" % [view.quest_title, view.next_action]
	elif quest_manager != null:
		view.quest_id = _presentation_quest_id()
		view.objective_id = get_active_objective_id(view.quest_id)
		if view.quest_id != "":
			view.objective_text = get_active_objective_text(view.quest_id, view.objective_id)
			view.quest_title = str(quest_manager.quest_defs.get(view.quest_id, {}).get("title", view.quest_id))
		if quest_beats != null and quest_beats.has_method("get_current_beat"):
			var beat: Dictionary = quest_beats.get_current_beat()
			if str(beat.get("quest_id", "")) == view.quest_id and str(beat.get("objective_id", "")) == view.objective_id:
				view.next_action = str(beat.get("next", "")).trim_suffix(".")
		var route: Dictionary = RouteCatalog.for_objective(view.quest_id, view.objective_id, story_state, quest_manager, zone_id)
		_apply_route(view, route)
		if route.has("next_action"):
			view.next_action = str(route["next_action"])
		view.tracker_text = _build_tracker_text(view)
	if view.objective_id == "":
		view.quest_title = "THE OPEN ROAD"
		view.next_action = "Explore %s or choose a known promise in the journal" % view.zone_name
		view.route_hint = "Marked wayposts remember the roads you have walked."
		view.guidance_scope = "exploration"
		view.tracker_text = "%s\n- %s" % [view.quest_title, view.next_action]
	view.contextual_text = view.next_action if view.next_action != "" else view.objective_text
	view.compass_text = view.destination_name if view.destination_name != "" else view.zone_name
	view.save_summary = _build_save_summary(view)
	return view.to_dictionary()

func get_navigation_view_model() -> Dictionary:
	var result := get_objective_view_model()
	result["nearby_work"] = StoryActivities.get_started_work(story_state, zone_id)
	return result

func _presentation_quest_id() -> String:
	var tracked: String = get_tracked_quest()
	if tracked != "" or quest_manager == null:
		return tracked
	# Automatic zone tracking may clear its selection on a connecting road.
	# Keep the ongoing promise visible without changing the player's selection.
	for id in quest_manager.active:
		if str(quest_manager.quest_defs.get(id, {}).get("type", "")) == "main":
			return str(id)
	return ""

func _apply_route(view: ObjectiveViewModelContract, route: Dictionary) -> void:
	view.destination_zone = str(route.get("destination_zone", ""))
	view.destination_name = str(route.get("destination_name", ""))
	view.target_ids.clear()
	for target_id in route.get("target_ids", []):
		view.target_ids.append(str(target_id))
	view.route_hint = str(route.get("route_hint", ""))
	view.purpose = str(route.get("purpose", ""))
	view.pinpoint = bool(route.get("pinpoint", false))
	view.guidance_scope = str(route.get("guidance_scope", "local"))
	if view.guidance_scope != "aftermath" and view.destination_zone != "" and view.destination_zone != zone_id:
		view.guidance_scope = "destination"

func _build_save_summary(view: ObjectiveViewModelContract) -> Dictionary:
	return {
		"zone_id": view.zone_id,
		"zone_name": view.zone_name,
		"quest_id": view.quest_id,
		"quest_title": view.quest_title,
		"objective_id": view.objective_id,
		"next_action": view.contextual_text,
	}

func _build_tracker_text(view: ObjectiveViewModelContract) -> String:
	# Build the tracker from the same selected objective that drives the compass
	# and interaction focus. QuestManager still owns progression, but its
	# all-active-quest summary is deliberately not used as presentation input.
	if quest_manager == null or view.quest_id == "":
		return "No objective in this area\nFollow the road or review the journal."
	if not quest_manager.active.has(view.quest_id):
		return "No objective in this area\nFollow the road or review the journal."
	var title := view.quest_title if view.quest_title != "" else view.quest_id
	var selected: Dictionary = {}
	var objectives: Array = quest_manager.active[view.quest_id].get("objectives", [])
	for raw_objective in objectives:
		if str(raw_objective.get("id", "")) == view.objective_id:
			selected = raw_objective
			break
	if selected.is_empty():
		return "%s\n- All objectives complete" % title
	var action := view.next_action if view.next_action != "" else str(selected.get("tracker_text", selected.get("text", view.objective_text))).trim_suffix(".")
	var group_id := str(selected.get("group", ""))
	if group_id == "":
		return "%s\n- %s" % [title, action]
	var required := maxi(1, int(selected.get("required_count", 1)))
	var done := 0
	for raw_objective in objectives:
		if str(raw_objective.get("group", "")) == group_id and bool(raw_objective.get("optional", false)) and bool(raw_objective.get("done", false)):
			done += 1
	return "%s\n- %s (%d/%d)" % [title, action, done, required]

func save_state() -> Dictionary:
	return {
		"zone_id": zone_id,
		# This is a display snapshot for save-slot summaries. Progression is still
		# restored from QuestManager, so a stale snapshot can never reopen or
		# complete an objective.
		"objective_summary": get_objective_view_model().get("save_summary", {}),
	}

func load_state(state: Dictionary) -> void:
	var requested := str(state.get("zone_id", zone_id)).strip_edges().to_lower()
	zone_id = requested if ZONE_LABELS.has(requested) else "greyfen"
