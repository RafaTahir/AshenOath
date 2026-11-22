extends SceneTree

func _initialize() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.settings.set_quality_preset("balanced")
	game._new_game()
	var deadline := Time.get_ticks_msec() + 45000
	while Time.get_ticks_msec() < deadline and (not game.game_started or game.zone_transition_pending or game.zone_root == null or not bool(game.zone_root.get_meta("opening_detail_complete", false))):
		await process_frame
	if not game.game_started or game.zone_transition_pending or game.zone_root == null or not bool(game.zone_root.get_meta("opening_detail_complete", false)):
		push_error("Actor ownership inspection did not reach complete detail")
		await _close(game)
		quit(1)
		return
	for id in ["speak_anwen", "bram", "sella", "oren", "fight_ghoulkin", "return_village"]:
		game.quests.complete_objective("main_road_of_crows", id)
	game.quests.start_quest("main_bell_beneath_greyfen")
	game.quests.complete_objective("main_bell_beneath_greyfen", "meet_anwen_gate")
	game.camera_rig.set_process(false)
	game.camera_rig.camera.look_at_from_position(Vector3(7.8, 3, 13.2), Vector3(14, 1, 8.2), Vector3.UP)
	for _index in 36:
		await process_frame
	var view: Camera3D = root.get_camera_3d()
	var actor: Node3D = game.zone_root.find_child("widow_elna", true, false)
	var rig: Skeleton3D = actor.find_child("Skeleton3D", true, false)
	print("CEMETERY CAMERA PROJECTION pos=", view.global_position, " fov=", view.fov, " root_pixel=", view.unproject_position(actor.global_position))
	for name in ["foot_l", "foot_r"]:
		var point := rig.global_transform * rig.get_bone_global_pose(rig.find_bone(name)).origin
		print("CEMETERY FOOT PROJECTION name=", name, " world=", point, " pixel=", view.unproject_position(point))
	if DisplayServer.get_name().to_lower() != "headless":
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("D:/Temp/AshenOath/cemetery_actor_owner_20260927.png")
		var widow: Node3D = game.zone_root.find_child("widow_elna", true, false)
		widow.visible = false
		for _index in 12:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("D:/Temp/AshenOath/cemetery_actor_hidden_20260927.png")
		widow.visible = true
		for mesh in widow.find_children("*", "MeshInstance3D", true, false):
			mesh.lod_bias = 1000.0
		for _index in 12:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("D:/Temp/AshenOath/cemetery_actor_full_lod_20260927.png")
		for mesh in widow.find_children("*", "MeshInstance3D", true, false):
			if mesh.skin != null:
				var source: ArrayMesh = mesh.mesh
				var unpacked := ArrayMesh.new()
				for surface in source.get_surface_count():
					var arrays := source.surface_get_arrays(surface)
					var flags := source.surface_get_format(surface) & ~Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES
					unpacked.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays, [], {}, flags)
					unpacked.surface_set_material(surface, source.surface_get_material(surface))
					print("CEMETERY SKIN FORMAT original=", source.surface_get_format(surface), " unpacked=", unpacked.surface_get_format(surface), " compressed=", bool(source.surface_get_format(surface) & Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES))
				mesh.mesh = unpacked
		widow.visible = true
		for _index in 12:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("D:/Temp/AshenOath/cemetery_actor_uncompressed_20260927.png")
	await _close(game)
	quit(0)

func _deformed_bounds(mesh: MeshInstance3D, skeleton: Skeleton3D) -> AABB:
	if mesh.skin == null or skeleton == null:
		return AABB()
	var result := AABB()
	var first := true
	for surface in mesh.mesh.get_surface_count():
		var arrays := mesh.mesh.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var stride := joints.size() / points.size()
		for point in points.size():
			var posed := Vector3.ZERO
			for channel in stride:
				var slot: int = point * stride + channel
				if weights[slot] <= 0:
					continue
				var bind: int = joints[slot]
				var name := mesh.skin.get_bind_name(bind)
				var bone := skeleton.find_bone(name) if not name.is_empty() else mesh.skin.get_bind_bone(bind)
				if bone < 0:
					continue
				posed += (skeleton.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(bind) * points[point]) * weights[slot]
			posed = skeleton.global_transform * posed
			if first:
				result = AABB(posed, Vector3.ZERO)
				first = false
			else:
				result = result.expand(posed)
	return result

func _close(game: Node) -> void:
	game.prepare_resource_shutdown()
	for _index in 24:
		await process_frame
	game.finalize_resource_shutdown()
	for _index in 12:
		await process_frame
	game.queue_free()
	for _index in 8:
		await process_frame
	RenderingServer.force_sync()
