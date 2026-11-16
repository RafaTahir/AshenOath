extends RefCounted
## enemy equipment view: scene-only responsibilities.

var _actor: CharacterBody3D

func _init(actor: CharacterBody3D) -> void:
	_actor = actor

func _find_type(root: Node, type_name: String) -> Node:
	if root.is_class(type_name):
		return root
	for child in root.get_children():
		var found: Variant = _actor._find_type(child, type_name)
		if found != null:
			return found
	return null

func _safe_scale_ratio(value: float, divisor: float) -> float:
	if absf(divisor) < 0.0001:
		return 1.0
	return value / divisor

func _safe_inverse_scale(value: float) -> float:
	if absf(value) < 0.0001:
		return 1.0
	return 1.0 / value

func _add_skeleton_impact_clip(mapped: Node3D) -> void:
	for node in mapped.find_children("*", "AnimationPlayer", true, false):
		var animator: Variant = node as AnimationPlayer
		if animator.has_animation_library("recovery") or not animator.has_animation("SkeletonArmature|Skeleton_Idle"):
			continue
		var idle: Variant = animator.get_animation("SkeletonArmature|Skeleton_Idle")
		var impact: Variant = Animation.new()
		impact.length = 0.34
		for source_track in range(idle.get_track_count()):
			var type: Variant = idle.track_get_type(source_track)
			if type not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D] or idle.track_get_key_count(source_track) == 0:
				continue
			var path: Variant = idle.track_get_path(source_track)
			var value = idle.track_get_key_value(source_track, 0)
			var track: Variant = impact.add_track(type)
			impact.track_set_path(track, path)
			impact.track_insert_key(track, 0.0, value)
			if type == Animation.TYPE_ROTATION_3D and str(path).to_lower().ends_with(":head"):
				impact.track_insert_key(track, 0.08, (value as Quaternion) * Quaternion(Vector3.RIGHT, -0.24))
				impact.track_insert_key(track, 0.18, (value as Quaternion) * Quaternion(Vector3.RIGHT, -0.14))
			impact.track_insert_key(track, impact.length, value)
		var library: Variant = AnimationLibrary.new()
		library.add_animation("Impact", impact)
		animator.add_animation_library("recovery", library)

func _configure_attack_contact_bone() -> void:
	_actor.attack_contact_bone = -1
	_actor.attack_contact_local_offset = Vector3.ZERO
	if _actor.animation_driver == null or not _actor.animation_driver.is_valid():
		return
	var skeleton: Skeleton3D = _actor.animation_driver.get_skeleton()
	if skeleton == null:
		return
	var preferred: Variant = ["hand.r", "hand_r", "righthand", "right_hand", "mixamorig:righthand", "hand.l", "hand_l", "lefthand", "left_hand", "forearm.r", "forearm_r"]
	for candidate in preferred:
		var wanted: String = candidate.replace(".", "").replace(":", "").replace("_", "")
		for index in range(skeleton.get_bone_count()):
			var compact: String = skeleton.get_bone_name(index).to_lower().replace(" ", "").replace("-", "").replace("_", "").replace(".", "").replace(":", "")
			if compact == wanted:
				_actor.attack_contact_bone = index
				return
	# A few of the compact skeleton-family source meshes do not expose hand
	# bones. Keep their contact authored by the animated skeleton instead of
	# silently reverting to a static actor-space point: the offset is a short
	# strike probe in the selected bone's local forward direction, so rotations
	# in the imported attack clip produce a measured contact path.
	for wanted_part in ["head", "torso", "neck"]:
		for index in range(skeleton.get_bone_count()):
			var compact: String = skeleton.get_bone_name(index).to_lower().replace(" ", "").replace("-", "").replace("_", "").replace(".", "").replace(":", "")
			if compact.contains(wanted_part):
				_actor.attack_contact_bone = index
				# Source FBX rigs have arbitrary bone axes and unit scales. Store
				# a metre-sized actor-forward probe in rest-bone space once.
				var rest_basis: Variant = skeleton.get_bone_global_rest(index).basis
				var ancestor: Node = skeleton
				while ancestor != null and ancestor != _actor:
					if ancestor is Node3D:
						rest_basis = (ancestor as Node3D).basis * rest_basis
					ancestor = ancestor.get_parent()
				_actor.attack_contact_local_offset = rest_basis.inverse() * Vector3(0, 0, -0.58)
				return

