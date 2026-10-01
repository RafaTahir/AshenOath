extends RefCounted

const ANWEN_CEMETERY_STAGE := Vector3(9.4, 0.0, 7.6)
const CROW_SHRINE_VISUAL_STAGE := Vector3(17.1, 0.0, 7.2)
const CROW_SHRINE_INTERACTION_STAGE := Vector3(16.35, 0.24, 7.7)
const BUILD_STAGES := ["approach", "boundary", "graves", "chapel", "bell", "edges", "presentation"]
const PRESENTATION_STAGES := ["bell", "chapel", "graves", "roost", "states"]
const CHAPEL_MESH := preload("res://assets_external/environment/village/Cemetery_chapel_Authored.res")
const BELL_FRAME_MESH := preload("res://assets_external/environment/village/Cemetery_bell_frame_Authored.res")
const BELL_MESH := preload("res://assets_external/environment/village/Cemetery_bell_Authored.res")
const GRAVE_ROWS_MESH := preload("res://assets_external/environment/village/Cemetery_grave_rows_Authored.res")
const DETAIL_MESHES := {
	"boundary": preload("res://assets_external/environment/village/Cemetery_boundary_Authored.res"),
	"grave_earth": preload("res://assets_external/environment/village/Cemetery_grave_earth_Authored.res"),
	"memory_window": preload("res://assets_external/environment/village/Cemetery_memory_window_Authored.res"),
}

func build(context: ZoneBuildContext, origin: Vector3, compact: bool = false) -> void:
	for stage in BUILD_STAGES:
		build_stage(context, origin, stage, compact)

func build_stage(context: ZoneBuildContext, origin: Vector3, stage: String, compact: bool = false) -> void:
	if stage.begins_with("presentation_") and not compact:
		_build_presentation_stage(context, origin, stage.trim_prefix("presentation_"))
		return
	if stage not in BUILD_STAGES:
		push_error("Unknown cemetery build stage: " + stage)
		return
	var section := context.zone_root.find_child("GreyfenCemeterySection", true, false)
	if section == null:
		section = _create_section(context, origin)
	var key := "built_" + stage
	if stage == "edges" and compact:
		return
	if stage == "presentation" and not compact and bool(section.get_meta("presentation_compact", false)):
		var compact_layer := context.zone_root.find_child("CemeteryAuthoredPresentation", true, false)
		if compact_layer != null and bool(compact_layer.get_meta("compact_opening", false)):
			compact_layer.name = "RetiredCompactCemeteryPresentation"
			compact_layer.queue_free()
		section.set_meta(key, false)
	if bool(section.get_meta(key, false)):
		return
	match stage:
		"approach": _build_approach(context, origin)
		"boundary": _build_boundary(context, origin)
		"graves": _build_grave_court(context, origin)
		"chapel": _build_chapel(context, origin)
		"bell": _build_bell_and_shrine(context, origin)
		"edges":
			if not compact:
				_build_edge_dressing(context, origin)
		"presentation":
			if compact:
				_add_compact_presentation_marker(context, origin)
			else:
				for presentation_stage in PRESENTATION_STAGES:
					_build_presentation_stage(context, origin, presentation_stage)
			section.set_meta("presentation_compact", compact)
	section.set_meta(key, true)
	for required_stage in BUILD_STAGES:
		if compact and required_stage == "edges":
			continue
		if not bool(section.get_meta("built_" + required_stage, false)):
			return
	section.set_meta("cemetery_build_complete", true)

