extends RefCounted
const Api = preload("res://scripts/core/zone_construction_api.gd")
const Scope = preload("res://scripts/core/zone_instance_scope.gd")
const TERRAIN_PATCHES_PER_UNIT := 8
var _host: Api
var _scope: Scope
const TreeBatches = preload("res://scripts/builders/tree_batch_builder.gd")
var tree_batches: TreeBatches
func _init(host: Api, scope: Scope) -> void:
	_host = host
	_scope = scope
	tree_batches = TreeBatches.new(host, scope)
func _append_prepared_detail(id: String) -> void:
	var entry: Variant = preload("res://scripts/prepared_static_batches.gd").entry(id)
	if entry.is_empty():
		return
	if _scope.environment_batches_flushed:
		_host._make_visual_box(entry.name, entry.position, entry.size, entry.color)
		return
	var pos: Vector3 = entry.position
	if _scope.zone_id not in ["record_hall", "undercroft"]:
		pos = _host.river_safe_position(pos, entry.size.z * 0.5 + 0.18)
	var record: Dictionary = entry
	if pos != entry.position:
		record = preload("res://scripts/static_multimesh_upload.gd").prepare_record(Transform3D(entry.transform.basis, pos), entry.color)
	_scope.visual_box_batch_data.append({"prepared": record, "color": entry.color})
func _make_prepared_prop(id: String) -> void:
	var entry: Variant = preload("res://scripts/prepared_static_batches.gd").entry(id)
	if not entry.is_empty():
		_host._make_prop_box(entry.name, entry.position, entry.size, entry.color, true, entry)
func _make_village_house_dressed(pos: Vector3, yaw: float, node_name: String) -> void:
	var house_variant: Variant = 0
	match node_name:
		"DressedVillageHouse_WestLane": house_variant = 1
		"DressedVillageHouse_EastLane": house_variant = 2
		"DressedVillageHouse_ShrineFrame": house_variant = 3
	var mesh_path: Variant = "res://assets_external/environment/village/GreyfenHouse_Authored.res" if house_variant == 0 else "res://assets_external/environment/village/GreyfenHouse_Authored_%d.res" % house_variant
	var authored_mesh: Variant = load(mesh_path) as ArrayMesh
	if authored_mesh == null or authored_mesh.get_surface_count() != 6:
		push_error("Required Greyfen house mesh is unavailable: " + node_name)
		return
	var root = Node3D.new()
	root.name = node_name
	root.add_to_group("first_route_house")
	root.add_to_group("greyfen_house")
	_host.write_construction_tag(root, "visible_house", true)
	_host.write_construction_tag(root, "house_variant", house_variant)
	root.position = pos
	root.rotation_degrees.y = yaw
	_scope.zone_root.add_child(root)
	_host._make_house_collision(root)
	var house_visual: Variant = MeshInstance3D.new()
	house_visual.name = "AuthoredHouse"
	house_visual.mesh = authored_mesh
	root.add_child(house_visual)
	var authored_tints: Variant = {
		"medieval_brick": Color(0.67, 0.65, 0.59),
		"plaster": [Color(0.76, 0.70, 0.58), Color(0.65, 0.68, 0.62), Color(0.78, 0.64, 0.48), Color(0.71, 0.72, 0.68)][house_variant],
		"timber": [Color(0.72, 0.57, 0.40), Color(0.62, 0.53, 0.43), Color(0.78, 0.54, 0.34), Color(0.53, 0.49, 0.43)][house_variant],
		"roof_tiles": [Color(0.76, 0.47, 0.37), Color(0.63, 0.51, 0.46), Color(0.82, 0.52, 0.39), Color(0.60, 0.59, 0.57)][house_variant],
		"glazing": Color(0.16, 0.22, 0.24),
		"metal": Color(0.34, 0.34, 0.32),
	}
	var house_quality: Variant = str(_host.settings.settings.get("quality_preset", "balanced"))
	for surface_index in authored_mesh.get_surface_count():
		var surface_name: Variant = authored_mesh.surface_get_name(surface_index)
		if not authored_tints.has(surface_name):
			push_error("Unknown authored Greyfen house surface: " + surface_name)
			return
		var material_role: Variant = surface_name if _host.world_materials.SURFACES.has(surface_name) else "metal"
		var surface_material: StandardMaterial3D = _host._mat(authored_tints[surface_name]) if surface_name == "glazing" else _host.world_materials.get_material(material_role, house_quality, authored_tints[surface_name], 0.0, false)
		house_visual.set_surface_override_material(surface_index, surface_material)
	_host.write_construction_tag(root, "roof_treatment", "authored_mesh")
	return
