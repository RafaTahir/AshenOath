extends RefCounted
## player equipment view: scene-only responsibilities.

var _actor: CharacterBody3D

func _init(actor: CharacterBody3D) -> void:
	_actor = actor

func _build_bow_visual() -> void:
	if _actor.bow_visual != null:
		return
	var skeleton: Skeleton3D = _actor._find_skeleton(_actor.visual_root)
	var hand_parent: Node3D = _actor.visual_root
	if skeleton != null:
		var hand_aliases: Array[String] = ["LeftHand", "Hand.L", "Fist.L", "FistL", "hand_l", "lefthand"]
		var hand_index: Variant = _actor._find_bone_index(skeleton, hand_aliases)
		if hand_index >= 0:
			_actor.bow_attachment = BoneAttachment3D.new()
			_actor.bow_attachment.name = "KaelBowHandSocket"
			_actor.bow_attachment.bone_idx = hand_index
			_actor.bow_attachment.bone_name = skeleton.get_bone_name(hand_index)
			skeleton.add_child(_actor.bow_attachment)
			hand_parent = _actor._create_equipment_space(_actor.bow_attachment, "KaelBowHandEquipmentSpace")
	_actor.bow_visual = Node3D.new()
	_actor.bow_visual.name = "KaelBowHandEquipment"
	_actor.bow_visual.position = Vector3(0.04, -0.02, 0.04) if hand_parent != _actor.visual_root else Vector3(-0.38, 1.20, 0.20)
	_actor.bow_visual.rotation_degrees = Vector3(0.0, 8.0, -12.0)
	# The retained source is normalized to .44m-source scale by BowPresentation.
	# Keep its hand parent unit-sized during transfers too; the former .82
	# parent made it shrink at draw contact and grow when aiming took ownership.
	_actor.bow_visual.scale = Vector3.ONE
	_actor.bow_visual.visible = false
	hand_parent.add_child(_actor.bow_visual)
	var modeled_bow: Variant = _actor._instantiate_modeled_prop(_actor.MODELED_BOW_PATH)
	if modeled_bow != null:
		modeled_bow.name = "KaelBowModeled"
		# The Ranger prop is authored along local Y, like the sword. Normalize the
		# source once inside the existing hand socket; the controller still owns
		# aim, draw, release, and visibility state.
		modeled_bow.scale = Vector3.ONE * 0.30
		modeled_bow.position = Vector3(0.04, -0.01, 0.04)
		_actor._prepare_modeled_prop(modeled_bow, Color(0.24, 0.12, 0.055))
		_actor.write_presentation_tag(modeled_bow, "equipment_visual_source", _actor.MODELED_BOW_PATH)
		_actor.write_presentation_tag(_actor.bow_visual, "equipment_visual_source", _actor.MODELED_BOW_PATH)
		_actor.bow_visual.add_child(modeled_bow)
	else:
		_actor.write_presentation_tag(_actor.bow_visual, "equipment_visual_failure", _actor.MODELED_BOW_PATH)
		push_error("Modeled bow source could not be loaded: %s" % _actor.MODELED_BOW_PATH)
	var quiver_parent: Node3D = _actor.visual_root
	if skeleton != null:
		var back_aliases: Array[String] = ["spine_03", "spine_02", "Spine3", "Spine2", "Chest", "Torso", "Spine", "Body"]
		var back_index: Variant = _actor._find_bone_index(skeleton, back_aliases)
		if back_index >= 0:
			_actor.bow_quiver_attachment = BoneAttachment3D.new()
			_actor.bow_quiver_attachment.name = "KaelQuiverBackSocket"
			_actor.bow_quiver_attachment.bone_idx = back_index
			_actor.bow_quiver_attachment.bone_name = skeleton.get_bone_name(back_index)
			skeleton.add_child(_actor.bow_quiver_attachment)
			quiver_parent = _actor._create_equipment_space(_actor.bow_quiver_attachment, "KaelQuiverBackEquipmentSpace")
	if quiver_parent != _actor.visual_root:
		_actor.bow_back_visual = Node3D.new()
		_actor.bow_back_visual.name = "KaelStowedBow"
		_actor.bow_back_visual.position = Vector3(-0.25, 0.16, -0.36)
		_actor.bow_back_visual.rotation_degrees = Vector3(0.0, 0.0, 24.0)
		_actor.bow_back_visual.scale = Vector3.ONE * 0.82
		quiver_parent.add_child(_actor.bow_back_visual)
		var stowed_bow: Variant = _actor._instantiate_modeled_prop(_actor.MODELED_BOW_PATH)
		if stowed_bow != null:
			stowed_bow.scale = Vector3.ONE * (0.44 / 0.82)
			stowed_bow.rotation = Vector3(0, -PI * 0.5, 0)
			stowed_bow.position = Vector3(0, 0, 0.094 / 0.82)
			_actor._prepare_modeled_prop(stowed_bow, Color(0.24, 0.12, 0.055))
			for packed_prop in stowed_bow.find_children("*", "MeshInstance3D", true, false):
				if str(packed_prop.name).to_lower().contains("arrow"): packed_prop.visible = false
			_actor.bow_back_visual.add_child(stowed_bow)
	if skeleton != null:
		_actor.equipment_left_arm_ik = _actor._make_arm_pose_ik(skeleton, "BowEquipmentReach", &"upperarm_l", &"hand_l")
	_actor.bow_quiver_visual = Node3D.new()
	_actor.bow_quiver_visual.name = "KaelQuiverBackEquipment"
	_actor.bow_quiver_visual.position = Vector3(-0.22, -0.12, 0.16) if quiver_parent != _actor.visual_root else Vector3(-0.22, 1.05, 0.28)
	_actor.bow_quiver_visual.rotation_degrees = Vector3(12.0, 0.0, -18.0)
	quiver_parent.add_child(_actor.bow_quiver_visual)
	var quiver: Variant = MeshInstance3D.new()
	quiver.name = "KaelArrowQuiver"
	quiver.mesh = _actor.HeldPropGeometry.vessel(.08,.06,.60,.008,16)
	quiver.material_override = _actor._mat(Color(0.12, 0.07, 0.035))
	_actor.bow_quiver_visual.add_child(quiver)
	var modeled_arrow: Variant = _actor._instantiate_modeled_prop(_actor.MODELED_ARROW_PATH)
	if modeled_arrow != null:
		modeled_arrow.name = "KaelQuiverArrow"
		modeled_arrow.scale = Vector3.ONE * 0.30
		# Seat the point toward the closed base and expose the fletching at the
		# open rim. Nocked/projectile orientation remains owned by ArrowVisual.
		modeled_arrow.rotation_degrees.x = 180.0
		modeled_arrow.position = Vector3(0.0, 0.10, 0.0)
		_actor._prepare_modeled_prop(modeled_arrow, Color(0.58, 0.42, 0.24))
		_actor.write_presentation_tag(modeled_arrow, "equipment_visual_source", _actor.MODELED_ARROW_PATH)
		_actor.bow_quiver_visual.add_child(modeled_arrow)
	else:
		_actor.write_presentation_tag(_actor.bow_quiver_visual, "equipment_visual_failure", _actor.MODELED_ARROW_PATH)
		push_error("Modeled arrow source could not be loaded: %s" % _actor.MODELED_ARROW_PATH)
	if skeleton != null and modeled_bow != null:
		_actor.bow_presentation = preload("res://scripts/bow_presentation.gd").new()
		_actor.bow_presentation.name = "KaelArcheryPose"
		skeleton.add_child(_actor.bow_presentation)
		var nocked_arrow: Variant = _actor._instantiate_modeled_prop(_actor.MODELED_ARROW_PATH)
		if nocked_arrow != null: _actor._prepare_modeled_prop(nocked_arrow, Color(0.58, 0.42, 0.24))
		_actor.bow_presentation.setup(_actor, _actor.bow_visual, modeled_bow, nocked_arrow)

