extends RefCounted

const RiverSection = preload("res://scripts/zones/river_section.gd")
const BridgeSurfaceContract = preload("res://scripts/bridge_surface_contract.gd")
const LandscapePresentation = preload("res://scripts/world_landscape_presentation.gd")

func build(context: ZoneBuildContext) -> void:
	seed(78233)
	var root := Node3D.new()
	root.name = "AuthoredWychwoodSection"
	root.set_meta("ticket", "WORLD-002")
	root.set_meta("main_route_half_width", 2.6)
	context.add_node(root)

	context.make_split_ground(44.0, 34.0, 0.0, 3.4, Color(0.065, 0.105, 0.07), BridgeSurfaceContract.DECK_WIDTH, BridgeSurfaceContract.bridge_length(3.4), BridgeSurfaceContract.APPROACH_LENGTH)
	RiverSection.new().build(context, 0.0, 44.0, 3.4)
	context.make_wychwood_terrain_layers()
	context.make_play_area_bounds(44, 34, Color(0.04, 0.075, 0.045))
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
	_make_canopy_layer(presentation, context, "WychwoodCanopyLower", 2.8, 6 if context.quality_preset() == "potato" else 9 if context.quality_preset() == "balanced" else 12, Color(0.13, 0.22, 0.13))
	_make_canopy_layer(presentation, context, "WychwoodCanopyUpper", 4.4, 4 if context.quality_preset() == "potato" else 7 if context.quality_preset() == "balanced" else 9, Color(0.09, 0.17, 0.11))
	_make_understory_layer(presentation, context)
	_make_forest_floor_layer(presentation, context)
	_make_path_floor_edges(presentation, context)
	_make_path_rock_edges(presentation)
	_make_clue_sightline_markers(presentation, context)
	_make_clearing_frame(presentation, context)

func _make_east_layby(context: ZoneBuildContext) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(12):
		var x0 := 0.7 + float(index) * 0.89
		var x1 := 0.7 + float(index + 1) * 0.89
		var z0 := -8.0 + sin(x0 * 0.48) * 0.33
		var z1 := -8.0 + sin(x1 * 0.48) * 0.33
		var width0 := 1.26 + 0.18 * sin(x0 * 1.13)
		var width1 := 1.26 + 0.18 * sin(x1 * 1.13)
		for side in [-1.0, 1.0]:
			var a := Vector3(x0, 0.061, z0)
			var b := Vector3(x1, 0.061, z1)
			var c := Vector3(x0, 0.061, z0 + side * width0)
			var d := Vector3(x1, 0.061, z1 + side * width1)
			var points := [a, b, c, c, b, d] if side < 0.0 else [a, c, b, c, d, b]
			for point in points:
				surface.set_normal(Vector3.UP)
				surface.set_color(Color(0.81, 0.84, 0.76) if point == c or point == d else Color.WHITE)
				surface.set_uv(Vector2(point.x, point.z) * 0.55)
				surface.add_vertex(point)
	var road := MeshInstance3D.new()
	road.name = "MudRoad"
	road.mesh = surface.commit()
	var material := context.make_world_material("wet_mud", Color(0.43, 0.41, 0.34)).duplicate() as StandardMaterial3D
	material.vertex_color_use_as_albedo = true
	road.material_override = material
	road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	context.add_node(road)

