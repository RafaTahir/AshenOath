extends RefCounted

const RiverSection = preload("res://scripts/zones/river_section.gd")

func build(context: ZoneBuildContext) -> void:
	seed(78233)
	var root := Node3D.new()
	root.name = "AuthoredWychwoodSection"
	root.set_meta("ticket", "WORLD-002")
	root.set_meta("main_route_half_width", 2.6)
	context.add_node(root)

	context.make_split_ground(44.0, 34.0, 0.0, 3.4, Color(0.065, 0.105, 0.07))
	RiverSection.new().build(context, 0.0, 44.0, 3.4)
	context.make_wychwood_terrain_layers()
	context.make_play_area_bounds(44, 34, Color(0.04, 0.075, 0.045))
	context.make_road(Vector3(0, 0.018, 3), Vector3(4.0, 0.04, 27.0), Color(0.065, 0.075, 0.052))
	context.make_road(Vector3(6, 0.019, -8), Vector3(10.0, 0.04, 3.0), Color(0.055, 0.065, 0.05))
	context.make_wychwood_path_edges()

	_build_light_composition(context)
	_build_gate_threshold(context)
	_build_authored_presentation(context)
	_build_forest_frame(context)
	_build_investigation_route(context)
	_build_combat_clearing(context)
	context.make_quality_wychwood_overhaul()
	_build_gameplay_content(context)
	context.make_narrative_aftermath()

func _build_authored_presentation(context: ZoneBuildContext) -> void:
	var presentation := Node3D.new()
	presentation.name = "WychwoodAuthoredPresentation"
	presentation.set_meta("ticket", "WORLD-013")
	presentation.set_meta("route_half_width", 2.6)
	presentation.set_meta("river_crossing", "bridge_only")
	presentation.set_meta("canopy_layers", 2)
	presentation.set_meta("clue_sightlines", 5)
	presentation.set_meta("combat_arena_authored", true)
	context.add_node(presentation)
	_make_root_arch(presentation, context)
	_make_canopy_layer(presentation, context, "WychwoodCanopyLower", 2.8, 9 if context.quality_preset() == "potato" else 13 if context.quality_preset() == "balanced" else 17, Color(0.025, 0.095, 0.050))
	_make_canopy_layer(presentation, context, "WychwoodCanopyUpper", 4.4, 7 if context.quality_preset() == "potato" else 10 if context.quality_preset() == "balanced" else 14, Color(0.018, 0.060, 0.036))
	_make_understory_layer(presentation, context)
	_make_forest_floor_layer(presentation, context)
	_make_clue_sightline_markers(presentation, context)
	_make_clearing_frame(presentation, context)

func _make_root_arch(parent: Node3D, context: ZoneBuildContext) -> void:
	var root_material := context.make_material(Color(0.16, 0.082, 0.040))
	root_material.roughness = 0.92
	root_material.emission_enabled = true
	root_material.emission = Color(0.035, 0.012, 0.004)
	root_material.emission_energy_multiplier = 0.24
	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		post.name = "WychwoodRootArchPost"
		var post_mesh := CylinderMesh.new()
		post_mesh.top_radius = 0.18
		post_mesh.bottom_radius = 0.30
		post_mesh.height = 2.25
		post_mesh.radial_segments = 7
		post.mesh = post_mesh
		post.position = Vector3(side * 3.25, 1.12, 13.15)
		post.rotation.z = side * 0.12
		post.material_override = root_material
		parent.add_child(post)
	var lintel := MeshInstance3D.new()
	lintel.name = "WychwoodRootArchLintel"
	var lintel_mesh := BoxMesh.new()
	lintel_mesh.size = Vector3(6.65, 0.22, 0.30)
	lintel.mesh = lintel_mesh
	lintel.position = Vector3(0, 2.18, 13.15)
	lintel.rotation.z = -0.035
	lintel.material_override = root_material
	parent.add_child(lintel)
	var crown := MeshInstance3D.new()
	crown.name = "WychwoodRootArchCrown"
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 0.52
	crown_mesh.height = 0.88
	crown_mesh.radial_segments = 8
	crown_mesh.rings = 4
	crown.mesh = crown_mesh
	crown.scale = Vector3(1.55, 0.48, 0.42)
	crown.position = Vector3(0, 2.30, 13.15)
	crown.material_override = root_material
	parent.add_child(crown)
	var rune := MeshInstance3D.new()
	rune.name = "WychwoodRootArchRune"
	var rune_mesh := BoxMesh.new()
	rune_mesh.size = Vector3(0.10, 0.42, 0.035)
	rune.mesh = rune_mesh
	rune.position = Vector3(0, 2.20, 12.98)
	var rune_material := context.make_material(Color(0.34, 0.72, 0.58))
	rune_material.emission_enabled = true
	rune_material.emission = Color(0.20, 0.54, 0.40)
	rune_material.emission_energy_multiplier = 0.55
	rune.material_override = rune_material
	parent.add_child(rune)

