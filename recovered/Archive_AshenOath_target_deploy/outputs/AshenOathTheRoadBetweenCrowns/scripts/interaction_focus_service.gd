extends Node

## One focus resolver for prompts, gates, clues, and gameplay interaction.
## The game remains responsible for candidate discovery and target validation;
## this service owns deterministic priority and scoring.

var quest_manager: Node
var last_focus: Node

func setup(manager: Node) -> void:
	quest_manager = manager

func choose(candidates: Array, player: Node3D, camera: Camera3D, validator: Callable) -> Node:
	if player == null:
		last_focus = null
		return null
	var best: Node = null
	var best_score := -999.0
	var forward: Vector3 = -camera.global_basis.z if camera != null else -player.global_basis.z
	var tracked_id := str(quest_manager.get_tracked_quest()) if quest_manager != null and quest_manager.has_method("get_tracked_quest") else ""
	var tracked_objective := _tracked_objective_id(tracked_id)
	for candidate in candidates.duplicate():
		if candidate == null or not is_instance_valid(candidate) or not candidate.is_inside_tree() or candidate.is_queued_for_deletion():
			continue
		var interaction_type := str(candidate.get("interaction_type"))
		var offset: Vector3 = candidate.global_position - player.global_position
		var distance := offset.length()
		var focus_range := 3.6 if interaction_type == "zone" else 2.8
		if distance > focus_range or distance < 0.01:
			continue
		var facing := forward.dot(offset.normalized())
		if (interaction_type != "zone" and facing < 0.12) or (validator.is_valid() and not bool(validator.call(candidate))):
			continue
		var priority := 0.0
		var quest_id := str(candidate.get("quest_id"))
		var objective_id := str(candidate.get("objective_id"))
		if tracked_id != "" and quest_id == tracked_id:
			if tracked_objective != "" and objective_id == tracked_objective:
				priority += 120.0
			else:
				priority -= 50.0
		elif quest_id != "" and quest_manager != null and quest_manager.has_method("is_active") and quest_manager.is_active(quest_id):
			priority -= 80.0
		if interaction_type == "dialogue":
			priority += 0.18
		elif interaction_type == "clue" and quest_manager != null and quest_manager.has_method("is_active") and quest_manager.is_active(quest_id):
			priority += 0.45
		elif interaction_type == "zone":
			priority += 1.25
		if tracked_id == "main_road_of_crows" and tracked_objective == "speak_anwen" and str(candidate.get("interaction_id")) == "sister_anwen":
			priority += 120.0
		var score := 100.0 - distance if interaction_type == "zone" else facing * 2.2 - distance * 0.42 + priority
		if score > best_score:
			best_score = score
			best = candidate
	last_focus = best
	return best

func _tracked_objective_id(quest_id: String) -> String:
	if quest_id == "" or quest_manager == null:
		return ""
	var active_variant = quest_manager.get("active")
	var active: Dictionary = active_variant if active_variant is Dictionary else {}
	if not active.has(quest_id):
		return ""
	for objective in active[quest_id].get("objectives", []):
		if not bool(objective.get("done", false)):
			return str(objective.get("id", ""))
	return ""
