extends "res://scripts/systems/game_bindings.gd"
## Owns session operations; configure() injects dependencies.
signal session_started()

func _gameplay_script(id: String) -> Script:
	if not gameplay_scripts.has(id):
		var script := load("res://scripts/%s.gd" % id) as Script
		if script == null or not script.can_instantiate():
			push_error("Required gameplay script unavailable: " + id)
			return null
		gameplay_scripts[id] = script
	return gameplay_scripts[id]

func start_session() -> void:
	var ready_started := Time.get_ticks_msec()
	_host.process_mode = Node.PROCESS_MODE_ALWAYS
	zone_residency.name = "ZoneResidencyService"
	_host.add_child(zone_residency)
	zone_residency.configure(Callable(_host, "_validate_zone_render_resources"))
	retired_zone_cleanup_root = Node3D.new()
	retired_zone_cleanup_root.name = "RetiredZoneCleanupRoot"
	retired_zone_cleanup_root.visible = false
	retired_zone_cleanup_root.process_mode = Node.PROCESS_MODE_DISABLED
	_host.add_child(retired_zone_cleanup_root)
	shared_box_mesh = BoxMesh.new()
	shared_box_mesh.size = Vector3.ONE
	var phase_started := Time.get_ticks_msec()
	_host.get_viewport().disable_3d = true
	var environment_ms := Time.get_ticks_msec() - phase_started
	phase_started = Time.get_ticks_msec()
	_setup_runtime()
	performance_budget_monitor = PerformanceBudgetMonitor.new()
	performance_budget_monitor.name = "PerformanceBudgetMonitor"
	_host.add_child(performance_budget_monitor)
	performance_budget_monitor.configure(_host)
	production_observation_bridge = ProductionObservationBridgeScript.new()
	production_observation_bridge.name = "ProductionObservationBridge"
	_host.add_child(production_observation_bridge)
	production_observation_bridge.setup(_host)
	var services_ms := Time.get_ticks_msec() - phase_started
	_refresh_journey_models()
	hud.show_main_menu()
	audio.set_music_state("main_menu")
	_host.get_tree().paused = true
	_host.call_deferred("_prepare_opening_after_menu_render")
	print("LOADING: runtime ready total=%dms environment=%dms services=%dms" % [
		Time.get_ticks_msec() - ready_started, environment_ms, services_ms,
	])
	session_started.emit()

func _prepare_opening_after_menu_render() -> void:
	if DisplayServer.get_name().to_lower() != "headless":
		await RenderingServer.frame_post_draw
	if not _host.is_inside_tree():
		return
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.dispatchEvent(new CustomEvent('ashen-oath-ui-ready'));", false)
	opening_startup_metrics["menu_ready_ms"] = Time.get_ticks_msec()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.dispatchEvent(new CustomEvent('ashen-oath-menu-ready'));", false)
	print("LOADING: usable_menu_ready ms=%d" % Time.get_ticks_msec())
	await _host.get_tree().process_frame
	if not game_started and not _journey_load_pending():
		_on_launch_accepted()

func _restore_browser_session(delta: float) -> void:
	if not OS.has_feature("web"):
		return
	browser_restore_check -= delta
	if browser_restore_check > 0.0:
		return
	browser_restore_check = 0.25
	var revision := int(JavaScriptBridge.eval("window.__ashenOathSessionRestores || 0", true))
	if revision == browser_restore_revision:
		return
	browser_restore_revision = revision
	input_router.reset_transient_input("browser_session_restored")
	if game_started and not _host.get_tree().paused and not _journey_load_pending():
		_pause_game()

func route_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_V:
			_play_voice_smoke_test("voice_sister_anwen_test", "AUDIO: voice_sister_anwen_test")
		elif event.keycode == KEY_B:
			_play_voice_smoke_test("voice_player_test", "AUDIO: voice_player_test")

