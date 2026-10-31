extends SceneTree

# Explicitly isolated review harness: no gameplay services, saves or rewards.
const Fusion = preload("res://scripts/character_animation_fusion.gd")
const FaceModifier = preload("res://scripts/story_head_modifier.gd")
var out := "D:/Temp/AshenOath/art_recovery_v2/anwen_godot"
var asset_path := "res://art_review/anwen/anwen_review.glb"
var staff_path := ""
var face_only := false
var check_deformations := false
var generic_body := false
var generic_humanoid := false
var material_ids := false

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
			if driver != null: driver.set_locomotion(0.5 if walking else 0.0, driver.get_visible_forward(), true)
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 45
		camera.position = Vector3(0,1.03,0) + Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*distance
		camera.look_at(Vector3(0,1.03,0))

func _initialize() -> void:
	print("ART USER DIRECTORY: ", OS.get_user_data_dir(), "; name=", ProjectSettings.get_setting("application/config/name"), "; custom=", ProjectSettings.get_setting("application/config/use_custom_user_dir", false))
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--generic": generic_body = true
		if arg == "--humanoid": generic_humanoid = true
		if arg == "--material-ids": material_ids = true
		if arg == "--face-only": face_only = true
		if arg == "--deformations": check_deformations = true
		if arg.begins_with("--asset="): asset_path = arg.trim_prefix("--asset=")
		if arg.begins_with("--staff="): staff_path = arg.trim_prefix("--staff=")
		if arg.begins_with("--output-dir="): out = arg.trim_prefix("--output-dir=")
	call_deferred("capture_generic" if generic_body else "capture")

