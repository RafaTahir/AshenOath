extends "res://scripts/systems/game_bindings.gd"
## Owns startup operations; configure() injects dependencies.
signal opening_phase_changed(phase: String)

func _opening_stage_required_before_control(stage: String) -> bool:
	return stage in OPENING_DETAIL_STAGES

func _record_opening_stage(root: Node3D, stage: String) -> void:
	var completed: Dictionary = root.get_meta("opening_completed_stages", {})
	completed[stage] = true
	root.set_meta("opening_completed_stages", completed)
	if not game_started and hud != null:
		var done := 0
		for required in OPENING_DETAIL_STAGES:
			if completed.has(required):
				done += 1
		_publish_web_opening_state("building", "Preparing Greyfen: %d / %d stages" % [done, OPENING_DETAIL_STAGES.size()], float(done) / float(OPENING_DETAIL_STAGES.size()))

func _opening_presentation_present(root: Node3D) -> bool:
	var completed: Dictionary = root.get_meta("opening_completed_stages", {})
	for stage in OPENING_DETAIL_STAGES:
		if _opening_stage_required_before_control(stage) and not completed.has(stage):
			return false
	var river := root.find_child("LivingRiverSection", true, false)
	return bool(root.get_meta("greyfen_architecture_complete", false)) \
		and bool(root.get_meta("opening_terrain_ready", false)) \
		and river != null and bool(river.get_meta("river_visuals_ready", false)) \
		and root.find_child("GreyfenAuthoredFrontages", true, false) != null \
		and root.find_child("GreyfenAuthoredOathstone", true, false) != null \
		and root.find_child("BlacksmithAuthoredForge", true, false) != null

func _start_campaign_visual_prewarm() -> void:
	if not game_started or resource_shutdown_prepared or asset_helper == null:
		return
	if not asset_helper.has_method("prewarm_roles"):
		return
	var requested_roles: Array[String] = []
	for raw_role in PREDICTIVE_VISUAL_PREWARM_ROLES.get(current_zone_id, []):
		requested_roles.append(str(raw_role))
	if requested_roles.is_empty():
		_cancel_campaign_visual_prewarm()
		return
	if campaign_visual_prewarm_started and campaign_visual_prewarm_zone == current_zone_id \
			and campaign_visual_prewarm_roles == requested_roles:
		return
	_cancel_campaign_visual_prewarm()
	campaign_visual_prewarm_started = true
	campaign_visual_prewarm_zone = current_zone_id
	campaign_visual_prewarm_roles = requested_roles
	campaign_visual_prewarm_generation += 1
	campaign_visual_prewarm_not_before_msec = Time.get_ticks_msec() + int(CAMPAIGN_VISUAL_PREWARM_DELAY_SECONDS * 1000.0)
	print("LOADING: campaign_visual_prewarm begin zone=%s roles=%d" % [campaign_visual_prewarm_zone, campaign_visual_prewarm_roles.size()])
	_host.call_deferred("_run_campaign_visual_prewarm", campaign_visual_prewarm_generation, 0)

func _cancel_campaign_visual_prewarm() -> void:
	if campaign_visual_prewarm_started or not campaign_visual_prewarm_roles.is_empty():
		campaign_visual_prewarm_generation += 1
	campaign_visual_prewarm_started = false
	campaign_visual_prewarm_zone = ""
	campaign_visual_prewarm_roles.clear()
	campaign_visual_prewarm_not_before_msec = 0

func should_defer_visual_role(role: String, category: String) -> bool:
	if category != "environment" or role not in CAMPAIGN_VISUAL_ROLES:
		return false
	# Potato/mobile intentionally omits optional campaign dressing. Do not leave
	# markers for visuals that this quality tier is guaranteed to reject during
	# deferred hydration; the gameplay-critical collision and route remain live.
	if settings != null and str(settings.settings.get("quality_preset", "balanced")) == "potato":
		return false
	if asset_helper == null or not asset_helper.has_method("is_role_warmed"):
		return true
	return not bool(asset_helper.is_role_warmed(role))

func should_defer_character_role(_role: String, _actor_id: String) -> bool:
	# Destination packs already gate construction. Required people must have a
	# body before their interaction is published, not a delayed visual marker.
	return false

func _schedule_deferred_visual_roles(root: Node3D) -> void:
	if root == null or not is_instance_valid(root):
		return
	if bool(root.get_meta("deferred_visual_roles_pending", false)):
		return
	var markers := _deferred_visual_markers(root)
	if markers.is_empty():
		return
	root.set_meta("deferred_visual_roles_pending", true)
	_host.call_deferred("_run_deferred_visual_roles", root)

