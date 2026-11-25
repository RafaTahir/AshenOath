extends SceneTree
## Source-authoring observation in real constructed levels. Fixture staging is
## explicit; these images do not establish earned progress or input acceptance.
const Palette = preload("res://scripts/views/monster_material_view.gd")
const PigmentMaterial = preload("res://scripts/views/monster_pigment_material.gd")
const Geometry = preload("res://tools/living_cast_capture_geometry.gd")
const ViewportCoordinates = preload("res://tools/qa_viewport_coordinates.gd")
const Composition = preload("res://scripts/zone_composition_router.gd")
const ENEMIES := {
	"M01": {"role":"ghoulkin", "zone":"wychwood"},
	"M02": {"role":"wychwood_stalker", "zone":"wychwood"},
	"M19": {"role":"wychwood_raider", "zone":"wychwood"},
	"M20": {"role":"wychwood_brute", "zone":"wychwood"},
	"M05": {"role":"bell_eater", "zone":"greyfen", "anchor":Vector3(10,0.8,8), "owner":"res://scripts/views/combat_boss_view.gd:_ensure_bell_eater"},
	"M07": {"role":"ashwing", "zone":"old_mill", "anchor":Vector3(5,1,-6.5), "owner":"res://scripts/zones/campaign_wilderness_section.gd:_build_mill_encounter"},
	"M03": {"role":"bog_wretch", "zone":"wychwood", "anchor":Vector3(0,0,-9), "owner":"res://scripts/saga_encounters.gd:activate/BOG_CENTER"},
	"M06": {"role":"rootbound_colossus", "zone":"deep_wood", "anchor":Vector3(0,0.8,-10.5), "owner":"res://scripts/zones/campaign_wilderness_section.gd:_build_deep_wood_encounter"},
	"M04": {"role":"gravebound_knight", "zone":"ruins", "anchor":Vector3(3,0.8,-3), "owner":"res://scripts/zones/ruins_section.gd:conditional_legacy_encounter"},
	"M08": {"role":"white_hart_avatar", "zone":"hart_glade", "anchor":Vector3(0,0.8,-7), "owner":"res://scripts/zones/campaign_finale_section.gd:_build_hart_presence"},
}
const ORDER := ["M01","M02","M19","M20","M11","M15","M05","M07","M09","M10","M03","M18","M13","M06","M14","M04","M12","M16","M08","M17"]
const IDENTITY := ["M02", "M09", "M11"]
var options: Dictionary = {}
var output := ""
var game: Node
var camera: Camera3D
var geometry: RefCounted
var viewport := Vector2i(1280, 720)
var window_size := Vector2i(1280, 720)
var profiles: Dictionary = {}
var ecology: Dictionary = {}
var current_environment := "day"
var current_environment_state: Dictionary = {}
var particle_speeds: Array[Dictionary] = []
var owned_fixture_scope: Dictionary = {}
var report := {"kind":"native_monster_material_level_observation", "failures":[], "frames":[], "specimens":[],
	"visual_acceptance":false, "earned_progress_acceptance":false, "real_input_acceptance":false,
	"mode":"source_authoring_preview", "frozen_export_verified":false,
	"staging":"real main/new journey and zone construction; authored actor placement attempted first; explicitly recorded floor-verified clearing fixture fallback when whole-body framing is blocked; missing quest enemies may be fixture-spawned through ZoneBuildContext; other actors hidden during palette comparison"}

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			var pair := arg.trim_prefix("--").split("=", true, 1)
			options[pair[0]] = pair[1]
	output = str(options.get("output", ""))
	if output.is_empty():
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var profile := str(options.get("profile", ""))
	if profile.is_empty() or not OS.get_user_data_dir().replace("\\", "/").ends_with(profile):
		_fail("Disposable profile must resolve before renderer initialization")
		_finish()
		return
	var desktop := OS.get_environment("ASHENOATH_CAPTURE_DESKTOP")
	if DisplayServer.get_name().to_lower() == "headless" or not desktop.begins_with("AshenOathCapture_") or not DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS):
		_fail("An unfocusable private-desktop graphical launcher is required")
		_finish()
		return
	if options.get("viewport", "desktop") == "touch": window_size = Vector2i(960, 540)
	# Preserve production's 1280x720 internal canvas. Touch QA changes only the
	# native client window; raw renderer PNGs truthfully remain 1280x720.
	root.size = window_size
	DisplayServer.window_set_size(window_size)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 60
	report["user_data_dir"] = OS.get_user_data_dir()
	report["viewport"] = [viewport.x, viewport.y]
	report["window_size"] = [window_size.x,window_size.y]
	report["render_viewport"] = [viewport.x,viewport.y]
	report["viewport_policy"] = "production_internal_canvas_with_native_window_stretch"
	report["background_rendered"] = {"desktop":desktop, "no_focus":true, "headless":false}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(Palette.PROFILE_PATH))
	if not parsed is Dictionary:
		_fail("Palette profiles are unavailable")
		_finish()
		return
	profiles = parsed.assets
	var sightings: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/design_pack_ecology.json"))
	if sightings is Dictionary:
		for row: Dictionary in sightings.get("sightings", []): ecology[str(row.design)] = row
	var requested: Array[String] = []
	if str(options.get("species", "all")) == "all": requested.assign(ORDER)
	else: requested.assign(str(options.species).split(","))
	for id: String in requested:
		if not profiles.has(id) or (not ENEMIES.has(id) and not ecology.has(id)):
			_fail("Unregistered QA monster target before world construction: "+id)
			_finish()
			return
		var zone: String = str(ENEMIES[id].zone) if ENEMIES.has(id) else str(ecology[id].zone)
		if not Composition.supports(zone):
			_fail("Unregistered QA realm before world construction: %s / %s" % [id,zone])
			_finish()
			return
	report["target_registry"] = {"validated_before_world_construction":true,"registered_zones":Composition.registered_zones()}
	call_deferred("_run")

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	var deadline := Time.get_ticks_msec() + 180000
	while not game.opening_startup_metrics.has("menu_ready_ms") and Time.get_ticks_msec() < deadline: await process_frame
	if not game.opening_startup_metrics.has("menu_ready_ms"):
		_fail("Real main menu readiness deadline")
		await _shutdown()
		return
	game.settings.set_quality_preset("balanced")
	game._new_game()
	deadline = Time.get_ticks_msec() + 180000
	while Time.get_ticks_msec() < deadline:
		if is_instance_valid(game.zone_root):
			var opening: Node = game.zone_root.find_child("GreyfenLifeController", true, false)
			if opening != null and bool(game.zone_root.get_meta("opening_scene_active", false)): opening.finish_opening_scene("skipped")
		if game.game_started and is_instance_valid(game.player) and game.player.can_control and not game.opening_scene_pending: break
		await process_frame
	if not game.game_started or not is_instance_valid(game.player) or not game.player.can_control:
		_fail("New disposable journey did not reach playable Greyfen")
		await _shutdown()
		return
	if not _check_dimensions("new_game_playable"):
		await _shutdown()
		return
	var mechanics_path := str(options.get("mechanics-script", ""))
	if not mechanics_path.is_empty():
		var mechanics: RefCounted = load(mechanics_path).new()
		DirAccess.make_dir_recursive_absolute(output.path_join("mechanics"))
		report["mechanics"] = await mechanics.run(game, output.path_join("mechanics"), window_size)
		# Early readiness failures legitimately return before a module's normal
		# report writer. Persist the exact returned outcome on every path so the
		# runner can hash failed mechanics and successful presentation separately.
		var mechanics_file := FileAccess.open(output.path_join("mechanics/report.json"),FileAccess.WRITE)
		if mechanics_file == null: _fail("Could not persist returned mechanics outcome")
		else: mechanics_file.store_string(JSON.stringify(report.mechanics,"\t")+"\n")
		if not bool((report.mechanics as Dictionary).get("passed", false)): _fail("Focused mechanics fixture did not pass; see mechanics report")
	Engine.time_scale = 1.0
	paused = false
	game.process_mode = Node.PROCESS_MODE_INHERIT
	game.day_night.set_time_lock(true)
	game.camera_rig.set_process(false)
	game.camera_rig.set_physics_process(false)
	camera = Camera3D.new()
	camera.name = "MonsterMaterialLevelCamera"
	# This camera is a fixed authoring fixture, not a physics-driven gameplay
	# camera. World time is frozen between material variants; interpolation must
	# not retain its previous physics-frame transform while projection is tested.
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.fov = 48.0
	camera.near = 0.035
	camera.far = game.camera_rig.camera.far
	camera.cull_mask = game.camera_rig.camera.cull_mask
	root.add_child(camera)
	camera.make_current()
	geometry = Geometry.new()
	report["configuration"] = {"quality":"balanced", "renderer":RenderingServer.get_current_rendering_method(),
		"driver":RenderingServer.get_current_rendering_driver_name(), "gpu":RenderingServer.get_video_adapter_name(),
		"gpu_vendor":RenderingServer.get_video_adapter_vendor(), "gpu_api":RenderingServer.get_video_adapter_api_version(),
		"window_mode":"background-rendered", "frame_limit":Engine.max_fps, "physics_ticks_per_second":Engine.physics_ticks_per_second}
	var requested: Array[String] = []
	if str(options.get("species", "all")) == "all": requested.assign(ORDER)
	else: requested.assign(str(options.species).split(","))
	report["requested_species"] = requested
	var zones: Dictionary = {}
	for id: String in requested:
		if not profiles.has(id) or (not ENEMIES.has(id) and not ecology.has(id)):
			_fail("Unknown native species: " + id)
			continue
		var zone := str(ENEMIES[id].zone) if ENEMIES.has(id) else str(ecology[id].zone)
		if not zones.has(zone): zones[zone] = []
		(zones[zone] as Array).append(id)
	for zone: String in zones:
		if not await _load_region(zone): continue
		for environment: String in str(options.get("environments", "day")).split(","):
			await _set_environment(environment)
			for id: String in zones[zone]:
				await _specimen(id, zone)
	await _shutdown()

