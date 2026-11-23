extends "res://scripts/core/game_session_bindings.gd"
func configure(host: Node3D, shared_state: State, services: Dictionary) -> void:
	_host = host
	_state = shared_state
	_systems = services
	configured.emit(str(name))
var world_vfx:
	get: return _construction_scope.world_vfx if _construction_scope != null else _state.world_vfx
	set(value):
		if _construction_scope == null: _state.world_vfx = value
		else: _construction_scope.world_vfx = value

var world_props: WorldPropController:
	get: return _construction_scope.world_props if _construction_scope != null else _state.world_props
	set(value):
		if _construction_scope == null: _state.world_props = value
		else: _construction_scope.world_props = value

var zone_root: Node3D:
	get: return _construction_scope.zone_root if _construction_scope != null and not _construction_scope.cancelled else (null if _construction_scope != null else _state.zone_root)
	set(value):
		if _construction_scope == null: _state.zone_root = value
		else: _construction_scope.zone_root = value

var neighbor_building: bool:
	get: return _construction_scope.preparing if _construction_scope != null else _state.neighbor_building
	set(value):
		if _construction_scope == null: _state.neighbor_building = value
		else: _construction_scope.preparing = value

var interaction_candidates: Array:
	get: return _construction_scope.interaction_candidates if _construction_scope != null else _state.interaction_candidates
	set(value):
		if _construction_scope == null: _state.interaction_candidates = value
		else: _construction_scope.interaction_candidates.assign(value)

var interaction_area_cache: Array[Area3D]:
	get: return _construction_scope.interaction_area_cache if _construction_scope != null else _state.interaction_area_cache
	set(value):
		if _construction_scope == null: _state.interaction_area_cache = value
		else: _construction_scope.interaction_area_cache.assign(value)

var interaction_area_cache_ready: bool:
	get: return _construction_scope.interaction_area_cache_ready if _construction_scope != null else _state.interaction_area_cache_ready
	set(value):
		if _construction_scope == null: _state.interaction_area_cache_ready = value
		else: _construction_scope.interaction_area_cache_ready = value

var current_zone_id: String:
	get: return _construction_scope.zone_id if _construction_scope != null else _state.current_zone_id
	set(value):
		if _construction_scope == null: _state.current_zone_id = value
		else: _construction_scope.zone_id = value

var active_enemies: Array:
	get: return _construction_scope.active_enemies if _construction_scope != null else _state.active_enemies
	set(value):
		if _construction_scope == null: _state.active_enemies = value
		else: _construction_scope.active_enemies.assign(value)

var runtime_light_count: int:
	get: return _construction_scope.runtime_light_count if _construction_scope != null else _state.runtime_light_count
	set(value):
		if _construction_scope == null: _state.runtime_light_count = value
		else: _construction_scope.runtime_light_count = value

var tree_batch_data: Array[Dictionary]:
	get: return _construction_scope.tree_batch_data if _construction_scope != null else _state.tree_batch_data
	set(value):
		if _construction_scope == null: _state.tree_batch_data = value
		else: _construction_scope.tree_batch_data.assign(value)

var deadfall_batch_data: Array[Transform3D]:
	get: return _construction_scope.deadfall_batch_data if _construction_scope != null else _state.deadfall_batch_data
	set(value):
		if _construction_scope == null: _state.deadfall_batch_data = value
		else: _construction_scope.deadfall_batch_data.assign(value)

var prop_batch_data: Dictionary:
	get: return _construction_scope.prop_batch_data if _construction_scope != null else _state.prop_batch_data
	set(value):
		if _construction_scope == null: _state.prop_batch_data = value
		else: _construction_scope.prop_batch_data.assign(value)

var visual_box_batch_data: Array[Dictionary]:
	get: return _construction_scope.visual_box_batch_data if _construction_scope != null else _state.visual_box_batch_data
	set(value):
		if _construction_scope == null: _state.visual_box_batch_data = value
		else: _construction_scope.visual_box_batch_data.assign(value)

var terrain_patch_batch_data: Array[Dictionary]:
	get: return _construction_scope.terrain_patch_batch_data if _construction_scope != null else _state.terrain_patch_batch_data
	set(value):
		if _construction_scope == null: _state.terrain_patch_batch_data = value
		else: _construction_scope.terrain_patch_batch_data.assign(value)

var house_batch_data: Dictionary:
	get: return _construction_scope.house_batch_data if _construction_scope != null else _state.house_batch_data
	set(value):
		if _construction_scope == null: _state.house_batch_data = value
		else: _construction_scope.house_batch_data.assign(value)

var house_module_batch_data: Dictionary:
	get: return _construction_scope.house_module_batch_data if _construction_scope != null else _state.house_module_batch_data
	set(value):
		if _construction_scope == null: _state.house_module_batch_data = value
		else: _construction_scope.house_module_batch_data.assign(value)

var spatial_service: Node:
	get: return _construction_scope.spatial_service if _construction_scope != null else _state.spatial_service
	set(value):
		if _construction_scope == null: _state.spatial_service = value
		else: _construction_scope.spatial_service = value

var environment_batches_flushed: bool:
	get: return _construction_scope.environment_batches_flushed if _construction_scope != null else _state.environment_batches_flushed
	set(value):
		if _construction_scope == null: _state.environment_batches_flushed = value
		else: _construction_scope.environment_batches_flushed = value

var new_game_start_pending: bool:
	get: return _state.new_game_start_pending
	set(value): _state.new_game_start_pending = value

var opening_scene_pending: bool:
	get: return _state.opening_scene_pending
	set(value): _state.opening_scene_pending = value

var zone_load_request_pending: bool:
	get: return _state.zone_load_request_pending
	set(value): _state.zone_load_request_pending = value

var resource_shutdown_prepared: bool:
	get: return _state.resource_shutdown_prepared
	set(value): _state.resource_shutdown_prepared = value

var requested_zone_id: String:
	get: return _state.requested_zone_id
	set(value): _state.requested_zone_id = value

var requested_zone_spawn: Vector3:
	get: return _state.requested_zone_spawn
	set(value): _state.requested_zone_spawn = value

var campaign_pack_waiting: bool:
	get: return _state.campaign_pack_waiting
	set(value): _state.campaign_pack_waiting = value

var opening_pack_waiting: bool:
	get: return _state.opening_pack_waiting
	set(value): _state.opening_pack_waiting = value

var greyfen_prewarm_started: bool:
	get: return _state.greyfen_prewarm_started
	set(value): _state.greyfen_prewarm_started = value

var opening_prepare_generation: int:
	get: return _state.opening_prepare_generation
	set(value): _state.opening_prepare_generation = value

var opening_phase_started_usec: int:
	get: return _state.opening_phase_started_usec
	set(value): _state.opening_phase_started_usec = value

var opening_startup_metrics: Dictionary:
	get: return _state.opening_startup_metrics
	set(value): _state.opening_startup_metrics = value

var startup_packs_waiting: bool:
	get: return _state.startup_packs_waiting
	set(value): _state.startup_packs_waiting = value

var startup_prepare_failed: bool:
	get: return _state.startup_prepare_failed
	set(value): _state.startup_prepare_failed = value

var new_game_requested_while_preparing: bool:
	get: return _state.new_game_requested_while_preparing
	set(value): _state.new_game_requested_while_preparing = value

