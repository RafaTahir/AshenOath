extends RefCounted


func build(context: ZoneBuildContext, origin: Vector3) -> void:
	var section := Node3D.new()
	section.name = "GreyfenCemeterySection"
	section.position = origin
	section.add_to_group("cemetery_section")
	section.set_meta("ticket", "WORLD-003")
	section.set_meta("authored_route_width", 2.4)
	context.add_node(section)

	_add_marker(section, "CemeteryEntry", Vector3(-4.3, 0, -0.6))
	_add_marker(section, "SisterAnwenCemeteryStage", Vector3(-3.2, 0, -1.7))
	_add_marker(section, "CemeteryEncounterStage", Vector3(0.3, 0, 0.1))
	_add_marker(section, "CrowShrineStage", Vector3(2.0, 0, -2.5))
	_add_composition_marker(section, "AuthoredCemeteryApproach", Vector3(-3.8, 0, -0.6))
	_add_composition_marker(section, "AuthoredGraveCourt", Vector3(0, 0, -0.2))
	_add_composition_marker(section, "AuthoredCrowChapel", Vector3(3.15, 0, -0.6))

	_build_approach(context, origin)
	_build_boundary(context, origin)
	_build_grave_court(context, origin)
	_build_chapel(context, origin)
	_build_bell_and_shrine(context, origin)
	_build_edge_dressing(context, origin)
	_build_authored_presentation(context, origin)

func _build_authored_presentation(context: ZoneBuildContext, origin: Vector3) -> void:
	var layer := Node3D.new()
	layer.name = "CemeteryAuthoredPresentation"
	layer.position = origin
	layer.set_meta("ticket", "WORLD-014")
	layer.set_meta("bell_stateful", true)
	layer.set_meta("chapel_stateful", true)
	layer.set_meta("ossuary_stateful", true)
	layer.set_meta("grave_rows", 3)
	layer.set_meta("crow_shrine_consequence", true)
	context.add_node(layer)
	_make_bell_house(layer, context)
	_make_chapel_focal_details(layer, context)
	_make_grave_row_rhythm(layer, context)
	_make_crow_roost(layer, context)
	_make_cemetery_state_anchors(layer, context)

func _make_bell_house(parent: Node3D, context: ZoneBuildContext) -> void:
	var wood := context.make_material(Color(0.19, 0.105, 0.050))
	wood.roughness = 0.94
	for side in [-1.0, 1.0]:
		var brace := MeshInstance3D.new()
		brace.name = "CemeteryBellHouseBrace"
		var brace_mesh := CylinderMesh.new()
		brace_mesh.top_radius = 0.11
		brace_mesh.bottom_radius = 0.16
		brace_mesh.height = 2.65
		brace_mesh.radial_segments = 7
		brace.mesh = brace_mesh
		brace.position = Vector3(1.75 + side * 0.82, 1.32, 1.08)
		brace.rotation.z = side * 0.13
		brace.material_override = wood
		parent.add_child(brace)
	var hood := MeshInstance3D.new()
	hood.name = "CemeteryBellHouseHood"
	var hood_mesh := CylinderMesh.new()
	hood_mesh.top_radius = 0.62
	hood_mesh.bottom_radius = 0.88
	hood_mesh.height = 0.22
	hood_mesh.radial_segments = 8
	hood.mesh = hood_mesh
	hood.position = Vector3(1.75, 2.48, 1.08)
	hood.scale = Vector3(1.0, 1.0, 0.72)
	hood.material_override = wood
	parent.add_child(hood)
	var clapper := MeshInstance3D.new()
	clapper.name = "CemeteryBellClapper"
	var clapper_mesh := CylinderMesh.new()
	clapper_mesh.top_radius = 0.04
	clapper_mesh.bottom_radius = 0.07
	clapper_mesh.height = 0.52
	clapper_mesh.radial_segments = 6
	clapper.mesh = clapper_mesh
	clapper.position = Vector3(1.75, 1.44, 1.08)
	clapper.material_override = context.make_material(Color(0.12, 0.10, 0.075))
	parent.add_child(clapper)
	var rope := MeshInstance3D.new()
	rope.name = "CemeteryBellRope"
	var rope_mesh := CylinderMesh.new()
	rope_mesh.top_radius = 0.025
	rope_mesh.bottom_radius = 0.025
	rope_mesh.height = 0.82
	rope_mesh.radial_segments = 5
	rope.mesh = rope_mesh
	rope.position = Vector3(1.75, 0.92, 1.08)
	rope.material_override = context.make_material(Color(0.28, 0.16, 0.07))
	parent.add_child(rope)

