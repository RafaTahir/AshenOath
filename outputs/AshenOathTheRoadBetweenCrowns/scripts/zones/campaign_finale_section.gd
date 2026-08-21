extends RefCounted

const CharacterRoleSpec = preload("res://scripts/character_role_spec.gd")
const ZONES := ["undercroft", "assembly", "hart_glade"]

func build(context: ZoneBuildContext) -> void:
	match context.zone_id:
		"undercroft":
			_build_undercroft(context)
		"assembly":
			_build_assembly(context)
		"hart_glade":
			_build_hart_glade(context)

func _marker(context: ZoneBuildContext, zone_id: String, authored_name: String) -> void:
	var compatibility := Node3D.new()
	compatibility.name = "CampaignSection_%s" % zone_id
	context.add_node(compatibility)
	var authored := Node3D.new()
	authored.name = authored_name
	context.add_node(authored)

func _build_undercroft(context: ZoneBuildContext) -> void:
	var stone := Color(0.068, 0.068, 0.072)
	context.make_ground(Vector3(0, -0.08, 0), Vector3(36, 0.16, 34), stone)
	context.make_play_area_bounds(36.0, 34.0, stone.darkened(0.42))
	context.make_road(Vector3(0, 0.02, 0), Vector3(6.5, 0.05, 29), Color(0.17, 0.16, 0.15))
	_make_undercroft_dressing(context)
	context.make_visual_box("UndercroftCeiling", Vector3(0, 6.3, 0), Vector3(36, 0.30, 34), Color(0.115, 0.105, 0.095))
	for x in [-12.0, -4.0, 4.0, 12.0]:
		context.make_visual_box("UndercroftBeam", Vector3(x, 5.95, 0), Vector3(0.26, 0.34, 31), Color(0.12, 0.095, 0.075))
	_marker(context, "undercroft", "AuthoredVarganUndercroft")
	for x in [-14.5, 14.5]:
		context.make_prop_box("UndercroftWall", Vector3(x, 2.8, 0), Vector3(1.2, 5.6, 31), Color(0.12, 0.12, 0.125))
	for z in [-14.5, 14.5]:
		context.make_prop_box("UndercroftWall", Vector3(0, 2.8, z), Vector3(28, 5.6, 1.2), Color(0.12, 0.12, 0.125))
	for z in [-9.0, -3.0, 3.0, 9.0]:
		for x in [-6.5, 6.5]:
			context.make_pillar(Vector3(x, 0, z))
	for position in [Vector3(-10, 0.8, -7), Vector3(10, 0.8, -7), Vector3(-10, 0.8, 5), Vector3(10, 0.8, 5)]:
		context.make_prop_box("StoneCoffin", position, Vector3(4.2, 1.6, 2.1), Color(0.15, 0.145, 0.14))
	# Reserve the two Balanced local-light slots for the witness route before
	# adding torch decoration. The previous order let torch lights consume both
	# slots, leaving the undercroft nearly black and the boss threshold unreadable.
	context.make_light("UndercroftWitnessLight", Vector3(0, 4.5, -7), Color(0.38, 0.45, 0.58), 3.6)
	context.make_light("UndercroftNavigationFill", Vector3(0, 3.0, 4), Color(0.34, 0.38, 0.48), 2.8)
	for position in [Vector3(-4, 0, 9), Vector3(4, 0, 9), Vector3(-4, 0, -8), Vector3(4, 0, -8)]:
		context.make_torch(position)
	context.make_named_interactable("halvern", "dialogue", "Speak to Sir Halvern", Vector3(0, 0, -9), Color(0.42, 0.43, 0.48))
	if context.is_quest_active("main_last_witness") and not context.is_objective_done("main_last_witness", "break_halvern_guard"):
		var guardian = context.spawn_enemy("halvern_boss", Vector3(0, 0.8, -5.5))
		if guardian != null:
			guardian.name = "HalvernGuard"
			guardian.leash_radius = 8.0
	context.make_zone_gate("Return to the Record Hall", Vector3(-6, 0, 14), "record_hall", Vector3(0, 1, -12))
	if str(context.get_story_flag("halvern_fate", "")) != "":
		context.make_zone_gate("Return to Greyfen for the assembly", Vector3(6, 0, -14), "assembly", Vector3(0, 1, 12))

