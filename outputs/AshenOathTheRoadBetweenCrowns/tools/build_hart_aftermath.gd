extends "res://tools/build_hart_landscape.gd"

const Endings = preload("res://scripts/ending_catalog.gd")

func _initialize() -> void:
	for ending: String in Endings.IDS:
		var covenant := Endings.covenant(ending)
		if "--only-new" in OS.get_cmdline_user_args() and ending in Endings.ORIGINAL_IDS: continue
		ground = SurfaceTool.new()
		stone = SurfaceTool.new()
		ground.begin(Mesh.PRIMITIVE_TRIANGLES)
		stone.begin(Mesh.PRIMITIVE_TRIANGLES)
		var obstacles: Array[Dictionary] = []
		var earth := Color(0.48, 0.62, 0.42) if covenant == "mercy" else (Color(0.16, 0.15, 0.13) if covenant == "ash" else Color(0.48, 0.50, 0.40))
		if covenant == "open_road": earth = Color(0.37, 0.33, 0.25)
		for segment in range(28):
			var a := TAU * segment / 28.0
			var b := TAU * (segment + 1) / 28.0
			var centre := Vector3(0, 0.049, -11.8)
			_vertex(ground, centre, earth)
			_vertex(ground, centre + Vector3(cos(b) * (4.4 + sin(b * 5) * 0.25), 0, sin(b) * 3.0), earth.lightened(0.12))
			_vertex(ground, centre + Vector3(cos(a) * (4.4 + sin(a * 5) * 0.25), 0, sin(a) * 3.0), earth.lightened(0.12))
		for index in range(5):
			var x := (index - 2) * 1.35
			var position := Vector3(x, 0.055, -12.0 - (2 - absi(index - 2)) * 0.35)
			var height: float = 1.45 + (2 - absi(index - 2)) * 0.30
			if covenant == "concord":
				# Equal low work stones leave empty places between responsibilities;
				# the actual consenting keepers are recorded by the ending owner.
				position = Vector3((index - 2) * 1.65, 0.055, -12.0 - (1.0 if index % 2 else 0.0))
				height = 0.72
			elif covenant == "open_road":
				# Boundary stones are laid down beside a clear outward path. Human
				# records travel in ordinary cases; no replacement magic seal remains.
				position = Vector3(-3.6 if index % 2 == 0 else 3.6, 0.055, -13.4 + index * 0.7)
			var fragment := SurfaceTool.new()
			fragment.begin(Mesh.PRIMITIVE_TRIANGLES)
			_monolith(fragment, Vector3.ZERO, height, 0.86, 0.48)
			fragment.generate_normals()
			var source := fragment.commit()
			var basis := Basis.IDENTITY
			if covenant in ["mercy", "ash", "open_road"]:
				basis = Basis(Vector3.UP, 0.20 * (index - 2)) * Basis(Vector3.RIGHT, deg_to_rad(78.0 if covenant == "mercy" else 96.0))
				if covenant == "open_road": basis = Basis(Vector3.UP, PI / 2) * Basis(Vector3.RIGHT, PI / 2)
				position.y = 0.055 - (Transform3D(basis, Vector3.ZERO) * source.get_aabb()).position.y
			var bounds: AABB = Transform3D(basis, position) * source.get_aabb()
			obstacles.append({"centre": bounds.get_center(), "size": bounds.size})
			_append_fragment(stone, source, Transform3D(basis, position), Color(0.85, 0.81, 0.66) if covenant == "witness" else (Color(0.25, 0.23, 0.21) if covenant == "ash" else Color(0.64, 0.73, 0.65)))
		if covenant == "mercy":
			for position in [Vector3(-3.1, 0.055, -11), Vector3(3.1, 0.055, -11), Vector3(-1.6, 0.055, -10.2), Vector3(1.6, 0.055, -10.2)]:
				for leaf in range(9):
					var angle := TAU * leaf / 9.0
					var direction := Vector3(cos(angle), 0, sin(angle))
					var side := Vector3(-direction.z, 0, direction.x) * 0.11
					var mid: Vector3 = position + direction * 0.35 + Vector3.UP * 0.34
					var tip: Vector3 = position + direction * 0.76 + Vector3.UP * 0.20
					for point in [position, mid + side, tip, position, tip, mid - side]:
						_vertex(ground, point, Color(0.27, 0.48, 0.25))
		if covenant == "duty":
			# Interlocked iron links bind the retained names, rather than another
			# decorative glowing ring at the creature's feet.
			for link in range(36):
				var mesh := TorusMesh.new()
				mesh.inner_radius = 0.058
				mesh.outer_radius = 0.082
				mesh.rings = 8
				mesh.ring_segments = 4
				var source := ArrayMesh.new()
				source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh.get_mesh_arrays())
				var basis := Basis(Vector3.FORWARD, PI / 2 if link % 2 == 0 else 0.0)
				_append_fragment(stone, source, Transform3D(basis, Vector3(-2.62 + link * 0.15, 1.15, -11.69)), Color(0.23, 0.27, 0.28))
		if covenant in ["concord", "open_road"]:
			for index in 3:
				var case_mesh := BoxMesh.new()
				case_mesh.size = Vector3(0.55, 0.20, 0.38)
				var source := ArrayMesh.new()
				source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, case_mesh.get_mesh_arrays())
				var position := Vector3((index - 1) * 1.65, 0.875, -12.0 - (1.0 if (index + 1) % 2 else 0.0)) if covenant == "concord" else Vector3(4.5, 0.16, -12.2 + index * 0.65)
				_append_fragment(stone, source, Transform3D(Basis.IDENTITY, position), Color(0.36, 0.25, 0.15))
				if covenant == "open_road": obstacles.append({"centre":position, "size":case_mesh.size})
		ground.generate_normals()
		ground.index()
		stone.generate_normals()
		stone.index()
		var result := ground.commit()
		stone.commit(result)
		for surface in result.get_surface_count():
			var material := StandardMaterial3D.new()
			material.vertex_color_use_as_albedo = true
			material.roughness = 0.96
			result.surface_set_material(surface, material)
		result.set_meta("source", "Original Ashen Oath consequential witness garden")
		result.set_meta("covenant", covenant)
		result.set_meta("obstacles", obstacles)
		var path := BASE + "HartAftermath_%s_Authored.res" % covenant
		var error := ResourceSaver.save(result, path, ResourceSaver.FLAG_COMPRESS)
		if error != OK:
			push_error(error_string(error))
			quit(1)
			return
		print("HART AFTERMATH BAKE: %s surfaces=%d triangles=%d bytes=%d" % [covenant, result.get_surface_count(), result.get_faces().size() / 3, FileAccess.get_file_as_bytes(path).size()])
	quit(0)

func _append_fragment(target: SurfaceTool, source: ArrayMesh, transform: Transform3D, tint: Color) -> void:
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var order: Array[int] = []
		if indices.is_empty():
			for index in vertices.size():
				order.append(index)
		else:
			for index in indices:
				order.append(index)
		for index in order:
			_vertex(target, transform * vertices[index], tint * colors[index] if not colors.is_empty() else tint)
