extends RefCounted
## enemy identity view: scene-only responsibilities.

var _actor: CharacterBody3D

func _init(actor: CharacterBody3D) -> void:
	_actor = actor

func _add_spectral_antler_crown(mapped: Node3D) -> void:
	var skeleton: Variant = _actor._find_type(mapped, "Skeleton3D") as Skeleton3D
	var parent: Node3D = mapped
	if skeleton != null:
		var attachment: Variant = BoneAttachment3D.new()
		attachment.name = "WhiteHartAntlerHeadAttachment"
		attachment.bone_name = "Bone.003"
		skeleton.add_child(attachment)
		parent = attachment
		# The imported Wolf FBX carries a large head-bone scale. Compensate only
		# that scale so the antlers remain attached without becoming world-sized.
		var mapped_scale: Variant = mapped.global_transform.basis.get_scale() if mapped.is_inside_tree() else Vector3.ONE
		var attachment_scale: Variant = attachment.global_transform.basis.get_scale() if attachment.is_inside_tree() else Vector3(19.36, 19.36, 19.36)
		var bone_scale: Variant = Vector3(
			_actor._safe_scale_ratio(attachment_scale.x, mapped_scale.x),
			_actor._safe_scale_ratio(attachment_scale.y, mapped_scale.y),
			_actor._safe_scale_ratio(attachment_scale.z, mapped_scale.z)
		)
		var crown_root: Variant = Node3D.new()
		crown_root.name = "WhiteHartAntlerScaleCompensation"
		crown_root.scale = Vector3(
			_actor._safe_inverse_scale(bone_scale.x),
			_actor._safe_inverse_scale(bone_scale.y),
			_actor._safe_inverse_scale(bone_scale.z)
		)
		parent.add_child(crown_root)
		parent = crown_root
	var antler_material: Variant = _actor._mat(Color(0.58, 0.48, 0.30))
	antler_material.emission_enabled = true
	antler_material.emission = Color(0.20, 0.48, 0.34)
	antler_material.emission_energy_multiplier = 0.42
	for side in [-1.0, 1.0]:
		var main: Variant = MeshInstance3D.new()
		main.name = "SpectralAntlerMain"
		var main_mesh: Variant = CylinderMesh.new()
		main_mesh.top_radius = 0.025
		main_mesh.bottom_radius = 0.055
		main_mesh.height = 0.78
		main_mesh.radial_segments = 8
		main.mesh = main_mesh
		main.position = Vector3(side * 0.16, 0.28, 0.01)
		main.rotation_degrees.z = side * -20.0
		main.material_override = antler_material
		parent.add_child(main)
		for branch_index in range(2):
			var branch: Variant = MeshInstance3D.new()
			branch.name = "SpectralAntlerBranch"
			var branch_mesh: Variant = CylinderMesh.new()
			branch_mesh.top_radius = 0.014
			branch_mesh.bottom_radius = 0.035
			branch_mesh.height = 0.34 if branch_index == 0 else 0.25
			branch_mesh.radial_segments = 8
			branch.mesh = branch_mesh
			branch.position = Vector3(side * (0.29 + branch_index * 0.06), 0.46 + branch_index * 0.17, 0.01)
			branch.rotation_degrees.z = side * (42.0 if branch_index == 0 else -36.0)
			branch.material_override = antler_material
			parent.add_child(branch)
	var sigil: Variant = MeshInstance3D.new()
	sigil.name = "WhiteHartCrownGlow"
	sigil.mesh = SphereMesh.new()
	sigil.scale = Vector3(0.08, 0.08, 0.08)
	sigil.position = Vector3(0, 0.06, -0.12)
	var sigil_material: Variant = _actor._mat(Color(0.50, 0.96, 0.72))
	sigil_material.emission_enabled = true
	sigil_material.emission = Color(0.50, 0.96, 0.72)
	sigil_material.emission_energy_multiplier = 1.4
	sigil.material_override = sigil_material
	parent.add_child(sigil)

