extends SceneTree

const CharacterVisualContract = preload("res://scripts/character_visual_contract.gd")
var failures := 0

func _initialize() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	check(scene != null, "Main scene is unavailable")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_new_game")
	await _frames(3)
	_verify_zone(game, "greyfen", Vector3(0, 1, -13), "gate_wychwood")
	_verify_humans(game)
	game.call("_load_zone", "wychwood", Vector3(0, 1, 13))
	await _frames(3)
	_verify_zone(game, "wychwood", Vector3(0, 1, 13), "gate_greyfen")
	_verify_pack(game)
	print("RECOVERY-002 FOUNDATION: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _verify_zone(game, id: String, gate_position: Vector3, gate_name: String) -> void:
	check(game.spatial_service != null, "%s spatial service missing" % id)
	check(game.spatial_service.is_reserved(gate_position, 0.0), "%s gate corridor is not reserved" % id)
	check(game.zone_root.find_child(gate_name, true, false) != null, "%s transition gate is missing" % id)
	for shape in game.zone_root.find_children("*", "CollisionShape3D", true, false):
		if shape.get_parent() != null and str(shape.get_parent().name) == "BatchedTreeCollisions":
			check(not game.spatial_service.is_reserved(shape.global_position, 0.45), "%s tree collision invades reserved route" % id)

func _verify_humans(game) -> void:
	var player_visual = game.player.find_child("player_kael_visual", true, false)
	var actors := [player_visual] if player_visual != null else []
	check(player_visual != null, "Kael rendered body is missing")
	for id in ["sister_anwen", "mira", "rook", "blacksmith_tor"]:
		var actor = game.zone_root.find_child(id, true, false)
		if actor != null: actors.append(actor)
	for actor in actors:
		var report := CharacterVisualContract.validate(actor, true)
		check(bool(report.valid), "%s fails visual contract" % actor.name)
		check(report.bounds.size.y >= 1.50 and report.bounds.size.y <= 1.95, "%s rendered height %.2f is outside human range" % [actor.name, report.bounds.size.y])

func _verify_pack(game) -> void:
	check(game.active_enemies.size() == 5, "Wychwood pack is incomplete")
	for enemy in game.active_enemies:
		var visual = enemy.find_child("*_visual", true, false)
		check(visual != null, "%s visual missing" % enemy.enemy_id)
		if visual != null:
			var report := CharacterVisualContract.validate(visual, true)
			check(report.bounds.size.y >= 1.45 and report.bounds.size.y <= 2.15, "%s rendered height %.2f is invalid" % [enemy.enemy_id, report.bounds.size.y])

func _frames(count: int) -> void:
	for _i in range(count): await process_frame

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
