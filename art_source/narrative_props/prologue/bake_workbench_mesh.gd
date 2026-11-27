extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for tag: String in ["yard", "basin"]:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0].path_join(tag + ".json")))
		var shape := ArrayMesh.new()
		shape.resource_name = "Sella_" + tag
		shape.resource_scene_unique_id = "Mesh_" + tag
		for key: String in data.surfaces:
			var src: Dictionary = data.surfaces[key]
			var mat := StandardMaterial3D.new()
			var desc: Dictionary = data.mats[key]
			mat.resource_name = key
			mat.resource_scene_unique_id = "Material_" + key
			mat.vertex_color_use_as_albedo = true
			mat.vertex_color_is_srgb = true
			mat.roughness = desc.get("rough", 1.0)
			mat.metallic = desc.get("metal", 0.0)
			if desc.has("tex"):
				var texture_file := args[0].path_join(str(desc.tex) + ".png")
				var tex := Image.load_from_file(texture_file)
				if tex == null:
					push_error("Missing workbench texture: " + texture_file)
					quit(1)
					return
				tex.generate_mipmaps()
				# A portable lossless texture carries its own encoded image data and
				# avoids a second Image resource with an engine-generated identifier.
				var image_texture := PortableCompressedTexture2D.new()
				image_texture.keep_compressed_buffer = true
				image_texture.create_from_image(tex, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS)
				image_texture.resource_name = key + " surface"
				image_texture.resource_scene_unique_id = "Texture_" + key
				mat.albedo_texture = image_texture
				mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			if desc.has("color"):
				var c: Array = desc.color
				mat.albedo_color = Color(c[0], c[1], c[2])
			if desc.has("emit"):
				mat.emission_enabled = true
				var c: Array = desc.emit
				mat.emission = Color(c[0], c[1], c[2])
				mat.emission_energy_multiplier = 2.2
			var vs := PackedVector3Array()
			var ns := PackedVector3Array()
			var tx := PackedVector2Array()
			var cl := PackedColorArray()
			for v: Array in src.v: vs.push_back(Vector3(v[0], v[1], v[2]))
			for n: Array in src.n: ns.push_back(Vector3(n[0], n[1], n[2]))
			for uv: Array in src.uv: tx.push_back(Vector2(uv[0], uv[1]))
			for c: Array in src.c: cl.push_back(Color(c[0], c[1], c[2]))
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = vs
			arr[Mesh.ARRAY_NORMAL] = ns
			arr[Mesh.ARRAY_TEX_UV] = tx
			arr[Mesh.ARRAY_COLOR] = cl
			arr[Mesh.ARRAY_INDEX] = PackedInt32Array(src.ix)
			shape.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			shape.surface_set_material(shape.get_surface_count()-1, mat)
			shape.surface_set_name(shape.get_surface_count()-1, key)
		var err := ResourceSaver.save(shape, args[1].path_join(tag+"_scenery.res"), ResourceSaver.FLAG_COMPRESS)
		if err != OK:
			push_error(error_string(err))
			quit(1)
			return
		print("Baked ", tag, " ", shape.get_surface_count(), " surfaces")
	quit()
