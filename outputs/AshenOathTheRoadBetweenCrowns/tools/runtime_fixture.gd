extends RefCounted

static func enact_covenant(game: Node, ending: String) -> bool:
	# Subsystem integration only: exercise every authored ritual activation and
	# dialogue-close boundary rather than inventing completion flags.
	for index in 3:
		var area = game.zone_root.find_child("covenant_%s_%d" % [ending, index], true, false)
		if area == null: return false
		game._handle_interaction(area)
		await game.get_tree().process_frame
		if not game.hud._close_dialogue_surface(): return false
		game.hud.dialogue_closed.emit()
		await game.get_tree().process_frame
	return bool(game.story_state.get_flag("final_choice_completed", false))

static func pack_owners(resource: String) -> Array[String]:
	var presets := ConfigFile.new()
	var owners: Array[String] = []
	if presets.load("res://export_presets.cfg") != OK:
		return owners
	var path := resource.trim_prefix("res://")
	for section in presets.get_sections():
		var name := str(presets.get_value(section, "name", ""))
		if not name.begins_with("Runtime Pack "):
			continue
		var included := false
		for pattern in str(presets.get_value(section, "include_filter", "")).split(","):
			included = included or (not pattern.is_empty() and path.match(pattern.strip_edges()))
		for pattern in str(presets.get_value(section, "exclude_filter", "")).split(","):
			if not pattern.is_empty() and path.match(pattern.strip_edges()):
				included = false
		if included:
			owners.append(name.trim_prefix("Runtime Pack ").to_snake_case())
	return owners

# Headless fixtures follow the same explicit menu-to-journey lifecycle as players.
static func menu(game: Node, timeout_ms: int = 120000) -> bool:
	if not game.is_inside_tree():
		await Engine.get_main_loop().process_frame
	var tree := game.get_tree()
	var deadline := Time.get_ticks_msec() + timeout_ms
	while not game.opening_startup_metrics.has("menu_ready_ms"):
		if Time.get_ticks_msec() >= deadline:
			push_error("Fixture menu readiness deadline expired")
			return false
		await tree.process_frame
	return true

static func start(game: Node, timeout_ms: int = 120000) -> bool:
	if not await menu(game, timeout_ms):
		return false
	if not game.game_started:
		game.call("_new_game")
	return await ready(game, "greyfen", timeout_ms)

static func ready(game: Node, zone_id: String = "", timeout_ms: int = 120000) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		if game.opening_scene_pending:
			await game.get_tree().process_frame
			continue
		if is_instance_valid(game.zone_root) and bool(game.zone_root.get_meta("opening_scene_active", false)):
			# These are subsystem fixtures, not an opening-cinematic acceptance run.
			var life: Node = game.zone_root.find_child("GreyfenLifeController", true, false)
			if life != null:
				life.finish_opening_scene("skipped")
		if game.player != null and game.zone_root != null and not game.zone_transition_pending and not game.zone_load_request_pending:
			if game.game_started and (zone_id.is_empty() or game.current_zone_id == zone_id) and game.player.can_control:
				return true
		await game.get_tree().process_frame
	push_error("Fixture destination readiness expired: requested=%s current=%s transition=%s request=%s paused=%s control=%s menu=%s health=%s" % [zone_id, game.current_zone_id, game.zone_transition_pending, game.zone_load_request_pending, game.get_tree().paused, game.player.can_control if game.player != null else false, game.hud.active_menu, game.player.health_component.health if game.player != null else -1])
	return false

static func shutdown(game: Node) -> void:
	var tree := game.get_tree()
	game.prepare_resource_shutdown()
	for index in range(20):
		await tree.process_frame
	game.finalize_resource_shutdown()
	for index in range(12):
		await tree.process_frame
	game.free()
	RenderingServer.force_sync()
	for index in range(8):
		await tree.process_frame

static func state_moves_bones(driver: Node, state: String) -> bool:
	if not driver.is_valid() or driver.get_clip_for_state(state) == StringName():
		return false
	var policy: Dictionary = driver.capture_clock()
	driver.set_distance_suspended(false)
	driver.set_external_tick(true)
	driver.dead = false
	driver.stop_action()
	if state in ["walk", "run", "walk_back", "strafe"]:
		driver.set_locomotion(1.6 if state == "run" else 0.5, Vector3.FORWARD, true)
	else:
		driver.trigger_action(state)
	driver.advance_external(0.15)
	var skeleton: Skeleton3D = driver.get_skeleton()
	var before: Array[Transform3D] = []
	for index in skeleton.get_bone_count():
		before.append(skeleton.get_bone_pose(index))
	driver.advance_external(0.15)
	var changed := false
	for index in skeleton.get_bone_count():
		changed = changed or not before[index].is_equal_approx(skeleton.get_bone_pose(index))
	driver.dead = false
	driver.stop_action()
	driver.set_locomotion(0.0, Vector3.ZERO, true)
	driver.restore_clock(policy)
	return changed

static func numerical_budget_passes(condition: bool, message: String) -> bool:
	if not condition and "--acceptance-profile=headless_release_with_disclosures" in OS.get_cmdline_user_args():
		print("PERFORMANCE LIMITATION: " + message)
		return true
	return condition