func _build_assembly(context: ZoneBuildContext) -> void:
	var earth := Color(0.125, 0.105, 0.075)
	context.make_ground(Vector3(0, -0.08, 0), Vector3(42, 0.16, 34), earth)
	context.make_play_area_bounds(42.0, 34.0, earth.darkened(0.36))
	context.make_road(Vector3(0, 0.02, 1), Vector3(8, 0.05, 30), Color(0.17, 0.145, 0.105))
	_make_assembly_dressing(context)
	_marker(context, "assembly", "AuthoredGreyfenAssembly")
	context.make_prop_box("AssemblyDais", Vector3(0, 0.35, -8.5), Vector3(10, 0.7, 5), Color(0.20, 0.145, 0.09))
	context.make_prop_box("WitnessTable", Vector3(0, 0.85, -6.5), Vector3(5.0, 1.7, 1.6), Color(0.20, 0.125, 0.065))
	for x in [-8.0, -4.0, 4.0, 8.0]:
		context.make_prop_box("AssemblyBench", Vector3(x, 0.4, 1.5), Vector3(3.0, 0.8, 1.2), Color(0.19, 0.12, 0.065))
		context.make_named_interactable("witness_%d" % int(x), "dialogue", "Hear testimony", Vector3(x, 0, -3.5), Color(0.27, 0.25, 0.22), Vector3(0.55, 0.55, 0.55))
	for position in [Vector3(-6, 0, -10), Vector3(6, 0, -10), Vector3(-7, 0, 8), Vector3(7, 0, 8)]:
		context.make_torch(position)
	context.make_clue("witnesses_ready", "Gather witnesses and records", Vector3(0, 0, -4.5), "main_crowns_without_mercy", "gather_witnesses", Color(0.42, 0.36, 0.26))
	context.make_named_interactable("assembly_choice", "dialogue", "Address Greyfen", Vector3(0, 0, -9), Color(0.49, 0.34, 0.18))
	context.make_zone_gate("Return beneath Castle Vargan", Vector3(-7, 0, 14), "undercroft", Vector3(0, 1, -12))
	if str(context.get_story_flag("confession_method", "")) != "":
		context.make_zone_gate("Walk the reopened road", Vector3(7, 0, -14), "hart_glade", Vector3(0, 1, 12))

func _build_hart_glade(context: ZoneBuildContext) -> void:
	var moss := Color(0.065, 0.105, 0.078)
	context.make_ground(Vector3(0, -0.08, 0), Vector3(44, 0.16, 38), moss)
	context.make_play_area_bounds(44.0, 38.0, moss.darkened(0.36))
	context.make_road(Vector3(0, 0.02, 2), Vector3(5.2, 0.05, 34), Color(0.12, 0.13, 0.10))
	_make_hart_glade_dressing(context)
	_marker(context, "hart_glade", "AuthoredWhiteHartGlade")
	for position in [
		Vector3(-16, 0, -13), Vector3(-14, 0, -5), Vector3(-15, 0, 10),
		Vector3(16, 0, -13), Vector3(14, 0, -5), Vector3(15, 0, 10)
	]:
		context.make_tree(position)
	for position in [Vector3(-7, 0, -7), Vector3(7, 0, -7), Vector3(-9, 0, -2), Vector3(9, 0, -2)]:
		context.make_ritual_stone(position)
	var covenant := str(context.get_story_flag("final_covenant", ""))
	if covenant == "":
		_make_hart_grove(context)
		_make_hart_witness(context)
		context.make_light("HartWitnessLight", Vector3(0, 6, -9), Color(0.62, 0.86, 0.75), 4.2)
		context.make_named_interactable("white_hart", "dialogue", "Stand before the White Hart", Vector3(0, 0, -9), Color(0.78, 0.80, 0.68), Vector3(0.42, 0.72, 0.42))
	else:
		_make_hart_aftermath(context, covenant)
	context.make_zone_gate("Return to Greyfen's assembly", Vector3(-7, 0, 16), "assembly", Vector3(0, 1, -12))