func _make_house_collision(parent: Node3D) -> void:
	var body = StaticBody3D.new()
	body.name = "HouseCollision"
	parent.add_child(body)
	var shape = CollisionShape3D.new()
	var box = preload("res://scripts/immutable_collision_shapes.gd").box(Vector3(4.2, 2.4, 3.4))
	shape.shape = box
	shape.position.y = 1.2
	body.add_child(shape)
	var camera_roof: Variant = StaticBody3D.new()
	camera_roof.name = "CameraRoofCollision"
	camera_roof.collision_layer = 1 << 6
	camera_roof.collision_mask = 0
	parent.add_child(camera_roof)
	var roof_shape: Variant = CollisionShape3D.new()
	var roof_box: Variant = preload("res://scripts/immutable_collision_shapes.gd").box(Vector3(5.0, 1.6, 4.2))
	roof_shape.shape = roof_box
	roof_shape.position.y = 3.2
	camera_roof.add_child(roof_shape)
	if int(_host.read_construction_tag(parent, "house_variant", 0)) == 1:
		for x in [-0.98, 0.98]:
			var post: Variant = CollisionShape3D.new()
			var post_box: Variant = preload("res://scripts/immutable_collision_shapes.gd").box(Vector3(0.12, 1.60, 0.12))
			post.shape = post_box
			post.position = Vector3(x, 0.95, -2.36)
			body.add_child(post)
func _make_multimesh_batch(node_name: String, mesh: Mesh, count: int, material: Material, use_colors: bool = false) -> MultiMeshInstance3D:
	var instance: Variant = MultiMeshInstance3D.new()
	instance.name = node_name
	instance.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var batch: Variant = MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = use_colors
	var base_mesh: Variant = mesh if mesh != null else _host.shared_box_mesh
	_host._ensure_mesh_surface_materials(base_mesh, _host._valid_material_or_fallback(null))
	batch.mesh = base_mesh
	batch.instance_count = count
	instance.multimesh = batch
	instance.material_override = null if material == null and base_mesh.get_surface_count() > 1 else _host._valid_material_or_fallback(material)
	instance.visibility_range_end = 58.0
	if _host._compatibility_budget_mode():
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scope.zone_root.add_child(instance)
	return instance
func _upload_static_batch(instance: MultiMeshInstance3D, transforms: Array, colors: Array = []) -> void:
	preload("res://scripts/static_multimesh_upload.gd").upload(instance.multimesh, transforms, colors, preload("res://scripts/performance_comparison_options.gd").enabled("static_bounds"))
func _flush_environment_batches() -> void:
	for phase in range(7):
		_host.flush_environment_batch_step(phase)
func flush_environment_batch_step(phase: int) -> void:
	if _host.context.zone_root == null:
		return
	match phase:
		0: _host._publish_environment_0()
		1: _host._publish_environment_1()
		2: _host._publish_environment_2()
		3: _host._publish_environment_3()
		4: _host._publish_environment_4()
		5: _host._publish_environment_5()
		6: _host._publish_environment_6()
	if phase == 6:
		_scope.environment_batches_flushed = true
func flush_environment_next_unit() -> bool:
	if _scope.environment_batches_flushed:
		return true
	if _scope.stream_environment_units.is_empty():
		var routes: Array[Dictionary] = preload("res://scripts/world_sector_manifest.gd").connections(_scope.zone_id,_host.story_state)
		var roads := _scope.zone_root.get_node_or_null("ConnectedRoads")
		for index in routes.size():
			if roads == null or not roads.has_node("RoadTo_" + str(routes[index].target)):
				_scope.stream_environment_units.append(_host._publish_connected_route.bind(index))
		var terrain_groups := _terrain_patch_groups()
		for key: String in terrain_groups:
			var group: Dictionary = terrain_groups[key]
			var items: Array = group.items
			var surface := SurfaceTool.new()
			for start in range(0, items.size(), TERRAIN_PATCHES_PER_UNIT):
				_scope.stream_environment_units.append(_append_terrain_patches.bind(surface, items, start, mini(start + TERRAIN_PATCHES_PER_UNIT, items.size())))
			_scope.stream_environment_units.append(_publish_terrain_group.bind(surface, key, group.material))
		if not _scope.visual_box_batch_data.is_empty():
			_scope.stream_environment_units.append(_host._publish_environment_1)
		for key in _scope.house_batch_data: _scope.stream_environment_units.append(_host._publish_environment_2.bind(str(key)))
		for key in _scope.house_module_batch_data: _scope.stream_environment_units.append(_host._publish_environment_3.bind(str(key)))
		for key in _scope.prop_batch_data: _scope.stream_environment_units.append(_host._publish_environment_4.bind(str(key)))
		if not _scope.tree_batch_data.is_empty():
			_scope.stream_environment_units.append_array(tree_batches.publication_units())
		for index: int in _host.zone_actor_spawner.pending_ecology_indices():
			_scope.stream_environment_units.append(_host._build_design_pack_ecology.bind(index))
		if not _scope.deadfall_batch_data.is_empty():
			_scope.stream_environment_units.append(_host._publish_environment_6.bind(false))
	if _scope.stream_environment_cursor < _scope.stream_environment_units.size():
		_scope.stream_environment_units[_scope.stream_environment_cursor].callv([])
		_scope.stream_environment_cursor += 1
	var complete := _scope.stream_environment_cursor >= _scope.stream_environment_units.size()
	if complete:
		_scope.environment_batches_flushed = true
		_scope.stream_environment_units.clear()
		_scope.stream_environment_cursor = 0
	return complete
