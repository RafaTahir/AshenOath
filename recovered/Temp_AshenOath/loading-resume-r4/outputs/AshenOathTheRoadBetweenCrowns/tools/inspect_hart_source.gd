extends SceneTree

const SOURCE := "D:/Temp/AshenOath/asset-source/quaternius-ultimate-animals/Stag.gltf"
const OUTPUT := "D:/Temp/AshenOath/asset-source/quaternius-ultimate-animals/"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var args := OS.get_cmdline_user_args()
	var source := args[0] if not args.is_empty() else SOURCE
	var error := document.append_from_file(source, state)
	if error != OK:
		push_error("Stag import failed: %s" % error)
		quit(1)
		return
	var actor := document.generate_scene(state)
	if actor == null:
		push_error("Stag scene is missing")
		quit(1)
		return
	var stage := Node3D.new()
	root.add_child(stage)
	stage.add_child(actor)
	var bounds := AABB()
	var first := true
	var surfaces := 0
	var triangles := 0
	for node in actor.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
		for surface in mesh.mesh.get_surface_count():
			surfaces += 1
			var indices: int = mesh.mesh.surface_get_array_index_len(surface)
			triangles += (indices if indices > 0 else mesh.mesh.surface_get_array_len(surface)) / 3
	var report := {"bounds_position": str(bounds.position), "bounds_size": str(bounds.size), "surfaces": surfaces, "triangles": triangles, "skeletons": [], "clips": []}
	for skeleton in actor.find_children("*", "Skeleton3D", true, false):
		report.skeletons.append(skeleton.get_bone_count())
		var head: int = skeleton.find_bone("Head")
		var body: int = skeleton.find_bone("Body")
		if head >= 0 and body >= 0:
			report["head_body_delta"] = str(skeleton.global_transform.basis * (skeleton.get_bone_global_rest(head).origin - skeleton.get_bone_global_rest(body).origin))
	for animation in actor.find_children("*", "AnimationPlayer", true, false):
		for clip in animation.get_animation_list():
			report.clips.append(str(clip))
	var stem := source.get_file().get_basename()
	var result := FileAccess.open(OUTPUT + stem + "_inspection.json", FileAccess.WRITE)
	result.store_string(JSON.stringify(report, "  "))
	result.close()
	print("HART SOURCE: ", JSON.stringify(report))
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1280, 720)
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.background_color = Color(0.09, 0.12, 0.12)
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color = Color.WHITE
		environment.environment.ambient_light_energy = 0.65
		stage.add_child(environment)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-40, -30, 0)
		stage.add_child(light)
		var camera := Camera3D.new()
		stage.add_child(camera)
		var center := bounds.get_center()
		camera.position = center + Vector3(1.0, 0.4, 1.0).normalized() * bounds.size.length() * 1.4
		camera.look_at(center)
		camera.current = true
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUTPUT + stem + "_source.png")
	stage.queue_free()
	await process_frame
	await process_frame
	quit(0)
