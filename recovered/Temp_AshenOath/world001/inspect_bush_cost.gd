extends SceneTree

func _initialize() -> void:
	var path := "res://assets_external/environment/forest/Bush_Common.obj"
	var imported := load(path) as ArrayMesh
	var helper = load("res://scripts/asset_spawn_helper.gd").new()
	var normalized := helper._load_obj_mesh(path) as ArrayMesh
	for label in ["imported", "normalized"]:
		var mesh: ArrayMesh = imported if label == "imported" else normalized
		if mesh == null:
			print("BUSH %s missing" % label)
			continue
		var triangles := 0
		var materials: Array[String] = []
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			triangles += (indices.size() if not indices.is_empty() else vertices.size()) / 3
			var material := mesh.surface_get_material(surface)
			materials.append("%s:%s" % [mesh.surface_get_name(surface), material.get_class() if material != null else "null"])
		print("BUSH %s surfaces=%d triangles=%d bounds=%s materials=%s" % [label, mesh.get_surface_count(), triangles, mesh.get_aabb(), materials])
	quit(0)
