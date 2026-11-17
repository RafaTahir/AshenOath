extends SceneTree
## Source-authoring observation in real constructed levels. Fixture staging is
## explicit; these images do not establish earned progress or input acceptance.
const Palette = preload("res://scripts/views/monster_material_view.gd")
const PigmentMaterial = preload("res://scripts/views/monster_pigment_material.gd")
const Geometry = preload("res://tools/living_cast_capture_geometry.gd")
const ENEMIES := {
	"M01": {"role":"ghoulkin", "zone":"wychwood"},
	"M02": {"role":"wychwood_stalker", "zone":"wychwood"},
	"M19": {"role":"wychwood_raider", "zone":"wychwood"},
	"M20": {"role":"wychwood_brute", "zone":"wychwood"},
	"M05": {"role":"bell_eater", "zone":"cemetery"},
	"M07": {"role":"ashwing", "zone":"old_mill"},
	"M03": {"role":"bog_wretch", "zone":"marsh_crossing"},
	"M06": {"role":"rootbound_colossus", "zone":"deep_wood"},
	"M04": {"role":"gravebound_knight", "zone":"ruins"},
	"M08": {"role":"white_hart_avatar", "zone":"hart_glade"},
}
const ORDER := ["M01","M02","M19","M20","M11","M15","M05","M07","M09","M10","M03","M18","M13","M06","M14","M04","M12","M16","M08","M17"]
const IDENTITY := ["M02", "M09", "M11"]
var options: Dictionary = {}
var output := ""
var game: Node
var camera: Camera3D
var geometry: RefCounted
var viewport := Vector2i(1280, 720)
var profiles: Dictionary = {}
var ecology: Dictionary = {}
var current_environment := "day"
var report := {"kind":"native_monster_material_level_observation", "failures":[], "frames":[], "specimens":[],
	"visual_acceptance":false, "earned_progress_acceptance":false, "real_input_acceptance":false,
	"mode":"source_authoring_preview", "frozen_export_verified":false,
	"staging":"real main/new journey and zone construction; ecology actors keep authored placement; missing quest enemies may be fixture-spawned through ZoneBuildContext; other actors hidden during palette comparison"}

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
	if options.get("viewport", "desktop") == "touch": viewport = Vector2i(960, 540)
	root.size = viewport
	DisplayServer.window_set_size(viewport)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 60
	report["user_data_dir"] = OS.get_user_data_dir()
	report["viewport"] = [viewport.x, viewport.y]
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
	var mechanics_path := str(options.get("mechanics-script", ""))
	if not mechanics_path.is_empty():
		var mechanics: RefCounted = load(mechanics_path).new()
		DirAccess.make_dir_recursive_absolute(output.path_join("mechanics"))
		report["mechanics"] = await mechanics.run(game, output.path_join("mechanics"), viewport)
		if not bool((report.mechanics as Dictionary).get("passed", false)): _fail("Focused mechanics fixture did not pass; see mechanics report")
	Engine.time_scale = 1.0
	paused = false
	game.process_mode = Node.PROCESS_MODE_INHERIT
	game.day_night.set_time_lock(true)
	game.camera_rig.set_process(false)
	game.camera_rig.set_physics_process(false)
	camera = Camera3D.new()
	camera.name = "MonsterMaterialLevelCamera"
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
	Engine.time_scale = 1.0
	game.process_mode = Node.PROCESS_MODE_INHERIT
	game.player.visible = true
	if str(game.current_zone_id) != zone: game._load_zone(zone)
	var deadline := Time.get_ticks_msec() + 180000
	while Time.get_ticks_msec() < deadline:
		if str(game.current_zone_id) == zone and not game.zone_transition_pending and not game.zone_load_request_pending and is_instance_valid(game.zone_root) and is_instance_valid(game.player) and game.player.can_control:
			for _index in range(4): await process_frame
			for layer: CanvasLayer in root.find_children("*", "CanvasLayer", true, false): layer.visible = false
			camera.make_current()
			return true
		await process_frame
	_fail("Real region construction readiness deadline: " + zone)
	return false

