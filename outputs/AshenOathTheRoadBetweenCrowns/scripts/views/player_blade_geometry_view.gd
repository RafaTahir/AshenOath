extends RefCounted
## player blade geometry view: scene-only responsibilities.

var _actor: CharacterBody3D

func _init(actor: CharacterBody3D) -> void:
	_actor = actor

func _configure_blade_markers(parent: Node3D, base_position: Vector3, tip_position: Vector3, fit_rendered_bounds: bool = false) -> void:
	if parent == null:
		return
	if fit_rendered_bounds:
		var fitted: Dictionary = _actor._blade_axis_from_rendered_bounds(parent)
		base_position = fitted.get("base", base_position)
		tip_position = fitted.get("tip", tip_position)
	_actor.blade_base_marker = Node3D.new()
	_actor.blade_base_marker.name = "BladeContactBase"
	_actor.blade_base_marker.position = base_position
	parent.add_child(_actor.blade_base_marker)
	_actor.blade_tip_marker = Node3D.new()
	_actor.blade_tip_marker.name = "BladeContactTip"
	_actor.blade_tip_marker.position = tip_position
	parent.add_child(_actor.blade_tip_marker)

func _blade_axis_from_rendered_bounds(parent: Node3D) -> Dictionary:
	var bounds: Variant = AABB()
	var has_bounds: Variant = false
	var inverse_parent: Variant = parent.global_transform.affine_inverse()
	for child in parent.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: Variant = child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var local_transform: Transform3D = inverse_parent * mesh_instance.global_transform
		var local_bounds: AABB = local_transform * mesh_instance.mesh.get_aabb()
		bounds = bounds.merge(local_bounds) if has_bounds else local_bounds
		has_bounds = true
	if not has_bounds:
		return {}
	var axis: Variant = 0
	if bounds.size.y > bounds.size.x and bounds.size.y >= bounds.size.z:
		axis = 1
	elif bounds.size.z > bounds.size.x and bounds.size.z > bounds.size.y:
		axis = 2
	var first: Variant = bounds.get_center()
	var second: Variant = bounds.get_center()
	first[axis] = bounds.position[axis]
	second[axis] = bounds.end[axis]
	var base: Variant = first if first.length_squared() <= second.length_squared() else second
	var tip: Variant = second if base == first else first
	return {"base": base, "tip": tip}

func _attach_rig_sword(mapped: Node3D) -> Node3D:
	var skeleton: Variant = _actor._find_skeleton(mapped)
	if skeleton == null:
		return null
	var hand_index: Variant = skeleton.find_bone("RightHand")
	if hand_index < 0:
		hand_index = skeleton.find_bone("Hand.R")
	if hand_index < 0:
		hand_index = skeleton.find_bone("hand_r")
	if hand_index < 0:
		hand_index = skeleton.find_bone("Weapon.R")
	if hand_index < 0:
		hand_index = skeleton.find_bone("Fist.R")
	if hand_index < 0:
		for bone_index in range(skeleton.get_bone_count()):
			var bone_name: Variant = str(skeleton.get_bone_name(bone_index)).to_lower()
			if bone_name.contains("right") and (bone_name.contains("hand") or bone_name.contains("wrist")):
				hand_index = bone_index
				break
	if hand_index < 0:
		for bone_index in range(skeleton.get_bone_count()):
			var bone_name: Variant = str(skeleton.get_bone_name(bone_index)).to_lower()
			if bone_name.contains("hand") or bone_name.contains("wrist"):
				hand_index = bone_index
				break
	if hand_index < 0:
		return null
	var attachment: Variant = BoneAttachment3D.new()
	attachment.name = "KaelSwordSocket"
	attachment.bone_idx = hand_index
	attachment.bone_name = skeleton.get_bone_name(hand_index)
	skeleton.add_child(attachment)
	_actor.sword_attachment = attachment
	if skeleton.find_bone("upperarm_r") >= 0 and skeleton.get_bone_name(hand_index) == "hand_r":
		_actor.guard_arm_ik = SkeletonIK3D.new()
		_actor.guard_arm_ik.name = "GuardArmPose"
		_actor.guard_arm_ik.root_bone = &"upperarm_r"
		_actor.guard_arm_ik.tip_bone = &"hand_r"
		_actor.guard_arm_ik.override_tip_basis = false
		_actor.guard_arm_ik.max_iterations = 12
		skeleton.add_child(_actor.guard_arm_ik)
	var equipment_space: Variant = _actor._create_equipment_space(attachment, "KaelSwordEquipmentSpace")
	_actor.sword_equipment_pivot = Node3D.new()
	_actor.sword_equipment_pivot.name = "KaelSwordGripPivot"
	equipment_space.add_child(_actor.sword_equipment_pivot)
	# The pivot remains inside the normalized hand attachment hierarchy. Its
	# grip basis is calibrated from the imported hand once the skeleton is live;
	# subsequent poses preserve that hand frame and add only deliberate combat
	# motion. This prevents the weapon from becoming a detached world object.
	_actor.sword_grip_basis = Basis.IDENTITY
	_actor.sword_grip_calibrated = false
	# The imported FBX had null Compatibility surfaces and was hidden
	# immediately. Use the validated Web-safe weapon directly.
	var held_blades: Variant = Node3D.new()
	held_blades.name = "KaelHeldBlades"
	_actor.sword_equipment_pivot.add_child(held_blades)
	for blade_id: String in _actor.EquipmentLoadout.BLADE_IDS:
		_actor.blade_hand_visuals[blade_id] = _actor._build_oathblade_visual(held_blades, blade_id)
	return held_blades