func _attach_humanoid_sword(label: String) -> void:
	var skeleton: Variant = _actor.visual_root.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		var skeletons: Variant = _actor.visual_root.find_children("*", "Skeleton3D", true, false)
		if not skeletons.is_empty():
			skeleton = skeletons[0] as Skeleton3D
	var hand: Variant = skeleton.find_bone("hand_r") if skeleton != null else -1
	if hand < 0:
		push_error("%s requires the approved right-hand equipment socket" % label)
		return
	var resource = _actor.asset_helper.load_runtime_resource("res://assets_external/characters/Sword.fbx")
	var sword: Variant = _actor.asset_helper.instantiate_runtime_resource(resource) as Node3D
	if sword == null:
		push_error("%s requires the authored Sword.fbx; no proxy weapon is permitted" % label)
		return
	var socket: Variant = BoneAttachment3D.new()
	socket.name = label + "SwordSocket"
	socket.bone_name = skeleton.get_bone_name(hand)
	socket.bone_idx = hand
	skeleton.add_child(socket)
	var grip: Variant = Node3D.new()
	grip.name = label + "SwordGrip"
	socket.add_child(grip)
	# Derive the authored grip in actor space, including offline zone builds.
	# Reading global transforms here is invalid before the zone enters the tree.
	if _actor.animation_driver != null:
		_actor.animation_driver.sample_pose()
	skeleton.force_update_all_bone_transforms()
	var skeleton_to_actor: Variant = Transform3D.IDENTITY
	var ancestor: Node = skeleton
	while ancestor != null and ancestor != _actor:
		if ancestor is Node3D:
			skeleton_to_actor = (ancestor as Node3D).transform * skeleton_to_actor
		ancestor = ancestor.get_parent()
	var hand_pose: Variant = skeleton.get_bone_global_pose(hand)
	var hand_basis: Variant = skeleton_to_actor.basis * hand_pose.basis
	var inherited: Variant = hand_basis.get_scale().abs().max(Vector3.ONE * 0.0001)
	var ready_direction: Variant = Vector3(0.50, -0.82, -0.15).normalized()
	grip.basis = (hand_basis.orthonormalized().inverse() * Basis(Quaternion(Vector3.DOWN, ready_direction))).scaled(Vector3.ONE / inherited)
	var finger_center: Variant = Vector3.ZERO
	var finger_count: Variant = 0
	for bone_name in ["index_02_r", "middle_02_r", "ring_02_r", "pinky_02_r"]:
		var finger: Variant = skeleton.find_bone(bone_name)
		if finger >= 0:
			finger_center += skeleton.get_bone_global_pose(finger).origin
			finger_count += 1
	if finger_count > 0:
		grip.position = hand_pose.affine_inverse() * (finger_center / float(finger_count))
	sword.name = label + "AuthoredSword"
	sword.rotation_degrees = Vector3(180, 0, 0)
	sword.scale = Vector3.ONE * 0.22
	sword.position = Vector3(0, 0.045, 0)
	grip.add_child(sword)
	var steel: Variant = StandardMaterial3D.new()
	steel.albedo_color = Color(0.57, 0.63, 0.70)
	steel.metallic = 0.7
	steel.roughness = 0.42
	for raw_mesh in sword.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: Variant = raw_mesh as MeshInstance3D
		mesh_instance.material_override = steel

