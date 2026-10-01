extends RefCounted

const CemeterySection = preload("res://scripts/zones/cemetery_section.gd")
const GreyfenLifeController = preload("res://scripts/greyfen_life_controller.gd")
const RiverSection = preload("res://scripts/zones/river_section.gd")
const BridgeSurfaceContract = preload("res://scripts/bridge_surface_contract.gd")
const GreyfenFrontier = preload("res://scripts/greyfen_frontier.gd")
const NOTICE_BOARD_POSITION := Vector3(4.4, 0.0, 12.1)
const BOOT_VISUAL_BUCKETS := 8
const BOUNDARY_STAGES: Array[String] = ["horizon", "vegetation", "lights", "north_south_fences", "side_fences"]
const VILLAGE_HOUSES := [
	[Vector3(-5, 0, -3), 8.0, "DressedVillageHouse_WestLane"],
	[Vector3(5.6, 0, -1.0), 0.0, "DressedVillageHouse_EastLane"],
	[Vector3(-10, 0, 11), 24.0, "DressedVillageHouse_SpawnFrame"],
	[Vector3(14, 0, -8.4), -42.0, "DressedVillageHouse_ShrineFrame"],
]

func build(context: ZoneBuildContext) -> void:
	seed(41021)
	var opening_fast := context.is_opening_fast()
	var opening_boot := context.is_opening_boot()
	var root := Node3D.new()
	root.name = "AuthoredGreyfenSection"
	root.set_meta("ticket", "WORLD-001")
	root.set_meta("main_route_half_width", 2.8)
	context.add_node(root)

	var authored_core := context.register_authored_gameplay_core()
	if not authored_core:
		context.make_split_ground(42.0, 34.0, 4.5, 3.4, Color(0.16, 0.18, 0.13), BridgeSurfaceContract.DECK_WIDTH, BridgeSurfaceContract.bridge_length(3.4), BridgeSurfaceContract.APPROACH_LENGTH)
	RiverSection.new().build(context, 4.5, 42.0, 3.4, opening_boot)
	if not opening_boot:
		context.make_greyfen_terrain_layers()
	if not authored_core:
		context.make_play_area_bounds(42, 34, Color(0.09, 0.12, 0.08))
		context.make_road(Vector3(0, 0.018, 0), Vector3(4.2, 0.04, 30.0), Color(0.16, 0.13, 0.09))
		context.make_road(Vector3(-5, 0.02, 9), Vector3(14.0, 0.04, 3.0), Color(0.15, 0.12, 0.085))
		context.make_road(Vector3(15.2, 0.022, 0), Vector3(8.8, 0.045, 3.4), Color(0.145, 0.115, 0.078))
	if not opening_boot:
		context.make_greyfen_path_edges()

	if not opening_boot:
		_build_light_composition(context)
	if not opening_boot:
		_build_village_silhouette(context)
		_build_authored_greyfen_details(context)
	# The cemetery is a released investigation route, not optional dressing. Keep
	# its landmarks and collision present in the fast opening composition so a
	# player can follow the quest there before deferred decoration begins.
	if opening_fast:
		CemeterySection.new().build(context, Vector3(14, 0, 8.6), true)
	if not opening_boot:
		context.make_spawn_composition()
	if opening_boot:
		_build_boot_gameplay_content(context)
		return
	_build_gameplay_content(context)
	if not opening_fast:
		_build_boundary_dressing(context)
		_build_landmarks(context)
		context.make_village_dressing()
		context.make_greyfen_first_impression_dressing()
		context.make_quality_greyfen_overhaul()
		context.make_tree_cluster([
			Vector3(-16,0,-12), Vector3(-12.8,0,16.2), Vector3(16,0,-11),
			Vector3(15,0,13), Vector3(0,0,15),
		])
		context.make_narrative_aftermath()

