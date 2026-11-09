extends RefCounted

## Build-only extraction of retained moving geometry. The scene carries no
## script/ticker: WorldPropController remains the sole ambient-motion owner.
const OUTPUT := "res://assets_external/environment_prepared/living_world/"
const BUILDERS := {
	"checkpoint_cloth": "res://tools/build_campaign_wilds.gd",
	"marsh_reeds": "res://tools/build_campaign_wilds.gd",
	"hart_ferns": "res://tools/build_hart_woodland.gd",
	"ash_mill_wheel": "res://tools/build_ash_mill.gd",
}

static func add_part(scene: Node3D, mesh: ArrayMesh, pivot: Vector3, kind: String, id: String, sources: Dictionary) -> String:
	if mesh == null or mesh.get_surface_count() == 0 or kind not in ["cloth", "foliage", "mill_wheel"]:
		return "Invalid retained moving part: " + id
	var faces := mesh.get_faces()
	if faces.is_empty() or not pivot.is_finite():
		return "Empty or nonfinite retained moving part: " + id
	for point: Vector3 in faces:
		if not point.is_finite():
			return "Nonfinite retained part vertex: " + id
		# Top-edge cloth and ground-rooted plants must pivot on their support,
		# never around the centre of a roof, trunk or entire terrain batch.
		if (kind == "cloth" and point.y > 0.0001) or (kind == "foliage" and point.y < -0.0001):
			return "Retained moving part crosses its support pivot: " + id
	var part := MeshInstance3D.new()
	part.name = id
	part.mesh = mesh
	part.position = pivot
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	part.set_meta("world_prop_kind", kind)
	part.set_meta("world_prop_id", id)
	part.set_meta("world_prop_verified_pivot", true)
	part.set_meta("source_sha256", sources)
	part.set_meta("retained_geometry_only", true)
	scene.add_child(part)
	part.owner = scene
	return ""

static func save(scene: Node3D, id: String, expected_count: int) -> String:
	if not BUILDERS.has(id):
		return "Unknown retained moving-part builder: " + id
	if scene.get_child_count() != expected_count:
		return "Moving-part scene count changed: " + id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var manifest: Array[Dictionary] = []
	var source_hashes: Dictionary = {}
	for source_path: String in [str(BUILDERS[id]), "res://tools/living_world_part_baker.gd"]:
		source_hashes[source_path] = FileAccess.get_sha256(source_path)
	for child: Node in scene.get_children():
		var part := child as MeshInstance3D
		if part == null or not bool(part.get_meta("world_prop_verified_pivot", false)):
			return "Moving-part scene contains an unverified child: " + id
		var retained_sources: Dictionary = part.get_meta("source_sha256", {})
		for source_path: String in retained_sources:
			var digest := str(retained_sources[source_path])
			if digest.length() != 64 or FileAccess.get_sha256(source_path) != digest:
				return "Retained moving-part source changed: " + source_path
			source_hashes[source_path] = digest
		# These small meshes/materials remain inline in the one compressed scene;
		# no hidden loose resources or source-only OBJ dependencies are required.
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(var_to_bytes(part.mesh.get_faces()))
		manifest.append({"node": str(part.name), "kind": part.get_meta("world_prop_kind"),
			"pivot": part.position, "pivot_godot": [part.position.x, part.position.y, part.position.z],
			"mesh_inline": true, "geometry_sha256": hash.finish().hex_encode(),
			"triangles": part.mesh.get_faces().size() / 3, "sources": part.get_meta("source_sha256")})
	scene.set_meta("living_world_parts", manifest)
	scene.set_meta("visual_only", true)
	scene.set_meta("static_source_geometry_removed", true)
	var packed := PackedScene.new()
	if packed.pack(scene) != OK:
		return "Cannot pack retained moving-part scene: " + id
	var path := OUTPUT + id + ".scn"
	if ResourceSaver.save(packed, path, ResourceSaver.FLAG_COMPRESS | ResourceSaver.FLAG_BUNDLE_RESOURCES) != OK:
		return "Cannot save retained moving-part scene: " + id
	var evidence := ProjectSettings.globalize_path("res://").path_join("../../art_source/art_recovery_v2/evidence/living_assets_stage3_20261107/scenery").simplify_path()
	DirAccess.make_dir_recursive_absolute(evidence)
	# Freeze the native comparison input separately from the runtime output.
	# The Blender compiler overwrites OUTPUT, so it must never reload OUTPUT as
	# the authority for a subsequent compile.
	var native_baseline := evidence.path_join(id + "_baseline.scn")
	if ResourceSaver.save(packed, native_baseline, ResourceSaver.FLAG_COMPRESS | ResourceSaver.FLAG_BUNDLE_RESOURCES) != OK:
		return "Cannot freeze retained native scenery input: " + id
	# This is retained input for the editable Blender assembly, not the final
	# authoring claim. Final delivery recompiles that reviewed Blender export.
	var baseline_path := evidence.path_join(id + "_baseline.glb")
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var export_error := document.append_from_scene(scene, state)
	if export_error == OK:
		export_error = document.write_to_filesystem(state, baseline_path)
	if export_error != OK:
		return "Cannot export retained Blender scenery input: " + id
	var baseline := FileAccess.open(evidence.path_join(id + "_baseline.json"), FileAccess.WRITE)
	if baseline == null:
		return "Cannot save retained Blender scenery input receipt: " + id
	baseline.store_string(JSON.stringify({"schema_version": 2, "asset": id, "source_hashes": source_hashes,
		"parts": manifest, "carrier": baseline_path, "carrier_sha256": FileAccess.get_sha256(baseline_path),
		"native_baseline": native_baseline, "native_baseline_sha256": FileAccess.get_sha256(native_baseline),
		"runtime_output": path,
		"visual_accepted": false}, "\t") + "\n")
	baseline.close()
	var receipt := FileAccess.open(evidence.path_join(id + "_compile.json"), FileAccess.WRITE)
	if receipt == null:
		return "Cannot save retained moving-part receipt: " + id
	receipt.store_string(JSON.stringify({"schema_version": 1, "asset": id,
		"path": path, "sha256": FileAccess.get_sha256(path),
		"bytes": FileAccess.get_file_as_bytes(path).size(), "source_hashes": source_hashes,
		"parts": manifest, "dependencies": ResourceLoader.get_dependencies(path),
		"blender_authored": false,
		"runtime_reviewed": false, "user_accepted": false}, "\t") + "\n")
	receipt.close()
	print("LIVING_WORLD_PARTS_COMPILED ", path, " children=", expected_count, " sha256=", FileAccess.get_sha256(path))
	return ""
