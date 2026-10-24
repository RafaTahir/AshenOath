extends "res://scripts/character_life_modifier.gd"

## One upper-body owner; locomotion, original skin and equipment sockets remain intact.
var player: CharacterBody3D
var bow: Node3D
var arrow: Node3D
var strings: Array[MeshInstance3D] = []
var first_person_arms: Array[MeshInstance3D] = []
var limbs: Array[MeshInstance3D] = []
var grip := Vector3.ZERO
var arrow_rest := Vector3.ZERO
var release_time := 0.0
var released_draw := 0.0
var reach := 0.6
var string_top := Vector3(0, 0.58, 0.145)
var string_bottom := Vector3(0, -0.58, 0.145)
var limb_bend := 0.06
var arrow_ready := false
var fingers: Dictionary = {}

func setup(owner_actor: CharacterBody3D, hand_bow: Node3D, source_bow: Node3D, source_arrow: Node3D) -> void:
	player = owner_actor
	bow = hand_bow
	configure(player, player.animation_driver)
	var skeleton := get_skeleton()
	for side: String in ["l", "r"]:
		for finger: String in ["index", "middle", "ring", "pinky"]:
			for joint in [2, 3]:
				var bone := skeleton.find_bone("%s_0%d_%s" % [finger, joint, side])
				if bone >= 0: fingers[bone] = 0.60 if side == "l" else (0.70 if finger in ["index", "middle"] else 0.20)
	source_bow.rotation = Vector3(0, -PI * 0.5, 0)
	source_bow.scale = Vector3.ONE * 0.44
	source_bow.position = Vector3(0, 0, 0.094)
	# The retained Ranger bow includes a separate, vertically packed display arrow.
	# Only our nocked arrow belongs in the hand; the quiver keeps its own arrow.
	for node in source_bow.find_children("*", "MeshInstance3D", true, false):
		if str(node.name).to_lower().contains("arrow"):
			node.visible = false
		else:
			_prepare_limbs(node as MeshInstance3D)
	if source_arrow != null:
		arrow = preload("res://scripts/arrow_visual.gd").attach(bow, source_arrow)
		arrow.visible = false
	var thread := StandardMaterial3D.new()
	thread.albedo_color = Color(0.72, 0.66, 0.49)
	thread.roughness = 0.9
	for index in 2:
		var segment := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.0016
		cylinder.bottom_radius = 0.0016
		cylinder.height = 1.0
		cylinder.radial_segments = 4
		segment.mesh = cylinder
		segment.material_override = thread
		segment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bow.add_child(segment)
		strings.append(segment)
	_make_first_person_arms()

func _prepare_limbs(mesh: MeshInstance3D) -> void:
	if mesh.mesh == null or not mesh.mesh is ArrayMesh:
		return
	var source := mesh.mesh as ArrayMesh
	# FBX vertices are centimetre-scaled, Z-up, under an imported transform.
	# Measure and bend in the held bow's frame, then convert back for the mesh.
	var mesh_to_bow := bow.global_transform.affine_inverse() * mesh.global_transform
	var bow_to_mesh := mesh_to_bow.affine_inverse()
	var bounds: AABB = mesh_to_bow * source.get_aabb()
	var height := bounds.size.y
	var center := bounds.get_center().y
	limb_bend = height * 0.045
	string_top = Vector3(0, bounds.end.y, bounds.get_center().z)
	string_bottom = Vector3(0, bounds.position.y, bounds.get_center().z)
	var shaped := ArrayMesh.new()
	shaped.add_blend_shape("Draw")
	shaped.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for index in vertices.size(): indices.append(index)
		var kept := PackedInt32Array()
		for face in range(0, indices.size(), 3):
			var a := mesh_to_bow * vertices[indices[face]]
			var b := mesh_to_bow * vertices[indices[face+1]]
			var c := mesh_to_bow * vertices[indices[face+2]]
			var span := a.max(b).max(c) - a.min(b).min(c)
			# Replace only the authored straight string, not either wooden limb.
			if span.y > height * 0.65 and maxf(span.x, span.z) < height * 0.015:
				continue
			kept.append_array(PackedInt32Array([indices[face], indices[face+1], indices[face+2]]))
		arrays[Mesh.ARRAY_INDEX] = kept
		if kept.is_empty(): continue
		var bent := vertices.duplicate()
		for index in vertices.size():
			var point := mesh_to_bow * vertices[index]
			point.z += pow(clampf(absf(point.y - center) / maxf(height * 0.5, 0.001), 0.0, 1.0), 1.8) * limb_bend
			bent[index] = bow_to_mesh * point
		var shape: Array = []
		shape.resize(Mesh.ARRAY_MAX)
		shape[Mesh.ARRAY_VERTEX] = bent
		shape[Mesh.ARRAY_NORMAL] = arrays[Mesh.ARRAY_NORMAL]
		shape[Mesh.ARRAY_TANGENT] = arrays[Mesh.ARRAY_TANGENT]
		var destination := shaped.get_surface_count()
		shaped.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays, [shape], {}, source.surface_get_format(surface))
		shaped.surface_set_material(destination, source.surface_get_material(surface))
	mesh.mesh = shaped
	limbs.append(mesh)

