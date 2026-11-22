class_name ZoneRuntimeCoordinator
extends RefCounted

const ZoneCompositionRouter = preload("res://scripts/zone_composition_router.gd")

## Small lifecycle contract shared by the host and release verifiers.
## Builders remain owned by ZoneCompositionRouter; this object owns the
## transition state and records failed/activated zone builds without hiding
## errors or changing manager ownership.

var host
var quest_manager: Node
var quest_presentation: Node
var quest_beats: Node
var interaction_focus: Node
var pending_zone := ""
var active_zone := ""
var transition_count := 0
var failure_count := 0
var last_failure: Dictionary = {}
var last_activation: Dictionary = {}
var build_count := 0
var last_build: Dictionary = {}
var build_started_usec := 0
var source_zone := ""
var source_position := Vector3.ZERO
var source_facing := 0.0

func _init(runtime_host: Node) -> void:
	host = runtime_host

func configure(presentation: Node, beats: Node, focus: Node, quests: Node) -> void:
	quest_presentation = presentation
	quest_beats = beats
	interaction_focus = focus
	quest_manager = quests

func normalize_zone_request(zone_id: String, spawn_position: Vector3) -> Dictionary:
	var normalized := zone_id.strip_edges().to_lower()
	var registered: Array[String] = ZoneCompositionRouter.registered_zones()
	# The router is preloaded by the host, so this fallback keeps the contract
	# usable in isolated unit tests without inventing an alternate zone list.
	if registered.is_empty() and host != null and host.has_method("_zone_display_name"):
		registered = [normalized]
	if normalized == "" or (not registered.is_empty() and normalized not in registered):
		return {"ok": false, "zone_id": normalized, "spawn_position": spawn_position, "error": "unknown_zone"}
	return {"ok": true, "zone_id": normalized, "spawn_position": spawn_position}

func sync_zone(zone_id: String) -> Dictionary:
	var normalized := zone_id.strip_edges().to_lower()
	if quest_presentation != null and quest_presentation.has_method("set_zone"):
		quest_presentation.set_zone(normalized)
	if quest_beats != null and quest_beats.has_method("set_zone"):
		quest_beats.set_zone(normalized)
	elif quest_manager != null and quest_manager.has_method("set_tracked_quest_for_zone"):
		quest_manager.set_tracked_quest_for_zone(normalized)
	return {
		"zone_id": normalized,
		"tracked_quest": str(quest_presentation.get_tracked_quest()) if quest_presentation != null and quest_presentation.has_method("get_tracked_quest") else str(quest_manager.get_tracked_quest()) if quest_manager != null else "",
		"display_name": str(quest_presentation.get_zone_display_name(normalized)) if quest_presentation != null and quest_presentation.has_method("get_zone_display_name") else normalized,
	}

func refresh_presentation() -> String:
	if quest_beats != null and quest_beats.has_method("refresh"):
		quest_beats.refresh()
	if quest_presentation != null and quest_presentation.has_method("get_objective_view_model"):
		var view: Dictionary = quest_presentation.get_objective_view_model()
		return str(view.get("tracker_text", "No objective in this area."))
	var tracker := str(quest_presentation.get_tracker_text()) if quest_presentation != null and quest_presentation.has_method("get_tracker_text") else str(quest_manager.get_tracker_text()) if quest_manager != null else "No objective in this area."
	if quest_beats != null and quest_beats.has_method("decorate_tracker"):
		tracker = quest_beats.decorate_tracker(tracker)
	return tracker

func choose_interaction(candidates: Array, player: Node3D, camera: Camera3D, validator: Callable) -> Node:
	if interaction_focus != null and interaction_focus.has_method("choose"):
		return interaction_focus.choose(candidates, player, camera, validator)
	return null

func record_playable_transition(zone_id: String, elapsed_ms: float, support_ready: bool) -> void:
	last_activation["zone"] = zone_id
	last_activation["state"] = "playable"
	last_activation["playable_ms"] = elapsed_ms
	last_activation["support_ready"] = support_ready