func _run_deferred_visual_roles(root: Node3D) -> void:
	# Let the arrival frame and its first input sample settle before parsing any
	# text-backed dressing. This keeps secondary presentation out of the gate's
	# measured handoff while retaining the authored asset replacement shortly
	# after the player arrives.
	var delay_timer := _create_owned_timer(0.45, true)
	await delay_timer.timeout
	if resource_shutdown_prepared or not game_started or root != zone_root or not is_instance_valid(root):
		if is_instance_valid(root):
			root.set_meta("deferred_visual_roles_pending", false)
		return
	var markers := _deferred_visual_markers(root)
	var needs_character_pack := false
	for marker in markers:
		if str(marker.get_meta("deferred_visual_category", "")) == "characters":
			needs_character_pack = true
			break
	if needs_character_pack and OS.has_feature("web") and runtime_packs != null and runtime_packs.has_method("is_ready") \
		and not bool(runtime_packs.is_ready("characters")):
		if runtime_packs.has_method("get_state") and str(runtime_packs.get_state("characters")) == "failed":
			root.set_meta("deferred_visual_roles_pending", false)
			push_error("Deferred character pack failed: %s" % runtime_packs.get_last_error("characters"))
			return
		if runtime_packs.has_method("request_pack"):
			runtime_packs.request_pack("characters")
		var pack_retry := _create_owned_timer(0.5, true)
		await pack_retry.timeout
		if is_instance_valid(root) and root == zone_root and game_started:
			_host.call_deferred("_run_deferred_visual_roles", root)
		return
	for marker in markers:
		if resource_shutdown_prepared or not is_instance_valid(marker) or root != zone_root or not game_started:
			if is_instance_valid(root):
				root.set_meta("deferred_visual_roles_pending", false)
			return
		await _host.get_tree().process_frame
		if resource_shutdown_prepared or not is_instance_valid(marker) or root != zone_root or not game_started:
			if is_instance_valid(root):
				root.set_meta("deferred_visual_roles_pending", false)
			return
		var role := str(marker.get_meta("deferred_visual_role", ""))
		var category := str(marker.get_meta("deferred_visual_category", "environment"))
		var scale_value: Vector3 = marker.get_meta("deferred_visual_scale", Vector3.ONE)
		var actor_id := str(marker.get_meta("deferred_visual_actor_id", ""))
		var visual := _make_role_visual(role, category, scale_value)
		if visual == null:
			# A Potato/mobile run is allowed to omit noncritical environment
			# dressing. This is a deliberate quality decision, not a missing
			# gameplay role, so it must not become a browser console error.
			if category == "environment" and settings != null and str(settings.settings.get("quality_preset", "balanced")) == "potato":
				marker.queue_free()
				continue
			push_error("Deferred runtime visual failed for role '%s'" % role)
			marker.queue_free()
			continue
		var parent := _deferred_visual_host(root, marker)
		if parent == null:
			visual.queue_free()
			continue
		visual.position = marker.position
		visual.rotation = marker.rotation
		if category == "characters" and asset_helper != null and asset_helper.has_method("apply_normalized_scale"):
			asset_helper.apply_normalized_scale(visual, scale_value.y)
		parent.add_child(visual)
		if category == "characters" and actor_id != "":
			parent.set_meta("character_variant_seed", actor_id)
			_configure_npc_animation(visual, actor_id)
			CharacterPresentation.apply_npc(parent, actor_id)
			parent.set_meta("character_deferred_hydrated", true)
		marker.queue_free()
	root.set_meta("deferred_visual_roles_pending", false)
	if visual_director != null:
		visual_director.refresh_zone_lighting(root)

func _deferred_visual_markers(root: Node3D) -> Array[Node3D]:
	var result: Array[Node3D] = []
	if root == null or not is_instance_valid(root):
		return result
	for candidate in root.find_children("*", "Node3D", true, false):
		if candidate.has_meta("deferred_visual_role"):
			result.append(candidate as Node3D)
	return result

func _run_campaign_visual_prewarm(generation: int, role_index: int) -> void:
	if generation != campaign_visual_prewarm_generation or not campaign_visual_prewarm_started:
		return
	if not game_started or resource_shutdown_prepared or asset_helper == null \
			or current_zone_id != campaign_visual_prewarm_zone:
		_cancel_campaign_visual_prewarm()
		return
	if role_index >= campaign_visual_prewarm_roles.size():
		var completed_zone := campaign_visual_prewarm_zone
		print("LOADING: campaign_visual_prewarm complete zone=%s" % completed_zone)
		campaign_visual_prewarm_started = false
		campaign_visual_prewarm_zone = ""
		campaign_visual_prewarm_roles.clear()
		campaign_visual_prewarm_not_before_msec = 0
		return
	if Time.get_ticks_msec() < campaign_visual_prewarm_not_before_msec:
		var wait_seconds := maxf(float(campaign_visual_prewarm_not_before_msec - Time.get_ticks_msec()) / 1000.0, 0.05)
		var wait_timer := _create_owned_timer(minf(wait_seconds, 1.0), true)
		await wait_timer.timeout
		if generation == campaign_visual_prewarm_generation:
			_host.call_deferred("_run_campaign_visual_prewarm", generation, role_index)
		return
	# Never parse an OBJ in the middle of a scene swap or a paused menu. One
	# role per settled frame keeps imported castle dressing out of the cold
	# transition while still warming the exact cache used by the builder.
	if campaign_visual_prewarm_suspended or zone_transition_pending or zone_load_request_pending or _host.get_tree().paused:
		await _host.get_tree().process_frame
		_host.call_deferred("_run_campaign_visual_prewarm", generation, role_index)
		return
	await _host.get_tree().process_frame
	if generation != campaign_visual_prewarm_generation or not game_started or resource_shutdown_prepared:
		return
	if campaign_visual_prewarm_suspended or zone_transition_pending or zone_load_request_pending or _host.get_tree().paused:
		_host.call_deferred("_run_campaign_visual_prewarm", generation, role_index)
		return
	var role := campaign_visual_prewarm_roles[role_index]
	var started_usec := Time.get_ticks_usec()
	var result: Dictionary = asset_helper.prewarm_roles([role])
	var missing: Array = result.get("missing", [])
	print("LOADING: campaign_visual_prewarm role=%s ms=%.1f missing=%s" % [
		role, float(Time.get_ticks_usec() - started_usec) / 1000.0, not missing.is_empty(),
	])
	_host.call_deferred("_run_campaign_visual_prewarm", generation, role_index + 1)

func _on_launch_accepted() -> void:
	if startup_packs_waiting or greyfen_prewarm_started or game_started or _journey_load_pending() or route_zone_cache.has("greyfen"):
		return
	opening_prepare_generation += 1
	if runtime_packs != null:
		runtime_packs.quality_preset = str(settings.settings.get("quality_preset", "balanced"))
	var retry_failed := startup_prepare_failed
	startup_prepare_failed = false
	_publish_web_opening_state("preparing", "Loading opening content...")
	if hud != null and hud.has_method("set_new_game_ready") and not route_zone_cache.has("greyfen"):
		hud.set_new_game_ready(false)
	if OS.has_feature("web") and runtime_packs != null and runtime_packs.has_method("request_startup_packs"):
		runtime_packs.prioritize_zone("greyfen")
		if runtime_packs.startup_packs_ready():
			print("LOADING: startup_pack_ready source=launch")
			_begin_opening_prewarm()
			return
		if startup_packs_waiting:
			return
		startup_packs_waiting = true
		if not runtime_packs.pack_progress.is_connected(Callable(_host, "_on_opening_pack_progress")):
			runtime_packs.pack_progress.connect(Callable(_host, "_on_opening_pack_progress"))
		if runtime_packs.has_signal("pack_ready") and not runtime_packs.pack_ready.is_connected(Callable(_host, "_on_startup_pack_ready")):
			runtime_packs.pack_ready.connect(Callable(_host, "_on_startup_pack_ready"))
		runtime_packs.request_startup_packs(retry_failed)
		# request_startup_packs may mount a cache immediately, before the
		# signal connection above can observe a later state change. Recheck on
		# the next idle frame as well as through pack_ready.
		_host.call_deferred("_begin_opening_prewarm_if_ready", opening_prepare_generation)
		# Cached Web packs can complete synchronously. The signal path handles
		# asynchronous downloads without depending on a paused-tree frame.
		_host.call_deferred("_wait_for_startup_packs_then_prewarm", opening_prepare_generation)
		return
	if not greyfen_prewarm_started and not game_started:
		_begin_opening_prewarm()