func build_detail_stage(context: ZoneBuildContext, stage: String) -> void:
	if stage.begins_with("gameplay_visual_"):
		_reveal_gameplay_visual_bucket(context, int(stage.trim_prefix("gameplay_visual_")))
		return
	if stage.begins_with("gameplay_place_"):
		_build_gameplay_place(context, int(stage.trim_prefix("gameplay_place_")))
		return
	if stage.begins_with("village_house_"):
		_build_village_house(context, int(stage.trim_prefix("village_house_")))
		return
	if stage.begins_with("gameplay_crowd_"):
		var life = context.zone_root.find_child("GreyfenLifeController", true, false)
		life.build_population_member(int(stage.trim_prefix("gameplay_crowd_")))
		return
	if stage.begins_with("village_architectural_details_"):
		_build_authored_greyfen_details(context, int(stage.trim_prefix("village_architectural_details_")))
		return
	# Opening prewarm publishes the playable road, actors, gates, and compact
	# landmark layer first. Deferred stages add noncritical village dressing in
	# bounded chunks so WebGL never compiles the whole zone in one frame.
	seed(41021)
	if stage.begins_with("boundary_"):
		_build_boundary_stage(context, stage.trim_prefix("boundary_"))
		return
	if stage.begins_with("landmark_cemetery_"):
		CemeterySection.new().build_stage(context, Vector3(14, 0, 8.6), stage.trim_prefix("landmark_cemetery_"))
		return
	if stage.begins_with("village_first_impression_"):
		context.make_greyfen_first_impression_dressing(stage.trim_prefix("village_first_impression_"))
		return
	match stage:
		"gameplay_base", "gameplay_places", "gameplay_side_clues", "gameplay_main_clues", "gameplay_gates", "gameplay_story":
			_build_gameplay_content(context, true, stage)
		"gameplay_gate_links":
			_activate_boot_gates(context)
		"gameplay_gate_visual":
			context.make_wychwood_gate_scene(Vector3(0, 0, -14.3))
		"gameplay_route_markers":
			context.make_route_markers()
		"opening_river_visual":
			var river := context.zone_root.find_child("LivingRiverSection", true, false) as Node3D
			if river != null:
				RiverSection.new().hydrate_visuals(river, 4.5, 42.0, 3.4)
		"opening_terrain":
			if not bool(context.zone_root.get_meta("opening_terrain_ready", false)):
				context.make_greyfen_terrain_layers()
				context.make_greyfen_path_edges()
				context.zone_root.set_meta("opening_terrain_ready", true)
		"opening_lighting":
			if not bool(context.zone_root.get_meta("opening_lighting_ready", false)):
				_build_light_composition(context)
				context.zone_root.set_meta("opening_lighting_ready", true)
		"opening_spawn":
			context.make_spawn_composition()
		"gameplay_population":
			var existing_life = context.zone_root.find_child("GreyfenLifeController", true, false)
			if existing_life == null:
				_build_population(context, true)
			else:
				context.configure_zone_controller(existing_life)
		"gameplay_common_table", "gameplay_barrel_board":
			_build_board_game(context, stage.trim_prefix("gameplay_"))
		"gameplay_mira", "gameplay_rook", "gameplay_widow_elna", "gameplay_blacksmith_tor", "gameplay_farmer_toma":
			_build_named_actor(context, stage.trim_prefix("gameplay_"))
		"boundary":
			_build_boundary_dressing(context)
		"village_architecture":
			if not context.zone_root.get_meta("greyfen_architecture_complete", false):
				_build_village_silhouette(context)
		"village_architectural_details":
			if context.zone_root.find_child("GreyfenAuthoredDetailLayer", true, false) == null:
				_build_authored_greyfen_details(context)
		"landmark_board":
			context.make_notice_board(NOTICE_BOARD_POSITION)
		"landmark_shrine":
			context.make_shrine_scene(Vector3(6.0, 0, -7.0))
		"landmark_blacksmith":
			context.make_blacksmith_scene(Vector3(10.5, 0, -1.2))
		"landmark_cemetery":
			if context.zone_root.find_child("GreyfenCemeterySection", true, false) == null:
				CemeterySection.new().build(context, Vector3(14, 0, 8.6))
		"landmark_cart_road":
			context.make_cart(Vector3(-6.2, 0, 9.0), false)
			_build_castle_road(context)
		"village_dressing":
			context.make_village_dressing()
		"village_first_impression":
			context.make_greyfen_first_impression_dressing()
		"village_quality":
			context.make_quality_greyfen_overhaul()
		"trees":
			context.make_tree_cluster([
				Vector3(-16,0,-12), Vector3(-12.8,0,16.2), Vector3(16,0,-11),
				Vector3(15,0,13), Vector3(0,0,15),
			])
		"aftermath":
			context.make_narrative_aftermath()

func _reveal_gameplay_visual_bucket(context: ZoneBuildContext, bucket: int) -> void:
	var root := context.zone_root
	if not root.has_meta("opening_visual_index"):
		var indexed := {}
		for child in root.find_children("*", "", true, false):
			if child is Node3D:
				var assigned_bucket := int(child.get_meta("opening_visual_bucket", -1))
				if assigned_bucket >= 0:
					if not indexed.has(assigned_bucket):
						indexed[assigned_bucket] = []
					indexed[assigned_bucket].append(child)
		root.set_meta("opening_visual_index", indexed)
	var visual_index: Dictionary = root.get_meta("opening_visual_index")
	for child in visual_index.get(bucket, []):
		if is_instance_valid(child):
			child.remove_meta("opening_visual_bucket")
			child.visible = true
	visual_index.erase(bucket)
	if bucket == 15:
		root.remove_meta("opening_visual_index")

func _build_light_composition(context: ZoneBuildContext) -> void:
	context.make_light("Village Warmth", Vector3(-1.5, 5.2, 2), Color(1.0, 0.58, 0.30), 3.0)
	context.make_light("Blue Dusk Fill", Vector3(9, 6, -10), Color(0.34, 0.42, 0.58), 2.8)
	var shrine_state := str(context.get_story_flag("crow_shrine_state", ""))
	var shrine_color := Color(0.70, 0.86, 0.60)
	var shrine_energy := 3.0
	if shrine_state == "disturbed":
		shrine_color = Color(0.72, 0.40, 0.28)
		shrine_energy = 2.4
	elif shrine_state == "bound":
		shrine_color = Color(0.34, 0.38, 0.42)
		shrine_energy = 1.55
	context.make_light("Shrine Beacon", Vector3(4.8, 4.8, -5.4), shrine_color, shrine_energy)
	context.make_light("Wychwood Gate Lantern", Vector3(0, 3.2, -14.3), Color(1.0, 0.48, 0.16), 2.2)
	context.make_fog_sheet(Vector3(0, 1.1, -12), Vector3(18, 1, 5), Color(0.18, 0.22, 0.22, 0.12))

func _build_village_silhouette(context: ZoneBuildContext) -> void:
	for index in VILLAGE_HOUSES.size():
		_build_village_house(context, index)

