extends SceneTree

const CharacterVisualContract = preload("res://scripts/character_visual_contract.gd")

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.settings.set_quality_preset("balanced")
	game._new_game()
	var deadline := Time.get_ticks_msec() + 45000
	while Time.get_ticks_msec() < deadline:
		if game.game_started and is_instance_valid(game.zone_root) and bool(game.zone_root.get_meta("opening_detail_complete", false)):
			break
		await process_frame
	_check(game.game_started and is_instance_valid(game.zone_root) and bool(game.zone_root.get_meta("opening_detail_complete", false)), "Complete canonical detail did not finish")
	var meshes: Dictionary = {}
	var actors: Dictionary = {}
	var material_names: Dictionary = {}
	for owner in [game.zone_root, game.player]:
		for raw in owner.find_children("*", "MeshInstance3D", true, false):
			var node := raw as MeshInstance3D
			if node.mesh == null or not bool(node.mesh.get_meta("shared_immutable_geometry_candidate", false)):
				continue
			meshes[node.mesh.get_instance_id()] = node.mesh.resource_path
			actors[str(node.get_path())] = node.mesh.resource_path
			_check(node.material_override == null, "Mixed whole/surface material ownership")
			_check(node.skin != null, "Character lost its skin")
			var contract: Dictionary = CharacterVisualContract.validate(owner, true) if owner == game.player else {}
			if not contract.is_empty():
				_check(bool(contract.valid), "Kael final skeletal contract failed")
			for surface in node.mesh.get_surface_count():
				_check(node.mesh.surface_get_material(surface) != null, "Shared source surface became null")
				var active := node.get_active_material(surface)
				_check(active != null, "Actor active material became null")
				material_names[str(node.get_path())] = active.resource_name if active != null else "NULL"
	_check(meshes.size() == 3, "Six assemblies do not share exactly three complete geometry resources")
	var census := JSON.parse_string(FileAccess.get_file_as_string("D:/Temp/AshenOath/perf_geometry_ownership_20260928/census.json")) as Dictionary
	var expected_paths: Dictionary = {}
	var normalized_actual: Dictionary = {}
	var generated_id := RegEx.new()
	generated_id.compile("@[A-Za-z0-9_]+@[0-9]+")
	for path in actors:
		normalized_actual[generated_id.sub(path, "@generated@", true)] = true
	for group in census.duplicate_groups:
		for record in group.records:
			if str(record.resource_path).begins_with("res://assets_external/characters_universal/runtime/"):
				for owner in record.owners:
					expected_paths[generated_id.sub(owner.path, "@generated@", true)] = true
	_check(expected_paths.size() > 0 and expected_paths.keys().all(func(path): return normalized_actual.has(path)) and normalized_actual.size() == expected_paths.size(), "Canonical affected actor/path population differs")
	var report := {"scope": "headless_complete_scene_resource_ownership_not_graphical_or_route_acceptance", "status": "pass" if failures.is_empty() else "fail", "geometry": meshes, "actors": actors, "materials": material_names, "node_count": game.zone_root.find_children("*", "", true, false).size(), "failures": failures}
	var file := FileAccess.open("D:/Temp/AshenOath/perf_shared_humanoids_20260928/unit.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("SHARED HUMANOID COMPLETE SCENE: %s / %d actor meshes / %d geometry resources" % [report.status, actors.size(), meshes.size()])
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

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
