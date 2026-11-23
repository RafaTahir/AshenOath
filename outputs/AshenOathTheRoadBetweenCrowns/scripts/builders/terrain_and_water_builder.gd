extends RefCounted
const Api = preload("res://scripts/core/zone_construction_api.gd")
const Scope = preload("res://scripts/core/zone_instance_scope.gd")
var _host: Api
var _scope: Scope
func _init(host: Api, scope: Scope) -> void:
	_host = host
	_scope = scope
func _make_ground(pos: Vector3, size: Vector3, color: Color, collision_enabled: bool = true) -> void:
	var parent: Node3D = _scope.zone_root
	if collision_enabled:
		var body: Variant = StaticBody3D.new()
		body.position = pos
		_scope.zone_root.add_child(body)
		var shape: Variant = CollisionShape3D.new()
		var box: Variant = preload("res://scripts/immutable_collision_shapes.gd").box(size)
		shape.shape = box
		body.add_child(shape)
		parent = body
	var mesh: Variant = MeshInstance3D.new()
	mesh.mesh = preload("res://scripts/core/wychwood_ground_geometry.gd").ground_mesh(size, pos) if _scope.zone_id == "wychwood" else _host.world_materials.make_tiled_box(size, pos)
	mesh.position = Vector3.ZERO if collision_enabled else pos
	mesh.material_override = _host._terrain_material("CampaignGround", color)
	_host.write_construction_tag(mesh, "split_ground_size", size)
	_host.write_construction_tag(mesh, "split_ground_origin", pos)
	parent.add_child(mesh)
func _make_split_ground(width: float, depth: float, river_z: float, river_span: float, color: Color, bridge_width: float = 0.0, bridge_length: float = 0.0, bridge_approach_length: float = 0.0) -> void:
	var south_edge: Variant = river_z + river_span * 0.5
	var north_edge: Variant = river_z - river_span * 0.5
	var north_depth: Variant = north_edge + depth * 0.5
	var south_depth: Variant = depth * 0.5 - south_edge
	if bridge_width > 0.0 and bridge_length > 0.0 and bridge_approach_length > 0.0:
		var side_width: Variant = maxf((width - bridge_width) * 0.5, 0.1)
		var side_center: Variant = bridge_width * 0.5 + side_width * 0.5
		_host._make_ground(Vector3(-side_center,-0.08,-depth*0.5+north_depth*0.5),Vector3(side_width,0.16,north_depth),color)
		_host._make_ground(Vector3(side_center,-0.08,-depth*0.5+north_depth*0.5),Vector3(side_width,0.16,north_depth),color)
		_host._make_ground(Vector3(-side_center,-0.08,south_edge+south_depth*0.5),Vector3(side_width,0.16,south_depth),color)
		_host._make_ground(Vector3(side_center,-0.08,south_edge+south_depth*0.5),Vector3(side_width,0.16,south_depth),color)
		var support_half_length: Variant = bridge_length * 0.5 + bridge_approach_length
		var north_corridor_end: Variant = river_z - support_half_length
		var north_corridor_depth: Variant = maxf(north_corridor_end + depth * 0.5, 0.0)
		if north_corridor_depth > 0.05:
			_host._make_ground(Vector3(0.0,-0.08,-depth*0.5+north_corridor_depth*0.5), Vector3(bridge_width,0.16,north_corridor_depth), color, false)
		var south_corridor_start: Variant = river_z + support_half_length
		var south_corridor_depth: Variant = maxf(depth * 0.5 - south_corridor_start, 0.0)
		if south_corridor_depth > 0.05:
			_host._make_ground(Vector3(0.0,-0.08,south_corridor_start+south_corridor_depth*0.5), Vector3(bridge_width,0.16,south_corridor_depth), color, false)
		_host._make_bridge_corridor_collision(bridge_width, river_z, bridge_length, bridge_approach_length, depth)
		return
	_host._make_ground(Vector3(0,-0.08,-depth*0.5+north_depth*0.5),Vector3(width,0.16,north_depth),color)
	_host._make_ground(Vector3(0,-0.08,south_edge+south_depth*0.5),Vector3(width,0.16,south_depth),color)
