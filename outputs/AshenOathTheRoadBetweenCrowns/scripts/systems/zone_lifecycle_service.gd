extends "res://scripts/systems/game_bindings.gd"
## Owns zone lifecycle operations; configure() injects dependencies.
signal zone_changed(zone_id: String)

func _request_zone_load(zone_id: String, spawn_pos: Vector3) -> void:
	if zone_transition_pending or zone_load_request_pending:
		return
	if zone_runtime_coordinator != null:
		var request := zone_runtime_coordinator.normalize_zone_request(zone_id, spawn_pos)
		if not bool(request.get("ok", false)):
			hud.toast("That road is not open yet.")
			return
		zone_id = str(request.get("zone_id", zone_id))
		spawn_pos = request.get("spawn_position", spawn_pos)
	zone_load_request_pending = true
	requested_zone_id = zone_id.strip_edges().to_lower()
	requested_zone_spawn = spawn_pos
	loading_started_usec = Time.get_ticks_usec()
	if hud != null and hud.has_method("arm_loading"):
		hud.arm_loading("Joining Greyfen's assembly..." if zone_id == "assembly" else "Preparing the journey to " + _zone_display_name(zone_id) + "...")
	if player != null:
		player.set_transition_locked(true)
	_perform_requested_zone_load()

func request_seamless_boundary_transition(zone_id: String, spawn_pos: Vector3, edge_id: String = "") -> bool:
	if zone_transition_pending or zone_load_request_pending or player == null:
		return false
	var target := zone_id.strip_edges().to_lower()
	if zone_runtime_coordinator != null and (seamless_world == null or seamless_world.crossing_for(target).is_empty()):
		var request := zone_runtime_coordinator.normalize_zone_request(target, spawn_pos)
		if not bool(request.get("ok", false)):
			if hud != null:
				hud.toast("The road beyond %s is not ready." % edge_id)
			if seamless_world != null:
				seamless_world.on_zone_failed(target, "unknown_destination")
			return false
		target = str(request.get("zone_id", target))
		spawn_pos = request.get("spawn_position", spawn_pos)
	requested_zone_id = target
	requested_zone_spawn = spawn_pos
	loading_started_usec = Time.get_ticks_usec()
	zone_load_request_pending = false
	player.set_transition_locked(true)
	# A complete neighbor is reused; a cold destination keeps its honest,
	# cancellable preparation presentation instead of freezing an old frame.
	_perform_direct_zone_load(target, spawn_pos)
	return true

func _perform_direct_zone_load(zone_id: String, spawn_pos: Vector3) -> void:
	requested_zone_id = ""
	requested_zone_spawn = Vector3.ZERO
	_load_zone_after_runtime_pack(zone_id, spawn_pos)

func _perform_requested_zone_load() -> void:
	var destination := requested_zone_id
	var arrival := requested_zone_spawn
	zone_load_request_pending = false
	requested_zone_id = ""
	_load_zone_after_runtime_pack(destination, arrival)

func _zone_encounter_packs(zone_id: String, recorded_journey: Dictionary = {}) -> Array[String]:
	var encounter_packs: Array[String] = []
	if zone_id != "greyfen":
		return encounter_packs
	var bell_pending: bool
	if recorded_journey.is_empty():
		bell_pending = quests.is_active("main_bell_beneath_greyfen") and not _boss_is_resolved("bell_eater")
	else:
		var flags: Dictionary = recorded_journey.get("story_state", {}).get("flags", {})
		var boss: Variant = recorded_journey.get("world_state", {}).get("boss_states", {}).get("bell_eater", {})
		bell_pending = recorded_journey.get("quests", {}).get("active", {}).has("main_bell_beneath_greyfen") \
			and not bool(flags.get("bell_eater_defeated", false)) and not bool(flags.get("bell_eater_legacy_retired", false)) \
			and not (boss is Dictionary and str(boss.get("outcome", "")) == "defeated")
	if bell_pending:
		encounter_packs.append("monsters")
	return encounter_packs

func _load_zone_after_runtime_pack(zone_id: String, spawn_pos: Vector3) -> void:
	_ensure_gameplay_runtime()
	var encounter_packs := _zone_encounter_packs(zone_id)
	if _zone_requires_campaign_pack(zone_id):
		runtime_services.configure_campaign()
	journey_loading.begin_arrival(_host, "travel", zone_id)
	_begin_gameplay_handoff("zone_travel")
	if runtime_packs != null:
		runtime_packs.quality_preset = str(settings.settings.get("quality_preset", "balanced"))
	zone_pack_request_serial += 1
	opening_pack_waiting = false
	campaign_pack_waiting = false
	if _zone_requires_opening_pack(zone_id) and OS.has_feature("web"):
		if runtime_packs == null or not runtime_packs.has_method("request_pack"):
			_recover_failed_pack_load()
			return
		# The Web candidate keeps the opening builders in the root PCK, but its
		# gameplay-critical opening art is owned by the startup opening pack. The
		# manifest-backed check below prevents a gate from bypassing that pack just
		# because a builder script happens to be embedded in the root.
		if not runtime_packs.zone_packs_ready(zone_id, encounter_packs):
			opening_pack_waiting = true
			if hud != null and hud.has_method("arm_loading"):
				hud.arm_loading("Preparing Greyfen's saved encounter..." if not encounter_packs.is_empty() else "Preparing the road into Wychwood...")
			runtime_packs.request_zone_packs(zone_id, encounter_packs)
			_begin_travel_download(zone_id,encounter_packs)
			_wait_for_opening_pack(zone_id, spawn_pos, zone_pack_request_serial, encounter_packs)
			return
	if not _zone_requires_campaign_pack(zone_id) or not OS.has_feature("web"):
		_load_zone(zone_id, spawn_pos)
		return
	if runtime_packs == null or not runtime_packs.has_method("request_pack"):
		_recover_failed_pack_load()
		return
	# The production and QA Web candidates may embed the campaign builder in the
	# root PCK, but campaign art remains owned by the external campaign pack. The
	# manifest-backed check below keeps the builder from bypassing that pack.
	if not runtime_packs.zone_packs_ready(zone_id):
		campaign_pack_waiting = true
		if hud != null and hud.has_method("arm_loading"):
			hud.arm_loading("Preparing the road beyond Greyfen...")
		runtime_packs.request_zone_packs(zone_id)
		_begin_travel_download(zone_id)
		_wait_for_campaign_pack(zone_id, spawn_pos, zone_pack_request_serial)
		return
	_load_zone(zone_id, spawn_pos)