func _instantiate_modeled_prop(path: String) -> Node3D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	if _actor.asset_helper != null and (_actor.asset_helper != null) and (_actor.asset_helper != null):
		var cached_resource = _actor.asset_helper.load_runtime_resource(path)
		var cached_instance: Node3D = _actor.asset_helper.instantiate_runtime_resource(cached_resource)
		if cached_instance != null:
			return cached_instance
	var resource = ResourceLoader.load(path)
	if resource is PackedScene:
		var instance: Variant = (resource as PackedScene).instantiate()
		return instance as Node3D
	if resource is Mesh:
		var mesh_instance: Variant = MeshInstance3D.new()
		mesh_instance.mesh = resource as Mesh
		return mesh_instance
	return null

func _prepare_modeled_prop(root: Node3D, fallback_color: Color) -> void:
	if root == null:
		return
	for raw_mesh in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: Variant = raw_mesh as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var material: Variant = mesh_instance.get_surface_override_material(surface_index)
			if material == null:
				material = mesh_instance.mesh.surface_get_material(surface_index)
			if material == null:
				mesh_instance.set_surface_override_material(surface_index, _actor._mat(fallback_color))
			elif material is StandardMaterial3D and material.albedo_texture == null and material.albedo_color.r > 0.85 and material.albedo_color.g > 0.85 and material.albedo_color.b > 0.85:
				var fitted: Variant = material.duplicate() as StandardMaterial3D
				fitted.albedo_color = fallback_color
				fitted.roughness = 0.75
				fitted.metallic = 0.0
				mesh_instance.set_surface_override_material(surface_index, fitted)

