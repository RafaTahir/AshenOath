extends SceneTree

const Helper = preload("res://scripts/asset_spawn_helper.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("Material color proof requires graphical rendering")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var scene := Node3D.new()
	root.add_child(scene)
	var helper := Helper.new()
	var source := ArrayMesh.new()
	source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, BoxMesh.new().get_mesh_arrays())
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(0, 0, 5)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4
	camera.current = true
	var actors: Array[MeshInstance3D] = []
	for index in range(2):
		var actor := MeshInstance3D.new()
		actor.mesh = source
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color.RED if index == 0 else Color.WHITE
		actor.set_surface_override_material(0, material)
		helper._apply_safe_materials(actor, "res://scripts/material_render_probe.obj")
		helper._apply_safe_materials(actor, "res://scripts/material_render_probe.obj")
		actor.position.x = -1 if index == 0 else 1
		scene.add_child(actor)
		actors.append(actor)
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var passed := image.get_size() == Vector2i(1280, 720)
	for index in range(2):
		var point := camera.unproject_position(actors[index].global_position)
		var color := image.get_pixel(int(point.x), int(point.y))
		var matches := color.r > 0.8 and (color.g < 0.1 and color.b < 0.1 if index == 0 else color.g > 0.8 and color.b > 0.8)
		passed = passed and matches
		print("MATERIAL PIXEL %d: %s match=%s" % [index, color, matches])
	passed = passed and image.save_png("D:/Temp/AshenOath/material_override_render.png") == OK
	helper.clear_runtime_caches()
	helper.free()
	scene.queue_free()
	for frame in 8:
		await process_frame
	print("MATERIAL OVERRIDE RENDER: %s" % ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