func _make_bell_eater_identity() -> void:
	_actor.boss_identity_base_scale = Vector3.ONE
	_actor.boss_visual_root.scale = Vector3.ONE
	var bell: Variant = MeshInstance3D.new()
	bell.name = "BellEaterChestBell"
	bell.mesh = load("res://assets/bosses/bell_eater_bell.res") as Mesh
	_actor.boss_visual_root.add_child(bell)
	var clapper: Variant = MeshInstance3D.new()
	clapper.name = "BellEaterClapper"
	var clapper_mesh: Variant = SphereMesh.new()
	clapper_mesh.radius = 0.09
	clapper_mesh.height = 0.18
	clapper_mesh.radial_segments = 10
	clapper_mesh.rings = 5
	clapper.mesh = clapper_mesh
	clapper.position = Vector3(0, -0.39, 0)
	clapper.material_override = _actor._mat(Color(0.10, 0.075, 0.04))
	_actor.boss_visual_root.add_child(clapper)
	var links: Variant = MultiMeshInstance3D.new()
	links.name = "BellEaterHarnessLinks"
	var link_mesh: Variant = TorusMesh.new()
	link_mesh.inner_radius = 0.027
	link_mesh.outer_radius = 0.045
	link_mesh.rings = 6
	link_mesh.ring_segments = 8
	link_mesh.material = _actor._mat(Color(0.16, 0.13, 0.085))
	links.multimesh = MultiMesh.new()
	links.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	links.multimesh.mesh = link_mesh
	links.multimesh.instance_count = 12
	for index in range(12):
		var side: Variant = -1.0 if index < 6 else 1.0
		var step: Variant = index % 6
		var basis: Variant = Basis(Vector3.RIGHT, PI * 0.5)
		if step % 2 == 1:
			basis = Basis(Vector3.UP, PI * 0.5) * basis
		links.multimesh.set_instance_transform(index, Transform3D(basis,
			Vector3(side * (0.10 + 0.025 * step), 0.38 + 0.055 * step, 0.06 + 0.075 * step)))
	_actor.boss_visual_root.add_child(links)
	_actor.boss_phase_sigil = clapper

func _attach_bell_eater_harness(mapped: Node3D) -> void:
	_actor._attach_boss_identity_to_bone(mapped, "spine_03", "BellEaterHarnessSocket", Vector3(0, 1.75, -0.60))

func _attach_boss_identity_to_bone(mapped: Node3D, bone_name: String, socket_name: String, anchor: Vector3, relative_to_bone: bool = false) -> void:
	var skeletons: Variant = mapped.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		push_error("%s requires its authored equipment skeleton" % _actor.enemy_id)
		return
	var skeleton: Variant = skeletons[0] as Skeleton3D
	var torso: Variant = skeleton.find_bone(bone_name)
	if torso < 0:
		push_error("%s requires the authored %s bone" % [_actor.enemy_id, bone_name])
		return
	_actor.animation_driver.sample_pose()
	skeleton.force_update_all_bone_transforms()
	var skeleton_to_actor: Variant = Transform3D.IDENTITY
	var ancestor: Node = skeleton
	while ancestor != null and ancestor != _actor:
		if ancestor is Node3D:
			skeleton_to_actor = (ancestor as Node3D).transform * skeleton_to_actor
		ancestor = ancestor.get_parent()
	var socket: Variant = BoneAttachment3D.new()
	socket.name = socket_name
	socket.bone_idx = torso
	socket.bone_name = skeleton.get_bone_name(torso)
	skeleton.add_child(socket)
	var torso_frame: Variant = skeleton_to_actor * skeleton.get_bone_global_pose(torso)
	if relative_to_bone:
		anchor += torso_frame.origin
	_actor.boss_visual_root.reparent(socket, false)
	_actor.boss_visual_root.transform = torso_frame.affine_inverse() * Transform3D(Basis.IDENTITY, anchor)

