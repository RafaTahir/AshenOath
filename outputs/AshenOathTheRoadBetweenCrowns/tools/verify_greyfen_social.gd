extends SceneTree

const ROOT := "res://assets_external/environment/props/"
var failures: Array[String] = []

func _initialize() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://runtime_asset_manifest.json"))
	var presets := ConfigFile.new()
	_check(presets.load("res://export_presets.cfg") == OK, "Export presets are unreadable")
	var total_bytes := 0
	for id in ["common_table", "barrel_board", "mira_apothecary"]:
		var path := ROOT + "GreyfenSocial_%s.res" % id
		var mesh := load(path) as ArrayMesh
		_check(mesh != null, "Required social furniture missing: " + id)
		if mesh == null:
			continue
		total_bytes += FileAccess.get_file_as_bytes(path).size()
		var entries: Array = manifest.get("authored_environment_derivatives", [])
		var matched := false
		for entry in entries:
			if entry.get("path", "") != path:
				continue
			matched = true
			_check(entry.get("bytes", 0) == FileAccess.get_file_as_bytes(path).size() and entry.get("sha256", "") == FileAccess.get_sha256(path), "Furniture release metadata is stale: " + id)
			_check(entry.get("pack_owner", "") == "base" and FileAccess.file_exists(entry.get("license_file", "")), "Furniture owner/license missing: " + id)
		_check(matched, "Furniture derivative is absent from the runtime manifest: " + id)
		for preset_id in [0, 1, 2]:
			var filter := str(presets.get_value("preset.%d" % preset_id, "include_filter", ""))
			_check(path.trim_prefix("res://") in filter.split(","), "Furniture absent from production/QA/base pack ownership: " + id)
		_check(mesh.get_surface_count() == 2, "Furniture surface budget drift: " + id)
		_check(mesh.get_aabb().position.y >= -0.002, "Furniture extends below its grounded origin: " + id)
		_check(mesh.get_meta("role", "") == id and mesh.get_meta("license", "") == "CC0 1.0", "Furniture role/license identity drift: " + id)
		var hashes: Dictionary = mesh.get_meta("source_sha256", {})
		_check(hashes.size() == 6, "Furniture source provenance is incomplete: " + id)
		for source in hashes:
			_check(hashes[source] == FileAccess.get_sha256(ROOT + source), "Furniture source changed: " + source)
		for part in mesh.get_surface_count():
			_check(mesh.surface_get_material(part) != null, "Null furniture material: " + id)
			var arrays := mesh.surface_get_arrays(part)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			_check((arrays[Mesh.ARRAY_COLOR] as PackedColorArray).size() == vertices.size(), "Furniture lost its material colors: " + id)
			for point in vertices:
				_check(point.is_finite(), "Nonfinite furniture geometry: " + id)
			if id == "mira_apothecary" and part == 1:
				var counter := float(mesh.get_meta("counter_height", 0.0))
				var bottle_bottom := INF
				var bottle_top := -INF
				var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
				for index in vertices.size():
					if colors[index].g > 0.5 or colors[index].r > 0.6:
						bottle_bottom = minf(bottle_bottom, vertices[index].y)
						bottle_top = maxf(bottle_top, vertices[index].y)
				_check(counter > 0.7 and counter < 1.0 and mesh.get_meta("stock_count", 0) == 5, "Apothecary counter/stock contract missing")
				_check(absf(bottle_bottom - counter - 0.003) < 0.002 and absf(bottle_top - counter - 0.303) < 0.002, "Potion stock floats or intersects its measured support")
			if id != "mira_apothecary":
				var quadrants: Dictionary = {}
				for point in vertices:
					if point.y < 0.006 and absf(point.x) > 0.15:
						quadrants[Vector2i(1 if point.x > 0.0 else -1, 1 if point.z > 0.0 else -1)] = true
				_check(quadrants.size() == 4, "Table/seating geometry lacks grounded legs in all four quadrants: " + id)
	_check(total_bytes < 250000, "Social quarter meshes exceed the 250 KB budget")
	var presentation := preload("res://scripts/greyfen_social_presentation.gd")
	var area := Node3D.new()
	root.add_child(area)
	presentation.apply(area, "common_table")
	_check(area.find_children("*", "CollisionObject3D", true, false).is_empty(), "Visual furniture changes physical route collision")
	area.free()
	print("GREYFEN SOCIAL RESOURCE CONTRACT: %s bytes=%d (not visual/player-route/performance acceptance)" % ["PASS" if failures.is_empty() else "FAIL", total_bytes])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