func _build_sheathed_sword() -> void:
	var skeleton: Skeleton3D = _actor._find_skeleton(_actor.visual_root)
	if skeleton == null:
		push_error("Kael's back equipment requires his character skeleton")
		return
	var back_aliases: Array[String] = ["spine_03", "spine_02", "Spine3", "Spine2", "Chest", "Torso", "Spine", "Body"]
	var back_index: Variant = _actor._find_bone_index(skeleton, back_aliases)
	if back_index < 0:
		push_error("Kael's back equipment requires a validated spine bone")
		return
	var attachment: Variant = BoneAttachment3D.new()
	attachment.name = "KaelBackSwordSocket"
	attachment.bone_idx = back_index
	attachment.bone_name = skeleton.get_bone_name(back_index)
	skeleton.add_child(attachment)
	var socket_parent: Variant = _actor._create_equipment_space(attachment, "KaelBackSwordEquipmentSpace")
	_actor.sheathed_sword_visual = Node3D.new()
	_actor.sheathed_sword_visual.name = "KaelBackScabbards"
	socket_parent.add_child(_actor.sheathed_sword_visual)
	var scabbard_mesh: Variant = _actor._build_scabbard_mesh()
	for blade_id: String in _actor.EquipmentLoadout.BLADE_IDS:
		var oath: Variant = blade_id == "oathblade"
		var assembly: Variant = Node3D.new()
		assembly.name = "OathbladeBackScabbard" if oath else "SteelBackScabbard"
		assembly.position = Vector3(0.14 if oath else -0.12, 0.22, -0.20)
		assembly.rotation_degrees = Vector3(-6.0, 0.0, 28.0 if oath else -28.0)
		_actor.sheathed_sword_visual.add_child(assembly)
		_actor.blade_scabbards[blade_id] = assembly
		var housed_blade: Variant = Node3D.new()
		housed_blade.name = "HousedOathblade" if oath else "HousedSteel"
		assembly.add_child(housed_blade)
		_actor.write_presentation_tag(housed_blade, "blade_id", blade_id)
		if not _actor._attach_modeled_sword(housed_blade, blade_id):
			push_error("Back sword source could not be loaded: " + _actor.MODELED_SWORD_PATH)
		_actor.blade_back_visuals[blade_id] = housed_blade
		var scabbard: Variant = MeshInstance3D.new()
		scabbard.name = "ScabbardBody"
		scabbard.mesh = scabbard_mesh
		scabbard.material_override = _actor._mat(Color(0.15, 0.18, 0.18) if oath else Color(0.20, 0.14, 0.10))
		assembly.add_child(scabbard)
		var trim: Variant = _actor._metal_mat(Color(0.46, 0.53, 0.54) if oath else Color(0.42, 0.30, 0.16))
		var throat: Variant = MeshInstance3D.new()
		throat.name = "ScabbardThroat"
		var throat_mesh: Variant = CylinderMesh.new()
		throat_mesh.top_radius = 1.0
		throat_mesh.bottom_radius = 1.0
		throat_mesh.height = 0.035
		throat_mesh.radial_segments = 8
		throat.mesh = throat_mesh
		throat.scale = Vector3(0.061, 1.0, 0.026)
		throat.position = Vector3(0.0, -0.065, 0.0)
		throat.material_override = trim
		assembly.add_child(throat)
		var cap: Variant = MeshInstance3D.new()
		cap.name = "ScabbardCap"
		var cap_mesh: Variant = SphereMesh.new()
		cap_mesh.radius = 0.025
		cap_mesh.height = 0.05
		cap_mesh.radial_segments = 8
		cap_mesh.rings = 3
		cap.mesh = cap_mesh
		cap.scale.z = 0.65
		cap.position = Vector3(0.0, -0.835, 0.0)
		cap.material_override = trim
		assembly.add_child(cap)

static var _scabbard_mesh: WeakRef