func _make_root_arch(parent: Node3D, context: ZoneBuildContext) -> void:
	var root_material := context.make_world_material("timber", Color(0.64, 0.56, 0.44))
	var tree_mesh := context.forest_tree_mesh("res://assets_external/environment/forest/TwistedTree_2.obj")
	if tree_mesh == null:
		push_error("Required Wychwood threshold tree is missing")
		return
	var bounds := tree_mesh.get_aabb()
	var bottom_center := bounds.position + Vector3(bounds.size.x * 0.5, 0, bounds.size.z * 0.5)
	var arch_z := 10.15
	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		post.name = "WychwoodRootArchPost"
		post.mesh = tree_mesh
		var scale_value := Vector3(1.75, 3.65, 1.55) / bounds.size.max(Vector3.ONE * 0.01)
		var basis := Basis.from_euler(Vector3(0, side * 0.72, side * 0.08)).scaled(scale_value)
		post.transform = Transform3D(basis, Vector3(side * 3.75, 0.035, arch_z) - basis * bottom_center)
		post.visibility_range_begin = 2.8
		post.visibility_range_begin_margin = 0.5
		parent.add_child(post)
	for side in [-1.0, 1.0]:
		_add_root_branch(parent, root_material, "WychwoodRootArchLintel", Vector3(side * 3.25, 2.03, arch_z), Vector3(side * 1.78, 3.02, arch_z - 0.12), 0.15, 0.11)
		_add_root_branch(parent, root_material, "WychwoodRootArchCrown", Vector3(side * 1.78, 3.02, arch_z - 0.12), Vector3(0, 3.32, arch_z - 0.07), 0.11, 0.075)
		_add_root_branch(parent, root_material, "WychwoodRootArchTwig", Vector3(side * 2.25, 2.70, arch_z - 0.07), Vector3(side * 2.78, 3.27, arch_z - 0.40), 0.055, 0.025)

func _add_root_branch(parent: Node3D, material: Material, branch_name: String, start: Vector3, end: Vector3, base_radius: float, tip_radius: float) -> void:
	var branch := MeshInstance3D.new()
	branch.name = branch_name
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = base_radius
	mesh.top_radius = tip_radius
	mesh.height = start.distance_to(end)
	mesh.radial_segments = 7
	branch.mesh = mesh
	branch.position = (start + end) * 0.5
	branch.basis = Basis(Quaternion(Vector3.UP, (end - start).normalized()))
	branch.material_override = material
	branch.visibility_range_begin = 2.8
	branch.visibility_range_begin_margin = 0.5
	parent.add_child(branch)

func _make_canopy_layer(parent: Node3D, context: ZoneBuildContext, node_name: String, height: float, count: int, color: Color) -> void:
	var source := load("res://assets_external/environment/forest/Bush_Common.obj") as ArrayMesh
	if source == null:
		push_error("Wychwood canopy foliage resource is missing")
		return
	var mesh := source.duplicate() as ArrayMesh
	var foliage := context.make_material(color)
	foliage.roughness = 0.95
	for surface_index in range(mesh.get_surface_count()):
		mesh.surface_set_material(surface_index, foliage)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = count
	var batch := MultiMeshInstance3D.new()
	batch.name = node_name
	batch.multimesh = multimesh
	batch.visibility_range_end = 54.0
	parent.add_child(batch)
	for index in range(count):
		var side := -1.0 if index % 2 == 0 else 1.0
		var lane := float(index / 2)
		var x := side * (7.0 + fmod(lane * 2.85, 8.8))
		var z := 11.8 - fmod(lane * 4.35 + float(index % 3) * 0.55, 25.8)
		var scale_factor := 0.95 + float(index % 3) * 0.16
		var yaw := float(index % 5) * 0.22
		var basis := Basis.from_euler(Vector3(0, yaw, 0)).scaled(Vector3(1.18 * scale_factor, 0.95 + float(index % 2) * 0.11, 1.08 * scale_factor))
		multimesh.set_instance_transform(index, Transform3D(basis, Vector3(x, height - 0.75, z)))