func _create_section(context: ZoneBuildContext, origin: Vector3) -> Node3D:
	var section := Node3D.new()
	section.name = "GreyfenCemeterySection"
	section.position = origin
	section.add_to_group("cemetery_section")
	section.set_meta("ticket", "WORLD-003")
	section.set_meta("authored_route_width", 2.4)
	context.add_node(section)

	_add_marker(section, "CemeteryEntry", Vector3(-4.3, 0, -0.6))
	_add_marker(section, "SisterAnwenCemeteryStage", ANWEN_CEMETERY_STAGE - origin)
	_add_marker(section, "CemeteryEncounterStage", Vector3(0.3, 0, 0.1))
	_add_marker(section, "CrowShrineStage", CROW_SHRINE_VISUAL_STAGE - origin)
	_add_composition_marker(section, "AuthoredCemeteryApproach", Vector3(-3.8, 0, -0.6))
	_add_composition_marker(section, "AuthoredGraveCourt", Vector3(0, 0, -0.2))
	_add_composition_marker(section, "AuthoredCrowChapel", Vector3(3.15, 0, -0.6))

	return section

func _add_compact_presentation_marker(context: ZoneBuildContext, origin: Vector3) -> void:
	var layer := Node3D.new()
	layer.name = "CemeteryAuthoredPresentation"
	layer.position = origin
	layer.set_meta("ticket", "WORLD-014")
	layer.set_meta("compact_opening", true)
	layer.set_meta("detail_deferred", true)
	context.add_node(layer)

func _build_authored_presentation(context: ZoneBuildContext, origin: Vector3) -> void:
	for presentation_stage in PRESENTATION_STAGES:
		_build_presentation_stage(context, origin, presentation_stage)

func _build_presentation_stage(context: ZoneBuildContext, origin: Vector3, stage: String) -> void:
	if stage not in PRESENTATION_STAGES:
		push_error("Unknown cemetery presentation stage: " + stage)
		return
	var section := context.zone_root.find_child("GreyfenCemeterySection", true, false)
	if section == null:
		section = _create_section(context, origin)
	if bool(section.get_meta("built_presentation_" + stage, false)):
		return
	if bool(section.get_meta("presentation_compact", false)):
		var compact_layer := context.zone_root.find_child("CemeteryAuthoredPresentation", true, false)
		if compact_layer != null and bool(compact_layer.get_meta("compact_opening", false)):
			compact_layer.name = "RetiredCompactCemeteryPresentation"
			compact_layer.queue_free()
	section.set_meta("presentation_compact", false)
	var layer := context.zone_root.find_child("CemeteryAuthoredPresentation", true, false) as Node3D
	if layer == null:
		layer = _create_authored_presentation_layer(context, origin)
	match stage:
		"bell": _make_bell_house(layer, context)
		"chapel": _make_chapel_focal_details(layer, context)
		"graves": _make_grave_row_rhythm(layer, context)
		"roost": _make_crow_roost(layer, context)
		"states": _make_cemetery_state_anchors(layer, context)
	section.set_meta("built_presentation_" + stage, true)
	for required_stage in PRESENTATION_STAGES:
		if not bool(section.get_meta("built_presentation_" + required_stage, false)):
			return
	section.set_meta("built_presentation", true)
	for required_stage in BUILD_STAGES:
		if not bool(section.get_meta("built_" + required_stage, false)):
			return
	section.set_meta("cemetery_build_complete", true)

func _create_authored_presentation_layer(context: ZoneBuildContext, origin: Vector3) -> Node3D:
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
	return layer

func _make_bell_house(parent: Node3D, context: ZoneBuildContext) -> void:
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
	var centre := Vector3(3.05, 0, -0.55)
	var window := MeshInstance3D.new()
	window.name = "CrowChapelMemoryWindow"
	window.mesh = _detail_mesh("memory_window")
	# The south wall faces the cemetery approach; the former back-wall window
	# was hidden behind masonry from every established player camera.
	window.position = centre + Vector3(0.25, 1.78, 1.97)
	window.rotation.y = PI * 0.5
	parent.add_child(window)
	for z in [-0.35, 0.0, 0.35]:
		context.make_visual_box("CrowChapelFloorMoss", centre + Vector3(0.1, 0.235, z), Vector3(1.1, 0.018, 0.08), Color(0.07, 0.14, 0.075))


