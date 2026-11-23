extends RefCounted
const Api = preload("res://scripts/core/zone_construction_api.gd")
const Scope = preload("res://scripts/core/zone_instance_scope.gd")
var _host: Api
var _scope: Scope
func _init(host: Api, scope: Scope) -> void:
	_host = host
	_scope = scope
func _make_grass_tufts(points: Array, color: Color) -> void:
	var safe_points: Array = []
	for point in points:
		if not _host._is_river_excluded(point,0.25) and (_scope.spatial_service == null or not _scope.spatial_service.is_reserved(point, 0.25)):
			safe_points.append(point)
	if safe_points.is_empty():
		return
	if _host._performance_mode() and int(_host.settings.settings.get("foliage_density", 0)) <= 0:
		return
	var batch = MultiMeshInstance3D.new()
	batch.name = "GrassBatch"
	var blade_mesh = QuadMesh.new()
	blade_mesh.size = Vector2(0.82, 1.0)
	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = blade_mesh
	multimesh.instance_count = safe_points.size() * 3
	var instance_index = 0
	for raw_pos in safe_points:
		var pos: Vector3 = raw_pos
		for i: int in range(3):
			var height: float = _host._scene_randf_range(0.34, 0.72)
			var basis = Basis()
			basis = basis.rotated(Vector3.UP, float(i) * PI / 3.0 + _host._scene_randf_range(-0.12, 0.12))
			basis = basis.scaled(Vector3(_host._scene_randf_range(0.82, 1.16), height, 1.0))
			var offset = Vector3(_host._scene_randf_range(-0.16, 0.16), height * 0.5, _host._scene_randf_range(-0.16, 0.16))
			multimesh.set_instance_transform(instance_index, Transform3D(basis, pos + offset))
			instance_index += 1
	batch.multimesh = multimesh
	batch.material_override = _host.world_materials.get_grass_material(str(_host.settings.settings.get("quality_preset", "balanced")))
	batch.visibility_range_end = 30.0
	_scope.zone_root.add_child(batch)
func _make_path_stone(pos: Vector3, scale_value: float) -> void:
	_host._make_terrain_patch("PathStone", pos + Vector3(0, 0.03, 0), Vector3(scale_value, 0.06, scale_value * 0.75), Color(0.18, 0.17, 0.15))
func _make_tree_cluster(points: Array) -> void:
	for pos in points:
		_host._make_tree(pos)
func _make_tree(pos: Vector3) -> void:
	if _scope.zone_id == "greyfen" and pos.x > 10.0 and pos.z > 7.5 and pos.z < 18.0:
		return
	if _scope.spatial_service != null and _scope.spatial_service.is_reserved(pos, 1.35):
		return
	if _host._is_river_excluded(pos,1.5):
		return
	pos = _host._route_safe_position(pos, 4.9)
	if _scope.spatial_service != null and _scope.spatial_service.is_reserved(pos, 1.35):
		return
	if _host._is_first_route_clearance(pos, 1.55):
		return
	if _scope.zone_id == "greyfen":
		for house in _host.get_tree().get_nodes_in_group("greyfen_house"):
			if not _scope.zone_root.is_ancestor_of(house):
				continue
			var house_position: Vector3 = _scope.zone_root.to_local((house as Node3D).global_position)
			if Vector2(pos.x, pos.z).distance_to(Vector2(house_position.x, house_position.z)) < 5.5:
				return
	var radius: Variant = _host._scene_randf_range(1.0, 1.35)
	pos = WorldSectorManifest.clear_connector_position(_scope.zone_id,pos,1.35,_host.story_state)
	if _scope.spatial_service != null:
		_scope.spatial_service.add_presence_landmark("shelter", pos, 0.7)
	var height: Variant = _host._scene_randf_range(2.0, 2.7)
	var yaw: Variant = _host._scene_randf_range(0.0, TAU)
	var tree_role: Variant = "forest_tree"
	var variant_selector: Variant = int(absf(pos.x * 17.0 + pos.z * 31.0))
	if variant_selector % 4 == 0:
		tree_role = "forest_tree_variant"
	elif _scope.zone_id == "wychwood":
		tree_role = "forest_tree_secondary"
	_scope.tree_batch_data.append({
		"trunk": Transform3D(Basis.IDENTITY, pos + Vector3(0, 0.9, 0)),
		"crown": Transform3D(Basis.from_euler(Vector3(0, yaw, 0)).scaled(Vector3(radius, height, radius)), pos + Vector3(0, 2.35, 0)),
		"asset_position": pos,
		"asset_scale": Vector3(radius * 0.88, height * 0.38, radius * 0.88),
		"asset_yaw": yaw,
		"asset_role": tree_role,
		"color": Color(0.055, 0.18, 0.085).lerp(Color(0.13, 0.24, 0.11), _host._scene_randf())
	})
	var tree_body: Variant = ZoneBuildContext.collision_batch(_scope.zone_root, "BatchedTreeCollisions")
	var shape: Variant = CollisionShape3D.new()
	var box: Variant = preload("res://scripts/immutable_collision_shapes.gd").box(Vector3(0.58, 3.6, 0.58))
	shape.shape = box
	shape.position = pos + Vector3(0, 2.1, 0)
	tree_body.add_child(shape)