func _make_understory_layer(parent: Node3D, context: ZoneBuildContext) -> void:
	var count := 10 if context.quality_preset() == "potato" else 16 if context.quality_preset() == "balanced" else 22
	var source := load("res://assets_external/environment/forest/Bush_Common.obj") as ArrayMesh
	if source == null:
		push_error("Wychwood understory foliage resource is missing")
		return
	var bounds := source.get_aabb()
	var bottom_center := bounds.position + Vector3(bounds.size.x * 0.5, 0, bounds.size.z * 0.5)
	var mesh := source.duplicate() as ArrayMesh
	var foliage := context.make_material(Color(0.16, 0.25, 0.12))
	foliage.roughness = 0.98
	for surface_index in range(mesh.get_surface_count()):
		mesh.surface_set_material(surface_index, foliage)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = count
	var batch := MultiMeshInstance3D.new()
	batch.name = "WychwoodUnderstoryBatch"
	batch.multimesh = multimesh
	batch.visibility_range_end = 32.0
	parent.add_child(batch)
	for index in range(count):
		var side := -1.0 if index % 2 == 0 else 1.0
		var z := 11.0 - fmod(float(index) * 2.7, 23.0) if index < count / 2 else -8.8 + float(index % 5) * 1.45
		var x := side * (3.9 + float(index % 4) * 0.82) if index < count / 2 else side * (5.9 + float(index % 3) * 0.73)
		var scale_factor := 0.72 + float(index % 3) * 0.12
		var target_size := Vector3(0.88 * scale_factor, 0.53 + float(index % 2) * 0.08, 0.82 * scale_factor)
		var normalized_scale := target_size / bounds.size.max(Vector3.ONE * 0.01)
		var basis := Basis.from_euler(Vector3(0, float(index) * 0.37, 0)).scaled(normalized_scale)
		multimesh.set_instance_transform(index, Transform3D(basis, Vector3(x, 0.045, z) - basis * bottom_center))

func _make_forest_floor_layer(parent: Node3D, context: ZoneBuildContext) -> void:
	var count := 12 if context.quality_preset() == "potato" else 20 if context.quality_preset() == "balanced" else 28
	var source := load("res://assets_external/environment/forest/Bush_Common.obj") as ArrayMesh
	if source == null:
		push_error("Wychwood forest-floor foliage resource is missing")
		return
	var bounds := source.get_aabb()
	var bottom_center := bounds.position + Vector3(bounds.size.x * 0.5, 0, bounds.size.z * 0.5)
	var mesh := source.duplicate() as ArrayMesh
	var fallen_leaves := context.make_material(Color(0.18, 0.19, 0.10))
	fallen_leaves.roughness = 1.0
	for surface_index in range(mesh.get_surface_count()):
		mesh.surface_set_material(surface_index, fallen_leaves)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = count
	var batch := MultiMeshInstance3D.new()
	batch.name = "WychwoodForestFloorDetail"
	batch.multimesh = multimesh
	batch.visibility_range_end = 28.0
	parent.add_child(batch)
	for index in range(count):
		var side := -1.0 if index % 2 == 0 else 1.0
		var z := 10.4 - fmod(float(index) * 1.83, 22.0) if index < count / 2 else -9.7 + float(index % 7) * 1.13
		var x := side * (3.15 + float(index % 5) * 0.52) if index < count / 2 else side * (4.8 + float(index % 3) * 0.66)
		var yaw := -0.55 + float(index % 4) * 0.37
		var target_size := Vector3(0.38 + float(index % 3) * 0.07, 0.12, 0.34 + float(index % 2) * 0.05)
		var normalized_scale := target_size / bounds.size.max(Vector3.ONE * 0.01)
		var basis := Basis.from_euler(Vector3(0, yaw, 0)).scaled(normalized_scale)
		multimesh.set_instance_transform(index, Transform3D(basis, Vector3(x, 0.045, z) - basis * bottom_center))

func _make_path_floor_edges(parent: Node3D, context: ZoneBuildContext) -> void:
	var material := context.make_world_material("forest_ground", Color(0.48, 0.53, 0.40))
	for side in [-1.0, 1.0]:
		for bank in [0, 1]:
			var start_z := -13.8 if bank == 0 else 3.4
			var end_z := -3.4 if bank == 0 else 14.2
			var vertices := PackedVector3Array()
			var uvs := PackedVector2Array()
			var indices := PackedInt32Array()
			for patch_index in range(7):
				var z := lerpf(start_z, end_z, float(patch_index) / 6.0)
				z += 0.22 * sin(float(patch_index) * 2.19 + side)
				var x: float = side * (3.85 + 0.45 * sin(float(patch_index) * 1.43 + bank))
				var radius_x := 0.92 + 0.18 * float(patch_index % 3)
				var radius_z := 0.60 + 0.16 * float((patch_index + bank) % 3)
				var center := vertices.size()
				vertices.append(Vector3(x, 0.066, z))
				uvs.append(Vector2(x * 0.28, z * 0.28))
				for point_index in range(10):
					var angle := TAU * float(point_index) / 10.0
					var variation := 0.83 + 0.15 * sin(float(point_index) * 2.37 + float(patch_index))
					var point := Vector3(x + cos(angle) * radius_x * variation, 0.066, z + sin(angle) * radius_z * variation)
					vertices.append(point)
					uvs.append(Vector2(point.x * 0.28, point.z * 0.28))
				for point_index in range(10):
					indices.append_array(PackedInt32Array([center, center + 1 + (point_index + 1) % 10, center + 1 + point_index]))
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = vertices
			arrays[Mesh.ARRAY_TEX_UV] = uvs
			arrays[Mesh.ARRAY_INDEX] = indices
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var edge := MeshInstance3D.new()
			edge.name = "WychwoodPathFloorEdge_%s_%s" % ["West" if side < 0.0 else "East", "North" if bank == 0 else "South"]
			edge.mesh = mesh
			edge.material_override = material
			edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(edge)

