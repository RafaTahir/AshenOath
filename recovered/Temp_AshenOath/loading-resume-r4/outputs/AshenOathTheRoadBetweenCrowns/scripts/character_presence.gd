extends RefCounted

## Presentation ownership shared by routine, attention and dialogue callers.
## Existing gameplay state is authoritative; this helper never commits choices.
const PRIORITY := {"social": 1, "work": 2, "dialogue": 3}

static func claim(actor: Node3D, kind: String, owner: Variant) -> bool:
	if not is_instance_valid(actor) or not PRIORITY.has(kind):
		return false
	var key := "cast_" + kind + "_owner"
	if actor.has_meta(key) and actor.get_meta(key) != owner:
		return false
	var interruptions: Array[Callable] = []
	var cursor: Node = actor
	while cursor != null:
		for other: String in PRIORITY:
			if not cursor.has_meta("cast_" + other + "_owner"):
				continue
			if int(PRIORITY[other]) > int(PRIORITY[kind]) or other == kind and cursor.get_meta(key) != owner:
				return false
			if int(PRIORITY[other]) < int(PRIORITY[kind]):
				var cancel: Callable = cursor.get_meta("cast_" + other + "_cancel", Callable())
				if cancel.is_valid() and cancel not in interruptions:
					interruptions.append(cancel)
		cursor = cursor.get_parent()
	for cancel: Callable in interruptions:
		cancel.call()
	actor.set_meta(key, owner)
	return true

static func release(actor: Node3D, kind: String, owner: Variant) -> void:
	var key := "cast_" + kind + "_owner"
	if not is_instance_valid(actor) or not actor.has_meta(key) or actor.get_meta(key) != owner:
		return
	actor.remove_meta(key)
	if actor.has_meta("cast_" + kind + "_cancel"):
		actor.remove_meta("cast_" + kind + "_cancel")

static func protected(actor: Node3D) -> bool:
	if not is_instance_valid(actor) or not actor.is_inside_tree() or actor.get_tree().paused:
		return true
	return has_protected_owner(actor)

static func has_protected_owner(actor: Node3D) -> bool:
	var cursor: Node = actor
	while cursor != null:
		if bool(cursor.get_meta("dialogue_facing_lock", false)) or bool(cursor.get_meta("cast_dialogue_owner", false)) or str(cursor.get_meta("cast_work_owner", "")) != "" or bool(cursor.get_meta("bell_eater_evacuated", false)):
			return true
		cursor = cursor.get_parent()
	return false

static func eye_height(actor: Node3D) -> float:
	var spec: Dictionary = actor.get_meta("character_role_spec", {})
	return float(spec.get("height", 1.72)) * 0.90

static func can_see(actor: Node3D, target: Node3D, radius: float, hear_approach: bool = false) -> bool:
	if not is_instance_valid(actor) or not is_instance_valid(target) or not actor.is_inside_tree() or not target.is_inside_tree():
		return false
	if actor.global_position.distance_squared_to(target.global_position) > radius * radius:
		return false
	var offset := target.global_position - actor.global_position
	var forward := actor.global_basis.z if bool(actor.get_meta("source_forward_positive_z", false)) else -actor.global_basis.z
	if actor.has_meta("cast_forward_axis"):
		forward = (actor.global_basis*(actor.get_meta("cast_forward_axis") as Vector3)).normalized()
	if not hear_approach and offset.length_squared() > 1.0 and forward.dot(offset.normalized()) < -0.15:
		return false
	var query := PhysicsRayQueryParameters3D.create(actor.global_position + Vector3.UP * eye_height(actor), target.global_position + Vector3.UP * eye_height(target), 1)
	query.collide_with_areas = false
	var excluded: Array[RID] = []
	var cursor: Node = actor
	while cursor != null:
		if cursor is CollisionObject3D:
			excluded.append(cursor.get_rid())
		cursor = cursor.get_parent()
	query.exclude = excluded
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == target

static func player_threat(player: Node3D) -> String:
	if not is_instance_valid(player):
		return ""
	if float(player.get("attack_anim_time")) > 0.0 or str(player.get("beam_cast_state")) in ["charging", "releasing"]:
		return "danger"
	if not bool(player.get("sword_sheathed")) or bool(player.get("bow_aiming")):
		return "armed"
	return ""
