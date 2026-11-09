extends SceneTree

## Instrumented native in-level observation, not a claim of real input QA.
## Can mount a frozen production pack set to capture the exact pre-edit game.
var options: Dictionary = {}
var report := {"kind":"native_living_cast_observation", "frames":[], "failures":[], "input":"fixture staging; real-input acceptance is separate"}
var output := ""
var game: Node
var viewport := Vector2i(1280, 720)
var camera: Camera3D
var geometry: RefCounted
var life: Node
var saved_scene_clocks: Dictionary = {}
var camera_offset := Vector3.ZERO
var camera_target_height := 1.0
var current_environment := "day"
var elapsed_start := 0
var camera_checks: Dictionary = {}
var delivery: Script
var capture_zone := "greyfen"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--") and "=" in arg:
			var pair := arg.trim_prefix("--").split("=", true, 1)
			options[pair[0]] = pair[1]
	output = str(options.get("output", "D:/Temp/AshenOath/living-cast-observation"))
	DirAccess.make_dir_recursive_absolute(output)
	# The runner configures user data before renderer initialization. Verify
	# the resolved directory before permitting the game to create saves.
	var profile := str(options.get("profile", ""))
	if profile.is_empty():
		_fail("Use run_living_cast_capture.py to configure isolation before renderer startup")
		_finish(1)
		return
	if not OS.get_user_data_dir().replace("\\", "/").ends_with(profile):
		_fail("Disposable user directory did not resolve: " + OS.get_user_data_dir())
		_finish(1)
		return
	if options.has("root-pack") and not ProjectSettings.load_resource_pack(str(options["root-pack"]), true):
		_fail("Could not mount frozen root pack")
		_finish(1)
		return
	report["user_data_dir"] = OS.get_user_data_dir()
	if DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir()) != OK:
		_fail("Could not create disposable user directory")
		_finish(1)
		return
	if options.has("packs"):
		var folder := str(options.packs)
		var names := DirAccess.get_files_at(folder)
		var mounted: Array[String] = []
		for name in names:
			if name.ends_with(".pck"):
				if not ProjectSettings.load_resource_pack(folder.path_join(name), true):
					_fail("Could not mount frozen pack: " + name)
				else:
					mounted.append(name)
		report["mounted_packs"] = mounted
	if not report.failures.is_empty():
		_finish(1)
		return
	if options.get("viewport", "desktop") == "touch": viewport = Vector2i(960, 540)
	root.size = viewport
	DisplayServer.window_set_size(viewport)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 60
	report["viewport"] = [viewport.x, viewport.y]
	report["label"] = str(options.get("label", "candidate"))
	report["acceptance_mode"] = str(options.get("acceptance-mode", "candidate"))
	report["behavior_acceptance"] = "evaluated separately by run_living_cast_capture.py"
	if report.acceptance_mode not in ["candidate", "baseline-observation"]:
		_fail("Unknown capture acceptance mode")
		_finish(1)
		return
	capture_zone = str(options.get("zone", "greyfen"))
	report["zone"] = capture_zone
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		_fail("Graphical renderer required")
		_finish(1)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	var deadline := Time.get_ticks_msec() + 180000
	while not game.opening_startup_metrics.has("menu_ready_ms") and Time.get_ticks_msec() < deadline:
		await process_frame
	if not game.opening_startup_metrics.has("menu_ready_ms"):
		_fail("Menu readiness deadline")
		await _shutdown()
		return
	game.settings.set_quality_preset("balanced")
	game._new_game()
	deadline = Time.get_ticks_msec() + 180000
	while Time.get_ticks_msec() < deadline:
		if is_instance_valid(game.zone_root) and bool(game.zone_root.get_meta("opening_scene_active", false)):
			var opening: Node = game.zone_root.find_child("GreyfenLifeController", true, false)
			if opening != null: opening.finish_opening_scene("skipped")
		if game.game_started and is_instance_valid(game.player) and game.player.can_control and not game.opening_scene_pending:
			break
		await process_frame
	if not game.game_started or not game.player.can_control:
		_fail("Playable Greyfen readiness deadline")
		await _shutdown()
		return
	if not await _prepare_region():
		await _shutdown()
		return
	life = game.zone_root.find_child("GreyfenLifeController", true, false)
	if life == null: life = game.zone_root.find_child("RegionalLifeController", true, false)
	if life == null:
		_fail("Missing runtime life controller")
		await _shutdown()
		return
	# Only random scene acquisition is suppressed. Actor/routine clocks keep running.
	life._end_social_exchange()
	saved_scene_clocks = {"world":life.world_scene_clock,"social":life.social_cooldown,"line":life.line_cooldown}
	life.world_scene_clock = 99999.0
	life.social_cooldown = 99999.0
	life.line_cooldown = 99999.0
	delivery = load("res://scripts/story_performance.gd")
	game.day_night.set_time_lock(true)
	game.camera_rig.set_process(false)
	game.camera_rig.set_physics_process(false)
	var source: Camera3D = game.camera_rig.camera
	camera = Camera3D.new()
	camera.name = "LivingCastFixtureCamera"
	for key: String in ["fov","near","far","cull_mask","keep_aspect","projection","size","environment","attributes"]:
		camera.set(key, source.get(key))
	root.add_child(camera)
	camera.make_current()
	game.player.sword_sheathed = true
	game.player.set_process_input(false)
	game.player.set_process_unhandled_input(false)
	geometry = load(str(options.get("geometry-script", get_script().resource_path.get_base_dir().path_join("living_cast_capture_geometry.gd")))).new()
	report["geometry"] = geometry.build(game.zone_root, game.player)
	report["configuration"] = {"quality":"balanced","renderer":RenderingServer.get_current_rendering_method(),"camera":_camera_record(),
		"random_scenes":"acquisition cooldown held; existing scene cancelled", "player":"fixture positioning; sword sheathed; input callbacks disabled",
		"scenarios":str(options.get("scenarios","observe")), "environments":str(options.get("environments","day")),
		"requested_sample_hz":float(options.get("sample-hz","10")),"scenario_seconds":float(options.get("duration","4.4")),
		"frame_limit":60,"vsync":"disabled","physics_ticks_per_second":Engine.physics_ticks_per_second}
	report["scenarios"] = []
	elapsed_start = Time.get_ticks_msec()
	_set_environment("day")
	if str(options.get("performance", "false")) == "true":
		report["performance"] = await _performance()
	var cast: Script = load("res://scripts/story_cast_profile.gd")
	for environment: String in str(options.get("environments", "day")).split(","):
		_set_environment(environment)
		for id: String in str(options.get("actors", "anwen,tor,mira,rook")).split(","):
			var actor: Node3D = cast.registered_actor(game.zone_root, id)
			if actor == null:
				_fail("Missing registered actor: " + id)
				continue
			var entry := _entry_for(actor)
			if entry.is_empty():
				_fail("Missing routine entry: " + id)
				continue
			for scenario: String in str(options.get("scenarios", "observe")).split(","):
				await _scenario(id, actor, entry, scenario)
			print("LIVING CAST CAPTURED: " + id + " / " + environment)
	await _shutdown()