func _build_village_house(context: ZoneBuildContext, index: int) -> void:
	if index < 0 or index >= VILLAGE_HOUSES.size():
		push_error("Invalid Greyfen house stage: %d" % index)
		return
	var key := "greyfen_house_%d_complete" % index
	if bool(context.zone_root.get_meta(key, false)):
		return
	var house: Array = VILLAGE_HOUSES[index]
	context.make_village_house_dressed(house[0], house[1], house[2])
	context.zone_root.set_meta(key, true)
	for house_index in VILLAGE_HOUSES.size():
		if not bool(context.zone_root.get_meta("greyfen_house_%d_complete" % house_index, false)):
			return
	context.zone_root.set_meta("greyfen_architecture_complete", true)

func _build_boundary_dressing(context: ZoneBuildContext) -> void:
	for stage in BOUNDARY_STAGES:
		_build_boundary_stage(context, stage)

func _build_boundary_stage(context: ZoneBuildContext, stage: String) -> void:
	if stage not in BOUNDARY_STAGES:
		push_error("Invalid Greyfen boundary stage: " + stage)
		return
	var key := "greyfen_boundary_" + stage
	if context.zone_root.get_meta(key, false):
		return
	match stage:
		"horizon":
			_build_horizon_ridges(context)
			_build_horizon_forest(context)
		"vegetation":
			# Keep the random-consuming tree calls together in their original order.
			context.make_tree_wall(20.0, 15.2, 7, true)
			context.make_tree_wall(20.0, -15.2, 7, true)
			for tree in [
				[Vector3(-16.2, 0, -10.8), 1.10, -18.0], [Vector3(-14.8, 0, -7.2), 0.92, 21.0],
				[Vector3(15.8, 0, -10.7), 1.04, 12.0], [Vector3(16.5, 0, -6.4), 0.88, -26.0],
				[Vector3(-16.0, 0, 11.6), 1.00, 8.0],
			]:
				context.make_loose_role("forest_tree", tree[0], Vector3.ONE * float(tree[1]), float(tree[2]))
		"lights":
			for pos in [Vector3(-5.3, 0, 3.4), Vector3(4.8, 0, -5.3), Vector3(-9.3, 0, 11.2)]:
				context.make_torch(pos)
		"north_south_fences":
			for x in [-17, -13, -9, -5, 5, 9, 13, 17]:
				context.make_fence(Vector3(x, 0.35, 14), false)
				context.make_fence(Vector3(x, 0.35, -14), false)
		"side_fences":
			for z in [-10, -6, -2, 2, 6, 10]:
				context.make_fence(Vector3(-19, 0.35, z), true)
				if absf(float(z)) > 2.5:
					context.make_fence(Vector3(19, 0.35, z), true)
	context.zone_root.set_meta(key, true)
	for required in BOUNDARY_STAGES:
		if not context.zone_root.get_meta("greyfen_boundary_" + required, false):
			return
	context.zone_root.set_meta("greyfen_boundary_complete", true)

func _build_horizon_ridges(context: ZoneBuildContext) -> void:
	GreyfenFrontier.build(context)

func _build_horizon_forest(context: ZoneBuildContext) -> void:
	if context.zone_root.find_child("GreyfenHorizonForest", true, false) != null:
		return
	var source := context.forest_tree_mesh("res://assets_external/environment/forest/TwistedTree_2.obj")
	if source == null or source.get_surface_count() != 2:
		push_error("Greyfen horizon requires the approved bark/leaf tree mesh")
		return
	var layer := Node3D.new()
	layer.name = "GreyfenHorizonForest"
	context.add_node(layer)
	var count := 24 if context.quality_preset() == "potato" else 40
	var positions: Array[Vector3] = GreyfenFrontier.tree_positions(count)
	var bounds := source.get_aabb()
	var bottom_center := bounds.position + Vector3(bounds.size.x * 0.5, 0.0, bounds.size.z * 0.5)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = source
	multimesh.instance_count = positions.size()
	var batch := MultiMeshInstance3D.new()
	batch.name = "GreyfenDistantTreeBatch"
	batch.multimesh = multimesh
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	batch.visibility_range_end = 72.0
	layer.add_child(batch)
	for index in positions.size():
		var height := 8.8 + float(index % 5) * 0.62
		var scale_factor := height / maxf(bounds.size.y, 0.01)
		var basis := Basis(Vector3.UP, float(index) * 1.71).scaled(Vector3.ONE * scale_factor)
		multimesh.set_instance_transform(index, Transform3D(basis, positions[index] - basis * bottom_center))