func _build_oathblade_visual(parent: Node3D, blade_id: String = "steel") -> Node3D:
	var oathblade: Variant = Node3D.new()
	oathblade.name = "KaelOathblade" if blade_id == "oathblade" else "KaelSteelSword"
	_actor.write_presentation_tag(oathblade, "blade_id", blade_id)
	# The hand, markers, slash ribbon, and collision all share this normalized
	# weapon root. Prefer the authored Quaternius sword; its FBX importer keeps
	# a 100x source-unit transform, so the child is normalized once here rather
	# than allowing that source scale to leak into the hand socket.
	oathblade.scale = Vector3.ONE
	parent.add_child(oathblade)
	if _actor._attach_modeled_sword(oathblade, blade_id):
		_actor.write_presentation_tag(oathblade, "weapon_visual_source", _actor.MODELED_SWORD_PATH)
		return oathblade
	# Keep a local diagnostic fallback for a missing imported source. The runtime
	# asset gate still rejects that state; this branch exists only to keep native
	# tools able to report the missing asset without silently losing the socket.
	push_error("Modeled sword source could not be loaded: %s" % _actor.MODELED_SWORD_PATH)
	var steel: Variant = _actor._metal_mat(Color(0.84, 0.88, 0.92))
	steel.metallic = 0.72
	steel.roughness = 0.20
	steel.emission_enabled = true
	steel.emission = Color(0.055, 0.065, 0.075)
	steel.emission_energy_multiplier = 0.22
	steel.emission_enabled = false
	steel.cull_mode = BaseMaterial3D.CULL_DISABLED
	var blade: Variant = MeshInstance3D.new()
	blade.name = "OathbladeSteel"
	blade.mesh = _actor._build_oathblade_mesh()
	blade.material_override = steel
	oathblade.add_child(blade)
	var guard: Variant = MeshInstance3D.new()
	guard.name = "OathbladeGuard"
	var guard_mesh: Variant = BoxMesh.new()
	guard_mesh.size = Vector3(0.25, 0.055, 0.072)
	guard.mesh = guard_mesh
	guard.position = Vector3(0.0, -0.075, 0.0)
	guard.material_override = _actor._metal_mat(Color(0.64, 0.43, 0.17))
	oathblade.add_child(guard)
	var grip: Variant = MeshInstance3D.new()
	grip.name = "OathbladeGrip"
	var grip_mesh: Variant = CylinderMesh.new()
	grip_mesh.top_radius = 0.028
	grip_mesh.bottom_radius = 0.032
	grip_mesh.height = 0.19
	grip_mesh.radial_segments = 8
	grip.mesh = grip_mesh
	grip.position = Vector3(0.0, 0.065, 0.0)
	grip.material_override = _actor._mat(Color(0.18, 0.07, 0.035))
	oathblade.add_child(grip)
	var pommel: Variant = MeshInstance3D.new()
	pommel.name = "OathbladePommel"
	var pommel_mesh: Variant = SphereMesh.new()
	pommel_mesh.radius = 0.045
	pommel_mesh.height = 0.09
	pommel.mesh = pommel_mesh
	pommel.position = Vector3(0.0, 0.18, 0.0)
	pommel.material_override = _actor._metal_mat(Color(0.52, 0.34, 0.15))
	oathblade.add_child(pommel)
	return oathblade

