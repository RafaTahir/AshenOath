extends SceneTree

const OUTPUT_DIR := "res://Development_Gallery/screenshots"
var failures := 0

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("CIN-002 capture requires a graphical Compatibility renderer")
		quit(1)
		return
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await _frames(24)
	game.settings.set_quality_preset("balanced")
	game.call("_new_game")
	await _frames(34)
	var anwen := game.zone_root.find_child("sister_anwen", true, false) as Node3D if game.zone_root != null else null
	if anwen == null:
		failures += 1
	else:
		var staged := anwen.global_position - anwen.global_basis.z.normalized() * 2.0
		game.player.global_position = staged + Vector3.UP * 0.22
		game.player.velocity = Vector3.ZERO
		game.call("_stage_dialogue_moment", anwen)
		game.call("_handle_interaction", anwen)
		await _frames(8)
		await _capture(game, "CIN_002_01_AnwenGreeting")
		var hud: Node = game.hud
		var page_count := int(hud.dialogue_pages.size()) if hud != null else 0
		for page_index in [1, 2, 3]:
			if page_index >= page_count:
				continue
			hud.dialogue_page_index = page_index
			hud.call("_render_dialogue_page")
			await _frames(6)
			await _capture(game, "CIN_002_%02d_DialogueTurn" % (page_index + 1))
	game.free()
	await _frames(4)
	print("CIN-002 SCREENSHOTS: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

func _capture(_game: Node, stem: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null or image.is_empty() or image.get_width() != 1280 or image.get_height() != 720:
		failures += 1
		return
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	if image.save_png(ProjectSettings.globalize_path("%s/%s_%s.png" % [OUTPUT_DIR, stem, stamp])) != OK:
		failures += 1

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame
