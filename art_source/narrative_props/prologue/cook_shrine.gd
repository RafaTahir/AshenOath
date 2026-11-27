extends SceneTree
## Invoked by author_shrine.py in a disposable project containing the sculpted surfaces.

func _initialize() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://mesh.json"))
	var mesh := ArrayMesh.new()
	for name: String in data:
		var surface: Dictionary = data[name]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vectors(surface.pos)
		arrays[Mesh.ARRAY_NORMAL] = vectors(surface.norm)
		arrays[Mesh.ARRAY_COLOR] = vertex_colours(surface.color)
		var uv := PackedVector2Array()
		for i in range(0, surface.uv.size(), 2):
			uv.append(Vector2(surface.uv[i], surface.uv[i + 1]))
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(surface.idx)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var index := mesh.get_surface_count() - 1
		mesh.surface_set_name(index, name.capitalize())
		mesh.surface_set_material(index, make_material(name))

	var destination := OS.get_cmdline_user_args()[0]
	var error := ResourceSaver.save(mesh, destination, ResourceSaver.FLAG_COMPRESS | ResourceSaver.FLAG_BUNDLE_RESOURCES)
	print("Shrine scenery baked ", mesh.get_surface_count(), " surfaces to ", destination)
	quit(int(error))

func vectors(components: Array) -> PackedVector3Array:
	var result := PackedVector3Array()
	for i in range(0, components.size(), 3):
		result.append(Vector3(components[i], components[i + 1], components[i + 2]))
	return result

func vertex_colours(components: Array) -> PackedColorArray:
	var result := PackedColorArray()
	for i in range(0, components.size(), 3):
		result.append(Color(components[i], components[i + 1], components[i + 2]))
	return result

func make_material(name: String) -> StandardMaterial3D:
	var image := Image.load_from_file("res://%s.png" % name)
	image.convert(Image.FORMAT_L8)
	image.generate_mipmaps()
	var material := StandardMaterial3D.new()
	material.resource_name = name.capitalize()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.70 if name == "onion" else 0.96
	return material
