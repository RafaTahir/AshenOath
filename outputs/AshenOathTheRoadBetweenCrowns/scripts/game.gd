extends Node3D

const EnemyAI = preload("res://scripts/enemy_ai.gd")
const Interactable = preload("res://scripts/interactable.gd")
const VisualDirector = preload("res://scripts/visual_director.gd")
const NpcAmbient = preload("res://scripts/npc_ambient.gd")
const CharacterPresentation = preload("res://scripts/character_presentation.gd")
const CombatFeedback = preload("res://scripts/combat_feedback.gd")
const CharacterAnimationDriver = preload("res://scripts/character_animation_driver.gd")
const WorldVisualUpgrade = preload("res://scripts/world_visual_upgrade.gd")
const WorldMotionController = preload("res://scripts/world_motion_controller.gd")
const SurfaceFeedbackManager = preload("res://scripts/surface_feedback_manager.gd")
const WorldVFXController = preload("res://scripts/world_vfx_controller.gd")
const ZoneSpatialService = preload("res://scripts/zone_spatial_service.gd")
const RuntimeServiceRegistry = preload("res://scripts/runtime_service_registry.gd")
const RuntimeActorFactory = preload("res://scripts/runtime_actor_factory.gd")
const ZoneCompositionRouter = preload("res://scripts/zone_composition_router.gd")

var player
var camera_rig
var hud
var quests
var dialogue
var story_state
var inventory
var crafting
var combat
var save_manager
var settings
var world_materials
var day_night
var audio
var asset_helper
var visual_director
var world_vfx
var minigames
var progression
var input_router
var mobile_touch
var zone_root: Node3D
var active_interactable
var interaction_candidates: Array = []
var current_zone_id = "greyfen"
var enemy_defs = {}
var active_enemies: Array = []
var active_enemy_attacker: Node
var wychwood_pack_kills = 0
var game_started = false
var paused_by_menu = true
var pending_ending = ""
var removed_interactions = {}
var autosave_cooldown = 0.0
var last_safe_player_position = Vector3(0, 1, 7)
var tutorial_flags = {}
var material_cache: Dictionary = {}
var runtime_light_count := 0
var tree_batch_data: Array[Dictionary] = []
var deadfall_batch_data: Array[Transform3D] = []
var tree_collision_body: StaticBody3D
var route_zone_cache: Dictionary = {}
var route_enemy_cache: Dictionary = {}
var route_zone_signatures: Dictionary = {}
var retired_zone_roots: Array[Node] = []
var pending_zone_retirements := 0
var retired_skinned_actor_pool: Node3D
var skinned_resource_anchors: Dictionary = {}
var retired_material_anchors: Dictionary = {}
var retirement_material: StandardMaterial3D
var transition_history: Array[Dictionary] = []
var active_zone_signature := -1
var shared_box_mesh: BoxMesh
var prop_batch_data: Dictionary = {}
var visual_box_batch_data: Array[Dictionary] = []
var terrain_patch_batch_data: Array[Dictionary] = []
var house_batch_data: Dictionary = {}
var spatial_service: Node
var environment_batches_flushed := false
var prop_collision_body: StaticBody3D
var pending_anwen_relocation := false
var runtime_services: Node
var zone_transition_pending := false
var zone_transition_frames := 0
var pending_spawn_position := Vector3.ZERO
var pending_spawn_facing := 0.0
var loading_started_usec := 0
var last_loading_metrics: Dictionary = {}
var new_game_start_pending := false
var zone_load_request_pending := false
var requested_zone_id := ""
var requested_zone_spawn := Vector3.ZERO
var greyfen_prewarm_started := false
var greyfen_prewarm_spatial_service: Node
const MAX_CACHED_ROUTE_ZONES := 1
const ZONE_RETIRE_FRAMES := 8
const MAX_SKINNED_RESOURCE_ANCHORS := 8
const MAX_RETIRED_MATERIAL_ANCHORS := 64
const MAX_TRANSITION_HISTORY := 16

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	shared_box_mesh = BoxMesh.new()
	shared_box_mesh.size = Vector3.ONE
	_build_global_environment()
	_setup_runtime()
	hud.show_launch_screen()
	audio.set_music_state("main_menu")
	get_tree().paused = true

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_V:
			_play_voice_smoke_test("voice_sister_anwen_test", "AUDIO: voice_sister_anwen_test")
		elif event.keycode == KEY_B:
			_play_voice_smoke_test("voice_player_test", "AUDIO: voice_player_test")

func _unhandled_input(event: InputEvent) -> void:
	if not game_started:
		return
	if minigames != null and minigames.is_open():
		return
	if event.is_action_pressed("pause"):
		if get_tree().paused:
			_resume_game()
		else:
			_pause_game()
	elif event.is_action_pressed("interact") and active_interactable != null and not get_tree().paused:
		if _interaction_target_valid(active_interactable):
			_handle_interaction(active_interactable)
		else:
			hud.set_guidance_hint("Face the object and move into clear view.", 2.0)
	elif event.is_action_pressed("open_inventory") and not get_tree().paused:
		get_tree().paused = true
		hud.show_inventory(inventory, quests, story_state, progression)

func _process(delta: float) -> void:
	if not game_started or player == null or get_tree().paused:
		return
	if zone_transition_pending:
		_advance_zone_transition()
		return
	_keep_player_in_world()
	_update_interaction_focus()
	_update_tutorial_prompts()
	autosave_cooldown = max(autosave_cooldown - delta, 0.0)
	if autosave_cooldown <= 0.0:
		autosave_cooldown = 45.0
		save_manager.autosave(self)
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
	add_child(runtime_services)
	var services: Dictionary = runtime_services.create_services()
	story_state = services["story_state"]
	quests = services["quests"]
	dialogue = services["dialogue"]
	inventory = services["inventory"]
	crafting = services["crafting"]
	combat = services["combat"]
	save_manager = services["save_manager"]
	settings = services["settings"]
	world_materials = services["world_materials"]
	day_night = services["day_night"]
	audio = services["audio"]
	asset_helper = services["asset_helper"]
	hud = services["hud"]
	minigames = services["minigames"]
	progression = services["progression"]
	input_router = services["input_router"]
	mobile_touch = services["mobile_touch"]
	runtime_services.configure(self)
	enemy_defs = _read_json("res://data/enemies.json")

func _new_game() -> void:
	if zone_transition_pending or zone_load_request_pending:
		return
	new_game_start_pending = true
	loading_started_usec = Time.get_ticks_usec()
	get_tree().paused = false
	_start_new_game_world()

func _request_zone_load(zone_id: String, spawn_pos: Vector3) -> void:
	if zone_transition_pending or zone_load_request_pending:
		return
	zone_load_request_pending = true
	requested_zone_id = zone_id.strip_edges().to_lower()
	requested_zone_spawn = spawn_pos
	loading_started_usec = Time.get_ticks_usec()
	if player != null:
		player.set_transition_locked(true)
	_perform_requested_zone_load()

func _perform_requested_zone_load() -> void:
	var destination := requested_zone_id
	var arrival := requested_zone_spawn
	zone_load_request_pending = false
	requested_zone_id = ""
	_load_zone(destination, arrival)

func _start_new_game_world() -> void:
	# An explicit transition can be requested before the menu's deferred setup
	# receives its first frame. Preserve that deliberate destination.
	if game_started or not new_game_start_pending:
		return
	new_game_start_pending = false
	# Keep the menu-prewarmed Greyfen tree while clearing any stale campaign
	# cache. Rebuilding this scene in Web/ANGLE was the dominant New Game delay.
	var prewarmed_greyfen = route_zone_cache.get("greyfen")
	var prewarmed_enemies: Array = route_enemy_cache.get("greyfen", [])
	if prewarmed_greyfen != null:
		route_zone_cache.erase("greyfen")
		route_enemy_cache.erase("greyfen")
	_clear_route_zone_cache()
	if prewarmed_greyfen != null and is_instance_valid(prewarmed_greyfen):
		_cache_route_zone("greyfen", prewarmed_greyfen, prewarmed_enemies, _zone_state_signature(), true)
	game_started = true
	paused_by_menu = false
	wychwood_pack_kills = 0
	pending_anwen_relocation = false
	tutorial_flags.clear()
	progression.load_state({})
	current_zone_id = "greyfen"
	day_night.set_time(day_night.START_TIME_MINUTES, 0)
	hud.hide_menus()
	quests.start_quest("main_road_of_crows")
	if route_zone_cache.has("greyfen"):
		route_zone_signatures["greyfen"] = _zone_state_signature()
	_load_zone("greyfen", Vector3(0, 1, 7))
	hud.toast("Greyfen whispers about the old road. Sister Anwen is waiting at the shrine.")
	hud.set_guidance_hint("E - Speak to Sister Anwen", 5.5)
	_refresh_tracker()
	_refresh_equipment_readout()
	save_manager.checkpoint(self)

func load_save_state(data: Dictionary) -> void:
	_clear_route_zone_cache()
	game_started = true
	get_tree().paused = false
	hud.hide_menus()
	inventory.load_state(data.get("inventory", {}))
	quests.load_state(data.get("quests", {}))
	story_state.load_state(data.get("story_state", {}))
	progression.load_state(data.get("progression", {}))
	progression.reconcile_completed_quests(quests.quest_defs, quests.completed)
	if int(data.get("version", 0)) < 3 and quests.is_completed("main_road_of_crows"):
		story_state.set_flag("legacy_report_choice_required", true)
	load_world_state(data.get("world_state", {}))
	var zone = str(data.get("zone", "greyfen"))
	var pos_array: Array = data.get("player_position", [0, 1, 7])
	var pos = Vector3(float(pos_array[0]), float(pos_array[1]), float(pos_array[2]))
	pos = _safe_loaded_position(zone, pos)
	_load_zone(zone, pos)
	player.health_component.load_state(data.get("player_health", {}))
	player.stamina_component.load_state(data.get("player_stamina", {}))
	_apply_progression_to_player()
	_refresh_tracker()
	_refresh_equipment_readout()

func _spawn_player(pos: Vector3) -> void:
	if player != null:
		player.queue_free()
	if camera_rig != null:
		camera_rig.queue_free()
	var actor_pair: Dictionary = RuntimeActorFactory.create_player_camera(self, pos, current_zone_id, input_router)
	assert(RuntimeActorFactory.is_valid_pair(actor_pair), "Player-camera composition failed")
	player = actor_pair["player"]
	camera_rig = actor_pair["camera"]
	_apply_progression_to_player()
	_apply_runtime_settings(settings.settings)
	player.blade_contact_requested.connect(_on_player_blade_contact)
	player.potion_requested.connect(_use_potion)
	player.bomb_requested.connect(_throw_bomb)
	player.beam_requested.connect(_on_player_beam)
	player.beam_phase_changed.connect(_on_player_beam_phase)
	player.footstep.connect(_on_player_footstep)
	player.parried.connect(_on_player_parried)
	player.blocked.connect(_on_player_blocked)
	player.hurt.connect(_on_player_hurt)
	player.stamina_exhausted.connect(_on_player_stamina_exhausted)
	player.died.connect(_on_player_died)
	player.health_component.changed.connect(hud.update_health)
	player.stamina_component.changed.connect(hud.update_stamina)
	hud.update_health(player.health_component.health, player.health_component.max_health)
	hud.update_stamina(player.stamina_component.stamina, player.stamina_component.max_stamina)

func _load_zone(zone_id: String, spawn_pos: Vector3 = Vector3.ZERO) -> void:
	if new_game_start_pending and not game_started:
		new_game_start_pending = false
	zone_id = zone_id.strip_edges().to_lower()
	loading_started_usec = loading_started_usec if loading_started_usec > 0 else Time.get_ticks_usec()
	if player != null and player.has_method("set_transition_locked"):
		player.set_transition_locked(true)
	_clear_oathfire_effects()
	runtime_light_count = 0
	tree_batch_data.clear()
	deadfall_batch_data.clear()
	prop_batch_data.clear()
	visual_box_batch_data.clear()
	terrain_patch_batch_data.clear()
	house_batch_data.clear()
	environment_batches_flushed = false
	tree_collision_body = null
	prop_collision_body = null
	if player != null and player.has_method("cancel_beam_charge"):
		player.cancel_beam_charge()
	var previous_zone_id: String = current_zone_id
	var previous_enemies: Array = active_enemies.duplicate()
	var reused_zone := false
	var requested_signature := _zone_state_signature()
	if zone_root != null:
		if previous_zone_id == zone_id and active_zone_signature == requested_signature:
			reused_zone = true
		elif previous_zone_id == zone_id:
			var stale_active := zone_root
			_retire_zone_root(stale_active)
			zone_root = null
		else:
			_cache_route_zone(previous_zone_id, zone_root, previous_enemies, active_zone_signature)
	active_interactable = null
	interaction_candidates.clear()
	current_zone_id = zone_id
	var using_prewarmed_spatial := zone_id == "greyfen" \
		and greyfen_prewarm_spatial_service != null \
		and is_instance_valid(greyfen_prewarm_spatial_service)
	if spatial_service != null and is_instance_valid(spatial_service) and spatial_service != greyfen_prewarm_spatial_service:
		_set_zone_collision_enabled(spatial_service, false)
		spatial_service.queue_free()
	if using_prewarmed_spatial:
		spatial_service = greyfen_prewarm_spatial_service
		greyfen_prewarm_spatial_service = null
		spatial_service.name = "ZoneSpatialService"
		spatial_service.process_mode = Node.PROCESS_MODE_INHERIT
	else:
		spatial_service = ZoneSpatialService.new()
		spatial_service.name = "ZoneSpatialService"
		add_child(spatial_service)
		spatial_service.configure(zone_id, _river_center(zone_id), _zone_half_extents(zone_id))
	if camera_rig != null and camera_rig.has_method("set_zone"):
		camera_rig.set_zone(zone_id)
	active_enemies.clear()
	hud.set_prompt("")
	if reused_zone:
		active_enemies = _valid_cached_enemies(previous_enemies)
	elif route_zone_cache.has(zone_id) and is_instance_valid(route_zone_cache[zone_id]) \
			and int(route_zone_signatures.get(zone_id, -1)) == requested_signature:
		zone_root = _activate_cached_zone(zone_id)
		active_zone_signature = int(route_zone_signatures.get(zone_id, requested_signature))
		route_zone_signatures.erase(zone_id)
		var prewarm_camera := zone_root.find_child("GreyfenPrewarmCamera", true, false) as Camera3D
		if prewarm_camera != null:
			prewarm_camera.current = false
			prewarm_camera.queue_free()
		active_enemies = _valid_cached_enemies(route_enemy_cache.get(zone_id, []))
		route_enemy_cache.erase(zone_id)
		reused_zone = true
	else:
		if route_zone_cache.has(zone_id):
			var stale_root = route_zone_cache.get(zone_id)
			route_zone_cache.erase(zone_id)
			route_enemy_cache.erase(zone_id)
			route_zone_signatures.erase(zone_id)
			if is_instance_valid(stale_root):
				_retire_zone_root(stale_root)
		zone_root = Node3D.new()
		zone_root.name = zone_id
		add_child(zone_root)
		var composition_kind := ZoneCompositionRouter.composition_kind(zone_id)
		var build_result: Dictionary
		if composition_kind == "campaign":
			build_result = ZoneCompositionRouter.build_campaign(self, zone_id)
		else:
			build_result = ZoneCompositionRouter.build_core(self, zone_id)
		if not bool(build_result.get("ok", false)):
			push_error("Zone composition failed for %s: %s" % [
				zone_id, ", ".join(build_result.get("errors", []))
			])
			_recover_failed_zone_load(previous_zone_id)
			return
		if composition_kind == "campaign":
			_apply_campaign_arrival(zone_id)
		_flush_environment_batches()
		if zone_id in ["greyfen", "wychwood"]:
			_add_visual_100_layer(zone_id)
		_apply_first_route_materials(zone_root)
		_validate_zone_render_resources(zone_root)
		active_zone_signature = _zone_state_signature()
	if zone_root != null:
		zone_root.set_meta("zone_resource_owner", "active")
		zone_root.set_meta("zone_resource_id", zone_id)
	_trim_route_zone_cache([previous_zone_id] if previous_zone_id != zone_id else [])
	# Avoid recursive diagnostic walks during every transition; on Web/ANGLE those
	# allocations made cached arrivals visibly slower.
	print("ZONE_COMPOSITION: id=%s reused=%s visible=%s position=%s" % [
		zone_id, reused_zone, zone_root.visible, zone_root.global_position,
	])
	active_zone_signature = _zone_state_signature()
	if not using_prewarmed_spatial:
		spatial_service.build_navigation(zone_root)
	for enemy in active_enemies:
		if is_instance_valid(enemy) and enemy.has_method("setup_navigation"):
			enemy.setup_navigation(spatial_service)
	var life_controller := zone_root.find_child("GreyfenLifeController", true, false)
	if life_controller != null and life_controller.has_method("set_spatial_service"):
		life_controller.set_spatial_service(spatial_service)
	quests.set_tracked_quest_for_zone(zone_id)
	if visual_director != null:
		visual_director.apply_zone(zone_id, zone_root)
	if audio != null:
		audio.play_ambient(zone_id)
		audio.set_music_state("wychwood_tension" if zone_id == "wychwood" else ("castle_silence" if zone_id in ["vargan_approach", "vargan_court", "record_hall"] else "greyfen_explore"))
		if zone_id == "greyfen":
			audio.play_event("shrine_hum", 0.01)
	var safe_spawn: Vector3 = spatial_service.nearest_safe(spawn_pos, spatial_service.bank_for(spawn_pos))
	if player == null:
		_spawn_player(safe_spawn)
	else:
		player.visible = true
		player.process_mode = Node.PROCESS_MODE_INHERIT
		if camera_rig != null:
			camera_rig.process_mode = Node.PROCESS_MODE_INHERIT
			var gameplay_camera := camera_rig.find_child("Camera3D", true, false) as Camera3D
			if gameplay_camera != null:
				gameplay_camera.current = true
	# Greyfen's life controller is constructed with the zone. New Game now creates
	# Kael after collision is ready, so bind the final player instance here.
	if life_controller != null:
		life_controller.player = player
	if player != null:
		pending_spawn_facing = player.rotation.y
		pending_spawn_position = safe_spawn
		player.global_position = safe_spawn + Vector3.UP * 0.9
		player.velocity = Vector3.ZERO
		if using_prewarmed_spatial and reused_zone:
			# This scene has already completed collision and navigation setup
			# behind the menu. Do not wait for another rendered WebGL frame.
			player.global_position = Vector3(safe_spawn.x, maxf(safe_spawn.y, 0.95), safe_spawn.z)
			player.set_transition_locked(false)
			last_safe_player_position = player.global_position
			zone_transition_pending = false
			var elapsed_ms := float(Time.get_ticks_usec() - loading_started_usec) / 1000.0
			_record_loading_metrics({
				"zone": current_zone_id,
				"to_playable_ms": elapsed_ms,
				"support_ready": true,
				"velocity_reset": true
			})
			print("LOADING: zone=%s playable_ms=%.1f" % [current_zone_id, elapsed_ms])
			loading_started_usec = 0
			hud.hide_loading()
		else:
			player.set_transition_locked(true)
			zone_transition_frames = 0
			zone_transition_pending = true
	if game_started:
		_schedule_zone_autosave()
	if zone_id == "wychwood" and quests.is_active("main_road_of_crows") and not quests.is_objective_done("main_road_of_crows", "fight_ghoulkin"):
		audio.play_event("reveal", 0.02)
		audio.play_event("wychwood_tension", 0.01)
		audio.set_music_state("wychwood_tension")
		hud.toast("The woods go quiet. Survive the Ghoulkin.")
		hud.set_guidance_hint("Left click strike | Space dodge | Tap Q parry | Hold Q block", 6.0)
		hud.show_status_cue("Survive the clearing", "neutral")

func _advance_zone_transition() -> void:
	zone_transition_frames += 1
	if player == null or spatial_service == null:
		return
	var grounded: Variant = _grounded_spawn_position(pending_spawn_position)
	if grounded == null:
		if zone_transition_frames > 3:
			push_warning("Zone spawn support timed out; using validated recovery: %s" % current_zone_id)
			grounded = spatial_service.nearest_safe(pending_spawn_position, spatial_service.bank_for(pending_spawn_position))
			grounded.y = 0.95
		else:
			return
	player.global_position = grounded
	player.rotation.y = pending_spawn_facing
	player.velocity = Vector3.ZERO
	if zone_transition_frames < 2:
		return
	player.set_transition_locked(false)
	last_safe_player_position = player.global_position
	zone_transition_pending = false
	var elapsed_ms := float(Time.get_ticks_usec() - loading_started_usec) / 1000.0
	_record_loading_metrics({
		"zone": current_zone_id,
		"to_playable_ms": elapsed_ms,
		"support_ready": true,
		"velocity_reset": player.velocity.is_zero_approx()
	})
	print("LOADING: zone=%s playable_ms=%.1f" % [current_zone_id, elapsed_ms])
	loading_started_usec = 0
	hud.hide_loading()

func _recover_failed_zone_load(previous_zone_id: String) -> void:
	zone_transition_pending = false
	zone_load_request_pending = false
	requested_zone_id = ""
	if zone_root != null:
		_retire_zone_root(zone_root)
		zone_root = null
	if route_zone_cache.has(previous_zone_id) and is_instance_valid(route_zone_cache[previous_zone_id]):
		zone_root = _activate_cached_zone(previous_zone_id)
		active_enemies = _valid_cached_enemies(route_enemy_cache.get(previous_zone_id, []))
		route_enemy_cache.erase(previous_zone_id)
		active_zone_signature = int(route_zone_signatures.get(previous_zone_id, -1))
		route_zone_signatures.erase(previous_zone_id)
		current_zone_id = previous_zone_id
	if player != null:
		player.set_transition_locked(false)
		player.global_position = last_safe_player_position
		player.velocity = Vector3.ZERO
	if hud != null:
		hud.hide_loading()
		hud.toast("The road will not open. You remain in %s." % _zone_display_name(previous_zone_id))

func _grounded_spawn_position(candidate: Vector3) -> Variant:
	if get_world_3d() == null:
		return null
	var query := PhysicsRayQueryParameters3D.create(candidate + Vector3.UP * 6.0, candidate - Vector3.UP * 12.0, 1)
	if player != null:
		query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	return Vector3(candidate.x, float(hit.position.y) + 0.95, candidate.z)

func _zone_display_name(zone_id: String) -> String:
	return zone_id.replace("_", " ").capitalize()

func _valid_cached_enemies(entries: Array) -> Array:
	var result: Array = []
	for enemy in entries:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			result.append(enemy)
	return result

func _zone_state_signature() -> int:
	var quest_world_state: Dictionary = quests.save_state().duplicate(true) if quests != null else {}
	# HUD tracking changes by zone and must not invalidate otherwise identical
	# cached world geometry.
	quest_world_state.erase("tracked_quest_id")
	quest_world_state.erase("tracker_context_zone")
	return hash([
		story_state.save_state() if story_state != null else {},
		quest_world_state,
		removed_interactions,
	])

func _deferred_free_zone(retired_root: Node) -> void:
	# Keep the complete render hierarchy intact until the scene tree disposes it.
	# Manually detaching skins or surfaces races RenderingServer teardown.
	for _frame in range(ZONE_RETIRE_FRAMES):
		await get_tree().process_frame
	if is_instance_valid(retired_root):
		if retired_root.is_inside_tree() and retired_root.get_parent() != null:
			retired_root.get_parent().remove_child(retired_root)
		RenderingServer.force_sync()
		await get_tree().process_frame
		retired_zone_roots.erase(retired_root)
		retired_root.free()
		RenderingServer.force_sync()
	else:
		retired_zone_roots.erase(retired_root)
	pending_zone_retirements = maxi(pending_zone_retirements - 1, 0)

func _retire_zone_root(retired_root: Node) -> void:
	if retired_root == null or not is_instance_valid(retired_root):
		return
	if retired_zone_roots.has(retired_root):
		return
	_remove_root_from_route_cache(retired_root)
	_anchor_retired_materials(retired_root)
	_anchor_shared_skinned_resources(retired_root)
	_quiesce_zone_runtime(retired_root)
	_validate_zone_render_resources(retired_root)
	_bind_retirement_material(retired_root)
	_set_zone_collision_enabled(retired_root, false)
	retired_root.visible = false
	retired_root.process_mode = Node.PROCESS_MODE_DISABLED
	retired_root.position = Vector3(0, -2000.0 - retired_zone_roots.size() * 100.0, 0)
	retired_root.name = "__retiring_%s_%d" % [str(retired_root.name), pending_zone_retirements]
	retired_root.set_meta("zone_resource_owner", "retiring")
	retired_zone_roots.append(retired_root)
	pending_zone_retirements += 1
	_deferred_free_zone(retired_root)

func _bind_retirement_material(root: Node) -> void:
	if retirement_material == null:
		retirement_material = StandardMaterial3D.new()
		retirement_material.albedo_color = Color(0.08, 0.08, 0.08)
		retirement_material.roughness = 1.0
	_keep_retired_material(retirement_material)
	for raw_mesh in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := raw_mesh as MeshInstance3D
		mesh_instance.material_override = retirement_material
		if mesh_instance.mesh == null:
			continue
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			mesh_instance.set_surface_override_material(surface_index, retirement_material)
	for raw_batch in root.find_children("*", "MultiMeshInstance3D", true, false):
		(raw_batch as MultiMeshInstance3D).material_override = retirement_material

func _anchor_retired_materials(root: Node) -> void:
	for raw_mesh in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := raw_mesh as MeshInstance3D
		if mesh_instance.material_override != null:
			_keep_retired_material(mesh_instance.material_override)
		if mesh_instance.mesh == null:
			continue
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var material := mesh_instance.get_surface_override_material(surface_index)
			if material == null:
				material = mesh_instance.mesh.surface_get_material(surface_index)
			if material != null:
				_keep_retired_material(material)

func _keep_retired_material(material: Material) -> void:
	if retired_material_anchors.size() >= MAX_RETIRED_MATERIAL_ANCHORS:
		return
	var key := str(material.get_rid().get_id())
	if not retired_material_anchors.has(key):
		retired_material_anchors[key] = material