func _make_first_person_arms() -> void:
	var skeleton := get_skeleton()
	for raw in player._mapped_body.find_children("*", "MeshInstance3D", true, false):
		var source := raw as MeshInstance3D
		if source.skin == null or source.mesh == null or not source.mesh is ArrayMesh:
			continue
		var allowed: Dictionary = {}
		for bind in source.skin.get_bind_count():
			var bone_name := str(source.skin.get_bind_name(bind))
			if bone_name == "":
				var bone := source.skin.get_bind_bone(bind)
				bone_name = str(skeleton.get_bone_name(bone)) if bone >= 0 and bone < skeleton.get_bone_count() else ""
			if bone_name.begins_with("upperarm_") or bone_name.begins_with("lowerarm_") or bone_name.begins_with("hand_") or bone_name.begins_with("thumb_") or bone_name.begins_with("index_") or bone_name.begins_with("middle_") or bone_name.begins_with("ring_") or bone_name.begins_with("pinky_"):
				allowed[bind] = true
		var arms_mesh := ArrayMesh.new()
		for surface in source.mesh.get_surface_count():
			var arrays := source.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			if vertices.is_empty() or weights.is_empty(): continue
			var slots := bones.size() / vertices.size()
			var arm_vertices := PackedByteArray()
			arm_vertices.resize(vertices.size())
			for vertex in vertices.size():
				var arm_weight := 0.0
				for slot in int(slots):
					if allowed.has(bones[vertex*int(slots)+slot]): arm_weight += weights[vertex*int(slots)+slot]
				arm_vertices[vertex] = 1 if arm_weight >= 0.8 else 0
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				for index in vertices.size(): indices.append(index)
			var kept := PackedInt32Array()
			for face in range(0, indices.size(), 3):
				if arm_vertices[indices[face]] and arm_vertices[indices[face+1]] and arm_vertices[indices[face+2]]:
					kept.append_array(PackedInt32Array([indices[face], indices[face+1], indices[face+2]]))
			if kept.is_empty(): continue
			arrays[Mesh.ARRAY_INDEX] = kept
			var destination := arms_mesh.get_surface_count()
			arms_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, source.mesh.surface_get_format(surface))
			arms_mesh.surface_set_material(destination, source.get_active_material(surface))
		if arms_mesh.get_surface_count() == 0: continue
		var view := MeshInstance3D.new()
		view.name = "KaelFirstPersonArms"
		view.mesh = arms_mesh
		view.skin = source.skin
		view.transform = source.transform
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		view.set_meta("bow_view_arms", true)
		view.visible = false
		source.get_parent().add_child(view)
		view.skeleton = view.get_path_to(source.get_node(source.skeleton))
		first_person_arms.append(view)

func on_release(ratio: float) -> void:
	release_time = 0.20
	released_draw = ratio
	arrow_ready = false
	if arrow != null: arrow.visible = false

