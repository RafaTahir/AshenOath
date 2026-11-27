extends SceneTree
## Godot 4.6, --headless --path PROJECT --script /path/to/this.gd -- INPUT.json OUTPUT_DIR
## Preserve Greyfen forge surface settings while keeping the deferred asset independent.
const FORGE := "res://assets_external/environment/props/GreyfenForgeWork_Authored.res"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Pass exported geometry JSON and a parts directory")
		quit(1)
		return
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var forge := load(FORGE) as ArrayMesh
	if not source is Dictionary or forge == null or forge.get_surface_count() == 0:
		push_error("Expected strongbox source and the Greyfen forge material")
		quit(1)
		return
	var base := forge.surface_get_material(0) as StandardMaterial3D
	if base == null or not base.vertex_color_use_as_albedo:
		push_error("Unexpected forge material")
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(args[1]) != OK:
		push_error("Cannot create mesh output directory")
		quit(1)
		return
	for part: String in ["Case", "Lid", "ClerkBarrel", "HouseholdBarrel", "CoinTray", "WrappedVolume"]:
		if not source.has(part) or source[part].is_empty():
			push_error("Missing part: " + part)
			quit(1)
			return
		var mesh := ArrayMesh.new()
		mesh.resource_name = "North kitchen " + part
		for finish: String in source[part]:
			var material := base.duplicate() as StandardMaterial3D
			material.resource_name = "Greyfen forged iron" if finish == "forge" else "Faded ledger cloth"
			material.metallic = 0.48 if finish == "forge" else 0.0
			material.roughness = 0.78 if finish == "forge" else 0.91
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			surface.set_material(material)
			var vertices: Array = source[part][finish]
			if vertices.is_empty() or vertices.size() % 3 != 0:
				push_error("Incomplete surface: " + part)
				quit(1)
				return
			for v: Array in vertices:
				surface.set_normal(Vector3(v[3], v[4], v[5]).normalized())
				surface.set_color(Color(v[6], v[7], v[8], 1))
				surface.add_vertex(Vector3(v[0], v[1], v[2]))
			surface.index()
			surface.commit(mesh)
		if part == "Lid":
			mesh = _pried_lid(mesh)
		var error := ResourceSaver.save(mesh, args[1].path_join(part.to_snake_case() + ".res"), ResourceSaver.FLAG_COMPRESS)
		if error != OK:
			push_error("Failed writing " + part + ": " + error_string(error))
			quit(1)
			return
		print(part, ": ", mesh.get_faces().size() / 3, " triangles")
	quit(0)


# In the later retrieval the left rear hinge tears while the household lock holds.
# Displacement rises toward that corner. Analytic derivatives carry surface normals
# through the fold, so the old bevels and band highlights bend with the sheet iron.
func _pried_lid(rest: ArrayMesh) -> ArrayMesh:
	var bent := ArrayMesh.new()
	bent.resource_name = rest.resource_name
	bent.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_RELATIVE
	bent.add_blend_shape(&"PriedCorner")
	for surface in rest.get_surface_count():
		var arrays := rest.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var shifts := PackedVector3Array()
		var normal_shifts := PackedVector3Array()
		for i in vertices.size():
			var p := vertices[i]
			var left := clampf((-p.x + 0.012) / 0.265, 0.0, 1.0)
			var rear := clampf((p.z + 0.31) / 0.28, 0.0, 1.0)
			var lift := 0.082 * left * left * (0.12 + 0.88 * rear * rear)
			shifts.append(Vector3(0, lift, 0))
			var dx := -0.164 * left * (0.12 + 0.88 * rear * rear) / 0.265 if left > 0 and left < 1 else 0.0
			var dz := 0.082 * left * left * 1.76 * rear / 0.28 if rear > 0 and rear < 1 else 0.0
			var n := normals[i]
			normal_shifts.append(Vector3(n.x - dx*n.y, n.y, n.z - dz*n.y).normalized() - n)
		var shape: Array = []
		shape.resize(Mesh.ARRAY_MAX)
		shape[Mesh.ARRAY_VERTEX] = shifts
		shape[Mesh.ARRAY_NORMAL] = normal_shifts
		# SurfaceTool does not generate tangents for this vertex-painted mesh.
		# Preserve any Godot-synthesized tangent channel with zero relative deltas.
		if arrays[Mesh.ARRAY_TANGENT] != null:
			var stationary := PackedFloat32Array()
			stationary.resize(vertices.size() * 4)
			shape[Mesh.ARRAY_TANGENT] = stationary
		bent.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [shape])
		bent.surface_set_material(surface, rest.surface_get_material(surface))
	return bent