func _make_grave_row_rhythm(parent: Node3D, context: ZoneBuildContext) -> void:
	var row_root := Node3D.new()
	row_root.name = "CemeteryGraveRowRhythm"
	row_root.set_meta("rows", 3)
	row_root.set_meta("purpose", "readable_investigation_framing")
	parent.add_child(row_root)
	var row_mesh := MeshInstance3D.new()
	row_mesh.name = "CemeteryFittedGraveRows"
	row_mesh.mesh = GRAVE_ROWS_MESH
	row_mesh.material_override = context.make_world_material("medieval_brick", Color(0.40, 0.42, 0.39))
	row_root.add_child(row_mesh)
	for row in range(3):
		for column in range(3):
			var marker := Node3D.new()
			marker.name = "CemeteryRowMarker_%d_%d" % [row, column]
			marker.set_meta("batched_visual", true)
			row_root.add_child(marker)
			marker.position = Vector3(-1.25 + float(column) * 0.72, 0.002, -1.3 + float(row))

func _make_crow_roost(parent: Node3D, context: ZoneBuildContext) -> void:
	var roost := Node3D.new()
	roost.name = "CrowShrineRoost"
	roost.set_meta("stateful", true)
	parent.add_child(roost)
	# These silhouettes are far from the camera and static. Keep the authored
	# roost hierarchy, but batch its six low-detail pieces with the environment.
	for index in range(3):
		var branch_pos := origin_from_parent(parent) + Vector3(2.05 + float(index - 1) * 0.42, 1.05, -3.0 + float(index % 2) * 0.12)
		var branch := Node3D.new()
		branch.name = "CrowShrineBranch_%d" % index
		branch.set_meta("batched_visual", true)
		roost.add_child(branch)
		context.make_visual_box("CrowShrineBranchVisual", branch_pos, Vector3(0.09, 1.15, 0.09), Color(0.10, 0.055, 0.025))
		var crow := Node3D.new()
		crow.name = "CrowShrineSilhouette_%d" % index
		crow.set_meta("batched_visual", true)
		roost.add_child(crow)
		context.make_visual_box("CrowShrineSilhouetteVisual", branch_pos + Vector3(0, 0.62, 0), Vector3(0.20, 0.22, 0.30), Color(0.012, 0.014, 0.016))

func origin_from_parent(parent: Node3D) -> Vector3:
	return parent.global_position

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
	var pier_mesh := _make_gate_pier_mesh()
	var pier_material := context.make_world_material("medieval_brick", Color(0.49, 0.50, 0.46))
	for offset in [Vector3(-3.4, 0, -2.15), Vector3(-3.4, 0, 0.95)]:
		context.make_reserved_collision_box("CemeteryGateStonePier", origin + offset + Vector3.UP * 0.68, Vector3(0.46, 1.36, 0.46))
		context.make_reserved_collision_box("CemeteryGateCapStone", origin + offset + Vector3.UP * 1.43, Vector3(0.62, 0.14, 0.62))
		var pier := MeshInstance3D.new()
		pier.name = "CemeteryCarvedGatePier"
		pier.mesh = pier_mesh
		pier.material_override = pier_material
		pier.position = origin + offset
		context.add_node(pier)
	# A broken iron lintel gives the entrance a silhouette without closing the route.
	context.make_visual_box("CemeteryBrokenLintel", origin + Vector3(-3.4, 1.42, -1.55), Vector3(0.12, 0.12, 0.72), Color(0.095, 0.085, 0.072))

