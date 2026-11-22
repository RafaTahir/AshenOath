extends SceneTree

const OUTPUT_DIR := "res://Development_Gallery/screenshots"
var failures := 0
var timestamp := ""

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("BOSS-006 capture requires a graphical renderer")
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
	var quest_id := "main_last_witness"
	if not game.quests.is_active(quest_id):
		game.quests.unlocked[quest_id] = true
		game.quests.start_quest(quest_id)
	game.quests.complete_objective(quest_id, "reach_undercroft")
	game.story_state.set_flag("halvern_fate", "")
	game.story_state.set_flag("halvern_guard_broken", false)
	game.call("_load_zone", "undercroft", Vector3(0, 1, 12))
	var dressing_ready := await _wait_for_undercroft_dressing(game)
	var boss = _find_boss(game, "halvern_boss") if dressing_ready else null
	if boss == null:
		failures += 1
		push_error("Halvern was not available for capture")
	else:
		# Freeze the whole fixture, not just one physics callback: the runtime
		# visibility manager otherwise reactivates Halvern during camera settling.
		game.process_mode = Node.PROCESS_MODE_PAUSABLE
		paused = true
		var socket := boss.find_child("HalvernSwordSocket", true, false) as BoneAttachment3D
		var sword := boss.find_child("HalvernAuthoredSword", true, false) as Node3D
		if socket == null or sword == null or not socket.is_ancestor_of(sword) or socket.bone_name != "hand_r":
			failures += 1
			push_error("Halvern sword is not attached to the required hand bone")
		boss.set_physics_process(false)
		boss.global_position = _floor_position(game, boss, Vector3(0, 0, -5.5))
		await _capture(game, boss, "BOSS-006_01_Halvern_TheGate", Vector3(0, 1.0, -3.2), 0.0)
		game.player.global_position = Vector3(0, 1.0, -3.4)
		game.player.parry_window = game.player.get_parry_window_duration()
		boss.windup_time = 0.48
		boss.attack_trace_start = boss.global_position + Vector3(0, 0.9, 0)
		boss.attack_trace_end = game.player.global_position + Vector3(0, 0.9, 0)
		boss.call("_resolve_attack")
		await _frames(12)
		await _capture(game, boss, "BOSS-006_02_Halvern_ParryWindow", Vector3(0, 1.0, -3.2), 0.0)
		boss.apply_damage(boss.health_component.max_health * 0.55, "capture")
		await _frames(16)
		boss.look_at(game.player.global_position + Vector3.UP * 0.9, Vector3.UP)
		await _capture(game, boss, "BOSS-006_03_Halvern_TheRefusal", Vector3(0, 1.0, -3.2), 0.0)
	print("BOSS-006 SCREENSHOTS: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	if game.has_method("prepare_resource_shutdown"):
		paused = false
		game.process_mode = Node.PROCESS_MODE_ALWAYS
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
	paused = false
	game.player.global_position = _floor_position(game, boss, position)
	game.player.velocity = Vector3.ZERO
	boss.look_at(game.player.global_position + Vector3.UP * 0.9, Vector3.UP)
	game.camera_rig.yaw = yaw
	game.camera_rig.pitch = -0.14
	game.camera_rig._initialized = false
	game.camera_rig._process(1.0 / 60.0)
	paused = true
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
		push_error("Invalid BOSS-006 frame: %s" % stem)
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
		push_error("Blank BOSS-006 frame: %s" % stem)
		return
	var path := "%s/%s_%s.png" % [OUTPUT_DIR, stem, timestamp]
	image.save_png(ProjectSettings.globalize_path(path))
	print("CAPTURED %s" % path)

func _floor_position(game: Node, boss: Node, position: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(position.x, 4.0, position.z), Vector3(position.x, -3.0, position.z), 1)
	query.exclude = [game.player.get_rid(), boss.get_rid()]
	var hit: Dictionary = game.player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		failures += 1
		push_error("Halvern capture has no physical floor at %s" % position)
		return position
	return (hit.position as Vector3) + Vector3.UP * 0.03

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _wait_for_undercroft_dressing(game: Node) -> bool:
	var deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		if str(game.current_zone_id) == "undercroft" and game.zone_root != null and is_instance_valid(game.zone_root):
			var markers: Array[Node] = game.zone_root.find_children("DeferredVisualRole_*", "", true, false)
			if markers.is_empty() and not bool(game.zone_root.get_meta("deferred_visual_roles_pending", false)):
				return true
		await process_frame
	push_error("Undercroft visual dressing did not complete within 10 seconds; active=%s" % str(game.current_zone_id))
	return false
