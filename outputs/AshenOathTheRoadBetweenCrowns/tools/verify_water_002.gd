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
	_verify_river(game, "greyfen")
	game.call("_load_zone", "wychwood", Vector3(0, 1, 8))
	await _frames(10)
	_verify_river(game, "wychwood")
	print("WATER-002 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

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
		check(_count_named(motion, "RiverRipple_") >= 7, "%s river ripple dressing is incomplete" % zone_id)
	check(river.find_child("RiverBankWetness_North", true, false) != null, "%s north bank wetness is missing" % zone_id)
	check(river.find_child("RiverBankWetness_South", true, false) != null, "%s south bank wetness is missing" % zone_id)
	var water: Node = river.find_child("FlowingRiverWater", true, false)
	check(water != null and water is MeshInstance3D, "%s flowing water is missing" % zone_id)
	if water is MeshInstance3D:
		check(str(water.get_meta("water_role", "")) == "WATER-002", "%s water role metadata is missing" % zone_id)
		check((water as MeshInstance3D).mesh is PlaneMesh, "%s water surface must be subdivided plane geometry" % zone_id)
		if (water as MeshInstance3D).mesh is PlaneMesh:
			var plane := (water as MeshInstance3D).mesh as PlaneMesh
			check(plane.subdivide_depth >= 24 and plane.subdivide_width >= 6, "%s water surface lacks vertex resolution for flow" % zone_id)
		var material := (water as MeshInstance3D).material_override
		check(material is ShaderMaterial, "%s water shader material is missing" % zone_id)
		if material is ShaderMaterial:
			var code := (material as ShaderMaterial).shader.code
			for token in ["flow_uv", "depth", "foam", "ripple", "NORMAL", "flow_speed"]:
				check(token in code, "%s water shader lacks %s" % [zone_id, token])

func _count_named(node: Node, prefix: String) -> int:
	var result := 1 if str(node.name).begins_with(prefix) else 0
	for child in node.get_children():
		result += _count_named(child, prefix)
	return result

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
