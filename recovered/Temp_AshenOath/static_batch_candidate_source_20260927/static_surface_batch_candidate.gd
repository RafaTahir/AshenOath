extends RefCounted

# Diagnostic only: this is not called by any production builder.
var groups: Dictionary = {}
var rejected: Dictionary = {}
var replacements: Array[Dictionary] = []
var batch_root: Node3D

func prepare(zone: Node3D) -> Dictionary:
	groups.clear()
	rejected.clear()
	for raw in zone.find_children("*", "MeshInstance3D", true, false):
		var node := raw as MeshInstance3D
		var reason := _reject_reason(node, zone)
		if reason != "":
			rejected[reason] = int(rejected.get(reason, 0)) + 1
			continue
		for surface in node.mesh.get_surface_count():
			var material := node.get_active_material(surface)
			var stored := RenderingServer.mesh_get_surface(node.mesh.get_rid(), surface)
			var key := "%d:%d:%d:%d" % [material.get_instance_id(), stored.format, node.layers, node.cast_shadow]
			if not groups.has(key):
				groups[key] = {"material": material, "layers": node.layers, "shadow": node.cast_shadow, "sources": []}
			groups[key].sources.append({"node": node, "surface": surface, "transform": zone.global_transform.affine_inverse() * node.global_transform})
	var source_surfaces := 0
	var batch_surfaces := 0
	var source_nodes: Dictionary = {}
	for key in groups:
		var entries: Array = groups[key].sources
		# All surfaces of a selected source must be emitted, including singletons.
		batch_surfaces += 1
		source_surfaces += entries.size()
		for entry in entries:
			source_nodes[entry.node.get_instance_id()] = str(zone.get_path_to(entry.node))
	return {"eligible_nodes": source_nodes.size(), "source_surfaces": source_surfaces,
		"batch_surfaces": batch_surfaces, "saved_surfaces": source_surfaces - batch_surfaces,
		"sources": source_nodes.values(), "rejected": rejected.duplicate()}

func build(zone: Node3D) -> Dictionary:
	var started := Time.get_ticks_usec()
	batch_root = Node3D.new()
	batch_root.name = "DiagnosticStaticSurfaceBatches"
	zone.add_child(batch_root)
	var failures: Array[String] = []
	var source_nodes: Dictionary = {}
	for key in groups:
		var group: Dictionary = groups[key]
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for entry in group.sources:
			tool.append_from(entry.node.mesh, entry.surface, entry.transform)
			var source := entry.node as MeshInstance3D
			source_nodes[source.get_instance_id()] = source
		var mesh := tool.commit()
		if mesh == null:
			failures.append("Empty batch: " + key)
			continue
		mesh.surface_set_material(0, group.material)
		_validate_arrays(mesh.surface_get_arrays(0), group.sources, failures)
		var visual := MeshInstance3D.new()
		visual.name = "StaticSurface_%d" % batch_root.get_child_count()
		visual.mesh = mesh
		visual.layers = group.layers
		visual.cast_shadow = group.shadow
		batch_root.add_child(visual)
	if failures.is_empty():
		for source in source_nodes.values():
			replacements.append({"node": source, "layers": source.layers})
			# Geometry is replaced by verified transformed copies, never discarded.
			source.layers = 0
	else:
		batch_root.visible = false
	return {"equivalence_failures": failures, "build_ms": float(Time.get_ticks_usec() - started) / 1000.0}

func restore() -> void:
	for entry in replacements:
		if is_instance_valid(entry.node):
			entry.node.layers = entry.layers
	replacements.clear()
	if is_instance_valid(batch_root):
		batch_root.get_parent().remove_child(batch_root)
		batch_root.free()
	batch_root = null
	groups.clear()

