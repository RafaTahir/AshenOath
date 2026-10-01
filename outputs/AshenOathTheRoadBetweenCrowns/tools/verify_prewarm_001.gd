extends SceneTree

const FRAME_BUDGET_MS := 350.0
const EXTERIOR_ROLES := ["castle_wall", "castle_arch", "castle_roof", "castle_lantern"]
const INTERIOR_ROLES := ["castle_bookcase", "castle_chair", "castle_bench", "castle_table", "castle_weapon_stand"]

var failures: Array[String] = []
var game: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	_check(scene != null, "main scene failed to load")
	if scene == null:
		_finish()
		return
	game = scene.instantiate()
	root.add_child(game)
	await _frames(2)
	game.call("_new_game")
	_check(await _wait_for_zone("greyfen", 12.0), "New Game did not reach Greyfen")
	_check(not bool(game.campaign_visual_prewarm_started), "Greyfen scheduled campaign visual prewarm")
	_check((game.campaign_visual_prewarm_roles as Array).is_empty(), "Greyfen retained Castle prewarm roles")
	for role in EXTERIOR_ROLES + INTERIOR_ROLES:
		_check(not bool(game.asset_helper.is_role_warmed(role)), "Greyfen startup warmed noncritical role %s" % role)

	game.call("_load_zone", "bandit_road", Vector3(-7.0, 0.9, 13.0))
	_check(await _wait_for_zone("bandit_road", 5.0), "Bandit Road did not become playable")
	_check(bool(game.campaign_visual_prewarm_started), "Bandit Road did not schedule adjacent Vargan roles")
	_check(str(game.campaign_visual_prewarm_zone) == "bandit_road", "prewarm source zone was not retained")
	_check((game.campaign_visual_prewarm_roles as Array) == EXTERIOR_ROLES, "Bandit Road selected non-adjacent roles")
	for role in INTERIOR_ROLES:
		_check(not bool(game.asset_helper.is_role_warmed(role)), "Bandit Road warmed Record Hall role %s" % role)

	# Bypass only the intentional eighteen-second idle delay; execute the real
	# role loader and measure its actual main-thread frame cost.
	game.campaign_visual_prewarm_not_before_msec = Time.get_ticks_msec() - 1
	var previous_usec := Time.get_ticks_usec()
	var worst_frame_ms := 0.0
	var first_role_ready := false
	var deadline := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		var now_usec := Time.get_ticks_usec()
		worst_frame_ms = maxf(worst_frame_ms, float(now_usec - previous_usec) / 1000.0)
		previous_usec = now_usec
		if bool(game.asset_helper.is_role_warmed(EXTERIOR_ROLES[0])):
			first_role_ready = true
			break
	_check(first_role_ready, "predictive prewarm did not warm its first adjacent role")
	_check(worst_frame_ms <= FRAME_BUDGET_MS, "predictive prewarm frame %.1f ms exceeded %.0f ms" % [worst_frame_ms, FRAME_BUDGET_MS])

	var generation_before_cancel := int(game.campaign_visual_prewarm_generation)
	game.call("_load_zone", "marsh_crossing", Vector3(-7.0, 0.9, 13.0))
	_check(await _wait_for_zone("marsh_crossing", 5.0), "Marsh Crossing did not become playable")
	var warmed_after_cancel := _warmed_count(EXTERIOR_ROLES)
	await _frames(30)
	_check(not bool(game.campaign_visual_prewarm_started), "prewarm remained active after leaving its source sector")
	_check((game.campaign_visual_prewarm_roles as Array).is_empty(), "cancelled prewarm retained queued roles")
	_check(int(game.campaign_visual_prewarm_generation) > generation_before_cancel, "zone change did not invalidate the prewarm generation")
	_check(_warmed_count(EXTERIOR_ROLES) == warmed_after_cancel, "cancelled prewarm continued loading roles")

	print("PREWARM-001 METRICS: first_role=%s worst_frame_ms=%.1f warmed_before_cancel=%d" % [
		first_role_ready, worst_frame_ms, warmed_after_cancel,
	])
	game.prepare_resource_shutdown()
	await _frames(12)
	if game.has_method("finalize_resource_shutdown"):
		game.finalize_resource_shutdown()
	await _frames(8)
	if game.is_inside_tree():
		root.remove_child(game)
	game.free()
	RenderingServer.force_sync()
	await _frames(4)
	if failures.is_empty():
		print("PREWARM-001 VERIFIER: PASS")
	else:
		print("PREWARM-001 VERIFIER: FAIL (%d)" % failures.size())
		for failure in failures:
			push_error(failure)
	_finish(0 if failures.is_empty() else 1)

func _wait_for_zone(zone_id: String, timeout_seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if str(game.current_zone_id) == zone_id and not bool(game.zone_transition_pending) \
				and game.player != null and bool(game.player.can_control):
			return true
		await process_frame
	return false

func _warmed_count(roles: Array) -> int:
	var count := 0
	for role in roles:
		if bool(game.asset_helper.is_role_warmed(str(role))):
			count += 1
	return count

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _check(condition: bool, message: String) -> void:
	if not condition and message not in failures:
		failures.append(message)

func _finish(code: int = 1) -> void:
	quit(code)
