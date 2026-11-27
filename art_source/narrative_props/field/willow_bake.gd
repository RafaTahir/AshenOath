extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var scratch := args[0]
	var output := args[1]
	var texture := PortableCompressedTexture2D.new()
	var image := Image.load_from_file(scratch.path_join("palette.png"))
	image.generate_mipmaps()
	texture.set_keep_compressed_buffer(true)
	texture.create_from_image(image, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSY, false, 0.87)
	texture.resource_scene_unique_id = "Texture_willowatlas"
	var mat := StandardMaterial3D.new()
	mat.resource_scene_unique_id = "StandardMaterial3D_willow"
	mat.resource_name = "Alder, weathered wool and fen stone"
	mat.albedo_texture = texture
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var target := output.path_join("willow_surface.res")
	if ResourceSaver.save(mat,target,ResourceSaver.FLAG_COMPRESS) != OK:
		quit(1)
		return
	ResourceSaver.set_uid(target, 0x1a34c5432af5200)
	var names := ["bank","loose","rigged","frame","oren","rest","porch","graves","lift_cloth"]
	for i in names.size():
		var name: String = names[i]
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(scratch.path_join(name + ".json")))
		var mesh := ArrayMesh.new()
		mesh.resource_scene_unique_id = "ArrayMesh_willow" + name
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		var verts := PackedVector3Array()
		var norms := PackedVector3Array()
		var uvs := PackedVector2Array()
		for n in range(0,data.v.size(),3):
			verts.append(Vector3(data.v[n],data.v[n+1],data.v[n+2]))
			norms.append(Vector3(data.n[n],data.n[n+1],data.n[n+2]))
		for n in range(0,data.uv.size(),2):
			uvs.append(Vector2(data.uv[n],data.uv[n+1]))
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = norms
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(data.idx)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.resource_name = "Willow " + name
		target = output.path_join("willow_" + name + ".res")
		if ResourceSaver.save(mesh,target,ResourceSaver.FLAG_COMPRESS) != OK:
			quit(1)
			return
		ResourceSaver.set_uid(target,0x1a34c5432af5201+i)
	quit(0)
