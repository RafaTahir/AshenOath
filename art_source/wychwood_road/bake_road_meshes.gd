extends SceneTree
## Run after the Blender export. Accepts a folder containing the three GLBs.

func _initialize() -> void:
	go.call_deferred()

func go() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		quit(1)
		return
	for asset: String in ["Wychwood_CartersAxle", "CarvedCrowToken", "Wychwood_RaiderTally"]:
		if not bake(args[0], asset):
			quit(1)
			return
	quit(0)

func bake(folder: String, asset: String) -> bool:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(folder.path_join(asset + ".glb"), state) != OK:
		return false
	var model := document.generate_scene(state)
	if not model: return false
	root.add_child(model)
	var groups := {}
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for s in part.mesh.get_surface_count():
			var mat := part.mesh.surface_get_material(s) as StandardMaterial3D
			if not mat or not mat.vertex_color_use_as_albedo:
				push_error("Missing Blender vertex pigment on " + part.name)
				return false
			var key := mat.resource_name
			if not groups.has(key):
				var builder := SurfaceTool.new()
				builder.begin(Mesh.PRIMITIVE_TRIANGLES)
				builder.set_material(mat)
				groups[key] = builder
			groups[key].append_from(part.mesh, s, part.global_transform)
	var mesh := ArrayMesh.new()
	for key: String in groups.keys():
		groups[key].commit(mesh)
		mesh.surface_set_name(mesh.get_surface_count() - 1, key)
	model.free()
	mesh.resource_name = asset
	var bounds := mesh.get_aabb()
	print("%s: %s, triangles=%d, draws=%d" % [asset, bounds, mesh.get_faces().size()/3, mesh.get_surface_count()])
	if groups.is_empty() or groups.size() > 2 or not bounds.size.is_finite() or bounds.size.y <= 0.05:
		return false
	return ResourceSaver.save(mesh, folder.path_join(asset + ".res"), ResourceSaver.FLAG_COMPRESS) == OK
