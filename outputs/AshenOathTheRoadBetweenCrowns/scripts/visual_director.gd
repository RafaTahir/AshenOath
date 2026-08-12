extends Node

var world_environment: WorldEnvironment
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var sky_dome: MeshInstance3D
var sun_disc: MeshInstance3D
var sun_halo: MeshInstance3D
var sun_rays: Node3D
var cloud_layer: Node3D
var moon_disc: MeshInstance3D
var moon_halo: MeshInstance3D
var star_field: MultiMeshInstance3D
var cloud_texture: ImageTexture
var current_environment: Environment
var environment_cache: Dictionary = {}
var night_node_cache: Dictionary = {}
var current_zone := "greyfen"
var current_zone_root: Node3D
var current_time_minutes := 990.0
var current_phase := "dusk"
var current_quality_preset := "balanced"
var reduced_motion := false

const INTERIOR_ZONES := ["record_hall", "undercroft"]
const FOREST_ZONES := ["wychwood", "deep_wood", "marsh_crossing", "burned_farmstead", "hart_glade"]
const CASTLE_ZONES := ["vargan_approach", "vargan_court", "assembly"]

func _ready() -> void:
	world_environment = WorldEnvironment.new()
	add_child(world_environment)
	sun = DirectionalLight3D.new()
	sun.name = "SliceSun"
	sun.shadow_enabled = false
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.name = "SliceMoon"
	moon.shadow_enabled = false
	moon.light_color = Color(0.38, 0.52, 0.72)
	add_child(moon)
	_build_sky_layer()
	apply_zone("greyfen")

func apply_zone(zone_id: String, zone_root: Node3D = null) -> void:
	current_zone = zone_id
	current_zone_root = zone_root
	_invalidate_night_cache()
	var env: Environment = environment_cache.get(zone_id)
	if env == null:
		env = Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.fog_enabled = true
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.adjustment_enabled = true
		_initialize_environment(env, _lighting_profile(zone_id))
		environment_cache[zone_id] = env
	world_environment.environment = env
	current_environment = env
	_position_sky_layer(zone_id)
	set_time(current_time_minutes, current_phase, 0)

func apply_settings(settings: Dictionary) -> void:
	current_quality_preset = str(settings.get("quality_preset", "balanced"))
	reduced_motion = bool(settings.get("reduced_motion", false))
	if current_environment != null:
		set_time(current_time_minutes, current_phase, 0)

func set_time(minutes: float, phase: String, _day_count: int = 0) -> void:
	current_time_minutes = minutes
	current_phase = phase
	if current_environment == null:
		return
	var profile := _lighting_profile(current_zone)
	var weights := _phase_weights(minutes)
	var daylight: float = weights.daylight
	var night: float = weights.night
	var twilight: float = weights.twilight
	if not bool(profile.outdoor):
		moon.light_energy = 0.0
		sun.light_energy = float(profile.interior_directional)
		sky_dome.visible = false
		for celestial in [sun_disc, sun_halo, moon_disc, moon_halo, star_field, cloud_layer]:
			celestial.visible = false
		current_environment.background_mode = Environment.BG_COLOR
		current_environment.background_color = profile.interior_background
		# Keep the renderer clear color in lockstep with the authored interior
		# profile. This is the fallback behind an interior ceiling when ANGLE
		# briefly renders before the WorldEnvironment has propagated.
		RenderingServer.set_default_clear_color(profile.interior_background)
		current_environment.ambient_light_color = profile.ambient_night.lerp(profile.ambient_day, daylight)
		current_environment.ambient_light_energy = lerpf(float(profile.ambient_night_energy), float(profile.ambient_day_energy), daylight)
		current_environment.adjustment_brightness = lerpf(float(profile.night_brightness), float(profile.day_brightness), daylight)
		current_environment.adjustment_saturation = float(profile.saturation)
		current_environment.fog_light_color = profile.interior_fog_color
		current_environment.fog_density = lerpf(float(profile.interior_fog_night), float(profile.interior_fog_day), daylight)
		_update_zone_night_state(night)
		return
	var twilight_sky: Color = profile.dawn_sky if minutes < 720.0 else profile.dusk_sky
	current_environment.background_color = profile.night_sky.lerp(twilight_sky, twilight).lerp(profile.day_sky, daylight)
	RenderingServer.set_default_clear_color(current_environment.background_color)
	current_environment.ambient_light_color = profile.ambient_night.lerp(profile.ambient_day, daylight)
	current_environment.ambient_light_energy = lerpf(float(profile.ambient_night_energy), float(profile.ambient_day_energy), daylight)
	current_environment.fog_light_color = profile.fog_night_color.lerp(profile.fog_day_color, daylight)
	current_environment.fog_density = lerpf(float(profile.fog_night), float(profile.fog_day), daylight)
	current_environment.adjustment_brightness = lerpf(float(profile.night_brightness), float(profile.day_brightness), daylight)
	current_environment.adjustment_contrast = float(profile.contrast)
	current_environment.adjustment_saturation = float(profile.saturation)
	var sun_direction := _solar_direction(minutes)
	sun.global_basis = Basis.looking_at(-sun_direction,Vector3.UP)
	var twilight_sun: Color = profile.dawn_sun if minutes < 720.0 else profile.dusk_sun
	sun.light_color = twilight_sun.lerp(profile.day_sun, daylight)
	sun.light_energy = daylight * float(profile.sun_energy) + twilight * float(profile.twilight_energy)
	moon.global_basis = Basis.looking_at(sun_direction,Vector3.UP)
	moon.light_color = profile.moon_color
	moon.light_energy = night * float(profile.moon_energy)
	_update_sky_cycle(daylight, twilight, night, minutes, profile)
	_update_zone_night_state(smoothstep(float(profile.night_light_threshold), 1.0, night))

