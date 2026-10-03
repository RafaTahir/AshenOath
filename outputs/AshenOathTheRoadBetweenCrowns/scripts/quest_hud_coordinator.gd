class_name QuestHudCoordinator
extends RefCounted

const SectorManifest = preload("res://scripts/world_sector_manifest.gd")
const RouteCatalog = preload("res://scripts/story_route_catalog.gd")

var presentation: Node
var quests: Node
var dirty := true
var cache_valid := false
var last_position := Vector3.ZERO
var last_zone := ""
var last_signature := ""

func configure(view_source: Node, quest_manager: Node) -> void:
	presentation = view_source
	quests = quest_manager

func refresh_tracker(hud: Node, refresh_presentation: Callable) -> void:
	dirty = true
	var view := _view()
	var text := "No objective in this area."
	if refresh_presentation.is_valid():
		text = str(refresh_presentation.call())
	elif not view.is_empty():
		text = str(view.get("tracker_text", text))
	elif quests != null:
		text = str(quests.get_tracker_text())
	hud.set_tracker(text)

func show_guidance(hud: Node, seconds: float) -> void:
	if hud == null or presentation == null or not presentation.has_method("get_objective_view_model"):
		return
	var guidance := str(_view().get("contextual_text", "")).strip_edges()
	if guidance != "" and not str(hud.tracker_label.text).contains(guidance):
		hud.set_guidance_hint(guidance, seconds)

func update_compass(hud: Node, player: Node3D, zone_id: String, candidates: Array, zone_label: String) -> void:
	if hud == null or player == null:
		return
	var model := build_navigation_model(player, zone_id, candidates)
	if str(model.get("primary", "")) == "":
		model["primary"] = zone_label
	if hud.has_method("set_navigation_model"):
		hud.set_navigation_model(model)
	else:
		var text: String = str(model.get("primary", zone_label))
		var distance: int = int(model.get("distance_m", -1))
		hud.set_compass(text if distance < 0 else "%s | %dm" % [text, distance])
	dirty = false
	cache_valid = true
	last_position = player.global_position
	last_zone = zone_id
	last_signature = state_signature()

func build_navigation_model(player: Node3D, zone_id: String, candidates: Array) -> Dictionary:
	var view := _view()
	var destination: String = str(view.get("destination_zone", ""))
	var scope: String = str(view.get("guidance_scope", "exploration"))
	var distant: bool = destination != "" and destination != zone_id
	var primary: String = str(view.get("destination_name", "")) if distant else str(view.get("zone_name", RouteCatalog.zone_name(zone_id)))
	var action: String = str(view.get("next_action", ""))
	if action == "":
		action = str(view.get("objective_text", "Explore the road and revisit known promises"))
	var route_hint: String = str(view.get("route_hint", ""))
	if distant:
		# The homecoming has a direct authored handoff from the ending screen.
		# Do not turn it into a request to retrace the castle's interiors.
		if not (scope == "aftermath" and zone_id == "hart_glade"):
			var exit_hint: String = _next_exit_hint(zone_id, destination, candidates)
			if exit_hint != "":
				route_hint = exit_hint
		if scope != "aftermath":
			scope = "destination"
	var nearby_work: Array[Dictionary] = []
	for raw_work in view.get("nearby_work", []):
		if raw_work is Dictionary and str(raw_work.get("destination_zone", "")) == zone_id:
			nearby_work.append(raw_work.duplicate(true))
			if nearby_work.size() >= 2:
				break
	return {
		"primary":primary, "action":action, "scope":scope,
		"distance_m":-1 if distant else objective_distance(view, player, candidates),
		"route_hint":route_hint, "purpose":str(view.get("purpose", "")),
		"nearby_work":nearby_work
	}

func needs_refresh(player: Node3D, zone_id: String) -> bool:
	if dirty or not cache_valid or player == null:
		return true
	if zone_id != last_zone or state_signature() != last_signature:
		return true
	return player.global_position.distance_squared_to(last_position) >= 0.0625

