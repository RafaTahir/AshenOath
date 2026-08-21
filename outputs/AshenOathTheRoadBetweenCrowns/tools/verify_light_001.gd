extends SceneTree

const OUTDOOR_ZONES := [
	"greyfen", "cemetery", "wychwood", "deep_wood", "marsh_crossing",
	"burned_farmstead", "hart_glade", "vargan_approach", "vargan_court", "assembly"
]
const INTERIOR_ZONES := ["record_hall", "undercroft"]
const PHASE_SAMPLES := {
	"dawn": 375.0,
	"day": 720.0,
	"dusk": 1155.0,
	"night": 60.0,
}

var failures: Array[String] = []

func _initialize() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	_check(packed != null, "main scene failed to load")
	if packed == null:
		_finish()
		return
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_new_game")
	await _frames(4)
	var director = game.visual_director
	var clock = game.day_night
	_check(director != null, "VisualDirector is missing")
	_check(clock != null, "DayNightController is missing")
	if director != null and clock != null:
		_verify_profiles(director)
		_verify_phase_states(director, clock)
		_verify_interior_states(director)
		_verify_clock_persistence(clock)
		_verify_quality_density(game, director)
	game.queue_free()
	await process_frame
	_finish()

func _verify_profiles(director: Node) -> void:
	for zone in OUTDOOR_ZONES + INTERIOR_ZONES:
		var profile: Dictionary = director.call("_lighting_profile", zone)
		_check(not profile.is_empty(), "%s has no lighting profile" % zone)
		for key in [
			"day_sky", "dawn_sky", "dusk_sky", "night_sky", "ambient_day",
			"ambient_night", "fog_day", "fog_night", "day_brightness",
			"night_brightness", "sun_energy", "moon_energy", "night_light_threshold"
		]:
			_check(profile.has(key), "%s profile is missing %s" % [zone, key])
		_check(bool(profile.outdoor) == (zone not in INTERIOR_ZONES), "%s indoor/outdoor classification is wrong" % zone)
		_check(float(profile.night_brightness) >= 1.08, "%s night brightness is below the readability floor" % zone)
		_check(float(profile.fog_night) < 0.07, "%s night fog is too dense for gameplay" % zone)

func _verify_phase_states(director: Node, clock: Node) -> void:
	director.apply_zone("greyfen", null)
	for phase in PHASE_SAMPLES:
		clock.set_time(float(PHASE_SAMPLES[phase]), 2)
		_check(clock.current_phase == phase, "%s sample does not resolve to its clock phase" % phase)
		if phase == "day":
			_check(director.sun_disc.visible, "sun is hidden during daytime")
			_check(not director.moon_disc.visible and not director.star_field.visible, "night celestial objects remain visible by day")
			_check(director.sky_backdrop.visible and bool(director.sky_backdrop.get_sky_state().get("clouds_visible", false)), "authored day clouds are hidden")
		elif phase == "night":
			_check(not director.sun_disc.visible, "sun remains visible at night")
			_check(director.moon_disc.visible and director.star_field.visible, "moon or stars are hidden at night")
			_check(director.current_environment.ambient_light_energy >= 0.80, "night ambient energy is below the readability floor")
		elif phase == "dawn":
			_check(director.sun_disc.visible and not director.moon_disc.visible, "dawn celestial transition is inconsistent")
		elif phase == "dusk":
			_check(director.sun_disc.visible != director.moon_disc.visible, "dusk shows both or neither primary celestial body")
	for zone in OUTDOOR_ZONES:
		director.apply_zone(zone, null)
		clock.set_time(720.0, 2)
		var day_colors: Dictionary = director.sky_backdrop.get_rendered_sky_colors()
		clock.set_time(60.0, 2)
		var night_colors: Dictionary = director.sky_backdrop.get_rendered_sky_colors()
		_check(day_colors.get("top") != night_colors.get("top") or day_colors.get("horizon") != night_colors.get("horizon"), "%s day and night sky colors are identical" % zone)

func _verify_interior_states(director: Node) -> void:
	for zone in INTERIOR_ZONES:
		director.apply_zone(zone, null)
		director.set_time(720.0, "day", 0)
		_check(not director.sun_disc.visible and not director.moon_disc.visible, "%s exposes sun or moon" % zone)
		_check(not director.star_field.visible and not director.cloud_layer.visible, "%s exposes outdoor sky layers" % zone)
		var day_energy: float = director.current_environment.ambient_light_energy
		director.set_time(60.0, "night", 0)
		_check(director.current_environment.ambient_light_energy > 0.65, "%s is too dark at night" % zone)
		_check(day_energy != director.current_environment.ambient_light_energy, "%s does not inherit a restrained time tint" % zone)

func _verify_clock_persistence(clock: Node) -> void:
	clock.set_time(1155.0, 4)
	var saved: Dictionary = clock.save_state()
	clock.set_time(720.0, 0)
	clock.load_state(saved)
	_check(is_equal_approx(clock.get_time(), 1155.0), "saved world time did not restore")
	_check(clock.day_count == 4 and clock.current_phase == "dusk", "saved day or phase did not restore")
	clock.set_time_lock(true)
	_check(clock.time_locked, "time lock did not engage")
	clock.set_time_lock(false)

func _verify_quality_density(game: Node, director: Node) -> void:
	_check(director.cloud_layer.get_child_count() == 7, "full cached cloud pool was not constructed")
	director.apply_zone("greyfen", null)
	game.settings.set_quality_preset("balanced")
	director.set_time(720.0, "day", 0)
	_check(int(director.sky_backdrop.get_visible_cloud_count()) == 4, "Balanced authored cloud budget is incorrect")
	_check(director.star_field.multimesh.visible_instance_count == 62, "Balanced star budget is incorrect")
	game.settings.set_quality_preset("potato")
	director.set_time(60.0, "night", 0)
	_check(int(director.sky_backdrop.get_visible_cloud_count()) == 2, "Potato authored cloud budget is incorrect")
	_check(director.star_field.multimesh.visible_instance_count == 28, "Potato star budget is incorrect")
	game.settings.set_quality_preset("balanced")

func _visible_children(node: Node) -> int:
	var count := 0
	for child in node.get_children():
		if child is Node3D and child.visible:
			count += 1
	return count

func _frames(count: int) -> void:
	for _i in range(count):
		await process_frame

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _finish() -> void:
	if not failures.is_empty():
		print("LIGHT-001 VERIFIER: FAIL (%d)" % failures.size())
		quit(1)
		return
	print("LIGHT-001 VERIFIER: PASS")
	quit()
