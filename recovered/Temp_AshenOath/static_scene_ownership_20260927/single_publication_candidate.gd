extends "D:/Temp/AshenOath/static_scene_ownership_20260927/mesh_residency_candidate.gd"

# Diagnostic only: one final graph, no simplified boot materials or later rebuild.
func _prewarm_greyfen_after_menu_frame() -> void:
	if game_started or zone_root != null or route_zone_cache.has("greyfen"):
		return
	candidate_building = true
	var started := Time.get_ticks_usec()
	var prior_pause := get_tree().paused
	var service := ZoneSpatialService.new()
	service.name = "GreyfenPrewarmSpatialService"
	add_child(service)
	service.configure("greyfen", _river_center("greyfen"), _zone_half_extents("greyfen"))
	spatial_service = service
	zone_root = Node3D.new()
	zone_root.name = "greyfen"
	zone_root.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(zone_root)
	var prepared := zone_root
	var layers := ZoneSceneCatalog.attach("greyfen", prepared, ["gameplay"])
	if not bool(layers.get("ok", false)):
		push_error("Single-publication authored core failed")
		candidate_building = false
		return
	runtime_light_count = 0
	_clear_environment_batch_buffers()
	environment_batches_flushed = false
	var core := ZoneCompositionRouter.build_core(self, "greyfen", "opening_boot")
	if not bool(core.get("ok", false)):
		push_error("Single-publication core failed")
		candidate_building = false
		return
	for stage in ["opening_river_visual", "opening_terrain"]:
		ZoneCompositionRouter.build_core_detail_stage(self, "greyfen", stage)
	for bucket in OPENING_GAMEPLAY_VISUAL_BUCKETS:
		ZoneCompositionRouter.build_core_detail_stage(self, "greyfen", "gameplay_visual_%d" % bucket)
	_flush_environment_batches()
	_clear_environment_batch_buffers()
	_add_visual_100_layer("greyfen")
	_apply_first_route_materials(prepared)
	world_materials.prewarm_surfaces(["forest_ground", "cobblestone", "wet_mud", "medieval_brick", "plaster", "timber", "roof_tiles"], str(settings.settings.get("quality_preset", "balanced")))
	asset_helper.request_resource_paths(CharacterPresentation.OPENING_OCCUPATION_PROP_PATHS)
	var roles: Array[String] = []
	for actor_id in OPENING_NAMED_ACTOR_IDS:
		roles.append(_role_for_interactable(actor_id))
	asset_helper.request_role_resources(roles)
	var resources_deadline := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < resources_deadline:
		var surfaces: Error = world_materials.poll_prewarm()
		var actors: Error = asset_helper.poll_role_resources()
		if surfaces not in [OK, ERR_BUSY] or actors not in [OK, ERR_BUSY]:
			push_error("Single-publication required resource failed")
			candidate_building = false
			return
		if surfaces == OK and actors == OK:
			break
		await get_tree().process_frame
	if world_materials.poll_prewarm() != OK or asset_helper.poll_role_resources() != OK:
		push_error("Single-publication resource timeout")
		candidate_building = false
		return
	opening_well_mesh = load("res://assets_external/environment/village/GreyfenWell_Authored.res") as ArrayMesh
	var build_ms := 0.0
	var stage_count := 0
	for stage in OPENING_DETAIL_STAGES:
		if stage in ["opening_river_visual", "opening_terrain"] or stage.begins_with("gameplay_visual_"):
			continue
		var stage_started := Time.get_ticks_usec()
		environment_batches_flushed = false
		var result := ZoneCompositionRouter.build_core_detail_stage(self, "greyfen", stage)
		if not bool(result.get("ok", false)):
			push_error("Single-publication stage failed: " + stage)
			candidate_building = false
			return
		_flush_environment_batches()
		_clear_environment_batch_buffers()
		build_ms += float(Time.get_ticks_usec() - stage_started) / 1000.0
		stage_count += 1
	_validate_zone_render_resources(prepared)
	prepared.set_meta("opening_build_profile", "complete")
	prepared.set_meta("opening_detail_complete", true)
	prepared.set_meta("opening_boot_materials_restored", true)
	prepared.set_meta("prewarm_navigation_pending", true)
	greyfen_prewarm_spatial_service = service
	_spawn_player(Vector3(0, 1, 9.8))
	player.set_transition_locked(true)
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	prepared.process_mode = Node.PROCESS_MODE_PAUSABLE
	visual_director.set_opening_boot_budget(false)
	visual_director.apply_zone("greyfen", prepared)
	visual_director.refresh_zone_lighting(prepared)
	get_tree().paused = false
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var warm: Dictionary = await _warm_final_static_meshes(prepared)
	get_tree().paused = prior_pause
	_cache_route_zone("greyfen", prepared, [], _zone_state_signature(), true, false, false)
	zone_root = null
	spatial_service = null
	candidate_report = {"complete_boot_ms": float(Time.get_ticks_usec() - started) / 1000.0,
		"additional_build_cpu_ms": build_ms, "stages": stage_count,
		"static_residency": warm, "zone_nodes": prepared.find_children("*", "", true, false).size(),
		"static_equivalence": {"matches": false, "status": "not evaluated; performance discriminant only"}}
	print("SINGLE_PUBLICATION_CANDIDATE " + JSON.stringify(candidate_report))
	candidate_building = false
	hud.set_new_game_ready(true)
	hud.set_new_game_status("Greyfen is ready.")
	if candidate_start_requested or new_game_start_pending:
		super._start_new_game_world()

func _warm_final_static_meshes(prepared: Node3D) -> Dictionary:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		push_error("Single-publication needs the actual gameplay camera")
		return {"error": "missing camera"}
	var previews := Node3D.new()
	add_child(previews)
	var count := 0
	var batch_count := 0
	var waits: Array[float] = []
	for source in prepared.find_children("*", "GeometryInstance3D", true, false):
		if source is MeshInstance3D and (source.mesh == null or source.skin != null):
			continue
		if source is MultiMeshInstance3D and (source.multimesh == null or source.multimesh.mesh == null):
			continue
		if not (source is MeshInstance3D or source is MultiMeshInstance3D):
			continue
		var preview := source.duplicate(0) as GeometryInstance3D
		for child in preview.get_children():
			child.free()
		preview.set_script(null)
		preview.process_mode = Node.PROCESS_MODE_DISABLED
		preview.visible = true
		preview.visibility_range_begin = 0
		preview.visibility_range_end = 0
		preview.layers = 1
		var bounds := preview.get_aabb()
		var factor := 0.7 / maxf(maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z)), 0.01)
		var offset := Vector3(float(batch_count % 4) * 0.8 - 1.2, float(batch_count / 4) * 0.8 - 1.2, -5.0)
		previews.add_child(preview)
		preview.global_transform = camera.global_transform * Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * factor), offset - bounds.get_center() * factor)
		count += 1
		batch_count += 1
		if batch_count == 16:
			var draw_started := Time.get_ticks_usec()
			await RenderingServer.frame_post_draw
			waits.append(float(Time.get_ticks_usec() - draw_started) / 1000.0)
			for node in previews.get_children():
				node.free()
			batch_count = 0
	if batch_count > 0:
		var draw_started := Time.get_ticks_usec()
		await RenderingServer.frame_post_draw
		waits.append(float(Time.get_ticks_usec() - draw_started) / 1000.0)
	previews.queue_free()
	await get_tree().process_frame
	return {"mesh_count": count, "batch_draw_wait_ms": waits}