func _make_chapel_focal_details(parent: Node3D, context: ZoneBuildContext) -> void:
	var stone := context.make_material(Color(0.30, 0.30, 0.275))
	stone.roughness = 0.98
	var centre := Vector3(3.05, 0, -0.55)
	for index in range(3):
		var buttress := MeshInstance3D.new()
		buttress.name = "CrowChapelButtress"
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.24, 1.9 + float(index % 2) * 0.35, 0.32)
		buttress.mesh = mesh
		buttress.position = centre + Vector3(1.55, 0.96, -1.35 + float(index) * 1.35)
		buttress.rotation.z = -0.10 if index != 1 else 0.08
		buttress.material_override = stone
		parent.add_child(buttress)
	var window := MeshInstance3D.new()
	window.name = "CrowChapelMemoryWindow"
	var window_mesh := BoxMesh.new()
	window_mesh.size = Vector3(0.035, 0.82, 0.58)
	window.mesh = window_mesh
	window.position = centre + Vector3(1.14, 1.96, 0)
	var window_material := context.make_material(Color(0.28, 0.62, 0.54))
	window_material.emission_enabled = true
	window_material.emission = Color(0.14, 0.40, 0.31)
	window_material.emission_energy_multiplier = 0.42
	window.material_override = window_material
	parent.add_child(window)
	for z in [-0.35, 0.0, 0.35]:
		context.make_visual_box("CrowChapelFloorMoss", centre + Vector3(0.1, 0.235, z), Vector3(1.1, 0.018, 0.08), Color(0.07, 0.14, 0.075))

func _make_grave_row_rhythm(parent: Node3D, context: ZoneBuildContext) -> void:
	var row_root := Node3D.new()
	row_root.name = "CemeteryGraveRowRhythm"
	row_root.set_meta("rows", 3)
	row_root.set_meta("purpose", "readable_investigation_framing")
	parent.add_child(row_root)
	var stone_material := context.make_material(Color(0.25, 0.255, 0.24))
	stone_material.roughness = 1.0
	for row in range(3):
		for column in range(3):
			var marker := MeshInstance3D.new()
			marker.name = "CemeteryRowMarker"
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.09, 0.48 + float((row + column) % 2) * 0.10, 0.16)
			marker.mesh = mesh
			marker.position = Vector3(-1.25 + float(column) * 0.72, 0.32, -1.3 + float(row) * 1.0)
			marker.rotation.y = -0.10 + float((row + column) % 3) * 0.12
			marker.material_override = stone_material
			row_root.add_child(marker)

func _make_crow_roost(parent: Node3D, context: ZoneBuildContext) -> void:
	var roost := Node3D.new()
	roost.name = "CrowShrineRoost"
	roost.set_meta("stateful", true)
	parent.add_child(roost)
	var branch_material := context.make_material(Color(0.10, 0.055, 0.025))
	for index in range(3):
		var branch := MeshInstance3D.new()
		branch.name = "CrowShrineBranch"
		var branch_mesh := CylinderMesh.new()
		branch_mesh.top_radius = 0.045
		branch_mesh.bottom_radius = 0.075
		branch_mesh.height = 1.15
		branch_mesh.radial_segments = 6
		branch.mesh = branch_mesh
		branch.position = Vector3(2.05 + float(index - 1) * 0.42, 1.05, -3.0 + float(index % 2) * 0.12)
		branch.rotation.z = -0.64 + float(index) * 0.58
		branch.material_override = branch_material
		roost.add_child(branch)
		var crow := MeshInstance3D.new()
		crow.name = "CrowShrineSilhouette"
		var crow_mesh := SphereMesh.new()
		crow_mesh.radius = 0.12
		crow_mesh.height = 0.30
		crow_mesh.radial_segments = 6
		crow_mesh.rings = 3
		crow.mesh = crow_mesh
		crow.scale = Vector3(1.0, 0.72, 1.45)
		crow.position = branch.position + Vector3(0, 0.62, 0)
		crow.material_override = context.make_material(Color(0.012, 0.014, 0.016))
		roost.add_child(crow)

