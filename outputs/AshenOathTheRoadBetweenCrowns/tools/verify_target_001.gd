extends SceneTree

const CharacterRoleSpec = preload("res://scripts/character_role_spec.gd")

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var camera := FileAccess.get_file_as_string("res://scripts/camera_controller.gd")
	var input := FileAccess.get_file_as_string("res://scripts/input_router.gd")
	for needle in [
		"_locked_combat_target", "_cycle_combat_target", "_target_is_visible",
		"_target_query_exclusions", "TARGET_OBSTRUCTION_GRACE",
		"_soft_frame_locked_target", "get_locked_combat_target", "clear_target_lock",
		"target_lock_changed"
	]:
		if not camera.contains(needle):
			failures.append("camera missing %s" % needle)
	for needle in [
		"target_lock", "JOY_BUTTON_RIGHT_STICK", "target_next", "target_previous",
		"JOY_AXIS_RIGHT_X"
	]:
		if not input.contains(needle):
			failures.append("input router missing %s" % needle)
	if not camera.contains("is_encounter_active"):
		failures.append("camera does not filter dormant encounter actors")
	if not input.contains("gamepad_action_label"):
		failures.append("input router does not expose controller target labels")
	await _verify_camera_clearance()
	await _verify_smoothed_encounter_fit()
	await _verify_actual_arena_rock()
	await _verify_mill_wall_visibility()
	if failures.is_empty():
		print("PASS TARGET-001: optional lock-on and controller target selection present")
		quit(0)
	else:
		for failure in failures:
			push_error("TARGET-001: %s" % failure)
		quit(1)

func _verify_camera_clearance() -> void:
	root.size = Vector2i(1280, 720)
	var controller := load("res://scripts/camera_controller.gd").new() as Node3D
	var player := CharacterBody3D.new()
	root.add_child(player)
	root.add_child(controller)
	controller.set_process(false)
	controller.target = player
	var canopy := StaticBody3D.new()
	canopy.collision_layer = 1 << 6
	canopy.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 6, 4)
	shape.shape = box
	canopy.add_child(shape)
	canopy.position = Vector3(13, 3, -11)
	root.add_child(canopy)
	await physics_frame
	await physics_frame
	var anchor := Vector3(7, 2.25, -11)
	var desired := Vector3(13, 3.4, -11)
	var resolved: Vector3 = controller._collide_camera(anchor, desired)
	if resolved.x >= 11.0:
		failures.append("Orbit still enters the recorded Rootbound crown volume")
	var physical_query := PhysicsRayQueryParameters3D.create(anchor, desired, 1)
	if not root.world_3d.direct_space_state.intersect_ray(physical_query).is_empty():
		failures.append("Camera-only clearance changes gameplay ray visibility")
	var overhead: Vector3 = controller._collide_camera(Vector3(13, 8, -11), Vector3(13, 3, -11))
	if overhead.y <= 6.0:
		failures.append("Upward camera-only crown surface was ignored as walkable floor")
	var boss := Node3D.new()
	boss.set_meta("camera_subject_height", 4.4)
	root.add_child(boss)
	var focal: Dictionary = controller._environment_focus(boss)
	if not is_equal_approx(focal.point.y, 2.2):
		failures.append("Tall-boss focus still assumes a human chest height")
	player.position = Vector3(7, 0, -11)
	boss.position = Vector3(4.5, -0.19, -11)
	boss.rotation.y = -PI * 0.5
	var body_bounds := CharacterRoleSpec.encounter_camera_bounds("rootbound_colossus_boss")
	boss.set_meta("camera_subject_bounds", body_bounds)
	var published_position: Vector3 = controller._resolve_encounter_orbit(anchor, desired, boss)
	var framing: Dictionary = controller._large_encounter_frame(published_position, boss)
	var view := Camera3D.new()
	controller.add_child(view)
	view.global_position = published_position
	view.look_at(framing.point)
	view.fov = framing.fov
	var points: Array[Vector3] = [player.global_position, player.global_position + Vector3.UP * 1.78]
	for index in range(8):
		points.append(boss.global_transform * body_bounds.get_endpoint(index))
	for point in points:
		var pixel: Vector2 = view.unproject_position(point)
		if view.is_position_behind(point) or pixel.y <= 0.0 or pixel.y >= root.size.y or pixel.x <= 0.0 or pixel.x >= root.size.x:
			failures.append("Collision-shortened tall-boss framing crops endpoint %s at %s in %s" % [point, pixel, root.size])
	player.position = Vector3.ZERO
	boss.position = Vector3(0, -0.19, -5)
	canopy.position = Vector3(0, 0.8, 1.5)
	box.size = Vector3(2.2, 1.6, 1.2)
	await physics_frame
	await physics_frame
	anchor = Vector3(0, 2.25, 0)
	desired = Vector3(0, 3.4, 6)
	if not controller._player_view_obstructed(desired):
		failures.append("Low arena cover fixture fails to reproduce cropped Kael legs")
	published_position = controller._resolve_encounter_orbit(anchor, desired, boss)
	if controller._player_view_obstructed(published_position):
		failures.append("Large encounter orbit still hides Kael behind camera-only arena cover")
	physical_query = PhysicsRayQueryParameters3D.create(desired, Vector3(0, 0.35, 0), 1)
	if not root.world_3d.direct_space_state.intersect_ray(physical_query).is_empty():
		failures.append("Low camera-only arena cover obstructs gameplay rays")
	boss.free()
	canopy.free()
	controller.free()
	player.free()

