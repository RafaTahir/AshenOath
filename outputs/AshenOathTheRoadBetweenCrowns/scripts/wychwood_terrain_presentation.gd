extends RefCounted

static func integrate(root: Node3D) -> bool:
	var ground_visuals: Array[MeshInstance3D] = []
	for candidate in root.find_children("*", "MeshInstance3D", true, false):
		var visual := candidate as MeshInstance3D
		if visual.has_meta("split_ground_size"):
			ground_visuals.append(visual)
	if ground_visuals.size() != 6:
		push_error("Wychwood needs all six split-ground visuals before terrain integration: %d/6" % ground_visuals.size())
		return false
	for index in ground_visuals.size():
		var visual := ground_visuals[index]
		if visual.mesh == null:
			push_error("Wychwood split ground lacks its prepared geometry")
			return false
		var source_material := visual.material_override as StandardMaterial3D
		if source_material == null or source_material.albedo_texture == null:
			push_error("Wychwood split ground lacks its authored forest material")
			return false
		var material := source_material.duplicate() as StandardMaterial3D
		material.resource_name = "WychwoodIntegratedTerrain"
		material.vertex_color_use_as_albedo = true
		visual.material_override = material
		visual.name = "WychwoodIntegratedGround_%d" % index
		visual.set_meta("wychwood_integrated_ground", true)
	return true