func _update_sky_cycle(daylight: float, twilight: float, night: float, minutes: float, profile: Dictionary) -> void:
	var camera := get_viewport().get_camera_3d()
	var sky_origin: Vector3 = camera.global_position if camera != null else Vector3.ZERO
	var view_forward: Vector3 = Vector3(0, 0, -1)
	var view_right: Vector3 = Vector3.RIGHT
	var view_up: Vector3 = Vector3.UP
	if camera != null:
		view_forward = -camera.global_transform.basis.z.normalized()
		view_right = camera.global_transform.basis.x.normalized()
		view_up = camera.global_transform.basis.y.normalized()
	var sun_direction := _solar_direction(minutes)
	var moon_direction := -sun_direction
	# Keep the procedural celestial bodies on a believable, camera-readable arc.
	# The directional lights still use the physical solar vector above; this only
	# prevents a valid sun or moon from disappearing outside the normal gameplay
	# composition on low-FOV laptop cameras.
	var arc_t := clampf((fposmod(minutes, 1440.0) - 330.0) / 870.0, 0.0, 1.0)
	var sun_screen_x := lerpf(-34.0, 34.0, arc_t)
	var sun_screen_y := 10.0 + sin(clampf((fposmod(minutes, 1440.0) - 420.0) / 690.0, 0.0, 1.0) * PI) * 12.0
	var sun_position: Vector3 = sky_origin + view_forward * 88.0 + view_right * sun_screen_x + view_up * sun_screen_y
	var moon_position: Vector3 = sky_origin + view_forward * 86.0 - view_right * sun_screen_x + view_up * (14.0 - sin(clampf((fposmod(minutes, 1440.0) - 420.0) / 690.0, 0.0, 1.0) * PI) * 5.0)
	sun_disc.position = sun_position
	sun_halo.position = sun_position + Vector3(0, 0, 0.4)
	sun_rays.position = sun_position
	moon_disc.position = moon_position
	moon_halo.position = moon_position + Vector3(0, 0, 0.4)
	star_field.position = sky_origin
	cloud_layer.position = sky_origin
	var sun_amount := clampf(daylight+twilight*0.72,0.0,1.0)
	var sun_above_horizon := sun_direction.y > -0.015
	var moon_above_horizon := moon_direction.y > 0.035
	sun_disc.visible = sun_above_horizon and (daylight + twilight) > 0.05
	sun_halo.visible = sun_disc.visible
	sun_rays.visible = sun_disc.visible and sun_amount > 0.14
	moon_disc.visible = not sun_disc.visible and moon_above_horizon and night > 0.05
	moon_halo.visible = moon_disc.visible
	_set_mesh_alpha(sun_disc, 0.92 * sun_amount)
	_set_mesh_alpha(sun_halo, 0.18 * sun_amount)
	_set_mesh_alpha(moon_disc, 0.94 * night)
	_set_mesh_alpha(moon_halo, 0.20 * night)
	star_field.visible = night > 0.22
	sky_dome.visible = false
	_set_mesh_alpha(star_field, clampf((night - 0.10) / 0.70, 0.0, 0.92))
	var quality := _quality_preset()
	if star_field != null and star_field.multimesh != null:
		star_field.multimesh.visible_instance_count = 28 if quality == "potato" else (96 if quality == "quality" else 62)
	# Keep the authored seven-cluster pool resident, then expose a deterministic
	# tier budget. Balanced needs enough depth to read as a sky, while Potato
	# retains two low-overdraw formations instead of collapsing to one card.
	var cloud_count := 2 if quality == "potato" else (7 if quality == "quality" else 4)
	cloud_layer.visible = bool(profile.clouds)
	# Keep cloud formations atmospheric rather than allowing one alpha card to
	# cover the whole gameplay composition, especially on low-FOV laptops.
	var cloud_alpha := clampf(daylight*0.44+twilight*0.38+night*0.16,0.10,0.48)
	var cloud_color := Color(0.92,0.94,0.96) if daylight > twilight else Color(0.82,0.46,0.30)
	if night > 0.55:
		cloud_color = Color(0.18,0.23,0.34)
	for i in range(cloud_layer.get_child_count()):
		var cloud := cloud_layer.get_child(i) as Node3D
		cloud.visible = bool(profile.clouds) and i < cloud_count
		var cloud_drift := 0.0 if _reduced_motion() else fmod(minutes * (0.018 + i * 0.002), 28.0) - 14.0
		var cloud_anchor := Vector3(-58.0 + i * 19.0, 23.0 + float(i % 3) * 5.0, 132.0 + float(i % 3) * 16.0)
		cloud.position = view_right * (cloud_anchor.x + cloud_drift) + view_up * cloud_anchor.y + view_forward * cloud_anchor.z
		for lobe in cloud.get_children():
			if lobe is MeshInstance3D:
				var material := (lobe as MeshInstance3D).material_override as StandardMaterial3D
				if material != null:
					material.albedo_color = Color(cloud_color.r,cloud_color.g,cloud_color.b,cloud_alpha)