func _make_gate_pier_mesh() -> ArrayMesh:
	var rings := [Vector2(0.21, 0.0), Vector2(0.23, 0.12), Vector2(0.19, 1.28), Vector2(0.22, 1.36), Vector2(0.30, 1.39), Vector2(0.29, 1.48), Vector2(0.25, 1.50)]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring_index in range(rings.size() - 1):
		for segment in 8:
			var angle_a := TAU * float(segment) / 8.0
			var angle_b := TAU * float(segment + 1) / 8.0
			var lower: Vector2 = rings[ring_index]
			var upper: Vector2 = rings[ring_index + 1]
			var a := Vector3(cos(angle_a) * lower.x, lower.y, sin(angle_a) * lower.x)
			var b := Vector3(cos(angle_b) * lower.x, lower.y, sin(angle_b) * lower.x)
			var c := Vector3(cos(angle_b) * upper.x, upper.y, sin(angle_b) * upper.x)
			var d := Vector3(cos(angle_a) * upper.x, upper.y, sin(angle_a) * upper.x)
			for point in [a, c, b, a, d, c]:
				surface.set_uv(Vector2(point.x + point.z, point.y))
				surface.add_vertex(point)
	surface.generate_normals()
	return surface.commit() as ArrayMesh


func _build_boundary(context: ZoneBuildContext, origin: Vector3) -> void:
	# The chapel completes the east edge; the west entrance remains entirely open.
	context.make_reserved_collision_box("CemeteryNorthWall", origin + Vector3(0.2, 0.45, -4.05), Vector3(8.0, 0.90, 0.38))
	context.make_reserved_collision_box("CemeterySouthWall", origin + Vector3(0.2, 0.45, 3.15), Vector3(8.0, 0.90, 0.38))
	context.make_reserved_collision_box("CemeteryEastWallNorth", origin + Vector3(4.1, 0.45, -3.15), Vector3(0.38, 0.90, 1.45))
	context.make_reserved_collision_box("CemeteryEastWallSouth", origin + Vector3(4.1, 0.45, 2.25), Vector3(0.38, 0.90, 1.45))
	var walls := Node3D.new()
	walls.name = "CemeteryFittedBoundary"
	context.add_node(walls)
	var source := _detail_mesh("boundary")
	var offsets := {"CemeteryNorthWall": Vector3(0.2, 0.45, -4.05), "CemeterySouthWall": Vector3(0.2, 0.45, 3.15), "CemeteryEastWallNorth": Vector3(4.1, 0.45, -3.15), "CemeteryEastWallSouth": Vector3(4.1, 0.45, 2.25)}
	for index in source.get_surface_count():
		var id := source.surface_get_name(index)
		var collision := context.zone_root.find_child(id + "Collision", true, false) as CollisionShape3D
		if collision == null:
			continue
		# The original prop policy may recover a bank-adjacent wall. Bind its
		# visible surface to that actual shape, not a second placement calculation.
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, source.surface_get_arrays(index))
		mesh.surface_set_material(0, context.make_world_material("medieval_brick", Color(0.53, 0.52, 0.47)))
		var wall := MeshInstance3D.new()
		wall.name = id + "FittedVisual"
		wall.mesh = mesh
		wall.position = context.zone_root.to_local(collision.global_position) - offsets[id]
		wall.set_meta("fitted_collision", id + "Collision")
		walls.add_child(wall)
	var north_collision := context.zone_root.find_child("CemeteryNorthWallCollision", true, false) as CollisionShape3D
	if north_collision != null:
		var north_center := context.zone_root.to_local(north_collision.global_position)
		for x in [-2.5, -0.7, 1.1, 2.9]:
			context.make_visual_box("CemeteryWallMoss", north_center + Vector3(x - 0.2, 0.33, -0.20), Vector3(0.65, 0.08, 0.03), Color(0.07, 0.14, 0.075))