func _begin_travel_download(zone_id: String, extras: Array[String] = []) -> void:
	if not game_started or journey_loading.pending(_host): return
	neighbor_crossing_pending = true
	neighbor_crossing_was_paused = _host.get_tree().paused
	_host.get_tree().paused = true
	audio.set_game_paused(true)
	hud.begin_journey_load({"summary":{"title":_zone_display_name(zone_id)}})
	runtime_packs.prioritize_zone(zone_id,extras)

func _finish_travel_download() -> void:
	if not neighbor_crossing_pending: return
	neighbor_crossing_pending = false
	neighbor_arrival_pending = true
	_host.get_tree().paused = neighbor_crossing_was_paused
	audio.set_game_paused(neighbor_crossing_was_paused)

func _wait_for_campaign_pack(zone_id: String, spawn_pos: Vector3, request_serial: int) -> void:
	for _frame in range(900):
		await _host.get_tree().process_frame
		if request_serial != zone_pack_request_serial or not campaign_pack_waiting:
			return
		if neighbor_crossing_pending: hud.update_journey_load_progress(zone_id,runtime_packs.zone_pack_progress(zone_id),"Downloading verified destination content...")
		if runtime_packs != null and runtime_packs.zone_packs_ready(zone_id):
			campaign_pack_waiting = false
			_finish_travel_download()
			if not neighbor_arrival_pending and hud != null and hud.has_method("hide_loading"):
				hud.hide_loading()
			_load_zone(zone_id, spawn_pos)
			return
		if runtime_packs != null and not runtime_packs.zone_pack_failures(zone_id).is_empty():
			break
	campaign_pack_waiting = false
	_recover_failed_pack_load("The road pack could not be prepared. Your current location remains open; use the crossing to retry.")

func _wait_for_opening_pack(zone_id: String, spawn_pos: Vector3, request_serial: int, encounter_packs: Array[String] = []) -> void:
	for _frame in range(900):
		await _host.get_tree().process_frame
		if request_serial != zone_pack_request_serial or not opening_pack_waiting:
			return
		if neighbor_crossing_pending: hud.update_journey_load_progress(zone_id,runtime_packs.zone_pack_progress(zone_id,encounter_packs),"Downloading verified destination content...")
		if runtime_packs != null and runtime_packs.zone_packs_ready(zone_id, encounter_packs):
			opening_pack_waiting = false
			_finish_travel_download()
			if not neighbor_arrival_pending and hud != null and hud.has_method("hide_loading"):
				hud.hide_loading()
			_load_zone(zone_id, spawn_pos)
			return
		if runtime_packs != null and not runtime_packs.zone_pack_failures(zone_id, encounter_packs).is_empty():
			break
	opening_pack_waiting = false
	_recover_failed_pack_load("The opening pack could not be prepared. Your current location remains open; use the crossing to retry.")

func _recover_failed_pack_load(reason: String = "The destination could not load. Please retry.") -> void:
	if neighbor_crossing_pending:
		_host.get_tree().paused = neighbor_crossing_was_paused
		audio.set_game_paused(neighbor_crossing_was_paused)
		hud.end_journey_load(false)
	neighbor_crossing_pending = false
	neighbor_arrival_pending = false
	if seamless_world != null: seamless_world.cancel_preparation()
	# No destination was constructed: the current world must remain resident.
	zone_pack_request_serial += 1
	journey_arrival_generation = 0
	opening_pack_waiting = false
	campaign_pack_waiting = false
	pending_player_restore.clear()
	zone_transition_pending = false
	zone_load_request_pending = false
	requested_zone_id = ""
	campaign_visual_prewarm_suspended = false
	if seamless_world != null:
		seamless_world.on_zone_failed(current_zone_id, "pack_load_failed")
	if player != null and is_instance_valid(player):
		player.set_transition_locked(false)
		player.velocity = Vector3.ZERO
	else:
		game_started = false
		if hud != null:
			hud.show_main_menu()
	if hud != null:
		hud.hide_loading()
		hud.post_notice(reason, "error", 5.5, "destination_download")
	_finish_gameplay_handoff()

func _zone_requires_campaign_pack(zone_id: String) -> bool:
	return zone_id in [
		"deep_wood", "old_mill", "burned_farmstead", "marsh_crossing", "bandit_road",
		"vargan_approach", "vargan_court", "record_hall", "undercroft", "assembly", "hart_glade",
	]

func _zone_requires_opening_pack(zone_id: String) -> bool:
	return zone_id in ["greyfen", "wychwood", "cemetery", "ruins"]

