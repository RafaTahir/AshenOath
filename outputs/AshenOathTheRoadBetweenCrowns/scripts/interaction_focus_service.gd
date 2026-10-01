extends Node

## One focus resolver for prompts, gates, clues, and gameplay interaction.
## The game supplies candidates; this service owns visibility and scoring.

var quest_manager: Node
var quest_presentation: Node
var last_focus: Node

func setup(manager: Node, presentation: Node = null) -> void:
	quest_manager = manager
	quest_presentation = presentation

func target_is_valid(area: Area3D, player: CharacterBody3D, camera: Camera3D) -> bool:
	if not is_instance_valid(player) or not is_instance_valid(area):
		return false
	var kind := str(area.get("interaction_type"))
	# Authored travel framing must not occlude the non-blocking travel volume.
	if kind == "zone":
		return player.global_position.distance_to(area.global_position) <= 3.65
	var origin := camera.global_position if camera != null else player.global_position + Vector3.UP
	var target_height := 0.92 if kind in ["clue", "herb", "village_place"] else 0.96
	var targets: Array[Vector3] = [area.global_position + Vector3.UP * target_height]
	if kind == "dialogue":
		targets.append(area.global_position + Vector3.UP * 1.30)
	var target := targets[0]
	var forward := -camera.global_basis.z if camera != null else -player.global_basis.z
	if forward.dot(origin.direction_to(target)) < 0.22:
		return false
	# Preserve the existing eye-line exception for ground-level clues.
	if kind in ["clue", "herb", "village_place"]:
		return true
	var space := player.get_world_3d().direct_space_state
	for target_point in targets:
		var query := PhysicsRayQueryParameters3D.create(origin, target_point, 1)
		query.exclude = [player.get_rid()]
		query.collide_with_areas = false
		query.collide_with_bodies = true
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return true
		var collider := hit.get("collider") as Node3D
		if collider != null:
			var current: Node = collider
			while current != null:
				if current == area or (current is Node3D and (current as Node3D).global_position.distance_to(area.global_position) <= 1.2):
					return true
				current = current.get_parent()
	# Shop counters retain their player-eye fallback behind booth framing.
	if kind == "vendor":
		var vendor_query := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP * 0.96, target, 1)
		vendor_query.exclude = [player.get_rid()]
		vendor_query.collide_with_areas = false
		vendor_query.collide_with_bodies = true
		return space.intersect_ray(vendor_query).is_empty()
	return false

func choose(candidates: Array, player: Node3D, camera: Camera3D, validator: Callable) -> Node:
	if player == null:
		last_focus = null
		return null
	var best: Node = null
	var best_score := -999.0
	var forward: Vector3 = -camera.global_basis.z if camera != null else -player.global_basis.z
	var objective_view: Dictionary = quest_presentation.get_objective_view_model() if quest_presentation != null and quest_presentation.has_method("get_objective_view_model") else {}
	var tracked_id := str(objective_view.get("quest_id", "")) if not objective_view.is_empty() else (str(quest_manager.get_tracked_quest()) if quest_manager != null and quest_manager.has_method("get_tracked_quest") else "")
	var tracked_objective := str(objective_view.get("objective_id", "")) if not objective_view.is_empty() else _tracked_objective_id(tracked_id)
	var grouped_targets := _unfinished_group_members(tracked_id, tracked_objective)
	for candidate in candidates.duplicate():
		if candidate == null or not is_instance_valid(candidate) or not candidate.is_inside_tree() or candidate.is_queued_for_deletion():
			continue
		var interaction_type := str(candidate.get("interaction_type"))
		var offset: Vector3 = candidate.global_position - player.global_position
		var distance := offset.length()
		# Conversation targets need a little more room than small props. This
		# keeps a speaker focusable from a natural shoulder-camera distance while
		# leaving clue, vendor, and scenery ranges unchanged.
		var focus_range := 3.6 if interaction_type in ["zone", "dialogue"] else 2.8
		if distance > focus_range or distance < 0.01:
			continue
		var facing := forward.dot(offset.normalized())
		# Dialogue has a target-specific eye-line validator in game.gd. Requiring
		# this service's separate trigger-origin angle as well can reject a speaker
		# who is visibly centered at conversation distance, especially with a
		# shoulder camera. Other interactions keep the wider service-level angle
		# gate so scenery cannot steal focus from the object being examined.
		var valid_target := not validator.is_valid() or bool(validator.call(candidate))
		# The game validator already checks the camera-to-target view cone and
		# physical visibility. Applying a second player-origin angle here can
		# reject a nearby clue that is visibly in frame, especially with the
		# shoulder camera offset. Keep the local fallback angle only for callers
		# that do not provide the authoritative validator.
		var fallback_facing_invalid := not validator.is_valid() \
			and interaction_type != "zone" and interaction_type != "dialogue" and facing < 0.12
		if not valid_target or fallback_facing_invalid:
			continue
		var priority := 0.0
		var quest_id := str(candidate.get("quest_id"))
		var objective_id := str(candidate.get("objective_id"))
		if tracked_id != "" and quest_id == tracked_id:
			if tracked_objective != "" and (objective_id == tracked_objective or grouped_targets.has(objective_id)):
				priority += 120.0
			else:
				priority -= 50.0
		if interaction_type == "dialogue":
			priority += 0.18
		elif interaction_type == "clue" and quest_manager != null and quest_manager.has_method("is_active") and quest_manager.is_active(quest_id):
			priority += 0.45
		elif interaction_type == "zone":
			priority += 1.25
		if tracked_id == "main_road_of_crows" and tracked_objective == "speak_anwen" and str(candidate.get("interaction_id")) == "sister_anwen":
			priority += 120.0
		if tracked_id == "main_teeth_in_rain" and tracked_objective == "speak_mira" and str(candidate.get("interaction_id")) == "mira":
			priority += 120.0
		var score := 100.0 - distance if interaction_type == "zone" else facing * 2.2 - distance * 0.42 + priority
		if score > best_score:
			best_score = score
			best = candidate
	last_focus = best
	return best

func _unfinished_group_members(quest_id: String, objective_id: String) -> Dictionary:
	var members := {}
	if quest_id == "" or objective_id == "" or quest_manager == null:
		return members
	var active_variant = quest_manager.get("active")
	if not active_variant is Dictionary or not active_variant.has(quest_id):
		return members
	var objectives: Array = active_variant[quest_id].get("objectives", [])
	var group_id := ""
	for objective in objectives:
		if str(objective.get("id", "")) == objective_id:
			group_id = str(objective.get("group", ""))
			break
	if group_id == "":
		return members
	for objective in objectives:
		if str(objective.get("group", "")) == group_id and bool(objective.get("optional", false)) and not bool(objective.get("done", false)):
			members[str(objective.get("id", ""))] = true
	return members

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
