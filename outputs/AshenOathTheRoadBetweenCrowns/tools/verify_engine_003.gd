extends SceneTree

const TEST_ZONES: Array[String] = [
	"greyfen",
	"wychwood",
	"greyfen",
	"vargan_approach",
	"greyfen",
]

var failures := 0

func _initialize() -> void:
	_verify_static_contract()
	var scene := load("res://scenes/main.tscn") as PackedScene
	check(scene != null, "Main scene is unavailable")
	if scene == null:
		_finish()
		return
	var game = scene.instantiate()
	root.add_child(game)
	await _frames(3)
	game.call("_new_game")
	await _wait_for_zone(game, "greyfen")
	await _verify_lifecycle(game)
	game.prepare_resource_shutdown()
	await _wait_for_retirement(game)
	var final_snapshot: Dictionary = game.zone_lifecycle_snapshot()
	check(int(final_snapshot.cached_count) == 0, "Shutdown retained cached zones")
	check(int(final_snapshot.retiring_count) == 0, "Shutdown retained retiring zones")
	game.queue_free()
	await _frames(5)
	_finish()

func _verify_static_contract() -> void:
	var game_source := FileAccess.get_file_as_string("res://scripts/game.gd")
	for required in [
		"func _cache_route_zone(",
		"func _activate_cached_zone(",
		"func _retire_zone_root(",
		"func _validate_zone_render_resources(",
		"_validate_zone_render_resources(visual_director)",
		"_validate_zone_render_resources(player)",
		"func prepare_resource_shutdown(",
		"func zone_lifecycle_snapshot(",
	]:
		check(game_source.contains(required), "Missing lifecycle contract: %s" % required)
	check(not game_source.contains("func _release_zone_render_resources("), "Retirement still strips live renderer resources")
	var retire_start := game_source.find("func _deferred_free_zone(")
	var retire_end := game_source.find("func _retire_zone_root(", retire_start)
	var retirement_source := game_source.substr(retire_start, retire_end - retire_start)
	check(not retirement_source.contains(".mesh = null"), "Retirement nulls Mesh resources before node disposal")
	check(not retirement_source.contains(".multimesh = null"), "Retirement nulls MultiMesh resources before node disposal")
	var material_source := FileAccess.get_file_as_string("res://scripts/world_material_library.gd")
	check(material_source.contains("func get_fallback_material()"), "World material library has no stable fallback")
	var asset_source := FileAccess.get_file_as_string("res://scripts/asset_spawn_helper.gd")
	check(asset_source.contains("get_surface_override_material"), "Imported mesh material validation is incomplete")

func _verify_lifecycle(game) -> void:
	var world_fallback = game.world_materials.get_fallback_material()
	check(world_fallback != null, "World fallback material was not created")
	check(world_fallback == game.world_materials.get_fallback_material(), "Fallback material is not cache-stable")
	for zone_id in TEST_ZONES:
		if str(game.current_zone_id) != zone_id:
			game.call("_load_zone", zone_id, Vector3(0, 1, 7))
			await _wait_for_zone(game, zone_id)
		await _wait_for_retirement(game)
		var snapshot: Dictionary = game.zone_lifecycle_snapshot()
		check(str(snapshot.active_zone) == zone_id, "Lifecycle active zone mismatch for %s" % zone_id)
		check(str(snapshot.active_owner) == "active", "%s root is not owned as active" % zone_id)
		check(int(snapshot.cached_count) <= game.MAX_CACHED_ROUTE_ZONES, "Route cache exceeded policy in %s" % zone_id)
		check(int(snapshot.retiring_count) == 0, "Retired roots survived staged disposal in %s" % zone_id)
		for cached_id in snapshot.cached_ids:
			var cached_root = game.route_zone_cache.get(cached_id)
			check(cached_root != null and is_instance_valid(cached_root), "Cache contains an invalid root: %s" % cached_id)
			if cached_root != null and is_instance_valid(cached_root):
				check(str(cached_root.get_meta("zone_resource_owner", "")) == "cached", "Cache ownership marker is wrong for %s" % cached_id)
				check(not cached_root.visible, "Cached zone remains visible: %s" % cached_id)
				check(cached_root.process_mode == Node.PROCESS_MODE_DISABLED, "Cached zone still processes: %s" % cached_id)
		check(_missing_material_count(game.zone_root) == 0, "%s contains visible geometry without an effective material" % zone_id)
		var render_report: Dictionary = game.call("_validate_zone_render_resources", game.zone_root)
		check(not render_report.is_empty(), "%s has no material-validation report" % zone_id)
		check(int(render_report.get("invalid_geometry", 0)) == 0, "%s retained invalid geometry resources: %s" % [
			zone_id, render_report.get("invalid_geometry_names", [])
		])
		if game.visual_director != null and is_instance_valid(game.visual_director):
			var sky_report: Dictionary = game.call("_validate_zone_render_resources", game.visual_director)
			check(int(sky_report.get("invalid_geometry", 0)) == 0, "%s sky layer retained invalid geometry" % zone_id)
		if game.player != null and is_instance_valid(game.player):
			var player_report: Dictionary = game.call("_validate_zone_render_resources", game.player)
			check(int(player_report.get("invalid_geometry", 0)) == 0, "%s player retained invalid geometry" % zone_id)

	var probe := MeshInstance3D.new()
	probe.name = "LifecycleMaterialProbe"
	probe.mesh = BoxMesh.new()
	game.zone_root.add_child(probe)
	check(_missing_material_count(probe) == 1, "Material probe did not begin without a material")
	game.call("_validate_zone_render_resources", game.zone_root)
	check(_missing_material_count(probe) == 0, "Material validator did not repair a missing surface material")
	probe.queue_free()
	await _frames(2)

func _missing_material_count(root_node: Node) -> int:
	var missing := 0
	var meshes: Array[Node] = []
	if root_node is MeshInstance3D:
		meshes.append(root_node)
	meshes.append_array(root_node.find_children("*", "MeshInstance3D", true, false))
	for raw_mesh in meshes:
		var mesh_instance := raw_mesh as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		if mesh_instance.material_override != null:
			continue
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var material := mesh_instance.get_surface_override_material(surface_index)
			if material == null:
				material = mesh_instance.mesh.surface_get_material(surface_index)
			if material == null:
				missing += 1
	var batches: Array[Node] = []
	if root_node is MultiMeshInstance3D:
		batches.append(root_node)
	batches.append_array(root_node.find_children("*", "MultiMeshInstance3D", true, false))
	for raw_batch in batches:
		var batch := raw_batch as MultiMeshInstance3D
		if batch.multimesh == null or batch.multimesh.mesh == null:
			continue
		if batch.material_override == null:
			missing += 1
	return missing

func _wait_for_zone(game, zone_id: String) -> void:
	for _index in range(90):
		await process_frame
		if str(game.current_zone_id) == zone_id and game.zone_root != null and not game.zone_transition_pending:
			return
	check(false, "Timed out waiting for zone: %s" % zone_id)

func _wait_for_retirement(game) -> void:
	for _index in range(600):
		await process_frame
		if int(game.zone_lifecycle_snapshot().retiring_count) == 0:
			return
	check(false, "Timed out waiting for staged zone retirement")

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _finish() -> void:
	print("ENGINE-003 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