func _make_hart_aftermath(context: ZoneBuildContext, covenant: String) -> void:
	# Completed endings are quiet world states, not a stale repeatable dialogue
	# node. Keep the grove legible after reload with a restrained covenant marker.
	var colors := {
		"witness": Color(0.78, 0.72, 0.42),
		"mercy": Color(0.44, 0.72, 0.86),
		"duty": Color(0.58, 0.66, 0.48),
		"ash": Color(0.42, 0.28, 0.24),
	}
	var tone: Color = colors.get(covenant, Color(0.35, 0.42, 0.38))
	var plinth := MeshInstance3D.new()
	plinth.name = "HartAftermath_%s" % covenant.capitalize()
	var plinth_mesh := CylinderMesh.new()
	plinth_mesh.top_radius = 1.65
	plinth_mesh.bottom_radius = 1.85
	plinth_mesh.height = 0.20
	plinth_mesh.radial_segments = 20
	plinth.mesh = plinth_mesh
	plinth.position = Vector3(0, 0.10, -9)
	plinth.material_override = context.make_material(tone.darkened(0.38))
	context.add_node(plinth)
	var seal := MeshInstance3D.new()
	seal.name = "HartAftermathSeal"
	var seal_mesh := TorusMesh.new()
	seal_mesh.inner_radius = 1.64
	seal_mesh.outer_radius = 1.76
	seal_mesh.rings = 28
	seal_mesh.ring_segments = 8
	seal.mesh = seal_mesh
	seal.position = Vector3(0, 0.23, -9)
	var seal_material := context.make_material(tone)
	seal_material.emission_enabled = true
	seal_material.emission = tone
	seal_material.emission_energy_multiplier = 0.42
	seal.material_override = seal_material
	context.add_node(seal)
	context.make_light("HartAftermathLight", Vector3(0, 4.5, -9), tone, 2.4)

func _make_hart_grove(context: ZoneBuildContext) -> void:
	var plinth := MeshInstance3D.new()
	plinth.name = "WhiteHartMemoryPlinth"
	var plinth_mesh := CylinderMesh.new()
	plinth_mesh.top_radius = 2.25
	plinth_mesh.bottom_radius = 2.55
	plinth_mesh.height = 0.24
	plinth_mesh.radial_segments = 16
	plinth.mesh = plinth_mesh
	plinth.position = Vector3(0, 0.12, -9)
	plinth.material_override = context.make_material(Color(0.20, 0.26, 0.22))
	context.add_node(plinth)
	var halo := MeshInstance3D.new()
	halo.name = "WhiteHartMemoryHalo"
	var halo_mesh := TorusMesh.new()
	halo_mesh.inner_radius = 2.55
	halo_mesh.outer_radius = 2.70
	halo_mesh.rings = 32
	halo_mesh.ring_segments = 8
	halo.mesh = halo_mesh
	halo.position = Vector3(0, 0.28, -9)
	var halo_material := context.make_material(Color(0.28, 0.72, 0.54))
	halo_material.emission_enabled = true
	halo_material.emission = Color(0.12, 0.52, 0.34)
	halo_material.emission_energy_multiplier = 0.70
	halo.material_override = halo_material
	context.add_node(halo)
	for index in range(8):
		var angle := TAU * float(index) / 8.0
		var stone := MeshInstance3D.new()
		stone.name = "HartGroveMarker_%02d" % index
		var stone_mesh := CylinderMesh.new()
		stone_mesh.top_radius = 0.24
		stone_mesh.bottom_radius = 0.34
		stone_mesh.height = 1.2 + float(index % 2) * 0.18
		stone_mesh.radial_segments = 7
		stone.mesh = stone_mesh
		stone.position = Vector3(cos(angle) * 4.3, stone_mesh.height * 0.5, -9 + sin(angle) * 4.3)
		stone.rotation.y = angle
		stone.material_override = context.make_material(Color(0.18, 0.23, 0.20))
		context.add_node(stone)

