extends SceneTree

const RiverSection = preload("res://scripts/zones/river_section.gd")
var failures: Array[String] = []

func _initialize() -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	var river := RiverSection.new()
	for side in [-1.0, 1.0]:
		river._make_bank_slope(parent, "Bank", 4.5 + side * 1.7, 42.0, side)
	for bank in parent.get_children():
		var mesh: ArrayMesh = bank.mesh
		var arrays := mesh.surface_get_arrays(0)
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var faces := mesh.get_faces()
		var wrong_normals := 0
		var wrong_faces := 0
		for normal in normals:
			if normal.y < 0.2:
				wrong_normals += 1
		for index in range(0, faces.size(), 3):
			# Godot renders clockwise front faces; banks must face above the water.
			if (faces[index + 1] - faces[index]).cross(faces[index + 2] - faces[index]).y >= 0.0:
				wrong_faces += 1
		if wrong_faces > 0 or wrong_normals > 0:
			failures.append("%s: below-facing triangles=%d normals=%d" % [bank.name, wrong_faces, wrong_normals])
		if mesh.surface_get_material(0) == null and bank.material_override == null:
			failures.append("Bank has no active material")
	parent.free()
	for failure in failures:
		push_error(failure)
	print("RIVER BANK FRONT-FACE CONTRACT: %s (geometry only)" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
