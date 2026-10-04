extends SceneTree

## One graphical session. No main scene, save service, save files or subprocesses.
## Run only after the production import; the report and rendered sequences are
## deliberately collected together so this does not require a second launch.
const PlayerController = preload("res://scripts/player_controller.gd")
const GreyfenLifeController = preload("res://scripts/greyfen_life_controller.gd")
const NpcAmbient = preload("res://scripts/npc_ambient.gd")
const OUTPUT_DIR := "res://../../work/natural-motion-once"
const FRAME_SIZE := Vector2i(1280, 720)
const POSE_BONES := ["pelvis", "thigh_l", "thigh_r", "calf_l", "calf_r", "foot_l", "foot_r", "spine_01"]

class FakeInputNode:
	extends Node
	var movement := Vector2.ZERO
	var held: Dictionary = {}
	func movement_vector() -> Vector2:
		return movement
	func is_gameplay_context() -> bool:
		return true
	func is_action_pressed(action: StringName) -> bool:
		return bool(held.get(str(action), false))
	func is_action_just_pressed(_action: StringName) -> bool:
		return false
	func is_action_just_released(_action: StringName) -> bool:
		return false

class CameraStub:
	extends Node
	var yaw := 0.0
	var first_person := false
	func get_flat_forward() -> Vector3:
		return -Basis(Vector3.UP, yaw).z
	func get_flat_right() -> Vector3:
		return Basis(Vector3.UP, yaw).x
	func is_first_person() -> bool:
		return first_person
	func get_locked_combat_target() -> Node3D:
		return null

class QuietHud:
	extends Node
	func toast(_message: String) -> void:
		pass

class RoutineHost:
	extends Node
	var game_started := true
	var story_state: Node
	var zone_root: Node3D
	var hud: Node
	func validate_walkable_position(value: Vector3) -> Vector3:
		return value

var stage: Node3D
var player: CharacterBody3D
var input_stub: FakeInputNode
var camera_stub: CameraStub
var camera: Camera3D
var overlay: Label
var wall: StaticBody3D
var output_path := ""
var failures: Array[String] = []
var results: Array[Dictionary] = []
var actor_steps := 0
var rig_steps := 0
var finished := false
var started_msec := 0
var routine: Node
var npc: Node3D
var npc_driver: Node
var observer: Node3D

func _initialize() -> void:
	output_path = ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(output_path)
	started_msec = Time.get_ticks_msec()
	root.size = FRAME_SIZE
	Engine.max_fps = 60
	create_timer(175.0).timeout.connect(func() -> void:
		if not finished:
			_assert(false, "Session exceeded its 175-second deadline")
			_finish()
	)
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		_assert(false, "A graphical Compatibility renderer is required for the same-session captures")
		_finish()
		return
	_build_fixture()
	await _settle(24)
	var driver: Node = player.get("animation_driver") as Node
	_assert(driver != null and bool(driver.call("is_valid")), "Player must instantiate a real skeleton and animation driver")
	if driver == null or not bool(driver.call("is_valid")):
		_finish()
		return
	driver.connect("locomotion_step", _on_rig_step)
	var cases: Array[Dictionary] = [
		{"id":"forward", "title":"Forward walk / achieved motion", "input":Vector2(0,-1)},
		{"id":"stale_yaw_retreat", "title":"Retreat from a stale 90 degree facing", "input":Vector2(0,1), "yaw":PI/2.0, "retreat":true, "captures":[1,12,42,120]},
		{"id":"camera_orbit_retreat", "title":"Keep retreating as the camera orbits 90 degrees", "input":Vector2(0,1), "orbit":true, "retreat":true, "captures":[24,40,72,120]},
		{"id":"diagonal_retreat", "title":"Diagonal retreat / body faces opposite travel", "input":Vector2(1,1).normalized(), "retreat":true},
		{"id":"free_right_turn", "title":"Forward stride into a free right turn", "input":Vector2(1,0), "preroll":45, "captures":[1,8,30,120]},
		{"id":"free_left_turn", "title":"Forward stride into a free left turn", "input":Vector2(-1,0), "preroll":45, "captures":[1,8,30,120]},
		{"id":"backward_sprint_turn", "title":"Run + backward input / turn then run toward travel", "input":Vector2(0,1), "run":true, "preroll":45, "captures":[1,10,32,120]},
		{"id":"coast_stop", "title":"Release movement / complete the last stride and stop", "input":Vector2.ZERO, "preroll":60, "stop":true, "captures":[1,4,10,90], "frames":90},
		{"id":"first_person_retreat", "title":"First-person aim facing / run held while retreat stays bounded", "input":Vector2(0,1), "run":true, "first_person":true, "retreat":true},
		{"id":"collision_stop", "title":"Walk into a real wall / animation follows achieved movement", "input":Vector2(0,-1), "wall":true, "stop":true, "captures":[12,25,60,120]}
	]
	for spec: Dictionary in cases:
		if finished:
			return
		await _run_player_case(spec)
	if not finished:
		await _run_npc_route()
	if not finished:
		await _run_ambient()
	_finish()