func _start_new_game_world() -> void:
	# An explicit transition can be requested before the menu's deferred setup
	# receives its first frame. Preserve that deliberate destination.
	if game_started or not new_game_start_pending:
		return
	var prepared_root := route_zone_cache.get("greyfen") as Node3D
	if prepared_root == null or not bool(prepared_root.get_meta("opening_presentation_ready", false)):
		return
	new_game_start_pending = false
	# Identity and reading history belong to the accepted world handoff, not a
	# request that can remain queued while files or the first view are prepared.
	save_manager.begin_new_journey()
	hud.load_text_history([])
	if hud != null and hud.has_method("set_new_game_ready"):
		hud.set_new_game_ready(true)
	if hud != null and hud.has_method("set_new_game_status"):
		hud.set_new_game_status("Greyfen is ready.")
	# Keep the menu-prewarmed Greyfen tree while clearing any stale campaign
	# cache. Rebuilding this scene in Web/ANGLE was the dominant New Game delay.
	var prewarmed_greyfen = route_zone_cache.get("greyfen")
	var prewarmed_enemies: Array = route_enemy_cache.get("greyfen", [])
	print("LOADING: new_game_handoff prewarmed=%s cached_zones=%d" % [prewarmed_greyfen != null, route_zone_cache.size()])
	if prewarmed_greyfen != null:
		# Remove only the preserved root from the cache before trimming unrelated
		# entries. Do not pass it through the retirement path: that schedules a
		# renderer teardown for the very scene we are about to activate.
		route_zone_cache.erase("greyfen")
		route_enemy_cache.erase("greyfen")
		route_zone_signatures.erase("greyfen")
		# The prewarm root is still held by zone_root while the menu is covering
		# it. Clear that active reference before trimming unrelated cache entries;
		# otherwise _clear_route_zone_cache() mistakes the root we are handing off
		# for a retired zone and performs the expensive renderer teardown again.
		if zone_root == prewarmed_greyfen:
			zone_root = null
	_clear_route_zone_cache()
	print("LOADING: new_game_stage=cache_clear elapsed=%.1f" % (float(Time.get_ticks_usec() - loading_started_usec) / 1000.0))
	if prewarmed_greyfen != null and is_instance_valid(prewarmed_greyfen):
		_cache_route_zone("greyfen", prewarmed_greyfen, prewarmed_enemies, _zone_state_signature("greyfen"), true, false, false)
	game_started = true
	_host.get_viewport().disable_3d = false
	paused_by_menu = false
	wychwood_pack_kills = 0
	wychwood_encounter_started = false
	pending_anwen_relocation = false
	tutorial_flags.clear()
	inventory.reset_starting_loadout()
	if vendor_service != null:
		vendor_service.reset_state()
	if minigames != null:
		minigames.load_state({})
	progression.load_state({})
	current_zone_id = "greyfen"
	day_night.set_time(day_night.START_TIME_MINUTES, 0)
	opening_detail_pending = prewarmed_greyfen != null \
		and not bool(prewarmed_greyfen.get_meta("opening_detail_complete", false)) \
		and str(prewarmed_greyfen.get_meta("opening_build_profile", "")) in ["opening_fast", "opening_boot"]
	opening_detail_stage_index = 0
	opening_detail_generation += 1
	opening_save_generation += 1
	opening_checkpoint_pending = true
	print("LOADING: handoff_phase=hide_menu_begin")
	hud.hide_menus()
	print("LOADING: handoff_phase=hide_menu_end")
	print("LOADING: handoff_phase=quest_begin")
	quests.start_quest("main_road_of_crows")
	story_state.set_flag("opening_care_enabled", true)
	story_state.set_flag("greyfen_guide_available", true)
	print("LOADING: handoff_phase=quest_end")
	# The opening is now playable. Remaining packs must not delay New Game or
	# the first quest interaction. In particular, do not start the character-pack
	# download here: Web hash/mount work can monopolize the main thread before the
	# first input sample. The deferred visual-role stage requests that pack only
	# after first control, while Kael and Anwen remain root-resident.
	if runtime_packs != null and runtime_packs.has_method("request_background_packs"):
		_host.call_deferred("_schedule_background_runtime_packs")
	print("LOADING: new_game_stage=state_ready elapsed=%.1f" % (float(Time.get_ticks_usec() - loading_started_usec) / 1000.0))
	if route_zone_cache.has("greyfen"):
		route_zone_signatures["greyfen"] = _zone_state_signature("greyfen")
	print("LOADING: new_game_stage=zone_dispatch elapsed=%.1f" % (float(Time.get_ticks_usec() - loading_started_usec) / 1000.0))
	print("LOADING: handoff_phase=load_zone_begin")
	journey_loading.begin_arrival(_host, "new_journey", "greyfen")
	opening_scene_pending = true
	_load_zone("greyfen", Vector3(0, 1, 9.8))
	print("LOADING: handoff_phase=load_zone_end")
	if not opening_boot_material_restore_queue.is_empty() \
			or (visual_director != null and visual_director.is_opening_boot_budget_active()):
		opening_boot_material_restore_generation += 1
		_host.call_deferred("_restore_opening_boot_materials", opening_boot_material_restore_generation)
	if opening_detail_pending:
		_host.call_deferred("_run_opening_detail_stage", opening_detail_generation)
	var new_game_elapsed_ms := float(Time.get_ticks_usec() - new_game_started_usec) / 1000.0 if new_game_started_usec > 0 else 0.0
	print("LOADING: new_game_stage=ready elapsed=%.1f" % new_game_elapsed_ms)
	# Keep the legacy stage label for older diagnostics, but report the same
	# request-to-control duration rather than the reset transition clock.
	print("LOADING: new_game_stage=zone_return elapsed=%.1f" % new_game_elapsed_ms)
	new_game_started_usec = 0
	_refresh_tracker()
	_show_current_objective_guidance(5.5)
	_refresh_equipment_readout()
	# FileAccess on Web can synchronously block the renderer for several seconds
	# on the first IndexedDB transaction. Persist the new-game checkpoint after
	# the opening frame has settled instead of making the first visible control
	# handoff wait on storage I/O.
	_host.call_deferred("_schedule_opening_save", opening_save_generation)

func _request_background_runtime_packs() -> void:
	if not game_started or runtime_packs == null:
		return
	# Optional pack mounts and neighbor imports can compile shaders and touch
	# IndexedDB for several frames on Web/ANGLE. Keep that work out of the whole
	# player-controlled opening route, not only the Greyfen sector: the first
	# Wychwood clues and bridge return still run on the same critical path.
	if _opening_route_is_active():
		# Retry after the route is complete. The timer is intentionally the only
		# retry mechanism so every background pack remains deferred as one batch.
		_schedule_background_runtime_packs(BACKGROUND_RUNTIME_RETRY_SECONDS)
		return
	# Reuse already-mounted neighbor resources, but do not enqueue the entire
	# campaign after a timer. Missing content belongs to the approached connection
	# or explicit destination, not unrelated post-control background mounts.
	# Recorded voices/foley retain their existing delayed availability owner.
	runtime_packs.request_pack("audio", 1000)
	if zone_streaming != null and zone_streaming.has_method("prewarm_neighbors"):
		zone_streaming.prewarm_neighbors(current_zone_id if current_zone_id != "" else "greyfen")

func _opening_route_is_active() -> bool:
	if current_zone_id not in ["greyfen", "wychwood"] or quests == null:
		return false
	return quests.is_active("main_road_of_crows") and not quests.is_completed("main_road_of_crows")

func should_defer_neighbor_prewarm() -> bool:
	# Keep the first Greyfen frame free of threaded scene imports while input and
	# opening save state settle. The delayed background request resumes prewarm.
	return opening_checkpoint_pending and game_started and current_zone_id == "greyfen"

func _schedule_background_runtime_packs(delay_seconds: float = BACKGROUND_RUNTIME_DELAY_SECONDS) -> void:
	# Do not let a fast local download/mount compete with the first playable
	# frames. The opening can request a campaign pack on demand; this timer only
	# starts optional background work after the handoff has visibly settled.
	if background_runtime_timer_pending:
		return
	background_runtime_timer_pending = true
	var delay_timer := _create_owned_timer(delay_seconds, true)
	await delay_timer.timeout
	background_runtime_timer_pending = false
	if resource_shutdown_prepared or not game_started or current_zone_id == "":
		return
	_request_background_runtime_packs()

func _schedule_opening_save(generation: int) -> void:
	var delay_timer := _create_owned_timer(OPENING_SAVE_DELAY_SECONDS, true)
	await delay_timer.timeout
	if generation != opening_save_generation or not game_started or save_manager == null:
		return
	if resource_shutdown_prepared or player == null or not is_instance_valid(player):
		return
	if _journey_load_pending():
		_host.call_deferred("_schedule_opening_save", generation)
		return
	# Save the current state rather than a stale Greyfen-only snapshot. If the
	# player reaches another supported zone during the delay, the normal autosave
	# path still owns that transition and this checkpoint remains a safe fallback.
	save_manager.checkpoint(_host)
	opening_checkpoint_pending = false