func _prepare_region() -> bool:
	# Observation-only setup, recorded independently of earned campaign/input QA.
	# No actor is injected: the requested region must construct its real cast.
	var seed_path := str(options.get("observation-state", ""))
	if not seed_path.is_empty():
		var seed: Variant = JSON.parse_string(FileAccess.get_file_as_string(seed_path))
		if not seed is Dictionary or not seed.get("flags") is Dictionary:
			_fail("Invalid observation state")
			return false
		for key: String in seed.flags: game.story_state.set_flag(key, seed.flags[key])
		report["observation_state"] = seed.duplicate(true)
	if capture_zone != "greyfen":
		game._load_zone(capture_zone)
		var deadline := Time.get_ticks_msec() + 180000
		while Time.get_ticks_msec() < deadline:
			if game.current_zone_id == capture_zone and not game.zone_transition_pending and not game.zone_load_request_pending and is_instance_valid(game.player) and game.player.can_control:
				return true
			await process_frame
		_fail("Observation region readiness deadline: " + capture_zone)
		return false
	return true

func _set_environment(value: String) -> void:
	current_environment = value
	# These are existing day/weather rules, not direct story flags or weather overrides.
	game.day_night.set_time(60.0 if value == "night" else 600.0, 1 if value == "rain" else 0)
	life._sync_story_state(true)