func _build_grave_court(context: ZoneBuildContext, origin: Vector3) -> void:
	# These graves frame, but never cover, the three existing investigation points.
	var headstone_mesh := _make_headstone_mesh()
	var headstone_material := context.make_world_material("medieval_brick", Color(0.48, 0.49, 0.45))
	var graves := [
		[Vector3(-1.8, 0, -2.10), -7.0], [Vector3(0.0, 0, 2.28), 4.0],
		[Vector3(2.2, 0, -2.10), 7.0], [Vector3(-1.8, 0, 1.05), -4.0],
		[Vector3(0.2, 0, -2.55), 5.0], [Vector3(2.0, 0, 1.95), -6.0],
	]
	for grave_index in range(graves.size()):
		var grave = graves[grave_index]
		var grave_pos: Vector3 = origin + grave[0]
		context.make_collision_box("CemeteryHeadstone", grave_pos + Vector3(0, 0.46, 0), Vector3(0.46, 0.92, 0.20))
		var headstone := MeshInstance3D.new()
		headstone.name = "CemeteryBeveledHeadstone_%d" % grave_index
		headstone.mesh = headstone_mesh
		headstone.material_override = headstone_material
		headstone.position = grave_pos
		headstone.rotation_degrees.y = float(grave[1])
		context.add_node(headstone)
	var soil := MeshInstance3D.new()
	soil.name = "CemeteryFittedGraveEarth"
	soil.mesh = _detail_mesh("grave_earth")
	soil.material_override = context.make_world_material("wet_mud", Color(0.43, 0.38, 0.31))
	soil.position = origin
	context.add_node(soil)
	for offset in [Vector3(-2.7, 0, -3.35), Vector3(-2.75, 0, 2.45), Vector3(0.75, 0, 2.65)]:
		context.make_rubble(origin + offset)
	for offset in [Vector3(-0.85, 0, 0.35), Vector3(0.65, 0, 0.65), Vector3(1.25, 0, -2.95)]:
		context.make_visual_box("CemeteryPathStone", origin + offset + Vector3.UP * 0.06, Vector3(0.58, 0.04, 0.38), Color(0.21, 0.215, 0.195))

func _make_headstone_mesh() -> ArrayMesh:
	var outline := PackedVector2Array([
		Vector2(-0.23, 0.0), Vector2(0.23, 0.0),
		Vector2(0.23, 0.68), Vector2(0.16, 0.84),
		Vector2(0.0, 0.92), Vector2(-0.16, 0.84),
		Vector2(-0.23, 0.68),
	])
	var front := -0.09
	var back := 0.09
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(1, outline.size() - 1):
		_add_stone_face(surface, outline[0], outline[index + 1], outline[index], front)
		_add_stone_face(surface, outline[0], outline[index], outline[index + 1], back)
	for index in range(outline.size()):
		var next := (index + 1) % outline.size()
		var a := Vector3(outline[index].x, outline[index].y, front)
		var b := Vector3(outline[next].x, outline[next].y, front)
		var c := Vector3(outline[next].x, outline[next].y, back)
		var d := Vector3(outline[index].x, outline[index].y, back)
		for point in [a, b, c, a, c, d]:
			surface.set_uv(Vector2(point.x + 0.23, point.y))
			surface.add_vertex(point)
	surface.generate_normals()
	return surface.commit() as ArrayMesh

func _add_stone_face(surface: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, depth: float) -> void:
	for point in [a, b, c]:
		surface.set_uv(Vector2(point.x + 0.23, point.y))
		surface.add_vertex(Vector3(point.x, point.y, depth))


