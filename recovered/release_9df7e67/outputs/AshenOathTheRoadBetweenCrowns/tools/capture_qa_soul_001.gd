extends SceneTree

const OUTPUT_DIR := "res://Development_Gallery/screenshots"
const REPORT_PATH := "res://.release-gate/qa_soul_001_runtime.json"
const VIEW_SIZE := Vector2i(1280, 720)

var failures: Array[String] = []
var timestamp := ""
var report := {
	"ticket": "QA-SOUL-001",
	"renderer": "",
	"viewport": [1280, 720],
	"timings_ms": {},
	"zones": {},
	"views": [],
}

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		_fail("QA-SOUL-001 capture requires a graphical Compatibility renderer")
		_finish()
		return
	DisplayServer.window_set_size(VIEW_SIZE)
	root.size = VIEW_SIZE
	timestamp = Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.release-gate"))
	report.renderer = RenderingServer.get_video_adapter_name()
	var started := Time.get_ticks_usec()
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		_fail("main scene is unavailable")
		_finish()
		return
	var game := packed.instantiate()
	root.add_child(game)
	await _frames(10)
	report.timings_ms.scene_ready = _elapsed_ms(started)
	game.hud.show_main_menu()
	await _frames(12)
	await _capture("QA-SOUL-001_01_Main_Menu", Vector2i(1920, 1080))
	var new_game_started := Time.get_ticks_usec()
	game.call("_new_game")
	await _wait_ready(game, "greyfen")
	report.timings_ms.new_game = _elapsed_ms(new_game_started)
	await _sample_zone(game, "greyfen", 1800)
	await _world_view(game, "QA-SOUL-001_04_Greyfen", Vector3(0, 0.95, 7.0), Vector3(0, 1.0, 1.5))
	await _world_view(game, "QA-SOUL-001_05_River", Vector3(-0.2, 0.95, 3.0), Vector3(0, 0.3, 4.5))
	await _actor_view(game, "QA-SOUL-001_02_Kael", game.player)
	var anwen := _find_named(game.zone_root, "sister_anwen") as Node3D
	if anwen == null:
		_fail("Sister Anwen is missing from Greyfen")
	else:
		await _actor_view(game, "QA-SOUL-001_03_Anwen", anwen)
	await _transition(game, "wychwood", Vector3(0, 1, 8))
	await _sample_zone(game, "wychwood", 1800)
	await _world_view(game, "QA-SOUL-001_06_Wychwood", Vector3(0, 0.95, 8), Vector3(0, 1.0, 2.5))
	await _combat_view(game)
	await _transition(game, "vargan_approach", Vector3(0, 1, 10))
	await _world_view(game, "QA-SOUL-001_08_Castle", Vector3(0, 0.95, 10), Vector3(0, 1.4, -2.0))
	await _transition(game, "hart_glade", Vector3(0, 1, 7))
	await _world_view(game, "QA-SOUL-001_09_Hart", Vector3(0, 0.95, 7), Vector3(0, 1.2, -2.0))
	report.static_memory_bytes = int(Performance.get_monitor(Performance.MEMORY_STATIC))
	report.node_count = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	report.material_count = _count_materials(game)
	report.generated_at_utc = Time.get_datetime_string_from_system(true)
	report.status = "pass" if failures.is_empty() else "fail"
	var file := FileAccess.open(ProjectSettings.globalize_path(REPORT_PATH), FileAccess.WRITE)
	if file == null:
		_fail("could not write QA-SOUL-001 runtime report")
	else:
		file.store_string(JSON.stringify(report, "\t"))
	if game.has_method("prepare_resource_shutdown"):
		game.prepare_resource_shutdown()
	await _frames(12)
	if game.is_inside_tree():
		root.remove_child(game)
	game.free()
	RenderingServer.force_sync()
	await _frames(12)
	_finish()

func _transition(game: Node, zone_id: String, arrival: Vector3) -> void:
	var started := Time.get_ticks_usec()
	game.call("_load_zone", zone_id, arrival)
	await _wait_ready(game, zone_id)
	report.timings_ms["transition_%s" % zone_id] = _elapsed_ms(started)

func _sample_zone(game: Node, zone_id: String, duration_ms: int) -> void:
	var frame_times: Array[float] = []
	var started := Time.get_ticks_msec()
	var previous := Time.get_ticks_usec()
	while Time.get_ticks_msec() - started < duration_ms:
		await process_frame
		var now := Time.get_ticks_usec()
		var frame_ms := float(now - previous) / 1000.0
		previous = now
		if frame_ms > 0.0 and frame_ms < 250.0:
			frame_times.append(frame_ms)
	var average_ms := 0.0
	for frame_ms in frame_times:
		average_ms += frame_ms
	average_ms /= maxf(float(frame_times.size()), 1.0)
	var sorted := frame_times.duplicate()
	sorted.sort()
	var slow_count := maxi(1, ceili(float(sorted.size()) * 0.01))
	var slow_ms := 0.0
	for index in range(sorted.size() - slow_count, sorted.size()):
		slow_ms += float(sorted[index])
	slow_ms /= float(slow_count)
	report.zones[zone_id] = {
		"average_fps": 1000.0 / maxf(average_ms, 0.001),
		"one_percent_low_fps": 1000.0 / maxf(slow_ms, 0.001),
		"frames": frame_times.size(),
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
	}

