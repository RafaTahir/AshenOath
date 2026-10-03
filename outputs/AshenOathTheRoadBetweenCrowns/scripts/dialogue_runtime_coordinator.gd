class_name DialogueRuntimeCoordinator
extends RefCounted

var _focus_actor: WeakRef
var _locked_actor: WeakRef

func get_focus_actor() -> Node3D:
	return _focus_actor.get_ref() as Node3D if _focus_actor != null else null

func stage(area: Node3D, player: Node3D, camera_rig: Node, validate_position: Callable) -> void:
	if not is_instance_valid(player) or not is_instance_valid(area):
		return
	_focus_actor = weakref(area)
	_set_player_pose(player, true)
	if area.find_child("CharacterAnimationDriver", true, false) != null:
		_locked_actor = weakref(area)
		_set_speaker_pose(area, true)
	_face_pair(area, player)
	# Preserve the spatially validated close-conversation step before pausing.
	if player.global_position.distance_to(area.global_position) < 1.35:
		var staged_position := area.global_position - area.global_basis.z.normalized() * 1.75
		if validate_position.is_valid():
			var validated_position: Vector3 = validate_position.call(staged_position)
			if validated_position.distance_to(staged_position) > 0.65 or validated_position.distance_to(player.global_position) > 2.0:
				staged_position = player.global_position
			else:
				staged_position = validated_position
		if staged_position != player.global_position:
			var supported: Variant = _supported_step(player, staged_position)
			staged_position = supported if supported != null else player.global_position
		if staged_position != player.global_position:
			player.global_position = staged_position
			player.set("velocity", Vector3.ZERO)
			_face_pair(area, player)
	_frame_camera(camera_rig, area)

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

func refresh_page(player: Node3D, camera_rig: Node) -> void:
	var actor := get_focus_actor()
	if not is_instance_valid(player) or not is_instance_valid(actor):
		return
	_face_pair(actor, player)
	_frame_camera(camera_rig, actor)

func face_actor(actor: Node3D, player: Node3D) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(player):
		return
	var to_player := player.global_position - actor.global_position
	to_player.y = 0.0
	if to_player.length_squared() > 0.01:
		actor.rotation.y = atan2(-to_player.x, -to_player.z)

func release(player: Node3D) -> void:
	_focus_actor = null
	_set_player_pose(player, false)
	var actor := _locked_actor.get_ref() as Node3D if _locked_actor != null else null
	if is_instance_valid(actor):
		_set_speaker_pose(actor, false)
	_locked_actor = null

func _face_pair(actor: Node3D, player: Node3D) -> void:
	if player.has_method("face_target"):
		player.face_target(actor.global_position)
	face_actor(actor, player)

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
		driver.set_working(false)
	if driver != null and driver.has_method("set_dialogue_pose"):
		driver.set_dialogue_pose(active)
