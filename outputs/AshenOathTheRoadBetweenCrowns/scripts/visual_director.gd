extends Node

var world_environment: WorldEnvironment
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var sky_dome: MeshInstance3D
var sun_disc: MeshInstance3D
var cloud_layer: Node3D
var moon_disc: MeshInstance3D
var current_environment: Environment
var current_zone := "greyfen"
var current_zone_root: Node3D
var current_time_minutes := 990.0
var current_phase := "dusk"

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
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.fog_enabled = true
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.34
	env.adjustment_saturation = 0.92
	var forest_zones := ["wychwood","deep_wood","marsh_crossing","burned_farmstead","hart_glade"]
	var ruin_zones := ["ruins","old_mill","bandit_road","vargan_approach","vargan_court","record_hall","undercroft","assembly"]
	if zone_id in forest_zones:
		_configure_wychwood(env)
	elif zone_id in ruin_zones:
		_configure_ruins(env)
	else:
		_configure_greyfen(env)
	world_environment.environment = env
	current_environment = env
	_position_sky_layer(zone_id)
	set_time(current_time_minutes, current_phase, 0)

func set_time(minutes: float, phase: String, _day_count: int = 0) -> void:
	current_time_minutes = minutes
	current_phase = phase
	if current_environment == null:
		return
	var outdoor := current_zone not in ["record_hall", "undercroft"]
	if not outdoor:
		moon.light_energy = 0.0
		sun.light_energy = 0.18
		_update_zone_night_state(0.75)
		return
	var solar: float = sin((minutes - 360.0) / 1440.0 * TAU)
	var daylight: float = clampf(solar * 1.35, 0.0, 1.0)
	var twilight: float = clampf(1.0 - absf(solar) * 2.6, 0.0, 1.0) if solar > -0.38 else 0.0
	var night: float = clampf(1.0 - daylight - twilight * 0.42, 0.0, 1.0)
	var forest := current_zone in ["wychwood", "deep_wood", "marsh_crossing", "burned_farmstead", "hart_glade"]
	var ruin := current_zone in ["ruins", "old_mill", "bandit_road", "vargan_approach", "vargan_court", "assembly"]
	var day_sky := Color(0.20, 0.32, 0.46) if not forest else Color(0.08, 0.18, 0.19)
	if ruin: day_sky = Color(0.22, 0.25, 0.30)
	var dusk_sky := Color(0.34, 0.16, 0.085) if not forest else Color(0.09, 0.13, 0.12)
	var night_sky := Color(0.008, 0.014, 0.028) if not forest else Color(0.006, 0.020, 0.022)
	current_environment.background_color = night_sky.lerp(dusk_sky, twilight).lerp(day_sky, daylight)
	current_environment.ambient_light_color = Color(0.075, 0.105, 0.16).lerp(Color(0.46, 0.40, 0.33), daylight)
	current_environment.ambient_light_energy = lerp(0.62, 0.88, daylight)
	current_environment.fog_light_color = Color(0.055, 0.080, 0.13).lerp(Color(0.34, 0.40, 0.46), daylight)
	var base_fog: float = 0.065 if forest else (0.038 if ruin else 0.030)
	current_environment.fog_density = base_fog * lerpf(1.12, 0.42, daylight)
	current_environment.adjustment_brightness = lerp(0.96, 1.03, daylight)
	sun.rotation_degrees = Vector3(-8.0 - (minutes / 1440.0) * 360.0, -28.0, 0.0)
	sun.light_color = Color(1.0, 0.48, 0.24).lerp(Color(1.0, 0.91, 0.74), daylight)
	sun.light_energy = daylight * (0.72 if forest else 1.05) + twilight * 0.28
	moon.rotation_degrees = Vector3(sun.rotation_degrees.x + 180.0, 22.0, 0.0)
	moon.light_energy = night * (0.48 if forest else 0.54)
	sun_disc.visible = daylight + twilight > 0.12
	moon_disc.visible = night > 0.18
	var orbit := (minutes / 1440.0) * TAU
	sun_disc.position = Vector3(cos(orbit) * 120.0, max(18.0, sin(orbit) * 85.0), -115.0)
	moon_disc.position = Vector3(-cos(orbit) * 105.0, max(22.0, -sin(orbit) * 76.0), -105.0)
	_update_zone_night_state(night)

func _update_zone_night_state(night_amount: float) -> void:
	if current_zone_root == null:
		return
	for node in current_zone_root.find_children("*", "OmniLight3D", true, false):
		var light := node as OmniLight3D
		var lower := light.name.to_lower()
		if lower.contains("lantern") or lower.contains("shrine") or lower.contains("warm") or lower.contains("window"):
			light.visible = night_amount > 0.18
	for node in current_zone_root.find_children("*", "MeshInstance3D", true, false):
		var lower := node.name.to_lower()
		if lower.contains("litwindow") or lower.contains("sidewindow") or lower.contains("lanternglow") or lower.contains("lightpool") or lower.contains("lanternpool") or lower.contains("shrineglow") or lower.contains("roadcandle"):
			(node as MeshInstance3D).visible = night_amount > 0.10

