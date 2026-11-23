extends RefCounted

static func decorate(anchor: Node3D, kind: String, quality: String) -> Dictionary:
	var decorations: Dictionary = {}
	if kind == "notice_board":
		for index in range(3):
			var paper := MeshInstance3D.new()
			paper.name = "NoticePaper_%02d" % index
			var paper_mesh := BoxMesh.new()
			paper_mesh.size = Vector3(0.30 + float(index % 2) * 0.06, 0.34, 0.025)
			paper.mesh = paper_mesh
			paper.position = Vector3(-0.48 + float(index) * 0.46, 1.16 + float(index % 2) * 0.07, -0.09)
			paper.rotation_degrees.z = -5.0 + float(index) * 7.0
			paper.material_override = _material(Color(0.68, 0.58, 0.39))
			decorations[paper] = "paper"
			anchor.add_child(paper)
	elif kind == "forge":
		var count := 2 if quality == "potato" else 3
		for index in range(count):
			var spark := MeshInstance3D.new()
			spark.name = "ForgeSpark_%02d" % index
			var spark_mesh := SphereMesh.new()
			spark_mesh.radial_segments = 5
			spark_mesh.rings = 3
			spark.mesh = spark_mesh
			spark.scale = Vector3.ONE * 0.045
			spark.position = Vector3(-0.22 + float(index) * 0.20, 0.72 + float(index % 2) * 0.16, 0.0)
			spark.material_override = _emissive_material(Color(1.0, 0.42, 0.10), 1.25)
			decorations[spark] = "forge"
			anchor.add_child(spark)
	elif kind == "shrine":
		var ember := MeshInstance3D.new()
		ember.name = "ShrineEmber"
		var ember_mesh := SphereMesh.new()
		ember_mesh.radial_segments = 5
		ember_mesh.rings = 3
		ember.mesh = ember_mesh
		ember.scale = Vector3(0.06, 0.11, 0.06)
		ember.position = Vector3(0.0, 1.46, -0.24)
		ember.material_override = _emissive_material(Color(0.64, 0.86, 0.60), 0.75)
		decorations[ember] = "shrine"
		anchor.add_child(ember)

	return decorations

static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	return material

static func _emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := _material(color)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
