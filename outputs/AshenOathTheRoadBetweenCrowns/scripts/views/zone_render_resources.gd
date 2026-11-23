extends RefCounted

static func begin() -> Dictionary:
	return {"unbound_surfaces": {}, "report": {
		"mesh_instances": 0,
		"multimesh_instances": 0,
		"fallbacks_applied": 0,
		"invalid_geometry": 0,
		"invalid_geometry_names": [],
	}}

static func prepare(geometry: GeometryInstance3D, validation: Dictionary) -> void:
	var report: Dictionary = validation.report
	var fallback: Material = validation.fallback
	var instance := geometry as MeshInstance3D
	var mesh: Mesh
	if instance != null:
		report.mesh_instances += 1
		mesh = instance.mesh
		if mesh == null:
			if not instance.is_queued_for_deletion():
				report.invalid_geometry += 1
				report.invalid_geometry_names.append(str(instance.name))
			return
		if mesh.get_surface_count() == 0:
			instance.material_override = fallback
			report.fallbacks_applied += 1
			return
	elif geometry is MultiMeshInstance3D:
		report.multimesh_instances += 1
		mesh = geometry.multimesh.mesh if geometry.multimesh != null else null
		if mesh == null:
			report.invalid_geometry += 1
			report.invalid_geometry_names.append(str(geometry.name))
			return
	else:
		return
	# The renderer consults base surfaces even on overridden skinned instances.
	# Check each shared mesh once and retain only holes still needing an override.
	var surfaces: Dictionary = validation.unbound_surfaces
	var id := mesh.get_instance_id()
	if not surfaces.has(id):
		var unresolved: Array[int] = []
		for index in mesh.get_surface_count():
			if mesh.surface_get_material(index) != null:
				continue
			if fallback != null:
				mesh.surface_set_material(index, fallback)
				report.fallbacks_applied += 1
			if mesh.surface_get_material(index) == null:
				unresolved.append(index)
		surfaces[id] = unresolved
	if instance != null:
		for index: int in surfaces[id]:
			if instance.get_surface_override_material(index) == null:
				instance.set_surface_override_material(index, instance.material_override if instance.material_override != null else fallback)
				report.fallbacks_applied += 1
