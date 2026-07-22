extends RefCounted


func build(parent: Node3D, context: Dictionary) -> void:
	var host: Node = context.get("host")
	var origin: Vector3 = context.get("origin", Vector3.ZERO)
	if host == null or parent == null:
		return

	var section := Node3D.new()
	section.name = "GreyfenCemeterySection"
	section.position = origin
	section.add_to_group("cemetery_section")
	section.set_meta("ticket", "WORLD-003")
	section.set_meta("authored_route_width", 2.4)
	parent.add_child(section)

	_add_marker(section, "CemeteryEntry", Vector3(-4.3, 0, -0.6))
	_add_marker(section, "SisterAnwenCemeteryStage", Vector3(-3.2, 0, -1.7))
	_add_marker(section, "CemeteryEncounterStage", Vector3(0.3, 0, 0.1))
	_add_marker(section, "CrowShrineStage", Vector3(2.0, 0, -2.5))
	_add_composition_marker(section, "AuthoredCemeteryApproach", Vector3(-3.8, 0, -0.6))
	_add_composition_marker(section, "AuthoredGraveCourt", Vector3(0, 0, -0.2))
	_add_composition_marker(section, "AuthoredCrowChapel", Vector3(3.15, 0, -0.6))

	_build_approach(host, origin)
	_build_boundary(host, origin)
	_build_grave_court(host, origin)
	_build_chapel(host, origin)
	_build_bell_and_shrine(host, origin)
	_build_edge_dressing(host, origin)


func _build_approach(host: Node, origin: Vector3) -> void:
	# The west lane stays broad enough for Kael, Anwen staging, and the camera boom.
	host.call("_make_road", origin + Vector3(-4.0, 0.024, -0.6), Vector3(8.0, 0.045, 2.6), Color(0.115, 0.105, 0.085))
	host.call("_make_road", origin + Vector3(-0.3, 0.025, -0.6), Vector3(6.8, 0.045, 7.4), Color(0.09, 0.087, 0.075))
	for offset in [Vector3(-3.4, 0, -2.15), Vector3(-3.4, 0, 0.95)]:
		host.call("_make_prop_box", "CemeteryGatePier", origin + offset + Vector3.UP * 1.15, Vector3(0.62, 2.3, 0.62), Color(0.20, 0.205, 0.19))
		host.call("_make_prop_box", "CemeteryGateCap", origin + offset + Vector3.UP * 2.38, Vector3(0.82, 0.20, 0.82), Color(0.27, 0.27, 0.25))
	# A broken iron lintel gives the entrance a silhouette without closing the route.
	host.call("_make_visual_box", "CemeteryBrokenLintel", origin + Vector3(-3.4, 2.35, -1.55), Vector3(0.12, 0.12, 0.92), Color(0.095, 0.085, 0.072))


func _build_boundary(host: Node, origin: Vector3) -> void:
	# The chapel completes the east edge; the west entrance remains entirely open.
	host.call("_make_prop_box", "CemeteryNorthWall", origin + Vector3(0.2, 0.45, -4.05), Vector3(8.0, 0.90, 0.38), Color(0.17, 0.18, 0.17))
	host.call("_make_prop_box", "CemeterySouthWall", origin + Vector3(0.2, 0.45, 3.15), Vector3(8.0, 0.90, 0.38), Color(0.17, 0.18, 0.17))
	host.call("_make_prop_box", "CemeteryEastWallNorth", origin + Vector3(4.1, 0.45, -3.15), Vector3(0.38, 0.90, 1.45), Color(0.16, 0.17, 0.16))
	host.call("_make_prop_box", "CemeteryEastWallSouth", origin + Vector3(4.1, 0.45, 2.25), Vector3(0.38, 0.90, 1.45), Color(0.16, 0.17, 0.16))
	for x in [-2.5, -0.7, 1.1, 2.9]:
		host.call("_make_visual_box", "CemeteryWallMoss", origin + Vector3(x, 0.78, -4.25), Vector3(0.65, 0.08, 0.03), Color(0.07, 0.14, 0.075))


func _build_grave_court(host: Node, origin: Vector3) -> void:
	# These graves frame, but never cover, the three existing investigation points.
	var graves := [
		[Vector3(-1.8, 0, -2.10), -7.0], [Vector3(0.0, 0, 2.28), 4.0],
		[Vector3(2.2, 0, -2.10), 7.0], [Vector3(-1.8, 0, 1.05), -4.0],
		[Vector3(0.2, 0, -2.55), 5.0], [Vector3(2.0, 0, 1.95), -6.0],
	]
	for grave in graves:
		var grave_pos: Vector3 = origin + grave[0]
		host.call("_make_gravestone", grave_pos)
		host.call("_make_visual_box", "GraveEarth", grave_pos + Vector3(0, 0.055, 0.52), Vector3(0.72, 0.035, 1.05), Color(0.070, 0.052, 0.040))
	for offset in [Vector3(-2.7, 0, -3.35), Vector3(-2.75, 0, 2.45), Vector3(0.75, 0, 2.65)]:
		host.call("_make_rubble", origin + offset)
	for offset in [Vector3(-0.85, 0, 0.35), Vector3(0.65, 0, 0.65), Vector3(1.25, 0, -2.95)]:
		host.call("_make_visual_box", "CemeteryPathStone", origin + offset + Vector3.UP * 0.06, Vector3(0.58, 0.04, 0.38), Color(0.21, 0.215, 0.195))