func _attach_bandit_shield() -> void:
	var skeleton: Variant = _actor.visual_root.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		var skeletons: Variant = _actor.visual_root.find_children("*", "Skeleton3D", true, false)
		if not skeletons.is_empty():
			skeleton = skeletons[0] as Skeleton3D
	var hand: Variant = skeleton.find_bone("hand_l") if skeleton != null else -1
	if hand < 0:
		push_error("Bandit tracker requires an approved left-hand equipment socket")
		return
	var resource = _actor.asset_helper.load_runtime_resource("res://assets_external/environment/props/Shield_Wooden.fbx")
	var shield: Variant = _actor.asset_helper.instantiate_runtime_resource(resource) as Node3D
	if shield == null:
		push_error("Bandit tracker requires authored Shield_Wooden.fbx")
		return
	var socket: Variant = BoneAttachment3D.new()
	socket.name = "BanditShieldSocket"
	socket.bone_idx = hand
	socket.bone_name = skeleton.get_bone_name(hand)
	skeleton.add_child(socket)
	shield.name = "BanditAuthoredShield"
	shield.position = Vector3(0.0, -0.02, -0.05)
	shield.rotation_degrees = Vector3(90, 0, 0)
	shield.scale = Vector3.ONE * 0.30
	socket.add_child(shield)

func _find_first_mesh(root: Node) -> MeshInstance3D:
	if root is MeshInstance3D:
		return root
	for child in root.get_children():
		var found = _actor._find_first_mesh(child)
		if found != null:
			return found
	return null

func _apply_material(root: Node, material: Material) -> void:
	if root is MeshInstance3D:
		# Preserve authored animal eyes while applying the Wychwood role tint to
		# the body, so distinct silhouettes also retain readable faces.
		var mesh_name: Variant = str(root.name).to_lower()
		if not (mesh_name.contains("eye") or mesh_name.contains("pupil")):
			root.material_override = material
	for child in root.get_children():
		_actor._apply_material(child, material)

func _apply_bad_material_fallback(root: Node, material: Material) -> void:
	if root is MeshInstance3D:
		var mesh_instance = root as MeshInstance3D
		if _actor._mesh_needs_visible_material(mesh_instance):
			mesh_instance.material_override = material
	for child in root.get_children():
		_actor._apply_bad_material_fallback(child, material)

func _mesh_needs_visible_material(mesh_instance: MeshInstance3D) -> bool:
	if mesh_instance.material_override != null:
		return _actor._is_bad_white_material(mesh_instance.material_override)
	if mesh_instance.mesh == null:
		return true
	var saw_material = false
	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		var material = mesh_instance.mesh.surface_get_material(surface_index)
		if material == null:
			continue
		saw_material = true
		if _actor._is_bad_white_material(material):
			return true
	return not saw_material

func _is_bad_white_material(material: Material) -> bool:
	if material == null:
		return true
	if material is StandardMaterial3D:
		var standard = material as StandardMaterial3D
		var color = standard.albedo_color
		return standard.albedo_texture == null and color.r > 0.85 and color.g > 0.85 and color.b > 0.85
	return false

func _add_part(pos: Vector3, scale_value: Vector3, color: Color, shape_name: String, rot_degrees: Vector3 = Vector3.ZERO) -> void:
	var part = MeshInstance3D.new()
	if shape_name == "sphere":
		part.mesh = SphereMesh.new()
	elif shape_name == "capsule":
		part.mesh = CapsuleMesh.new()
	elif shape_name == "cylinder":
		var cylinder: Variant = CylinderMesh.new()
		cylinder.top_radius = 0.5
		cylinder.bottom_radius = 0.62
		cylinder.height = 1.0
		cylinder.radial_segments = 10
		part.mesh = cylinder
	elif shape_name == "cone":
		var cone: Variant = CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.5
		cone.height = 1.0
		cone.radial_segments = 6
		part.mesh = cone
	else:
		var mesh = BoxMesh.new()
		mesh.size = Vector3.ONE
		part.mesh = mesh
	part.position = pos
	part.rotation_degrees = rot_degrees
	part.scale = scale_value
	part.material_override = _actor._mat(color)
	# Boss identity pieces belong to the phase-animated identity layer. Keeping
	# them beside that layer made shoulders and chains lag behind the bell/eyes
	# during phase pulses and made the encounter read as detached geometry.
	var parent: Node3D = _actor.boss_visual_root if _actor.boss_visual_root != null else _actor.visual_root
	if parent != null:
		parent.add_child(part)
	else:
		_actor.add_child(part)