func _on_opening_pack_progress(_pack_id: String, _progress: float) -> void:
	if startup_packs_waiting and not startup_prepare_failed and not game_started:
		_publish_web_opening_state("downloading", "Loading opening content...", runtime_packs.startup_pack_progress())

func _on_startup_pack_ready(_pack_id: String) -> void:
	if game_started or startup_prepare_failed or not startup_packs_waiting or runtime_packs == null:
		return
	if not runtime_packs.startup_packs_ready():
		return
	print("LOADING: startup_pack_ready source=signal id=%s" % _pack_id)
	startup_packs_waiting = false
	_begin_opening_prewarm()

func _begin_opening_prewarm_if_ready(generation: int) -> void:
	if not _opening_attempt_current(generation) or not startup_packs_waiting \
			or greyfen_prewarm_started or runtime_packs == null:
		return
	if runtime_packs.has_method("startup_packs_ready") and runtime_packs.startup_packs_ready():
		print("LOADING: startup_pack_ready source=deferred")
		startup_packs_waiting = false
		_begin_opening_prewarm()

func _wait_for_startup_packs_then_prewarm(generation: int) -> void:
	var deadline := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < deadline:
		if not _opening_attempt_current(generation):
			return
		if runtime_packs != null and runtime_packs.has_method("startup_packs_ready") and runtime_packs.startup_packs_ready():
			startup_packs_waiting = false
			_begin_opening_prewarm()
			return
		var failures: Array[String] = runtime_packs.startup_pack_failures() if runtime_packs != null and runtime_packs.has_method("startup_pack_failures") else []
		if not failures.is_empty():
			startup_packs_waiting = false
			_opening_prepare_failed("Opening content could not be prepared: %s. Select Retry to try again." % "; ".join(failures))
			return
		await _host.get_tree().process_frame
	if not _opening_attempt_current(generation):
		return
	startup_packs_waiting = false
	_opening_prepare_failed("Opening content took too long to prepare. Select New Game to retry.")

func _begin_opening_prewarm() -> void:
	if game_started or greyfen_prewarm_started or _journey_load_pending() or route_zone_cache.has("greyfen"):
		return
	# Prepare New Game while the menu is open even when Continue is available.
	# Loading a save cancels this attempt through _discard_menu_opening().
	greyfen_prewarm_started = true
	_host.call_deferred("_prepare_opening_services", opening_prepare_generation)

func _prepare_opening_services(generation: int) -> void:
	await _wait_for_opening_build_slot(generation)
	if not _opening_attempt_current(generation):
		return
	_publish_web_opening_state("services", "Preparing the journey...")
	await _host.get_tree().process_frame
	if not _opening_attempt_current(generation):
		return
	var services_ready: bool = await runtime_services.prepare_gameplay_services(Callable(_host, "_opening_attempt_current").bind(generation))
	if not _opening_attempt_current(generation):
		return
	if not services_ready:
		_opening_prepare_failed("Journey services could not be prepared. Select Retry to try again.")
		return
	_ensure_gameplay_runtime()
	if not gameplay_runtime_ready:
		_opening_prepare_failed("Journey services could not be prepared. Select Retry to try again.")
		return
	_publish_web_opening_state("resources", "Preparing characters and materials...")
	world_materials.begin_prewarm_attempt()
	asset_helper.begin_resource_attempt()
	# Decode required texture leaves before any prop or environment parent can
	# be cached with an incomplete imported material graph, including headless.
	var environment_status: Error = asset_helper.request_environment_resources(["opening"])
	while _opening_attempt_current(generation):
		if environment_status in [OK, ERR_BUSY]:
			environment_status = asset_helper.poll_role_resources(30000)
		if environment_status == OK:
			break
		if environment_status != ERR_BUSY:
			print("LOADING: opening_resource_failure environment=%s" % asset_helper.resource_prewarm_error)
			_opening_prepare_failed("Greyfen's environment could not be prepared. %s Select Retry to try again." % asset_helper.resource_prewarm_error)
			return
		await _host.get_tree().process_frame
	if not _opening_attempt_current(generation):
		return
	# Both platforms now own the opening pack before requesting its resources.
	if DisplayServer.get_name().to_lower() != "headless":
		world_materials.prewarm_surfaces(["forest_ground", "cobblestone", "wet_mud", "medieval_brick", "plaster", "timber", "roof_tiles"], str(settings.settings.get("quality_preset", "balanced")))
		var props_status: Error = asset_helper.request_resource_paths(CharacterPresentation.OPENING_OCCUPATION_PROP_PATHS)
		if props_status != OK:
			_opening_prepare_failed("Greyfen's opening props could not be prepared. Select New Game to retry.")
			return
	if DisplayServer.get_name().to_lower() != "headless":
		var named_roles: Array[String] = ["player_kael", "sister_anwen"]
		for actor_id in OPENING_NAMED_ACTOR_IDS:
			named_roles.append(_role_for_interactable(actor_id))
		var actors_status: Error = asset_helper.request_role_resources(named_roles)
		if actors_status != OK:
			_opening_prepare_failed("Greyfen's opening characters could not be prepared. Select New Game to retry.")
			return
		# Resolve the same variant-safe resources the crowd will actually spawn.
		# Raw authored bodies remain requested only for roles without a prepared recipe.
		var population_script: Script = _gameplay_script("greyfen_life_controller")
		var population_status: Error = asset_helper.request_role_resources(population_script.CROWD_VISUAL_ROLES, true, "opening_population")
		if population_status != OK:
			_opening_prepare_failed("Greyfen's village bodies could not be prepared. Select Retry to try again.")
			return
	# Opening resources have mounted before this point on Web. Later character,
	# monster and campaign packs remain independent of menu readiness.
	print("LOADING: Greyfen prewarm begin")
	_host.call_deferred("_prepare_opening_resources", generation)