func _phase_weights(minutes: float) -> Dictionary:
	minutes = fposmod(minutes, 1440.0)
	if minutes >= 330.0 and minutes < 420.0:
		var dawn_t := smoothstep(0.0, 1.0, (minutes - 330.0) / 90.0)
		return {"daylight": dawn_t, "twilight": sin(dawn_t * PI), "night": 1.0 - dawn_t}
	if minutes >= 420.0 and minutes < 1110.0:
		return {"daylight": 1.0, "twilight": 0.0, "night": 0.0}
	if minutes >= 1110.0 and minutes < 1200.0:
		var dusk_t := smoothstep(0.0, 1.0, (minutes - 1110.0) / 90.0)
		return {"daylight": 1.0 - dusk_t, "twilight": sin(dusk_t * PI), "night": dusk_t}
	return {"daylight": 0.0, "twilight": 0.0, "night": 1.0}

func _solar_direction(minutes: float) -> Vector3:
	minutes = fposmod(minutes, 1440.0)
	var elevation := -0.24
	if minutes >= 330.0 and minutes < 420.0:
		elevation = lerpf(-0.06, 0.28, (minutes - 330.0) / 90.0)
	elif minutes >= 420.0 and minutes < 1110.0:
		var day_t := (minutes - 420.0) / 690.0
		elevation = 0.28 + sin(day_t * PI) * 0.68
	elif minutes >= 1110.0 and minutes < 1200.0:
		elevation = lerpf(0.28, -0.06, (minutes - 1110.0) / 90.0)
	else:
		var night_t := fposmod(minutes - 1200.0, 570.0) / 570.0
		elevation = -0.12 - sin(night_t * PI) * 0.48
	var azimuth := (minutes / 1440.0) * TAU - PI * 0.5
	return Vector3(cos(azimuth), elevation, sin(azimuth) * 0.72).normalized()