func _reject_reason(node: MeshInstance3D, zone: Node3D) -> String:
	if node.mesh == null or not node.is_visible_in_tree() or node.layers == 0:
		return "not_rendered"
	if node.skin != null or (node.mesh is ArrayMesh and node.mesh.get_blend_shape_count() > 0):
		return "animated_mesh"
	if node.material_overlay != null or node.custom_aabb.has_volume():
		return "custom_rendering"
	if node.visibility_range_begin != 0.0 or node.visibility_range_end != 0.0 or not node.visibility_parent.is_empty():
		return "individual_visibility_or_lod"
	var parent: Node = node
	while parent != zone and parent != null:
		if parent.get_script() != null or parent is CollisionObject3D or parent is Skeleton3D or parent is BoneAttachment3D:
			return "runtime_owner"
		if parent.has_meta("motion_type") or parent.has_meta("world_prop_kind") or parent.has_meta("night_only_geometry") or parent.has_meta("night_window_material"):
			return "dynamic_state"
		var lower := str(parent.name).to_lower()
		for pattern in ["litwindow", "sidewindow", "lanternglow", "lightpool", "lanternpool", "shrineglow", "roadcandle"]:
			if lower.contains(pattern):
				return "night_state_owner"
		if parent is Node3D and not parent.visible:
			return "hidden_parent"
		if parent.find_children("*", "AnimationPlayer", false, false).size() > 0:
			return "animation_owner"
		parent = parent.get_parent()
	var transform := zone.global_transform.affine_inverse() * node.global_transform
	var scale := transform.basis.get_scale()
	if transform.basis.determinant() <= 0 or not is_equal_approx(scale.x, scale.y) or not is_equal_approx(scale.y, scale.z):
		return "nonuniform_or_mirrored_transform"
	for surface in node.mesh.get_surface_count():
		var stored := RenderingServer.mesh_get_surface(node.mesh.get_rid(), surface)
		if stored.primitive != Mesh.PRIMITIVE_TRIANGLES:
			return "nontriangle"
		if not stored.get("lods", []).is_empty():
			return "embedded_lod"
		var arrays := node.mesh.surface_get_arrays(surface)
		if arrays[Mesh.ARRAY_BONES] != null or arrays[Mesh.ARRAY_WEIGHTS] != null:
			return "skeleton_attributes"
		for attribute in range(Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM3 + 1):
			if arrays[attribute] != null:
				return "custom_attributes"
		var material := node.get_active_material(surface) as StandardMaterial3D
		if material == null or material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			return "shader_or_transparency"
		if material.next_pass != null or material.emission_enabled or material.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED:
			return "dynamic_material"
		if material.uv1_triplanar or material.uv2_triplanar or material.grow or material.fixed_size or material.use_point_size:
			return "object_space_material"
		if material.distance_fade_mode != BaseMaterial3D.DISTANCE_FADE_DISABLED or material.proximity_fade_enabled:
			return "material_visibility"
	return ""

func _validate_arrays(actual: Array, sources: Array, failures: Array[String]) -> void:
	var offset := 0
	var expected_indices: Array[int] = []
	for entry in sources:
		var arrays: Array = entry.node.mesh.surface_get_arrays(entry.surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		for index in vertices.size():
			if offset + index >= actual[Mesh.ARRAY_VERTEX].size():
				failures.append("Missing transformed vertex")
				return
			if actual[Mesh.ARRAY_VERTEX][offset + index].distance_to(entry.transform * vertices[index]) > 0.0001:
				failures.append("Transformed position changed")
				return
			for attribute in [Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_COLOR]:
				if arrays[attribute] == null:
					continue
				var expected = arrays[attribute][index]
				if attribute == Mesh.ARRAY_NORMAL:
					expected = (entry.transform.basis.inverse().transposed() * expected).normalized()
				if attribute == Mesh.ARRAY_COLOR:
					if not actual[attribute][offset + index].is_equal_approx(expected):
						failures.append("Vertex color changed")
						return
				elif actual[attribute][offset + index].distance_to(expected) > 0.002:
					failures.append("Normal/UV attribute changed")
					return
			if arrays[Mesh.ARRAY_TANGENT] != null:
				var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
				var expected_tangent: Vector3 = (entry.transform.basis * Vector3(tangents[index * 4], tangents[index * 4 + 1], tangents[index * 4 + 2])).normalized()
				var start := (offset + index) * 4
				var actual_tangent := Vector3(actual[Mesh.ARRAY_TANGENT][start], actual[Mesh.ARRAY_TANGENT][start + 1], actual[Mesh.ARRAY_TANGENT][start + 2])
				if actual_tangent.distance_to(expected_tangent) > 0.002 or not is_equal_approx(actual[Mesh.ARRAY_TANGENT][start + 3], tangents[index * 4 + 3]):
					failures.append("Tangent changed")
					return
		if indices.is_empty():
			for index in vertices.size():
				expected_indices.append(offset + index)
		else:
			for index in indices:
				expected_indices.append(offset + index)
		offset += vertices.size()
	if actual[Mesh.ARRAY_VERTEX].size() != offset:
		failures.append("Unexpected added vertices")
	var actual_indices: PackedInt32Array = actual[Mesh.ARRAY_INDEX] if actual[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if actual_indices.is_empty():
		for index in offset:
			actual_indices.append(index)
	if actual_indices != PackedInt32Array(expected_indices):
		failures.append("Triangle indices/winding changed")
