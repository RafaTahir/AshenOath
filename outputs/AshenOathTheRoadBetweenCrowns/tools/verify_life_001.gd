extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	_assert(scene != null, "Main scene is unavailable")
	if scene == null:
		_finish()
		return
	var game = scene.instantiate()
	root.add_child(game)
	await _frames(2)
	game.settings.set_quality_preset("balanced")
	game.call("_new_game")
	await _frames(14)
	_assert(str(game.current_zone_id) == "greyfen", "New Game did not start in Greyfen")
	var life: Node = game.zone_root.find_child("GreyfenLifeController", true, false)
	_assert(life != null, "Greyfen daily-life controller is missing")
	if life == null:
		_finish(game)
		return
	var snapshot: Array = life.get_routine_snapshot() if life.has_method("get_routine_snapshot") else []
	_assert(snapshot.size() >= 7, "Greyfen daily life has fewer than seven retained actors")
	var ids := {}
	var occupations := {}
	for item in snapshot:
		var id := str(item.get("id", ""))
		ids[id] = true
		occupations[str(item.get("occupation", ""))] = true
		_assert(str(item.get("activity", "")) != "", "%s has no authored activity beat" % id)
		_assert(str(item.get("state", "")) == "walking", "%s did not begin in a walking state" % id)
		# Routine actors are owned by the zone root, not the controller. Inspect
		# ownership and route safety through the controller's public snapshot.
		var found: Node = game.zone_root.find_child(id if bool(item.get("named", false)) else "Routine_%s" % id, true, false)
		_assert(found != null, "%s routine actor is missing" % id)
		if found != null:
			_assert(str(found.get_meta("life_ticket", "")) == "LIFE-001", "%s lacks LIFE-001 ownership" % id)
			_assert(not game.spatial_service.is_river_excluded(found.global_position, 0.55), "%s spawned in the river" % id)
	_assert(ids.has("walker_well") and ids.has("walker_board") and ids.has("shrine_pilgrim") and ids.has("forge_helper"), "Core Greyfen routines are incomplete")
	_assert(occupations.size() >= 4, "Daily life occupations are too repetitive")

	# Exercise the authored activity contract on every retained routine. This
	# does not grant story progress; it proves that each driver can enter and
	# leave its work/prayer/attention pose without becoming permanently locked.
	for entry in life.get("actors"):
		life.call("_begin_activity", entry)
		_assert(bool(entry.get("activity_active", false)), "%s could not enter activity" % str(entry.id))
		_assert(str(entry.get("life_state", "")).begins_with("working:"), "%s has no working state" % str(entry.id))
		life.call("_end_activity", entry)
		_assert(not bool(entry.get("activity_active", false)), "%s remained locked in activity" % str(entry.id))

	# Reporting and bell state alter ambient reaction metadata without moving
	# actors across the river or replacing their normal schedule.
	game.story_state.set_flag("evidence_report", "public")
	game.story_state.set_flag("cemetery_bell_rung", true)
	life.call("_sync_story_state", false)
	for entry in life.get("actors"):
		_assert(str(entry.get("story_reaction", "")).contains("reported_public"), "%s did not receive report reaction" % str(entry.id))
		_assert(str(entry.get("story_reaction", "")).contains("bell_rung"), "%s did not receive bell reaction" % str(entry.id))

	print("LIFE-001 METRICS actors=%d occupations=%d" % [snapshot.size(), occupations.size()])
	_finish(game)

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)

func _finish(game = null) -> void:
	if game != null and is_instance_valid(game):
		game.free()
	if failures.is_empty():
		print("LIFE-001 VERIFIER: PASS - routine beats, poses, reactions, and river-safe ownership")
	else:
		print("LIFE-001 VERIFIER: FAIL (%d)" % failures.size())
		for failure in failures:
			print("- %s" % failure)
	quit(0 if failures.is_empty() else 1)
