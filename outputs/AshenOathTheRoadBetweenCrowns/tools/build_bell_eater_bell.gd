extends SceneTree

# Original hollow bronze bell, authored as a lathed section with a broken lip.
# Bake once; gameplay loads the resulting mesh instead of generating surfaces.
func _initialize() -> void:
	var profile := [Vector2(0, 0.42), Vector2(0.11, 0.40), Vector2(0.16, 0.30), Vector2(0.18, 0.12), Vector2(0.23, -0.12), Vector2(0.34, -0.32), Vector2(0.48, -0.42), Vector2(0.48, -0.48), Vector2(0.40, -0.48), Vector2(0.30, -0.34), Vector2(0.19, -0.10), Vector2(0.14, 0.17), Vector2(0.10, 0.30), Vector2(0, 0.30)]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(profile.size() - 1):
		for segment in range(32):
			var corners := [Vector2i(ring, segment), Vector2i(ring + 1, segment), Vector2i(ring + 1, segment + 1), Vector2i(ring, segment + 1)]
			for index in [0, 2, 1, 0, 3, 2]:
				var corner: Vector2i = corners[index]
				var point: Vector2 = profile[corner.x]
				var angle := TAU * float(corner.y) / 32.0
				var chip := 0.14 if corner.y % 32 in [6, 7] and point.y < -0.3 else 0.0
				var patina := 0.20 + 0.12 * sin(angle * 3.0 + point.y * 7.0)
				surface.set_color(Color(0.48, 0.28, 0.10).lerp(Color(0.12, 0.27, 0.22), patina))
				surface.set_uv(Vector2(float(corner.y) / 32.0, point.y + 0.48))
				surface.add_vertex(Vector3(cos(angle) * point.x, point.y + chip, sin(angle) * point.x))
	surface.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.metallic = 0.65
	material.roughness = 0.62
	surface.set_material(material)
	var mesh := surface.commit()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/bosses"))
	var result := ResourceSaver.save(mesh, "res://assets/bosses/bell_eater_bell.res")
	print("BELL MESH BUILD: %s" % ("PASS" if result == OK else "FAIL"))
	quit(0 if result == OK else 1)