func _configure_greyfen(env: Environment) -> void:
	env.background_color = Color(0.040, 0.048, 0.060)
	env.fog_light_color = Color(0.38, 0.31, 0.24)
	env.fog_density = 0.028
	env.ambient_light_color = Color(0.17, 0.15, 0.13)
	sun.rotation_degrees = Vector3(-52, 24, 0)
	sun.light_color = Color(1.00, 0.55, 0.28)
	sun.light_energy = 0.72
	_set_sky_colors(Color(0.040, 0.048, 0.064), Color(1.0, 0.46, 0.18), Color(0.36, 0.30, 0.24, 0.24))

func _configure_wychwood(env: Environment) -> void:
	env.background_color = Color(0.018, 0.034, 0.034)
	env.fog_light_color = Color(0.13, 0.25, 0.22)
	env.fog_density = 0.070
	env.ambient_light_color = Color(0.09, 0.13, 0.13)
	sun.rotation_degrees = Vector3(-62, -22, 0)
	sun.light_color = Color(0.34, 0.55, 0.72)
	sun.light_energy = 0.55
	_set_sky_colors(Color(0.018, 0.034, 0.036), Color(0.62, 0.82, 0.92), Color(0.11, 0.18, 0.17, 0.34))

func _configure_ruins(env: Environment) -> void:
	env.background_color = Color(0.035, 0.035, 0.038)
	env.fog_light_color = Color(0.20, 0.18, 0.16)
	env.fog_density = 0.044
	env.ambient_light_color = Color(0.16, 0.15, 0.14)
	sun.rotation_degrees = Vector3(-50, 45, 0)
	sun.light_color = Color(0.72, 0.62, 0.50)
	sun.light_energy = 0.42
	_set_sky_colors(Color(0.040, 0.040, 0.046), Color(0.78, 0.66, 0.48), Color(0.22, 0.20, 0.18, 0.32))

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
	var sun_mesh = PlaneMesh.new()
	sun_mesh.size = Vector2(1.0, 1.0)
	sun_disc.mesh = sun_mesh
	sun_disc.scale = Vector3(9.5, 9.5, 9.5)
	sun_disc.material_override = _emissive_billboard_material(Color(1.0, 0.50, 0.20), 1.45, 0.90)
	add_child(sun_disc)
	moon_disc = MeshInstance3D.new()
	moon_disc.name = "MoonDisc"
	moon_disc.mesh = sun_mesh.duplicate()
	moon_disc.scale = Vector3(6.5, 6.5, 6.5)
	moon_disc.material_override = _emissive_billboard_material(Color(0.62, 0.76, 1.0), 0.62, 0.86)
	add_child(moon_disc)

	cloud_layer = Node3D.new()
	cloud_layer.name = "CloudLayer"
	add_child(cloud_layer)
	for i: int in range(7):
		var cloud = MeshInstance3D.new()
		cloud.name = "CloudPlane"
		var cloud_mesh = PlaneMesh.new()
		cloud_mesh.size = Vector2(1.0, 1.0)
		cloud.mesh = cloud_mesh
		cloud.scale = Vector3(36.0 + i * 3.4, 1.0, 8.0 + (i % 3) * 2.0)
		cloud.rotation_degrees.x = -78.0
		cloud.rotation_degrees.y = -10.0 + i * 6.0
		cloud.position = Vector3(-62.0 + i * 22.0, 32.0 + (i % 2) * 5.0, -72.0 + (i % 3) * 24.0)
		cloud.material_override = _emissive_billboard_material(Color(0.32, 0.28, 0.24), 0.12, 0.20)
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
		cloud_layer.visible = false
	elif zone_id in ["ruins","old_mill","bandit_road","vargan_approach","vargan_court","record_hall","undercroft","assembly"]:
		origin = Vector3(0, -12, 0)
		sun_disc.position = Vector3(110, 70, -95)
		sun_disc.rotation_degrees = Vector3(60, 42, 0)
		cloud_layer.position = Vector3(0, 2, -4)
		cloud_layer.visible = false
	else:
		origin = Vector3(0, -10, 0)
		sun_disc.position = Vector3(90, 52, -115)
		sun_disc.rotation_degrees = Vector3(63, 32, 0)
		cloud_layer.position = Vector3(0, 0, 0)
		cloud_layer.visible = true
	sky_dome.position = origin

func _set_sky_colors(dome_color: Color, sun_color: Color, cloud_color: Color) -> void:
	if sky_dome != null:
		sky_dome.material_override = _sky_material(dome_color)
	if sun_disc != null:
		sun_disc.material_override = _emissive_billboard_material(sun_color, 1.45, 0.90)
	if cloud_layer != null:
		for child in cloud_layer.get_children():
			if child is MeshInstance3D:
				child.material_override = _emissive_billboard_material(cloud_color, 0.10, cloud_color.a)

func _sky_material(color: Color) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
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
	return material
