extends SceneTree

const Game = preload("res://scripts/game.gd")

func _initialize() -> void:
	call_deferred("_run")

func _triangles(mesh: Mesh) -> int:
	var result := 0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		result += arrays[Mesh.ARRAY_INDEX].size() / 3
	return result

func _run() -> void:
	var game := Game.new()
	game.zone_root = Node3D.new()
	game.add_child(game.zone_root)
	game._make_crow_silhouettes()
	var parts := game.zone_root.find_children("*", "MeshInstance3D", true, false)
	var passed := parts.size() == 12 and game.zone_root.get_child_count() == 2
	var old_count := 0
	var new_count := 0
	var shared: Mesh
	var originals: Array[Mesh] = []
	var optimized: Array[Mesh] = []
	for part in parts:
		var original: PrimitiveMesh
		if part.mesh is SphereMesh:
			original = SphereMesh.new()
			if shared == null:
				shared = part.mesh
			passed = passed and part.mesh == shared
		else:
			var beak := CylinderMesh.new()
			beak.top_radius = 0.0
			beak.bottom_radius = 0.055
			beak.height = 0.16
			original = beak
		old_count += _triangles(original)
		new_count += _triangles(part.mesh)
		originals.append(original)
		optimized.append(part.mesh)
		if part.mesh.get_aabb().size.distance_to(original.get_aabb().size) >= 0.03:
			print("BOUNDS %s old=%s new=%s" % [part.name, original.get_aabb(), part.mesh.get_aabb()])
		passed = passed and part.mesh.get_aabb().size.distance_to(original.get_aabb().size) < 0.03
		passed = passed and part.material_override != null and part.visibility_range_end == 32.0
	passed = passed and new_count < old_count / 10
	for crow in game.zone_root.get_children():
		var body: MeshInstance3D = crow.get_node("CrowBody")
		var head: MeshInstance3D = crow.get_node("CrowHead")
		var beak: MeshInstance3D = crow.get_node("CrowBeak")
		var head_bounds: AABB = head.transform * head.mesh.get_aabb()
		passed = passed and head_bounds.intersects(body.transform * body.mesh.get_aabb())
		passed = passed and head_bounds.intersects(beak.transform * beak.mesh.get_aabb())
	if "--capture" in OS.get_cmdline_user_args():
		if DisplayServer.get_name().to_lower() == "headless":
			push_error("Capture requires graphical renderer")
			passed = false
		else:
			DisplayServer.window_set_size(Vector2i(1280, 720))
			root.size = Vector2i(1280, 720)
			game.remove_child(game.zone_root)
			root.add_child(game.zone_root)
			var environment := WorldEnvironment.new()
			environment.environment = Environment.new()
			environment.environment.background_mode = Environment.BG_COLOR
			environment.environment.background_color = Color(0.55, 0.65, 0.70)
			environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			environment.environment.ambient_light_color = Color.WHITE
			environment.environment.ambient_light_energy = 1.0
			root.add_child(environment)
			var camera := Camera3D.new()
			root.add_child(camera)
			camera.current = true
			var target: Vector3 = game.zone_root.get_child(0).global_position
			for distance in [1.5, 8.0]:
				camera.position = target + Vector3(0.1, 0.3, distance)
				camera.look_at(target)
				for variant in ["before", "after"]:
					for index in parts.size():
						parts[index].mesh = originals[index] if variant == "before" else optimized[index]
						if parts[index].name == "CrowHead":
							parts[index].position = Vector3(0, 0.10, -0.22) if variant == "before" else Vector3(0, 0.04, -0.13)
						elif parts[index].name == "CrowBeak":
							parts[index].position = Vector3(0, 0.08, -0.36) if variant == "before" else Vector3(0, 0.04, -0.22)
					for frame in range(3):
						await process_frame
					await RenderingServer.frame_post_draw
					var image := root.get_texture().get_image()
					var path := "D:/Temp/AshenOath/crow_connected_%s_%s.png" % [distance, variant]
					passed = passed and image.get_size() == Vector2i(1280, 720)
					passed = passed and image.save_png(path) == OK
					print("CROW CAPTURE: " + path)
			game.zone_root.queue_free()
			environment.queue_free()
			camera.queue_free()
			await process_frame
	print("CROW GEOMETRY: %s old_triangles=%d new_triangles=%d bodies=2 parts=12" % ["PASS" if passed else "FAIL", old_count, new_count])
	game.free()
	quit(0 if passed else 1)
