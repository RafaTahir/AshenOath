extends SceneTree

## Isolated production Enemy/driver renderer proof. No Game, journey or saves.
## The grey capsule and amber sphere are labelled reference geometry only.
const Enemy = preload("res://scripts/enemy_ai.gd")
const Bindings = preload("res://scripts/character_material_bindings.gd")
const Profiles = preload("res://scripts/native_attack_profiles.gd")

class Defender extends CharacterBody3D:
	var contacts := 0
	var received_damage := 0.0
	func take_damage(amount: float) -> bool:
		contacts += 1
		received_damage += amount
		return false

var output := ""
var id := ""
var camera: Camera3D
var marker: MeshInstance3D
var actor: Node
var target: Defender
var height := 2.0
var frames: Array[Dictionary] = []
var failures: Array[String] = []

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--id="): id = arg.trim_prefix("--id=")
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	_run.call_deferred()

func _run() -> void:
	if id not in ["M03", "M20"] or output.is_empty():
		push_error("Required: --id=M03|M20 --output=<explicit isolated directory>")
		quit(1)
		return
	root.size = Vector2i(1100,900)
	root.content_scale_size = root.size
	DirAccess.make_dir_recursive_absolute(output)
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.18,0.19,0.20)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.65
	stage.add_child(environment)
	for position in [Vector3(-3,5,-3),Vector3(3,3,3)]:
		var light := DirectionalLight3D.new()
		stage.add_child(light)
		light.position = position
		light.look_at(Vector3(0,1,0))
		light.light_energy = 0.75 if position.z < 0 else 0.4
	var ground := MeshInstance3D.new()
	var ground_mesh := BoxMesh.new()
	ground_mesh.size = Vector3(8,0.04,8)
	ground.mesh = ground_mesh
	ground.position.y = -0.04
	ground.material_override = _material(Color(0.12,0.13,0.14))
	stage.add_child(ground)
	target = Defender.new()
	target.name = "CanonicalDefenderReference"
	stage.add_child(target)
	target.position.z = -1.2
	var reference := MeshInstance3D.new()
	reference.name = "GreyReferenceCapsule_NotAnAsset"
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.32
	capsule.height = 1.65
	reference.mesh = capsule
	reference.position.y = 0.825
	var translucent := _material(Color(0.34,0.37,0.39,0.24))
	translucent.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	reference.material_override = translucent
	target.add_child(reference)
	marker = MeshInstance3D.new()
	marker.name = "AmberContactProbeReference_NotAnAsset"
	var sphere := SphereMesh.new()
	sphere.radius = 0.025
	sphere.height = 0.05
	marker.mesh = sphere
	var amber := _material(Color(0.95,0.61,0.18))
	amber.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override = amber
	stage.add_child(marker)
	var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	var enemy_id := "bog_wretch" if id == "M03" else "wychwood_brute"
	actor = Enemy.new()
	stage.add_child(actor)
	actor.setup(enemy_id, definitions[enemy_id], target)
	actor.set_physics_process(false)
	var driver = actor.animation_driver
	if driver == null or not driver.is_valid() or actor.native_attack_profile.is_empty():
		push_error("Native production actor/profile unavailable: " + id)
		quit(1)
		return
	var visual: Node3D = driver.character_root
	_check(Bindings.has_textured_identity(visual), "production source must retain authored texture bindings")
	height = float(actor.get_meta("camera_subject_height", 2.0))
	camera = Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = height * 1.65
	camera.far = 50.0
	camera.make_current()
	var windup: float = actor._windup_duration()
	var recovery: float = actor._strike_recovery()
	actor.windup_time = windup
	actor.pending_attack_time = windup
	actor.attack_windup_total = windup
	actor._start_attack_animation()
	actor.attack_trace_start = actor._attack_contact_point()
	_check(driver.current_state == "attack" and driver.externally_ticked, "native strike must begin under its physics clock")
	await _capture("start")
	while actor.pending_attack_time > 0.0:
		var step := minf(1.0 / 120.0, float(actor.pending_attack_time))
		actor.windup_time = maxf(0.0, float(actor.windup_time) - step)
		actor._tick_pending_attack(step)
	var contact_clock: Dictionary = driver.capture_clock()
	_check(not bool(contact_clock.external) and is_equal_approx(float(contact_clock.interval), 1.0/12.0), "contact must return to the production 12 Hz tail owner")
	_check(is_equal_approx(float(driver.action_elapsed), windup), "damage must remain at the original windup boundary")
	_check(is_equal_approx(float(driver.action_duration), windup + recovery), "tail must fit the original recovery budget")
	_check(target.contacts == 1, "canonical defender must receive exactly one actual production contact")
	driver.set_external_tick(true)
	await _capture("contact")
	# Resume the actual production timer, rather than seeking an animation pose.
	driver.restore_clock(contact_clock)
	await create_timer(recovery * 0.5).timeout
	_check(float(driver.action_elapsed) > windup, "the production animation timer must advance the strike tail")
	var tail_clock: Dictionary = driver.capture_clock()
	driver.set_external_tick(true)
	await _capture("tail")
	var profile: Dictionary = actor.native_attack_profile
	var report := {"id":id, "enemy":enemy_id, "scope":"isolated production Enemy.setup, native contact and actual 12 Hz tail; no journey/save",
		"source":profile.source, "source_sha256":profile.source_sha256, "profile_sha256":FileAccess.get_sha256(Profiles.PATH),
		"profile_method":profile.method, "fallback_reason":profile.get("fallback_reason", ""), "contact_fraction":profile.contact_fraction,
		"clip":profile.clip, "clip_seconds":profile.duration_seconds, "windup_seconds":windup, "recovery_seconds":recovery,
		"contact_clock":contact_clock, "tail_clock":tail_clock, "contact_count":target.contacts, "received_damage":target.received_damage,
		"reference_geometry":"Grey capsule = canonical defender at (0,0,-1.2); amber sphere = actual _attack_contact_point(); neither is shipped anatomy",
		"material_bindings":Bindings.descriptors(visual), "frames":frames, "checks_passed":failures.is_empty(), "errors":failures,
		"visual_acceptance":"pending inspection"}
	FileAccess.open(output.path_join("review.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t",true)+"\n")
	for failure in failures: push_error(failure)
	print("NATIVE CONTACT RENDER ", id, ": ", "PASS" if failures.is_empty() else "FAIL", "; output=", output)
	actor.asset_helper.clear_runtime_caches()
	stage.free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _capture(label: String) -> void:
	var driver = actor.animation_driver
	marker.global_position = actor._attack_contact_point()
	var sample := {"label":label, "action_elapsed":driver.action_elapsed, "action_duration":driver.action_duration,
		"rate":driver.current_playback_scale, "state":driver.current_state, "graph_state":str(driver.animation_graph.playback.get_current_node()),
		"probe":[marker.global_position.x,marker.global_position.y,marker.global_position.z], "images":[]}
	var center := Vector3(0,height*0.47,-0.45)
	for view: String in ["quarter","side"]:
		var direction := Vector3(1.2,0.25,-1.8) if view == "quarter" else Vector3(1.8,0.15,0)
		camera.position = center + direction * height * 2.0
		camera.look_at(center)
		await process_frame
		await RenderingServer.frame_post_draw
		var file := output.path_join(label + "_" + view + ".png")
		_check(root.get_texture().get_image().save_png(file) == OK, "could not save rendered proof: " + file)
		sample.images.append(file)
	frames.append(sample)

func _material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.9
	return result

func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
