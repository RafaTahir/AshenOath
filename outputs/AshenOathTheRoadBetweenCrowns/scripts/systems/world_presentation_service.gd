extends "res://scripts/systems/game_bindings.gd"
## Owns world operations; configure() injects dependencies.
signal render_resources_validated(report: Dictionary)

func _add_visual_100_layer(zone_id: String) -> void:
	_zone_construction()._add_visual_100_layer(zone_id)

func _install_world_prop_controller(zone_id: String) -> void:
	_zone_construction()._install_world_prop_controller(zone_id)

func _install_opening_soundscape(zone_id: String) -> void:
	StoryWorldDirector.decorate(_host, zone_root, zone_id)
	CovenantResolution.restore(_host)
	_host.call_deferred("_persist_story_action")
	_host.call_deferred("_finish_covenant_if_ready")
	if audio != null:
		audio.set_story_context(story_state, zone_id)
	if zone_root == null or not is_instance_valid(zone_root) or audio == null:
		return
	var soundscape := zone_root.find_child("OpeningSoundscape", true, false) as OpeningSoundscape
	if soundscape == null:
		soundscape = OpeningSoundscape.new()
		soundscape.name = "OpeningSoundscape"
		zone_root.add_child(soundscape)
	var quality := str(settings.settings.get("quality_preset", "balanced")) if settings != null else "balanced"
	soundscape.configure(zone_root, zone_id, player, audio, quality)

func _make_play_area_bounds(width: float, depth: float, color: Color) -> void:
	_zone_construction()._make_play_area_bounds(width, depth, color)

func _make_boundary_edge(edge_id: String, width: float, depth: float, color: Color) -> void:
	_zone_construction()._make_boundary_edge(edge_id, width, depth, color)

func _make_invisible_wall(pos: Vector3, size: Vector3) -> void:
	_zone_construction()._make_invisible_wall(pos, size)

func _make_greyfen_terrain_layers() -> void:
	_zone_construction()._make_greyfen_terrain_layers()

func _finish_greyfen_ground_surfaces() -> void:
	_zone_construction()._finish_greyfen_ground_surfaces()

func _finish_greyfen_paved_roads() -> void:
	_zone_construction()._finish_greyfen_paved_roads()

func _make_wychwood_terrain_layers() -> void:
	_zone_construction()._make_wychwood_terrain_layers()

func _make_wychwood_clearing_floor() -> void:
	var floor := MeshInstance3D.new()
	floor.name = "WychwoodClearingMud"
	floor.mesh = preload("res://scripts/prepared_zone_geometry.gd").mesh("wychwood_clearing")
	var material := world_materials.get_material("wet_mud", str(settings.settings.get("quality_preset", "balanced")), Color(0.30, 0.36, 0.29), 0.0, true).duplicate() as StandardMaterial3D
	material.vertex_color_use_as_albedo = true
	floor.material_override = material
	floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	zone_root.add_child(floor)

func _make_wychwood_winding_path() -> void:
	if zone_root.find_child("WychwoodWindingPath", true, false) != null:
		return
	var path := MeshInstance3D.new()
	path.name = "WychwoodWindingPath"
	var mesh := preload("res://scripts/prepared_zone_geometry.gd").mesh("wychwood_winding_path").duplicate() as ArrayMesh
	var mud_material := world_materials.get_material("wet_mud", str(settings.settings.get("quality_preset", "balanced")), Color(0.56, 0.50, 0.42), 0.20, true).duplicate() as StandardMaterial3D
	mud_material.resource_name = "WychwoodWindingPathMud"
	mud_material.roughness = 0.88
	mud_material.vertex_color_use_as_albedo = true
	mesh.surface_set_material(0, mud_material)
	var shoulder_material := world_materials.get_material("forest_ground", str(settings.settings.get("quality_preset", "balanced")), Color(0.58, 0.62, 0.54), 0.0, true).duplicate() as StandardMaterial3D
	shoulder_material.vertex_color_use_as_albedo = true
	mesh.surface_set_material(1, shoulder_material)
	path.mesh = mesh
	path.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	zone_root.add_child(path)

func _wychwood_path_center(z: float) -> float:
	return sin(z * 0.28) * 0.62 * smoothstep(2.3, 7.0, absf(z))

func _make_greyfen_path_edges() -> void:
	_zone_construction()._make_greyfen_path_edges()

func _make_wychwood_path_edges() -> void:
	_zone_construction()._make_wychwood_path_edges()

