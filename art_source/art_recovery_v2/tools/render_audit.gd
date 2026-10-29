extends SceneTree

# Isolated art inspection: uses exported body data, never opens a journey/save.
var out := "D:/Temp/AshenOath/art_recovery_v2/audit"
var view: SubViewport
var camera: Camera3D

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	view = SubViewport.new()
	view.size = Vector2i(512, 640)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.23, 0.24, 0.25)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.65
	view.add_child(env)
	for pos in [Vector3(-3, 5, -4), Vector3(4, 3, 2)]:
		var light := DirectionalLight3D.new()
		view.add_child(light)
		light.position = pos
		light.look_at(Vector3(0, 1, 0))
		light.light_energy = 0.8 if pos.x < 0 else 0.5
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	view.add_child(camera)
	camera.make_current()
	var ledger: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/design_pack_assets.json"))
	var evidence := {}
	for id: String in ledger.assets:
		var path: String = ledger.assets[id].path
		var scene := load(path) as PackedScene
		if scene == null:
			push_error("Missing body " + path)
			continue
		var body := scene.instantiate() as Node3D
		view.add_child(body)
		var bounds := AABB()
		var first := true
		for raw in body.find_children("*", "MeshInstance3D", true, false):
			var mesh := raw as MeshInstance3D
			var box := mesh.global_transform * mesh.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
		var center := bounds.get_center()
		var extent := maxf(bounds.size.y, maxf(bounds.size.x, bounds.size.z))
		camera.size = extent * 1.20
		var shots := {}
		for label: String in {"front":0.0, "side":90.0, "rear":180.0, "quarter":35.0}:
			var angle: float = deg_to_rad({"front":0.0, "side":90.0, "rear":180.0, "quarter":35.0}[label])
			camera.position = center + Vector3(sin(angle), 0.05, -cos(angle)) * extent * 3
			camera.look_at(center)
			await process_frame
			await RenderingServer.frame_post_draw
			var file := out.path_join(id + "_" + label + ".png")
			view.get_texture().get_image().save_png(file)
			shots[label] = file
		evidence[id] = {"path":path, "sha256":FileAccess.get_sha256(path), "bounds":str(bounds), "views":shots, "motion_reviewed":false, "level_lighting_reviewed":false}
		body.free()
		print("ART AUDIT CAPTURED ", id)
	var file := FileAccess.open(out.path_join("capture_manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence, "\t"))
	quit()
