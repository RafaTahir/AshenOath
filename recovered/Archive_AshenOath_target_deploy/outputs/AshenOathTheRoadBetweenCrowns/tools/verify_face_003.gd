extends SceneTree

const AssetSpawnHelper = preload("res://scripts/asset_spawn_helper.gd")
const CharacterPresentation = preload("res://scripts/character_presentation.gd")

var failures: Array[String] = []
var helper: Node
var tested_game: Node

func _initialize() -> void:
	helper = AssetSpawnHelper.new()
	root.add_child(helper)
	await process_frame
	_verify_asset_role("player_human", "Kael")
	_verify_asset_role("sister_anwen_human", "Sister Anwen")

	var packed := load("res://scenes/main.tscn") as PackedScene
	_assert(packed != null, "main scene is unavailable")
	if packed != null:
		tested_game = packed.instantiate()
		root.add_child(tested_game)
		await _frames(2)
		tested_game.call("_new_game")
		await _frames(8)
		_verify_runtime_face(tested_game.player, "Kael")
		var anwen = tested_game.zone_root.find_child("sister_anwen", true, false)
		_verify_runtime_face(anwen, "Sister Anwen")
		var life = tested_game.zone_root.find_child("GreyfenLifeController", true, false)
		_assert(life != null and life.actors.size() >= 7, "Greyfen crowd is unavailable for face validation")
		if life != null:
			for entry in life.actors:
				_verify_runtime_face(entry.node, str(entry.id))
		tested_game.call("_load_zone", "Wychwood", Vector3(0, 0.9, 9))
		await _frames(8)
		_assert(tested_game.active_enemies.size() == 5, "Wychwood enemies are unavailable for face validation")
		for enemy in tested_game.active_enemies:
			_verify_runtime_face(enemy, str(enemy.enemy_id))

	_finish()

func _verify_asset_role(role: String, label: String) -> void:
	var visual: Node3D = helper.spawn_visual_role(role, "characters")
	_assert(visual != null, "%s visual failed to instantiate" % label)
	if visual == null:
		return
	var owner := Node3D.new()
	root.add_child(owner)
	owner.add_child(visual)
	if role == "player_human":
		CharacterPresentation.apply_player(owner, visual)
	else:
		CharacterPresentation.apply_npc(owner, role)
	await _frames(1)
	_verify_face_contract(owner if role != "player_human" else visual, label)
	owner.free()

func _verify_runtime_face(actor: Node, label: String) -> void:
	_assert(actor != null, "%s actor is missing" % label)
	if actor == null:
		return
	# Presentation is applied to the gameplay actor for NPCs/enemies and to its
	# visual child for the player. Check the actor root so both contracts are
	# covered without losing the driver attached by CharacterPresentation.
	_verify_face_contract(actor, label)

func _verify_face_contract(root_node: Node, label: String) -> void:
	var driver = root_node.find_child("CharacterFaceDriver", true, false)
	_assert(driver != null and driver.has_method("get_contract_report"), "%s has no native face driver" % label)
	if driver == null:
		return
	var report: Dictionary = driver.get_contract_report()
	_assert(bool(report.get("valid", false)), "%s native face contract is invalid: %s" % [label, report])
	_assert(int(report.get("native_face_surface_count", 0)) > 0, "%s has no native face/skin material surfaces" % label)
	_assert(not bool(report.get("synthetic_geometry_created", true)), "%s face driver created synthetic geometry" % label)
	_assert(not _has_legacy_overlay(root_node), "%s still contains legacy face/eye overlay anatomy" % label)

func _has_legacy_overlay(root_node: Node) -> bool:
	for child in root_node.find_children("*", "", true, false):
		var token := str(child.name).to_lower().replace(" ", "").replace("-", "")
		for forbidden in [
			"faceplane", "eyewhite", "irisl", "irisr", "browl", "browr", "nosebridge", "mouthline", "hairline",
			"headfeaturesocket", "monsterheadfeatures", "monsteredgedetail", "hunchedbackread",
			"fake_neck", "proxy", "motionarm", "motionleg"
		]:
			if token.contains(forbidden.replace("_", "")):
				return true
	return false

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _finish() -> void:
	if is_instance_valid(tested_game):
		tested_game.free()
	if is_instance_valid(helper):
		helper.free()
	if failures.is_empty():
		print("FACE-003 VERIFIER: PASS - native face materials and feature driver")
		quit(0)
		return
	print("FACE-003 VERIFIER: FAIL (%d)" % failures.size())
	for failure in failures:
		print("- %s" % failure)
	quit(1)
