extends SceneTree

var failures := 0

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	check(scene != null,"Main scene missing")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_new_game")
	await settle(5)
	for event_name in ["step_road","step_forest","step_mud","swing","heavy","light_hit","heavy_hit","block","parry","oathfire_sheathe","cloth_wind","village_life","menu_hover","menu_click"]:
		check(game.audio.has_recorded_event(event_name),"Recorded audio missing for %s" % event_name)
		check(game.audio.call("_event_stream",event_name) is AudioStream,"Recorded event %s cannot resolve a stream" % event_name)

	var camera = game.camera_rig
	var initial_zoom: float = camera.get_zoom_distance()
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	camera.call("_input",wheel)
	check(camera.get_zoom_distance() < initial_zoom,"Mouse-wheel zoom in failed")
	var after_wheel: float = camera.get_zoom_distance()
	Input.action_press("camera_zoom_out")
	camera.call("_apply_keyboard_camera",0.5)
	Input.action_release("camera_zoom_out")
	check(camera.get_zoom_distance() > after_wheel,"Keyboard zoom out failed")
	check(camera.get_zoom_distance() >= camera.MIN_ZOOM_DISTANCE and camera.get_zoom_distance() <= camera.MAX_ZOOM_DISTANCE,"Camera zoom escaped its safe range")

	for zone_id in ["greyfen","wychwood"]:
		game.call("_load_zone",zone_id,Vector3(0,1,7))
		await settle(4)
		check(_count_prefix(game.zone_root,"BridgeApproachRamp") == 4,"%s bridge has no walkable approach pair" % zone_id)

	print("AUDIO-001 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	game.queue_free()
	await settle(3)
	quit(0 if failures == 0 else 1)

func _count_prefix(parent: Node, prefix: String) -> int:
	var count := 1 if str(parent.name).begins_with(prefix) else 0
	for child in parent.get_children():
		count += _count_prefix(child,prefix)
	return count

func settle(frames: int) -> void:
	for _index in range(frames):
		await process_frame
		await physics_frame

func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("AUDIO-001: %s" % message)
