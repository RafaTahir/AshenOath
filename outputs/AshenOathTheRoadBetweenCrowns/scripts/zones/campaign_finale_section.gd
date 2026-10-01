extends RefCounted

const CharacterRoleSpec = preload("res://scripts/character_role_spec.gd")
const CharacterAnimationDriver = preload("res://scripts/character_animation_driver.gd")
const WorldMaterialLibrary = preload("res://scripts/world_material_library.gd")
const UndercroftVault = preload("res://assets_external/environment/village/UndercroftVault_Authored.res")
const AssemblyCourt = preload("res://assets_external/environment/village/AssemblyCourt_Authored.res")
const HartLandscape = preload("res://assets_external/environment/forest/HartLandscape_Authored.res")
const HartWitnessStones = preload("res://assets_external/environment/forest/HartWitnessStones_Authored.res")
const HartWoodland = preload("res://scripts/hart_woodland.gd")
const LandscapePresentation = preload("res://scripts/world_landscape_presentation.gd")
const StoryActorPresence = preload("res://scripts/story_actor_presence.gd")
const AssemblyFrontier = preload("res://scripts/zones/campaign_wilds_presentation.gd")
const UndercroftMemorial = preload("res://scripts/undercroft_memorial.gd")
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
	_make_undercroft_stone_box(context, "UndercroftProcessionalAisle", Vector3(0, 0.024, 0), Vector3(6.5, 0.012, 29), "cobblestone", Color(0.47, 0.49, 0.51))
	# A visible witness wall and shallow duel dais give Halvern a readable
	# threshold without changing the central collision-owned combat lane.
	_make_undercroft_stone_box(context, "HalvernDuelDais", Vector3(0, 0.075, -6.4), Vector3(7.4, 0.10, 5.8), "medieval_brick", Color(0.68, 0.66, 0.63))
	var memorial := UndercroftMemorial.new()
	memorial.name = "UndercroftMemorial"
	memorial.story_state = context.story_state
	memorial.stone_material = context.make_world_material("medieval_brick", Color(0.82, 0.80, 0.72)).duplicate() as StandardMaterial3D
	memorial.stone_material.vertex_color_use_as_albedo = true
	memorial.timber_material = context.make_world_material("timber", Color(0.50, 0.40, 0.29)).duplicate() as StandardMaterial3D
	memorial.timber_material.vertex_color_use_as_albedo = true
	context.add_node(memorial)
	_make_undercroft_dressing(context)
	_make_authored_undercroft_dressing(context)
	_make_undercroft_stone_box(context, "UndercroftStoneFloor", Vector3(0, 0.008, 0), Vector3(28.0, 0.012, 31.0), "cobblestone", Color(0.65, 0.63, 0.60))
	_make_undercroft_stone_box(context, "UndercroftStoneCeiling", Vector3(0, 5.95, 0), Vector3(28.0, 0.14, 31.0), "medieval_brick", Color(0.56, 0.54, 0.52))
	for x in [-13.96, 13.96]:
		_make_undercroft_stone_box(context, "UndercroftStoneSide", Vector3(x, 2.8, 0), Vector3(0.10, 5.6, 30.8), "medieval_brick", Color(0.63, 0.61, 0.58))
	_marker(context, "undercroft", "AuthoredVarganUndercroft")
	for x in [-14.5, 14.5]:
		context.make_collision_box("UndercroftWall", Vector3(x, 2.8, 0), Vector3(1.2, 5.6, 31))
	_make_undercroft_doorway_wall(context, -14.5, 6.0, true)
	_make_undercroft_doorway_wall(context, 14.5, -6.0, false)
	for position in [Vector3(-10, 0.8, -7), Vector3(10, 0.8, -7), Vector3(-10, 0.8, 5), Vector3(10, 0.8, 5)]:
		context.make_reserved_collision_box("StoneCoffin", position, Vector3(4.2, 1.6, 2.1))
	_make_undercroft_vault(context)
	# Reserve the two Balanced local-light slots for the witness route before
	# adding torch decoration. The previous order let torch lights consume both
	# slots, leaving the undercroft nearly black and the boss threshold unreadable.
	context.make_light("UndercroftWitnessLight", Vector3(0, 4.5, -7), Color(0.38, 0.45, 0.58), 3.6)
	context.make_light("UndercroftNavigationFill", Vector3(0, 3.0, 4), Color(0.34, 0.38, 0.48), 2.8)
	context.make_light("UndercroftHalvernFill", Vector3(0, 3.4, -6.5), Color(0.42, 0.46, 0.56), 3.0)
	for position in [Vector3(-4, 0, 9), Vector3(4, 0, 9), Vector3(-4, 0, -8), Vector3(4, 0, -8)]:
		context.make_torch(position)
	if StoryActorPresence.remains("halvern", str(context.get_story_flag("halvern_fate", ""))):
		context.make_named_interactable("halvern", "dialogue", "Speak to Sir Halvern", Vector3(0, 0, -9), Color(0.42, 0.43, 0.48))
	if context.is_quest_active("main_last_witness") and str(context.get_story_flag("halvern_fate", "")) == "":
		var guardian = context.spawn_enemy("halvern_boss", Vector3(0, 0.8, -5.5))
		if guardian != null:
			guardian.name = "HalvernGuard"
			guardian.leash_radius = 8.0
	context.make_zone_gate("Return to the Record Hall", Vector3(-6, 0, 14), "record_hall", Vector3(0, 1, -12))
	if str(context.get_story_flag("halvern_fate", "")) != "":
		context.make_zone_gate("Return to Greyfen for the assembly", Vector3(6, 0, -14), "assembly", Vector3(0, 1, 12))

