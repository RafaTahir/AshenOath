extends RefCounted
## Imported Universal material work; the existing spawn owner keeps its tags.
static func collapse_normals(meshes: Array) -> Array[MeshInstance3D]:
	var changed_meshes: Array[MeshInstance3D] = []
	for mesh_instance: MeshInstance3D in meshes:
		if mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() == 0:
			continue
		var local_mesh := mesh_instance.mesh.duplicate(false) as Mesh
		if local_mesh == null:
			continue
		var changed := false
		for surface_index in local_mesh.get_surface_count():
			var source := local_mesh.surface_get_material(surface_index)
			if not source is StandardMaterial3D:
				continue
			var material := source.duplicate() as StandardMaterial3D
			if material.normal_enabled or material.normal_texture != null:
				material.normal_enabled = false
				material.normal_texture = null
				changed = true
			local_mesh.surface_set_material(surface_index, material)
		if changed:
			mesh_instance.mesh = local_mesh
			changed_meshes.append(mesh_instance)
	return changed_meshes