func _invalidate_night_cache() -> void:
	for key in night_node_cache.keys():
		var cached: Dictionary = night_node_cache[key]
		var valid_entry := false
		for light in cached.get("lights", []):
			if is_instance_valid(light):
				valid_entry = true
				break
		if not valid_entry:
			night_node_cache.erase(key)
	if current_zone_root != null:
		night_node_cache.erase(current_zone_root.get_instance_id())

func _update_zone_night_state(night_amount: float) -> void:
	if current_zone_root == null:
		return
	var key := current_zone_root.get_instance_id()
	if not night_node_cache.has(key):
		var lights: Array = []
		var meshes: Array = []
		for node in current_zone_root.find_children("*", "OmniLight3D", true, false):
			var lower := node.name.to_lower()
			if lower.contains("lantern") or lower.contains("shrine") or lower.contains("warm") or lower.contains("window"):
				lights.append(node)
		for node in current_zone_root.find_children("*", "MeshInstance3D", true, false):
			var lower := node.name.to_lower()
			if lower.contains("litwindow") or lower.contains("sidewindow") or lower.contains("lanternglow") or lower.contains("lightpool") or lower.contains("lanternpool") or lower.contains("shrineglow") or lower.contains("roadcandle"):
				meshes.append(node)
		night_node_cache[key] = {"lights": lights, "meshes": meshes}
	var cached: Dictionary = night_node_cache[key]
	for light in cached.lights:
		if is_instance_valid(light): light.visible = night_amount > 0.18
	for mesh in cached.meshes:
		if is_instance_valid(mesh): mesh.visible = night_amount > 0.10

func _initialize_environment(env: Environment, profile: Dictionary) -> void:
	env.background_color = profile.night_sky
	env.fog_light_color = profile.fog_night_color
	env.fog_density = float(profile.fog_night)
	env.ambient_light_color = profile.ambient_night
	env.ambient_light_energy = float(profile.ambient_night_energy)
	env.adjustment_brightness = float(profile.night_brightness)
	env.adjustment_contrast = float(profile.contrast)
	env.adjustment_saturation = float(profile.saturation)