func _load_region(zone: String) -> bool:
	_release_owned_fixture()
	_restore_particle_speeds("before_region_load")
	Engine.time_scale = 1.0
	game.process_mode = Node.PROCESS_MODE_INHERIT
	game.player.visible = true
	if str(game.current_zone_id) != zone: game._load_zone(zone)
	var deadline := Time.get_ticks_msec() + 180000
	while Time.get_ticks_msec() < deadline:
		if str(game.current_zone_id) == zone and not game.zone_transition_pending and not game.zone_load_request_pending and is_instance_valid(game.zone_root) and is_instance_valid(game.player) and game.player.can_control:
			for _index in range(4): await process_frame
			var retirement_start := Time.get_ticks_msec()
			var before := _residency_snapshot()
			var waited_frames := 0
			while int(game.zone_residency.pending_zone_retirements) > 0 and Time.get_ticks_msec() < deadline:
				# The source comparison may suspend fixture opponents while the
				# real residency owner finishes its asynchronous retirement work.
				# Keep normal world processing until its exact pending count drains.
				for enemy: Node in game.active_enemies:
					if is_instance_valid(enemy): enemy.set_encounter_active(false)
				await process_frame
				waited_frames += 1
			var after := _residency_snapshot()
			var lifecycle: Array = report.get("region_lifecycle", [])
			lifecycle.append({"zone":zone,"before":before,"after":after,"waited_process_frames":waited_frames,
				"elapsed_ms":Time.get_ticks_msec()-retirement_start,"deadline":"shared existing region preparation deadline",
				"normal_world_processing":game.process_mode==Node.PROCESS_MODE_INHERIT,"fixture_opponents_suspended_during_wait":true})
			report["region_lifecycle"] = lifecycle
			if int(after.pending_retirements) != 0:
				_fail("Actual residency owner did not finish retirement within region preparation deadline: " + zone)
				return false
			if not _check_dimensions("region_playable:"+zone): return false
			for layer: CanvasLayer in root.find_children("*", "CanvasLayer", true, false): layer.visible = false
			camera.make_current()
			return true
		await process_frame
	_fail("Real region construction readiness deadline: " + zone)
	return false

func _dimension_record() -> Dictionary:
	var actual_window := DisplayServer.window_get_size(root.get_window_id())
	var logical_size := root.get_visible_rect().size
	return {"window_size":[root.size.x,root.size.y],"window_client_size":[actual_window.x,actual_window.y],
		"content_scale_size":[root.content_scale_size.x,root.content_scale_size.y],
		"content_scale_mode":root.content_scale_mode,"visible_rect_size":_v2(logical_size),
		"render_texture_size":_v2(root.get_texture().get_size()),
		"mapping":ViewportCoordinates.contract(logical_size,Vector2(actual_window)),
		"raw_png_policy":"unresampled native render texture; physical window and internal render dimensions are distinct"}

func _check_dimensions(phase: String) -> bool:
	var record := _dimension_record()
	var passed: bool = root.size == window_size and Vector2i(DisplayServer.window_get_size(root.get_window_id())) == window_size \
		and root.content_scale_size == viewport and root.get_visible_rect().size == Vector2(viewport) \
		and root.get_texture().get_size() == Vector2(viewport) and bool(record.mapping.valid)
	record["phase"] = phase
	record["passed"] = passed
	var checks: Array = report.get("dimension_checks",[])
	checks.append(record)
	report["dimension_checks"] = checks
	if not passed: _fail("Production canvas/native window dimension contract failed: "+phase)
	return passed

func _residency_snapshot() -> Dictionary:
	var residency: Node = game.zone_residency
	var roots: Array[String] = []
	for index in residency.retired_zone_roots.size():
		var entry: Variant = residency.retired_zone_roots[index]
		if is_instance_valid(entry): roots.append(str(entry.get_path()))
	return {"pending_retirements":int(residency.pending_zone_retirements),"live_retired_roots":roots,
		"route_cache_ids":residency.route_zone_cache.keys(),"resource_anchors":residency.skinned_resource_anchors.size(),
		"retired_material_anchors":residency.retired_material_anchors.size(),
		"engine_static_bytes":OS.get_static_memory_usage(),"engine_static_peak_bytes":OS.get_static_memory_peak_usage(),
		"render_video_memory_bytes":int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
		"memory_scope":"engine/native render counters; not operating system available RAM"}

func _set_environment(value: String) -> void:
	current_environment = value
	var restoration := _restore_particle_speeds("before_environment")
	# A longer weather warmup must not let an invisible, fixture-excluded
	# opponent attack the disposable player while this visual comparison stages.
	var suspended := 0
	for enemy: Node in game.active_enemies:
		if is_instance_valid(enemy):
			enemy.set_encounter_active(false)
			suspended += 1
	Engine.time_scale = 1.0
	game.process_mode = Node.PROCESS_MODE_INHERIT
	game.day_night.set_time(60.0 if value == "night" else 600.0, 1 if value == "rain" else 0)
	var expected_weather := "rain" if value == "rain" else "clear"
	var started := Time.get_ticks_msec()
	var warmup_ms := 1600 if value == "rain" else 500
	var deadline := started + 6000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if str(game.day_night.current_weather) == expected_weather and Time.get_ticks_msec() - started >= warmup_ms: break
	var ready := str(game.day_night.current_weather) == expected_weather and Time.get_ticks_msec() - started >= warmup_ms
	if not ready: _fail("Weather owner readiness deadline: " + value)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	Engine.time_scale = 0.0
	current_environment_state = {"requested":value, "expected_weather":expected_weather, "weather_owner_ready":ready,
		"actual_weather":str(game.day_night.current_weather), "world_time_minutes":float(game.day_night.get_time()),
		"day_count":int(game.day_night.day_count), "warmup_ms":Time.get_ticks_msec()-started,
		"restoration":restoration, "fixture_opponents_suspended":suspended, "particles":_freeze_particle_speeds(),
		"limitation":"weather owner and emitter state recorded; image review establishes visible rain, not a particle-count assertion"}
	camera.make_current()

func _restore_particle_speeds(phase: String) -> Dictionary:
	var retained: Array[Dictionary] = []
	var restored := 0
	var freed := 0
	for saved: Dictionary in particle_speeds:
		var particles: Node = (saved.reference as WeakRef).get_ref()
		if not is_instance_valid(particles):
			freed += 1
			continue
		if particles is GPUParticles3D or particles is CPUParticles3D:
			particles.speed_scale = float(saved.speed)
			retained.append(saved)
			restored += 1
	particle_speeds = retained
	var record := {"phase":phase, "restored":restored, "discarded_freed_nodes":freed, "retained_weak_references":retained.size()}
	var history: Array = report.get("particle_restorations", [])
	history.append(record)
	report["particle_restorations"] = history
	return record