func _publish_connected_route(index: int) -> void:
	preload("res://scripts/connected_route_geometry.gd").install(_host.context,index)
func _publish_environment_0(install_routes: bool = true) -> void:
	if install_routes: preload("res://scripts/connected_route_geometry.gd").install(ZoneBuildContext.new(_host,_scope.zone_id))
	var groups := _terrain_patch_groups()
	for key: String in groups:
		var group: Dictionary = groups[key]
		var items: Array = group.items
		var surface := SurfaceTool.new()
		_append_terrain_patches(surface, items, 0, items.size())
		_publish_terrain_group(surface, key, group.material)

func _terrain_patch_groups() -> Dictionary:
	var terrain_groups: Dictionary = {}
	for item in _scope.terrain_patch_batch_data:
		var terrain_key := str(item.material.get_instance_id())
		if not terrain_groups.has(terrain_key):
			terrain_groups[terrain_key] = {"material":item.material,"items":[]}
		terrain_groups[terrain_key].items.append(item)
	return terrain_groups

func _append_terrain_patches(surface: SurfaceTool, items: Array, start: int, end: int) -> void:
	for index in range(start, end):
		var marker: Node3D = items[index].node
		var patch_size: Vector3 = items[index].size
		var patch_mesh: ArrayMesh = _host.world_materials.make_organic_ground_patch(patch_size, marker.position, marker.basis) if _scope.zone_id == "wychwood" else _host.world_materials.make_tiled_ground_patch(patch_size, marker.position, marker.basis)
		surface.append_from(patch_mesh, 0, marker.transform)
		marker.queue_free()

func _publish_terrain_group(surface: SurfaceTool, key: String, material: Material) -> void:
	var terrain_batch := MeshInstance3D.new()
	terrain_batch.name = "TerrainPatchBatch_%s" % key
	terrain_batch.mesh = surface.commit()
	terrain_batch.material_override = material
	_scope.zone_root.add_child(terrain_batch)
func _publish_environment_1() -> void:
	var visual_groups: Dictionary = {}
	var separate_alpha: Variant = preload("res://scripts/performance_comparison_options.gd").enabled("alpha_batches")
	for item in _scope.visual_box_batch_data:
		var color: Color = item.color
		var use_instance_colors: bool = _scope.zone_id != "record_hall"
		var visual_key: Variant = "instance_colors" if use_instance_colors else color.to_html(true)
		var transparent: Variant = separate_alpha and color.a < 0.999
		if transparent:
			visual_key = "alpha_" + visual_key
		var night_only: bool = _host.read_construction_tag(item.node, "night_only_geometry", false) if item.has("node") else false
		if night_only:
			visual_key = "night_" + visual_key
		if not visual_groups.has(visual_key):
			var material: StandardMaterial3D
			if use_instance_colors:
				if not _host.material_cache.has("detail_instance_colors"):
					var shared_material: Variant = StandardMaterial3D.new()
					shared_material.roughness = 0.9
					shared_material.vertex_color_use_as_albedo = true
					_host.material_cache["detail_instance_colors"] = shared_material
				material = _host.material_cache["detail_instance_colors"]
			else:
				material = _host._mat(color)
			if transparent:
				material = material.duplicate() as StandardMaterial3D
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			visual_groups[visual_key] = {"material": material, "colors": use_instance_colors, "night_only": night_only, "items": []}
		visual_groups[visual_key].items.append(item)
	for visual_key in visual_groups:
		var group: Dictionary = visual_groups[visual_key]
		var items: Array = group.items
		var detail_batch: Variant = _host._make_multimesh_batch("AuthoredDetailBatch_%s" % visual_key, _host.shared_box_mesh, items.size(), group.material, group.colors)
		if group.night_only:
			_host.write_construction_tag(detail_batch, "night_only_geometry", true)
		var detail_transforms: Array = []
		var detail_colors: Array = []
		for i in range(items.size()):
			if items[i].has("prepared"):
				detail_transforms.append(items[i].prepared)
				if group.colors:
					detail_colors.append(items[i].color)
				continue
			var marker: Node3D = items[i].node
			var detail_size: Vector3 = items[i].size
			detail_transforms.append(Transform3D(marker.basis.scaled(detail_size), marker.position))
			if group.colors:
				detail_colors.append(items[i].color)
			marker.queue_free()
		_host._upload_static_batch(detail_batch, detail_transforms, detail_colors)
