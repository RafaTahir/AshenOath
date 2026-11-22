extends SceneTree

const OUT := "D:/Temp/AshenOath/kael-visible-20261019"
var game: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	var deadline := Time.get_ticks_msec() + 180000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if game.get("hud") != null and bool(game.hud.get("new_game_ready")):
			break
	var report := {"phase": "before_new_game", "userdata": OS.get_user_data_dir(), "before": _snapshot()}
	if game.get("hud") != null:
		game.hud.new_game_requested.emit()
	deadline = Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if bool(game.get("game_started")) and game.get("player") != null and bool(game.player.get("can_control")):
			break
	for frame in range(30):
		await process_frame
	await RenderingServer.frame_post_draw
	report["after"] = _snapshot()
	root.get_texture().get_image().save_png(OUT + "/native-gameplay.png")
	if game.get("player") != null and game.get("camera_rig") != null:
		game.hud.visible = false
		game.camera_rig.distance = 3.2
		game.camera_rig.yaw = PI
		game.camera_rig.pitch = -0.08
		game.camera_rig.prepare_view()
		for frame in range(30):
			await process_frame
		await RenderingServer.frame_post_draw
		report["close"] = _snapshot()
		root.get_texture().get_image().save_png(OUT + "/native-close.png")
	var file := FileAccess.open(OUT + "/diagnostic.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("KAEL_DIAGNOSTIC " + JSON.stringify(report))
	game.prepare_resource_shutdown()
	for frame in range(20):
		await process_frame
	game.finalize_resource_shutdown()
	game.queue_free()
	for frame in range(12):
		await process_frame
	quit(0)

func _snapshot() -> Dictionary:
	var state := {"started": bool(game.get("game_started")), "paused": paused, "disable_3d": root.disable_3d, "player": {}, "meshes": []}
	var player = game.get("player")
	if player == null:
		return state
	state.player = {"visible": player.visible, "visible_in_tree": player.is_visible_in_tree(), "position": str(player.global_position), "scale": str(player.global_basis.get_scale()), "body_failure": player.visual_root.get_meta("character_visual_failure", false), "close_view": player.get("_camera_close_view")}
	var rig = game.get("camera_rig")
	if rig != null:
		state["camera"] = {"distance": rig.distance, "first_person": rig.is_first_person(), "position": str(rig.camera.global_position), "yaw": rig.yaw, "cull_mask": rig.camera.cull_mask}
	for node in player.find_children("*", "MeshInstance3D", true, false):
		var row := {"path": str(player.get_path_to(node)), "mesh_present": node.mesh != null, "visible": node.visible, "visible_in_tree": node.is_visible_in_tree(), "shadow": node.cast_shadow, "transparency": node.transparency, "layers": node.layers, "scale": str(node.global_basis.get_scale()), "position": str(node.global_position), "skinned": node.skin != null, "materials": []}
		if node.mesh != null:
			row["aabb"] = str(node.get_aabb())
			row["world_aabb"] = str(node.global_transform * node.get_aabb())
			row["frustum"] = rig.camera.is_position_in_frustum(node.global_transform * node.get_aabb().get_center()) if rig != null else false
			for index in range(node.mesh.get_surface_count()):
				var mat: Material = node.get_active_material(index)
				var info := {"class": mat.get_class() if mat != null else "null", "name": mat.resource_name if mat != null else "", "whole_override": node.material_override != null}
				if mat is BaseMaterial3D:
					info["albedo"] = str(mat.albedo_color)
					info["texture"] = mat.albedo_texture.resource_path if mat.albedo_texture != null else ""
					info["transparency"] = mat.transparency
					info["cull"] = mat.cull_mode
				row.materials.append(info)
		state.meshes.append(row)
	return state
