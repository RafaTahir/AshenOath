extends SceneTree

const ROOT := "res://assets_external/environment/village/"
const SURFACE_COUNTS := {"chapel": 3, "bell_frame": 2, "bell": 1, "grave_rows": 1, "boundary": 4, "grave_earth": 1, "memory_window": 2, "grave_harl": 2, "grave_child": 2, "grave_soldier": 2, "disturbed_soil": 1}
var failures: Array[String] = []

func _initialize() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://runtime_asset_manifest.json"))
	var presets := ConfigFile.new()
	_check(presets.load("res://export_presets.cfg") == OK, "Unreadable cemetery export ownership")
	var total := 0
	for id in SURFACE_COUNTS:
		var path := ROOT + "Cemetery_%s_Authored.res" % id
		var mesh := load(path) as ArrayMesh
		_check(mesh != null, "Required cemetery assembly missing: " + id)
		if mesh == null:
			continue
		total += FileAccess.get_file_as_bytes(path).size()
		var matched := false
		for entry: Dictionary in manifest.get("authored_environment_derivatives", []):
			if entry.get("path", "") != path:
				continue
			matched = true
			_check(entry.get("bytes", 0) == FileAccess.get_file_as_bytes(path).size() and entry.get("sha256", "") == FileAccess.get_sha256(path), "Stale cemetery derivative identity: " + id)
			_check(entry.get("pack_owner", "") == "base", "Cemetery preload has no base pack owner: " + id)
			if id in ["chapel", "bell_frame", "boundary"]:
				_check(FileAccess.file_exists(entry.get("license_file", "")), "Cemetery kit license missing: " + id)
		_check(matched, "Cemetery resource is absent from the runtime manifest: " + id)
		for preset_id in [0, 1, 2]:
			_check(path.trim_prefix("res://") in str(presets.get_value("preset.%d" % preset_id, "include_filter", "")).split(","), "Cemetery production/QA/base ownership drift: " + id)
		_check(mesh.get_meta("role", "") == id, "Cemetery assembly identity mismatch: " + id)
		var hashes: Dictionary = mesh.get_meta("source_sha256", {})
		_check(hashes.size() == 4, "Cemetery source provenance missing: " + id)
		for source in hashes:
			_check(hashes[source] == FileAccess.get_sha256(ROOT + source), "Cemetery source hash changed: " + source)
		_check(mesh.get_surface_count() == SURFACE_COUNTS[id], "Cemetery surface budget changed: " + id)
		for surface in mesh.get_surface_count():
			_check(mesh.surface_get_material(surface) != null, "Null cemetery material: " + id)
			var arrays := mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			_check(normals.size() == points.size(), "Cemetery normals missing: " + id)
			for point in points:
				_check(point.is_finite(), "Nonfinite cemetery vertex: " + id)
				if id == "chapel":
					_check(not (point.x < -1.15 and point.y > 0.1 and point.y < 2.20 and absf(point.z) < 0.79), "Chapel assembly enters the physical doorway")
			if id in ["grave_earth", "disturbed_soil"]:
				var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
				_check(uvs.size() == points.size(), "Grave soil UVs are missing")
				for point_index in mini(uvs.size(), points.size()):
					_check(uvs[point_index].distance_to(Vector2(points[point_index].x, points[point_index].z)) < 0.001, "Grave soil UV projection collapses into stripes")
				for normal in normals:
					_check(normal.y > 0.7, "Grave soil is inverted or unreadably steep")
		var bounds := mesh.get_aabb()
		if id == "chapel":
			_check(bounds.size.y > 3.5 and bounds.size.y < 3.9 and bounds.size.z > 3.9, "Chapel roof/footprint lost its fitted shape")
		elif id == "bell_frame":
			_check(absf(bounds.position.y) < 0.003 and bounds.size.y > 2.7, "Bell structure lost its grounded support")
		elif id == "bell":
			var faces := mesh.get_faces()
			var mouth := 0
			for index in range(0, faces.size(), 3):
				var a := faces[index]
				var b := faces[index + 1]
				var c := faces[index + 2]
				if is_equal_approx(a.y, -0.25) and is_equal_approx(b.y, -0.25) and is_equal_approx(c.y, -0.25):
					mouth += 1
					_check(minf(Vector2(a.x, a.z).length(), minf(Vector2(b.x, b.z).length(), Vector2(c.x, c.z).length())) > 0.28, "Bell mouth has a solid cap instead of a hollow rim")
			_check(mouth == 48, "Bell hollow mouth/rim is incomplete")
		elif id == "grave_rows":
			_check(absf(bounds.position.y - 0.002) < 0.001 and mesh.get_faces().size() / 3 == 216, "Nine grave markers lost grounded complete geometry")
		elif id == "boundary":
			_check(absf(bounds.size.y - 0.9) < 0.001 and mesh.get_faces().size() / 3 == 560, "Courtyard boundary changed height or lost modular sections")
		elif id == "memory_window":
			var glazing := mesh.surface_get_material(1) as StandardMaterial3D
			_check(glazing != null and glazing.emission_enabled and glazing.emission_energy_multiplier >= 0.4 and glazing.emission_energy_multiplier <= 0.55 and glazing.albedo_color.g <= 0.36, "Chapel glazing lost its readable, restrained emission")
	var presentation := preload("res://scripts/cemetery_evidence_presentation.gd")
	for id in ["grave_harl", "grave_child", "grave_soldier", "grave_bell", "chapel_door", "chapel_names"]:
		var area := Node3D.new()
		_check(presentation.apply(area, id), "Cemetery evidence mapping missing: " + id)
		_check(area.find_children("*", "CollisionObject3D", true, false).is_empty(), "Cemetery visual adds route collision: " + id)
		if id.begins_with("grave_"):
			var marker := area.get_node_or_null("CemeteryMemorialEvidence") as MeshInstance3D
			_check(marker != null and marker.mesh is ArrayMesh and marker.mesh.get_surface_count() == 2, "Cemetery evidence uses generic proxy geometry: " + id)
			if marker != null:
				_check(absf(marker.position.y + marker.mesh.get_aabb().position.y - 0.053) < 0.001, "Cemetery evidence lost its court support: " + id)
		else:
			_check(area.get_meta("external_clue_visual", "") == "CrowChapelAuthoredArchitecture", "Chapel interaction lost its external architecture identity")
		area.free()
	_check(total < 150000, "Cemetery assembly exceeds its 150 KB budget")
	print("CEMETERY ARCHITECTURE RESOURCE CONTRACT: %s bytes=%d (not visual/route/performance acceptance)" % ["PASS" if failures.is_empty() else "FAIL", total])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