func _set_environment(value: String) -> void:
	current_environment = value
	Engine.time_scale = 1.0
	game.process_mode = Node.PROCESS_MODE_INHERIT
	game.day_night.set_time(60.0 if value == "night" else 600.0, 1 if value == "rain" else 0)
	for _index in range(4): await process_frame
	game.process_mode = Node.PROCESS_MODE_DISABLED
	Engine.time_scale = 0.0
	for particles: GPUParticles3D in game.find_children("*", "GPUParticles3D", true, false): particles.speed_scale = 0.0
	for particles: CPUParticles3D in game.find_children("*", "CPUParticles3D", true, false): particles.speed_scale = 0.0
	camera.make_current()

func _specimen(id: String, zone: String) -> void:
	var selected := _select_actor(id)
	if selected.is_empty():
		_fail("No actual or owner-constructed actor: " + id + " in " + zone)
		return
	var actor := selected.actor as Node3D
	var source_root := _palette_root(actor, str(profiles[id].source))
	if source_root == null:
		_fail("Native palette root is missing: " + id)
		return
	_isolate_actor(actor, source_root)
	var geometry_report: Dictionary = geometry.build(game.zone_root, game.player)
	var entries: Array[Dictionary] = []
	for mesh: MeshInstance3D in source_root.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null: continue
		for surface in mesh.mesh.get_surface_count():
			var variant := mesh.get_active_material(surface) as PigmentMaterial
			if variant == null or variant.native_material == null:
				_fail("Native material provenance missing: " + id)
				return
			var original := variant.native_material
			var identity := variant.duplicate(false) as PigmentMaterial
			identity.set_shader_parameter("pigment_strength", 0.0)
			entries.append({"mesh":mesh, "surface":surface, "variant":variant, "original":original, "identity":identity})
	var specimen := {"asset":id, "role":str(selected.role), "zone":zone, "environment":current_environment,
		"source":str(profiles[id].source), "source_sha256":str(profiles[id].source_sha256),
		"placement":str(selected.placement), "actor_position":_v3(actor.global_position), "actor_path":str(actor.get_path()),
		"geometry_validation":geometry_report, "visible_skeletons":_visible_skeletons(), "collision_shapes":_collision_records(actor), "frames":[], "poses":[]}
	if int(specimen.visible_skeletons) > 10: _fail("Visible skeleton budget exceeded: " + id)
	for pose_name: String in str(options.get("poses", "idle")).split(","):
		var pose := _stage_pose(actor, pose_name, ENEMIES.has(id))
		if pose.is_empty():
			_fail("Could not stage native pose: " + id + " / " + pose_name)
			continue
		# Settle the scheduled skeleton/skin upload before baking bounds or
		# comparing the material-only modes against the same final native pose.
		for _settle in range(2): await process_frame
		await RenderingServer.frame_post_draw
		var bounds := _baked_bounds(source_root)
		var camera_check := _stage_camera(actor, bounds)
		if not bool(camera_check.get("passed", false)):
			_fail("Actual-level camera is obstructed: " + id)
			(specimen.poses as Array).append({"requested":pose_name, "camera_check":camera_check})
			continue
		pose["camera_check"] = camera_check
		pose["bounds"] = _aabb(bounds)
		var before_hash := _pose_hash(source_root)
		var modes: Array[String] = ["original", "candidate"]
		if id in IDENTITY: modes = ["original", "identity", "candidate"]
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
					"native_pose":"direct authored clip seek; animation trees and player paused", "background_motion":"shader TIME/temporal noise may still differ; measured separately"}}
			(report.frames as Array).append(frame)
			(specimen.frames as Array).append(name)
		(specimen.poses as Array).append(pose)
		if str(options.get("performance", "false")) == "true" and id in IDENTITY and pose_name == "idle":
			specimen["paired_render_cost"] = await _render_cost(entries)
	_set_mode(entries, "candidate")
	(report.specimens as Array).append(specimen)
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
			return {"actor":enemy, "role":str(definition.role), "placement":"existing_level_enemy"}
	# The source-authoring preview may inspect a boss before its quest gate is
	# earned, using the real construction owner. This is not progression QA.
	var point := game.player.global_position
	var found := false
	for offset: Vector3 in [Vector3(0,0,-4),Vector3(3,0,-3),Vector3(-3,0,-3),Vector3(0,0,-7),Vector3(4,0,0),Vector3(-4,0,0),Vector3.ZERO]:
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
	return {"actor":enemy, "role":str(definition.role), "placement":"fixture_enemy_via_ZoneBuildContext_at_verified_real_floor"}

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