func state_signature() -> String:
	if presentation != null and presentation.has_method("get_objective_view_model"):
		var view := _view()
		return "%s|%s|%s|%s|%s|%s|%s" % [str(view.get("quest_id", "")), str(view.get("objective_id", "")), str(view.get("tracker_text", "")), str(view.get("next_action", "")), str(view.get("destination_zone", "")), str(view.get("route_hint", "")), JSON.stringify(view.get("nearby_work", []))]
	if quests != null:
		var tracked_id := str(quests.get_tracked_quest()) if quests.has_method("get_tracked_quest") else ""
		var objective_id := ""
		var active: Dictionary = quests.get("active")
		if active.has(tracked_id):
			for objective in active[tracked_id].get("objectives", []):
				if not bool(objective.get("done", false)):
					objective_id = str(objective.get("id", ""))
					break
		return "%s|%s" % [tracked_id, objective_id]
	return ""

func objective_distance(view: Dictionary, player: Node3D, candidates: Array) -> int:
	if player == null or not bool(view.get("pinpoint", false)):
		return -1
	var destination: String = str(view.get("destination_zone", ""))
	if destination != "" and destination != str(view.get("zone_id", "")):
		return -1
	var targets: Array = view.get("target_ids", [])
	if targets.is_empty():
		return -1
	var distance := INF
	for candidate in candidates:
		if not _eligible(candidate):
			continue
		if str(candidate.get("interaction_id")) in targets:
			distance = minf(distance, candidate.global_position.distance_to(player.global_position))
	return -1 if is_inf(distance) else int(distance)

func _eligible(candidate) -> bool:
	if candidate == null or not is_instance_valid(candidate) or not candidate is Area3D:
		return false
	if not candidate.is_inside_tree() or candidate.is_queued_for_deletion() or not candidate.is_visible_in_tree():
		return false
	if candidate.has_method("is_interaction_enabled") and not candidate.is_interaction_enabled():
		return false
	return candidate.has_method("get_context_prompt")

func _next_exit_hint(zone_id: String, destination: String, candidates: Array) -> String:
	var best_gate = null
	var best_steps := 999
	for candidate in candidates:
		if not _eligible(candidate) or str(candidate.get("interaction_type")) != "zone":
			continue
		var target: String = str(candidate.get("zone_target"))
		if target == "":
			continue
		var steps: int = _steps_to(target, destination, zone_id)
		if steps >= 0 and steps < best_steps:
			best_steps = steps
			best_gate = candidate
	if best_gate == null:
		return "Follow the known road toward %s" % RouteCatalog.zone_name(destination)
	var next_zone: String = str(best_gate.get("zone_target"))
	var edge: Dictionary = SectorManifest.edge_between(zone_id, next_zone)
	if not edge.is_empty():
		return "Take the %s road toward %s" % [str(edge.get("id", "")), RouteCatalog.zone_name(destination)]
	var prompt: String = str(best_gate.get("prompt"))
	return prompt if prompt != "" else "Use the passage toward %s" % RouteCatalog.zone_name(destination)

func _steps_to(source: String, destination: String, excluded_zone: String) -> int:
	# The manifest supplies adjacency, not a revealed map. Only the available
	# gate in the current place is ever shown to the player.
	if source == destination:
		return 0
	var visited: Dictionary = {excluded_zone:true, source:true}
	var queue: Array = [[source, 0]]
	while not queue.is_empty():
		var entry: Array = queue.pop_front()
		for next_zone in SectorManifest.neighbors(str(entry[0])):
			if visited.has(next_zone):
				continue
			var steps: int = int(entry[1]) + 1
			if next_zone == destination:
				return steps
			visited[next_zone] = true
			queue.append([next_zone, steps])
	return -1

func _view() -> Dictionary:
	if presentation != null and presentation.has_method("get_navigation_view_model"):
		return presentation.get_navigation_view_model()
	return presentation.get_objective_view_model() if presentation != null and presentation.has_method("get_objective_view_model") else {}