func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or not is_instance_valid(player): return
	var enabled: bool = player.is_bow_pose_active()
	for view in first_person_arms:
		view.visible = enabled and player._camera_close_view
	if not enabled:
		player.bow_pose_valid = false
		pose_weight = 0.0
		release_time = 0.0
		if arrow != null: arrow.visible = false
		return
	var delta := minf(get_process_delta_time(), 0.05)
	pose_weight = move_toward(pose_weight, 1.0, delta * 8.0)
	release_time = maxf(0.0, release_time - delta)
	var aim_weight: float = player.bow_pose_aim
	var draw: float = clampf(player.bow_draw_time / player.get_bow_draw_duration(), 0.0, 1.0)
	var forward: Vector3 = player.bow_pose_direction
	if forward.length_squared() < 0.5: forward = -player.global_basis.z
	var right := forward.cross(Vector3.UP).normalized()
	var up := right.cross(forward).normalized()
	var frame := Basis(right, up, -forward)
	for bone: int in fingers:
		skeleton.set_bone_pose_rotation(bone, skeleton.get_bone_pose_rotation(bone) * Quaternion(Vector3.RIGHT, float(fingers[bone]) * pose_weight * (1.0 if player.bow_aiming else 0.55)))
	for arm: Dictionary in arms:
		if float(arm.side) > 0: continue
		var shoulder := _world(skeleton, int(arm.upper))
		var elbow := _world(skeleton, int(arm.lower))
		var hand := _world(skeleton, int(arm.hand))
		reach = shoulder.distance_to(elbow) + elbow.distance_to(hand)
		var rest := shoulder + (-player.global_basis.z * 0.22 - Vector3.UP * 0.63) * reach
		# Slightly unlocked bow elbow; draw hand anchors beside the jaw, never behind the skull.
		grip = rest.lerp(shoulder + (forward * 0.90 + right * 0.05 + up * 0.035) * reach, aim_weight)
		var palm_offset := _hand_contact(skeleton, "l") - hand
		_solve_arm(skeleton, arm, hand.lerp(grip - palm_offset, pose_weight), null, -up - right * 0.15)
		grip = _hand_contact(skeleton, "l")
	var brace := 0.145
	var draw_length := maxf(reach * 0.79 - brace, 0.15)
	var nock := grip + up * 0.045 + right * 0.012 - forward * (brace + draw * draw_length)
	var hand_draw := maxf(draw, released_draw * smoothstep(0.15, 0.65, release_time / 0.20))
	var anchor := grip + up * 0.045 + right * 0.012 - forward * (brace + hand_draw * draw_length)
	for arm: Dictionary in arms:
		if float(arm.side) < 0: continue
		var hand := _world(skeleton, int(arm.hand))
		var shoulder := _world(skeleton, int(arm.upper))
		var resting := shoulder - Vector3.UP * reach * 0.83 + forward * 0.08
		var follow := right * sin(release_time / 0.20 * PI) * 0.045
		var goal := resting.lerp(anchor + follow, aim_weight)
		for correction in 2:
			hand = _world(skeleton, int(arm.hand))
			var hook_offset := (_hand_contact(skeleton, "r") - hand) * aim_weight
			_solve_arm(skeleton, arm, hand.lerp(goal - hook_offset, pose_weight), null, right - forward * 0.65 + up * 0.15)
		if aim_weight > 0.99 and release_time <= 0.0:
			# The string follows the actual hook fingers, never an unreachable goal.
			nock = _hand_contact(skeleton, "r")
	# Derive from the live solved hand, not last frame's BoneAttachment transform.
	var parent_frame: Transform3D = player._equipment_anchor_world(bow.get_parent())
	var held_frame := frame
	if aim_weight < 1.0:
		var carried := Basis(player.global_basis.x, Vector3.UP, player.global_basis.z).orthonormalized()
		held_frame = carried.slerp(frame, aim_weight)
	bow.transform = parent_frame.affine_inverse() * Transform3D(held_frame, grip)
	arrow_rest = nock + forward * preload("res://scripts/arrow_visual.gd").LENGTH
	player.bow_pose_local_origin = player.to_local(arrow_rest)
	player.bow_pose_valid = true
	var local_nock := held_frame.inverse() * (nock - grip)
	_set_string(strings[0], string_top + Vector3(0, 0, draw * limb_bend), local_nock)
	_set_string(strings[1], string_bottom + Vector3(0, 0, draw * limb_bend), local_nock)
	for limb in limbs: limb.set_blend_shape_value(0, draw)
	arrow_ready = aim_weight > 0.1 and release_time <= 0.0 and player.bow_has_arrow()
	if arrow != null:
		arrow.visible = arrow_ready
		arrow.position = local_nock

func _set_string(segment: MeshInstance3D, tip: Vector3, nock: Vector3) -> void:
	var offset := tip - nock
	if offset.length_squared() < 0.000001:
		return
	segment.transform = Transform3D(Basis(Quaternion(Vector3.UP, offset.normalized())).scaled(Vector3(1, offset.length(), 1)), (tip + nock) * 0.5)

func _hand_contact(skeleton: Skeleton3D, side: String) -> Vector3:
	var center := Vector3.ZERO
	var count := 0
	for finger: String in ["index", "middle"]:
		var bone := skeleton.find_bone("%s_0%d_%s" % [finger, 2 if side == "l" else 3, side])
		if bone >= 0:
			center += _world(skeleton, bone)
			count += 1
	return center / float(count) if count > 0 else _world(skeleton, skeleton.find_bone("hand_" + side))
