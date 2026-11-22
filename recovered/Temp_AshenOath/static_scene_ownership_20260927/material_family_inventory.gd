extends SceneTree

func _initialize() -> void:
	var scene: Node = load("D:/Temp/AshenOath/static_scene_ownership_20260927/static_snapshot.scn").instantiate()
	var materials: Dictionary = {}
	for node in scene.get_children():
		var mesh: Mesh = node.mesh if node is MeshInstance3D else node.multimesh.mesh
		if node.material_override != null:
			materials[node.material_override] = true
		if node.material_overlay != null:
			materials[node.material_overlay] = true
		for surface in mesh.get_surface_count():
			var material: Material = mesh.surface_get_material(surface)
			if material != null:
				materials[material] = true
			if node is MeshInstance3D and node.get_surface_override_material(surface) != null:
				materials[node.get_surface_override_material(surface)] = true
	var rows: Array[Dictionary] = []
	for material in materials:
		var row: Dictionary = {"class": material.get_class(), "name": material.resource_name, "properties": {}}
		for entry in material.get_property_list():
			var property := str(entry.name)
			if not (int(entry.usage) & PROPERTY_USAGE_STORAGE) or property.begins_with("resource_") or property == "script":
				continue
			var value = material.get(property)
			row.properties[property] = value.resource_path if value is Resource else value
		rows.append(row)
	var file := FileAccess.open("D:/Temp/AshenOath/static_scene_ownership_20260927/material_family_inventory.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, "\t"))
	file.close()
	print("MATERIAL_FAMILY_INVENTORY: %d final source materials" % rows.size())
	materials.clear()
	scene.free()
	quit()
