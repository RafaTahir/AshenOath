extends SceneTree

const ZoneBudget = preload("res://scripts/zone_budget.gd")
const ZoneCompositionRouter = preload("res://scripts/zone_composition_router.gd")

var failures: Array[String] = []
var report: Dictionary = {"limits": ZoneBudget.LIMITS, "zones": {}}

func _initialize() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		_fail("Main scene unavailable")
		_finish()
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.settings.set_quality_preset("balanced")
	game.call("_new_game")
	await _settle_transition(game)
	var zones := ZoneCompositionRouter.registered_zones()
	for zone_id in zones:
		game.call("_load_zone", zone_id, Vector3(0, 1, 8))
		await _settle_transition(game)
		await _settle_retirement(game)
		_verify_zone(game, zone_id)
		_check(game.route_zone_cache.size() <= game.MAX_CACHED_ROUTE_ZONES, "%s retained too many cached zones" % zone_id)
		_check(game.retired_zone_roots.is_empty(), "%s retained retired zone roots after the render-safe release window" % zone_id)
	game.settings.set_quality_preset("potato")
	game.call("_load_zone", "vargan_court", Vector3(0, 1, 8))
	await _settle_transition(game)
	await _settle_retirement(game)
	_verify_zone(game, "vargan_court_potato")
	_write_report()
	game.settings.set_quality_preset("balanced")
	game.queue_free()
	await _frames(4)
	_finish()

func _verify_zone(game, zone_id: String) -> void:
	var snapshot := ZoneBudget.capture(game.zone_root)
	report.zones[zone_id] = snapshot
	print("ZONE_BUDGET %s %s" % [zone_id, JSON.stringify(snapshot)])
	for violation in ZoneBudget.violations(snapshot):
		_fail("%s: %s" % [zone_id, violation])

func _settle_transition(game: Node) -> void:
	for _index in range(12):
		await process_frame
		await physics_frame
		if not bool(game.zone_transition_pending):
			return
	_fail("%s transition did not settle for budget capture" % str(game.current_zone_id))

func _settle_retirement(game: Node) -> void:
	for _index in range(game.ZONE_RETIRE_FRAMES + 6):
		await process_frame
		if game.retired_zone_roots.is_empty():
			return
	_fail("%s retirement did not settle for budget capture" % str(game.current_zone_id))

func _write_report() -> void:
	var directory := ProjectSettings.globalize_path("res://.release-gate")
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory.path_join("perf_001_zone_budgets.json"), FileAccess.WRITE)
	if file != null:
		report["generated_at_utc"] = Time.get_datetime_string_from_system(true)
		report["status"] = "pass" if failures.is_empty() else "fail"
		file.store_string(JSON.stringify(report, "\t"))

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	failures.append(message)
	push_error(message)

func _finish() -> void:
	if failures.is_empty():
		print("ZONE BUDGETS: PASS (%d released configurations)" % report.zones.size())
		quit()
		return
	print("ZONE BUDGETS: FAIL (%d)" % failures.size())
	quit(1)