func _world_view(game: Node, id: String, player_position: Vector3, focus: Vector3) -> void:
	game.player.global_position = player_position
	game.player.velocity = Vector3.ZERO
	await _set_camera(game, player_position + Vector3(3.8, 2.5, 4.8), focus)
	await _capture(id)

func _actor_view(game: Node, id: String, actor: Node3D) -> void:
	if actor == null:
		_fail("%s actor is missing" % id)
		return
	var face_side := actor.global_transform.basis.z.normalized()
	var camera_position := actor.global_position + face_side * 3.0 + actor.global_transform.basis.x.normalized() * 0.55 + Vector3.UP * 1.34
	var focus := actor.global_position + Vector3.UP * 1.08
	var previous_fov: float = game.camera_rig.camera.fov
	game.camera_rig.camera.fov = 35.0
	game.hud.visible = false
	await _set_camera(game, camera_position, focus)
	await _capture(id)
	game.hud.visible = true
	game.camera_rig.camera.fov = previous_fov

func _combat_view(game: Node) -> void:
	if game.active_enemies.is_empty():
		_fail("Wychwood combat baseline has no enemy")
		return
	game.player.global_position = Vector3(0, 0.95, -2.0)
	var enemy: Node3D = game.active_enemies[0]
	enemy.global_position = Vector3(-1.4, 0.8, -5.0)
	if enemy.has_method("set_encounter_active"):
		enemy.set_encounter_active(true)
	await _set_camera(game, Vector3(3.8, 2.55, 3.2), Vector3(0, 1.0, -3.5))
	await _capture("QA-SOUL-001_07_Combat")

func _set_camera(game: Node, camera_position: Vector3, focus: Vector3) -> void:
	if game.camera_rig == null or game.camera_rig.camera == null:
		_fail("active camera rig is missing")
		return
	game.camera_rig.set_process(false)
	game.camera_rig.camera.look_at_from_position(camera_position, focus, Vector3.UP)
	await _frames(16)
	await RenderingServer.frame_post_draw

func _capture(id: String, expected_size: Vector2i = VIEW_SIZE) -> void:
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.get_size() != expected_size:
		_fail("%s did not produce the expected %s frame; got %s" % [id, str(expected_size), str(image.get_size() if image != null else Vector2i.ZERO)])
		return
	var sample := image.duplicate()
	sample.resize(64, 36, Image.INTERPOLATE_NEAREST)
	var total := 0.0
	var total_sq := 0.0
	var minimum := 1.0
	var maximum := 0.0
	for y in range(sample.get_height()):
		for x in range(sample.get_width()):
			var pixel: Color = sample.get_pixel(x, y)
			var luminance: float = pixel.r * 0.2126 + pixel.g * 0.7152 + pixel.b * 0.0722
			total += luminance
			total_sq += luminance * luminance
			minimum = minf(minimum, luminance)
			maximum = maxf(maximum, luminance)
	var count := float(sample.get_width() * sample.get_height())
	var mean := total / count
	var variance := maxf(total_sq / count - mean * mean, 0.0)
	if maximum - minimum < 0.08 or variance < 0.0006:
		_fail("%s is blank or visually flat" % id)
		return
	var relative := "%s/%s_%s.png" % [OUTPUT_DIR, id, timestamp]
	var absolute := ProjectSettings.globalize_path(relative)
	if image.save_png(absolute) != OK:
		_fail("%s could not be saved" % id)
		return
	report.views.append({"id": id, "path": relative.trim_prefix("res://"), "mean_luminance": mean, "variance": variance})
	print("CAPTURED %s" % absolute)

func _wait_ready(game: Node, zone_id: String) -> void:
	for _index in range(300):
		await process_frame
		if str(game.current_zone_id) == zone_id and game.zone_root != null and not bool(game.zone_transition_pending) and not bool(game.zone_load_request_pending):
			return
	_fail("timed out waiting for %s" % zone_id)

func _find_named(node: Node, target: String) -> Node:
	if node == null:
		return null
	if node.name == target:
		return node
	for child in node.get_children():
		var found := _find_named(child, target)
		if found != null:
			return found
	return null

func _count_materials(node: Node) -> int:
	var material_ids := {}
	for mesh_instance in node.find_children("*", "MeshInstance3D", true, false):
		if mesh_instance.material_override != null:
			material_ids[mesh_instance.material_override.get_instance_id()] = true
		if mesh_instance.mesh == null:
			continue
		for surface in range(mesh_instance.mesh.get_surface_count()):
			var material: Material = mesh_instance.get_active_material(surface)
			if material != null:
				material_ids[material.get_instance_id()] = true
	return material_ids.size()

func _elapsed_ms(start_usec: int) -> float:
	return float(Time.get_ticks_usec() - start_usec) / 1000.0

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _fail(message: String) -> void:
	failures.append(message)
	push_error(message)

func _finish() -> void:
	if failures.is_empty():
		print("QA-SOUL-001 CAPTURE: PASS")
		quit(0)
	else:
		print("QA-SOUL-001 CAPTURE: FAIL (%d)" % failures.size())
		quit(1)