func _make_undercroft_doorway_wall(context: ZoneBuildContext, z: float, doorway_x: float, visible_stone: bool) -> void:
	# Gate focus and the player capsule need the same opening through the wall.
	var half_opening := 2.1
	var opening_height := 3.4
	var left_edge := doorway_x - half_opening
	var right_edge := doorway_x + half_opening
	var sections := [
		{"center": Vector3((-14.0 + left_edge) * 0.5, 2.8, z), "size": Vector3(left_edge + 14.0, 5.6, 1.2)},
		{"center": Vector3((right_edge + 14.0) * 0.5, 2.8, z), "size": Vector3(14.0 - right_edge, 5.6, 1.2)},
		{"center": Vector3(doorway_x, (opening_height + 5.6) * 0.5, z), "size": Vector3(half_opening * 2.0, 5.6 - opening_height, 1.2)},
	]
	for index in range(sections.size()):
		var center: Vector3 = sections[index].center
		var size: Vector3 = sections[index].size
		context.make_collision_box("UndercroftDoorWall_%s_%d" % [str(z), index], center, size)
		if visible_stone:
			center.z = -14.02
			size.z = 0.10
			_make_undercroft_stone_box(context, "UndercroftStoneRear_%d" % index, center, size, "medieval_brick", Color(0.71, 0.69, 0.66))

