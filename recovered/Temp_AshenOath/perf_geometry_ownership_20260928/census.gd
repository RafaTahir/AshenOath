extends SceneTree

const OUTPUT := "D:/Temp/AshenOath/perf_geometry_ownership_20260928/census.json"
var unique_meshes: Dictionary = {}
var groups: Dictionary = {}
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.settings.set_quality_preset("balanced")
	game._new_game()
	var deadline := Time.get_ticks_msec() + 45000
	while Time.get_ticks_msec() < deadline:
		if game.game_started and is_instance_valid(game.zone_root) and bool(game.zone_root.get_meta("opening_detail_complete", false)):
			break
		await process_frame
	if not game.game_started or not is_instance_valid(game.zone_root) or not bool(game.zone_root.get_meta("opening_detail_complete", false)):
		failures.append("Complete canonical Greyfen did not become available")
	else:
		for owner in [game.zone_root, game.player]:
			for node in owner.find_children("*", "GeometryInstance3D", true, false):
				_inspect(node)
	var duplicate_groups: Array = []
	var redundant_meshes := 0
	var redundant_vertices := 0
	var total_vertices := 0
	for entry in unique_meshes.values():
		total_vertices += int(entry.vertices)
	for key in groups:
		var group: Array = groups[key]
		if group.size() > 1:
			var records: Array = []
			for id in group:
				records.append(unique_meshes[id])
			var excess: int = group.size() - 1
			redundant_meshes += excess
			redundant_vertices += excess * int(records[0].vertices)
			duplicate_groups.append({"base_array_hash": key, "distinct_resources": group.size(), "records": records})
	duplicate_groups.sort_custom(func(a, b): return int(a.distinct_resources) * int(a.records[0].vertices) > int(b.distinct_resources) * int(b.records[0].vertices))
	var report := {
		"status": "diagnostic_complete" if failures.is_empty() else "failed",
		"scope": "read_only_headless_geometry_census_not_render_or_performance_acceptance",
		"generated_at_utc": Time.get_datetime_string_from_system(true),
		"source": {
			"game": FileAccess.get_sha256("res://scripts/game.gd"),
			"asset_helper": FileAccess.get_sha256("res://scripts/asset_spawn_helper.gd"),
			"greyfen": FileAccess.get_sha256("res://scripts/zones/greyfen_section.gd"),
			"river": FileAccess.get_sha256("res://scripts/zones/river_section.gd"),
		},
		"distinct_meshes": unique_meshes.size(), "total_vertices": total_vertices,
		"redundant_meshes": redundant_meshes, "redundant_vertices": redundant_vertices,
		"caveat": "Base-array equality is a census only; LOD, material, blend, skin, shadow-mesh and mutation ownership must independently match before any reuse.",
		"duplicate_groups": duplicate_groups, "failures": failures,
	}
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("GEOMETRY CENSUS: %s distinct meshes, %s/%s redundant vertices across %s duplicate resources" % [unique_meshes.size(), redundant_vertices, total_vertices, redundant_meshes])
	print("VERIFIER_PHASE: SHUTDOWN")
	game.prepare_resource_shutdown()
	for index in game.ZONE_RETIRE_FRAMES + 6:
		await process_frame
	game.finalize_resource_shutdown()
	for index in 8:
		await process_frame
	root.remove_child(game)
	game.free()
	RenderingServer.force_sync()
	for index in 5:
		await process_frame
	quit(0 if failures.is_empty() else 1)

func _inspect(node: GeometryInstance3D) -> void:
	var mesh: Mesh
	if node is MeshInstance3D:
		mesh = node.mesh
	elif node is MultiMeshInstance3D and node.multimesh != null:
		mesh = node.multimesh.mesh
	if mesh == null:
		return
	var id := mesh.get_instance_id()
	var owner_record := {"path": str(node.get_path()), "class": node.get_class(), "material_override_id": node.material_override.get_instance_id() if node.material_override != null else 0}
	if unique_meshes.has(id):
		unique_meshes[id].owners.append(owner_record)
		return
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	var blend_count: int = mesh.get_blend_shape_count() if mesh is ArrayMesh else 0
	context.update(var_to_bytes([mesh.get_class(), mesh.get_surface_count(), blend_count, mesh.get_aabb()]))
	var vertices := 0
	var skin := false
	var material_ids: Array = []
	for index in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(index)
		vertices += arrays[Mesh.ARRAY_VERTEX].size()
		skin = skin or (arrays[Mesh.ARRAY_BONES] != null and arrays[Mesh.ARRAY_BONES].size() > 0)
		if mesh is ArrayMesh:
			context.update(var_to_bytes([mesh.surface_get_primitive_type(index), mesh.surface_get_format(index), arrays]))
		elif mesh is PrimitiveMesh:
			context.update(var_to_bytes([mesh.custom_aabb, mesh.flip_faces, mesh.add_uv2, mesh.uv2_padding, arrays]))
		else:
			failures.append("Unsupported mesh class: " + mesh.get_class())
			return
		var material := mesh.surface_get_material(index)
		material_ids.append(material.get_instance_id() if material != null else 0)
	var hash := context.finish().hex_encode()
	var record := {
		"id": id, "class": mesh.get_class(), "resource_path": mesh.resource_path,
		"vertices": vertices, "surfaces": mesh.get_surface_count(), "skin": skin,
		"blend_shapes": blend_count, "material_ids": material_ids,
		"owners": [owner_record],
	}
	unique_meshes[id] = record
	if not groups.has(hash):
		groups[hash] = []
	groups[hash].append(id)
