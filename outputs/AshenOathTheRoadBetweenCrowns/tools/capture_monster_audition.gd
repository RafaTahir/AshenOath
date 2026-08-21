extends SceneTree

const OUTPUT := "res://Development_Gallery/screenshots/MON_002_MONSTER_AUDITION.png"
const SOURCES := [
	"res://assets_external/enemies/Skeleton.fbx",
	"res://assets_external/enemies/Dragon.fbx",
	"res://assets_external/enemies/Wolf.fbx",
	"res://assets_external/characters_real/GhoulGaunt_Real.glb",
	"res://assets_external/characters_real/GhoulStalker_Real.glb",
	"res://assets_external/characters_real/GhoulBrute_Real.glb"
]

var failures := 0

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("MON-002 audition requires a graphical renderer")
		quit(1)
		return
	var world := Node3D.new()
	world.name = "MonsterAuditionWorld"
	root.add_child(world)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("11131a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("9ba8bd")
	env.ambient_light_energy = 0.72
	environment.environment = env
	world.add_child(environment)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 2.3, 8.6)
	camera.look_at_from_position(camera.position, Vector3(0.0, 1.15, 0.0), Vector3.UP)
	camera.fov = 42.0
	world.add_child(camera)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35.0, -25.0, 0.0)
	key.light_color = Color("d8e3ff")
	key.light_energy = 1.45
	key.shadow_enabled = true
	world.add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(0.0, 2.0, 2.2)
	rim.light_color = Color("b98367")
	rim.light_energy = 1.7
	rim.omni_range = 10.0
	world.add_child(rim)
	var floor := MeshInstance3D.new()
	floor.name = "AuditionFloor"
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(20.0, 12.0)
	floor.mesh = floor_mesh
	floor.material_override = _material(Color("26242a"), 0.92)
	world.add_child(floor)
	var label_layer := CanvasLayer.new()
	world.add_child(label_layer)
	for index in SOURCES.size():
		var path: String = SOURCES[index]
		var packed := load(path) as PackedScene
		if packed == null:
			failures += 1
			push_error("Missing audition source: %s" % path)
			continue
		var actor := packed.instantiate() as Node3D
		if actor == null:
			failures += 1
			continue
		actor.name = "Audition_%02d" % index
		actor.position = Vector3((index - 2.5) * 2.15, 0.02, 0.0)
		actor.scale = Vector3.ONE * (0.92 if index < 3 else 0.82)
		world.add_child(actor)
		_ground_actor(actor)
		var animation_player := actor.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if animation_player != null:
			print("AUDITION_CLIPS %s: %s" % [path.get_file(), ",".join(animation_player.get_animation_list())])
		if path.ends_with("Skeleton.fbx"):
			for mesh_node in actor.find_children("*", "MeshInstance3D", true, false):
				var mesh_instance := mesh_node as MeshInstance3D
				if mesh_instance.mesh == null:
					continue
				for surface_index in mesh_instance.mesh.get_surface_count():
					var material := mesh_instance.mesh.surface_get_material(surface_index)
					print("AUDITION_SURFACE %s / %s / %s" % [mesh_instance.name, mesh_instance.mesh.surface_get_name(surface_index), str(material.resource_name if material != null else "")])
		var title := Label.new()
		title.text = path.get_file().get_basename()
		title.position = Vector2(30 + index * 205, 670)
		title.add_theme_font_size_override("font_size", 15)
		title.add_theme_color_override("font_color", Color("e8dfcf"))
		label_layer.add_child(title)
	await _frames(25)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null or image.get_size() != Vector2i(1280, 720):
		failures += 1
	else:
		image.save_png(ProjectSettings.globalize_path(OUTPUT))
	print("MON-002 AUDITION: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _ground_actor(actor: Node3D) -> void:
	var bounds := AABB()
	var initialized := false
	for mesh in actor.find_children("*", "MeshInstance3D", true, false):
		var instance := mesh as MeshInstance3D
		if instance.mesh == null:
			continue
		var local_bounds := instance.transform * instance.mesh.get_aabb()
		bounds = bounds.merge(local_bounds) if initialized else local_bounds
		initialized = true
	if initialized and bounds.position.y < 0.0:
		actor.position.y -= bounds.position.y

func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _frames(count: int) -> void:
	for _index in count:
		await process_frame
