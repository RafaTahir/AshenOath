extends "res://scripts/game.gd"

var candidate_building := false
var candidate_start_requested := false
var candidate_report: Dictionary = {}

func _start_new_game_world() -> void:
	if candidate_building:
		candidate_start_requested = true
		return
	super._start_new_game_world()

func _prewarm_greyfen_after_menu_frame() -> void:
	candidate_building = true
	var started := Time.get_ticks_usec()
	await super._prewarm_greyfen_after_menu_frame()
	var prepared := route_zone_cache.get("greyfen") as Node3D
	if prepared == null or resource_shutdown_prepared:
		candidate_building = false
		return
	zone_root = prepared
	spatial_service = greyfen_prewarm_spatial_service
	hud.set_new_game_ready(false)
	hud.set_new_game_status("Preparing the complete opening...")
	var prior_pause := get_tree().paused
	get_tree().paused = false
	var already_built: Array[String] = [
		"opening_river_visual", "opening_terrain", "opening_lighting",
		"gameplay_population", "gameplay_crowd_0", "gameplay_crowd_1",
		"gameplay_place_0", "gameplay_place_1", "gameplay_place_2", "gameplay_place_3", "gameplay_place_4",
		"gameplay_common_table", "gameplay_barrel_board",
		"gameplay_crowd_2", "gameplay_crowd_3", "gameplay_crowd_4", "gameplay_crowd_5",
		"gameplay_crowd_6", "gameplay_crowd_7", "gameplay_crowd_8", "gameplay_crowd_9",
		"village_house_0", "village_house_1", "village_house_2", "village_house_3",
		"village_architectural_details_0", "village_architectural_details_1", "village_architectural_details_2",
		"village_architectural_details_3", "village_architectural_details_4",
	]
	var built_ms := 0.0
	for stage in OPENING_DETAIL_STAGES:
		if stage in already_built or stage.begins_with("gameplay_visual_"):
			continue
		var stage_started := Time.get_ticks_usec()
		environment_batches_flushed = false
		var result := ZoneCompositionRouter.build_core_detail_stage(self, "greyfen", stage)
		if not bool(result.get("ok", false)):
			push_error("Residency candidate stage failed: " + stage)
			candidate_building = false
			return
		_flush_environment_batches()
		_clear_environment_batch_buffers()
		built_ms += float(Time.get_ticks_usec() - stage_started) / 1000.0
		await RenderingServer.frame_post_draw
	_validate_zone_render_resources(prepared)
	visual_director.set_opening_boot_budget(false)
	visual_director.refresh_zone_lighting(prepared)
	prepared.set_meta("opening_build_profile", "complete")
	prepared.set_meta("opening_detail_complete", true)
	prepared.set_meta("opening_boot_materials_restored", true)
	var equivalence := _static_equivalence(prepared)
	var warm_report: Dictionary = await _warm_final_static_meshes(prepared)
	candidate_report = {"complete_boot_ms": float(Time.get_ticks_usec() - started) / 1000.0,
		"additional_build_cpu_ms": built_ms, "static_residency": warm_report,
		"zone_nodes": prepared.find_children("*", "", true, false).size(), "static_equivalence": equivalence}
	var file := FileAccess.open("D:/Temp/AshenOath/static_scene_ownership_20260927/readiness_candidate_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(candidate_report, "\t"))
	file.close()
	print("MESH_RESIDENCY_CANDIDATE " + JSON.stringify(candidate_report))
	get_tree().paused = prior_pause
	zone_root = null
	spatial_service = null
	candidate_building = false
	hud.set_new_game_ready(true)
	if candidate_start_requested or new_game_start_pending:
		super._start_new_game_world()

func _warm_final_static_meshes(prepared: Node3D) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(96, 96)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.position = Vector3(0, 0, 4)
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	viewport.add_child(light)
	var count := 0
	var draw_times: Array[float] = []
	var geometries := prepared.find_children("*", "GeometryInstance3D", true, false)
	for raw_node in geometries:
		var source := raw_node as GeometryInstance3D
		if source is MeshInstance3D and (source.mesh == null or source.skin != null or source.skeleton != NodePath("")):
			continue
		if not (source is MeshInstance3D or source is MultiMeshInstance3D):
			continue
		if source is MultiMeshInstance3D and (source.multimesh == null or source.multimesh.mesh == null):
			continue
		var preview := source.duplicate(0) as GeometryInstance3D
		for child in preview.get_children():
			preview.remove_child(child)
			child.free()
		preview.set_script(null)
		preview.process_mode = Node.PROCESS_MODE_DISABLED
		preview.visible = true
		preview.visibility_range_begin = 0.0
		preview.visibility_range_end = 0.0
		preview.layers = 1
		var bounds := preview.get_aabb()
		var extent := maxf(maxf(bounds.size.x, bounds.size.y), bounds.size.z)
		var factor := 1.5 / maxf(extent, 0.01)
		preview.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * factor), -(bounds.position + bounds.size * 0.5) * factor)
		viewport.add_child(preview)
		var draw_started := Time.get_ticks_usec()
		await RenderingServer.frame_post_draw
		draw_times.append(float(Time.get_ticks_usec() - draw_started) / 1000.0)
		viewport.remove_child(preview)
		preview.free()
		count += 1
	viewport.queue_free()
	await get_tree().process_frame
	return {"mesh_count": count, "draw_wait_ms": draw_times}