func _build_chapel(context: ZoneBuildContext, origin: Vector3) -> void:
	var centre := origin + Vector3(3.05, 0, -0.55)
	context.make_prop_box("RuinedCrowChapelFloor", centre + Vector3(0, 0.11, 0), Vector3(3.0, 0.22, 3.65), Color(0.125, 0.125, 0.112))
	context.make_reserved_collision_box("RuinedCrowChapelBackWall", centre + Vector3(1.38, 1.38, 0), Vector3(0.42, 2.76, 3.65))
	context.make_reserved_collision_box("RuinedCrowChapelNorthWall", centre + Vector3(0, 1.38, -1.66), Vector3(2.75, 2.76, 0.38))
	context.make_reserved_collision_box("RuinedCrowChapelSouthWall", centre + Vector3(0.25, 1.12, 1.66), Vector3(2.25, 2.24, 0.38))
	# Split facade leaves a physical doorway centred on the existing chapel interaction.
	context.make_reserved_collision_box("CrowChapelFacadeNorth", centre + Vector3(-1.38, 1.25, -1.22), Vector3(0.38, 2.50, 0.82))
	context.make_reserved_collision_box("CrowChapelFacadeSouth", centre + Vector3(-1.38, 1.25, 1.22), Vector3(0.38, 2.50, 0.82))
	context.make_reserved_collision_box("CrowChapelDoorLintel", centre + Vector3(-1.38, 2.42, 0), Vector3(0.38, 0.34, 1.62))
	# A fractured roofline reads as a ruin instead of a sealed box.
	context.make_reserved_collision_box("CrowChapelRoofNorth", centre + Vector3(0.35, 3.18, -1.05), Vector3(2.0, 0.24, 1.45))
	context.make_reserved_collision_box("CrowChapelRoofSouth", centre + Vector3(0.72, 2.95, 1.20), Vector3(1.25, 0.22, 1.02))
	var architecture := MeshInstance3D.new()
	architecture.name = "CrowChapelAuthoredArchitecture"
	architecture.mesh = _textured_architecture(CHAPEL_MESH, context)
	architecture.position = centre
	context.add_node(architecture)
	context.make_prop_box("CrowChapelAltar", centre + Vector3(0.72, 0.52, 0), Vector3(0.72, 1.04, 1.18), Color(0.17, 0.17, 0.15))
	context.make_prop_box("OssuarySealedDoor", centre + Vector3(1.14, 0.86, 0), Vector3(0.12, 1.72, 1.12), Color(0.075, 0.065, 0.052))
	context.make_visual_box("OssuaryIronBinding", centre + Vector3(1.06, 0.98, 0), Vector3(0.04, 0.09, 1.24), Color(0.25, 0.19, 0.11))


func _build_bell_and_shrine(context: ZoneBuildContext, origin: Vector3) -> void:
	var bell_root := Node3D.new()
	bell_root.name = "CemeteryBellFrame"
	bell_root.position = origin + Vector3(1.75, 0, 1.08)
	bell_root.add_to_group("cemetery_landmark")
	context.add_node(bell_root)
	context.make_reserved_collision_box("BellPost", origin + Vector3(1.15, 1.18, 1.08), Vector3(0.18, 2.36, 0.18))
	context.make_reserved_collision_box("BellPost", origin + Vector3(2.35, 1.18, 1.08), Vector3(0.18, 2.36, 0.18))
	context.make_reserved_collision_box("BellCrossbeam", origin + Vector3(1.75, 2.25, 1.08), Vector3(1.55, 0.18, 0.22))
	var frame := MeshInstance3D.new()
	frame.name = "CemeteryBellHouseHood"
	frame.mesh = _textured_architecture(BELL_FRAME_MESH, context)
	bell_root.add_child(frame)
	var bell := MeshInstance3D.new()
	bell.name = "CrowCemeteryBell"
	bell.mesh = BELL_MESH
	bell.position = origin + Vector3(1.75, 1.75, 1.08)
	if bool(context.get_story_flag("cemetery_bell_silent", false)):
		bell.rotation.z = -0.20
	bell.set_meta("world_prop_kind", "bell")
	bell.set_meta("world_prop_id", "cemetery_bell")
	bell.set_meta("world_prop_state_key", "cemetery_bell_rung")
	context.add_node(bell)
	# The shrine is readable from the entrance but stays clear of the grave clues.
	context.make_prop_box("CemeteryCrowShrine", CROW_SHRINE_VISUAL_STAGE + Vector3.UP * 0.72, Vector3(0.58, 1.44, 0.38), Color(0.23, 0.235, 0.215))
	context.make_visual_box("CrowShrineMark", CROW_SHRINE_VISUAL_STAGE + Vector3(-0.31, 0.90, 0), Vector3(0.025, 0.42, 0.24), Color(0.045, 0.042, 0.038))
	var shrine_state := str(context.get_story_flag("crow_shrine_state", ""))
	var chapel_color := Color(0.46, 0.60, 0.50)
	if shrine_state == "cleansed":
		# Keep the clean covenant state explicit so saved consequences have a
		# distinct authored presentation instead of relying on the default.
		chapel_color = Color(0.46, 0.60, 0.50)
	elif shrine_state == "disturbed":
		chapel_color = Color(0.62, 0.34, 0.25)
	elif shrine_state == "bound":
		chapel_color = Color(0.30, 0.35, 0.40)
	context.make_light("CemeteryChapelGlow", origin + Vector3(2.55, 2.2, -0.55), chapel_color, 1.15)