func _make_hart_witness(context: ZoneBuildContext) -> void:
	# The finale landmark uses the same connected animated animal source as the
	# encounter body. The antler crown is attached to the imported head bone so
	# it follows the idle/walk skeleton instead of floating beside the creature.
	# The witness display uses the same focal role as the encounter. Its 3.60 m
	# normalized height keeps the final creature readable at gameplay distance;
	# the small multiplier is only a restrained spectral presence, not a second
	# source normalization pass.
	var root: Node3D = context.make_visual_role("white_hart_boss", "enemies", Vector3(0, 0, -9), Vector3.ONE * 1.08, 180.0) as Node3D
	if root == null:
		return
	root.position.y += CharacterRoleSpec.ground_offset("white_hart_boss")
	root.name = "WhiteHartWitnessDisplay"
	root.set_meta("focal_creature", true)
	var spectral_material := context.make_material(Color(0.72, 0.78, 0.69))
	spectral_material.roughness = 0.52
	spectral_material.emission_enabled = true
	spectral_material.emission = Color(0.24, 0.38, 0.28)
	spectral_material.emission_energy_multiplier = 0.42
	for raw_mesh in root.find_children("*", "MeshInstance3D", true, false):
		var hart_mesh := raw_mesh as MeshInstance3D
		if hart_mesh != null:
			hart_mesh.material_override = spectral_material
	_add_hart_antler_crown(root, context)
	var oath_mark := MeshInstance3D.new()
	oath_mark.name = "WhiteHartWitnessOathMark"
	var mark_mesh := SphereMesh.new()
	mark_mesh.radius = 0.18
	mark_mesh.height = 0.36
	oath_mark.mesh = mark_mesh
	oath_mark.position = Vector3(0, 1.48, -0.58)
	oath_mark.scale = Vector3(0.78, 1.22, 0.58)
	var mark_material := context.make_material(Color(0.54, 0.92, 0.72))
	mark_material.emission_enabled = true
	mark_material.emission = Color(0.38, 0.82, 0.60)
	mark_material.emission_energy_multiplier = 0.72
	oath_mark.material_override = mark_material
	root.add_child(oath_mark)

func _add_hart_antler_crown(root: Node3D, context: ZoneBuildContext) -> void:
	var skeleton := _find_skeleton(root)
	var parent: Node3D = root
	if skeleton != null:
		var attachment := BoneAttachment3D.new()
		attachment.name = "WhiteHartWitnessAntlerAttachment"
		attachment.bone_name = "Bone.003"
		skeleton.add_child(attachment)
		parent = attachment
		# Match the imported animal body without inheriting its oversized head
		# bone scale. The crown remains bone-attached and follows the head.
		var root_scale := root.global_transform.basis.get_scale()
		var attachment_scale := attachment.global_transform.basis.get_scale()
		var crown_root := Node3D.new()
		crown_root.name = "WhiteHartWitnessAntlerScaleCompensation"
		crown_root.scale = Vector3(
			_safe_inverse_scale(_safe_scale_ratio(attachment_scale.x, root_scale.x)),
			_safe_inverse_scale(_safe_scale_ratio(attachment_scale.y, root_scale.y)),
			_safe_inverse_scale(_safe_scale_ratio(attachment_scale.z, root_scale.z))
		)
		parent.add_child(crown_root)
		parent = crown_root
	var antler_material := context.make_material(Color(0.58, 0.48, 0.30))
	antler_material.emission_enabled = true
	antler_material.emission = Color(0.20, 0.48, 0.34)
	antler_material.emission_energy_multiplier = 0.42
	for side in [-1.0, 1.0]:
		var main := MeshInstance3D.new()
		main.name = "HartWitnessAntlerMain"
		var main_mesh := CylinderMesh.new()
		main_mesh.top_radius = 0.025
		main_mesh.bottom_radius = 0.055
		main_mesh.height = 0.58
		main_mesh.radial_segments = 8
		main.mesh = main_mesh
		main.position = Vector3(side * 0.14, 0.20, 0.01)
		main.rotation_degrees.z = side * -20.0
		main.material_override = antler_material
		parent.add_child(main)
		for branch_index in range(2):
			var branch := MeshInstance3D.new()
			branch.name = "HartWitnessAntlerBranch"
			var branch_mesh := CylinderMesh.new()
			branch_mesh.top_radius = 0.014
			branch_mesh.bottom_radius = 0.035
			branch_mesh.height = 0.26 if branch_index == 0 else 0.20
			branch_mesh.radial_segments = 8
			branch.mesh = branch_mesh
			branch.position = Vector3(side * (0.25 + branch_index * 0.045), 0.34 + branch_index * 0.13, 0.01)
			branch.rotation_degrees.z = side * (42.0 if branch_index == 0 else -36.0)
			branch.material_override = antler_material
			parent.add_child(branch)

func _find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root as Skeleton3D
	for child in root.get_children():
		var found := _find_skeleton(child)
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

func _add_hart_part(parent: Node3D, node_name: String, mesh: Mesh, position: Vector3, scale_value: Vector3, material: Material, rotation_degrees := Vector3.ZERO) -> void:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = position
	node.scale = scale_value
	node.rotation_degrees = rotation_degrees
	node.material_override = material
	parent.add_child(node)