func _make_canopy_layer(parent: Node3D, context: ZoneBuildContext, node_name: String, height: float, count: int, color: Color) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = count
	var batch := MultiMeshInstance3D.new()
	batch.name = node_name
	batch.multimesh = multimesh
	batch.material_override = context.make_material(color)
	batch.material_override.roughness = 0.95
	batch.visibility_range_end = 54.0
	parent.add_child(batch)
	for index in range(count):
		var side := -1.0 if index % 2 == 0 else 1.0
		var lane := float(index / 2)
		var x := side * (7.0 + fmod(lane * 2.85, 8.8))
		var z := 11.8 - fmod(lane * 4.35 + float(index % 3) * 0.55, 25.8)
		var scale_factor := 0.95 + float(index % 3) * 0.16
		var yaw := float(index % 5) * 0.22
		var basis := Basis.from_euler(Vector3(0, yaw, 0)).scaled(Vector3(1.35 * scale_factor, 0.78 + float(index % 2) * 0.13, 1.15 * scale_factor))
		multimesh.set_instance_transform(index, Transform3D(basis, Vector3(x, height, z)))

func _make_understory_layer(parent: Node3D, context: ZoneBuildContext) -> void:
	var count := 10 if context.quality_preset() == "potato" else 16 if context.quality_preset() == "balanced" else 22
	var mesh := SphereMesh.new()
	mesh.radius = 0.62
	mesh.height = 0.82
	mesh.radial_segments = 7
	mesh.rings = 3
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = count
	var batch := MultiMeshInstance3D.new()
	batch.name = "WychwoodUnderstoryBatch"
	batch.multimesh = multimesh
	batch.material_override = context.make_material(Color(0.035, 0.14, 0.060))
	batch.material_override.roughness = 0.98
	batch.visibility_range_end = 32.0
	parent.add_child(batch)
	for index in range(count):
		var side := -1.0 if index % 2 == 0 else 1.0
		var z := 11.0 - fmod(float(index) * 2.7, 23.0)
		var x := side * (3.9 + float(index % 4) * 0.82)
		var scale_factor := 0.72 + float(index % 3) * 0.12
		var basis := Basis.from_euler(Vector3(0, float(index) * 0.37, 0)).scaled(Vector3(scale_factor, 0.70 + float(index % 2) * 0.10, scale_factor))
		multimesh.set_instance_transform(index, Transform3D(basis, Vector3(x, 0.40, z)))

func _make_forest_floor_layer(parent: Node3D, context: ZoneBuildContext) -> void:
	var count := 12 if context.quality_preset() == "potato" else 20 if context.quality_preset() == "balanced" else 28
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.92, 0.028, 0.24)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = count
	var batch := MultiMeshInstance3D.new()
	batch.name = "WychwoodForestFloorDetail"
	batch.multimesh = multimesh
	batch.material_override = context.make_material(Color(0.075, 0.080, 0.045))
	batch.material_override.roughness = 1.0
	batch.visibility_range_end = 28.0
	parent.add_child(batch)
	for index in range(count):
		var side := -1.0 if index % 2 == 0 else 1.0
		var z := 10.4 - fmod(float(index) * 1.83, 22.0)
		var x := side * (3.15 + float(index % 5) * 0.52)
		var yaw := -0.55 + float(index % 4) * 0.37
		var basis := Basis.from_euler(Vector3(0, yaw, 0)).scaled(Vector3(0.9 + float(index % 3) * 0.16, 1.0, 0.8 + float(index % 2) * 0.18))
		multimesh.set_instance_transform(index, Transform3D(basis, Vector3(x, 0.06, z)))