func _build_assembly(context: ZoneBuildContext) -> void:
	var earth := Color(0.125, 0.105, 0.075)
	context.make_ground(Vector3(0, -0.08, 0), Vector3(42, 0.16, 34), earth)
	context.make_play_area_bounds(42.0, 34.0, earth.darkened(0.36))
	_make_undercroft_stone_box(context, "AssemblySettlementGround", Vector3(0, -0.015, -4), Vector3(66, 0.014, 62), "forest_ground", Color(0.46, 0.51, 0.39))
	_make_undercroft_stone_box(context, "AssemblyCivicPaving", Vector3(0, 0.033, 1), Vector3(8, 0.014, 30), "cobblestone", Color(0.68, 0.66, 0.59))
	_make_assembly_dressing(context)
	AssemblyFrontier.adjoining_frontier(context)
	_marker(context, "assembly", "AuthoredGreyfenAssembly")
	_make_undercroft_stone_box(context, "AssemblyDais", Vector3(0, 0.045, -8.5), Vector3(10, 0.014, 5), "medieval_brick", Color(0.71, 0.69, 0.61))
	_make_assembly_court(context)
	for witness in [["witness_-7", -8.0], ["witness_-3", -4.0], ["witness_3", 4.0], ["witness_7", 8.0]]:
		context.make_named_interactable(witness[0], "dialogue", "Hear testimony" if witness[0] != "witness_7" else "Read the witness record", Vector3(witness[1], 0, -3.5), Color(0.27, 0.25, 0.22))
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
	_make_hart_moss_ground(context, "HartGladeMossGround", Vector3(0, 0.014, 0), Vector3(45.0, 0.025, 39.0), Color(0.43, 0.60, 0.49))
	_make_hart_landscape(context)
	_make_hart_glade_dressing(context)
	_marker(context, "hart_glade", "AuthoredWhiteHartGlade")
	for position in [
		Vector3(-16, 0, -13), Vector3(-14, 0, -5), Vector3(-15, 0, 10),
		Vector3(16, 0, -13), Vector3(14, 0, -5), Vector3(15, 0, 10)
	]:
		context.make_tree(position)
	for position in [Vector3(-7, 0, -7), Vector3(7, 0, -7), Vector3(-9, 0, -2), Vector3(9, 0, -2)]:
		context.make_reserved_collision_box("RitualStone", position + Vector3(0, 0.8, 0), Vector3(0.6, 1.6, 0.35))
		var rune := context.make_visual_box("HartRitualRune", position + Vector3(0, 0.95, -0.19), Vector3(0.05, 0.42, 0.02), Color(0.64, 0.85, 0.72)) as MeshInstance3D
		var rune_material := context.make_material(Color(0.64, 0.85, 0.72))
		rune_material.emission_enabled = true
		rune_material.emission = Color(0.64, 0.85, 0.72)
		rune_material.emission_energy_multiplier = 0.55
		rune.material_override = rune_material
	var covenant := str(context.get_story_flag("final_covenant", ""))
	if covenant == "":
		_make_hart_grove(context)
		_make_hart_witness(context)
		context.make_light("HartWitnessLight", Vector3(0, 6, -9), Color(0.62, 0.86, 0.75), 4.2)
		context.make_named_interactable("white_hart", "dialogue", "Stand before the White Hart", Vector3(0, 0, -9), Color(0.78, 0.80, 0.68), Vector3(0.42, 0.72, 0.42))
	elif covenant in ["duty", "ash"] and not bool(context.get_story_flag("final_choice_completed", false)):
		_make_hart_grove(context)
		var boss = context.spawn_enemy("white_hart_avatar", Vector3(0, 0.8, -7))
		if boss != null:
			boss.name = "WhiteHartFinalEncounter"
			boss.leash_radius = 10.0
	else:
		_make_hart_aftermath(context, covenant)
	context.make_zone_gate("Return to Greyfen's assembly", Vector3(-7, 0, 16), "assembly", Vector3(0, 1, -12))