func route_unhandled_input(event: InputEvent) -> void:
	if not game_started:
		return
	if minigames != null and minigames.is_open():
		return
	if event.is_action_pressed("pause") and not event.is_echo():
		_request_pause_or_back(event)
	elif not _host.get_tree().paused and input_router.accept_event(event, &"interact", "gameplay"):
		_host.get_viewport().set_input_as_handled()
		_dispatch_gameplay_action("interact")
	elif not _host.get_tree().paused and input_router.accept_event(event, &"open_inventory", "gameplay"):
		_host.get_viewport().set_input_as_handled()
		_dispatch_gameplay_action("open_inventory")

func _on_virtual_gameplay_action(request: Dictionary) -> void:
	_dispatch_gameplay_action(str(request.get("action", "")), int(request.get("target_instance_id", 0)))

func _dispatch_gameplay_action(action: String, target_instance_id: int = 0) -> void:
	if not game_started or _host.get_tree().paused or input_router == null or not input_router.is_gameplay_context() or _journey_load_pending() or zone_transition_pending or zone_load_request_pending or opening_pack_waiting or campaign_pack_waiting:
		return
	if minigames != null and minigames.is_open():
		return
	match action:
		"interact":
			var shown: Dictionary = hud.get_interaction_prompt_model()
			var chosen_id: int = target_instance_id if target_instance_id > 0 else int(shown.get("target_instance_id", 0))
			var focused_target: Area3D = instance_from_id(chosen_id) as Area3D if chosen_id > 0 else null
			if is_instance_valid(focused_target) and zone_root != null and zone_root.is_ancestor_of(focused_target) and _interaction_target_valid(focused_target):
				_handle_interaction(focused_target)
			else:
				hud.set_guidance_hint("Face the object and move into clear view.", 2.0)
		"pause":
			_pause_game()
		"open_inventory":
			audio.set_game_paused(true)
			_host.get_tree().paused = true
			_show_preparation_menu()
		"touch_more":
			_show_touch_actions()
		"companion_command":
			_show_companion_commands()

func _request_pause_or_back(event: InputEvent) -> void:
	if is_instance_valid(zone_root) and bool(zone_root.get_meta("opening_scene_active", false)):
		if input_router.accept_event(event, &"pause", input_router.get_context()):
			_host.get_viewport().set_input_as_handled()
			var life := zone_root.find_child("GreyfenLifeController", true, false)
			if life != null: life.finish_opening_scene("skipped")
		return
	if _journey_load_pending():
		if event.is_action_pressed("pause") and not event.is_echo():
			_host.get_viewport().set_input_as_handled()
			_cancel_journey_load()
		return
	if input_router == null or not input_router.accept_event(event, &"pause", input_router.get_context()):
		return
	_host.get_viewport().set_input_as_handled()
	if zone_transition_pending or zone_load_request_pending or opening_pack_waiting or campaign_pack_waiting:
		return
	if _host.get_tree().paused or not input_router.is_gameplay_context():
		# The active surface owns Back. Death, ending and transition screens must
		# never reach generic Resume merely because the tree happens to be paused.
		hud.request_back()
		return
	_dispatch_gameplay_action("pause")

func _invalidate_interaction_prompt() -> void:
	interaction_focus_dirty = true
	interaction_focus_cache_valid = false
	_publish_interaction_prompt()

func _publish_interaction_prompt() -> void:
	if hud == null:
		return
	if input_router == null or not input_router.is_gameplay_context() or _host.get_tree().paused \
			or not is_instance_valid(active_interactable) or not _interaction_target_valid(active_interactable):
		hud.set_interaction_prompt({"available": false})
		return
	var prompt_model: Dictionary = active_interactable.get_prompt_model() if active_interactable.has_method("get_prompt_model") else {"text": active_interactable.get_context_prompt()}
	prompt_model["target_id"] = str(active_interactable.interaction_id)
	prompt_model["target_instance_id"] = active_interactable.get_instance_id()
	prompt_model["binding"] = input_router.action_label("interact")
	prompt_model["available"] = true
	hud.set_interaction_prompt(prompt_model)