func _wait_for_opening_build_slot(generation: int) -> void:
	# Settings/save browsing gets the main thread; an explicit New Game owns it.
	while _opening_attempt_current(generation) and not new_game_start_pending and hud.active_menu != "main":
		await _host.get_tree().process_frame

func _opening_attempt_current(generation: int) -> bool:
	return generation == opening_prepare_generation and not resource_shutdown_prepared \
		and not game_started and not startup_prepare_failed and not _journey_load_pending()

func _prepare_opening_resources(generation: int) -> void:
	if not _opening_attempt_current(generation):
		return
	# Poll before drawing the world: first-use rendering must not consume the
	# asset request timeout or obscure which resource actually failed.
	if DisplayServer.get_name().to_lower() != "headless":
		var deadline := Time.get_ticks_msec() + 30000
		while _opening_attempt_current(generation):
			var surfaces: Error = world_materials.poll_prewarm()
			var actors: Error = asset_helper.poll_role_resources(30000)
			if surfaces == OK and actors == OK:
				break
			if surfaces not in [OK, ERR_BUSY] or actors not in [OK, ERR_BUSY] or Time.get_ticks_msec() >= deadline:
				print("LOADING: opening_resource_failure materials=%s actors=%s" % [world_materials.prewarm_error, asset_helper.resource_prewarm_error])
				var detail := str(world_materials.prewarm_error) + " " + str(asset_helper.resource_prewarm_error)
				_opening_prepare_failed("Greyfen's authored resources could not be prepared. %s Select Retry to try again." % detail.strip_edges())
				return
			await _host.get_tree().process_frame
	if _opening_attempt_current(generation):
		await _wait_for_opening_build_slot(generation)
	if _opening_attempt_current(generation):
		_prewarm_greyfen_after_menu_frame(generation)

func _discard_menu_opening() -> void:
	opening_prepare_generation += 1
	_clear_route_zone_cache()
	_abort_opening_prewarm(zone_root, greyfen_prewarm_spatial_service, "", false)
	startup_packs_waiting = false
	greyfen_prewarm_started = false
	startup_prepare_failed = false
	_host.get_viewport().disable_3d = true

func _restart_menu_opening() -> void:
	if game_started or _journey_load_pending():
		return
	_discard_menu_opening()
	if hud != null:
		hud.set_new_game_ready(false)
		_publish_web_opening_state("preparing", "Preparing the selected visual quality...")
	var generation := opening_prepare_generation
	await _host.get_tree().process_frame
	if _opening_attempt_current(generation):
		_on_launch_accepted()

func _opening_prepare_failed(message: String) -> void:
	if game_started or resource_shutdown_prepared:
		return
	# Retry must not retain a partial world that makes the next build early-out.
	if zone_root != null or player != null or route_zone_cache.has("greyfen"):
		_discard_menu_opening()
	_host.get_viewport().disable_3d = true
	_host.get_tree().paused = true
	opening_prepare_generation += 1
	startup_packs_waiting = false
	greyfen_prewarm_started = false
	startup_prepare_failed = true
	message = message.replace("Select New Game to retry.", "Select Retry to try again.")
	if hud != null and hud.has_method("set_new_game_ready"):
		hud.set_new_game_ready(false)
	if hud != null and hud.has_method("set_new_game_status"):
		hud.set_new_game_status(message)
	_publish_web_opening_state("failed", message)

func _abort_opening_prewarm(prewarm_root: Node3D, prewarm_service: Node, message: String, notify_failure: bool = true) -> void:
	opening_boot_material_restore_generation += 1
	opening_boot_material_restore_queue.clear()
	opening_well_mesh = null
	if prewarm_root != null and is_instance_valid(prewarm_root):
		_retire_zone_root(prewarm_root)
	if zone_root == prewarm_root:
		zone_root = null
	if prewarm_service != null and is_instance_valid(prewarm_service):
		prewarm_service.queue_free()
	if spatial_service == prewarm_service:
		spatial_service = null
	greyfen_prewarm_spatial_service = null
	if player != null and is_instance_valid(player):
		player.queue_free()
	player = null
	if camera_rig != null and is_instance_valid(camera_rig):
		camera_rig.queue_free()
	camera_rig = null
	if notify_failure:
		_opening_prepare_failed(message)

func _publish_web_opening_state(state: String, message: String = "", progress: float = -1.0) -> void:
	opening_phase_changed.emit(state)
	var now := Time.get_ticks_usec()
	var previous := str(opening_startup_metrics.get("phase", ""))
	if state != previous:
		if opening_phase_started_usec > 0:
			opening_startup_metrics[previous + "_ms"] = float(opening_startup_metrics.get(previous + "_ms", 0.0)) + float(now - opening_phase_started_usec) / 1000.0
		opening_phase_started_usec = now
		opening_startup_metrics["phase"] = state
	if hud != null and not game_started:
		hud.set_opening_preparation(state, message, progress, new_game_start_pending)
	if not OS.has_feature("web"):
		return
	var payload := JSON.stringify({
		"state": state,
		"message": message,
		"timestamp_ms": Time.get_ticks_msec(),
		"progress": progress,
		"timings": opening_startup_metrics.duplicate(),
	})
	JavaScriptBridge.eval("window.__ashenOathOpeningState = %s; window.dispatchEvent(new CustomEvent('ashen-oath-opening-progress', {detail:window.__ashenOathOpeningState}));" % payload, false)

