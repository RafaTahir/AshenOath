extends SceneTree

var failures := 0

func _initialize() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	check(scene != null, "Main scene is unavailable")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await _frames(2)
	game.call("_new_game")
	await _frames(8)
	await _verify_river(game, "greyfen")
	game.call("_load_zone", "wychwood", Vector3(0, 1, 8))
	await _frames(10)
	await _verify_river(game, "wychwood")
	var result_code := 0 if failures == 0 else 1
	await _shutdown_game(game)
	print("WATER-002 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(result_code)

func _verify_river(game, zone_id: String) -> void:
	var zone_root: Node = game.get("zone_root")
	var river: Node = zone_root.find_child("LivingRiverSection", true, false) if zone_root != null else null
	check(river != null, "%s river is missing" % zone_id)
	if river == null:
		return
	var motion: Node = river.find_child("RiverMotionController", true, false)
	check(motion != null, "%s river motion controller is missing" % zone_id)
	if motion != null:
		check(str(motion.get_meta("ticket", "")) == "WATER-002", "%s river motion ticket metadata is missing" % zone_id)
		var leaves: Node = motion.find_child("RiverFloatingLeafBatch", true, false)
		check(leaves != null and leaves is MultiMeshInstance3D, "%s river leaf batch is missing" % zone_id)
		if leaves is MultiMeshInstance3D:
			var multimesh := (leaves as MultiMeshInstance3D).multimesh
			check(multimesh != null and multimesh.instance_count >= 14, "%s river leaf batch is under-populated" % zone_id)
			if multimesh != null:
				var start_time := float(motion.get("flow_time"))
				var start := multimesh.get_instance_transform(0).origin
				for _tick in range(20):
					await physics_frame
				var end := multimesh.get_instance_transform(0).origin
				check(float(motion.get("flow_time")) > start_time + 0.10, "%s river motion clock is stalled" % zone_id)
				if DisplayServer.get_name().to_lower() != "headless":
					check(end.x > start.x + 0.04 and absf(end.z - start.z) < 0.10, "%s river leaves do not flow along the channel" % zone_id)
		var ribbons := motion.find_child("RiverCurrentRibbonBatch", true, false) as MultiMeshInstance3D
		check(ribbons != null and ribbons.multimesh != null, "%s current ribbons are missing" % zone_id)
		if ribbons != null and ribbons.multimesh != null:
			var ribbon_sizes: Array = motion.get("current_ribbon_sizes")
			check(not ribbon_sizes.is_empty() and ribbon_sizes[0].x < float(motion.get("width")) * 0.20, "%s current ribbon spans too much of the channel" % zone_id)
		check(_count_named(motion, "RiverRipple_") >= 7, "%s river ripple dressing is incomplete" % zone_id)
	check(river.find_child("RiverBankWetness_North", true, false) != null, "%s north bank wetness is missing" % zone_id)
	check(river.find_child("RiverBankWetness_South", true, false) != null, "%s south bank wetness is missing" % zone_id)
	for bank in ["North", "South"]:
		var foam := river.find_child("RiverShoreFoam_%s" % bank, true, false) as MeshInstance3D
		check(foam != null and foam.mesh is ArrayMesh, "%s %s shore foam is not broken shoreline geometry" % [zone_id, bank])
	var water: Node = river.find_child("FlowingRiverWater", true, false)
	check(water != null and water is MeshInstance3D, "%s flowing water is missing" % zone_id)
	if water is MeshInstance3D:
		check(str(water.get_meta("water_role", "")) == "WATER-002", "%s water role metadata is missing" % zone_id)
		check((water as MeshInstance3D).mesh is ArrayMesh, "%s water surface lacks authored shoreline geometry" % zone_id)
		if (water as MeshInstance3D).mesh is ArrayMesh:
			var mesh := (water as MeshInstance3D).mesh as ArrayMesh
			check(mesh.surface_get_array_len(0) >= 1000, "%s water surface lacks vertex resolution for flow" % zone_id)
			var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			check(absf(vertices[0].z - vertices[3].z) > 0.001, "%s water still has a straight bank edge" % zone_id)
		var material := (water as MeshInstance3D).material_override
		check(material is ShaderMaterial, "%s water shader material is missing" % zone_id)
		if material is ShaderMaterial:
			var code := (material as ShaderMaterial).shader.code
			for token in ["flow_uv", "depth", "foam", "ripple", "NORMAL", "flow_speed"]:
				check(token in code, "%s water shader lacks %s" % [zone_id, token])
			check("min(UV.y, 1.0 - UV.y)" in code and "vec2(-TIME" in code, "%s shader treats channel ends as banks or flows across the banks" % zone_id)

func _count_named(node: Node, prefix: String) -> int:
	var result := 1 if str(node.name).begins_with(prefix) else 0
	for child in node.get_children():
		result += _count_named(child, prefix)
	return result

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _shutdown_game(game: Node) -> void:
	if is_instance_valid(game) and game.has_method("prepare_resource_shutdown"):
		game.prepare_resource_shutdown()
		await _frames(20)
	if is_instance_valid(game) and game.has_method("finalize_resource_shutdown"):
		game.finalize_resource_shutdown()
		await _frames(12)
	print("VERIFIER_PHASE: SHUTDOWN")
	if is_instance_valid(game):
		game.queue_free()
		await _frames(8)
	RenderingServer.force_sync()
	await _frames(4)

func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
