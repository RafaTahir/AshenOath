extends SceneTree

const OUTPUT := "res://Development_Gallery/screenshots/MON_002_RUNTIME_FAMILIES.png"
const EnemyAI = preload("res://scripts/enemy_ai.gd")
const IDS := [
	"ghoulkin",
	"wychwood_stalker",
	"wychwood_raider",
	"wychwood_brute",
	"bog_wretch",
	"gravebound_knight",
	"white_hart_avatar"
]

var failures := 0

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("Monster family capture requires a graphical renderer")
		quit(1)
		return
	var world := Node3D.new()
	world.name = "MonsterFamilyCaptureWorld"
	root.add_child(world)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("10151b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("93a4b5")
	env.ambient_light_energy = 1.05
	environment.environment = env
	world.add_child(environment)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 2.65, 15.0)
	camera.look_at_from_position(camera.position, Vector3(0.0, 1.55, 0.0), Vector3.UP)
	camera.fov = 50.0
	world.add_child(camera)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-34.0, -28.0, 0.0)
	key.light_color = Color("d7e4f2")
	key.light_energy = 1.55
	key.shadow_enabled = true
	world.add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(0.0, 2.1, 4.2)
	rim.light_color = Color("bb7c69")
	rim.light_energy = 2.0
	rim.omni_range = 15.0
	world.add_child(rim)
	var floor := MeshInstance3D.new()
	floor.name = "CaptureFloor"
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(18.0, 9.0)
	floor.mesh = floor_mesh
	floor.material_override = _material(Color("2d2b31"), 0.94)
	world.add_child(floor)
	var floor_body := StaticBody3D.new()
	floor_body.name = "CaptureFloorCollision"
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(18.0, 0.2, 9.0)
	floor_collision.shape = floor_shape
	floor_collision.position.y = -0.1
	floor_body.add_child(floor_collision)
	world.add_child(floor_body)
	var definitions: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	if not definitions is Dictionary:
		push_error("Enemy definitions are unavailable")
		failures += 1
		definitions = {}
	var labels := CanvasLayer.new()
	world.add_child(labels)
	var actors: Array = []
	for index in IDS.size():
		var id: String = IDS[index]
		var target := Node3D.new()
		target.name = "%sCaptureTarget" % id
		world.add_child(target)
		var actor := EnemyAI.new()
		actor.name = "%sCaptureActor" % id
		actor.position = Vector3((index - 3.0) * 2.0, 0.0, 0.0)
		actor.rotation.y = PI
		world.add_child(actor)
		actor.setup(id, definitions.get(id, {}), target)
		actors.append(actor)
		# Keep the audition in a stable idle pose; gameplay physics and pursuit are
		# exercised by the runtime gates, not by this composition capture.
		actor.player = null
		var label := Label.new()
		label.text = id.replace("_", " ").to_upper()
		label.position = Vector2(10 + index * 181, 675)
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color("e8dfcf"))
		labels.add_child(label)
	await _frames(40)
	for actor in actors:
		var report := {
			"id": actor.enemy_id,
			"position": actor.global_position,
			"driver": actor.animation_driver.get_contract_report() if actor.animation_driver != null else {},
			"meshes": []
		}
		for raw_mesh in actor.visual_root.find_children("*", "MeshInstance3D", true, false):
			var mesh := raw_mesh as MeshInstance3D
			var local_bounds := mesh.get_aabb()
			if mesh.skin != null:
				var baked := mesh.bake_mesh_from_current_skeleton_pose()
				if baked != null:
					local_bounds = baked.get_aabb()
			var surfaces: Array = []
			for surface_index in mesh.mesh.get_surface_count():
				var material := mesh.get_active_material(surface_index)
				var surface_report := {
					"index": surface_index,
					"class": material.get_class() if material != null else "null",
					"resource": material.resource_path if material != null else "",
					"priority": material.render_priority if material != null else 0
				}
				if material is BaseMaterial3D:
					surface_report.merge({
						"albedo": material.albedo_color,
						"texture": material.albedo_texture.resource_path if material.albedo_texture != null else "",
						"transparency": material.transparency,
						"shading": material.shading_mode,
						"cull": material.cull_mode,
						"depth_test_disabled": material.no_depth_test,
						"vertex_color_albedo": material.vertex_color_use_as_albedo,
						"distance_fade": material.distance_fade_mode
					})
				surfaces.append(surface_report)
			(report.meshes as Array).append({
				"name": mesh.name,
				"visible": mesh.is_visible_in_tree(),
				"layers": mesh.layers,
				"cast_shadow": mesh.cast_shadow,
				"visibility_begin": mesh.visibility_range_begin,
				"visibility_end": mesh.visibility_range_end,
				"in_frustum": camera.is_position_in_frustum((mesh.global_transform * local_bounds).get_center()),
				"global_bounds": mesh.global_transform * local_bounds,
				"surfaces": surfaces
			})
		print("MONSTER FAMILY RENDER ", JSON.stringify(report))
	await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null or image.get_size() != Vector2i(1280, 720):
		failures += 1
		push_error("Monster family capture has unexpected dimensions")
	else:
		image.save_png(ProjectSettings.globalize_path(OUTPUT))
	print("MON-002 RUNTIME FAMILY CAPTURE: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _frames(count: int) -> void:
	for _index in count:
		await process_frame