func _anchor_shared_skinned_resources(root: Node) -> void:
	if retired_skinned_actor_pool == null or not is_instance_valid(retired_skinned_actor_pool):
		retired_skinned_actor_pool = Node3D.new()
		retired_skinned_actor_pool.name = "SharedSkinnedResourceAnchors"
		retired_skinned_actor_pool.visible = false
		retired_skinned_actor_pool.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(retired_skinned_actor_pool)
	var branches: Array[Node] = []
	for raw_skeleton in root.find_children("*", "Skeleton3D", true, false):
		var branch := raw_skeleton as Node
		while branch.get_parent() != null and branch.get_parent() != root:
			branch = branch.get_parent()
		if branch.get_parent() == root and not branches.has(branch):
			branches.append(branch)
	for branch in branches:
		var fingerprint := _skinned_resource_fingerprint(branch)
		if fingerprint.is_empty() or skinned_resource_anchors.has(fingerprint):
			continue
		if skinned_resource_anchors.size() >= MAX_SKINNED_RESOURCE_ANCHORS:
			break
		branch.reparent(retired_skinned_actor_pool, false)
		if branch is Node3D:
			(branch as Node3D).visible = false
		branch.process_mode = Node.PROCESS_MODE_DISABLED
		skinned_resource_anchors[fingerprint] = branch

func _skinned_resource_fingerprint(branch: Node) -> String:
	var fingerprints: Array[String] = []
	for raw_mesh in branch.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := raw_mesh as MeshInstance3D
		if mesh_instance.skin == null or mesh_instance.mesh == null:
			continue
		var fingerprint := mesh_instance.mesh.resource_path
		if fingerprint.is_empty():
			fingerprint = "mesh_rid:%s" % str(mesh_instance.mesh.get_rid().get_id())
		if not fingerprints.has(fingerprint):
			fingerprints.append(fingerprint)
	fingerprints.sort()
	return "|".join(fingerprints)

func _record_loading_metrics(metrics: Dictionary) -> void:
	last_loading_metrics = metrics
	transition_history.append(metrics.duplicate(true))
	while transition_history.size() > MAX_TRANSITION_HISTORY:
		transition_history.pop_front()

func _quiesce_zone_runtime(root: Node) -> void:
	for raw_player in root.find_children("*", "AnimationPlayer", true, false):
		var animation_player := raw_player as AnimationPlayer
		animation_player.stop(true)
		animation_player.active = false
	for raw_tree in root.find_children("*", "AnimationTree", true, false):
		(raw_tree as AnimationTree).active = false
	for raw_audio in root.find_children("*", "AudioStreamPlayer3D", true, false):
		(raw_audio as AudioStreamPlayer3D).stop()

func _cache_route_zone(zone_id: String, root: Node3D, enemies: Array, signature: int, keep_visible: bool = false) -> void:
	if root == null or not is_instance_valid(root):
		return
	var existing = route_zone_cache.get(zone_id)
	if existing != null and existing != root and is_instance_valid(existing):
		_retire_zone_root(existing)
	_remove_root_from_route_cache(root)
	_set_zone_collision_enabled(root, false)
	root.visible = keep_visible
	root.process_mode = Node.PROCESS_MODE_DISABLED
	root.position = Vector3.ZERO if keep_visible else Vector3(0, -1000, 0)
	root.set_meta("zone_resource_owner", "cached")
	root.set_meta("zone_resource_id", zone_id)
	route_zone_cache[zone_id] = root
	route_enemy_cache[zone_id] = _valid_cached_enemies(enemies)
	route_zone_signatures[zone_id] = signature

func _activate_cached_zone(zone_id: String) -> Node3D:
	var cached_root = route_zone_cache.get(zone_id)
	if cached_root == null or not is_instance_valid(cached_root):
		return null
	route_zone_cache.erase(zone_id)
	cached_root.visible = true
	cached_root.position = Vector3.ZERO
	cached_root.process_mode = Node.PROCESS_MODE_INHERIT
	cached_root.set_meta("zone_resource_owner", "active")
	_set_zone_collision_enabled(cached_root, true)
	return cached_root as Node3D

func _remove_root_from_route_cache(root: Node) -> void:
	for raw_id in route_zone_cache.keys().duplicate():
		var id := str(raw_id)
		if route_zone_cache.get(id) == root:
			route_zone_cache.erase(id)
			route_enemy_cache.erase(id)
			route_zone_signatures.erase(id)

func _trim_route_zone_cache(preferred_ids: Array) -> void:
	var retained: Array[String] = []
	for raw_id in preferred_ids:
		var id := str(raw_id)
		if route_zone_cache.has(id) and not retained.has(id) and retained.size() < MAX_CACHED_ROUTE_ZONES:
			retained.append(id)
	for raw_id in route_zone_cache.keys().duplicate():
		var id := str(raw_id)
		if retained.has(id):
			continue
		var cached_root = route_zone_cache.get(id)
		route_zone_cache.erase(id)
		route_enemy_cache.erase(id)
		route_zone_signatures.erase(id)
		if is_instance_valid(cached_root):
			_retire_zone_root(cached_root)

func _set_zone_collision_enabled(node: Node, enabled: bool) -> void:
	if node is NavigationRegion3D:
		(node as NavigationRegion3D).enabled = enabled
	if node is CollisionObject3D:
		var collision_object := node as CollisionObject3D
		if not collision_object.has_meta("zone_collision_layer"):
			collision_object.set_meta("zone_collision_layer", collision_object.collision_layer)
			collision_object.set_meta("zone_collision_mask", collision_object.collision_mask)
		collision_object.collision_layer = int(collision_object.get_meta("zone_collision_layer", 1)) if enabled else 0
		collision_object.collision_mask = int(collision_object.get_meta("zone_collision_mask", 1)) if enabled else 0
	if node is Area3D:
		var area := node as Area3D
		if not area.has_meta("zone_monitoring"):
			area.set_meta("zone_monitoring", area.monitoring)
			area.set_meta("zone_monitorable", area.monitorable)
		area.monitoring = bool(area.get_meta("zone_monitoring", true)) if enabled else false
		area.monitorable = bool(area.get_meta("zone_monitorable", true)) if enabled else false
	for child in node.get_children():
		_set_zone_collision_enabled(child, enabled)

func _schedule_zone_autosave() -> void:
	var expected_zone: String = current_zone_id
	get_tree().create_timer(0.35).timeout.connect(func():
		if game_started and current_zone_id == expected_zone and save_manager != null:
			save_manager.autosave(self)
	, CONNECT_ONE_SHOT)

func _clear_route_zone_cache() -> void:
	if zone_root != null and is_instance_valid(zone_root):
		_retire_zone_root(zone_root)
	zone_root = null
	for cached_root in route_zone_cache.values():
		if is_instance_valid(cached_root):
			if not cached_root.is_inside_tree():
				add_child(cached_root)
			_retire_zone_root(cached_root)
	route_zone_cache.clear()
	route_enemy_cache.clear()
	route_zone_signatures.clear()

func prepare_resource_shutdown() -> void:
	if zone_root != null and is_instance_valid(zone_root):
		_retire_zone_root(zone_root)
	zone_root = null
	for cached_root in route_zone_cache.values().duplicate():
		if cached_root != null and is_instance_valid(cached_root):
			_retire_zone_root(cached_root)
	route_zone_cache.clear()
	route_enemy_cache.clear()
	route_zone_signatures.clear()

func zone_lifecycle_snapshot() -> Dictionary:
	var cached_ids: Array[String] = []
	for raw_id in route_zone_cache.keys():
		cached_ids.append(str(raw_id))
	cached_ids.sort()
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
	}

func _subtree_node_count(root: Node) -> int:
	if root == null or not is_instance_valid(root):
		return 0
	var count := 1
	for child in root.get_children():
		count += _subtree_node_count(child)
	return count

func _exit_tree() -> void:
	# Cached zones remain children of the game and are released by normal subtree
	# destruction. Touching renderer resources during NOTIFICATION_EXIT_TREE is unsafe.
	route_zone_cache.clear()
	route_enemy_cache.clear()
	route_zone_signatures.clear()
	for retired_root in retired_zone_roots.duplicate():
		if retired_root != null and is_instance_valid(retired_root) and not retired_root.is_inside_tree():
			retired_root.free()
	retired_zone_roots.clear()
	pending_zone_retirements = 0
	skinned_resource_anchors.clear()
	retired_material_anchors.clear()
	transition_history.clear()

func _add_visual_100_layer(zone_id: String) -> void:
	var quality := str(settings.settings.get("quality_preset", "balanced")) if settings != null else "balanced"
	var visual_root := Node3D.new()
	visual_root.name = "AuthoredVisualLayer_%s" % zone_id.capitalize()
	visual_root.set_meta("synthetic_visual_100_removed", true)
	zone_root.add_child(visual_root)
	var motion = WorldMotionController.new()
	motion.name = "WorldMotionController"
	zone_root.add_child(motion)
	motion.configure(zone_root, quality)
	var surface = SurfaceFeedbackManager.new()
	surface.name = "SurfaceFeedbackManager"
	zone_root.add_child(surface)
	surface.configure(player, quality)
	world_vfx = WorldVFXController.new()
	world_vfx.name = "WorldVFXController"
	zone_root.add_child(world_vfx)
	world_vfx.configure(zone_id, quality)

func _handle_interaction(area) -> void:
	if world_vfx != null and is_instance_valid(world_vfx) and area is Node3D:
		world_vfx.pulse_interaction((area as Node3D).global_position)
	if area.interaction_type == "minigame":
		minigames.open_game("tic_tac_toe" if area.interaction_id == "common_table" else "draughts")
	elif area.interaction_type == "village_place":
		_handle_village_place(area.interaction_id)
	elif area.interaction_type == "dialogue":
		if area.interaction_id == "vargan_ledger_choice":
			quests.complete_evidence("main_blood_under_stone", "evidence_ledger_fragment")
			quests.complete_objective("main_blood_under_stone", "recover_ledger")
		var dialogue_data = dialogue.get_dialogue(area.dialogue_id)
		var played_report_voice = false
		var report_chosen := false
		if _road_ready_to_report() and area.interaction_id in ["sister_anwen", "notice_board", "retain_evidence"]:
			report_chosen = true
			var report_method: String = str({"sister_anwen":"private", "notice_board":"public", "retain_evidence":"retained"}[area.interaction_id])
			story_state.set_flag("evidence_report", report_method)
			story_state.set_flag("cemetery_bell_rung", true)
			story_state.adjust_value("anwen_trust", 1 if report_method == "private" else (-1 if report_method == "public" else 0))
			story_state.adjust_value("greyfen_fear", 1 if report_method == "public" else 0)
			quests.complete_objective("main_road_of_crows", "return_village")
			dialogue_data = dialogue.get_dialogue(area.dialogue_id)
			if area.interaction_id == "sister_anwen":
				pending_anwen_relocation = true
			else:
				_relocate_anwen_to_cemetery()
		if area.interaction_id == "sister_anwen" and not bool(tutorial_flags.get("anwen_talked", false)):
			tutorial_flags["anwen_talked"] = true
			quests.complete_objective("main_road_of_crows", "speak_anwen")
		elif area.interaction_id == "sister_anwen" and not report_chosen and quests.is_active("main_bell_beneath_greyfen"):
			quests.complete_objective("main_bell_beneath_greyfen", "meet_anwen_gate")
			story_state.set_flag("bell_gate_met", true)
			dialogue_data = dialogue.get_dialogue(area.dialogue_id)
			audio.set_music_state("shrine_anwen")
			hud.toast("The cut bell rope runs beneath the graves. Anwen waits for proof.")
			hud.set_guidance_hint("Inspect any two disturbed graves beside the chapel.", 6.0)
		if report_chosen and area.interaction_id == "sister_anwen":
			audio.play_event("return_report", 0.02)
			audio.play_voice("voice_sister_anwen_report_01")
			played_report_voice = true
			audio.set_music_state("return_report")
			hud.show_status_cue("Anwen knows the sign", "victory")
			hud.toast("Anwen goes still at the feathers. 'Then it was called here,' she says, and will say no more.")
		_stage_dialogue_moment(area)
		get_tree().paused = true
		hud.show_dialogue(dialogue_data)
		if dialogue_data.has("voice") and not played_report_voice:
			audio.play_voice_sequence(dialogue_data.get("voice", []))
		elif not played_report_voice:
			var campaign_voice: String = str({
				"captain_senn":"voice_senn_confession", "halvern":"voice_halvern_witness",
				"edric_campaign":"voice_edric_ledger", "assembly_choice":"voice_kael_names",
				"white_hart":"voice_hart_choice"
			}.get(area.interaction_id, ""))
			if campaign_voice != "": audio.play_voice(campaign_voice)
	elif area.interaction_type == "clue":
		if area.interaction_id == "chapel_door" and not _chapel_can_open():
			if not quests.is_objective_done("main_bell_beneath_greyfen", "grave_truth"):
				hud.toast("The chapel seal has no keyhole. The disturbed graves must explain the bell.")
			else:
				hud.toast("Something moves beneath the grave soil. The chapel will not open while it remains.")
			hud.set_guidance_hint("Finish the cemetery investigation before opening the chapel.", 5.0)
			return
		if area.quest_id == "main_road_of_crows":
			_handle_road_of_crows_clue(area)
		else:
			quests.complete_objective(area.quest_id, area.objective_id)
		if area.interaction_id == "tracks":
			if quests.is_objective_done("main_road_of_crows", "fight_ghoulkin"):
				hud.toast("The tracks change after the Ghoulkin falls: boots beside claws, both leading back toward Greyfen.")
				hud.set_guidance_hint("Return to Greyfen. Report to Sister Anwen.", 5.5)
				audio.play_event("tracks_found", 0.02)
				audio.play_voice("voice_player_return_report_01")
				audio.set_music_state("return_report")
			else:
				hud.toast("Dragged tracks run beside boot prints. Something was led here, not merely hunting.")
				audio.play_voice("voice_player_clue_observation_01")
			audio.play_event("reveal", 0.02)
		elif area.interaction_id == "corpse":
			hud.toast("Old blood in the mud. The body was searched after death, carefully, by human hands.")
		elif area.interaction_id == "claw_marks":
			hud.toast("The claw marks are real, but they cut over wagon ruts. The beast came after the cart stopped.")
		elif area.interaction_id == "black_feathers":
			hud.toast("Sella's pilgrim bead is tied in shrine-red burial thread. It was prepared before she died.")
		elif area.interaction_id == "oren_token":
			hud.toast("Oren's wooden crow has its name panel scratched away. Someone wanted the child forgotten.")
		elif area.interaction_id == "chapel_names":
			story_state.set_flag("chapel_names_read", true)
			hud.toast("The chapel lists Bram and Sella. Oren's name was cut away, but the red thread still marks his place.")
			hud.set_guidance_hint("Return to Wychwood. Speak Oren's name at the ritual stones.", 6.0)
			audio.play_event("reveal", 0.02)
		elif area.interaction_id == "ritual_stones":
			quests.complete_objective("main_teeth_in_rain", "name_the_dead")
			story_state.set_flag("oren_name_spoken", true)
			hud.toast("Kael speaks Oren's name. Something deeper in Wychwood answers.")
			hud.set_guidance_hint("The deeper road is open. Find what carried Oren's memory.", 6.0)
			audio.play_event("reveal", 0.03)
			if current_zone_id == "wychwood" and not _has_interactable("deep_wood_gate"):
				var deeper_gate = _make_zone_gate("Enter deeper Wychwood", Vector3(10.8, 0, -13.2), "deep_wood", Vector3(0, 1, 12))
				if deeper_gate != null:
					deeper_gate.name = "deep_wood_gate"
		elif area.interaction_id == "old_hall":
			quests.complete_objective("main_blood_under_stone", "locate_record_hall")
		elif area.interaction_id == "grave_bell":
			quests.complete_objective("side_widows_bell", "find_bell")
		elif area.interaction_id == "massacre_iron":
			quests.complete_objective("side_iron_remembers", "recover_iron")
			hud.toast("The iron bears Vargan hammer marks beneath the soot.")
		elif area.interaction_id == "empty_grave_tracks":
			quests.complete_objective("side_empty_grave", "follow_empty_grave")
			hud.toast("Bare footprints leave the grave and stop beside the old road.")
			hud.set_guidance_hint("A returned soldier waits near Greyfen's eastern lane.", 5.0)
		elif area.interaction_id == "bandit_camp":
			hud.toast("Boot prints. Rope. A child's torn ribbon. Not a dog's work.")
		elif area.interaction_id == "bitter_roots":
			quests.complete_objective("side_bitter_roots", "collect_roots")
		elif area.interaction_id == "sacrifice_roots":
			hud.toast("The roots drink from old blood. Mira knew this place.")
		elif area.interaction_id == "chapel_door":
			story_state.set_flag("crow_chapel_opened", true)
			hud.toast("The chapel seal yields. The Crow Shrine inside is still bound to the erased names.")
			hud.set_guidance_hint("Return to the shrine and decide what should happen to the covenant.", 6.0)
			_spawn_crow_shrine_choice()
		elif area.interaction_id.begins_with("grave_"):
			_ensure_cemetery_ambush()
		elif area.interaction_id.begins_with("vargan_"):
			story_state.set_flag(area.interaction_id, true)
			story_state.set_flag("castle_discovered", true)
			match area.interaction_id:
				"vargan_mile_marker": hud.toast("The seal is Vargan. The scrape marks are newer.")
				"vargan_supply_cart": hud.toast("Army weights and refugee canvas. Soldiers moved this cargo after the road closed.")
				"vargan_gate_notice": hud.toast("The road was not lost. It was closed by order.")
				"vargan_iron_binding": hud.toast("Iron wire, blackened at the twist. The same work as Oren's token.")
		_mark_interaction_removed(area)
		active_interactable = null
		hud.set_prompt("")
		area.queue_free()
	elif area.interaction_type == "herb":
		var gain = {}
		gain[area.interaction_id] = 1
		inventory.add_ingredients(gain)
		hud.toast("Gathered %s." % area.interaction_id.capitalize())
		_mark_interaction_removed(area)
		area.queue_free()
	elif area.interaction_type == "zone":
		_request_zone_load(area.zone_target, area.get_meta("spawn_pos"))
	elif area.interaction_type == "blocked_zone":
		hud.toast(str(area.get_meta("message", "That road is barred tonight.")))

func _handle_village_place(id: String) -> void:
	match id:
		"village_well":
			player.stamina_component.restore(5.0)
			hud.toast("Cold iron in the water. Kael catches his breath.")
		"forge_corner": hud.toast("Vargan iron, hammered into Greyfen hinges. Tor never mentions the crest marks.")
		"shrine_prayer": hud.toast("The bench is worn smooth by people asking not to be noticed.")
		"river_water":
			player.stamina_component.restore(18.0)
			hud.toast("Cold river water. Clean enough above Greyfen, for now.")
		_: hud.toast("Greyfen has made use of everything it could keep.")

func _on_minigame_result(game_id: String, outcome: String) -> void:
	var played_id := "%s_played" % game_id
	story_state.set_flag(played_id, int(story_state.get_flag(played_id,0)) + 1)
	if outcome == "win":
		var wins_id := "%s_wins" % game_id
		story_state.set_flag(wins_id, int(story_state.get_flag(wins_id,0)) + 1)
		var reward_id := "%s_reward_claimed" % game_id
		if not bool(story_state.get_flag(reward_id,false)):
			story_state.set_flag(reward_id,true)
			if game_id == "tic_tac_toe":
				story_state.set_flag("rook_road_hint",true)
				hud.toast("Rook: Road wasn't always cursed. Ask who bent it.")
			else:
				story_state.set_flag("tor_iron_hint",true)
				inventory.add_ingredients({"scrap_iron":1})
				hud.toast("Tor gives up scrap bearing an old Vargan stamp.")
	save_manager.autosave(self)

func _handle_road_of_crows_clue(area) -> void:
	if not quests.is_active("main_road_of_crows"):
		return
	match area.interaction_id:
		"corpse":
			quests.complete_evidence("main_road_of_crows", "bram")
			story_state.set_flag("road_evidence_bram", true)
		"black_feathers":
			quests.complete_evidence("main_road_of_crows", "sella")
			story_state.set_flag("road_evidence_sella", true)
		"oren_token":
			quests.complete_evidence("main_road_of_crows", "oren")
			story_state.set_flag("road_evidence_oren", true)
		"claw_marks":
			quests.complete_evidence("main_road_of_crows", "vargan_wire")
			story_state.set_flag("road_evidence_vargan_wire", true)
		"tracks":
			quests.complete_evidence("main_road_of_crows", "drag_marks")
			story_state.set_flag("road_evidence_drag_marks", true)
			if quests.is_objective_done("main_road_of_crows", "fight_ghoulkin"):
				for evidence_id in ["bram", "sella", "oren", "vargan_wire"]:
					quests.complete_evidence("main_road_of_crows", evidence_id)

func _apply_campaign_arrival(zone_id: String) -> void:
	if zone_id in ["vargan_approach", "vargan_court", "record_hall"]:
		story_state.set_flag("castle_discovered", true)
		if not quests.is_unlocked("main_blood_under_stone"):
			quests.unlocked["main_blood_under_stone"] = true
		if not quests.is_active("main_blood_under_stone") and not quests.is_completed("main_blood_under_stone"):
			quests.start_quest("main_blood_under_stone")
	var arrivals := {
		"old_mill":["main_ash_at_the_mill","reach_mill"],
		"bandit_road":["main_soldier_without_banner","reach_bandit_road"],
		"vargan_approach":["main_blood_under_stone","reach_castle"],
		"vargan_court":["main_blood_under_stone","enter_courtyard"],
		"record_hall":["main_blood_under_stone","locate_record_hall"],
		"undercroft":["main_last_witness","reach_undercroft"],
		"assembly":["main_crowns_without_mercy","greyfen_assembly"],
		"hart_glade":["main_hart_remembers","enter_glade"]
	}
	if arrivals.has(zone_id):
		quests.complete_objective(arrivals[zone_id][0], arrivals[zone_id][1])

func _road_ready_to_report() -> bool:
	return quests.is_active("main_road_of_crows") and quests.is_objective_done("main_road_of_crows", "fight_ghoulkin") and not quests.is_objective_done("main_road_of_crows", "return_village")

func _crow_shrine_choice_ready() -> bool:
	return quests.is_active("main_bell_beneath_greyfen") \
		and quests.is_objective_done("main_bell_beneath_greyfen", "open_chapel") \
		and not quests.is_objective_done("main_bell_beneath_greyfen", "crow_shrine_choice")

func _chapel_can_open() -> bool:
	return quests.is_active("main_bell_beneath_greyfen") \
		and quests.is_objective_done("main_bell_beneath_greyfen", "grave_truth") \
		and quests.is_objective_done("main_bell_beneath_greyfen", "cemetery_ambush")

func _ensure_cemetery_ambush() -> void:
	if not quests.is_active("main_bell_beneath_greyfen"):
		return
	if not quests.is_objective_done("main_bell_beneath_greyfen", "grave_truth"):
		return
	if quests.is_objective_done("main_bell_beneath_greyfen", "cemetery_ambush"):
		return
	for enemy in active_enemies:
		if is_instance_valid(enemy) and bool(enemy.get_meta("act_one_cemetery_ambush", false)):
			return
	var ambusher = _spawn_enemy("ghoulkin", Vector3(14.2, 0.8, 5.4))
	if ambusher != null:
		ambusher.set_meta("act_one_cemetery_ambush", true)
		hud.show_status_cue("The grave soil breaks", "hurt")
		hud.set_guidance_hint("Defeat the Ghoulkin between the graves and chapel.", 5.0)
		audio.play_event("reveal", 0.02)

func _spawn_crow_shrine_choice() -> void:
	if not _crow_shrine_choice_ready() or zone_root == null:
		return
	if zone_root.find_child("crow_shrine_choice", true, false) != null:
		return
	_make_named_interactable("crow_shrine_choice", "dialogue", "Choose the Crow Shrine's fate", Vector3(6.5,0,-7.5), Color(0.3,0.38,0.3), Vector3(0.45,0.45,0.45))

func _relocate_anwen_to_cemetery() -> void:
	if zone_root == null:
		return
	var anwen = zone_root.find_child("sister_anwen", true, false)
	if anwen == null:
		return
	anwen.global_position = Vector3(11.0, 0, 4.8)
	anwen.set("prompt", "Meet Sister Anwen at the cemetery gate")
	anwen.rotation_degrees.y = 95.0