func _verify_smoothed_encounter_fit() -> void:
	var controller := load("res://scripts/camera_controller.gd").new() as Node3D
	var player := CharacterBody3D.new()
	var boss := Node3D.new()
	root.add_child(player)
	root.add_child(controller)
	root.add_child(boss)
	controller.set_process(false)
	controller.target = player
	player.position = Vector3(7.0, 0.000208, -11.0)
	boss.position = Vector3(1.248452, -0.188202, -10.58739)
	boss.rotation.y = atan2(player.position.x - boss.position.x, player.position.z - boss.position.z)
	boss.set_meta("camera_subject_height", 4.4)
	var bounds := CharacterRoleSpec.encounter_camera_bounds("rootbound_colossus_boss")
	boss.set_meta("camera_subject_bounds", bounds)
	var anchor := player.position + Vector3.UP * 2.25
	var shortened := Vector3(8.532537, 2.587185, -10.75792)
	var resolved := Vector3(11.71352, 3.398695, -13.88867)
	var published: Vector3 = controller._publish_encounter_position(anchor, shortened, resolved, boss)
	var framing: Dictionary = controller._large_encounter_frame(published, boss)
	if framing.required_fov > 90.0:
		failures.append("Recorded Rootbound smoothing requires %.2f degrees beyond the camera limit" % framing.required_fov)
	var view := Camera3D.new()
	controller.add_child(view)
	view.global_position = published
	view.look_at(framing.point)
	view.fov = framing.fov
	var body := AABB(Vector3(-0.32, 0, -0.32), Vector3(0.64, 1.78, 0.64))
	for index in range(8):
		for point in [player.global_position + body.get_endpoint(index), boss.global_transform * bounds.get_endpoint(index)]:
			var pixel: Vector2 = view.unproject_position(point)
			if view.is_position_behind(point) or pixel.y <= 0.0 or pixel.y >= root.size.y or pixel.x <= 0.0 or pixel.x >= root.size.x:
				failures.append("Recorded Rootbound smoothing crops body corner %s at %s" % [point, pixel])
	controller.free()
	player.free()
	boss.free()
	await process_frame