func _spawn_player(pos: Vector3) -> void:
	if player != null:
		player.queue_free()
	if camera_rig != null:
		camera_rig.queue_free()
	var actor_pair: Dictionary = RuntimeActorFactory.create_player_camera(_host, pos, current_zone_id, input_router)
	assert(RuntimeActorFactory.is_valid_pair(actor_pair), "Player-camera composition failed")
	player = actor_pair["player"]
	camera_rig = actor_pair["camera"]
	if camera_rig != null and camera_rig.has_signal("target_lock_changed") and not camera_rig.target_lock_changed.is_connected(Callable(_host, "_on_target_lock_changed")):
		camera_rig.target_lock_changed.connect(Callable(_host, "_on_target_lock_changed"))
	_apply_progression_to_player()
	_apply_runtime_settings(settings.settings)
	if player.has_method("bind_inventory"):
		player.bind_inventory(inventory)
	player.blade_contact_requested.connect(Callable(_host, "_on_player_blade_contact"))
	player.potion_requested.connect(Callable(_host, "_use_potion"))
	player.bomb_requested.connect(Callable(_host, "_throw_bomb"))
	player.beam_requested.connect(Callable(_host, "_on_player_beam"))
	player.beam_phase_changed.connect(Callable(_host, "_on_player_beam_phase"))
	player.arrow_requested.connect(Callable(_host, "_on_player_arrow"))
	player.arrow_unavailable.connect(Callable(_host, "_on_player_arrow_unavailable"))
	player.equipment_loadout.changed.connect(Callable(_host, "_refresh_equipment_readout"))
	player.footstep.connect(Callable(_host, "_on_player_footstep"))
	player.ability_hint.connect(func(text: String): hud.post_notice(text, "info", 2.5, "ability_requirement"))
	player.parried.connect(Callable(_host, "_on_player_parried"))
	player.blocked.connect(Callable(_host, "_on_player_blocked"))
	player.hurt.connect(Callable(_host, "_on_player_hurt"))
	player.stamina_exhausted.connect(Callable(_host, "_on_player_stamina_exhausted"))
	player.died.connect(Callable(_host, "_on_player_died"))
	player.health_component.changed.connect(hud.update_health)
	player.stamina_component.changed.connect(hud.update_stamina)
	_bind_spatial_player_body()
	_sync_camera_enemy_cache()
	hud.update_health(player.health_component.health, player.health_component.max_health)
	hud.update_stamina(player.stamina_component.stamina, player.stamina_component.max_stamina)

func _sync_camera_enemy_cache() -> void:
	if neighbor_building: return
	# Keep restored encounter actors on the same owned peer list as the camera.
	# Cached-zone activation replaces active_enemies with a fresh filtered Array;
	# rebinding here keeps spacing and attack-lane checks on the restored list;
	# enemy controllers never discover peers in unrelated scene-tree groups.
	encounter_spatial_index.clear()
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			encounter_spatial_index.update(enemy)
	for enemy in active_enemies:
		if is_instance_valid(enemy) and enemy.has_method("set_encounter_peers"):
			enemy.set_encounter_peers(active_enemies, encounter_spatial_index)
	if camera_rig != null and is_instance_valid(camera_rig) and camera_rig.has_method("set_enemy_candidates"):
		camera_rig.set_enemy_candidates(active_enemies)

func _bind_spatial_player_body() -> void:
	if player == null or not is_instance_valid(player):
		return
	var body := player as CollisionObject3D
	if body == null:
		return
	for service in [spatial_service, greyfen_prewarm_spatial_service]:
		if service != null and is_instance_valid(service) and service.has_method("set_player_body"):
			service.set_player_body(body)

func _load_zone(zone_id: String, spawn_pos: Vector3 = Vector3.ZERO) -> void:
	_begin_gameplay_handoff("zone_activation")
	var paired_crossing := game_started and seamless_world != null and current_zone_id != zone_id and not journey_loading.pending(_host) and ZoneCompositionRouter.supports(zone_id)
	if paired_crossing and seamless_world != null and is_instance_valid(zone_root) and is_instance_valid(player) and not seamless_world.has_prepared(zone_id):
		neighbor_crossing_pending = true
		neighbor_crossing_was_paused = _host.get_tree().paused
		_host.get_tree().paused = true
		audio.set_game_paused(true)
		var serial := zone_pack_request_serial
		hud.begin_journey_load({"summary":{"title":"the road into " + _zone_display_name(zone_id)}})
		var ready: bool = await seamless_world.finish_preparation(zone_id,func(): return neighbor_crossing_pending and serial == zone_pack_request_serial and not resource_shutdown_prepared)
		if not neighbor_crossing_pending or serial != zone_pack_request_serial: return
		neighbor_crossing_pending = false
		_host.get_tree().paused = neighbor_crossing_was_paused
		audio.set_game_paused(neighbor_crossing_was_paused)
		if not ready:
			# Opportunistic preparation must never become the only way out of a
			# region. The normal coordinator still validates the complete build
			# and rolls back to this world if that authoritative load fails.
			print("TRAVEL: neighbor preparation unavailable for %s: %s; using normal destination construction" % [zone_id,seamless_world.preparation_snapshot().get("failure","")])
		neighbor_arrival_pending = true
		hud.set_journey_load_applying("Entering " + _zone_display_name(zone_id) + "...")
	zone_runtime_coordinator.load_zone(zone_id, spawn_pos)
	_finish_gameplay_handoff()

func _advance_zone_transition() -> void:
	zone_runtime_coordinator.advance_transition()
	_finish_gameplay_handoff()

func _apply_zone_audio(zone_id: String) -> void:
	if audio == null or zone_id == "":
		return
	audio.prepare_destination(zone_id, story_state)
	audio.play_ambient(zone_id)
	audio.set_music_state(audio.music_state_for_zone(zone_id))
	audio.set_story_context(story_state, zone_id)
	if zone_id == "greyfen":
		audio.play_event("shrine_hum", 0.01)

func _schedule_deferred_zone_audio(zone_id: String, root: Node3D) -> void:
	if root == null or not is_instance_valid(root) or not bool(root.get_meta("zone_audio_pending", false)):
		return
	root.set_meta("zone_audio_pending", false)
	_host.call_deferred("_finish_deferred_zone_audio", zone_id, root)

func _finish_deferred_zone_audio(zone_id: String, root: Node3D) -> void:
	# Keep first control and the measured transition clear of generated stream
	# synthesis. The short delay is intentional: it gives the arrival camera a
	# settled frame, while still starting the region's audio before exploration
	# can feel silent.
	var delay_timer := _create_owned_timer(0.45, true)
	await delay_timer.timeout
	if resource_shutdown_prepared or not game_started or current_zone_id != zone_id or zone_root != root:
		return
	_apply_zone_audio(zone_id)

