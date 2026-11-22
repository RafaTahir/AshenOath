extends SceneTree

const OUTPUT_DIR := "res://Development_Gallery/screenshots"
var failures := 0

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("PRODUCT capture requires a graphical Compatibility renderer")
		quit(1)
		return
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await _frames(24)
	game.settings.set_quality_preset("balanced")
	game.hud.show_main_menu()
	await _frames(8)
	await _capture(game, "HUD_005_MainMenu_1080p")
	game.call("_new_game")
	await _frames(32)
	_clear_transient_overlays(game)
	await _settle_player(game, Vector3(0, 0.2, 7))
	game.camera_rig.yaw = 0.0
	game.camera_rig.pitch = -0.12
	await _frames(12)
	await _capture(game, "SOUL_REBUILD_Greyfen_Current")
	game.quests.unlocked["main_hart_remembers"] = true
	game.quests.start_quest("main_hart_remembers")
	game.story_state.set_flag("confession_method", "witnesses")
	game.call("_load_zone", "hart_glade", Vector3(0, 1, 8))
	await _frames(26)
	_clear_transient_overlays(game)
	await _settle_player(game, Vector3(0, 0.2, 7))
	game.camera_rig.yaw = 0.0
	game.camera_rig.pitch = -0.16
	await _frames(12)
	await _capture(game, "SOUL_REBUILD_HartGlade_Current")
	game.free()
	await _frames(4)
	print("PRODUCT-001 SCREENSHOTS: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

func _capture(game: Node, stem: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		failures += 1
		return
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	var path := ProjectSettings.globalize_path("%s/%s_%s.png" % [OUTPUT_DIR, stem, stamp])
	if image.save_png(path) != OK:
		failures += 1

func _clear_transient_overlays(game: Node) -> void:
	var hud: Node = game.get("hud") as Node
	if hud == null:
		return
	for field_name in ["toast_label", "status_label", "hint_label"]:
		var overlay: CanvasItem = hud.get(field_name) as CanvasItem
		if overlay != null:
			overlay.visible = false

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _settle_player(game: Node, requested_position: Vector3) -> void:
	var safe_position := requested_position
	var spatial := game.get("spatial_service") as Node
	if spatial != null and spatial.has_method("nearest_safe"):
		var bank: int = int(spatial.bank_for(requested_position)) if spatial.has_method("bank_for") else 0
		safe_position = spatial.nearest_safe(requested_position, bank)
	game.player.global_position = safe_position + Vector3.UP * 0.24
	game.player.velocity = Vector3.ZERO
	if "floor_snap_length" in game.player:
		game.player.floor_snap_length = 0.65
	for _index in range(24):
		await physics_frame
		await process_frame
		if game.player.is_on_floor():
			break
	game.player.velocity = Vector3.ZERO