func _entry_for(actor: Node3D) -> Dictionary:
	for entry: Dictionary in life.actors:
		if entry.node == actor: return entry
	return {}

func _forward(actor: Node3D) -> Vector3:
	var driver: Node = actor.find_child("CharacterAnimationDriver", true, false)
	var direction := actor.global_basis.z.normalized()
	if driver != null and driver.has_method("get_visible_forward"):
		direction = driver.get_visible_forward()
	elif not bool(actor.get_meta("source_forward_positive_z", false)):
		direction = -direction
	direction.y = 0.0
	return direction.normalized()

func _position_player(actor: Node3D, distance: float, front: bool = false) -> bool:
	var forward := _forward(actor)
	for angle in [0.35,-0.35,0.7,-0.7,1.2,-1.2,2.0,-2.0,3.14]:
		if front and absf(angle) > 1.2: continue
		var point := actor.global_position + forward.rotated(Vector3.UP, angle) * distance
		point = geometry.support_point(game.player.get_world_3d().direct_space_state,point,[game.player.get_rid()],0.65)
		if not point.is_finite(): continue
		if game.spatial_service.is_walkable_position(point, 0.55, game.spatial_service.bank_for(point)):
			# The actual player capsule base is on its root, just like NPC feet.
			game.player.global_position = point + Vector3.UP * 0.025
			game.player.velocity = Vector3.ZERO
			return true
	return false

func _stage_activity(entry: Dictionary) -> bool:
	if life.has_method("_cancel_greeting"): life._cancel_greeting(entry)
	life._release_activity(entry)
	life._apply_pending_routine(entry)
	var activities: Array = entry.profile.get("activities", [])
	var index: int = entry.path.size()-1 if activities.is_empty() else 0
	if current_environment == "day":
		var wanted := str(entry.profile.get("workstation", {}).get("activity", entry.profile.get("activity", "")))
		if activities.has(wanted): index = activities.find(wanted)
		else:
			for candidate in range(activities.size()):
				if str(activities[candidate]) not in ["idle","rest","sleep","watch","talk","walk"]:
					index = candidate
					break
	if entry.path.is_empty(): return false
	index = mini(index, entry.path.size()-1)
	var point: Vector3 = entry.path[index]
	point = geometry.support_point(game.player.get_world_3d().direct_space_state,point,[game.player.get_rid()],0.18)
	if not point.is_finite() or not game.spatial_service.is_walkable_position(point, 0.35, game.spatial_service.bank_for(point)):
		return false
	entry.node.global_position = point
	entry.arrived_target = index
	entry.target = (index + 1) % entry.path.size()
	entry.route = []
	entry.route_index = 0
	entry.motion_speed = 0.0
	entry.travel_direction = Vector3.ZERO
	entry.pause = 0.0
	entry.bark_cooldown = 0.0
	entry.greeted_on_approach = false
	entry.driver.set_locomotion_motion(Vector3.ZERO, true)
	life._begin_activity(entry)
	var station: Dictionary = entry.profile.get("workstation", {})
	var facing := point
	if str(station.get("activity","")) == str(entry.profile.get("activity","")):
		facing = station.get("look",station.get("point",point))
	if str(entry.profile.get("activity", "")) == "sleep":
		facing = entry.profile.get("rest_anchor", {}).get("look", facing)
	# Placement/facing is explicit fixture staging; native clip and contact clocks
	# remain owned by the existing animation driver and life controller.
	if facing.distance_squared_to(point) > 0.01: life._face(entry.node,facing,10.0)
	return bool(entry.get("activity_active", false)) or str(report.acceptance_mode) == "baseline-observation"

