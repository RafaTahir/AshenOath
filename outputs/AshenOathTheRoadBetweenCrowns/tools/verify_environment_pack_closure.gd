extends SceneTree

const AFFECTED := [
	"village/T_WoodTrim_BaseColor.png", "village/T_WoodTrim_Roughness.png",
	"village/T_WoodTrim_Normal.png", "forest/Rocks_Diffuse.png",
]
const TREE_SOURCES := [
	"res://assets_external/environment/forest/CommonTree_5.obj",
	"res://assets_external/environment/forest/TwistedTree_2.obj",
	"res://assets_external/environment/forest/TwistedTree_4.obj",
]
const MAX_DECODED_BYTES := 268435456
var failures: Array[String] = []
var artifacts: Dictionary = {}
var artifact_root := ""
var scratch_root := ""
var mounted := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("Expected Web artifact directory and isolated scratch directory")
		quit(2)
		return
	artifact_root = args[0].simplify_path()
	scratch_root = args[1].simplify_path()
	if not scratch_root.replace("\\", "/").begins_with("D:/Temp/AshenOath/"):
		push_error("Pack check scratch must remain under D:/Temp/AshenOath")
		quit(2)
		return
	if not ProjectSettings.globalize_path("res://").replace("\\", "/").begins_with("D:/Temp/AshenOath/"):
		push_error("Run this check from an isolated scratch project, not the source checkout")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(scratch_root)
	var release: Variant = _json_file(artifact_root.path_join("release_manifest.json"))
	if not release is Dictionary:
		_fail("Invalid delivered release manifest")
		_finish(0, 0)
		return
	if not _index_artifacts(release):
		_finish(0, 0)
		return
	var root_record: Variant = release.get("root_pck")
	if not root_record is Dictionary or root_record.get("path") != "index.pck" or root_record.get("bytes") != artifacts.get("index.pck", {}).get("bytes") or root_record.get("sha256") != artifacts.get("index.pck", {}).get("sha256"):
		_fail("Release root PCK identity is missing or inconsistent")
		_finish(0, 0)
		return
	# Mount the verified root before resolving any scripts/resources from it.
	var root_bytes := _verified_artifact("index.pck", true)
	if root_bytes.is_empty() or not _mount("index.pck", root_bytes):
		_finish(0, 0)
		return
	var manifest_ref: Variant = release.get("runtime_pack_manifest")
	if not manifest_ref is Dictionary or manifest_ref.get("path") != "runtime_pack_manifest.json" or manifest_ref.get("bytes") != artifacts.get("runtime_pack_manifest.json", {}).get("bytes") or manifest_ref.get("sha256") != artifacts.get("runtime_pack_manifest.json", {}).get("sha256"):
		_fail("Release runtime-pack graph identity is missing or inconsistent")
		_finish(0, 0)
		return
	var manifest_bytes := _verified_artifact("runtime_pack_manifest.json", false)
	var manifest: Variant = JSON.parse_string(manifest_bytes.get_string_from_utf8())
	if not manifest is Dictionary or not manifest.get("packs") is Dictionary:
		_fail("Invalid delivered runtime-pack graph")
		_finish(0, 0)
		return
	var packs: Dictionary = manifest.packs
	var base: Variant = packs.get("base")
	if not base is Dictionary or base.get("url", "") != "" or base.get("dependencies", []) != [] or (base.get("status", "") != "embedded_current_pck" and base.get("embedded_artifact", "") != "index.pck"):
		_fail("Base must be the dependency-free embedded root PCK")
		_finish(0, 0)
		return
	var order: Array[String] = []
	if not _dependency_order("opening", packs, {"base": 2}, order):
		_finish(0, 0)
		return
	for id: String in order:
		var row: Dictionary = packs[id]
		var relative := str(row.get("url", "")).get_slice("?", 0)
		if not _safe_relative(relative) or not relative.begins_with("packs/") or not relative.ends_with(".pck"):
			_fail("Pack URL must name a local PCK artifact: " + id)
			_finish(0, 0)
			return
		var decoded := _verified_artifact(relative, true)
		# Runtime manifests describe decoded PCKs; release artifacts describe
		# the encoded local file. Validate both independent identities.
		if decoded.is_empty() or decoded.size() != int(row.get("bytes", -1)) or _sha256(decoded) != str(row.get("sha256", "")).to_lower():
			_fail("Decoded runtime-pack identity mismatch: " + id)
			_finish(0, 0)
			return
		if not _mount(relative, decoded):
			_finish(0, 0)
			return
	# Retire former tree texture assertions only after the exact prepared-tree
	# contract succeeds against the actual mounted export resources.
	var tree_count := _verify_prepared_trees()
	if tree_count != TREE_SOURCES.size():
		_finish(0, tree_count)
		return
	_finish(_verify_textures(), tree_count)

func _json_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		_fail("Missing JSON artifact: " + path)
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null:
		_fail("Invalid JSON artifact: " + path)
	return parsed

func _safe_relative(path: String) -> bool:
	if path == "" or path.begins_with("/") or path.contains("\\") or path.contains(":") or path.contains("?") or path.contains("#") or path.simplify_path() != path:
		return false
	for component: String in path.split("/"):
		if component in ["", ".", ".."]:
			return false
	return true

func _index_artifacts(release: Dictionary) -> bool:
	var records: Variant = release.get("artifacts")
	if not records is Array:
		_fail("Release artifact table is missing")
		return false
	for row: Variant in records:
		if not row is Dictionary or not _safe_relative(str(row.get("path", ""))) or artifacts.has(row.get("path")):
			_fail("Release artifact table has an unsafe or duplicate path")
			return false
		artifacts[row.path] = row
	return true

func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