func _make_clue_sightline_markers(parent: Node3D, context: ZoneBuildContext) -> void:
	var route := Node3D.new()
	route.name = "WychwoodClueSightlines"
	route.set_meta("count", 5)
	route.set_meta("route_width", 5.2)
	route.set_meta("order_independent", true)
	parent.add_child(route)
	var positions := [Vector3(-2.0, 0.0, 7.4), Vector3(-4.0, 0.0, 4.0), Vector3(3.8, 0.0, 2.2), Vector3(2.5, 0.0, 4.8), Vector3(0.0, 0.0, -4.2)]
	for index in range(5):
		var marker := Node3D.new()
		marker.name = "ClueSightline_%02d" % index
		marker.set_meta("clearance", 1.35)
		marker.set_meta("purpose", "readable_layby")
		marker.position = positions[index]
		route.add_child(marker)
	for pos in [Vector3(-2.8, 0.075, 9.8), Vector3(2.9, 0.078, 6.0), Vector3(-2.7, 0.080, 2.0), Vector3(2.8, 0.082, -1.0)]:
		context.make_visual_box("WychwoodRootCrossing", pos, Vector3(1.10, 0.045, 0.16), Color(0.085, 0.045, 0.024))

func _make_clearing_frame(parent: Node3D, context: ZoneBuildContext) -> void:
	var arena := Node3D.new()
	arena.name = "WychwoodCombatClearingFrame"
	arena.set_meta("center", Vector3(0, 0, -6.5))
	arena.set_meta("safe_half_extents", Vector2(5.2, 4.2))
	arena.set_meta("enemy_spacing", 2.3)
	parent.add_child(arena)
	var ash_material := context.make_material(Color(0.065, 0.050, 0.040))
	ash_material.roughness = 1.0
	for index in range(6):
		var angle := TAU * float(index) / 6.0
		var stone := MeshInstance3D.new()
		stone.name = "WychwoodClearingBoundaryStone"
		var stone_mesh := SphereMesh.new()
		stone_mesh.radius = 0.34 + float(index % 2) * 0.08
		stone_mesh.height = 0.55 + float(index % 3) * 0.10
		stone_mesh.radial_segments = 7
		stone_mesh.rings = 3
		stone.mesh = stone_mesh
		stone.position = Vector3(cos(angle) * 5.0, 0.28, -6.5 + sin(angle) * 3.7)
		stone.rotation.y = angle
		stone.material_override = ash_material
		arena.add_child(stone)
	var ring := MeshInstance3D.new()
	ring.name = "WychwoodClearingAshBed"
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 4.6
	ring_mesh.bottom_radius = 4.8
	ring_mesh.height = 0.028
	ring_mesh.radial_segments = 24
	ring.mesh = ring_mesh
	ring.position = Vector3(0, 0.045, -6.5)
	ring.material_override = ash_material
	arena.add_child(ring)
	var landmark := Node3D.new()
	landmark.name = "WychwoodMemoryLandmark"
	landmark.set_meta("purpose", "combat_aftermath_anchor")
	landmark.set_meta("visual_state", "unresolved_memory")
	landmark.position = Vector3(0, 0, -10.8)
	arena.add_child(landmark)
	context.make_ritual_stone(Vector3(0, 0, -10.8))

func _build_light_composition(context: ZoneBuildContext) -> void:
	context.make_light("Moon Shaft", Vector3(0, 6.6, -7), Color(0.48, 0.58, 0.78), 4.2)
	context.make_light("Sick Green Bounce", Vector3(9, 3.2, -9), Color(0.25, 0.42, 0.28), 1.7)
	context.make_light("Trail Threat", Vector3(0, 2.4, -2.8), Color(0.42, 0.68, 0.62), 1.4)
	context.make_fog_sheet(Vector3(0, 1.0, -6), Vector3(24, 1, 8), Color(0.24, 0.30, 0.28, 0.20))
	context.make_fog_sheet(Vector3(-10, 0.8, 5), Vector3(14, 1, 5), Color(0.16, 0.24, 0.18, 0.16))