func _publish_environment_2(only_key: String = "") -> void:
	var keys := _scope.house_batch_data.keys() if only_key.is_empty() else [only_key]
	for house_key: String in keys:
		var house_group: Dictionary = _scope.house_batch_data.get(house_key, {})
		var house_transforms: Array = house_group.get("transforms", [])
		if house_transforms.is_empty():
			continue
		var house_batch: Variant = _host._make_multimesh_batch(
			"HouseBatch_%s" % str(house_key).replace(":", "_"),
			_host.shared_box_mesh,
			house_transforms.size(),
			house_group.material,
			true
		)
		if str(house_key).begins_with("emissive_window:"):
			_host.write_construction_tag(house_batch, "night_window_material", house_group.material)
			_host.write_construction_tag(house_batch, "night_window_color", house_group.material.albedo_color)
		_host._upload_static_batch(house_batch, house_transforms, house_group.colors)
func _publish_environment_3(only_key: String = "") -> void:
	var keys := _scope.house_module_batch_data.keys() if only_key.is_empty() else [only_key]
	for batch_key: String in keys:
		var module_group: Dictionary = _scope.house_module_batch_data.get(batch_key, {})
		var module_transforms: Array = module_group.get("transforms", [])
		if module_transforms.is_empty():
			continue
		var module_batch: Variant = _host._make_multimesh_batch(
			"HouseModuleBatch_%s" % batch_key,
			module_group.mesh,
			module_transforms.size(),
			null
		)
		module_batch.material_override = null
		_host._upload_static_batch(module_batch, module_transforms)
func _publish_environment_4(only_key: String = "") -> void:
	var keys := _scope.prop_batch_data.keys() if only_key.is_empty() else [only_key]
	for batch_key: String in keys:
		var entry: Dictionary = _scope.prop_batch_data.get(batch_key, {})
		var transforms: Array = entry.get("transforms", [])
		if transforms.is_empty():
			continue
		var batch: Variant = _host._make_multimesh_batch("WorldPropBatch_%s" % str(batch_key), _host.shared_box_mesh, transforms.size(), entry.get("material"))
		_host._upload_static_batch(batch, transforms)
func _publish_environment_5() -> void:
	tree_batches.flush()
func _publish_environment_6(include_ecology: bool = true) -> void:
	if include_ecology: _host._build_design_pack_ecology()
	if not _scope.deadfall_batch_data.is_empty():
		var deadfall_mesh: Variant = CylinderMesh.new()
		deadfall_mesh.top_radius = 0.16
		deadfall_mesh.bottom_radius = 0.22
		deadfall_mesh.height = 3.4
		deadfall_mesh.radial_segments = 7
		var deadfalls: Variant = _host._make_multimesh_batch("DeadfallBatch", deadfall_mesh, _scope.deadfall_batch_data.size(), _host.world_materials.get_material("timber", str(_host.settings.settings.get("quality_preset", "balanced")), Color(0.34, 0.25, 0.17), 0.0, false))
		_host._upload_static_batch(deadfalls, _scope.deadfall_batch_data)
func _ensure_mesh_surface_materials(mesh: Mesh, fallback: Material) -> int:
	if mesh == null or fallback == null:
		return 0
	var applied: Variant = 0
	for surface_index in range(mesh.get_surface_count()):
		if mesh.surface_get_material(surface_index) == null:
			mesh.surface_set_material(surface_index, fallback)
			applied += 1
	return applied
func _make_collision_box(name: String, pos: Vector3, size: Vector3) -> void:
	ZoneBuildContext.add_collision_box(_scope.zone_root, name, pos, size)
