extends SceneTree
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var folder := args[0]
	var output := args[1]
	var groups: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("gate_geo.json")))
	var mesh := ArrayMesh.new()
	mesh.resource_scene_unique_id = "ArrayMesh_gate1"
	mesh.resource_name = "Gate, travelling shawl and Oren's coat"
	for key: String in groups:
		var data: Dictionary = groups[key]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		var uv := PackedVector2Array()
		for i in range(0,data.v.size(),3):
			vertices.append(Vector3(data.v[i],data.v[i+1],data.v[i+2]))
			normals.append(Vector3(data.n[i],data.n[i+1],data.n[i+2]))
		for i in range(0,data.uv.size(),2):
			uv.append(Vector2(data.uv[i],data.uv[i+1]))
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(data.idx)
		var mat := StandardMaterial3D.new()
		mat.resource_name = key
		mat.resource_scene_unique_id = "Mat_" + key
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED if key in ["shawl","ochre","ochre_dim","coat","coat_edge","lining"] else BaseMaterial3D.CULL_BACK
		mat.roughness = 0.92
		if key in ["iron","iron_bright","button"]:
			mat.metallic = .48
			mat.roughness = .61
		if key == "embers":
			mat.emission_enabled = true
			mat.emission = Color("#9b3721")
			mat.emission_energy_multiplier = 0.7
		var im := Image.load_from_file(folder.path_join(key+".png"))
		im.generate_mipmaps()
		var texture := PortableCompressedTexture2D.new()
		texture.set_keep_compressed_buffer(true)
		texture.resource_scene_unique_id = "Texture_" + key
		texture.create_from_image(im,PortableCompressedTexture2D.COMPRESSION_MODE_LOSSY,false,0.76)
		mat.albedo_texture = texture
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		mesh.surface_set_material(mesh.get_surface_count()-1,mat)
		mesh.surface_set_name(mesh.get_surface_count()-1,key)
	assert(ResourceSaver.save(mesh,output,ResourceSaver.FLAG_COMPRESS | ResourceSaver.FLAG_BUNDLE_RESOURCES) == OK)
	assert(ResourceSaver.set_uid(output,0x25c7f24c4830b979) == OK)
	print("GATE SCENE ", mesh.get_surface_count(), " baked materials")
	quit()
