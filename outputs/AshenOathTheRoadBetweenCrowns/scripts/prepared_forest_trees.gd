extends RefCounted

# This contract covers only the three trees whose runtime materials were already
# replaced in AssetSpawnHelper. Ordinary imported environment meshes retain
# their authored materials and must never enter this map.
const CONTRACT_VERSION := 1
const CATALOG_PATH := "res://data/prepared_forest_trees.json"
const ROOT := "res://assets_external/environment/prepared/"
const SOURCES := {
	"res://assets_external/environment/forest/CommonTree_5.obj": ROOT + "forest_tree_CommonTree_5.res",
	"res://assets_external/environment/forest/TwistedTree_2.obj": ROOT + "forest_tree_TwistedTree_2.res",
	"res://assets_external/environment/forest/TwistedTree_4.obj": ROOT + "forest_tree_TwistedTree_4.res",
}
const IGNORED_RESOURCE_PROPERTIES := ["resource_path", "resource_scene_unique_id", "resource_uid"]

static var _catalog: Dictionary = {}
static var _catalog_loaded := false

static func clear_cached_catalog() -> void:
	_catalog.clear()
	_catalog_loaded = false

static func is_source(source: String) -> bool:
	return SOURCES.has(source)

static func source_paths() -> Array[String]:
	var result: Array[String] = []
	for source: String in SOURCES:
		result.append(source)
	result.sort()
	return result

static func resource_path(source: String) -> String:
	return str(SOURCES.get(source, ""))

static func source_path(prepared: String) -> String:
	for source: String in SOURCES:
		if SOURCES[source] == prepared:
			return source
	return ""

static func entry(source: String) -> Dictionary:
	if not is_source(source):
		return {}
	if not _catalog_loaded:
		_catalog_loaded = true
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH)) if FileAccess.file_exists(CATALOG_PATH) else null
		if not parsed is Dictionary or parsed.size() != SOURCES.size():
			push_error("Required prepared forest tree catalog is missing or invalid")
			return {}
		_catalog = parsed
	var record: Variant = _catalog.get(source)
	if not record is Dictionary or not _valid_record(source, record):
		push_error("Required prepared forest tree certificate is missing or stale: " + source)
		return {}
	return record

static func _valid_record(source: String, record: Dictionary) -> bool:
	if int(record.get("contract_version", 0)) != CONTRACT_VERSION or record.get("source_path", "") != source or record.get("path", "") != resource_path(source):
		return false
	for field in ["compiled_sha256", "source_geometry_sha256", "geometry_sha256", "material_sha256"]:
		if str(record.get(field, "")).length() != 64:
			return false
	if record.source_geometry_sha256 != record.geometry_sha256 or int(record.get("compiled_bytes", 0)) <= 0:
		return false
	if not record.get("source_fingerprints") is Dictionary or not record.source_fingerprints.has(source):
		return false
	if not record.get("compiler_fingerprints") is Dictionary:
		return false
	if not record.get("surface_names") is Array or record.surface_names.size() < 2:
		return false
	if not record.get("aabb") is Array or record.aabb.size() != 6:
		return false
	return record.get("source_scene_dependencies", ["missing"]) == [] and record.get("resource_dependencies", ["missing"]) == []

static func material(surface_name: String) -> StandardMaterial3D:
	# Exact former AssetSpawnHelper._forest_tree_material values and defaults.
	var result := StandardMaterial3D.new()
	result.albedo_color = Color(0.27, 0.20, 0.15) if surface_name.begins_with("Bark_") else Color(0.12, 0.24, 0.13)
	result.roughness = 0.88
	return result

static func _material_document(value: StandardMaterial3D) -> Dictionary:
	var result: Dictionary = {}
	for property: Dictionary in value.get_property_list():
		var name := str(property.name)
		if property.usage & PROPERTY_USAGE_STORAGE and name not in IGNORED_RESOURCE_PROPERTIES and not name.begins_with("metadata/"):
			result[name] = value.get(name)
	return result