func _make_hart_aftermath(context: ZoneBuildContext, covenant: String) -> void:
	# Completed covenants alter the same memorial garden, without repeating
	# the encounter or changing the established approach and return lanes.
	var colors := {
		"witness": Color(0.78, 0.72, 0.42),
		"mercy": Color(0.44, 0.72, 0.86),
		"duty": Color(0.58, 0.66, 0.48),
		"ash": Color(0.42, 0.28, 0.24),
	}
	var tone: Color = colors.get(covenant, Color(0.35, 0.42, 0.38))
	var mesh := load("res://assets_external/environment/forest/HartAftermath_%s_Authored.res" % covenant) as ArrayMesh
	if mesh == null:
		push_error("Required Hart aftermath geometry is missing: " + covenant)
		return
	var seal := MeshInstance3D.new()
	seal.name = "HartAftermathSeal"
	seal.mesh = mesh
	for surface in range(2):
		var material := context.make_world_material("forest_ground" if surface == 0 else "medieval_brick", Color.WHITE).duplicate() as StandardMaterial3D
		material.vertex_color_use_as_albedo = true
		seal.set_surface_override_material(surface, material)
	seal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	context.add_node(seal)
	var obstacles: Array = mesh.get_meta("obstacles", [])
	for index in obstacles.size():
		context.make_collision_box("HartMemorialStone_%d" % index, obstacles[index].centre, obstacles[index].size)
	var inscription := Label3D.new()
	inscription.name = "HartCovenantInscription"
	inscription.text = {"witness": "THE NAMES ARE KEPT", "mercy": "THE OATH IS RELEASED", "duty": "THE OATH HOLDS", "ash": "NO OATH REMAINS"}.get(covenant, "")
	inscription.position = Vector3(0, 2.65, -12.8)
	inscription.font_size = 64
	inscription.pixel_size = 0.0043
	inscription.modulate = tone.lightened(0.20)
	inscription.outline_size = 8
	context.add_node(inscription)
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
	# The visual inlay shares the arena floor; it must not bury the stag's feet.
	plinth.position = Vector3(0, -0.12, -9)
	plinth.material_override = context.make_material(Color(0.20, 0.26, 0.22))
	context.add_node(plinth)
	# Memory roots radiate from the witness plinth and remain purely visual, so
	# the final combat and peaceful approach retain full capsule clearance.
	for angle_index in range(12):
		var root_angle := TAU * float(angle_index) / 12.0
		var root_pos := Vector3(cos(root_angle) * 2.7, 0.025, -9 + sin(root_angle) * 2.7)
		var root_trace := context.make_visual_box("HartMemoryRoot", root_pos, Vector3(0.10, 0.022, 2.6), Color(0.20, 0.48, 0.33)) as MeshInstance3D
		root_trace.rotation_degrees.y = -rad_to_deg(root_angle)
	for side in [-1.0, 1.0]:
		context.make_visual_box("HartWitnessRune", Vector3(side * 5.6, 1.45, -10.49), Vector3(0.08, 0.88, 0.025), Color(0.48, 0.83, 0.65))
	var witness_stones := MeshInstance3D.new()
	witness_stones.name = "HartWitnessMonoliths"
	witness_stones.mesh = HartWitnessStones
	var witness_material := context.make_world_material("medieval_brick", Color(0.79, 0.85, 0.78)).duplicate() as StandardMaterial3D
	witness_material.vertex_color_use_as_albedo = true
	witness_stones.material_override = witness_material
	witness_stones.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	context.add_node(witness_stones)
	for index in range(8):
		if index in [2, 6]:
			continue
		var angle := TAU * float(index) / 8.0
		# Low weathered stones mark the witness circle without blocking its sightline.
		var size := 0.30 + float(index % 3) * 0.055
		var stone: Node3D = context.make_visual_role("forest_rock", "environment",
			Vector3(cos(angle) * 4.3, 0, -9 + sin(angle) * 4.3),
			Vector3(size, size * 0.65, size), float(index * 53))
		if stone != null:
			stone.name = "HartGroveMarker_%02d" % index

func _make_hart_witness(context: ZoneBuildContext) -> void:
	# The witness shares the encounter's native stag anatomy and palette.
	# The witness display uses the same focal role as the encounter. Its 3.60 m
	# normalized height keeps the final creature readable at gameplay distance;
	# the small multiplier is only a restrained spectral presence, not a second
	# source normalization pass.
	var world_yaw := 180.0 + CharacterRoleSpec.facing_degrees("white_hart_boss")
	var root: Node3D = context.make_visual_role("white_hart_boss", "enemies", Vector3(0, 0, -9), Vector3.ONE * 1.08, world_yaw) as Node3D
	if root == null:
		return
	root.position.y += CharacterRoleSpec.ground_offset("white_hart_boss")
	root.name = "WhiteHartWitnessDisplay"
	root.set_meta("focal_creature", true)
	# Native stag antlers and authored materials are shared with the encounter.
	configure_witness_animation(root)

