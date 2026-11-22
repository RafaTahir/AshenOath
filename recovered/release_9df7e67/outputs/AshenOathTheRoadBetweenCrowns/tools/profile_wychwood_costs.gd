extends SceneTree

const SAMPLE_MS := 3500
const SETTLE_FRAMES := 45

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("Wychwood cost profile requires graphical Compatibility rendering")
		quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 60
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game = scene.instantiate()
	root.add_child(game)
	await _frames(2)
	game.settings.set_quality_preset("balanced")
	game.settings.settings["touch_controls"] = "off"
	game.call("_new_game")
	await _wait_zone(game, "greyfen")
	game.call("_load_zone", "wychwood", Vector3(0, 1, 8))
	await _wait_zone(game, "wychwood")
	for _index in range(180):
		await process_frame
	if game.get("performance_budget_monitor") != null:
		game.performance_budget_monitor.suspend()
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)

	var batches: Array[Node3D] = []
	var meshes: Array[Node3D] = []
	var lights: Array[Node3D] = []
	for node in game.zone_root.find_children("*", "", true, false):
		if node is MultiMeshInstance3D:
			batches.append(node)
		elif node is MeshInstance3D:
			meshes.append(node)
		elif node is OmniLight3D:
			lights.append(node)
	var categories := {"batches": batches.size(), "meshes": meshes.size(), "local_lights": lights.size()}
	var inventory: Array[Dictionary] = []
	for node in batches:
		var multimesh: MultiMesh = (node as MultiMeshInstance3D).multimesh
		var triangles := 0
		if multimesh != null and multimesh.mesh != null:
			triangles = multimesh.mesh.get_faces().size() / 3
		inventory.append({"name": node.name, "instances": multimesh.instance_count if multimesh != null else 0, "triangles_per_instance": triangles, "total_triangles": triangles * multimesh.instance_count if multimesh != null else 0, "visible": node.visible, "range_end": node.visibility_range_end})
	if "--inventory-only" in OS.get_cmdline_user_args():
		print("WYCHWOOD BATCH INVENTORY: " + JSON.stringify(inventory))
		await _shutdown(game)
		quit(0)
		return
	if "--groups-only" in OS.get_cmdline_user_args():
		var tree_batches: Array[Node3D] = []
		var distant_batches: Array[Node3D] = []
		var foliage_batches: Array[Node3D] = []
		var river_batches: Array[Node3D] = []
		for node in batches:
			if node.name.begins_with("AuthoredTreeBatch"):
				tree_batches.append(node)
			elif node.name.begins_with("WychwoodDistantForest"):
				distant_batches.append(node)
			elif node.name.begins_with("WychwoodCanopy") or node.name in ["WychwoodUnderstoryBatch", "WychwoodForestFloorDetail", "GrassBatch"]:
				foliage_batches.append(node)
			elif node.name.begins_with("River"):
				river_batches.append(node)
		var groups := {"authored_trees": tree_batches, "distant_forest": distant_batches, "undergrowth": foliage_batches, "river": river_batches}
		var grouped_samples := {"baseline_start": await _sample()}
		for group_name in groups.keys():
			await _set_visible(groups[group_name], false)
			grouped_samples["without_" + group_name] = await _sample()
			await _set_visible(groups[group_name], true)
			grouped_samples["baseline_after_" + group_name] = await _sample()
		print("WYCHWOOD GROUP COSTS: " + JSON.stringify({"scope": "diagnostic only", "samples": grouped_samples}))
		await _shutdown(game)
		quit(0)
		return
	if "--tree-chunks-only" in OS.get_cmdline_user_args():
		var originals: Array[MultiMeshInstance3D] = []
		for node in batches:
			if node.name.begins_with("AuthoredTreeBatch"):
				originals.append(node as MultiMeshInstance3D)
		var chunked: Array[Node3D] = []
		var chunk_samples := {"baseline_a": await _sample()}
		for original in originals:
			var groups_by_cell := {}
			for index in range(original.multimesh.instance_count):
				var transform := original.multimesh.get_instance_transform(index)
				var cell := Vector2i(floori(transform.origin.x / 12.0), floori(transform.origin.z / 12.0))
				if not groups_by_cell.has(cell):
					groups_by_cell[cell] = []
				groups_by_cell[cell].append(transform)
			for cell in groups_by_cell.keys():
				var instance := MultiMeshInstance3D.new()
				instance.name = "%s_cell_%s_%s" % [original.name, cell.x, cell.y]
				var multimesh := MultiMesh.new()
				multimesh.transform_format = MultiMesh.TRANSFORM_3D
				multimesh.mesh = original.multimesh.mesh
				multimesh.instance_count = groups_by_cell[cell].size()
				for index in range(multimesh.instance_count):
					multimesh.set_instance_transform(index, groups_by_cell[cell][index])
				instance.multimesh = multimesh
				instance.material_override = original.material_override
				instance.cast_shadow = original.cast_shadow
				instance.visibility_range_end = original.visibility_range_end
				game.zone_root.add_child(instance)
				chunked.append(instance)
		for original in originals:
			original.visible = false
		await _frames(SETTLE_FRAMES)
		chunk_samples["chunked_a"] = await _sample()
		await _set_visible(chunked, false)
		for original in originals:
			original.visible = true
		chunk_samples["baseline_b"] = await _sample()
		for original in originals:
			original.visible = false
		await _set_visible(chunked, true)
		chunk_samples["chunked_b"] = await _sample()
		print("WYCHWOOD TREE CHUNKS: " + JSON.stringify({"scope": "diagnostic only", "original_batches": originals.size(), "chunked_batches": chunked.size(), "samples": chunk_samples}))
		await _shutdown(game)
		quit(0)
		return
	if "--low-tree-only" in OS.get_cmdline_user_args():
		var candidate_mesh := load("res://assets_external/environment/forest/CommonTree_5.obj") as ArrayMesh
		if candidate_mesh == null:
			push_error("Same-pack CommonTree_5 candidate is unavailable")
			await _shutdown(game)
			quit(1)
			return
		var originals: Array[MultiMeshInstance3D] = []
		var candidates: Array[Node3D] = []
		var candidate_samples := {"baseline_a": await _sample()}
		for node in batches:
			if not node.name.begins_with("AuthoredTreeBatch"):
				continue
			var original := node as MultiMeshInstance3D
			originals.append(original)
			var old_normalization := _tree_normalization(original.multimesh.mesh)
			var new_normalization := _tree_normalization(candidate_mesh)
			var replacement := MultiMeshInstance3D.new()
			replacement.name = original.name + "_CommonTree5Diagnostic"
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.mesh = candidate_mesh
			multimesh.instance_count = original.multimesh.instance_count
			for index in range(multimesh.instance_count):
				var transform := original.multimesh.get_instance_transform(index)
				multimesh.set_instance_transform(index, transform * old_normalization.affine_inverse() * new_normalization)
			replacement.multimesh = multimesh
			replacement.material_override = original.material_override
			replacement.cast_shadow = original.cast_shadow
			replacement.visibility_range_end = original.visibility_range_end
			game.zone_root.add_child(replacement)
			candidates.append(replacement)
			original.visible = false
		await _frames(SETTLE_FRAMES)
		candidate_samples["candidate_a"] = await _sample()
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("D:/Temp/AshenOath/wychwood_common_tree5_diagnostic.png")
		await _set_visible(candidates, false)
		for original in originals:
			original.visible = true
		candidate_samples["baseline_b"] = await _sample()
		for original in originals:
			original.visible = false
		await _set_visible(candidates, true)
		candidate_samples["candidate_b"] = await _sample()
		print("WYCHWOOD SAME-PACK TREE CANDIDATE: " + JSON.stringify({"scope": "diagnostic only", "candidate": "CommonTree_5.obj", "samples": candidate_samples}))
		await _shutdown(game)
		quit(0)
		return
	var samples := {}
	samples["baseline_a"] = await _sample()
	await _set_visible(batches, false)
	samples["without_batches"] = await _sample()
	await _set_visible(batches, true)
	samples["baseline_b"] = await _sample()
	await _set_visible(meshes, false)
	samples["without_meshes"] = await _sample()
	await _set_visible(meshes, true)
	samples["baseline_c"] = await _sample()
	await _set_visible(lights, false)
	samples["without_local_lights"] = await _sample()
	await _set_visible(lights, true)
	samples["baseline_d"] = await _sample()
	game.hud.hud_root.visible = false
	samples["without_hud"] = await _sample()
	game.hud.hud_root.visible = true
	samples["baseline_e"] = await _sample()
	var report := {"scope": "diagnostic only; stationary Wychwood, not release acceptance", "categories": categories, "samples": samples}
	print("WYCHWOOD COST PROFILE: " + JSON.stringify(report))
	await _shutdown(game)
	quit(0)