static func material_error(mesh: ArrayMesh) -> String:
	if mesh == null:
		return "mesh is null"
	for index in mesh.get_surface_count():
		var actual := mesh.surface_get_material(index) as StandardMaterial3D
		if actual == null:
			return "surface %d has no StandardMaterial3D" % index
		var expected := material(mesh.surface_get_name(index))
		var expected_properties := _material_document(expected)
		var actual_properties := _material_document(actual)
		if expected_properties != actual_properties:
			return "surface %d differs from the exact flat material contract" % index
	if mesh.shadow_mesh != null:
		return material_error(mesh.shadow_mesh)
	return ""

static func material_signature(mesh: ArrayMesh) -> String:
	var surfaces: Array = []
	for index in mesh.get_surface_count():
		surfaces.append([mesh.surface_get_name(index), _material_document(mesh.surface_get_material(index) as StandardMaterial3D)])
	if mesh.shadow_mesh != null:
		surfaces.append(["shadow_mesh", material_signature(mesh.shadow_mesh)])
	return var_to_bytes(surfaces).hex_encode().sha256_text()

static func geometry_signature(mesh: ArrayMesh) -> String:
	# Include serialized vertex/index/attribute/skin/blend-shape/LOD buffers as
	# well as public arrays. Only surface material references are omitted.
	var serialized: Array = []
	for property: Dictionary in mesh.get_property_list():
		if str(property.name) != "_surfaces":
			continue
		var source: Array = mesh.get(property.name)
		for surface: Dictionary in source:
			var record := surface.duplicate(true)
			record.erase("material")
			serialized.append(record)
	if serialized.size() != mesh.get_surface_count():
		push_error("Cannot certify forest tree serialized surface buffers")
		return ""
	var surfaces: Array = []
	for index in mesh.get_surface_count():
		surfaces.append([mesh.surface_get_name(index), mesh.surface_get_primitive_type(index), mesh.surface_get_format(index), mesh.surface_get_arrays(index), mesh.surface_get_blend_shape_arrays(index)])
	var blend_shapes: Array[StringName] = []
	for index in mesh.get_blend_shape_count():
		blend_shapes.append(mesh.get_blend_shape_name(index))
	var shadow := geometry_signature(mesh.shadow_mesh) if mesh.shadow_mesh != null else ""
	return var_to_bytes([mesh.get_aabb(), mesh.custom_aabb, mesh.lightmap_size_hint, mesh.blend_shape_mode, blend_shapes, surfaces, serialized, shadow]).hex_encode().sha256_text()

static func validate(mesh: ArrayMesh, source: String, certificate: Dictionary = {}) -> bool:
	var record := certificate if not certificate.is_empty() else entry(source)
	if not is_source(source) or not _valid_record(source, record) or mesh == null:
		push_error("Required prepared forest tree is missing or uncertified: " + source)
		return false
	if int(mesh.get_meta("forest_tree_contract_version", 0)) != CONTRACT_VERSION or mesh.get_meta("forest_tree_source", "") != source:
		push_error("Prepared forest tree identity is stale: " + source)
		return false
	if mesh.get_meta("forest_tree_geometry_sha256", "") != record.geometry_sha256 or mesh.get_meta("forest_tree_material_sha256", "") != record.material_sha256:
		push_error("Prepared forest tree certificate does not match its mesh: " + source)
		return false
	var names: Array = []
	for index in mesh.get_surface_count():
		names.append(mesh.surface_get_name(index))
	var bounds := mesh.get_aabb()
	var expected_bounds: Array = record.aabb
	var expected := AABB(Vector3(expected_bounds[0], expected_bounds[1], expected_bounds[2]), Vector3(expected_bounds[3], expected_bounds[4], expected_bounds[5]))
	var error := material_error(mesh)
	if names != record.surface_names or bounds != expected or error != "" or material_signature(mesh) != record.material_sha256:
		push_error("Prepared forest tree surfaces, bounds or materials changed: %s (%s)" % [source, error])
		return false
	return true