func _make_tree_wall(axis_extent: float, fixed_pos: float, count: int, along_x: bool) -> void:
	for i in range(count):
		var t: float = 0.0 if count <= 1 else float(i) / float(count - 1)
		var offset: float = lerp(-axis_extent, axis_extent, t)
		var pos = Vector3(offset, 0, fixed_pos) if along_x else Vector3(fixed_pos, 0, offset)
		_host._make_tree(pos + Vector3(_host._scene_randf_range(-0.8, 0.8), 0, _host._scene_randf_range(-0.5, 0.5)))
func _make_prop_box(name: String, pos: Vector3, size: Vector3, color: Color, render_geometry: bool = true, prepared: Dictionary = {}) -> void:
	var authored_prop_ids: Array = _host.read_construction_tag(_scope.zone_root, "authored_prop_ids", [])
	if name not in authored_prop_ids:
		authored_prop_ids.append(name)
		_host.write_construction_tag(_scope.zone_root, "authored_prop_ids", authored_prop_ids)
	var preserve_authored_position: Variant = name in ["OssuarySealedDoor", "CemeteryCrowShrine", "GreyfenRiverShoreStone"]
	if name not in ["NorthBerm","SouthBerm","WestBerm","EastBerm"] and not preserve_authored_position:
		pos = _host.river_safe_position(pos,size.z*0.5+0.15)
	if _scope.spatial_service != null and _scope.spatial_service.is_reserved(pos, maxf(size.x, size.z) * 0.5 + 0.35):
		return
	var lower: Variant = name.to_lower()
	var separate_body: Variant = name in ["NorthBerm","SouthBerm","WestBerm","EastBerm"]
	if _scope.spatial_service != null and (lower.contains("crate") or lower.contains("barrel") or lower.contains("camp")):
		_scope.spatial_service.add_presence_landmark("camp", Vector3(pos.x, 0, pos.z), maxf(size.x, size.z) * 0.5)
	var decorative_only: Variant = name == "GreyfenRiverShoreStone" \
		or (size.y <= 0.28 and not _host._prop_requires_collision(lower)) \
		or lower.contains("torch") or lower.contains("lantern")
	var body: StaticBody3D = null
	if not decorative_only and separate_body:
		body = StaticBody3D.new()
		body.name = name
		body.position = pos
		_scope.zone_root.add_child(body)
	elif not decorative_only:
		body = ZoneBuildContext.collision_batch(_scope.zone_root, "BatchedPropCollisions")
	if not decorative_only:
		var shape: Variant = CollisionShape3D.new()
		shape.name = "%sCollision" % name
		var box: Variant = preload("res://scripts/immutable_collision_shapes.gd").box(size)
		shape.shape = box
		if not separate_body:
			shape.position = pos
		body.add_child(shape)
	if not render_geometry:
		return
	if _scope.zone_id in ["greyfen", "wychwood", "deep_wood", "old_mill", "burned_farmstead", "marsh_crossing", "bandit_road", "assembly", "hart_glade", "lantern_reach", "hearthward"] and separate_body and body != null:
		var bank: Variant = MeshInstance3D.new()
		bank.name = "WeatheredLandscapeBoundary"
		bank.mesh = _host.world_materials.make_forest_berm(size, pos)
		bank.material_override = _host.world_materials.get_material("forest_ground", str(_host.settings.settings.get("quality_preset", "balanced")), color.lightened(0.22), 0.0, false)
		body.add_child(bank)
		return
	if lower.contains("glow") or lower.contains("window") or lower.contains("coal") or lower.contains("candle"):
		var mesh: Variant = MeshInstance3D.new()
		mesh.mesh = _host.shared_box_mesh
		mesh.scale = size
		mesh.material_override = _host._emissive_mat(color, 0.65)
		if separate_body and body != null:
			body.add_child(mesh)
		else:
			mesh.position = pos
			_scope.zone_root.add_child(mesh)
	else:
		var surface: Variant = "plaster"
		if lower.contains("roof"):
			surface = "roof_tiles"
		elif lower.contains("wood") or lower.contains("door") or lower.contains("fence") or lower.contains("rail") or lower.contains("post") or lower.contains("board") or lower.contains("cart") or lower.contains("crate") or lower.contains("barrel"):
			surface = "timber"
		elif lower.contains("stone") or lower.contains("wall") or lower.contains("grave") or lower.contains("foundation") or lower.contains("chimney") or lower.contains("rubble"):
			surface = "medieval_brick"
		elif lower.contains("berm") or lower.contains("moss"):
			surface = "forest_ground"
		var surface_base: Variant = Color(0.72, 0.70, 0.66)
		var surface_tint: Variant = surface_base.lerp(color, 0.58)
		var tint_key: Variant = "%d_%d_%d" % [int(surface_tint.r * 8.0), int(surface_tint.g * 8.0), int(surface_tint.b * 8.0)]
		var batch_key: Variant = "%s_%s" % [surface, tint_key]
		var material = _host.world_materials.get_material(surface, str(_host.settings.settings.get("quality_preset", "balanced")), surface_tint, 0.15 if surface == "wet_mud" else 0.0, true)
		if not _scope.prop_batch_data.has(batch_key):
			_scope.prop_batch_data[batch_key] = {"material": material, "transforms": []}
		_scope.prop_batch_data[batch_key].transforms.append(prepared if not prepared.is_empty() and pos == prepared.position else Transform3D(Basis.IDENTITY.scaled(size), pos))