func _make_path_rock_edges(parent: Node3D) -> void:
	var rock_path := "res://assets_external/environment/forest/RockPath_Round_Small_1.obj"
	var texture_path := "res://assets_external/environment/forest/PathRocks_Diffuse.png"
	var rock_mesh := load(rock_path) as ArrayMesh
	var rock_texture := load(texture_path) as Texture2D
	if rock_mesh == null or rock_texture == null:
		push_error("Wychwood path rocks are missing an approved mesh or material")
		return
	var bounds := rock_mesh.get_aabb()
	var source_size := bounds.size
	var bottom_center := bounds.position + Vector3(source_size.x * 0.5, 0.0, source_size.z * 0.5)
	var material := StandardMaterial3D.new()
	material.albedo_texture = rock_texture
	material.albedo_color = Color(0.68, 0.72, 0.66)
	material.roughness = 0.98
	var surface := SurfaceTool.new()
	var positions := [12.0, 9.1, 6.2, 3.5, -3.5, -6.1, -9.0, -12.0]
	for side in [-1.0, 1.0]:
		for stone_index in range(positions.size()):
			var z: float = positions[stone_index] + 0.24 * sin(float(stone_index) * 1.71 + side)
			var x: float = side * (3.38 + 0.30 * sin(float(stone_index) * 1.29 + side))
			var target_size := Vector3(0.32 + 0.07 * float(stone_index % 3), 0.10, 0.38 + 0.09 * float((stone_index + 1) % 3))
			var scale_value := Vector3(target_size.x / maxf(source_size.x, 0.01), target_size.y / maxf(source_size.y, 0.01), target_size.z / maxf(source_size.z, 0.01))
			var basis := Basis(Vector3.UP, float(stone_index) * 0.83 + side * 0.41).scaled(scale_value)
			surface.append_from(rock_mesh, 0, Transform3D(basis, Vector3(x, 0.044, z) - basis * bottom_center))
	var batch := MeshInstance3D.new()
	batch.name = "WychwoodPathRockBatch"
	batch.mesh = surface.commit()
	batch.material_override = material
	batch.visibility_range_end = 28.0
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	batch.set_meta("source_pack", "Quaternius Stylized Nature MegaKit CC0")
	parent.add_child(batch)

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

