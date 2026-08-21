extends SceneTree

const OUTDOOR_ZONES := ["greyfen", "wychwood", "cemetery", "vargan_approach", "hart_glade"]
const INTERIOR_ZONES := ["record_hall", "undercroft"]
var failures: Array[String] = []

func _initialize() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	_check(packed != null, "main scene is unavailable")
	if packed == null:
		_finish()
		return
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_new_game")
	await _frames(6)
	var director = game.visual_director
	_check(director != null, "VisualDirector is unavailable")
	if director == null:
		_finish()
		return
	_check(not director.sky_canvas.visible, "Production sky still exposes the screen-space CanvasLayer")
	_check(director.sun_disc.material_override.no_depth_test == false, "Sun disc is not depth-tested")
	var backdrop = director.sky_backdrop
	_check(backdrop != null, "SKY-003 authored backdrop is missing")
	if backdrop != null:
		_check(str(backdrop.get_meta("ticket", "")) == "SKY-003", "SKY-003 backdrop metadata is missing")
		_check(backdrop.has_method("get_sky_state"), "SKY-003 backdrop state contract is missing")
		_check(backdrop.has_method("get_visible_cloud_count"), "SKY-003 cloud budget contract is missing")
		_check(backdrop.has_method("get_visible_star_count"), "SKY-003 star budget contract is missing")
	_verify_exterior_states(director, backdrop)
	_verify_interior_suppression(director, backdrop)
	_verify_quality_budgets(game, director, backdrop)
	game.queue_free()
	await process_frame
	_finish()

func _verify_exterior_states(director: Node, backdrop: Node) -> void:
	for zone in OUTDOOR_ZONES:
		director.apply_zone(zone, null)
		director.set_time(720.0, "day", 0)
		var day_state: Dictionary = backdrop.get_sky_state()
		_check(bool(day_state.get("outdoor", false)), "%s day backdrop is not outdoor" % zone)
		_check(bool(day_state.get("sun_visible", false)), "%s day sun is not visible" % zone)
		_check(not bool(day_state.get("moon_visible", true)), "%s day moon is visible" % zone)
		_check(not bool(day_state.get("stars_visible", true)), "%s day stars are visible" % zone)
		director.set_time(60.0, "night", 0)
		var night_state: Dictionary = backdrop.get_sky_state()
		_check(not bool(night_state.get("sun_visible", true)), "%s night sun is visible" % zone)
		_check(bool(night_state.get("moon_visible", false)), "%s night moon is hidden" % zone)
		_check(bool(night_state.get("stars_visible", false)), "%s night stars are hidden" % zone)
		_check(director.current_environment.background_color != director._lighting_profile(zone).day_sky, "%s day profile is not applied" % zone)

func _verify_interior_suppression(director: Node, backdrop: Node) -> void:
	for zone in INTERIOR_ZONES:
		director.apply_zone(zone, null)
		director.set_time(720.0, "day", 0)
		var state: Dictionary = backdrop.get_sky_state()
		_check(not bool(state.get("outdoor", true)), "%s is marked outdoor" % zone)
		_check(not backdrop.visible, "%s backdrop remains visible indoors" % zone)
		_check(not director.sun_disc.visible and not director.moon_disc.visible, "%s exposes celestial meshes" % zone)
		_check(not director.cloud_layer.visible and not director.star_field.visible, "%s exposes outdoor layers" % zone)

func _verify_quality_budgets(game: Node, director: Node, backdrop: Node) -> void:
	director.apply_zone("greyfen", null)
	game.settings.set_quality_preset("potato")
	director.set_time(60.0, "night", 0)
	_check(int(backdrop.get_visible_cloud_count()) == 2, "Potato sky cloud budget is incorrect")
	_check(int(backdrop.get_visible_star_count()) == 28, "Potato sky star budget is incorrect")
	game.settings.set_quality_preset("balanced")
	director.set_time(720.0, "day", 0)
	_check(int(backdrop.get_visible_cloud_count()) == 4, "Balanced sky cloud budget is incorrect")
	_check(int(backdrop.get_visible_star_count()) == 0, "Balanced day stars are not suppressed")
	game.settings.set_quality_preset("quality")
	director.set_time(60.0, "night", 0)
	_check(int(backdrop.get_visible_cloud_count()) == 6, "Quality sky cloud budget is incorrect")
	_check(int(backdrop.get_visible_star_count()) == 96, "Quality sky star budget is incorrect")
	game.settings.set_quality_preset("balanced")

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _finish() -> void:
	if failures.is_empty():
		print("SKY-003 VERIFIER: PASS")
		quit(0)
		return
	print("SKY-003 VERIFIER: FAIL (%d)" % failures.size())
	quit(1)