func _freeze_particle_speeds() -> Array:
	var records: Array = []
	var particles_to_freeze: Array = game.find_children("*", "GPUParticles3D", true, false)
	particles_to_freeze.append_array(game.find_children("*", "CPUParticles3D", true, false))
	for particles: Node in particles_to_freeze:
		var saved_index := -1
		for index in particle_speeds.size():
			if (particle_speeds[index].reference as WeakRef).get_ref() == particles:
				saved_index = index
				break
		var speed: float = particles.speed_scale
		var saved := {"reference":weakref(particles), "speed":speed}
		if saved_index < 0: particle_speeds.append(saved)
		else: particle_speeds[saved_index] = saved
		records.append({"node":str(particles.get_path()), "class":particles.get_class(), "original_speed_scale":speed,
			"emitting":bool(particles.emitting), "amount":int(particles.amount), "frozen_speed_scale":0.0})
		particles.speed_scale = 0.0
	return records

const HUNT_GEAR := {
	"M01":"res://assets/characters/wychwood_hunters/m01_shroud.res",
	"M02":"res://assets/characters/wychwood_hunters/m02_vanes.res",
	"M19":"res://assets/characters/wychwood_raider_regalia.res",
	"M20":"res://assets/characters/wychwood_brute_regalia.res",
}

func _authored_hunt_gear(id: String, mesh: MeshInstance3D, surface: int) -> bool:
	if mesh.get_active_material(surface) != mesh.mesh.surface_get_material(surface):
		return false
	if id == "M19" and mesh.mesh.resource_path == "res://assets_external/environment/forest/Wychwood_RaiderTally.res":
		var socket := mesh.get_parent() as BoneAttachment3D
		return socket != null and socket.name == &"CartersWristCord"
	return HUNT_GEAR.has(id) and mesh.skin != null and mesh.mesh.resource_path == HUNT_GEAR[id]

func _authored_grave_weapon(mesh: MeshInstance3D, source_root: Node3D, surface: int) -> bool:
	var ancestor: Node = mesh
	while ancestor != null and ancestor != source_root:
		if ancestor.scene_file_path == "res://assets/characters/grave_tithe_scythe.scn":
			var socket := ancestor.get_parent() as BoneAttachment3D
			return socket != null and socket.name == &"GraveTitheGrip" and socket.bone_name == &"hand_r" and mesh.get_active_material(surface) == mesh.mesh.surface_get_material(surface)
		ancestor = ancestor.get_parent()
	return false

func _specimen(id: String, zone: String) -> void:
	var selected := _select_actor(id)
	if selected.is_empty():
		_fail("No actual or owner-constructed actor: " + id + " in " + zone)
		return
	var actor := selected.actor as Node3D
	var authored_actor_transform := actor.global_transform
	var source_root := _palette_root(actor, str(profiles[id].source))
	if source_root == null:
		_fail("Native palette root is missing: " + id)
		_release_owned_fixture()
		return
	_isolate_actor(actor, source_root)
	var geometry_report: Dictionary = geometry.build(game.zone_root, game.player)
	var entries: Array[Dictionary] = []
	var hunt_gear_surfaces := 0
	for mesh: MeshInstance3D in source_root.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null: continue
		for surface in mesh.mesh.get_surface_count():
			var variant: Material = mesh.get_active_material(surface)
			var original: BaseMaterial3D
			var identity: Material
			var retained_native := false
			if variant is PigmentMaterial:
				original = variant.native_material
				var private_identity := variant.duplicate(false) as PigmentMaterial
				private_identity.set_shader_parameter("pigment_strength", 0.0)
				identity = private_identity
			elif variant is BaseMaterial3D:
				# A zero-strength recipe deliberately retains the complete original
				# layered PBR/alpha/depth material. It is still part of the captured
				# surface inventory and must stay exactly native in every mode.
				original = variant
				var recipes: Dictionary = profiles[id].materials
				var hunt_gear := _authored_hunt_gear(id, mesh, surface)
				if hunt_gear and mesh.skin != null and mesh.mesh.resource_path == HUNT_GEAR.get(id, ""):
					hunt_gear_surfaces += 1
				var native_gear := (id == "M04" and _authored_grave_weapon(mesh, source_root, surface)) or hunt_gear
				if not native_gear and (not recipes.has(original.resource_name) or float(recipes[original.resource_name].strength) != 0.0):
					_fail("Unexpected ungraded native material: %s [%s]" % [id,original.resource_name])
					return
				identity = original
				retained_native = true
			if original == null or identity == null:
				_fail("Native material provenance missing: " + id)
				return
			entries.append({"mesh":mesh, "surface":surface, "variant":variant, "original":original, "identity":identity,
				"retained_native":retained_native})
	if str(options.get("require-hunt-gear", "false")) == "true" and HUNT_GEAR.has(id):
		if hunt_gear_surfaces == 0 or not actor.enemy_presence_view.has_hunt_performance:
			_fail("Missing fitted rig on live actor: " + id)
			return
		for sample: Array in [[7.9, 30.0], [9.0, 30.0], [10.0, 12.0], [9.0, 12.0]]:
			actor.enemy_presence_view.update_hunt_pose_rate(sample[0])
			if not is_equal_approx(actor.animation_driver.manual_update_interval, 1.0 / float(sample[1])):
				_fail("Incorrect live hunter pose rate: " + id)
				return
	var retained_surfaces := 0
	for entry: Dictionary in entries:
		if bool(entry.retained_native): retained_surfaces += 1
	var specimen := {"asset":id, "role":str(selected.role), "zone":zone, "environment":current_environment,
		"source":str(profiles[id].source), "source_sha256":str(profiles[id].source_sha256),
		"placement":str(selected.placement), "actor_position":_v3(actor.global_position), "actor_path":str(actor.get_path()),
		"target_owner_evidence":selected.get("owner", "current design_pack_ecology sighting and actual actor"),
		"fixture_spawn":selected.get("fixture_spawn", {}),
		"geometry_validation":geometry_report, "visible_skeletons":_visible_skeletons(), "collision_shapes":_collision_records(actor),
		"material_policy":{"total_surfaces":entries.size(), "graded_opaque_surfaces":entries.size()-retained_surfaces,
			"retained_native_surfaces":retained_surfaces, "fitted_gear_surfaces":hunt_gear_surfaces, "retained_surface_modes":"exact original material in all modes; no replacement shader"},
		"frames":[], "poses":[]}
	if int(specimen.visible_skeletons) > 10: _fail("Visible skeleton budget exceeded: " + id)
	for pose_name: String in str(options.get("poses", "idle")).split(","):
		actor.global_transform = authored_actor_transform
		actor.reset_physics_interpolation()
		source_root.reset_physics_interpolation()
		var pose := _stage_pose(actor, pose_name, ENEMIES.has(id))
		if pose.is_empty():
			_fail("Could not stage native pose: " + id + " / " + pose_name)
			continue
		# Settle the scheduled skeleton/skin upload before baking bounds or
		# comparing the material-only modes against the same final native pose.
		for _settle in range(2): await process_frame
		await RenderingServer.frame_post_draw
		var bounds := _baked_bounds(source_root)
		var lit_clearing: bool = id in str(options.get("lit-clearing", "")).split(",", false)
		var dry_floor: bool = id in str(options.get("dry-floor-seat", "")).split(",",false)
		var camera_check := _stage_camera(actor, bounds, _baked_surface_points(source_root), lit_clearing)
		if dry_floor: await _habitat_images(id,zone,pose_name,actor,source_root,entries,bounds,camera_check)
		if lit_clearing or dry_floor or not bool(camera_check.get("passed", false)):
			var authored_check := camera_check.duplicate(true)
			if not bool(camera_check.get("passed", false)):
				await _failed_framing_image(id, zone, pose_name, bounds, camera_check, source_root)
			if lit_clearing or dry_floor or str(options.get("framing-policy", "clearing-fallback")) == "clearing-fallback":
				var restage: Dictionary = await _restage_in_clearing(actor, source_root, zone, lit_clearing,dry_floor)
				pose["fixture_restage"] = restage
				if bool(restage.get("passed", false)):
					bounds = _baked_bounds(source_root)
					camera_check = restage.camera_check
					pose["authored_placement_camera_check"] = authored_check
					specimen["framing_restage"] = restage
				elif lit_clearing or dry_floor:
					camera_check = {"passed":false,"reason":"requested native-lit front/threequarter clearing was unavailable"}
			if not bool(camera_check.get("passed", false)):
				_fail("Actual-level whole-body camera remains obstructed: " + id)
				(specimen.poses as Array).append({"requested":pose_name, "camera_check":camera_check, "bounds":_aabb(bounds)})
				continue
		pose["camera_check"] = camera_check
		pose["bounds"] = _aabb(bounds)
		var before_hash := _pose_hash(source_root)
		var modes: Array[String] = ["original", "candidate"]
		if id in IDENTITY: modes = ["original", "identity", "candidate"]
		if id == "M11" and str(options.get("isolate-m11", "false")) == "true": modes = ["original", "identity_body", "identity_wing", "identity", "candidate"]
		for mode: String in modes:
			_set_mode(entries, mode)
			for _index in range(3): await process_frame
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			var name := "%s_%s_%s_%s_%s.png" % [id, zone, current_environment, pose_name, mode]
			var target := output.path_join(name)
			if image == null or image.get_size() != viewport or image.save_png(target) != OK:
				_fail("Viewport PNG capture failed: " + name)
				continue
			var now_hash := _pose_hash(source_root)
			if now_hash != before_hash: _fail("Fixed native pose changed between material modes: " + id)
			var frame := {"asset":id, "zone":zone, "environment":current_environment, "pose_request":pose_name,
				"mode":mode, "path":target, "camera":_camera_record(), "pose":pose.duplicate(true),
				"pose_sha256":now_hash, "source_geometry_unchanged":now_hash == before_hash,
				"projection":_project_bounds(bounds), "materials":_material_records(entries), "lighting":_lighting_record(),
				"freeze":{"main_process_disabled":game.process_mode == Node.PROCESS_MODE_DISABLED, "time_scale":Engine.time_scale,
					"native_pose":"direct authored clip seek; animation trees and player paused", "weather_setup":current_environment_state.duplicate(true),
					"background_motion":"shader TIME/temporal noise may still differ; measured separately"}}
			(report.frames as Array).append(frame)
			(specimen.frames as Array).append(name)
		if pose_name == "action" and ENEMIES.has(id) and str(options.get("motion-reels", "false")) == "true":
			pose["strike_reel"] = await _strike_reel(actor, id, zone, pose)
		(specimen.poses as Array).append(pose)
		if str(options.get("performance", "false")) == "true" and id in IDENTITY and pose_name == "idle":
			specimen["paired_render_cost"] = await _render_cost(entries)
	_set_mode(entries, "candidate")
	(report.specimens as Array).append(specimen)
	actor.global_transform = authored_actor_transform
	actor.reset_physics_interpolation()
	_release_owned_fixture()
	print("MONSTER MATERIAL LEVEL CAPTURED: %s / %s / %s" % [id, zone, current_environment])