func _make_clearing_frame(parent: Node3D, context: ZoneBuildContext) -> void:
	var arena := Node3D.new()
	arena.name = "WychwoodCombatClearingFrame"
	arena.set_meta("center", Vector3(0, 0, -6.5))
	arena.set_meta("safe_half_extents", Vector2(5.2, 4.2))
	arena.set_meta("enemy_spacing", 2.3)
	parent.add_child(arena)
	var ash_material := context.make_material(Color(0.145, 0.115, 0.085))
	ash_material.roughness = 1.0
	ash_material.emission_enabled = true
	ash_material.emission = Color(0.022, 0.016, 0.010)
	ash_material.emission_energy_multiplier = 0.16
	var rock_mesh := load("res://assets_external/environment/forest/RockPath_Round_Small_1.obj") as ArrayMesh
	var rock_texture := load("res://assets_external/environment/forest/PathRocks_Diffuse.png") as Texture2D
	if rock_mesh == null or rock_texture == null:
		push_error("Wychwood clearing boundary rocks are missing their approved source")
		return
	var rock_bounds := rock_mesh.get_aabb()
	var rock_center := rock_bounds.position + Vector3(rock_bounds.size.x * 0.5, 0, rock_bounds.size.z * 0.5)
	var rock_surface := SurfaceTool.new()
	for index in range(6):
		var angle := TAU * float(index) / 6.0
		var size := Vector3(0.75 + float(index % 2) * 0.17, 0.32 + float(index % 3) * 0.08, 0.62 + float(index % 2) * 0.11)
		var scale_value := size / rock_bounds.size.max(Vector3.ONE * 0.01)
		var basis := Basis(Vector3.UP, angle + float(index) * 0.37).scaled(scale_value)
		var origin := Vector3(cos(angle) * 5.0, 0.065, -6.5 + sin(angle) * 3.7) - basis * rock_center
		rock_surface.append_from(rock_mesh, 0, Transform3D(basis, origin))
	var stones := MeshInstance3D.new()
	stones.name = "WychwoodClearingBoundaryStones"
	stones.mesh = rock_surface.commit()
	var stone_material := StandardMaterial3D.new()
	stone_material.albedo_texture = rock_texture
	stone_material.albedo_color = Color(0.50, 0.55, 0.49)
	stone_material.roughness = 0.98
	stones.material_override = stone_material
	stones.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arena.add_child(stones)
	var stain_data := [
		[Vector3(-2.3, 0.035, -8.1), 1.35, 0.72],
		[Vector3(2.1, 0.035, -7.4), 1.05, 0.85],
		[Vector3(-0.4, 0.035, -4.8), 0.78, 0.50],
	]
	for stain_index in range(stain_data.size()):
		var patch_data: Array = stain_data[stain_index]
		_make_clearing_stain(arena, ash_material, patch_data[0], float(patch_data[1]), float(patch_data[2]), stain_index)
	var landmark := Node3D.new()
	landmark.name = "WychwoodMemoryLandmark"
	landmark.set_meta("purpose", "combat_aftermath_anchor")
	landmark.set_meta("visual_state", "unresolved_memory")
	landmark.position = Vector3(0, 0, -10.8)
	arena.add_child(landmark)
	_make_memory_shrine(landmark, context)
	var witness_tree = context.make_fitted_environment_role("forest_tree", Vector3(0, 0, -10.8), Vector3(3.2, 4.8, 3.0), -9.0, false)
	if witness_tree != null:
		witness_tree.name = "WychwoodMemoryWitnessTree"
		witness_tree.set_meta("purpose", "combat_aftermath_anchor")
		var witness_material := context.make_material(Color(0.075, 0.090, 0.068))
		witness_material.roughness = 0.98
		witness_material.emission_enabled = true
		witness_material.emission = Color(0.020, 0.055, 0.038)
		witness_material.emission_energy_multiplier = 0.28
		_apply_witness_material(witness_tree, witness_material)
	context.make_ritual_stone(Vector3(0, 0, -10.8))

func _make_clearing_stain(parent: Node3D, material: Material, position: Vector3, radius: float, depth_scale: float, stain_index: int) -> void:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var points := 12
	for segment_index in range(points):
		var next := (segment_index + 1) % points
		var angle := TAU * float(segment_index) / float(points)
		var variation := 0.82 + 0.15 * sin(float(segment_index) * 2.17 + radius)
		var point := Vector3(cos(angle) * radius * variation, 0, sin(angle) * radius * depth_scale * variation)
		var next_angle := TAU * float(next) / float(points)
		var next_variation := 0.82 + 0.15 * sin(float(next) * 2.17 + radius)
		var next_point := Vector3(cos(next_angle) * radius * next_variation, 0, sin(next_angle) * radius * depth_scale * next_variation)
		# Clockwise in XZ produces an upward-facing triangle in Godot.
		for vertex in [Vector3.ZERO, next_point, point]:
			vertices.append(vertex)
			uvs.append(Vector2(0.5 + vertex.x / (radius * 2.0), 0.5 + vertex.z / (radius * depth_scale * 2.0)))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var stain := MeshInstance3D.new()
	stain.name = "WychwoodClearingAshStain_%d" % stain_index
	stain.mesh = mesh
	stain.position = position
	stain.material_override = material
	parent.add_child(stain)