func _scenario(id: String, actor: Node3D, entry: Dictionary, scenario: String) -> void:
	var owner: Variant = actor.get_meta("locomotion_owner", "")
	var held := false
	var held_profile: Dictionary = {}
	var prior_hold: Variant = null
	var identity: String = load("res://scripts/story_cast_profile.gd").canonical_identity(id)
	var row := {"actor":id,"identity":identity,"environment":current_environment,"scenario":scenario,"staging":"instrumented existing runtime APIs", "samples":[],"frames":[],"contacts":[]}
	if scenario != "observe" and scenario != "resume":
		if not _stage_activity(entry):
			_fail("Cannot stage authored activity: " + id + "/" + current_environment + "/" + scenario)
			return
	if not _position_player(actor, 6.0):
		_fail("No walkable observation player position: " + id)
		return
	if scenario == "work":
		held_profile = entry.profile
		prior_hold = held_profile.get("hold_activity")
		held_profile["hold_activity"] = true
		row["staging"] = "authored activity anchor; fixture holds station for full animation cycle; original hold restored"
	if scenario == "idle":
		life._release_activity(entry)
		actor.set_meta("locomotion_owner", "capture_fixture")
		held = true
		entry.driver.set_life_activity("idle")
		if is_instance_valid(entry.get("face")):
			if entry.face.has_method("set_attention"): entry.face.set_attention("neutral")
			else: entry.face.set_focus_target(null)
	elif scenario == "approach":
		await _wait_seconds(0.3)
		if not _position_player(actor, 2.0, true):
			_fail("No walkable approach position: " + id)
			return
	elif scenario == "dialogue":
		if not _position_player(actor, 2.0, true):
			_fail("No walkable dialogue position: " + id)
			return
		delivery.begin(actor, game.player, {}, game.story_state)
		var speaker: String = {"anwen":"sister_anwen","tor":"blacksmith_tor"}.get(id,id)
		delivery.page(actor, {"speaker_id":speaker,"performance":{"emotion":"warmth","gesture":"explain"}}, null)
	elif scenario == "interruption":
		life._on_perception_cue(actor.global_position + _forward(actor)*2.0, 6.0, true)
	elif scenario == "resume":
		delivery.finish(actor)
		# Wait for the real scheduler to reach an activity again, not merely for
		# the threat timer to expire. Follow at observation distance so LOD cannot
		# prevent recovery while the actor walks to a different authored station.
		var resume_start := Time.get_ticks_msec()
		var deadline := resume_start + 60000
		row["resume_wait_samples"] = []
		var next_resume_sample := resume_start
		while (float(entry.get("reaction_time",0.0)) > 0.0 or not bool(entry.get("activity_active",false))) and Time.get_ticks_msec() < deadline:
			if actor.global_position.distance_to(game.player.global_position) > 8.0: _position_player(actor,6.0)
			camera.global_position = actor.global_position + Vector3(0,1.8,3)
			camera.look_at(actor.global_position + Vector3.UP)
			camera.make_current()
			await process_frame
			if Time.get_ticks_msec() >= next_resume_sample:
				row.resume_wait_samples.append(_actor_sample(actor,entry))
				next_resume_sample = Time.get_ticks_msec() + 100
		row["resume_wait_ms"] = Time.get_ticks_msec()-resume_start
		if float(entry.get("reaction_time",0.0)) > 0.0 or not bool(entry.get("activity_active",false)):
			if str(report.acceptance_mode) == "candidate": _fail("Scheduler activity recovery deadline: " + id)
			else: row["staging_limitation"] = "Scheduler activity recovery deadline reached in baseline observation"
	if not _stage_camera(actor):
		_fail("No clear projected actor camera: " + id + "/" + scenario + " " + str(camera_checks))
		if held: actor.set_meta("locomotion_owner", owner)
		_restore_hold(held_profile,prior_hold)
		delivery.finish(actor)
		return
	row["initial"] = _actor_sample(actor,entry)
	row["camera_preflight"] = camera_checks.duplicate(true)
	var duration := float(options.get("idle-duration", "16.4")) if scenario == "idle" else float(options.get("duration", "4.4"))
	var listening_page_started := false
	var interval := 1000.0 / float(options.get("sample-hz", "10"))
	var start := Time.get_ticks_msec()
	var contact_listener := func(event: String, point: Vector3) -> void:
		row.contacts.append({"event":event,"position":_v3(point),"scenario_elapsed_ms":Time.get_ticks_msec()-start,
			"state":_actor_sample(actor,entry)})
	var contact_driver: Node = entry.get("driver")
	var contact_supported := is_instance_valid(contact_driver) and contact_driver.has_signal("activity_contact")
	row["contact_signal_available"] = contact_supported
	if contact_supported: contact_driver.connect("activity_contact",contact_listener)
	var next_sample := float(start)
	var frame_count := int(options.get("frames-per-scenario", "5"))
	var next_frame := 0
	while Time.get_ticks_msec() - start < duration * 1000.0:
		camera.global_position = actor.global_position + camera_offset
		camera.look_at(actor.global_position + Vector3.UP * camera_target_height)
		camera.make_current()
		await process_frame
		var now := Time.get_ticks_msec()
		if scenario == "dialogue" and not listening_page_started and float(now-start) >= duration*500.0:
			# Exercise the retained conversation owner's speaker/listener transition.
			delivery.page(actor, {"speaker_id":"player", "performance":{"emotion":"neutral","listener_gesture":"acknowledge"}}, null)
			listening_page_started = true
		if float(now) >= next_sample:
			row.samples.append(_actor_sample(actor,entry))
			next_sample = float(now) + interval
		if next_frame < frame_count and float(now-start) >= duration*1000.0*float(next_frame)/float(frame_count):
			var geometry_start := Time.get_ticks_usec()
			var validation := _validate_actor_camera(actor)
			if not validation.is_empty() and not _stage_camera(actor):
				_fail("Actor became visually occluded: " + id + "/" + scenario)
				break
			if not validation.is_empty(): validation = _validate_actor_camera(actor)
			var geometry_us := Time.get_ticks_usec() - geometry_start
			await RenderingServer.frame_post_draw
			var name := "%s_%s_%s_%02d.png" % [id,current_environment,scenario,next_frame]
			var path := output.path_join(name)
			var readback_start := Time.get_ticks_usec()
			var captured := root.get_texture().get_image()
			var readback_us := Time.get_ticks_usec() - readback_start
			var write_start := Time.get_ticks_usec()
			if captured.save_png(path) != OK: _fail("Capture write failed: " + path)
			var write_us := Time.get_ticks_usec() - write_start
			var frame := {"actor":id,"scenario":scenario,"environment":current_environment,"sample":next_frame,"path":path,
				"captured_at_ms":Time.get_ticks_msec()-elapsed_start,"scenario_elapsed_ms":Time.get_ticks_msec()-start,
				"state":_actor_sample(actor,entry),"camera":_camera_record(),"validation":validation,"source":"actual " + capture_zone + " runtime actor",
				"instrumentation_us":{"geometry":geometry_us,"readback":readback_us,"png_write":write_us}}
			report.frames.append(frame)
			row.frames.append(path)
			next_frame += 1
	row["elapsed_seconds"] = float(Time.get_ticks_msec()-start)/1000.0
	row["requested_duration_seconds"] = duration
	row["listening_page_started"] = listening_page_started
	row["observed_sample_hz"] = row.samples.size()/float(row.elapsed_seconds)
	row["requested_frames"] = frame_count
	row["rendered_frames"] = row.frames.size()
	row["rendered_frame_hz"] = row.frames.size()/float(row.elapsed_seconds)
	if row.frames.size() != frame_count: _fail("Incomplete frame sequence: " + id + "/" + scenario)
	row["final"] = _actor_sample(actor,entry)
	if contact_supported and is_instance_valid(contact_driver) and contact_driver.is_connected("activity_contact",contact_listener):
		contact_driver.disconnect("activity_contact",contact_listener)
	row["observations"] = _scenario_observations(scenario,row)
	report.scenarios.append(row)
	if held:
		actor.set_meta("locomotion_owner", owner)
		entry.driver.clear_life_activity()
	if scenario == "dialogue": delivery.finish(actor)
	_restore_hold(held_profile,prior_hold)

