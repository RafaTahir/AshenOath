extends RefCounted

const Options = preload("res://scripts/performance_comparison_options.gd")
static var _surfaces: Dictionary = {}

static func attach(shell: MeshInstance3D) -> void:
	if not Options.enabled("interior_occlusion") or shell == null or shell.mesh == null:
		return
	var material := shell.material_override as StandardMaterial3D
	if material == null or material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or material.albedo_color.a < 0.999:
		return
	var mesh := shell.mesh
	if not _surfaces.has(mesh):
		var vertices := PackedVector3Array()
		var indices := PackedInt32Array()
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var offset := vertices.size()
			vertices.append_array(points)
			var triangles: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if triangles.is_empty():
				for index in points.size():
					indices.append(offset + index)
			else:
				for index in triangles:
					indices.append(offset + index)
		var occluder := ArrayOccluder3D.new()
		occluder.set_arrays(vertices, indices)
		_surfaces[mesh] = occluder
	var instance := OccluderInstance3D.new()
	instance.name = "OpaqueShellOccluder"
	instance.occluder = _surfaces[mesh]
	shell.add_child(instance) # Exact opaque triangles, not a box over doorways.
	shell.get_viewport().use_occlusion_culling = true

static func clear() -> void:
	_surfaces.clear()