var greyfen_prewarm_spatial_service: Node:
	get: return _state.greyfen_prewarm_spatial_service
	set(value): _state.greyfen_prewarm_spatial_service = value

var opening_detail_pending: bool:
	get: return _state.opening_detail_pending
	set(value): _state.opening_detail_pending = value

var opening_well_mesh: ArrayMesh:
	get: return _state.opening_well_mesh
	set(value): _state.opening_well_mesh = value

var opening_detail_stage_index: int:
	get: return _state.opening_detail_stage_index
	set(value): _state.opening_detail_stage_index = value

var opening_detail_generation: int:
	get: return _state.opening_detail_generation
	set(value): _state.opening_detail_generation = value

var opening_boot_material_restore_generation: int:
	get: return _state.opening_boot_material_restore_generation
	set(value): _state.opening_boot_material_restore_generation = value

var opening_boot_material_restore_queue: Array[Dictionary]:
	get: return _state.opening_boot_material_restore_queue
	set(value): _state.opening_boot_material_restore_queue = value

var opening_save_generation: int:
	get: return _state.opening_save_generation
	set(value): _state.opening_save_generation = value

var opening_checkpoint_pending: bool:
	get: return _state.opening_checkpoint_pending
	set(value): _state.opening_checkpoint_pending = value

var campaign_visual_prewarm_started: bool:
	get: return _state.campaign_visual_prewarm_started
	set(value): _state.campaign_visual_prewarm_started = value

var campaign_visual_prewarm_generation: int:
	get: return _state.campaign_visual_prewarm_generation
	set(value): _state.campaign_visual_prewarm_generation = value

var campaign_visual_prewarm_not_before_msec: int:
	get: return _state.campaign_visual_prewarm_not_before_msec
	set(value): _state.campaign_visual_prewarm_not_before_msec = value

var campaign_visual_prewarm_suspended: bool:
	get: return _state.campaign_visual_prewarm_suspended
	set(value): _state.campaign_visual_prewarm_suspended = value

var campaign_visual_prewarm_zone: String:
	get: return _state.campaign_visual_prewarm_zone
	set(value): _state.campaign_visual_prewarm_zone = value

var campaign_visual_prewarm_roles: Array[String]:
	get: return _state.campaign_visual_prewarm_roles
	set(value): _state.campaign_visual_prewarm_roles = value

var background_runtime_timer_pending: bool:
	get: return _state.background_runtime_timer_pending
	set(value): _state.background_runtime_timer_pending = value

var owned_timers: Array[Timer]:
	get: return _state.owned_timers
	set(value): _state.owned_timers = value

var interaction_focus_cooldown: float:
	get: return _state.interaction_focus_cooldown
	set(value): _state.interaction_focus_cooldown = value

var interaction_input_block_until_usec: int:
	get: return _state.interaction_input_block_until_usec
	set(value): _state.interaction_input_block_until_usec = value

var compass_refresh_cooldown: float:
	get: return _state.compass_refresh_cooldown
	set(value): _state.compass_refresh_cooldown = value

var navigation_dial_refresh_cooldown: float:
	get: return _state.navigation_dial_refresh_cooldown
	set(value): _state.navigation_dial_refresh_cooldown = value

var tutorial_refresh_cooldown: float:
	get: return _state.tutorial_refresh_cooldown
	set(value): _state.tutorial_refresh_cooldown = value

var target_status_refresh_cooldown: float:
	get: return _state.target_status_refresh_cooldown
	set(value): _state.target_status_refresh_cooldown = value

var interaction_focus_dirty: bool:
	get: return _construction_scope.interaction_focus_dirty if _construction_scope != null else _state.interaction_focus_dirty
	set(value):
		if _construction_scope == null: _state.interaction_focus_dirty = value
		else: _construction_scope.interaction_focus_dirty = value

var interaction_focus_cache_valid: bool:
	get: return _state.interaction_focus_cache_valid
	set(value): _state.interaction_focus_cache_valid = value

var last_focus_position: Vector3:
	get: return _state.last_focus_position
	set(value): _state.last_focus_position = value

var last_focus_forward: Vector3:
	get: return _state.last_focus_forward
	set(value): _state.last_focus_forward = value

var compass_dirty: bool:
	get: return _state.compass_dirty
	set(value): _state.compass_dirty = value

var compass_cache_valid: bool:
	get: return _state.compass_cache_valid
	set(value): _state.compass_cache_valid = value

var last_compass_position: Vector3:
	get: return _state.last_compass_position
	set(value): _state.last_compass_position = value

var last_compass_zone: String:
	get: return _state.last_compass_zone
	set(value): _state.last_compass_zone = value

var last_compass_signature: String:
	get: return _state.last_compass_signature
	set(value): _state.last_compass_signature = value

var encounter_spatial_index:
	get: return _construction_scope.encounter_spatial_index if _construction_scope != null else _state.encounter_spatial_index
	set(value):
		if _construction_scope == null: _state.encounter_spatial_index = value
		else: _construction_scope.encounter_spatial_index = value

var _hitstop_generation: int:
	get: return _state._hitstop_generation
	set(value): _state._hitstop_generation = value

var _hitstop_restore_scale: float:
	get: return _state._hitstop_restore_scale
	set(value): _state._hitstop_restore_scale = value

var _applied_setting_groups: Dictionary:
	get: return _state._applied_setting_groups
	set(value): _state._applied_setting_groups = value

