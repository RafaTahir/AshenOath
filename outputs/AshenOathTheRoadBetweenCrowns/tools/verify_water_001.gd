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
	print("WATER-001 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _verify_river(game, zone_id: String) -> void:
	var river = game.zone_root.find_child("LivingRiverSection", true, false)
	check(river != null, "%s river is missing" % zone_id)
	if river == null:
		return
	check(river.find_child("NorthBankSlope", true, false) != null, "%s north bank is not integrated" % zone_id)
	check(river.find_child("SouthBankSlope", true, false) != null, "%s south bank is not integrated" % zone_id)
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

func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
