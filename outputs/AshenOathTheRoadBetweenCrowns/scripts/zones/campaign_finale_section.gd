extends RefCounted

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
	context.make_road(Vector3(0, 0.02, 0), Vector3(6.5, 0.05, 29), Color(0.11, 0.105, 0.10))
	context.make_visual_box("UndercroftCeiling", Vector3(0, 6.3, 0), Vector3(36, 0.30, 34), Color(0.028, 0.028, 0.032))
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
	for position in [Vector3(-4, 0, 9), Vector3(4, 0, 9), Vector3(-4, 0, -8), Vector3(4, 0, -8)]:
		context.make_torch(position)
	context.make_light("UndercroftWitnessLight", Vector3(0, 4.5, -7), Color(0.38, 0.45, 0.58), 2.6)
	context.make_named_interactable("halvern", "dialogue", "Speak to Sir Halvern", Vector3(0, 0, -9), Color(0.42, 0.43, 0.48))
	if context.is_quest_active("main_last_witness") and not context.is_objective_done("main_last_witness", "break_halvern_guard"):
		var guardian = context.spawn_enemy("gravebound_knight", Vector3(0, 0.8, -5.5))
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
	_marker(context, "hart_glade", "AuthoredWhiteHartGlade")
	for position in [
		Vector3(-16, 0, -13), Vector3(-14, 0, -5), Vector3(-15, 0, 10),
		Vector3(16, 0, -13), Vector3(14, 0, -5), Vector3(15, 0, 10)
	]:
		context.make_tree(position)
	for position in [Vector3(-7, 0, -7), Vector3(7, 0, -7), Vector3(-9, 0, -2), Vector3(9, 0, -2)]:
		context.make_ritual_stone(position)
	_make_hart_grove(context)
	_make_hart_witness(context)
	context.make_light("HartWitnessLight", Vector3(0, 6, -9), Color(0.62, 0.86, 0.75), 4.2)
	context.make_named_interactable("white_hart", "dialogue", "Stand before the White Hart", Vector3(0, 0, -9), Color(0.78, 0.80, 0.68), Vector3(0.42, 0.72, 0.42))
	context.make_zone_gate("Return to Greyfen's assembly", Vector3(-7, 0, 16), "assembly", Vector3(0, 1, -12))

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
	# Display-only focal actor for the glade. The ending resolver still owns
	# combat spawning, so this does not change the encounter state machine.
	var root := Node3D.new()
	root.name = "WhiteHartWitnessDisplay"
	root.position = Vector3(0, 0, -9)
	context.add_node(root)
	var body_material := context.make_material(Color(0.22, 0.30, 0.25))
	var shadow_material := context.make_material(Color(0.075, 0.105, 0.090))
	var antler_material := context.make_material(Color(0.26, 0.18, 0.10))
	_add_hart_part(root, "HartBody", SphereMesh.new(), Vector3(0, 1.18, 0.12), Vector3(1.30, 0.72, 1.56), body_material)
	_add_hart_part(root, "HartNeck", CapsuleMesh.new(), Vector3(0, 1.94, -0.42), Vector3(0.66, 1.02, 0.72), body_material, Vector3(-24, 0, 0))
	_add_hart_part(root, "HartHead", SphereMesh.new(), Vector3(0, 2.48, -0.86), Vector3(0.58, 0.50, 0.78), body_material)
	_add_hart_part(root, "HartMuzzle", SphereMesh.new(), Vector3(0, 2.32, -1.18), Vector3(0.34, 0.25, 0.42), shadow_material)
	_add_hart_part(root, "HartMane", SphereMesh.new(), Vector3(0, 2.02, -0.30), Vector3(0.46, 0.78, 0.34), shadow_material)
	_add_hart_part(root, "HartEar", SphereMesh.new(), Vector3(-0.32, 2.68, -0.72), Vector3(0.20, 0.10, 0.30), shadow_material, Vector3(0, 0, -18))
	_add_hart_part(root, "HartEar", SphereMesh.new(), Vector3(0.32, 2.68, -0.72), Vector3(0.20, 0.10, 0.30), shadow_material, Vector3(0, 0, 18))
	for side in [-1.0, 1.0]:
		for z in [-0.34, 0.34]:
			_add_hart_part(root, "HartLeg", CylinderMesh.new(), Vector3(side * 0.38, 0.52, z), Vector3(0.22, 0.92, 0.22), shadow_material)
		_add_hart_part(root, "HartAntlerMain", CylinderMesh.new(), Vector3(side * 0.25, 2.92, -0.76), Vector3(0.13, 0.92, 0.13), antler_material, Vector3(0, 0, side * -18.0))
		_add_hart_part(root, "HartAntlerBranch", CylinderMesh.new(), Vector3(side * 0.48, 3.26, -0.76), Vector3(0.09, 0.54, 0.09), antler_material, Vector3(0, 0, side * 34.0))
	var eye_material := context.make_material(Color(0.48, 0.92, 0.72))
	eye_material.emission_enabled = true
	eye_material.emission = Color(0.18, 0.72, 0.46)
	eye_material.emission_energy_multiplier = 1.8
	for side in [-1.0, 1.0]:
		_add_hart_part(root, "HartEye", SphereMesh.new(), Vector3(side * 0.17, 2.52, -1.22), Vector3(0.075, 0.075, 0.075), eye_material)
	_add_hart_part(root, "HartSigilLight", SphereMesh.new(), Vector3(0, 1.42, -0.54), Vector3(0.13, 0.13, 0.13), eye_material)

func _add_hart_part(parent: Node3D, node_name: String, mesh: Mesh, position: Vector3, scale_value: Vector3, material: Material, rotation_degrees := Vector3.ZERO) -> void:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = position
	node.scale = scale_value
	node.rotation_degrees = rotation_degrees
	node.material_override = material
	parent.add_child(node)