func _select_actor(id: String) -> Dictionary:
	if ecology.has(id):
		for node: Node in game.zone_root.find_children("*", "Node3D", true, false):
			var sighting: Dictionary = node.get_meta("design_ecology", {})
			if str(sighting.get("design", "")) == id: return {"actor":node, "role":str(sighting.role), "placement":"authored_ecology_actor_and_position"}
		return {}
	var definition: Dictionary = ENEMIES[id]
	for enemy: Node in game.active_enemies:
		if is_instance_valid(enemy) and str(enemy.enemy_id) == str(definition.role) and not enemy.dead:
			enemy.set_encounter_active(false)
			return {"actor":enemy, "role":str(definition.role), "placement":"existing_level_enemy", "owner":str(definition.get("owner", "current existing enemy setup"))}
	if id == "M03": return _spawn_owned_bog_fixture(definition)
	# The source-authoring preview may inspect a boss before its quest gate is
	# earned, using the real construction owner. This is not progression QA.
	var point: Vector3 = definition.get("anchor", game.player.global_position)
	var requested_anchor := point
	var found := false
	for offset: Vector3 in [Vector3.ZERO,Vector3(0,0,-4),Vector3(3,0,-3),Vector3(-3,0,-3),Vector3(0,0,-7),Vector3(4,0,0),Vector3(-4,0,0)]:
		var candidate: Vector3 = geometry.support_point(game.player.get_world_3d().direct_space_state, point + offset, [game.player.get_rid()], 1.5)
		if candidate.is_finite() and game.spatial_service.is_walkable_position(candidate, 0.5, game.spatial_service.bank_for(candidate)):
			point = candidate + Vector3.UP*0.02
			found = true
			break
	if not found: return {}
	var context := ZoneBuildContext.new(game, str(definition.zone))
	var enemy: Node3D = context.spawn_enemy(str(definition.role), point)
	if enemy == null: return {}
	enemy.set_encounter_active(false)
	enemy.set_meta("monster_capture_fixture_spawn", true)
	return {"actor":enemy, "role":str(definition.role), "placement":"fixture_enemy_via_ZoneBuildContext_at_verified_real_floor",
		"owner":str(definition.get("owner", "current enemy setup")),
		"fixture_spawn":{"requested_owner_anchor":_v3(requested_anchor),"verified_floor_request":_v3(point),"actual_position":_v3(enemy.global_position),
			"quest_flags_or_progress_awarded":false,"original_arena_anchor_used":is_equal_approx(point.x,requested_anchor.x) and is_equal_approx(point.z,requested_anchor.z)}}

func _spawn_owned_bog_fixture(definition: Dictionary) -> Dictionary:
	# Use the production construction authority at its authored arena point.
	# A generic humanoid/NPC clearance predicate is diagnostic, not a boss gate.
	var audit: RefCounted = load("res://tools/capture_bog_wretch_wychwood.gd").new()
	audit._game = game
	audit._tree = self
	audit._original_pool = game.active_enemies.duplicate()
	for actor: Node3D in audit._original_pool:
		if is_instance_valid(actor): audit._snapshots.append({"actor":actor,"active":actor.encounter_active})
	audit._generic_anchor_preflight("original_palette_selector_pool")
	for snapshot: Dictionary in audit._snapshots: snapshot.actor.set_encounter_active(false)
	game.active_enemies.clear()
	audit._generic_anchor_preflight("scoped_palette_selector_pool")
	var before: Dictionary = audit._progression_snapshot()
	var actor: Node3D = game._spawn_enemy(str(definition.role), definition.anchor)
	audit._owned_bog = actor
	owned_fixture_scope = {"audit":audit,"actor":actor,"progression_before":before}
	var trace := {"asset":"M03","original_living_pool_count":audit._original_pool.size(),"scoped_pool_count_before_factory":0,
		"generic_selector_probes":audit._generic_probes,"factory_returned_actor":is_instance_valid(actor),"owner":definition.owner,
		"requested_arena_anchor":_v3(definition.anchor),"actual_collision":{}}
	if is_instance_valid(actor):
		actor.set_encounter_active(false)
		var body: CollisionShape3D = audit._fixture_collision(actor)
		var floor_hit: Dictionary = audit._fixture_floor(actor.global_position)
		if body != null and not floor_hit.is_empty():
			var sweep: Dictionary = audit._fixture_sweep(body,actor.global_position,actor.global_position)
			var bottom: float = body.global_position.y-float(body.shape.height)*0.5
			var gap: float = bottom-float(floor_hit.position.y)
			trace.actual_collision = {"shape":body.shape.get_class(),"height":body.shape.height,"radius":body.shape.radius,
				"static_occupancy":sweep,"actual_floor":_v3(floor_hit.position),"normal":_v3(floor_hit.normal),"bottom_clearance":gap,
				"passed":bool(sweep.clear) and floor_hit.normal.y>=0.7 and gap>=-0.02 and gap<=0.30,
				"exclusions":"explicit scoped original fixture actors and player; actual static world/capsule retained"}
		trace["actual_spawn_position"] = _v3(actor.global_position)
	var rows: Array = report.get("actor_selection_diagnostics",[])
	rows.append(trace)
	report["actor_selection_diagnostics"] = rows
	if not is_instance_valid(actor) or not bool((trace.actual_collision as Dictionary).get("passed",false)):
		_release_owned_fixture()
		return {}
	return {"actor":actor,"role":str(definition.role),"owner":definition.owner,"placement":"explicit_owned_conditional_fixture_via_actual_Saga_factory",
		"fixture_spawn":trace}