func _build_scabbard_mesh() -> ArrayMesh:
	var cached: Variant = _scabbard_mesh.get_ref() as ArrayMesh if _scabbard_mesh != null else null
	if cached != null:
		return cached
	var surface: Variant = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var section: Variant = [Vector2(-0.75, -1), Vector2(0.75, -1), Vector2(1, -0.65), Vector2(1, 0.65), Vector2(0.75, 1), Vector2(-0.75, 1), Vector2(-1, 0.65), Vector2(-1, -0.65)]
	var profiles: Variant = [Vector3(0.058, -0.065, 0.024), Vector3(0.048, -0.68, 0.021), Vector3(0.020, -0.835, 0.016)]
	for ring in range(profiles.size() - 1):
		for side in range(section.size()):
			var next: Variant = (side + 1) % section.size()
			var a: Vector3 = profiles[ring]
			var b: Vector3 = profiles[ring + 1]
			var vertices: Variant = [Vector3(section[side].x * a.x, a.y, section[side].y * a.z), Vector3(section[next].x * a.x, a.y, section[next].y * a.z), Vector3(section[next].x * b.x, b.y, section[next].y * b.z), Vector3(section[side].x * b.x, b.y, section[side].y * b.z)]
			for index in [0, 2, 1, 0, 3, 2]:
				surface.add_vertex(vertices[index])
	surface.generate_normals()
	var mesh: Variant = surface.commit()
	_scabbard_mesh = weakref(mesh)
	return mesh

func _make_sword_readable(sword: Node3D) -> void:
	var blade_material: Variant = _actor._metal_mat(Color(0.72, 0.78, 0.82))
	blade_material.metallic = 0.72
	blade_material.roughness = 0.30
	var found_mesh: Variant = false
	for child in sword.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: Variant = child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		found_mesh = true
		mesh_instance.visible = true
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mesh_instance.material_override = blade_material
	if found_mesh:
		return
	var blade: Variant = MeshInstance3D.new()
	blade.name = "KaelReadableSwordBlade"
	var blade_mesh: Variant = BoxMesh.new()
	blade_mesh.size = Vector3(0.065, 1.02, 0.035)
	blade.mesh = blade_mesh
	blade.position = Vector3(0.0, -0.53, 0.0)
	blade.material_override = blade_material
	sword.add_child(blade)
	var guard: Variant = MeshInstance3D.new()
	guard.name = "KaelReadableSwordGuard"
	var guard_mesh: Variant = BoxMesh.new()
	guard_mesh.size = Vector3(0.28, 0.055, 0.055)
	guard.mesh = guard_mesh
	guard.position = Vector3(0.0, -0.02, 0.0)
	guard.material_override = _actor._metal_mat(Color(0.42, 0.32, 0.18))
	sword.add_child(guard)

func _create_equipment_space(attachment: BoneAttachment3D, space_name: String) -> Node3D:
	var equipment_space: Variant = Node3D.new()
	equipment_space.name = space_name
	attachment.add_child(equipment_space)
	var inherited_scale: Variant = attachment.global_basis.get_scale()
	equipment_space.scale = Vector3(
		1.0 / max(abs(inherited_scale.x), 0.0001),
		1.0 / max(abs(inherited_scale.y), 0.0001),
		1.0 / max(abs(inherited_scale.z), 0.0001)
	)
	return equipment_space

func _ensure_equipment_loadout() -> void:
	_actor.equipment_loadout.bind_node("sword_hand", _actor.rig_sword_visual if _actor.rig_sword_visual != null else _actor.weapon_root)
	for blade_id: String in _actor.EquipmentLoadout.BLADE_IDS:
		_actor.equipment_loadout.bind_node(blade_id + "_hand", _actor.blade_hand_visuals.get(blade_id))
		_actor.equipment_loadout.bind_node(blade_id + "_back", _actor.blade_back_visuals.get(blade_id))
		_actor.equipment_loadout.bind_node(blade_id + "_scabbard", _actor.blade_scabbards.get(blade_id))
	_actor.equipment_loadout.bind_node("bow", _actor.bow_visual)
	_actor.equipment_loadout.bind_node("bow_back", _actor.bow_back_visual)
	_actor.equipment_loadout.bind_node("quiver", _actor.bow_quiver_visual)
	_actor.equipment_loadout.set_active_weapon(_actor.weapon_mode)
	_actor.equipment_loadout.set_sword_drawn(not _actor.sword_sheathed)
	_actor.equipment_loadout.set_selected_arrow(_actor.selected_arrow_id)
