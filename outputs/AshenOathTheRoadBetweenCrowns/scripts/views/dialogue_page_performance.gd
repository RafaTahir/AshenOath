extends RefCounted

const StoryPerformance = preload("res://scripts/story_performance.gd")
const PLAYER_SPEAKERS := ["player", "kael", "player_kael", "player_human"]

static func visible_actor(page: Dictionary) -> Node3D:
	var speaker_id := str(page.get("speaker_id", "")).to_lower()
	if speaker_id in PLAYER_SPEAKERS or speaker_id in ["narrator", ""]:
		return null
	var instance_id := int(page.get("speaker_actor_id", 0))
	var actor := instance_from_id(instance_id) as Node3D if instance_id > 0 else null
	if not is_instance_valid(actor) or actor.is_queued_for_deletion() or not actor.is_visible_in_tree():
		return null
	return actor

static func present(player: Node3D, focus: Node3D, partner: Node3D, supporting: Array[WeakRef], page: Dictionary, audio: Node) -> void:
	var speaker_id := str(page.get("speaker_id", "")).to_lower()
	var speaker := visible_actor(page)
	if speaker_id in PLAYER_SPEAKERS:
		speaker = player
	elif speaker == null and is_instance_valid(focus) and speaker_id not in ["narrator", ""]:
		var performance := focus.get_node_or_null("StoryPerformance")
		if performance != null and performance.owns_speaker_identity(speaker_id):
			speaker = focus
	var participants: Array[Node3D] = [player, focus]
	for ref: WeakRef in supporting:
		participants.append(ref.get_ref() as Node3D)
	for participant: Node3D in participants:
		if not is_instance_valid(participant):
			continue
		var eyeline := partner if participant == player else player
		if is_instance_valid(speaker) and speaker != participant:
			eyeline = speaker
		StoryPerformance.page(participant, page, audio, speaker, eyeline, participant == player or participant == partner)

static func supported_step(player: Node3D, candidate: Vector3) -> Variant:
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