func _prewarm_greyfen_after_menu_frame(generation: int = -1) -> void:
	if generation < 0:
		generation = opening_prepare_generation
	if not _opening_attempt_current(generation):
		return
	# Only this attempt may publish a prepared world. Early clicks queue a handoff.
	if game_started or zone_root != null or route_zone_cache.has("greyfen"):
		return
	# Every required scenery/population stage finishes before control on both platforms.
	var prewarm_started := Time.get_ticks_msec()
	_publish_web_opening_state("building", "Building Greyfen's roads and scenery...")
	print("LOADING: Greyfen prewarm build_begin")
	var phase_started := prewarm_started
	var prewarm_service := ZoneSpatialService.new()
	prewarm_service.name = "GreyfenPrewarmSpatialService"
	_host.add_child(prewarm_service)
	prewarm_service.configure("greyfen", _river_center("greyfen"), _zone_half_extents("greyfen"))
	greyfen_prewarm_spatial_service = prewarm_service
	zone_root = Node3D.new()
	zone_root.name = "greyfen"
	zone_root.visible = false
	zone_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	_host.add_child(zone_root)
	spatial_service = prewarm_service
	runtime_light_count = 0
	tree_batch_data.clear()
	deadfall_batch_data.clear()
	prop_batch_data.clear()
	visual_box_batch_data.clear()
	terrain_patch_batch_data.clear()
	house_batch_data.clear()
	house_module_batch_data.clear()
	environment_batches_flushed = false
	var authored_layers := ZoneSceneCatalog.attach("greyfen", zone_root, ["gameplay"])
	if not bool(authored_layers.get("ok", false)):
		push_error("Greyfen authored core failed during prewarm: %s" % ", ".join(authored_layers.get("errors", [])))
		_retire_zone_root(zone_root)
		zone_root = null
		prewarm_service.queue_free()
		spatial_service = null
		_opening_prepare_failed("Greyfen could not be prepared. Select New Game to retry.")
		return
	var prewarm_build := ZoneCompositionRouter.build_core(_host, "greyfen", "opening_boot")
	var build_ms := Time.get_ticks_msec() - phase_started
	print("LOADING: Greyfen prewarm build_complete ms=%d ok=%s" % [build_ms, bool(prewarm_build.get("ok", false))])
	if not bool(prewarm_build.get("ok", false)):
		push_error("Greyfen prewarm composition failed: %s" % ", ".join(prewarm_build.get("errors", [])))
		_retire_zone_root(zone_root)
		zone_root = null
		prewarm_service.queue_free()
		spatial_service = null
		_opening_prepare_failed("Greyfen could not be prepared. Select New Game to retry.")
		return
	var prewarm_root: Node3D = zone_root
	await _host.get_tree().process_frame
	await _wait_for_opening_build_slot(generation)
	if not _opening_attempt_current(generation):
		return
	phase_started = Time.get_ticks_msec()
	var slice_started := Time.get_ticks_usec()
	for visual_bucket in range(OPENING_GAMEPLAY_VISUAL_BUCKETS):
		ZoneCompositionRouter.build_core_detail_stage(_host, "greyfen", "gameplay_visual_%d" % visual_bucket)
		_record_opening_stage(zone_root, "gameplay_visual_%d" % visual_bucket)
		if Time.get_ticks_usec() - slice_started >= OPENING_BUILD_SLICE_USEC:
			await _host.get_tree().process_frame
			await _wait_for_opening_build_slot(generation)
			if not _opening_attempt_current(generation):
				return
			slice_started = Time.get_ticks_usec()
	if not await _publish_opening_batches(generation):
		return
	_add_visual_100_layer("greyfen")
	_apply_first_route_materials(zone_root)
	# Cleared below after every opening stage has been published under cover.
	prewarm_root.set_meta("prewarm_navigation_pending", true)
	prewarm_root.set_meta("opening_build_profile", "opening_boot")
	_clear_environment_batch_buffers()
	var world_finalize_ms := Time.get_ticks_msec() - phase_started
	greyfen_prewarm_spatial_service = prewarm_service
	await _host.get_tree().process_frame
	await _wait_for_opening_build_slot(generation)
	if not _opening_attempt_current(generation):
		return
	# Kael's rig and camera are also expensive to instantiate in WebGL. Prepare
	# them while the launch/menu presentation is already covering the viewport.
	phase_started = Time.get_ticks_msec()
	_spawn_player(Vector3(0, 1, 9.8))
	if player == null or not player.has_required_body():
		_abort_opening_prewarm(prewarm_root, prewarm_service, "Kael's authored body or colours could not be loaded. Select Retry to try again.")
		return
	camera_rig.prepare_view()
	var player_ms := Time.get_ticks_msec() - phase_started
	# Publish only the complete opening; intermediate builds need no GPU draw.
	player.visible = false
	player.set_transition_locked(true)
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	camera_rig.process_mode = Node.PROCESS_MODE_INHERIT
	var gameplay_camera := camera_rig.find_child("Camera3D", true, false) as Camera3D
	if gameplay_camera != null:
		gameplay_camera.current = true
	zone_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	zone_root.position = Vector3.ZERO
	# `_load_zone()` applies this profile immediately before the first gameplay
	# draw. Render the same environment here under the visible menu so WebGL does
	# not compile Greyfen's real sky and lighting only after New Game is clicked.
	if visual_director != null:
		visual_director.apply_zone("greyfen", prewarm_root)
		visual_director.set_opening_boot_budget(false)
		prewarm_root.set_meta("opening_visual_profile_prewarmed", true)
	var was_paused := _host.get_tree().paused
	# Complete first-use mesh and texture decoding under the menu cover. Doing
	# this after control is handed over causes visible 40-70 ms hydration frames.
	opening_well_mesh = load("res://assets_external/environment/village/GreyfenWell_Authored.res") as ArrayMesh
	if opening_well_mesh == null or opening_well_mesh.get_surface_count() != 6:
		_host.get_tree().paused = was_paused
		_abort_opening_prewarm(prewarm_root, prewarm_service, "Greyfen's authored well could not be prepared. Select New Game to retry.")
		return
	slice_started = Time.get_ticks_usec()
	for covered_stage in OPENING_DETAIL_STAGES:
		if bool(prewarm_root.get_meta("opening_completed_stages", {}).get(covered_stage, false)):
			continue
		if not _opening_stage_required_before_control(covered_stage):
			continue
		if not _opening_attempt_current(generation) or not is_instance_valid(prewarm_root):
			return
		environment_batches_flushed = false
		var covered_result := ZoneCompositionRouter.build_core_detail_stage(_host, "greyfen", covered_stage)
		if not bool(covered_result.get("ok", false)):
			_host.get_tree().paused = was_paused
			_abort_opening_prewarm(prewarm_root, prewarm_service, "Greyfen's opening scene could not be prepared. Select New Game to retry.")
			return
		if not await _publish_opening_batches(generation):
			return
		_clear_environment_batch_buffers()
		environment_batches_flushed = true
		_record_opening_stage(prewarm_root, covered_stage)
		if Time.get_ticks_usec() - slice_started >= OPENING_BUILD_SLICE_USEC:
			await _host.get_tree().process_frame
			await _wait_for_opening_build_slot(generation)
			if not _opening_attempt_current(generation):
				return
			slice_started = Time.get_ticks_usec()
	if not _opening_attempt_current(generation):
		return
	if not asset_helper.resource_prewarm_error.is_empty():
		_abort_opening_prewarm(prewarm_root, prewarm_service, "Greyfen's environment could not be prepared. %s Select Retry to try again." % asset_helper.resource_prewarm_error)
		return
	if not _opening_presentation_present(prewarm_root):
		_host.get_tree().paused = was_paused
		_abort_opening_prewarm(prewarm_root, prewarm_service, "Greyfen's scenery is incomplete. Select New Game to retry.")
		return
	_publish_web_opening_state("finalizing", "Finishing Greyfen's routes and characters...")
	prewarm_service.build_navigation(prewarm_root)
	prewarm_root.set_meta("prewarm_navigation_pending", false)
	_validate_zone_render_resources(prewarm_root)
	prewarm_root.set_meta("opening_detail_complete", true)
	if visual_director != null:
		visual_director.refresh_zone_lighting(prewarm_root)
	camera_rig.prepare_view()
	prewarm_root.visible = true
	player.visible = true
	_host.get_viewport().disable_3d = false
	if DisplayServer.get_name().to_lower() != "headless":
		_publish_web_opening_state("first_view", "Preparing Greyfen's first view...")
		# Evaluate the complete, transition-locked rig before its first draw.
		await _host.get_tree().process_frame
		if not _opening_attempt_current(generation):
			return
		await RenderingServer.frame_post_draw
		if not _opening_attempt_current(generation):
			return
		prewarm_root.set_meta("opening_unpaused_frame_prewarmed", true)
		prewarm_root.set_meta("opening_first_frame_rendered", true)
	prewarm_root.set_meta("opening_presentation_ready", true)
	_host.get_tree().paused = was_paused
	# New Game can activate Greyfen while this menu-covered prewarm is still
	# finishing. Never let the background task overwrite the active zone or its
	# spatial service after that handoff.
	if game_started or zone_root != prewarm_root:
		if prewarm_root != null and prewarm_root != zone_root and is_instance_valid(prewarm_root):
			_retire_zone_root(prewarm_root)
		if prewarm_service != null and prewarm_service != spatial_service and is_instance_valid(prewarm_service):
			prewarm_service.queue_free()
		greyfen_prewarm_spatial_service = null
		if audio != null and audio.has_method("prewarm_opening_audio"):
			audio.prewarm_opening_audio()
		if hud != null and hud.has_method("set_new_game_ready"):
			hud.set_new_game_ready(true)
		return
	# Retain the prepared resources while the menu owns the screen.
	_host.get_viewport().disable_3d = true
	_cache_route_zone("greyfen", zone_root, [], _zone_state_signature("greyfen"), true, false, false)
	zone_root = null
	spatial_service = null
	if audio != null and audio.has_method("prewarm_opening_audio"):
		audio.prewarm_opening_audio()
	if hud != null and hud.has_method("set_new_game_status"):
		hud.set_new_game_status("Greyfen is ready.")
	# The actual gameplay-camera frame above is the render readiness boundary.
	greyfen_prewarm_started = false
	_publish_web_opening_state("ready", "Greyfen is ready.")
	_refresh_journey_models()
	if hud != null:
		hud.set_new_game_ready(true)
	print("LOADING: opening_world_render_ready")
	print("LOADING: Greyfen prewarmed total=%dms build=%dms world=%dms player=%dms" % [
		Time.get_ticks_msec() - prewarm_started, build_ms, world_finalize_ms, player_ms,
	])
	if new_game_start_pending:
		_host.get_tree().paused = false
		_start_new_game_world()