func _build_chapel(host: Node, origin: Vector3) -> void:
	var centre := origin + Vector3(3.05, 0, -0.55)
	host.call("_make_prop_box", "RuinedCrowChapelFloor", centre + Vector3(0, 0.11, 0), Vector3(3.0, 0.22, 3.65), Color(0.125, 0.125, 0.112))
	host.call("_make_prop_box", "RuinedCrowChapelBackWall", centre + Vector3(1.38, 1.72, 0), Vector3(0.42, 3.44, 3.65), Color(0.235, 0.235, 0.215))
	host.call("_make_prop_box", "RuinedCrowChapelNorthWall", centre + Vector3(0, 1.38, -1.66), Vector3(2.75, 2.76, 0.38), Color(0.22, 0.22, 0.20))
	host.call("_make_prop_box", "RuinedCrowChapelSouthWall", centre + Vector3(0.25, 1.12, 1.66), Vector3(2.25, 2.24, 0.38), Color(0.205, 0.205, 0.187))
	# Split facade leaves a physical doorway centred on the existing chapel interaction.
	host.call("_make_prop_box", "CrowChapelFacadeNorth", centre + Vector3(-1.38, 1.25, -1.22), Vector3(0.38, 2.50, 0.82), Color(0.22, 0.22, 0.20))
	host.call("_make_prop_box", "CrowChapelFacadeSouth", centre + Vector3(-1.38, 1.25, 1.22), Vector3(0.38, 2.50, 0.82), Color(0.22, 0.22, 0.20))
	host.call("_make_prop_box", "CrowChapelDoorLintel", centre + Vector3(-1.38, 2.42, 0), Vector3(0.38, 0.34, 1.62), Color(0.24, 0.24, 0.22))
	# A fractured roofline reads as a ruin instead of a sealed box.
	host.call("_make_prop_box", "CrowChapelRoofNorth", centre + Vector3(0.35, 3.18, -1.05), Vector3(2.0, 0.24, 1.45), Color(0.095, 0.092, 0.082))
	host.call("_make_prop_box", "CrowChapelRoofSouth", centre + Vector3(0.72, 2.95, 1.20), Vector3(1.25, 0.22, 1.02), Color(0.095, 0.092, 0.082))
	host.call("_make_prop_box", "CrowChapelAltar", centre + Vector3(0.72, 0.52, 0), Vector3(0.72, 1.04, 1.18), Color(0.17, 0.17, 0.15))
	host.call("_make_prop_box", "OssuarySealedDoor", centre + Vector3(1.14, 0.86, 0), Vector3(0.12, 1.72, 1.12), Color(0.075, 0.065, 0.052))
	host.call("_make_visual_box", "OssuaryIronBinding", centre + Vector3(1.06, 0.98, 0), Vector3(0.04, 0.09, 1.24), Color(0.25, 0.19, 0.11))


func _build_bell_and_shrine(host: Node, origin: Vector3) -> void:
	var bell_root := Node3D.new()
	bell_root.name = "CemeteryBellFrame"
	bell_root.position = origin + Vector3(1.75, 0, 1.08)
	bell_root.add_to_group("cemetery_landmark")
	host.zone_root.add_child(bell_root)
	host.call("_make_prop_box", "BellPost", origin + Vector3(1.15, 1.18, 1.08), Vector3(0.18, 2.36, 0.18), Color(0.12, 0.075, 0.042))
	host.call("_make_prop_box", "BellPost", origin + Vector3(2.35, 1.18, 1.08), Vector3(0.18, 2.36, 0.18), Color(0.12, 0.075, 0.042))
	host.call("_make_prop_box", "BellCrossbeam", origin + Vector3(1.75, 2.25, 1.08), Vector3(1.55, 0.18, 0.22), Color(0.14, 0.085, 0.045))
	var bell := MeshInstance3D.new()
	bell.name = "CrowCemeteryBell"
	var bell_mesh := CylinderMesh.new()
	bell_mesh.top_radius = 0.16
	bell_mesh.bottom_radius = 0.31
	bell_mesh.height = 0.52
	bell_mesh.radial_segments = 12
	bell.mesh = bell_mesh
	bell.position = origin + Vector3(1.75, 1.75, 1.08)
	bell.material_override = host.call("_mat", Color(0.30, 0.235, 0.13))
	host.zone_root.add_child(bell)
	# The shrine is readable from the entrance but stays clear of the grave clues.
	host.call("_make_prop_box", "CemeteryCrowShrine", origin + Vector3(2.05, 0.72, -2.92), Vector3(0.58, 1.44, 0.38), Color(0.23, 0.235, 0.215))
	host.call("_make_visual_box", "CrowShrineMark", origin + Vector3(2.05, 0.90, -3.13), Vector3(0.24, 0.42, 0.025), Color(0.045, 0.042, 0.038))
	host.call("_make_light", "CemeteryChapelGlow", origin + Vector3(2.55, 2.2, -0.55), Color(0.46, 0.60, 0.50), 1.15)


func _build_edge_dressing(host: Node, origin: Vector3) -> void:
	for tree in [
		[Vector3(-2.9, 0, -4.8), 0.78, -15.0], [Vector3(0.4, 0, -4.9), 0.92, 12.0],
		[Vector3(-2.7, 0, 3.9), 0.84, 21.0], [Vector3(1.0, 0, 4.0), 0.72, -8.0],
	]:
		host.call("_make_loose_role", "forest_tree", origin + tree[0], Vector3.ONE * float(tree[1]), float(tree[2]))
	for offset in [Vector3(-2.55, 0, -3.45), Vector3(-1.0, 0, 2.78), Vector3(2.75, 0, 2.82)]:
		host.call("_make_loose_role", "forest_rock", origin + offset, Vector3.ONE * 0.55, 0.0)
	host.call("_make_fog_sheet", origin + Vector3(0.3, 0.42, -0.35), Vector3(7.5, 0.62, 6.6), Color(0.13, 0.16, 0.145, 0.09))


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
