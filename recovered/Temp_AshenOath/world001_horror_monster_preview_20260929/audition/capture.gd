extends SceneTree

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("Graphical renderer required")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var args := OS.get_cmdline_user_args()
	var source_path := str(args[0]) if args.size() > 0 else "res://Idle.fbx"
	var output_path := str(args[1]) if args.size() > 1 else "res://horror_monster_idle_audition.png"
	var packed := load(source_path) as PackedScene
	if packed == null:
		push_error("Candidate source is unavailable: " + source_path)
		quit(1)
		return
	var world := Node3D.new()
	root.add_child(world)
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("222622")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b5b7aa")
	env.ambient_light_energy = 0.8
	env_node.environment = env
	world.add_child(env_node)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12.0, 12.0)
	floor.mesh = plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("4c493e")
	floor.material_override = floor_material
	world.add_child(floor)
	var actor := packed.instantiate() as Node3D
	world.add_child(actor)
	await process_frame
	var meshes := actor.find_children("*", "MeshInstance3D", true, false)
	var skeletons := actor.find_children("*", "Skeleton3D", true, false)
	var players := actor.find_children("*", "AnimationPlayer", true, false)
	print("AUDITION_STRUCTURE meshes=%d skeletons=%d players=%d" % [meshes.size(), skeletons.size(), players.size()])
	for skeleton in skeletons:
		var skel := skeleton as Skeleton3D
		print("AUDITION_BONES %d" % skel.get_bone_count())
		for bone in skel.get_bone_count():
			if skel.get_bone_name(bone).to_lower().contains("spine") or skel.get_bone_name(bone).to_lower().contains("arm") or skel.get_bone_name(bone).to_lower().contains("head"):
				print("AUDITION_BONE_NAME %d %s" % [bone, skel.get_bone_name(bone)])
	for player in players:
		var animation_player := player as AnimationPlayer
		print("AUDITION_CLIPS %s" % ",".join(animation_player.get_animation_list()))
		if animation_player.get_animation_list().size() > 0:
			animation_player.play(animation_player.get_animation_list()[0])
	var bounds := AABB()
	var found := false
	for mesh in meshes:
		var instance := mesh as MeshInstance3D
		if instance.mesh == null:
			continue
		var box := instance.global_transform * instance.mesh.get_aabb()
		bounds = bounds.merge(box) if found else box
		found = true
		for surface in instance.mesh.get_surface_count():
			var material := instance.mesh.surface_get_material(surface)
			var has_albedo := material is BaseMaterial3D and (material as BaseMaterial3D).albedo_texture != null
			print("AUDITION_SURFACE %s vertices=%d material=%s albedo=%s" % [instance.name, instance.mesh.surface_get_array_len(surface), str(material != null), str(has_albedo)])
	if not found or bounds.size.y < 0.001:
		push_error("No usable mesh bounds: %s" % str(bounds))
		quit(1)
		return
	var factor := 2.0 / bounds.size.y
	actor.scale = Vector3.ONE * factor
	actor.position.y = -bounds.position.y * factor
	print("AUDITION_BOUNDS %s factor=%f" % [str(bounds), factor])
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.9, 6.0)
	camera.look_at_from_position(camera.position, Vector3(0.0, 1.0, 0.0), Vector3.UP)
	camera.fov = 45.0
	world.add_child(camera)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	key.light_energy = 1.3
	world.add_child(key)
	for _frame in 35:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.get_size() != Vector2i(1280, 720):
		push_error("Missing 1280x720 frame")
		quit(1)
		return
	image.save_png(output_path)
	print("AUDITION_CAPTURE " + output_path)
	quit(0)