func _handle_dialogue_action(action: Dictionary) -> void:
	audio.stop_voice()
	audio.play_event("ui")
	var type = str(action.get("type", ""))
	if type == "start_quest":
		quests.start_quest(action.get("quest", ""))
		if action.get("quest", "") == "main_road_of_crows":
			audio.play_voice("voice_player_accept_contract_01")
	elif type == "complete_objective":
		quests.complete_objective(action.get("quest", ""), action.get("objective", ""))
		for id in action.get("sets_flags", {}):
			story_state.set_flag(str(id), action["sets_flags"][id])
		if str(action.get("quest", "")) == "main_teeth_in_rain" and str(action.get("objective", "")) == "speak_mira" and current_zone_id == "greyfen":
			if not _has_interactable("chapel_names"):
				_make_clue("chapel_names", "Read the erased names in the chapel", Vector3(15.0,0,8.2), "main_teeth_in_rain", "read_chapel_names", Color(0.44,0.39,0.31))
		if action.get("quest", "") == "main_road_of_crows" and action.get("objective", "") == "speak_anwen":
			hud.show_status_cue("Road of Crows updated", "item")
			hud.set_guidance_hint("Follow the old road: cart, clawed mud, black feathers.", 6.0)
	elif type == "give_ingredients":
		inventory.add_ingredients(action.get("items", {}))
		for id in action.get("sets_flags", {}):
			story_state.set_flag(str(id), action["sets_flags"][id])
		hud.toast("Supplies added.")
	elif type == "resolve_side_quest":
		var side_id := str(action.get("quest", ""))
		if quests.is_active(side_id):
			for objective in quests.active[side_id]["objectives"].duplicate(true):
				quests.complete_objective(side_id, str(objective["id"]))
			story_state.set_flag("%s_outcome" % side_id, str(action.get("outcome", "resolved")))
			hud.toast(str(action.get("result", "Greyfen will remember what you chose.")))
	elif type == "story_choice":
		if action.get("sets_flags", {}).has("crow_shrine_state") and str(story_state.get_flag("crow_shrine_state", "")) != "":
			hud.toast("The Crow Shrine has already answered Kael's choice.")
			return
		if action.get("sets_flags", {}).has("bog_core_fate") and str(story_state.get_flag("bog_core_fate", "")) != "":
			hud.toast("The memory core has already been given a fate.")
			return
		for id in action.get("sets_flags", {}):
			story_state.set_flag(str(id), action["sets_flags"][id])
		for id in action.get("adjusts_values", {}):
			story_state.adjust_value(str(id), int(action["adjusts_values"][id]))
		if action.has("quest") and action.has("objective"):
			quests.complete_objective(str(action["quest"]), str(action["objective"]))
		for completion in action.get("completes", []):
			quests.complete_objective(str(completion.get("quest", "")), str(completion.get("objective", "")))
		for item_id in action.get("gives_items", {}):
			inventory.add_item(str(item_id), int(action["gives_items"][item_id]))
		hud.toast(str(action.get("result", "Your choice will be remembered.")))
		if action.get("sets_flags", {}).has("crow_shrine_state"):
			hud.show_status_cue("The covenant changes", "victory")
			hud.set_guidance_hint("Speak with Mira. Ask what the dead remember.", 6.0)
			if active_interactable != null and str(active_interactable.get("interaction_id")) == "crow_shrine_choice":
				_mark_interaction_removed(active_interactable)
				active_interactable.queue_free()
				active_interactable = null
		elif action.get("sets_flags", {}).has("bog_core_fate"):
			hud.show_status_cue("Memory given a fate", "victory")
			hud.set_guidance_hint("Act One complete. The recovered names point deeper into Greyfen.", 6.0)
			if active_interactable != null and str(active_interactable.get("interaction_id")) == "bog_core_choice":
				_mark_interaction_removed(active_interactable)
				active_interactable.queue_free()
				active_interactable = null
		if str(action.get("quest", "")) == "main_blood_under_stone" and str(action.get("objective", "")) == "ledger_choice":
			story_state.set_flag("vargan_ledger_found", true)
			story_state.set_flag("vargan_ledger_choice_made", true)
			story_state.set_flag("record_hall_unlocked", true)
			hud.set_guidance_hint("The record hall is no longer empty. Stand ready.", 5.0)
	elif type == "ending":
		_complete_ending(action.get("ending", "expose"))
		return
	get_tree().paused = false
	hud.hide_menus()
	_refresh_tracker()
	if current_zone_id != "":
		_load_zone(current_zone_id, player.global_position)
	save_manager.autosave(self)

func _on_launch_accepted() -> void:
	audio.play_event("ui", 0.0)
	if not greyfen_prewarm_started and not game_started:
		greyfen_prewarm_started = true
		_prewarm_greyfen_after_menu_frame()

func _prewarm_greyfen_after_menu_frame() -> void:
	await get_tree().process_frame
	if game_started or zone_root != null or route_zone_cache.has("greyfen"):
		return
	var prewarm_service := ZoneSpatialService.new()
	prewarm_service.name = "GreyfenPrewarmSpatialService"
	add_child(prewarm_service)
	prewarm_service.configure("greyfen", _river_center("greyfen"), _zone_half_extents("greyfen"))
	spatial_service = prewarm_service
	zone_root = Node3D.new()
	zone_root.name = "greyfen"
	add_child(zone_root)
	runtime_light_count = 0
	tree_batch_data.clear()
	deadfall_batch_data.clear()
	prop_batch_data.clear()
	visual_box_batch_data.clear()
	terrain_patch_batch_data.clear()
	house_batch_data.clear()
	environment_batches_flushed = false
	var prewarm_build := ZoneCompositionRouter.build_core(self, "greyfen")
	if not bool(prewarm_build.get("ok", false)):
		push_error("Greyfen prewarm composition failed: %s" % ", ".join(prewarm_build.get("errors", [])))
		_retire_zone_root(zone_root)
		zone_root = null
		prewarm_service.queue_free()
		spatial_service = null
		return
	_flush_environment_batches()
	_add_visual_100_layer("greyfen")
	_apply_first_route_materials(zone_root)
	_validate_zone_render_resources(zone_root)
	prewarm_service.build_navigation(zone_root)
	greyfen_prewarm_spatial_service = prewarm_service
	# Kael's rig and camera are also expensive to instantiate in WebGL. Prepare
	# them while the launch/menu presentation is already covering the viewport.
	_spawn_player(Vector3(0, 1, 7))
	# Keep the body renderable behind the opaque menu so WebGL compiles its
	# skinned materials before New Game instead of on the first gameplay frame.
	player.visible = true
	player.process_mode = Node.PROCESS_MODE_DISABLED
	camera_rig.process_mode = Node.PROCESS_MODE_DISABLED
	var gameplay_camera := camera_rig.find_child("Camera3D", true, false) as Camera3D
	if gameplay_camera != null:
		gameplay_camera.current = false
	# Render one real 3D frame behind the opaque menu so Web/ANGLE compiles the
	# Greyfen materials before New Game is clicked.
	var prewarm_camera := Camera3D.new()
	prewarm_camera.name = "GreyfenPrewarmCamera"
	prewarm_camera.position = Vector3(0, 5.5, 13.0)
	prewarm_camera.rotation_degrees = Vector3(-17.0, 0.0, 0.0)
	prewarm_camera.current = true
	zone_root.add_child(prewarm_camera)
	zone_root.visible = true
	zone_root.process_mode = Node.PROCESS_MODE_DISABLED
	zone_root.position = Vector3.ZERO
	_set_zone_collision_enabled(zone_root, false)
	_cache_route_zone("greyfen", zone_root, [], _zone_state_signature(), true)
	zone_root = null
	spatial_service = null
	print("LOADING: Greyfen prewarmed behind main menu")

func _complete_ending(ending: String) -> void:
	if not quests.is_active("main_hart_remembers") or str(story_state.get_flag("confession_method", "")) == "":
		hud.toast("The Hart will not answer until Greyfen has heard the testimony.")
		get_tree().paused = false
		hud.hide_menus()
		return
	var witnesses: Array[String] = []
	if str(story_state.get_flag("halvern_fate", "")) == "witness":
		witnesses.append("halvern")
	if str(story_state.get_flag("edric_stance", "")) in ["cooperate", "compelled"]:
		witnesses.append("edric")
	if int(story_state.values.get("anwen_trust", 0)) >= 0:
		witnesses.append("anwen")
	if witnesses.is_empty():
		witnesses.append("kael")
	story_state.set_flag("final_witnesses", witnesses)
	quests.world_flags["ending"] = ending
	story_state.set_flag("final_covenant", {"expose":"witness", "free":"mercy", "bind":"duty", "kill":"ash"}.get(ending, ending))
	quests.complete_objective("main_hart_remembers", "hear_testimony")
	if ending == "kill" or ending == "bind":
		pending_ending = ending
		active_interactable = null
		hud.set_prompt("")
		hud.hide_menus()
		get_tree().paused = false
		_remove_interactable("white_hart")
		if not _has_living_enemy("white_hart_avatar"):
			var hart_boss = _spawn_enemy("white_hart_avatar", Vector3(0, 0.8, -7))
			if hart_boss != null:
				hart_boss.name = "WhiteHartFinalEncounter"
				hart_boss.leash_radius = 10.0
		audio.play_event("boss", 0.02)
		hud.toast("The White Hart answers with antler, root, and light.")
		return
	_show_ending_consequence(ending)

func _show_ending_consequence(ending: String) -> void:
	quests.world_flags["ending"] = ending
	quests.complete_objective("main_hart_remembers", "final_choice")
	var title = "The Road Between Crowns"
	var body = ""
	if ending == "kill":
		body = "Kael kills the White Hart after a brutal clearing fight. Greyfen survives the season, but the Wychwood fades into gray rot."
	elif ending == "free":
		body = "Kael frees the White Hart. The curse breaks, House Vargan falls, and frightened villagers abandon the old road."
	elif ending == "bind":
		body = "Kael breaks the avatar and binds the White Hart again. Greyfen prospers for now, and his name joins the crime beneath the stones."
	else:
		body = "Kael exposes House Vargan. The village turns on Edric, the spirit remains wounded, and truth finally has witnesses."
	body += "\n\nAnwen: %s. Greyfen: %s. The Hart's debt: %s." % [
		"trusted Kael" if int(story_state.values.get("anwen_trust",0)) > 0 else "kept her distance",
		"heard the names" if story_state.get_flag("names_policy","") == "published" else "learned the truth slowly",
		str(story_state.values.get("hart_debt",0))
	]
	get_tree().paused = true
	hud.show_ending(title, body)
	save_manager.checkpoint(self)

func _on_player_blade_contact(contact: Dictionary) -> void:
	var heavy := bool(contact.get("heavy", false))
	audio.play_event("heavy" if heavy else "swing")
	var result: Dictionary = combat.resolve_player_blade_contact(player, active_enemies, contact, inventory.active_oil)
	if bool(result.get("hit", false)):
		var target = result.get("enemy")
		if target != null and is_instance_valid(target) and target.health_component != null:
			hud.show_enemy(target.display_name, target.health_component.health, target.health_component.max_health)
			if target.enemy_id == "bog_wretch":
				if inventory.active_oil == "moon_oil":
					_expose_bog_core(target, "Moon Oil")
				elif heavy:
					_record_bog_stagger(target, "heavy blows")

func _on_player_beam_phase(phase: String) -> void:
	match phase:
		"sheathing": audio.play_event("oathfire_sheathe",0.02)
		"charging": audio.play_event("oathfire_charge",0.01)
		"releasing": audio.play_event("oathfire_release",0.015)

func _on_player_beam(charge_ratio: float, direction: Vector3) -> void:
	if player == null or zone_root == null:
		return
	_clear_oathfire_effects()
	var locked_direction: Vector3 = direction.normalized()
	var origin: Vector3 = player.get_oathfire_origin() if player.has_method("get_oathfire_origin") else player.global_position + Vector3(0, 1.12, 0) + locked_direction * 0.62
	var beam_range: float = 12.0 + progression.effect_value("beam_range_bonus", 0.0)
	var endpoint: Vector3 = origin + locked_direction * beam_range
	var query = PhysicsRayQueryParameters3D.create(origin, endpoint)
	var beam_exclusions: Array[RID] = [player.get_rid()]
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			beam_exclusions.append(enemy.get_rid())
	query.exclude = beam_exclusions
	query.collide_with_areas = false
	var result = get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		endpoint = result.position
	var damage: float = lerpf(35.0, 70.0, charge_ratio)
	var cast := {
		"origin": origin,
		"direction": locked_direction,
		"endpoint": endpoint,
		"width": 1.2,
		"damage": damage,
		"charge_ratio": charge_ratio
	}
	var hits: Array = combat.resolve_oathfire_cast(active_enemies, cast)
	set_meta("last_oathfire_cast", cast)
	set_meta("last_oathfire_hit_count", hits.size())
	audio.play_event("heavy", 0.03)
	_make_oathfire_beam(origin, endpoint, charge_ratio, not _performance_mode())
	if camera_rig != null:
		camera_rig.shake(0.12 + 0.08 * charge_ratio)
	CombatFeedback.ground_ring(zone_root, player.global_position, Color(0.18, 0.72, 0.95), 0.75, 0.18)
	CombatFeedback.impact_burst(zone_root, origin, false, Color(0.62, 0.95, 1.0))
	CombatFeedback.impact_burst(zone_root, endpoint, true, Color(0.26, 0.82, 1.0))
	for enemy in hits:
		CombatFeedback.impact_burst(zone_root, enemy.global_position + Vector3(0, 0.9, 0), true, Color(0.30, 0.88, 1.0))
	hud.show_status_cue("Oathfire Beam", "item")

func _make_oathfire_beam(origin: Vector3, endpoint: Vector3, charge_ratio: float, rich_effect: bool) -> void:
	var length = origin.distance_to(endpoint)
	if length <= 0.05:
		return
	var root = Node3D.new()
	root.name = "OathfireBeamEffect"
	root.add_to_group("oathfire_runtime_effect")
	zone_root.add_child(root)
	root.global_position = origin.lerp(endpoint, 0.5)
	root.look_at(endpoint, Vector3.UP)
	var core = MeshInstance3D.new()
	var core_mesh = CylinderMesh.new()
	core_mesh.top_radius = 0.18+charge_ratio*0.10
	core_mesh.bottom_radius = 0.30+charge_ratio*0.14
	core_mesh.height = length
	core_mesh.radial_segments = 12
	core.mesh = core_mesh
	core.rotation_degrees.x = 90.0
	core.name = "OathfireBeamCore"
	core.material_override = _oathfire_material(Color(0.72, 0.96, 1.0, 0.96), 2.8)
	root.add_child(core)
	if rich_effect:
		var aura = MeshInstance3D.new()
		var aura_mesh = CylinderMesh.new()
		aura_mesh.top_radius = 0.42+charge_ratio*0.16
		aura_mesh.bottom_radius = 0.58+charge_ratio*0.20
		aura_mesh.height = length*0.98
		aura_mesh.radial_segments = 12
		aura.mesh = aura_mesh
		aura.rotation_degrees.x = 90.0
		aura.name = "OathfireBeamAura"
		aura.material_override = _oathfire_material(Color(0.16, 0.66, 1.0, 0.30), 1.5)
		root.add_child(aura)
		var inner = MeshInstance3D.new()
		var inner_mesh = CylinderMesh.new()
		inner_mesh.top_radius = 0.07 + charge_ratio * 0.04
		inner_mesh.bottom_radius = 0.10 + charge_ratio * 0.05
		inner_mesh.height = length * 1.01
		inner_mesh.radial_segments = 10
		inner.mesh = inner_mesh
		inner.rotation_degrees.x = 90.0
		inner.name = "OathfireBeamHotCore"
		inner.material_override = _oathfire_material(Color(0.94, 1.0, 1.0, 1.0), 4.2)
		root.add_child(inner)
	root.scale = Vector3(0.04,0.04,0.08)
	var tween = create_tween()
	tween.tween_property(root,"scale",Vector3.ONE,0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.16)
	tween.tween_property(root,"scale",Vector3(0.08,0.08,1.0),0.18)
	tween.tween_callback(root.queue_free)

func _clear_oathfire_effects() -> void:
	for effect in get_tree().get_nodes_in_group("oathfire_runtime_effect"):
		if is_instance_valid(effect):
			effect.queue_free()

func _oathfire_material(color: Color, energy: float) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = energy
	return material

func _on_player_footstep() -> void:
	if audio == null or player == null:
		return
	var on_road = abs(player.global_position.x) < 2.25
	if current_zone_id == "wychwood":
		on_road = abs(player.global_position.x) < 2.5 and player.global_position.z > -12.5
	audio.play_footstep(current_zone_id, on_road)

func _on_player_parried() -> void:
	if progression != null and player != null:
		player.stamina_component.restore(progression.effect_value("parry_stamina_restore", 0.0))
	tutorial_flags["block_hint_done"] = true
	hud.set_guidance_hint("")

func _on_player_blocked(_amount: float) -> void:
	audio.play_event("block")
	if input_router != null:
		input_router.rumble(0.18, 0.32, 0.08)
	if camera_rig != null:
		camera_rig.shake(0.08)
	if zone_root != null and player != null:
		CombatFeedback.block_flash(zone_root, player.global_position, false)
		CombatFeedback.ground_ring(zone_root, player.global_position, Color(0.58, 0.36, 0.12), 0.45, 0.12)
	hud.show_status_cue("Blocked", "block")
	tutorial_flags["block_hint_done"] = true
	hud.set_guidance_hint("")

func _on_player_hurt(_amount: float) -> void:
	audio.play_event("hurt")
	if input_router != null:
		input_router.rumble(0.36, 0.58, 0.14)
	if camera_rig != null:
		camera_rig.shake(0.14)
	if zone_root != null and player != null:
		CombatFeedback.impact_burst(zone_root, player.global_position + Vector3(0, 1.0, 0), false, Color(0.9, 0.22, 0.12))
	hud.show_status_cue("Hit: -%d" % int(_amount), "hurt")

func _on_player_stamina_exhausted(_action: String) -> void:
	hud.mark_stamina_exhausted()
	hud.set_guidance_hint("Breath is spent. Back away, then strike.", 2.8)

func _use_potion() -> void:
	if inventory.consume("redroot_potion"):
		player.health_component.heal(45.0 + progression.effect_value("potion_heal_bonus", 0.0))
		audio.play_event("potion")
		hud.show_status_cue("Redroot used", "item")
		hud.toast("Redroot warms the blood.")
		_refresh_equipment_readout()
	else:
		hud.show_status_cue("No Redroot", "hurt")

func _throw_bomb() -> void:
	if inventory.consume("ash_bomb"):
		audio.play_event("bomb")
		if camera_rig != null:
			camera_rig.shake(0.12)
		combat.throw_bomb(player, active_enemies, 45.0)
		for enemy in active_enemies:
			if is_instance_valid(enemy) and not enemy.dead and enemy.enemy_id == "bog_wretch" and enemy.global_position.distance_to(player.global_position) <= 6.5:
				_expose_bog_core(enemy, "Ash Bomb")
		hud.show_status_cue("Ash Bomb thrown", "item")
		_refresh_equipment_readout()
	else:
		hud.show_status_cue("No Ash Bomb", "hurt")

func _use_inventory_item(item_id: String) -> void:
	if item_id == "redroot_potion":
		_use_potion()
	elif item_id == "bitterleaf_tonic":
		if inventory.consume("bitterleaf_tonic"):
			player.stamina_component.restore(55.0)
			audio.play_event("potion")
			hud.show_status_cue("Bitterleaf used", "item")
			hud.toast("Bitterleaf clears the lungs.")
	elif item_id == "ash_bomb":
		_throw_bomb()
	elif item_id == "moon_oil" or item_id == "rot_oil":
		if not inventory.apply_oil(item_id):
			return
		_refresh_equipment_readout()
		hud.show_status_cue("Oil applied", "item")
		hud.toast("%s slicks the blade." % inventory.get_item_name(item_id))
	elif item_id == "iron_trap":
		if inventory.consume("iron_trap"):
			combat.place_trap(player, active_enemies)
			hud.show_status_cue("Iron Trap set", "item")
			_refresh_equipment_readout()

func _on_enemy_died(enemy) -> void:
	audio.play_event("death", 0.05)
	if camera_rig != null:
		camera_rig.shake(0.09)
	if zone_root != null and enemy != null:
		CombatFeedback.ground_ring(zone_root, enemy.global_position, Color(0.12, 0.08, 0.055), 0.9, 0.24)
	if current_zone_id == "greyfen" and bool(enemy.get_meta("act_one_cemetery_ambush", false)):
		quests.complete_objective("main_bell_beneath_greyfen", "cemetery_ambush")
		story_state.set_flag("cemetery_ambush_cleared", true)
		hud.hide_enemy()
		hud.show_status_cue("The graves fall still", "victory")
		hud.set_guidance_hint("Open the ruined Crow Chapel.", 5.0)
		hud.toast("The Ghoulkin carried grave soil beneath its nails. The chapel seal answers its death.")
	elif current_zone_id == "wychwood" and enemy.enemy_id in ["ghoulkin", "wychwood_stalker", "wychwood_raider", "wychwood_brute"]:
		wychwood_pack_kills += 1
		if wychwood_pack_kills == 1:
			_activate_wychwood_wave(["ghoulkin"], "A second Ghoulkin answers from the trees.")
		elif wychwood_pack_kills == 2:
			_activate_wychwood_wave(["wychwood_stalker", "wychwood_raider"], "Branches snap on both flanks.")
		elif wychwood_pack_kills == 4:
			_activate_wychwood_wave(["wychwood_brute"], "The earth heaves. The Brute comes last.")
		if wychwood_pack_kills >= 5:
			quests.complete_objective("main_road_of_crows", "fight_ghoulkin")
			story_state.set_flag("wychwood_pack_cleared", true)
			audio.play_event("victory", 0.03)
			audio.play_music_cue("victory_return_cue", "return_report")
			audio.set_music_state("return_report")
			audio.play_voice("voice_player_ghoulkin_death_01")
			hud.hide_enemy()
			hud.show_status_cue("Wychwood pack broken", "victory")
			hud.set_guidance_hint("Inspect the tracks, then return to Greyfen.", 6.0)
			hud.toast("The Ghoulkin dies too far from its den. Something drew it to the road. Search the tracks.")
			_make_post_ghoulkin_story_clue()
	elif enemy.enemy_id == "bog_wretch":
		quests.complete_objective("main_teeth_in_rain", "fight_bog_wretch")
		story_state.set_flag("bog_memory_core_revealed", true)
		if not bool(story_state.get_flag("bog_core_exposed", false)):
			story_state.set_flag("bog_core_forced_open", true)
		_make_named_interactable("bog_core_choice", "dialogue", "Choose the memory core's fate", enemy.global_position, Color(0.35, 0.58, 0.52), Vector3(0.4, 0.4, 0.4))
		hud.show_status_cue("A memory remains", "victory")
		hud.set_guidance_hint("Inspect the Bog Wretch's exposed memory core.", 5.0)
	elif enemy.enemy_id == "wychwood_stalker" and current_zone_id == "record_hall":
		story_state.set_flag("castle_haunting_cleared", true)
		quests.complete_objective("main_blood_under_stone", "survive_haunting")
		hud.toast("The erased names settle. Edric waits beneath the Vargan seal.")
		hud.set_guidance_hint("Demand Lord Edric's answer before descending.", 6.0)
		_load_zone("record_hall", player.global_position)
	elif enemy.enemy_id == "gravebound_knight":
		if current_zone_id == "undercroft":
			quests.complete_objective("main_last_witness", "break_halvern_guard")
		if current_zone_id == "ruins" and quests.is_unlocked("main_hart_remembers"):
			_make_named_interactable("white_hart", "dialogue", "Speak to the White Hart", Vector3(12, 0, 10), Color(0.86, 0.83, 0.70), Vector3(0.36, 0.64,0.36))
	elif enemy.enemy_id == "white_hart_avatar":
		var ending = pending_ending if pending_ending != "" else "kill"
		pending_ending = ""
		_show_ending_consequence(ending)
	elif enemy.enemy_id == "bandit":
		if current_zone_id == "bandit_road" and bool(enemy.get_meta("senn_guard", false)) and not _has_living_enemy("bandit"):
			quests.complete_objective("main_soldier_without_banner", "senn_confrontation")
			story_state.set_flag("senn_ready_to_testify", true)
			hud.show_status_cue("Senn's guard breaks", "victory")
			hud.set_guidance_hint("Captain Senn has lowered his blade. Hear his testimony.", 5.5)
		elif not _has_living_enemy("bandit"):
			quests.complete_objective("side_black_dog", "find_dog")
	elif current_zone_id == "old_mill" and bool(enemy.get_meta("ash_mill_enemy", false)):
		var ash_enemy_alive := false
		for candidate in active_enemies:
			if is_instance_valid(candidate) and candidate != enemy and not candidate.dead and bool(candidate.get_meta("ash_mill_enemy", false)):
				ash_enemy_alive = true
				break
		if not ash_enemy_alive:
			quests.complete_objective("main_ash_at_the_mill", "mill_encounter")
			story_state.set_flag("ash_mill_cleared", true)
			_make_named_interactable("miller_record", "dialogue", "Read the miller's record", Vector3(-7.0,0,-7), Color(0.5,0.4,0.25))
			hud.show_status_cue("The mill falls quiet", "victory")
			hud.set_guidance_hint("Read the miller's ledger beside the broken wall.", 5.5)
	if enemy.health_component != null:
		hud.show_enemy(enemy.display_name, 0.0, enemy.health_component.max_health)
	hud.toast("%s slain." % enemy.display_name)
	save_manager.autosave(self)

func _on_enemy_damaged(enemy, current: float, maximum: float) -> void:
	hud.show_enemy(enemy.display_name, current, maximum)
	hud.show_status_cue("Enemy hit", "item")
	if enemy != null and enemy.enemy_id == "ghoulkin":
		audio.play_event("stagger", 0.06)

func _on_enemy_windup_started(enemy) -> void:
	audio.play_event("enemy_windup", 0.02)
	if zone_root != null and enemy != null:
		CombatFeedback.ground_ring(zone_root, enemy.global_position, Color(0.46, 0.05, 0.025), 0.62, 0.18)
	if enemy != null and enemy.health_component != null:
		hud.show_enemy(enemy.display_name, enemy.health_component.health, enemy.health_component.max_health)
	if current_zone_id == "wychwood" and not bool(tutorial_flags.get("block_hint_done", false)):
		hud.set_guidance_hint("Tap Q at the lunge to parry. Hold Q to block.", 4.2)

func _on_enemy_attack_resolved(enemy, parried: bool, contact_position: Vector3) -> void:
	if parried:
		audio.play_event("parry")
		if input_router != null:
			input_router.rumble(0.24, 0.52, 0.10)
		if camera_rig != null:
			camera_rig.shake(0.18)
		if zone_root != null:
			CombatFeedback.block_flash(zone_root, player.global_position, true)
			CombatFeedback.impact_burst(zone_root, contact_position, true, Color(0.74, 0.88, 1.0))
			CombatFeedback.ground_ring(zone_root, player.global_position, Color(0.22, 0.46, 0.72), 0.65, 0.16)
		hud.show_status_cue("Parry", "parry")
		hud.toast("Parry breaks %s's guard." % enemy.display_name)
		if enemy != null and enemy.enemy_id == "bog_wretch":
			_record_bog_stagger(enemy, "parries")
	else:
		audio.play_event("ghoulkin_lunge" if enemy != null and enemy.enemy_id == "ghoulkin" else "hit", 0.04)
		if zone_root != null and enemy != null:
			CombatFeedback.impact_burst(zone_root, contact_position, false, Color(0.85, 0.30, 0.12))
	if enemy != null and enemy.health_component != null:
		hud.show_enemy(enemy.display_name, enemy.health_component.health, enemy.health_component.max_health)

func _on_quest_completed(id: String) -> void:
	if id == "main_bell_beneath_greyfen":
		story_state.set_flag("teeth_in_rain_available", true)
	if id == "main_teeth_in_rain":
		story_state.set_flag("teeth_in_rain_completed", true)
		story_state.set_flag("deep_wychwood_passage", true)
	if id == "main_blood_under_stone":
		story_state.set_flag("blood_under_stone_completed", true)
	var reward = quests.quest_defs.get(id, {}).get("rewards", {})
	progression.award_for_quest(id, str(quests.quest_defs.get(id, {}).get("type", "")))
	if not reward.is_empty():
		inventory.add_reward(reward)
		hud.toast("Reward received for %s." % quests.quest_defs.get(id, {}).get("title", id))
	save_manager.checkpoint(self)