func capture_generic() -> void:
	# Native-clip and shared-human art inspection only; never starts a journey.
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(800, 800)
	root.content_scale_size = Vector2i(800, 800)
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.18, 0.19, 0.20)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.65
	stage.add_child(environment)
	for position in [Vector3(-3, 5, 3), Vector3(3, 3, -3)]:
		var light := DirectionalLight3D.new()
		stage.add_child(light)
		light.position = position
		light.look_at(Vector3(0, 1, 0))
		light.light_energy = 0.75 if position.z > 0 else 0.4
	var packed := load(asset_path) as PackedScene
	if packed == null:
		push_error("Candidate scene unavailable: " + asset_path)
		quit(1)
		return
	var body := packed.instantiate() as Node3D
	stage.add_child(body)
	var bindings := preload("res://scripts/character_material_bindings.gd")
	if not bindings.capture(body, "res://assets_external/design_pack_v1/review_body.glb"):
		push_error("Candidate lost required authored textures: %s" % body.get_meta("character_material_errors", []))
		quit(1)
		return
	var animation: AnimationPlayer = null
	var owned_driver: Node = null
	if generic_humanoid:
		animation = Fusion.attach_shared_library(body)
	else:
		var players := body.find_children("*", "AnimationPlayer", true, false)
		if not players.is_empty(): animation = players[0] as AnimationPlayer
	var clips := animation.get_animation_list() if animation != null else PackedStringArray()
	var idle := "Idle" if clips.has("Idle") else ""
	var walk := "Walk" if clips.has("Walk") else ("Walking" if clips.has("Walking") else "")
	for clip: String in clips:
		if idle.is_empty() and clip.to_lower().contains("idle"): idle = clip
		if walk.is_empty() and clip.to_lower().contains("walk"): walk = clip
	if animation == null or idle.is_empty() or walk.is_empty():
		push_error("Candidate lacks required idle/walk playback: " + asset_path)
		quit(1)
		return
	if animation != null and not idle.is_empty():
		animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		animation.play(idle)
		animation.advance(0.2)
	var box := AABB()
	var first := true
	for node in body.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var bounds := mesh.global_transform * mesh.get_aabb()
		box = bounds if first else box.merge(bounds)
		first = false
	if first or box.size.length() < 0.01:
		push_error("Candidate has no visible mesh bounds")
		quit(1)
		return
	var designs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/design_pack_assets.json"))
	for entry: Dictionary in designs.get("assets", {}).values():
		if str(entry.path) != asset_path:
			continue
		var profile: Dictionary = entry.get("authored_bind_bounds", {})
		if not profile.is_empty():
			var p: Array = profile.position
			var s: Array = profile.size
			box = AABB(Vector3(p[0], p[1], p[2]), Vector3(s[0], s[1], s[2]))
			if generic_humanoid and float(profile.get("garment_arm_clearance_m", 0.0)) > 0.0 and not material_ids:
				body.set_meta("garment_arm_clearance_m", float(profile.garment_arm_clearance_m))
				owned_driver = preload("res://scripts/character_animation_driver.gd").new()
				body.add_child(owned_driver)
				if not owned_driver.configure(body, {"idle":"Idle", "walk":"Walk", "run":"Sprint"}):
					push_error("Garment review could not acquire existing pose ownership")
					quit(1)
					return
				owned_driver.set_external_tick(true)
				owned_driver.set_locomotion(0.0, owned_driver.get_visible_forward(), true)
				owned_driver.advance_external(0.2)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(box.size.x, maxf(box.size.y, box.size.z)) * 1.35
	camera.far = maxf(50.0, camera.size * 8.0)
	camera.make_current()
	var center := box.get_center()
	if material_ids:
		var palette := [Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW, Color.MAGENTA, Color.CYAN]
		var surfaces: Array[Dictionary] = []
		for mesh: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
			for surface in mesh.mesh.get_surface_count():
				var original := mesh.get_active_material(surface)
				var color: Color = palette[surfaces.size() % palette.size()]
				var material := StandardMaterial3D.new()
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				material.albedo_color = color
				mesh.set_surface_override_material(surface, material)
				surfaces.append({"mesh":mesh.name,"surface":surface,"material":original.resource_name,"color":color.to_html()})
		animation.play(walk)
		animation.advance(animation.get_animation(walk).length / 3.0)
		camera.position = center + Vector3(0.574, 0.04, 0.819) * camera.size * 2.0
		camera.look_at(center)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join("material_ids.png"))
		FileAccess.open(out.path_join("material_ids.json"), FileAccess.WRITE).store_string(JSON.stringify({"scope":"Temporary per-instance material IDs only; NOT candidate appearance or approval","asset":asset_path,"surfaces":surfaces},"\t"))
		quit(0)
		return
	for label: String in {"front":0.0,"side":90.0,"rear":180.0,"quarter":35.0}:
		var angle := deg_to_rad(float({"front":0.0,"side":90.0,"rear":180.0,"quarter":35.0}[label]))
		camera.position = center + Vector3(sin(angle), 0.04, cos(angle)) * camera.size * 2.0
		camera.look_at(center)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join(label + ".png"))
	if animation != null and not walk.is_empty():
		if owned_driver != null:
			owned_driver.set_locomotion(0.5, owned_driver.get_visible_forward(), true)
		else:
			animation.play(walk)
		for frame in 12:
			if owned_driver != null:
				owned_driver.advance_external(animation.get_animation(walk).length / 12.0)
			else:
				animation.advance(animation.get_animation(walk).length / 12.0)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out.path_join("walk_%02d.png" % frame))
	var action_views: Array[String] = []
	var owned_locomotion := owned_driver != null
	if owned_driver != null:
		owned_driver.set_distance_suspended(true)
		animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	if animation != null:
		for clip: String in clips:
			var lower := clip.to_lower()
			if not (lower.contains("attack") or lower.contains("block") or lower.contains("hurt") or lower.contains("hitreact") or lower.contains("interact") or lower.contains("cast") or lower.contains("dodge") or lower.contains("bow") or lower.contains("shoot") or lower.contains("aim")):
				continue
			animation.play(clip)
			animation.advance(maxf(0.0, animation.get_animation(clip).length * 0.5))
			await process_frame
			await RenderingServer.frame_post_draw
			var filename := "action_" + clip.replace("/", "_").replace(":", "_") + ".png"
			root.get_texture().get_image().save_png(out.path_join(filename))
			action_views.append(filename)
	var file := FileAccess.open(out.path_join("review.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"isolated native/shared clip art preview, not gameplay acceptance", "asset":asset_path, "asset_sha256":FileAccess.get_sha256(asset_path), "authored_material_contract":true,"clips":Array(clips),"idle_clip":idle,"walk_clip":walk,"walk_cycle_seconds":animation.get_animation(walk).length,"action_midpoint_views":action_views,"framing_source":"skin-aware authored bind bounds / square art viewport", "owned_locomotion":owned_locomotion,"accepted":false}, "\t"))
	file.close()
	quit(0)

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
	var body: Node3D = load(asset_path).instantiate()
	stage.add_child(body)
	var bindings := preload("res://scripts/character_material_bindings.gd")
	# Exercise the production body's required-atlas policy, not a looser review
	# policy just because the derivative lives outside the production registry.
	if not bindings.capture(body, "res://assets_external/design_pack_v1/humans/C01_Anwen.glb"):
		push_error("Review body fails authored material ownership: %s" % str(body.get_meta("character_material_errors", [])))
		quit(1)
		return
	body.set_meta("character_prebaked_identity", true)
	body.set_meta("character_authored_silhouette", true)
	body.set_meta("character_asset_family", "quaternius_animated_humanoid")
	var identity := preload("res://scripts/character_identity_profile.gd").apply(body, "sister_anwen", "sister_anwen")
	if not bool(identity.get("valid", true)):
		push_error("Review body could not retain its authored identity")
		quit(1)
		return
	var body_skeleton := body.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	if preload("res://scripts/character_presentation.gd").uses_fitted_anwen_staff(body_skeleton, body):
		# Match the existing actor factory's +Z convention for this retained rig.
		body.set_meta("source_forward_positive_z", true)
	var player: AnimationPlayer = null
	var driver: Node = null
	var face_modifier: FaceModifier = null
	if not face_only:
		player = Fusion.attach_shared_library(body)
		preload("res://scripts/character_presentation.gd")._add_anwen_staff(body)
		if not replace_review_staff(body, staff_path):
			quit(1)
			return
		driver = preload("res://scripts/character_animation_driver.gd").new()
		body.add_child(driver)
		if not driver.configure(body, {"idle":"Idle", "walk":"Walk", "run":"Sprint"}):
			push_error("Review actor could not acquire the existing animation owner")
			quit(1)
			return
		driver.set_external_tick(true)
		driver.set_locomotion(0.0, Vector3.ZERO, true)
		driver.advance_external(0.25)
		var face_driver := body.find_child("CharacterFaceDriver", true, false)
		if face_driver != null:
			face_driver.set_expression("neutral")
			if check_deformations: face_modifier = face_driver.head_modifier
	var clips := player.get_animation_list() if player != null else PackedStringArray()
	var idle := ""
	var walk := ""
	for clip: String in clips:
		if clip.to_lower().contains("idle") and idle == "": idle = clip
		if clip.to_lower() == "walk": walk = clip
	var cam := Camera3D.new()
	stage.add_child(cam)
	cam.near = 0.05
	cam.far = 12.0
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.13
	cam.make_current()
	var views := {"front":0.0,"side":90.0,"rear":180.0,"quarter":35.0,"face":10.0}
	if face_only: views = {"front":0.0,"profile":90.0,"quarter":25.0,"rear":180.0}
	for label: String in views:
		var a: float = deg_to_rad(float(views[label]))
		var center := Vector3(0, 1.665 if face_only or label == "face" else 0.93, 0)
		cam.size = 0.34 if face_only else 0.43 if label == "face" else 2.13
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
		driver.set_locomotion(0.5, driver.get_visible_forward(), true)
		for frame in 24:
			driver.advance_external(1.0/24.0)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out.path_join("walk_%02d.png" % frame))
	if face_modifier != null:
		var face_driver := body.find_child("CharacterFaceDriver", true, false)
		if face_driver != null and face_driver.update_timer != null: face_driver.update_timer.stop()
		driver.set_locomotion(0.0, Vector3.ZERO, true)
		cam.size = 0.43
		cam.position = Vector3(0.35, 1.68, 3.0)
		cam.look_at(Vector3(0, 1.66, 0))
		for state: String in ["neutral", "blink_half", "blink_closed", "concerned", "speech"]:
			face_modifier.blink_closure = 0.5 if state == "blink_half" else 1.0 if state == "blink_closed" else 0.0
			face_modifier.set_expression("concerned" if state == "concerned" else "neutral")
			# Inspect settled intended poses, not a claim about transition timing
			# or synchronization to recorded speech.
			face_modifier.expression_weights = face_modifier.wanted_expression
			face_modifier.speech_amount = 0.6 if state == "speech" else 0.0
			face_modifier.current_speech = face_modifier.speech_amount
			for frame in 5:
				driver.advance_external(1.0 / 30.0)
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out.path_join("expression_" + state + ".png"))
	var record := {"scope":"isolated Godot Compatibility art review; not live campaign acceptance", "asset":asset_path,"asset_sha256":FileAccess.get_sha256(asset_path),"face_only":face_only,"settled_face_pose_review":check_deformations,"asset_staff_profile_effective":driver != null and driver.life_modifier != null and driver.life_modifier.anwen_staff_pose,"idle_clip":idle, "walk_clip":walk, "clips":Array(clips), "accepted":false}
	record["authored_material_contract"] = bool(body.get_meta("character_material_bindings_valid", false))
	record["identity"] = identity
	if not staff_path.is_empty():
		record["staff"] = staff_path
		record["staff_sha256"] = FileAccess.get_sha256(staff_path)
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

static func replace_review_staff(body: Node3D, path: String) -> bool:
	if path.is_empty(): return true
	var equipment := body.find_child("AnwenStaffEquipment", true, false) as Node3D
	if equipment == null or not path.begins_with("res://art_review/") or not ResourceLoader.exists(path):
		push_error("Art review staff/socket is unavailable: %s" % path)
		return false
	var packed := load(path) as PackedScene
	if packed == null: return false
	var replacement := packed.instantiate() as Node3D
	if replacement == null: return false
	var old := equipment.get_node_or_null("AnwenStaffModeled") as Node3D
	if old != null:
		replacement.scale = old.scale
		old.free()
	else:
		replacement.scale.y = 0.93 / 0.86
	replacement.name = "AnwenStaffModeled"
	equipment.add_child(replacement)
	return true
