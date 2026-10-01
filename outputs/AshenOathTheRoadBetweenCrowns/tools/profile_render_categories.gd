extends SceneTree

const OUTPUT := "D:/Temp/AshenOath/world001/render_categories.json"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("Render isolation requires graphical Compatibility")
		quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_move_to_foreground()
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.settings.set_quality_preset("balanced")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 60
	game._on_launch_accepted()
	var deadline := Time.get_ticks_msec() + 30000
	while not game.route_zone_cache.has("greyfen") and Time.get_ticks_msec() < deadline:
		await process_frame
	game._new_game()
	deadline = Time.get_ticks_msec() + 45000
	while game.zone_root == null or not game.zone_root.get_meta("opening_detail_complete", false):
		if Time.get_ticks_msec() >= deadline:
			push_error("Render isolation hydration timed out")
			await _shutdown(game)
			quit(1)
			return
		await process_frame
	if "--inventory" in OS.get_cmdline_user_args():
		var inventory_ok := _write_inventory(game)
		await _shutdown(game)
		quit(0 if inventory_ok else 1)
		return
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var results: Array[Dictionary] = []
	var sun_shadows_enabled: bool = game.visual_director.sun.shadow_enabled
	var local_lights: Array[Light3D] = []
	for raw_light in game.find_children("*", "Light3D", true, false):
		var light: Light3D = raw_light as Light3D
		if light != game.visual_director.sun and light != game.visual_director.moon and light.visible:
			local_lights.append(light)
	var categories := ["baseline", "sun_shadows_off", "local_lights_off", "core", "cemetery", "houses", "river", "imported", "named_batches", "unnamed_batches", "other_static", "static", "baseline_restored"]
	if "--named-only" in OS.get_cmdline_user_args():
		categories = ["baseline", "named_house", "named_trees", "named_props", "named_grass", "named_river", "named_misc", "baseline_restored"]
	elif "--other-only" in OS.get_cmdline_user_args():
		categories = ["baseline", "other_static", "baseline_restored"]
	elif "--material-only" in OS.get_cmdline_user_args():
		categories = ["baseline", "flat_lit_material", "flat_unshaded_material", "baseline_restored"]
	elif "--vertex-only" in OS.get_cmdline_user_args():
		categories = ["baseline", "vertex_lit_material", "baseline_restored"]
	elif "--filter-only" in OS.get_cmdline_user_args():
		categories = ["baseline", "linear_filter_material", "baseline_restored"]
	elif "--texture-only" in OS.get_cmdline_user_args():
		categories = ["baseline", "no_albedo_texture", "baseline_restored"]
	elif "--shrine-only" in OS.get_cmdline_user_args():
		categories = ["baseline", "shrine_garden", "shrine_cloth", "shrine_all", "baseline_restored"]
	var flat_lit := StandardMaterial3D.new()
	flat_lit.albedo_color = Color(0.5, 0.5, 0.5)
	var flat_unshaded := StandardMaterial3D.new()
	flat_unshaded.albedo_color = Color(0.5, 0.5, 0.5)
	flat_unshaded.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for category in categories:
		var hidden: Array[Node3D] = []
		var paths: Array[String] = []
		var replaced_materials: Array[Dictionary] = []
		var vertex_materials: Array[Dictionary] = []
		var vertex_ids: Dictionary = {}
		if category == "sun_shadows_off":
			game.visual_director.sun.shadow_enabled = false
		if category == "local_lights_off":
			for light in local_lights:
				light.visible = false
		for raw_node in game.find_children("*", "GeometryInstance3D", true, false):
			var node: GeometryInstance3D = raw_node as GeometryInstance3D
			if not node.is_visible_in_tree():
				continue
			if category in ["flat_lit_material", "flat_unshaded_material"] and game.zone_root.is_ancestor_of(node):
				replaced_materials.append({"node": node, "material": node.material_override})
				node.material_override = flat_lit if category == "flat_lit_material" else flat_unshaded
			if category in ["vertex_lit_material", "linear_filter_material", "no_albedo_texture"] and game.zone_root.is_ancestor_of(node):
				var candidates: Array[Material] = []
				if node.material_override != null:
					candidates.append(node.material_override)
				var mesh: Mesh = null
				if node is MeshInstance3D:
					mesh = (node as MeshInstance3D).mesh
				elif node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh != null:
					mesh = (node as MultiMeshInstance3D).multimesh.mesh
				if mesh != null:
					for surface_index in range(mesh.get_surface_count()):
						var surface_material := mesh.surface_get_material(surface_index)
						if surface_material != null:
							candidates.append(surface_material)
				for candidate in candidates:
					if candidate is StandardMaterial3D and not vertex_ids.has(candidate.get_instance_id()):
						vertex_ids[candidate.get_instance_id()] = true
						vertex_materials.append({"material": candidate, "mode": candidate.shading_mode, "filter": candidate.texture_filter, "albedo": candidate.albedo_texture})
						if category == "vertex_lit_material":
							candidate.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
						elif category == "linear_filter_material":
							candidate.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
						else:
							candidate.albedo_texture = null
			var is_sky := false
			var is_actor := false
			var parent: Node = node
			while parent != game and parent != null:
				is_sky = is_sky or str(parent.name) in ["SkyGradientDome", "SunDisc", "MoonDisc", "AtmosphericSunLayer", "CloudLayer", "ProceduralStarField"]
				is_actor = is_actor or parent is CharacterBody3D
				parent = parent.get_parent()
			var path: String = str(game.get_path_to(node))
			var parts: PackedStringArray = path.split("/")
			var owner_name: String = parts[1] if parts.size() > 1 else ""
			var is_zone_static: bool = game.zone_root.is_ancestor_of(node) and not is_actor
			var is_batch: bool = node is MultiMeshInstance3D
			var is_core: bool = owner_name == "Gameplay_greyfen"
			var is_cemetery: bool = owner_name == "CemeteryAuthoredPresentation"
			var is_house: bool = owner_name.begins_with("DressedVillageHouse_") or owner_name == "GreyfenBlacksmithStoneShop"
			var is_river: bool = owner_name == "LivingRiverSection"
			var is_imported: bool = owner_name.begins_with("@Node3D@")
			var is_named_batch: bool = is_batch and not owner_name.begins_with("@MultiMeshInstance3D@")
			var is_unnamed_batch: bool = is_batch and not is_named_batch
			var is_other: bool = is_zone_static and not (is_core or is_cemetery or is_house or is_river or is_imported or is_batch)
			var batch_name := str(node.name)
			var named_house := batch_name.begins_with("HouseBatch_") or batch_name.begins_with("HouseModuleBatch_")
			var named_trees := batch_name.begins_with("AuthoredTreeBatch_")
			var named_props := batch_name.begins_with("WorldPropBatch_")
			var named_grass := batch_name == "GrassBatch"
			var named_river := batch_name.begins_with("River")
			var named_misc := is_named_batch and not (named_house or named_trees or named_props or named_grass or named_river)
			var shrine_garden := batch_name.begins_with("GreyfenShrineGarden")
			var shrine_cloth := batch_name.begins_with("HangingClothDrape_")
			var matches: bool = (category == "core" and is_core) or (category == "cemetery" and is_cemetery) or (category == "houses" and is_house) or (category == "river" and is_river) or (category == "imported" and is_imported) or (category == "named_batches" and is_named_batch) or (category == "unnamed_batches" and is_unnamed_batch) or (category == "other_static" and is_other) or (category == "static" and is_zone_static) or (category == "named_house" and is_named_batch and named_house) or (category == "named_trees" and is_named_batch and named_trees) or (category == "named_props" and is_named_batch and named_props) or (category == "named_grass" and is_named_batch and named_grass) or (category == "named_river" and is_named_batch and named_river) or (category == "named_misc" and named_misc) or (category == "shrine_garden" and shrine_garden) or (category == "shrine_cloth" and shrine_cloth) or (category == "shrine_all" and (shrine_garden or shrine_cloth))
			if matches:
				hidden.append(node)
				paths.append(path)
				node.visible = false
		await _frames(30)
		var row := await _sample()
		row["category"] = category
		row["hidden_paths"] = paths
		row["sun_shadows_initially_enabled"] = sun_shadows_enabled
		row["local_lights_count"] = local_lights.size()
		results.append(row)
		print("RENDER CATEGORY " + JSON.stringify(row))
		for node in hidden:
			node.visible = true
		for item in replaced_materials:
			item.node.material_override = item.material
		for item in vertex_materials:
			item.material.shading_mode = item.mode
			item.material.texture_filter = item.filter
			item.material.albedo_texture = item.albedo
		game.visual_director.sun.shadow_enabled = sun_shadows_enabled
		for light in local_lights:
			light.visible = true
	var output_path := "D:/Temp/AshenOath/world001/shrine_render_categories.json" if "--shrine-only" in OS.get_cmdline_user_args() else OUTPUT
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"scope": "stationary diagnostic; hidden scenery is never acceptance", "samples": results}, "\t"))
		file.close()
	else:
		push_error("Cannot write render diagnostic")
	await _shutdown(game)
	quit(0 if file != null else 1)