func _verified_artifact(relative: String, pck: bool) -> PackedByteArray:
	if not _safe_relative(relative) or not artifacts.has(relative):
		_fail("Artifact is missing from the release table: " + relative)
		return PackedByteArray()
	var row: Dictionary = artifacts[relative]
	var bytes := FileAccess.get_file_as_bytes(artifact_root.path_join(relative))
	if bytes.is_empty() or bytes.size() != int(row.get("bytes", -1)) or _sha256(bytes) != str(row.get("sha256", "")).to_lower():
		_fail("Local artifact size/hash mismatch: " + relative)
		return PackedByteArray()
	if not pck:
		return bytes
	var gzip := bytes.size() >= 2 and bytes[0] == 0x1f and bytes[1] == 0x8b
	if gzip != (row.get("content_encoding", "") == "gzip"):
		_fail("PCK encoding metadata mismatch: " + relative)
		return PackedByteArray()
	var decoded := bytes.decompress_dynamic(MAX_DECODED_BYTES, FileAccess.COMPRESSION_GZIP) if gzip else bytes
	if decoded.size() < 4 or decoded.slice(0, 4) != PackedByteArray([71, 68, 80, 67]):
		_fail("Cannot decode a valid Godot PCK: " + relative)
		return PackedByteArray()
	if decoded.size() != int(row.get("decoded_bytes", -1)) or _sha256(decoded) != str(row.get("decoded_sha256", "")).to_lower():
		_fail("Decoded release-artifact size/hash mismatch: " + relative)
		return PackedByteArray()
	return decoded

func _dependency_order(id: String, packs: Dictionary, states: Dictionary, order: Array[String]) -> bool:
	if states.get(id, 0) == 1:
		_fail("Runtime-pack dependency cycle at " + id)
		return false
	if states.get(id, 0) == 2:
		return true
	var row: Variant = packs.get(id)
	if not row is Dictionary or not row.get("dependencies") is Array:
		_fail("Missing pack or dependency list: " + id)
		return false
	states[id] = 1
	for dependency: Variant in row.dependencies:
		if not dependency is String or dependency == "" or not _dependency_order(dependency, packs, states, order):
			_fail("Invalid dependency of " + id)
			return false
	states[id] = 2
	order.append(id)
	return true

func _mount(relative: String, bytes: PackedByteArray) -> bool:
	var decoded := scratch_root.path_join(relative)
	DirAccess.make_dir_recursive_absolute(decoded.get_base_dir())
	var file := FileAccess.open(decoded, FileAccess.WRITE)
	if file == null:
		_fail("Cannot write decoded scratch PCK: " + relative)
		return false
	file.store_buffer(bytes)
	file.close()
	if not ProjectSettings.load_resource_pack(decoded, false):
		_fail("Cannot mount " + relative)
		return false
	mounted += 1
	return true

func _verify_prepared_trees() -> int:
	# No preload: this checker starts in an otherwise empty scratch project.
	var contract = ResourceLoader.load("res://scripts/prepared_forest_trees.gd")
	if contract == null:
		_fail("Mounted root has no prepared forest tree contract")
		return 0
	var sources: Array[String] = contract.source_paths()
	if sources != TREE_SOURCES:
		_fail("Prepared tree contract does not cover exactly the approved sources")
		return 0
	var checked := 0
	for source: String in sources:
		var row: Dictionary = contract.entry(source)
		var prepared := str(row.get("path", ""))
		if prepared.is_empty():
			_fail("Prepared tree has no declared runtime resource: " + source)
			continue
		var mesh := ResourceLoader.load(prepared, "ArrayMesh", ResourceLoader.CACHE_MODE_IGNORE) as ArrayMesh
		if row.is_empty() or not contract.validate(mesh, source) or contract.geometry_signature(mesh) != row.get("geometry_sha256") or not ResourceLoader.get_dependencies(prepared).is_empty():
			_fail("Exported prepared tree failed its exact geometry/material contract: " + source)
			continue
		if ResourceLoader.exists(source) or FileAccess.file_exists(source) or FileAccess.file_exists(source + ".import"):
			_fail("Retired raw tree import remains in the mounted export: " + source)
			continue
		checked += 1
		print("ENVIRONMENT_PREPARED_TREE source=%s mesh=%s exact_geometry=true exact_materials=true" % [source, prepared])
	return checked

func _verify_textures() -> int:
	var paths: Array[String] = []
	for relative: String in AFFECTED:
		paths.append("res://assets_external/environment/" + relative)
	var parsed: Variant = _json_file("res://data/environment_material_dependencies.json")
	if not parsed is Dictionary or parsed.get("schema_version", 0) != 1 or not parsed.get("textures") is Dictionary:
		_fail("Invalid exported environment dependency ledger")
		return 0
	var records: Dictionary = parsed.textures
	for path: String in paths:
		if not records.has(path):
			_fail("Known affected texture omitted from ledger: " + path)
	for path: String in records:
		if not records[path] is Dictionary:
			_fail("Invalid environment texture record: " + path)
			continue
		if records[path].get("owner", "") == "opening" and path not in paths:
			paths.append(path)
	for path: String in paths:
		var imported := FileAccess.file_exists(path + ".import")
		var texture := ResourceLoader.load(path, "Texture2D") as Texture2D
		var valid := texture != null and texture.get_width() > 0 and texture.get_height() > 0
		print("ENVIRONMENT_TEXTURE path=%s import=%s texture=%s" % [path, imported, valid])
		if not imported or not valid:
			_fail("Missing imported texture: " + path)
	return paths.size()

func _finish(textures: int, trees: int) -> void:
	print("ENVIRONMENT PACK CLOSURE: %s (%d packs, %d prepared trees, %d textures, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", mounted, trees, textures, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _fail(message: String) -> void:
	failures.append(message)
	push_error(message)
