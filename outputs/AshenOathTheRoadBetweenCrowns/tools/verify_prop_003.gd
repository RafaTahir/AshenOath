extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	_check(packed != null, "main scene is unavailable")
	if packed == null:
		_finish()
		return
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_new_game")
	await _frames(10)
	var detail_deadline := Time.get_ticks_msec() + 120000
	while game.opening_detail_pending and Time.get_ticks_msec() < detail_deadline:
		await process_frame
	_check(not game.opening_detail_pending, "opening prop assembly did not finish")
	if game.opening_detail_pending:
		game.queue_free()
		await process_frame
		_finish()
		return
	var board := game.zone_root.find_child("notice_board", true, false) as Node3D
	var requests := game.zone_root.find_child("side_contracts", true, false) as Node3D
	_check(board != null and requests != null, "notice-board interactions are missing")
	if board != null and requests != null:
		_check(board.get_meta("external_world_prop", "") == "notice_board", "notice board has no visible prop owner")
		_check(requests.get_meta("external_world_prop", "") == "notice_board", "requests have no visible prop owner")
		for area in [board, requests]:
			_check(area.find_children("*", "MeshInstance3D", true, false).is_empty(), "notice-board interaction draws an orphaned proxy")
		var backing := game.zone_root.find_child("NoticeBoardCollision", true, false) as CollisionShape3D
		_check(backing != null, "notice papers have no physical backing board")
		var post_count: int = 0
		for shape in game.zone_root.find_children("*", "CollisionShape3D", true, false):
			if not shape.shape is BoxShape3D or shape.shape.size.distance_to(Vector3(0.16, 1.4, 0.16)) > 0.02:
				continue
			for offset in [-0.55, 0.55]:
				if shape.global_position.distance_to(board.global_position + Vector3(offset, 0.7, 0)) < 0.02:
					post_count += 1
		_check(post_count == 2, "notice board must have both supported posts")
		if backing != null:
			_check(backing.global_position.distance_to(board.global_position + Vector3(0, 1.25, 0)) < 0.02, "notice-board backing was relocated away from its papers")
			var rendered_backing := false
			for batch in game.zone_root.find_children("*", "MultiMeshInstance3D", true, false):
				if batch.multimesh == null or batch.multimesh.mesh == null:
					continue
				for index in batch.multimesh.instance_count:
					var transform: Transform3D = batch.global_transform * batch.multimesh.get_instance_transform(index)
					if transform.origin.distance_to(backing.global_position) < 0.02 and transform.basis.get_scale().distance_to(Vector3(1.55, 0.9, 0.12)) < 0.02:
						rendered_backing = true
			_check(rendered_backing, "notice-board backing collision has no corresponding rendered surface")
	if "--notice-board-only" in OS.get_cmdline_user_args():
		game.queue_free()
		await process_frame
		_finish()
		return
	var controller = game.world_props
	_check(controller != null, "WorldPropController is not installed")
	if controller == null:
		_finish()
		return
	_check(controller.has_method("get_prop_snapshot"), "world prop snapshot contract is missing")
	var snapshot: Array = controller.get_prop_snapshot()
	var kinds := {}
	for item in snapshot:
		var kind := str(item.get("kind", ""))
		kinds[kind] = int(kinds.get(kind, 0)) + 1
	_check(kinds.has("lantern") or kinds.has("flame"), "lantern/flame props are not registered")
	_check(kinds.has("wheel"), "cart wheel prop is not registered")
	_check(kinds.has("notice_board"), "notice board prop is not registered")
	_check(kinds.has("forge"), "forge prop is not registered")
	_check(kinds.has("shrine"), "shrine prop is not registered")
	_check(kinds.has("bell"), "cemetery bell prop is not registered")
	var component = null
	for candidate in game.zone_root.find_children("InteractiveWorldProp", "Node3D", true, false):
		var parent: Node = candidate.get_parent()
		if parent != null and str(parent.get_meta("world_prop_id", "")) == "village_well":
			component = candidate
			break
	_check(component != null, "interactive world prop component is missing")
	if component != null:
		_check(component.has_method("activate"), "interactive prop activation contract is missing")
		var previous := str(component.get_state())
		component.activate()
		_check(str(component.get_state()) != previous, "interactive prop state did not change")
		_check(str(game.story_state.get_flag("greyfen_well_state", "")) != "", "interactive prop state was not persisted")
	_check(controller.activate_prop("cemetery_bell"), "cemetery bell activation did not resolve")
	_check(controller.has_method("set_prop_state"), "world prop state setter is missing")
	_check(controller.has_method("get_prop_snapshot"), "world prop snapshot is missing")
	game.queue_free()
	await process_frame
	_finish()

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _finish() -> void:
	if failures.is_empty():
		print("PROP-003 VERIFIER: PASS")
		quit(0)
		return
	print("PROP-003 VERIFIER: FAIL (%d)" % failures.size())
	quit(1)
