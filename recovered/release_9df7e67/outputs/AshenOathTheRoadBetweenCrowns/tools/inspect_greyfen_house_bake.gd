extends SceneTree

const MESH_PATH := "res://assets_external/environment/village/GreyfenHouse_Authored.res"
const OUTPUT_PATH := "D:/Temp/AshenOath/world001_house_bake_preview.png"
const WorldMaterialLibrary := preload("res://scripts/world_material_library.gd")

func _initialize() -> void:
	call_deferred("_inspect")

func _inspect() -> void:
	var variant := 0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--variant="):
			variant = int(argument.trim_prefix("--variant="))
	var mesh_path := MESH_PATH if variant == 0 else MESH_PATH.trim_suffix(".res") + "_%d.res" % variant
	var output_path := OUTPUT_PATH if variant == 0 else OUTPUT_PATH.trim_suffix(".png") + "_%d.png" % variant
	var mesh := load(mesh_path) as ArrayMesh
	if mesh == null or mesh.get_surface_count() != 6:
		push_error("Greyfen house mesh is missing or incomplete")
		quit(1)
		return
	var scene := Node3D.new()
	root.add_child(scene)
	var library: Node = WorldMaterialLibrary.new()
	scene.add_child(library)
	var house := MeshInstance3D.new()
	house.mesh = mesh
	scene.add_child(house)
	var tints := {
		"medieval_brick": Color(0.67, 0.65, 0.59),
		"plaster": Color(0.76, 0.70, 0.58),
		"timber": Color(0.35, 0.23, 0.14),
		"roof_tiles": Color(0.53, 0.24, 0.16),
		"glazing": Color(0.16, 0.22, 0.24),
		"metal": Color(0.34, 0.34, 0.32),
	}
	for index in mesh.get_surface_count():
		var surface := mesh.surface_get_name(index)
		if not tints.has(surface):
			push_error("Unknown Greyfen house surface: " + surface)
			quit(1)
			return
		var material_id := surface if WorldMaterialLibrary.SURFACES.has(surface) else "metal"
		house.set_surface_override_material(index, library.get_material(material_id, "balanced", tints[surface], 0.0, false))
	var floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(11, 11)
	floor.mesh = floor_mesh
	floor.material_override = library.get_material("wet_mud", "balanced", Color(0.65, 0.62, 0.56))
	scene.add_child(floor)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-47, -35, 0)
	light.light_energy = 1.2
	scene.add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.45, 0.51, 0.53)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.65, 0.69, 0.72)
	scene.add_child(environment)
	var camera := Camera3D.new()
	camera.look_at_from_position(Vector3(6.4, 3.1, -7.5), Vector3(0, 1.65, 0), Vector3.UP)
	camera.current = true
	scene.add_child(camera)
	for _index in 24:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.get_size() != Vector2i(1280, 720):
		push_error("Greyfen house preview render unavailable")
		quit(1)
		return
	var error := image.save_png(output_path)
	if error != OK:
		push_error("Greyfen house preview save failed: " + error_string(error))
		quit(1)
		return
	print("GREYFEN HOUSE PREVIEW: PASS variant=%d bounds=%s file=%s" % [variant, mesh.get_aabb(), output_path])
	quit(0)