func _add_horizon_ridge(parent: Node3D, node_name: String, position: Vector3, width: float, height: float, color: Color, yaw: float) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var segments := 18
	var orientation := Basis(Vector3.UP, yaw)
	# Every side uses the same radial bands and world-space height function.
	# Adjacent corners match exactly, outside all existing playable bounds.
	for row in range(3):
		for index in range(segments + 1):
			var x := -width * 0.5 + width * float(index) / float(segments)
			var world: Vector3 = (Vector3(position.x, 0.0, position.z) + orientation * Vector3(x, 0.0, 0.0)) * [1.0, 1.25, 1.6][row]
			var shoulder := 0.36 + sin(world.x * 0.23 + world.z * 0.17) * 0.14 + cos(world.x * 0.49 - world.z * 0.31) * 0.095
			world.y = 0.0 if row == 0 else height * shoulder * (0.62 if row == 1 else 1.0)
			vertices.append(orientation.inverse() * (world - Vector3(position.x, 0.0, position.z)))
			colors.append(color.lightened(0.035 * float(row) + 0.045 * sin(world.x * 0.4 - world.z * 0.27)))
			normals.append(Vector3.UP)
	for row in range(2):
		for index in range(segments):
			var base := row * (segments + 1) + index
			var next := base + segments + 1
			indices.append_array(PackedInt32Array([base, next, base + 1, base + 1, next, next + 1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var surface := SurfaceTool.new()
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	surface.create_from(mesh, 0)
	surface.generate_normals()
	mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	var ridge := MeshInstance3D.new()
	ridge.name = node_name
	ridge.mesh = mesh
	ridge.material_override = material
	ridge.position = position
	ridge.rotation.y = yaw
	ridge.set_meta("world_visual_role", "horizon_ridge")
	parent.add_child(ridge)

func _build_landmarks(context: ZoneBuildContext) -> void:
	context.make_notice_board(NOTICE_BOARD_POSITION)
	context.make_shrine_scene(Vector3(6.0, 0, -7.0))
	context.make_blacksmith_scene(Vector3(10.5, 0, -1.2))
	CemeterySection.new().build(context, Vector3(14, 0, 8.6))
	context.make_cart(Vector3(-6.2, 0, 9.0), false)
	_build_castle_road(context)

func _build_authored_greyfen_details(context: ZoneBuildContext, segment: int = -1) -> void:
	var layer := context.zone_root.find_child("GreyfenAuthoredDetailLayer", true, false) as Node3D
	if layer == null:
		layer = Node3D.new()
		layer.name = "GreyfenAuthoredDetailLayer"
		layer.set_meta("ticket", "WORLD-012")
		context.add_node(layer)
	if segment >= 0 and bool(layer.get_meta("segment_%d_complete" % segment, false)):
		return

	# Structural details give each quarter a function without narrowing the
	# reserved player lanes or adding new gameplay interactions.
	if segment in [-1, 0]:
		var frontages := MeshInstance3D.new()
		frontages.name = "GreyfenAuthoredFrontages"
		frontages.mesh = load("res://assets_external/environment/village/GreyfenFrontages_Authored.res") as ArrayMesh
		if frontages.mesh == null:
			push_error("Greyfen requires its fitted street and work-area surface")
			frontages.free()
			return
		frontages.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		layer.add_child(frontages)
		for detail in [
		["GreyfenWestDrainStone", Vector3(-5.0, 0.09, -4.90), Vector3(3.0, 0.18, 0.22), Color(0.31, 0.30, 0.27)],
		["GreyfenEastDrainStone", Vector3(7.0, 0.09, 2.95), Vector3(2.8, 0.18, 0.22), Color(0.29, 0.29, 0.27)],
		["GreyfenSpawnDrain", Vector3(-10.0, 0.09, 9.85), Vector3(2.8, 0.18, 0.22), Color(0.32, 0.30, 0.26)],
		["GreyfenShrineStep", Vector3(6.0, 0.10, -8.25), Vector3(2.55, 0.20, 0.46), Color(0.34, 0.33, 0.29)],
		["GreyfenForgeStep", Vector3(10.5, 0.10, -2.65), Vector3(2.3, 0.20, 0.42), Color(0.29, 0.28, 0.25)],
		]:
			context.make_prop_box(str(detail[0]), detail[1], detail[2], detail[3])
			_mark_detail(layer, str(detail[0]))

	# A fitted stone arch frames the altar without walling off Anwen's approach.
	if segment in [-1, 1]:
		var shrine_arch: Node3D = context.make_fitted_environment_role("castle_arch", Vector3(6.0, 0.0, -7.75), Vector3(2.70, 2.22, 0.24), 0.0, false)
		if shrine_arch != null:
			shrine_arch.name = "GreyfenShrineStoneArch"
			if shrine_arch is MeshInstance3D:
				(shrine_arch as MeshInstance3D).material_override = context.make_world_material("medieval_brick", Color(0.72, 0.75, 0.70))
		_mark_detail(layer, "GreyfenShrineArchDetail")
	# The planted back edge frames the oathstone without narrowing the approach
	# from Anwen or adding a collider beside the Castle road.
	if segment in [-1, 2]:
		for planting in [
		["GreyfenShrineGardenWest", Vector3(4.15, 0.0, -9.35), 1.05, -18.0],
		["GreyfenShrineGardenEast", Vector3(8.35, 0.0, -9.55), 1.20, 24.0],
		["GreyfenShrineGardenFar", Vector3(9.65, 0.0, -10.55), 0.85, -30.0],
		]:
			var bush: Node3D = context.make_loose_role("forest_bush", planting[1], Vector3.ONE * float(planting[2]), float(planting[3]))
			if bush != null:
				bush.name = str(planting[0])
		context.make_prop_box("GreyfenForgeRack", Vector3(8.7, 0.78, -1.35), Vector3(0.16, 1.40, 1.45), Color(0.29, 0.29, 0.26))
		_mark_detail(layer, "GreyfenForgeRack")

	# River stones frame the water while leaving the bridge centre and both
	# bridge approaches clear for the spatial service.
	if segment in [-1, 3]:
		for detail in [
		["GreyfenRiverShoreStone", Vector3(-7.4, 0.18, 2.62), Vector3(0.72, 0.36, 0.50)],
		["GreyfenRiverShoreStone", Vector3(7.5, 0.18, 2.70), Vector3(0.62, 0.32, 0.44)],
		["GreyfenRiverShoreStone", Vector3(-7.0, 0.18, 6.28), Vector3(0.65, 0.34, 0.46)],
		["GreyfenRiverShoreStone", Vector3(7.2, 0.18, 6.36), Vector3(0.75, 0.38, 0.52)],
		]:
			context.make_prop_box(str(detail[0]), detail[1], detail[2], Color(0.27, 0.29, 0.27))

	# The existing Quaternius stall cart replaces the three proxy boxes at the
	# entrance without changing interaction or schedule ownership.
	if segment in [-1, 4]:
		var market_stall: Node3D = context.make_fitted_environment_role("cart", Vector3(-6.9, 0.0, 8.45), Vector3(2.0, 1.6, 0.9), 0.0, false)
		if market_stall != null:
			market_stall.name = "GreyfenMarketStall"
		_mark_detail(layer, "GreyfenMarketStallDetail")
	if segment >= 0:
		layer.set_meta("segment_%d_complete" % segment, true)

func _mark_detail(layer: Node3D, detail_id: String) -> void:
	var marker := Node3D.new()
	marker.name = detail_id
	layer.add_child(marker)

func _build_castle_road(context: ZoneBuildContext) -> void:
	var marker := Node3D.new()
	marker.name = "GreyfenCastleRoad"
	marker.position = Vector3(15.2, 0, 0)
	marker.add_to_group("castle_gateway_corridor")
	context.add_node(marker)
	for z in [-2.25, 2.25]:
		context.make_prop_box("CastleRoadWaystone", Vector3(17.9, 0.72, z), Vector3(0.62, 1.44, 0.62), Color(0.22, 0.22, 0.205))
		context.make_visual_box("VarganWaymark", Vector3(17.55, 0.88, z), Vector3(0.035, 0.34, 0.22), Color(0.42, 0.32, 0.16))
	context.make_visual_box("CastleRoadRuts", Vector3(15.0, 0.052, -0.72), Vector3(5.8, 0.025, 0.18), Color(0.065, 0.045, 0.030))
	context.make_visual_box("CastleRoadRuts", Vector3(15.0, 0.052, 0.72), Vector3(5.8, 0.025, 0.18), Color(0.065, 0.045, 0.030))

func _build_boot_gameplay_content(context: ZoneBuildContext) -> void:
	# The boot profile is deliberately small: it is the scene shown while the
	# menu-covered prewarm finishes. Keep the first objective and all legal exits
	# available, then hydrate the full village on the first settled gameplay
	# frames. These gate markers are removed before the full gameplay stage so
	# the player never receives duplicate focus targets.
	var anwen_position := context.authored_anchor_position("AnwenAnchor", Vector3(2.0, 0, -5.0))
	var anwen = context.make_named_interactable("sister_anwen", "dialogue", "Talk to Sister Anwen", anwen_position, Color(0.34, 0.35, 0.48))
	_defer_boot_interactable_visual(anwen, 0)
	var boot_gates := [
		["To Wychwood", context.authored_anchor_position("WychwoodGateAnchor", Vector3(0, 0, -15.2)), "wychwood", Vector3(0, 1, 13)],
		["The long road", context.authored_anchor_position("DeepWoodGateAnchor", Vector3(-18, 0, -10)), "deep_wood", Vector3(0, 1, 12)],
		["Road to Castle Vargan", context.authored_anchor_position("CastleGateAnchor", Vector3(17.5, 0, 0)), "vargan_approach", Vector3(0, 1, 14)],
	]
	for entry in boot_gates:
		var gate = context.make_zone_gate(entry[0], entry[1], entry[2], entry[3])
		if gate != null:
			gate.set_meta("opening_boot_gate", true)
			# The Area3D remains live for route/focus correctness. Rendering three
			# animated portals during menu prewarm only spends the first WebGL frame
			# on visuals that the gameplay stage replaces immediately after control.
			_defer_boot_interactable_visual(gate, -1)
			if str(entry[2]) == "vargan_approach":
				gate.rotation_degrees.y = 90.0

func _defer_boot_interactable_visual(interactable: Node3D, reveal_bucket: int) -> void:
	if interactable == null:
		return
	interactable.set_meta("opening_boot_visual_deferred", true)
	var visual_index := 0
	for descendant in interactable.find_children("*", "", true, false):
		if not (descendant is MeshInstance3D or descendant is GPUParticles3D):
			continue
		var visual := descendant as Node3D
		if not visual.visible:
			continue
		visual.visible = false
		if reveal_bucket >= 0:
			visual.set_meta("opening_visual_bucket", (reveal_bucket + visual_index) % BOOT_VISUAL_BUCKETS)
		visual_index += 1
	interactable.set_meta("opening_boot_visual_count", visual_index)

func _remove_boot_gates(context: ZoneBuildContext) -> void:
	if context.zone_root == null:
		return
	for child in context.zone_root.get_children().duplicate():
		if child is Area3D and bool(child.get_meta("opening_boot_gate", false)):
			child.free()

func _activate_boot_gates(context: ZoneBuildContext) -> void:
	for target in ["wychwood", "deep_wood", "vargan_approach"]:
		var gate := context.zone_root.find_child("gate_%s" % target, true, false) as Area3D
		if gate == null or not bool(gate.get_meta("opening_boot_gate", false)):
			push_error("Greyfen prewarmed gate missing at hydration: " + target)
			return
		gate.remove_meta("opening_boot_gate")
		gate.remove_meta("opening_boot_visual_deferred")
		if target == "vargan_approach":
			gate.set_meta("always_accessible", true)

func _build_gameplay_content(context: ZoneBuildContext, defer_population := false, phase := "") -> void:
	if phase == "":
		_remove_boot_gates(context)
		for part in ["gameplay_base", "gameplay_places", "gameplay_side_clues", "gameplay_main_clues", "gameplay_gates", "gameplay_story"]:
			_build_gameplay_content(context, defer_population, part)
		if not defer_population:
			_build_population(context)
		return
	match phase:
		"gameplay_base":
			_build_gameplay_base(context)
			if not defer_population:
				for actor_id in ["mira", "rook", "widow_elna", "blacksmith_tor", "farmer_toma"]:
					_build_named_actor(context, actor_id)
		"gameplay_places":
			_build_gameplay_places(context)
			if not defer_population:
				_build_board_game(context, "common_table")
				_build_board_game(context, "barrel_board")
		"gameplay_side_clues":
			_build_gameplay_side_clues(context)
		"gameplay_main_clues":
			_build_gameplay_main_clues(context)
		"gameplay_gates":
			_remove_boot_gates(context)
			_build_gameplay_gates(context)
		"gameplay_story":
			context.make_greyfen_story_beats()

func _build_gameplay_base(context: ZoneBuildContext) -> void:
	var road_ready := context.road_ready_to_report()
	var board_prompt := "Post the road evidence publicly" if road_ready else "Read notice board"
	context.make_named_interactable("notice_board", "dialogue", board_prompt, NOTICE_BOARD_POSITION, Color(0.48, 0.28, 0.12), Vector3(0.45, 0.45, 0.45))
	var anwen_at_cemetery := context.is_quest_active("main_bell_beneath_greyfen")
	# Keep the opening speaker on the cleared shrine approach.
	var anwen_position := CemeterySection.ANWEN_CEMETERY_STAGE if anwen_at_cemetery else context.authored_anchor_position("AnwenAnchor", Vector3(2.0, 0, -5.0))
	var anwen_prompt := "Meet Sister Anwen at the cemetery gate" if anwen_at_cemetery else ("Report the road evidence privately" if road_ready else "Talk to Sister Anwen")
	if context.zone_root.find_child("sister_anwen", true, false) == null:
		context.make_named_interactable("sister_anwen", "dialogue", anwen_prompt, anwen_position, Color(0.34, 0.35, 0.48))
	context.make_named_interactable("side_contracts", "dialogue", "Read village requests", NOTICE_BOARD_POSITION + Vector3(0.65, 0, 0), Color(0.42,0.27,0.14), Vector3(0.4,0.4,0.4))
	if context.is_quest_active("main_names_they_burned") and not context.is_objective_done("main_names_they_burned", "names_choice"):
		context.make_named_interactable("names_decision", "dialogue", "Decide the fate of the names", Vector3(4.4,0,-5.0), Color(0.36,0.32,0.25), Vector3(0.45,0.45,0.45))
	var names_policy := str(context.get_story_flag("names_policy", ""))
	if names_policy == "published":
		context.make_visual_box("PublishedRefugeeNames", Vector3(4.4, 1.28, -5.18), Vector3(1.8, 1.05, 0.06), Color(0.48, 0.38, 0.22))
	elif names_policy == "withheld":
		context.make_visual_box("WithheldRefugeeRegister", Vector3(4.4, 1.10, -5.18), Vector3(0.72, 0.18, 0.34), Color(0.18, 0.12, 0.08))
	if context.crow_shrine_choice_ready() and context.zone_root.find_child("crow_shrine_choice", true, false) == null:
		context.make_named_interactable("crow_shrine_choice", "dialogue", "Choose the Crow Shrine's fate", CemeterySection.CROW_SHRINE_INTERACTION_STAGE, Color(0.3,0.38,0.3), Vector3(0.45,0.45,0.45))
	if road_ready:
		context.make_named_interactable("retain_evidence", "dialogue", "Keep Oren's token", Vector3(1.8,0,8.8), Color(0.38,0.24,0.16), Vector3(0.35,0.35,0.35))

func _build_gameplay_places(context: ZoneBuildContext) -> void:
	for place_index in range(5):
		_build_gameplay_place(context, place_index)

func _build_gameplay_place(context: ZoneBuildContext, place_index: int) -> void:
	var place_ids := ["village_well", "forge_corner", "tor_forge", "mira_apothecary", "shrine_prayer"]
	if place_index >= 0 and place_index < place_ids.size() \
			and context.zone_root.find_child(place_ids[place_index], true, false) != null:
		return
	match place_index:
		0:
			context.make_village_place("village_well", "village_place", "Draw from the village well", Vector3(-8.0,0,-0.5), Vector3(2.2,0.9,2.2), Color(0.19,0.18,0.16))
		1:
			context.make_village_place("forge_corner", "village_place", "Inspect Tor's old iron", Vector3(11.0,0,-1.2), Vector3(1.5,0.7,1.2), Color(0.28,0.18,0.10))
		2:
			context.make_village_place("tor_forge", "vendor", "Buy arrows and gear from Tor", Vector3(10.2,0,-0.3), Vector3(1.8,0.78,1.35), Color(0.34,0.20,0.10))
		3:
			context.make_village_place("mira_apothecary", "vendor", "Buy remedies from Mira", Vector3(-5.4,0,-1.2), Vector3(1.75,0.78,1.25), Color(0.20,0.34,0.24))
		4:
			context.make_village_place("shrine_prayer", "village_place", "Sit at the shrine bench", Vector3(8.0,0,-6.2), Vector3(2.4,0.55,0.7), Color(0.22,0.15,0.09))

func _build_gameplay_side_clues(context: ZoneBuildContext) -> void:
	if context.is_quest_active("side_widows_bell") and not context.is_objective_done("side_widows_bell", "find_bell"):
		context.make_clue("grave_bell", "Inspect Harl's grave bell", Vector3(15.8, 0, 9.5), "side_widows_bell", "find_bell", Color(0.60, 0.55, 0.44))
	if context.is_quest_active("side_iron_remembers") and not context.is_objective_done("side_iron_remembers", "recover_iron"):
		context.make_clue("massacre_iron", "Recover blackened chapel iron", Vector3(15.4, 0, 8.5), "side_iron_remembers", "recover_iron", Color(0.26, 0.24, 0.20))
	if context.is_quest_active("side_empty_grave") and not context.is_objective_done("side_empty_grave", "follow_empty_grave"):
		context.make_clue("empty_grave_tracks", "Follow prints from the empty grave", Vector3(16.0, 0, 6.7), "side_empty_grave", "follow_empty_grave", Color(0.25, 0.24, 0.22))
	publish_returned_soldier(context)
	publish_oren_charm_return(context)
	publish_memorial_candles(context)
	if str(context.get_story_flag("widow_truth", "")) == "told":
		context.make_visual_box("HarlBellCutCord", Vector3(15.8, 0.8, 9.5), Vector3(0.05, 0.7, 0.05), Color(0.18, 0.12, 0.07))
	if str(context.get_story_flag("iron_fate", "")) == "memorial":
		context.make_visual_box("ForgeNameMemorial", Vector3(10.4, 1.0, -1.2), Vector3(1.6, 1.7, 0.14), Color(0.30, 0.25, 0.18))
	if str(context.get_story_flag("mira_truth", "")) == "confessed":
		context.make_visual_box("MiraTruthLabels", Vector3(-6.3, 0.8, -2.0), Vector3(1.4, 0.08, 0.6), Color(0.42, 0.38, 0.25))
	if str(context.get_story_flag("returned_soldier_fate", "")) == "named":
		context.make_visual_box("ReturnedSoldierNamedStone", Vector3(16.0, 0.65, 6.7), Vector3(0.55, 1.3, 0.20), Color(0.25, 0.25, 0.24))

func publish_returned_soldier(context: ZoneBuildContext) -> void:
	if not context.is_quest_active("side_empty_grave") or not context.is_objective_done("side_empty_grave", "follow_empty_grave") or context.is_objective_done("side_empty_grave", "walker_choice"):
		return
	if context.zone_root.find_child("returned_soldier", true, false) != null:
		return
	context.make_named_interactable("returned_soldier", "dialogue", "Speak to the returned soldier", Vector3(10.8, 0, 8.2), Color(0.28, 0.29, 0.31))

func publish_oren_charm_return(context: ZoneBuildContext) -> void:
	if not context.is_quest_active("side_childs_charm") or not context.is_objective_done("side_childs_charm", "trace_thread") or context.is_objective_done("side_childs_charm", "return_charm"):
		return
	if context.zone_root.find_child("oren_charm_shrine", true, false) != null:
		return
	context.make_clue("oren_charm_shrine", "Place Oren's charm by his grave", Vector3(10.8, 0, 10.7), "side_childs_charm", "return_charm", Color(0.45, 0.27, 0.18))

func publish_memorial_candles(context: ZoneBuildContext) -> void:
	var memorials := [
		["bram", Vector3(5.2, 0, 8.2), bool(context.get_story_flag("road_evidence_bram", false))],
		["sella", Vector3(5.2, 0, 11.2), bool(context.get_story_flag("road_evidence_sella", false))],
		["oren", Vector3(5.2, 0, 14.2), bool(context.get_story_flag("oren_name_spoken", false)) or bool(context.get_story_flag("road_evidence_oren", false))],
	]
	for memorial in memorials:
		var name_id := str(memorial[0])
		var position: Vector3 = memorial[1]
		var objective_id := "light_%s" % name_id
		var lit := context.is_objective_done("side_three_candles", objective_id)
		if lit:
			if context.zone_root.find_child("LitMemorialCandle_%s" % name_id, true, false) == null:
				context.add_node(_make_memorial_candle_visual(context, name_id, position, true))
		elif context.is_quest_active("side_three_candles") and bool(memorial[2]):
			if context.zone_root.find_child("memorial_candle_%s" % name_id, true, false) != null:
				continue
			var clue := context.make_clue("memorial_candle_%s" % name_id, "Light %s's memorial candle" % name_id.capitalize(), position, "side_three_candles", objective_id, Color(0.52, 0.43, 0.31)) as Area3D
			if clue == null:
				continue
			for child in clue.get_children():
				if child is MeshInstance3D:
					child.visible = false
			clue.add_child(_make_memorial_candle_visual(context, name_id, Vector3.ZERO, false))

func _make_memorial_candle_visual(context: ZoneBuildContext, name_id: String, position: Vector3, lit: bool) -> Node3D:
	var candle := Node3D.new()
	candle.name = "LitMemorialCandle_%s" % name_id if lit else "MemorialCandleVisual"
	candle.position = position
	var wax := MeshInstance3D.new()
	wax.name = "Wax"
	var wax_mesh := CylinderMesh.new()
	wax_mesh.top_radius = 0.075
	wax_mesh.bottom_radius = 0.09
	wax_mesh.height = 0.30
	wax.mesh = wax_mesh
	wax.position.y = 0.18
	wax.material_override = context.make_material(Color(0.68, 0.60, 0.43))
	candle.add_child(wax)
	var wick := MeshInstance3D.new()
	wick.name = "Wick"
	var wick_mesh := CylinderMesh.new()
	wick_mesh.top_radius = 0.008
	wick_mesh.bottom_radius = 0.008
	wick_mesh.height = 0.055
	wick.mesh = wick_mesh
	wick.position.y = 0.35
	wick.material_override = context.make_material(Color(0.07, 0.055, 0.04))
	candle.add_child(wick)
	var flame := MeshInstance3D.new()
	flame.name = "Flame"
	var flame_mesh := SphereMesh.new()
	flame_mesh.radial_segments = 8
	flame_mesh.rings = 4
	flame.mesh = flame_mesh
	flame.scale = Vector3(0.045, 0.09, 0.045)
	flame.position.y = 0.42
	var glow := context.make_material(Color(1.0, 0.53, 0.15))
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.34, 0.08)
	glow.emission_energy_multiplier = 1.5
	flame.material_override = glow
	flame.visible = lit
	candle.add_child(flame)
	return candle

func _build_gameplay_main_clues(context: ZoneBuildContext) -> void:
	context.make_clue("grave_harl", "Inspect Harl's disturbed grave", Vector3(12.2,0,7.2), "main_bell_beneath_greyfen", "grave_harl", Color(0.3,0.28,0.25))
	context.make_clue("grave_child", "Inspect the nameless child's grave", Vector3(14.0,0,10.2), "main_bell_beneath_greyfen", "grave_child", Color(0.3,0.28,0.25))
	context.make_clue("grave_soldier", "Inspect the empty soldier's grave", Vector3(16.2,0,7.2), "main_bell_beneath_greyfen", "grave_soldier", Color(0.3,0.28,0.25))
	context.make_clue("chapel_door", "Open the ruined Crow Chapel", Vector3(16.3,0,8.0), "main_bell_beneath_greyfen", "open_chapel", Color(0.24,0.22,0.18))
	if context.is_quest_active("main_teeth_in_rain"):
		context.set_story_flag("teeth_in_rain_available", true)
		if context.is_objective_done("main_teeth_in_rain", "speak_mira") and not context.is_objective_done("main_teeth_in_rain", "read_chapel_names"):
			context.make_clue("chapel_names", "Read the erased names in the chapel", Vector3(15.0,0,8.2), "main_teeth_in_rain", "read_chapel_names", Color(0.44,0.39,0.31))
	if context.is_quest_active("main_names_they_burned"):
		context.make_clue("register_anwen", "Take Anwen's hidden register page", Vector3(5.4,0,-6.2), "main_names_they_burned", "fragment_anwen", Color(0.42,0.36,0.22))
		context.make_clue("register_tor", "Take the forge register page", Vector3(9.0,0,-1.0), "main_names_they_burned", "fragment_tor", Color(0.42,0.36,0.22))
	if context.is_quest_active("side_black_dog") and not bool(context.get_story_flag("black_dog_sheepfold_inspected", false)):
		context.make_clue("sheepfold", "Inspect sheepfold", Vector3(15, 0, -11), "side_black_dog", "find_dog", Color(0.36, 0.24, 0.16))

func _build_gameplay_gates(context: ZoneBuildContext) -> void:
	context.make_zone_gate("To Wychwood", context.authored_anchor_position("WychwoodGateAnchor", Vector3(0, 0, -15.2)), "wychwood", Vector3(0, 1, 13))
	context.make_zone_gate("The long road", context.authored_anchor_position("DeepWoodGateAnchor", Vector3(-18,0,-10)), "deep_wood", Vector3(0,1,12))
	context.make_wychwood_gate_scene(Vector3(0, 0, -14.3))
	context.make_route_markers()
	var castle_gate = context.make_zone_gate("Road to Castle Vargan", context.authored_anchor_position("CastleGateAnchor", Vector3(17.5, 0, 0)), "vargan_approach", Vector3(0, 1, 14))
	if castle_gate != null:
		castle_gate.rotation_degrees.y = 90.0
		castle_gate.set_meta("always_accessible", true)

func _build_board_game(context: ZoneBuildContext, id: String) -> void:
	if context.zone_root.find_child(id, true, false) != null:
		return
	if id == "common_table":
		context.make_village_place("common_table", "minigame", "Play Three Marks with Rook", Vector3(-5.4,0,11.5), Vector3(2.8,0.85,1.8), Color(0.28,0.18,0.10))
	else:
		context.make_village_place("barrel_board", "minigame", "Play Greyfen Draughts with Tor", Vector3(7.0,0,10.3), Vector3(2.2,0.85,1.5), Color(0.24,0.15,0.08))

func _build_named_actor(context: ZoneBuildContext, actor_id: String) -> void:
	match actor_id:
		"mira":
			context.make_named_interactable("mira", "dialogue", "Talk to Mira Fen", Vector3(-6.7, 0, -0.35), Color(0.22, 0.48, 0.32), Vector3(0.62, 0.62, 0.62))
		"rook":
			context.make_named_interactable("rook", "dialogue", "Talk to Rook", Vector3(-7.8, 0, 8.5), Color(0.42, 0.33, 0.23), Vector3(0.62, 0.62, 0.62))
		"widow_elna":
			context.make_named_interactable("widow_elna", "dialogue", "Talk to Widow Elna", Vector3(13.0, 0, 7.0), Color(0.32, 0.30, 0.42), Vector3(0.54, 0.54, 0.54))
		"blacksmith_tor":
			context.make_named_interactable("blacksmith_tor", "dialogue", "Talk to Blacksmith Tor", Vector3(9.5, 0, -2.8), Color(0.43, 0.37, 0.31), Vector3(0.54, 0.54, 0.54))
		"farmer_toma":
			context.make_named_interactable("farmer_toma", "dialogue", "Talk to Farmer Toma", Vector3(10.7, 0, -10.7), Color(0.39, 0.30, 0.18), Vector3(0.46, 0.46, 0.46))

func _build_population(context: ZoneBuildContext, staged := false) -> void:
	var life = GreyfenLifeController.new()
	life.name = "GreyfenLifeController"
	life.set_meta("staged_population", staged)
	context.add_node(life)
	context.configure_zone_controller(life)
