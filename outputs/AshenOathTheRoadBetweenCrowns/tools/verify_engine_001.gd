extends SceneTree

const RuntimeServiceRegistry = preload("res://scripts/runtime_service_registry.gd")
const ZoneCompositionRouter = preload("res://scripts/zone_composition_router.gd")

var failures := 0

func _initialize() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	check(scene != null, "Main scene is unavailable")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	_verify_service_boundary(game)
	_verify_composition_contract()
	game.call("_new_game")
	await _frames(4)
	_verify_actor_boundary(game)
	_verify_zone_route(game, "greyfen")
	game.call("_load_zone", "wychwood", Vector3(0, 1, 13))
	await _frames(4)
	_verify_zone_route(game, "wychwood")
	_verify_service_boundary(game)
	print("ENGINE-001 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _verify_service_boundary(game) -> void:
	var registry = game.get("runtime_services")
	check(registry != null, "Runtime service registry is missing")
	if registry == null:
		return
	check(registry.name == "RuntimeServices", "Runtime service registry has an unstable name")
	check(registry.get_parent() == game, "Runtime service registry is not owned by the game root")
	check(bool(registry.get("configured")), "Runtime service registry was not configured")
	check(bool(registry.call("is_complete")), "Runtime service registry is incomplete")
	for id in RuntimeServiceRegistry.REQUIRED_SERVICES:
		var service = registry.call("get_service", id)
		check(service != null, "Missing runtime service: %s" % id)
		if service == null:
			continue
		check(service.get_parent() == registry, "%s is not owned by RuntimeServices" % id)
		check(game.get(id) == service, "game.%s does not reference the registered service" % id)
	check(registry.get_child_count() == RuntimeServiceRegistry.REQUIRED_SERVICES.size(),
		"RuntimeServices contains unexpected or duplicate children")

func _verify_actor_boundary(game) -> void:
	var player = game.get("player")
	var camera = game.get("camera_rig")
	check(player != null and is_instance_valid(player), "Actor factory did not create the player")
	check(camera != null and is_instance_valid(camera), "Actor factory did not create the camera rig")
	if player != null:
		check(player.name == "Player", "Actor factory produced an unexpected player identity")
		check(player.get_parent() == game, "Player is not owned by the game composition root")
	if camera != null:
		check(camera.name == "PlayerCameraRig", "Actor factory produced an unexpected camera identity")
		check(camera.get_parent() == game, "Camera rig is not owned by the game composition root")
	if player != null and camera != null:
		check(player.get("camera_controller") == camera, "Player and camera factory output is not connected")

func _verify_zone_route(game, expected_zone: String) -> void:
	check(ZoneCompositionRouter.supports(expected_zone), "Router does not support %s" % expected_zone)
	check(str(game.get("current_zone_id")) == expected_zone, "Router did not activate %s" % expected_zone)
	var zone = game.get("zone_root")
	check(zone != null and is_instance_valid(zone), "%s composition root is missing" % expected_zone)
	if zone != null:
		check(str(zone.name) == expected_zone, "%s composition root has the wrong identity" % expected_zone)

func _verify_composition_contract() -> void:
	var game_source := FileAccess.get_file_as_string("res://scripts/game.gd")
	check(game_source.contains("RuntimeActorFactory.create_player_camera"),
		"game.gd does not delegate player-camera construction")
	check(game_source.contains("ZoneCompositionRouter.build"),
		"game.gd does not delegate zone routing")
	check(not game_source.contains("PlayerController.new()"),
		"game.gd still constructs PlayerController directly")
	check(not game_source.contains("CameraController.new()"),
		"game.gd still constructs CameraController directly")
	check(not game_source.contains("CampaignSection.new()"),
		"game.gd still selects campaign builders directly")
	var zones := ZoneCompositionRouter.registered_zones()
	for required in ["greyfen", "wychwood", "ruins", "vargan_approach", "hart_glade"]:
		check(required in zones, "Zone router omitted released zone: %s" % required)

func _frames(count: int) -> void:
	for _i in range(count):
		await process_frame

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