func _build_gate_threshold(context: ZoneBuildContext) -> void:
	var marker := Node3D.new()
	marker.name = "WychwoodGateThreshold"
	marker.set_meta("clear_half_width", 3.4)
	context.add_node(marker)
	for x in [-3.7, 3.7]:
		context.make_torch(Vector3(x, 0, 13.4))
		context.make_tree(Vector3(x * 2.15, 0, 13.8))
	context.make_visual_box("WychwoodThresholdBrokenSign", Vector3(-4.2, 0.82, 12.8), Vector3(1.05, 0.12, 0.42), Color(0.10, 0.055, 0.028))

func _build_forest_frame(context: ZoneBuildContext) -> void:
	for x in [-20.0, -16.0, -12.0, -8.0, 8.0, 12.0, 16.0, 20.0]:
		context.make_tree(Vector3(x, 0, 15.2))
		context.make_tree(Vector3(x, 0, -15.2))
	context.make_tree_wall(16.0, -20.0, 7, false)
	context.make_tree_wall(16.0, 20.0, 7, false)
	context.make_tree_cluster([
		Vector3(-18,0,-12), Vector3(-15,0,-6), Vector3(-16,0,7), Vector3(-13,0,13),
		Vector3(16,0,-12), Vector3(18,0,-5), Vector3(17,0,5), Vector3(14,0,13),
		Vector3(-8,0,-14), Vector3(8,0,14), Vector3(-4,0,15), Vector3(5,0,-15),
	])
	for tree in [
		[Vector3(-13.0,0,10.0), 0.74, -12.0], [Vector3(12.5,0,9.2), 0.66, 17.0],
		[Vector3(-12.6,0,5.7), 0.64, 24.0], [Vector3(13.2,0,4.9), 0.76, -16.0],
		[Vector3(-12.8,0,-4.0), 0.72, 9.0], [Vector3(12.4,0,-3.8), 0.68, -22.0],
		[Vector3(-11.4,0,-11.0), 0.78, -6.0], [Vector3(11.8,0,-11.4), 0.74, 19.0],
	]:
		context.make_tree(tree[0])
		var marker := Node3D.new()
		marker.name = "WychwoodLandmarkTree"
		marker.position = tree[0]
		marker.set_meta("authored_scale", float(tree[1]))
		marker.set_meta("authored_yaw", float(tree[2]))
		marker.add_to_group("wychwood_landmark_tree")
		context.add_node(marker)

func _build_investigation_route(context: ZoneBuildContext) -> void:
	var marker := Node3D.new()
	marker.name = "WychwoodInvestigationRoute"
	marker.set_meta("clue_laybys", 3)
	context.add_node(marker)
	context.make_wychwood_route_dressing()
	context.make_wychwood_corridor()
	context.make_wychwood_story_beats()
	for pos in [Vector3(-8,0,-3), Vector3(6.7,0,-9.2), Vector3(9.8,0,-12.0), Vector3(-5,0,9.8)]:
		context.make_deadfall(pos)
	for bush in [Vector3(-6.6,0,8.0), Vector3(6.2,0,6.2), Vector3(-6.7,0,3.2), Vector3(6.8,0,-2.4)]:
		context.make_visual_box("WychwoodRouteBush", bush + Vector3(0, 0.42, 0), Vector3(1.15, 0.72, 0.62), Color(0.08, 0.20, 0.09))
		var bush_marker := Node3D.new()
		bush_marker.name = "WychwoodRouteBushMarker"
		bush_marker.position = bush
		bush_marker.add_to_group("wychwood_route_bush")
		context.add_node(bush_marker)