func _on_input_context_changed(_context: String) -> void:
	if is_instance_valid(player) and player.has_method("cancel_buffered_input"):
		player.cancel_buffered_input("context_change")
	if interaction_focus != null:
		interaction_focus.reset()
	if is_instance_valid(active_interactable):
		_set_interactable_label_visible(active_interactable, false)
	active_interactable = null
	_invalidate_interaction_prompt()

func _on_transient_input_reset(reason: String) -> void:
	if is_instance_valid(player) and player.has_method("cancel_buffered_input"):
		player.cancel_buffered_input(reason)
	_invalidate_interaction_prompt()

func _begin_gameplay_handoff(reason: String) -> void:
	if quest_hud_coordinator != null:
		quest_hud_coordinator.reset_navigation_dial(hud)
	navigation_dial_refresh_cooldown = 0.0
	if input_router != null:
		input_router.suspend_gameplay(reason)
	if is_instance_valid(player) and player.has_method("cancel_buffered_input"):
		player.cancel_buffered_input(reason)
	if interaction_focus != null:
		interaction_focus.reset()
	_invalidate_interaction_prompt()

func _finish_gameplay_handoff() -> void:
	if neighbor_arrival_pending and not neighbor_crossing_pending and not zone_transition_pending and not zone_load_request_pending and not opening_pack_waiting and not campaign_pack_waiting:
		neighbor_arrival_pending = false
		hud.end_journey_load(true)
	journey_loading.try_finish(_host)
	_restore_active_world_view()
	if input_router == null or input_router.get_context() != "transition":
		_publish_journey_arrival()
		return
	if not game_started or _host.get_tree().paused or not is_instance_valid(player):
		return
	if zone_transition_pending or zone_load_request_pending or opening_pack_waiting or campaign_pack_waiting:
		return
	if _journey_load_pending():
		return
	input_router.begin_context("gameplay")
	_invalidate_interaction_prompt()
	_publish_journey_arrival()

func _restore_active_world_view() -> void:
	if not game_started or not is_instance_valid(zone_root) or not is_instance_valid(player) or not is_instance_valid(camera_rig):
		return
	if zone_transition_pending or zone_load_request_pending or opening_pack_waiting or campaign_pack_waiting or _journey_load_pending():
		return
	if str(zone_root.get_meta("zone_resource_owner", "active")) != "active":
		return
	# Only a fully published active world may take rendering back from the
	# menu/preparation path. HUD visibility is not a substitute for this handoff.
	zone_root.visible = true
	_host.get_viewport().disable_3d = false
	camera_rig.restore_gameplay_view()

func tick_session(delta: float) -> void:
	_restore_browser_session(delta)
	if game_started and _host.get_viewport().disable_3d:
		_restore_active_world_view()
	# Loading is lifecycle work, not simulation. Settings may reload a world
	# while paused; its completion must not require Resume behind the loader.
	if game_started and player != null and zone_transition_pending:
		_advance_zone_transition()
		return
	if not game_started or player == null or _host.get_tree().paused:
		return
	if opening_scene_pending and not zone_transition_pending and not zone_load_request_pending and input_router.is_gameplay_context() and player.can_control:
		var life := zone_root.find_child("GreyfenLifeController", true, false) if is_instance_valid(zone_root) else null
		if life != null:
			opening_scene_pending = false
			life.begin_opening_scene()
	if is_instance_valid(zone_root) and bool(zone_root.get_meta("opening_scene_active", false)):
		return
	if _journey_load_pending():
		journey_loading.try_finish(_host)
		return
	_record_first_control()
	if input_router.consume_companion_menu_request():
		_show_companion_commands()
		return
	if seamless_world != null and seamless_world.update_player(player, current_zone_id, delta):
		return
	if inventory != null and input_router.is_gameplay_context() and player.can_control and not player.transition_locked \
			and player.health_component.health > 0.0 and not zone_load_request_pending and not opening_pack_waiting and not campaign_pack_waiting:
		inventory.advance_oil(delta)
	_keep_player_in_world()
	interaction_focus_cooldown -= delta
	if interaction_focus_cooldown <= 0.0:
		interaction_focus_cooldown = 0.10
		if _interaction_focus_needs_refresh():
			_update_interaction_focus()
	tutorial_refresh_cooldown -= delta
	if tutorial_refresh_cooldown <= 0.0:
		tutorial_refresh_cooldown = 0.10
		_update_tutorial_prompts()
	target_status_refresh_cooldown -= delta
	if target_status_refresh_cooldown <= 0.0:
		target_status_refresh_cooldown = 0.10
		_update_target_lock_hud()
	navigation_dial_refresh_cooldown -= delta
	if navigation_dial_refresh_cooldown <= 0.0:
		navigation_dial_refresh_cooldown = 0.10
		quest_hud_coordinator.update_navigation_dial(hud, player, current_zone_id, interaction_area_cache if zone_root != null else [], spatial_service, zone_root)
	autosave_cooldown = max(autosave_cooldown - delta, 0.0)
	if autosave_cooldown <= 0.0:
		autosave_cooldown = 180.0
		save_manager.autosave(_host)
	compass_refresh_cooldown -= delta
	if compass_refresh_cooldown <= 0.0:
		compass_refresh_cooldown = 0.50
		if _compass_needs_refresh():
			_update_compass()