func _write_inventory(game: Node) -> bool:
	var rows: Array[Dictionary] = []
	for raw_node in game.zone_root.find_children("*", "MeshInstance3D", true, false):
		var node := raw_node as MeshInstance3D
		if node == null or node.mesh == null or not node.is_visible_in_tree():
			continue
		var relative := str(game.get_path_to(node))
		var parts := relative.split("/")
		var materials: Array[String] = []
		for surface_index in range(node.mesh.get_surface_count()):
			var material := node.get_active_material(surface_index)
			if material is StandardMaterial3D:
				var standard := material as StandardMaterial3D
				materials.append("%s:%s:%s" % [standard.resource_name, standard.albedo_color.to_html(true), str(standard.albedo_texture.resource_path) if standard.albedo_texture != null else ""])
			else:
				materials.append("missing" if material == null else material.get_class())
		var has_dynamic_ancestor := false
		var parent: Node = node
		while parent != game.zone_root and parent != null:
			if parent is CharacterBody3D or parent is Area3D or parent.get_script() != null:
				has_dynamic_ancestor = true
			parent = parent.get_parent()
		rows.append({
			"path": relative,
			"owner": parts[1] if parts.size() > 1 else "",
			"mesh_type": node.mesh.get_class(),
			"surfaces": node.mesh.get_surface_count(),
			"materials": materials,
			"position": [node.global_position.x, node.global_position.y, node.global_position.z],
			"dynamic_ancestor": has_dynamic_ancestor,
			"night_only": bool(node.get_meta("night_only_geometry", false)),
		})
	var path := "D:/Temp/AshenOath/world001/static_mesh_inventory.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write static mesh inventory")
		return false
	file.store_string(JSON.stringify({"scope": "hydrated Greyfen visual ownership only", "meshes": rows}, "\t"))
	file.close()
	print("STATIC INVENTORY meshes=%d path=%s" % [rows.size(), path])
	return true

func _sample() -> Dictionary:
	var start := Time.get_ticks_usec()
	var frames := 0
	var cpu := 0.0
	var draws := 0.0
	var primitives := 0.0
	while Time.get_ticks_usec() - start < 2500000:
		await process_frame
		frames += 1
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		primitives += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	return {"fps": frames * 1000000.0 / (Time.get_ticks_usec() - start), "render_cpu_ms": cpu / frames, "draws": draws / frames, "primitives": primitives / frames}

func _frames(count: int) -> void:
	for index in range(count):
		await process_frame

func _shutdown(game: Node) -> void:
	game.prepare_resource_shutdown()
	await _frames(20)
	game.finalize_resource_shutdown()
	await _frames(12)
	game.queue_free()
	await _frames(8)
	RenderingServer.force_sync()