func _set_visible(nodes: Array[Node3D], enabled: bool) -> void:
	for node in nodes:
		if is_instance_valid(node):
			node.visible = enabled
	await _frames(SETTLE_FRAMES)

func _tree_normalization(mesh: Mesh) -> Transform3D:
	var bounds := mesh.get_aabb()
	var scale_value := 6.0 / maxf(bounds.size.y, 0.001)
	return Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale_value), Vector3(0, -bounds.position.y * scale_value, 0))

func _sample() -> Dictionary:
	await _frames(SETTLE_FRAMES)
	var times: Array[float] = []
	var process_total := 0.0
	var physics_total := 0.0
	var render_cpu_total := 0.0
	var render_gpu_total := 0.0
	var started := Time.get_ticks_msec()
	var previous := Time.get_ticks_usec()
	while Time.get_ticks_msec() - started < SAMPLE_MS:
		await process_frame
		var now := Time.get_ticks_usec()
		times.append(float(now - previous) / 1000.0)
		previous = now
		process_total += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		physics_total += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		render_cpu_total += RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
		render_gpu_total += RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
	var mean_ms := 0.0
	for value in times:
		mean_ms += value
	mean_ms /= maxf(times.size(), 1)
	var sorted := times.duplicate()
	sorted.sort()
	var low_count := maxi(1, ceili(sorted.size() * 0.01))
	var low_ms := 0.0
	for index in range(sorted.size() - low_count, sorted.size()):
		low_ms += sorted[index]
	low_ms /= low_count
	return {
		"frames": times.size(), "average_fps": 1000.0 / maxf(mean_ms, 0.001),
		"one_percent_low_fps": 1000.0 / maxf(low_ms, 0.001),
		"process_ms": process_total / maxf(times.size(), 1),
		"physics_ms": physics_total / maxf(times.size(), 1),
		"render_cpu_ms": render_cpu_total / maxf(times.size(), 1),
		"render_gpu_ms": render_gpu_total / maxf(times.size(), 1),
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
	}

func _wait_zone(game: Node, zone_id: String) -> void:
	for _index in range(240):
		await process_frame
		if game.current_zone_id == zone_id and not game.zone_transition_pending and not game.zone_load_request_pending:
			return
	push_error("Wychwood cost profile setup timed out: " + zone_id)

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _shutdown(game: Node) -> void:
	print("VERIFIER_PHASE: SHUTDOWN")
	game.prepare_resource_shutdown()
	await _frames(game.ZONE_RETIRE_FRAMES + 6)
	game.finalize_resource_shutdown()
	await _frames(8)
	root.remove_child(game)
	game.free()
	RenderingServer.force_sync()
	await _frames(5)
