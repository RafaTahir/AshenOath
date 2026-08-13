extends SceneTree

var failures: Array[String] = []
var game: Node = null

func _initialize() -> void:
	var packed := ResourceLoader.load("res://scenes/main.tscn") as PackedScene
	_check(packed != null, "main scene failed to load")
	if packed == null:
		_finish()
		return
	game = packed.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_new_game")
	await _frames(8)
	var anwen := game.find_child("sister_anwen", true, false)
	_check(anwen != null, "Sister Anwen interaction did not instantiate")
	if anwen == null:
		_finish()
		return
	var visual := anwen.find_child("sister_anwen_human", true, false)
	_check(visual != null, "Anwen visual role is missing")
	if visual == null:
		_finish()
		return
	var driver := anwen.find_child("CharacterAnimationDriver", true, false)
	_check(driver != null and driver.has_method("is_valid") and driver.is_valid(), "Anwen has no valid fused animation driver")
	if driver != null:
		_check(driver.get("animation_players").size() == 1, "Anwen must use one consolidated animation rig")
		_check(driver.get_animation_player().has_animation("Idle_No"), "UAL2 idle is not attached to Anwen")
	var composite := _find_composite(visual)
	_check(composite != null and int(composite.get_meta("character_rig_layer_count", 0)) == 1, "Anwen rig layers were not consolidated")
	var skeleton := _find_skeleton(visual)
	_check(skeleton != null, "Anwen lacks Skeleton3D")
	if skeleton != null:
		_check(skeleton.find_bone("Head") >= 0, "Anwen has no native head bone")
		_check(skeleton.find_bone("hand_r") >= 0, "Anwen shared rig lacks hand_r")
	_check(_has_visible_skinned_mesh(visual), "Anwen has no visible skinned mesh")
	_check(not _has_proxy_anatomy(visual), "Anwen still has forbidden proxy anatomy")
	var bounds := _rendered_bounds(visual)
	_check(bounds.size.y > 1.45 and bounds.size.y < 1.90, "Anwen rendered height is outside the role range")
	_check(absf(bounds.position.y) < 0.12, "Anwen rendered feet are not grounded")

	# Approach behavior is part of Anwen's visible contract: put Kael inside
	# her attention radius and prove the +Z-facing wrapper turns toward him.
	var player := game.get("player") as Node3D
	if player != null:
		player.global_position = anwen.global_position + Vector3(0, 0, 3.0)
		await _frames(18)
		var to_player: Vector3 = player.global_position - anwen.global_position
		to_player.y = 0.0
		var forward: Vector3 = anwen.global_basis.z.normalized()
		_check(to_player.length() > 0.1 and forward.dot(to_player.normalized()) > 0.72, "Anwen turns away from Kael during approach")
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

func _has_visible_skinned_mesh(node: Node) -> bool:
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh != null and mesh.visible and mesh.skin != null:
			return true
	return false

func _has_proxy_anatomy(node: Node) -> bool:
	for child in node.find_children("*", "", true, false):
		var lowered := str(child.name).to_lower().replace("_", "")
		for token in ["faceplane", "eyelef", "eyeright", "fakeneck", "proxy", "hunchedback", "motionarm", "motionleg"]:
			if lowered.contains(token):
				return true
	return false

func _rendered_bounds(root_node: Node3D) -> AABB:
	var has_bounds := false
	var combined := AABB()
	for mesh in root_node.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null or not mesh.visible:
			continue
		var local: AABB = mesh.get_aabb()
		var global: AABB = AABB(mesh.global_transform * local.position, local.size)
		var corners := [
			Vector3(global.position.x, global.position.y, global.position.z),
			Vector3(global.end.x, global.position.y, global.position.z),
			Vector3(global.position.x, global.end.y, global.position.z),
			Vector3(global.position.x, global.position.y, global.end.z),
			Vector3(global.end.x, global.end.y, global.end.z)
		]
		for corner in corners:
			if not has_bounds:
				combined = AABB(corner, Vector3.ZERO)
				has_bounds = true
			else:
				combined = combined.expand(corner)
	return combined

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
		print("CHAR-007 VERIFIER: PASS - Anwen uses the fused female body and holds player-facing approach")
	else:
		print("CHAR-007 VERIFIER: FAIL (%d)" % failures.size())
		for failure in failures:
			print("- %s" % failure)
	quit(0 if failures.is_empty() else 1)
