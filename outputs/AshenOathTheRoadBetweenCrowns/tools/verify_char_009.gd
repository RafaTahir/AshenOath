extends SceneTree

var failures := 0

func _initialize() -> void:
	var packed := ResourceLoader.load("res://scenes/main.tscn") as PackedScene
	check(packed != null, "main scene is missing")
	if packed == null:
		quit(1)
		return
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_new_game")
	await _frames(8)
	var life: Node = game.zone_root.find_child("GreyfenLifeController", true, false)
	check(life != null, "Greyfen life controller is missing")
	if life != null:
		var actors: Array = life.get("actors")
		var previous_body := ""
		var identities: Dictionary = {}
		var ambient_count := 0
		for entry in actors:
			if bool(entry.get("named", false)):
				continue
			ambient_count += 1
			var node: Node3D = entry.get("node")
			check(node != null, "ambient routine has no actor node")
			if node == null:
				continue
			var visual: Node = null
			for candidate in node.find_children("*", "Node3D", true, false):
				if candidate.has_meta("char_009_identity"):
					visual = candidate
					break
			check(visual != null, "%s has no shared crowd visual" % str(entry.get("id", "routine")))
			if visual == null:
				continue
			var body_role: String = str(visual.get_meta("char_002_body_role", ""))
			var identity: String = str(visual.get_meta("char_009_identity", ""))
			check(not body_role.is_empty(), "%s has no body role" % str(entry.get("id", "routine")))
			check(not identity.is_empty(), "%s has no deterministic identity" % str(entry.get("id", "routine")))
			check(body_role != previous_body, "adjacent crowd actors repeat the same body role")
			previous_body = body_role
			identities[identity] = true
			var driver: Node = visual.find_child("CharacterAnimationDriver", true, false)
			check(driver != null and driver.has_method("is_valid") and driver.is_valid(), "%s lacks a valid crowd animation driver" % str(entry.get("id", "routine")))
			var normalized_height: float = float(visual.get_meta("normalized_target_height", 0.0))
			check(normalized_height >= 1.55 and normalized_height <= 1.90, "%s is outside adult crowd height range" % str(entry.get("id", "routine")))
			check(not visual.name.to_lower().contains("placeholder"), "%s uses a placeholder crowd body" % str(entry.get("id", "routine")))
			check(not _has_proxy_anatomy(visual), "%s contains proxy anatomy" % str(entry.get("id", "routine")))
			check(visual.find_children("*", "Skeleton3D", true, false).size() > 0, "%s has no crowd skeleton" % str(entry.get("id", "routine")))
			check(visual.find_children("*", "AnimationPlayer", true, false).size() > 0, "%s has no crowd animation player" % str(entry.get("id", "routine")))
		check(ambient_count >= 4, "Greyfen must retain four ambient routines")
		check(identities.size() >= 4, "ambient crowd variation is too repetitive")
	if is_instance_valid(game):
		game.free()
	print("CHAR-009 VERIFIER: %s" % ("PASS - crowd scale, identity, and animation variation" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _has_proxy_anatomy(node: Node) -> bool:
	for child in node.find_children("*", "", true, false):
		var lowered: String = str(child.name).to_lower().replace("_", "")
		for token in ["faceplane", "eyelef", "eyeright", "fakeneck", "proxy", "hunchedback", "motionarm", "motionleg"]:
			if lowered.contains(token):
				return true
	return false

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
