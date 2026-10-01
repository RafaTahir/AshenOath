extends SceneTree

const OUTPUT_DIR := "res://Development_Gallery/screenshots"
var output_dir := OUTPUT_DIR
var failures := 0

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("WORLD-012 capture requires a graphical renderer")
		quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_move_to_foreground()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir=res://.release-gate/"):
			output_dir = argument.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var scene := load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		push_error("Main scene unavailable")
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await _frames(2)
	game.settings.set_quality_preset("balanced")
	game.call("_new_game")
	var detail_deadline := Time.get_ticks_msec() + 45000
	var playable := false
	while Time.get_ticks_msec() < detail_deadline:
		playable = game.game_started and not paused and game.player != null and game.zone_root != null and game.current_zone_id == "greyfen" and not game.zone_transition_pending and not game.player.transition_locked
		if playable and bool(game.zone_root.get_meta("opening_detail_complete", false)):
			break
		await process_frame
	if not playable or not bool(game.zone_root.get_meta("opening_detail_complete", false)):
		push_error("WORLD-012 Greyfen was not playable and hydrated before capture: started=%s pending=%s detail=%s" % [game.game_started, game.zone_transition_pending, game.zone_root.get_meta("opening_detail_complete", false) if game.zone_root != null else false])
		await _release_game(game)
		quit(1)
		return
	if "--well-only" in OS.get_cmdline_user_args():
		await _capture_well_detail(game)
		print("WORLD-001 WELL SCREENSHOT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
		await _release_game(game)
		quit(0 if failures == 0 else 1)
		return
	if "--social-only" in OS.get_cmdline_user_args() or "--landscape-only" in OS.get_cmdline_user_args():
		await _capture(game, "WORLD_001_Social_Spawn", Vector3(0, 0.16, 12), 0.0)
		for view in [
			["WORLD_001_Social_Table", Vector3(-5.4, 0.8, 7.2)],
			["WORLD_001_Social_Table_Current", Vector3(-5.4, 0.8, 11.5)],
			["WORLD_001_Social_Barrel_Current", Vector3(7.0, 0.8, 10.3)],
			["WORLD_001_Social_Apothecary", Vector3(-5.4, 1.0, -1.2)],
		]:
			game.camera_rig.set_process(false)
			game.camera_rig.camera.look_at_from_position(view[1] + Vector3(4.6, 2.5, 4.4), view[1], Vector3.UP)
			await _frames(12)
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			if image == null or image.get_size() != Vector2i(1280, 720) or not _is_visible(image):
				failures += 1
				push_error("Invalid social composition frame: " + view[0])
			else:
				image.save_png(ProjectSettings.globalize_path("%s/%s.png" % [output_dir, view[0]]))
		if "--landscape-only" in OS.get_cmdline_user_args():
			await _capture_bridge(game)
		print("WORLD-001 SOCIAL/LANDSCAPE CAPTURE: %s (staged visual evidence only)" % ("PASS" if failures == 0 else "FAIL"))
		await _release_game(game)
		quit(0 if failures == 0 else 1)
		return
	if "--houses-only" in OS.get_cmdline_user_args():
		await _capture_house_variants(game)
		print("WORLD-001 HOUSE VARIANTS: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
		await _release_game(game)
		quit(0 if failures == 0 else 1)
		return
	var shrine_only := "--shrine-only" in OS.get_cmdline_user_args()
	var spawn_only := "--spawn-only" in OS.get_cmdline_user_args()
	var house_only := "--house-only" in OS.get_cmdline_user_args()
	var forge_only := "--forge-only" in OS.get_cmdline_user_args()
	var bridge_only := "--bridge-only" in OS.get_cmdline_user_args()
	if not shrine_only and not house_only and not forge_only and not bridge_only:
		await _capture(game, "WORLD_012_01_Greyfen_Spawn_Street", Vector3(0, 0.16, 12), 0.0)
	if not spawn_only and not house_only and not forge_only and not bridge_only:
		await _capture(game, "WORLD_012_02_Greyfen_Shrine_Quarter", Vector3(0.0, 0.72, -4.6), 0.0)
		await _capture_shrine_detail(game)
	if not shrine_only and not spawn_only and not house_only and not bridge_only:
		await _capture_forge(game)
	if bridge_only or (not shrine_only and not spawn_only and not house_only and not forge_only):
		# Approach the bridge from the south road so recovery barriers cannot move the
		# camera onto the empty outer boundary. The view keeps both banks and the
		# crossing in frame while remaining on the authored route.
		await _capture_bridge(game)
	if not shrine_only and not spawn_only and not house_only and not forge_only and not bridge_only:
		await _capture_house(game)
	if house_only:
		await _capture_house(game)
	print("WORLD-012 SCREENSHOTS: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	await _release_game(game)
	quit(0 if failures == 0 else 1)

func _capture(game, stem: String, position: Vector3, yaw: float) -> void:
	game.player.global_position = position
	game.player.velocity = Vector3.ZERO
	game.camera_rig.yaw = yaw
	game.camera_rig.pitch = -0.18
	await _frames(18)
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.get_size() != Vector2i(1280, 720) or not _is_visible(image):
		failures += 1
		push_error("Invalid WORLD-012 frame: %s" % stem)
		return
	image.save_png(ProjectSettings.globalize_path("%s/%s.png" % [output_dir, stem]))
	print("CAPTURED %s" % stem)

func _capture_house(game) -> void:
	game.camera_rig.set_process(false)
	game.camera_rig.camera.look_at_from_position(Vector3(-12.6, 2.7, 5.8), Vector3(-10.0, 1.35, 11.0), Vector3.UP)
	await _frames(24)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null or image.get_size() != Vector2i(1280, 720) or not _is_visible(image):
		failures += 1
		push_error("Invalid WORLD-001 house frame")
		return
	image.save_png(ProjectSettings.globalize_path("%s/WORLD-001_Greyfen_Modular_House.png" % output_dir))
	print("CAPTURED WORLD-001_Greyfen_Modular_House")

func _capture_shrine_detail(game) -> void:
	game.camera_rig.set_process(false)
	game.camera_rig.camera.look_at_from_position(Vector3(5.5, 2.25, -3.25), Vector3(6.0, 0.95, -7.0), Vector3.UP)
	await _frames(24)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null or image.get_size() != Vector2i(1280, 720) or not _is_visible(image):
		failures += 1
		push_error("Invalid WORLD-001 shrine detail frame")
		return
	image.save_png(ProjectSettings.globalize_path("%s/WORLD-001_Shrine_OathstoneClose.png" % output_dir))
	print("CAPTURED WORLD-001_Shrine_OathstoneClose")

func _capture_well_detail(game) -> void:
	game.camera_rig.set_process(false)
	game.camera_rig.camera.look_at_from_position(Vector3(-5.9, 2.45, 2.4), Vector3(-8.0, 1.0, -0.5), Vector3.UP)
	var hud_visible: bool = game.hud.visible
	game.hud.visible = false
	await _frames(24)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	game.hud.visible = hud_visible
	if image == null or image.get_size() != Vector2i(1280, 720) or not _is_visible(image):
		failures += 1
		push_error("Invalid WORLD-001 well frame")
		return
	image.save_png(ProjectSettings.globalize_path("%s/WORLD-001_Greyfen_VillageWell.png" % output_dir))
	print("CAPTURED WORLD-001_Greyfen_VillageWell")

func _capture_house_variants(game) -> void:
	game.camera_rig.set_process(false)
	for house in game.zone_root.find_children("*", "Node3D", true, false):
		if not house.is_in_group("greyfen_house"):
			continue
		var viewpoint: Vector3 = house.global_transform * Vector3(0, 2.8, -6.8)
		var focus: Vector3 = house.global_transform * Vector3(0, 1.65, 0)
		game.camera_rig.camera.look_at_from_position(viewpoint, focus, Vector3.UP)
		await _frames(18)
		await RenderingServer.frame_post_draw
		var frame: Image = root.get_viewport().get_texture().get_image()
		if frame == null or frame.get_size() != Vector2i(1280, 720) or not _is_visible(frame):
			failures += 1
			push_error("Invalid WORLD-001 house variant frame: " + house.name)
			continue
		var path := ProjectSettings.globalize_path("%s/WORLD-001_%s.png" % [output_dir, house.name])
		if frame.save_png(path) != OK:
			failures += 1
			push_error("Cannot save WORLD-001 house variant frame: " + path)
			continue
		print("CAPTURED WORLD-001 %s" % house.name)

func _capture_forge(game) -> void:
	game.camera_rig.set_process(false)
	game.camera_rig.camera.look_at_from_position(Vector3(10.5, 2.4, 7.2), Vector3(10.5, 1.15, 0.1), Vector3.UP)
	await _frames(24)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null or image.get_size() != Vector2i(1280, 720) or not _is_visible(image):
		failures += 1
		push_error("Invalid WORLD-012 forge frame")
		return
	image.save_png(ProjectSettings.globalize_path("%s/WORLD_012_03_Greyfen_Forge_Yard.png" % output_dir))
	print("CAPTURED WORLD_012_03_Greyfen_Forge_Yard")
	game.camera_rig.camera.look_at_from_position(Vector3(10.5, 2.35, -6.2), Vector3(10.5, 1.25, 0.0), Vector3.UP)
	await _frames(24)
	await RenderingServer.frame_post_draw
	image = root.get_viewport().get_texture().get_image()
	if image == null or image.get_size() != Vector2i(1280, 720) or not _is_visible(image):
		failures += 1
		push_error("Invalid WORLD-001 forge street frame")
		return
	image.save_png(ProjectSettings.globalize_path("%s/WORLD-001_Forge_StreetFront.png" % output_dir))
	print("CAPTURED WORLD-001_Forge_StreetFront")

func _capture_bridge(game) -> void:
	game.camera_rig.set_process(false)
	game.camera_rig.camera.look_at_from_position(Vector3(0, 2.2, 10.2), Vector3(0, 0.35, 4.5), Vector3.UP)
	await _frames(24)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null or image.get_size() != Vector2i(1280, 720) or not _is_visible(image):
		failures += 1
		push_error("Invalid WORLD-012 bridge frame")
		return
	image.save_png(ProjectSettings.globalize_path("%s/WORLD_012_04_Greyfen_River_Bridge.png" % output_dir))
	print("CAPTURED WORLD_012_04_Greyfen_River_Bridge")

func _is_visible(image: Image) -> bool:
	var minimum := 1.0
	var maximum := 0.0
	for y in range(0, image.get_height(), 12):
		for x in range(0, image.get_width(), 12):
			var pixel := image.get_pixel(x, y)
			var luminance := pixel.r * 0.2126 + pixel.g * 0.7152 + pixel.b * 0.0722
			minimum = minf(minimum, luminance)
			maximum = maxf(maximum, luminance)
	return maximum - minimum >= 0.08

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _release_game(game: Node) -> void:
	if game != null and is_instance_valid(game):
		if game.has_method("prepare_resource_shutdown"):
			game.prepare_resource_shutdown()
			await _frames(int(game.ZONE_RETIRE_FRAMES) + 4)
		game.queue_free()
	await _frames(8)
	RenderingServer.force_sync()
