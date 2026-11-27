extends SceneTree
## godot --headless --path <scratch-project> --script cook_brace.gd -- <GLB> <output.res>

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Expected intermediate GLB and output .res")
		quit(1)
		return
	var state := GLTFState.new()
	var document := GLTFDocument.new()
	if document.append_from_file(args[0], state) != OK:
		push_error("Could not read fitted geometry from " + args[0])
		quit(1)
		return
	if state.get_meshes().size() != 1:
		push_error("Expected the joined garment mesh")
		quit(1)
		return
	var mesh: ArrayMesh = state.get_meshes()[0].mesh.get_mesh()
	if mesh == null or mesh.get_surface_count() != 2:
		push_error("Expected crate wood and linen surfaces")
		quit(1)
		return
	var tris := 0
	for i in mesh.get_surface_count():
		var material := mesh.surface_get_material(i) as StandardMaterial3D
		if material == null or not mesh.surface_get_format(i) & Mesh.ARRAY_FORMAT_COLOR:
			push_error("The brace must retain both authored pigmented surfaces")
			quit(1)
			return
		material.vertex_color_use_as_albedo = true
		tris += mesh.surface_get_array_index_len(i) / 3
	mesh.resource_name = "Tor left wrist splints"
	var error := ResourceSaver.save(mesh, args[1], ResourceSaver.FLAG_COMPRESS | ResourceSaver.FLAG_BUNDLE_RESOURCES)
	if error != OK:
		push_error("Could not bake the wrist brace: " + error_string(error))
		quit(1)
		return
	print("Baked Tor left wrist brace, %d triangles, %s" % [tris, mesh.get_aabb()])
	quit()