func configure_witness_animation(root: Node3D) -> void:
	var driver := CharacterAnimationDriver.new()
	driver.name = "HartWitnessAnimation"
	root.add_child(driver)
	if not driver.configure(root, {"idle": "Idle", "dialogue": "Idle_2"}):
		push_error("White Hart witness requires native idle animation")
		return
	driver.set_update_rate_hz(12.0)

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
	context.make_visual_box("UndercroftWitnessThreshold", Vector3(0, 0.10, -10.4), Vector3(7.2, 0.08, 0.18), Color(0.28, 0.22, 0.14))

func _make_authored_undercroft_dressing(context: ZoneBuildContext) -> void:
	for pos in [Vector3(-9.8, 0.0, -7.0), Vector3(9.8, 0.0, -7.0), Vector3(-9.8, 0.0, 5.0), Vector3(9.8, 0.0, 5.0)]:
		context.make_fitted_environment_role("castle_bench", pos, Vector3(2.20, 0.55, 0.55), 90.0)
	for pos in [Vector3(-13.55, 3.4, -8.0), Vector3(13.55, 3.4, -8.0), Vector3(-13.55, 3.4, 7.0), Vector3(13.55, 3.4, 7.0)]:
		context.make_fitted_environment_role("castle_lantern", pos, Vector3(0.28, 0.55, 0.24), 90.0 if pos.x < 0.0 else -90.0)
	context.make_fitted_environment_role("castle_arch", Vector3(6.0, 0, -13.48), Vector3(4.20, 3.40, 0.22), 0.0)

func _make_undercroft_vault(context: ZoneBuildContext) -> void:
	var vault := MeshInstance3D.new()
	vault.name = "UndercroftAuthoredVault"
	vault.mesh = UndercroftVault
	vault.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := context.make_world_material("medieval_brick", Color(0.80, 0.79, 0.75)).duplicate() as StandardMaterial3D
	material.vertex_color_use_as_albedo = true
	vault.material_override = material
	context.add_node(vault)
	# Ceiling collision comes from the same intrados surface, never the doors or
	# the tomb decoration. Existing tomb/wall ownership remains unchanged.
	var roof_mesh := ArrayMesh.new()
	roof_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, UndercroftVault.surface_get_arrays(0))
	roof_mesh.surface_set_material(0, material)
	var body := StaticBody3D.new()
	body.name = "UndercroftVaultCollision"
	body.set_meta("walkable_support", false)
	var shape := CollisionShape3D.new()
	shape.shape = roof_mesh.create_trimesh_shape()
	body.add_child(shape)
	context.add_node(body)

func _make_assembly_dressing(context: ZoneBuildContext) -> void:
	for x in [-12.0, 12.0]:
		context.make_visual_box("AssemblyWitnessBannerPole", Vector3(x, 2.5, -7.5), Vector3(0.16, 5.0, 0.16), Color(0.16, 0.095, 0.045))
		context.make_visual_box("AssemblyWitnessBanner", Vector3(x, 3.6, -7.5), Vector3(1.1, 1.7, 0.06), Color(0.25, 0.055, 0.035))
	context.make_light("AssemblyFireLight", Vector3(0, 2.0, 4.2), Color(0.78, 0.28, 0.08), 1.0)

func _make_assembly_court(context: ZoneBuildContext) -> void:
	var court := MeshInstance3D.new()
	court.name = "AssemblyAuthoredCourt"
	court.mesh = AssemblyCourt
	court.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var stone := context.make_world_material("medieval_brick", Color(0.83, 0.82, 0.77)).duplicate() as StandardMaterial3D
	stone.vertex_color_use_as_albedo = true
	court.set_surface_override_material(0, stone)
	context.add_node(court)
	for x in [-8.6, -4.0, 4.0, 8.6]:
		context.make_collision_box("AssemblyBench", Vector3(x, 0.4, 1.5), Vector3(3.0, 0.8, 1.2))
	for table in [[Vector3(0, 0.5, -6.5), Vector3(3.4, 1.0, 0.95)], [Vector3(0, 0.5, -9), Vector3(2.4, 1.0, 1.1)], [Vector3(8, 0.5, -3.5), Vector3(2.4, 1.0, 1.1)]]:
		context.make_collision_box("AssemblyReadingTable", table[0], table[1])

