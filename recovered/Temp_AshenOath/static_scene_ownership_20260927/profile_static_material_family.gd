extends SceneTree

const Family = preload("D:/Temp/AshenOath/static_scene_ownership_20260927/static_material_family.gd")
const DIR := "D:/Temp/AshenOath/static_scene_ownership_20260927"
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_move_to_foreground()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 60
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.look_at_from_position(Vector3(0, 3.1, 10), Vector3(0, 1, 0), Vector3.UP)
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
	var family := Family.new()
	var samples: Array[Dictionary] = []
	var before: Image
	for mode in ["baseline", "shared_family"]:
		var packed := ResourceLoader.load(DIR + "/static_snapshot.scn", "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		var scene := packed.instantiate() as Node3D
		var indices: Array = []
		for node in scene.get_children():
			var mesh: Mesh = node.mesh if node is MeshInstance3D else node.multimesh.mesh
			for surface in mesh.get_surface_count():
				indices.append(mesh.surface_get_arrays(surface))
			if mode == "shared_family":
				node.material_override = family.convert(node.material_override)
				node.material_overlay = family.convert(node.material_overlay)
				for surface in mesh.get_surface_count():
					mesh.surface_set_material(surface, family.convert(mesh.surface_get_material(surface)))
					if node is MeshInstance3D:
						node.set_surface_override_material(surface, family.convert(node.get_surface_override_material(surface)))
		if not family.failures.is_empty():
			failures.append_array(family.failures)
			scene.free()
			break
		var started := Time.get_ticks_usec()
		world.add_child(scene)
		await RenderingServer.frame_post_draw
		var first_ms := float(Time.get_ticks_usec() - started) / 1000.0
		for frame in 30:
			await process_frame
		await RenderingServer.frame_post_draw
		var frame := root.get_texture().get_image()
		frame.save_png(DIR + "/material_family_" + mode + ".png")
		var row := {"mode": mode, "first_draw_ms": first_ms, "draws": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), "nodes": scene.get_child_count()}
		if mode == "baseline":
			before = frame
		else:
			var difference := 0.0
			var maximum := 0.0
			var changed := 0
			for y in frame.get_height():
				for x in frame.get_width():
					var a := before.get_pixel(x, y)
					var b := frame.get_pixel(x, y)
					var delta := maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))
					difference += delta
					maximum = maxf(maximum, delta)
					if delta > 0.02:
						changed += 1
			row["pixel_difference"] = {"mean": difference / float(frame.get_width() * frame.get_height()), "maximum": maximum, "over_0_02": changed}
			if maximum > 0.02:
				failures.append("Rendered material parity differs beyond quantization")
		samples.append(row)
		print("STATIC_MATERIAL_FAMILY " + JSON.stringify(row))
		scene.queue_free()
		packed = null
		for frame_index in 12:
			await process_frame
	var report := {"scope": "isolated historical static snapshot; not current full-game acceptance", "samples": samples, "shader_families": family.shaders.size(), "converted_materials": family.materials.size(), "failures": failures}
	var output := FileAccess.open(DIR + "/static_material_family_report.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	family.clear()
	world.queue_free()
	for frame in 16:
		await process_frame
	RenderingServer.force_sync()
	print("STATIC MATERIAL FAMILY: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
