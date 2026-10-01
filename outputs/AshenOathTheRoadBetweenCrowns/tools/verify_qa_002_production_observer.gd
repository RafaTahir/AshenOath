extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	_check(scene != null, "Main scene is unavailable")
	if scene == null:
		quit(1)
		return
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_new_game")
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline and (not bool(game.get("game_started")) or bool(game.get("opening_detail_pending"))):
		await process_frame
	_check(bool(game.get("game_started")) and not bool(game.get("opening_detail_pending")), "Greyfen did not become ready")
	var bridge := game.get("production_observation_bridge") as Node
	_check(bridge != null, "Production read-only observer is missing")
	if bridge != null:
		var story := game.get("story_state") as Node
		var inventory := game.get("inventory") as Node
		var before_flags: Dictionary = (story.get("flags") as Dictionary).duplicate(true)
		var before_items: Dictionary = (inventory.get("items") as Dictionary).duplicate(true)
		var state: Dictionary = bridge.call("snapshot_for_game", game)
		_check(state.get("schema_version") == 2 and state.get("read_only") == true, "Observer schema or read-only identity drifted")
		_check(bool(state.get("ready")) and state.get("zone") == "greyfen", "Observer lost actual New Game readiness")
		_check(state.get("player", {}).get("position", {}) is Dictionary, "Player coordinates are missing")
		_check(state.get("player", {}).has("stamina") and state.get("player", {}).has("weapon_mode") and state.get("player", {}).has("attack_cooldown"), "Combat/weapon observation is incomplete")
		_check(state.get("camera", {}).has("yaw"), "Camera bearing is missing")
		_check(state.get("camera", {}).has("locked_target_id"), "Target-lock observation is missing")
		_check(_has_target(state.get("gates", []), "wychwood"), "Wychwood gate is absent from the read-only catalog")
		_check(_has_id(state.get("interactions", []), "sister_anwen"), "Anwen is absent from the read-only catalog")
		_check(state.get("quests", {}).has("objectives") and state.get("quests", {}).has("objectives_done") and state.get("quests", {}).has("world_flags") and state.get("story", {}).has("flags"), "Quest/choice observation is incomplete")
		_check(state.get("inventory", {}).has("items") and state.get("saves", {}).has("manual"), "Inventory/save observation is incomplete")
		_check(state.get("audio", {}).has("music_state") and state.get("audio", {}).has("music_playing") and state.get("input", {}).has("context"), "Audio/input observation is incomplete")
		_check(state.get("settings", {}).has("subtitle_scale") and state.get("settings", {}).has("custom_bindings") and state.get("ui", {}).has("viewport"), "Accessibility/UI observation is incomplete")
		_check(not state.has("command_result"), "Production observer exposes a command result")
		_check((story.get("flags") as Dictionary) == before_flags and (inventory.get("items") as Dictionary) == before_items, "Reading the snapshot mutated gameplay state")
		var route: Dictionary = bridge.call("route_for_id", game, "sister_anwen")
		_check(route.get("read_only") == true and route.get("ok") == true and not (route.get("points") as Array).is_empty(), "Anwen read-only route is unavailable")
		if not route.get("points", []).is_empty():
			var endpoint: Dictionary = route.points.back()
			var position := Vector3(float(endpoint.x), float(endpoint.y), float(endpoint.z))
			for entry in bridge.get("_catalog_interactions"):
				if str(entry.get("interaction_id")) == "sister_anwen":
					_check(position.distance_to(entry.global_position) >= 1.8, "Dialogue route walks into the speaker origin")
		for id in ["grave_harl", "grave_child", "grave_soldier", "chapel_door"]:
			var target: Node3D
			for entry in bridge.get("_catalog_interactions"):
				if str(entry.get("interaction_id")) == id:
					target = entry
			_check(target != null, "Missing cemetery route fixture: " + id)
			if target == null:
				continue
			var approach: Dictionary = bridge.call("route_for_id", game, id)
			var points: Array = approach.get("points", [])
			_check(bool(approach.get("ok")) and not points.is_empty(), "No physical approach route: " + id)
			if not points.is_empty():
				var endpoint: Dictionary = points.back()
				var position := Vector3(float(endpoint.x), float(endpoint.y), float(endpoint.z))
				_check(position.distance_to(target.global_position) <= 2.8, "Route ended outside interaction range: " + id)
				_check(game.spatial_service.is_walkable_position(position, 0.55), "Route ended inside scenery: " + id)
		_check(bridge.call("route_for_id", game, "not_a_real_interaction").get("ok") == false, "Unknown route target was accepted")
		_check((story.get("flags") as Dictionary) == before_flags and (inventory.get("items") as Dictionary) == before_items, "Route lookup mutated gameplay state")
		var second: Dictionary = bridge.call("snapshot_for_game", game)
		_check(second.get("read_only") == true and second.get("zone") == "greyfen", "Repeated observation became invalid")
		var hud := game.get("hud") as Node
		hud.call("show_dialogue", {"name": "Observer fixture", "pages": [{"text": "Read-only choice"}], "actions": [{"label": "Witness"}, {"label": "Mercy"}]})
		await process_frame
		var dialogue_state: Dictionary = bridge.call("snapshot_for_game", game)
		_check(dialogue_state.get("dialogue", {}).get("visible") == true, "Visible dialogue was not observed")
		_check(dialogue_state.get("dialogue", {}).get("actions") == ["Witness", "Mercy"], "Dialogue choice labels were not observed")
		_check(int(dialogue_state.get("dialogue", {}).get("focused_action", -1)) >= 0, "Dialogue focused choice was not observed")
		_check((story.get("flags") as Dictionary) == before_flags and (inventory.get("items") as Dictionary) == before_items, "Dialogue observation mutated gameplay state")
		hud.call("hide_menus")
		hud.call("show_vendor", "tor_forge", game.get("vendor_service"), inventory, game.get("quests"), story)
		await process_frame
		var vendor_state: Dictionary = bridge.call("snapshot_for_game", game)
		var vendor_ui: Dictionary = vendor_state.get("ui", {})
		_check(bool(vendor_ui.get("inventory_visible", false)), "Visible vendor menu was not observed")
		var found_arrow := false
		var found_close := false
		for entry in vendor_ui.get("buttons", []):
			if str(entry.get("text", "")).begins_with("Buy Standard Arrow"):
				found_arrow = true
			if str(entry.get("text", "")) == "Close":
				found_close = true
			_check(entry.has("focused") and entry.has("enabled") and entry.has("position") and entry.has("size"), "Vendor button observation is incomplete")
		_check(found_arrow and found_close, "Tor's vendor buttons are not visible in read-only observation")
		_check((story.get("flags") as Dictionary) == before_flags and (inventory.get("items") as Dictionary) == before_items, "Vendor observation mutated gameplay state")
		hud.call("hide_menus")
		var fixture_root := Node3D.new()
		var fixture_parent := Node3D.new()
		fixture_root.add_child(fixture_parent)
		root.add_child(fixture_root)
		bridge.call("_refresh_catalog", game, fixture_root)
		var nested := preload("res://scripts/interactable.gd").new() as Area3D
		nested.call("setup", "qa_nested_catalog_entry", "dialogue", "Inspect QA fixture")
		fixture_parent.add_child(nested)
		nested.global_position = Vector3(16.35, 0.24, 7.7)
		await create_timer(1.1).timeout
		bridge.call("_refresh_catalog", game, fixture_root)
		var found_nested := false
		for entry in bridge.get("_catalog_interactions"):
			if is_instance_valid(entry) and str(entry.get("interaction_id")) == "qa_nested_catalog_entry":
				found_nested = true
		_check(found_nested, "Nested interaction added without root/count changes remained invisible")
		bridge.call("_refresh_catalog", game, game.get("zone_root"))
		bridge.get("_catalog_interactions").append(nested)
		var standing_route: Dictionary = bridge.call("route_for_id", game, "qa_nested_catalog_entry")
		var standing_points: Array = standing_route.get("points", [])
		_check(not standing_points.is_empty(), "Shrine conversation approach is unavailable")
		if not standing_points.is_empty():
			var endpoint: Dictionary = standing_points.back()
			var position := Vector3(float(endpoint.x), float(endpoint.y), float(endpoint.z))
			_check(position.distance_to(nested.global_position) >= 1.8 and position.distance_to(nested.global_position) <= 3.6, "Shrine route lacks a usable conversation standing gap")
			_check(game.spatial_service.is_walkable_position(position, 0.55), "Shrine conversation approach intersects scenery")
		fixture_root.queue_free()
		await process_frame
	if game.has_method("prepare_resource_shutdown"):
		game.call("prepare_resource_shutdown")
	await _frames(20)
	if game.has_method("finalize_resource_shutdown"):
		game.call("finalize_resource_shutdown")
	await _frames(12)
	print("VERIFIER_PHASE: SHUTDOWN")
	game.queue_free()
	await _frames(8)
	RenderingServer.force_sync()
	await _frames(4)
	print("QA-002 PRODUCTION OBSERVER: %s" % ("PASS" if failures.is_empty() else "FAIL: " + "; ".join(failures)))
	quit(0 if failures.is_empty() else 1)

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _has_target(entries: Array, target: String) -> bool:
	for entry in entries:
		if entry is Dictionary and str(entry.get("target", "")) == target:
			return true
	return false

func _has_id(entries: Array, id: String) -> bool:
	for entry in entries:
		if entry is Dictionary and str(entry.get("id", "")) == id:
			return true
	return false

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
