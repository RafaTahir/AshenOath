extends SceneTree

## Resource checks only. Enactment, visibility and level acceptance are separate.
const Endings = preload("res://scripts/ending_catalog.gd")
const BASE := "res://assets_external/environment/forest/"
var failures: Array[String] = []
var rows: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var only_new := "--only-new" in OS.get_cmdline_user_args()
	for action: String in Endings.IDS:
		if only_new and action in Endings.ORIGINAL_IDS:
			continue
		var covenant := Endings.covenant(action)
		var path := BASE + "HartAftermath_%s_Authored.res" % covenant
		var mesh := ResourceLoader.load(path, "ArrayMesh", ResourceLoader.CACHE_MODE_IGNORE) as ArrayMesh
		if mesh == null:
			_fail("Missing aftermath mesh: " + covenant)
			continue
		_check(str(mesh.get_meta("covenant", "")) == covenant, covenant + ": wrong covenant identity")
		_check(mesh.get_surface_count() == 2, covenant + ": expected ground and monument surfaces")
		var triangles := 0
		for surface in mesh.get_surface_count():
			_check(mesh.surface_get_primitive_type(surface) == Mesh.PRIMITIVE_TRIANGLES, covenant + ": non-triangle surface")
			var arrays := mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			_check(not vertices.is_empty() and normals.size() == vertices.size() and colors.size() == vertices.size(), covenant + ": missing surface attributes")
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
			var count := vertices.size() if indices.is_empty() else indices.size()
			_check(count > 0 and count % 3 == 0, covenant + ": incomplete triangles")
			triangles += count / 3
			for index in indices:
				_check(index >= 0 and index < vertices.size(), covenant + ": invalid vertex index")
			for point in vertices:
				_check(point.is_finite(), covenant + ": nonfinite vertex")
			for normal in normals:
				_check(normal.is_finite() and normal.length_squared() > 0.000001, covenant + ": invalid normal")
			for color in colors:
				_check(is_finite(color.r) and is_finite(color.g) and is_finite(color.b) and is_finite(color.a), covenant + ": nonfinite palette color")
			var material := mesh.surface_get_material(surface) as StandardMaterial3D
			_check(material != null and material.vertex_color_use_as_albedo, covenant + ": palette material missing")
		var obstacles: Variant = mesh.get_meta("obstacles", [])
		_check(obstacles is Array and not obstacles.is_empty(), covenant + ": collision metadata missing")
		if obstacles is Array:
			for obstacle: Variant in obstacles:
				if not obstacle is Dictionary or not obstacle.get("centre") is Vector3 or not obstacle.get("size") is Vector3:
					_fail(covenant + ": malformed obstacle")
					continue
				var centre: Vector3 = obstacle.centre
				var size: Vector3 = obstacle.size
				_check(centre.is_finite() and size.is_finite() and size.x > 0 and size.y > 0 and size.z > 0, covenant + ": invalid collision bounds")
				if covenant == "open_road":
					# Laid-down boundary stones and record cases leave the authored
					# central outward path open. This is not a player movement test.
					var bounds := AABB(centre - size * 0.5, size)
					var path_bounds := AABB(Vector3(-1.2, 0.0, -15.0), Vector3(2.4, 2.0, 6.0))
					_check(not bounds.intersects(path_bounds), "open_road: collision blocks the outward corridor")
		rows.append({"action":action,"covenant":covenant,"path":path,"sha256":FileAccess.get_sha256(path),"bytes":FileAccess.get_file_as_bytes(path).size(),"triangles":triangles,"obstacles":obstacles.size() if obstacles is Array else 0})
	_check(rows.size() == (2 if only_new else Endings.IDS.size()), "Aftermath resource set is incomplete")
	print("HART_AFTERMATH_ASSETS " + JSON.stringify({"status":"pass" if failures.is_empty() else "fail","only_new":only_new,"resources":rows,"failures":failures,"enactment_verified":false,"visual_acceptance":false,"gameplay_acceptance":false}))
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, reason: String) -> void:
	if not condition:
		_fail(reason)

func _fail(reason: String) -> void:
	if not failures.has(reason):
		failures.append(reason)
		push_error(reason)