func begin_transition(zone_id: String, previous_zone: String, spawn_position: Vector3) -> void:
	preload("res://scripts/greyfen_archery_range.gd").stop_activity(host)
	preload("res://scripts/bracken_field_trial.gd").stop_activity(host)
	source_zone = previous_zone
	if host != null and is_instance_valid(host.player):
		source_position = host.player.global_position
		source_facing = host.player.rotation.y
	pending_zone = zone_id
	transition_count += 1
	last_activation = {
		"zone": zone_id,
		"previous_zone": previous_zone,
		"spawn_position": spawn_position,
		"state": "building",
	}

func begin_build(zone_id: String, composition_kind: String) -> void:
	build_count += 1
	build_started_usec = Time.get_ticks_usec()
	last_build = {
		"zone": zone_id,
		"composition_kind": composition_kind,
		"state": "building",
		"build_index": build_count,
	}

func finish_build(result: Dictionary, root: Node3D) -> Dictionary:
	var elapsed_ms := float(Time.get_ticks_usec() - build_started_usec) / 1000.0 if build_started_usec > 0 else 0.0
	var completed := result.duplicate(true)
	completed["build_ms"] = elapsed_ms
	var node_count := _node_count(root)
	completed["node_count"] = node_count
	if root != null and is_instance_valid(root):
		# Node count is diagnostic data, not a second activation requirement. Cache
		# the one traversal performed for this build so activation and snapshots
		# do not walk the same zone again on the transition path.
		root.set_meta("zone_runtime_node_count", node_count)
	completed["state"] = "validated" if bool(result.get("ok", false)) else "failed"
	last_build = completed
	build_started_usec = 0
	return completed

func validate_build(zone_id: String, result: Dictionary, root: Node3D) -> Dictionary:
	var errors: Array[String] = []
	if not bool(result.get("ok", false)):
		errors.append_array(result.get("errors", []))
	if root == null or not is_instance_valid(root):
		errors.append("zone root is missing")
	elif root.get_child_count() == 0:
		errors.append("zone root is empty")
	for required_counter in ["ground_count", "bounds_count", "gate_count"]:
		if int(result.get(required_counter, 0)) < 1:
			errors.append("missing build contract: %s" % required_counter)
	var contract: Dictionary = root.get_meta("zone_build_contract", {})
	if not contract.is_empty() and not bool(contract.get("ok", false)):
		errors.append_array(contract.get("errors", []))
	return {"ok": errors.is_empty(), "zone": zone_id, "errors": errors}

func activate(zone_id: String, root: Node3D, reused: bool) -> void:
	active_zone = zone_id
	pending_zone = ""
	var node_count := int(root.get_meta("zone_runtime_node_count", -1)) if root != null and is_instance_valid(root) else 0
	if node_count < 0:
		node_count = _node_count(root)
	last_activation = {
		"zone": zone_id,
		"state": "active",
		"reused": reused,
		"node_count": node_count,
	}

func rollback(zone_id: String, previous_zone: String, errors: Array) -> void:
	failure_count += 1
	pending_zone = ""
	last_failure = {
		"zone": zone_id,
		"previous_zone": previous_zone,
		"errors": errors.duplicate(),
	}

func snapshot() -> Dictionary:
	return {
		"pending_zone": pending_zone,
		"active_zone": active_zone,
		"transition_count": transition_count,
		"failure_count": failure_count,
		"last_failure": last_failure.duplicate(true),
		"last_activation": last_activation.duplicate(true),
		"build_count": build_count,
		"last_build": last_build.duplicate(true),
		"presentation_zone": str(quest_presentation.get_zone_id()) if quest_presentation != null and quest_presentation.has_method("get_zone_id") else "",
		"tracked_quest": str(quest_presentation.get_tracked_quest()) if quest_presentation != null and quest_presentation.has_method("get_tracked_quest") else str(quest_manager.get_tracked_quest()) if quest_manager != null else "",
	}