func _verify_actual_arena_rock() -> void:
	var game := load("res://scripts/game.gd").new() as Node3D
	game.add_child(game.zone_residency)
	game.current_zone_id = "old_mill"
	game.settings = load("res://scripts/settings_manager.gd").new()
	game.add_child(game.settings)
	game.asset_helper = load("res://scripts/asset_spawn_helper.gd").new()
	game.add_child(game.asset_helper)
	game.zone_root = Node3D.new()
	root.add_child(game.zone_root)
	var rock: Node3D = game._make_loose_role("forest_rock", Vector3(1.8, 0, -3), Vector3.ONE * 0.52, 16.2)
	var clearance := rock.find_child("RockCameraClearance", true, false) as StaticBody3D if rock != null else null
	if clearance == null:
		failures.append("Actual Ashwing rock mesh has no camera-only clearance")
	else:
		await physics_frame
		await physics_frame
		var shape := clearance.get_child(0) as CollisionShape3D
		var centre := shape.global_position
		var from_pos := centre - Vector3.FORWARD * 3.0
		var to_pos := centre + Vector3.FORWARD * 3.0
		var space := root.world_3d.direct_space_state
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(from_pos, to_pos, 1 << 6)).is_empty():
			failures.append("Actual rock camera shape does not cover its rendered centre")
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(from_pos, to_pos, 1)).is_empty():
			failures.append("Actual rock camera clearance changes gameplay collision")
		var player := CharacterBody3D.new()
		var boss := Node3D.new()
		var controller := load("res://scripts/camera_controller.gd").new() as Node3D
		game.zone_root.add_child(player)
		game.zone_root.add_child(boss)
		game.zone_root.add_child(controller)
		controller.set_process(false)
		controller.target = player
		player.position = Vector3(2.152236, 0.032741, -3.351147)
		boss.position = Vector3(3.927932, -0.117972, -4.493867)
		boss.rotation.y = atan2(player.position.x - boss.position.x, player.position.z - boss.position.z)
		boss.set_meta("camera_subject_height", 5.13)
		boss.set_meta("camera_subject_bounds", CharacterRoleSpec.encounter_camera_bounds("ashwing_boss"))
		await physics_frame
		await physics_frame
		var blocked := Vector3(-1.986913, 6.221745, -1.287972)
		if not controller._player_view_obstructed(blocked):
			failures.append("Actual mill rock does not reproduce the recorded leg occlusion")
		var body := AABB(Vector3(-0.32, 0.2, -0.32), Vector3(0.64, 1.5, 0.64))
		var shape_bounds := AABB(-shape.shape.size * 0.5, shape.shape.size)
		var body_inside := false
		for index in range(8):
			body_inside = body_inside or shape_bounds.has_point(shape.global_transform.affine_inverse() * (player.position + body.get_endpoint(index)))
		if not body_inside:
			failures.append("Old rock placement does not reproduce the actual lower-body intersection")
		rock.position = Vector3(10.4, 0, -6.8)
		rock.rotation_degrees.y = 10.4 * 9.0
		var arena_rocks: Array = load("res://scripts/zones/campaign_wilderness_section.gd").ASHWING_ARENA_ROCKS
		if arena_rocks.size() != 4 or not arena_rocks.has(rock.position) or arena_rocks.has(Vector3(1.8, 0, -3)):
			failures.append("Authored arena does not preserve four stones outside the blocked approach")
		await physics_frame
		await physics_frame
		var anchor := player.position + Vector3.UP * 2.25
		var resolved: Vector3 = controller._resolve_encounter_orbit(anchor, blocked, boss)
		if controller._player_view_obstructed(resolved):
			failures.append("Actual mill rock leaves every tested orbit obstructed")
	game.zone_residency._release_zone_render_resources(game.zone_root)
	game.zone_root.free()
	game.asset_helper.clear_runtime_caches()
	game.free()
	await process_frame

func _verify_mill_wall_visibility() -> void:
	var controller := load("res://scripts/camera_controller.gd").new() as Node3D
	var player := CharacterBody3D.new()
	var boss := Node3D.new()
	root.add_child(player)
	root.add_child(controller)
	root.add_child(boss)
	controller.set_process(false)
	controller.target = player
	player.position = Vector3(2.165042, 0.032753, -3.430887)
	boss.position = Vector3(4.163248, -0.11797, -4.485112)
	boss.rotation.y = atan2(player.position.x - boss.position.x, player.position.z - boss.position.z)
	boss.set_meta("camera_subject_height", 5.13)
	boss.set_meta("camera_subject_bounds", CharacterRoleSpec.encounter_camera_bounds("ashwing_boss"))
	var wall := StaticBody3D.new()
	wall.position = Vector3(-1.25, 1.45, -5.25)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.42, 2.45, 5.2)
	shape.shape = box
	wall.add_child(shape)
	root.add_child(wall)
	await physics_frame
	await physics_frame
	var blocked := Vector3(-3.638391, 3.425174, -2.369149)
	if not controller._player_view_obstructed(blocked):
		failures.append("Recorded Ashwing windup camera behind the mill wall was accepted")
	var anchor := player.position + Vector3.UP * 2.25
	var resolved: Vector3 = controller._resolve_encounter_orbit(anchor, blocked, boss)
	if controller._player_view_obstructed(resolved):
		failures.append("Mill-wall orbit did not select an unobstructed flank")
	var published: Vector3 = controller._publish_encounter_position(anchor, blocked, resolved, boss)
	if controller._player_view_obstructed(published) or not published.is_equal_approx(resolved):
		failures.append("Camera smoothing republishes the rejected mill-wall sightline")
	var clear := player.position + Vector3(8.0, 4.0, 7.0)
	if controller._large_encounter_frame(clear, boss).required_fov > 90.0:
		failures.append("Clear interpolation fixture exceeds the encounter FOV limit")
	var clear_publication: Vector3 = controller._publish_encounter_position(anchor, clear, resolved, boss)
	if not clear_publication.is_equal_approx(clear):
		failures.append("Unobstructed encounter camera no longer preserves smoothing")
	wall.free()
	boss.free()
	controller.free()
	player.free()
	await process_frame