func _scenario_observations(scenario: String, row: Dictionary) -> Dictionary:
	var observed := {"activity":false,"greeting":false,"dialogue":false,"threat":false}
	for sample: Dictionary in row.samples:
		observed.activity = observed.activity or bool(sample.activity_active)
		observed.greeting = observed.greeting or float(sample.greeting_remaining) > 0.0
		observed.dialogue = observed.dialogue or bool(sample.dialogue_owned)
		observed.threat = observed.threat or float(sample.reaction_time) > 0.0
	# Capture success describes usable frames, not a passing performance.
	# The runner applies the same strict behavior validator to both modes;
	# baseline observations retain shortcomings as explicit limitations.
	if scenario == "approach" and not observed.greeting:
		# Verified supported sleep intentionally does not acknowledge an approach.
		var sleeping := str(row.initial.get("attention", "")) == "sleep" and bool(row.initial.get("rest_supported",false))
		observed["sleep_preserved"] = sleeping
	return observed

func _restore_hold(profile: Dictionary, prior: Variant) -> void:
	if profile.is_empty(): return
	if prior == null: profile.erase("hold_activity")
	else: profile["hold_activity"] = prior

func _actor_sample(actor: Node3D, entry: Dictionary) -> Dictionary:
	var driver: Node = entry.get("driver")
	var face: Node = entry.get("face")
	var sample := {"at_ms":Time.get_ticks_msec()-elapsed_start,"position":_v3(actor.global_position),"player":_v3(game.player.global_position),
		"visible":actor.is_visible_in_tree(),"life_state":str(actor.get_meta("life_state","")),"activity":str(entry.profile.get("activity","")),
		"activity_active":bool(entry.get("activity_active",false)),"greeting_remaining":float(entry.get("greeting_remaining",0.0)),
		"reaction":str(entry.get("reaction","")),"reaction_time":float(entry.get("reaction_time",0.0)),
		"owner":str(actor.get_meta("locomotion_owner","")),"dialogue_owned":actor.has_meta("cast_dialogue_owner"),
		"station":str(entry.get("station","")),"weather":str(game.day_night.current_weather),"time":game.day_night.get_time()}
	sample["rest_supported"] = false
	if is_instance_valid(driver):
		sample["motion_state"] = str(driver.get("current_state"))
		sample["presentation"] = str(driver.get("presentation_state"))
		if driver.has_method("life_motion_sample"): sample["native_life"] = driver.life_motion_sample()
		var modifier: Node = driver.get("life_modifier")
		if is_instance_valid(modifier):
			var rest: Variant = modifier.get("rest_anchor")
			if rest is Dictionary:
				var anchor_ref: WeakRef = rest.get("node")
				sample["rest_supported"] = anchor_ref != null and is_instance_valid(anchor_ref.get_ref()) and str(rest.get("kind","")) == "seated"
			var contacts: Variant = modifier.get("last_contact_samples")
			if contacts is Array or contacts is Dictionary: sample["contact_probes"] = _json_value(contacts)
			var tool: Node3D = modifier.get("tool")
			if is_instance_valid(tool):
				sample["tool_visible"] = tool.is_visible_in_tree()
				sample["tool_owned"] = modifier.get("owns_tool") == true
	if is_instance_valid(face):
		sample["expression"] = str(face.get("expression"))
		if face.has_method("capture_attention"):
			var attention: Dictionary = face.capture_attention()
			sample["attention"] = str(attention.get("mode",""))
			var focus: Variant = attention.get("point")
			if focus is Vector3: sample["attention_point"] = _v3(focus)
	return sample

