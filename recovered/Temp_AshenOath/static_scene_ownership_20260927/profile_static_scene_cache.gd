extends SceneTree

const DIR := "D:/Temp/AshenOath/static_scene_ownership_20260927"
var failures: Array[String] = []
var report: Dictionary = {"scope": "diagnostic only, not cold-cache or ticket acceptance"}
var originals: Array[GeometryInstance3D] = []
var original_visibility: Array[bool] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("Static scene ownership requires a graphical renderer")
		quit(1)
		return
	if OS.get_cmdline_user_args().has("--isolated-publication"):
		await _isolated_publication()
		return
	DirAccess.make_dir_recursive_absolute(DIR)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_move_to_foreground()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 60
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.settings.set_quality_preset("balanced")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 60
	report["benchmark_environment"] = {
		"max_fps": Engine.max_fps,
		"vsync": DisplayServer.window_get_vsync_mode(),
		"window_size": str(DisplayServer.window_get_size()),
		"viewport_size": str(root.size),
		"resolution_scale": game.settings.settings.get("resolution_scale"),
		"quality": game.settings.settings.get("quality_preset"),
		"gpu": RenderingServer.get_video_adapter_name(),
	}
	game._on_launch_accepted()
	var deadline := Time.get_ticks_msec() + 30000
	while not game.route_zone_cache.has("greyfen") and Time.get_ticks_msec() < deadline:
		await process_frame
	game._new_game()
	deadline = Time.get_ticks_msec() + 45000
	while (game.zone_root == null or not bool(game.zone_root.get_meta("opening_detail_complete", false))) and Time.get_ticks_msec() < deadline:
		await process_frame
	if game.zone_root == null or not bool(game.zone_root.get_meta("opening_detail_complete", false)):
		_fail("Complete source scene unavailable")
		await _shutdown(game)
		return
	var template := Node3D.new()
	template.name = "StaticSceneSnapshot"
	var reuse := OS.get_cmdline_user_args().has("--reuse-snapshot")
	_collect(game.zone_root, game.zone_root, null if reuse else template)
	report["static_nodes"] = originals.size()
	report["original_zone_nodes"] = game.zone_root.find_children("*", "", true, false).size()
	if not reuse:
		var packed := PackedScene.new()
		_check(packed.pack(template) == OK, "Static snapshot packing failed")
		var save_started := Time.get_ticks_usec()
		_check(ResourceSaver.save(packed, DIR + "/static_snapshot.scn") == OK, "Static snapshot save failed")
		report["save_ms"] = float(Time.get_ticks_usec() - save_started) / 1000.0
	report["snapshot_reused"] = reuse
	template.free()
	var load_started := Time.get_ticks_usec()
	var loaded := load(DIR + "/static_snapshot.scn") as PackedScene
	report["load_ms"] = float(Time.get_ticks_usec() - load_started) / 1000.0
	if loaded == null:
		_fail("Serialized static snapshot unavailable")
		await _shutdown(game)
		return
	var instantiate_started := Time.get_ticks_usec()
	var candidate := loaded.instantiate() as Node3D
	report["instantiate_ms"] = float(Time.get_ticks_usec() - instantiate_started) / 1000.0
	_check(candidate != null and candidate.get_child_count() == originals.size(), "Snapshot population drift")
	if candidate == null:
		await _shutdown(game)
		return
	for index in originals.size():
		_compare(originals[index], candidate.get_child(index), game.zone_root)
	if not failures.is_empty():
		candidate.free()
		await _shutdown(game)
		return
	for index in originals.size():
		original_visibility.append(originals[index].visible)
	report["samples"] = []
	report.samples.append(await _sample("original_a", 2500))
	var attach_started := Time.get_ticks_usec()
	game.zone_root.add_child(candidate)
	for source in originals:
		source.visible = false
	await RenderingServer.frame_post_draw
	report["first_publication_ms"] = float(Time.get_ticks_usec() - attach_started) / 1000.0
	report.samples.append(await _sample("serialized_snapshot", 2500))
	for index in originals.size():
		originals[index].visible = original_visibility[index]
	candidate.visible = false
	candidate.queue_free()
	for _index in 8:
		await process_frame
	report.samples.append(await _sample("original_b", 2500))
	await _shutdown(game)

func _collect(node: Node, zone: Node3D, template: Node3D) -> void:
	if node != zone and (node.get_script() != null or node is CollisionObject3D and not node is StaticBody3D or node is Skeleton3D or node is AnimationMixer):
		return
	if node.name == "LivingRiverSection" or bool(node.get_meta("night_only_geometry", false)):
		return
	if node is GeometryInstance3D and (node is MeshInstance3D or node is MultiMeshInstance3D):
		var geometry := node as GeometryInstance3D
		if geometry.material_override is ShaderMaterial or geometry is MeshInstance3D and geometry.skin != null:
			return
		if template != null:
			var copy := geometry.duplicate(0) as GeometryInstance3D
			for child in copy.get_children():
				copy.remove_child(child)
				child.free()
			copy.name = "Geometry_%04d" % originals.size()
			copy.transform = zone.global_transform.affine_inverse() * geometry.global_transform
			copy.visible = geometry.is_visible_in_tree()
			template.add_child(copy)
			copy.owner = template
		originals.append(geometry)
	for child in node.get_children():
		_collect(child, zone, template)