func _make_memory_shrine(parent: Node3D, context: ZoneBuildContext) -> void:
	var token_material := context.make_material(Color(0.30, 0.47, 0.39))
	token_material.emission_enabled = true
	token_material.emission = Color(0.08, 0.22, 0.16)
	token_material.emission_energy_multiplier = 0.45
	for data in [[Vector3(-0.58, 1.62, -0.12), -12.0], [Vector3(0.48, 1.92, 0.08), 9.0], [Vector3(0.05, 1.30, 0.16), 0.0]]:
		var token := MeshInstance3D.new()
		token.name = "MemoryShrineWitnessToken"
		var token_mesh := BoxMesh.new()
		token_mesh.size = Vector3(0.11, 0.24, 0.035)
		token.mesh = token_mesh
		token.position = data[0]
		token.rotation_degrees.z = float(data[1])
		token.material_override = token_material
		parent.add_child(token)

func _apply_witness_material(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = material
	for child in node.get_children():
		_apply_witness_material(child, material)

func _build_light_composition(context: ZoneBuildContext) -> void:
	context.make_light("Moon Shaft", Vector3(-2.2, 5.0, -5.5), Color(0.56, 0.64, 0.76), 3.8)
	context.make_light("Trail Threat", Vector3(3.0, 2.9, -6.1), Color(0.77, 0.58, 0.38), 2.0)
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
	_build_distant_forest(context)
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

func _build_distant_forest(context: ZoneBuildContext) -> void:
	var apron_surface := SurfaceTool.new()
	apron_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point in [Vector3(-42, -0.35, -38), Vector3(42, -0.35, -38), Vector3(-42, -0.35, 38), Vector3(42, -0.35, -38), Vector3(42, -0.35, 38), Vector3(-42, -0.35, 38)]:
		apron_surface.set_uv(Vector2(point.x, point.z))
		apron_surface.add_vertex(point)
	apron_surface.generate_normals()
	var apron := MeshInstance3D.new()
	apron.name = "WychwoodDistantForestGround"
	apron.mesh = apron_surface.commit()
	apron.material_override = context.make_world_material("forest_ground", Color(0.38, 0.43, 0.34))
	apron.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	context.add_node(apron)
	LandscapePresentation.build(context, Vector2(42, 38), 1.3, -0.35)
	var count := 16 if context.quality_preset() == "potato" else 32
	var source_paths := ["TwistedTree_2.obj", "CommonTree_5.obj"]
	for source_index in range(source_paths.size()):
		var source := context.forest_tree_mesh("res://assets_external/environment/forest/" + source_paths[source_index])
		if source == null:
			push_error("Wychwood distant forest resource is missing: " + source_paths[source_index])
			return
		var bounds := source.get_aabb()
		var bottom_center := bounds.position + Vector3(bounds.size.x * 0.5, 0, bounds.size.z * 0.5)
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = source
		var species_count := (count + 1 - source_index) / 2
		multimesh.instance_count = species_count
		var batch := MultiMeshInstance3D.new()
		batch.name = "WychwoodDistantForest" if source_index == 0 else "WychwoodDistantForest_%d" % source_index
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		batch.multimesh = multimesh
		context.add_node(batch)
		for local_index in range(species_count):
			var index := local_index * 2 + source_index
			var ring := index % 2
			var angle := TAU * (float(index / 2) + 0.27 + float(ring) * 0.51) / float(count / 2)
			var position := Vector3(cos(angle) * (32.0 + float(ring) * 7.0), -0.35, sin(angle) * (28.0 + float(ring) * 8.0))
			if index % 4 == 0:
				position = Vector3(-19.0 + float(index / 4) * 5.4, -0.35, -19.0 - float(index % 3) * 1.2)
			var height := 8.0 + float(index % 5) * 0.75 + float(ring) * 2.1
			var scale_factor := height / maxf(bounds.size.y, 0.01)
			var basis := Basis.from_euler(Vector3(0, float(index) * 1.73, 0)).scaled(Vector3.ONE * scale_factor)
			multimesh.set_instance_transform(local_index, Transform3D(basis, position - basis * bottom_center))

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
		_make_route_bush(context, bush)
		var bush_marker := Node3D.new()
		bush_marker.name = "WychwoodRouteBushMarker"
		bush_marker.position = bush
		bush_marker.add_to_group("wychwood_route_bush")
		context.add_node(bush_marker)

func _make_route_bush(context: ZoneBuildContext, position: Vector3) -> void:
	var source := load("res://assets_external/environment/forest/Bush_Common.obj") as ArrayMesh
	if source == null:
		push_error("Wychwood route bush foliage resource is missing")
		return
	var bounds := source.get_aabb()
	var bottom_center := bounds.position + Vector3(bounds.size.x * 0.5, 0, bounds.size.z * 0.5)
	var material := context.make_material(Color(0.055, 0.17, 0.072))
	material.roughness = 0.98
	var mesh := source.duplicate() as ArrayMesh
	for surface_index in range(mesh.get_surface_count()):
		mesh.surface_set_material(surface_index, material)
	for index in range(3):
		var leaf_mass := MeshInstance3D.new()
		leaf_mass.name = "WychwoodRouteBushMass"
		leaf_mass.add_to_group("wychwood_route_bush_visual")
		leaf_mass.mesh = mesh
		var target_size := Vector3(0.83 + float(index % 2) * 0.15, 0.62 + float(index % 2) * 0.08, 0.72)
		var normalized_scale := target_size / bounds.size.max(Vector3.ONE * 0.01)
		var basis := Basis(Vector3.UP, deg_to_rad(float(index) * 37.0)).scaled(normalized_scale)
		leaf_mass.transform = Transform3D(basis, position + Vector3(float(index - 1) * 0.42, 0.045, 0.12 * float((index + 1) % 2)) - basis * bottom_center)
		context.add_node(leaf_mass)

func _build_combat_clearing(context: ZoneBuildContext) -> void:
	var marker := Node3D.new()
	marker.name = "AuthoredWychwoodCombatArena"
	marker.set_meta("safe_half_extents", Vector2(5.2, 4.2))
	context.add_node(marker)
	context.make_monster_clearing(Vector3(0, 0, -6.5))
	# Keep the ritual cluster west of the reserved x=10.8 north-arrival route.
	# The former stones at (6.8, -10.2) and (10.0, -9.8) each caught a
	# player-sized capsule returning from the Deep Wood.
	for pos in [Vector3(5.4,0,-8.6), Vector3(8.5,0,-11.6), Vector3(6.6,0,-10.0), Vector3(8.5,0,-8.1)]:
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
	if context.is_quest_active("side_black_dog") and not bool(context.get_story_flag("black_dog_bandit_camp_inspected", false)):
		context.make_clue("bandit_camp", "Inspect bandit camp", Vector3(-12, 0, -12), "side_black_dog", "find_dog", Color(0.30, 0.18, 0.10))
	context.make_clue("bitter_roots", "Collect bitter roots", Vector3(8, 0, -7.8), "side_bitter_roots", "collect_roots", Color(0.46, 0.22, 0.16))
	# Inspecting the bed supplies evidence. Mira's treatment is a separate,
	# explicit conversation choice and must never finish on this interaction.
	context.make_clue("sacrifice_roots", "Study the sacrifice-root bed", Vector3(10, 0, -9.2), "side_bitter_roots", "study_roots", Color(0.38, 0.16, 0.13))
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
	if context.is_quest_active("side_black_dog") and not context.is_objective_done("side_black_dog", "find_dog") and not bool(context.get_story_flag("black_dog_bandits_defeated", false)):
		context.spawn_enemy("bandit", Vector3(-14, 0.8, -14))
		context.spawn_enemy("bandit", Vector3(-12, 0.8, -15))
