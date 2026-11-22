extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	if not _mount_candidate_packs():
		print("PACKED STARTUP VERIFIER: FAIL (%d)" % failures.size())
		quit(1)
		return
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
			print("VERIFIER_PHASE: SHUTDOWN")
			# Packed startup used to quit one frame after queue_free(), which left
			# owned timers, zone services, and renderer resources alive at process
			# exit. Exercise the runtime's real staged shutdown contract instead.
			if game.has_method("prepare_resource_shutdown"):
				game.prepare_resource_shutdown()
				await _settle_frames(int(game.get("ZONE_RETIRE_FRAMES")) + 8)
			if game.has_method("finalize_resource_shutdown"):
				game.finalize_resource_shutdown()
			await _settle_frames(8)
			if game.is_inside_tree():
				root.remove_child(game)
			if is_instance_valid(game):
				game.free()
			await physics_frame
			await _settle_frames(4)
			RenderingServer.force_sync()
			await _settle_frames(2)
	if failures.is_empty():
		print("PACKED STARTUP VERIFIER: PASS")
		quit()
	else:
		print("PACKED STARTUP VERIFIER: FAIL (%d)" % failures.size())
		quit(1)

func _mount_candidate_packs() -> bool:
	# This native check executes a Web export. Native lacks Web's Fetch/mount
	# handoff, so resolve only declared local packs from the isolated candidate.
	var candidate_root := ProjectSettings.globalize_path("res://")
	if not FileAccess.file_exists(candidate_root.path_join("index.pck")) or FileAccess.file_exists(candidate_root.path_join("project.godot")):
		_fail("packed startup requires an isolated --main-pack invocation")
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://runtime_pack_manifest.json"))
	if not parsed is Dictionary or not parsed.get("packs") is Dictionary:
		_fail("packed startup has no valid runtime pack manifest")
		return false
	var packs: Dictionary = parsed.packs
	for id in packs:
		var spec: Dictionary = packs[id]
		if str(spec.get("url", "")).is_empty():
			continue
		var artifact := str(spec.get("candidate_artifact", ""))
		if artifact.is_empty() or artifact != artifact.get_file() or not artifact.ends_with(".pck"):
			_fail("invalid declared candidate pack: " + str(id))
			return false
		var path := ProjectSettings.globalize_path("res://packs/" + artifact)
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null or file.get_length() != int(spec.get("bytes", -1)):
			_fail("missing or mismatched declared candidate pack: " + str(id))
			return false
		file.close()
		if not ProjectSettings.load_resource_pack(path, false):
			_fail("declared candidate pack could not be mounted: " + str(id))
			return false
		print("PACKED STARTUP: mounted " + str(id))
	return true

func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	failures.append(message)
	push_error(message)

func _settle_frames(count: int) -> void:
	for _index in range(maxi(count, 0)):
		await process_frame