func _lighting_profile(zone_id: String) -> Dictionary:
	var profile := {
		"id": "greyfen",
		"outdoor": true,
		"clouds": true,
		"day_sky": Color(0.24, 0.39, 0.56),
		"dawn_sky": Color(0.42, 0.25, 0.20),
		"dusk_sky": Color(0.38, 0.18, 0.10),
		"night_sky": Color(0.020, 0.045, 0.090),
		"interior_background": Color(0.018, 0.015, 0.014),
		"interior_fog_color": Color(0.018, 0.015, 0.014),
		"interior_fog_day": 0.004,
		"interior_fog_night": 0.007,
		"ambient_day": Color(0.48, 0.44, 0.38),
		"ambient_night": Color(0.22, 0.29, 0.43),
		"ambient_day_energy": 0.88,
		"ambient_night_energy": 0.88,
		"fog_day_color": Color(0.38, 0.43, 0.49),
		"fog_night_color": Color(0.12, 0.19, 0.31),
		"fog_day": 0.014,
		"fog_night": 0.027,
		"day_brightness": 1.03,
		"night_brightness": 1.16,
		"contrast": 1.28,
		"saturation": 0.94,
		"day_sun": Color(1.0, 0.94, 0.82),
		"dawn_sun": Color(1.0, 0.54, 0.30),
		"dusk_sun": Color(1.0, 0.42, 0.20),
		"sun_energy": 1.02,
		"twilight_energy": 0.30,
		"moon_color": Color(0.48, 0.62, 0.88),
		"moon_energy": 0.82,
		"night_light_threshold": 0.14,
		"interior_directional": 0.16,
	}
	if zone_id == "cemetery":
		profile.merge({
			"id": "cemetery", "day_sky": Color(0.20, 0.31, 0.40),
			"dawn_sky": Color(0.31, 0.24, 0.22), "dusk_sky": Color(0.27, 0.16, 0.13),
			"night_sky": Color(0.014, 0.034, 0.070), "ambient_day": Color(0.38, 0.39, 0.38),
			"interior_background": Color(0.016, 0.015, 0.016),
			"fog_day": 0.025, "fog_night": 0.046, "moon_energy": 0.90,
		}, true)
	elif zone_id in FOREST_ZONES:
		profile.merge({
			"id": "hart" if zone_id == "hart_glade" else "forest",
			"day_sky": Color(0.10, 0.23, 0.25), "dawn_sky": Color(0.19, 0.25, 0.22),
			"dusk_sky": Color(0.10, 0.16, 0.15), "night_sky": Color(0.010, 0.038, 0.060),
			"ambient_day": Color(0.29, 0.38, 0.34), "ambient_night": Color(0.18, 0.31, 0.38),
			"fog_day_color": Color(0.16, 0.29, 0.27), "fog_night_color": Color(0.08, 0.19, 0.24),
			"fog_day": 0.035, "fog_night": 0.058, "day_brightness": 1.07,
			"night_brightness": 1.20, "sun_energy": 0.72, "moon_energy": 0.92,
			"saturation": 0.89,
		}, true)
		if zone_id == "hart_glade":
			profile.merge({"fog_day": 0.022, "fog_night": 0.034, "moon_energy": 1.02}, true)
	elif zone_id in CASTLE_ZONES or zone_id in ["ruins", "old_mill", "bandit_road"]:
		profile.merge({
			"id": "castle", "day_sky": Color(0.25, 0.29, 0.35),
			"dawn_sky": Color(0.38, 0.29, 0.25), "dusk_sky": Color(0.30, 0.20, 0.17),
			"night_sky": Color(0.020, 0.032, 0.060), "ambient_day": Color(0.42, 0.40, 0.38),
			"interior_background": Color(0.018, 0.016, 0.014),
			"ambient_night": Color(0.24, 0.28, 0.38), "fog_day": 0.020,
			"fog_night": 0.038, "sun_energy": 0.86, "moon_energy": 0.86,
			"contrast": 1.32, "saturation": 0.88,
		}, true)
	elif zone_id in INTERIOR_ZONES:
		profile.merge({
			"id": zone_id, "outdoor": false, "clouds": false,
			"night_sky": Color(0.014, 0.012, 0.012), "interior_background": Color(0.024, 0.019, 0.016),
			"interior_fog_color": Color(0.028, 0.022, 0.018), "interior_fog_day": 0.004, "interior_fog_night": 0.007,
			"ambient_day": Color(0.31, 0.25, 0.20), "ambient_night": Color(0.21, 0.22, 0.28),
			"ambient_day_energy": 0.90, "ambient_night_energy": 0.84,
			"fog_night": 0.012, "day_brightness": 1.10, "night_brightness": 1.14,
			"contrast": 1.22, "saturation": 0.84, "interior_directional": 0.24,
		}, true)
		if zone_id == "record_hall":
			profile.merge({
				"interior_background": Color(0.034, 0.027, 0.022),
				"interior_fog_color": Color(0.040, 0.031, 0.024),
				"ambient_day_energy": 1.08, "ambient_night_energy": 1.00,
				"day_brightness": 1.24, "night_brightness": 1.26,
				"contrast": 1.16, "saturation": 0.90, "interior_directional": 0.34,
			}, true)
	return profile

