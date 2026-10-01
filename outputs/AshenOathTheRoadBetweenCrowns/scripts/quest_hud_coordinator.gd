class_name QuestHudCoordinator
extends RefCounted

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
	var view := _view()
	var text := str(view.get("compass_text", "")) if not view.is_empty() else zone_label
	var distance := objective_distance(view, player, candidates)
	hud.set_compass(text if distance < 0 else "%s | %dm" % [text, distance])
	dirty = false
	cache_valid = true
	last_position = player.global_position
	last_zone = zone_id
	last_signature = state_signature()

func needs_refresh(player: Node3D, zone_id: String) -> bool:
	if dirty or not cache_valid or player == null:
		return true
	if zone_id != last_zone or state_signature() != last_signature:
		return true
	return player.global_position.distance_squared_to(last_position) >= 0.0625

func state_signature() -> String:
	if presentation != null and presentation.has_method("get_objective_view_model"):
		var view := _view()
		return "%s|%s|%s|%s" % [str(view.get("quest_id", "")), str(view.get("objective_id", "")), str(view.get("tracker_text", "")), str(view.get("next_action", ""))]
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
	if player == null:
		return -1
	var quest_id := str(view.get("quest_id", ""))
	var objective_id := str(view.get("objective_id", ""))
	if quest_id == "" or objective_id == "":
		return -1
	var distance := INF
	for candidate in candidates:
		if candidate == null or not is_instance_valid(candidate) or not candidate.is_inside_tree() or not candidate.has_method("get_overlapping_bodies"):
			continue
		var matches := str(candidate.get("quest_id")) == quest_id and str(candidate.get("objective_id")) == objective_id
		if quest_id == "main_road_of_crows" and objective_id == "speak_anwen" and str(candidate.get("interaction_id")) == "sister_anwen":
			matches = true
		if matches:
			distance = minf(distance, candidate.global_position.distance_to(player.global_position))
	return -1 if is_inf(distance) else int(distance)

func _view() -> Dictionary:
	return presentation.get_objective_view_model() if presentation != null and presentation.has_method("get_objective_view_model") else {}