func _attach_modeled_sword(oathblade: Node3D, blade_id: String = "steel") -> bool:
	var modeled: Node3D = null
	if _actor.asset_helper != null and (_actor.asset_helper != null) and (_actor.asset_helper != null):
		var resource = _actor.asset_helper.load_runtime_resource(_actor.MODELED_SWORD_PATH)
		modeled = _actor.asset_helper.instantiate_runtime_resource(resource)
	else:
		var resource = ResourceLoader.load(_actor.MODELED_SWORD_PATH)
		if resource is PackedScene:
			var instance: Variant = (resource as PackedScene).instantiate()
			if instance is Node3D:
				modeled = instance as Node3D
	if modeled == null:
		return false
	modeled.name = "OathbladeModeledMesh"
	# The imported Sword mesh is authored along its local +Y after the FBX
	# conversion. Flip it so the hilt stays at the hand and the blade extends
	# down local -Y, matching the existing contact-marker contract.
	modeled.rotation_degrees = Vector3(180.0, 0.0, 0.0)
	# Both blades retain the same physical reach; cross-section and finish differ.
	modeled.scale = (Vector3(1.12, 1.0, 0.92) if blade_id == "oathblade" else Vector3.ONE) * 0.22
	modeled.position = Vector3(0.0, 0.045, 0.0)
	oathblade.add_child(modeled)
	var mesh_count: Variant = 0
	var canonical_blade: MeshInstance3D = null
	var finish: Variant = _actor._metal_mat(Color(0.65, 0.80, 0.82) if blade_id == "oathblade" else Color(0.78, 0.82, 0.88))
	for raw_mesh in modeled.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: Variant = raw_mesh as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		mesh_count += 1
		if canonical_blade == null:
			canonical_blade = mesh_instance
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		# Keep the blade readable while retaining leather grip, painted leather
		# and brass fittings as separate physical surfaces. The prior whole-mesh
		# override turned all four authored slots into the blade's steel/cyan.
		if mesh_instance.mesh.get_surface_count() == 0:
			mesh_instance.material_override = _actor._metal_mat(Color(0.72, 0.78, 0.82))
		else:
			mesh_instance.material_override = null
			for surface_index in range(mesh_instance.mesh.get_surface_count()):
				var source: Variant = mesh_instance.get_active_material(surface_index) as StandardMaterial3D
				var label: Variant = source.resource_name.to_lower() if source != null else "metal"
				if source == null or label.contains("metal") or label.contains("steel") or label.contains("blade"):
					mesh_instance.set_surface_override_material(surface_index, finish)
				elif label.contains("gold") or label.contains("brass"):
					var fitting: Variant = source.duplicate() as StandardMaterial3D
					fitting.metallic = .72
					fitting.roughness = .46
					mesh_instance.set_surface_override_material(surface_index, fitting)
				elif label.contains("brown") or label.contains("red") or label.contains("leather"):
					var grip: Variant = source.duplicate() as StandardMaterial3D
					grip.metallic = 0.0
					grip.roughness = .88
					mesh_instance.set_surface_override_material(surface_index, grip)
	if canonical_blade != null:
		# Keep the imported geometry as the single source of truth while exposing
		# the stable blade contract used by contact, visuals, and release gates.
		canonical_blade.name = "OathbladeSteel"
		_actor.write_presentation_tag(canonical_blade, "modeled_blade", true)
	return mesh_count > 0 and canonical_blade != null