func _apply_progression_to_player() -> void:
	if player != null and progression != null:
		player.set_progression(progression)

func _record_bog_stagger(enemy, source: String) -> void:
	var count := int(story_state.get_flag("bog_stagger_hits", 0)) + 1
	story_state.set_flag("bog_stagger_hits", count)
	if count >= 2:
		_expose_bog_core(enemy, source)

func _expose_bog_core(enemy, method: String) -> void:
	if enemy == null or not is_instance_valid(enemy) or enemy.enemy_id != "bog_wretch":
		return
	if bool(story_state.get_flag("bog_core_exposed", false)):
		return
	story_state.set_flag("bog_core_exposed", true)
	story_state.set_flag("bog_core_exposure_method", method)
	enemy.stagger(1.15)
	hud.show_status_cue("Memory core exposed", "victory")
	hud.toast("%s tears the dead memory loose from the Wretch's hide." % method)
	audio.play_event("reveal", 0.035)

func _on_combat_impact(pos: Vector3, heavy: bool) -> void:
	if audio != null:
		audio.play_event("heavy_hit" if heavy else "light_hit", 0.04)
	if camera_rig != null:
		camera_rig.shake(0.11 if heavy else 0.06)
	_make_hit_spark(pos, heavy)
	if zone_root != null:
		CombatFeedback.ground_ring(zone_root, pos, Color(0.54, 0.36, 0.16), 0.42 if heavy else 0.30, 0.12)

func _hitstop(seconds: float) -> void:
	Engine.time_scale = 0.18
	var timer = get_tree().create_timer(seconds, true, false, true)
	timer.timeout.connect(func(): Engine.time_scale = 1.0)

func _has_living_enemy(enemy_id: String) -> bool:
	for enemy in active_enemies:
		if enemy != null and not enemy.dead and enemy.enemy_id == enemy_id:
			return true
	return false

func _nearest_living_enemy(max_distance: float):
	var best = null
	var best_distance = max_distance
	for enemy in active_enemies:
		if enemy == null or enemy.dead:
			continue
		var dist = enemy.global_position.distance_to(player.global_position)
		if dist < best_distance:
			best_distance = dist
			best = enemy
	return best

func _remove_interactable(id: String) -> void:
	if zone_root == null:
		return
	for child in zone_root.get_children():
		if child.get("interaction_id") == id:
			child.queue_free()

func _has_interactable(id: String) -> bool:
	if zone_root == null:
		return false
	for child in zone_root.get_children():
		if str(child.name) == id or str(child.get("interaction_id")) == id:
			return true
	return false

func _mark_interaction_removed(area) -> void:
	removed_interactions["%s:%s" % [current_zone_id, area.interaction_id]] = true

func _is_interaction_removed(id: String) -> bool:
	return bool(removed_interactions.get("%s:%s" % [current_zone_id, id], false))

func save_world_state() -> Dictionary:
	return {
		"removed_interactions": removed_interactions,
		"pending_ending": pending_ending,
		"wychwood_pack_kills": wychwood_pack_kills,
		"ghoulkin_kills": wychwood_pack_kills,
		"day_night": day_night.save_state() if day_night != null else {}
	}

func load_world_state(state: Dictionary) -> void:
	removed_interactions = state.get("removed_interactions", {})
	pending_ending = str(state.get("pending_ending", ""))
	wychwood_pack_kills = int(state.get("wychwood_pack_kills", state.get("ghoulkin_kills", wychwood_pack_kills)))
	if day_night != null:
		day_night.load_state(state.get("day_night", {}))

func _on_player_died() -> void:
	audio.play_event("hurt")
	get_tree().paused = true
	hud.show_death_screen("The road keeps its dead.\n\nLoad Last Checkpoint returns Kael to the last safe contract marker with quest progress preserved.")

func _pause_game() -> void:
	get_tree().paused = true
	paused_by_menu = true
	audio.play_event("ui")
	hud.show_pause_menu()

func _resume_game() -> void:
	get_tree().paused = false
	paused_by_menu = false
	audio.play_event("ui")
	hud.hide_menus()

func _handle_setting(action: String) -> void:
	audio.play_event("ui")
	if action == "render_scale":
		settings.cycle_resolution_scale()
	elif action == "shadows":
		settings.cycle_shadows()
	elif action == "vsync":
		settings.toggle_vsync()
	elif action == "fullscreen":
		settings.toggle_fullscreen()
	elif action == "potato":
		settings.set_potato_mode(not bool(settings.settings["potato_mode"]))
	elif action == "visual_preset":
		var preset = settings.cycle_quality_preset()
		hud.toast("Visual preset: %s" % preset.capitalize())
		if game_started and player != null:
			_load_zone(current_zone_id, player.global_position)
	elif action == "mouse_sensitivity":
		settings.cycle_mouse_sensitivity()
	elif action == "gamepad_sensitivity":
		settings.cycle_gamepad_look_sensitivity()
	elif action == "gamepad_vibration":
		settings.toggle_gamepad_vibration()
	elif action == "touch_controls":
		settings.cycle_touch_controls()
	elif action == "touch_sensitivity":
		settings.cycle_touch_look_sensitivity()
	elif action == "invert_y":
		settings.toggle_invert_y()
	elif action == "volume":
		settings.cycle_master_volume()
	elif action == "subtitle_scale":
		settings.cycle_subtitle_scale()
	elif action == "camera_shake":
		settings.cycle_camera_shake()
	elif action == "reduced_motion":
		settings.toggle_reduced_motion()
	if action != "visual_preset":
		hud.toast("Settings updated.")
	hud.show_settings_menu(hud.controls_back_target)

func _apply_runtime_settings(current_settings: Dictionary) -> void:
	if audio != null:
		audio.set_master_volume(float(current_settings.get("master_volume", 0.85)))
	if camera_rig != null:
		camera_rig.apply_settings(
			float(current_settings.get("mouse_sensitivity", 0.003)),
			bool(current_settings.get("invert_y", false)),
			float(current_settings.get("gamepad_look_sensitivity", 1.0))
		)
		camera_rig.shake_decay = 1000.0 if float(current_settings.get("camera_shake", 1.0)) <= 0.0 else 6.0 / maxf(float(current_settings.get("camera_shake", 1.0)), 0.5)
	if hud != null:
		hud.apply_accessibility(float(current_settings.get("subtitle_scale", 1.0)))
	if visual_director != null and visual_director.sun != null:
		visual_director.apply_settings(current_settings)
		visual_director.sun.shadow_enabled = int(current_settings.get("shadow_quality", 1)) > 0
		visual_director.sun.directional_shadow_max_distance = 42.0

func _refresh_tracker() -> void:
	hud.set_tracker(quests.get_tracker_text())
	_update_compass()

func _refresh_equipment_readout() -> void:
	if hud == null or inventory == null:
		return
	var oil_name = ""
	if inventory.active_oil != "":
		oil_name = inventory.get_item_name(inventory.active_oil)
	hud.update_equipment(int(inventory.items.get("redroot_potion", 0)), int(inventory.items.get("ash_bomb", 0)), oil_name)

func _update_tutorial_prompts() -> void:
	if player == null:
		return
	if active_interactable != null and not bool(tutorial_flags.get("interact", false)):
		tutorial_flags["interact"] = true
		hud.toast("Press E to interact. In menus and dialogue, use the mouse pointer.")
	if current_zone_id == "greyfen" and not bool(tutorial_flags.get("route", false)) and player.global_position.z < -8.0:
		tutorial_flags["route"] = true
		audio.play_event("cloth_wind", 0.03)
		audio.set_music_state("wychwood_tension")
		hud.toast("The village noise thins behind you. The old road keeps its own silence.")
		hud.set_guidance_hint("Wychwood gate ahead. Stay on the lit road.", 4.5)
	if current_zone_id == "greyfen" and not bool(tutorial_flags.get("shrine_audio", false)) and player.global_position.distance_to(Vector3(6.0, player.global_position.y, -7.0)) < 5.0:
		tutorial_flags["shrine_audio"] = true
		audio.set_music_state("shrine_anwen")
		audio.play_event("shrine_hum", 0.005)
		audio.play_event("shrine_candle", 0.02)
		audio.play_event("shrine_bell", 0.01)
	if current_zone_id == "wychwood" and not bool(tutorial_flags.get("clearing_tension", false)) and player.global_position.z < 1.0:
		tutorial_flags["clearing_tension"] = true
		audio.set_music_state("wychwood_tension")
		audio.play_event("wychwood_drop", 0.01)
		audio.play_event("wychwood_tension", 0.02)
	if current_zone_id == "wychwood" and not bool(tutorial_flags.get("near_clearing_audio", false)) and player.global_position.z < -4.0:
		tutorial_flags["near_clearing_audio"] = true
		audio.play_event("ghoulkin_idle", 0.03)
	if current_zone_id == "wychwood" and active_enemies.size() > 0 and not bool(tutorial_flags.get("combat", false)):
		tutorial_flags["combat"] = true
		audio.set_music_state("ghoulkin_combat")
		audio.play_event("wychwood_tension", 0.01)
		hud.toast("Survive the Ghoulkin.")
		hud.set_guidance_hint("Left click strike | Space dodge | Tap Q parry | Hold Q block", 6.0)

func _update_compass() -> void:
	if hud == null or player == null:
		return
	var zone_name = {"greyfen":"Greyfen", "wychwood":"The Wychwood", "ruins":"Castle Vargan", "deep_wood":"Deep Wychwood", "old_mill":"The Ash Mill", "burned_farmstead":"Burned Farmstead", "marsh_crossing":"Marsh Crossing", "bandit_road":"The Long Road", "vargan_approach":"Castle Vargan Approach", "vargan_court":"Castle Vargan Courtyard", "record_hall":"Vargan Record Hall", "undercroft":"Vargan Undercroft", "assembly":"Greyfen Assembly", "hart_glade":"White Hart Glade"}.get(current_zone_id, "The Road Between Crowns")
	hud.set_compass("%s | %s" % [zone_name, _nearest_interactable_summary()])

func _nearest_interactable_summary() -> String:
	if zone_root == null:
		return "No marker"
	var best_text = "No marker"
	var best_score = 9999.0
	var tracked_id: String = quests.get_tracked_quest() if quests.has_method("get_tracked_quest") else ""
	var tracked_objective := _tracked_objective_id(tracked_id)
	var found_tracked_target := false
	for child in zone_root.get_children():
		if not child.has_method("get_overlapping_bodies"):
			continue
		var interaction_id = child.get("interaction_id")
		if interaction_id == null or str(interaction_id) == "":
			continue
		if not child.is_inside_tree():
			continue
		var dist = child.global_position.distance_to(player.global_position)
		var score: float = float(dist)
		var quest_id = child.get("quest_id")
		var objective_id = child.get("objective_id")
		if tracked_id != "" and quest_id != null and str(quest_id) == tracked_id:
			if tracked_objective != "" and objective_id != null and str(objective_id) == tracked_objective:
				score -= 120.0
				found_tracked_target = true
			else:
				# Do not let later or optional quest markers contradict the tracked objective.
				score += 50.0
		elif quest_id != null and str(quest_id) != "" and quests.is_active(str(quest_id)):
			score += 80.0
		elif str(child.get("interaction_type")) == "dialogue":
			score += 10.0
		if tracked_id == "main_road_of_crows" and tracked_objective == "speak_anwen" and str(interaction_id) == "sister_anwen":
			score -= 120.0
			found_tracked_target = true
		if str(child.get("interaction_type")) == "zone":
			score -= 4.0
		if score < best_score:
			best_score = score
			best_text = "%s %dm" % [child.get("prompt"), int(dist)]
	if tracked_objective != "" and not found_tracked_target:
		return _tracked_objective_text(tracked_id, tracked_objective)
	return best_text

func _tracked_objective_id(quest_id: String) -> String:
	if quest_id == "" or not quests.active.has(quest_id):
		return ""
	for objective in quests.active[quest_id].get("objectives", []):
		if not bool(objective.get("done", false)):
			return str(objective.get("id", ""))
	return ""

func _tracked_objective_text(quest_id: String, objective_id: String) -> String:
	if not quests.active.has(quest_id):
		return "Follow the road"
	for objective in quests.active[quest_id].get("objectives", []):
		if str(objective.get("id", "")) == objective_id:
			return str(objective.get("text", "Follow the road")).trim_suffix(".")
	return "Follow the road"

func _keep_player_in_world() -> void:
	if player == null:
		return
	if _is_river_recovery_position(current_zone_id, player.global_position):
		_recover_from_river(player, _river_center(current_zone_id), 3.4)
		return
	var half = _zone_half_extents(current_zone_id)
	if player.global_position.y > -2.0 and abs(player.global_position.x) < half.x - 1.5 and abs(player.global_position.z) < half.y - 1.5:
		last_safe_player_position = player.global_position
		return
	if player.global_position.y < -8.0 or abs(player.global_position.x) > half.x + 4.0 or abs(player.global_position.z) > half.y + 4.0:
		player.global_position = last_safe_player_position + Vector3(0, 1.2, 0)
		player.velocity = Vector3.ZERO
		hud.toast("Kael catches himself before the dark takes him.")

func _safe_loaded_position(zone: String, pos: Vector3) -> Vector3:
	var river_z := _river_center(zone)
	# The bridge deck is valid walkable space even though its collision sits below the capsule.
	if river_z < 900.0 and absf(pos.x) < 2.0 and absf(pos.z - river_z) <= 2.25 and pos.y >= 0.18:
		return pos
	if spatial_service != null and spatial_service.zone_id == zone:
		return spatial_service.nearest_safe(pos, spatial_service.bank_for(pos))
	var validator = ZoneSpatialService.new()
	validator.configure(zone, _river_center(zone), _zone_half_extents(zone))
	return validator.nearest_safe(pos, validator.bank_for(pos))

func validate_walkable_position(pos: Vector3) -> Vector3:
	if spatial_service != null:
		return spatial_service.validate_position(pos, 0.90)
	var safe := river_safe_position(pos, 0.90)
	safe.x = clampf(safe.x, -18.5, 18.5)
	safe.z = clampf(safe.z, -14.5, 14.5)
	safe.y = 0.0
	return safe

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
	if zone == "greyfen":
		return 4.5
	if zone == "wychwood":
		return 0.0
	return 999.0

func _is_river_recovery_position(zone: String, pos: Vector3) -> bool:
	var river_z := _river_center(zone)
	if river_z > 900.0:
		return false
	return absf(pos.z-river_z) < 2.0 and (absf(pos.x) > 2.7 or pos.y < 0.12)

func _is_river_excluded(pos: Vector3, margin: float = 0.0) -> bool:
	var river_z := _river_center()
	return river_z < 900.0 and absf(pos.z-river_z) < 2.25 + margin

func river_safe_position(pos: Vector3, margin: float = 0.55) -> Vector3:
	if spatial_service != null:
		return spatial_service.validate_position(pos, margin)
	if not _is_river_excluded(pos, margin):
		return pos
	var river_z := _river_center()
	var side := -1.0 if pos.z <= river_z else 1.0
	pos.z = river_z + side * (2.25 + margin)
	return pos

func river_safe_path(points: Array, margin: float = 0.90) -> Array:
	if spatial_service != null:
		return spatial_service.validate_path(points, margin)
	var sanitized: Array = []
	if points.is_empty():
		return sanitized
	for point in points:
		var safe_point: Vector3 = river_safe_position(point, margin)
		if sanitized.is_empty():
			sanitized.append(safe_point)
			continue
		var previous: Vector3 = sanitized.back()
		var river_z := _river_center()
		var crosses_banks := river_z < 900.0 and (previous.z-river_z) * (safe_point.z-river_z) < 0.0
		if crosses_banks:
			var north_z := river_z - (2.25 + margin)
			var south_z := river_z + (2.25 + margin)
			var entry_z := north_z if previous.z < river_z else south_z
			var exit_z := south_z if previous.z < river_z else north_z
			sanitized.append(Vector3(0.0, maxf(previous.y,0.55), entry_z))
			sanitized.append(Vector3(0.0, 0.55, river_z))
			sanitized.append(Vector3(0.0, maxf(safe_point.y,0.55), exit_z))
		sanitized.append(safe_point)
	return sanitized

func _zone_half_extents(zone_id: String) -> Vector2:
	if zone_id == "wychwood":
		return Vector2(22, 17)
	if zone_id == "greyfen":
		return Vector2(21, 17)
	return Vector2(24, 21)

func _make_play_area_bounds(width: float, depth: float, color: Color) -> void:
	var half_w = width * 0.5
	var half_d = depth * 0.5
	_make_prop_box("NorthBerm", Vector3(0, 0.9, -half_d), Vector3(width, 1.8, 1.2), color)
	_make_prop_box("SouthBerm", Vector3(0, 0.9, half_d), Vector3(width, 1.8, 1.2), color)
	_make_prop_box("WestBerm", Vector3(-half_w, 0.9, 0), Vector3(1.2, 1.8, depth), color)
	_make_prop_box("EastBerm", Vector3(half_w, 0.9, 0), Vector3(1.2, 1.8, depth), color)
	_make_invisible_wall(Vector3(0, 1.6, -half_d - 0.65), Vector3(width, 3.2, 0.4))
	_make_invisible_wall(Vector3(0, 1.6, half_d + 0.65), Vector3(width, 3.2, 0.4))
	_make_invisible_wall(Vector3(-half_w - 0.65, 1.6, 0), Vector3(0.4, 3.2, depth))
	_make_invisible_wall(Vector3(half_w + 0.65, 1.6, 0), Vector3(0.4, 3.2, depth))

func _make_invisible_wall(pos: Vector3, size: Vector3) -> void:
	var body = StaticBody3D.new()
	body.name = "WorldBoundary"
	body.position = pos
	zone_root.add_child(body)
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)

func _make_greyfen_terrain_layers() -> void:
	_make_terrain_patch("GreyfenVillageGreen", Vector3(-9.5, 0.012, -4.0), Vector3(11.5, 0.035, 8.0), Color(0.095, 0.145, 0.085))
	_make_terrain_patch("GreyfenShrineRise", Vector3(6.0, 0.038, -7.0), Vector3(7.4, 0.08, 5.2), Color(0.105, 0.125, 0.095))
	_make_terrain_patch("GreyfenCemeterySoil", Vector3(14.0, 0.028, 8.6), Vector3(8.0, 0.045, 5.0), Color(0.095, 0.090, 0.078))
	_make_terrain_patch("GreyfenBlacksmithYard", Vector3(9.5, 0.026, 4.5), Vector3(7.0, 0.045, 5.2), Color(0.115, 0.095, 0.072))
	for z in [-12.0, -8.0, -4.0, 0.0, 4.0, 8.0, 12.0]:
		_make_terrain_patch("GreyfenRoadShoulder", Vector3(-3.4, 0.024, z), Vector3(1.2, 0.032, 2.6), Color(0.095, 0.105, 0.075))
		_make_terrain_patch("GreyfenRoadShoulder", Vector3(3.4, 0.024, z), Vector3(1.2, 0.032, 2.6), Color(0.095, 0.105, 0.075))
	_make_grass_tufts([
		Vector3(-3.4, 0, -11.5), Vector3(3.1, 0, -10.7), Vector3(-3.6, 0, -7.5), Vector3(3.3, 0, -5.6),
		Vector3(-3.8, 0, -1.4), Vector3(3.6, 0, 1.8), Vector3(-3.0, 0, 5.6), Vector3(3.7, 0, 7.9),
		Vector3(5.2, 0, -8.8), Vector3(7.4, 0, -4.9), Vector3(11.9, 0, 7.4), Vector3(14.8, 0, 6.2)
	], Color(0.070, 0.145, 0.070))
	_make_balanced_road_surface(true)

func _make_wychwood_terrain_layers() -> void:
	_make_terrain_patch("WychwoodWetRoad", Vector3(0, 0.028, 4.0), Vector3(5.2, 0.045, 22.0), Color(0.045, 0.055, 0.043))
	_make_terrain_patch("WychwoodRootFloorLeft", Vector3(-7.0, 0.018, 1.0), Vector3(8.0, 0.04, 25.0), Color(0.035, 0.072, 0.045))
	_make_terrain_patch("WychwoodRootFloorRight", Vector3(7.0, 0.018, 0.0), Vector3(8.0, 0.04, 25.0), Color(0.035, 0.068, 0.045))
	_make_terrain_patch("WychwoodClearingMud", Vector3(0, 0.032, -6.5), Vector3(10.0, 0.05, 7.0), Color(0.035, 0.044, 0.036))
	for z in [12.0, 8.0, 4.0, 0.0, -4.0, -8.0]:
		_make_terrain_patch("WychwoodPathShoulder", Vector3(-3.0, 0.035, z), Vector3(1.0, 0.035, 2.6), Color(0.032, 0.060, 0.040))
		_make_terrain_patch("WychwoodPathShoulder", Vector3(3.0, 0.035, z), Vector3(1.0, 0.035, 2.6), Color(0.032, 0.060, 0.040))
	_make_grass_tufts([
		Vector3(-2.8, 0, 11.8), Vector3(2.6, 0, 10.5), Vector3(-3.1, 0, 7.2), Vector3(3.3, 0, 5.6),
		Vector3(-3.4, 0, 2.0), Vector3(3.5, 0, -0.2), Vector3(-3.7, 0, -4.2), Vector3(3.4, 0, -6.1),
		Vector3(-5.0, 0, -8.4), Vector3(5.3, 0, -9.0)
	], Color(0.045, 0.115, 0.065))
	_make_balanced_road_surface(false)

func _make_balanced_road_surface(paved: bool) -> void:
	if _performance_mode():
		return
	var batch = MultiMeshInstance3D.new()
	batch.name = "BalancedPavedRoadDetail" if paved else "BalancedWychwoodRoadDetail"
	var detail_mesh = BoxMesh.new()
	detail_mesh.size = Vector3(0.70, 0.040, 0.53) if paved else Vector3(1.2, 0.012, 0.48)
	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = paved
	multimesh.mesh = detail_mesh
	var rows = 43 if paved else 12
	var columns = 5 if paved else 1
	multimesh.instance_count = rows * columns
	var index = 0
	for row in range(rows):
		for column in range(columns):
			var row_offset := 0.09 if paved and row % 2 == 1 else 0.0
			var x = (float(column) - 2.0) * 0.73 + row_offset if paved else sin(float(row) * 1.7) * 0.55
			var z = -13.0 + float(row) * (0.63 if paved else 2.05)
			var yaw = sin(float(row * 7 + column * 3)) * 0.035 if paved else sin(float(row) * 0.8) * 0.16
			var basis := Basis(Vector3.UP, yaw)
			if paved:
				basis = basis.scaled(Vector3(0.94 + float((row + column) % 3) * 0.025, 1.0, 0.94 + float((row * 2 + column) % 3) * 0.025))
			multimesh.set_instance_transform(index, Transform3D(basis, Vector3(x, 0.064, z)))
			if paved:
				var shade := 0.82 + float((row + column * 2) % 4) * 0.045
				multimesh.set_instance_color(index, Color(shade, shade * 0.94, shade * 0.84, 1.0))
			index += 1
	batch.multimesh = multimesh
	var material: StandardMaterial3D
	if paved:
		material = world_materials.get_material("cobblestone", str(settings.settings.get("quality_preset", "balanced")), Color(0.72, 0.69, 0.62), 0.16, false).duplicate()
		material.vertex_color_use_as_albedo = true
	else:
		material = StandardMaterial3D.new()
		material.albedo_color = Color(0.025, 0.034, 0.030)
		material.roughness = 0.32
	batch.material_override = material
	zone_root.add_child(batch)

func _make_greyfen_path_edges() -> void:
	var marker = Node3D.new()
	marker.name = "GreyfenPathEdgeComposition"
	zone_root.add_child(marker)
	for z in [-12, -9, -6, -3, 0, 3, 6, 9, 12]:
		_make_path_stone(Vector3(-2.35 + randf_range(-0.12, 0.12), 0, z + randf_range(-0.35, 0.35)), 0.35)
		_make_path_stone(Vector3(2.35 + randf_range(-0.12, 0.12), 0, z + randf_range(-0.35, 0.35)), 0.32)
	for z in [-11.8, -7.8, -3.8, 0.2, 4.2, 8.2]:
		_make_low_berm(Vector3(-4.7, 0, z), Vector3(1.2, 0.38, 2.2), Color(0.085, 0.105, 0.070))
		_make_low_berm(Vector3(4.7, 0, z), Vector3(1.2, 0.38, 2.2), Color(0.085, 0.105, 0.070))

func _make_wychwood_path_edges() -> void:
	var marker = Node3D.new()
	marker.name = "WychwoodPathEdgeComposition"
	zone_root.add_child(marker)
	for z in [12, 9, 6, 3, 0, -3, -6, -9]:
		_make_path_stone(Vector3(-2.25 + randf_range(-0.18, 0.18), 0, z + randf_range(-0.25, 0.25)), 0.42)
		_make_path_stone(Vector3(2.25 + randf_range(-0.18, 0.18), 0, z + randf_range(-0.25, 0.25)), 0.42)
		_make_low_berm(Vector3(-4.25, 0, z), Vector3(1.4, 0.48, 2.2), Color(0.030, 0.060, 0.038))
		_make_low_berm(Vector3(4.25, 0, z), Vector3(1.4, 0.48, 2.2), Color(0.030, 0.060, 0.038))