func _build_fixture() -> void:
	stage = Node3D.new()
	stage.name = "NaturalMotionIsolatedFloor"
	root.add_child(stage)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("151c21")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b5c0c8")
	environment.ambient_light_energy = 0.82
	environment_node.environment = environment
	stage.add_child(environment_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42,-24,0)
	sun.light_color = Color("ffe0bd")
	sun.light_energy = 1.45
	stage.add_child(sun)
	var floor_body := StaticBody3D.new()
	floor_body.position.y = -0.10
	stage.add_child(floor_body)
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80,0.20,80)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80,80)
	floor_mesh.mesh = plane
	floor_mesh.material_override = _material(Color("343733"))
	stage.add_child(floor_mesh)
	for index: int in range(-20,21):
		_add_grid_line(Vector3(float(index),0.004,0), Vector3(0.012,0.005,40))
		_add_grid_line(Vector3(0,0.004,float(index)), Vector3(40,0.005,0.012))
	wall = StaticBody3D.new()
	wall.position = Vector3(0,1.10,-2.4)
	wall.collision_layer = 0
	wall.visible = false
	stage.add_child(wall)
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(5,2.2,0.30)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	var wall_mesh := MeshInstance3D.new()
	var wall_visual := BoxMesh.new()
	wall_visual.size = wall_box.size
	wall_mesh.mesh = wall_visual
	wall_mesh.material_override = _material(Color("77716b"))
	wall.add_child(wall_mesh)
	input_stub = FakeInputNode.new()
	camera_stub = CameraStub.new()
	stage.add_child(input_stub)
	stage.add_child(camera_stub)
	player = PlayerController.new()
	player.set("input_source", input_stub)
	player.set("camera_controller", camera_stub)
	player.position = Vector3(0,0.04,0)
	stage.add_child(player)
	player.connect("footstep", _on_player_step)
	camera = Camera3D.new()
	camera.fov = 36.0
	camera.current = true
	stage.add_child(camera)
	var layer := CanvasLayer.new()
	stage.add_child(layer)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.025,0.035,0.045,0.93)
	backdrop.size = Vector2(1280,112)
	layer.add_child(backdrop)
	overlay = Label.new()
	overlay.position = Vector2(20,12)
	overlay.size = Vector2(1240,96)
	overlay.add_theme_font_size_override("font_size", 22)
	overlay.add_theme_color_override("font_color", Color("f0e8d8"))
	layer.add_child(overlay)
	_frame_actor(player)

func _material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.94
	return result

