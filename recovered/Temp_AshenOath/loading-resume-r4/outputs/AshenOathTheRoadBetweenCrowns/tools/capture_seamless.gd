extends SceneTree

const OUTPUT_DIR := "res://Development_Gallery/screenshots"
var failures := 0
var timestamp := ""

func _initialize() -> void:
	if "--connector-composition" in OS.get_cmdline_user_args():
		call_deferred("_capture_composition")
		return
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("SEAM capture requires a graphical renderer")
		quit(1)
		return
	timestamp = Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var scene := load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		push_error("Main scene unavailable")
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.settings.set_quality_preset("balanced")
	game.call("_new_game")
	await _wait_for_zone(game, "greyfen")
	await _capture(game, "SEAM_001_01_GreyfenBoundary", Vector3(0, 1, -15.7), 0.0)
	await _wait_for_zone(game, "greyfen")
	game.player.global_position = Vector3(0, 0.95, -16.7)
	game.call("_process", 0.25)
	await _wait_for_zone(game, "wychwood")
	await _capture(game, "SEAM_001_02_WychwoodArrival", Vector3(0, 1, 12.4), 3.14)
	print("SEAM-001 SCREENSHOTS: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	if game.has_method("prepare_resource_shutdown"):
		game.prepare_resource_shutdown()
	await _frames(int(game.ZONE_RETIRE_FRAMES) + 6)
	if game.has_method("finalize_resource_shutdown"):
		game.finalize_resource_shutdown()
	await _frames(4)
	game.queue_free()
	await _frames(24)
	if is_instance_valid(game):
		game.free()
	await _frames(2)
	RenderingServer.force_sync()
	quit(0 if failures == 0 else 1)

func _capture(game, stem: String, position: Vector3, yaw: float) -> void:
	game.player.global_position = position
	game.player.velocity = Vector3.ZERO
	game.camera_rig.yaw = yaw
	game.camera_rig.pitch = -0.16
	await _frames(24)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null or image.get_width() != 1280 or image.get_height() != 720:
		failures += 1
		push_error("Invalid SEAM frame: %s" % stem)
		return
	var sample := image.duplicate()
	sample.resize(64, 36, Image.INTERPOLATE_NEAREST)
	var minimum := 1.0
	var maximum := 0.0
	for y in range(sample.get_height()):
		for x in range(sample.get_width()):
			var color: Color = sample.get_pixel(x, y)
			var luminance := color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			minimum = minf(minimum, luminance)
			maximum = maxf(maximum, luminance)
	if maximum - minimum < 0.08:
		failures += 1
		push_error("Blank SEAM frame: %s" % stem)
		return
	var path := "%s/%s_%s.png" % [OUTPUT_DIR, stem, timestamp]
	image.save_png(ProjectSettings.globalize_path(path))
	print("CAPTURED %s" % path)

func _wait_for_zone(game, zone_id: String) -> void:
	for _index in range(360):
		await process_frame
		if game.current_zone_id == zone_id and not game.zone_transition_pending:
			return
	failures += 1
	push_error("Timed out waiting for %s" % zone_id)

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _capture_composition() -> void:
	# Isolated scene/camera evidence, not an earned normal-input route or timing.
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("Connector composition needs the graphical renderer")
		quit(1)
		return
	var output := "D:/Temp/AshenOath/connector-composition-20261029/before"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--composition-output="):
			output = argument.trim_prefix("--composition-output=").replace("\\", "/")
	if not output.begins_with("D:/Temp/AshenOath/"):
		push_error("Composition evidence must remain in D:/Temp/AshenOath")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	var game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	# Composition may wait for slow shader preparation; this allowance does not
	# pass or change the game's retained startup/performance requirements.
	if not await preload("res://tools/runtime_fixture.gd").start(game,180000):
		await preload("res://tools/runtime_fixture.gd").shutdown(game)
		quit(1)
		return
	game.seamless_world.cancel_preparation()
	game.seamless_world.set_process(false)
	game.seamless_world.set_physics_process(false)
	game.set_process(false)
	game.player.set_physics_process(false)
	game.day_night.set_time(900.0)
	game.day_night.set_time_lock(true)
	var life: Node = game.zone_root.find_child("GreyfenLifeController",true,false)
	if life != null: life.set_physics_process(false)
	game.camera_rig.set_process(false)
	var roads := game.zone_root.get_node("ConnectedRoads") as Node3D
	var frontier := game.zone_root.get_node("GreyfenAuthoredFrontier") as Node3D
	var berms: Array[Node] = game.zone_root.find_children("WeatheredLandscapeBoundary","MeshInstance3D",true,false)
	var inventory: Array = []
	for visual: MeshInstance3D in game.zone_root.find_children("*","MeshInstance3D",true,false):
		if not roads.is_ancestor_of(visual) and not frontier.is_ancestor_of(visual) and visual not in berms: continue
		inventory.append({"path":str(game.zone_root.get_path_to(visual)),"aabb":str(visual.get_aabb()),"transform":str(visual.global_transform)})
	var ledger := FileAccess.open(output+"/mesh-owners.json",FileAccess.WRITE)
	ledger.store_string(JSON.stringify(inventory,"  "))
	ledger.close()
	var views := [
		["north_approach",Vector3(0,0,-10),0.0],
		["north_entry",Vector3(0,0,-15),0.0],
		["north_bend",Vector3(0,0,-19),-PI*0.5],
		["north_return",Vector3(6,0,-23),PI*0.5],
		["west_approach",Vector3(-15,0,-10),PI*0.5],
		["east_approach",Vector3(15,0,0),-PI*0.5]
	]
	var selected: PackedStringArray = []
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--composition-views="):
			selected = argument.trim_prefix("--composition-views=").split(",")
	for view: Array in views:
		if not selected.is_empty() and str(view[0]) not in selected: continue
		game.player.global_position = view[1]
		game.player.velocity = Vector3.ZERO
		game.camera_rig.yaw = float(view[2])
		game.camera_rig.pitch = -0.16
		game.camera_rig.reset_follow()
		game.camera_rig.prepare_view()
		await _composition_frame(output+"/"+str(view[0])+".png")
		if str(view[0]) != "north_approach": continue
		roads.visible = false
		await _composition_frame(output+"/north_without_roads.png")
		roads.visible = true
		frontier.visible = false
		await _composition_frame(output+"/north_without_frontier.png")
		frontier.visible = true
		for berm: Node3D in berms: berm.visible = false
		await _composition_frame(output+"/north_without_berms.png")
		for berm: Node3D in berms: berm.visible = true
	print("CONNECTOR COMPOSITION: %s; owners=%d; output=%s; isolated camera evidence only" % ["PASS" if failures == 0 else "FAIL",inventory.size(),output])
	await preload("res://tools/runtime_fixture.gd").shutdown(game)
	quit(0 if failures == 0 else 1)

func _composition_frame(path: String) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.get_size() != Vector2i(1280,720) or image.save_png(path) != OK:
		failures += 1
		push_error("Connector composition capture failed: "+path)
	else:
		print("COMPOSITION CAPTURE ",path)
