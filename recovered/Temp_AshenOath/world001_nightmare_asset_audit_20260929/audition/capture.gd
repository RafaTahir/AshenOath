extends SceneTree

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("Graphical renderer required")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var scene := load("res://crawlmaster deluxe.fbx") as PackedScene
	if scene == null:
		push_error("FBX import failed")
		quit(1)
		return
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("24272a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c3c8bf")
	env.ambient_light_energy = 0.7
	environment.environment = env
	world.add_child(environment)
	var floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(12.0, 12.0)
	floor.mesh = floor_mesh
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("42413b")
	floor.material_override = floor_material
	world.add_child(floor)
	var actor := scene.instantiate() as Node3D
	world.add_child(actor)
	await process_frame
	var meshes := actor.find_children("*", "MeshInstance3D", true, false)
	var skeletons := actor.find_children("*", "Skeleton3D", true, false)
	var players := actor.find_children("*", "AnimationPlayer", true, false)
	print("AUDITION_STRUCTURE meshes=%d skeletons=%d players=%d" % [meshes.size(), skeletons.size(), players.size()])
	_print_tree(actor, "")
	for skeleton in skeletons:
		var skeleton_node := skeleton as Skeleton3D
		print("AUDITION_SKELETON bones=%d" % skeleton_node.get_bone_count())
		for bone in skeleton_node.get_bone_count():
			print("AUDITION_BONE %d %s" % [bone, skeleton_node.get_bone_name(bone)])
	for mesh in meshes:
		var instance := mesh as MeshInstance3D
		if instance.mesh == null:
			continue
		print("AUDITION_MESH %s surfaces=%d bounds=%s global=%s skin=%s" % [instance.name, instance.mesh.get_surface_count(), str(instance.mesh.get_aabb()), str(instance.global_transform), str(instance.skin != null)])
		for index in instance.mesh.get_surface_count():
			var material := instance.mesh.surface_get_material(index)
			print("AUDITION_MATERIAL %s %s vertices=%d" % [instance.name, str(material != null), instance.mesh.surface_get_array_len(index)])
	for player in players:
		var animation_player := player as AnimationPlayer
		print("AUDITION_CLIPS %s" % ",".join(animation_player.get_animation_list()))
	var bounds := AABB()
	var found := false
	for mesh in meshes:
		var instance := mesh as MeshInstance3D
		if instance.mesh == null:
			continue
		var box := instance.global_transform * instance.mesh.get_aabb()
		bounds = bounds.merge(box) if found else box
		found = true
	if not found or bounds.size.y < 0.00001:
		push_error("No usable body bounds: %s" % str(bounds))
		quit(1)
		return
	var scale_factor := 2.2 / bounds.size.y
	actor.scale = Vector3.ONE * scale_factor
	actor.position.y = -bounds.position.y * scale_factor
	print("AUDITION_BOUNDS %s scale=%f" % [str(bounds), scale_factor])
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 2.0, 6.2)
	camera.look_at_from_position(camera.position, Vector3(0.0, 1.1, 0.0), Vector3.UP)
	camera.fov = 45.0
	world.add_child(camera)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45.0, -25.0, 0.0)
	light.light_energy = 1.2
	world.add_child(light)
	for _frame in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.get_size() != Vector2i(1280, 720):
		push_error("Missing 1280x720 frame")
		quit(1)
		return
	image.save_png("res://crawlmaster_audition.png")
	print("AUDITION_CAPTURE res://crawlmaster_audition.png")
	quit(0)

func _print_tree(node: Node, prefix: String) -> void:
	print("AUDITION_NODE %s%s %s" % [prefix, node.name, node.get_class()])
	for child in node.get_children():
		_print_tree(child, prefix + "  ")