func _build_combat_clearing(context: ZoneBuildContext) -> void:
	var marker := Node3D.new()
	marker.name = "AuthoredWychwoodCombatArena"
	marker.set_meta("safe_half_extents", Vector2(5.2, 4.2))
	context.add_node(marker)
	context.make_monster_clearing(Vector3(0, 0, -6.5))
	for pos in [Vector3(6.8,0,-10.2), Vector3(8.5,0,-11.6), Vector3(10.0,0,-9.8), Vector3(8.5,0,-8.1)]:
		context.make_ritual_stone(pos)

func _build_gameplay_content(context: ZoneBuildContext) -> void:
	context.make_zone_gate("Back to Greyfen", Vector3(0, 0, 15), "greyfen", Vector3(0, 1, -13))
	context.make_clue("corpse", "Identify Bram by his cart ledger", Vector3(-0.9, 0, 9.0), "main_road_of_crows", "bram", Color(0.32, 0.18, 0.16))
	context.make_clue("black_feathers", "Identify Sella by the red-thread feathers", Vector3(0.9, 0, 7.3), "main_road_of_crows", "sella", Color(0.03, 0.03, 0.035))
	context.make_clue("oren_token", "Recover Oren's scratched shrine token", Vector3(3.8, 0, 2.2), "main_road_of_crows", "oren", Color(0.46, 0.28, 0.12))
	context.make_clue("claw_marks", "Recover the blackened Vargan wire", Vector3(-0.8, 0, 5.6), "main_road_of_crows", "vargan_wire", Color(0.18, 0.18, 0.18))
	context.make_clue("tracks", "Read the deliberate drag marks", Vector3(0, 0, -4.2), "main_road_of_crows", "drag_marks", Color(0.15, 0.11, 0.08))
	if context.is_quest_active("main_teeth_in_rain") and context.is_objective_done("main_teeth_in_rain", "read_chapel_names"):
		if not context.is_objective_done("main_teeth_in_rain", "name_the_dead"):
			context.make_clue("ritual_stones", "Speak Oren's name at the ritual stones", Vector3(8, 0, -10), "main_teeth_in_rain", "name_the_dead", Color(0.38, 0.38, 0.36))
		else:
			context.make_zone_gate("Enter deeper Wychwood", Vector3(10.8, 0, -13.2), "deep_wood", Vector3(0, 1, 12))
	context.make_clue("bandit_camp", "Inspect bandit camp", Vector3(-12, 0, -12), "side_black_dog", "find_dog", Color(0.30, 0.18, 0.10))
	context.make_clue("bitter_roots", "Collect bitter roots", Vector3(8, 0, -7.8), "side_bitter_roots", "collect_roots", Color(0.46, 0.22, 0.16))
	context.make_clue("sacrifice_roots", "Study sacrifice roots", Vector3(10, 0, -9.2), "side_bitter_roots", "mira_choice", Color(0.38, 0.16, 0.13))
	context.make_herb("mooncap", Vector3(-7, 0, -6), Color(0.58, 0.65, 0.86))
	context.make_herb("redroot", Vector3(-10, 0, -2), Color(0.55, 0.12, 0.11))
	context.make_herb("grave_moss", Vector3(5, 0, -13), Color(0.24, 0.42, 0.24))
	if context.is_quest_active("main_road_of_crows") and not context.is_objective_done("main_road_of_crows", "fight_ghoulkin"):
		context.spawn_enemy("ghoulkin", Vector3(-2.4, 0.8, -8.8))
		var second_ghoul = context.spawn_enemy("ghoulkin", Vector3(2.7, 0.8, -9.6))
		if second_ghoul != null:
			second_ghoul.set_encounter_active(false)
		context.spawn_enemy("wychwood_stalker", Vector3(-4.8, 0.8, -3.8))
		context.spawn_enemy("wychwood_raider", Vector3(4.6, 0.8, -5.3))
		var brute_z := -14.2 if context.is_objective_done("main_road_of_crows", "drag_marks") else -12.4
		context.spawn_enemy("wychwood_brute", Vector3(0.2, 0.8, brute_z))
	if context.is_quest_active("side_black_dog") and not context.is_objective_done("side_black_dog", "find_dog"):
		context.spawn_enemy("bandit", Vector3(-14, 0.8, -14))
		context.spawn_enemy("bandit", Vector3(-12, 0.8, -15))