func _activate_prewarmed_player_runtime() -> void:
	if not game_started or current_zone_id != "greyfen" or player == null or not is_instance_valid(player):
		return
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	if camera_rig == null or not is_instance_valid(camera_rig):
		return
	camera_rig.process_mode = Node.PROCESS_MODE_INHERIT
	var gameplay_camera := camera_rig.find_child("Camera3D", true, false) as Camera3D
	if gameplay_camera != null:
		gameplay_camera.current = true
	_finish_prewarmed_greyfen_runtime()

func _schedule_zone_runtime_finalize(zone_id: String, root: Node3D, service: Node, enemies: Array, navigation_pending: bool) -> void:
	_host.call_deferred("_finish_zone_runtime_finalize", zone_id, root, service, enemies, navigation_pending)

func _finish_zone_runtime_finalize(zone_id: String, root: Node3D, service: Node, enemies: Array, navigation_pending: bool) -> void:
	# Arrival still owns input: required navigation and consequences must not
	# create a second construction stall after the playable boundary.
	if not game_started or current_zone_id != zone_id:
		return
	if root == null or not is_instance_valid(root) or zone_root != root:
		return
	if service == null or not is_instance_valid(service) or spatial_service != service:
		return
	var started := Time.get_ticks_msec()
	if navigation_pending:
		service.build_navigation(root)
		root.set_meta("navigation_pending", false)
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.has_method("setup_navigation"):
			enemy.setup_navigation(service)
	if visual_director != null:
		_validate_zone_render_resources(visual_director)
	if player != null and is_instance_valid(player):
		_validate_zone_render_resources(player)
	for enemy in enemies:
		if is_instance_valid(enemy):
			_validate_zone_render_resources(enemy)
	StoryWorldDirector.decorate(_host, root, zone_id)
	CovenantResolution.restore(_host)
	_persist_story_action()
	print("LOADING: zone_stage=runtime_finalized zone=%s navigation=%s ms=%d" % [zone_id, navigation_pending, Time.get_ticks_msec() - started])

func _finish_prewarmed_greyfen_runtime() -> void:
	# Compatibility for older prepared roots; new roots finish this under cover.
	if not game_started or current_zone_id != "greyfen" or zone_root == null or not is_instance_valid(zone_root):
		return
	if not bool(zone_root.get_meta("prewarm_navigation_pending", false)):
		return
	var started := Time.get_ticks_msec()
	if spatial_service != null and is_instance_valid(spatial_service):
		spatial_service.build_navigation(zone_root)
	zone_root.set_meta("prewarm_navigation_pending", false)
	_validate_zone_render_resources(zone_root)
	for enemy in active_enemies:
		if is_instance_valid(enemy) and enemy.has_method("setup_navigation"):
			enemy.setup_navigation(spatial_service)
	print("LOADING: Greyfen deferred_runtime_complete ms=%d" % (Time.get_ticks_msec() - started))

func _recover_failed_zone_load(previous_zone_id: String) -> void:
	zone_runtime_coordinator.recover_failed_transition(previous_zone_id)

func _grounded_spawn_position(candidate: Vector3) -> Variant:
	if _host.get_world_3d() == null:
		return null
	var excluded: Array[RID] = []
	if player != null:
		excluded.append(player.get_rid())
	var hit := SpatialSurfaceContract.support_hit(_host.get_world_3d().direct_space_state, candidate + Vector3.UP * 6.0, candidate - Vector3.UP * 12.0, excluded)
	if hit.is_empty():
		return null
	return Vector3(candidate.x, float(hit.position.y) + 0.95, candidate.z)

func _zone_display_name(zone_id: String) -> String:
	return zone_id.replace("_", " ").capitalize()

func _valid_cached_enemies(entries: Array) -> Array:
	return zone_residency._valid_cached_enemies(entries)

func _zone_state_signature(zone_id: String = current_zone_id) -> int:
	var quest_world_state: Dictionary = quests.world_signature_state(zone_id).duplicate(true) if quests != null else {}
	# HUD tracking changes by zone and must not invalidate otherwise identical
	# cached world geometry.
	quest_world_state.erase("tracked_quest_id")
	quest_world_state.erase("tracker_context_zone")
	var story_world_state: Dictionary = story_state.world_signature_state(zone_id).duplicate(true) if story_state != null else {}
	if story_world_state.get("flags") is Dictionary:
		# Companion position/command is reinstalled separately, not world geometry.
		story_world_state.flags.erase("bracken_travel")
	var zone_removed: Dictionary = {}
	for key: String in removed_interactions:
		if key.begins_with(zone_id + ":"): zone_removed[key] = removed_interactions[key]
	return hash([
		story_world_state,
		quest_world_state,
		zone_removed,
		str(settings.settings.get("quality_preset","balanced")) if settings != null else "balanced",
	])

func _begin_zone_world_reads(zone_id: String, reset: bool = true) -> void:
	preload("res://scripts/prepared_zone_geometry.gd").set_zone_scope(zone_id)
	if asset_helper != null:
		asset_helper.set_zone_scope(zone_id)
	story_state.world_reads.begin(zone_id, reset)
	quests.world_reads.begin(zone_id, reset)

func _end_zone_world_reads() -> void:
	story_state.world_reads.end()
	quests.world_reads.end()

func _deferred_free_zone(retired_root: Node) -> void:
	zone_residency._deferred_free_zone(retired_root)

func _release_zone_render_resources(root: Node) -> void:
	zone_residency._release_zone_render_resources(root)

func _retire_zone_root(retired_root: Node) -> void:
	zone_residency._retire_zone_root(retired_root)

func _bind_retirement_material(root: Node) -> void:
	zone_residency._bind_retirement_material(root)

func _anchor_retired_materials(root: Node) -> void:
	zone_residency._anchor_retired_materials(root)

func _keep_retired_material(material: Material) -> void:
	zone_residency._keep_retired_material(material)

func _anchor_shared_skinned_resources(root: Node) -> void:
	zone_residency._anchor_shared_skinned_resources(root)

func _skinned_resource_fingerprint(branch: Node) -> String:
	return zone_residency._skinned_resource_fingerprint(branch)

func _record_loading_metrics(metrics: Dictionary) -> void:
	last_loading_metrics = metrics
	if game_started and not opening_startup_metrics.has("world_ready_ms"):
		opening_startup_metrics["world_ready_ms"] = Time.get_ticks_msec()
	transition_history.append(metrics.duplicate(true))
	while transition_history.size() > MAX_TRANSITION_HISTORY:
		transition_history.pop_front()
	zone_changed.emit(current_zone_id)