func _build_sky_layer() -> void:
	sky_dome = MeshInstance3D.new()
	sky_dome.name = "SkyGradientDome"
	var dome_mesh = SphereMesh.new()
	dome_mesh.radius = 1.0
	dome_mesh.height = 2.0
	dome_mesh.radial_segments = 32
	dome_mesh.rings = 16
	sky_dome.mesh = dome_mesh
	sky_dome.scale = Vector3(420, 210, 420)
	sky_dome.material_override = _sky_material(Color(0.040, 0.044, 0.052))
	sky_dome.visible = false
	add_child(sky_dome)

	sun_disc = MeshInstance3D.new()
	sun_disc.name = "SunDisc"
	# A camera-facing disc reads as a distant sun. The former sphere was large
	# enough to look like a glowing prop hanging over the village.
	var sun_mesh := QuadMesh.new()
	sun_mesh.size = Vector2(2.3, 2.3)
	sun_disc.mesh = sun_mesh
	sun_disc.scale = Vector3.ONE
	sun_disc.material_override = _emissive_billboard_material(Color(1.0, 0.94, 0.78), 2.15, 0.96)
	add_child(sun_disc)
	moon_disc = MeshInstance3D.new()
	moon_disc.name = "MoonDisc"
	moon_disc.mesh = sun_mesh.duplicate()
	moon_disc.scale = Vector3(0.92, 0.92, 0.92)
	moon_disc.material_override = _emissive_billboard_material(Color(0.62, 0.76, 1.0), 0.62, 0.86)
	add_child(moon_disc)
	var halo_mesh := QuadMesh.new()
	halo_mesh.size = Vector2.ONE
	sun_halo = _make_celestial_plane("SunHalo", halo_mesh, Vector3(9.0, 9.0, 9.0), Color(1.0, 0.72, 0.32), 0.34, 0.16)
	sun_rays = Node3D.new()
	sun_rays.name = "AtmosphericSunLayer"
	add_child(sun_rays)
	moon_halo = _make_celestial_plane("MoonHalo", halo_mesh, Vector3(8.0, 8.0, 8.0), Color(0.48, 0.68, 1.0), 0.16, 0.18)
	_build_star_field()

	cloud_layer = Node3D.new()
	cloud_layer.name = "CloudLayer"
	add_child(cloud_layer)
	cloud_texture = _build_cloud_texture()
	var cloud_count := 7
	for i: int in range(cloud_count):
		var cloud := Node3D.new()
		cloud.name = "CloudCluster"
		cloud.position = Vector3(-62.0 + i * 22.0, 46.0 + (i % 2) * 6.0, -92.0 + (i % 3) * 18.0)
		cloud.set_meta("base_position", cloud.position)
		# Build each cloud from a few offset, irregular cards. The individual
		# cards share one generated alpha texture, but their overlap breaks the
		# old single-rectangle silhouette without adding an asset or shader.
		var lobe_specs := [
			{"name": "CloudBody", "size": Vector2(24.0 + float(i % 3) * 3.0, 7.8), "position": Vector3(0, 0, 0), "rotation": 0.0, "alpha": 0.52},
			{"name": "CloudLeft", "size": Vector2(17.0, 6.2), "position": Vector3(-8.5, -0.8, 0.5), "rotation": -0.035, "alpha": 0.42},
			{"name": "CloudRight", "size": Vector2(18.5, 6.5), "position": Vector3(9.0, -0.5, 0.8), "rotation": 0.028, "alpha": 0.44},
		]
		for spec in lobe_specs:
			var lobe := MeshInstance3D.new()
			lobe.name = str(spec.name)
			var cloud_mesh := QuadMesh.new()
			cloud_mesh.size = spec.size
			lobe.mesh = cloud_mesh
			lobe.position = spec.position
			lobe.rotation.z = float(spec.rotation)
			lobe.material_override = _cloud_material(Color(0.92, 0.94, 0.96, float(spec.alpha)))
			cloud.add_child(lobe)
		cloud_layer.add_child(cloud)

func _position_sky_layer(zone_id: String) -> void:
	if sky_dome == null:
		return
	var origin = Vector3.ZERO
	if zone_id in ["wychwood","deep_wood","marsh_crossing","burned_farmstead","hart_glade"]:
		origin = Vector3(0, -10, 0)
		sun_disc.position = Vector3(-95, 58, -120)
		sun_disc.rotation_degrees = Vector3(64, -38, 0)
		cloud_layer.position = Vector3(0, 0, 8)
		cloud_layer.visible = true
	elif zone_id in ["ruins","old_mill","bandit_road","vargan_approach","vargan_court","record_hall","undercroft","assembly"]:
		origin = Vector3(0, -12, 0)
		sun_disc.position = Vector3(110, 70, -95)
		sun_disc.rotation_degrees = Vector3(60, 42, 0)
		cloud_layer.position = Vector3(0, 2, -4)
		cloud_layer.visible = zone_id not in ["record_hall", "undercroft"]
	else:
		origin = Vector3(0, -10, 0)
		sun_disc.position = Vector3(90, 52, -115)
		sun_disc.rotation_degrees = Vector3(63, 32, 0)
		cloud_layer.position = Vector3(0, 0, 0)
		cloud_layer.visible = true
	sky_dome.position = origin
	star_field.position = origin