func _build_edge_dressing(context: ZoneBuildContext, origin: Vector3) -> void:
	for tree in [
		# Keep the cemetery edge alive without filling the authored sightlines.
		[Vector3(-3.4, 0, -6.25), 0.40, -15.0], [Vector3(0.9, 0, -6.35), 0.44, 12.0],
		[Vector3(-3.2, 0, 6.05), 0.40, 21.0],
	]:
		context.make_loose_role("forest_tree", origin + tree[0], Vector3.ONE * float(tree[1]), float(tree[2]))
	for offset in [Vector3(-2.55, 0, -3.45), Vector3(-1.0, 0, 2.78), Vector3(2.75, 0, 2.82)]:
		context.make_loose_role("forest_rock", origin + offset, Vector3.ONE * 0.55, 0.0)
	_build_cemetery_backdrop(context, origin)
	context.make_fog_sheet(origin + Vector3(0.3, 0.42, -0.35), Vector3(7.5, 0.62, 6.6), Color(0.13, 0.16, 0.145, 0.09))

func _build_cemetery_backdrop(context: ZoneBuildContext, origin: Vector3) -> void:
	var source := context.forest_tree_mesh("res://assets_external/environment/forest/TwistedTree_2.obj")
	if source == null:
		push_error("Cemetery backdrop requires the approved forest tree mesh")
		return
	var bounds := source.get_aabb()
	var bottom_center := bounds.position + Vector3(bounds.size.x * 0.5, 0.0, bounds.size.z * 0.5)
	var positions := [Vector3(9.0, 0, -7.0), Vector3(12.0, 0, -4.0), Vector3(16.0, 0, -6.0), Vector3(14.0, 0, -1.0), Vector3(10.0, 0, 3.0), Vector3(14.0, 0, 6.0), Vector3(11.0, 0, 10.0), Vector3(18.0, 0, 9.0)]
	var count := 5 if context.quality_preset() == "potato" else positions.size()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = source
	multimesh.instance_count = count
	for index in count:
		var height := 6.0 + float(index % 4) * 0.8
		var scale_factor := height / maxf(bounds.size.y, 0.01)
		var basis := Basis(Vector3.UP, float(index) * 1.39).scaled(Vector3.ONE * scale_factor)
		multimesh.set_instance_transform(index, Transform3D(basis, origin + positions[index] - basis * bottom_center))
	var backdrop := MultiMeshInstance3D.new()
	backdrop.name = "CemeteryDistantTreeline"
	backdrop.multimesh = multimesh
	backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	backdrop.visibility_range_end = 68.0
	context.add_node(backdrop)

func _textured_architecture(source: ArrayMesh, context: ZoneBuildContext) -> ArrayMesh:
	var mesh := source.duplicate() as ArrayMesh
	for index in mesh.get_surface_count():
		var group := mesh.surface_get_name(index)
		var surface := "medieval_brick" if group == "masonry" else ("roof_tiles" if group == "roof" else "timber")
		mesh.surface_set_material(index, context.make_world_material(surface, source.surface_get_material(index).albedo_color))
	return mesh

func _detail_mesh(id: String) -> ArrayMesh:
	assert(DETAIL_MESHES.has(id), "Required cemetery detail missing: " + id)
	return DETAIL_MESHES[id]


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