func _release_owned_fixture() -> void:
	if owned_fixture_scope.is_empty(): return
	var audit: RefCounted = owned_fixture_scope.audit
	var actor: Variant = owned_fixture_scope.actor
	if is_instance_valid(actor):
		actor.set_encounter_active(false)
		game.zone_residency._release_zone_render_resources(actor)
		actor.queue_free()
	game.active_enemies.clear()
	game.active_enemies.append_array(audit._original_pool)
	for snapshot: Dictionary in audit._snapshots:
		if is_instance_valid(snapshot.actor): snapshot.actor.set_encounter_active(bool(snapshot.active))
	game._sync_camera_enemy_cache()
	var progression_unchanged: bool = audit._progression_snapshot()==owned_fixture_scope.progression_before
	var restored: bool = game.active_enemies==audit._original_pool
	var rows: Array = report.get("conditional_fixture_cleanup",[])
	rows.append({"asset":"M03","restored_pool_count":game.active_enemies.size(),"original_pool_count":audit._original_pool.size(),
		"original_pool_order_restored":restored,"owned_actor_queued_for_free":is_instance_valid(actor) and actor.is_queued_for_deletion(),
		"progression_unchanged":progression_unchanged})
	report["conditional_fixture_cleanup"] = rows
	owned_fixture_scope.clear()
	if not progression_unchanged or not restored: _fail("Conditional source fixture failed to preserve original progression or enemy pool")

func _palette_root(node: Node, source: String) -> Node3D:
	# Source identity belongs to the existing asset/prepared-scene owner.
	# The draw-only material view carries typed resource provenance and never
	# writes Node metadata for QA or gameplay to consume.
	if node is Node3D and (str(node.get_meta("prepared_actor_source", "")) == source or str(node.get_meta("runtime_asset_path", "")) == source): return node
	for child: Node in node.get_children():
		var found := _palette_root(child, source)
		if found != null: return found
	if node is MeshInstance3D and node.mesh != null:
		for surface in node.mesh.get_surface_count():
			var material := node.get_active_material(surface) as PigmentMaterial
			if material != null and material.source_path == source: return node.get_parent() as Node3D
	return null

func _isolate_actor(actor: Node3D, source_root: Node3D) -> void:
	game.player.visible = false
	for node: Node3D in game.zone_root.find_children("*", "Node3D", true, false):
		if node.has_meta("character_visual_role") and node != actor and not actor.is_ancestor_of(node) and not node.is_ancestor_of(actor): node.visible = false
	for enemy: Node in game.active_enemies:
		if is_instance_valid(enemy) and enemy != actor: enemy.visible = false
	actor.visible = true
	source_root.visible = true
	actor.process_mode = Node.PROCESS_MODE_DISABLED
	game.process_mode = Node.PROCESS_MODE_DISABLED
	Engine.time_scale = 0.0

# Fixed camera and native game lighting. Each timestamp is on the AI strike clock.
func _strike_reel(actor: Node3D, id: String, zone: String, pose: Dictionary) -> Dictionary:
	var player: AnimationPlayer = actor.animation_driver.get_animation_player()
	var windup: float = actor._windup_duration()
	var recovery: float = actor._strike_recovery()
	var contact: float = float(pose.fraction)
	var folder := output.path_join("reels").path_join("%s_%s_%s" % [id, zone, current_environment])
	var frame_count := ceili((windup + recovery) * 24.0) + 1
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		_fail("Could not create strike reel directory: " + id)
		return {}
	for i in frame_count:
		var seconds := minf(float(i) / 24.0, windup + recovery)
		var fraction := contact * seconds / windup if seconds <= windup else contact + (1.0 - contact) * (seconds - windup) / recovery
		player.seek(fraction * float(pose.duration), true)
		await process_frame
		await RenderingServer.frame_post_draw
		var shot := root.get_texture().get_image()
		shot.resize(640, 360, Image.INTERPOLATE_LANCZOS)
		if shot.save_jpg(folder.path_join("%03d.jpg" % i), 0.92) != OK:
			_fail("Could not save strike reel: " + id)
			return {}
	return {"directory":folder,"frames":frame_count,"fps":24,"windup":windup,"recovery":recovery,"contact":contact}


func _stage_pose(actor: Node3D, requested: String, combat: bool) -> Dictionary:
	var driver := actor.find_child("CharacterAnimationDriver", true, false)
	if driver == null: return {}
	var player: AnimationPlayer = driver.get_animation_player()
	if player == null: return {}
	for tree: AnimationTree in actor.find_children("*", "AnimationTree", true, false): tree.active = false
	# Runtime playback belongs to AnimationTree; its owner deliberately leaves
	# source AnimationPlayers inactive. This frozen QA fixture disables that
	# graph and explicitly enables only the manually evaluated source player.
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.active = true
	var clip: StringName = driver.get_clip_for_state("idle")
	var purpose := "native_idle_reference"
	var fraction := 0.31
	if requested == "action":
		if combat:
			clip = driver.get_clip_for_state("attack")
			var profile: Dictionary = actor.native_attack_profile
			fraction = float(profile.get("contact_fraction", 0.5))
			purpose = "authored_attack_contact_pose_only; not a damage observation"
		else:
			for hint: String in ["Feed", "Investigate", "Idle"]:
				var found := _resolve_clip(player, hint)
				if found != StringName():
					clip = found
					break
			fraction = 0.5
			purpose = "authored_ambient_pose_only; wildlife_has_no_EnemyAI_attack"
	if clip == StringName() or not player.has_animation(clip): return {}
	var animation := player.get_animation(clip)
	var requested_position: float = animation.length * fraction
	player.stop()
	player.play(clip)
	# Apply AnimationPlayer's queued play/reset before the explicit seek. Advancing
	# after seeking resets newly queued clips to time zero on this engine version.
	player.advance(0.0)
	var zero_pose_hash := _pose_hash(actor)
	player.seek(requested_position, true)
	player.pause()
	var sought_pose_hash := _pose_hash(actor)
	var actual_clip: StringName = player.assigned_animation
	var actual_duration: float = player.current_animation_length
	var actual_position: float = player.current_animation_position
	var tolerance := 0.0001
	var identity_verified: bool = actual_clip == clip
	var duration_verified: bool = absf(actual_duration-animation.length) <= tolerance
	var position_verified: bool = absf(actual_position-requested_position) <= tolerance
	if not identity_verified or not duration_verified or not position_verified:
		_fail("Native pose seek contract failed: %s / %s actual=%s %.6f/%.6f expected=%.6f/%.6f" % [
			str(actor.get_path()),str(clip),str(actual_clip),actual_position,actual_duration,requested_position,animation.length])
		return {}
	return {"requested":requested, "clip":str(clip), "duration":animation.length, "fraction":fraction,
		"requested_progress":fraction, "requested_position":requested_position, "position":actual_position,
		"actual_clip":str(actual_clip), "actual_duration":actual_duration, "clip_identity_verified":identity_verified,
		"duration_verified":duration_verified, "position_verified":position_verified, "position_tolerance_seconds":tolerance,
		"source_player_active":player.active,"source_player_clock":"manual QA only; runtime AnimationTree disabled",
		"pose_sha256_at_clip_zero":zero_pose_hash,"pose_sha256_after_seek":sought_pose_hash,
		"native_pose_changed_from_clip_zero":zero_pose_hash != sought_pose_hash,
		"purpose":purpose}

func _resolve_clip(player: AnimationPlayer, hint: String) -> StringName:
	for clip: String in player.get_animation_list():
		if clip.to_lower() == hint.to_lower() or clip.get_file().to_lower() == hint.to_lower(): return StringName(clip)
	return StringName()

func _baked_bounds(source: Node3D) -> AABB:
	var bounds := AABB()
	var initialized := false
	for mesh: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null or not mesh.is_visible_in_tree() or str(mesh.name).to_lower().contains("shadow"): continue
		var local := mesh.mesh.get_aabb()
		if mesh.skin != null:
			var baked := mesh.bake_mesh_from_current_skeleton_pose()
			if baked != null: local = baked.get_aabb()
		var current: AABB = mesh.global_transform * local
		bounds = bounds.merge(current) if initialized else current
		initialized = true
	return bounds