func dispose() -> void:
	# The coordinator is a RefCounted lifecycle object owned by game.gd. Clear
	# its service references explicitly before the host is freed so a verifier or
	# scene reload cannot retain a stale owner graph past shutdown.
	host = null
	quest_manager = null
	quest_presentation = null
	quest_beats = null
	interaction_focus = null
	pending_zone = ""
	active_zone = ""
	last_failure.clear()
	last_activation.clear()
	last_build.clear()
	build_started_usec = 0

func _node_count(root: Node) -> int:
	if root == null or not is_instance_valid(root):
		return 0
	var count := 0
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var current: Node = pending.pop_back() as Node
		count += 1
		for child in current.get_children():
			pending.append(child)
	return count

func load_zone(zone_id: String, spawn_pos: Vector3 = Vector3.ZERO) -> void:
	if host.new_game_start_pending and not host.game_started:
		host.new_game_start_pending = false
	zone_id = zone_id.strip_edges().to_lower()
	# Synchronous visual imports must never overlap a zone swap. The prewarm
	# coroutine is resumed after the player is playable again.
	host.campaign_visual_prewarm_suspended = true
	if host.performance_budget_monitor != null:
		host.performance_budget_monitor.suspend()
	host.loading_started_usec = host.loading_started_usec if host.loading_started_usec > 0 else Time.get_ticks_usec()
	if host.player != null and host.player.has_method("set_transition_locked"):
		host.player.set_transition_locked(true)
	if host.camera_rig != null and host.camera_rig.has_method("clear_target_lock"):
		host.camera_rig.clear_target_lock()
	if host.hud != null and host.hud.has_method("clear_target_lock_status"):
		host.hud.clear_target_lock_status()
	host._clear_oathfire_effects()
	host.runtime_light_count = 0
	host.tree_batch_data.clear()
	host.deadfall_batch_data.clear()
	host.prop_batch_data.clear()
	host.visual_box_batch_data.clear()
	host.terrain_patch_batch_data.clear()
	host.house_batch_data.clear()
	host.house_module_batch_data.clear()
	host.environment_batches_flushed = false
	host.tree_collision_body = null
	host.prop_collision_body = null
	if host.player != null and host.player.has_method("cancel_beam_charge"):
		host.player.cancel_beam_charge()
	var previous_zone_id: String = host.current_zone_id
	var previous_enemies: Array = host.active_enemies.duplicate()
	var world_prop_controller_installed = false
	if host.zone_runtime_coordinator != null:
		host.zone_runtime_coordinator.begin_transition(zone_id, previous_zone_id, spawn_pos)
	var previous_spatial_service: Node = host.spatial_service
	preload("res://scripts/companion_controller.gd").depart(host)
	var reused_zone = false
	var requested_signature = host._zone_state_signature()
	if host.zone_root != null:
		if previous_zone_id == zone_id and host.active_zone_signature == requested_signature:
			reused_zone = true
		elif previous_zone_id == zone_id:
			var stale_active = host.zone_root
			host._retire_zone_root(stale_active)
			host.zone_root = null
		else:
			host._cache_route_zone(previous_zone_id, host.zone_root, previous_enemies, host.active_zone_signature)
			host._cache_route_spatial_service(previous_zone_id, previous_spatial_service)
	host.active_interactable = null
	host.interaction_candidates.clear()
	host.interaction_area_cache.clear()
	host.interaction_area_cache_ready = false
	host.interaction_focus_dirty = true
	host.interaction_focus_cache_valid = false
	host.compass_dirty = true
	host.compass_cache_valid = false
	host.last_compass_zone = ""
	host.last_compass_signature = ""
	# Guidance belongs to the previous route. Clear it before the new zone
	# refreshes its own contextual hint so stale prompts cannot survive a gate.
	host.hud.set_guidance_hint("")
	host.current_zone_id = zone_id
	if zone_id != "greyfen":
		host.opening_detail_pending = false
		host.opening_detail_generation += 1
	var using_prewarmed_spatial = zone_id == "greyfen" \
		and host.greyfen_prewarm_spatial_service != null \
		and is_instance_valid(host.greyfen_prewarm_spatial_service)
	var cached_spatial_service: Node = host.route_spatial_cache.get(zone_id)
	var using_cached_spatial = cached_spatial_service != null \
		and is_instance_valid(cached_spatial_service) \
		and host.route_zone_cache.has(zone_id) \
		and int(host.route_zone_signatures.get(zone_id, -1)) == requested_signature
	print("LOADING: zone_begin id=%s prewarm=%s cached=%s" % [zone_id, using_prewarmed_spatial, using_cached_spatial])
	host._release_active_spatial_service()
	if using_prewarmed_spatial:
		host.spatial_service = host.greyfen_prewarm_spatial_service
		host.greyfen_prewarm_spatial_service = null
		host.spatial_service.name = "ZoneSpatialService"
		host.spatial_service.process_mode = Node.PROCESS_MODE_INHERIT
	elif using_cached_spatial:
		host.spatial_service = cached_spatial_service
		host.route_spatial_cache.erase(zone_id)
		host.spatial_service.name = "ZoneSpatialService"
		host.spatial_service.process_mode = Node.PROCESS_MODE_INHERIT
	else:
		host.spatial_service = host.ZoneSpatialService.new()
		host.spatial_service.name = "ZoneSpatialService"
		host.add_child(host.spatial_service)
		host.spatial_service.configure(zone_id, host._river_center(zone_id), host._zone_half_extents(zone_id))
	host._bind_spatial_player_body()
	if host.camera_rig != null and host.camera_rig.has_method("set_zone"):
		host.camera_rig.set_zone(zone_id)
	host.active_enemies.clear()
	host._sync_camera_enemy_cache()
	host.hud.set_prompt("")
	# Target health belongs to the active encounter. Clear it before the new
	# zone starts so Castle, finale, and dialogue views cannot inherit a dead
	# Wychwood target from the previous route.
	host.hud.hide_enemy()
	if reused_zone:
		host.active_enemies = host._valid_cached_enemies(previous_enemies)
	elif host.route_zone_cache.has(zone_id) and is_instance_valid(host.route_zone_cache[zone_id]) \
			and int(host.route_zone_signatures.get(zone_id, -1)) == requested_signature:
		host.zone_root = host._activate_cached_zone(zone_id)
		print("LOADING: cached_zone_activated id=%s valid=%s" % [zone_id, host.zone_root != null])
		print("LOADING: zone_stage=cache_activated elapsed=%.1f" % (float(Time.get_ticks_usec() - host.loading_started_usec) / 1000.0))
		host.active_zone_signature = int(host.route_zone_signatures.get(zone_id, requested_signature))
		host.route_zone_signatures.erase(zone_id)
		var prewarm_camera = host.zone_root.find_child("GreyfenPrewarmCamera", true, false) as Camera3D
		if prewarm_camera != null:
			prewarm_camera.current = false
			prewarm_camera.queue_free()
		host.active_enemies = host._valid_cached_enemies(host.route_enemy_cache.get(zone_id, []))
		host.route_enemy_cache.erase(zone_id)
		reused_zone = true
	else:
		if host.route_zone_cache.has(zone_id):
			var stale_root = host.route_zone_cache.get(zone_id)
			host.route_zone_cache.erase(zone_id)
			host.route_enemy_cache.erase(zone_id)
			host.route_zone_signatures.erase(zone_id)
			if is_instance_valid(stale_root):
				host._retire_zone_root(stale_root)
		host.zone_root = Node3D.new()
		host.zone_root.name = zone_id
		host.zone_root.process_mode = Node.PROCESS_MODE_PAUSABLE
		host.add_child(host.zone_root)
		var authored_layers = host.ZoneSceneCatalog.attach(zone_id, host.zone_root)
		if not bool(authored_layers.get("ok", true)):
			push_error("Authored zone layers failed for %s: %s" % [
				zone_id, ", ".join(authored_layers.get("errors", []))
			])
		var composition_kind = host.ZoneCompositionRouter.composition_kind(zone_id)
		var build_result: Dictionary
		if host.zone_runtime_coordinator != null:
			host.zone_runtime_coordinator.begin_build(zone_id, composition_kind)
		if composition_kind == "campaign":
			build_result = host.ZoneCompositionRouter.build_campaign(host, zone_id)
		else:
			build_result = host.ZoneCompositionRouter.build_core(host, zone_id)
		if host.zone_runtime_coordinator != null:
			build_result = host.zone_runtime_coordinator.finish_build(build_result, host.zone_root)
		var build_validation = host.zone_runtime_coordinator.validate_build(zone_id, build_result, host.zone_root) if host.zone_runtime_coordinator != null else build_result
		if not bool(build_validation.get("ok", false)):
			push_error("Zone composition failed for %s: %s" % [
				zone_id, ", ".join(build_validation.get("errors", []))
			])
			if host.zone_runtime_coordinator != null:
				host.zone_runtime_coordinator.rollback(zone_id, previous_zone_id, build_validation.get("errors", []))
			host._recover_failed_zone_load(previous_zone_id)
			return
		if composition_kind == "campaign":
			host._apply_campaign_arrival(zone_id)
		host._flush_environment_batches()
		host._install_world_prop_controller(zone_id)
		world_prop_controller_installed = true
		if zone_id in ["greyfen", "wychwood"]:
			host._add_visual_100_layer(zone_id)
		host._apply_first_route_materials(host.zone_root)
		# The authoritative render-resource pass runs after the player, sky, and
		# encounter roots are attached below. Walking a large campaign zone here as
		# well doubled castle activation work without protecting an additional
		# visible frame.
		host.active_zone_signature = host._zone_state_signature()
	host._sync_camera_enemy_cache()
	if host.zone_root != null:
		host.zone_root.set_meta("zone_resource_owner", "active")
		host.zone_root.set_meta("zone_resource_id", zone_id)
		if zone_id == "deep_wood":
			host.CampaignWildernessSection.new().publish_rooks_false_road(ZoneBuildContext.new(host, zone_id))
		elif zone_id == "old_mill":
			host.CampaignWildernessSection.new().publish_hidden_ash_measure(ZoneBuildContext.new(host, zone_id))
		if not world_prop_controller_installed:
			host._install_world_prop_controller(zone_id)
		if host.zone_runtime_coordinator != null:
			host.zone_runtime_coordinator.activate(zone_id, host.zone_root, reused_zone)
	host._trim_route_zone_cache([previous_zone_id] if previous_zone_id != zone_id else [])
	# Avoid recursive diagnostic walks during every transition; on Web/ANGLE those
	# allocations made cached arrivals visibly slower.
	print("ZONE_COMPOSITION: id=%s reused=%s visible=%s position=%s" % [
		zone_id, reused_zone, host.zone_root.visible, host.zone_root.global_position,
	])
	host.active_zone_signature = host._zone_state_signature()
	# Navigation baking and the recursive render-resource audit are correctness
	# work, not prerequisites for the first visible arrival. A cold campaign
	# build can otherwise spend most of its transition budget here before the
	# player receives control. The deferred finalizer is guarded by the active
	# root/service pair so a fast return cannot let stale work touch a new zone.
	var navigation_pending = not using_prewarmed_spatial and not using_cached_spatial
	var life_controller = host.zone_root.find_child("GreyfenLifeController", true, false)
	if life_controller != null and life_controller.has_method("set_spatial_service"):
		life_controller.set_spatial_service(host.spatial_service)
	if host.zone_runtime_coordinator != null:
		host.zone_runtime_coordinator.sync_zone(zone_id)
	host._refresh_tracker()
	print("LOADING: zone_stage=systems_synced elapsed=%.1f" % (float(Time.get_ticks_usec() - host.loading_started_usec) / 1000.0))
	if host.visual_director != null:
		host.visual_director.apply_zone(zone_id, host.zone_root)
	print("LOADING: zone_stage=visual_applied elapsed=%.1f" % (float(Time.get_ticks_usec() - host.loading_started_usec) / 1000.0))
	if host.zone_streaming != null and host.zone_streaming.has_method("prewarm_neighbors") and not host.should_defer_neighbor_prewarm():
		host.zone_streaming.prewarm_neighbors(zone_id)
	# Generated campaign ambience and music can allocate several seconds of WAV
	# data on first use. Mark it for the first settled frame instead of making
	# audio synthesis part of the player's transition lock. Greyfen remains on
	# the opening path because its menu prewarm already prepares those cues.
	if zone_id == "greyfen":
		host._apply_zone_audio(zone_id)
	else:
		host.zone_root.set_meta("zone_audio_pending", true)
	# Authored arrivals are already reserved by the zone builder. Preserve their
	# exact route position here; nearest_safe() is an emergency recovery API and
	# can otherwise move a valid arrival to a distant edge anchor.
	var safe_spawn: Vector3 = host.spatial_service.validate_position(spawn_pos, 0.8, host.spatial_service.bank_for(spawn_pos))
	if host.player == null:
		host._spawn_player(safe_spawn)
	else:
		host.player.visible = true
		if not using_prewarmed_spatial:
			host.player.process_mode = Node.PROCESS_MODE_PAUSABLE
			if host.camera_rig != null:
				host.camera_rig.process_mode = Node.PROCESS_MODE_INHERIT
				var gameplay_camera = host.camera_rig.find_child("Camera3D", true, false) as Camera3D
				if gameplay_camera != null:
					gameplay_camera.current = true
	# Greyfen's life controller is constructed with the zone. New Game now creates
	host._apply_pending_player_restore()
	if zone_id == "greyfen":
		host._restore_greyfen_cemetery_state()
	# Kael after collision is ready, so bind the final player instance here.
	if life_controller != null:
		life_controller.player = host.player
	host._install_opening_soundscape(zone_id)
	# The builder and imported-asset helper attach validated materials as each
	# mesh is created. The full zone tree is audited by lifecycle gates; doing the
	# same recursive walk on every player transition adds visible latency on
	# Compatibility/ANGLE, so keep that audit off the swap path.
	# The late-created render roots still receive the fast, focused validation.
	# The full zone tree is checked explicitly by verify_engine_003/004.
	if host.visual_director != null:
		host._validate_zone_render_resources(host.visual_director)
	if host.player != null:
		host._validate_zone_render_resources(host.player)
	for enemy in host.active_enemies:
		if is_instance_valid(enemy):
			host._validate_zone_render_resources(enemy)
	# The finalizer prints the render_validated stage after the player is live.
	# Full-zone lifecycle verifiers still audit every surface independently.
	print("LOADING: zone_stage=render_validation_deferred elapsed=%.1f" % (float(Time.get_ticks_usec() - host.loading_started_usec) / 1000.0))
	if host.performance_budget_monitor != null:
		var quality_preset = str(host.settings.settings.get("quality_preset", "balanced")) if host.settings != null else "balanced"
		host.performance_budget_monitor.set_active_zone(host.current_zone_id, host.zone_root, host.player, quality_preset)
	print("LOADING: zone_stage=budget_ready elapsed=%.1f" % (float(Time.get_ticks_usec() - host.loading_started_usec) / 1000.0))
	host._schedule_zone_runtime_finalize(zone_id, host.zone_root, host.spatial_service, host.active_enemies.duplicate(), navigation_pending)
	if host.player != null:
		host.pending_spawn_facing = host.player.rotation.y
		host.pending_spawn_position = safe_spawn
		host.player.global_position = safe_spawn + Vector3.UP * 0.9
		host.player.velocity = Vector3.ZERO
		if using_prewarmed_spatial:
			# This scene has already completed collision and navigation setup
			# behind the menu. Do not wait for another rendered WebGL frame.
			host.player.global_position = Vector3(safe_spawn.x, maxf(safe_spawn.y, 0.95), safe_spawn.z)
			print("LOADING: handoff_phase=unlock_begin")
			host.player.set_transition_locked(false)
			print("LOADING: handoff_phase=unlock_end")
			host.last_safe_player_position = host.player.global_position
			host.zone_transition_pending = false
			host.campaign_visual_prewarm_suspended = false
			# The player and camera are already visible behind the menu. Enabling
			# their full process tree can trigger synchronous WebGL animation and
			# physics setup, so finish activation after the playable marker.
			host.call_deferred("_activate_prewarmed_player_runtime")
			var elapsed_ms = float(Time.get_ticks_usec() - host.loading_started_usec) / 1000.0
			host._record_loading_metrics({
				"zone": host.current_zone_id,
				"to_playable_ms": elapsed_ms,
				"support_ready": true,
				"velocity_reset": true
			})
			if host.zone_runtime_coordinator != null:
				host.zone_runtime_coordinator.record_playable_transition(host.current_zone_id, elapsed_ms, true)
			print("LOADING: zone=%s playable_ms=%.1f" % [host.current_zone_id, elapsed_ms])
			host.loading_started_usec = 0
			print("LOADING: handoff_phase=hide_loading_begin")
			host.hud.hide_loading()
			print("LOADING: handoff_phase=hide_loading_end")
		else:
			host.player.set_transition_locked(true)
			host.zone_transition_frames = 0
			host.zone_transition_pending = true
	print("LOADING: handoff_phase=before_seamless")
	if host.seamless_world != null:
		host.seamless_world.on_zone_activated(host.current_zone_id, safe_spawn)
	print("LOADING: handoff_phase=after_seamless")
	if host.game_started:
		host._schedule_zone_autosave()
	print("LOADING: handoff_phase=after_autosave")
	if zone_id == "greyfen" and not host.opening_detail_pending \
			and str(host.zone_root.get_meta("opening_build_profile", "")) in ["opening_fast", "opening_boot"] \
			and not bool(host.zone_root.get_meta("opening_detail_complete", false)):
		host.opening_detail_pending = true
		host.opening_detail_stage_index = 0
		host.opening_detail_generation += 1
		host.call_deferred("_run_opening_detail_stage", host.opening_detail_generation)
	if zone_id == "wychwood" and host.quests.is_active("main_road_of_crows") and not host.quests.is_objective_done("main_road_of_crows", "fight_ghoulkin"):
		host.audio.play_event("reveal", 0.02)
		host.audio.play_event("wychwood_tension", 0.01)
		host.audio.set_music_state("wychwood_tension")
		if host.audio.has_method("prewarm_music_state"):
			host.audio.prewarm_music_state("ghoulkin_combat")

