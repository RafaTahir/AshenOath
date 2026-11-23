extends RefCounted

static func camera_transform(destination: String, source: String) -> Transform3D:
	var reverse := WorldSectorManifest.connection_between(destination, source)
	if reverse.is_empty(): return Transform3D(Basis.IDENTITY,Vector3(0,2.5,10))
	var frame := WorldSectorManifest.crossing_frame(reverse)
	var outward := WorldSectorManifest.direction(str(reverse.id))
	var eye := frame.origin+outward*3.0+Vector3.UP*2.5
	return Transform3D(Basis.IDENTITY,eye).looking_at(frame.origin-outward*6.0+Vector3.UP,Vector3.UP)

static func _render_material_key(material: Material) -> Variant:
	if material == null: return RID()
	# A custom shader resource owns the program. Each material keeps its uniforms.
	if material is ShaderMaterial and material.shader != null and material.next_pass == null:
		return [material.shader.get_rid(), material.render_priority]
	return material.get_rid()

static func render_group_key(visual: GeometryInstance3D) -> Array:
	var mesh: Mesh
	var key: Array = [visual.get_class(), visual.cast_shadow,
		_render_material_key(visual.material_override), _render_material_key(visual.material_overlay)]
	if visual is MeshInstance3D:
		mesh = visual.mesh
		key.append(visual.skin != null)
	elif visual is MultiMeshInstance3D and visual.multimesh != null:
		mesh = visual.multimesh.mesh
		key.append(visual.multimesh.use_colors)
		key.append(visual.multimesh.use_custom_data)
		key.append(visual.multimesh.transform_format)
	if mesh != null:
		for surface in mesh.get_surface_count():
			if visual.material_override == null:
				var material: Material = visual.get_active_material(surface) if visual is MeshInstance3D else mesh.surface_get_material(surface)
				key.append(_render_material_key(material))
			# Meshes with the same vertex layout can warm the same material variant.
			# The real entry draw still submits every visible mesh.
			if mesh is ArrayMesh:
				key.append([mesh.surface_get_primitive_type(surface), mesh.surface_get_format(surface)])
			else: key.append(mesh.get_rid())
	else: key.append(visual.get_instance_id())
	return key

static func intersects(bounds: AABB, planes: Array[Plane]) -> bool:
	# Keep slabs and other large meshes spanning the frustum even when none
	# of their original corners is inside it.
	for plane: Plane in planes:
		var end := bounds.end
		var nearest := Vector3(
			bounds.position.x if plane.normal.x >= 0.0 else end.x,
			bounds.position.y if plane.normal.y >= 0.0 else end.y,
			bounds.position.z if plane.normal.z >= 0.0 else end.z)
		if plane.is_point_over(nearest):
			return false
	return true