func _stage_camera(actor: Node3D) -> bool:
	var rejected: Array = []
	var tries := 0
	for distance in [3.0,2.3,3.8,1.8]:
		for angle in [0.0,0.3,-0.3,0.65,-0.65,1.0,-1.0,1.4,-1.4]:
			for height in [1.5,1.9]:
				tries += 1
				camera_offset = _forward(actor).rotated(Vector3.UP,angle)*distance + Vector3.UP*height
				camera.global_position = actor.global_position + camera_offset
				camera.look_at(actor.global_position + Vector3.UP*camera_target_height)
				camera.make_current()
				var issue := _validate_actor_camera(actor)
				if issue.is_empty():
					camera_checks = {"tries":tries,"rejected":rejected,"actor_projection_and_visual_rays":"pass"}
					return true
				if rejected.size() < 8: rejected.append(issue)
	camera_checks = {"tries":tries,"rejected":rejected}
	return false

func _validate_actor_camera(actor: Node3D) -> Dictionary:
	return geometry.validate_actor(camera,actor,viewport,_forward(actor))

func _camera_record() -> Dictionary:
	return {"position":_v3(camera.global_position),"rotation":_v3(camera.global_rotation),"fov":camera.fov,"near":camera.near,"far":camera.far,
		"cull_mask":camera.cull_mask,"keep_aspect":camera.keep_aspect,"projection":camera.projection,"current":camera.is_current(),"viewport":[viewport.x,viewport.y]}

