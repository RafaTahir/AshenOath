extends SceneTree

var failures := 0

func _initialize() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_new_game")
	await _frames(6)
	_verify_river(game, "greyfen")
	game.call("_load_zone", "wychwood", Vector3(0, 1, 8))
	await _frames(8)
	_verify_river(game, "wychwood")
	var result_code := 0 if failures == 0 else 1
	await _shutdown_game(game)
	print("WATER-001 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(result_code)

func _verify_river(game, zone_id: String) -> void:
	var river = game.zone_root.find_child("LivingRiverSection", true, false)
	check(river != null, "%s river is missing" % zone_id)
	if river == null:
		return
	for bank_name in ["NorthBankSlope", "SouthBankSlope"]:
		var bank := river.find_child(bank_name, true, false) as MeshInstance3D
		check(bank != null and bank.mesh is ArrayMesh and bank.mesh.get_surface_count() > 0, "%s %s lacks rendered geometry" % [zone_id, bank_name])
		if bank != null:
			var material := bank.material_override as StandardMaterial3D
			check(material != null and material.albedo_texture != null, "%s %s lacks the bank material" % [zone_id, bank_name])
	check(_count_named(river, "BridgeStoneFoundation") == 4, "%s bridge lacks four foundations" % zone_id)
	var audio := river.find_child("RiverCurrentAudio", true, false) as AudioStreamPlayer3D
	check(audio != null and audio.stream is AudioStreamWAV, "%s river lacks spatial current audio" % zone_id)
	if audio != null:
		check(audio.max_distance <= 24.0 and audio.volume_db <= -28.0, "%s river audio is not restrained or local" % zone_id)
	var water := river.find_child("FlowingRiverWater", true, false) as MeshInstance3D
	check(water != null and water.material_override is ShaderMaterial, "%s water shader is missing" % zone_id)
	if water != null and water.material_override is ShaderMaterial:
		var code := (water.material_override as ShaderMaterial).shader.code
		check("shore" in code and "foam" in code and "current" in code, "%s water lacks depth, shore, or current cues" % zone_id)

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
