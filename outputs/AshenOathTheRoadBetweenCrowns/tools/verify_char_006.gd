extends SceneTree

var failures: Array[String] = []
var game: Node = null

func _initialize() -> void:
	var packed := ResourceLoader.load("res://scenes/main.tscn") as PackedScene
	_check(packed != null, "main scene failed to load")
	if packed == null:
		quit(1)
		return
	game = packed.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_new_game")
	await _frames(6)
	var player: Node = game.get("player")
	_check(player != null, "Kael failed to instantiate")
	if player == null:
		_finish()
		return
	var visual_root: Node = player.get("visual_root")
	_check(visual_root != null, "Kael has no visual root")
	if visual_root == null:
		_finish()
		return
	var driver: Node = player.get("animation_driver")
	_check(driver != null and driver.has_method("is_valid") and driver.is_valid(), "Kael has no valid fused animation driver")
	if driver != null:
		print("CHAR-006 animation players: %d" % driver.get("animation_players").size())
		_check(driver.get("animation_players").size() == 1, "Kael must use one consolidated animation rig")
	var composite := _find_composite(visual_root)
	_check(composite != null and int(composite.get_meta("character_rig_layer_count", 0)) == 1, "Kael rig layers were not consolidated")
	if driver != null and driver.has_method("is_valid") and driver.is_valid():
		_check(driver.get_animation_player().has_animation("Sword_Attack"), "Neutral sword attack is not attached to Kael")
		_check(driver.get_animation_player().has_animation("Idle"), "Neutral idle is not attached to Kael")
	var skeleton: Skeleton3D = _find_skeleton(visual_root)
	_check(skeleton != null, "Kael lacks Skeleton3D")
	if skeleton != null:
		_check(skeleton.find_bone("hand_r") >= 0, "Kael shared rig lacks hand_r")
		var sword_socket := visual_root.find_child("KaelSwordSocket", true, false)
		_check(sword_socket != null, "Kael sword is not attached to a bone socket")
		_check(sword_socket != null and sword_socket.get("bone_name") == "hand_r", "Kael sword socket is not on hand_r")
	_check(skeleton != null and skeleton.find_bone("Head") >= 0, "Kael has no native head bone")
	_check(not _has_proxy_anatomy(visual_root), "Kael still has forbidden proxy anatomy")
	if driver != null and driver.has_method("trigger_action"):
		var before := skeleton.get_bone_pose(skeleton.find_bone("hand_r")) if skeleton != null else Transform3D.IDENTITY
		driver.trigger_action("attack_light")
		await _frames(8)
		var after := skeleton.get_bone_pose(skeleton.find_bone("hand_r")) if skeleton != null else Transform3D.IDENTITY
		_check(before != after, "Kael sword attack did not change the hand pose")
	_finish()

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

func _find_composite(node: Node) -> Node:
	if bool(node.get_meta("character_composite", false)):
		return node
	for child in node.get_children():
		var found := _find_composite(child)
		if found != null:
			return found
	return null

func _has_proxy_anatomy(node: Node) -> bool:
	for child in node.find_children("*", "", true, false):
		var lowered := str(child.name).to_lower().replace("_", "")
		for token in ["faceplane", "eyelef", "eyeright", "fake neck", "proxy", "hunchedback", "motionarm", "motionleg"]:
			if lowered.contains(token.replace(" ", "")):
				return true
	return false

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _finish() -> void:
	if is_instance_valid(game):
		game.free()
	if failures.is_empty():
		print("CHAR-006 VERIFIER: PASS - Kael uses the fused shared humanoid and bone sword")
	else:
		print("CHAR-006 VERIFIER: FAIL (%d)" % failures.size())
		for failure in failures:
			print("- %s" % failure)
	quit(0 if failures.is_empty() else 1)