func _make_cemetery_state_anchors(parent: Node3D, context: ZoneBuildContext) -> void:
	var states := Node3D.new()
	states.name = "CemeteryStateAnchors"
	states.set_meta("bell_before", "silent")
	states.set_meta("bell_after", "rung")
	states.set_meta("chapel_before", "sealed")
	states.set_meta("chapel_after", "opened")
	states.set_meta("ambush_before", "pending")
	states.set_meta("ambush_after", "cleared")
	parent.add_child(states)
	for data in [
		["BellStateAnchor", Vector3(1.75, 2.60, 1.08)],
		["ChapelStateAnchor", Vector3(4.10, 1.18, -0.55)],
		["AmbushStateAnchor", Vector3(0.30, 0.05, 0.10)],
	]:
		var anchor := Node3D.new()
		anchor.name = str(data[0])
		anchor.position = data[1]
		anchor.set_meta("visual_state_source", "story_state")
		states.add_child(anchor)


func _build_approach(context: ZoneBuildContext, origin: Vector3) -> void:
	# The west lane stays broad enough for Kael, Anwen staging, and the camera boom.
	context.make_road(origin + Vector3(-4.0, 0.024, -0.6), Vector3(8.0, 0.045, 2.6), Color(0.115, 0.105, 0.085))
	context.make_road(origin + Vector3(-0.3, 0.025, -0.6), Vector3(6.8, 0.045, 7.4), Color(0.09, 0.087, 0.075))
	for offset in [Vector3(-3.4, 0, -2.15), Vector3(-3.4, 0, 0.95)]:
		context.make_prop_box("CemeteryGatePier", origin + offset + Vector3.UP * 1.15, Vector3(0.62, 2.3, 0.62), Color(0.20, 0.205, 0.19))
		context.make_prop_box("CemeteryGateCap", origin + offset + Vector3.UP * 2.38, Vector3(0.82, 0.20, 0.82), Color(0.27, 0.27, 0.25))
	# A broken iron lintel gives the entrance a silhouette without closing the route.
	context.make_visual_box("CemeteryBrokenLintel", origin + Vector3(-3.4, 2.35, -1.55), Vector3(0.12, 0.12, 0.92), Color(0.095, 0.085, 0.072))


func _build_boundary(context: ZoneBuildContext, origin: Vector3) -> void:
	# The chapel completes the east edge; the west entrance remains entirely open.
	context.make_prop_box("CemeteryNorthWall", origin + Vector3(0.2, 0.45, -4.05), Vector3(8.0, 0.90, 0.38), Color(0.17, 0.18, 0.17))
	context.make_prop_box("CemeterySouthWall", origin + Vector3(0.2, 0.45, 3.15), Vector3(8.0, 0.90, 0.38), Color(0.17, 0.18, 0.17))
	context.make_prop_box("CemeteryEastWallNorth", origin + Vector3(4.1, 0.45, -3.15), Vector3(0.38, 0.90, 1.45), Color(0.16, 0.17, 0.16))
	context.make_prop_box("CemeteryEastWallSouth", origin + Vector3(4.1, 0.45, 2.25), Vector3(0.38, 0.90, 1.45), Color(0.16, 0.17, 0.16))
	for x in [-2.5, -0.7, 1.1, 2.9]:
		context.make_visual_box("CemeteryWallMoss", origin + Vector3(x, 0.78, -4.25), Vector3(0.65, 0.08, 0.03), Color(0.07, 0.14, 0.075))