func _compare(source: GeometryInstance3D, copy: GeometryInstance3D, zone: Node3D) -> void:
	_check(source.get_class() == copy.get_class(), "Geometry class changed")
	_check(copy.transform.is_equal_approx(zone.global_transform.affine_inverse() * source.global_transform), "Transform drift: " + str(source.name))
	for property in ["layers", "cast_shadow", "lod_bias", "visibility_range_begin", "visibility_range_end", "visibility_range_begin_margin", "visibility_range_end_margin", "visibility_range_fade_mode", "extra_cull_margin", "ignore_occlusion_culling", "sorting_offset", "sorting_use_aabb_center"]:
		_check(source.get(property) == copy.get(property), "Render/cull contract drift: " + property)
	_compare_material(source.material_override, copy.material_override)
	_compare_material(source.material_overlay, copy.material_overlay)
	var source_mesh: Mesh = source.mesh if source is MeshInstance3D else source.multimesh.mesh
	var copy_mesh: Mesh = copy.mesh if copy is MeshInstance3D else copy.multimesh.mesh
	_check(source_mesh.get_surface_count() == copy_mesh.get_surface_count(), "Surface count drift")
	for surface in source_mesh.get_surface_count():
		_check(var_to_bytes(source_mesh.surface_get_arrays(surface)) == var_to_bytes(copy_mesh.surface_get_arrays(surface)), "Vertex/normal/UV/index drift: " + str(source.name))
		if source_mesh is ArrayMesh and copy_mesh is ArrayMesh:
			var a_surfaces = source_mesh.get("_surfaces")
			var b_surfaces = copy_mesh.get("_surfaces")
			_check(a_surfaces is Array and b_surfaces is Array, "Serialized LOD storage unavailable")
			if a_surfaces is Array and b_surfaces is Array:
				_check(a_surfaces[surface].get("lods", {}) == b_surfaces[surface].get("lods", {}), "Embedded LOD drift")
		_compare_material(source_mesh.surface_get_material(surface), copy_mesh.surface_get_material(surface))
		if source is MeshInstance3D:
			_compare_material(source.get_surface_override_material(surface), copy.get_surface_override_material(surface))
	if source is MultiMeshInstance3D:
		var a: MultiMesh = source.multimesh
		var b: MultiMesh = copy.multimesh
		_check(a.instance_count == b.instance_count and a.visible_instance_count == b.visible_instance_count and a.transform_format == b.transform_format and a.use_colors == b.use_colors and a.use_custom_data == b.use_custom_data, "Instance budget/layout drift")
		_check(a.buffer == b.buffer, "Instance transform/color buffer drift")

func _compare_material(a: Material, b: Material) -> void:
	if a == null or b == null:
		_check(a == b, "Missing material drift")
		return
	_check(a.get_class() == b.get_class(), "Material type drift")
	for entry in a.get_property_list():
		var property := str(entry.name)
		if not (int(entry.usage) & PROPERTY_USAGE_STORAGE) or property.begins_with("resource_") or property == "script":
			continue
		var original = a.get(property)
		var restored = b.get(property)
		if original is Resource or restored is Resource:
			_check(original != null and restored != null and original.resource_path == restored.resource_path, "Material resource drift: " + property)
		else:
			_check(original == restored, "Material property drift: " + property)

func _sample(label: String, duration: int) -> Dictionary:
	var times: Array[float] = []
	var started := Time.get_ticks_msec()
	var previous := Time.get_ticks_usec()
	while Time.get_ticks_msec() - started < duration:
		await process_frame
		var now := Time.get_ticks_usec()
		times.append(float(now - previous) / 1000.0)
		previous = now
	var total := 0.0
	for value in times:
		total += value
	times.sort()
	var row := {"phase": label, "average_fps": times.size() * 1000.0 / total, "p99_frame_ms": times[mini(times.size() - 1, floori(times.size() * 0.99))], "draws": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC)}
	print("STATIC_SCENE_SAMPLE " + JSON.stringify(row))
	return row