func _apply_web_opening_boot_material_budget(world_root: Node, player_root: Node, force_for_test := false) -> void:
	opening_boot_material_restore_generation += 1
	opening_boot_material_restore_queue.clear()
	if not force_for_test and not OS.has_feature("web"):
		return
	# Compatibility/ANGLE blocks the main thread while each lit spatial shader
	# variant reports link completion. The menu-covered boot frame needs only the
	# authored albedo and silhouette; restore the original materials after input
	# is live, one renderer instance per frame.
	for owner in [player_root, world_root]:
		if owner == null or not is_instance_valid(owner):
			continue
		if owner is GeometryInstance3D:
			_apply_opening_boot_material(owner as GeometryInstance3D)
		for descendant in owner.find_children("*", "", true, false):
			if descendant is GeometryInstance3D:
				_apply_opening_boot_material(descendant as GeometryInstance3D)
	if world_root != null and is_instance_valid(world_root):
		world_root.set_meta("opening_boot_material_budget", true)
		world_root.set_meta("opening_boot_material_count", opening_boot_material_restore_queue.size())

func _apply_opening_boot_material(geometry: GeometryInstance3D) -> void:
	if geometry == null or not is_instance_valid(geometry) or not geometry.visible:
		return
	var source_material: Material = geometry.material_override
	if source_material == null and geometry is MeshInstance3D:
		var mesh_instance := geometry as MeshInstance3D
		if mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() > 0:
			source_material = mesh_instance.get_active_material(0)
	elif source_material == null and geometry is MultiMeshInstance3D:
		var multimesh_instance := geometry as MultiMeshInstance3D
		if multimesh_instance.multimesh != null and multimesh_instance.multimesh.mesh != null \
				and multimesh_instance.multimesh.mesh.get_surface_count() > 0:
			source_material = multimesh_instance.multimesh.mesh.surface_get_material(0)
	if source_material == null:
		return
	var boot_material := StandardMaterial3D.new()
	boot_material.resource_name = "OpeningBootUnshaded"
	boot_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	boot_material.disable_receive_shadows = true
	if source_material is BaseMaterial3D:
		var source_base := source_material as BaseMaterial3D
		var boot_color := source_base.albedo_color
		boot_color.a = 1.0
		boot_material.albedo_color = boot_color
	# The covered boot frame needs one shader family, not every authored texture,
	# transparency, culling, and vertex-color combination. Original materials are
	# restored progressively after input is live.
	boot_material.albedo_texture = null
	boot_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	boot_material.cull_mode = BaseMaterial3D.CULL_BACK
	boot_material.vertex_color_use_as_albedo = false
	opening_boot_material_restore_queue.append({
		"node": geometry,
		"material_override": geometry.material_override,
		"cast_shadow": geometry.cast_shadow,
	})
	geometry.material_override = boot_material
	geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _restore_opening_boot_material_entry(entry: Dictionary) -> void:
	var geometry := entry.get("node") as GeometryInstance3D
	if geometry == null or not is_instance_valid(geometry):
		return
	geometry.material_override = entry.get("material_override") as Material
	geometry.cast_shadow = int(entry.get("cast_shadow", GeometryInstance3D.SHADOW_CASTING_SETTING_ON))