func _record_first_control() -> void:
	if opening_startup_metrics.has("first_control_ms") or not game_started or not is_instance_valid(player) or not player.can_control or player.transition_locked:
		return
	if opening_scene_pending or zone_transition_pending or zone_load_request_pending or opening_pack_waiting or campaign_pack_waiting or _host.get_tree().paused or not input_router.is_gameplay_context():
		return
	if is_instance_valid(zone_root) and bool(zone_root.get_meta("opening_scene_active", false)):
		return
	opening_startup_metrics["first_control_ms"] = Time.get_ticks_msec()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.dispatchEvent(new CustomEvent('ashen-oath-first-control'));", false)

func _create_owned_timer(seconds: float, ignore_time_scale: bool = false) -> Timer:
	var timer := Timer.new()
	timer.name = "OwnedDelayTimer"
	timer.wait_time = maxf(seconds, 0.0)
	timer.one_shot = true
	timer.ignore_time_scale = ignore_time_scale
	_host.add_child(timer)
	owned_timers.append(timer)
	timer.timeout.connect(func():
		owned_timers.erase(timer)
		if is_instance_valid(timer):
			timer.queue_free()
	)
	timer.start()
	return timer

func _cancel_owned_timers() -> void:
	for timer in owned_timers.duplicate():
		if timer == null or not is_instance_valid(timer):
			continue
		timer.stop()
		# Coroutines awaiting this timer's timeout must be resumed before the
		# timer is released. Freeing it silently leaves the await state alive at
		# shutdown, which appears as a leaked RefCounted and orphaned StringName.
		# Every continuation checks resource_shutdown_prepared before doing work.
		timer.emit_signal("timeout")
		if is_instance_valid(timer):
			timer.queue_free()
	owned_timers.clear()
	background_runtime_timer_pending = false

func _quiesce_zone_runtime(root: Node) -> void:
	zone_residency._quiesce_zone_runtime(root)

func _cache_route_zone(zone_id: String, root: Node3D, enemies: Array, signature: int, keep_visible: bool = false, disable_collision: bool = true, disable_process: bool = true) -> void:
	zone_residency._cache_route_zone(zone_id, root, enemies, signature, keep_visible, disable_collision, disable_process)

func _cache_route_spatial_service(zone_id: String, service: Node) -> void:
	zone_residency._cache_route_spatial_service(zone_id, service)

func _release_route_spatial_service(zone_id: String) -> void:
	zone_residency._release_route_spatial_service(zone_id, [spatial_service, greyfen_prewarm_spatial_service])

func _release_active_spatial_service() -> void:
	var current: Node = spatial_service
	spatial_service = null
	if current == null or not is_instance_valid(current):
		return
	if current == greyfen_prewarm_spatial_service or route_spatial_cache.values().has(current):
		return
	current.queue_free()

func _defer_cached_zone_collision_disable(zone_id: String) -> void:
	var delay_timer := _create_owned_timer(0.45, true)
	delay_timer.timeout.connect(func():
		var cached_root: Node3D = route_zone_cache.get(zone_id)
		if cached_root != null and is_instance_valid(cached_root) and str(cached_root.get_meta("zone_resource_owner", "")) == "cached":
			_set_zone_collision_enabled(cached_root, false)
	)

func _activate_cached_zone(zone_id: String) -> Node3D:
	return zone_residency._activate_cached_zone(zone_id)

func _remove_root_from_route_cache(root: Node) -> void:
	zone_residency._remove_root_from_route_cache(root)

func _trim_route_zone_cache(preferred_ids: Array) -> void:
	zone_residency._trim_route_zone_cache(preferred_ids)
	preload("res://scripts/prepared_zone_geometry.gd").retain_zone_scopes([current_zone_id] + route_zone_cache.keys())
	if asset_helper != null:
		asset_helper.retain_zone_scopes([current_zone_id] + route_zone_cache.keys())

func _set_zone_collision_enabled(node: Node, enabled: bool) -> void:
	zone_residency._set_zone_collision_enabled(node, enabled)

func _collect_zone_collision_targets(root: Node) -> Array:
	return zone_residency._collect_zone_collision_targets(root)

func _set_single_zone_collision_enabled(node: Node, enabled: bool) -> void:
	zone_residency._set_single_zone_collision_enabled(node, enabled)

func _schedule_zone_autosave() -> void:
	var expected_zone: String = current_zone_id
	var delay_timer := _create_owned_timer(0.35)
	delay_timer.timeout.connect(func():
		if opening_checkpoint_pending:
			return
		if not resource_shutdown_prepared and game_started and player != null and is_instance_valid(player) and current_zone_id == expected_zone and save_manager != null:
			save_manager.autosave(_host)
	)

func _clear_route_zone_cache(preserve_root: Node3D = null) -> void:
	if seamless_world != null: seamless_world.cancel_preparation()
	if zone_root != null and is_instance_valid(zone_root):
		_retire_zone_root(zone_root)
	zone_root = null
	for cached_root in route_zone_cache.values():
		if cached_root == preserve_root:
			continue
		if is_instance_valid(cached_root):
			if not cached_root.is_inside_tree():
				_host.add_child(cached_root)
			_retire_zone_root(cached_root)
	route_zone_cache.clear()
	route_enemy_cache.clear()
	route_zone_signatures.clear()
	for raw_id in route_spatial_cache.keys().duplicate():
		_release_route_spatial_service(str(raw_id))

func prepare_resource_shutdown() -> void:
	journey_loading.cancel(_host, "", false, true)
	if resource_shutdown_prepared:
		return
	resource_shutdown_prepared = true
	neighbor_crossing_pending = false
	if seamless_world != null: seamless_world.cancel_preparation()
	if is_instance_valid(runtime_services):
		var display_bridge: Node = runtime_services.get_service("display_metrics")
		if is_instance_valid(display_bridge):
			display_bridge.call("shutdown")
	dialogue_runtime_coordinator.release(player)
	combat_vfx_coordinator.clear_oathfire_effects()
	# Invalidate deferred frame continuations before releasing their scene-owned
	# resources. A shutdown can otherwise leave a suspended GDScript state alive
	# until process exit, even though the active route has already completed.
	game_started = false
	new_game_start_pending = false
	new_game_requested_while_preparing = false
	startup_packs_waiting = false
	opening_pack_waiting = false
	campaign_pack_waiting = false
	opening_detail_pending = false
	campaign_visual_prewarm_suspended = false
	opening_detail_generation += 1
	opening_boot_material_restore_generation += 1
	opening_boot_material_restore_queue.clear()
	_cancel_campaign_visual_prewarm()
	_cancel_owned_timers()
	if performance_budget_monitor != null:
		performance_budget_monitor.suspend()
	if zone_root != null and is_instance_valid(zone_root):
		_retire_zone_root(zone_root)
	zone_root = null
	for cached_root in route_zone_cache.values().duplicate():
		if cached_root != null and is_instance_valid(cached_root):
			_retire_zone_root(cached_root)
	route_zone_cache.clear()
	route_enemy_cache.clear()
	route_zone_signatures.clear()
	for raw_id in route_spatial_cache.keys().duplicate():
		_release_route_spatial_service(str(raw_id))
	if greyfen_prewarm_spatial_service != null and is_instance_valid(greyfen_prewarm_spatial_service):
		greyfen_prewarm_spatial_service.queue_free()
	greyfen_prewarm_spatial_service = null
	_release_active_spatial_service()