func _baked_surface_points(source: Node3D) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for instance: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
		if instance.mesh == null or not instance.is_visible_in_tree() or str(instance.name).to_lower().contains("shadow"): continue
		var mesh: Mesh = instance.mesh
		if instance.skin != null:
			var baked := instance.bake_mesh_from_current_skeleton_pose()
			if baked != null: mesh = baked
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var step := maxi(1, ceili(float(vertices.size())/1800.0))
			for index in range(0, vertices.size(), step): points.append(instance.global_transform * vertices[index])
	return points

func _stage_camera(actor: Node3D, bounds: AABB, surface_points: Array[Vector3], front_threequarter := false) -> Dictionary:
	if not bounds.size.is_finite() or bounds.size.length_squared() <= 0.00001: return {"passed":false, "reason":"empty native bounds"}
	var center := bounds.get_center()
	var half_fov := tan(deg_to_rad(camera.fov*0.5))
	var aspect := float(viewport.x)/float(viewport.y)
	var distance := maxf(bounds.size.y/(2.0*half_fov), maxf(bounds.size.x,bounds.size.z)/(2.0*half_fov*aspect))*1.55
	distance = maxf(distance, 1.1)
	var driver := actor.find_child("CharacterAnimationDriver", true, false)
	var forward: Vector3 = driver.get_visible_forward() if driver != null else -actor.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.01: forward = Vector3.FORWARD
	forward = forward.normalized()
	var rejected: Array = []
	var projection_rejections := 0
	var obstruction_rejections := 0
	var angles: Array = [0.35,-0.35,0.0,0.8,-0.8,1.2,-1.2,1.6,-1.6,2.1,-2.1,2.6,-2.6,PI]
	var heights: Array = [0.22,0.5,0.8,1.1]
	if front_threequarter:
		angles = [0.35,-0.35,0.0,0.65,-0.65,0.95,-0.95]
		heights = [0.15,0.3,0.5]
	for multiplier in [1.0,1.3,1.7,2.2]:
		for angle in angles:
			for height in heights:
				camera.global_position = center + forward.rotated(Vector3.UP,float(angle))*distance*float(multiplier) + Vector3.UP*distance*float(height)
				camera.look_at(center)
				camera.reset_physics_interpolation()
				camera.make_current()
				var projection := _project_bounds(bounds)
				if not bool(projection.get("safe", false)):
					projection_rejections += 1
					if rejected.size() < 6: rejected.append({"reason":"projection", "projection":projection, "camera":_camera_record()})
					continue
				var coverage := _surface_ray_coverage(actor, surface_points, projection)
				if bool(coverage.get("passed", false)): return {"passed":true, "projection":projection, "render_mesh_surface_rays":coverage, "rejected":rejected,
					"projection_rejections":projection_rejections, "obstruction_rejections":obstruction_rejections,
					"composition":{"front_threequarter":front_threequarter,"elevation_degrees":rad_to_deg(atan(float(height)/float(multiplier))),
						"horizontal_angle_from_native_front_degrees":rad_to_deg(float(angle))}}
				obstruction_rejections += 1
				var hit: Dictionary = coverage.get("blocker", {})
				var blocker := root.get_node_or_null(NodePath(str(hit.get("node", "")))) as GeometryInstance3D
				hit["camera_cull_mask"] = camera.cull_mask
				hit["blocker_layers"] = blocker.layers if blocker != null else 0
				if rejected.size() < 12: rejected.append({"reason":"rendered_mesh_obstruction", "hit":hit, "camera":_camera_record(), "projection":projection})
	return {"passed":false, "reason":"no safe frame with a clear rendered center ray", "rejected":rejected,
		"projection_rejections":projection_rejections, "obstruction_rejections":obstruction_rejections,
		"final_projection":_project_bounds(bounds), "final_camera":_camera_record(), "bounds":_aabb(bounds)}

func _surface_ray_coverage(actor: Node3D, points: Array[Vector3], projection: Dictionary) -> Dictionary:
	if points.is_empty(): return {"passed":false, "reason":"no native surface samples"}
	var low := Vector2(float(projection.min[0]),float(projection.min[1]))
	var high := Vector2(float(projection.max[0]),float(projection.max[1]))
	var size := (high-low).max(Vector2.ONE)
	var projected: Array[Dictionary] = []
	for point: Vector3 in points:
		if not camera.is_position_behind(point): projected.append({"world":point, "uv":(camera.unproject_position(point)-low)/size})
	var candidates: Array = geometry._query_entries(actor, camera.cull_mask)
	var checked: Array = []
	for y in [0.15,0.5,0.85]:
		for x in [0.15,0.5,0.85]:
			var target_uv := Vector2(x,y)
			var nearest := Vector3.INF
			var nearest_error := INF
			for point: Dictionary in projected:
				var error := (point.uv as Vector2).distance_squared_to(target_uv)
				if error < nearest_error:
					nearest_error = error
					nearest = point.world
			if not nearest.is_finite(): return {"passed":false, "reason":"no projected native sample"}
			var hit: Dictionary = geometry._query_obstruction(camera.global_position, nearest, candidates)
			checked.append({"screen_grid":_v2(target_uv), "native_surface_point":_v3(nearest), "clear":hit.is_empty()})
			if not hit.is_empty():
				hit["screen_grid"] = _v2(target_uv)
				hit["native_surface_point"] = _v3(nearest)
				return {"passed":false, "blocker":hit, "checked":checked}
	return {"passed":true, "checked":checked, "method":"nine image-grid samples select actual baked native surface vertices; all rendered-triangle rays must be clear",
		"limitations":"conservative geometry rays; raster alpha and unsampled thin branches still require image review"}

func _native_key_light() -> DirectionalLight3D:
	var key: DirectionalLight3D
	for light: DirectionalLight3D in root.find_children("*", "DirectionalLight3D", true, false):
		if light.is_visible_in_tree() and light.light_energy > 0.0 and (key == null or light.light_energy > key.light_energy): key = light
	return key

func _native_light_clearance(actor: Node3D, bounds: AABB, light: DirectionalLight3D) -> Dictionary:
	if light == null: return {"passed":false,"reason":"no existing active directional key light"}
	var direction := light.global_basis.z.normalized()
	var candidates: Array[Dictionary] = []
	for candidate: Dictionary in geometry._query_entries(actor, camera.cull_mask):
		if candidate.node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: candidates.append(candidate)
	var samples: Array[Dictionary] = []
	var clear := true
	for height in [0.45,0.7,0.88]:
		var point := bounds.get_center()
		point.y = bounds.position.y + bounds.size.y*float(height)
		var hit: Dictionary = geometry._query_obstruction(point+direction*0.02, point+direction*128.0, candidates) if light.shadow_enabled else {}
		if not hit.is_empty(): clear = false
		samples.append({"point":_v3(point),"clear":hit.is_empty(),"blocker":hit})
	return {"passed":clear,"light":str(light.get_path()),"light_energy":light.light_energy,"light_color":_color(light.light_color),
		"native_shadow_enabled":light.shadow_enabled,"toward_light":_v3(direction),"samples":samples,
		"method":"native directional key; conservative shadow-casting rendered-triangle rays at three body heights",
		"limitation":"transparent raster shadow details and actual skin exposure still require image review; no added lights"}

