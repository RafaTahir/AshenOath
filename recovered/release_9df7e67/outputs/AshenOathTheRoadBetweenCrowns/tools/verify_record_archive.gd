extends SceneTree

const PATH := "res://assets_external/environment/props/RecordArchive_Authored.res"
const Castle = preload("res://scripts/zones/castle_vargan_section.gd")
var failures := 0

func _initialize() -> void:
	var mesh := load(PATH) as ArrayMesh
	check(mesh != null, "Required archive mesh is unavailable")
	if mesh != null:
		check(mesh.get_surface_count() == 2, "Archive batching must retain two surfaces")
		check(int(mesh.get_meta("cabinet_count", 0)) == 20, "An archive cabinet was removed")
		check(int(mesh.get_meta("book_group_count", 0)) == 120, "Archive contents are incomplete")
		check(mesh.get_meta("cabinet_recipe", "") == "wide-inward-75deg-v1", "Archive composition recipe is stale")
		var cabinets: Array = mesh.get_meta("cabinet_bounds", [])
		check(cabinets.size() == 20, "Cabinet clearance metadata is incomplete")
		var aisle := AABB(Vector3(-3.5, 0, -14), Vector3(7, 2.2, 28))
		var east_arrival := AABB(Vector3(4.8, 0, -14.5), Vector3(2.4, 2.2, 3))
		var west_return := AABB(Vector3(-7.2, 0, 11.5), Vector3(2.4, 2.2, 3))
		for cabinet: AABB in cabinets:
			check(not cabinet.intersects(aisle), "Cabinet invades the central physical route")
			check(not cabinet.intersects(east_arrival), "Cabinet invades the undercroft approach")
			check(not cabinet.intersects(west_return), "Cabinet invades the courtyard return")
		check(mesh.get_aabb().position.y >= -0.002, "Furniture is below the physical floor")
		check(mesh.get_aabb().end.y <= 2.151, "Archive furniture exceeds its authored height")
		check(FileAccess.get_file_as_bytes(PATH).size() < 2000000, "Archive exceeds its two-MB artifact budget")
		var hashes: Dictionary = mesh.get_meta("source_sha256", {})
		for source in mesh.get_meta("source_files", []):
			check(hashes.get(source, "") == FileAccess.get_sha256("res://assets_external/environment/props/" + source), "Source revision drift: " + source)
		for surface in mesh.get_surface_count():
			check(mesh.surface_get_material(surface) != null, "Null archive material")
			var arrays := mesh.surface_get_arrays(surface)
			check(not (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).is_empty(), "Archive geometry was not indexed")
			check((arrays[Mesh.ARRAY_COLOR] as PackedColorArray).size() == (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), "Archive color data is incomplete")
		var preset := FileAccess.get_file_as_string("res://export_presets.cfg")
		check(preset.contains("campaign_finale_section.gd,assets_external/environment/props/RecordArchive_Authored.res"), "Campaign pack omits its required archive mesh")
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://runtime_asset_manifest.json"))
		var entry: Dictionary = {}
		for candidate in manifest.get("authored_environment_derivatives", []):
			if candidate.get("id", "") == "record_hall_archive":
				entry = candidate
		check(not entry.is_empty(), "Archive manifest entry is missing")
		check(entry.get("path", "") == PATH and entry.get("sha256", "") == FileAccess.get_sha256(PATH), "Archive manifest hash drift")
		check(int(entry.get("bytes", 0)) == FileAccess.get_file_as_bytes(PATH).size(), "Archive manifest byte-size drift")
		check(FileAccess.file_exists(str(entry.get("license_file", ""))), "Archive source license is missing")
	_check_architecture_uvs()
	print("RECORD ARCHIVE RESOURCE CONTRACT: %s (not visual or player-route acceptance)" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _check_architecture_uvs() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var builder := Castle.new()
	for triangle in [
		[Vector3(0, 0, 0), Vector3(0, 3, 0), Vector3(0, 0, 4)],
		[Vector3(0, 0, 0), Vector3(4, 0, 0), Vector3(0, 0, 3)],
		[Vector3(0, 0, 0), Vector3(4, 0, 0), Vector3(0, 3, 0)]]:
		builder._add_record_hall_triangle(surface, triangle[0], triangle[1], triangle[2])
	var mesh := surface.commit()
	mesh.surface_set_material(0, StandardMaterial3D.new())
	var arrays := mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	for index in points.size():
		var point := points[index]
		var normal := normals[index]
		var expected := Vector2(point.z, point.y) if absf(normal.x) > 0.5 else (Vector2(point.x, point.z) if absf(normal.y) > 0.5 else Vector2(point.x, point.y))
		check(uvs[index].is_equal_approx(expected), "Architecture UVs apply the material's metre scale twice")