func _restore_opening_boot_materials(generation: int) -> void:
	var settle_timer := _create_owned_timer(OPENING_BOOT_MATERIAL_RESTORE_DELAY_SECONDS, true)
	await settle_timer.timeout
	while generation == opening_boot_material_restore_generation \
			and not resource_shutdown_prepared \
			and game_started \
			and current_zone_id == "greyfen" \
			and not opening_boot_material_restore_queue.is_empty():
		var entry: Dictionary = opening_boot_material_restore_queue.pop_front()
		_restore_opening_boot_material_entry(entry)
		await _host.get_tree().process_frame
		var interval_timer := _create_owned_timer(OPENING_BOOT_MATERIAL_RESTORE_INTERVAL_SECONDS, true)
		await interval_timer.timeout
	if generation == opening_boot_material_restore_generation and opening_boot_material_restore_queue.is_empty():
		if visual_director != null and visual_director.is_opening_boot_budget_active():
			visual_director.set_opening_boot_budget(false)
		if zone_root != null and is_instance_valid(zone_root):
			zone_root.set_meta("opening_boot_materials_restored", true)
		print("LOADING: opening_boot_materials_restored")

func _run_opening_detail_stage(generation: int) -> void:
	if resource_shutdown_prepared or generation != opening_detail_generation or not opening_detail_pending:
		return
	# Completion belongs to the cached zone, not to a transient scheduler index.
	# Returning to Greyfen resumes outstanding work without duplicating scenery.
	if zone_root != null and is_instance_valid(zone_root):
		var completed: Dictionary = zone_root.get_meta("opening_completed_stages", {})
		while opening_detail_stage_index < OPENING_DETAIL_STAGES.size() and completed.has(OPENING_DETAIL_STAGES[opening_detail_stage_index]):
			opening_detail_stage_index += 1
	var requested_stage_index := opening_detail_stage_index
	# call_deferred only queues another idle callback; several callbacks can still
	# drain in one browser turn. Let the playable scene settle for a short idle
	# window first, then yield a real frame between every decoration chunk so the
	# browser can paint and accept movement before late scenery compiles.
	var stage := OPENING_DETAIL_STAGES[opening_detail_stage_index] if opening_detail_stage_index < OPENING_DETAIL_STAGES.size() else ""
	if stage == "gameplay_base":
		var gameplay_timer := _create_owned_timer(OPENING_GAMEPLAY_HYDRATE_DELAY_SECONDS, true)
		await gameplay_timer.timeout
	elif opening_detail_stage_index == 0:
		var initial_delay := _create_owned_timer(OPENING_DETAIL_INITIAL_DELAY_SECONDS, true)
		await initial_delay.timeout
	else:
		await _host.get_tree().process_frame
		var stage_delay := _create_owned_timer(OPENING_DETAIL_STAGE_DELAY_SECONDS, true)
		await stage_delay.timeout
	if resource_shutdown_prepared or generation != opening_detail_generation or not opening_detail_pending:
		return
	if not game_started or current_zone_id != "greyfen" or zone_root == null or not is_instance_valid(zone_root):
		opening_detail_pending = false
		return
	# First-hour landmarks belong to the active settlement, not a quest reward.
	# Publish during idle windows even at spawn; the stage/frame budget above
	# still separates work from the initial handoff and from moving actors.
	if player == null or not is_instance_valid(player):
		var retry_timer := _create_owned_timer(OPENING_DETAIL_RETRY_SECONDS, true)
		await retry_timer.timeout
		if generation == opening_detail_generation and opening_detail_pending:
			_host.call_deferred("_run_opening_detail_stage", generation)
		return
	# Every deferred visual/detail stage may reference opening-pack resources.
	# Require the verified startup mount instead of silently constructing
	# fallback presentation from the root PCK.
	if OS.has_feature("web") and runtime_packs != null and not runtime_packs.is_ready("opening"):
		if runtime_packs.get_state("opening") == "failed":
			push_error("Opening detail pack failed: %s" % runtime_packs.get_last_error("opening"))
			opening_detail_pending = false
			return
		var pack_retry_timer := _create_owned_timer(0.25, true)
		await pack_retry_timer.timeout
		if generation == opening_detail_generation and opening_detail_pending:
			_host.call_deferred("_run_opening_detail_stage", generation)
		return
	if opening_detail_stage_index >= OPENING_DETAIL_STAGES.size():
		opening_detail_pending = false
		zone_root.set_meta("opening_detail_complete", true)
		_validate_zone_render_resources(zone_root)
		print("LOADING: Greyfen deferred_detail complete")
		return
	var pending_resource_path := ""
	if stage.begins_with("gameplay_crowd_"):
		var crowd_index := int(stage.trim_prefix("gameplay_crowd_"))
		if crowd_index < CharacterPresentation.OPENING_OCCUPATION_PROP_PATHS.size():
			pending_resource_path = str(CharacterPresentation.OPENING_OCCUPATION_PROP_PATHS[crowd_index])
	elif not OS.has_feature("web") and stage.begins_with("gameplay_"):
		var actor_id := stage.trim_prefix("gameplay_")
		if actor_id in OPENING_NAMED_ACTOR_IDS:
			var actor_role := _role_for_interactable(actor_id)
			pending_resource_path = str(asset_helper.database.get_asset_for_role(actor_role).get("path", ""))
	if pending_resource_path != "":
		var resource_status: Error = asset_helper.poll_role_resources()
		if resource_status not in [OK, ERR_BUSY]:
			push_error("Greyfen resource prewarm failed at %s: %s" % [stage, error_string(resource_status)])
			opening_detail_pending = false
			return
		if not asset_helper.is_resource_cached(pending_resource_path):
			if resource_status == OK:
				push_error("Greyfen staged resource was not requested: %s" % pending_resource_path)
				opening_detail_pending = false
				return
			var resource_retry_timer := _create_owned_timer(OPENING_DETAIL_STAGE_DELAY_SECONDS, true)
			await resource_retry_timer.timeout
			if generation == opening_detail_generation and opening_detail_pending:
				_host.call_deferred("_run_opening_detail_stage", generation)
			return
	if stage == "gameplay_place_0":
		var well_material_status: Error = world_materials.poll_prewarm()
		if well_material_status not in [OK, ERR_BUSY]:
			push_error("Greyfen well material prewarm failed: %s" % error_string(well_material_status))
			opening_detail_pending = false
			return
		if well_material_status == ERR_BUSY:
			var well_retry_timer := _create_owned_timer(OPENING_DETAIL_STAGE_DELAY_SECONDS, true)
			await well_retry_timer.timeout
			if generation == opening_detail_generation and opening_detail_pending:
				_host.call_deferred("_run_opening_detail_stage", generation)
			return
	if stage == "opening_terrain":
		var terrain_status: Error = world_materials.poll_prewarm()
		if terrain_status not in [OK, ERR_BUSY]:
			push_error("Greyfen terrain material prewarm failed: %s" % error_string(terrain_status))
			opening_detail_pending = false
			return
		if terrain_status == ERR_BUSY:
			var terrain_retry_timer := _create_owned_timer(OPENING_DETAIL_STAGE_DELAY_SECONDS, true)
			await terrain_retry_timer.timeout
			if generation == opening_detail_generation and opening_detail_pending:
				_host.call_deferred("_run_opening_detail_stage", generation)
			return
	if generation != opening_detail_generation or requested_stage_index != opening_detail_stage_index:
		return
	var started := Time.get_ticks_msec()
	if stage.begins_with("village_house_"):
		var material_status: Error = world_materials.poll_prewarm()
		var facade_status: Error = asset_helper.poll_role_resources()
		if material_status not in [OK, ERR_BUSY] or facade_status not in [OK, ERR_BUSY]:
			push_error("Greyfen architecture prewarm failed: materials=%s facades=%s" % [error_string(material_status), error_string(facade_status)])
			opening_detail_pending = false
			return
		if material_status == ERR_BUSY or facade_status == ERR_BUSY:
			_host.call_deferred("_run_opening_detail_stage", generation)
			return
	# Each stage gets fresh buffers. Published MultiMeshes remain untouched,
	# while late decoration is still grouped instead of creating one
	# renderer instance per small prop.
	environment_batches_flushed = false
	var published_ids := {}
	for child in zone_root.get_children():
		published_ids[child.get_instance_id()] = true
	var result := ZoneCompositionRouter.build_core_detail_stage(_host, "greyfen", stage)
	if not bool(result.get("ok", false)):
		push_error("Greyfen deferred detail failed at %s: %s" % [stage, ", ".join(result.get("errors", []))])
		opening_detail_pending = false
		return
	if stage == "gameplay_base":
		world_materials.prewarm_surfaces(["forest_ground", "cobblestone", "wet_mud", "medieval_brick", "plaster", "timber", "roof_tiles"], str(settings.settings.get("quality_preset", "balanced")))
		var props_status: Error = asset_helper.request_resource_paths(CharacterPresentation.OPENING_OCCUPATION_PROP_PATHS)
		if props_status != OK:
			push_error("Greyfen occupation prop prewarm request failed: %s" % error_string(props_status))
			opening_detail_pending = false
			return
		if not OS.has_feature("web"):
			var named_roles: Array[String] = []
			for actor_id in OPENING_NAMED_ACTOR_IDS:
				named_roles.append(_role_for_interactable(actor_id))
			var actors_status: Error = asset_helper.request_role_resources(named_roles)
			if actors_status != OK:
				push_error("Greyfen named actor prewarm request failed: %s" % error_string(actors_status))
				opening_detail_pending = false
				return
	_flush_environment_batches()
	_clear_environment_batch_buffers()
	environment_batches_flushed = true
	var published_nodes: Array[Node] = []
	for child in zone_root.get_children():
		if not published_ids.has(child.get_instance_id()):
			published_nodes.append(child)
	if visual_director != null and not published_nodes.is_empty():
		visual_director.refresh_zone_lighting(zone_root, published_nodes)
	if stage in ["gameplay_base", "gameplay_place_0", "gameplay_place_1", "gameplay_place_2", "gameplay_place_3", "gameplay_place_4", "gameplay_side_clues", "gameplay_main_clues", "gameplay_gate_visual", "gameplay_route_markers", "gameplay_story"]:
		_defer_opening_renderables(published_nodes)
	if stage.begins_with("gameplay_"):
		# Gameplay stages replace boot gates and publish actors. Rebuild focus from the
		# published zone tree so no deferred frame can inspect those stale Areas.
		active_interactable = null
		interaction_candidates.clear()
		interaction_area_cache.clear()
		interaction_area_cache_ready = false
		interaction_focus_dirty = true
		interaction_focus_cache_valid = false
		_schedule_deferred_visual_roles(zone_root)
	if stage == "gameplay_farmer_toma":
		# The prewarmed crowd controller predates the deferred named actors.
		var life := zone_root.find_child("GreyfenLifeController", true, false)
		if life != null:
			life.configure(_host, str(settings.settings.get("quality_preset", "balanced")))
	_record_opening_stage(zone_root, stage)
	opening_detail_stage_index += 1
	print("LOADING: Greyfen deferred_detail stage=%s ms=%d" % [stage, Time.get_ticks_msec() - started])
	# Yield between chunks so movement, focus, and audio get a normal frame even
	# on Web/ANGLE. A generation token cancels the continuation on zone travel.
	_host.call_deferred("_run_opening_detail_stage", generation)

func _defer_opening_renderables(published_nodes: Array[Node]) -> void:
	var visual_index := 0
	for published in published_nodes:
		for descendant in published.find_children("*", "", true, false):
			if not descendant is VisualInstance3D or not descendant.visible:
				continue
			descendant.visible = false
			descendant.set_meta("opening_visual_bucket", visual_index % OPENING_GAMEPLAY_VISUAL_BUCKETS)
			visual_index += 1

func _deferred_visual_host(branch: Node, marker: Node) -> Node:
	for child in branch.get_children():
		if child == marker:
			return branch
		var found := _deferred_visual_host(child, marker)
		if found != null:
			return found
	return null