func _play_voice_smoke_test(voice_id: String, label: String) -> void:
	if audio == null:
		return
	audio.play_voice(voice_id)
	print(label)
	if hud != null:
		hud.toast(label)

func _setup_runtime() -> void:
	runtime_services = RuntimeServiceRegistry.new()
	runtime_services.name = "RuntimeServices"
	_host.add_child(runtime_services)
	_bind_runtime_services(runtime_services.create_services(true))
	runtime_services.configure_menu(_host)

func _bind_runtime_services(services: Dictionary) -> void:
	for id in services:
		if id != "display_metrics":
			_host.set(id, services[id])

func _ensure_gameplay_runtime() -> void:
	if gameplay_runtime_ready:
		return
	_bind_runtime_services(runtime_services.create_gameplay_services())
	if not runtime_services.is_complete():
		return
	gameplay_runtime_ready = true
	quest_hud_coordinator.configure(quest_presentation, quests, story_state)
	_build_global_environment()
	runtime_services.configure(_host)
	hud.revisit_covenant_requested.connect(func(): save_manager.load_pre_covenant(_host))
	zone_runtime_coordinator = ZoneRuntimeCoordinator.new(_host)
	zone_runtime_coordinator.configure(quest_presentation, quest_beats, interaction_focus, quests)
	seamless_world = SeamlessWorldService.new()
	seamless_world.name = "SeamlessWorldService"
	_host.add_child(seamless_world)
	seamless_world.configure(_host, zone_streaming)
	if OS.has_feature("ashenoath_qa"):
		var qa_script = load("res://scripts/qa_browser_telemetry.gd")
		if qa_script != null:
			qa_adapter = qa_script.new()
			qa_adapter.name = "QABrowserTelemetry"
			_host.add_child(qa_adapter)
	enemy_defs = _read_json("res://data/enemies.json")
	boss_defs = _read_json("res://data/bosses.json")

