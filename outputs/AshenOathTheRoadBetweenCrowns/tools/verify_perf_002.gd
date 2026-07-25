extends SceneTree

const ROUTE: Array[String] = [
	"greyfen", "wychwood", "greyfen", "vargan_approach", "greyfen",
	"wychwood", "greyfen",
]

var failures := 0

func _initialize() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	check(scene != null, "Main scene is unavailable")
	if scene == null:
		_finish()
		return
	var game = scene.instantiate()
	root.add_child(game)
	await _frames(3)
	game.call("_new_game")
	await _wait_for_zone(game, "greyfen")
	var baseline_memory := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	for zone_id in ROUTE.slice(1):
		game.call("_load_zone", zone_id, Vector3(0, 1, 7))
		await _wait_for_zone(game, zone_id)
		await _wait_for_retirement(game)
		var snapshot: Dictionary = game.zone_lifecycle_snapshot()
		check(int(snapshot.cached_count) <= 1, "Route cache exceeded one zone in %s" % zone_id)
		check(int(snapshot.retiring_count) == 0, "Retirement did not settle in %s" % zone_id)
		check(int(snapshot.resource_anchor_count) <= game.MAX_SKINNED_RESOURCE_ANCHORS, "Shared skinned-resource anchor cap exceeded")
		check(int(snapshot.material_anchor_count) <= game.MAX_RETIRED_MATERIAL_ANCHORS, "Retired material anchor cap exceeded")
		check(int(snapshot.active_navigation_regions) <= 1, "Duplicate active navigation regions in %s" % zone_id)
	var final_snapshot: Dictionary = game.zone_lifecycle_snapshot()
	var growth := int(final_snapshot.static_memory_bytes) - baseline_memory
	check(growth <= 16 * 1024 * 1024, "Repeated route memory grew by more than 16 MB: %d" % growth)
	check(final_snapshot.transition_history.size() <= game.MAX_TRANSITION_HISTORY, "Transition history is unbounded")
	var warm_samples: Array[float] = []
	for entry in final_snapshot.transition_history:
		if str(entry.get("zone", "")) == "greyfen":
			warm_samples.append(float(entry.get("to_playable_ms", 99999.0)))
	check(warm_samples.size() >= 2, "Warm Greyfen transitions were not measured")
	if warm_samples.size() >= 2:
		check(warm_samples.min() <= 350.0, "No warm transition met the 350 ms Web budget: %s" % [warm_samples])
	print("PERF-002 METRICS: memory_growth_mb=%.2f anchors=%d warm_ms=%s" % [
		float(growth) / (1024.0 * 1024.0),
		int(final_snapshot.resource_anchor_count),
		str(warm_samples),
	])
	game.prepare_resource_shutdown()
	await _wait_for_retirement(game)
	game.queue_free()
	await _frames(5)
	_finish()

func _wait_for_zone(game, zone_id: String) -> void:
	for _index in range(180):
		await process_frame
		if str(game.current_zone_id) == zone_id and game.zone_root != null and not game.zone_transition_pending:
			return
	check(false, "Timed out waiting for zone: %s" % zone_id)

func _wait_for_retirement(game) -> void:
	for _index in range(180):
		await process_frame
		if int(game.zone_lifecycle_snapshot().retiring_count) == 0:
			return
	check(false, "Timed out waiting for staged retirement")

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _finish() -> void:
	print("PERF-002 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
