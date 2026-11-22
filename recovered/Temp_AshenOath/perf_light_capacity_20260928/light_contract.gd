extends SceneTree

const Router = preload("res://scripts/zone_composition_router.gd")
var failures: Array[String] = []
var counts: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func _wait(game: Node) -> void:
	var deadline := Time.get_ticks_msec() + 45000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if game.game_started and not game.zone_transition_pending:
			if not game.opening_detail_pending or bool(game.zone_root.get_meta("opening_detail_complete", false)):
				return
	failures.append("Complete scene did not settle: " + str(game.current_zone_id))

func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.settings.set_quality_preset("balanced")
	game._new_game()
	await _wait(game)
	for zone in Router.registered_zones():
		if game.current_zone_id != zone:
			game._load_zone(zone, Vector3(0, 1, 8))
			await _wait(game)
		var local: Array = []
		for node in game.zone_root.find_children("*", "Light3D", true, false):
			if node is OmniLight3D or node is SpotLight3D:
				local.append({"path": str(node.get_path()), "energy": node.light_energy, "visible": node.visible, "range": node.omni_range if node is OmniLight3D else node.spot_range})
		counts[zone] = local
		if local.size() > 8:
			failures.append("Capacity would discard lights in " + zone)
	var output := {"scope": "headless light capacity ownership, NOT graphical quality or performance acceptance", "counts": counts, "failures": failures, "max_renderable_lights": ProjectSettings.get_setting("rendering/limits/opengl/max_renderable_lights"), "max_lights_per_object": ProjectSettings.get_setting("rendering/limits/opengl/max_lights_per_object"), "game_sha256": FileAccess.get_sha256("res://scripts/game.gd")}
	var file := FileAccess.open("D:/Temp/AshenOath/perf_light_capacity_20260928/light_contract.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(output, "\t"))
	file.close()
	game.prepare_resource_shutdown()
	for index in 24:
		await process_frame
	game.finalize_resource_shutdown()
	for index in 12:
		await process_frame
	print("VERIFIER_PHASE: SHUTDOWN")
	game.queue_free()
	for index in 8:
		await process_frame
	RenderingServer.force_sync()
	print("LIGHT CAPACITY CONTRACT: ", "PASS" if failures.is_empty() else "FAIL", " ", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