func _performance() -> Array:
	var anchors: Array = []
	# Preflight every anchor before timing any of them. Geometry validation is never measured.
	for view_anchor: Vector3 in [Vector3(0,1,7),Vector3(3,1,-4),Vector3(6,1,2)]:
		var feet: Vector3 = geometry.support_point(game.player.get_world_3d().direct_space_state,view_anchor-Vector3.UP,[game.player.get_rid()],0.65)
		if not feet.is_finite() or not game.spatial_service.is_walkable_position(feet,0.55,game.spatial_service.bank_for(feet)):
			_fail("Unsafe performance feet anchor: " + str(view_anchor))
			return []
		var point := feet + Vector3.UP*0.025
		var target := view_anchor + Vector3(0,0.4,-3)
		var selected: Dictionary = {}
		for offset: Vector3 in [Vector3(0,2.1,4.5),Vector3(4.5,2.1,0),Vector3(-4.5,2.1,0),Vector3(0,2.1,-4.5)]:
			camera.global_position = view_anchor + offset
			camera.look_at(target)
			camera.make_current()
			if geometry.obstruction(camera.global_position,target,null,camera.cull_mask).is_empty():
				selected = {"player":_v3(point),"target":_v3(target),"camera":_camera_record()}
				break
		if selected.is_empty():
			_fail("No visually clear performance view: " + str(point))
			return []
		anchors.append(selected)
	report["performance_preflight"] = anchors.duplicate(true)
	var reference := str(options.get("reference-report", ""))
	if reference != "":
		var previous: Variant = JSON.parse_string(FileAccess.get_file_as_string(reference))
		if not previous is Dictionary or JSON.stringify(previous.get("performance_preflight", [])) != JSON.stringify(anchors):
			_fail("Performance camera/config differs from reference report")
			return []
	var rows: Array = []
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	for anchor: Dictionary in anchors:
		game.player.global_position = _from_v3(anchor.player)
		game.player.velocity = Vector3.ZERO
		camera.global_position = _from_v3(anchor.camera.position)
		camera.global_rotation = _from_v3(anchor.camera.rotation)
		camera.make_current()
		await _wait_seconds(2.5)
		for repeat in range(3):
			var frames: Array[float] = []
			var cpu := 0.0
			var draws := 0.0
			var deadline := Time.get_ticks_msec() + 5000
			var previous := Time.get_ticks_usec()
			while Time.get_ticks_msec() < deadline:
				await process_frame
				var now := Time.get_ticks_usec()
				frames.append(float(now-previous)/1000.0)
				previous = now
				cpu += Performance.get_monitor(Performance.TIME_PROCESS)*1000.0
				draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			frames.sort()
			if not frames.is_empty():
				rows.append({"anchor":anchor,"repeat":repeat,"samples":frames.size(),"p50_ms":frames[int(frames.size()*0.5)],
					"p95_ms":frames[mini(frames.size()-1,int(frames.size()*0.95))],"process_ms":cpu/frames.size(),"draw_calls":draws/frames.size(),"actual_camera":_camera_record(),"actual_player":_v3(game.player.global_position)})
	Engine.max_fps = 60
	return rows

func _wait_seconds(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds*1000.0)
	while Time.get_ticks_msec() < until: await process_frame

func _v3(value: Vector3) -> Array:
	return [value.x,value.y,value.z]

func _json_value(value: Variant) -> Variant:
	if value is Vector3: return _v3(value)
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value: result[str(key)] = _json_value(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value: result.append(_json_value(item))
		return result
	return value

func _from_v3(value: Array) -> Vector3:
	return Vector3(float(value[0]),float(value[1]),float(value[2]))

func _fail(message: String) -> void:
	report.failures.append(message)
	push_error(message)

func _shutdown() -> void:
	if is_instance_valid(life) and not saved_scene_clocks.is_empty():
		life.world_scene_clock = saved_scene_clocks.world
		life.social_cooldown = saved_scene_clocks.social
		life.line_cooldown = saved_scene_clocks.line
	if is_instance_valid(game):
		game.prepare_resource_shutdown()
		for index in range(20): await process_frame
		game.finalize_resource_shutdown()
		for index in range(12): await process_frame
		game.queue_free()
		for index in range(8): await process_frame
		RenderingServer.force_sync()
	_finish(0 if report.failures.is_empty() else 1)

func _finish(code: int) -> void:
	report["status"] = "pass" if code == 0 else "fail"
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print("LIVING CAST CAPTURE: " + str(report.status))
	quit(code)
