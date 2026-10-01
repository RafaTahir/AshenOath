extends SceneTree

const ROOT := "res://assets_external/environment/forest/"
const IDS := ["corpse", "black_feathers", "oren_token", "claw_marks", "tracks"]
var failures: Array[String] = []

func _initialize() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://runtime_asset_manifest.json"))
	var presets := ConfigFile.new()
	_check(presets.load("res://export_presets.cfg") == OK, "Unreadable export ownership")
	var total := 0
	for id in IDS:
		var path := ROOT + "Wychwood_%s_Evidence.res" % id
		var mesh := load(path) as ArrayMesh
		_check(mesh != null, "Required evidence missing: " + id)
		if mesh == null:
			continue
		total += FileAccess.get_file_as_bytes(path).size()
		_check(mesh.get_meta("clue_identity", "") == id, "Evidence identity changed: " + id)
		var matched := false
		for entry: Dictionary in manifest.get("authored_environment_derivatives", []):
			if entry.get("path", "") != path:
				continue
			matched = true
			_check(entry.get("sha256", "") == FileAccess.get_sha256(path) and entry.get("bytes", 0) == FileAccess.get_file_as_bytes(path).size(), "Stale evidence identity: " + id)
			_check(entry.get("pack_owner", "") == "opening" and FileAccess.file_exists(entry.get("license_file", "")), "Missing evidence owner/license: " + id)
		_check(matched, "Evidence absent from canonical asset manifest: " + id)
		for preset in [0, 1, 3]:
			_check(path.trim_prefix("res://") in str(presets.get_value("preset.%d" % preset, "include_filter", "")).split(","), "Production/QA/opening ownership drift: " + id)
		var hashes: Dictionary = mesh.get_meta("source_sha256", {})
		_check(hashes.size() == 2, "Evidence provenance missing: " + id)
		for source in hashes:
			_check(hashes[source] == FileAccess.get_sha256(source), "Evidence source changed: " + id)
		_check(mesh.get_surface_count() <= 3 and mesh.get_surface_count() > 0, "Evidence surface budget failed: " + id)
		for surface in mesh.get_surface_count():
			_check(mesh.surface_get_material(surface) != null, "Null evidence material: " + id)
			var arrays := mesh.surface_get_arrays(surface)
			_check(arrays[Mesh.ARRAY_BONES] == null and arrays[Mesh.ARRAY_WEIGHTS] == null, "Static evidence retained skeletal processing: " + id)
			for point: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				_check(point.is_finite(), "Nonfinite evidence vertex: " + id)
		_check(mesh.get_aabb().position.y >= -0.001, "Unsupported evidence: " + id)
		if id == "corpse":
			_check(mesh.get_aabb().size.y < 0.5 and mesh.get_aabb().size.z > 1.5 and mesh.surface_get_name(0).begins_with("BramCompleteBody"), "Corpse lost its full authored death pose")
	_check(total < 450000, "Evidence payload exceeds 450 KB")
	var ground := load("res://scripts/world_material_library.gd").make_organic_ground_patch(Vector3(8, 0.04, 12), Vector3(7, 0, 4)) as ArrayMesh
	var arrays := ground.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	_check(points.size() == 25, "Organic patch lost bounded silhouette")
	for i in points.size():
		_check(absf(points[i].x) < 4 and absf(points[i].z) < 6, "Organic patch escaped its original visual envelope")
		_check(uvs[i].distance_to(Vector2(points[i].x + 7, points[i].z + 4)) < 0.001, "Organic terrain lost world-metre UVs")
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in range(0, indices.size(), 3):
		_check((points[indices[i + 2]] - points[indices[i]]).cross(points[indices[i + 1]] - points[indices[i]]).y > 0, "Organic terrain winding hides its top")
	print("WYCHWOOD EVIDENCE RESOURCE CONTRACT: %s bytes=%d (not route/visual/performance acceptance)" % ["PASS" if failures.is_empty() else "FAIL", total])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
