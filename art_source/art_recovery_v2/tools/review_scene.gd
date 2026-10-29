extends SceneTree

# Explicitly isolated review harness: no gameplay services, saves or rewards.
const Fusion = preload("res://scripts/character_animation_fusion.gd")
var out := "D:/Temp/AshenOath/art_recovery_v2/anwen_godot"

class OrbitReview extends Node3D:
	var camera: Camera3D
	var playback: AnimationPlayer
	var driver: Node
	var walk_clip := ""
	var idle_clip := ""
	var yaw := 0.3
	var pitch := 0.05
	var distance := 3.0
	var walking := false
	func _process(delta: float) -> void:
		if driver != null: driver.advance_external(delta)
	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			yaw -= event.relative.x * 0.007
			pitch = clampf(pitch + event.relative.y * 0.005, -0.6, 0.7)
		elif event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP: distance = maxf(0.5, distance - 0.2)
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: distance = minf(6.0, distance + 0.2)
		elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
			walking = not walking
			if driver != null: driver.set_locomotion(0.5 if walking else 0.0, Vector3.FORWARD, true)
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 45
		camera.position = Vector3(0,1.03,0) + Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*distance
		camera.look_at(Vector3(0,1.03,0))

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1000, 1000)
	var stage := Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.22, 0.23, 0.24)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.5
	stage.add_child(env)
	for pos in [Vector3(-3, 4, 3), Vector3(3, 3, -3)]:
		var light := DirectionalLight3D.new()
		stage.add_child(light)
		light.position = pos
		light.look_at(Vector3(0, 1, 0))
		light.light_energy = 0.75 if pos.z > 0 else 0.4
	var body: Node3D = load("res://art_review/anwen/anwen_review.glb").instantiate()
	stage.add_child(body)
	var player: AnimationPlayer = Fusion.attach_shared_library(body)
	preload("res://scripts/character_presentation.gd")._add_anwen_staff(body)
	var driver: Node = preload("res://scripts/character_animation_driver.gd").new()
	body.add_child(driver)
	if not driver.configure(body, {"idle":"Idle", "walk":"Walk", "run":"Sprint"}):
		push_error("Review actor could not acquire the existing animation owner")
		quit(1)
		return
	driver.set_external_tick(true)
	driver.set_locomotion(0.0, Vector3.ZERO, true)
	driver.advance_external(0.25)
	var clips := player.get_animation_list() if player != null else PackedStringArray()
	var idle := ""
	var walk := ""
	for clip: String in clips:
		if clip.to_lower().contains("idle") and idle == "": idle = clip
		if clip.to_lower() == "walk": walk = clip
	var cam := Camera3D.new()
	stage.add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.13
	cam.make_current()
	for label: String in {"front":0.0,"side":90.0,"rear":180.0,"quarter":35.0,"face":10.0}:
		var a: float = deg_to_rad({"front":0.0,"side":90.0,"rear":180.0,"quarter":35.0,"face":10.0}[label])
		var center := Vector3(0, 1.66 if label == "face" else 0.93, 0)
		cam.size = 0.43 if label == "face" else 2.13
		cam.position = center + Vector3(sin(a), 0.03, cos(a))*3
		cam.look_at(center)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join(label + ".png"))
	cam.size = 2.13
	cam.position = Vector3(1.6, 1.05, 3.2)
	cam.look_at(Vector3(0,0.93,0))
	# Sample actual shared walking deformation without moving a game character.
	if walk != "":
		driver.set_locomotion(0.5, Vector3.FORWARD, true)
		for frame in 24:
			driver.advance_external(1.0/24.0)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out.path_join("walk_%02d.png" % frame))
	var record := {"scope":"isolated Godot Compatibility art review; not live campaign acceptance", "idle_clip":idle, "walk_clip":walk, "clips":Array(clips), "accepted":false}
	FileAccess.open(out.path_join("review.json"),FileAccess.WRITE).store_string(JSON.stringify(record,"\t"))
	if "--interactive" in OS.get_cmdline_user_args():
		var orbit := OrbitReview.new()
		orbit.camera = cam
		orbit.playback = player
		orbit.driver = driver
		orbit.walk_clip = walk
		orbit.idle_clip = idle
		stage.add_child(orbit)
		root.title = "Anwen - ART REWORK / NOT ACCEPTED"
	else:
		quit()