func finalize_resource_shutdown() -> void:
	# Called only after staged zone retirement has completed. Actors and camera
	# are no longer needed, so release their scene ownership before clearing
	# global caches held by runtime services.
	prepare_resource_shutdown()
	if player != null and is_instance_valid(player):
		player.queue_free()
	player = null
	if camera_rig != null and is_instance_valid(camera_rig):
		camera_rig.queue_free()
	camera_rig = null
	zone_residency.release_shared_anchors()
	if asset_helper != null and asset_helper.has_method("clear_runtime_caches"):
		asset_helper.clear_runtime_caches()
	if world_materials != null and world_materials.has_method("clear_cache"):
		world_materials.clear_cache()
	if visual_director != null and visual_director.has_method("clear_runtime_caches"):
		visual_director.clear_runtime_caches()
	if zone_streaming != null and zone_streaming.has_method("clear_requests"):
		zone_streaming.clear_requests()
	if runtime_packs != null and runtime_packs.has_method("clear_requests"):
		runtime_packs.clear_requests()
	CombatFeedback.clear_runtime_caches()
	preload("res://scripts/prepared_zone_geometry.gd").clear()
	preload("res://scripts/interior_occlusion.gd").clear()
	# These arrays are build-time ownership, not runtime state. They retain
	# queued marker MeshInstance3D nodes and shared materials after their zone
	# has retired, which keeps renderer instances alive outside the scene tree.
	# Clear them only after staged retirement so no visible zone references are
	# invalidated during normal travel.
	tree_batch_data.clear()
	deadfall_batch_data.clear()
	prop_batch_data.clear()
	visual_box_batch_data.clear()
	terrain_patch_batch_data.clear()
	house_batch_data.clear()
	house_module_batch_data.clear()
	material_cache.clear()
	shared_box_mesh = null
	zone_residency.release_material_anchors()
	# These nodes are global renderer/service owners rather than part of the
	# retired zone hierarchy. Release them explicitly after staged scene disposal
	# so a verifier or editor preview cannot leave their WorldEnvironment,
	# lights, timers, or service-owned render resources alive until process exit.
	if visual_director != null and is_instance_valid(visual_director):
		_release_zone_render_resources(visual_director)
		visual_director.queue_free()
	visual_director = null
	if retired_zone_cleanup_root != null and is_instance_valid(retired_zone_cleanup_root):
		retired_zone_cleanup_root.queue_free()
	retired_zone_cleanup_root = null
	if performance_budget_monitor != null and is_instance_valid(performance_budget_monitor):
		performance_budget_monitor.queue_free()
	performance_budget_monitor = null
	if seamless_world != null and is_instance_valid(seamless_world):
		seamless_world.queue_free()
	seamless_world = null
	if qa_adapter != null and is_instance_valid(qa_adapter):
		qa_adapter.queue_free()
	qa_adapter = null
	if runtime_services != null and is_instance_valid(runtime_services):
		runtime_services.process_mode = Node.PROCESS_MODE_DISABLED
		for service in runtime_services.get_children():
			if service is Node:
				(service as Node).process_mode = Node.PROCESS_MODE_DISABLED
		runtime_services.queue_free()
	runtime_services = null
	if zone_runtime_coordinator != null:
		zone_runtime_coordinator.dispose()
	zone_runtime_coordinator = null

func zone_lifecycle_snapshot() -> Dictionary:
	var cached_ids: Array[String] = []
	for raw_id in route_zone_cache.keys():
		cached_ids.append(str(raw_id))
	cached_ids.sort()
	if performance_budget_monitor != null:
		performance_budget_monitor.refresh_budget_snapshot()
	return {
		"active_zone": current_zone_id if zone_root != null and is_instance_valid(zone_root) else "",
		"active_owner": str(zone_root.get_meta("zone_resource_owner", "")) if zone_root != null and is_instance_valid(zone_root) else "",
		"cached_ids": cached_ids,
		"cached_count": cached_ids.size(),
		"retiring_count": pending_zone_retirements,
		"resource_anchor_count": skinned_resource_anchors.size(),
		"resource_anchor_nodes": retired_skinned_actor_pool.get_child_count() if retired_skinned_actor_pool != null and is_instance_valid(retired_skinned_actor_pool) else 0,
		"material_anchor_count": retired_material_anchors.size(),
		"active_nodes": _subtree_node_count(zone_root),
		"active_skeletons": zone_root.find_children("*", "Skeleton3D", true, false).size() if zone_root != null and is_instance_valid(zone_root) else 0,
		"active_navigation_regions": zone_root.find_children("*", "NavigationRegion3D", true, false).size() if zone_root != null and is_instance_valid(zone_root) else 0,
		"static_memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"transition_history": transition_history.duplicate(true),
		"material_cache_count": material_cache.size(),
		"zone_runtime": zone_runtime_coordinator.snapshot() if zone_runtime_coordinator != null else {},
		"seamless_world": seamless_world.snapshot() if seamless_world != null else {},
		"performance": performance_budget_monitor.get_snapshot() if performance_budget_monitor != null else {},
	}

func _subtree_node_count(root: Node) -> int:
	if root == null or not is_instance_valid(root):
		return 0
	var count := 1
	for child in root.get_children():
		count += _subtree_node_count(child)
	return count

func release_session() -> void:
	# Cached zones remain children of the game and are released by normal subtree
	# destruction. Touching renderer resources during NOTIFICATION_EXIT_TREE is unsafe.
	route_zone_cache.clear()
	route_enemy_cache.clear()
	route_zone_signatures.clear()
	route_spatial_cache.clear()
	# Do not free retired roots from NOTIFICATION_EXIT_TREE. Their parent scene
	# owns destruction, and touching detached renderer resources during shutdown
	# produces misleading null-material/RID diagnostics in Compatibility mode.
	retired_zone_roots.clear()
	pending_zone_retirements = 0
	skinned_resource_anchors.clear()
	retired_material_anchors.clear()
	transition_history.clear()
	if performance_budget_monitor != null:
		performance_budget_monitor.suspend()