func _make_visual_box(name: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var preserve_interior_position: bool = _scope.zone_id in ["record_hall", "undercroft"]
	if not preserve_interior_position:
		pos = _host.river_safe_position(pos, size.z * 0.5 + 0.18)
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = name
	_host.write_construction_tag(mesh_instance, "visual_name", name)
	mesh_instance.position = pos
	mesh_instance.visibility_range_end = 32.0
	_scope.zone_root.add_child(mesh_instance)
	if _scope.environment_batches_flushed:
		mesh_instance.mesh = _host.shared_box_mesh
		mesh_instance.scale = size
		mesh_instance.material_override = _host._mat(color)
	else:
		_scope.visual_box_batch_data.append({"node":mesh_instance,"size":size,"color":color})
	return mesh_instance
func _make_loose_role(role_name: String, pos: Vector3, scale_value: Vector3, yaw: float) -> Node3D:
	var key = role_name.to_lower()
	if key in ["forest_tree", "forest_tree_variant"]:
		var before_count: Variant = _scope.tree_batch_data.size()
		_host._make_tree(pos)
		if _scope.tree_batch_data.size() > before_count:
			var item: Dictionary = _scope.tree_batch_data[_scope.tree_batch_data.size() - 1]
			item["asset_role"] = key
			item["asset_scale"] = scale_value
			item["asset_yaw"] = deg_to_rad(yaw)
			_scope.tree_batch_data[_scope.tree_batch_data.size() - 1] = item
		return null
	if key == "forest_rock":
		if _host._is_river_excluded(pos, 0.75) or _host._is_first_route_clearance(pos, 0.55):
			return null
		var rock: Variant = _host._make_role_visual("forest_rock", "environment", scale_value)
		if rock != null:
			var safe_rock_position: Variant = _host.river_safe_position(pos, 0.75)
			if safe_rock_position.distance_to(pos) > 1.6:
				rock.free()
				return null
			rock.position = safe_rock_position
			rock.rotation_degrees.y = yaw
			_scope.zone_root.add_child(rock)
			if _scope.zone_id == "old_mill":
				var rock_meshes: Variant = rock.find_children("*", "MeshInstance3D", true, false)
				if rock is MeshInstance3D:
					rock_meshes.append(rock)
				for raw_mesh in rock_meshes:
					var mesh: Variant = raw_mesh as MeshInstance3D
					if mesh.mesh == null:
						continue
					var bounds: Variant = mesh.mesh.get_aabb()
					var clearance: Variant = StaticBody3D.new()
					clearance.name = "RockCameraClearance"
					clearance.collision_layer = 1 << 6
					clearance.collision_mask = 0
					var collision: Variant = CollisionShape3D.new()
					var shape: Variant = preload("res://scripts/immutable_collision_shapes.gd").box(bounds.size)
					collision.shape = shape
					collision.position = bounds.get_center()
					clearance.add_child(collision)
					mesh.add_child(clearance)
			return rock
		_host._make_rubble(pos)
		return null
	if key == "crate":
		_host._make_prop_box("RouteCrate", pos + Vector3(0, 0.32 * scale_value.y, 0), Vector3(0.72, 0.64, 0.72) * scale_value, Color(0.20, 0.12, 0.065))
		return null
	if key == "barrel":
		_host._make_prop_box("RouteBarrel", pos + Vector3(0, 0.36 * scale_value.y, 0), Vector3(0.58, 0.72, 0.58) * scale_value, Color(0.17, 0.09, 0.045))
		return null
	if key == "fence":
		var fence_size = Vector3(1.9, 0.32, 0.18) * scale_value
		if abs(fposmod(yaw, 180.0) - 90.0) < 2.0:
			fence_size = Vector3(0.18, 0.32, 1.9) * scale_value
		_host._make_prop_box("RouteFence", pos + Vector3(0, 0.46, 0), fence_size, Color(0.15, 0.085, 0.045))
		return null
	var node = _host._make_role_visual(role_name, "environment", scale_value)
	if node == null:
		return null
	node.position = pos
	node.rotation_degrees.y = yaw
	_scope.zone_root.add_child(node)
	return node
func _make_role_visual(role_name: String, category: String, scale_value: Vector3) -> Node3D:
	if role_name == "" or _host.asset_helper == null:
		return null
	if _host._compatibility_budget_mode() and category == "environment":
		var balanced_environment_roles: Variant = [
			"greyfen_door_facade", "greyfen_window_facade", "greyfen_chimney",
			"greyfen_roof", "cart",
			"forest_tree", "forest_tree_variant", "forest_tree_secondary", "forest_rock", "forest_bush",
			"castle_wall", "castle_arch", "castle_roof", "castle_door",
			"castle_bookcase", "castle_chair", "castle_bench", "castle_table",
			"castle_weapon_stand", "castle_lantern",
		]
		if str(_host.settings.settings.get("quality_preset", "balanced")) == "potato" or role_name not in balanced_environment_roles:
			return null
	var node: Node3D
	if category == "characters":
		var visual_role = _host._visual_role_for_legacy_character(role_name)
		if visual_role != "" and (_host.asset_helper != null) and (_host.asset_helper != null) and _host.asset_helper.has_visual_role(visual_role):
			node = _host.asset_helper.spawn_visual_role(visual_role, "characters", role_name)
			if node != null and not node.name.ends_with("_placeholder"):
				return node
			if node != null:
				node.queue_free()
		node = _host.asset_helper.spawn_character(role_name)
	elif category == "enemies":
		if (_host.asset_helper != null) and (_host.asset_helper != null) and _host.asset_helper.has_visual_role(role_name):
			node = _host.asset_helper.spawn_visual_role(role_name, "enemies")
		else:
			node = _host.asset_helper.spawn_enemy(role_name)
	else:
		node = _host.asset_helper.spawn_environment(role_name)
	if node == null or node.name.ends_with("_placeholder"):
		if node != null:
			node.queue_free()
		return null
	if category == "enemies":
		_host.asset_helper.apply_normalized_scale(node, scale_value.y)
	elif category == "characters":
		pass
	else:
		node.scale = scale_value
	return node
func _environment_role_scale(role_name: String, target_size: Vector3) -> Vector3:
	var normalized_size: Vector3 = _host.ENVIRONMENT_ROLE_NORMALIZED_SIZE.get(role_name, Vector3.ZERO)
	if normalized_size == Vector3.ZERO:
		push_error("No fitted environment bounds registered for role '%s'" % role_name)
		return Vector3.ONE
	return Vector3(
		target_size.x / maxf(normalized_size.x, 0.001),
		target_size.y / maxf(normalized_size.y, 0.001),
		target_size.z / maxf(normalized_size.z, 0.001)
	)
func _make_deadfall(pos: Vector3) -> void:
	if _host._is_river_excluded(pos,1.8):
		return
	if _scope.spatial_service != null:
		_scope.spatial_service.add_presence_landmark("scavenge", pos, 1.0)
	var rotation: Variant = Vector3(deg_to_rad(88.0), deg_to_rad(_host._scene_randf_range(-20.0, 20.0)), deg_to_rad(_host._scene_randf_range(-8.0, 8.0)))
	_scope.deadfall_batch_data.append(Transform3D(Basis.from_euler(rotation), pos + Vector3(0, 0.35, 0)))
func _make_crow_silhouettes() -> void:
	var silhouette_mesh: Variant = SphereMesh.new()
	silhouette_mesh.radial_segments = 12
	silhouette_mesh.rings = 7
	var index: Variant = 0
	for item in [
		[Vector3(-8.5, 5.8, -11.5), -14.0],
		[Vector3(10.2, 5.5, -10.6), 18.0]
	]:
		var root: Variant = Node3D.new()
		root.name = "CrowSilhouette"
		root.position = item[0]
		root.rotation_degrees.y = float(item[1])
		_host.write_construction_tag(root, "motion_type", "bird")
		_host.write_construction_tag(root, "wildlife_reactive", true)
		_host.write_construction_tag(root, "motion_phase", float(index) * 1.7)
		_host.write_construction_tag(root, "motion_amount", 4.0)
		_scope.zone_root.add_child(root)
		_host._add_crow_part(root, "CrowBody", silhouette_mesh, Vector3(0, 0, 0), Vector3(0.18, 0.12, 0.30), Color(0.010, 0.010, 0.012))
		_host._add_crow_part(root, "CrowHead", silhouette_mesh, Vector3(0, 0.04, -0.13), Vector3(0.12, 0.11, 0.13), Color(0.016, 0.016, 0.018))
		var beak_mesh: Variant = CylinderMesh.new()
		beak_mesh.top_radius = 0.0
		beak_mesh.bottom_radius = 0.055
		beak_mesh.height = 0.16
		beak_mesh.radial_segments = 8
		_host._add_crow_part(root, "CrowBeak", beak_mesh, Vector3(0, 0.04, -0.22), Vector3(0.72, 0.72, 1.0), Color(0.15, 0.12, 0.08), Vector3(-90, 0, 0))
		_host._add_crow_part(root, "CrowWingLeft", silhouette_mesh, Vector3(-0.18, 0.0, -0.01), Vector3(0.30, 0.035, 0.13), Color(0.008, 0.008, 0.010), Vector3(0, 0, -18))
		_host._add_crow_part(root, "CrowWingRight", silhouette_mesh, Vector3(0.18, 0.0, -0.01), Vector3(0.30, 0.035, 0.13), Color(0.008, 0.008, 0.010), Vector3(0, 0, 18))
		_host._add_crow_part(root, "CrowTail", silhouette_mesh, Vector3(0, -0.02, 0.24), Vector3(0.12, 0.04, 0.24), Color(0.008, 0.008, 0.010), Vector3(18, 0, 0))
		index += 1
func _make_fake_fog_bank(pos: Vector3) -> void:
	_host._make_visual_box("LowColdFogBank", pos + Vector3(0, 0.07, 0), Vector3(1.6, 0.10, 0.55), Color(0.105, 0.125, 0.118))
func _make_herb(id: String, pos: Vector3, color: Color) -> Variant:
	return _host._make_named_interactable(id, "herb", "Gather %s" % id.capitalize(), pos, color, Vector3(0.35, 0.35, 0.35))
func _make_black_feather_scatter(base_name: String, center: Vector3, count: int, spread: float) -> void:
	for i in range(count):
		var offset = Vector3(_host._scene_randf_range(-spread, spread), 0.0, _host._scene_randf_range(-spread * 0.55, spread * 0.55))
		var feather = _host._make_visual_box(base_name, center + offset, Vector3(_host._scene_randf_range(0.24, 0.42), 0.022, 0.070), Color(0.010, 0.010, 0.012))
		feather.rotation_degrees.y = _host._scene_randf_range(-35.0, 35.0)