func _add_grid_line(position: Vector3, dimensions: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	mesh.mesh = box
	mesh.position = position
	mesh.material_override = _material(Color("545950"))
	stage.add_child(mesh)

func _settle(frames: int) -> void:
	for _index: int in range(frames):
		if finished:
			return
		_frame_actor(player)
		await physics_frame
		await RenderingServer.frame_post_draw

func _run_player_case(spec: Dictionary) -> void:
	input_stub.movement = Vector2.ZERO
	input_stub.held.clear()
	camera_stub.yaw = 0.0
	camera_stub.first_person = false
	wall.collision_layer = 0
	wall.visible = false
	player.call("cancel_buffered_input", "fixture")
	player.global_position = Vector3(0,0.04,0)
	player.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	var stamina: Node = player.get("stamina_component") as Node
	stamina.call("restore", 100.0)
	await _settle(16)
	var preroll: int = int(spec.get("preroll", 0))
	if preroll > 0:
		input_stub.movement = Vector2(0,-1)
		await _settle(preroll)
	player.rotation.y = float(spec.get("yaw", player.rotation.y))
	camera_stub.first_person = bool(spec.get("first_person", false))
	input_stub.movement = spec.get("input", Vector2.ZERO)
	input_stub.held["run"] = bool(spec.get("run", false))
	wall.visible = bool(spec.get("wall", false))
	wall.collision_layer = 1 if wall.visible else 0
	var driver: Node = player.get("animation_driver") as Node
	var samples: Array[Dictionary] = []
	var captures: Array[Image] = []
	var capture_frames: Array = spec.get("captures", [15,42,77,120])
	var frame_count: int = int(spec.get("frames", 120))
	actor_steps = 0
	rig_steps = 0
	var origin: Vector3 = player.global_position
	var previous: Vector3 = origin
	for frame: int in range(1,frame_count+1):
		if finished:
			return
		if bool(spec.get("orbit", false)) and frame == 32:
			camera_stub.yaw = PI/2.0
		await physics_frame
		_frame_actor(player)
		var before_render: Dictionary = _sample(player, driver, player.get_real_velocity(), frame)
		_set_overlay(str(spec.title), before_render)
		await RenderingServer.frame_post_draw
		var sample: Dictionary = _sample(player, driver, player.get_real_velocity(), frame)
		sample["distance_delta"] = Vector2(player.global_position.x-previous.x, player.global_position.z-previous.z).length()
		previous = player.global_position
		samples.append(sample)
		if capture_frames.has(frame):
			captures.append(root.get_texture().get_image())
	var summary: Dictionary = _summarize(samples)
	summary["net_displacement"] = _vector(player.global_position-origin)
	summary["player_footsteps"] = actor_steps
	summary["rig_contacts"] = rig_steps
	var expected: Vector3 = (camera_stub.get_flat_right()*input_stub.movement.x-camera_stub.get_flat_forward()*input_stub.movement.y).normalized()
	var tail: Array[Dictionary] = samples.slice(maxi(samples.size()-20,0))
	var tail_speed: float = _mean(tail,"speed_mps")
	_assert(bool(summary.get("finite", false)), str(spec.id)+": physical samples must remain finite")
	_assert(float(summary.max_root_y)-float(summary.min_root_y) < 0.12, str(spec.id)+": isolated-floor body should stay grounded")
	if bool(spec.get("stop", false)):
		_assert(tail_speed < 0.10, str(spec.id)+": achieved movement must stop")
		_assert(str(samples.back().state) == "idle", str(spec.id)+": stopped gait must settle to idle")
		if str(spec.id) == "coast_stop":
			_assert(float(summary.distance_m) < 0.90, "coast_stop: release should stop within a short final step")
	else:
		var tail_direction: Vector3 = _mean_vector(tail,"velocity").normalized()
		var tail_forward: Vector3 = _mean_vector(tail,"forward").normalized()
		_assert(tail_direction.dot(expected) > 0.93, str(spec.id)+": final travel must match requested world direction")
		var expected_facing: Vector3 = -expected if bool(spec.get("retreat",false)) else expected
		_assert(tail_forward.dot(expected_facing) > 0.92, str(spec.id)+": settled visible facing must agree with movement intent")
		if bool(spec.get("retreat",false)):
			_assert(tail_speed > 0.65 and tail_speed <= 1.55, str(spec.id)+": retreat must remain a controlled short stride")
		else:
			var expected_speed: float = 5.3 if bool(spec.get("run",false)) else 3.4
			_assert(absf(tail_speed-expected_speed) < 0.25, str(spec.id)+": settled travel speed must retain requested pace")
		_assert(float(summary.pose_excursion) > 0.02, str(spec.id)+": real skeletal bones must move")
		_assert(rig_steps > 0, str(spec.id)+": moving rig should produce foot contacts")
	_store_case(str(spec.id), str(spec.title), samples, summary, captures)
	input_stub.movement = Vector2.ZERO
	input_stub.held.clear()

func _run_npc_route() -> void:
	wall.collision_layer = 0
	wall.visible = false
	player.set_physics_process(false)
	player.visible = false
	var host := RoutineHost.new()
	host.zone_root = stage
	host.hud = QuietHud.new()
	stage.add_child(host)
	host.add_child(host.hud)
	observer = Node3D.new()
	observer.position = Vector3(0,0,5.5)
	stage.add_child(observer)
	routine = GreyfenLifeController.new()
	routine.set("host", host)
	routine.set("player", observer)
	routine.set("asset_helper", player.get("asset_helper"))
	routine.set("quality", "quality")
	stage.add_child(routine)
	npc = Node3D.new()
	npc.name = "RealGreyfenRoutineFixture"
	stage.add_child(npc)
	npc_driver = routine.call("_make_skeletal_villager", npc, "motion_fixture", 0, 1.0) as Node
	_assert(npc_driver != null and bool(npc_driver.call("is_valid")), "NPC must use the real role spawner and skeletal driver")
	if npc_driver == null or not bool(npc_driver.call("is_valid")):
		return
	npc_driver.connect("locomotion_step", _on_rig_step)
	var route: Array = [Vector3.ZERO,Vector3(0,0,-1.4),Vector3(1.5,0,-1.4),Vector3(1.5,0,0)]
	var entry: Dictionary = routine.call("_make_entry", "motion_fixture", npc, route, 1.05, npc_driver, true)
	entry.pause = 0.0
	# Fixture anchors use the real arrival/work state but shorten its dwell so
	# one recording includes arrival, a planted turn and the next waypoint.
	entry.profile = {"occupation":"fixture walker", "activity":"idle", "activity_seconds":0.18}
	var actors: Array = routine.get("actors")
	actors.append(entry)
	var samples: Array[Dictionary] = []
	var captures: Array[Image] = []
	var previous: Vector3 = npc.global_position
	var previous_time: int = Time.get_ticks_usec()
	rig_steps = 0
	for frame: int in range(1,421):
		if finished:
			return
		await process_frame
		_frame_actor(npc)
		_set_overlay("Greyfen: accelerate, arrive, plant, turn, next waypoint", _sample(npc,npc_driver,Vector3.ZERO,frame))
		await RenderingServer.frame_post_draw
		var now: int = Time.get_ticks_usec()
		var delta: float = maxf(float(now-previous_time)/1000000.0,0.001)
		var achieved: Vector3 = (npc.global_position-previous)/delta
		var sample: Dictionary = _sample(npc,npc_driver,achieved,frame)
		sample["target_waypoint"] = int(entry.target)
		sample["routine_state"] = str(entry.life_state)
		sample["distance_delta"] = npc.global_position.distance_to(previous)
		samples.append(sample)
		previous = npc.global_position
		previous_time = now
		if frame in [35,115,250,420]:
			captures.append(root.get_texture().get_image())
	var summary: Dictionary = _summarize(samples)
	summary["rig_contacts"] = rig_steps
	summary["activity_cycles"] = int(entry.activity_cycles)
	_assert(float(summary.distance_m) > 1.5, "NPC routine must travel between real waypoints")
	_assert(int(entry.activity_cycles) > 0, "NPC must reach and enter a waypoint activity")
	_assert(float(summary.max_speed_mps) < 1.6, "NPC should keep its authored walking pace without jumps")
	_assert(float(summary.pose_excursion) > 0.02, "NPC waypoint travel must animate real bones")
	_assert(rig_steps > 0, "NPC moving gait must emit contacts")
	_store_case("npc_waypoints", "Real Greyfen waypoint controller", samples, summary, captures)

func _run_ambient() -> void:
	if npc == null or npc_driver == null:
		return
	routine.set_process(false)
	npc.remove_meta("locomotion_owner")
	npc.position = Vector3.ZERO
	npc.rotation = Vector3.ZERO
	npc_driver.call("set_working", false)
	npc_driver.call("set_dialogue_pose", false)
	npc_driver.call("stop_action")
	npc_driver.call("set_locomotion_motion", Vector3.ZERO, true)
	observer.position = Vector3(1.8,0,-2.4)
	var ambient := NpcAmbient.new()
	ambient.name = "NpcAmbient"
	ambient.call("setup", "walker_well", observer)
	npc.add_child(ambient)
	var samples: Array[Dictionary] = []
	var captures: Array[Image] = []
	var previous: Vector3 = npc.global_position
	rig_steps = 0
	for frame: int in range(1,181):
		if finished:
			return
		if frame == 70:
			observer.position = Vector3(-1.8,0,2.4)
		await process_frame
		_frame_actor(npc)
		_set_overlay("Ambient attention: planted root, bounded turn, skeletal breathing", _sample(npc,npc_driver,Vector3.ZERO,frame))
		await RenderingServer.frame_post_draw
		var sample: Dictionary = _sample(npc,npc_driver,Vector3.ZERO,frame)
		sample["distance_delta"] = npc.global_position.distance_to(previous)
		previous = npc.global_position
		samples.append(sample)
		if frame in [20,65,115,180]:
			captures.append(root.get_texture().get_image())
	var summary: Dictionary = _summarize(samples)
	_assert(float(summary.distance_m) < 0.002, "Ambient actor root must stay planted rather than bob or slide")
	_assert(float(summary.max_root_y)-float(summary.min_root_y) < 0.001, "Ambient breathing must not lift the root off the floor")
	_assert(rig_steps == 0, "Stationary ambient actor must not emit walking contacts")
	summary["rig_contacts"] = rig_steps
	_store_case("ambient_planted", "Real NPC ambient attention", samples, summary, captures)

func _sample(actor: Node3D, driver: Node, achieved_velocity: Vector3, frame: int) -> Dictionary:
	var flat: Vector3 = Vector3(achieved_velocity.x,0,achieved_velocity.z)
	var forward: Vector3 = driver.call("get_visible_forward")
	var mixer: AnimationPlayer = driver.call("get_animation_player") as AnimationPlayer
	var skeleton: Skeleton3D = driver.call("get_skeleton") as Skeleton3D
	var clip_name: String = str(mixer.current_animation) if mixer != null else ""
	var phase := 0.0
	if mixer != null and clip_name != "" and mixer.has_animation(clip_name):
		phase = fposmod(mixer.current_animation_position/maxf(mixer.get_animation(clip_name).length,0.001),1.0)
	var pose: Array[float] = []
	var feet: Dictionary = {}
	if skeleton != null:
		for bone_name: String in POSE_BONES:
			var index: int = skeleton.find_bone(bone_name)
			if index < 0:
				continue
			var rotation: Quaternion = skeleton.get_bone_pose_rotation(index)
			pose.append_array([rotation.x,rotation.y,rotation.z,rotation.w])
			if bone_name in ["foot_l","foot_r"]:
				feet[bone_name] = _vector(skeleton.global_transform*skeleton.get_bone_global_pose(index).origin)
	return {"frame":frame, "position":_vector(actor.global_position), "root_y":actor.global_position.y,
		"velocity":_vector(flat), "speed_mps":flat.length(), "forward":_vector(forward),
		"travel_facing_dot":forward.dot(flat.normalized()) if flat.length() > 0.02 else 0.0,
		"state":str(driver.get("current_state")), "clip":clip_name, "phase":phase,
		"playback_scale":float(driver.get("current_playback_scale")), "pose":pose, "feet":feet}

func _summarize(samples: Array[Dictionary]) -> Dictionary:
	var summary: Dictionary = {"finite":true,"distance_m":0.0,"max_speed_mps":0.0,"min_root_y":INF,"max_root_y":-INF,"pose_excursion":0.0,"phase_distance":0.0}
	var initial_pose: Array = samples[0].pose if not samples.is_empty() else []
	var previous_phase := -1.0
	var previous_clip := ""
	for sample: Dictionary in samples:
		var speed: float = float(sample.speed_mps)
		summary.finite = bool(summary.finite) and is_finite(speed) and is_finite(float(sample.root_y))
		summary.distance_m = float(summary.distance_m)+float(sample.get("distance_delta",0.0))
		summary.max_speed_mps = maxf(float(summary.max_speed_mps),speed)
		summary.min_root_y = minf(float(summary.min_root_y),float(sample.root_y))
		summary.max_root_y = maxf(float(summary.max_root_y),float(sample.root_y))
		var pose: Array = sample.pose
		var excursion := 0.0
		for index: int in range(mini(initial_pose.size(),pose.size())):
			excursion += absf(float(pose[index])-float(initial_pose[index]))
		summary.pose_excursion = maxf(float(summary.pose_excursion),excursion)
		if previous_phase >= 0.0 and previous_clip == str(sample.clip):
			summary.phase_distance = float(summary.phase_distance)+absf(wrapf(float(sample.phase)-previous_phase,-0.5,0.5))
		previous_phase = float(sample.phase)
		previous_clip = str(sample.clip)
	return summary

func _mean(samples: Array[Dictionary], key: String) -> float:
	var total := 0.0
	for sample: Dictionary in samples:
		total += float(sample.get(key,0.0))
	return total/maxf(float(samples.size()),1.0)

func _mean_vector(samples: Array[Dictionary], key: String) -> Vector3:
	var total := Vector3.ZERO
	for sample: Dictionary in samples:
		var values: Array = sample.get(key,[0.0,0.0,0.0])
		total += Vector3(float(values[0]),float(values[1]),float(values[2]))
	return total/maxf(float(samples.size()),1.0)

func _vector(value: Vector3) -> Array:
	return [value.x,value.y,value.z]

func _frame_actor(actor: Node3D) -> void:
	var center: Vector3 = actor.global_position+Vector3(0,0.88,0)
	# Observe a wall stop from the open side, so the actual collider does not
	# hide the body and feet that this same frame sequence needs to record.
	var camera_side: float = 4.5 if wall != null and wall.visible else -4.5
	camera.look_at_from_position(center+Vector3(2.6,1.35,camera_side),center,Vector3.UP)

func _set_overlay(title: String, sample: Dictionary) -> void:
	overlay.text = "%s  |  frame %d\n%s / %s  |  %.2f m/s  |  gait %.2fx  |  phase %.2f\nFacing/travel dot %.2f   +1 forward, -1 backward   |   floor grid: 1 metre" % [title,int(sample.frame),str(sample.state),str(sample.clip),float(sample.speed_mps),float(sample.playback_scale),float(sample.phase),float(sample.travel_facing_dot)]

func _store_case(id: String, title: String, samples: Array[Dictionary], summary: Dictionary, captures: Array[Image]) -> void:
	_assert(captures.size() == 4, id+": four separate rendered frames are required")
	var contact := Image.create_empty(1920,1080,false,Image.FORMAT_RGBA8)
	contact.fill(Color("10171b"))
	var files: Array[String] = []
	for index: int in range(captures.size()):
		var image: Image = captures[index]
		_assert(image != null and image.get_width() > 0 and image.get_height() > 0,id+": renderer returned an image")
		if image == null or image.is_empty():
			continue
		var file_name: String = "%s_%02d.png" % [id,index+1]
		_assert(image.save_png(output_path.path_join(file_name)) == OK,id+": rendered frame should save")
		files.append(file_name)
		var panel: Image = image.duplicate()
		panel.convert(Image.FORMAT_RGBA8)
		panel.resize(960,540,Image.INTERPOLATE_LANCZOS)
		contact.blit_rect(panel,Rect2i(0,0,960,540),Vector2i((index%2)*960,(index/2)*540))
	var sheet_name: String = id+"_contact_sheet.png"
	_assert(contact.save_png(output_path.path_join(sheet_name)) == OK,id+": contact sheet should save")
	results.append({"id":id,"title":title,"summary":summary,"samples":samples,"frames":files,"contact_sheet":sheet_name})
	print("NATURAL_MOTION_CASE ",id," ",JSON.stringify(summary))

func _on_player_step() -> void:
	actor_steps += 1

func _on_rig_step(_side: StringName) -> void:
	rig_steps += 1

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _finish() -> void:
	if finished:
		return
	finished = true
	var report: Dictionary = {"suite":"natural_motion_once","pass":failures.is_empty(),"elapsed_seconds":float(Time.get_ticks_msec()-started_msec)/1000.0,"failures":failures,"cases":results,"notes":["One graphical process; actual controllers and rigs on an isolated collision floor.","No save files or campaign scene loaded.","Bone-space feet positions are measurements, not an automatic claim that every foot plant looks natural.","Inspect the four-frame contact sheets alongside physical metrics within this same verification pass."]}
	var file: FileAccess = FileAccess.open(output_path.path_join("report.json"),FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report,"\t"))
		file.close()
	else:
		failures.append("Unable to write report.json")
	print("NATURAL MOTION ONCE: ","PASS" if failures.is_empty() else "FAIL", " | ",results.size()," cases | ",output_path)
	if stage != null and is_instance_valid(stage):
		stage.queue_free()
		for _index: int in range(4):
			await process_frame
	quit(0 if failures.is_empty() else 1)
