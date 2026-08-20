extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		_fail("main scene could not be loaded from the packed Web artifact")
	else:
		var game := scene.instantiate()
		if game == null:
			_fail("main scene instantiation returned null")
		else:
			root.add_child(game)
			await process_frame
			_check(game.get_script() != null, "packed main scene has no runtime script")
			_check(game.get("hud") != null, "packed runtime did not initialize the HUD")
			_check(game.get("audio") != null, "packed runtime did not initialize audio")
			game.queue_free()
			await process_frame
	if failures.is_empty():
		print("PACKED STARTUP VERIFIER: PASS")
		quit()
	else:
		print("PACKED STARTUP VERIFIER: FAIL (%d)" % failures.size())
		quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	failures.append(message)
	push_error(message)