func _stage_pose(actor: Node3D, requested: String, combat: bool) -> Dictionary:
	var driver := actor.find_child("CharacterAnimationDriver", true, false)
	if driver == null: return {}
	var player: AnimationPlayer = driver.get_animation_player()
	if player == null: return {}
	for tree: AnimationTree in actor.find_children("*", "AnimationTree", true, false): tree.active = false
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
	player.stop()
	player.play(clip)
	player.seek(animation.length * fraction, true)
	player.advance(0.0)
	player.pause()
	return {"requested":requested, "clip":str(clip), "duration":animation.length, "fraction":fraction, "position":player.current_animation_position, "purpose":purpose}

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

func _stage_camera(actor: Node3D, bounds: AABB) -> Dictionary:
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
	for multiplier in [1.0,1.3,1.7]:
		for angle in [0.35,-0.35,0.0,0.8,-0.8,1.5,-1.5,PI]:
			for height in [0.22,0.5,0.8]:
				camera.global_position = center + forward.rotated(Vector3.UP,float(angle))*distance*float(multiplier) + Vector3.UP*distance*float(height)
				camera.look_at(center)
				camera.make_current()
				var projection := _project_bounds(bounds)
				if not bool(projection.get("safe", false)): continue
				var hit: Dictionary = geometry.obstruction(camera.global_position, center, actor, camera.cull_mask)
				if hit.is_empty(): return {"passed":true, "projection":projection, "render_mesh_center_ray":"clear", "rejected":rejected}
				if rejected.size() < 6: rejected.append(hit)
	return {"passed":false, "reason":"no safe frame with a clear rendered center ray", "rejected":rejected}

func _project_bounds(bounds: AABB) -> Dictionary:
	var low := Vector2.INF
	var high := -Vector2.INF
	for x in [0.0,1.0]:
		for y in [0.0,1.0]:
			for z in [0.0,1.0]:
				var point := bounds.position + bounds.size*Vector3(x,y,z)
				if camera.is_position_behind(point): return {"safe":false,"reason":"bounds behind camera"}
				var pixel := camera.unproject_position(point)
				low = low.min(pixel)
				high = high.max(pixel)
	return {"min":[low.x,low.y], "max":[high.x,high.y], "safe":low.x >= viewport.x*.06 and low.y >= viewport.y*.06 and high.x <= viewport.x*.94 and high.y <= viewport.y*.94}

func _set_mode(entries: Array[Dictionary], mode: String) -> void:
	for entry: Dictionary in entries:
		var material: Material = entry.original if mode == "original" else (entry.identity if mode == "identity" else entry.variant)
		entry.mesh.material_override = null
		entry.mesh.set_surface_override_material(int(entry.surface), material)

func _material_records(entries: Array[Dictionary]) -> Array:
	var rows: Array = []
	for entry: Dictionary in entries:
		var native := entry.original as BaseMaterial3D
		var current: Material = entry.mesh.get_active_material(int(entry.surface))
		rows.append({"mesh":str(entry.mesh.name), "surface":int(entry.surface), "native_name":native.resource_name,
			"active_class":current.get_class(), "shader":current.shader.resource_path if current is ShaderMaterial else "",
			"atlas":native.albedo_texture.resource_path, "normal":native.normal_texture.resource_path if native.normal_texture != null else "",
			"normal_scale":native.normal_scale, "roughness":native.roughness, "metallic":native.metallic,
			"specular":native.metallic_specular, "clearcoat":native.clearcoat if native.clearcoat_enabled else 0.0,
			"alpha":native.albedo_color.a, "transparency":native.transparency, "cull":native.cull_mode,
			"geometry_rid":str(entry.mesh.mesh.get_rid()), "skin_rid":str(entry.mesh.skin.get_rid()) if entry.mesh.skin != null else ""})
	return rows

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
	var record := {"lights":lights, "visible_light_count":lights.size(), "day_time":game.day_night.time_of_day if game.day_night.get("time_of_day") != null else null}
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
		"current":camera.is_current(), "viewport":[viewport.x,viewport.y], "cull_mask":camera.cull_mask}

func _v3(value: Vector3) -> Array: return [value.x,value.y,value.z]
func _color(value: Color) -> Array: return [value.r,value.g,value.b,value.a]
func _aabb(value: AABB) -> Dictionary: return {"position":_v3(value.position), "size":_v3(value.size)}
func _fail(message: String) -> void:
	(report.failures as Array).append(message)
	push_error(message)

func _shutdown() -> void:
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