func _static_equivalence(prepared: Node3D) -> Dictionary:
	var reference: Node3D = load("D:/Temp/AshenOath/static_scene_ownership_20260927/static_snapshot.scn").instantiate()
	var expected: Dictionary = {}
	var actual: Dictionary = {}
	for child in reference.get_children():
		var key := _geometry_key(child, child.transform)
		expected[key] = int(expected.get(key, 0)) + 1
	_collect_static_keys(prepared, prepared, actual)
	var matches := expected == actual
	if not matches:
		push_error("Final static scene equivalence failed: reference=%d candidate=%d" % [reference.get_child_count(), _key_count(actual)])
	var result := {"matches": matches, "reference_count": reference.get_child_count(), "actual_count": _key_count(actual)}
	reference.free()
	return result

func _key_count(keys: Dictionary) -> int:
	var count := 0
	for value in keys.values():
		count += int(value)
	return count

func _collect_static_keys(node: Node, prepared: Node3D, keys: Dictionary) -> void:
	if node != prepared and (node.get_script() != null or node is CollisionObject3D and not node is StaticBody3D or node is Skeleton3D or node is AnimationMixer):
		return
	if node.name == "LivingRiverSection" or bool(node.get_meta("night_only_geometry", false)):
		return
	if node is GeometryInstance3D and (node is MeshInstance3D or node is MultiMeshInstance3D):
		if node.material_override is ShaderMaterial or node is MeshInstance3D and node.skin != null:
			return
		var key := _geometry_key(node, prepared.global_transform.affine_inverse() * node.global_transform)
		keys[key] = int(keys.get(key, 0)) + 1
	for child in node.get_children():
		_collect_static_keys(child, prepared, keys)

func _geometry_key(node: GeometryInstance3D, placement: Transform3D) -> String:
	var data: Array = [node.get_class(), placement]
	for property in ["layers", "cast_shadow", "lod_bias", "visibility_range_begin", "visibility_range_end", "visibility_range_begin_margin", "visibility_range_end_margin", "visibility_range_fade_mode", "extra_cull_margin", "ignore_occlusion_culling", "sorting_offset", "sorting_use_aabb_center"]:
		data.append(node.get(property))
	data.append(_material_key(node.material_override))
	data.append(_material_key(node.material_overlay))
	var mesh: Mesh = node.mesh if node is MeshInstance3D else node.multimesh.mesh
	for surface in mesh.get_surface_count():
		data.append(mesh.surface_get_arrays(surface))
		data.append(mesh.get("_surfaces")[surface].get("lods", {}) if mesh is ArrayMesh else {})
		data.append(_material_key(mesh.surface_get_material(surface)))
		if node is MeshInstance3D:
			data.append(_material_key(node.get_surface_override_material(surface)))
	if node is MultiMeshInstance3D:
		data.append_array([node.multimesh.instance_count, node.multimesh.visible_instance_count, node.multimesh.transform_format, node.multimesh.use_colors, node.multimesh.use_custom_data, node.multimesh.buffer])
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(var_to_bytes(data))
	return digest.finish().hex_encode()

func _material_key(material: Material) -> Array:
	if material == null:
		return []
	var values: Array = [material.get_class()]
	for entry in material.get_property_list():
		var property := str(entry.name)
		if not (int(entry.usage) & PROPERTY_USAGE_STORAGE) or property.begins_with("resource_") or property == "script":
			continue
		var value = material.get(property)
		values.append(value.resource_path if value is Resource else value)
	return values