func _make_rootbound_identity() -> void:
	# The imported body owns every limb. Only the exposed oath wound is added.
	_actor.boss_identity_base_scale = Vector3.ONE
	_actor.boss_visual_root.scale = Vector3.ONE
	var heart: Variant = MeshInstance3D.new()
	heart.name = "RootboundHeart"
	var wound: Variant = SurfaceTool.new()
	wound.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edge: Variant = PackedVector3Array([
		Vector3(-0.02, 0.22, -0.035), Vector3(0.09, 0.07, -0.035),
		Vector3(0.025, 0.015, -0.035), Vector3(0.065, -0.13, -0.035),
		Vector3(-0.015, -0.22, -0.035), Vector3(-0.06, -0.045, -0.035),
		Vector3(-0.10, 0.075, -0.035)])
	for index in range(edge.size()):
		for point in [Vector3(0, 0, -0.045), edge[index], edge[(index + 1) % edge.size()]]:
			wound.set_normal(Vector3.FORWARD)
			wound.add_vertex(point)
	heart.mesh = wound.commit()
	heart.scale = Vector3(0.8, 1.0, 0.35)
	heart.material_override = _actor._emissive_boss_material(Color(0.15, 0.38, 0.10), 0.30)
	(heart.material_override as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	_actor.boss_visual_root.add_child(heart)
	_actor.boss_phase_sigil = heart

func _make_ashwing_identity() -> void:
	# Ashwing's mapped dragon supplies the animated silhouette. These restrained
	# details establish the burned-mill identity without adding a second body:
	# a charred harness, ember core, and scorched wing roots.
	var harness: Variant = MeshInstance3D.new()
	harness.name = "AshwingBurntHarness"
	var harness_mesh: Variant = TorusMesh.new()
	harness_mesh.inner_radius = 0.46
	harness_mesh.outer_radius = 0.56
	harness_mesh.rings = 10
	harness_mesh.ring_segments = 18
	harness.mesh = harness_mesh
	harness.position = Vector3(0, 1.28, 0.10)
	harness.scale = Vector3(1.36, 0.52, 0.86)
	harness.rotation.x = PI * 0.5
	harness.material_override = _actor._mat(Color(0.16, 0.08, 0.05))
	_actor.boss_visual_root.add_child(harness)

	var core: Variant = MeshInstance3D.new()
	core.name = "AshwingAshCore"
	var core_mesh: Variant = SphereMesh.new()
	core_mesh.radius = 0.19
	core_mesh.height = 0.36
	core.mesh = core_mesh
	core.position = Vector3(0, 1.34, -0.48)
	core.scale = Vector3(1.0, 0.82, 0.70)
	core.material_override = _actor._emissive_boss_material(Color(0.25, 0.07, 0.01), 0.20)
	_actor.boss_visual_root.add_child(core)
	_actor.boss_phase_sigil = core

func _make_halvern_identity() -> void:
	# The complete Ranger-derived body supplies authored clothing, armor, face,
	# and connected anatomy. Keep this layer to a non-anatomical oath effect.
	var seal: Variant = MeshInstance3D.new()
	seal.name = "HalvernGraveSeal"
	var seal_mesh: Variant = TorusMesh.new()
	seal_mesh.inner_radius = 0.12
	seal_mesh.outer_radius = 0.17
	seal_mesh.rings = 8
	seal_mesh.ring_segments = 14
	seal.mesh = seal_mesh
	seal.position = Vector3(0, 0.95, -0.40)
	seal.rotation.x = PI * 0.5
	seal.material_override = _actor._emissive_boss_material(Color(0.36, 0.48, 0.72), 0.78)
	_actor.boss_visual_root.add_child(seal)
	_actor.boss_phase_sigil = seal

func _make_white_hart_identity() -> void:
	# The Wolf source and bone-attached antlers supply the body. These pieces
	# establish the Hart's memory-covenant identity without duplicating anatomy:
	# a ground halo, chest oath mark, and restrained spectral rings.
	var halo: Variant = MeshInstance3D.new()
	halo.name = "WhiteHartMemoryHalo"
	var halo_mesh: Variant = TorusMesh.new()
	# Keep the covenant cue close to the hooves. The previous wide ring read as
	# a gameplay marker and overwhelmed the imported creature at distance.
	halo_mesh.inner_radius = 0.86
	halo_mesh.outer_radius = 0.96
	halo_mesh.rings = 16
	halo_mesh.ring_segments = 24
	halo.mesh = halo_mesh
	halo.position = Vector3(0, 0.12, 0.0)
	halo.rotation.x = PI * 0.5
	halo.material_override = _actor._emissive_boss_material(Color(0.22, 0.68, 0.48), 0.62)
	_actor.boss_visual_root.add_child(halo)

	var oath_mark: Variant = MeshInstance3D.new()
	oath_mark.name = "WhiteHartOathMark"
	var mark_mesh: Variant = SphereMesh.new()
	mark_mesh.radius = 0.16
	mark_mesh.height = 0.32
	oath_mark.mesh = mark_mesh
	oath_mark.position = Vector3(0, 1.55, -0.60)
	oath_mark.scale = Vector3(0.88, 1.42, 0.70)
	oath_mark.material_override = _actor._emissive_boss_material(Color(0.46, 0.82, 0.68), 0.86)
	_actor.boss_visual_root.add_child(oath_mark)
	_actor.boss_phase_sigil = oath_mark

	for side in [-1.0, 1.0]:
		var ring: Variant = MeshInstance3D.new()
		ring.name = "WhiteHartMemoryRingLeft" if side < 0.0 else "WhiteHartMemoryRingRight"
		var ring_mesh: Variant = TorusMesh.new()
		ring_mesh.inner_radius = 0.16
		ring_mesh.outer_radius = 0.21
		ring_mesh.rings = 10
		ring_mesh.ring_segments = 16
		ring.mesh = ring_mesh
		ring.position = Vector3(side * 0.42, 0.78, -0.18)
		ring.rotation_degrees = Vector3(12.0, 0, side * 24.0)
		ring.material_override = _actor._emissive_boss_material(Color(0.32, 0.56, 0.70), 0.42)
		_actor.boss_visual_root.add_child(ring)

func _emissive_boss_material(color: Color, energy: float) -> StandardMaterial3D:
	var material: Variant = _actor._mat(color)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
