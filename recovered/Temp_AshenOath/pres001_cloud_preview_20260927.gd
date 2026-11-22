extends SceneTree

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1280,720))
	DisplayServer.window_move_to_foreground()
	var camera := Camera3D.new()
	camera.fov = 75.0
	root.add_child(camera)
	camera.look_at_from_position(Vector3(0,2.2,10.2),Vector3(0,0.35,4.5),Vector3.UP)
	var director: Node = load("res://scripts/visual_director.gd").new()
	root.add_child(director)
	await process_frame
	for view in [["day",720.0],["night",60.0]]:
		director.force_time_update = true
		director.set_time(view[1],view[0])
		for _i in range(20):
			await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		image.save_png("D:/Temp/AshenOath/pres001_cloud_preview_" + view[0] + "_20260927.png")
	director.clear_runtime_caches()
	director.free()
	camera.free()
	for _i in range(8):
		await process_frame
	RenderingServer.force_sync()
	print("PRES-001 CLOUD PREVIEW: PASS (render only, not approval)")
	quit()