func _build_grave_court(context: ZoneBuildContext, origin: Vector3) -> void:
	# These graves frame, but never cover, the three existing investigation points.
	var graves := [
		[Vector3(-1.8, 0, -2.10), -7.0], [Vector3(0.0, 0, 2.28), 4.0],
		[Vector3(2.2, 0, -2.10), 7.0], [Vector3(-1.8, 0, 1.05), -4.0],
		[Vector3(0.2, 0, -2.55), 5.0], [Vector3(2.0, 0, 1.95), -6.0],
	]
	for grave in graves:
		var grave_pos: Vector3 = origin + grave[0]
		context.make_gravestone(grave_pos)
		context.make_visual_box("GraveEarth", grave_pos + Vector3(0, 0.055, 0.52), Vector3(0.72, 0.035, 1.05), Color(0.070, 0.052, 0.040))
	for offset in [Vector3(-2.7, 0, -3.35), Vector3(-2.75, 0, 2.45), Vector3(0.75, 0, 2.65)]:
		context.make_rubble(origin + offset)
	for offset in [Vector3(-0.85, 0, 0.35), Vector3(0.65, 0, 0.65), Vector3(1.25, 0, -2.95)]:
		context.make_visual_box("CemeteryPathStone", origin + offset + Vector3.UP * 0.06, Vector3(0.58, 0.04, 0.38), Color(0.21, 0.215, 0.195))


func _build_chapel(context: ZoneBuildContext, origin: Vector3) -> void:
	var centre := origin + Vector3(3.05, 0, -0.55)
	context.make_prop_box("RuinedCrowChapelFloor", centre + Vector3(0, 0.11, 0), Vector3(3.0, 0.22, 3.65), Color(0.125, 0.125, 0.112))
	context.make_prop_box("RuinedCrowChapelBackWall", centre + Vector3(1.38, 1.72, 0), Vector3(0.42, 3.44, 3.65), Color(0.235, 0.235, 0.215))
	context.make_prop_box("RuinedCrowChapelNorthWall", centre + Vector3(0, 1.38, -1.66), Vector3(2.75, 2.76, 0.38), Color(0.22, 0.22, 0.20))
	context.make_prop_box("RuinedCrowChapelSouthWall", centre + Vector3(0.25, 1.12, 1.66), Vector3(2.25, 2.24, 0.38), Color(0.205, 0.205, 0.187))
	# Split facade leaves a physical doorway centred on the existing chapel interaction.
	context.make_prop_box("CrowChapelFacadeNorth", centre + Vector3(-1.38, 1.25, -1.22), Vector3(0.38, 2.50, 0.82), Color(0.22, 0.22, 0.20))
	context.make_prop_box("CrowChapelFacadeSouth", centre + Vector3(-1.38, 1.25, 1.22), Vector3(0.38, 2.50, 0.82), Color(0.22, 0.22, 0.20))
	context.make_prop_box("CrowChapelDoorLintel", centre + Vector3(-1.38, 2.42, 0), Vector3(0.38, 0.34, 1.62), Color(0.24, 0.24, 0.22))
	# A fractured roofline reads as a ruin instead of a sealed box.
	context.make_prop_box("CrowChapelRoofNorth", centre + Vector3(0.35, 3.18, -1.05), Vector3(2.0, 0.24, 1.45), Color(0.095, 0.092, 0.082))
	context.make_prop_box("CrowChapelRoofSouth", centre + Vector3(0.72, 2.95, 1.20), Vector3(1.25, 0.22, 1.02), Color(0.095, 0.092, 0.082))
	context.make_prop_box("CrowChapelAltar", centre + Vector3(0.72, 0.52, 0), Vector3(0.72, 1.04, 1.18), Color(0.17, 0.17, 0.15))
	context.make_prop_box("OssuarySealedDoor", centre + Vector3(1.14, 0.86, 0), Vector3(0.12, 1.72, 1.12), Color(0.075, 0.065, 0.052))
	context.make_visual_box("OssuaryIronBinding", centre + Vector3(1.06, 0.98, 0), Vector3(0.04, 0.09, 1.24), Color(0.25, 0.19, 0.11))