func _make_terrain_patch(name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var river_z := _river_center()
	var river_min := river_z - 2.05
	var river_max := river_z + 2.05
	var patch_min := pos.z - size.z * 0.5
	var patch_max := pos.z + size.z * 0.5
	if river_z < 900.0 and patch_min < river_max and patch_max > river_min:
		if patch_min < river_min:
			var north_size := river_min - patch_min
			_make_terrain_patch_raw("%s_NorthBank" % name, Vector3(pos.x,pos.y,patch_min+north_size*0.5), Vector3(size.x,size.y,north_size), color)
		if patch_max > river_max:
			var south_size := patch_max - river_max
			_make_terrain_patch_raw("%s_SouthBank" % name, Vector3(pos.x,pos.y,river_max+south_size*0.5), Vector3(size.x,size.y,south_size), color)
		return
	_make_terrain_patch_raw(name,pos,size,color)

func _make_terrain_patch_raw(name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var mesh = MeshInstance3D.new()
	mesh.name = name
	mesh.position = pos
	mesh.rotation_degrees.y = randf_range(-2.0, 2.0)
	zone_root.add_child(mesh)
	terrain_patch_batch_data.append({"node":mesh,"size":size,"color":color,"material":_terrain_material(name,color)})

func _make_path_stone(pos: Vector3, scale_value: float) -> void:
	_make_terrain_patch("PathStone", pos + Vector3(0, 0.03, 0), Vector3(scale_value, 0.06, scale_value * 0.75), Color(0.18, 0.17, 0.15))

func _make_low_berm(pos: Vector3, size: Vector3, color: Color) -> void:
	if _is_river_excluded(pos,size.z*0.5):
		return
	var body = StaticBody3D.new()
	body.name = "LowBerm"
	body.position = pos + Vector3(0, size.y * 0.5, 0)
	zone_root.add_child(body)
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh = MeshInstance3D.new()
	mesh.mesh = shared_box_mesh
	mesh.scale = size
	mesh.material_override = world_materials.get_material("forest_ground", str(settings.settings.get("quality_preset", "balanced")), color.lightened(0.30), 0.0, true)
	body.add_child(mesh)

func _make_grass_tufts(points: Array, color: Color) -> void:
	var safe_points: Array = []
	for point in points:
		if not _is_river_excluded(point,0.25):
			safe_points.append(point)
	if safe_points.is_empty():
		return
	if _performance_mode() and int(settings.settings.get("foliage_density", 0)) <= 0:
		return
	var batch = MultiMeshInstance3D.new()
	batch.name = "GrassBatch"
	var blade_mesh = QuadMesh.new()
	blade_mesh.size = Vector2(0.82, 1.0)
	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = blade_mesh
	multimesh.instance_count = safe_points.size() * 3
	var instance_index = 0
	for raw_pos in safe_points:
		var pos: Vector3 = raw_pos
		for i: int in range(3):
			var height: float = randf_range(0.34, 0.72)
			var basis = Basis()
			basis = basis.rotated(Vector3.UP, float(i) * PI / 3.0 + randf_range(-0.12, 0.12))
			basis = basis.scaled(Vector3(randf_range(0.82, 1.16), height, 1.0))
			var offset = Vector3(randf_range(-0.16, 0.16), height * 0.5, randf_range(-0.16, 0.16))
			multimesh.set_instance_transform(instance_index, Transform3D(basis, pos + offset))
			instance_index += 1
	batch.multimesh = multimesh
	batch.material_override = world_materials.get_grass_material(str(settings.settings.get("quality_preset", "balanced")))
	batch.visibility_range_end = 30.0
	zone_root.add_child(batch)

func _make_spawn_composition() -> void:
	var marker = Node3D.new()
	marker.name = "GreyfenSpawnComposition"
	marker.position = Vector3(0, 0, 7)
	zone_root.add_child(marker)
	_make_light("SpawnWarmRead", Vector3(-2.6, 2.8, 5.7), Color(1.0, 0.42, 0.16), 1.0)
	_make_light("SpawnCoolBackplate", Vector3(1.8, 3.5, 0.4), Color(0.30, 0.36, 0.50), 1.4)
	_make_fog_sheet(Vector3(0, 0.8, 0.8), Vector3(10.0, 0.7, 3.2), Color(0.13, 0.15, 0.16, 0.07))
	_make_fake_light_pool("SpawnLanternPool", Vector3(-2.55, 0.035, 5.6), Vector3(1.9, 0.025, 1.25), Color(0.42, 0.20, 0.075))
	_make_visual_box("SpawnViewShadowLeft", Vector3(-4.0, 0.035, 4.6), Vector3(1.2, 0.025, 3.4), Color(0.055, 0.070, 0.055))
	_make_visual_box("SpawnViewShadowRight", Vector3(4.0, 0.035, 3.9), Vector3(1.1, 0.025, 3.7), Color(0.055, 0.068, 0.055))
	for pos in [Vector3(-3.1, 0, 4.2), Vector3(3.0, 0, 3.4), Vector3(-2.9, 0, 0.2), Vector3(2.9, 0, -1.5)]:
		_make_path_stone(pos, 0.22)
	_make_lantern_post(Vector3(-2.8, 0, 5.7), false, true)
	_make_lantern_post(Vector3(2.65, 0, 1.5), false, false)
	_make_firewood_stack(Vector3(-5.1, 0, 5.2), 18.0)
	_make_broken_fence_run(Vector3(4.7, 0, 5.8), false)

func _make_greyfen_first_impression_dressing() -> void:
	var marker = Node3D.new()
	marker.name = "GreyfenFirstImpressionDressing"
	marker.position = Vector3(0, 0, 0)
	zone_root.add_child(marker)
	_make_road_ruts()
	_make_lantern_rhythm()
	_make_shrine_approach()
	_make_village_story_clusters()
	_make_crow_silhouettes()

func _make_quality_greyfen_overhaul() -> void:
	if str(settings.settings.get("quality_preset", "balanced")) != "quality":
		return
	var marker = Node3D.new()
	marker.name = "QualityGreyfenVisualOverhaul"
	zone_root.add_child(marker)
	for z in [-13.0, -10.5, -8.0, -5.5, -3.0, -0.5, 2.0, 4.5, 7.0, 9.5, 12.0]:
		_make_visual_box("QualityWetRoadSheen", Vector3(randf_range(-0.45, 0.45), 0.058, z), Vector3(randf_range(0.55, 1.35), 0.012, randf_range(0.42, 1.15)), Color(0.045, 0.037, 0.030))
		_make_visual_box("QualityRoadLeafLitter", Vector3(randf_range(-1.9, 1.9), 0.066, z + randf_range(-0.75, 0.75)), Vector3(randf_range(0.18, 0.55), 0.012, randf_range(0.08, 0.20)), Color(0.12, 0.060, 0.030))
	for pos in [Vector3(-5.8,0,2.5), Vector3(-7.0,0,-3.2), Vector3(7.2,0,-0.2), Vector3(9.8,0,1.8), Vector3(-10.0,0,8.8), Vector3(11.2,0,-7.4)]:
		_make_quality_survival_cluster(pos)
	for pos in [Vector3(4.0,0,-6.0), Vector3(5.2,0,-4.5), Vector3(7.5,0,-7.2), Vector3(6.8,0,-5.8)]:
		_make_fake_light_pool("QualityShrineCandlePool", pos + Vector3(0, 0.038, 0), Vector3(1.05, 0.016, 0.64), Color(0.34, 0.19, 0.07))
	for pos in [Vector3(-3.2,0,-12.5), Vector3(3.4,0,-11.6), Vector3(-3.6,0,-9.2), Vector3(3.2,0,-7.8), Vector3(-3.1,0,-4.8), Vector3(3.5,0,-2.0)]:
		_make_visual_box("QualityRoadEdgeWeeds", pos + Vector3(0, 0.15, 0), Vector3(0.12, randf_range(0.26, 0.46), 0.08), Color(0.060, 0.120, 0.055))
	_make_light("QualityShrineWarmth", Vector3(5.5, 2.7, -5.9), Color(1.0, 0.50, 0.20), 1.2)
	_make_light("QualityVillageColdEdge", Vector3(-10.0, 3.8, -8.0), Color(0.22, 0.32, 0.46), 1.1)

func _make_quality_survival_cluster(pos: Vector3) -> void:
	_make_visual_box("QualityMudSack", pos + Vector3(0.0, 0.16, 0.0), Vector3(0.58, 0.32, 0.36), Color(0.17, 0.115, 0.065))
	_make_visual_box("QualityBrokenBoard", pos + Vector3(0.62, 0.13, -0.14), Vector3(0.88, 0.08, 0.18), Color(0.13, 0.075, 0.038))
	_make_visual_box("QualityBucket", pos + Vector3(-0.52, 0.24, 0.18), Vector3(0.32, 0.48, 0.32), Color(0.10, 0.085, 0.065))
	_make_visual_box("QualityClothScrap", pos + Vector3(0.1, 0.045, 0.5), Vector3(0.82, 0.018, 0.32), Color(0.23, 0.055, 0.044))

func _make_road_ruts() -> void:
	for z in [-11.5, -8.6, -5.7, -2.8, 0.1, 3.0, 5.9, 8.8]:
		_make_visual_box("RoadWheelRut", Vector3(-0.82, 0.044, z), Vector3(0.18, 0.018, 2.0), Color(0.075, 0.058, 0.040))
		_make_visual_box("RoadWheelRut", Vector3(0.82, 0.044, z + 0.18), Vector3(0.18, 0.018, 2.0), Color(0.075, 0.058, 0.040))
	for z in [-10.0, -6.0, -2.0, 2.0, 6.0, 10.0]:
		_make_visual_box("RoadCenterMud", Vector3(0, 0.046, z), Vector3(0.42, 0.016, 1.25), Color(0.090, 0.066, 0.043))

func _make_lantern_rhythm() -> void:
	var points = [
		[Vector3(-2.85, 0, 6.4), true],
		[Vector3(2.95, 0, 2.2), false],
		[Vector3(-2.75, 0, -2.5), false],
		[Vector3(2.85, 0, -6.8), false],
		[Vector3(-2.55, 0, -10.8), false]
	]
	for item in points:
		_make_lantern_post(item[0], false, bool(item[1]))
		_make_fake_light_pool("RoadLanternPool", item[0] + Vector3(0, 0.035, 0.25), Vector3(1.55, 0.022, 1.05), Color(0.32, 0.135, 0.045))

func _make_shrine_approach() -> void:
	_make_visual_box("ShrinePathWarmEdge", Vector3(3.05, 0.047, -5.55), Vector3(2.9, 0.018, 0.22), Color(0.24, 0.16, 0.075))
	_make_visual_box("ShrinePathWarmEdge", Vector3(4.65, 0.047, -6.55), Vector3(2.3, 0.018, 0.22), Color(0.24, 0.16, 0.075))
	_make_lantern_post(Vector3(3.4, 0, -4.25), true, true)
	_make_lantern_post(Vector3(7.65, 0, -6.1), true, false)
	for offset in [Vector3(-1.25, 0, 0.75), Vector3(1.18, 0, 0.82), Vector3(-1.55, 0, -0.25), Vector3(1.5, 0, -0.3)]:
		_make_shrine_candle(Vector3(6.0, 0, -7.0) + offset)
	_make_hanging_cloth(Vector3(4.85, 1.25, -7.95), Vector3(0.55, 0.72, 0.035), Color(0.34, 0.035, 0.030))
	_make_hanging_cloth(Vector3(7.05, 1.20, -7.92), Vector3(0.48, 0.62, 0.035), Color(0.12, 0.16, 0.13))

func _make_village_story_clusters() -> void:
	_make_firewood_stack(Vector3(-6.8, 0, -0.8), -12.0)
	_make_firewood_stack(Vector3(8.2, 0, -1.2), 24.0)
	_make_broken_fence_run(Vector3(-4.8, 0, -7.0), true)
	_make_broken_fence_run(Vector3(4.9, 0, -10.4), true)
	_make_wheelbarrow(Vector3(-7.9, 0, 6.6), -22.0)
	_make_wheelbarrow(Vector3(11.7, 0, -10.2), 35.0)
	for pos in [Vector3(-10.7, 0, 10.5), Vector3(12.4, 0, 6.3), Vector3(15.6, 0, 7.7)]:
		_make_mourning_marker(pos)
	for pos in [Vector3(-12.7, 0, -5.8), Vector3(-11.8, 0, -4.3), Vector3(13.2, 0, -5.4), Vector3(14.2, 0, -4.0)]:
		_make_fake_fog_bank(pos)

func _make_lantern_post(pos: Vector3, shrine_style: bool, casts_light: bool) -> void:
	_make_prop_box("LanternPost", pos + Vector3(0, 0.75, 0), Vector3(0.12, 1.5, 0.12), Color(0.12, 0.070, 0.038))
	_make_visual_box("LanternArm", pos + Vector3(0.28, 1.38, 0), Vector3(0.56, 0.08, 0.08), Color(0.12, 0.070, 0.038))
	_make_visual_box("LanternCage", pos + Vector3(0.56, 1.18, 0), Vector3(0.22, 0.34, 0.22), Color(0.055, 0.040, 0.030))
	var glow_color = Color(1.0, 0.50, 0.16) if not shrine_style else Color(0.74, 0.88, 0.58)
	var glow = MeshInstance3D.new()
	glow.name = "LanternGlow"
	glow.set_meta("visual_name", "LanternGlow")
	glow.mesh = SphereMesh.new()
	glow.scale = Vector3(0.16, 0.22, 0.16)
	glow.position = pos + Vector3(0.56, 1.17, 0)
	glow.material_override = _emissive_mat(glow_color, 1.25)
	zone_root.add_child(glow)
	if casts_light:
		_make_light("SpawnWarmRead" if not shrine_style else "Shrine Beacon", pos + Vector3(0.45, 1.45, 0), glow_color, 0.9)

func _make_fake_light_pool(name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	_make_visual_box(name, pos, size, color)

func _make_firewood_stack(pos: Vector3, yaw: float) -> void:
	var root = Node3D.new()
	root.name = "FirewoodStack"
	root.position = pos
	root.rotation_degrees.y = yaw
	zone_root.add_child(root)
	for i in range(5):
		var log_mesh = MeshInstance3D.new()
		log_mesh.name = "StackedLog"
		var mesh = CylinderMesh.new()
		mesh.top_radius = 0.075
		mesh.bottom_radius = 0.085
		mesh.height = 1.05
		mesh.radial_segments = 6
		log_mesh.mesh = mesh
		log_mesh.position = Vector3(-0.34 + float(i) * 0.17, 0.18 + float(i % 2) * 0.13, 0)
		log_mesh.rotation_degrees = Vector3(90, 0, 90)
		log_mesh.material_override = _mat(Color(0.135, 0.078, 0.044))
		root.add_child(log_mesh)

func _make_broken_fence_run(pos: Vector3, vertical: bool) -> void:
	for i in range(3):
		var offset = Vector3(0, 0, float(i) * 0.85) if vertical else Vector3(float(i) * 0.85, 0, 0)
		_make_visual_box("BrokenFencePost", pos + offset + Vector3(0, 0.42 + 0.06 * float(i % 2), 0), Vector3(0.12, 0.84, 0.12), Color(0.13, 0.075, 0.040))
	var rail_size = Vector3(0.10, 0.10, 2.35) if vertical else Vector3(2.35, 0.10, 0.10)
	_make_visual_box("BrokenFenceRail", pos + Vector3(0.42 if not vertical else 0, 0.72, 0.42 if vertical else 0), rail_size, Color(0.16, 0.095, 0.050))

func _make_wheelbarrow(pos: Vector3, yaw: float) -> void:
	var root = Node3D.new()
	root.name = "WheelbarrowStoryProp"
	root.position = pos
	root.rotation_degrees.y = yaw
	zone_root.add_child(root)
	_add_visual_box_child(root, "WheelbarrowTray", Vector3(0, 0.38, 0), Vector3(1.0, 0.24, 0.55), Color(0.15, 0.085, 0.045))
	_add_visual_box_child(root, "WheelbarrowHandle", Vector3(-0.62, 0.42, -0.23), Vector3(0.75, 0.07, 0.07), Color(0.12, 0.070, 0.038))
	_add_visual_box_child(root, "WheelbarrowHandle", Vector3(-0.62, 0.42, 0.23), Vector3(0.75, 0.07, 0.07), Color(0.12, 0.070, 0.038))
	var wheel = MeshInstance3D.new()
	wheel.name = "WheelbarrowWheel"
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.22
	mesh.bottom_radius = 0.22
	mesh.height = 0.08
	mesh.radial_segments = 8
	wheel.mesh = mesh
	wheel.position = Vector3(0.53, 0.22, 0)
	wheel.rotation_degrees.z = 90
	wheel.material_override = _mat(Color(0.055, 0.040, 0.030))
	root.add_child(wheel)

func _make_mourning_marker(pos: Vector3) -> void:
	_make_visual_box("MourningMarkerPost", pos + Vector3(0, 0.38, 0), Vector3(0.09, 0.76, 0.09), Color(0.11, 0.075, 0.050))
	_make_visual_box("MourningMarkerCross", pos + Vector3(0, 0.62, 0), Vector3(0.54, 0.07, 0.07), Color(0.11, 0.075, 0.050))
	_make_hanging_cloth(pos + Vector3(0.25, 0.45, 0.01), Vector3(0.18, 0.28, 0.025), Color(0.30, 0.030, 0.025))

func _make_shrine_candle(pos: Vector3) -> void:
	_make_visual_box("ShrineCandle", pos + Vector3(0, 0.17, 0), Vector3(0.10, 0.34, 0.10), Color(0.72, 0.62, 0.44))
	var flame = MeshInstance3D.new()
	flame.name = "ShrineCandleFlame"
	flame.mesh = SphereMesh.new()
	flame.scale = Vector3(0.07, 0.11, 0.07)
	flame.position = pos + Vector3(0, 0.39, 0)
	flame.material_override = _emissive_mat(Color(1.0, 0.48, 0.14), 1.1)
	zone_root.add_child(flame)

func _make_hanging_cloth(pos: Vector3, size: Vector3, color: Color) -> void:
	_make_visual_box("HangingCloth", pos, size, color)

func _make_fake_fog_bank(pos: Vector3) -> void:
	_make_visual_box("LowColdFogBank", pos + Vector3(0, 0.07, 0), Vector3(1.6, 0.10, 0.55), Color(0.105, 0.125, 0.118))

func _make_crow_silhouettes() -> void:
	for item in [
		[Vector3(-8.5, 5.8, -11.5), -14.0],
		[Vector3(-7.8, 6.15, -12.2), 8.0],
		[Vector3(10.2, 5.5, -10.6), 18.0]
	]:
		var root = Node3D.new()
		root.name = "CrowSilhouette"
		root.position = item[0]
		root.rotation_degrees.y = float(item[1])
		zone_root.add_child(root)
		_add_visual_box_child(root, "CrowWing", Vector3(-0.16, 0, 0), Vector3(0.34, 0.035, 0.08), Color(0.010, 0.010, 0.012))
		_add_visual_box_child(root, "CrowWing", Vector3(0.16, 0, 0), Vector3(0.34, 0.035, 0.08), Color(0.010, 0.010, 0.012))

func _make_visual_box(name: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	pos = river_safe_position(pos,size.z*0.5+0.18)
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = name
	mesh_instance.set_meta("visual_name", name)
	mesh_instance.position = pos
	zone_root.add_child(mesh_instance)
	if environment_batches_flushed:
		mesh_instance.mesh = shared_box_mesh
		mesh_instance.scale = size
		mesh_instance.material_override = _mat(color)
	else:
		visual_box_batch_data.append({"node":mesh_instance,"size":size,"color":color})
	return mesh_instance

func _add_visual_box_child(parent: Node3D, name: String, local_pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = name
	mesh_instance.set_meta("visual_name", name)
	mesh_instance.mesh = shared_box_mesh
	mesh_instance.scale = size
	mesh_instance.position = local_pos
	mesh_instance.material_override = _mat(color)
	parent.add_child(mesh_instance)
	return mesh_instance

func _make_greyfen_road_of_crows_story_beats() -> void:
	var marker = Node3D.new()
	marker.name = "RoadOfCrowsGreyfenStoryBeats"
	zone_root.add_child(marker)
	_make_black_feather_scatter("RoadCrowsNoticeBlackFeathers", Vector3(-2.8, 0.09, 9.0), 4, 0.75)
	_make_broken_charm("RoadCrowsNoticePrayerCharm", Vector3(-1.35, 0.10, 8.95), 0.0)
	_make_black_feather_scatter("RoadCrowsShrineBlackFeathers", Vector3(5.25, 0.10, -6.25), 5, 0.65)
	_make_broken_charm("RoadCrowsShrineSnappedToken", Vector3(5.65, 0.12, -6.75), -22.0)
	_make_visual_box("RoadCrowsExtinguishedCandle", Vector3(6.55, 0.16, -6.35), Vector3(0.11, 0.28, 0.11), Color(0.075, 0.065, 0.055))
	_make_visual_box("RoadCrowsGraveyardDisturbedSoil", Vector3(13.65, 0.065, 9.45), Vector3(1.65, 0.035, 0.85), Color(0.060, 0.044, 0.033))
	_make_broken_charm("RoadCrowsGraveyardHalfBuriedCharm", Vector3(13.18, 0.13, 9.15), 14.0)
	_make_black_feather_scatter("RoadCrowsGateThresholdFeathers", Vector3(-1.25, 0.10, -13.65), 5, 0.9)
	_make_dark_track("RoadCrowsGateMudTrail", Vector3(0.0, 0.071, -13.15), Vector3(0.42, 0.022, 2.15), Color(0.040, 0.027, 0.020))
	_make_visual_box("RoadCrowsGateBrokenSign", Vector3(-2.95, 0.86, -13.85), Vector3(1.05, 0.14, 0.38), Color(0.135, 0.075, 0.038))
	_make_claw_marks("RoadCrowsGateClawedPost", Vector3(2.35, 0.95, -13.85), true)

func _make_wychwood_road_of_crows_story_beats() -> void:
	var marker = Node3D.new()
	marker.name = "RoadOfCrowsWychwoodStoryBeats"
	zone_root.add_child(marker)
	_make_cart(Vector3(-5.35, 0, 6.6))
	_make_visual_box("RoadCrowsBrokenCartSupplySack", Vector3(-4.65, 0.18, 6.0), Vector3(0.58, 0.24, 0.42), Color(0.17, 0.115, 0.075))
	_make_dark_track("RoadCrowsDraggedTrackA", Vector3(-1.05, 0.073, 6.4), Vector3(0.32, 0.018, 2.6), Color(0.050, 0.027, 0.020))
	_make_dark_track("RoadCrowsDraggedTrackB", Vector3(0.75, 0.074, 5.1), Vector3(0.26, 0.018, 2.0), Color(0.055, 0.030, 0.022))
	_make_claw_marks("RoadCrowsCartClawMarks", Vector3(2.7, 0.22, 4.65), false)
	_make_visual_box("RoadCrowsTornRedCloth", Vector3(-3.65, 0.105, 2.15), Vector3(0.58, 0.035, 0.24), Color(0.28, 0.055, 0.042))
	_make_broken_charm("RoadCrowsBrokenPrayerToken", Vector3(-3.18, 0.13, 2.25), -12.0)
	_make_black_feather_scatter("RoadCrowsOldRoadBlackFeathers", Vector3(-3.95, 0.10, 1.75), 6, 0.75)
	_make_dark_track("RoadCrowsClearingDraggedMarks", Vector3(0.0, 0.074, -5.65), Vector3(0.46, 0.020, 3.1), Color(0.060, 0.022, 0.016))
	_make_visual_box("RoadCrowsClearingOldBloodMud", Vector3(-0.8, 0.076, -6.95), Vector3(1.35, 0.020, 0.62), Color(0.080, 0.018, 0.013))
	_make_broken_charm("RoadCrowsClearingSnappedCharm", Vector3(1.35, 0.13, -6.9), 24.0)
	_make_black_feather_scatter("RoadCrowsClearingFeathers", Vector3(1.55, 0.10, -7.25), 5, 0.72)

func _make_post_ghoulkin_story_clue() -> void:
	if zone_root == null or zone_root.find_child("RoadCrowsPostVictoryBootTracks", true, false) != null:
		return
	_make_dark_track("RoadCrowsPostVictoryBootTracks", Vector3(0.95, 0.087, -4.25), Vector3(0.30, 0.026, 1.9), Color(0.020, 0.018, 0.015))
	_make_dark_track("RoadCrowsPostVictoryClawTracks", Vector3(1.45, 0.088, -4.75), Vector3(0.34, 0.025, 1.55), Color(0.060, 0.022, 0.016))
	_make_visual_box("RoadCrowsPostVictoryCutThread", Vector3(0.55, 0.13, -3.72), Vector3(0.70, 0.030, 0.06), Color(0.36, 0.035, 0.030))
	_make_black_feather_scatter("RoadCrowsPostVictoryFeathers", Vector3(0.35, 0.11, -3.95), 4, 0.55)

func _make_narrative_aftermath(zone_id: String) -> void:
	if zone_root == null:
		return
	if zone_id == "wychwood":
		if quests.is_objective_done("main_road_of_crows", "fight_ghoulkin") or bool(story_state.get_flag("wychwood_pack_cleared", false)):
			_make_post_ghoulkin_story_clue()
			_make_visual_box("WychwoodPackAshResidue", Vector3(0.0, 0.078, -7.0), Vector3(1.7, 0.018, 1.25), Color(0.045, 0.035, 0.032))
			_make_visual_box("WychwoodPackBrokenBinding", Vector3(1.2, 0.115, -6.4), Vector3(0.55, 0.025, 0.08), Color(0.22, 0.16, 0.10))
		for evidence in [
			["bram", Vector3(-2.0, 0.10, 7.4), Color(0.30, 0.18, 0.12)],
			["sella", Vector3(-4.0, 0.10, 4.0), Color(0.24, 0.035, 0.03)],
			["oren", Vector3(3.8, 0.10, 2.2), Color(0.48, 0.36, 0.18)],
			["vargan_wire", Vector3(2.5, 0.10, 4.8), Color(0.14, 0.14, 0.13)],
			["drag_marks", Vector3(0.0, 0.09, -4.2), Color(0.09, 0.055, 0.035)]
		]:
			if quests.is_objective_done("main_road_of_crows", str(evidence[0])) or bool(story_state.get_flag("road_evidence_%s" % evidence[0], false)):
				var marker := _make_visual_box("ExaminedEvidence_%s" % evidence[0], evidence[1], Vector3(0.34, 0.025, 0.34), evidence[2])
				marker.set_meta("narrative_state", "examined")
	elif zone_id == "greyfen":
		var report_method := str(story_state.get_flag("evidence_report", ""))
		if report_method != "":
			var report_colors := {
				"private": Color(0.58, 0.50, 0.34),
				"public": Color(0.62, 0.18, 0.12),
				"retained": Color(0.25, 0.22, 0.18)
			}
			_make_visual_box("GreyfenReportedNotice", Vector3(-1.98, 1.18, 9.34), Vector3(0.46, 0.58, 0.025), report_colors.get(report_method, Color(0.5, 0.45, 0.34)))
			_make_visual_box("GreyfenWitnessCandle", Vector3(5.65, 0.18, -6.72), Vector3(0.08, 0.22, 0.08), Color(0.65, 0.46, 0.22))
		if bool(story_state.get_flag("cemetery_ambush_cleared", false)):
			_make_visual_box("CemeterySettledEarth", Vector3(14.0, 0.072, 8.8), Vector3(2.1, 0.025, 1.25), Color(0.085, 0.070, 0.052))
			_make_visual_box("CemeteryAftermathLantern", Vector3(15.7, 0.42, 8.1), Vector3(0.16, 0.40, 0.16), Color(0.52, 0.40, 0.21))

func _make_black_feather_scatter(base_name: String, center: Vector3, count: int, spread: float) -> void:
	for i in range(count):
		var offset = Vector3(randf_range(-spread, spread), 0.0, randf_range(-spread * 0.55, spread * 0.55))
		var feather = _make_visual_box(base_name, center + offset, Vector3(randf_range(0.24, 0.42), 0.022, 0.070), Color(0.010, 0.010, 0.012))
		feather.rotation_degrees.y = randf_range(-35.0, 35.0)

func _make_broken_charm(name: String, pos: Vector3, yaw: float) -> void:
	var root = Node3D.new()
	root.name = name
	root.position = pos
	root.rotation_degrees.y = yaw
	zone_root.add_child(root)
	_add_visual_box_child(root, "%sBoneHalfA" % name, Vector3(-0.08, 0.0, 0.0), Vector3(0.17, 0.035, 0.24), Color(0.54, 0.50, 0.42))
	_add_visual_box_child(root, "%sBoneHalfB" % name, Vector3(0.11, 0.0, 0.04), Vector3(0.15, 0.035, 0.20), Color(0.48, 0.45, 0.38))
	_add_visual_box_child(root, "%sRedThread" % name, Vector3(0.0, 0.024, -0.12), Vector3(0.38, 0.020, 0.045), Color(0.30, 0.035, 0.028))

func _make_dark_track(name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var track = _make_visual_box(name, pos, size, color)
	track.rotation_degrees.y = randf_range(-8.0, 8.0)

func _make_claw_marks(name: String, pos: Vector3, vertical: bool) -> void:
	for i in range(3):
		var mark_pos = pos + (Vector3(0.0, 0.11 * float(i), 0.0) if vertical else Vector3(0.18 * float(i), 0.0, 0.0))
		var size = Vector3(0.045, 0.50, 0.035) if vertical else Vector3(0.055, 0.030, 0.62)
		var mark = _make_visual_box(name, mark_pos, size, Color(0.030, 0.018, 0.012))
		mark.rotation_degrees.z = -18.0 if vertical else 0.0

func _make_wychwood_corridor() -> void:
	var marker = Node3D.new()
	marker.name = "WychwoodCorridorComposition"
	marker.position = Vector3(0, 0, 4)
	zone_root.add_child(marker)
	for z in [11.0, 7.5, 4.0, 0.5, -3.0]:
		_make_tree(Vector3(-9.2 + randf_range(-0.25, 0.25), 0, z))
		_make_tree(Vector3(9.2 + randf_range(-0.25, 0.25), 0, z + randf_range(-0.25, 0.25)))
		_make_fog_sheet(Vector3(0, 0.75, z - 0.8), Vector3(7.5, 0.72, 1.5), Color(0.12, 0.18, 0.16, 0.11))

func _make_stylized_house(pos: Vector3) -> void:
	_make_prop_box("VillageHouseBody", pos + Vector3(0, 1.05, 0), Vector3(3.8, 2.1, 3.0), Color(0.25, 0.18, 0.13))
	_make_roof(pos + Vector3(0, 2.45, 0), Vector3(4.6, 0.95, 3.6), Color(0.12, 0.085, 0.06))
	_make_prop_box("VillageDoor", pos + Vector3(0, 0.75, -1.55), Vector3(0.75, 1.35, 0.12), Color(0.08, 0.055, 0.035))
	_make_prop_box("VillageWindow", pos + Vector3(-1.15, 1.25, -1.56), Vector3(0.55, 0.45, 0.08), Color(0.86, 0.55, 0.22))
	_make_prop_box("VillageWindow", pos + Vector3(1.15, 1.25, -1.56), Vector3(0.55, 0.45, 0.08), Color(0.86, 0.55, 0.22))

func _make_village_house_dressed(pos: Vector3, yaw: float, node_name: String) -> void:
	var root = Node3D.new()
	root.name = node_name
	root.add_to_group("first_route_house")
	root.add_to_group("greyfen_house")
	root.set_meta("visible_house", true)
	root.position = pos
	root.rotation_degrees.y = yaw
	zone_root.add_child(root)
	_make_house_collision(root)
	var facade_variant: int = absi(node_name.hash()) % 3
	var plaster_colors := [Color(0.32, 0.245, 0.17), Color(0.29, 0.265, 0.205), Color(0.33, 0.225, 0.16)]
	var timber_colors := [Color(0.105, 0.055, 0.028), Color(0.085, 0.050, 0.032), Color(0.12, 0.062, 0.026)]
	var plaster: Color = plaster_colors[facade_variant]
	var timber: Color = timber_colors[facade_variant]
	_add_house_box(root, "StoneFoundation", Vector3(0, 0.18, 0), Vector3(4.55, 0.36, 3.55), Color(0.28, 0.27, 0.24))
	_add_house_box(root, "PlasteredWall", Vector3(0, 1.05, 0), Vector3(4.3, 2.1, 3.35), plaster)
	_add_house_gables(root, plaster, timber)
	if _performance_mode():
		_add_house_box(root, "LeftRoofSlope", Vector3(-0.9, 2.42, 0), Vector3(2.55, 0.42, 3.95), Color(0.14, 0.055, 0.035), Vector3(0, 0, -13))
		_add_house_box(root, "RightRoofSlope", Vector3(0.9, 2.42, 0), Vector3(2.55, 0.42, 3.95), Color(0.14, 0.055, 0.035), Vector3(0, 0, 13))
	else:
		# OBJ roof pieces normalize by their broad source bounds; uniform scale keeps the eaves near the 4.5 m shell.
		_add_house_module(root, "greyfen_roof", Vector3(0.55, 0.55, 0.55), Vector3(0, 2.02, 0), 0.0, "ModularTileRoof")
	var chimney_x: float = -1.38 if facade_variant == 0 else 1.38
	_add_house_box(root, "StoneChimney", Vector3(chimney_x, 2.63, 0.62), Vector3(0.48, 1.38, 0.48), Color(0.23, 0.22, 0.20))
	_add_house_box(root, "ChimneyCap", Vector3(chimney_x, 3.31, 0.62), Vector3(0.62, 0.14, 0.62), Color(0.19, 0.18, 0.17))
	_add_house_box(root, "FrontDoor", Vector3(0, 0.78, -1.72), Vector3(0.78, 1.28, 0.12), Color(0.10, 0.055, 0.030))
	_add_house_box(root, "DoorStep", Vector3(0, 0.12, -1.98), Vector3(1.02, 0.22, 0.48), Color(0.28, 0.27, 0.24))
	_add_house_box(root, "TimberLintel", Vector3(0, 1.53, -1.78), Vector3(1.05, 0.14, 0.12), Color(0.11, 0.065, 0.035))
	for x in [-1.42, 1.42]:
		_add_house_box(root, "FrontTimber", Vector3(x, 1.12, -1.78), Vector3(0.13, 1.85, 0.12), timber)
		var window_x: float = x * 0.62
		_add_house_box(root, "LitWindow", Vector3(window_x, 1.42, -1.80), Vector3(0.52, 0.38, 0.045), Color(0.95, 0.52, 0.18))
		_add_house_box(root, "WindowShutter", Vector3(window_x - 0.37, 1.42, -1.84), Vector3(0.16, 0.48, 0.055), Color(0.12, 0.07, 0.035))
		_add_house_box(root, "WindowShutter", Vector3(window_x + 0.37, 1.42, -1.84), Vector3(0.16, 0.48, 0.055), Color(0.12, 0.07, 0.035))
		_add_house_box(root, "RearTimber", Vector3(x, 1.12, 1.78), Vector3(0.13, 1.85, 0.12), timber)
		_add_house_box(root, "RearLitWindow", Vector3(window_x, 1.42, 1.80), Vector3(0.52, 0.38, 0.045), Color(0.88, 0.46, 0.15))
		_add_house_box(root, "RearWindowShutter", Vector3(window_x - 0.37, 1.42, 1.84), Vector3(0.16, 0.48, 0.055), timber)
		_add_house_box(root, "RearWindowShutter", Vector3(window_x + 0.37, 1.42, 1.84), Vector3(0.16, 0.48, 0.055), timber)
	_add_house_box(root, "SideTimberLeft", Vector3(-2.18, 1.18, 0), Vector3(0.12, 1.75, 2.45), Color(0.11, 0.065, 0.035))
	_add_house_box(root, "SideTimberRight", Vector3(2.18, 1.18, 0), Vector3(0.12, 1.75, 2.45), Color(0.11, 0.065, 0.035))
	for side in [-1.0, 1.0]:
		_add_house_box(root, "SideBeltTimber", Vector3(2.19 * side, 1.12, 0), Vector3(0.13, 0.12, 2.70), Color(0.10, 0.057, 0.03))
		_add_house_box(root, "SideWindow", Vector3(2.20 * side, 1.42, 0.35), Vector3(0.055, 0.42, 0.58), Color(0.88, 0.48, 0.16))
	_add_house_box(root, "WeatheredBaseCourse", Vector3(0, 0.42, -1.73), Vector3(4.22, 0.26, 0.08), Color(0.18, 0.18, 0.15))
	_add_house_box(root, "RearWeatheredBaseCourse", Vector3(0, 0.42, 1.73), Vector3(4.22, 0.26, 0.08), Color(0.16, 0.17, 0.14))
	_add_house_box(root, "FrontCrossBrace", Vector3(-1.43, 1.16, -1.85), Vector3(0.11, 1.42, 0.10), Color(0.10, 0.055, 0.03), Vector3(0, 0, -36))
	_add_house_box(root, "FrontCrossBrace", Vector3(1.43, 1.16, -1.85), Vector3(0.11, 1.42, 0.10), Color(0.10, 0.055, 0.03), Vector3(0, 0, 36))
	if str(settings.settings.get("quality_preset", "balanced")) == "quality":
		_add_house_module(root, "greyfen_door_facade", Vector3(0.90, 0.90, 0.90), Vector3(-0.98, 0.02, -1.82), 0.0, "ModularDoorFacade")
		_add_house_module(root, "greyfen_window_facade", Vector3(0.90, 0.90, 0.90), Vector3(1.04, 0.02, -1.82), 0.0, "ModularWindowFacade")
		_add_house_module(root, "greyfen_chimney", Vector3(0.48, 0.58, 0.48), Vector3(chimney_x, 2.20, 0.62), 0.0, "ModularChimney")
	if facade_variant == 0:
		_add_house_box(root, "PorchCanopy", Vector3(0, 1.68, -2.05), Vector3(1.65, 0.14, 0.72), Color(0.12, 0.065, 0.032), Vector3(-8, 0, 0))
		for x in [-0.72, 0.72]:
			_add_house_box(root, "PorchPost", Vector3(x, 0.82, -2.30), Vector3(0.11, 1.55, 0.11), Color(0.09, 0.05, 0.025))
	elif facade_variant == 1:
		_add_house_box(root, "TradingAwning", Vector3(0.92, 1.36, -2.02), Vector3(1.45, 0.12, 0.74), Color(0.23, 0.12, 0.065), Vector3(-11, 0, 0))
		_add_house_box(root, "SupplyShelf", Vector3(1.18, 0.48, -2.02), Vector3(1.30, 0.12, 0.42), Color(0.10, 0.055, 0.03))
	else:
		_add_house_box(root, "SideLeanToRoof", Vector3(-2.48, 1.34, 0.46), Vector3(1.04, 0.16, 2.20), Color(0.13, 0.06, 0.035), Vector3(0, 0, -12))
		_add_house_box(root, "SideLeanToPost", Vector3(-2.82, 0.62, -0.36), Vector3(0.12, 1.22, 0.12), Color(0.09, 0.05, 0.025))

func _add_house_module(parent: Node3D, role_name: String, scale_value: Vector3, local_pos: Vector3, yaw: float, node_name: String) -> Node3D:
	var module := _make_role_visual(role_name, "environment", scale_value)
	if module == null:
		return null
	module.name = node_name
	module.position = local_pos
	module.rotation_degrees.y = yaw
	module.set_meta("world_001_module", true)
	parent.add_child(module)
	return module

func _add_house_gables(parent: Node3D, plaster: Color, timber: Color) -> void:
	var vertices := PackedVector3Array([
		Vector3(-2.08, 2.08, -1.69), Vector3(2.08, 2.08, -1.69), Vector3(0.0, 3.18, -1.69),
		Vector3(2.08, 2.08, 1.69), Vector3(-2.08, 2.08, 1.69), Vector3(0.0, 3.18, 1.69),
	])
	var normals := PackedVector3Array([
		Vector3.BACK, Vector3.BACK, Vector3.BACK,
		Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD,
	])
	var uvs := PackedVector2Array([
		Vector2(0, 1), Vector2(1, 1), Vector2(0.5, 0),
		Vector2(0, 1), Vector2(1, 1), Vector2(0.5, 0),
	])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var gable_mesh := ArrayMesh.new()
	gable_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var gables := MeshInstance3D.new()
	gables.name = "PlasteredGableWalls"
	gables.mesh = gable_mesh
	gables.material_override = world_materials.get_material("plaster", str(settings.settings.get("quality_preset", "balanced")), plaster.lightened(0.48), 0.0, false)
	parent.add_child(gables)
	for z in [-1.72, 1.72]:
		_add_house_box(parent, "GableKingPost", Vector3(0, 2.57, z), Vector3(0.13, 1.14, 0.10), timber)

func _add_house_box(parent: Node3D, node_name: String, local_pos: Vector3, size: Vector3, color: Color, local_rot: Vector3 = Vector3.ZERO) -> Node3D:
	# Keep named authored details while rendering repeated pieces in material batches.
	var marker := Node3D.new()
	marker.name = node_name
	marker.position = local_pos
	marker.rotation_degrees = local_rot
	parent.add_child(marker)
	var lower := node_name.to_lower()
	var surface := "plaster"
	if lower.contains("window"):
		surface = "emissive_window"
	elif lower.contains("roof") or lower.contains("awning") or lower.contains("canopy"):
		surface = "roof_tiles"
	elif lower.contains("timber") or lower.contains("door") or lower.contains("shutter") or lower.contains("post") or lower.contains("shelf"):
		surface = "timber"
	elif lower.contains("foundation") or lower.contains("stone") or lower.contains("step"):
		surface = "medieval_brick"
	var batch_key := surface if surface != "emissive_window" else "%s:%s" % [surface, color.to_html(false)]
	if not house_batch_data.has(batch_key):
		var material: Material
		if surface == "emissive_window":
			material = _emissive_mat(color, 0.7)
		else:
			material = world_materials.get_material(surface, str(settings.settings.get("quality_preset", "balanced")), Color.WHITE, 0.0, true).duplicate()
			(material as StandardMaterial3D).vertex_color_use_as_albedo = true
		house_batch_data[batch_key] = {"material": material, "transforms": [], "colors": []}
	var rotation_radians := Vector3(deg_to_rad(local_rot.x), deg_to_rad(local_rot.y), deg_to_rad(local_rot.z))
	var basis := Basis.from_euler(rotation_radians).scaled(size)
	var zone_transform: Transform3D = parent.transform * Transform3D(basis, local_pos)
	house_batch_data[batch_key].transforms.append(zone_transform)
	house_batch_data[batch_key].colors.append(Color.WHITE if surface == "emissive_window" else color.lightened(0.55))
	return marker

func _make_house_collision(parent: Node3D) -> void:
	var body = StaticBody3D.new()
	body.name = "HouseCollision"
	parent.add_child(body)
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(4.2, 2.4, 3.4)
	shape.shape = box
	shape.position.y = 1.2
	body.add_child(shape)

func _add_lit_window(parent: Node3D, local_pos: Vector3) -> void:
	var pane = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.52, 0.38, 0.035)
	pane.mesh = mesh
	pane.position = local_pos
	pane.material_override = _emissive_mat(Color(1.0, 0.58, 0.20), 0.85)
	parent.add_child(pane)

func _add_role_child(parent: Node3D, role_name: String, scale_value: Vector3, local_pos: Vector3, yaw: float) -> Node3D:
	var node = _make_role_visual(role_name, "environment", scale_value)
	if node == null:
		return null
	node.position = local_pos
	node.rotation_degrees.y = yaw
	parent.add_child(node)
	return node

func _make_village_dressing() -> void:
	for item in [
		["barrel", Vector3(-4.0, 0, 3.4), 0.56, -8.0],
		["barrel", Vector3(-4.8, 0, 4.1), 0.48, 15.0],
		["crate", Vector3(-7.3, 0, 4.9), 0.64, 25.0],
		["crate", Vector3(8.0, 0, 2.8), 0.72, -18.0],
		["barrel", Vector3(10.7, 0, 2.9), 0.58, 18.0],
		["forest_rock", Vector3(4.6, 0, -11.0), 0.55, 0.0],
		["forest_rock", Vector3(-4.8, 0, -12.4), 0.52, 0.0],
		["crate", Vector3(5.5, 0, -6.9), 0.46, -12.0],
		["barrel", Vector3(7.2, 0, -6.4), 0.46, 10.0]
	]:
		_make_loose_role(str(item[0]), item[1], Vector3.ONE * float(item[2]), float(item[3]))
	for pos in [Vector3(-3.8, 0, -6.0), Vector3(3.9, 0, -9.2), Vector3(-4.4, 0, -13.0)]:
		_make_rubble(pos)

func _make_wychwood_gate_scene(pos: Vector3) -> void:
	for offset in [-2.25, 2.25]:
		_make_torch(pos + Vector3(offset, 0, 0.2))
		_make_loose_role("fence", pos + Vector3(offset * 0.82, 0, 0.65), Vector3(0.92, 0.92, 0.92), 90.0)
	for offset in [Vector3(-4.2, 0, 1.4), Vector3(4.0, 0, 1.2), Vector3(-4.0, 0, -1.1), Vector3(3.9, 0, -1.0)]:
		_make_rubble(pos + offset)
	_make_fog_sheet(pos + Vector3(0, 0.75, -0.4), Vector3(6.2, 0.9, 1.9), Color(0.20, 0.24, 0.22, 0.16))

func _make_wychwood_route_dressing() -> void:
	for item in [
		["forest_rock", Vector3(-2.8, 0, 9.0), 1.0, 8.0],
		["forest_rock", Vector3(3.1, 0, 7.8), 0.8, -16.0],
		["forest_rock", Vector3(-3.4, 0, 1.6), 1.1, 22.0],
		["forest_rock", Vector3(3.7, 0, -1.7), 0.9, 0.0],
		["barrel", Vector3(-5.2, 0, 8.2), 0.48, 0.0],
		["crate", Vector3(-5.8, 0, 7.6), 0.56, 11.0]
	]:
		_make_loose_role(str(item[0]), item[1], Vector3.ONE * float(item[2]), float(item[3]))
	for pos in [Vector3(-4.7, 0, 11.5), Vector3(4.6, 0, 10.5), Vector3(-4.8, 0, 5.5), Vector3(4.8, 0, 3.0), Vector3(-5.0, 0, -2.0), Vector3(4.8, 0, -4.8)]:
		_make_deadfall(pos)
	for pos in [Vector3(-8.4, 0, 12.5), Vector3(8.3, 0, 11.8), Vector3(-8.6, 0, 4.8), Vector3(8.5, 0, 1.2), Vector3(-8.8, 0, -5.4), Vector3(8.7, 0, -7.2)]:
		_make_tree(pos)

func _make_quality_wychwood_overhaul() -> void:
	if str(settings.settings.get("quality_preset", "balanced")) != "quality":
		return
	var marker = Node3D.new()
	marker.name = "QualityWychwoodVisualOverhaul"
	zone_root.add_child(marker)
	for z in [12.0, 9.5, 7.0, 4.5, 2.0, -0.5, -3.0, -5.5, -8.0]:
		_make_visual_box("QualityWychwoodWetMud", Vector3(randf_range(-0.55, 0.55), 0.060, z), Vector3(randf_range(0.70, 1.55), 0.012, randf_range(0.42, 1.05)), Color(0.018, 0.027, 0.024))
		_make_visual_box("QualityWychwoodRootCrossing", Vector3(randf_range(-2.3, 2.3), 0.145, z + randf_range(-0.6, 0.6)), Vector3(randf_range(0.95, 1.8), 0.11, 0.13), Color(0.070, 0.038, 0.022))
	for z in [10.5, 7.5, 4.5, 1.5, -1.5, -4.5, -7.5]:
		_make_deadfall(Vector3(-5.8 + randf_range(-0.4, 0.2), 0, z))
		_make_deadfall(Vector3(5.8 + randf_range(-0.2, 0.4), 0, z + randf_range(-0.3, 0.3)))
		_make_tree(Vector3(-10.4, 0, z + randf_range(-0.5, 0.5)))
		_make_tree(Vector3(10.4, 0, z + randf_range(-0.5, 0.5)))
	for pos in [Vector3(-2.2,0,6.7), Vector3(2.6,0,4.6), Vector3(-2.8,0,1.2), Vector3(2.9,0,-1.8)]:
		_make_visual_box("QualityClueGroundDarkening", pos + Vector3(0, 0.065, 0), Vector3(1.15, 0.014, 0.56), Color(0.027, 0.022, 0.018))
	for pos in [Vector3(-4.8,0,-5.8), Vector3(4.6,0,-6.4), Vector3(-2.6,0,-8.8), Vector3(2.8,0,-8.3), Vector3(0.0,0,-6.2)]:
		_make_visual_box("QualityClearingBloodMud", pos + Vector3(0, 0.070, 0), Vector3(1.15, 0.014, 0.46), Color(0.070, 0.018, 0.012))
	for pos in [Vector3(-7.0,0,-10.4), Vector3(7.2,0,-10.0), Vector3(-6.8,0,-4.8), Vector3(6.7,0,-4.2)]:
		_make_fog_sheet(pos + Vector3(0, 0.85, 0), Vector3(4.4, 0.72, 1.45), Color(0.10, 0.18, 0.16, 0.18))
	for pos in [Vector3(-8.2,0,13.0), Vector3(8.0,0,12.8), Vector3(-6.5,0,8.8)]:
		_make_visual_box("QualityBrokenForestSign", pos + Vector3(0, 0.85, 0), Vector3(0.95, 0.12, 0.40), Color(0.11, 0.065, 0.034))
	_make_light("QualityForestBlueRim", Vector3(0, 3.6, -6.5), Color(0.22, 0.42, 0.58), 1.4)
	_make_light("QualityGateLastWarmth", Vector3(0, 2.6, 11.6), Color(1.0, 0.42, 0.14), 1.0)

func _make_loose_role(role_name: String, pos: Vector3, scale_value: Vector3, yaw: float) -> Node3D:
	var key = role_name.to_lower()
	if key == "forest_rock":
		_make_rubble(pos)
		return null
	if key == "crate":
		_make_prop_box("RouteCrate", pos + Vector3(0, 0.32 * scale_value.y, 0), Vector3(0.72, 0.64, 0.72) * scale_value, Color(0.20, 0.12, 0.065))
		return null
	if key == "barrel":
		_make_prop_box("RouteBarrel", pos + Vector3(0, 0.36 * scale_value.y, 0), Vector3(0.58, 0.72, 0.58) * scale_value, Color(0.17, 0.09, 0.045))
		return null
	if key == "fence":
		var fence_size = Vector3(1.9, 0.32, 0.18) * scale_value
		if abs(fposmod(yaw, 180.0) - 90.0) < 2.0:
			fence_size = Vector3(0.18, 0.32, 1.9) * scale_value
		_make_prop_box("RouteFence", pos + Vector3(0, 0.46, 0), fence_size, Color(0.15, 0.085, 0.045))
		return null
	var node = _make_role_visual(role_name, "environment", scale_value)
	if node == null:
		return null
	node.position = pos
	node.rotation_degrees.y = yaw
	zone_root.add_child(node)
	return node

func _make_roof(pos: Vector3, size: Vector3, color: Color) -> void:
	_make_prop_box("VillageRoof", pos, size, color)
	_make_prop_box("RoofRidge", pos + Vector3(0, 0.55, 0), Vector3(size.x * 0.18, 0.18, size.z * 1.05), color.darkened(0.18))

func _make_notice_board(pos: Vector3) -> void:
	_make_prop_box("NoticePost", pos + Vector3(-0.55, 0.7, 0), Vector3(0.16, 1.4, 0.16), Color(0.14, 0.08, 0.045))
	_make_prop_box("NoticePost", pos + Vector3(0.55, 0.7, 0), Vector3(0.16, 1.4, 0.16), Color(0.14, 0.08, 0.045))
	_make_prop_box("NoticeBoard", pos + Vector3(0, 1.25, 0), Vector3(1.55, 0.9, 0.12), Color(0.28, 0.16, 0.08))

func _make_route_markers() -> void:
	for pos in [Vector3(-0.9, 0, -4.5), Vector3(0.95, 0, -8.2), Vector3(-0.7, 0, -11.4)]:
		_make_prop_box("RoadCandle", pos + Vector3(0, 0.18, 0), Vector3(0.14, 0.36, 0.14), Color(0.20, 0.11, 0.05))
		var flame = MeshInstance3D.new()
		flame.mesh = SphereMesh.new()
		flame.scale = Vector3(0.12, 0.18, 0.12)
		flame.position = pos + Vector3(0, 0.48, 0)
		flame.material_override = _emissive_mat(Color(1.0, 0.48, 0.16), 1.1)
		zone_root.add_child(flame)
		_make_light("RoadCandleGlow", pos + Vector3(0, 0.72, 0), Color(1.0, 0.45, 0.16), 0.8)

func _make_shrine_scene(pos: Vector3) -> void:
	_make_prop_box("ShrineBase", pos + Vector3(0, 0.15, 0), Vector3(2.0, 0.3, 1.4), Color(0.26, 0.25, 0.23))
	_make_prop_box("ShrineStone", pos + Vector3(0, 0.95, -0.1), Vector3(0.55, 1.55, 0.32), Color(0.46, 0.45, 0.40))
	_make_prop_box("ShrineGlow", pos + Vector3(0, 1.05, -0.29), Vector3(0.08, 0.6, 0.03), Color(0.68, 0.86, 0.70))
	_make_prop_box("ShrineOfferings", pos + Vector3(-0.65, 0.36, -0.45), Vector3(0.52, 0.16, 0.34), Color(0.28, 0.18, 0.10))
	_make_prop_box("ShrineCloth", pos + Vector3(0.58, 0.38, -0.42), Vector3(0.46, 0.08, 0.32), Color(0.36, 0.08, 0.07))
	_make_loose_role("shrine", pos + Vector3(0, 0.15, -0.05), Vector3(1.45, 1.45, 1.45), 0.0)
	_make_loose_role("crate", pos + Vector3(-1.15, 0, -0.65), Vector3.ONE * 0.48, -12.0)
	_make_loose_role("barrel", pos + Vector3(1.2, 0, -0.55), Vector3.ONE * 0.42, 16.0)
	_make_light("ShrineGlow", pos + Vector3(0, 1.7, -0.3), Color(0.56, 0.78, 0.62), 1.6)

func _make_blacksmith_scene(pos: Vector3) -> void:
	_make_prop_box("BlacksmithShop", pos + Vector3(0, 0.9, 1.2), Vector3(3.4, 1.8, 2.4), Color(0.20, 0.15, 0.11))
	_make_prop_box("Forge", pos + Vector3(1.5, 0.55, -1.1), Vector3(1.0, 1.1, 0.75), Color(0.12, 0.11, 0.10))
	_make_prop_box("ForgeCoal", pos + Vector3(1.5, 1.15, -1.1), Vector3(0.75, 0.12, 0.55), Color(0.95, 0.30, 0.08))
	_make_light("ForgeLight", pos + Vector3(1.5, 1.5, -1.1), Color(1.0, 0.35, 0.12), 2.5)
	var anvil = _make_role_visual("blacksmith_shop", "environment", Vector3(0.9, 0.9, 0.9))
	if anvil != null:
		anvil.position = pos + Vector3(-1.2, 0, -0.35)
		zone_root.add_child(anvil)
	_make_loose_role("crate", pos + Vector3(-2.2, 0, 0.35), Vector3.ONE * 0.62, 9.0)
	_make_loose_role("barrel", pos + Vector3(2.15, 0, 0.95), Vector3.ONE * 0.55, -20.0)
	_make_torch(pos + Vector3(-1.8, 0, -1.2))

func _make_cemetery_scene(pos: Vector3) -> void:
	_make_prop_box("CemeteryWall", pos + Vector3(0, 0.35, 1.9), Vector3(7.0, 0.7, 0.45), Color(0.18, 0.18, 0.17))
	for i in range(5):
		_make_gravestone(pos + Vector3(-2.6 + i * 1.3, 0, 0.4 + (i % 2) * 0.75))
	for offset in [Vector3(-3.4, 0, 2.0), Vector3(3.2, 0, 1.8), Vector3(0.4, 0, 2.2)]:
		_make_rubble(pos + offset)
	_make_fog_sheet(pos + Vector3(0, 0.55, 0.8), Vector3(7.2, 0.7, 2.8), Color(0.18, 0.18, 0.16, 0.11))

func _make_tree_cluster(points: Array) -> void:
	for pos in points:
		_make_tree(pos)

func _make_collapsed_road(pos: Vector3) -> void:
	_make_prop_box("BlockedRoadBerm", pos + Vector3(0.8, 0.65, 0), Vector3(3.2, 1.3, 5.4), Color(0.10, 0.095, 0.075))
	_make_prop_box("BlockedRoadPalisade", pos + Vector3(-0.1, 1.05, -1.25), Vector3(0.28, 2.1, 0.28), Color(0.13, 0.075, 0.04))
	_make_prop_box("BlockedRoadPalisade", pos + Vector3(-0.1, 1.05, 1.25), Vector3(0.28, 2.1, 0.28), Color(0.13, 0.075, 0.04))
	_make_prop_box("BlockedRoadRail", pos + Vector3(-0.15, 1.25, 0), Vector3(0.28, 0.28, 3.4), Color(0.15, 0.08, 0.045))
	for offset in [Vector3(0.5, 0, -1.8), Vector3(1.0, 0, 1.6), Vector3(1.4, 0, 0.2)]:
		_make_rubble(pos + offset)
	_make_torch(pos + Vector3(-1.0, 0, -2.1))

func _make_monster_clearing(pos: Vector3) -> void:
	var marker = Node3D.new()
	marker.name = "FirstCombatReadabilityDressing"
	marker.position = pos
	zone_root.add_child(marker)
	_make_road(pos + Vector3(0, 0.023, 0), Vector3(9.0, 0.045, 6.8), Color(0.045, 0.050, 0.042))
	_make_combat_readability_marks(pos)
	_make_light("ClearingColdSpot", pos + Vector3(0, 2.8, -0.4), Color(0.35, 0.48, 0.58), 2.4)
	_make_light("ClearingRimLantern", pos + Vector3(-3.2, 1.9, 1.8), Color(0.9, 0.38, 0.14), 1.2)
	_make_fog_sheet(pos + Vector3(0, 0.55, 0), Vector3(8, 1, 4.5), Color(0.18, 0.25, 0.22, 0.22))
	_make_fog_sheet(pos + Vector3(0, 1.15, -1.8), Vector3(9.2, 1, 3.0), Color(0.16, 0.20, 0.19, 0.16))
	for offset in [Vector3(-5.2,0,-2.9), Vector3(5.2,0,-2.4), Vector3(-5.0,0,2.8), Vector3(5.0,0,3.0)]:
		_make_deadfall(pos + offset)
	for offset in [Vector3(-6.2,0,-3.4), Vector3(6.2,0,-3.2), Vector3(-6.4,0,3.4), Vector3(6.3,0,3.3)]:
		_make_tree(pos + offset)
	for offset in [Vector3(-2.0,0,-1.1), Vector3(1.7,0,-1.4), Vector3(-0.6,0,1.4)]:
		_make_prop_box("BonePile", pos + offset + Vector3(0, 0.09, 0), Vector3(0.9, 0.18, 0.36), Color(0.46, 0.42, 0.35))
	for offset in [Vector3(-1.2,0,0.8), Vector3(1.1,0,0.6), Vector3(0.2,0,-1.9)]:
		_make_prop_box("BlackFeatherScatter", pos + offset + Vector3(0, 0.035, 0), Vector3(0.55, 0.04, 0.10), Color(0.015, 0.014, 0.016))
	for offset in [Vector3(-4.2,0,0.1), Vector3(4.2,0,0.0), Vector3(0,0,-3.2)]:
		_make_rubble(pos + offset)
	_make_loose_role("crate", pos + Vector3(-4.2, 0, 2.1), Vector3.ONE * 0.48, 18.0)
	_make_loose_role("barrel", pos + Vector3(-4.9, 0, 1.4), Vector3.ONE * 0.42, -8.0)
	_make_torch(pos + Vector3(-4.2, 0, 2.1))

func _make_combat_readability_marks(pos: Vector3) -> void:
	_make_visual_box("CombatClearingCenterRead", pos + Vector3(0, 0.054, -0.1), Vector3(2.2, 0.018, 1.55), Color(0.070, 0.052, 0.038))
	for x in [-2.9, 2.9]:
		_make_visual_box("CombatLaneEdge", pos + Vector3(x, 0.056, -0.35), Vector3(0.18, 0.020, 4.6), Color(0.055, 0.070, 0.052))
	for offset in [Vector3(-2.4, 0, -2.6), Vector3(2.4, 0, -2.6), Vector3(-2.6, 0, 1.9), Vector3(2.6, 0, 1.9)]:
		_make_visual_box("CombatSafeFootingStone", pos + offset + Vector3(0, 0.062, 0), Vector3(0.72, 0.035, 0.40), Color(0.16, 0.14, 0.115))
	for offset in [Vector3(-3.8, 0, -1.9), Vector3(3.8, 0, -1.6), Vector3(-3.8, 0, 1.6), Vector3(3.8, 0, 1.4)]:
		_make_visual_box("CombatBoundaryRoot", pos + offset + Vector3(0, 0.14, 0), Vector3(1.15, 0.16, 0.18), Color(0.10, 0.060, 0.035))

func _make_named_interactable(id: String, type: String, prompt: String, pos: Vector3, color: Color, scale_override: Vector3 = Vector3.ONE):
	if _is_interaction_removed(id):
		return null
	pos = river_safe_position(pos,0.8)
	var area = Interactable.new()
	area.setup(id, type, prompt)
	area.position = pos
	area.build_collision(2.8 if type == "zone" else 1.45)
	zone_root.add_child(area)
	var role = _role_for_interactable(id)
	var mapped = _make_role_visual(role, "characters", Vector3.ONE)
	if mapped != null:
		area.add_child(mapped)
		_configure_npc_animation(mapped, id)
	elif type == "zone" or type == "blocked_zone":
		_make_gate_marker(area, color, scale_override)
	else:
		var mesh = MeshInstance3D.new()
		mesh.mesh = CapsuleMesh.new()
		mesh.scale = Vector3(0.45, 0.85, 0.45) * scale_override
		mesh.position.y = 0.85 * scale_override.y
		mesh.material_override = _mat(color)
		area.add_child(mesh)
	var has_character_role: bool = str(role) != ""
	if type == "dialogue" and id != "notice_board" and has_character_role:
		CharacterPresentation.apply_npc(area, id)
	if type != "clue" and type != "herb" and id != "notice_board":
		var label = Label3D.new()
		label.name = "InteractionWorldLabel"
		label.text = _label_for_interactable(id, prompt)
		label.position = Vector3(0, 2.15 * max(scale_override.y, 0.75), 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 22
		label.pixel_size = 0.009
		label.modulate = Color(0.84, 0.78, 0.62)
		label.outline_size = 5
		label.outline_modulate = Color(0.02, 0.018, 0.015)
		label.visible = false
		area.add_child(label)
	if type == "dialogue" and id != "notice_board" and has_character_role:
		var ambient = NpcAmbient.new()
		ambient.setup(id, player)
		area.add_child(ambient)
	_connect_interactable(area)
	return area

func _make_village_place(id: String, type: String, prompt: String, pos: Vector3, size: Vector3, color: Color):
	pos = river_safe_position(pos,maxf(size.z*0.5,0.8))
	var area = Interactable.new()
	area.setup(id,type,prompt)
	area.position = pos
	area.build_collision(1.35)
	zone_root.add_child(area)
	var table := MeshInstance3D.new()
	table.name = "%s_VisibleProp" % id
	var mesh := BoxMesh.new()
	mesh.size = size
	table.mesh = mesh
	table.position.y = size.y * 0.5
	table.material_override = _mat(color)
	area.add_child(table)
	if type == "minigame":
		var board := MeshInstance3D.new()
		board.name = "%s_GameBoard" % id
		var board_mesh := BoxMesh.new()
		board_mesh.size = Vector3(size.x * 0.72,0.06,size.z * 0.72)
		board.mesh = board_mesh
		board.position.y = size.y + 0.05
		board.material_override = _mat(Color(0.62,0.50,0.30))
		area.add_child(board)
	var label := Label3D.new()
	label.name = "InteractionWorldLabel"
	label.text = prompt
	label.position = Vector3(0,size.y+0.7,0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 18
	label.pixel_size = 0.008
	label.modulate = Color(0.84,0.78,0.62)
	label.visible = false
	area.add_child(label)
	_connect_interactable(area)
	return area

func _configure_npc_animation(mapped: Node3D, id: String) -> void:
	var clips := {"idle": "Idle", "walk": "Walk", "run": "Run", "hit": "RecieveHit", "death": "Death"}
	if id == "sister_anwen":
		clips["idle"] = "Idle"
	elif id == "rook":
		clips["idle"] = "Attacking_Idle"
		clips["hit"] = "RecieveHit_2"
	var driver = CharacterAnimationDriver.new()
	driver.name = "CharacterAnimationDriver"
	mapped.add_child(driver)
	driver.configure(mapped, clips)

func _stage_dialogue_moment(area) -> void:
	if player == null or area == null or not (area is Node3D):
		return
	var npc = area as Node3D
	var flat_to_player = player.global_position - npc.global_position
	flat_to_player.y = 0.0
	if area.interaction_id == "sister_anwen":
		npc.set_meta("dialogue_facing_lock", true)
	if player.has_method("face_target"):
		player.face_target(npc.global_position)
	var to_player = player.global_position - npc.global_position
	to_player.y = 0.0
	if to_player.length() > 0.1:
		var staged_yaw := rad_to_deg(atan2(-to_player.x,-to_player.z))
		if area.interaction_id == "sister_anwen":
			staged_yaw += 180.0
		npc.rotation_degrees.y = staged_yaw

func _release_dialogue_facing() -> void:
	audio.stop_voice()
	if zone_root == null:
		return
	var anwen = zone_root.find_child("sister_anwen", true, false)
	if anwen != null:
		anwen.set_meta("dialogue_facing_lock", false)
	if pending_anwen_relocation:
		pending_anwen_relocation = false
		_relocate_anwen_to_cemetery()

func _make_gate_marker(parent: Node3D, color: Color, scale_override: Vector3) -> void:
	var arch = MeshInstance3D.new()
	var arch_mesh = BoxMesh.new()
	arch_mesh.size = Vector3(1.2, 1.6, 0.18)
	arch.mesh = arch_mesh
	arch.position.y = 0.8
	arch.scale = scale_override
	arch.material_override = _mat(color)
	parent.add_child(arch)
	var lintel = MeshInstance3D.new()
	var lintel_mesh = BoxMesh.new()
	lintel_mesh.size = Vector3(1.75, 0.22, 0.26)
	lintel.mesh = lintel_mesh
	lintel.position.y = 1.65 * scale_override.y
	lintel.material_override = _mat(color.lightened(0.12))
	parent.add_child(lintel)

func _label_for_interactable(id: String, prompt: String) -> String:
	if dialogue != null and dialogue.dialogues.has(id):
		return dialogue.dialogues[id].get("name", prompt)
	if id.begins_with("gate_"):
		return prompt
	return prompt.replace("Inspect ", "").replace("Gather ", "").replace("Take ", "")

func _make_clue(id: String, prompt: String, pos: Vector3, quest_id: String, objective_id: String, color: Color):
	var area = _make_named_interactable(id, "clue", prompt, pos, color, Vector3(0.55, 0.25, 0.55))
	if area == null:
		return null
	area.quest_id = quest_id
	area.objective_id = objective_id
	return area

func _make_herb(id: String, pos: Vector3, color: Color):
	return _make_named_interactable(id, "herb", "Gather %s" % id.capitalize(), pos, color, Vector3(0.35, 0.35, 0.35))

func _make_zone_gate(prompt: String, pos: Vector3, zone_target: String, spawn_pos: Vector3):
	var area = _make_named_interactable("gate_%s" % zone_target, "zone", prompt, pos, Color(0.18, 0.22, 0.28), Vector3(1.0, 1.2, 1.0))
	if area == null:
		return null
	area.zone_target = zone_target
	area.set_meta("spawn_pos", spawn_pos)
	return area

func _make_blocked_gate(prompt: String, pos: Vector3, message: String):
	var area = _make_named_interactable("blocked_ruins", "blocked_zone", prompt, pos, Color(0.20, 0.16, 0.11), Vector3(0.8, 0.8, 0.8))
	if area == null:
		return null
	area.set_meta("message", message)
	return area

func _connect_interactable(area) -> void:
	area.body_entered.connect(func(body: Node):
		if body == player and area not in interaction_candidates:
			interaction_candidates.append(area)
	)
	area.body_exited.connect(func(body: Node):
		if body == player:
			interaction_candidates.erase(area)
			_set_interactable_label_visible(area,false)
			if active_interactable == area:
				active_interactable = null
	)

func _update_interaction_focus() -> void:
	var best = null
	var best_score := -999.0
	var camera := get_viewport().get_camera_3d()
	var forward: Vector3 = -camera.global_basis.z if camera != null else -player.global_basis.z
	for candidate in interaction_candidates.duplicate():
		if candidate == null or not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
			interaction_candidates.erase(candidate)
			continue
		var offset: Vector3 = candidate.global_position-player.global_position
		var distance := offset.length()
		var focus_range := 3.6 if candidate.interaction_type == "zone" else 2.8
		if distance > focus_range or distance < 0.01:
			continue
		var facing := forward.dot(offset.normalized())
		if (candidate.interaction_type != "zone" and facing < 0.12) or not _interaction_target_valid(candidate):
			continue
		var priority := 0.0
		if candidate.interaction_type == "dialogue": priority += 0.18
		if candidate.interaction_type == "clue" and quests.is_active(candidate.quest_id): priority += 0.45
		if candidate.interaction_type == "zone": priority += 1.25
		var score := 100.0 - distance if candidate.interaction_type == "zone" else facing*2.2-distance*0.42+priority
		if score > best_score:
			best_score = score
			best = candidate
	if active_interactable != best:
		if active_interactable != null and is_instance_valid(active_interactable):
			_set_interactable_label_visible(active_interactable,false)
		active_interactable = best
		if active_interactable != null:
			_set_interactable_label_visible(active_interactable,true)
	if active_interactable != null:
		hud.set_prompt("E  %s" % active_interactable.get_context_prompt())
	else:
		hud.set_prompt("")

func _interaction_target_valid(area: Area3D) -> bool:
	if player == null or area == null or not is_instance_valid(area):
		return false
	# Travel volumes sit inside authored gate/berm geometry. Camera rays can hit
	# that framing even while Kael is correctly standing in the gate trigger.
	if area.interaction_type == "zone":
		return player.global_position.distance_to(area.global_position) <= 3.65
	var camera := get_viewport().get_camera_3d()
	var origin: Vector3 = camera.global_position if camera != null else player.global_position + Vector3.UP
	var target: Vector3 = area.global_position + Vector3.UP * 0.5
	var direction := origin.direction_to(target)
	var forward: Vector3 = -camera.global_basis.z if camera != null else -player.global_basis.z
	if forward.dot(direction) < 0.22:
		return false
	var query := PhysicsRayQueryParameters3D.create(origin, target)
	query.exclude = [player.get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty()

func _set_interactable_label_visible(area: Node, visible: bool) -> void:
	var label := area.find_child("InteractionWorldLabel", true, false) as Label3D
	if label != null:
		label.visible = visible

func _spawn_enemy(id: String, pos: Vector3) -> Node:
	if active_enemies.size() >= 5:
		return null
	pos = river_safe_position(pos,1.2)
	var enemy = EnemyAI.new()
	# Keep the actor hidden while imported surfaces are normalized and receive
	# their validated overrides. Grounding still needs an in-tree transform.
	enemy.visible = false
	zone_root.add_child(enemy)
	enemy.global_position = pos
	enemy.setup(id, enemy_defs.get(id, {}), player)
	enemy.visible = true
	enemy.encounter_slot = active_enemies.size()
	enemy.setup_navigation(spatial_service)
	if current_zone_id == "wychwood" and id in ["wychwood_stalker", "wychwood_raider", "wychwood_brute"]:
		enemy.set_encounter_active(false)
	enemy.attack_gate = _enemy_attack_token
	if id == "ghoulkin":
		enemy.rotation_degrees.y = 180.0
		if audio != null and current_zone_id == "wychwood" and not bool(tutorial_flags.get("ghoulkin_spawn_audio", false)):
			tutorial_flags["ghoulkin_spawn_audio"] = true
			audio.play_event("ghoulkin_idle", 0.025)
	enemy.died.connect(_on_enemy_died)
	enemy.damaged.connect(_on_enemy_damaged)
	enemy.windup_started.connect(_on_enemy_windup_started)
	enemy.attack_resolved.connect(_on_enemy_attack_resolved)
	enemy.boss_phase_changed.connect(_on_boss_phase_changed)
	active_enemies.append(enemy)
	return enemy

func _on_boss_phase_changed(enemy: Node, phase: int) -> void:
	if enemy == null or not is_instance_valid(enemy) or enemy.enemy_id != "white_hart_avatar":
		return
	var cue := "The Hart tears roots from the old road." if phase == 2 else "The covenant is breaking."
	hud.show_status_cue("White Hart — Phase %d" % phase, "danger")
	hud.toast(cue)
	audio.play_event("reveal" if phase == 2 else "boss", 0.025)
	if world_vfx != null and is_instance_valid(world_vfx):
		world_vfx.pulse_interaction(enemy.global_position)
	CombatFeedback.impact_burst(zone_root, enemy.global_position + Vector3.UP, true, Color(0.58, 0.88, 0.72))

func _activate_wychwood_wave(ids: Array, cue: String) -> void:
	for enemy in active_enemies:
		if enemy != null and not enemy.dead and enemy.enemy_id in ids:
			enemy.set_encounter_active(true)
	if hud != null:
		hud.toast(cue)
	if audio != null:
		audio.play_event("reveal", 0.02)

func _enemy_attack_token(enemy: Node, claim: bool) -> bool:
	if claim:
		if active_enemy_attacker != null and is_instance_valid(active_enemy_attacker) and active_enemy_attacker != enemy:
			return false
		active_enemy_attacker = enemy
		return true
	if active_enemy_attacker == enemy:
		active_enemy_attacker = null
	return true

func _make_ground(pos: Vector3, size: Vector3, color: Color) -> void:
	var body = StaticBody3D.new()
	body.position = pos
	zone_root.add_child(body)
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh = MeshInstance3D.new()
	mesh.mesh = shared_box_mesh
	mesh.scale = size
	mesh.material_override = _terrain_material("CampaignGround", color)
	body.add_child(mesh)

func _make_split_ground(width: float, depth: float, river_z: float, river_span: float, color: Color) -> void:
	var south_edge := river_z + river_span * 0.5
	var north_edge := river_z - river_span * 0.5
	var north_depth := north_edge + depth * 0.5
	var south_depth := depth * 0.5 - south_edge
	_make_ground(Vector3(0,-0.08,-depth*0.5+north_depth*0.5),Vector3(width,0.16,north_depth),color)
	_make_ground(Vector3(0,-0.08,south_edge+south_depth*0.5),Vector3(width,0.16,south_depth),color)

func _make_hut(pos: Vector3) -> void:
	_make_prop_box("Hut", pos + Vector3(0, 1, 0), Vector3(3.6, 2, 3.0), Color(0.22, 0.16, 0.12))
	_make_prop_box("Roof", pos + Vector3(0, 2.25, 0), Vector3(4.2, 0.8, 3.6), Color(0.10, 0.09, 0.08))
	_make_prop_box("Door", pos + Vector3(0, 0.65, -1.54), Vector3(0.75, 1.25, 0.08), Color(0.10, 0.07, 0.045))
	_make_prop_box("Chimney", pos + Vector3(1.1, 2.95, 0.4), Vector3(0.38, 0.9, 0.38), Color(0.12, 0.11, 0.10))

func _make_tree(pos: Vector3) -> void:
	if _is_river_excluded(pos,1.5):
		return
	pos = _route_safe_position(pos, 4.9)
	if spatial_service != null and spatial_service.is_reserved(pos, 1.35):
		return
	if _is_first_route_clearance(pos, 1.55):
		return
	var radius := randf_range(1.0, 1.35)
	var height := randf_range(2.0, 2.7)
	var yaw := randf_range(0.0, TAU)
	tree_batch_data.append({
		"trunk": Transform3D(Basis.IDENTITY, pos + Vector3(0, 0.9, 0)),
		"crown": Transform3D(Basis.from_euler(Vector3(0, yaw, 0)).scaled(Vector3(radius, height, radius)), pos + Vector3(0, 2.35, 0)),
		"color": Color(0.055, 0.18, 0.085).lerp(Color(0.13, 0.24, 0.11), randf())
	})
	if tree_collision_body == null:
		tree_collision_body = StaticBody3D.new()
		tree_collision_body.name = "BatchedTreeCollisions"
		zone_root.add_child(tree_collision_body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.78, 3.6, 0.78)
	shape.shape = box
	shape.position = pos + Vector3(0, 2.1, 0)
	tree_collision_body.add_child(shape)

func _make_tree_wall(axis_extent: float, fixed_pos: float, count: int, along_x: bool) -> void:
	for i in range(count):
		var t: float = 0.0 if count <= 1 else float(i) / float(count - 1)
		var offset: float = lerp(-axis_extent, axis_extent, t)
		var pos = Vector3(offset, 0, fixed_pos) if along_x else Vector3(fixed_pos, 0, offset)
		_make_tree(pos + Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.5, 0.5)))

func _make_deadfall(pos: Vector3) -> void:
	if _is_river_excluded(pos,1.8):
		return
	var rotation := Vector3(deg_to_rad(88.0), deg_to_rad(randf_range(-20.0, 20.0)), deg_to_rad(randf_range(-8.0, 8.0)))
	deadfall_batch_data.append(Transform3D(Basis.from_euler(rotation), pos + Vector3(0, 0.35, 0)))

func _flush_environment_batches() -> void:
	var terrain_groups: Dictionary = {}
	for item in terrain_patch_batch_data:
		var color: Color = item.color
		var terrain_key := "%d_%d_%d" % [int(color.r * 3.0), int(color.g * 3.0), int(color.b * 3.0)]
		if not terrain_groups.has(terrain_key):
			terrain_groups[terrain_key] = {"material":item.material,"items":[]}
		terrain_groups[terrain_key].items.append(item)
	for terrain_key in terrain_groups:
		var terrain_group: Dictionary = terrain_groups[terrain_key]
		var terrain_items: Array = terrain_group.items
		var terrain_batch := _make_multimesh_batch("TerrainPatchBatch_%s" % terrain_key, shared_box_mesh, terrain_items.size(), terrain_group.material)
		for i in range(terrain_items.size()):
			var marker: Node3D = terrain_items[i].node
			var patch_size: Vector3 = terrain_items[i].size
			terrain_batch.multimesh.set_instance_transform(i, Transform3D(marker.basis.scaled(patch_size), marker.position))
			marker.queue_free()
	var visual_groups: Dictionary = {}
	for item in visual_box_batch_data:
		var color: Color = item.color
		var visual_key := "%d_%d_%d" % [int(color.r * 3.0), int(color.g * 3.0), int(color.b * 3.0)]
		if not visual_groups.has(visual_key):
			visual_groups[visual_key] = {"material": _mat(color), "items": []}
		visual_groups[visual_key].items.append(item)
	for visual_key in visual_groups:
		var group: Dictionary = visual_groups[visual_key]
		var items: Array = group.items
		var detail_batch := _make_multimesh_batch("AuthoredDetailBatch_%s" % visual_key, shared_box_mesh, items.size(), group.material)
		for i in range(items.size()):
			var marker: Node3D = items[i].node
			var detail_size: Vector3 = items[i].size
			detail_batch.multimesh.set_instance_transform(i, Transform3D(marker.basis.scaled(detail_size), marker.position))
			marker.queue_free()
	for house_key in house_batch_data:
		var house_group: Dictionary = house_batch_data[house_key]
		var house_transforms: Array = house_group.transforms
		if house_transforms.is_empty():
			continue
		var house_batch := _make_multimesh_batch(
			"HouseBatch_%s" % str(house_key).replace(":", "_"),
			shared_box_mesh,
			house_transforms.size(),
			house_group.material,
			true
		)
		for transform_index in range(house_transforms.size()):
			house_batch.multimesh.set_instance_transform(transform_index, house_transforms[transform_index])
			house_batch.multimesh.set_instance_color(transform_index, house_group.colors[transform_index])
	for batch_key in prop_batch_data:
		var entry: Dictionary = prop_batch_data[batch_key]
		var transforms: Array = entry.get("transforms", [])
		if transforms.is_empty():
			continue
		var batch := _make_multimesh_batch("WorldPropBatch_%s" % str(batch_key), shared_box_mesh, transforms.size(), entry.get("material"))
		for i in range(transforms.size()):
			batch.multimesh.set_instance_transform(i, transforms[i])
	if not tree_batch_data.is_empty():
		var trunk_mesh := BoxMesh.new()
		trunk_mesh.size = Vector3(0.42, 1.8, 0.42)
		var trunks := _make_multimesh_batch("TreeTrunkBatch", trunk_mesh, tree_batch_data.size(), world_materials.get_material("timber", str(settings.settings.get("quality_preset", "balanced")), Color(0.42, 0.30, 0.20), 0.0, false))
		var crown_mesh := CylinderMesh.new()
		crown_mesh.top_radius = 0.38
		crown_mesh.bottom_radius = 1.0
		crown_mesh.height = 1.0
		crown_mesh.radial_segments = 7
		var crown_material := _mat(Color.WHITE)
		crown_material.vertex_color_use_as_albedo = true
		var crowns := _make_multimesh_batch("TreeCrownBatch", crown_mesh, tree_batch_data.size(), crown_material, true)
		for i in range(tree_batch_data.size()):
			trunks.multimesh.set_instance_transform(i, tree_batch_data[i].trunk)
			crowns.multimesh.set_instance_transform(i, tree_batch_data[i].crown)
			crowns.multimesh.set_instance_color(i, tree_batch_data[i].color)
	if not deadfall_batch_data.is_empty():
		var deadfall_mesh := CylinderMesh.new()
		deadfall_mesh.top_radius = 0.16
		deadfall_mesh.bottom_radius = 0.22
		deadfall_mesh.height = 3.4
		deadfall_mesh.radial_segments = 7
		var deadfalls := _make_multimesh_batch("DeadfallBatch", deadfall_mesh, deadfall_batch_data.size(), world_materials.get_material("timber", str(settings.settings.get("quality_preset", "balanced")), Color(0.34, 0.25, 0.17), 0.0, false))
		for i in range(deadfall_batch_data.size()):
			deadfalls.multimesh.set_instance_transform(i, deadfall_batch_data[i])
	environment_batches_flushed = true

func _make_multimesh_batch(node_name: String, mesh: Mesh, count: int, material: Material, use_colors: bool = false) -> MultiMeshInstance3D:
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = use_colors
	var base_mesh := mesh if mesh != null else shared_box_mesh
	_ensure_mesh_surface_materials(base_mesh, _valid_material_or_fallback(null))
	batch.mesh = base_mesh
	batch.instance_count = count
	instance.multimesh = batch
	instance.material_override = _valid_material_or_fallback(material)
	instance.visibility_range_end = 58.0
	zone_root.add_child(instance)
	return instance

func _valid_material_or_fallback(material: Material) -> Material:
	if material != null:
		return material
	if world_materials != null and world_materials.has_method("get_fallback_material"):
		return world_materials.get_fallback_material()
	return _first_route_material("ground")

func _ensure_mesh_surface_materials(mesh: Mesh, fallback: Material) -> int:
	if mesh == null or fallback == null:
		return 0
	var applied := 0
	for surface_index in range(mesh.get_surface_count()):
		if mesh.surface_get_material(surface_index) == null:
			mesh.surface_set_material(surface_index, fallback)
			applied += 1
	return applied

func _validate_zone_render_resources(root: Node) -> Dictionary:
	var report := {
		"mesh_instances": 0,
		"multimesh_instances": 0,
		"fallbacks_applied": 0,
		"invalid_geometry": 0,
		"invalid_geometry_names": [],
	}
	if root == null:
		return report
	var fallback := _valid_material_or_fallback(null)
	for mesh_node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		report.mesh_instances += 1
		if mesh_instance.mesh == null:
			if not mesh_instance.is_queued_for_deletion():
				report.invalid_geometry += 1
				report.invalid_geometry_names.append(str(mesh_instance.name))
			continue
		if mesh_instance.mesh.get_surface_count() == 0:
			mesh_instance.material_override = fallback
			report.fallbacks_applied += 1
			continue
		# RenderingServer consults the mesh's base surface material while releasing
		# skinned instances, even when an instance override is present.
		report.fallbacks_applied += _ensure_mesh_surface_materials(mesh_instance.mesh, fallback)
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var effective := mesh_instance.get_surface_override_material(surface_index)
			if effective == null:
				effective = mesh_instance.mesh.surface_get_material(surface_index)
			if effective == null:
				var replacement := mesh_instance.material_override if mesh_instance.material_override != null else fallback
				mesh_instance.set_surface_override_material(surface_index, replacement)
				report.fallbacks_applied += 1
	for batch_node in root.find_children("*", "MultiMeshInstance3D", true, false):
		var batch_instance := batch_node as MultiMeshInstance3D
		report.multimesh_instances += 1
		if batch_instance.multimesh == null or batch_instance.multimesh.mesh == null:
			report.invalid_geometry += 1
			report.invalid_geometry_names.append(str(batch_instance.name))
			continue
		report.fallbacks_applied += _ensure_mesh_surface_materials(batch_instance.multimesh.mesh, fallback)
		if batch_instance.material_override == null:
			batch_instance.material_override = fallback
			report.fallbacks_applied += 1
	root.set_meta("zone_render_resource_report", report)
	return report

func _make_road(pos: Vector3, size: Vector3, color: Color) -> void:
	var mesh = MeshInstance3D.new()
	mesh.name = "PavedRoad" if current_zone_id == "greyfen" else "MudRoad"
	var cube = BoxMesh.new()
	cube.size = size
	mesh.mesh = cube
	mesh.position = pos
	mesh.material_override = _road_material(current_zone_id == "greyfen", color)
	zone_root.add_child(mesh)

func _make_fence(pos: Vector3, vertical: bool) -> void:
	_make_prop_box("FencePost", pos + Vector3(0, 0.2, 0), Vector3(0.16, 0.8, 0.16), Color(0.15, 0.09, 0.055))
	var rail_size = Vector3(2.5, 0.12, 0.12)
	if vertical:
		rail_size = Vector3(0.12, 0.12, 2.5)
	_make_prop_box("FenceRail", pos + Vector3(0, 0.52, 0), rail_size, Color(0.17, 0.105, 0.06))

func _make_gravestone(pos: Vector3) -> void:
	_make_prop_box("Gravestone", pos + Vector3(0, 0.45, 0), Vector3(0.45, 0.9, 0.18), Color(0.31, 0.31, 0.30))
	_make_prop_box("GraveBase", pos + Vector3(0, 0.09, 0.34), Vector3(0.75, 0.16, 1.0), Color(0.11, 0.10, 0.09))
	_make_prop_box("GraveMoss", pos + Vector3(0.08, 0.72, -0.095), Vector3(0.18, 0.20, 0.025), Color(0.09, 0.18, 0.08))

func _make_cart(pos: Vector3) -> void:
	pos = river_safe_position(pos,1.0)
	_make_prop_box("BrokenCartBed", pos + Vector3(0, 0.45, 0), Vector3(2.0, 0.28, 1.1), Color(0.17, 0.10, 0.055))
	for x in [-0.78, 0.78]:
		var wheel = MeshInstance3D.new()
		var mesh = CylinderMesh.new()
		mesh.top_radius = 0.35
		mesh.bottom_radius = 0.35
		mesh.height = 0.12
		wheel.mesh = mesh
		wheel.position = pos + Vector3(x, 0.35, -0.62)
		wheel.rotation_degrees.z = 90
		wheel.material_override = _mat(Color(0.07, 0.05, 0.035))
		zone_root.add_child(wheel)

func _make_ritual_stone(pos: Vector3) -> void:
	_make_prop_box("RitualStone", pos + Vector3(0, 0.8, 0), Vector3(0.6, 1.6, 0.35), Color(0.32, 0.34, 0.32))
	var rune = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.05, 0.42, 0.02)
	rune.mesh = mesh
	rune.position = pos + Vector3(0, 0.95, -0.19)
	rune.material_override = _emissive_mat(Color(0.64, 0.85, 0.72), 0.55)
	zone_root.add_child(rune)

func _make_pillar(pos: Vector3) -> void:
	var mapped = _make_role_visual("ruins_pillar", "environment", Vector3(1.2, 1.2, 1.2))
	if mapped != null:
		mapped.position = pos
		zone_root.add_child(mapped)
		return
	var pillar = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.42
	mesh.bottom_radius = 0.48
	mesh.height = 3.0
	mesh.radial_segments = 8
	pillar.mesh = mesh
	pillar.position = pos + Vector3(0, 1.5, 0)
	pillar.material_override = _mat(Color(0.27, 0.27, 0.25))
	zone_root.add_child(pillar)

func _make_rubble(pos: Vector3) -> void:
	pos = _route_safe_position(pos, 3.8)
	if _is_first_route_clearance(pos, 0.95):
		return
	for i in range(2):
		var offset = Vector3(randf_range(-0.18, 0.18), 0, randf_range(-0.16, 0.16))
		_make_prop_box("Rubble", pos + offset + Vector3(0, 0.16, 0), Vector3(randf_range(0.45, 0.95), randf_range(0.20, 0.42), randf_range(0.35, 0.82)), Color(0.18, 0.18, 0.165).lerp(Color(0.08, 0.13, 0.08), randf() * 0.35))

func _make_torch(pos: Vector3) -> void:
	_make_prop_box("TorchPost", pos + Vector3(0, 0.85, 0), Vector3(0.13, 1.7, 0.13), Color(0.10, 0.06, 0.035))
	var flame = MeshInstance3D.new()
	flame.mesh = SphereMesh.new()
	flame.scale = Vector3(0.10, 0.18, 0.10)
	flame.position = pos + Vector3(0, 1.75, 0)
	flame.material_override = _emissive_mat(Color(1.0, 0.45, 0.14), 1.4)
	zone_root.add_child(flame)
	_make_light("TorchLight", pos + Vector3(0, 1.8, 0), Color(1.0, 0.45, 0.16), 1.45)

func _make_hit_spark(pos: Vector3, heavy: bool) -> void:
	if zone_root == null:
		return
	var spark = MeshInstance3D.new()
	spark.mesh = SphereMesh.new()
	spark.scale = Vector3.ONE * (0.22 if heavy else 0.14)
	spark.material_override = _emissive_mat(Color(1.0, 0.68, 0.24), 1.8)
	zone_root.add_child(spark)
	spark.global_position = pos
	var tween = create_tween()
	tween.tween_property(spark, "scale", Vector3.ONE * 0.02, 0.18)
	tween.parallel().tween_property(spark, "position:y", spark.position.y + 0.45, 0.18)
	tween.tween_callback(spark.queue_free)

func _make_fog_sheet(pos: Vector3, scale_value: Vector3, color: Color) -> void:
	if settings != null and str(settings.settings.get("quality_preset", "balanced")) != "quality":
		return
	if _performance_mode() and current_zone_id == "greyfen":
		return
	if _performance_mode() and randf() < 0.45:
		return
	var fog = MeshInstance3D.new()
	fog.mesh = PlaneMesh.new()
	fog.position = pos
	fog.scale = scale_value
	fog.rotation_degrees.x = 90
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fog.material_override = material
	zone_root.add_child(fog)

func _make_prop_box(name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	if name not in ["NorthBerm","SouthBerm","WestBerm","EastBerm"]:
		pos = river_safe_position(pos,size.z*0.5+0.15)
	var separate_body := name in ["NorthBerm","SouthBerm","WestBerm","EastBerm"]
	var body: StaticBody3D
	if separate_body:
		body = StaticBody3D.new()
		body.name = name
		body.position = pos
		zone_root.add_child(body)
	else:
		if prop_collision_body == null:
			prop_collision_body = StaticBody3D.new()
			prop_collision_body.name = "BatchedPropCollisions"
			zone_root.add_child(prop_collision_body)
		body = prop_collision_body
	var shape = CollisionShape3D.new()
	shape.name = "%sCollision" % name
	var box = BoxShape3D.new()
	box.size = size
	shape.shape = box
	if not separate_body:
		shape.position = pos
	body.add_child(shape)
	var mesh = MeshInstance3D.new()
	mesh.mesh = shared_box_mesh
	mesh.scale = size
	var lower := name.to_lower()
	if lower.contains("glow") or lower.contains("window") or lower.contains("coal") or lower.contains("candle"):
		mesh.material_override = _emissive_mat(color, 0.65)
		if separate_body:
			body.add_child(mesh)
		else:
			mesh.position = pos
			zone_root.add_child(mesh)
	else:
		var surface := "plaster"
		if lower.contains("roof"):
			surface = "roof_tiles"
		elif lower.contains("wood") or lower.contains("door") or lower.contains("fence") or lower.contains("rail") or lower.contains("post") or lower.contains("board") or lower.contains("cart") or lower.contains("crate") or lower.contains("barrel"):
			surface = "timber"
		elif lower.contains("stone") or lower.contains("wall") or lower.contains("grave") or lower.contains("foundation") or lower.contains("chimney") or lower.contains("rubble"):
			surface = "medieval_brick"
		elif lower.contains("berm") or lower.contains("moss"):
			surface = "forest_ground"
		var material = world_materials.get_material(surface, str(settings.settings.get("quality_preset", "balanced")), Color(0.72, 0.70, 0.66), 0.15 if surface == "wet_mud" else 0.0, true)
		if not prop_batch_data.has(surface):
			prop_batch_data[surface] = {"material": material, "transforms": []}
		prop_batch_data[surface].transforms.append(Transform3D(Basis.IDENTITY.scaled(size), pos))

func _is_first_route_clearance(pos: Vector3, radius: float = 0.0) -> bool:
	if current_zone_id == "greyfen":
		if abs(pos.x) < 2.85 + radius and pos.z > -15.8 and pos.z < 13.4:
			return true
		if pos.x > 1.2 - radius and pos.x < 7.0 + radius and pos.z > -8.8 - radius and pos.z < -3.8 + radius:
			return true
	elif current_zone_id == "wychwood":
		if abs(pos.x) < 3.15 + radius and pos.z > -13.2 and pos.z < 14.2:
			return true
		if abs(pos.x) < 4.4 + radius and pos.z > -9.8 and pos.z < -3.0:
			return true
	return false

func _route_safe_position(pos: Vector3, target_x: float) -> Vector3:
	if not _is_first_route_clearance(pos, 0.0):
		return pos
	var side = -1.0 if pos.x < 0.0 else 1.0
	if abs(pos.x) < 0.2:
		side = -1.0 if randf() < 0.5 else 1.0
	pos.x = side * target_x
	return pos

func _apply_first_route_materials(root: Node) -> void:
	if root == null:
		return
	for child in root.get_children():
		_apply_first_route_materials(child)
	if root is MeshInstance3D:
		var mesh_instance = root as MeshInstance3D
		var palette_key = _first_route_palette_key(mesh_instance)
		if palette_key == "":
			return
		if _mesh_needs_visible_fallback(mesh_instance):
			mesh_instance.material_override = _first_route_material(palette_key)

func _first_route_palette_key(node: Node) -> String:
	var combined = _node_keyword_path(node)
	if combined.contains("roof"):
		return "roof"
	if combined.contains("house") or combined.contains("wall") or combined.contains("plaster"):
		return "wall"
	if combined.contains("tree") or combined.contains("trunk"):
		return "trunk"
	if combined.contains("leaf") or combined.contains("leaves") or combined.contains("crown"):
		return "leaves"
	if combined.contains("rock") or combined.contains("rubble") or combined.contains("stone") or combined.contains("pathstone"):
		return "rock"
	if combined.contains("grave"):
		return "grave"
	if combined.contains("shrine"):
		return "shrine"
	if combined.contains("fence") or combined.contains("wood") or combined.contains("cart") or combined.contains("crate") or combined.contains("barrel") or combined.contains("torch"):
		return "wood"
	if combined.contains("road") or combined.contains("mud") or combined.contains("ground") or combined.contains("berm"):
		return "ground"
	if combined.contains("cloth") or combined.contains("cloak") or combined.contains("robe"):
		return "cloth"
	if combined.contains("skin") or combined.contains("face") or combined.contains("sister") or combined.contains("npc") or combined.contains("villager"):
		return "skin"
	if combined.contains("ghoul") or combined.contains("monster") or combined.contains("enemy"):
		return "monster"
	if combined.contains("metal") or combined.contains("sword") or combined.contains("blade"):
		return "metal"
	return ""

func _node_keyword_path(node: Node) -> String:
	var combined = ""
	var current: Node = node
	while current != null and current != zone_root:
		combined += " " + String(current.name).to_lower()
		current = current.get_parent()
	return combined

func _mesh_needs_visible_fallback(mesh_instance: MeshInstance3D) -> bool:
	if mesh_instance.material_override != null:
		return _is_bad_white_material(mesh_instance.material_override)
	if mesh_instance.mesh == null:
		return true
	var saw_material = false
	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		var material = mesh_instance.mesh.surface_get_material(surface_index)
		if material == null:
			continue
		saw_material = true
		if _is_bad_white_material(material):
			return true
	return not saw_material

func _is_bad_white_material(material: Material) -> bool:
	if material == null:
		return true
	if material is StandardMaterial3D:
		var standard = material as StandardMaterial3D
		var has_texture = standard.albedo_texture != null
		var color = standard.albedo_color
		return not has_texture and color.r > 0.85 and color.g > 0.85 and color.b > 0.85
	return false

func _first_route_material(key: String) -> StandardMaterial3D:
	var cache_key = "first_route:%s" % key
	if material_cache.has(cache_key):
		return material_cache[cache_key]
	var colors = {
		"rock": Color(0.17, 0.18, 0.16),
		"trunk": Color(0.16, 0.095, 0.055),
		"leaves": Color(0.055, 0.15, 0.075),
		"roof": Color(0.13, 0.055, 0.035),
		"wall": Color(0.30, 0.22, 0.15),
		"grave": Color(0.30, 0.31, 0.30),
		"shrine": Color(0.37, 0.38, 0.35),
		"ground": Color(0.11, 0.10, 0.07),
		"wood": Color(0.16, 0.09, 0.045),
		"metal": Color(0.44, 0.44, 0.42),
		"cloth": Color(0.11, 0.12, 0.13),
		"skin": Color(0.66, 0.52, 0.40),
		"monster": Color(0.15, 0.20, 0.14)
	}
	var material = StandardMaterial3D.new()
	material.albedo_color = colors.get(key, Color(0.24, 0.24, 0.22))
	material.roughness = 0.86
	if key == "metal":
		material.metallic = 0.35
		material.roughness = 0.52
	material_cache[cache_key] = material
	return material

func _role_for_interactable(id: String) -> String:
	var roles = {
		"sister_anwen": "sister_anwen",
		"mira": "mira_herbalist",
		"rook": "rook_smuggler",
		"widow_elna": "widow_elna",
		"blacksmith_tor": "blacksmith_tor",
		"farmer_toma": "generic_villager_01",
		"edric": "castle_guard",
		"vargan_gate_guard": "castle_guard",
		"vargan_record_keeper": "castle_guard",
		"captain_senn": "road_ranger",
		"halvern": "castle_guard",
		"white_hart": "white_hart_avatar"
	}
	return str(roles.get(id, ""))

func _visual_role_for_interactable(id: String) -> String:
	var roles = {
		"sister_anwen": "sister_anwen_human",
		"mira": "mira_human",
		"rook": "rook_human",
		"widow_elna": "villager_hooded_human",
		"blacksmith_tor": "villager_worker_human",
		"farmer_toma": "villager_human",
		"edric": "castle_guard_human",
		"vargan_gate_guard": "castle_guard_human",
		"vargan_record_keeper": "castle_guard_human",
		"captain_senn": "road_ranger_human",
		"halvern": "castle_guard_human"
	}
	return str(roles.get(id, ""))

func _role_for_prop(name: String) -> String:
	var key = name.to_lower()
	if key.contains("crate"):
		return "crate"
	if key.contains("barrel"):
		return "barrel"
	return ""

func _make_role_visual(role_name: String, category: String, scale_value: Vector3) -> Node3D:
	if role_name == "" or asset_helper == null:
		return null
	if _performance_mode() and category == "environment":
		return null
	var node: Node3D
	if category == "characters":
		var visual_role = _visual_role_for_legacy_character(role_name)
		if visual_role != "" and asset_helper.has_method("spawn_visual_role") and asset_helper.has_method("has_visual_role") and asset_helper.has_visual_role(visual_role):
			node = asset_helper.spawn_visual_role(visual_role, "characters")
			if node != null and not node.name.ends_with("_placeholder"):
				return node
			if node != null:
				node.queue_free()
		node = asset_helper.spawn_character(role_name)
	elif category == "enemies":
		node = asset_helper.spawn_enemy(role_name)
	else:
		node = asset_helper.spawn_environment(role_name)
	if node == null or node.name.ends_with("_placeholder"):
		if node != null:
			node.queue_free()
		return null
	if category == "enemies":
		asset_helper.apply_normalized_scale(node, scale_value.y)
	elif category == "characters":
		pass
	else:
		node.scale = scale_value
	return node

func _visual_role_for_legacy_character(role_name: String) -> String:
	var roles = {
		"player_kael": "player_human",
		"sister_anwen": "sister_anwen_human",
		"mira_herbalist": "mira_human",
		"rook_smuggler": "rook_human",
		"widow_elna": "villager_hooded_human",
		"blacksmith_tor": "villager_worker_human",
		"generic_villager_01": "villager_human",
		"lord_edric": "castle_guard_human",
		"castle_guard": "castle_guard_human",
		"road_ranger": "road_ranger_human"
	}
	return str(roles.get(role_name, ""))

func _make_light(name: String, pos: Vector3, color: Color, energy: float) -> void:
	if _performance_mode() and not _keep_performance_light(name):
		return
	var quality := str(settings.settings.get("quality_preset", "balanced")) if settings != null else "balanced"
	# Four local pools preserve the route landmarks while keeping the Web
	# Compatibility renderer inside its transition and frame-time budget.
	if quality == "balanced" and runtime_light_count >= 4:
		return
	var light = OmniLight3D.new()
	light.name = name
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 14.0 if quality == "quality" else 8.0
	light.shadow_enabled = false
	zone_root.add_child(light)
	runtime_light_count += 1

func _performance_mode() -> bool:
	return settings != null and bool(settings.settings.get("potato_mode", true))

func _keep_performance_light(name: String) -> bool:
	return name in ["Village Warmth", "Shrine Beacon", "Wychwood Gate Lantern", "Moon Shaft", "Trail Threat", "ClearingColdSpot", "SpawnWarmRead"]

func _build_global_environment() -> void:
	visual_director = VisualDirector.new()
	add_child(visual_director)

func _mat(color: Color) -> StandardMaterial3D:
	var key := "flat:%s" % color.to_html(true)
	if material_cache.has(key):
		return material_cache[key]
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	material_cache[key] = material
	return material

func _terrain_material(name: String, color: Color) -> StandardMaterial3D:
	if world_materials != null:
		var lower := name.to_lower()
		var surface := "forest_ground"
		var wetness := 0.0
		if lower.contains("mud") or lower.contains("wet") or lower.contains("cemetery"):
			surface = "wet_mud"
			wetness = 0.72
		return world_materials.get_material(surface, str(settings.settings.get("quality_preset", "balanced")), color.lightened(0.65), wetness, true)
	var key = "terrain:%s:%s" % [name, color.to_html()]
	if material_cache.has(key):
		return material_cache[key]
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.94
	material.metallic = 0.0
	if name.to_lower().contains("mud") or name.to_lower().contains("wet"):
		material.albedo_color = color.lerp(Color(0.025, 0.030, 0.026), 0.35)
		material.roughness = 0.70
	elif name.to_lower().contains("green") or name.to_lower().contains("shoulder"):
		material.albedo_color = color.lerp(Color(0.060, 0.120, 0.055), 0.24)
	material_cache[key] = material
	return material

func _road_material(paved: bool, color: Color) -> StandardMaterial3D:
	if world_materials != null:
		return world_materials.get_material("cobblestone" if paved else "wet_mud", str(settings.settings.get("quality_preset", "balanced")), Color(0.82, 0.80, 0.76) if paved else Color(0.60, 0.64, 0.58), 0.15 if paved else 0.78, true)
	var key = "road:paved" if paved else "road:mud"
	if material_cache.has(key):
		return material_cache[key]
	var material = StandardMaterial3D.new()
	if paved:
		material.albedo_color = color.lerp(Color(0.22, 0.20, 0.17), 0.45)
		material.roughness = 0.96
	else:
		material.albedo_color = color.lerp(Color(0.026, 0.034, 0.030), 0.55)
		material.roughness = 0.68
	material_cache[key] = material
	return material

func _grass_material(color: Color) -> StandardMaterial3D:
	var key = "grass:%s" % color.to_html()
	if material_cache.has(key):
		return material_cache[key]
	var material = StandardMaterial3D.new()
	material.albedo_color = color.lerp(Color(0.075, 0.115, 0.060), 0.28)
	material.roughness = 0.88
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_cache[key] = material
	return material

func _emissive_mat(color: Color, energy: float) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material

func _read_json(path: String):
	if not FileAccess.file_exists(path):
		push_warning("Missing JSON: %s" % path)
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed != null else {}