func _make_play_area_bounds(width: float, depth: float, color: Color) -> void:
	var half_w = width * 0.5
	var half_d = depth * 0.5
	_host._make_boundary_edge("north", width, depth, color)
	_host._make_boundary_edge("south", width, depth, color)
	_host._make_boundary_edge("west", width, depth, color)
	_host._make_boundary_edge("east", width, depth, color)
func _make_road(pos: Vector3, size: Vector3, color: Color) -> void:
	var mesh = MeshInstance3D.new()
	mesh.name = "PavedRoad" if _scope.zone_id == "greyfen" else "MudRoad"
	var geometry_owner: Variant = "greyfen" if _scope.zone_id in ["greyfen", "cemetery"] else "wychwood" if _scope.zone_id in ["wychwood", "ruins"] else "campaign"
	mesh.mesh = preload("res://scripts/prepared_zone_geometry.gd").mesh("%s_road_%s" % [geometry_owner, preload("res://scripts/prepared_zone_geometry.gd").geometry_key(size, pos)])
	mesh.position = pos
	mesh.material_override = _host._road_material(_scope.zone_id == "greyfen", color)
	_scope.zone_root.add_child(mesh)
func _make_terrain_patch(name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var river_z: Variant = _host._river_center()
	var river_min: Variant = river_z - _host.BridgeSurfaceContract.RIVER_HALF_SPAN
	var river_max: Variant = river_z + _host.BridgeSurfaceContract.RIVER_HALF_SPAN
	var patch_min: Variant = pos.z - size.z * 0.5
	var patch_max: Variant = pos.z + size.z * 0.5
	if river_z < _host.SpatialSurfaceContract.NO_RIVER and patch_min < river_max and patch_max > river_min:
		if patch_min < river_min:
			var north_size: Variant = river_min - patch_min
			_host._make_terrain_patch_raw("%s_NorthBank" % name, Vector3(pos.x,pos.y,patch_min+north_size*0.5), Vector3(size.x,size.y,north_size), color)
		if patch_max > river_max:
			var south_size: Variant = patch_max - river_max
			_host._make_terrain_patch_raw("%s_SouthBank" % name, Vector3(pos.x,pos.y,river_max+south_size*0.5), Vector3(size.x,size.y,south_size), color)
		return
	_host._make_terrain_patch_raw(name,pos,size,color)
func _make_water_patch(id: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var water: Variant = MeshInstance3D.new()
	water.name = id
	var water_mesh: Variant = BoxMesh.new()
	water_mesh.size = size
	water.mesh = water_mesh
	water.position = pos
	var material: StandardMaterial3D = _host.world_materials.get_material("water", str(_host.settings.settings.get("quality_preset", "balanced")), color, 1.0, true).duplicate() as StandardMaterial3D
	material.roughness = 0.24
	material.metallic = 0.08
	material.emission_enabled = true
	material.emission = color.lightened(0.12)
	material.emission_energy_multiplier = 0.16
	water.material_override = material
	_host.write_construction_tag(water, "world_prop_kind", "marsh_water")
	_host.write_construction_tag(water, "non_walkable_visual_only", true)
	_scope.zone_root.add_child(water)
func _make_fog_sheet(pos: Vector3, scale_value: Vector3, color: Color) -> void:
	if _host.settings != null and str(_host.settings.settings.get("quality_preset", "balanced")) != "quality":
		return
	if _host._performance_mode() and _scope.zone_id == "greyfen":
		return
	if _host._performance_mode() and _host._scene_randf() < 0.45:
		return
	var fog = MeshInstance3D.new()
	fog.mesh = PlaneMesh.new()
	fog.position = pos
	fog.scale = scale_value
	fog.rotation_degrees.x = 90
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fog.material_override = material
	_scope.zone_root.add_child(fog)
func _make_bridge_corridor_collision(bridge_width: float, river_z: float, bridge_length: float, approach_length: float, zone_depth: float) -> void:
	var body: Variant = StaticBody3D.new()
	body.name = "RiverBridgeContinuousSurface"
	body.position = Vector3(0.0, 0.0, 0.0)
	_scope.zone_root.add_child(body)
	var collision: Variant = CollisionShape3D.new()
	var support_length: Variant = maxf(zone_depth, bridge_length + approach_length * 2.0)
	var shape: Variant = preload("res://scripts/immutable_collision_shapes.gd").box(Vector3(bridge_width, 0.20, support_length))
	collision.position = Vector3(0.0, -0.10, 0.0)
	collision.shape = shape
	body.add_child(collision)
func _make_boundary_edge(edge_id: String, width: float, depth: float, color: Color) -> void:
	var half_w: float = width * 0.5
	var half_d: float = depth * 0.5
	var open_edge: Dictionary = _host.seamless_world.open_edges_for(_scope.zone_id).get(edge_id, {}) if _host.seamless_world != null else {}
	var opening_half: float = float(open_edge.get("half_width", 0.0))
	var lane: float = float(open_edge.get("lane", 0.0))
	var openings: Array[Vector2] = []
	for edge: Dictionary in WorldSectorManifest.connections(_scope.zone_id, _host.story_state):
		if str(edge.id) == edge_id: openings.append(Vector2(float(edge.lane) - float(edge.half_width), float(edge.lane) + float(edge.half_width)))
	if openings.is_empty() and not open_edge.is_empty() and opening_half > 0.0 and WorldSectorManifest.connection_between(_scope.zone_id, str(open_edge.get("target", ""))).is_empty():
		openings.append(Vector2(lane - opening_half, lane + opening_half))
	var along_x: bool = edge_id in ["north", "south"]
	var line_half: float = half_w if along_x else half_d
	openings.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var segments: Array[Vector2] = []
	var cursor: float = -line_half
	for opening: Vector2 in openings:
		var start: float = clampf(opening.x, -line_half + 0.6, line_half - 0.6)
		var finish: float = clampf(opening.y, -line_half + 0.6, line_half - 0.6)
		if start > cursor: segments.append(Vector2(cursor, start))
		cursor = maxf(cursor, finish)
	if cursor < line_half: segments.append(Vector2(cursor, line_half))
	var sign_value: float = -1.0 if edge_id in ["north", "west"] else 1.0
	var enclosed: bool = _scope.zone_id in ["record_hall", "undercroft"]
	for segment: Vector2 in segments:
		var length: float = segment.y - segment.x
		if length < 0.35: continue
		var center: float = (segment.x + segment.y) * 0.5
		var position: Vector3 = Vector3(center, 0.9, sign_value * half_d) if along_x else Vector3(sign_value * half_w, 0.9, center)
		var size: Vector3 = Vector3(length, 1.8, 1.2) if along_x else Vector3(1.2, 1.8, length)
		if not enclosed: _host._make_prop_box(edge_id.capitalize() + "Berm", position, size, color)
		var collision_pos: Vector3 = Vector3(center, 1.6, sign_value * (half_d + 0.65)) if along_x else Vector3(sign_value * (half_w + 0.65), 1.6, center)
		var collision_size: Vector3 = Vector3(length, 3.2, 0.4) if along_x else Vector3(0.4, 3.2, length)
		_host._make_invisible_wall(collision_pos, collision_size)
func _make_terrain_patch_raw(name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var mesh = MeshInstance3D.new()
	mesh.name = name
	mesh.position = pos
	mesh.rotation_degrees.y = 0.0 if _scope.zone_id == "wychwood" else _host._scene_randf_range(-2.0, 2.0)
	_scope.zone_root.add_child(mesh)
	_scope.terrain_patch_batch_data.append({"node":mesh,"size":size,"color":color,"material":_host._terrain_material(name,color)})
func river_safe_position(pos: Vector3, margin: float = 0.55) -> Vector3:
	if _scope.spatial_service != null:
		return _scope.spatial_service.validate_position(pos, margin)
	var validator: Variant = _host.ZoneSpatialService.new()
	validator.configure(_scope.zone_id, _host._river_center(), _host._zone_half_extents(_scope.zone_id))
	var result: Vector3 = validator.validate_position(pos, margin, validator.bank_for(pos))
	validator.free()
	return result
func validate_walkable_position(pos: Vector3) -> Vector3:
	if _scope.spatial_service != null:
		return _scope.spatial_service.validate_position(pos, 0.90)
	var safe: Variant = _host.river_safe_position(pos, 0.90)
	safe.x = clampf(safe.x, -18.5, 18.5)
	safe.z = clampf(safe.z, -14.5, 14.5)
	safe.y = 0.0
	return safe
func _river_center(zone: String = _scope.zone_id) -> float:
	return _host.SpatialSurfaceContract.river_center(zone)
func _is_river_excluded(pos: Vector3, margin: float = 0.0) -> bool:
	if _scope.spatial_service != null and _scope.spatial_service.zone_id == _scope.zone_id:
		return _scope.spatial_service.is_river_excluded(pos, margin)
	return _host.SpatialSurfaceContract.is_river_excluded(_scope.zone_id, pos, margin)
func _route_safe_position(pos: Vector3, target_x: float) -> Vector3:
	if not _host._is_first_route_clearance(pos, 0.0):
		return pos
	var side = -1.0 if pos.x < 0.0 else 1.0
	if abs(pos.x) < 0.2:
		side = -1.0 if _host._scene_randf() < 0.5 else 1.0
	pos.x = side * target_x
	return pos
func _make_low_berm(pos: Vector3, size: Vector3, color: Color) -> void:
	if _host._is_river_excluded(pos,size.z*0.5):
		return
	if _scope.spatial_service != null and _scope.spatial_service.is_reserved(pos, maxf(size.x, size.z) * 0.5 + 0.35):
		return
	var body = StaticBody3D.new()
	body.name = "LowBerm"
	body.position = pos + Vector3(0, size.y * 0.5, 0)
	_scope.zone_root.add_child(body)
	var shape = CollisionShape3D.new()
	var box = preload("res://scripts/immutable_collision_shapes.gd").box(size)
	shape.shape = box
	body.add_child(shape)
	var mesh = MeshInstance3D.new()
	mesh.name = "RoundedEarthBerm"
	mesh.mesh = preload("res://scripts/prepared_zone_geometry.gd").mesh("wychwood_berm_" + preload("res://scripts/prepared_zone_geometry.gd").geometry_key(size, pos))
	mesh.material_override = _host._terrain_material("WychwoodEarthBerm", color)
	body.add_child(mesh)
func _make_invisible_wall(pos: Vector3, size: Vector3) -> void:
	var body = StaticBody3D.new()
	body.name = "WorldBoundary"
	body.position = pos
	_scope.zone_root.add_child(body)
	var shape = CollisionShape3D.new()
	var box = preload("res://scripts/immutable_collision_shapes.gd").box(size)
	shape.shape = box
	body.add_child(shape)
func _finish_greyfen_ground_surfaces() -> void:
	if _scope.zone_root.find_child("GreyfenGroundMerged", true, false) != null:
		return
	var prepared: Variant = preload("res://scripts/prepared_zone_geometry.gd").mesh("greyfen_ground")
	if prepared == null:
		return
	var source_surfaces: Array[MeshInstance3D] = []
	for ground_name in ["GroundNorthWest", "GroundNorthEast", "GroundSouthWest", "GroundSouthEast", "GroundCenterNorthVisual", "GroundCenterSouthVisual"]:
		var ground: Variant = _scope.zone_root.find_child(ground_name, true, false)
		if ground == null:
			continue
		var surface: Variant = ground as MeshInstance3D if ground is MeshInstance3D else ground.get_node_or_null("Surface") as MeshInstance3D
		if surface != null:
			source_surfaces.append(surface)
	if source_surfaces.size() != 6:
		push_error("Greyfen authored ground is incomplete: %d/6 surfaces" % source_surfaces.size())
		return
	var ground_visual: Variant = MeshInstance3D.new()
	ground_visual.name = "GreyfenGroundMerged"
	ground_visual.mesh = prepared
	var ground_material: Variant = _host.world_materials.get_material("forest_ground", str(_host.settings.settings.get("quality_preset", "balanced")), Color.WHITE, 0.0, false).duplicate() as StandardMaterial3D
	ground_material.resource_name = "GreyfenGroundBlended"
	ground_material.vertex_color_use_as_albedo = true
	ground_visual.material_override = ground_material
	ground_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scope.zone_root.add_child(ground_visual)
	for surface in source_surfaces:
		surface.visible = false
		surface.queue_free()
func _finish_greyfen_paved_roads() -> void:
	for road_name in ["PavedRoadMain", "PavedRoadVillage", "PavedRoadCastle"]:
		var road: Variant = _scope.zone_root.find_child(road_name, true, false) as MeshInstance3D
		if road == null:
			continue
		road.mesh = preload("res://scripts/prepared_zone_geometry.gd").mesh("greyfen_" + road_name)
		road.scale = Vector3.ONE
		var road_material: Variant = _host._road_material(true, Color(0.16, 0.13, 0.09)).duplicate() as StandardMaterial3D
		road_material.vertex_color_use_as_albedo = true
		road.material_override = road_material
func _make_road_ruts() -> void:
	return
func _make_greyfen_terrain_layers() -> void:
	_host._finish_greyfen_ground_surfaces()
	_host._finish_greyfen_paved_roads()
	_host._make_terrain_patch("GreyfenCemeterySoil", Vector3(14.0, 0.028, 8.6), Vector3(8.0, 0.045, 5.0), Color(0.095, 0.090, 0.078))
	_host._make_grass_tufts([
		Vector3(-3.4, 0, -11.5), Vector3(3.1, 0, -10.7), Vector3(-3.6, 0, -7.5), Vector3(3.3, 0, -5.6),
		Vector3(-3.8, 0, -1.4), Vector3(3.6, 0, 1.8), Vector3(-3.0, 0, 5.6), Vector3(3.7, 0, 7.9),
		Vector3(-3.2, 0, -9.5), Vector3(3.0, 0, -8.1), Vector3(-3.0, 0, -5.0), Vector3(3.2, 0, -3.0),
		Vector3(-3.1, 0, 8.4), Vector3(3.2, 0, 9.0), Vector3(-3.3, 0, 11.2), Vector3(3.4, 0, 11.5),
		Vector3(-3.5, 0, 13.6), Vector3(3.1, 0, 13.4), Vector3(5.2, 0, -8.8), Vector3(7.4, 0, -4.9),
		Vector3(11.9, 0, 7.4), Vector3(14.8, 0, 6.2)
	], Color(0.070, 0.145, 0.070))
func _make_wychwood_terrain_layers() -> void:
	if not _host.WychwoodTerrainPresentation.integrate(_scope.zone_root):
		push_error("Wychwood walkable terrain could not be integrated")
		return
	_host._make_grass_tufts([
		Vector3(-2.8, 0, 11.8), Vector3(2.6, 0, 10.5), Vector3(-3.1, 0, 7.2), Vector3(3.3, 0, 5.6),
		Vector3(-3.4, 0, 2.0), Vector3(3.5, 0, -0.2), Vector3(-3.7, 0, -4.2), Vector3(3.4, 0, -6.1),
		Vector3(-5.0, 0, -8.4), Vector3(5.3, 0, -9.0)
	], Color(0.045, 0.115, 0.065))
func _make_greyfen_path_edges() -> void:
	var marker = Node3D.new()
	marker.name = "GreyfenPathEdgeComposition"
	_scope.zone_root.add_child(marker)
	for z in [-12, -4, 4, 12]:
		_host._make_path_stone(Vector3(-2.35 + _host._scene_randf_range(-0.12, 0.12), 0, z + _host._scene_randf_range(-0.35, 0.35)), 0.35)
		_host._make_path_stone(Vector3(2.35 + _host._scene_randf_range(-0.12, 0.12), 0, z + _host._scene_randf_range(-0.35, 0.35)), 0.32)
func _make_wychwood_path_edges() -> void:
	var marker = Node3D.new()
	marker.name = "WychwoodPathEdgeComposition"
	_scope.zone_root.add_child(marker)
	for z in [12, 9, 6, 3, 0, -3, -6, -9]:
		_host._make_low_berm(Vector3(-4.25, 0, z), Vector3(1.4, 0.48, 2.2), Color(0.030, 0.060, 0.038))
		_host._make_low_berm(Vector3(4.25, 0, z), Vector3(1.4, 0.48, 2.2), Color(0.030, 0.060, 0.038))
func _make_monster_clearing(pos: Vector3) -> void:
	var marker = Node3D.new()
	marker.name = "FirstCombatReadabilityDressing"
	marker.position = pos
	_scope.zone_root.add_child(marker)
	_host._make_light("ClearingColdSpot", pos + Vector3(0, 2.8, -0.4), Color(0.35, 0.48, 0.58), 2.4)
	_host._make_light("ClearingRimLantern", pos + Vector3(-3.2, 1.9, 1.8), Color(0.9, 0.38, 0.14), 1.2)
	_host._make_fog_sheet(pos + Vector3(0, 0.55, 0), Vector3(8, 1, 4.5), Color(0.18, 0.25, 0.22, 0.22))
	_host._make_fog_sheet(pos + Vector3(0, 1.15, -1.8), Vector3(9.2, 1, 3.0), Color(0.16, 0.20, 0.19, 0.16))
	for offset in [Vector3(-5.2,0,-2.9), Vector3(5.2,0,-2.4), Vector3(-5.0,0,2.8), Vector3(5.0,0,3.0)]:
		_host._make_deadfall(pos + offset)
	for offset in [Vector3(-6.2,0,-3.4), Vector3(6.2,0,-3.2), Vector3(-6.4,0,3.4), Vector3(6.3,0,3.3)]:
		_host._make_tree(pos + offset)
	for offset in [Vector3(-2.0,0,-1.1), Vector3(1.7,0,-1.4), Vector3(-0.6,0,1.4)]:
		_host._make_prop_box("BonePile", pos + offset + Vector3(0, 0.09, 0), Vector3(0.9, 0.18, 0.36), Color(0.46, 0.42, 0.35))
	for offset in [Vector3(-1.2,0,0.8), Vector3(1.1,0,0.6), Vector3(0.2,0,-1.9)]:
		_host._make_prop_box("BlackFeatherScatter", pos + offset + Vector3(0, 0.035, 0), Vector3(0.55, 0.04, 0.10), Color(0.015, 0.014, 0.016))
	for offset in [Vector3(-4.2,0,0.1), Vector3(4.2,0,0.0), Vector3(0,0,-3.2)]:
		_host._make_rubble(pos + offset)
	_host._make_loose_role("crate", pos + Vector3(-4.2, 0, 2.1), Vector3.ONE * 0.48, 18.0)
	_host._make_loose_role("barrel", pos + Vector3(-4.9, 0, 1.4), Vector3.ONE * 0.42, -8.0)
	_host._make_torch(pos + Vector3(-4.2, 0, 2.1))
func _make_ritual_stone(pos: Vector3) -> void:
	_host._make_prop_box("RitualStone", pos + Vector3(0, 0.8, 0), Vector3(0.6, 1.6, 0.35), Color(0.32, 0.34, 0.32))
	var rune = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.05, 0.42, 0.02)
	rune.mesh = mesh
	rune.position = pos + Vector3(0, 0.95, -0.19)
	rune.material_override = _host._emissive_mat(Color(0.64, 0.85, 0.72), 0.55)
	_scope.zone_root.add_child(rune)
func _make_rubble(pos: Vector3) -> void:
	if _scope.spatial_service != null and _scope.spatial_service.is_reserved(pos, 0.95):
		return
	pos = _host._route_safe_position(pos, 3.8)
	if _scope.spatial_service != null and _scope.spatial_service.is_reserved(pos, 0.95):
		return
	if _host._is_first_route_clearance(pos, 0.95):
		return
	for i in range(2):
		var offset = Vector3(_host._scene_randf_range(-0.18, 0.18), 0, _host._scene_randf_range(-0.16, 0.16))
		_host._make_prop_box("Rubble", pos + offset + Vector3(0, 0.16, 0), Vector3(_host._scene_randf_range(0.45, 0.95), _host._scene_randf_range(0.20, 0.42), _host._scene_randf_range(0.35, 0.82)), Color(0.18, 0.18, 0.165).lerp(Color(0.08, 0.13, 0.08), _host._scene_randf() * 0.35))
func _make_dark_track(name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	if _scope.zone_id == "wychwood":
		var trace: Variant = MeshInstance3D.new()
		trace.name = name
		trace.mesh = _host.world_materials.make_organic_ground_patch(size, pos)
		trace.position = pos
		trace.material_override = _host.world_materials.get_material("wet_mud", str(_host.settings.settings.get("quality_preset", "balanced")), color.lightened(0.18), 0.0, false)
		trace.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_scope.zone_root.add_child(trace)
		return
	var track = _host._make_visual_box(name, pos, size, color)
	track.rotation_degrees.y = _host._scene_randf_range(-8.0, 8.0)
func _make_claw_marks(name: String, pos: Vector3, vertical: bool) -> void:
	for i in range(3):
		var mark_pos = pos + (Vector3(0.0, 0.11 * float(i), 0.0) if vertical else Vector3(0.18 * float(i), 0.0, 0.0))
		var size = Vector3(0.045, 0.50, 0.035) if vertical else Vector3(0.055, 0.030, 0.62)
		var mark = _host._make_visual_box(name, mark_pos, size, Color(0.030, 0.018, 0.012))
		mark.rotation_degrees.z = -18.0 if vertical else 0.0
func _make_all_evidence_safe_edge() -> void:
	if _scope.zone_root == null or _scope.zone_root.find_child("RoadCrowsEvidenceSafeEdge", true, false) != null:
		return
	var edge: Variant = _host._make_visual_box("RoadCrowsEvidenceSafeEdge", Vector3(-4.25, 0.085, -6.25), Vector3(1.8, 0.025, 0.42), Color(0.31, 0.27, 0.14))
	_host.write_construction_tag(edge, "narrative_state", "safe_edge")
func _make_world_wheel(id: String, pos: Vector3, radius: float, depth: float, color: Color, rotation_degrees: Vector3 = Vector3.ZERO) -> void:
	var wheel: Variant = MeshInstance3D.new()
	wheel.name = id
	var wheel_mesh: Variant = CylinderMesh.new()
	wheel_mesh.top_radius = radius
	wheel_mesh.bottom_radius = radius
	wheel_mesh.height = depth
	wheel_mesh.radial_segments = 16
	wheel.mesh = wheel_mesh
	wheel.position = pos
	wheel.rotation_degrees = rotation_degrees
	wheel.material_override = _host.world_materials.get_material("timber", str(_host.settings.settings.get("quality_preset", "balanced")), color, 0.0, true)
	_host.write_construction_tag(wheel, "world_prop_kind", "mill_wheel")
	_host.write_construction_tag(wheel, "world_prop_spin_axis", Vector3.UP)
	_host.write_construction_tag(wheel, "world_prop_spin_speed", 0.45)
	_scope.zone_root.add_child(wheel)
	var hub: Variant = MeshInstance3D.new()
	hub.name = "%sHub" % id
	var hub_mesh: Variant = CylinderMesh.new()
	hub_mesh.top_radius = radius * 0.17
	hub_mesh.bottom_radius = radius * 0.17
	hub_mesh.height = depth * 1.18
	hub_mesh.radial_segments = 12
	hub.mesh = hub_mesh
	hub.position = pos
	hub.rotation_degrees = rotation_degrees
	hub.material_override = _host.world_materials.get_material("metal", str(_host.settings.settings.get("quality_preset", "balanced")), Color(0.20, 0.18, 0.14), 0.0, false)
	_scope.zone_root.add_child(hub)
func _make_fence(pos: Vector3, vertical: bool) -> void:
	_host._make_prop_box("FencePost", pos + Vector3(0, 0.2, 0), Vector3(0.16, 0.8, 0.16), Color(0.15, 0.09, 0.055))
	var rail_size = Vector3(2.5, 0.12, 0.12)
	if vertical:
		rail_size = Vector3(0.12, 0.12, 2.5)
	_host._make_prop_box("FenceRail", pos + Vector3(0, 0.52, 0), rail_size, Color(0.17, 0.105, 0.06))