func advance_transition() -> void:
	host.zone_transition_frames += 1
	if host.player == null or host.spatial_service == null:
		return
	var grounded: Variant = host._grounded_spawn_position(host.pending_spawn_position)
	if grounded == null:
		if host.zone_transition_frames > 3:
			push_warning("Zone spawn support timed out; using validated recovery: %s" % host.current_zone_id)
			grounded = host.spatial_service.nearest_safe(host.pending_spawn_position, host.spatial_service.bank_for(host.pending_spawn_position))
			grounded.y = 0.95
		else:
			return
	host.player.global_position = grounded
	host.player.rotation.y = host.pending_spawn_facing
	host.player.velocity = Vector3.ZERO
	if host.zone_transition_frames < 2:
		return
	host.player.set_transition_locked(false)
	host.last_safe_player_position = host.player.global_position
	host.zone_transition_pending = false
	host.campaign_visual_prewarm_suspended = false
	var elapsed_ms = float(Time.get_ticks_usec() - host.loading_started_usec) / 1000.0
	host._record_loading_metrics({
		"zone": host.current_zone_id,
		"to_playable_ms": elapsed_ms,
		"support_ready": true,
		"velocity_reset": host.player.velocity.is_zero_approx()
	})
	if host.performance_budget_monitor != null:
		host.performance_budget_monitor.record_transition(elapsed_ms)
	if host.zone_runtime_coordinator != null:
		host.zone_runtime_coordinator.record_playable_transition(host.current_zone_id, elapsed_ms, true)
	print("LOADING: zone=%s playable_ms=%.1f" % [host.current_zone_id, elapsed_ms])
	host.loading_started_usec = 0
	host.hud.hide_loading()
	host._start_campaign_visual_prewarm()
	host._schedule_deferred_visual_roles(host.zone_root)
	host._schedule_deferred_zone_audio(host.current_zone_id, host.zone_root)