func _make_terrain_patch(name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	_zone_construction()._make_terrain_patch(name, pos, size, color)

func _make_terrain_patch_raw(name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	_zone_construction()._make_terrain_patch_raw(name, pos, size, color)

func _make_path_stone(pos: Vector3, scale_value: float) -> void:
	_zone_construction()._make_path_stone(pos, scale_value)

func _make_low_berm(pos: Vector3, size: Vector3, color: Color) -> void:
	_zone_construction()._make_low_berm(pos, size, color)

func _make_grass_tufts(points: Array, color: Color) -> void:
	_zone_construction()._make_grass_tufts(points, color)

func _make_spawn_composition() -> void:
	_zone_construction()._make_spawn_composition()

func _make_greyfen_first_impression_dressing(stage: String = "") -> void:
	_zone_construction()._make_greyfen_first_impression_dressing(stage)

func _make_quality_greyfen_overhaul() -> void:
	_zone_construction()._make_quality_greyfen_overhaul()

func _make_quality_survival_cluster(pos: Vector3) -> void:
	_zone_construction()._make_quality_survival_cluster(pos)

func _make_road_ruts() -> void:
	_zone_construction()._make_road_ruts()

func _make_lantern_rhythm() -> void:
	_zone_construction()._make_lantern_rhythm()

func _make_shrine_approach() -> void:
	_zone_construction()._make_shrine_approach()

func _make_village_story_clusters() -> void:
	_zone_construction()._make_village_story_clusters()

func _make_lantern_post(pos: Vector3, shrine_style: bool, casts_light: bool) -> void:
	_zone_construction()._make_lantern_post(pos, shrine_style, casts_light)

func _make_fake_light_pool(name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	_zone_construction()._make_fake_light_pool(name, pos, size, color)

func _make_firewood_stack(pos: Vector3, yaw: float) -> void:
	_zone_construction()._make_firewood_stack(pos, yaw)

func _make_broken_fence_run(pos: Vector3, vertical: bool) -> void:
	_zone_construction()._make_broken_fence_run(pos, vertical)

func _make_wheelbarrow(pos: Vector3, yaw: float) -> void:
	_zone_construction()._make_wheelbarrow(pos, yaw)

func _make_mourning_marker(pos: Vector3) -> void:
	_zone_construction()._make_mourning_marker(pos)

func _make_shrine_candle(pos: Vector3) -> void:
	_zone_construction()._make_shrine_candle(pos)

func _make_hanging_cloth(pos: Vector3, size: Vector3, color: Color) -> void:
	_zone_construction()._make_hanging_cloth(pos, size, color)

func _make_fake_fog_bank(pos: Vector3) -> void:
	_zone_construction()._make_fake_fog_bank(pos)

func _make_crow_silhouettes() -> void:
	_zone_construction()._make_crow_silhouettes()

func _add_crow_part(parent: Node3D, name: String, mesh: Mesh, local_pos: Vector3, scale_value: Vector3, color: Color, rotation_degrees := Vector3.ZERO) -> MeshInstance3D:
	return _zone_construction()._add_crow_part(parent, name, mesh, local_pos, scale_value, color, rotation_degrees)

func _make_visual_box(name: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	return _zone_construction()._make_visual_box(name, pos, size, color)

func _append_prepared_detail(id: String) -> void:
	_zone_construction()._append_prepared_detail(id)

func _make_prepared_prop(id: String) -> void:
	_zone_construction()._make_prepared_prop(id)

func _add_visual_box_child(parent: Node3D, name: String, local_pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	return _zone_construction()._add_visual_box_child(parent, name, local_pos, size, color)

func _make_greyfen_road_of_crows_story_beats() -> void:
	_zone_construction()._make_greyfen_road_of_crows_story_beats()

func _make_wychwood_road_of_crows_story_beats() -> void:
	_zone_construction()._make_wychwood_road_of_crows_story_beats()

func _make_post_ghoulkin_story_clue() -> void:
	_zone_construction()._make_post_ghoulkin_story_clue()

func _make_narrative_aftermath(zone_id: String) -> void:
	_zone_construction()._make_narrative_aftermath(zone_id)

func _make_black_feather_scatter(base_name: String, center: Vector3, count: int, spread: float) -> void:
	_zone_construction()._make_black_feather_scatter(base_name, center, count, spread)

func _make_broken_charm(name: String, pos: Vector3, yaw: float) -> void:
	_zone_construction()._make_broken_charm(name, pos, yaw)

func _make_dark_track(name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	_zone_construction()._make_dark_track(name, pos, size, color)

func _make_claw_marks(name: String, pos: Vector3, vertical: bool) -> void:
	_zone_construction()._make_claw_marks(name, pos, vertical)

func _make_wychwood_corridor() -> void:
	_zone_construction()._make_wychwood_corridor()

func _make_stylized_house(pos: Vector3) -> void:
	_make_prop_box("VillageHouseBody", pos + Vector3(0, 1.05, 0), Vector3(3.8, 2.1, 3.0), Color(0.25, 0.18, 0.13))
	_make_roof(pos + Vector3(0, 2.45, 0), Vector3(4.6, 0.95, 3.6), Color(0.12, 0.085, 0.06))
	_make_prop_box("VillageDoor", pos + Vector3(0, 0.75, -1.55), Vector3(0.75, 1.35, 0.12), Color(0.08, 0.055, 0.035))
	_make_prop_box("VillageWindow", pos + Vector3(-1.15, 1.25, -1.56), Vector3(0.55, 0.45, 0.08), Color(0.86, 0.55, 0.22))
	_make_prop_box("VillageWindow", pos + Vector3(1.15, 1.25, -1.56), Vector3(0.55, 0.45, 0.08), Color(0.86, 0.55, 0.22))

func _make_village_house_dressed(pos: Vector3, yaw: float, node_name: String) -> void:
	_zone_construction()._make_village_house_dressed(pos, yaw, node_name)

func _add_house_module(parent: Node3D, role_name: String, scale_value: Vector3, local_pos: Vector3, yaw: float, node_name: String) -> Node3D:
	var module: Node3D = _make_house_facade_module(role_name, scale_value) if role_name in ["greyfen_door_facade", "greyfen_window_facade", "greyfen_wall_facade", "greyfen_roof"] else _make_role_visual(role_name, "environment", scale_value)
	if module == null:
		return null
	module.name = node_name
	module.position = local_pos
	module.rotation_degrees.y = yaw
	module.set_meta("world_001_module", true)
	parent.add_child(module)
	if role_name in ["greyfen_window_facade", "greyfen_wall_facade"] and module is MeshInstance3D:
		var facade := module as MeshInstance3D
		var batch_key := "%s_%s" % [role_name, parent.name]
		if not house_module_batch_data.has(batch_key):
			house_module_batch_data[batch_key] = {"mesh": facade.mesh, "transforms": []}
		house_module_batch_data[batch_key].transforms.append(parent.transform * facade.transform)
		facade.visible = false
	return module

func _make_house_facade_module(role_name: String, scale_value: Vector3) -> MeshInstance3D:
	if asset_helper == null or asset_helper.database == null:
		return null
	var entry: Dictionary = asset_helper.database.get_asset_for_role(role_name)
	var path := str(entry.get("path", ""))
	var source: ArrayMesh = asset_helper.load_runtime_resource(path) as ArrayMesh
	if source == null or source.get_surface_count() < 2:
		push_error("Greyfen facade lost material-grouped mesh: " + role_name)
		return null
	var mesh := source.duplicate() as ArrayMesh
	var quality := str(settings.settings.get("quality_preset", "balanced"))
	for index in range(mesh.get_surface_count()):
		var group := source.surface_get_name(index).to_lower()
		var surface_id := ""
		if group.contains("plaster"):
			surface_id = "plaster"
		elif group.contains("roundtiles"):
			surface_id = "roof_tiles"
		elif group.contains("wood"):
			surface_id = "timber"
		elif group.contains("brick") or group.contains("rock"):
			surface_id = "medieval_brick"
		if surface_id == "":
			push_error("Unknown Greyfen facade material group: " + group)
			return null
		var tint := Color(0.48, 0.41, 0.34) if surface_id == "plaster" else Color.WHITE
		mesh.surface_set_material(index, world_materials.get_material(surface_id, quality, tint, 0.0, true))
	var module := MeshInstance3D.new()
	module.mesh = mesh
	var native_size := source.get_aabb().size
	if native_size.x <= 0.001 or native_size.y <= 0.001 or native_size.z <= 0.001:
		push_error("Greyfen module has invalid native bounds: " + role_name)
		return null
	var target_size: Vector3 = ENVIRONMENT_ROLE_NORMALIZED_SIZE.get(role_name, native_size)
	module.scale = Vector3(
		scale_value.x * target_size.x / native_size.x,
		scale_value.y * target_size.y / native_size.y,
		scale_value.z * target_size.z / native_size.z
	)
	module.set_meta("world_material_groups", mesh.get_surface_count())
	return module

func _add_house_gables(parent: Node3D, plaster: Color, timber: Color, authored_facades: bool) -> void:
	var vertices := PackedVector3Array([
		Vector3(-2.08, 2.08, -1.69), Vector3(2.08, 2.08, -1.69), Vector3(0.0, 3.18, -1.69),
		Vector3(2.08, 2.08, 1.69), Vector3(-2.08, 2.08, 1.69), Vector3(0.0, 3.18, 1.69),
	])
	var normals := PackedVector3Array([
		Vector3.BACK, Vector3.BACK, Vector3.BACK,
		Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD,
	])
	var uvs := PackedVector2Array([
		Vector2(0, 1), Vector2(1, 1), Vector2(0.5, 0),
		Vector2(0, 1), Vector2(1, 1), Vector2(0.5, 0),
	])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var gable_mesh := ArrayMesh.new()
	gable_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var gables := MeshInstance3D.new()
	gables.name = "PlasteredGableWalls"
	gables.mesh = gable_mesh
	gables.material_override = world_materials.get_material("plaster", str(settings.settings.get("quality_preset", "balanced")), plaster.lightened(0.48), 0.0, false)
	parent.add_child(gables)
	if not authored_facades:
		for z in [-1.72, 1.72]:
			_add_house_box(parent, "GableKingPost", Vector3(0, 2.57, z), Vector3(0.13, 1.14, 0.10), timber)

func _add_house_gabled_roof(parent: Node3D, color: Color) -> MeshInstance3D:
	var width := 4.78
	var length := 4.10
	var eave_y := 2.08
	var ridge_y := 3.16
	var half_length := length * 0.5
	var half_width := width * 0.5
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	# Front is negative Z. Winding is chosen so both sloped planes face upward.
	_append_house_quad(vertices, normals, uvs, indices,
		Vector3(-half_width, eave_y, -half_length),
		Vector3(-half_width, eave_y, half_length),
		Vector3(0.0, ridge_y, half_length),
		Vector3(0.0, ridge_y, -half_length))
	_append_house_quad(vertices, normals, uvs, indices,
		Vector3(0.0, ridge_y, -half_length),
		Vector3(0.0, ridge_y, half_length),
		Vector3(half_width, eave_y, half_length),
		Vector3(half_width, eave_y, -half_length))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var roof_mesh := ArrayMesh.new()
	roof_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var roof := MeshInstance3D.new()
	roof.name = "AuthoredGabledRoof"
	roof.mesh = roof_mesh
	roof.material_override = world_materials.get_material("roof_tiles", str(settings.settings.get("quality_preset", "balanced")), color, 0.0, false)
	roof.set_meta("world_visual_role", "gabled_roof")
	parent.add_child(roof)
	return roof

func _append_house_quad(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var base := vertices.size()
	var normal := (b - a).cross(c - a).normalized()
	for point in [a, b, c, d]:
		vertices.append(point)
		normals.append(normal)
		uvs.append(Vector2(point.x * 0.32, point.z * 0.32))
	indices.append(base)
	indices.append(base + 1)
	indices.append(base + 2)
	indices.append(base)
	indices.append(base + 2)
	indices.append(base + 3)

func _add_house_box(parent: Node3D, node_name: String, local_pos: Vector3, size: Vector3, color: Color, local_rot: Vector3 = Vector3.ZERO) -> Node3D:
	# Keep named authored details while rendering repeated pieces in material batches.
	var marker := Node3D.new()
	marker.name = node_name
	marker.position = local_pos
	marker.rotation_degrees = local_rot
	parent.add_child(marker)
	var lower := node_name.to_lower()
	var surface := "plaster"
	if lower in ["litwindow", "rearlitwindow", "sidewindow", "uppergablewindow"]:
		surface = "emissive_window"
	elif lower == "glazedpane":
		surface = "glazing"
	elif lower.contains("roof") or lower.contains("awning") or lower.contains("canopy"):
		surface = "roof_tiles"
	elif lower.contains("timber") or lower.contains("door") or lower.contains("window") or lower.contains("shutter") or lower.contains("post") or lower.contains("shelf"):
		surface = "timber"
	elif lower.contains("foundation") or lower.contains("stone") or lower.contains("step"):
		surface = "medieval_brick"
	var batch_key := surface if surface != "emissive_window" else "%s:%s" % [surface, color.to_html(false)]
	if not house_batch_data.has(batch_key):
		var material: Material
		if surface == "emissive_window":
			material = _emissive_mat(color, 0.7)
		elif surface == "glazing":
			material = _mat(color)
		else:
			material = world_materials.get_material(surface, str(settings.settings.get("quality_preset", "balanced")), Color.WHITE, 0.0, true).duplicate()
			(material as StandardMaterial3D).vertex_color_use_as_albedo = true
		house_batch_data[batch_key] = {"material": material, "transforms": [], "colors": []}
	var rotation_radians := Vector3(deg_to_rad(local_rot.x), deg_to_rad(local_rot.y), deg_to_rad(local_rot.z))
	var basis := Basis.from_euler(rotation_radians).scaled(size)
	var zone_transform: Transform3D = parent.transform * Transform3D(basis, local_pos)
	house_batch_data[batch_key].transforms.append(zone_transform)
	var tint := color.lightened(0.20 if surface == "plaster" else 0.12)
	house_batch_data[batch_key].colors.append(Color.WHITE if surface in ["emissive_window", "glazing"] else tint)
	return marker

func _make_house_collision(parent: Node3D) -> void:
	_zone_construction()._make_house_collision(parent)

func _add_lit_window(parent: Node3D, local_pos: Vector3) -> void:
	var pane = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.52, 0.38, 0.035)
	pane.mesh = mesh
	pane.position = local_pos
	pane.material_override = _emissive_mat(Color(1.0, 0.58, 0.20), 0.85)
	parent.add_child(pane)

func _add_role_child(parent: Node3D, role_name: String, scale_value: Vector3, local_pos: Vector3, yaw: float) -> Node3D:
	var node = _make_role_visual(role_name, "environment", scale_value)
	if node == null:
		return null
	node.position = local_pos
	node.rotation_degrees.y = yaw
	parent.add_child(node)
	return node

func _make_village_dressing() -> void:
	_zone_construction()._make_village_dressing()

func _make_wychwood_gate_scene(pos: Vector3) -> void:
	_zone_construction()._make_wychwood_gate_scene(pos)

func _make_wychwood_route_dressing() -> void:
	_zone_construction()._make_wychwood_route_dressing()

func _make_quality_wychwood_overhaul() -> void:
	_zone_construction()._make_quality_wychwood_overhaul()

func _make_loose_role(role_name: String, pos: Vector3, scale_value: Vector3, yaw: float) -> Node3D:
	return _zone_construction()._make_loose_role(role_name, pos, scale_value, yaw)

func _make_roof(pos: Vector3, size: Vector3, color: Color) -> void:
	_make_prop_box("VillageRoof", pos, size, color)
	_make_prop_box("RoofRidge", pos + Vector3(0, 0.55, 0), Vector3(size.x * 0.18, 0.18, size.z * 1.05), color.darkened(0.18))

func _make_notice_board(pos: Vector3) -> void:
	_zone_construction()._make_notice_board(pos)

func _make_route_markers() -> void:
	_zone_construction()._make_route_markers()

func _make_shrine_scene(pos: Vector3) -> void:
	_zone_construction()._make_shrine_scene(pos)

func _make_blacksmith_scene(pos: Vector3) -> void:
	_zone_construction()._make_blacksmith_scene(pos)

func _make_cemetery_scene(pos: Vector3) -> void:
	_make_prop_box("CemeteryWall", pos + Vector3(0, 0.35, 1.9), Vector3(7.0, 0.7, 0.45), Color(0.18, 0.18, 0.17))
	for i in range(5):
		_make_gravestone(pos + Vector3(-2.6 + i * 1.3, 0, 0.4 + (i % 2) * 0.75))
	for offset in [Vector3(-3.4, 0, 2.0), Vector3(3.2, 0, 1.8), Vector3(0.4, 0, 2.2)]:
		_make_rubble(pos + offset)
	_make_fog_sheet(pos + Vector3(0, 0.55, 0.8), Vector3(7.2, 0.7, 2.8), Color(0.18, 0.18, 0.16, 0.11))

func _make_tree_cluster(points: Array) -> void:
	_zone_construction()._make_tree_cluster(points)

func _make_collapsed_road(pos: Vector3) -> void:
	_make_prop_box("BlockedRoadBerm", pos + Vector3(0.8, 0.65, 0), Vector3(3.2, 1.3, 5.4), Color(0.10, 0.095, 0.075))
	_make_prop_box("BlockedRoadPalisade", pos + Vector3(-0.1, 1.05, -1.25), Vector3(0.28, 2.1, 0.28), Color(0.13, 0.075, 0.04))
	_make_prop_box("BlockedRoadPalisade", pos + Vector3(-0.1, 1.05, 1.25), Vector3(0.28, 2.1, 0.28), Color(0.13, 0.075, 0.04))
	_make_prop_box("BlockedRoadRail", pos + Vector3(-0.15, 1.25, 0), Vector3(0.28, 0.28, 3.4), Color(0.15, 0.08, 0.045))
	for offset in [Vector3(0.5, 0, -1.8), Vector3(1.0, 0, 1.6), Vector3(1.4, 0, 0.2)]:
		_make_rubble(pos + offset)
	_make_torch(pos + Vector3(-1.0, 0, -2.1))

func _make_monster_clearing(pos: Vector3) -> void:
	_zone_construction()._make_monster_clearing(pos)

func _make_named_interactable(id: String, type: String, prompt: String, pos: Vector3, color: Color, scale_override: Vector3 = Vector3.ONE):
	return _zone_construction()._make_named_interactable(id, type, prompt, pos, color, scale_override)

func _make_ledger_interaction_visual(area: Node3D, scale_override: Vector3) -> void:
	_zone_construction()._make_ledger_interaction_visual(area, scale_override)

func _make_token_interaction_visual(area: Node3D, scale_override: Vector3) -> void:
	_zone_construction()._make_token_interaction_visual(area, scale_override)

func _make_village_place(id: String, type: String, prompt: String, pos: Vector3, size: Vector3, color: Color):
	return _zone_construction()._make_village_place(id, type, prompt, pos, size, color)

func _apply_greyfen_well_visual(visual: MeshInstance3D, pos: Vector3) -> void:
	_zone_construction()._apply_greyfen_well_visual(visual, pos)

func _make_board_game_staging(area: Node3D, id: String, size: Vector3) -> void:
	_zone_construction()._make_board_game_staging(area, id, size)

func _make_board_game_chair(area: Node3D, position: Vector3, yaw: float, batch: MultiMeshInstance3D, first_index: int) -> void:
	_zone_construction()._make_board_game_chair(area, position, yaw, batch, first_index)

func _world_prop_spec(id: String) -> Dictionary:
	return {
		"notice_board": {"kind": "notice_board", "state_key": "greyfen_prop:notice_board"},
		"village_well": {"kind": "well", "state_key": "greyfen_well_state"},
		"forge_corner": {"kind": "forge", "state_key": "greyfen_prop:forge_corner"},
		"shrine_prayer": {"kind": "shrine", "state_key": "shrine_prayer_state"},
		"common_table": {"kind": "table", "state_key": "common_table_state"},
		"barrel_board": {"kind": "table", "state_key": "barrel_board_state"},
		"vargan_ledger_choice": {"kind": "ledger", "state_key": "vargan_ledger_state"},
	}.get(id, {})

func _configure_npc_animation(mapped: Node3D, id: String) -> bool:
	return _zone_construction()._configure_npc_animation(mapped, id)

func _make_gate_marker(parent: Node3D, color: Color, scale_override: Vector3) -> void:
	_zone_construction()._make_gate_marker(parent, color, scale_override)

func _label_for_interactable(id: String, prompt: String) -> String:
	if dialogue != null and dialogue.has_dialogue(id):
		return dialogue.display_name(id, prompt)
	if id.begins_with("gate_"):
		return prompt
	return prompt.replace("Inspect ", "").replace("Gather ", "").replace("Take ", "")

func _make_clue(id: String, prompt: String, pos: Vector3, quest_id: String, objective_id: String, color: Color):
	return _zone_construction()._make_clue(id, prompt, pos, quest_id, objective_id, color)

func _present_castle_clue(id: String, title: String) -> void:
	var accounts := {
		"vargan_mile_marker": "Vargan's crest is worn into the roadside marker. Compare the passage this road promised with the closure posted at the gate.",
		"vargan_supply_cart": "A military supply cart stands abandoned on the approach. Keep this trace beside the dated command ledger before deciding whose order it supports.",
		"vargan_gate_notice": "The gatehouse notice closes the road under Vargan's authority. The written command, rather than the decorative crest alone, belongs in the account.",
		"vargan_iron_binding": "The blackened wire matches the binding recovered from the road tokens. It links the later containment to Vargan, not the original attack to a proven commander."
	}
	if not accounts.has(id):
		return
	audio.set_game_paused(true)
	hud.show_dialogue({"name": title, "pages": [{"speaker": "The recovered account", "speaker_id": "narrator", "text": accounts[id]}], "actions": []})

func _make_herb(id: String, pos: Vector3, color: Color):
	return _zone_construction()._make_herb(id, pos, color)

func _make_zone_gate(prompt: String, pos: Vector3, zone_target: String, spawn_pos: Vector3):
	return _zone_construction()._make_zone_gate(prompt, pos, zone_target, spawn_pos)

func _add_physical_door_visual(area: Node3D, zone_target: String) -> void:
	_zone_construction()._add_physical_door_visual(area, zone_target)

func _make_blocked_gate(prompt: String, pos: Vector3, message: String):
	var area = _make_named_interactable("blocked_ruins", "blocked_zone", prompt, pos, Color(0.20, 0.16, 0.11), Vector3(0.8, 0.8, 0.8))
	if area == null:
		return null
	area.set_meta("message", message)
	return area

func _make_ground(pos: Vector3, size: Vector3, color: Color, collision_enabled: bool = true) -> void:
	_zone_construction()._make_ground(pos, size, color, collision_enabled)

func _make_split_ground(width: float, depth: float, river_z: float, river_span: float, color: Color, bridge_width: float = 0.0, bridge_length: float = 0.0, bridge_approach_length: float = 0.0) -> void:
	_zone_construction()._make_split_ground(width, depth, river_z, river_span, color, bridge_width, bridge_length, bridge_approach_length)

func _make_bridge_corridor_collision(bridge_width: float, river_z: float, bridge_length: float, approach_length: float, zone_depth: float) -> void:
	_zone_construction()._make_bridge_corridor_collision(bridge_width, river_z, bridge_length, approach_length, zone_depth)

func _make_hut(pos: Vector3) -> void:
	_make_prop_box("Hut", pos + Vector3(0, 1, 0), Vector3(3.6, 2, 3.0), Color(0.22, 0.16, 0.12))
	_make_prop_box("Roof", pos + Vector3(0, 2.25, 0), Vector3(4.2, 0.8, 3.6), Color(0.10, 0.09, 0.08))
	_make_prop_box("Door", pos + Vector3(0, 0.65, -1.54), Vector3(0.75, 1.25, 0.08), Color(0.10, 0.07, 0.045))
	_make_prop_box("Chimney", pos + Vector3(1.1, 2.95, 0.4), Vector3(0.38, 0.9, 0.38), Color(0.12, 0.11, 0.10))

func _scene_randf() -> float:
	return _zone_construction()._scene_randf()

func _scene_randf_range(from: float, to: float) -> float:
	return _zone_construction()._scene_randf_range(from, to)

func _make_tree(pos: Vector3) -> void:
	_zone_construction()._make_tree(pos)

func _make_tree_wall(axis_extent: float, fixed_pos: float, count: int, along_x: bool) -> void:
	_zone_construction()._make_tree_wall(axis_extent, fixed_pos, count, along_x)

func _make_deadfall(pos: Vector3) -> void:
	_zone_construction()._make_deadfall(pos)

func _clear_environment_batch_buffers() -> void:
	# Build-time arrays are only transform carriers. Once copied into their
	# MultiMesh nodes they must be released, otherwise a later detail stage would
	# rebatch the entire zone and duplicate geometry.
	tree_batch_data.clear()
	deadfall_batch_data.clear()
	prop_batch_data.clear()
	visual_box_batch_data.clear()
	terrain_patch_batch_data.clear()
	house_batch_data.clear()
	house_module_batch_data.clear()

func _upload_static_batch(instance: MultiMeshInstance3D, transforms: Array, colors: Array = []) -> void:
	_zone_construction()._upload_static_batch(instance, transforms, colors)

func _flush_environment_batches() -> void:
	_zone_construction()._flush_environment_batches()

func _flush_authored_tree_assets() -> bool:
	return _zone_construction()._flush_authored_tree_assets()

func _make_multimesh_batch(node_name: String, mesh: Mesh, count: int, material: Material, use_colors: bool = false) -> MultiMeshInstance3D:
	return _zone_construction()._make_multimesh_batch(node_name, mesh, count, material, use_colors)

func _valid_material_or_fallback(material: Material) -> Material:
	if material != null:
		return material
	if world_materials != null and world_materials.has_method("get_fallback_material"):
		return world_materials.get_fallback_material()
	return _first_route_material("ground")

func _ensure_mesh_surface_materials(mesh: Mesh, fallback: Material) -> int:
	if mesh == null or fallback == null:
		return 0
	var applied := 0
	for surface_index in range(mesh.get_surface_count()):
		if mesh.surface_get_material(surface_index) == null:
			mesh.surface_set_material(surface_index, fallback)
			applied += 1
	return applied

func _validate_zone_render_resources(root: Node) -> Dictionary:
	var report := {
		"mesh_instances": 0,
		"multimesh_instances": 0,
		"fallbacks_applied": 0,
		"invalid_geometry": 0,
		"invalid_geometry_names": [],
	}
	if root == null:
		return report
	var fallback := _valid_material_or_fallback(null)
	for mesh_node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		report.mesh_instances += 1
		if mesh_instance.mesh == null:
			if not mesh_instance.is_queued_for_deletion():
				report.invalid_geometry += 1
				report.invalid_geometry_names.append(str(mesh_instance.name))
			continue
		if mesh_instance.mesh.get_surface_count() == 0:
			mesh_instance.material_override = fallback
			report.fallbacks_applied += 1
			continue
		# RenderingServer consults the mesh's base surface material while releasing
		# skinned instances, even when an instance override is present.
		report.fallbacks_applied += _ensure_mesh_surface_materials(mesh_instance.mesh, fallback)
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var effective := mesh_instance.get_surface_override_material(surface_index)
			if effective == null:
				effective = mesh_instance.mesh.surface_get_material(surface_index)
			if effective == null:
				var replacement := mesh_instance.material_override if mesh_instance.material_override != null else fallback
				mesh_instance.set_surface_override_material(surface_index, replacement)
				report.fallbacks_applied += 1
	for batch_node in root.find_children("*", "MultiMeshInstance3D", true, false):
		var batch_instance := batch_node as MultiMeshInstance3D
		report.multimesh_instances += 1
		if batch_instance.multimesh == null or batch_instance.multimesh.mesh == null:
			report.invalid_geometry += 1
			report.invalid_geometry_names.append(str(batch_instance.name))
			continue
		report.fallbacks_applied += _ensure_mesh_surface_materials(batch_instance.multimesh.mesh, fallback)
		# Mesh-owned materials are valid without an instance override. Replacing
		# them here destroys transparency/emission (including the star field).
	root.set_meta("zone_render_resource_report", report)
	render_resources_validated.emit(report)
	return report

func _make_road(pos: Vector3, size: Vector3, color: Color) -> void:
	_zone_construction()._make_road(pos, size, color)

func _make_world_wheel(id: String, pos: Vector3, radius: float, depth: float, color: Color, rotation_degrees: Vector3 = Vector3.ZERO) -> void:
	_zone_construction()._make_world_wheel(id, pos, radius, depth, color, rotation_degrees)

func _make_water_patch(id: String, pos: Vector3, size: Vector3, color: Color) -> void:
	_zone_construction()._make_water_patch(id, pos, size, color)

func _make_fence(pos: Vector3, vertical: bool) -> void:
	_zone_construction()._make_fence(pos, vertical)

func _make_gravestone(pos: Vector3) -> void:
	_zone_construction()._make_gravestone(pos)

func _make_cart(pos: Vector3, include_visual: bool = true) -> void:
	_zone_construction()._make_cart(pos, include_visual)

func _make_world_prop_anchor(id: String, kind: String, pos: Vector3, state_key: String = "") -> Node3D:
	return _zone_construction()._make_world_prop_anchor(id, kind, pos, state_key)

func _make_ritual_stone(pos: Vector3) -> void:
	_zone_construction()._make_ritual_stone(pos)

func _make_pillar(pos: Vector3) -> void:
	_zone_construction()._make_pillar(pos)

func _make_rubble(pos: Vector3) -> void:
	_zone_construction()._make_rubble(pos)

func _make_torch(pos: Vector3) -> void:
	_zone_construction()._make_torch(pos)

func _make_hit_spark(pos: Vector3, heavy: bool) -> void:
	if zone_root == null:
		return
	var spark = MeshInstance3D.new()
	var spark_mesh := SphereMesh.new()
	spark_mesh.radial_segments = 5
	spark_mesh.rings = 3
	spark.mesh = spark_mesh
	spark.scale = Vector3.ONE * (0.22 if heavy else 0.14)
	spark.material_override = _emissive_mat(Color(1.0, 0.68, 0.24), 1.8)
	zone_root.add_child(spark)
	spark.global_position = pos
	var tween = _host.create_tween()
	tween.tween_property(spark, "scale", Vector3.ONE * 0.02, 0.18)
	tween.parallel().tween_property(spark, "position:y", spark.position.y + 0.45, 0.18)
	tween.tween_callback(spark.queue_free)

func _make_fog_sheet(pos: Vector3, scale_value: Vector3, color: Color) -> void:
	_zone_construction()._make_fog_sheet(pos, scale_value, color)

func _make_prop_box(name: String, pos: Vector3, size: Vector3, color: Color, render_geometry: bool = true, prepared: Dictionary = {}) -> void:
	_zone_construction()._make_prop_box(name, pos, size, color, render_geometry, prepared)

func _make_collision_box(name: String, pos: Vector3, size: Vector3) -> void:
	_zone_construction()._make_collision_box(name, pos, size)

func _prop_requires_collision(lower_name: String) -> bool:
	return _zone_construction()._prop_requires_collision(lower_name)

func _is_first_route_clearance(pos: Vector3, radius: float = 0.0) -> bool:
	return _zone_construction()._is_first_route_clearance(pos, radius)

func _route_safe_position(pos: Vector3, target_x: float) -> Vector3:
	return _zone_construction()._route_safe_position(pos, target_x)

func _apply_first_route_materials(root: Node) -> void:
	_zone_construction()._apply_first_route_materials(root)

func _first_route_palette_key(node: Node) -> String:
	return _zone_construction()._first_route_palette_key(node)

func _node_keyword_path(node: Node) -> String:
	return _zone_construction()._node_keyword_path(node)

func _mesh_needs_visible_fallback(mesh_instance: MeshInstance3D) -> bool:
	return _zone_construction()._mesh_needs_visible_fallback(mesh_instance)

func _surface_has_authored_colors(mesh: Mesh, surface_index: int, material: Material) -> bool:
	return _zone_construction()._surface_has_authored_colors(mesh, surface_index, material)

func _is_bad_white_material(material: Material) -> bool:
	return _zone_construction()._is_bad_white_material(material)

func _first_route_material(key: String) -> StandardMaterial3D:
	return _zone_construction()._first_route_material(key)

func _role_for_interactable(id: String) -> String:
	var roles = {
		"sister_anwen": "sister_anwen",
		"mira": "mira_herbalist",
		"rook": "rook_smuggler",
		"widow_elna": "widow_elna",
		"blacksmith_tor": "blacksmith_tor",
		"farmer_toma": "generic_villager_01",
		"returned_soldier": "castle_guard",
		"edric": "castle_guard",
		"vargan_gate_guard": "castle_guard",
		"vargan_record_keeper": "castle_guard",
		"vargan_steward": "vargan_steward",
		"vargan_servant": "vargan_servant",
		"vargan_patrol": "vargan_patrol",
		"edric_castle": "edric_castle",
		"edric_campaign": "edric_campaign",
		"captain_senn": "road_ranger",
		"halvern": "halvern_boss",
		"white_hart": "white_hart_avatar",
		"witness_-7": "mira_herbalist",
		"witness_-3": "rook_smuggler",
		"witness_3": "sister_anwen"
	}
	return str(roles.get(id, ""))

func _visual_role_for_interactable(id: String) -> String:
	var roles = {
		"sister_anwen": "sister_anwen_human",
		"mira": "mira_human",
		"rook": "rook_human",
		"widow_elna": "villager_female_human",
		"blacksmith_tor": "villager_worker_human",
		"farmer_toma": "villager_human",
		"returned_soldier": "castle_guard_human",
		"edric": "castle_guard_human",
		"vargan_gate_guard": "castle_guard_human",
		"vargan_record_keeper": "villager_worker_human",
		"vargan_steward": "villager_worker_human",
		"vargan_servant": "villager_female_human",
		"vargan_patrol": "road_ranger_human",
		"edric_castle": "castle_guard_human",
		"edric_campaign": "castle_guard_human",
		"captain_senn": "road_ranger_human",
		"halvern": "halvern_boss"
	}
	return str(roles.get(id, ""))

func _role_for_prop(name: String) -> String:
	var key = name.to_lower()
	if key.contains("crate"):
		return "crate"
	if key.contains("barrel"):
		return "barrel"
	return ""

func _make_role_visual(role_name: String, category: String, scale_value: Vector3) -> Node3D:
	return _zone_construction()._make_role_visual(role_name, category, scale_value)

func _environment_role_scale(role_name: String, target_size: Vector3) -> Vector3:
	var normalized_size: Vector3 = ENVIRONMENT_ROLE_NORMALIZED_SIZE.get(role_name, Vector3.ZERO)
	if normalized_size == Vector3.ZERO:
		push_error("No fitted environment bounds registered for role '%s'" % role_name)
		return Vector3.ONE
	return Vector3(
		target_size.x / maxf(normalized_size.x, 0.001),
		target_size.y / maxf(normalized_size.y, 0.001),
		target_size.z / maxf(normalized_size.z, 0.001)
	)

func _visual_role_for_legacy_character(role_name: String) -> String:
	var roles = {
		"player_kael": "player_human",
		"sister_anwen": "sister_anwen_human",
		"mira_herbalist": "mira_human",
		"rook_smuggler": "rook_human",
		"widow_elna": "villager_female_human",
		"blacksmith_tor": "villager_worker_human",
		"generic_villager_01": "villager_human",
		"lord_edric": "castle_guard_human",
		"castle_guard": "castle_guard_human",
		"vargan_gate_guard": "castle_guard_human",
		"vargan_record_keeper": "villager_worker_human",
		"vargan_steward": "villager_worker_human",
		"vargan_servant": "villager_female_human",
		"vargan_patrol": "road_ranger_human",
		"edric_castle": "castle_guard_human",
		"edric_campaign": "castle_guard_human",
		"halvern_boss": "halvern_boss",
		"road_ranger": "road_ranger_human"
	}
	return str(roles.get(role_name, ""))

func _make_light(name: String, pos: Vector3, color: Color, energy: float) -> void:
	_zone_construction()._make_light(name, pos, color, energy)

func _performance_mode() -> bool:
	return settings != null and bool(settings.settings.get("potato_mode", true))

func _compatibility_budget_mode() -> bool:
	return settings == null or str(settings.settings.get("quality_preset", "balanced")) != "quality"

func _keep_performance_light(name: String) -> bool:
	return name in ["Village Warmth", "Shrine Beacon", "Wychwood Gate Lantern", "Moon Shaft", "Trail Threat", "ClearingColdSpot", "SpawnWarmRead", "AshMillFacadeFill", "BanditWarmLantern", "LedgerTableLight", "RecordHallNavigationFill", "RecordHallEntryFill", "RecordHallArchiveFill", "HartWitnessLight", "HartAftermathLight", "UndercroftNavigationFill", "UndercroftHalvernFill"]

func _build_global_environment() -> void:
	visual_director = VisualDirector.new()
	_host.add_child(visual_director)

func _mat(color: Color) -> StandardMaterial3D:
	var interior_lift: bool = current_zone_id in ["record_hall", "undercroft", "old_mill"]
	var key := "flat:%s:%s" % [color.to_html(true), current_zone_id if interior_lift else "world"]
	if material_cache.has(key):
		return material_cache[key]
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	if interior_lift:
		# Compatibility can leave upward-facing procedural archive surfaces
		# unlit. A restrained self-lit lift preserves their authored color without
		# turning the room into a flat white box.
		material.emission_enabled = true
		material.emission = color.lightened(0.18)
		var lift_strength := 0.52 if current_zone_id == "record_hall" else (0.22 if current_zone_id == "old_mill" else 0.34)
		material.emission_energy_multiplier = lift_strength
	material_cache[key] = material
	return material

func _terrain_material(name: String, color: Color) -> StandardMaterial3D:
	if world_materials != null:
		var lower := name.to_lower()
		var surface := "forest_ground"
		var wetness := 0.0
		if lower.contains("mud") or lower.contains("wet") or lower.contains("cemetery"):
			surface = "wet_mud"
			wetness = 0.72
		var tint_lift := 0.34 if lower.begins_with("wychwood") or current_zone_id == "wychwood" else 0.65
		return world_materials.get_material(surface, str(settings.settings.get("quality_preset", "balanced")), color.lightened(tint_lift), wetness, true)
	var key = "terrain:%s:%s" % [name, color.to_html()]
	if material_cache.has(key):
		return material_cache[key]
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.94
	material.metallic = 0.0
	if name.to_lower().contains("mud") or name.to_lower().contains("wet"):
		material.albedo_color = color.lerp(Color(0.025, 0.030, 0.026), 0.35)
		material.roughness = 0.70
	elif name.to_lower().contains("green") or name.to_lower().contains("shoulder"):
		material.albedo_color = color.lerp(Color(0.060, 0.120, 0.055), 0.24)
	material_cache[key] = material
	return material

func _road_material(paved: bool, color: Color) -> StandardMaterial3D:
	if world_materials != null:
		var road_tint := Color(0.64, 0.61, 0.56) if paved else Color(0.38, 0.31, 0.22).lerp(color, 0.15)
		return world_materials.get_material("cobblestone" if paved else "wet_mud", str(settings.settings.get("quality_preset", "balanced")), road_tint, 0.15 if paved else 0.78, true)
	var key = "road:paved" if paved else "road:mud"
	if material_cache.has(key):
		return material_cache[key]
	var material = StandardMaterial3D.new()
	if paved:
		material.albedo_color = color.lerp(Color(0.22, 0.20, 0.17), 0.45)
		material.roughness = 0.96
	else:
		material.albedo_color = color.lerp(Color(0.026, 0.034, 0.030), 0.55)
		material.roughness = 0.68
	material_cache[key] = material
	return material

func _grass_material(color: Color) -> StandardMaterial3D:
	var key = "grass:%s" % color.to_html()
	if material_cache.has(key):
		return material_cache[key]
	var material = StandardMaterial3D.new()
	material.albedo_color = color.lerp(Color(0.075, 0.115, 0.060), 0.28)
	material.roughness = 0.88
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_cache[key] = material
	return material

func _emissive_mat(color: Color, energy: float) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material

func _zone_construction() -> Node3D:
	return ZoneBuildContext.active_host(_host)

func _zone_runtime_fields() -> Dictionary:
	return ZoneBuildContext.fields_for(zone_root) if is_instance_valid(zone_root) else _unbound_zone_fields

func _publish_opening_batches(generation: int) -> bool:
	var root := zone_root
	var builder := _zone_construction()
	var slice_started := Time.get_ticks_usec()
	for phase in range(7):
		if not _opening_attempt_current(generation) or not is_instance_valid(root) or zone_root != root:
			return false
		builder.flush_environment_batch_step(phase)
		if Time.get_ticks_usec() - slice_started >= OPENING_BUILD_SLICE_USEC:
			await _host.get_tree().process_frame
			await _wait_for_opening_build_slot(generation)
			slice_started = Time.get_ticks_usec()
	return _opening_attempt_current(generation) and is_instance_valid(root) and zone_root == root