func _gameplay_script(id: String) -> Script: return _systems["session"]._gameplay_script(id)
func _prepare_opening_after_menu_render() -> void: await _systems["session"]._prepare_opening_after_menu_render()
func _on_virtual_gameplay_action(request: Dictionary) -> void: _systems["session"]._on_virtual_gameplay_action(request)
func _dispatch_gameplay_action(action: String, target_instance_id: int = 0) -> void: _systems["session"]._dispatch_gameplay_action(action, target_instance_id)
func _invalidate_interaction_prompt() -> void: _systems["session"]._invalidate_interaction_prompt()
func _on_input_context_changed(_context: String) -> void: _systems["session"]._on_input_context_changed(_context)
func _on_transient_input_reset(reason: String) -> void: _systems["session"]._on_transient_input_reset(reason)
func _begin_gameplay_handoff(reason: String) -> void: _systems["session"]._begin_gameplay_handoff(reason)
func _finish_gameplay_handoff() -> void: _systems["session"]._finish_gameplay_handoff()
func _ensure_gameplay_runtime() -> void: _systems["session"]._ensure_gameplay_runtime()
func _new_game() -> void: _systems["session"]._new_game()
func _cancel_new_game_request() -> void: _systems["session"]._cancel_new_game_request()
func _handle_quit_request() -> void: _systems["session"]._handle_quit_request()
func request_seamless_boundary_transition(zone_id: String, spawn_pos: Vector3, edge_id: String = "") -> bool: return _systems["zone_lifecycle"].request_seamless_boundary_transition(zone_id, spawn_pos, edge_id)
func _zone_encounter_packs(zone_id: String, recorded_journey: Dictionary = {}) -> Array[String]: return _systems["zone_lifecycle"]._zone_encounter_packs(zone_id, recorded_journey)
func _load_zone_after_runtime_pack(zone_id: String, spawn_pos: Vector3) -> void: _systems["zone_lifecycle"]._load_zone_after_runtime_pack(zone_id, spawn_pos)
func _recover_failed_pack_load(reason: String = "The destination could not load. Please retry.") -> void: _systems["zone_lifecycle"]._recover_failed_pack_load(reason)
func _zone_requires_campaign_pack(zone_id: String) -> bool: return _systems["zone_lifecycle"]._zone_requires_campaign_pack(zone_id)
func _zone_requires_opening_pack(zone_id: String) -> bool: return _systems["zone_lifecycle"]._zone_requires_opening_pack(zone_id)
func should_defer_neighbor_prewarm() -> bool: return _systems["zone_lifecycle"].should_defer_neighbor_prewarm()
func _schedule_background_runtime_packs(delay_seconds: float = BACKGROUND_RUNTIME_DELAY_SECONDS) -> void: await _systems["zone_lifecycle"]._schedule_background_runtime_packs(delay_seconds)
func _schedule_opening_save(generation: int) -> void: await _systems["zone_lifecycle"]._schedule_opening_save(generation)
func load_save_state(data: Dictionary) -> void: _systems["save"].load_save_state(data)
func _journey_load_pending() -> bool: return _systems["save"]._journey_load_pending()
func _on_prepared_journey_load(prepared: Dictionary) -> void: _systems["save"]._on_prepared_journey_load(prepared)
func _cancel_journey_load() -> void: _systems["save"]._cancel_journey_load()
func _publish_journey_arrival() -> void: _systems["save"]._publish_journey_arrival()
func _queue_journey_models_refresh() -> void: _systems["save"]._queue_journey_models_refresh()
func _refresh_journey_models() -> void: _systems["save"]._refresh_journey_models()
func _request_journey_load(selection: Dictionary) -> void: _systems["save"]._request_journey_load(selection)
func _open_journal_section(section_id: String) -> void: _systems["save"]._open_journal_section(section_id)
func _sync_camera_enemy_cache() -> void: _systems["zone_lifecycle"]._sync_camera_enemy_cache()
func _load_zone(zone_id: String, spawn_pos: Vector3 = Vector3.ZERO) -> void: await _systems["zone_lifecycle"]._load_zone(zone_id, spawn_pos)
func _finish_deferred_zone_audio(zone_id: String, root: Node3D, generation: int, music_request: int) -> void: await _systems["zone_lifecycle"]._finish_deferred_zone_audio(zone_id, root, generation, music_request)
func _cancel_campaign_visual_prewarm() -> void: _systems["startup"]._cancel_campaign_visual_prewarm()
func should_defer_visual_role(role: String, category: String) -> bool: return _systems["startup"].should_defer_visual_role(role, category)
func should_defer_character_role(_role: String, _actor_id: String) -> bool: return _systems["startup"].should_defer_character_role(_role, _actor_id)
func _run_deferred_visual_roles(root: Node3D) -> void: await _systems["startup"]._run_deferred_visual_roles(root)
func _run_campaign_visual_prewarm(generation: int, role_index: int) -> void: await _systems["startup"]._run_campaign_visual_prewarm(generation, role_index)
func _finish_zone_runtime_finalize(zone_id: String, root: Node3D, service: Node, enemies: Array, navigation_pending: bool) -> void: _systems["zone_lifecycle"]._finish_zone_runtime_finalize(zone_id, root, service, enemies, navigation_pending)
func _grounded_spawn_position(candidate: Vector3) -> Variant: return _systems["zone_lifecycle"]._grounded_spawn_position(candidate)
func _zone_display_name(zone_id: String) -> String: return _systems["zone_lifecycle"]._zone_display_name(zone_id)
func _valid_cached_enemies(entries: Array) -> Array: return _systems["zone_lifecycle"]._valid_cached_enemies(entries)
func _zone_state_signature(zone_id: String = current_zone_id) -> int: return _systems["zone_lifecycle"]._zone_state_signature(zone_id)
func _begin_zone_world_reads(zone_id: String, reset: bool = true) -> void: _systems["zone_lifecycle"]._begin_zone_world_reads(zone_id, reset)
func _end_zone_world_reads() -> void: _systems["zone_lifecycle"]._end_zone_world_reads()
func _deferred_free_zone(retired_root: Node) -> void: _systems["zone_lifecycle"]._deferred_free_zone(retired_root)
func _release_zone_render_resources(root: Node) -> void: _systems["zone_lifecycle"]._release_zone_render_resources(root)
func _retire_zone_root(retired_root: Node) -> void: _systems["zone_lifecycle"]._retire_zone_root(retired_root)
func _bind_retirement_material(root: Node) -> void: _systems["zone_lifecycle"]._bind_retirement_material(root)
func _anchor_retired_materials(root: Node) -> void: _systems["zone_lifecycle"]._anchor_retired_materials(root)
func _keep_retired_material(material: Material) -> void: _systems["zone_lifecycle"]._keep_retired_material(material)
func _anchor_shared_skinned_resources(root: Node) -> void: _systems["zone_lifecycle"]._anchor_shared_skinned_resources(root)
func _skinned_resource_fingerprint(branch: Node) -> String: return _systems["zone_lifecycle"]._skinned_resource_fingerprint(branch)
func _create_owned_timer(seconds: float, ignore_time_scale: bool = false) -> Timer: return _systems["zone_lifecycle"]._create_owned_timer(seconds, ignore_time_scale)
func _cancel_owned_timers() -> void: _systems["zone_lifecycle"]._cancel_owned_timers()
func _quiesce_zone_runtime(root: Node) -> void: _systems["zone_lifecycle"]._quiesce_zone_runtime(root)
func _cache_route_zone(zone_id: String, root: Node3D, enemies: Array, signature: int, keep_visible: bool = false, disable_collision: bool = true, disable_process: bool = true) -> void: _systems["zone_lifecycle"]._cache_route_zone(zone_id, root, enemies, signature, keep_visible, disable_collision, disable_process)
func _cache_route_spatial_service(zone_id: String, service: Node) -> void: _systems["zone_lifecycle"]._cache_route_spatial_service(zone_id, service)
func _release_route_spatial_service(zone_id: String) -> void: _systems["zone_lifecycle"]._release_route_spatial_service(zone_id)
func _release_active_spatial_service() -> void: _systems["zone_lifecycle"]._release_active_spatial_service()
func _activate_cached_zone(zone_id: String) -> Node3D: return _systems["zone_lifecycle"]._activate_cached_zone(zone_id)
func _remove_root_from_route_cache(root: Node) -> void: _systems["zone_lifecycle"]._remove_root_from_route_cache(root)
func _trim_route_zone_cache(preferred_ids: Array) -> void: _systems["zone_lifecycle"]._trim_route_zone_cache(preferred_ids)
func _set_zone_collision_enabled(node: Node, enabled: bool) -> void: _systems["zone_lifecycle"]._set_zone_collision_enabled(node, enabled)
func _collect_zone_collision_targets(root: Node) -> Array: return _systems["zone_lifecycle"]._collect_zone_collision_targets(root)
func _set_single_zone_collision_enabled(node: Node, enabled: bool) -> void: _systems["zone_lifecycle"]._set_single_zone_collision_enabled(node, enabled)
func _clear_route_zone_cache(preserve_root: Node3D = null) -> void: _systems["zone_lifecycle"]._clear_route_zone_cache(preserve_root)
func prepare_resource_shutdown() -> void: _systems["zone_lifecycle"].prepare_resource_shutdown()
func finalize_resource_shutdown() -> void: _systems["zone_lifecycle"].finalize_resource_shutdown()
func zone_lifecycle_snapshot() -> Dictionary: return _systems["zone_lifecycle"].zone_lifecycle_snapshot()
func _add_visual_100_layer(zone_id: String) -> void: _systems["world"]._add_visual_100_layer(zone_id)
func _install_world_prop_controller(zone_id: String) -> void: _systems["world"]._install_world_prop_controller(zone_id)
func _install_opening_soundscape(zone_id: String) -> void: _systems["world"]._install_opening_soundscape(zone_id)
func _handle_interaction(area) -> void: _systems["interaction"]._handle_interaction(area)
func _on_minigame_result(game_id: String, outcome: String) -> void: _systems["interaction"]._on_minigame_result(game_id, outcome)
func _on_minigame_state_changed() -> void: _systems["interaction"]._on_minigame_state_changed()
func _make_all_evidence_safe_edge() -> void: _systems["quest"]._make_all_evidence_safe_edge()
func _legacy_report_choice_required() -> bool: return _systems["quest"]._legacy_report_choice_required()
func _crow_shrine_choice_ready() -> bool: return _systems["quest"]._crow_shrine_choice_ready()
func _spawn_crow_shrine_choice() -> void: _systems["quest"]._spawn_crow_shrine_choice()
func _relocate_anwen_to_cemetery() -> void: _systems["quest"]._relocate_anwen_to_cemetery()
func _handle_dialogue_action(action: Dictionary) -> void: _systems["dialogue"]._handle_dialogue_action(action)
func _finish_story_action(action: Dictionary) -> void: _systems["dialogue"]._finish_story_action(action)
func _persist_story_action() -> void: _systems["dialogue"]._persist_story_action()
func _story_has_active_combat() -> bool: return _systems["dialogue"]._story_has_active_combat()
func _dialogue_action_available(action: Dictionary) -> bool: return _systems["dialogue"]._dialogue_action_available(action)
func _on_launch_accepted() -> void: _systems["startup"]._on_launch_accepted()
func _on_opening_pack_progress(_pack_id: String, _progress: float) -> void: _systems["startup"]._on_opening_pack_progress(_pack_id, _progress)
func _on_startup_pack_ready(_pack_id: String) -> void: _systems["startup"]._on_startup_pack_ready(_pack_id)
func _begin_opening_prewarm_if_ready(generation: int) -> void: _systems["startup"]._begin_opening_prewarm_if_ready(generation)
func _wait_for_startup_packs_then_prewarm(generation: int) -> void: await _systems["startup"]._wait_for_startup_packs_then_prewarm(generation)
func _begin_opening_prewarm() -> void: _systems["startup"]._begin_opening_prewarm()
func _prepare_opening_services(generation: int) -> void: await _systems["startup"]._prepare_opening_services(generation)
func _wait_for_opening_build_slot(generation: int) -> void: await _systems["startup"]._wait_for_opening_build_slot(generation)
func _opening_attempt_current(generation: int) -> bool: return _systems["startup"]._opening_attempt_current(generation)
func _prepare_opening_resources(generation: int) -> void: await _systems["startup"]._prepare_opening_resources(generation)
func _discard_menu_opening() -> void: _systems["startup"]._discard_menu_opening()
func _opening_prepare_failed(message: String) -> void: _systems["startup"]._opening_prepare_failed(message)
func _abort_opening_prewarm(prewarm_root: Node3D, prewarm_service: Node, message: String, notify_failure: bool = true) -> void: _systems["startup"]._abort_opening_prewarm(prewarm_root, prewarm_service, message, notify_failure)
func _publish_web_opening_state(state: String, message: String = "", progress: float = -1.0) -> void: _systems["startup"]._publish_web_opening_state(state, message, progress)
func _restore_opening_boot_materials(generation: int) -> void: await _systems["startup"]._restore_opening_boot_materials(generation)
func _run_opening_detail_stage(generation: int) -> void: await _systems["startup"]._run_opening_detail_stage(generation)
func _show_completed_epilogue() -> void: _systems["quest"]._show_completed_epilogue()
func _on_player_blade_contact(contact: Dictionary) -> void: _systems["combat"]._on_player_blade_contact(contact)
func _on_player_arrow_unavailable() -> void: _systems["combat"]._on_player_arrow_unavailable()
func _on_player_arrow(request: Dictionary) -> void: _systems["combat"]._on_player_arrow(request)
func _on_arrow_impact(result: Dictionary, arrow_id: String, damage: float, zone_instance: int) -> void: _systems["combat"]._on_arrow_impact(result, arrow_id, damage, zone_instance)
func _present_surface_contact(result: Dictionary, arrow: bool) -> void: _systems["combat"]._present_surface_contact(result, arrow)
func _civilian_contact_candidates(position: Vector3, radius: float) -> Array: return _systems["combat"]._civilian_contact_candidates(position, radius)
func _make_arrow_trail(origin: Vector3, endpoint: Vector3, color: Color) -> void: _systems["combat"]._make_arrow_trail(origin, endpoint, color)
func _on_player_beam_phase(phase: String) -> void: _systems["combat"]._on_player_beam_phase(phase)
func _on_player_beam(charge_ratio: float, direction: Vector3) -> void: _systems["combat"]._on_player_beam(charge_ratio, direction)
func _make_oathfire_beam(origin: Vector3, endpoint: Vector3, charge_ratio: float, rich_effect: bool) -> void: _systems["combat"]._make_oathfire_beam(origin, endpoint, charge_ratio, rich_effect)
func _clear_oathfire_effects() -> void: _systems["combat"]._clear_oathfire_effects()
func _on_player_footstep() -> void: _systems["combat"]._on_player_footstep()
func _on_player_parried() -> void: _systems["combat"]._on_player_parried()
func _on_player_blocked(_amount: float) -> void: _systems["combat"]._on_player_blocked(_amount)
func _on_player_hurt(_amount: float) -> void: _systems["combat"]._on_player_hurt(_amount)
func _on_player_stamina_exhausted(_action: String) -> void: _systems["combat"]._on_player_stamina_exhausted(_action)
func _use_potion() -> void: _systems["inventory"]._use_potion()
func _throw_bomb() -> void: _systems["inventory"]._throw_bomb()
func _preparation_item_result(item_id: String, ok: bool, message: String, operation: String = "use", consumed: int = 0) -> Dictionary: return _systems["inventory"]._preparation_item_result(item_id, ok, message, operation, consumed)
func _update_preparation_context() -> void: _systems["inventory"]._update_preparation_context()
func _show_preparation_menu() -> void: _systems["inventory"]._show_preparation_menu()
func _craft_preparation_item(item_id: String) -> void: _systems["inventory"]._craft_preparation_item(item_id)
func _use_preparation_item(item_id: String) -> void: _systems["inventory"]._use_preparation_item(item_id)
func _set_inventory_preference(key: String, value: String) -> void: _systems["inventory"]._set_inventory_preference(key, value)
func _learn_preparation_practice(upgrade_id: String) -> void: _systems["inventory"]._learn_preparation_practice(upgrade_id)
func _redistribute_practices() -> void: _systems["inventory"]._redistribute_practices()
func _finish_preparation_operation(result: Dictionary, vendor_id: String = "") -> void: _systems["inventory"]._finish_preparation_operation(result, vendor_id)
func _refresh_preparation_after_operation(result: Dictionary, vendor_id: String, screen_key: String) -> void: _systems["inventory"]._refresh_preparation_after_operation(result, vendor_id, screen_key)
func _purchase_from_vendor(vendor_id: String, item_id: String, quantity: int = 1) -> void: _systems["inventory"]._purchase_from_vendor(vendor_id, item_id, quantity)
func _sell_to_vendor(vendor_id: String, item_id: String, quantity: int) -> void: _systems["inventory"]._sell_to_vendor(vendor_id, item_id, quantity)
func _on_enemy_died(enemy) -> void: _systems["combat"]._on_enemy_died(enemy)
func _try_complete_black_dog_investigation() -> void: _systems["combat"]._try_complete_black_dog_investigation()
func accept_ordinary_surrender(enemy: Node) -> void: _systems["combat"].accept_ordinary_surrender(enemy)
func _try_complete_oren_thread_trace(publish_return := true) -> void: _systems["combat"]._try_complete_oren_thread_trace(publish_return)
func _record_encounter_knowledge(enemy) -> void: _systems["combat"]._record_encounter_knowledge(enemy)
func _on_enemy_damaged(enemy, current: float, maximum: float) -> void: _systems["combat"]._on_enemy_damaged(enemy, current, maximum)
func _on_enemy_windup_started(enemy) -> void: _systems["combat"]._on_enemy_windup_started(enemy)
func _on_enemy_attack_resolved(enemy, parried: bool, contact_position: Vector3) -> void: _systems["combat"]._on_enemy_attack_resolved(enemy, parried, contact_position)
func _on_enemy_parry_window_opened(enemy: Node, duration: float) -> void: _systems["combat"]._on_enemy_parry_window_opened(enemy, duration)
func _on_quest_completed(id: String) -> void: _systems["quest"]._on_quest_completed(id)
func _apply_progression_to_player() -> void: _systems["quest"]._apply_progression_to_player()
func _on_progression_changed() -> void: _systems["quest"]._on_progression_changed()
func _queue_progression_rewards() -> void: _systems["quest"]._queue_progression_rewards()
func _flush_progression_rewards() -> void: _systems["quest"]._flush_progression_rewards()
func _collect_progression_rewards() -> bool: return _systems["quest"]._collect_progression_rewards()
func _record_bog_stagger(enemy, source: String) -> void: _systems["combat"]._record_bog_stagger(enemy, source)
func _expose_bog_core(enemy, method: String) -> void: _systems["combat"]._expose_bog_core(enemy, method)
func _on_target_lock_changed(target_actor: Node3D, locked: bool) -> void: _systems["combat"]._on_target_lock_changed(target_actor, locked)
func _update_target_lock_hud() -> void: _systems["combat"]._update_target_lock_hud()
func _on_combat_impact(pos: Vector3, heavy: bool) -> void: _systems["combat"]._on_combat_impact(pos, heavy)
func _hitstop(seconds: float) -> void: _systems["combat"]._hitstop(seconds)
func _has_living_enemy(enemy_id: String) -> bool: return _systems["combat"]._has_living_enemy(enemy_id)
func _nearest_living_enemy(max_distance: float): return _systems["combat"]._nearest_living_enemy(max_distance)
func _remove_interactable(id: String) -> void: _systems["interaction"]._remove_interactable(id)
func _consume_story_choice_interactable(id: String) -> void: _systems["interaction"]._consume_story_choice_interactable(id)
func _has_interactable(id: String) -> bool: return _systems["interaction"]._has_interactable(id)
func _mark_interaction_removed(area) -> void: _systems["interaction"]._mark_interaction_removed(area)
func _is_interaction_removed(id: String) -> bool: return _systems["interaction"]._is_interaction_removed(id)
func save_world_state() -> Dictionary: return _systems["save"].save_world_state()
func load_world_state(state: Dictionary) -> void: _systems["save"].load_world_state(state)
func _on_player_died() -> void: _systems["combat"]._on_player_died()
func _on_dialogue_closed_audio() -> void: _systems["dialogue"]._on_dialogue_closed_audio()
func _finish_covenant_if_ready() -> void: _systems["dialogue"]._finish_covenant_if_ready()
func _on_touch_layout_unavailable(reason: String) -> void: _systems["hud"]._on_touch_layout_unavailable(reason)
func _pause_game() -> void: _systems["hud"]._pause_game()
func _show_companion_commands() -> void: _systems["hud"]._show_companion_commands()
func _on_touch_quick_action(action: String) -> void: _systems["hud"]._on_touch_quick_action(action)
func _resume_game() -> void: _systems["hud"]._resume_game()
func _handle_setting(action: String) -> void: _systems["hud"]._handle_setting(action)
func _apply_runtime_settings(current_settings: Dictionary) -> void: _systems["hud"]._apply_runtime_settings(current_settings)
func _queue_story_guidance_refresh() -> void: _systems["hud"]._queue_story_guidance_refresh()
func _apply_story_guidance_refresh() -> void: _systems["hud"]._apply_story_guidance_refresh()
func _refresh_tracker() -> void: _systems["hud"]._refresh_tracker()
func _show_current_objective_guidance(seconds: float = 5.0) -> void: _systems["hud"]._show_current_objective_guidance(seconds)
func _refresh_equipment_readout() -> void: _systems["hud"]._refresh_equipment_readout()
func _reconcile_preparation_objective() -> void: _systems["hud"]._reconcile_preparation_objective()
func _tracked_objective_id(quest_id: String) -> String: return _systems["hud"]._tracked_objective_id(quest_id)
func validate_walkable_position(pos: Vector3) -> Vector3: return _systems["zone_lifecycle"].validate_walkable_position(pos)
func _recover_from_river(body: Node, river_z: float, span: float) -> void: _systems["zone_lifecycle"]._recover_from_river(body, river_z, span)
func _river_center(zone: String = current_zone_id) -> float: return _systems["zone_lifecycle"]._river_center(zone)
func _is_river_excluded(pos: Vector3, margin: float = 0.0) -> bool: return _systems["zone_lifecycle"]._is_river_excluded(pos, margin)
func river_safe_position(pos: Vector3, margin: float = 0.55) -> Vector3: return _systems["zone_lifecycle"].river_safe_position(pos, margin)
func river_safe_path(points: Array, margin: float = 0.90) -> Array: return _systems["zone_lifecycle"].river_safe_path(points, margin)
func get_zone_half_extents(zone_id: String) -> Vector2: return _systems["zone_lifecycle"].get_zone_half_extents(zone_id)
func _zone_half_extents(zone_id: String) -> Vector2: return _systems["zone_lifecycle"]._zone_half_extents(zone_id)
func _make_play_area_bounds(width: float, depth: float, color: Color) -> void: _systems["world"]._make_play_area_bounds(width, depth, color)
func _make_boundary_edge(edge_id: String, width: float, depth: float, color: Color) -> void: _systems["world"]._make_boundary_edge(edge_id, width, depth, color)
func _make_invisible_wall(pos: Vector3, size: Vector3) -> void: _systems["world"]._make_invisible_wall(pos, size)
func _make_greyfen_terrain_layers() -> void: _systems["world"]._make_greyfen_terrain_layers()
func _finish_greyfen_ground_surfaces() -> void: _systems["world"]._finish_greyfen_ground_surfaces()
func _finish_greyfen_paved_roads() -> void: _systems["world"]._finish_greyfen_paved_roads()
func _make_wychwood_terrain_layers() -> void: _systems["world"]._make_wychwood_terrain_layers()
func _make_greyfen_path_edges() -> void: _systems["world"]._make_greyfen_path_edges()
func _make_wychwood_path_edges() -> void: _systems["world"]._make_wychwood_path_edges()
func _make_terrain_patch(name: String, pos: Vector3, size: Vector3, color: Color) -> void: _systems["world"]._make_terrain_patch(name, pos, size, color)
func _make_terrain_patch_raw(name: String, pos: Vector3, size: Vector3, color: Color) -> void: _systems["world"]._make_terrain_patch_raw(name, pos, size, color)
func _make_path_stone(pos: Vector3, scale_value: float) -> void: _systems["world"]._make_path_stone(pos, scale_value)
func _make_low_berm(pos: Vector3, size: Vector3, color: Color) -> void: _systems["world"]._make_low_berm(pos, size, color)
func _make_grass_tufts(points: Array, color: Color) -> void: _systems["world"]._make_grass_tufts(points, color)
func _make_spawn_composition() -> void: _systems["world"]._make_spawn_composition()
func _make_greyfen_first_impression_dressing(stage: String = "") -> void: _systems["world"]._make_greyfen_first_impression_dressing(stage)
func _make_quality_greyfen_overhaul() -> void: _systems["world"]._make_quality_greyfen_overhaul()
func _make_quality_survival_cluster(pos: Vector3) -> void: _systems["world"]._make_quality_survival_cluster(pos)
func _make_road_ruts() -> void: _systems["world"]._make_road_ruts()
func _make_lantern_rhythm() -> void: _systems["world"]._make_lantern_rhythm()
func _make_shrine_approach() -> void: _systems["world"]._make_shrine_approach()
func _make_village_story_clusters() -> void: _systems["world"]._make_village_story_clusters()
func _make_lantern_post(pos: Vector3, shrine_style: bool, casts_light: bool) -> void: _systems["world"]._make_lantern_post(pos, shrine_style, casts_light)
func _make_fake_light_pool(name: String, pos: Vector3, size: Vector3, color: Color) -> void: _systems["world"]._make_fake_light_pool(name, pos, size, color)
func _make_firewood_stack(pos: Vector3, yaw: float) -> void: _systems["world"]._make_firewood_stack(pos, yaw)
func _make_broken_fence_run(pos: Vector3, vertical: bool) -> void: _systems["world"]._make_broken_fence_run(pos, vertical)
func _make_wheelbarrow(pos: Vector3, yaw: float) -> void: _systems["world"]._make_wheelbarrow(pos, yaw)
func _make_mourning_marker(pos: Vector3) -> void: _systems["world"]._make_mourning_marker(pos)
func _make_shrine_candle(pos: Vector3) -> void: _systems["world"]._make_shrine_candle(pos)
func _make_hanging_cloth(pos: Vector3, size: Vector3, color: Color) -> void: _systems["world"]._make_hanging_cloth(pos, size, color)
func _make_fake_fog_bank(pos: Vector3) -> void: _systems["world"]._make_fake_fog_bank(pos)
func _make_crow_silhouettes() -> void: _systems["world"]._make_crow_silhouettes()
func _add_crow_part(parent: Node3D, name: String, mesh: Mesh, local_pos: Vector3, scale_value: Vector3, color: Color, rotation_degrees := Vector3.ZERO) -> MeshInstance3D: return _systems["world"]._add_crow_part(parent, name, mesh, local_pos, scale_value, color, rotation_degrees)
func _make_visual_box(name: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D: return _systems["world"]._make_visual_box(name, pos, size, color)
func _append_prepared_detail(id: String) -> void: _systems["world"]._append_prepared_detail(id)
func _make_prepared_prop(id: String) -> void: _systems["world"]._make_prepared_prop(id)
func _add_visual_box_child(parent: Node3D, name: String, local_pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D: return _systems["world"]._add_visual_box_child(parent, name, local_pos, size, color)
func _make_greyfen_road_of_crows_story_beats() -> void: _systems["world"]._make_greyfen_road_of_crows_story_beats()
func _make_wychwood_road_of_crows_story_beats() -> void: _systems["world"]._make_wychwood_road_of_crows_story_beats()
func _make_post_ghoulkin_story_clue() -> void: _systems["world"]._make_post_ghoulkin_story_clue()
func _make_narrative_aftermath(zone_id: String) -> void: _systems["world"]._make_narrative_aftermath(zone_id)
func _make_black_feather_scatter(base_name: String, center: Vector3, count: int, spread: float) -> void: _systems["world"]._make_black_feather_scatter(base_name, center, count, spread)
func _make_broken_charm(name: String, pos: Vector3, yaw: float) -> void: _systems["world"]._make_broken_charm(name, pos, yaw)
func _make_dark_track(name: String, pos: Vector3, size: Vector3, color: Color) -> void: _systems["world"]._make_dark_track(name, pos, size, color)
func _make_claw_marks(name: String, pos: Vector3, vertical: bool) -> void: _systems["world"]._make_claw_marks(name, pos, vertical)
func _make_wychwood_corridor() -> void: _systems["world"]._make_wychwood_corridor()
func _make_village_house_dressed(pos: Vector3, yaw: float, node_name: String) -> void: _systems["world"]._make_village_house_dressed(pos, yaw, node_name)
func _make_house_facade_module(role_name: String, scale_value: Vector3) -> MeshInstance3D: return _systems["world"]._make_house_facade_module(role_name, scale_value)
func _append_house_quad(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void: _systems["world"]._append_house_quad(vertices, normals, uvs, indices, a, b, c, d)
func _add_house_box(parent: Node3D, node_name: String, local_pos: Vector3, size: Vector3, color: Color, local_rot: Vector3 = Vector3.ZERO) -> Node3D: return _systems["world"]._add_house_box(parent, node_name, local_pos, size, color, local_rot)
func _make_house_collision(parent: Node3D) -> void: _systems["world"]._make_house_collision(parent)
func _make_village_dressing() -> void: _systems["world"]._make_village_dressing()
func _make_wychwood_gate_scene(pos: Vector3) -> void: _systems["world"]._make_wychwood_gate_scene(pos)
func _make_wychwood_route_dressing() -> void: _systems["world"]._make_wychwood_route_dressing()
func _make_quality_wychwood_overhaul() -> void: _systems["world"]._make_quality_wychwood_overhaul()
func _make_loose_role(role_name: String, pos: Vector3, scale_value: Vector3, yaw: float) -> Node3D: return _systems["world"]._make_loose_role(role_name, pos, scale_value, yaw)
func _make_roof(pos: Vector3, size: Vector3, color: Color) -> void: _systems["world"]._make_roof(pos, size, color)
func _make_notice_board(pos: Vector3) -> void: _systems["world"]._make_notice_board(pos)
func _make_route_markers() -> void: _systems["world"]._make_route_markers()
func _make_shrine_scene(pos: Vector3) -> void: _systems["world"]._make_shrine_scene(pos)
func _make_blacksmith_scene(pos: Vector3) -> void: _systems["world"]._make_blacksmith_scene(pos)
func _make_tree_cluster(points: Array) -> void: _systems["world"]._make_tree_cluster(points)
func _make_monster_clearing(pos: Vector3) -> void: _systems["world"]._make_monster_clearing(pos)
func _make_named_interactable(id: String, type: String, prompt: String, pos: Vector3, color: Color, scale_override: Vector3 = Vector3.ONE): return _systems["world"]._make_named_interactable(id, type, prompt, pos, color, scale_override)
func _make_ledger_interaction_visual(area: Node3D, scale_override: Vector3) -> void: _systems["world"]._make_ledger_interaction_visual(area, scale_override)
func _make_token_interaction_visual(area: Node3D, scale_override: Vector3) -> void: _systems["world"]._make_token_interaction_visual(area, scale_override)
func _make_village_place(id: String, type: String, prompt: String, pos: Vector3, size: Vector3, color: Color): return _systems["world"]._make_village_place(id, type, prompt, pos, size, color)
func _apply_greyfen_well_visual(visual: MeshInstance3D, pos: Vector3) -> void: _systems["world"]._apply_greyfen_well_visual(visual, pos)
func _make_board_game_staging(area: Node3D, id: String, size: Vector3) -> void: _systems["world"]._make_board_game_staging(area, id, size)
func _make_board_game_chair(area: Node3D, position: Vector3, yaw: float, batch: MultiMeshInstance3D, first_index: int) -> void: _systems["world"]._make_board_game_chair(area, position, yaw, batch, first_index)
func _world_prop_spec(id: String) -> Dictionary: return _systems["world"]._world_prop_spec(id)
func _configure_npc_animation(mapped: Node3D, id: String) -> bool: return _systems["world"]._configure_npc_animation(mapped, id)
func _prepare_dialogue_presence(content: Dictionary) -> Dictionary: return _systems["dialogue"]._prepare_dialogue_presence(content)
func _stage_dialogue_moment(area) -> void: _systems["dialogue"]._stage_dialogue_moment(area)
func _on_dialogue_page_changed(_speaker: String, _speaker_id: String, _page_index: int, _total_pages: int) -> void: _systems["dialogue"]._on_dialogue_page_changed(_speaker, _speaker_id, _page_index, _total_pages)
func _on_dialogue_topic_requested(context_id: String, topic_id: String, revision_key: String) -> void: _systems["dialogue"]._on_dialogue_topic_requested(context_id, topic_id, revision_key)
func _release_dialogue_facing() -> void: _systems["dialogue"]._release_dialogue_facing()
func _make_gate_marker(parent: Node3D, color: Color, scale_override: Vector3) -> void: _systems["world"]._make_gate_marker(parent, color, scale_override)
func _label_for_interactable(id: String, prompt: String) -> String: return _systems["world"]._label_for_interactable(id, prompt)
func _make_clue(id: String, prompt: String, pos: Vector3, quest_id: String, objective_id: String, color: Color): return _systems["world"]._make_clue(id, prompt, pos, quest_id, objective_id, color)
func _present_castle_clue(id: String, title: String) -> void: _systems["world"]._present_castle_clue(id, title)
func _make_herb(id: String, pos: Vector3, color: Color): return _systems["world"]._make_herb(id, pos, color)
func _make_zone_gate(prompt: String, pos: Vector3, zone_target: String, spawn_pos: Vector3): return _systems["world"]._make_zone_gate(prompt, pos, zone_target, spawn_pos)
func _add_physical_door_visual(area: Node3D, zone_target: String) -> void: _systems["world"]._add_physical_door_visual(area, zone_target)
func _connect_interactable(area, owner_root: Node3D = null, owner_cache: Array = []) -> void: _systems["interaction"]._connect_interactable(area, owner_root, owner_cache)
func _remove_interaction_candidate(area) -> void: _systems["interaction"]._remove_interaction_candidate(area)
func _interaction_target_valid(area: Area3D) -> bool: return _systems["interaction"]._interaction_target_valid(area)
func _set_interactable_label_visible(area: Node, visible: bool) -> void: _systems["interaction"]._set_interactable_label_visible(area, visible)
func _spawn_enemy(id: String, pos: Vector3, visual_role: String = "") -> Node: return _systems["combat"]._spawn_enemy(id, pos, visual_role)
func _boss_is_resolved(id: String) -> bool: return _systems["combat"]._boss_is_resolved(id)
func _ensure_bell_eater() -> void: _systems["combat"]._ensure_bell_eater()
func _retire_bell_eater() -> void: _systems["combat"]._retire_bell_eater()
func _open_rootbound_encounter() -> void: _systems["combat"]._open_rootbound_encounter()
func _evacuate_bell_eater_bystanders() -> void: _systems["combat"]._evacuate_bell_eater_bystanders()
func _restore_bell_eater_bystanders() -> void: _systems["combat"]._restore_bell_eater_bystanders()
func _on_boss_controller_phase_changed(boss_id: String, phase: int) -> void: _systems["combat"]._on_boss_controller_phase_changed(boss_id, phase)
func _on_boss_checkpoint(controller: Node) -> void: _systems["combat"]._on_boss_checkpoint(controller)
func _on_boss_resolved(boss_id: String, outcome: String) -> void: _systems["combat"]._on_boss_resolved(boss_id, outcome)
func _apply_boss_resolution_contract(boss_id: String) -> void: _systems["combat"]._apply_boss_resolution_contract(boss_id)
func _publish_halvern_exit() -> void: _systems["combat"]._publish_halvern_exit()
func _on_boss_peaceful_resolution(boss_id: String, outcome: String, enemy: Node) -> void: _systems["combat"]._on_boss_peaceful_resolution(boss_id, outcome, enemy)
func _on_boss_phase_changed(enemy: Node, phase: int) -> void: _systems["combat"]._on_boss_phase_changed(enemy, phase)
func _on_boss_special_attack(enemy: Node, attack_id: String, contact_position: Vector3, radius: float, damage: float, parried: bool) -> void: _systems["combat"]._on_boss_special_attack(enemy, attack_id, contact_position, radius, damage, parried)
func _activate_wychwood_wave(ids: Array, cue: String) -> void: _systems["combat"]._activate_wychwood_wave(ids, cue)
func _ensure_wychwood_wave() -> void: _systems["combat"]._ensure_wychwood_wave()
func checkpoint_return_position() -> Vector3: return _systems["combat"].checkpoint_return_position()
func _has_active_encounter_enemy() -> bool: return _systems["combat"]._has_active_encounter_enemy()
func _enemy_attack_token(enemy: Node, claim: bool) -> bool: return _systems["combat"]._enemy_attack_token(enemy, claim)
func _make_ground(pos: Vector3, size: Vector3, color: Color, collision_enabled: bool = true) -> void: _systems["world"]._make_ground(pos, size, color, collision_enabled)
func _make_split_ground(width: float, depth: float, river_z: float, river_span: float, color: Color, bridge_width: float = 0.0, bridge_length: float = 0.0, bridge_approach_length: float = 0.0) -> void: _systems["world"]._make_split_ground(width, depth, river_z, river_span, color, bridge_width, bridge_length, bridge_approach_length)
func _make_bridge_corridor_collision(bridge_width: float, river_z: float, bridge_length: float, approach_length: float, zone_depth: float) -> void: _systems["world"]._make_bridge_corridor_collision(bridge_width, river_z, bridge_length, approach_length, zone_depth)
func _scene_randf() -> float: return _systems["world"]._scene_randf()
func _scene_randf_range(from: float, to: float) -> float: return _systems["world"]._scene_randf_range(from, to)
func _make_tree(pos: Vector3) -> void: _systems["world"]._make_tree(pos)
func _make_tree_wall(axis_extent: float, fixed_pos: float, count: int, along_x: bool) -> void: _systems["world"]._make_tree_wall(axis_extent, fixed_pos, count, along_x)
func _make_deadfall(pos: Vector3) -> void: _systems["world"]._make_deadfall(pos)
func _clear_environment_batch_buffers() -> void: _systems["world"]._clear_environment_batch_buffers()
func _upload_static_batch(instance: MultiMeshInstance3D, transforms: Array, colors: Array = []) -> void: _systems["world"]._upload_static_batch(instance, transforms, colors)
func _flush_environment_batches() -> void: _systems["world"]._flush_environment_batches()
func _flush_authored_tree_assets() -> bool: return _systems["world"]._flush_authored_tree_assets()
func _make_multimesh_batch(node_name: String, mesh: Mesh, count: int, material: Material, use_colors: bool = false) -> MultiMeshInstance3D: return _systems["world"]._make_multimesh_batch(node_name, mesh, count, material, use_colors)
func _valid_material_or_fallback(material: Material) -> Material: return _systems["world"]._valid_material_or_fallback(material)
func _ensure_mesh_surface_materials(mesh: Mesh, fallback: Material) -> int: return _systems["world"]._ensure_mesh_surface_materials(mesh, fallback)
func _validate_zone_render_resources(root: Node, descendants: bool = true) -> Dictionary: return _systems["world"]._validate_zone_render_resources(root, descendants)
func _make_road(pos: Vector3, size: Vector3, color: Color) -> void: _systems["world"]._make_road(pos, size, color)
func _make_world_wheel(id: String, pos: Vector3, radius: float, depth: float, color: Color, rotation_degrees: Vector3 = Vector3.ZERO) -> void: _systems["world"]._make_world_wheel(id, pos, radius, depth, color, rotation_degrees)
func _make_water_patch(id: String, pos: Vector3, size: Vector3, color: Color) -> void: _systems["world"]._make_water_patch(id, pos, size, color)
func _make_fence(pos: Vector3, vertical: bool) -> void: _systems["world"]._make_fence(pos, vertical)
func _make_gravestone(pos: Vector3) -> void: _systems["world"]._make_gravestone(pos)
func _make_cart(pos: Vector3, include_visual: bool = true) -> void: _systems["world"]._make_cart(pos, include_visual)
func _make_world_prop_anchor(id: String, kind: String, pos: Vector3, state_key: String = "") -> Node3D: return _systems["world"]._make_world_prop_anchor(id, kind, pos, state_key)
func _make_ritual_stone(pos: Vector3) -> void: _systems["world"]._make_ritual_stone(pos)
func _make_pillar(pos: Vector3) -> void: _systems["world"]._make_pillar(pos)
func _make_rubble(pos: Vector3) -> void: _systems["world"]._make_rubble(pos)
func _make_torch(pos: Vector3) -> void: _systems["world"]._make_torch(pos)
func _make_hit_spark(pos: Vector3, heavy: bool) -> void: _systems["world"]._make_hit_spark(pos, heavy)
func _make_fog_sheet(pos: Vector3, scale_value: Vector3, color: Color) -> void: _systems["world"]._make_fog_sheet(pos, scale_value, color)
func _make_prop_box(name: String, pos: Vector3, size: Vector3, color: Color, render_geometry: bool = true, prepared: Dictionary = {}) -> void: _systems["world"]._make_prop_box(name, pos, size, color, render_geometry, prepared)
func _make_collision_box(name: String, pos: Vector3, size: Vector3) -> void: _systems["world"]._make_collision_box(name, pos, size)
func _prop_requires_collision(lower_name: String) -> bool: return _systems["world"]._prop_requires_collision(lower_name)
func _is_first_route_clearance(pos: Vector3, radius: float = 0.0) -> bool: return _systems["world"]._is_first_route_clearance(pos, radius)
func _route_safe_position(pos: Vector3, target_x: float) -> Vector3: return _systems["world"]._route_safe_position(pos, target_x)
func _apply_first_route_materials(root: Node) -> void: _systems["world"]._apply_first_route_materials(root)
func _first_route_palette_key(node: Node) -> String: return _systems["world"]._first_route_palette_key(node)
func _node_keyword_path(node: Node) -> String: return _systems["world"]._node_keyword_path(node)
func _mesh_needs_visible_fallback(mesh_instance: MeshInstance3D) -> bool: return _systems["world"]._mesh_needs_visible_fallback(mesh_instance)
func _surface_has_authored_colors(mesh: Mesh, surface_index: int, material: Material) -> bool: return _systems["world"]._surface_has_authored_colors(mesh, surface_index, material)
func _is_bad_white_material(material: Material) -> bool: return _systems["world"]._is_bad_white_material(material)
func _first_route_material(key: String) -> StandardMaterial3D: return _systems["world"]._first_route_material(key)
func _role_for_interactable(id: String) -> String: return _systems["world"]._role_for_interactable(id)
func _make_role_visual(role_name: String, category: String, scale_value: Vector3) -> Node3D: return _systems["world"]._make_role_visual(role_name, category, scale_value)
func _environment_role_scale(role_name: String, target_size: Vector3) -> Vector3: return _systems["world"]._environment_role_scale(role_name, target_size)
func _visual_role_for_legacy_character(role_name: String) -> String: return _systems["world"]._visual_role_for_legacy_character(role_name)
func _make_light(name: String, pos: Vector3, color: Color, energy: float) -> void: _systems["world"]._make_light(name, pos, color, energy)
func _performance_mode() -> bool: return _systems["world"]._performance_mode()
func _compatibility_budget_mode() -> bool: return _systems["world"]._compatibility_budget_mode()
func _keep_performance_light(name: String) -> bool: return _systems["world"]._keep_performance_light(name)
func _build_global_environment() -> void: _systems["world"]._build_global_environment()
func _mat(color: Color) -> StandardMaterial3D: return _systems["world"]._mat(color)
func _terrain_material(name: String, color: Color) -> StandardMaterial3D: return _systems["world"]._terrain_material(name, color)
func _road_material(paved: bool, color: Color) -> StandardMaterial3D: return _systems["world"]._road_material(paved, color)
func _emissive_mat(color: Color, energy: float) -> StandardMaterial3D: return _systems["world"]._emissive_mat(color, energy)
func _read_json(path: String): return _systems["session"]._read_json(path)
func _zone_construction() -> Node3D: return _systems["world"]._zone_construction()
func _zone_runtime_fields() -> InstanceScope: return _construction_scope if _construction_scope != null else _systems["world"]._zone_runtime_fields()
func _publish_opening_batches(generation: int) -> bool: return await _systems["world"]._publish_opening_batches(generation)