func recover_failed_transition(previous_zone_id: String) -> void:
	host.pending_player_restore.clear()
	host.campaign_pack_waiting = false
	if host.seamless_world != null:
		host.seamless_world.on_zone_failed(host.current_zone_id, "zone_build_failed")
	host.zone_transition_pending = false
	host.campaign_visual_prewarm_suspended = false
	host.zone_load_request_pending = false
	host.requested_zone_id = ""
	if host.zone_root != null:
		host._retire_zone_root(host.zone_root)
		host.zone_root = null
	host._release_active_spatial_service()
	if host.route_zone_cache.has(previous_zone_id) and is_instance_valid(host.route_zone_cache[previous_zone_id]):
		host.zone_root = host._activate_cached_zone(previous_zone_id)
		var cached_spatial_service: Node = host.route_spatial_cache.get(previous_zone_id)
		if cached_spatial_service != null and is_instance_valid(cached_spatial_service):
			host.route_spatial_cache.erase(previous_zone_id)
			host.spatial_service = cached_spatial_service
			host.spatial_service.process_mode = Node.PROCESS_MODE_INHERIT
		host.active_enemies = host._valid_cached_enemies(host.route_enemy_cache.get(previous_zone_id, []))
		host.route_enemy_cache.erase(previous_zone_id)
		host.active_zone_signature = int(host.route_zone_signatures.get(previous_zone_id, -1))
		host.route_zone_signatures.erase(previous_zone_id)
		host.current_zone_id = previous_zone_id
		activate(previous_zone_id, host.zone_root, true)
		host._bind_spatial_player_body()
		if host.camera_rig != null:
			host.camera_rig.set_zone(previous_zone_id)
		if host.visual_director != null:
			host.visual_director.apply_zone(previous_zone_id, host.zone_root)
		sync_zone(previous_zone_id)
		host._refresh_tracker()
		host.compass_dirty = true
		host.compass_cache_valid = false
		host.interaction_focus_dirty = true
		host.interaction_focus_cache_valid = false
		host._apply_zone_audio(previous_zone_id)
	host._sync_camera_enemy_cache()
	if host.player != null:
		host.player.set_transition_locked(false)
		host.player.global_position = source_position if source_zone == previous_zone_id else host.last_safe_player_position
		if source_zone == previous_zone_id:
			host.player.rotation.y = source_facing
		host.last_safe_player_position = host.player.global_position
		host.player.velocity = Vector3.ZERO
	if host.seamless_world != null and host.zone_root != null:
		host.seamless_world.on_zone_activated(previous_zone_id, host.player.global_position if host.player != null else Vector3.ZERO)
	if is_instance_valid(host.zone_root):
		preload("res://scripts/companion_controller.gd").install(host, host.zone_root, previous_zone_id)
	if host.performance_budget_monitor != null:
		var quality_preset = str(host.settings.settings.get("quality_preset", "balanced")) if host.settings != null else "balanced"
		host.performance_budget_monitor.set_active_zone(previous_zone_id, host.zone_root, host.player, quality_preset)
	if host.hud != null:
		host.hud.hide_loading()
		host.hud.toast("The road will not open. You remain in %s." % host._zone_display_name(previous_zone_id))
