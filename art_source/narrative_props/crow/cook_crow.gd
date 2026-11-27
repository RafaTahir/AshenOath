extends SceneTree
## godot --headless --path EMPTY_PROJECT --script cook_crow.gd -- BUILD_DIR DATA_DIR

const PARTS := ["OrenToken","SellaCord","BurialThread","TwoWireTurns","OldWrapping"]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Expected intermediate GLB directory and runtime mesh directory.")
		quit(1)
		return
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(args[0].path_join("CrowParts.glb"), state) != OK:
		push_error("Could not open Blender GLB.")
		quit(1)
		return
	var scene := document.generate_scene(state)
	if scene == null or DirAccess.make_dir_recursive_absolute(args[1]) != OK:
		quit(1)
		return
	for part: String in PARTS:
		var node := scene.find_child(part, true, false) as MeshInstance3D
		if node == null or node.mesh == null or not node.transform.is_equal_approx(Transform3D.IDENTITY):
			push_error("Invalid named part or non-identity mesh transform: " + part)
			scene.free()
			quit(1)
			return
		var mesh := node.mesh as ArrayMesh
		# Real-world brass and cord are only a few millimetres thick. Preserve the
		# authored bounds/indices; no gameplay-scale expansion in the export.
		var aabb := mesh.get_aabb()
		var tris := 0
		for i in mesh.get_surface_count():
			tris += mesh.surface_get_array_index_len(i) / 3
			var mat := mesh.surface_get_material(i) as StandardMaterial3D
			if mat == null:
				push_error("Material missing from " + part)
				scene.free()
				quit(1)
				return
		var flags := ResourceSaver.FLAG_COMPRESS | ResourceSaver.FLAG_BUNDLE_RESOURCES | ResourceSaver.FLAG_OMIT_EDITOR_PROPERTIES
		if ResourceSaver.save(mesh, args[1].path_join(part + ".res"), flags) != OK:
			push_error("Could not bake " + part)
			scene.free()
			quit(1)
			return
		print(part, "  bounds=", aabb, "  triangles=", tris)
	scene.free()
	quit(0)
