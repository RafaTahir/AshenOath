extends SceneTree

func _initialize() -> void:
	var packed := load("D:/Temp/AshenOath/static_scene_ownership_20260927/static_snapshot.scn") as PackedScene
	var scene := packed.instantiate()
	var meshes: Dictionary = {}
	var layouts: Dictionary = {}
	for node in scene.find_children("*", "GeometryInstance3D", true, false):
		var mesh: Mesh = node.mesh if node is MeshInstance3D else (node.multimesh.mesh if node is MultiMeshInstance3D else null)
		if mesh == null or meshes.has(mesh.get_instance_id()):
			continue
		meshes[mesh.get_instance_id()] = true
		for surface in range(mesh.get_surface_count()):
			var arrays := mesh.surface_get_arrays(surface)
			var format: int = mesh.surface_get_format(surface) if mesh is ArrayMesh else 0
			var key := str(format)
			if not layouts.has(key):
				layouts[key] = {"surfaces": 0, "owners": [], "arrays": []}
				for i in range(arrays.size()):
					if arrays[i] != null and arrays[i].size() > 0:
						layouts[key].arrays.append(i)
			layouts[key].surfaces += 1
			if layouts[key].owners.size() < 4:
				layouts[key].owners.append(str(node.name))
	var output := FileAccess.open("D:/Temp/AshenOath/perf_stack_owner_20260929/layouts.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"meshes": meshes.size(), "layouts": layouts}, "\t"))
	output.close()
	print("LAYOUT CENSUS: meshes=%d formats=%d" % [meshes.size(), layouts.size()])
	scene.free()
	quit()