func _build_bell_and_shrine(context: ZoneBuildContext, origin: Vector3) -> void:
	var bell_root := Node3D.new()
	bell_root.name = "CemeteryBellFrame"
	bell_root.position = origin + Vector3(1.75, 0, 1.08)
	bell_root.add_to_group("cemetery_landmark")
	context.add_node(bell_root)
	context.make_prop_box("BellPost", origin + Vector3(1.15, 1.18, 1.08), Vector3(0.18, 2.36, 0.18), Color(0.12, 0.075, 0.042))
	context.make_prop_box("BellPost", origin + Vector3(2.35, 1.18, 1.08), Vector3(0.18, 2.36, 0.18), Color(0.12, 0.075, 0.042))
	context.make_prop_box("BellCrossbeam", origin + Vector3(1.75, 2.25, 1.08), Vector3(1.55, 0.18, 0.22), Color(0.14, 0.085, 0.045))
	var bell := MeshInstance3D.new()
	bell.name = "CrowCemeteryBell"
	var bell_mesh := CylinderMesh.new()
	bell_mesh.top_radius = 0.16
	bell_mesh.bottom_radius = 0.31
	bell_mesh.height = 0.52
	bell_mesh.radial_segments = 12
	bell.mesh = bell_mesh
	bell.position = origin + Vector3(1.75, 1.75, 1.08)
	bell.material_override = context.make_material(Color(0.30, 0.235, 0.13))
	context.add_node(bell)
	# The shrine is readable from the entrance but stays clear of the grave clues.
	context.make_prop_box("CemeteryCrowShrine", origin + Vector3(2.05, 0.72, -2.92), Vector3(0.58, 1.44, 0.38), Color(0.23, 0.235, 0.215))
	context.make_visual_box("CrowShrineMark", origin + Vector3(2.05, 0.90, -3.13), Vector3(0.24, 0.42, 0.025), Color(0.045, 0.042, 0.038))
	context.make_light("CemeteryChapelGlow", origin + Vector3(2.55, 2.2, -0.55), Color(0.46, 0.60, 0.50), 1.15)


func _build_edge_dressing(context: ZoneBuildContext, origin: Vector3) -> void:
	for tree in [
		# Keep the cemetery edge alive without filling the authored sightlines.
		[Vector3(-3.4, 0, -6.25), 0.40, -15.0], [Vector3(0.9, 0, -6.35), 0.44, 12.0],
		[Vector3(-3.2, 0, 6.05), 0.40, 21.0], [Vector3(1.35, 0, 6.15), 0.38, -8.0],
	]:
		context.make_loose_role("forest_tree", origin + tree[0], Vector3.ONE * float(tree[1]), float(tree[2]))
	for offset in [Vector3(-2.55, 0, -3.45), Vector3(-1.0, 0, 2.78), Vector3(2.75, 0, 2.82)]:
		context.make_loose_role("forest_rock", origin + offset, Vector3.ONE * 0.55, 0.0)
	context.make_fog_sheet(origin + Vector3(0.3, 0.42, -0.35), Vector3(7.5, 0.62, 6.6), Color(0.13, 0.16, 0.145, 0.09))


func _add_composition_marker(parent: Node3D, marker_name: String, local_position: Vector3) -> void:
	var marker := Node3D.new()
	marker.name = marker_name
	marker.position = local_position
	marker.add_to_group("world_003_composition")
	parent.add_child(marker)


func _add_marker(parent: Node3D, marker_name: String, local_position: Vector3) -> void:
	var marker := Marker3D.new()
	marker.name = marker_name
	marker.position = local_position
	parent.add_child(marker)