func _restage_in_clearing(actor: Node3D, source_root: Node3D, zone: String, native_lit := false, dry_floor := false) -> Dictionary:
	var original: Vector3 = actor.global_position
	var original_transform := actor.global_transform
	var original_yaw := actor.global_rotation.y
	var key: DirectionalLight3D = _native_key_light() if native_lit else null
	if native_lit and key != null:
		var driver := actor.find_child("CharacterAnimationDriver",true,false)
		var forward: Vector3 = driver.get_visible_forward() if driver != null else -actor.global_basis.z
		var toward_light: Vector3 = key.global_basis.z
		forward.y = 0.0
		toward_light.y = 0.0
		if forward.length_squared()>0.0001 and toward_light.length_squared()>0.0001:
			actor.global_rotate(Vector3.UP,forward.normalized().signed_angle_to(toward_light.normalized(),Vector3.UP))
	var home: Vector3 = game.player.global_position
	var anchors: Array[Vector3] = []
	if native_lit or dry_floor: anchors.append(original)
	if zone == "wychwood": anchors.append_array([Vector3(-1,0,-6.5),Vector3(0,0,-8.8),Vector3(2,0,-5.3),Vector3(-2,0,-5.3)])
	if zone == "marsh_crossing" and (native_lit or dry_floor): anchors.append_array([Vector3(-2,0,-1),Vector3(2,0,-1),Vector3(-3,0,-4),Vector3(3,0,-4),Vector3(0,0,1),Vector3(0,0,-8)])
	for offset: Vector3 in [Vector3(0,0,-4),Vector3(3,0,-3),Vector3(-3,0,-3),Vector3(0,0,-7),Vector3(4,0,0),Vector3(-4,0,0)]: anchors.append(home+offset)
	var excluded: Array = [game.player.get_rid()]
	if actor is CollisionObject3D: excluded.append(actor.get_rid())
	var attempts: Array = []
	for anchor: Vector3 in anchors:
		var floor_point: Vector3 = geometry.support_point(game.player.get_world_3d().direct_space_state, anchor, excluded, 1.5)
		if not floor_point.is_finite() or not game.spatial_service.is_walkable_position(floor_point,0.55,game.spatial_service.bank_for(floor_point)):
			attempts.append({"anchor":_v3(anchor), "support_and_walkability":false})
			continue
		actor.global_position = floor_point + Vector3.UP*0.02
		if native_lit or dry_floor:
			# A QA restage seats the complete authored pose above its verified
			# floor instead of retaining an authored placement buried in a bridge.
			# Only the actor's fixture transform changes; mesh/capsule dimensions do not.
			var initial_bounds := _baked_bounds(source_root)
			actor.global_position.y += maxf(0.0,floor_point.y+0.02-initial_bounds.position.y)
		actor.reset_physics_interpolation()
		source_root.reset_physics_interpolation()
		for _settle in range(2): await process_frame
		var bounds := _baked_bounds(source_root)
		var light_check: Dictionary = _native_light_clearance(actor,bounds,key) if native_lit else {"passed":true,"requested":false}
		if not bool(light_check.get("passed",false)):
			attempts.append({"anchor":_v3(anchor),"verified_floor":_v3(floor_point),"light_clearance":light_check,"camera_attempted":false})
			continue
		var check := _stage_camera(actor,bounds,_baked_surface_points(source_root),native_lit)
		attempts.append({"anchor":_v3(anchor), "verified_floor":_v3(floor_point), "camera_passed":bool(check.get("passed",false)),"light_clearance":light_check})
		if bool(check.get("passed", false)): return {"passed":true, "kind":"QA_only_floor_verified_clearing_restage", "original_actor_position":_v3(original),
			"actor_position":_v3(actor.global_position), "verified_floor":_v3(floor_point), "camera_check":check, "attempts":attempts,
			"native_lit_front_threequarter":native_lit,"native_light_clearance":light_check,
			"dry_whole_body_floor_seat":dry_floor,"aquatic_behavior_acceptance":false,
			"original_actor_yaw":original_yaw,"fixture_actor_yaw":actor.global_rotation.y,
			"native_pose_bottom_above_floor":bounds.position.y-floor_point.y,
			"environment_hidden":false, "source_shape_skin_animation_unchanged":true, "authored_ecology_placement_acceptance":false}
	actor.global_transform = original_transform
	actor.reset_physics_interpolation()
	source_root.reset_physics_interpolation()
	return {"passed":false, "kind":"QA_only_floor_verified_clearing_restage", "original_actor_position":_v3(original), "attempts":attempts, "actor_restored":true}

func _habitat_images(id: String, zone: String, pose: String, actor: Node3D, source: Node3D, entries: Array[Dictionary], bounds: AABB, check: Dictionary) -> void:
	# Keep the authored water/ground contact visible as context before the
	# separate dry material-inspection fixture. This is not a clear full-body view.
	var rows: Array = report.get("habitat_observations",[])
	var before := _pose_hash(source)
	for mode: String in ["original","candidate"]:
		_set_mode(entries,mode)
		for _settle in range(2): await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		var path := output.path_join("HABITAT_%s_%s_%s_%s_%s.png" % [id,zone,current_environment,pose,mode])
		var error := image.save_png(path) if image != null and image.get_size()==viewport else ERR_CANT_CREATE
		if error != OK or _pose_hash(source)!=before: _fail("Authored habitat context capture failed: "+id)
		rows.append({"asset":id,"zone":zone,"environment":current_environment,"pose":pose,"mode":mode,"path":path,
			"write_error":error,"actor_position":_v3(actor.global_position),"source_position":_v3(source.global_position),
			"bounds":_aabb(bounds),"camera":_camera_record(),"original_habitat_transform_preserved":true,
			"whole_body_clearance_passed":bool(check.get("passed",false)),"complete_material_coverage_acceptance":false,
			"meaning":"authored habitat/submersion context; dry full-body inspection is separately labelled"})
	report["habitat_observations"] = rows
	_set_mode(entries,"candidate")

func _failed_framing_image(id: String, zone: String, pose: String, bounds: AABB, check: Dictionary, source_root: Node3D) -> void:
	# Failed observations remain reviewable. This image never enters the passing
	# comparison matrix and never relaxes environment visibility or ray checks.
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path := output.path_join("FAILED_FRAMING_%s_%s_%s_%s.png" % [id,zone,current_environment,pose])
	var error := image.save_png(path) if image != null else ERR_CANT_CREATE
	var rows: Array = report.get("diagnostics", [])
	rows.append({"kind":"failed_framing", "asset":id, "zone":zone, "environment":current_environment, "pose":pose,
		"path":path, "write_error":error, "camera":_camera_record(), "bounds":_aabb(bounds), "camera_check":check,
		"source_root":str(source_root.get_path()), "source_position":_v3(source_root.global_position),
		"source_scale":_v3(source_root.global_basis.get_scale()), "acceptance":false})
	report["diagnostics"] = rows

func _project_bounds(bounds: AABB) -> Dictionary:
	var low := Vector2.INF
	var high := -Vector2.INF
	for x in [0.0,1.0]:
		for y in [0.0,1.0]:
			for z in [0.0,1.0]:
				var point := bounds.position + bounds.size*Vector3(x,y,z)
				if camera.is_position_behind(point): return {"safe":false,"reason":"bounds behind camera", "point":_v3(point), "actual_viewport":_v2(camera.get_viewport().get_visible_rect().size)}
				var pixel := camera.unproject_position(point)
				low = low.min(pixel)
				high = high.max(pixel)
	return {"min":[low.x,low.y], "max":[high.x,high.y], "actual_viewport":_v2(camera.get_viewport().get_visible_rect().size),
		"safe":low.x >= viewport.x*.06 and low.y >= viewport.y*.06 and high.x <= viewport.x*.94 and high.y <= viewport.y*.94}

func _set_mode(entries: Array[Dictionary], mode: String) -> void:
	for entry: Dictionary in entries:
		var material: Material = entry.original if mode == "original" else (entry.identity if mode == "identity" else entry.variant)
		if mode == "identity_body": material = entry.identity if str(entry.original.resource_name) == "M11_RecoveryAtlas" else entry.original
		if mode == "identity_wing": material = entry.identity if str(entry.original.resource_name) == "M11_BoundedWingMembrane" else entry.original
		if bool(entry.retained_native): material = entry.original
		entry.mesh.material_override = null
		entry.mesh.set_surface_override_material(int(entry.surface), material)

func _material_records(entries: Array[Dictionary]) -> Array:
	var rows: Array = []
	for entry: Dictionary in entries:
		var native := entry.original as BaseMaterial3D
		var current: Material = entry.mesh.get_active_material(int(entry.surface))
		rows.append({"mesh":str(entry.mesh.name), "surface":int(entry.surface), "native_name":native.resource_name,
			"native_features":_native_feature_flags(native),
			"active_shader_uniforms":_shader_uniform_records(current),
			"retained_native":bool(entry.retained_native), "active_matches_native_resource":current == native,
			"material_policy":"retained_native" if bool(entry.retained_native) else "graded_opaque_shader",
			"active_class":current.get_class(), "shader":current.shader.resource_path if current is ShaderMaterial else "",
			"atlas":native.albedo_texture.resource_path if native.albedo_texture != null else "", "normal":native.normal_texture.resource_path if native.normal_texture != null else "",
			"normal_scale":native.normal_scale, "roughness":native.roughness, "metallic":native.metallic,
			"specular":native.metallic_specular, "clearcoat":native.clearcoat if native.clearcoat_enabled else 0.0,
			"alpha":native.albedo_color.a, "transparency":native.transparency, "cull":native.cull_mode,
			"geometry_rid":str(entry.mesh.mesh.get_rid()), "skin_rid":str(entry.mesh.skin.get_rid()) if entry.mesh.skin != null else ""})
	return rows

