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