func _shutdown(game: Node) -> void:
	report["failures"] = failures
	var file := FileAccess.open(DIR + ("/report_corrected.json" if report.get("snapshot_reused", false) else "/report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("STATIC_SCENE_OWNERSHIP " + JSON.stringify(report))
	game.prepare_resource_shutdown()
	for _index in int(game.ZONE_RETIRE_FRAMES) + 6:
		await process_frame
	game.finalize_resource_shutdown()
	for _index in 12:
		await process_frame
	game.queue_free()
	for _index in 8:
		await process_frame
	RenderingServer.force_sync()
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	failures.append(message)
	push_error(message)

func _isolated_publication() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_move_to_foreground()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 60
	report["scope"] = "isolated static publication, no actors/gameplay/FPS acceptance"
	report["benchmark_environment"] = {"max_fps": Engine.max_fps, "vsync": DisplayServer.window_get_vsync_mode(), "window_size": str(DisplayServer.window_get_size()), "gpu": RenderingServer.get_video_adapter_name()}
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.look_at_from_position(Vector3(0, 3.1, 10.0), Vector3(0, 1.0, 0), Vector3.UP)
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -35, 0)
	light.light_energy = 1.2
	world.add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.55, 0.60, 0.65)
	environment.environment.ambient_light_energy = 0.6
	world.add_child(environment)
	var base_pack := load(DIR + "/static_snapshot.scn") as PackedScene
	var primary := base_pack.instantiate() as Node3D
	world.add_child(primary)
	for _index in 60:
		await process_frame
	primary.visible = false
	report["publication_trials"] = []
	for mode in ["new_graph_a", "resident_materials_a", "resident_meshes_a", "resident_graph_a", "new_graph_b", "resident_materials_b", "resident_meshes_b", "resident_graph_b"]:
		var load_started := Time.get_ticks_usec()
		var trial_pack := ResourceLoader.load(DIR + "/static_snapshot.scn", "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		var load_ms := float(Time.get_ticks_usec() - load_started) / 1000.0
		var instantiate_started := Time.get_ticks_usec()
		var trial := trial_pack.instantiate() as Node3D
		var instantiate_ms := float(Time.get_ticks_usec() - instantiate_started) / 1000.0
		var resident_materials: bool = str(mode).begins_with("resident_materials") or str(mode).begins_with("resident_graph")
		var resident_meshes: bool = str(mode).begins_with("resident_meshes") or str(mode).begins_with("resident_graph")
		var restored_surfaces: Dictionary = {}
		_check(trial.get_child_count() == primary.get_child_count(), "Isolated population drift")
		for index in primary.get_child_count():
			var a := primary.get_child(index) as GeometryInstance3D
			var b := trial.get_child(index) as GeometryInstance3D
			_compare(a, b, primary)
			if resident_materials:
				b.material_override = a.material_override
				b.material_overlay = a.material_overlay
			var original_mesh: Mesh = a.mesh if a is MeshInstance3D else a.multimesh.mesh
			var candidate_mesh: Mesh = b.mesh if b is MeshInstance3D else b.multimesh.mesh
			if resident_materials:
				for surface in original_mesh.get_surface_count():
					candidate_mesh.surface_set_material(surface, original_mesh.surface_get_material(surface))
					if b is MeshInstance3D:
						b.set_surface_override_material(surface, a.get_surface_override_material(surface))
			if resident_meshes:
				if not resident_materials:
					if not restored_surfaces.has(original_mesh):
						var saved: Array[Material] = []
						for surface in original_mesh.get_surface_count():
							saved.append(original_mesh.surface_get_material(surface))
						restored_surfaces[original_mesh] = saved
					for surface in original_mesh.get_surface_count():
						original_mesh.surface_set_material(surface, candidate_mesh.surface_get_material(surface))
				if b is MeshInstance3D:
					b.mesh = original_mesh
				else:
					b.multimesh.mesh = original_mesh
			_compare(a, b, primary)
		var publish_started := Time.get_ticks_usec()
		world.add_child(trial)
		var attach_ms := float(Time.get_ticks_usec() - publish_started) / 1000.0
		await RenderingServer.frame_post_draw
		var first_draw_ms := float(Time.get_ticks_usec() - publish_started) / 1000.0
		var row := {"mode": mode, "load_ms": load_ms, "instantiate_ms": instantiate_ms, "attach_ms": attach_ms, "first_draw_ms": first_draw_ms, "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC)}
		report.publication_trials.append(row)
		print("ISOLATED_PUBLICATION " + JSON.stringify(row))
		trial.queue_free()
		trial = null
		trial_pack = null
		for mesh in restored_surfaces:
			for surface in mesh.get_surface_count():
				mesh.surface_set_material(surface, restored_surfaces[mesh][surface])
		for _index in 12:
			await process_frame
	report["failures"] = failures
	var file := FileAccess.open(DIR + "/publication_factor_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("ISOLATED_PUBLICATION_RESULT " + JSON.stringify(report))
	world.queue_free()
	primary = null
	base_pack = null
	for _index in 16:
		await process_frame
	RenderingServer.force_sync()
	quit(0 if failures.is_empty() else 1)