func _keep_player_in_world() -> void:
	if player == null:
		return
	var in_passage := WorldSectorManifest.connector_contains(current_zone_id,player.global_position) or (seamless_world != null and seamless_world.contains_resident_passage(player.global_position))
	if in_passage and player.global_position.y > -2.0: return
	if _is_river_recovery_position(current_zone_id, player.global_position):
		_recover_from_river(player, _river_center(current_zone_id), 3.4)
		return
	var half = _zone_half_extents(current_zone_id)
	var inside_recovery_bounds: bool = player.global_position.y > -2.0 \
		and abs(player.global_position.x) < half.x - 1.5 \
		and abs(player.global_position.z) < half.y - 1.5
	if inside_recovery_bounds:
		# Broad bounds alone can remember a point inside a tree, wall, or prop and
		# later restore Kael into that obstruction. Only the active spatial service
		# may promote a live position to the recovery checkpoint.
		if player.global_position.distance_squared_to(last_safe_player_position) >= 0.0625:
			if spatial_service == null or spatial_service.is_walkable_position(
					player.global_position, 0.55, spatial_service.bank_for(player.global_position)):
				last_safe_player_position = player.global_position
		return
	if player.global_position.y < -8.0 or abs(player.global_position.x) > half.x + 4.0 or abs(player.global_position.z) > half.y + 4.0:
		var recovery: Vector3 = last_safe_player_position
		if spatial_service != null:
			var preferred_bank: int = spatial_service.bank_for(last_safe_player_position)
			recovery = spatial_service.nearest_safe(player.global_position, preferred_bank)
		player.global_position = recovery + Vector3(0, 1.2, 0)
		player.reset_physics_interpolation()
		if camera_rig != null:
			camera_rig.reset_follow()
		player.velocity = Vector3.ZERO
		last_safe_player_position = player.global_position
		hud.toast("Kael catches himself before the dark takes him.")

func _safe_loaded_position(zone: String, pos: Vector3) -> Vector3:
	if WorldSectorManifest.connector_contains(zone,pos) and pos.y > -2.0 and pos.y < 4.0:
		return Vector3(pos.x,maxf(0.95,pos.y),pos.z)
	var river_z := _river_center(zone)
	if spatial_service != null and spatial_service.zone_id == zone:
		var active_candidate: Vector3 = spatial_service.validate_position(pos, 0.90, spatial_service.bank_for(pos))
		if river_z < SpatialSurfaceContract.NO_RIVER and spatial_service.is_on_bridge(active_candidate, 0.90):
			active_candidate.y = maxf(active_candidate.y, 0.95)
			return active_candidate
		var active_safe: Vector3 = spatial_service.nearest_safe(active_candidate, spatial_service.bank_for(active_candidate))
		# Spatial services return a walkable surface point. Player transforms store
		# the CharacterBody capsule origin, so every loaded position needs the same
		# clearance already applied to bridge saves.
		active_safe.y = maxf(active_safe.y, 0.95)
		return active_safe
	var validator = ZoneSpatialService.new()
	validator.configure(zone, _river_center(zone), _zone_half_extents(zone))
	var fallback_candidate: Vector3 = validator.validate_position(pos, 0.90, validator.bank_for(pos))
	if river_z < SpatialSurfaceContract.NO_RIVER and validator.is_on_bridge(fallback_candidate, 0.90):
		fallback_candidate.y = maxf(fallback_candidate.y, 0.95)
		validator.free()
		return fallback_candidate
	var safe := validator.nearest_safe(fallback_candidate, validator.bank_for(fallback_candidate))
	validator.free()
	safe.y = maxf(safe.y, 0.95)
	return safe

func validate_walkable_position(pos: Vector3) -> Vector3:
	return _zone_construction().validate_walkable_position(pos)

func _recover_from_river(body: Node, river_z: float, span: float) -> void:
	if not (body is CharacterBody3D):
		return
	var actor := body as Node3D
	var side := -1 if actor.global_position.z <= river_z else 1
	var candidate: Vector3 = spatial_service.nearest_safe(actor.global_position, side) if spatial_service != null else validate_walkable_position(Vector3(actor.global_position.x, 0.0, river_z + float(side) * (span * 0.5 + 1.35)))
	actor.global_position = candidate + Vector3.UP * 0.9
	(body as CharacterBody3D).velocity = Vector3.ZERO
	if body == player:
		last_safe_player_position = actor.global_position
		hud.toast("The bank catches Kael before the current can take him.")

func _river_center(zone: String = current_zone_id) -> float:
	return SpatialSurfaceContract.river_center(zone)

func _is_river_recovery_position(zone: String, pos: Vector3) -> bool:
	var river_z := _river_center(zone)
	if river_z >= SpatialSurfaceContract.NO_RIVER:
		return false
	# The bridge deck occupies the river exclusion band by design. It is flush
	# with the banks, so identify the legal crossing by the full bridge corridor
	# rather than by actor height. This also prevents the recovery guard from
	# snapping a player off the deck while stepping onto the far bank.
	# The deck is flush with the road at world Y=0, so a grounded actor root
	# normally remains near zero while its capsule stands on the deck. Requiring
	# Y>=0.2 incorrectly classified every ordinary bridge crossing as water.
	var on_bridge_deck := false
	if spatial_service != null and spatial_service.has_method("is_on_bridge"):
		on_bridge_deck = spatial_service.is_on_bridge(pos, 0.0)
	else:
		on_bridge_deck = SpatialSurfaceContract.is_on_default_bridge(zone, pos, 0.0)
	if on_bridge_deck:
		return false
	return SpatialSurfaceContract.is_river_excluded(zone, pos, -0.25)

func _is_river_excluded(pos: Vector3, margin: float = 0.0) -> bool:
	return _zone_construction()._is_river_excluded(pos, margin)

func river_safe_position(pos: Vector3, margin: float = 0.55) -> Vector3:
	return _zone_construction().river_safe_position(pos, margin)

func river_safe_path(points: Array, margin: float = 0.90) -> Array:
	if spatial_service != null:
		return spatial_service.validate_path(points, margin)
	var validator := ZoneSpatialService.new()
	validator.configure(current_zone_id, _river_center(), _zone_half_extents(current_zone_id))
	var sanitized: Array = validator.validate_path(points, margin)
	validator.free()
	return sanitized

func get_zone_half_extents(zone_id: String) -> Vector2:
	return SpatialSurfaceContract.zone_half_extents(zone_id)

func _zone_half_extents(zone_id: String) -> Vector2:
	return get_zone_half_extents(zone_id)
