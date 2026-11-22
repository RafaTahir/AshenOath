extends SceneTree

const OUTPUT_DIR := "res://Development_Gallery/screenshots"
var failures := 0

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("LIFE-001 capture requires a graphical renderer")
		quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
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
	var detail_deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < detail_deadline:
		if game.game_started and game.zone_root != null and bool(game.zone_root.get_meta("opening_detail_complete", false)):
			break
		await process_frame
	if not game.game_started or game.zone_root == null or not bool(game.zone_root.get_meta("opening_detail_complete", false)):
		push_error("Greyfen life did not finish hydrating before capture")
		quit(1)
		return
	var life: Node = game.zone_root.find_child("GreyfenLifeController", true, false)
	if life == null or int(life.call("actor_count")) < 7:
		push_error("Greyfen life population is incomplete before capture")
		quit(1)
		return
	await _frames(14)
	await _capture(game, "LIFE_001_01_Greyfen_Spawn_Life", Vector3(-2.5, 1, 8.3), 0.25)
	await _capture_actor(game, "LIFE_001_02_Shrine_Pilgrim", "shrine_pilgrim")
	await _capture_actor(game, "LIFE_001_03_Forge_Helper", "forge_helper")
	print("LIFE-001 SCREENSHOTS: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _capture(game, stem: String, position: Vector3, yaw: float) -> void:
	if game.spatial_service == null or not game.spatial_service.is_walkable_position(position, 0.55, game.spatial_service.bank_for(position)):
		failures += 1
		push_error("Unsafe LIFE-001 camera anchor: %s" % stem)
		return
	game.player.global_position = position
	game.player.velocity = Vector3.ZERO
	game.camera_rig.yaw = yaw
	game.camera_rig.pitch = -0.16
	await _frames(18)
	if game.player.global_position.distance_to(position) > 1.5:
		failures += 1
		push_error("LIFE-001 camera anchor triggered player recovery: %s" % stem)
		return
	_save_frame(stem)

func _capture_actor(game, stem: String, routine_id: String) -> void:
	var life: Variant = game.zone_root.find_child("GreyfenLifeController", true, false)
	var actor: Node3D = null
	if life != null:
		for entry in life.actors:
			if str(entry.id) == routine_id:
				actor = entry.node
				break
	var camera: Camera3D = game.camera_rig.camera
	if actor == null or camera == null:
		failures += 1
		push_error("LIFE-001 actor or camera missing: %s actor=%s camera=%s" % [routine_id, actor != null, camera != null])
		return
	var rejected: Array[String] = []
	for offset in [
		Vector3(0, 0, 3.3), Vector3(-3.3, 0, 1.5), Vector3(3.3, 0, 1.5), Vector3(0, 0, -3.3),
		Vector3(-4.2, 0, -2.8), Vector3(4.2, 0, -2.8), Vector3(-4.2, 0, 3.4), Vector3(4.2, 0, 3.4),
	]:
		var position: Vector3 = actor.global_position + offset
		position.y = 1.0
		if not game.spatial_service.is_walkable_position(position, 0.55, game.spatial_service.bank_for(position)):
			rejected.append("%s:unsafe" % offset)
			continue
		game.player.global_position = position
		game.player.velocity = Vector3.ZERO
		var direction: Vector3 = actor.global_position - position
		game.camera_rig.yaw = atan2(-direction.x, -direction.z)
		game.camera_rig.pitch = -0.16
		await _frames(18)
		if game.player.global_position.distance_to(position) > 1.5:
			rejected.append("%s:recovery" % offset)
			continue
		if _camera_inside_house_visual(camera):
			rejected.append("%s:house" % offset)
			continue
		var target := actor.global_position + Vector3.UP * 1.0
		if camera.is_position_behind(target):
			rejected.append("%s:behind" % offset)
			continue
		var screen := camera.unproject_position(target)
		if screen.x < 128.0 or screen.x > 1152.0 or screen.y < 72.0 or screen.y > 648.0:
			rejected.append("%s:offscreen %s" % [offset, screen])
			continue
		var ray := PhysicsRayQueryParameters3D.create(camera.global_position, target)
		ray.exclude = [game.player.get_rid()]
		var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and camera.global_position.distance_to(hit.position) + 0.6 < camera.global_position.distance_to(target):
			rejected.append("%s:blocked %s" % [offset, hit.get("collider")])
			continue
		if not actor.visible:
			rejected.append("%s:hidden" % offset)
			continue
		_save_frame(stem)
		return
	failures += 1
	push_error("No clear LIFE-001 camera anchor for %s at %s: %s" % [routine_id, actor.global_position, "; ".join(rejected)])

func _camera_inside_house_visual(camera: Camera3D) -> bool:
	for house in get_nodes_in_group("greyfen_house"):
		var visual := (house as Node).find_child("AuthoredHouse", true, false) as MeshInstance3D
		if visual == null or visual.mesh == null:
			continue
		if visual.mesh.get_aabb().has_point(visual.to_local(camera.global_position)):
			return true
	return false

func _save_frame(stem: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.get_size() != Vector2i(1280, 720) or not _is_visible(image):
		failures += 1
		push_error("Invalid LIFE-001 frame: %s" % stem)
		return
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var file_name := "%s_%s.png" % [stem, stamp]
	image.save_png(ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name]))
	print("CAPTURED %s" % file_name)

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