func _build_oathblade_mesh() -> ImmediateMesh:
	var mesh: Variant = ImmediateMesh.new()
	var vertices: Variant = [
		# A restrained single-edged hunter blade: narrow shoulder, shallow
		# fuller, and a centered point. The previous 15 cm shoulder made the
		# weapon read as a pale wedge at gameplay distance.
		Vector3(-0.050, -0.10, 0.026), Vector3(0.050, -0.10, 0.026), Vector3(0.034, -0.72, 0.018),
		Vector3(-0.034, -0.72, 0.018), Vector3(0.0, -1.02, 0.0),
		Vector3(-0.050, -0.10, -0.026), Vector3(0.050, -0.10, -0.026), Vector3(0.034, -0.72, -0.018),
		Vector3(-0.034, -0.72, -0.018), Vector3(0.0, -1.02, 0.0)
	]
	var faces: Variant = [
		[0, 1, 2], [0, 2, 3], [5, 7, 6], [5, 8, 7], [3, 2, 4], [8, 9, 4],
		[0, 5, 6], [0, 6, 1], [1, 6, 7], [1, 7, 2], [2, 7, 9], [2, 9, 4],
		[4, 9, 8], [4, 8, 3], [3, 8, 5], [3, 5, 0]
	]
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in faces:
		var a: Vector3 = vertices[face[0]]
		var b: Vector3 = vertices[face[1]]
		var c: Vector3 = vertices[face[2]]
		var normal: Variant = (b - a).cross(c - a).normalized()
		mesh.surface_set_normal(normal)
		mesh.surface_add_vertex(a)
		mesh.surface_set_normal(normal)
		mesh.surface_add_vertex(b)
		mesh.surface_set_normal(normal)
		mesh.surface_add_vertex(c)
	mesh.surface_end()
	return mesh

func _add_mapped_weapon_visuals() -> void:
	_actor._add_weapon_visuals(Vector3(0.42, 0.84, -0.42))

func _add_weapon_visuals(local_pos: Vector3) -> void:
	_actor.weapon_root = Node3D.new()
	_actor.weapon_root.name = "visible_sword_root"
	_actor.weapon_root.position = local_pos
	_actor.weapon_root.rotation_degrees = _actor._weapon_ready_pose()
	_actor.visual_root.add_child(_actor.weapon_root)

	var sword = MeshInstance3D.new()
	sword.name = "visible_sword_blade"
	var sword_mesh = BoxMesh.new()
	sword_mesh.size = Vector3(0.105, 0.060, 1.78)
	sword.mesh = sword_mesh
	sword.position = Vector3(0.0, 0.28, -0.66)
	sword.material_override = _actor._metal_mat(Color(0.68, 0.70, 0.68))
	_actor.weapon_root.add_child(sword)
	_actor.sword_visual = sword
	_actor._configure_blade_markers(_actor.weapon_root, Vector3(0.0, 0.25, 0.02), Vector3(0.0, 0.28, -1.56))

	var hilt = MeshInstance3D.new()
	hilt.name = "visible_sword_hilt"
	var hilt_mesh = BoxMesh.new()
	hilt_mesh.size = Vector3(0.42, 0.080, 0.095)
	hilt.mesh = hilt_mesh
	hilt.position = Vector3(0.0, -0.04, 0.03)
	hilt.material_override = _actor._mat(Color(0.13, 0.08, 0.045))
	_actor.weapon_root.add_child(hilt)
	_actor.sword_hilt_visual = hilt

	var pommel = MeshInstance3D.new()
	pommel.name = "visible_sword_pommel"
	var pommel_mesh = BoxMesh.new()
	pommel_mesh.size = Vector3(0.13, 0.13, 0.13)
	pommel.mesh = pommel_mesh
	pommel.position = Vector3(0.0, -0.15, 0.14)
	pommel.material_override = _actor._metal_mat(Color(0.37, 0.34, 0.28))
	_actor.weapon_root.add_child(pommel)

	var trail = MeshInstance3D.new()
	trail.name = "visible_sword_swing_trail"
	var trail_mesh = BoxMesh.new()
	trail_mesh.size = Vector3(0.24, 0.16, 2.45)
	trail.mesh = trail_mesh
	trail.position = Vector3(0.30, 0.34, -0.92)
	trail.rotation_degrees.z = -24.0
	trail.material_override = _actor._trail_mat(Color(1.0, 0.78, 0.36, 0.88))
	trail.visible = false
	_actor.weapon_root.add_child(trail)
	_actor.sword_trail_visual = trail
	_actor._add_slash_arc_visuals()

func _weapon_ready_pose() -> Vector3:
	return Vector3(18, 0, 8)
