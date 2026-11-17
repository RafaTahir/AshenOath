extends RefCounted
## player camera occlusion view: scene-only responsibilities.

var _actor: CharacterBody3D

func _init(actor: CharacterBody3D) -> void:
	_actor = actor

func get_camera_eye_height() -> float:
	return _actor.CharacterRoleSpec.target_height("player_human", 1.78) * 0.91

func set_camera_close_view(enabled: bool) -> void:
	if _actor._camera_close_view == enabled:
		return
	_actor._camera_close_view = enabled
	if enabled:
		_actor._cache_camera_body(_actor.visual_root)
	for geometry: GeometryInstance3D in _actor._camera_body_shadows:
		if is_instance_valid(geometry):
			geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if enabled else _actor._camera_body_shadows[geometry]
	if not enabled:
		_actor._camera_body_shadows.clear()

func _cache_camera_body(node: Node) -> void:
	if node == null:
		return
	# Keep hand equipment and effects without drawing the inside of the head,
	# hair, clothing, scabbard or quiver over the camera. Shadows still render.
	if _actor.read_presentation_tag(node, "bow_view_arms", false) or node == _actor.rig_sword_visual or node == _actor.weapon_root or node == _actor.bow_visual or node == _actor.slash_arc_root or node == _actor.beam_left_hand_glow or node == _actor.beam_right_hand_glow:
		return
	if node is GeometryInstance3D:
		_actor._camera_body_shadows[node] = node.cast_shadow
	for child in node.get_children():
		_actor._cache_camera_body(child)

func _uses_first_person_camera() -> bool:
	return _actor.camera_controller != null and (_actor.camera_controller != null) and _actor.camera_controller.is_first_person()