func _shader_uniform_records(material: Material) -> Dictionary:
	if not material is ShaderMaterial: return {}
	var values: Dictionary = {}
	for name in ["pigment_strength","neutral_color","warm_color","cool_color","chroma_preservation","highlight_preservation","value_gain","atlas_regions",
		"authored_tint","authored_uv_scale","authored_uv_offset","vertex_color_enabled","normal_enabled","authored_normal_scale",
		"authored_roughness","authored_metallic","authored_specular","authored_clearcoat","authored_clearcoat_roughness"]:
		var value: Variant = (material as ShaderMaterial).get_shader_parameter(name)
		if value is Color: values[name] = _color(value)
		elif value is Vector2: values[name] = _v2(value)
		elif value is Vector3: values[name] = _v3(value)
		elif value is Vector4: values[name] = [value.x,value.y,value.z,value.w]
		elif value == null or typeof(value) in [TYPE_BOOL,TYPE_INT,TYPE_FLOAT,TYPE_STRING,TYPE_STRING_NAME]: values[name] = value
	return values

func _native_feature_flags(native: BaseMaterial3D) -> Dictionary:
	var fields := ["transparency","blend_mode","depth_draw_mode","cull_mode","shading_mode","diffuse_mode","specular_mode",
		"texture_filter","texture_repeat","render_priority","next_pass","vertex_color_use_as_albedo","vertex_color_is_srgb",
		"disable_receive_shadows","disable_ambient_light","disable_fog","use_shadow_to_opacity","refraction_enabled",
		"proximity_fade_enabled","distance_fade_mode","detail_enabled","uv1_scale","uv1_offset","uv1_triplanar",
		"uv2_scale","uv2_offset","uv2_triplanar","normal_enabled","normal_scale","clearcoat_enabled","clearcoat","clearcoat_roughness",
		"roughness","metallic","metallic_specular","roughness_texture_channel","metallic_texture_channel"]
	var flags: Dictionary = {}
	for property: Dictionary in native.get_property_list():
		var name := str(property.name)
		if name not in fields and not name.begins_with("alpha_") and not name.begins_with("albedo_"): continue
		var value: Variant = native.get(name)
		if value is Color: flags[name] = _color(value)
		elif value is Vector2: flags[name] = _v2(value)
		elif value is Vector3: flags[name] = _v3(value)
		elif value is Resource: flags[name] = {"class":value.get_class(), "path":value.resource_path}
		elif value == null or typeof(value) in [TYPE_BOOL,TYPE_INT,TYPE_FLOAT,TYPE_STRING,TYPE_STRING_NAME]: flags[name] = value
	return flags

func _collision_records(actor: Node3D) -> Array:
	var rows: Array = []
	for collision: CollisionShape3D in actor.find_children("*", "CollisionShape3D", true, false):
		if collision.shape == null: continue
		var row := {"node":str(actor.get_path_to(collision)), "shape":collision.shape.get_class(), "position":_v3(collision.position),
			"scale":_v3(collision.scale), "disabled":collision.disabled, "parent_class":collision.get_parent().get_class()}
		if collision.shape is CapsuleShape3D or collision.shape is CylinderShape3D:
			row["height"] = collision.shape.height
			row["radius"] = collision.shape.radius
		elif collision.shape is SphereShape3D: row["radius"] = collision.shape.radius
		elif collision.shape is BoxShape3D: row["size"] = _v3(collision.shape.size)
		rows.append(row)
	return rows

func _pose_hash(source: Node3D) -> String:
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	var skeletons: Array = source.find_children("*", "Skeleton3D", true, false)
	if source is Skeleton3D: skeletons.push_front(source)
	for skeleton: Skeleton3D in skeletons:
		for bone in skeleton.get_bone_count():
			var transform := skeleton.get_bone_pose(bone)
			digest.update(PackedFloat32Array([transform.basis.x.x,transform.basis.x.y,transform.basis.x.z,transform.basis.y.x,transform.basis.y.y,transform.basis.y.z,transform.basis.z.x,transform.basis.z.y,transform.basis.z.z,transform.origin.x,transform.origin.y,transform.origin.z]).to_byte_array())
	return digest.finish().hex_encode()

func _visible_skeletons() -> int:
	var count := 0
	for skeleton: Skeleton3D in root.find_children("*", "Skeleton3D", true, false):
		if skeleton.is_visible_in_tree(): count += 1
	return count

func _lighting_record() -> Dictionary:
	var environment: Environment = camera.get_world_3d().environment
	var lights: Array = []
	for light: Light3D in root.find_children("*", "Light3D", true, false):
		if light.is_visible_in_tree(): lights.append({"name":str(light.name), "class":light.get_class(), "color":_color(light.light_color), "energy":light.light_energy, "position":_v3(light.global_position)})
	var record := {"lights":lights, "visible_light_count":lights.size(), "day_time":float(game.day_night.get_time()),
		"day_count":int(game.day_night.day_count), "weather":str(game.day_night.current_weather)}
	if environment != null:
		record["environment"] = {"ambient_color":_color(environment.ambient_light_color), "ambient_energy":environment.ambient_light_energy,
			"brightness":environment.adjustment_brightness, "saturation":environment.adjustment_saturation, "contrast":environment.adjustment_contrast,
			"fog_color":_color(environment.fog_light_color), "fog_density":environment.fog_density, "tonemap":environment.tonemap_mode}
	return record

func _render_cost(entries: Array[Dictionary]) -> Dictionary:
	var rows: Array = []
	var previous_cap := Engine.max_fps
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for index in range(6):
		var mode := "original" if index in [0,3,4] else "candidate"
		_set_mode(entries, mode)
		for _warmup in range(12): await process_frame
		var frames: Array[float] = []
		var deadline := Time.get_ticks_msec() + 1800
		var previous := Time.get_ticks_usec()
		while Time.get_ticks_msec() < deadline:
			await process_frame
			var now := Time.get_ticks_usec()
			frames.append(float(now-previous)/1000.0)
			previous = now
		frames.sort()
		if not frames.is_empty(): rows.append({"mode":mode, "repeat":index, "samples":frames.size(), "p50_ms":frames[int(frames.size()*.5)], "p95_ms":frames[mini(frames.size()-1,int(frames.size()*.95))]})
	Engine.max_fps = previous_cap
	return {"kind":"paired_frozen_real_level_render_cost_diagnostic", "representative_route_benchmark":false,
		"main_process_disabled":true, "uncapped":true, "vsync":0, "sequence":"ABBAAB after material warmup", "windows":rows,
		"limitations":"one visible fixed-pose specimen; excludes locomotion, combat, input and representative route simulation"}

func _camera_record() -> Dictionary:
	return {"position":_v3(camera.global_position), "rotation":_v3(camera.global_rotation), "fov":camera.fov, "near":camera.near, "far":camera.far,
		"current":camera.is_current(), "viewport":[viewport.x,viewport.y], "actual_viewport":_v2(camera.get_viewport().get_visible_rect().size),
		"dimensions":_dimension_record(),
		"physics_interpolation_mode":camera.physics_interpolation_mode, "cull_mask":camera.cull_mask}

func _v3(value: Vector3) -> Array: return [value.x,value.y,value.z]
func _v2(value: Vector2) -> Array: return [value.x,value.y]
func _color(value: Color) -> Array: return [value.r,value.g,value.b,value.a]
func _aabb(value: AABB) -> Dictionary: return {"position":_v3(value.position), "size":_v3(value.size)}
func _fail(message: String) -> void:
	(report.failures as Array).append(message)
	push_error(message)

func _shutdown() -> void:
	_release_owned_fixture()
	_restore_particle_speeds("before_shutdown")
	Engine.time_scale = 1.0
	paused = false
	if is_instance_valid(game):
		game.process_mode = Node.PROCESS_MODE_INHERIT
		game.prepare_resource_shutdown()
		for _index in range(20): await process_frame
		game.finalize_resource_shutdown()
		for _index in range(12): await process_frame
		game.queue_free()
		for _index in range(8): await process_frame
		RenderingServer.force_sync()
	_finish()

func _finish() -> void:
	report["status"] = "pass" if (report.failures as Array).is_empty() and not (report.frames as Array).is_empty() else "fail"
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t") + "\n")
		file.close()
	quit(0 if str(report.status) == "pass" else 1)
