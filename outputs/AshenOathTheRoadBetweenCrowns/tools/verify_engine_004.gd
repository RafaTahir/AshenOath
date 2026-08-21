extends SceneTree

const TEST_ZONES: Array[String] = [
	"greyfen",
	"wychwood",
	"vargan_approach",
	"record_hall",
	"greyfen",
]

var failures: Array[String] = []

func _initialize() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	_check(scene != null, "Main scene failed to load")
	if scene == null:
		_finish()
		return
	var game := scene.instantiate()
	root.add_child(game)
	await _frames(3)
	game.call("_new_game")
	await _wait_for_zone(game, "greyfen")
	_check(game.world_materials.get_fallback_material() != null, "Stable world fallback material is missing")
	_check(game.world_materials.get_fallback_material() == game.world_materials.get_fallback_material(), "Fallback material is not cache-stable")

	for zone_id in TEST_ZONES:
		if str(game.current_zone_id) != zone_id:
			game.call("_load_zone", zone_id, Vector3(0, 1, 7))
			await _wait_for_zone(game, zone_id)
		await _wait_for_retirement(game)
		_validate_active_zone(game, zone_id)

	game.prepare_resource_shutdown()
	await _wait_for_retirement(game)
	var before_finalize: Dictionary = game.zone_lifecycle_snapshot()
	_check(int(before_finalize.get("cached_count", 0)) == 0, "Shutdown retained cached zones")
	_check(int(before_finalize.get("retiring_count", 0)) == 0, "Shutdown retained retiring zones")
	game.finalize_resource_shutdown()
	await _frames(4)
	var after_finalize: Dictionary = game.zone_lifecycle_snapshot()
	_check(int(after_finalize.get("material_anchor_count", 0)) == 0, "Finalization retained material anchors")
	game.queue_free()
	await _frames(24)
	_check(not is_instance_valid(game), "Game root did not retire after resource shutdown")

	if failures.is_empty():
		print("ENGINE-004 VERIFIER: PASS")
	else:
		print("ENGINE-004 VERIFIER: FAIL (%d)" % failures.size())
		for failure in failures:
			push_error(failure)
	_finish(0 if failures.is_empty() else 1)

func _validate_active_zone(game: Node, zone_id: String) -> void:
	_check(str(game.current_zone_id) == zone_id, "Active zone mismatch: %s" % zone_id)
	_check(not game.zone_transition_pending, "Zone remained in transition: %s" % zone_id)
	var snapshot: Dictionary = game.zone_lifecycle_snapshot()
	_check(str(snapshot.get("active_owner", "")) == "active", "Zone owner is not active: %s" % zone_id)
	_check(int(snapshot.get("cached_count", 0)) <= int(game.MAX_CACHED_ROUTE_ZONES), "Cache policy exceeded: %s" % zone_id)
	_check(int(snapshot.get("retiring_count", 0)) == 0, "Retired root survived: %s" % zone_id)
	_check(_missing_material_count(game.zone_root) == 0, "Active zone has a null effective material: %s" % zone_id)
	var report: Dictionary = game.call("_validate_zone_render_resources", game.zone_root)
	_check(int(report.get("invalid_geometry", 0)) == 0, "Active zone has invalid geometry: %s" % zone_id)
	if game.visual_director != null and is_instance_valid(game.visual_director):
		var sky_report: Dictionary = game.call("_validate_zone_render_resources", game.visual_director)
		_check(int(sky_report.get("invalid_geometry", 0)) == 0, "Sky has invalid geometry: %s" % zone_id)
	if game.player != null and is_instance_valid(game.player):
		var player_report: Dictionary = game.call("_validate_zone_render_resources", game.player)
		_check(int(player_report.get("invalid_geometry", 0)) == 0, "Player has invalid geometry: %s" % zone_id)

func _missing_material_count(root_node: Node) -> int:
	var missing := 0
	var meshes: Array[Node] = []
	if root_node is MeshInstance3D:
		meshes.append(root_node)
	meshes.append_array(root_node.find_children("*", "MeshInstance3D", true, false))
	for raw_mesh in meshes:
		var mesh_instance := raw_mesh as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
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
		if batch == null or batch.multimesh == null or batch.multimesh.mesh == null:
			continue
		if batch.material_override == null:
			for surface_index in range(batch.multimesh.mesh.get_surface_count()):
				if batch.multimesh.mesh.surface_get_material(surface_index) == null:
					missing += 1
	return missing

func _wait_for_zone(game: Node, zone_id: String) -> void:
	for _index in range(120):
		await process_frame
		if str(game.current_zone_id) == zone_id and game.zone_root != null and not game.zone_transition_pending:
			return
	_check(false, "Timed out waiting for zone: %s" % zone_id)

func _wait_for_retirement(game: Node) -> void:
	for _index in range(600):
		await process_frame
		if int(game.zone_lifecycle_snapshot().get("retiring_count", 0)) == 0:
			return
	_check(false, "Retired zone roots did not clear")

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)

func _finish(code: int = 1) -> void:
	quit(code)