func _make_celestial_plane(node_name: String, source_mesh: Mesh, scale_value: Vector3, color: Color, energy: float, alpha: float) -> MeshInstance3D:
	var plane := MeshInstance3D.new()
	plane.name = node_name
	plane.mesh = source_mesh.duplicate()
	plane.scale = scale_value
	plane.material_override = _emissive_billboard_material(color, energy, alpha)
	add_child(plane)
	return plane

func _build_star_field() -> void:
	star_field = MultiMeshInstance3D.new()
	star_field.name = "ProceduralStarField"
	var star_mesh := SphereMesh.new()
	star_mesh.radius = 0.42
	star_mesh.height = 0.84
	star_mesh.radial_segments = 6
	star_mesh.rings = 3
	star_mesh.material = _emissive_billboard_material(Color(0.72, 0.82, 1.0), 0.72, 0.86)
	var stars := MultiMesh.new()
	stars.transform_format = MultiMesh.TRANSFORM_3D
	stars.instance_count = 96
	stars.mesh = star_mesh
	for i in range(96):
		var angle := float((i * 137) % 360) * PI / 180.0
		var height := 38.0 + float((i * 47) % 58)
		var radius := 112.0 + float((i * 29) % 34)
		var transform := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * (0.55 + float(i % 4) * 0.16)), Vector3(cos(angle) * radius, height, sin(angle) * radius))
		stars.set_instance_transform(i, transform)
	star_field.multimesh = stars
	add_child(star_field)

func _set_mesh_alpha(node: GeometryInstance3D, alpha: float) -> void:
	if node == null:
		return
	var material := node.material_override as StandardMaterial3D
	if material == null and node is MultiMeshInstance3D:
		var multimesh := (node as MultiMeshInstance3D).multimesh
		if multimesh != null and multimesh.mesh != null:
			material = multimesh.mesh.material as StandardMaterial3D
	if material != null:
		material.albedo_color.a = alpha

func _quality_preset() -> String:
	return current_quality_preset

func _reduced_motion() -> bool:
	return reduced_motion

func _set_sky_colors(dome_color: Color, sun_color: Color, cloud_color: Color) -> void:
	if sky_dome != null:
		sky_dome.material_override = _sky_material(dome_color)
	if sun_disc != null:
		sun_disc.material_override = _emissive_billboard_material(sun_color, 1.45, 0.90)
	if cloud_layer != null:
		for child in cloud_layer.get_children():
			for lobe in child.get_children():
				if lobe is MeshInstance3D:
					var material := (lobe as MeshInstance3D).material_override as StandardMaterial3D
					if material != null:
						material.albedo_color = cloud_color

func _build_cloud_texture() -> ImageTexture:
	var image := Image.create(128,64,false,Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 7319
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.045
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.52
	var detail_noise := FastNoiseLite.new()
	detail_noise.seed = 1483
	detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	detail_noise.frequency = 0.095
	detail_noise.fractal_octaves = 2
	for y in range(64):
		for x in range(128):
			var nx := (float(x)/127.0-0.5)*2.0
			var ny := (float(y)/63.0-0.5)*2.0
			var envelope := clampf(1.0-(nx*nx*0.72+ny*ny*1.85),0.0,1.0)
			var detail := noise.get_noise_2d(float(x),float(y))*0.5+0.5
			var fine := detail_noise.get_noise_2d(float(x),float(y))*0.5+0.5
			var shape := clampf(detail*0.58 + fine*0.16 + envelope*0.54, 0.0, 1.0)
			var edge := smoothstep(0.02, 0.22, envelope)
			var alpha := smoothstep(0.46, 0.71, shape) * edge
			var shade := lerpf(0.56, 1.0, clampf(1.0-float(y)/63.0+detail*0.16,0.0,1.0))
			image.set_pixel(x,y,Color(shade,shade,shade,alpha))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

func _cloud_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = cloud_texture
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _sky_material(color: Color) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	return material

func _emissive_billboard_material(color: Color, energy: float, alpha: float) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.no_depth_test = true
	return material
