extends SceneTree

func _initialize() -> void:
	var scene: Node = load("D:/Temp/AshenOath/static_scene_ownership_20260927/static_snapshot.scn").instantiate()
	var source := (scene.get_child(0) as MeshInstance3D).material_override as StandardMaterial3D
	if source == null:
		push_error("Generated-material source unavailable")
		quit(1)
		return
	var template := source.duplicate(false) as StandardMaterial3D
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var white := ImageTexture.create_from_image(image)
	template.albedo_texture = white
	template.vertex_color_use_as_albedo = true
	template.emission_enabled = true
	template.emission_texture = white
	var code := RenderingServer.shader_get_code(template.get_shader_rid())
	var output := FileAccess.open("D:/Temp/AshenOath/static_scene_ownership_20260927/generated_material.gdshader", FileAccess.WRITE)
	output.store_string(code)
	output.close()
	print("GENERATED MATERIAL: %d bytes; original albedo=%s emission=%s energy=%s" % [code.length(), RenderingServer.material_get_param(source.get_rid(), "albedo"), RenderingServer.material_get_param(source.get_rid(), "emission"), RenderingServer.material_get_param(source.get_rid(), "emission_energy")])
	scene.free()
	quit()