func _make_hart_glade_dressing(context: ZoneBuildContext) -> void:
	# The grove is framed as a deliberate clearing, with a readable approach and
	# an open witness space around the Hart rather than an empty field.
	for position in [Vector3(-4.8, 0.04, -11.5), Vector3(4.8, 0.04, -11.5), Vector3(-5.1, 0.04, 11.5), Vector3(5.1, 0.04, 11.5)]:
		context.make_path_stone(position, 0.68)
	context.make_visual_box("HartGladeWitnessThreshold", Vector3(0, 0.10, -5.8), Vector3(4.0, 0.08, 0.18), Color(0.18, 0.34, 0.22))
	for position in [Vector3(-10.5, 0, -9.0), Vector3(10.5, 0, -9.0), Vector3(-11.0, 0, 4.5), Vector3(11.0, 0, 5.5)]:
		context.make_loose_role("forest_tree_variant", position, Vector3(1.12, 1.06, 1.12), position.x * 2.0)
	for position in [Vector3(-6.2, 0, -10.8), Vector3(6.5, 0, -10.4), Vector3(-8.2, 0, -4.5), Vector3(8.0, 0, -3.8)]:
		context.make_loose_role("forest_rock", position, Vector3.ONE * 0.72, position.x * 7.0)
	for position in [Vector3(-5.4, 0, -8.8), Vector3(5.0, 0, -9.2), Vector3(-7.0, 0, 1.8), Vector3(7.4, 0, 2.4)]:
		context.make_loose_role("forest_bush", position, Vector3.ONE * 0.78, position.z * 9.0)
	# Three low witness rings lead the eye to the Hart without blocking combat or
	# the return road. Their broken arcs keep the clearing organic rather than
	# presenting another rectangular platform.
	for radius in [3.2, 5.0, 7.0]:
		for index in range(8):
			if index in [2, 6]:
				continue
			var angle := TAU * float(index) / 8.0
			var stone_pos := Vector3(cos(angle) * radius, 0.035, -8.6 + sin(angle) * radius)
			context.make_path_stone(stone_pos, 0.42 if radius < 5.5 else 0.34)

func _make_hart_moss_ground(context: ZoneBuildContext, node_name: String, pos: Vector3, size: Vector3, tint: Color) -> void:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = WorldMaterialLibrary.make_tiled_ground_patch(size, pos)
	node.position = pos
	node.material_override = context.make_world_material("forest_ground", tint)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	context.add_node(node)

func _make_hart_landscape(context: ZoneBuildContext) -> void:
	HartWoodland.build(context)
	var landscape := MeshInstance3D.new()
	landscape.name = "HartAuthoredLandscape"
	landscape.mesh = HartLandscape
	landscape.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ground := context.make_world_material("forest_ground").duplicate() as StandardMaterial3D
	ground.vertex_color_use_as_albedo = true
	var stone := context.make_world_material("medieval_brick").duplicate() as StandardMaterial3D
	stone.vertex_color_use_as_albedo = true
	landscape.set_surface_override_material(0, ground)
	landscape.set_surface_override_material(1, stone)
	context.add_node(landscape)

func _make_undercroft_stone_box(context: ZoneBuildContext, node_name: String, pos: Vector3, size: Vector3, surface: String, tint: Color) -> void:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = WorldMaterialLibrary.make_tiled_box(size, pos)
	node.position = pos
	node.material_override = context.make_world_material(surface, tint)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	context.add_node(node)