func _new_game() -> void:
	if game_started or new_game_start_pending or zone_transition_pending or zone_load_request_pending or _journey_load_pending():
		return
	var received_usec := Time.get_ticks_usec()
	opening_startup_metrics["new_game_input_received_ms"] = float(received_usec) / 1000.0
	if DisplayServer.get_name().to_lower() != "headless":
		RenderingServer.frame_post_draw.connect(func():
			if not resource_shutdown_prepared and float(opening_startup_metrics.get("new_game_input_received_ms", -1.0)) == float(received_usec) / 1000.0:
				opening_startup_metrics["new_game_ack_frame_ms"] = float(Time.get_ticks_usec() - received_usec) / 1000.0
		, CONNECT_ONE_SHOT)
	zone_pack_request_serial += 1
	opening_pack_waiting = false
	campaign_pack_waiting = false
	pending_player_restore.clear()
	# Start the player-facing timer at the first New Game request, including the
	# queued cold-pack/prewarm path. The old branch left this at zero until the
	# cache was ready, which made the measured handoff look like a stale prior
	# transition and hid the actual wait from diagnostics.
	if loading_started_usec <= 0:
		loading_started_usec = Time.get_ticks_usec()
	if new_game_started_usec <= 0:
		new_game_started_usec = loading_started_usec
	new_game_start_pending = true
	if runtime_packs != null:
		runtime_packs.quality_preset = str(settings.settings.get("quality_preset", "balanced"))
		if OS.has_feature("web"):
			runtime_packs.prioritize_zone("greyfen")
	if OS.has_feature("web") and runtime_packs != null and runtime_packs.has_method("startup_packs_ready"):
		if not runtime_packs.startup_packs_ready():
			new_game_start_pending = true
			new_game_requested_while_preparing = true
			if not startup_packs_waiting and not greyfen_prewarm_started:
				_on_launch_accepted()
			if hud != null:
				hud.set_new_game_status("Greyfen is waking. Your New Game request will open as soon as it is ready.")
				_publish_web_opening_state("downloading", "Loading Greyfen for your New Game...", runtime_packs.startup_pack_progress())
			return
	# Opening readiness and Greyfen prewarm are separate states on every
	# platform. A fast click must wait for the covered cache, not trigger a cold
	# construction while the menu prewarm is still active.
	if not route_zone_cache.has("greyfen"):
		new_game_start_pending = true
		new_game_requested_while_preparing = true
		if not greyfen_prewarm_started:
			_on_launch_accepted()
		if hud != null:
			hud.set_new_game_status("Greyfen is opening. Your New Game request is queued.")
			_publish_web_opening_state("preparing", "Preparing Greyfen for your New Game...")
		return
	new_game_start_pending = true
	new_game_requested_while_preparing = false
	var generation := opening_prepare_generation
	_publish_web_opening_state("ready", "Greyfen is ready.", 1.0)
	# Paint the accepted request before the synchronous cached-world handoff.
	# Otherwise even a prepared scene makes the menu appear inert for that work.
	if DisplayServer.get_name().to_lower() == "headless":
		await _host.get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw
	if not new_game_start_pending or generation != opening_prepare_generation or game_started or _journey_load_pending() or resource_shutdown_prepared:
		return
	if loading_started_usec <= 0:
		loading_started_usec = Time.get_ticks_usec()
	if new_game_started_usec <= 0:
		new_game_started_usec = loading_started_usec
	if audio != null:
		audio.set_game_paused(false)
	# A menu-prewarmed Greyfen is already built and has a valid spatial service.
	# Do not arm the full-screen loader for that warm handoff: the handoff itself
	# is synchronous and the overlay would only appear when a slow browser frame
	# exceeds the delayed-visibility threshold. Cold route loads retain the
	# readiness-aware loader for real work and failure feedback.
	if hud != null and hud.has_method("arm_loading") and not route_zone_cache.has("greyfen"):
		hud.arm_loading("Opening Greyfen...")
	_host.get_tree().paused = false
	_start_new_game_world()

func _cancel_new_game_request() -> void:
	if game_started or _journey_load_pending():
		return
	new_game_start_pending = false
	new_game_requested_while_preparing = false
	new_game_started_usec = 0
	loading_started_usec = 0
	if startup_prepare_failed:
		_publish_web_opening_state("failed", hud.new_game_status)
	else:
		_publish_web_opening_state("ready" if route_zone_cache.has("greyfen") else str(opening_startup_metrics.get("phase", "preparing")), "Greyfen is ready." if route_zone_cache.has("greyfen") else "Preparing Greyfen in the background...")

func _handle_quit_request() -> void:
	if OS.has_feature("web"):
		hud.show_exit_notice()
		return
	_host.get_tree().quit()

func _read_json(path: String):
	if not FileAccess.file_exists(path):
		push_warning("Missing JSON: %s" % path)
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed != null else {}