func _make_undercroft_dressing(context: ZoneBuildContext) -> void:
	# Interiors inherit a very low outdoor ambient value. These two restrained,
	# unshaded architectural inlays keep the route readable without turning the
	# undercroft into a bright outdoor room or adding more dynamic lights.
	_make_flat_light_box(context, "UndercroftRouteInlay", Vector3(0, 0.085, 0), Vector3(6.0, 0.018, 28.0), Color(0.15, 0.13, 0.11))
	_make_flat_light_box(context, "UndercroftCeilingInlayA", Vector3(0, 6.08, -8.5), Vector3(8.0, 0.018, 4.2), Color(0.08, 0.07, 0.06))
	_make_flat_light_box(context, "UndercroftCeilingInlayB", Vector3(0, 6.08, 7.5), Vector3(8.0, 0.018, 4.2), Color(0.07, 0.075, 0.09))
	for z in [-12.0, -6.0, 0.0, 6.0, 12.0]:
		context.make_terrain_patch("UndercroftFloorInset", Vector3(0, 0.008, z), Vector3(5.4, 0.026, 0.76), Color(0.14, 0.13, 0.12))
	for x in [-12.5, 12.5]:
		context.make_visual_box("UndercroftWallBand", Vector3(x, 4.8, 0), Vector3(0.18, 0.24, 28.0), Color(0.24, 0.21, 0.18))
	for z in [-13.6, 13.6]:
		context.make_visual_box("UndercroftArchBand", Vector3(0, 4.95, z), Vector3(27.0, 0.24, 0.18), Color(0.22, 0.19, 0.16))
	context.make_visual_box("UndercroftWitnessThreshold", Vector3(0, 0.10, -10.4), Vector3(7.2, 0.08, 0.18), Color(0.28, 0.22, 0.14))

func _make_assembly_dressing(context: ZoneBuildContext) -> void:
	for z in [-11.5, -6.0, 0.0, 6.0, 11.5]:
		context.make_terrain_patch("AssemblyRoadWear", Vector3(0, 0.008, z), Vector3(6.8, 0.024, 0.78), Color(0.20, 0.16, 0.11))
	for x in [-12.0, 12.0]:
		context.make_visual_box("AssemblyWitnessBannerPole", Vector3(x, 2.5, -7.5), Vector3(0.16, 5.0, 0.16), Color(0.16, 0.095, 0.045))
		context.make_visual_box("AssemblyWitnessBanner", Vector3(x, 3.6, -7.5), Vector3(1.1, 1.7, 0.06), Color(0.25, 0.055, 0.035))
	context.make_visual_box("AssemblyDaisFront", Vector3(0, 0.74, -10.9), Vector3(10.6, 0.16, 0.20), Color(0.35, 0.21, 0.10))
	context.make_visual_box("AssemblyFireBowl", Vector3(0, 1.15, 4.2), Vector3(0.72, 0.24, 0.72), Color(0.26, 0.18, 0.09))
	context.make_visual_box("AssemblyFire", Vector3(0, 1.38, 4.2), Vector3(0.22, 0.44, 0.22), Color(0.76, 0.34, 0.10))

func _make_hart_glade_dressing(context: ZoneBuildContext) -> void:
	# The grove is framed as a deliberate clearing, with a readable approach and
	# an open witness space around the Hart rather than an empty field.
	for z in [-12.0, -6.0, 0.0, 7.0, 13.0]:
		context.make_terrain_patch("HartGladeMossBand", Vector3(-7.0, 0.008, z), Vector3(3.8, 0.024, 1.15), Color(0.09, 0.16, 0.11))
		context.make_terrain_patch("HartGladeMossBand", Vector3(7.0, 0.009, z + 0.3), Vector3(3.8, 0.024, 1.15), Color(0.075, 0.14, 0.095))
	for position in [Vector3(-4.8, 0.04, -11.5), Vector3(4.8, 0.04, -11.5), Vector3(-5.1, 0.04, 11.5), Vector3(5.1, 0.04, 11.5)]:
		context.make_path_stone(position, 0.68)
	context.make_visual_box("HartGladeWitnessThreshold", Vector3(0, 0.10, -5.8), Vector3(4.0, 0.08, 0.18), Color(0.18, 0.34, 0.22))
	context.make_visual_box("HartGladeMoonlitMarker", Vector3(0, 2.1, -9.0), Vector3(0.18, 3.4, 0.18), Color(0.19, 0.45, 0.29))

func _make_flat_light_box(context: ZoneBuildContext, node_name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.roughness = 1.0
	node.material_override = material
	context.add_node(node)
