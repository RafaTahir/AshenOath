class_name DialogueRuntimeCoordinator
extends RefCounted

var _focus_actor: WeakRef
var _locked_actor: WeakRef
var _topic_generation: int = 0
var _topic_context: Dictionary = {}
var _turns: Array[Tween] = []

func get_focus_actor() -> Node3D:
	return _focus_actor.get_ref() as Node3D if _focus_actor != null else null

func stage(area: Node3D, player: Node3D, camera_rig: Node, _validate_position: Callable) -> void:
	_invalidate_topic_context()
	_focus_actor = null
	if not is_instance_valid(player) or not is_instance_valid(area):
		return
	_focus_actor = weakref(area)
	_set_player_pose(player, true)
	if area.find_child("CharacterAnimationDriver", true, false) != null:
		_locked_actor = weakref(area)
		_set_speaker_pose(area, true)
	_face_pair(area, player)
	# Preserve both people's positions. The camera owns close framing; starting
	# a conversation must never teleport Kael away from an approaching walker.
	player.set("velocity", Vector3.ZERO)
	_frame_camera(camera_rig, area)

func bind_topic_context(actor_id: String, zone_id: String) -> String:
	_invalidate_topic_context()
	var actor: Node3D = get_focus_actor()
	if actor_id == "" or zone_id == "" or not _topic_actor_available(actor, actor_id):
		return ""
	var context_id: String = "conversation:%d:%d" % [_topic_generation, actor.get_instance_id()]
	_topic_context = {"context_id": context_id, "actor_id": actor_id, "zone_id": zone_id}
	return context_id

func get_topic_context(context_id: String) -> Dictionary:
	if context_id == "" or str(_topic_context.get("context_id", "")) != context_id:
		return {}
	var actor: Node3D = get_focus_actor()
	if not _topic_actor_available(actor, str(_topic_context.get("actor_id", ""))):
		_invalidate_topic_context()
		return {}
	return _topic_context.duplicate(true)

func _topic_actor_available(actor: Node3D, actor_id: String) -> bool:
	if not is_instance_valid(actor) or actor.is_queued_for_deletion() or not actor.is_inside_tree() or not actor.is_visible_in_tree():
		return false
	if not actor.has_method("is_interaction_enabled") or not bool(actor.call("is_interaction_enabled")):
		return false
	return str(actor.get("interaction_id")) == actor_id and str(actor.get("interaction_type")) == "dialogue"

func _invalidate_topic_context() -> void:
	_topic_generation += 1
	_topic_context.clear()

func _supported_step(player: Node3D, candidate: Vector3) -> Variant:
	var world := player.get_world_3d()
	if world == null:
		return null
	var excluded: Array[RID] = []
	if player is CollisionObject3D:
		excluded.append(player.get_rid())
	var hit := SpatialSurfaceContract.support_hit(world.direct_space_state,
		candidate + Vector3.UP * 0.75, candidate - Vector3.UP * 1.5, excluded)
	if hit.is_empty() or absf(float(hit.position.y) - player.global_position.y) > 0.35:
		return null
	return Vector3(candidate.x, float(hit.position.y) + 0.002, candidate.z)

func refresh_page(player: Node3D, camera_rig: Node, page: Dictionary = {}) -> void:
	var actor := get_focus_actor()
	if not is_instance_valid(player) or not is_instance_valid(actor):
		return
	if camera_rig != null and camera_rig.has_method("frame_dialogue_beat"):
		camera_rig.call("frame_dialogue_beat", actor, str(page.get("speaker_id", "")), str(page.get("performance", {}).get("framing", "speaker")))
	else:
		_frame_camera(camera_rig, actor)

func face_actor(actor: Node3D, player: Node3D) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(player):
		return
	var to_player := player.global_position - actor.global_position
	to_player.y = 0.0
	if to_player.length_squared() > 0.01:
		actor.rotation.y = atan2(-to_player.x, -to_player.z)

func release(player: Node3D) -> void:
	for turn: Tween in _turns:
		if turn != null and turn.is_valid(): turn.kill()
	_turns.clear()
	_invalidate_topic_context()
	_focus_actor = null
	_set_player_pose(player, false)
	var actor := _locked_actor.get_ref() as Node3D if _locked_actor != null else null
	if is_instance_valid(actor):
		_set_speaker_pose(actor, false)
	_locked_actor = null

func _face_pair(actor: Node3D, player: Node3D) -> void:
	for turn: Tween in _turns:
		if turn != null and turn.is_valid(): turn.kill()
	_turns.clear()
	_turn_toward(player, actor.global_position)
	if actor.find_child("CharacterAnimationDriver", true, false) != null:
		_turn_toward(actor, player.global_position)

func _turn_toward(body: Node3D, point: Vector3) -> void:
	var offset := point - body.global_position
	offset.y = 0.0
	if offset.length_squared() < 0.01: return
	var yaw := atan2(-offset.x, -offset.z)
	if bool(body.get_meta("source_forward_positive_z", false)): yaw += PI
	var difference := wrapf(yaw - body.global_rotation.y, -PI, PI)
	var turn := body.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	turn.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	turn.tween_property(body, "global_rotation:y", body.global_rotation.y + difference, clampf(absf(difference) / 2.8, 0.18, 0.65))
	_turns.append(turn)

func _frame_camera(camera_rig: Node, actor: Node3D) -> void:
	if is_instance_valid(camera_rig) and camera_rig.has_method("frame_dialogue_target"):
		camera_rig.frame_dialogue_target(actor)

func _set_player_pose(player: Node3D, active: bool) -> void:
	if not is_instance_valid(player):
		return
	var driver = player.get("animation_driver")
	if is_instance_valid(driver) and driver.has_method("set_dialogue_pose"):
		driver.set_dialogue_pose(active)

func _set_speaker_pose(actor: Node3D, active: bool) -> void:
	actor.set_meta("dialogue_facing_lock", active)
	var driver := actor.find_child("CharacterAnimationDriver", true, false)
	if active and driver != null and driver.has_method("set_working"):
		actor.set_meta("conversation_previous_work", str(driver.get("presentation_state")) == "work")
		driver.set_working(false)
	if driver != null and driver.has_method("set_dialogue_pose"):
		driver.set_dialogue_pose(active)
	if not active and driver != null and bool(actor.get_meta("conversation_previous_work", false)):
		driver.set_working(true)
	if not active: actor.remove_meta("conversation_previous_work")
