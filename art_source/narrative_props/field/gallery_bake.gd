extends SceneTree
## Native, self-contained geometry for the accident. Run via gallery_author.py.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var work := args[0]
	var output := args[1]
	var scene := Node3D.new()
	scene.name = "MillGallery"
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(work.path_join("gallery.json")))
	var mats := {}
	for part: String in data:
		var visual := MeshInstance3D.new()
		visual.name = part
		var mesh := ArrayMesh.new()
		mesh.resource_scene_unique_id = "Mesh_" + part
		mesh.resource_name = part
		for name_id: String in data[part]:
			if not mats.has(name_id):
				mats[name_id] = _material(work, name_id)
			var source: Dictionary = data[part][name_id]
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			var vertices := PackedVector3Array()
			var normals := PackedVector3Array()
			var uvs := PackedVector2Array()
			for i in range(0, source.v.size(), 3):
				vertices.append(Vector3(source.v[i],source.v[i+1],source.v[i+2]))
				normals.append(Vector3(source.n[i],source.n[i+1],source.n[i+2]))
			for i in range(0, source.uv.size(), 2):
				uvs.append(Vector2(source.uv[i],source.uv[i+1]))
			arrays[Mesh.ARRAY_VERTEX] = vertices
			arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_TEX_UV] = uvs
			arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(source.idx)
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var surface := mesh.get_surface_count() - 1
			mesh.surface_set_name(surface, name_id)
			mesh.surface_set_material(surface, mats[name_id])
		visual.mesh = mesh
		scene.add_child(visual)
		visual.owner = scene
	var packed := PackedScene.new()
	packed.resource_scene_unique_id = "GalleryAccident"
	var err := packed.pack(scene)
	if err == OK:
		# Godot assigns random node IDs at pack time. These named nodes have
		# a fixed order in the authored file and no external node references.
		var bundle := packed._bundled
		var ids: PackedInt32Array = bundle.node_ids
		for index in ids.size():
			ids[index] = 14140100 + index
		bundle.node_ids = ids
		packed._bundled = bundle
		err = ResourceSaver.save(packed, output, ResourceSaver.FLAG_COMPRESS | ResourceSaver.FLAG_BUNDLE_RESOURCES)
	if err == OK:
		err = ResourceSaver.set_uid(output, 0x2a12fa0371436d99)
	scene.free()
	quit(0 if err == OK else 1)

func _material(work: String, name_id: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.resource_scene_unique_id = "Material_" + name_id
	mat.resource_name = name_id
	mat.metallic = 0.6 if name_id == "iron" else 0.0
	mat.roughness = 0.25 if name_id == "water" else (0.52 if name_id == "iron" else 0.89)
	var image := Image.load_from_file(work.path_join(name_id + ".png"))
	image.resize(192,192,Image.INTERPOLATE_LANCZOS)
	image.generate_mipmaps()
	var texture := PortableCompressedTexture2D.new()
	texture.set_keep_compressed_buffer(true)
	texture.resource_scene_unique_id = "Albedo_" + name_id
	texture.create_from_image(image, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSY, false, 0.76)
	mat.albedo_texture = texture
	return mat
