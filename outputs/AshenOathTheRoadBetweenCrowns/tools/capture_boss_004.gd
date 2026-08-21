extends SceneTree

const OUTPUT_DIR := "res://Development_Gallery/screenshots"
var failures := 0
var timestamp := ""

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("BOSS-004 capture requires a graphical renderer")
		quit(1)
		return
	timestamp = Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await _frames(2)
	game.settings.set_quality_preset("balanced")
	game.call("_new_game")
	await _frames(45)
	var quest_id := "main_names_they_burned"
	if not game.quests.is_active(quest_id):
		game.quests.unlocked[quest_id] = true
		game.quests.start_quest(quest_id)
	for objective_id in ["fragment_anwen", "fragment_rook", "fragment_tor", "fragment_mira", "reconstruct_register"]:
		game.quests.complete_objective(quest_id, objective_id)
	game.story_state.set_flag("rootbound_colossus_spawned", false)
	game.call("_load_zone", "deep_wood", Vector3(0, 0, 12))
	await _frames(14)
	var boss = _find_boss(game, "rootbound_colossus")
	if boss == null:
		failures += 1
		push_error("Rootbound Colossus was not available for capture")
	else:
		boss.set_physics_process(false)
		await _capture(game, boss, "BOSS-004_01_Rootbound_Buried", Vector3(0, 1.0, -7.0), 0.0)
		boss.apply_damage(boss.health_component.max_health * 0.40, "capture")
		await _frames(16)
		boss.look_at(game.player.global_position + Vector3.UP * 0.9, Vector3.UP)
		await _capture(game, boss, "BOSS-004_02_Rootbound_Uprooted", Vector3(0, 1.0, -7.0), 0.0)
		boss.apply_damage(boss.health_component.max_health * 0.30, "capture")
		await _frames(16)
		boss.look_at(game.player.global_position + Vector3.UP * 0.9, Vector3.UP)
		await _capture(game, boss, "BOSS-004_03_Rootbound_ExposedHeart", Vector3(0, 1.0, -7.0), 0.0)
	print("BOSS-004 SCREENSHOTS: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	if game.has_method("prepare_resource_shutdown"):
		game.prepare_resource_shutdown()
		await _frames(int(game.ZONE_RETIRE_FRAMES) + 4)
	game.queue_free()
	await _frames(8)
	quit(0 if failures == 0 else 1)

func _find_boss(game: Node, id: String) -> Node:
	for enemy in game.active_enemies:
		if is_instance_valid(enemy) and str(enemy.get("enemy_id")) == id and not bool(enemy.get("dead")):
			return enemy
	return null

func _capture(game: Node, boss: Node, stem: String, position: Vector3, yaw: float) -> void:
	game.player.global_position = position
	game.player.velocity = Vector3.ZERO
	boss.look_at(game.player.global_position + Vector3.UP * 0.9, Vector3.UP)
	game.camera_rig.yaw = yaw
	game.camera_rig.pitch = -0.14
	game.hud.set_guidance_hint("")
	game.set_process(false)
	game.active_interactable = null
	game.hud.set_prompt("")
	game.hud.prompt_label.visible = false
	game.hud.hint_label.visible = false
	await _frames(34)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null or image.get_size() != Vector2i(1280, 720):
		failures += 1
		push_error("Invalid BOSS-004 frame: %s" % stem)
		return
	var sample := image.duplicate()
	sample.resize(64, 36, Image.INTERPOLATE_NEAREST)
	var minimum := 1.0
	var maximum := 0.0
	for y in range(sample.get_height()):
		for x in range(sample.get_width()):
			var pixel: Color = sample.get_pixel(x, y)
			var luminance := pixel.r * 0.2126 + pixel.g * 0.7152 + pixel.b * 0.0722
			minimum = minf(minimum, luminance)
			maximum = maxf(maximum, luminance)
	if maximum - minimum < 0.08:
		failures += 1
		push_error("Blank BOSS-004 frame: %s" % stem)
		return
	var path := "%s/%s_%s.png" % [OUTPUT_DIR, stem, timestamp]
	image.save_png(ProjectSettings.globalize_path(path))
	print("CAPTURED %s" % path)

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame
