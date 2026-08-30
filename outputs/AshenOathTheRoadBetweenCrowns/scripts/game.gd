extends Node3D

const EnemyAI = preload("res://scripts/enemy_ai.gd")
const Interactable = preload("res://scripts/interactable.gd")
const VisualDirector = preload("res://scripts/visual_director.gd")
const NpcAmbient = preload("res://scripts/npc_ambient.gd")
const CharacterPresentation = preload("res://scripts/character_presentation.gd")
const CombatFeedback = preload("res://scripts/combat_feedback.gd")
const CharacterAnimationDriver = preload("res://scripts/character_animation_driver.gd")
const BoardGameOpponent = preload("res://scripts/board_game_opponent.gd")
const WorldVisualUpgrade = preload("res://scripts/world_visual_upgrade.gd")
const WorldMotionController = preload("res://scripts/world_motion_controller.gd")
const WorldPropController = preload("res://scripts/world_prop_controller.gd")
const InteractiveWorldProp = preload("res://scripts/interactive_world_prop.gd")
const OpeningSoundscape = preload("res://scripts/opening_soundscape.gd")
const SurfaceFeedbackManager = preload("res://scripts/surface_feedback_manager.gd")
const WorldVFXController = preload("res://scripts/world_vfx_controller.gd")
const EpilogueResolver = preload("res://scripts/epilogue_resolver.gd")
const ZoneSpatialService = preload("res://scripts/zone_spatial_service.gd")
const RuntimeServiceRegistry = preload("res://scripts/runtime_service_registry.gd")
const RuntimeActorFactory = preload("res://scripts/runtime_actor_factory.gd")
const ZoneCompositionRouter = preload("res://scripts/zone_composition_router.gd")
const ZoneRuntimeCoordinator = preload("res://scripts/zone_runtime_coordinator.gd")
const ZoneSceneCatalog = preload("res://scripts/zone_scene_catalog.gd")
const OathGatePortal = preload("res://scripts/oath_gate_portal.gd")
const BossEncounterScript = preload("res://scripts/boss_encounter.gd")
const PerformanceBudgetMonitor = preload("res://scripts/performance_budget_monitor.gd")
const SeamlessWorldService = preload("res://scripts/seamless_world_service.gd")

var player
var camera_rig
var hud
var quests
var quest_presentation
var quest_beats
var dialogue
var story_state
var inventory
var vendor_service
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
var world_props: WorldPropController
var minigames
var progression
var input_router
var interaction_focus
var mobile_touch
var zone_streaming
var seamless_world: SeamlessWorldService
var runtime_packs
var qa_adapter
var zone_root: Node3D
var active_interactable
var dialogue_focus_actor: Node3D
var interaction_candidates: Array = []
var interaction_area_cache: Array[Area3D] = []
var interaction_area_cache_ready := false
var current_zone_id = "greyfen"
var enemy_defs = {}
var boss_defs = {}
var active_enemies: Array = []
var active_enemy_attacker: Node
var boss_saved_states: Dictionary = {}
var wychwood_pack_kills = 0
var game_started = false
var paused_by_menu = true
var pending_ending = ""
var removed_interactions = {}
var autosave_cooldown = 180.0
var last_safe_player_position = Vector3(0, 1, 9.8)
var tutorial_flags = {}
var material_cache: Dictionary = {}
var runtime_light_count := 0
var tree_batch_data: Array[Dictionary] = []
var deadfall_batch_data: Array[Transform3D] = []
var tree_collision_body: StaticBody3D
var route_zone_cache: Dictionary = {}
var route_enemy_cache: Dictionary = {}
var route_zone_signatures: Dictionary = {}
var route_spatial_cache: Dictionary = {}
var retired_zone_roots: Array[Node] = []
var retired_zone_cleanup_root: Node3D
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
var zone_runtime_coordinator: ZoneRuntimeCoordinator
var environment_batches_flushed := false
var prop_collision_body: StaticBody3D
var pending_anwen_relocation := false
var runtime_services: Node
var performance_budget_monitor: PerformanceBudgetMonitor
var zone_transition_pending := false
var zone_transition_frames := 0
var pending_spawn_position := Vector3.ZERO
var pending_spawn_facing := 0.0
var loading_started_usec := 0
var last_loading_metrics: Dictionary = {}
var new_game_start_pending := false
var zone_load_request_pending := false
var resource_shutdown_prepared := false
var requested_zone_id := ""
var requested_zone_spawn := Vector3.ZERO
var campaign_pack_waiting := false
var greyfen_prewarm_started := false
var startup_packs_waiting := false
var greyfen_prewarm_spatial_service: Node
var interaction_focus_cooldown := 0.0
var compass_refresh_cooldown := 0.0
var tutorial_refresh_cooldown := 0.0
var target_status_refresh_cooldown := 0.0
const MAX_CACHED_ROUTE_ZONES := 1
const ZONE_RETIRE_FRAMES := 8
const MAX_SKINNED_RESOURCE_ANCHORS := 4
const MAX_RETIRED_MATERIAL_ANCHORS := 64
const MAX_TRANSITION_HISTORY := 16

func _ready() -> void:
	var ready_started := Time.get_ticks_msec()
	process_mode = Node.PROCESS_MODE_ALWAYS
	retired_zone_cleanup_root = Node3D.new()
	retired_zone_cleanup_root.name = "RetiredZoneCleanupRoot"
	retired_zone_cleanup_root.visible = false
	retired_zone_cleanup_root.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(retired_zone_cleanup_root)
	shared_box_mesh = BoxMesh.new()
	shared_box_mesh.size = Vector3.ONE
	var phase_started := Time.get_ticks_msec()
	_build_global_environment()
	var environment_ms := Time.get_ticks_msec() - phase_started
	phase_started = Time.get_ticks_msec()
	_setup_runtime()
	performance_budget_monitor = PerformanceBudgetMonitor.new()
	performance_budget_monitor.name = "PerformanceBudgetMonitor"
	add_child(performance_budget_monitor)
	performance_budget_monitor.configure(self)
	var services_ms := Time.get_ticks_msec() - phase_started
	# The browser shell is already the audio/input consent surface. Showing a
	# second in-engine launch screen made Web startup require two clicks and
	# doubled the perceived wait. Desktop keeps the explicit launch surface so
	# audio capture remains predictable there; Web enters the real menu directly
	# while Greyfen prewarming happens behind it.
	if OS.has_feature("web"):
		hud.show_main_menu()
		_on_launch_accepted()
	else:
		hud.show_launch_screen()
	audio.set_music_state("main_menu")
	get_tree().paused = true
	print("LOADING: runtime ready total=%dms environment=%dms services=%dms" % [
		Time.get_ticks_msec() - ready_started, environment_ms, services_ms,
	])

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
		audio.set_game_paused(true)
		get_tree().paused = true
		hud.show_inventory(inventory, quests, story_state, progression)

func _process(delta: float) -> void:
	if not game_started or player == null or get_tree().paused:
		return
	if zone_transition_pending:
		_advance_zone_transition()
		return
	if seamless_world != null and seamless_world.update_player(player, current_zone_id, delta):
		return
	_keep_player_in_world()
	interaction_focus_cooldown -= delta
	if interaction_focus_cooldown <= 0.0:
		interaction_focus_cooldown = 0.10
		_update_interaction_focus()
	tutorial_refresh_cooldown -= delta
	if tutorial_refresh_cooldown <= 0.0:
		tutorial_refresh_cooldown = 0.10
		_update_tutorial_prompts()
	target_status_refresh_cooldown -= delta
	if target_status_refresh_cooldown <= 0.0:
		target_status_refresh_cooldown = 0.10
		_update_target_lock_hud()
	autosave_cooldown = max(autosave_cooldown - delta, 0.0)
	if autosave_cooldown <= 0.0:
		autosave_cooldown = 180.0
		save_manager.autosave(self)
	compass_refresh_cooldown -= delta
	if compass_refresh_cooldown <= 0.0:
		compass_refresh_cooldown = 0.25
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
	quest_presentation = services["quest_presentation"]
	quest_beats = services["quest_beats"]
	dialogue = services["dialogue"]
	inventory = services["inventory"]
	vendor_service = services["vendor_service"]
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
	interaction_focus = services["interaction_focus"]
	mobile_touch = services["mobile_touch"]
	zone_streaming = services["zone_streaming"]
	runtime_packs = services["runtime_packs"]
	runtime_services.configure(self)
	zone_runtime_coordinator = ZoneRuntimeCoordinator.new(self)
	zone_runtime_coordinator.configure(quest_presentation, quest_beats, interaction_focus, quests)
	seamless_world = SeamlessWorldService.new()
	seamless_world.name = "SeamlessWorldService"
	add_child(seamless_world)
	seamless_world.configure(self, zone_streaming)
	if OS.has_feature("ashenoath_qa"):
		var qa_script = load("res://scripts/qa_browser_telemetry.gd")
		if qa_script != null:
			qa_adapter = qa_script.new()
			qa_adapter.name = "QABrowserTelemetry"
			add_child(qa_adapter)
	enemy_defs = _read_json("res://data/enemies.json")
	boss_defs = _read_json("res://data/bosses.json")

func _new_game() -> void:
	if zone_transition_pending or zone_load_request_pending:
		return
	if OS.has_feature("web") and runtime_packs != null and runtime_packs.has_method("startup_packs_ready"):
		if not runtime_packs.startup_packs_ready():
			hud.toast("Greyfen is still being prepared. The road will open shortly.")
			return
	new_game_start_pending = true
	loading_started_usec = Time.get_ticks_usec()
	if audio != null:
		audio.set_game_paused(false)
	if hud != null and hud.has_method("arm_loading"):
		hud.arm_loading("Opening Greyfen...")
	get_tree().paused = false
	_start_new_game_world()

func _handle_quit_request() -> void:
	if OS.has_feature("web"):
		hud.show_exit_notice()
		return
	get_tree().quit()

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
		hud.arm_loading("Crossing the Oath Gate...")
	if player != null:
		player.set_transition_locked(true)
	_perform_requested_zone_load()

func request_seamless_boundary_transition(zone_id: String, spawn_pos: Vector3, edge_id: String = "") -> bool:
	if zone_transition_pending or zone_load_request_pending or player == null:
		return false
	var target := zone_id.strip_edges().to_lower()
	if zone_runtime_coordinator != null:
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
	# Boundary travel keeps the previous rendered frame and never arms the
	# full-screen loading layer. The destination is prewarmed by
	# SeamlessWorldService before this call.
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

func _load_zone_after_runtime_pack(zone_id: String, spawn_pos: Vector3) -> void:
	if not _zone_requires_campaign_pack(zone_id) or not OS.has_feature("web"):
		_load_zone(zone_id, spawn_pos)
		return
	if runtime_packs == null or not runtime_packs.has_method("request_pack"):
		_recover_failed_zone_load(current_zone_id)
		return
	if not runtime_packs.is_ready("campaign"):
		campaign_pack_waiting = true
		if hud != null and hud.has_method("arm_loading"):
			hud.arm_loading("Preparing the road beyond Greyfen...")
		runtime_packs.request_pack("campaign")
		_wait_for_campaign_pack(zone_id, spawn_pos)
		return
	_load_zone(zone_id, spawn_pos)

func _wait_for_campaign_pack(zone_id: String, spawn_pos: Vector3) -> void:
	for _frame in range(900):
		await get_tree().process_frame
		if not campaign_pack_waiting:
			return
		if runtime_packs != null and runtime_packs.is_ready("campaign"):
			campaign_pack_waiting = false
			if hud != null and hud.has_method("hide_loading"):
				hud.hide_loading()
			_load_zone(zone_id, spawn_pos)
			return
		if runtime_packs != null and runtime_packs.get_state("campaign") == "failed":
			break
	campaign_pack_waiting = false
	if hud != null and hud.has_method("hide_loading"):
		hud.hide_loading()
	if hud != null:
		hud.toast("The road pack could not be prepared. You remain in Greyfen.")
	_recover_failed_zone_load(current_zone_id)

func _zone_requires_campaign_pack(zone_id: String) -> bool:
	return zone_id in [
		"deep_wood", "old_mill", "burned_farmstead", "marsh_crossing", "bandit_road",
		"vargan_approach", "vargan_court", "record_hall", "undercroft", "assembly", "hart_glade",
	]

func _start_new_game_world() -> void:
	# An explicit transition can be requested before the menu's deferred setup
	# receives its first frame. Preserve that deliberate destination.
	if game_started or not new_game_start_pending:
		return
	new_game_start_pending = false
	if hud != null and hud.has_method("set_new_game_ready"):
		hud.set_new_game_ready(true)
	# Keep the menu-prewarmed Greyfen tree while clearing any stale campaign
	# cache. Rebuilding this scene in Web/ANGLE was the dominant New Game delay.
	var prewarmed_greyfen = route_zone_cache.get("greyfen")
	var prewarmed_enemies: Array = route_enemy_cache.get("greyfen", [])
	print("LOADING: new_game_handoff prewarmed=%s cached_zones=%d" % [prewarmed_greyfen != null, route_zone_cache.size()])
	if prewarmed_greyfen != null:
		route_zone_cache.erase("greyfen")
		route_enemy_cache.erase("greyfen")
	_clear_route_zone_cache(prewarmed_greyfen)
	print("LOADING: new_game_stage=cache_clear elapsed=%.1f" % (float(Time.get_ticks_usec() - loading_started_usec) / 1000.0))
	if prewarmed_greyfen != null and is_instance_valid(prewarmed_greyfen):
		_cache_route_zone("greyfen", prewarmed_greyfen, prewarmed_enemies, _zone_state_signature(), true, false, false)
	game_started = true
	paused_by_menu = false
	wychwood_pack_kills = 0
	pending_anwen_relocation = false
	tutorial_flags.clear()
	inventory.reset_starting_loadout()
	if vendor_service != null:
		vendor_service.reset_state()
	progression.load_state({})
	current_zone_id = "greyfen"
	day_night.set_time(day_night.START_TIME_MINUTES, 0)
	hud.hide_menus()
	quests.start_quest("main_road_of_crows")
	print("LOADING: new_game_stage=state_ready elapsed=%.1f" % (float(Time.get_ticks_usec() - loading_started_usec) / 1000.0))
	if route_zone_cache.has("greyfen"):
		route_zone_signatures["greyfen"] = _zone_state_signature()
	print("LOADING: new_game_stage=zone_dispatch elapsed=%.1f" % (float(Time.get_ticks_usec() - loading_started_usec) / 1000.0))
	_load_zone("greyfen", Vector3(0, 1, 9.8))
	print("LOADING: new_game_stage=zone_return elapsed=%.1f" % (float(Time.get_ticks_usec() - loading_started_usec) / 1000.0))
	hud.toast("Greyfen whispers about the old road. Sister Anwen is waiting at the shrine.")
	hud.set_guidance_hint("E - Speak to Sister Anwen", 5.5)
	_refresh_tracker()
	_refresh_equipment_readout()
	save_manager.checkpoint(self)

func load_save_state(data: Dictionary) -> void:
	if save_manager != null and save_manager.has_method("migrate_save_data"):
		var migrated: Dictionary = save_manager.migrate_save_data(data)
		if migrated.is_empty():
			if hud != null:
				hud.toast("This save belongs to a newer version of Ashen Oath.")
			return
		data = migrated
	_clear_route_zone_cache()
	game_started = true
	if audio != null:
		audio.set_game_paused(false)
	get_tree().paused = false
	hud.hide_menus()
	inventory.load_state(data.get("inventory", {}))
	if vendor_service != null:
		vendor_service.load_state(data.get("vendors", {}))
	quests.load_state(data.get("quests", {}))
	if quest_presentation != null:
		quest_presentation.load_state(data.get("quest_presentation", {}))
	if quest_beats != null:
		quest_beats.load_state(data.get("quest_beats", {}))
	if settings != null and typeof(data.get("settings", {})) == TYPE_DICTIONARY and not data.get("settings", {}).is_empty():
		for key in data.settings:
			if settings.settings.has(key) and typeof(settings.settings[key]) == typeof(data.settings[key]):
				settings.settings[key] = data.settings[key]
		settings.apply()
	story_state.load_state(data.get("story_state", {}))
	progression.load_state(data.get("progression", {}))
	if seamless_world != null and seamless_world.has_method("load_state"):
		seamless_world.load_state(data.get("seamless_world", {}))
	progression.reconcile_completed_quests(quests.quest_defs, quests.completed)
	if int(data.get("version", 0)) < 3 and quests.is_completed("main_road_of_crows"):
		story_state.set_flag("legacy_report_choice_required", true)
	load_world_state(data.get("world_state", {}))
	var zone = str(data.get("world_sector", data.get("zone", "greyfen")))
	var pos_array: Array = data.get("player_position", [0, 1, 7])
	var pos = Vector3(float(pos_array[0]), float(pos_array[1]), float(pos_array[2]))
	var world_array: Array = data.get("world_position", [])
	if seamless_world != null and world_array.size() >= 3:
		pos = seamless_world.local_position_for(zone, Vector3(float(world_array[0]), float(world_array[1]), float(world_array[2])))
	pos = _safe_loaded_position(zone, pos)
	# Campaign saves must follow the same streamed-pack handoff as a gate
	# transition. Otherwise a legacy save opened directly in a later sector
	# reaches the lazy builder before its script pack is mounted.
	_load_zone_after_runtime_pack(zone, pos)
	player.health_component.load_state(data.get("player_health", {}))
	player.stamina_component.load_state(data.get("player_stamina", {}))
	if player.has_method("load_equipment_state"):
		player.load_equipment_state(data.get("equipment", {}))
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
	if camera_rig != null and camera_rig.has_signal("target_lock_changed") and not camera_rig.target_lock_changed.is_connected(_on_target_lock_changed):
		camera_rig.target_lock_changed.connect(_on_target_lock_changed)
	_apply_progression_to_player()
	_apply_runtime_settings(settings.settings)
	if player.has_method("bind_inventory"):
		player.bind_inventory(inventory)
	player.blade_contact_requested.connect(_on_player_blade_contact)
	player.potion_requested.connect(_use_potion)
	player.bomb_requested.connect(_throw_bomb)
	player.beam_requested.connect(_on_player_beam)
	player.beam_phase_changed.connect(_on_player_beam_phase)
	player.arrow_requested.connect(_on_player_arrow)
	player.arrow_unavailable.connect(_on_player_arrow_unavailable)
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
	if performance_budget_monitor != null:
		performance_budget_monitor.suspend()
	loading_started_usec = loading_started_usec if loading_started_usec > 0 else Time.get_ticks_usec()
	if player != null and player.has_method("set_transition_locked"):
		player.set_transition_locked(true)
	if camera_rig != null and camera_rig.has_method("clear_target_lock"):
		camera_rig.clear_target_lock()
	if hud != null and hud.has_method("clear_target_lock_status"):
		hud.clear_target_lock_status()
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
	if zone_runtime_coordinator != null:
		zone_runtime_coordinator.begin_transition(zone_id, previous_zone_id, spawn_pos)
	var previous_spatial_service: Node = spatial_service
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
			_cache_route_spatial_service(previous_zone_id, previous_spatial_service)
	active_interactable = null
	interaction_candidates.clear()
	interaction_area_cache.clear()
	interaction_area_cache_ready = false
	# Guidance belongs to the previous route. Clear it before the new zone
	# refreshes its own contextual hint so stale prompts cannot survive a gate.
	hud.set_guidance_hint("")
	current_zone_id = zone_id
	var using_prewarmed_spatial := zone_id == "greyfen" \
		and greyfen_prewarm_spatial_service != null \
		and is_instance_valid(greyfen_prewarm_spatial_service)
	var cached_spatial_service: Node = route_spatial_cache.get(zone_id)
	var using_cached_spatial := cached_spatial_service != null \
		and is_instance_valid(cached_spatial_service) \
		and route_zone_cache.has(zone_id) \
		and int(route_zone_signatures.get(zone_id, -1)) == requested_signature
	print("LOADING: zone_begin id=%s prewarm=%s cached=%s" % [zone_id, using_prewarmed_spatial, using_cached_spatial])
	_release_active_spatial_service()
	if using_prewarmed_spatial:
		spatial_service = greyfen_prewarm_spatial_service
		greyfen_prewarm_spatial_service = null
		spatial_service.name = "ZoneSpatialService"
		spatial_service.process_mode = Node.PROCESS_MODE_INHERIT
	elif using_cached_spatial:
		spatial_service = cached_spatial_service
		route_spatial_cache.erase(zone_id)
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
	# Target health belongs to the active encounter. Clear it before the new
	# zone starts so Castle, finale, and dialogue views cannot inherit a dead
	# Wychwood target from the previous route.
	hud.hide_enemy()
	if reused_zone:
		active_enemies = _valid_cached_enemies(previous_enemies)
	elif route_zone_cache.has(zone_id) and is_instance_valid(route_zone_cache[zone_id]) \
			and int(route_zone_signatures.get(zone_id, -1)) == requested_signature:
		zone_root = _activate_cached_zone(zone_id)
		print("LOADING: cached_zone_activated id=%s valid=%s" % [zone_id, zone_root != null])
		print("LOADING: zone_stage=cache_activated elapsed=%.1f" % (float(Time.get_ticks_usec() - loading_started_usec) / 1000.0))
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
		var authored_layers := ZoneSceneCatalog.attach(zone_id, zone_root)
		if not bool(authored_layers.get("ok", true)):
			push_error("Authored zone layers failed for %s: %s" % [
				zone_id, ", ".join(authored_layers.get("errors", []))
			])
		var composition_kind := ZoneCompositionRouter.composition_kind(zone_id)
		var build_result: Dictionary
		if zone_runtime_coordinator != null:
			zone_runtime_coordinator.begin_build(zone_id, composition_kind)
		if composition_kind == "campaign":
			build_result = ZoneCompositionRouter.build_campaign(self, zone_id)
		else:
			build_result = ZoneCompositionRouter.build_core(self, zone_id)
		if zone_runtime_coordinator != null:
			build_result = zone_runtime_coordinator.finish_build(build_result, zone_root)
		var build_validation := zone_runtime_coordinator.validate_build(zone_id, build_result, zone_root) if zone_runtime_coordinator != null else build_result
		if not bool(build_validation.get("ok", false)):
			push_error("Zone composition failed for %s: %s" % [
				zone_id, ", ".join(build_validation.get("errors", []))
			])
			if zone_runtime_coordinator != null:
				zone_runtime_coordinator.rollback(zone_id, previous_zone_id, build_validation.get("errors", []))
			_recover_failed_zone_load(previous_zone_id)
			return
		if composition_kind == "campaign":
			_apply_campaign_arrival(zone_id)
		_flush_environment_batches()
		_install_world_prop_controller(zone_id)
		if zone_id in ["greyfen", "wychwood"]:
			_add_visual_100_layer(zone_id)
		_apply_first_route_materials(zone_root)
		# The authoritative render-resource pass runs after the player, sky, and
		# encounter roots are attached below. Walking a large campaign zone here as
		# well doubled castle activation work without protecting an additional
		# visible frame.
		active_zone_signature = _zone_state_signature()
	if zone_root != null:
		zone_root.set_meta("zone_resource_owner", "active")
		zone_root.set_meta("zone_resource_id", zone_id)
		_install_world_prop_controller(zone_id)
		if zone_runtime_coordinator != null:
			zone_runtime_coordinator.activate(zone_id, zone_root, reused_zone)
	_trim_route_zone_cache([previous_zone_id] if previous_zone_id != zone_id else [])
	# Avoid recursive diagnostic walks during every transition; on Web/ANGLE those
	# allocations made cached arrivals visibly slower.
	print("ZONE_COMPOSITION: id=%s reused=%s visible=%s position=%s" % [
		zone_id, reused_zone, zone_root.visible, zone_root.global_position,
	])
	active_zone_signature = _zone_state_signature()
	if not using_prewarmed_spatial and not using_cached_spatial:
		spatial_service.build_navigation(zone_root)
	for enemy in active_enemies:
		if is_instance_valid(enemy) and enemy.has_method("setup_navigation"):
			enemy.setup_navigation(spatial_service)
	var life_controller := zone_root.find_child("GreyfenLifeController", true, false)
	if life_controller != null and life_controller.has_method("set_spatial_service"):
		life_controller.set_spatial_service(spatial_service)
	if zone_runtime_coordinator != null:
		zone_runtime_coordinator.sync_zone(zone_id)
	_refresh_tracker()
	print("LOADING: zone_stage=systems_synced elapsed=%.1f" % (float(Time.get_ticks_usec() - loading_started_usec) / 1000.0))
	if visual_director != null:
		visual_director.apply_zone(zone_id, zone_root)
	print("LOADING: zone_stage=visual_applied elapsed=%.1f" % (float(Time.get_ticks_usec() - loading_started_usec) / 1000.0))
	if zone_streaming != null and zone_streaming.has_method("prewarm_neighbors"):
		zone_streaming.prewarm_neighbors(zone_id)
	if audio != null:
		audio.play_ambient(zone_id)
		audio.set_music_state(audio.music_state_for_zone(zone_id))
		if zone_id == "greyfen":
			audio.play_event("shrine_hum", 0.01)
	# Authored arrivals are already reserved by the zone builder. Preserve their
	# exact route position here; nearest_safe() is an emergency recovery API and
	# can otherwise move a valid arrival to a distant edge anchor.
	var safe_spawn: Vector3 = spatial_service.validate_position(spawn_pos, 0.8, spatial_service.bank_for(spawn_pos))
	if player == null:
		_spawn_player(safe_spawn)
	else:
		player.visible = true
		if not using_prewarmed_spatial:
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
	_install_opening_soundscape(zone_id)
	# The builder and imported-asset helper attach validated materials as each
	# mesh is created. The full zone tree is audited by lifecycle gates; doing the
	# same recursive walk on every player transition adds visible latency on
	# Compatibility/ANGLE, so keep that audit off the swap path.
	# The late-created render roots still receive the fast, focused validation.
	# The full zone tree is checked explicitly by verify_engine_003/004.
	if visual_director != null:
		_validate_zone_render_resources(visual_director)
	if player != null:
		_validate_zone_render_resources(player)
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			_validate_zone_render_resources(enemy)
	print("LOADING: zone_stage=render_validated elapsed=%.1f" % (float(Time.get_ticks_usec() - loading_started_usec) / 1000.0))
	if performance_budget_monitor != null:
		var quality_preset := str(settings.settings.get("quality_preset", "balanced")) if settings != null else "balanced"
		performance_budget_monitor.set_active_zone(current_zone_id, zone_root, player, quality_preset)
	print("LOADING: zone_stage=budget_ready elapsed=%.1f" % (float(Time.get_ticks_usec() - loading_started_usec) / 1000.0))
	if player != null:
		pending_spawn_facing = player.rotation.y
		pending_spawn_position = safe_spawn
		player.global_position = safe_spawn + Vector3.UP * 0.9
		player.velocity = Vector3.ZERO
		if using_prewarmed_spatial:
			# This scene has already completed collision and navigation setup
			# behind the menu. Do not wait for another rendered WebGL frame.
			player.global_position = Vector3(safe_spawn.x, maxf(safe_spawn.y, 0.95), safe_spawn.z)
			player.set_transition_locked(false)
			last_safe_player_position = player.global_position
			zone_transition_pending = false
			# The player and camera are already visible behind the menu. Enabling
			# their full process tree can trigger synchronous WebGL animation and
			# physics setup, so finish activation after the playable marker.
			call_deferred("_activate_prewarmed_player_runtime")
			var elapsed_ms := float(Time.get_ticks_usec() - loading_started_usec) / 1000.0
			_record_loading_metrics({
				"zone": current_zone_id,
				"to_playable_ms": elapsed_ms,
				"support_ready": true,
				"velocity_reset": true
			})
			if zone_runtime_coordinator != null:
				zone_runtime_coordinator.record_playable_transition(current_zone_id, elapsed_ms, true)
			print("LOADING: zone=%s playable_ms=%.1f" % [current_zone_id, elapsed_ms])
			loading_started_usec = 0
			hud.hide_loading()
		else:
			player.set_transition_locked(true)
			zone_transition_frames = 0
			zone_transition_pending = true
	if seamless_world != null:
		seamless_world.on_zone_activated(current_zone_id, safe_spawn)
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
	if performance_budget_monitor != null:
		performance_budget_monitor.record_transition(elapsed_ms)
	if zone_runtime_coordinator != null:
		zone_runtime_coordinator.record_playable_transition(current_zone_id, elapsed_ms, true)
	print("LOADING: zone=%s playable_ms=%.1f" % [current_zone_id, elapsed_ms])
	loading_started_usec = 0
	hud.hide_loading()

func _activate_prewarmed_player_runtime() -> void:
	if not game_started or current_zone_id != "greyfen" or player == null or not is_instance_valid(player):
		return
	player.process_mode = Node.PROCESS_MODE_INHERIT
	if camera_rig == null or not is_instance_valid(camera_rig):
		return
	camera_rig.process_mode = Node.PROCESS_MODE_INHERIT
	var gameplay_camera := camera_rig.find_child("Camera3D", true, false) as Camera3D
	if gameplay_camera != null:
		gameplay_camera.current = true

func _recover_failed_zone_load(previous_zone_id: String) -> void:
	campaign_pack_waiting = false
	if seamless_world != null:
		seamless_world.on_zone_failed(current_zone_id, "zone_build_failed")
	zone_transition_pending = false
	zone_load_request_pending = false
	requested_zone_id = ""
	if zone_root != null:
		_retire_zone_root(zone_root)
		zone_root = null
	_release_active_spatial_service()
	if route_zone_cache.has(previous_zone_id) and is_instance_valid(route_zone_cache[previous_zone_id]):
		zone_root = _activate_cached_zone(previous_zone_id)
		var cached_spatial_service: Node = route_spatial_cache.get(previous_zone_id)
		if cached_spatial_service != null and is_instance_valid(cached_spatial_service):
			route_spatial_cache.erase(previous_zone_id)
			spatial_service = cached_spatial_service
			spatial_service.process_mode = Node.PROCESS_MODE_INHERIT
		active_enemies = _valid_cached_enemies(route_enemy_cache.get(previous_zone_id, []))
		route_enemy_cache.erase(previous_zone_id)
		active_zone_signature = int(route_zone_signatures.get(previous_zone_id, -1))
		route_zone_signatures.erase(previous_zone_id)
		current_zone_id = previous_zone_id
	if player != null:
		player.set_transition_locked(false)
		player.global_position = last_safe_player_position
		player.velocity = Vector3.ZERO
	if performance_budget_monitor != null:
		var quality_preset := str(settings.settings.get("quality_preset", "balanced")) if settings != null else "balanced"
		performance_budget_monitor.set_active_zone(previous_zone_id, zone_root, player, quality_preset)
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
	# Manually detaching skins or surfaces races RenderingServer teardown. The
	# hidden cleanup owner keeps the retired root scene-owned while queue_free()
	# lets Godot release renderer dependencies at the end of a frame.
	for _frame in range(ZONE_RETIRE_FRAMES):
		await get_tree().process_frame
	if is_instance_valid(retired_root):
		if retired_zone_cleanup_root != null and is_instance_valid(retired_zone_cleanup_root):
			retired_root.reparent(retired_zone_cleanup_root, false)
		elif retired_root.is_inside_tree() and retired_root.get_parent() != null:
			retired_root.get_parent().remove_child(retired_root)
		retired_zone_roots.erase(retired_root)
		retired_root.queue_free()
		await get_tree().process_frame
	else:
		retired_zone_roots.erase(retired_root)
	pending_zone_retirements = maxi(pending_zone_retirements - 1, 0)
	# Material anchors only bridge the renderer-safe retirement window. Once the
	# final staged root has been queued and released, no retired scene owns those
	# materials anymore; dropping the anchors here prevents shutdown retention
	# while keeping shared materials alive for any active zone that still uses
	# them.
	if pending_zone_retirements == 0:
		retired_material_anchors.clear()

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
		# A skinned branch is detached from the zone before the normal zone
		# validation pass. Validate it in place so imported meshes with empty
		# surfaces cannot reach the renderer during retirement.
		_validate_zone_render_resources(branch)
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

func _cache_route_zone(zone_id: String, root: Node3D, enemies: Array, signature: int, keep_visible: bool = false, disable_collision: bool = true, disable_process: bool = true) -> void:
	if root == null or not is_instance_valid(root):
		return
	var existing = route_zone_cache.get(zone_id)
	if existing != null and existing != root and is_instance_valid(existing):
		_release_route_spatial_service(zone_id)
		_retire_zone_root(existing)
	_remove_root_from_route_cache(root)
	root.visible = keep_visible
	root.process_mode = Node.PROCESS_MODE_DISABLED if disable_process else Node.PROCESS_MODE_INHERIT
	root.position = Vector3.ZERO if keep_visible else Vector3(0, -1000, 0)
	root.set_meta("zone_resource_owner", "cached")
	root.set_meta("zone_resource_id", zone_id)
	var cached_collision_disabled := false
	if keep_visible and disable_collision:
		_set_zone_collision_enabled(root, false)
		cached_collision_disabled = true
	else:
		# Moving the inactive zone away removes route interference while keeping
		# its collision state intact. Re-enabling hundreds of cached colliders on
		# the next arrival made warm transitions miss the browser budget.
		cached_collision_disabled = false
	root.set_meta("cached_collision_disabled", cached_collision_disabled)
	root.set_meta("cached_process_disabled", disable_process)
	route_zone_cache[zone_id] = root
	route_enemy_cache[zone_id] = _valid_cached_enemies(enemies)
	route_zone_signatures[zone_id] = signature

func _cache_route_spatial_service(zone_id: String, service: Node) -> void:
	if service == null or not is_instance_valid(service):
		return
	var existing: Node = route_spatial_cache.get(zone_id)
	if existing != null and existing != service and is_instance_valid(existing):
		existing.queue_free()
	service.process_mode = Node.PROCESS_MODE_DISABLED
	route_spatial_cache[zone_id] = service

func _release_route_spatial_service(zone_id: String) -> void:
	var cached: Node = route_spatial_cache.get(zone_id)
	route_spatial_cache.erase(zone_id)
	if cached == null or not is_instance_valid(cached):
		return
	if cached == spatial_service or cached == greyfen_prewarm_spatial_service:
		return
	cached.queue_free()

func _release_active_spatial_service() -> void:
	var current: Node = spatial_service
	spatial_service = null
	if current == null or not is_instance_valid(current):
		return
	if current == greyfen_prewarm_spatial_service or route_spatial_cache.values().has(current):
		return
	current.queue_free()


func _defer_cached_zone_collision_disable(zone_id: String) -> void:
	get_tree().create_timer(0.45, true, false, true).timeout.connect(func():
		var cached_root: Node3D = route_zone_cache.get(zone_id)
		if cached_root != null and is_instance_valid(cached_root) and str(cached_root.get_meta("zone_resource_owner", "")) == "cached":
			_set_zone_collision_enabled(cached_root, false)
	, CONNECT_ONE_SHOT)

func _activate_cached_zone(zone_id: String) -> Node3D:
	var cached_root = route_zone_cache.get(zone_id)
	if cached_root == null or not is_instance_valid(cached_root):
		return null
	route_zone_cache.erase(zone_id)
	cached_root.set_meta("zone_resource_owner", "active")
	if bool(cached_root.get_meta("cached_process_disabled", true)):
		cached_root.process_mode = Node.PROCESS_MODE_INHERIT
	cached_root.position = Vector3.ZERO
	if bool(cached_root.get_meta("cached_collision_disabled", false)):
		_set_zone_collision_enabled(cached_root, true)
	cached_root.set_meta("cached_collision_disabled", false)
	cached_root.visible = true
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
		_release_route_spatial_service(id)
		if is_instance_valid(cached_root):
			_retire_zone_root(cached_root)

func _set_zone_collision_enabled(node: Node, enabled: bool) -> void:
	var targets: Array = node.get_meta("zone_collision_targets", [])
	if targets.is_empty():
		targets = _collect_zone_collision_targets(node)
		node.set_meta("zone_collision_targets", targets)
	for target in targets:
		if target == null or not is_instance_valid(target):
			continue
		_set_single_zone_collision_enabled(target, enabled)

func _collect_zone_collision_targets(root: Node) -> Array:
	var targets: Array = []
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		if current is NavigationRegion3D or current is CollisionObject3D:
			targets.append(current)
		for child in current.get_children():
			pending.append(child)
	return targets

func _set_single_zone_collision_enabled(node: Node, enabled: bool) -> void:
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

func _schedule_zone_autosave() -> void:
	var expected_zone: String = current_zone_id
	get_tree().create_timer(0.35).timeout.connect(func():
		if not resource_shutdown_prepared and game_started and player != null and is_instance_valid(player) and current_zone_id == expected_zone and save_manager != null:
			save_manager.autosave(self)
	, CONNECT_ONE_SHOT)

func _clear_route_zone_cache(preserve_root: Node3D = null) -> void:
	if zone_root != null and is_instance_valid(zone_root):
		_retire_zone_root(zone_root)
	zone_root = null
	for cached_root in route_zone_cache.values():
		if cached_root == preserve_root:
			continue
		if is_instance_valid(cached_root):
			if not cached_root.is_inside_tree():
				add_child(cached_root)
			_retire_zone_root(cached_root)
	route_zone_cache.clear()
	route_enemy_cache.clear()
	route_zone_signatures.clear()
	for raw_id in route_spatial_cache.keys().duplicate():
		_release_route_spatial_service(str(raw_id))

func prepare_resource_shutdown() -> void:
	if resource_shutdown_prepared:
		return
	resource_shutdown_prepared = true
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
	# Keep explicit ownership of every branch detached for shared skeletal
	# resource anchoring. A detached branch is not guaranteed to be released by
	# freeing its hidden owner during final tree teardown, so release the exact
	# anchors first while their references are still known.
	for raw_branch in skinned_resource_anchors.values():
		var branch := raw_branch as Node
		if branch != null and is_instance_valid(branch):
			branch.free()
	skinned_resource_anchors.clear()
	if retired_skinned_actor_pool != null and is_instance_valid(retired_skinned_actor_pool):
		# This pool owns branches detached from retired zone roots. At this point
		# prepare_resource_shutdown() has waited for every staged root to leave the
		# renderer, so synchronous destruction is safe and prevents orphaned
		# MeshInstance3D nodes from surviving outside the scene tree.
		retired_skinned_actor_pool.free()
	retired_skinned_actor_pool = null
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
	material_cache.clear()
	shared_box_mesh = null
	retirement_material = null
	retired_material_anchors.clear()
	if runtime_services != null and is_instance_valid(runtime_services):
		runtime_services.process_mode = Node.PROCESS_MODE_DISABLED
		for service in runtime_services.get_children():
			if service is Node:
				(service as Node).process_mode = Node.PROCESS_MODE_DISABLED

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

func _exit_tree() -> void:
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

func _install_world_prop_controller(zone_id: String) -> void:
	if zone_root == null or not is_instance_valid(zone_root):
		world_props = null
		return
	var existing := zone_root.find_child("WorldPropController", true, false) as WorldPropController
	if existing != null:
		world_props = existing
		return
	world_props = WorldPropController.new()
	world_props.name = "WorldPropController"
	zone_root.add_child(world_props)
	world_props.configure(zone_root, zone_id, str(settings.settings.get("quality_preset", "balanced")), story_state, audio)

func _install_opening_soundscape(zone_id: String) -> void:
	if zone_root == null or not is_instance_valid(zone_root) or audio == null:
		return
	var soundscape := zone_root.find_child("OpeningSoundscape", true, false) as OpeningSoundscape
	if soundscape == null:
		soundscape = OpeningSoundscape.new()
		soundscape.name = "OpeningSoundscape"
		zone_root.add_child(soundscape)
	var quality := str(settings.settings.get("quality_preset", "balanced")) if settings != null else "balanced"
	soundscape.configure(zone_root, zone_id, player, audio, quality)

func _handle_interaction(area) -> void:
	if world_props != null and area != null and area.has_meta("world_prop_id"):
		world_props.activate_prop(str(area.get_meta("world_prop_id", "")))
	var world_prop_component := area.find_child("InteractiveWorldProp", true, false) as InteractiveWorldProp if area != null else null
	if world_prop_component != null:
		world_prop_component.activate()
	if world_vfx != null and is_instance_valid(world_vfx) and area is Node3D:
		world_vfx.pulse_interaction((area as Node3D).global_position)
	if area.interaction_type == "minigame":
		minigames.open_game("tic_tac_toe" if area.interaction_id == "common_table" else "draughts")
	elif area.interaction_type == "vendor":
		if vendor_service == null:
			hud.toast("The shop is not available right now.")
			return
		audio.set_game_paused(true)
		get_tree().paused = true
		hud.show_vendor(area.interaction_id, vendor_service, inventory, quests, story_state)
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
			var legacy_report := _legacy_report_choice_required()
			story_state.set_flag("evidence_report", report_method)
			if legacy_report:
				# A migrated completed Road of Crows save must choose its report method
				# before the cemetery handoff is restored; never infer the old choice.
				story_state.set_flag("legacy_report_choice_required", false)
			story_state.set_flag("cemetery_bell_rung", true)
			story_state.adjust_value("anwen_trust", 1 if report_method == "private" else (-1 if report_method == "public" else 0))
			story_state.adjust_value("greyfen_fear", 1 if report_method == "public" else 0)
			quests.complete_objective("main_road_of_crows", "return_village")
			if legacy_report and not quests.is_active("main_bell_beneath_greyfen") and not quests.is_completed("main_bell_beneath_greyfen"):
				quests.unlocked["main_bell_beneath_greyfen"] = true
				quests.start_quest("main_bell_beneath_greyfen")
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
		_set_interactable_label_visible(area, false)
		_stage_dialogue_moment(area)
		audio.set_game_paused(true)
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
		elif area.interaction_id == "post_victory_token":
			story_state.set_flag("road_token_recovered", true)
			hud.toast("Oren's token is complete. Vargan binding wire is wound through the scratched name.")
			hud.set_guidance_hint("Return to Greyfen. Decide who receives the token.", 6.0)
			audio.play_event("reveal", 0.02)
		elif area.interaction_id == "chapel_door":
			story_state.set_flag("crow_chapel_opened", true)
			hud.toast("The chapel seal yields. The Crow Shrine inside is still bound to the erased names.")
			hud.set_guidance_hint("Return to the shrine and decide what should happen to the covenant.", 6.0)
			_spawn_crow_shrine_choice()
			_ensure_bell_eater()
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
		var portal := area.find_child("OathGatePortal", true, false) as OathGatePortal
		if portal != null and portal.state != OathGatePortal.PortalState.READY:
			hud.toast("The Oath Gate is still gathering the road beyond.")
			return
		if portal != null:
			portal.mark_traveling()
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
	if _road_evidence_count() >= 5 and not bool(story_state.get_flag("all_road_evidence", false)):
		story_state.set_flag("all_road_evidence", true)
		_make_all_evidence_safe_edge()
		hud.toast("Every clue agrees: the pack followed the names, not the food. A safer edge of the clearing reveals itself.")
		hud.set_guidance_hint("Use the marked edge when the creatures emerge.", 5.0)

func _road_evidence_count() -> int:
	var count := 0
	for evidence_id in ["bram", "sella", "oren", "vargan_wire", "drag_marks"]:
		if quests.is_objective_done("main_road_of_crows", evidence_id) or bool(story_state.get_flag("road_evidence_%s" % evidence_id, false)):
			count += 1
	return count

func _make_all_evidence_safe_edge() -> void:
	if zone_root == null or zone_root.find_child("RoadCrowsEvidenceSafeEdge", true, false) != null:
		return
	var edge := _make_visual_box("RoadCrowsEvidenceSafeEdge", Vector3(-4.25, 0.085, -6.25), Vector3(1.8, 0.025, 0.42), Color(0.31, 0.27, 0.14))
	edge.set_meta("narrative_state", "safe_edge")

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
	var legacy_choice: bool = _legacy_report_choice_required()
	var active_route: bool = quests.is_active("main_road_of_crows") and quests.is_objective_done("main_road_of_crows", "fight_ghoulkin") and not quests.is_objective_done("main_road_of_crows", "return_village")
	return active_route or legacy_choice

func _legacy_report_choice_required() -> bool:
	return bool(story_state.get_flag("legacy_report_choice_required", false)) and str(story_state.get_flag("evidence_report", "")) == ""

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
	var requested_position := Vector3(11.0, 0.0, 4.8)
	var safe_position: Vector3 = Vector3(spatial_service.validate_position(requested_position, 0.85, spatial_service.bank_for(requested_position)))
	# This is an authored flat cemetery stage. A generic downward ray can hit
	# the nearby wall/roof collision and float Anwen above the graves.
	safe_position.y = 0.0
	anwen.global_position = safe_position + Vector3.UP * 0.02
	anwen.set("prompt", "Meet Sister Anwen at the cemetery gate")
	_face_npc_toward_player(anwen)

func _handle_dialogue_action(action: Dictionary) -> void:
	# Dialogue action buttons emit their choice before the game receives it. The
	# close button already restores these states, so action buttons must do the
	# same before applying quest/story mutations or the world stays paused.
	get_tree().paused = false
	if hud != null:
		hud.hide_menus()
	if audio != null:
		audio.set_game_paused(false)
	audio.stop_voice()
	audio.play_event("ui")
	var type = str(action.get("type", ""))
	if not _dialogue_action_available(action):
		hud.toast("That part of the story is not ready yet.")
		_refresh_tracker()
		return
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
		# Every consequential story choice is one-shot. The flag guard above
		# covers legacy one-off choices with custom wording; the objective guard
		# keeps names, mill, testimony, ledger, and ending decisions from being
		# replayed through a stale dialogue node or a saved interaction prompt.
		var choice_quest_id := str(action.get("quest", ""))
		var choice_objective_id := str(action.get("objective", ""))
		if choice_quest_id != "" and choice_objective_id != "" and quests.is_objective_done(choice_quest_id, choice_objective_id):
			hud.toast("That decision has already been made.")
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
		elif action.get("sets_flags", {}).has("names_policy"):
			hud.show_status_cue("The names have a new public life", "victory")
			hud.set_guidance_hint("Follow the ash road to the old mill.", 6.0)
			_consume_story_choice_interactable("names_decision")
		elif action.get("sets_flags", {}).has("mill_fate"):
			hud.show_status_cue("The mill's record is settled", "victory")
			hud.set_guidance_hint("Find Captain Senn on the bandit road.", 6.0)
			_consume_story_choice_interactable("miller_record")
		if action.get("sets_flags", {}).has("halvern_fate"):
			var halvern_outcome := str(action["sets_flags"]["halvern_fate"])
			for boss in active_enemies:
				if not is_instance_valid(boss) or boss.enemy_id != "halvern_boss":
					continue
				var controller: Node = boss.get_node_or_null("BossEncounterController")
				if controller != null and controller.has_method("resolve_peaceful"):
					controller.resolve_peaceful(halvern_outcome)
				break
		if str(action.get("quest", "")) == "main_blood_under_stone" and str(action.get("objective", "")) == "ledger_choice":
			story_state.set_flag("vargan_ledger_found", true)
			story_state.set_flag("vargan_ledger_choice_made", true)
			story_state.set_flag("record_hall_unlocked", true)
			hud.set_guidance_hint("The record hall is no longer empty. Stand ready.", 5.0)
	elif type == "ending":
		_complete_ending(action.get("ending", "expose"))
		return
	if audio != null:
		audio.set_game_paused(false)
	get_tree().paused = false
	hud.hide_menus()
	_refresh_tracker()
	if current_zone_id != "":
		_load_zone(current_zone_id, player.global_position)

func _dialogue_action_available(action: Dictionary) -> bool:
	var type := str(action.get("type", ""))
	var quest_id := str(action.get("quest", ""))
	var objective_id := str(action.get("objective", ""))
	if type == "start_quest":
		return quest_id != "" and quests.is_unlocked(quest_id) and not quests.is_active(quest_id) and not quests.is_completed(quest_id)
	if type == "complete_objective":
		return quest_id != "" and objective_id != "" and quests.is_active(quest_id) and not quests.is_objective_done(quest_id, objective_id)
	if type == "resolve_side_quest":
		return quest_id != "" and quests.is_active(quest_id) and _quest_required_objectives_done(quest_id)
	if type == "story_choice" and quest_id != "" and objective_id != "":
		if not quests.is_active(quest_id) or quests.is_objective_done(quest_id, objective_id):
			return false
		return _story_choice_prerequisites_done(quest_id, objective_id)
	return true

func _quest_required_objectives_done(quest_id: String) -> bool:
	var definition: Dictionary = quests.quest_defs.get(quest_id, {})
	for raw_objective in definition.get("objectives", []):
		if bool(raw_objective.get("optional", false)):
			continue
		if not quests.is_objective_done(quest_id, str(raw_objective.get("id", ""))):
			return false
	return true

func _story_choice_prerequisites_done(quest_id: String, choice_id: String) -> bool:
	var definition: Dictionary = quests.quest_defs.get(quest_id, {})
	var found_choice := false
	for raw_objective in definition.get("objectives", []):
		var objective_id := str(raw_objective.get("id", ""))
		if objective_id == choice_id:
			found_choice = true
			break
		if bool(raw_objective.get("optional", false)):
			continue
		if not quests.is_objective_done(quest_id, objective_id):
			return false
	return found_choice
	save_manager.autosave(self)

func _on_launch_accepted() -> void:
	audio.play_event("ui", 0.0)
	# Keep the same menu-covered prewarm on Web and desktop. The HTML shell is
	# already visible, so moving Greyfen construction before the New Game click
	# removes the long post-click stall without introducing a black loading frame.
	if hud != null and hud.has_method("set_new_game_ready") and not route_zone_cache.has("greyfen"):
		hud.set_new_game_ready(false)
	if OS.has_feature("web") and runtime_packs != null and runtime_packs.has_method("request_startup_packs"):
		if startup_packs_waiting:
			return
		startup_packs_waiting = true
		if runtime_packs.has_signal("pack_ready") and not runtime_packs.pack_ready.is_connected(_on_startup_pack_ready):
			runtime_packs.pack_ready.connect(_on_startup_pack_ready)
		runtime_packs.request_startup_packs()
		# Cached Web packs can complete synchronously. The signal path handles
		# asynchronous downloads without depending on a paused-tree frame.
		if runtime_packs.startup_packs_ready():
			_on_startup_pack_ready("__startup__")
		call_deferred("_wait_for_startup_packs_then_prewarm")
		return
	if zone_streaming != null and zone_streaming.has_method("prewarm_neighbors"):
		zone_streaming.prewarm_neighbors("greyfen")
	if not greyfen_prewarm_started and not game_started:
		greyfen_prewarm_started = true
		# Do not include the heavy Greyfen build in Godot's initial Web
		# Engine.startGame promise. The HTML shell and real menu are already
		# visible; warm the route on the first deferred frame instead.
		call_deferred("_prewarm_greyfen_after_menu_frame")

func _on_startup_pack_ready(_pack_id: String) -> void:
	if not startup_packs_waiting or game_started or runtime_packs == null:
		return
	if not runtime_packs.startup_packs_ready():
		return
	startup_packs_waiting = false
	if zone_streaming != null and zone_streaming.has_method("prewarm_neighbors"):
		zone_streaming.prewarm_neighbors("greyfen")
	if not greyfen_prewarm_started:
		greyfen_prewarm_started = true
		call_deferred("_prewarm_greyfen_after_menu_frame")

func _wait_for_startup_packs_then_prewarm() -> void:
	for _frame in range(1800):
		if runtime_packs != null and runtime_packs.has_method("startup_packs_ready") and runtime_packs.startup_packs_ready():
			startup_packs_waiting = false
			if zone_streaming != null and zone_streaming.has_method("prewarm_neighbors"):
				zone_streaming.prewarm_neighbors("greyfen")
			if not greyfen_prewarm_started and not game_started:
				greyfen_prewarm_started = true
				call_deferred("_prewarm_greyfen_after_menu_frame")
			return
		var failures: Array[String] = runtime_packs.startup_pack_failures() if runtime_packs != null and runtime_packs.has_method("startup_pack_failures") else []
		if not failures.is_empty():
			startup_packs_waiting = false
			if hud != null:
				hud.toast("Opening content could not be prepared. Refresh to retry.")
			return
		await get_tree().process_frame
	startup_packs_waiting = false
	if hud != null:
		hud.toast("Opening content took too long to prepare. Refresh to retry.")

func _prewarm_greyfen_after_menu_frame() -> void:
	# Start immediately after the launch shell is accepted. Deferring the first
	# build frame allowed a fast test click (and a fast human click) to race the
	# prewarm and fall back to a cold Greyfen build. The launch/menu presentation
	# is already covering the viewport, so doing the construction here makes the
	# later New Game action deterministic without adding a second loading stall.
	if game_started or zone_root != null or route_zone_cache.has("greyfen"):
		return
	var prewarm_started := Time.get_ticks_msec()
	var phase_started := prewarm_started
	var prewarm_service := ZoneSpatialService.new()
	prewarm_service.name = "GreyfenPrewarmSpatialService"
	add_child(prewarm_service)
	prewarm_service.configure("greyfen", _river_center("greyfen"), _zone_half_extents("greyfen"))
	spatial_service = prewarm_service
	zone_root = Node3D.new()
	zone_root.name = "greyfen"
	add_child(zone_root)
	# Castle environment imports are otherwise paid on the first gate travel.
	# Warm the shared resource cache while the menu still covers the viewport so
	# the first Castle arrival remains a scene activation rather than an import.
	if asset_helper != null and asset_helper.has_method("prewarm_roles"):
		var castle_prewarm: Dictionary = asset_helper.prewarm_roles([
			"castle_wall", "castle_arch", "castle_roof", "castle_door",
			"castle_bookcase", "castle_chair", "castle_bench", "castle_table",
			"castle_weapon_stand", "castle_lantern",
			# Castle activation instantiates these same role resources. Warming their
			# imported scenes behind the menu avoids paying first-use parse and
			# skeleton setup on the gate's critical path.
			"castle_guard_human", "villager_worker_human", "villager_female_human",
			"road_ranger_human",
		])
		print("LOADING: Castle roles prewarmed loaded=%d missing=%d" % [
			Array(castle_prewarm.get("loaded", [])).size(),
			Array(castle_prewarm.get("missing", [])).size(),
		])
	runtime_light_count = 0
	tree_batch_data.clear()
	deadfall_batch_data.clear()
	prop_batch_data.clear()
	visual_box_batch_data.clear()
	terrain_patch_batch_data.clear()
	house_batch_data.clear()
	environment_batches_flushed = false
	var prewarm_build := ZoneCompositionRouter.build_core(self, "greyfen")
	var build_ms := Time.get_ticks_msec() - phase_started
	if not bool(prewarm_build.get("ok", false)):
		push_error("Greyfen prewarm composition failed: %s" % ", ".join(prewarm_build.get("errors", [])))
		_retire_zone_root(zone_root)
		zone_root = null
		prewarm_service.queue_free()
		spatial_service = null
		if hud != null and hud.has_method("set_new_game_ready"):
			hud.set_new_game_ready(true)
		return
	var prewarm_root: Node3D = zone_root
	phase_started = Time.get_ticks_msec()
	_flush_environment_batches()
	_add_visual_100_layer("greyfen")
	_apply_first_route_materials(zone_root)
	_validate_zone_render_resources(zone_root)
	prewarm_service.build_navigation(zone_root)
	var world_finalize_ms := Time.get_ticks_msec() - phase_started
	greyfen_prewarm_spatial_service = prewarm_service
	# Kael's rig and camera are also expensive to instantiate in WebGL. Prepare
	# them while the launch/menu presentation is already covering the viewport.
	phase_started = Time.get_ticks_msec()
	_spawn_player(Vector3(0, 1, 9.8))
	var player_ms := Time.get_ticks_msec() - phase_started
	# Keep the real gameplay view active behind the opaque menu so WebGL compiles
	# the same skinned materials and camera path used after New Game.
	player.visible = true
	player.set_transition_locked(true)
	player.process_mode = Node.PROCESS_MODE_INHERIT
	camera_rig.process_mode = Node.PROCESS_MODE_INHERIT
	var gameplay_camera := camera_rig.find_child("Camera3D", true, false) as Camera3D
	if gameplay_camera != null:
		gameplay_camera.current = true
	zone_root.visible = true
	zone_root.process_mode = Node.PROCESS_MODE_INHERIT
	zone_root.position = Vector3.ZERO
	# Allow one real 3D frame to reach Web/ANGLE while the menu still covers the
	# viewport. This moves first-frame shader work out of the New Game click.
	await get_tree().process_frame
	# Publish the prepared scene immediately. The launch/menu shell already
	# covers the viewport, and waiting on a 30-frame render warmup here allowed a
	# fast New Game click to race the cache publication. Shader compilation is
	# allowed to happen on the first real frame; the scene build, materials, and
	# navigation are already complete and the release performance gate settles
	# before sampling sustained play.
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
	# Keep the prewarmed route processing behind the menu so activation does not
	# pay the first-frame animation and physics setup cost again.
	_cache_route_zone("greyfen", zone_root, [], _zone_state_signature(), true, false, false)
	zone_root = null
	spatial_service = null
	if audio != null and audio.has_method("prewarm_opening_audio"):
		audio.prewarm_opening_audio()
	if hud != null and hud.has_method("set_new_game_ready"):
		hud.set_new_game_ready(true)
	print("LOADING: Greyfen prewarmed total=%dms build=%dms world=%dms player=%dms" % [
		Time.get_ticks_msec() - prewarm_started, build_ms, world_finalize_ms, player_ms,
	])

func _complete_ending(ending: String) -> void:
	var ending_id := str(ending)
	if ending_id not in ["expose", "free", "bind", "kill"]:
		hud.toast("The covenant offers no such answer.")
		get_tree().paused = false
		hud.hide_menus()
		return
	# The final covenant is immutable. This guard covers stale dialogue nodes,
	# reloads, and browser double-activation after the ending has resolved.
	if str(story_state.get_flag("final_covenant", "")) != "" or bool(story_state.get_flag("final_choice_completed", false)):
		hud.toast("The covenant has already been chosen.")
		get_tree().paused = false
		hud.hide_menus()
		return
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
	quests.world_flags["ending"] = ending_id
	story_state.set_flag("final_covenant", {"expose":"witness", "free":"mercy", "bind":"duty", "kill":"ash"}.get(ending_id, ending_id))
	quests.complete_objective("main_hart_remembers", "hear_testimony")
	if ending_id == "kill" or ending_id == "bind":
		pending_ending = ending_id
		active_interactable = null
		hud.set_prompt("")
		hud.hide_menus()
		get_tree().paused = false
		_remove_interactable("white_hart")
		if zone_root != null and is_instance_valid(zone_root):
			var witness_display := zone_root.find_child("WhiteHartWitnessDisplay", true, false)
			if witness_display != null:
				witness_display.queue_free()
		if not _has_living_enemy("white_hart_avatar"):
			var hart_boss = _spawn_enemy("white_hart_avatar", Vector3(0, 0.8, -7))
			if hart_boss != null:
				hart_boss.name = "WhiteHartFinalEncounter"
				hart_boss.leash_radius = 10.0
		audio.play_event("boss", 0.02)
		hud.toast("The White Hart answers with antler, root, and light.")
		return
	_show_ending_consequence(ending_id)

func _show_ending_consequence(ending: String) -> void:
	quests.world_flags["ending"] = ending
	quests.complete_objective("main_hart_remembers", "final_choice")
	# This flag is separate from the covenant value so boss resolution and
	# cached-zone rebuilds can distinguish a chosen outcome from a pending one.
	story_state.set_flag("final_choice_completed", true)
	pending_ending = ""
	var title = "The Road Between Crowns"
	var cards: Array[String] = EpilogueResolver.resolve(ending, story_state)
	story_state.set_flag("epilogue_cards", cards)
	var body := "\n\n".join(cards)
	audio.set_game_paused(true)
	get_tree().paused = true
	hud.show_ending(title, body)
	save_manager.checkpoint(self)

func _on_player_blade_contact(contact: Dictionary) -> void:
	var heavy := bool(contact.get("heavy", false))
	audio.play_event("heavy" if heavy else "swing")
	var result: Dictionary = combat.resolve_player_blade_contact(player, active_enemies, contact, inventory.active_oil)
	if bool(result.get("hit", false)):
		var contact_source := str(result.get("source_tag", "")).to_lower()
		var contact_color := Color(0.98, 0.78, 0.34) if contact_source != "moon_oil" else Color(0.66, 0.88, 1.0)
		CombatFeedback.weapon_contact(
			zone_root,
			result.get("blade_base", player.global_position),
			result.get("blade_tip", player.global_position),
			result.get("contact_point", result.get("point", player.global_position)),
			heavy,
			contact_color,
			result.get("previous_base", Vector3.ZERO),
			result.get("previous_tip", Vector3.ZERO)
		)
		audio.play_event_limited("heavy_hit" if heavy else "light_hit", 0.045, 0.04)
		if input_router != null:
			input_router.rumble(0.16 if heavy else 0.09, 0.30 if heavy else 0.20, 0.07)
		if camera_rig != null:
			camera_rig.shake(0.09 if heavy else 0.045)
		var target = result.get("enemy")
		if target != null and is_instance_valid(target) and target.health_component != null:
			hud.show_enemy(target.display_name, target.health_component.health, target.health_component.max_health)
			if target.enemy_id == "bog_wretch":
				if inventory.active_oil == "moon_oil":
					_expose_bog_core(target, "Moon Oil")
				elif heavy:
					_record_bog_stagger(target, "heavy blows")

func _on_player_arrow_unavailable() -> void:
	hud.toast("No arrows. Tor keeps a reserve at his forge in Greyfen.")
	hud.show_status_cue("No arrows", "hurt")

func _on_player_arrow(request: Dictionary) -> void:
	if player == null or zone_root == null:
		return
	var origin: Vector3 = request.get("origin", player.global_position + Vector3.UP * 1.3)
	var direction: Vector3 = request.get("direction", -player.global_transform.basis.z)
	direction.y = 0.0
	if direction.length_squared() < 0.5:
		direction = -player.global_transform.basis.z
		direction.y = 0.0
	direction = direction.normalized()
	var arrow_id := str(request.get("arrow_id", "standard_arrow"))
	var arrow_def: Dictionary = inventory.item_defs.get(arrow_id, {})
	var effect: Dictionary = arrow_def.get("effect", {})
	var damage := float(effect.get("damage", 28.0))
	var endpoint: Vector3 = origin + direction * float(request.get("range", 24.0))
	var query := PhysicsRayQueryParameters3D.create(origin, endpoint)
	var arrow_exclusions: Array[RID] = [player.get_rid()]
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			arrow_exclusions.append(enemy.get_rid())
	query.exclude = arrow_exclusions
	query.collide_with_areas = false
	var wall_hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not wall_hit.is_empty():
		endpoint = wall_hit.position
	var result: Dictionary = combat.resolve_arrow_shot(active_enemies, {
		"origin": origin,
		"endpoint": endpoint,
		"direction": direction,
		"width": float(request.get("width", 0.34)),
		"damage": damage,
		"source_tag": "arrow_%s" % arrow_id,
	})
	_make_arrow_trail(origin, endpoint, Color(0.92, 0.70, 0.34) if arrow_id == "standard_arrow" else (Color(0.72, 0.86, 0.96) if arrow_id == "bodkin_arrow" else Color(1.0, 0.30, 0.12)))
	if bool(result.get("hit", false)):
		audio.play_event("light_hit", 0.03)
		hud.show_status_cue("Arrow hit: %d" % int(damage), "item")
		CombatFeedback.impact_burst(zone_root, result.get("point", endpoint), false, Color(1.0, 0.52, 0.20) if arrow_id == "ashfire_arrow" else Color(0.95, 0.78, 0.38))
		var target = result.get("enemy")
		if target != null and is_instance_valid(target):
			hud.show_enemy(target.display_name, target.health_component.health, target.health_component.max_health)
	else:
		audio.play_event("swing", 0.02)

func _make_arrow_trail(origin: Vector3, endpoint: Vector3, color: Color) -> void:
	var length := origin.distance_to(endpoint)
	if length <= 0.05:
		return
	var root := Node3D.new()
	root.name = "ArrowFlightEffect"
	root.add_to_group("arrow_runtime_effect")
	zone_root.add_child(root)
	root.global_position = origin.lerp(endpoint, 0.5)
	root.look_at(endpoint, Vector3.UP)
	var shaft := MeshInstance3D.new()
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.018
	shaft_mesh.bottom_radius = 0.022
	shaft_mesh.height = length
	shaft_mesh.radial_segments = 6
	shaft.mesh = shaft_mesh
	shaft.rotation_degrees.x = 90.0
	shaft.material_override = _oathfire_material(Color(color.r, color.g, color.b, 0.88), 1.1)
	root.add_child(shaft)
	root.scale = Vector3(0.12, 0.12, 0.12)
	var tween := create_tween()
	tween.tween_property(root, "scale", Vector3.ONE, 0.06)
	tween.tween_interval(0.08)
	tween.tween_property(root, "scale", Vector3(0.08, 0.08, 0.08), 0.12)
	tween.tween_callback(root.queue_free)

func _on_player_beam_phase(phase: String) -> void:
	match phase:
		"sheathing": audio.play_event("oathfire_sheathe",0.02)
		"charging": audio.play_event("oathfire_charge",0.01)
		"releasing": audio.play_event("oathfire_release",0.015)

func _on_player_beam(charge_ratio: float, direction: Vector3) -> void:
	if player == null or zone_root == null:
		return
	_clear_oathfire_effects()
	var locked_direction: Vector3 = direction
	locked_direction.y = 0.0
	if locked_direction.length_squared() < 0.5 and player.has_method("get_beam_locked_direction"):
		locked_direction = player.get_beam_locked_direction()
	if locked_direction.length_squared() < 0.5:
		locked_direction = -player.global_transform.basis.z
	locked_direction.y = 0.0
	if locked_direction.length_squared() < 0.5:
		locked_direction = Vector3.FORWARD
	locked_direction = locked_direction.normalized()
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
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		endpoint = result.position
	var damage: float = lerpf(35.0, 70.0, charge_ratio)
	var cast := {
		"origin": origin,
		"direction": locked_direction,
		"endpoint": endpoint,
		"endpoint_distance": origin.distance_to(endpoint),
		"width": 1.2,
		"damage": damage,
		"charge_ratio": charge_ratio
	}
	var hits: Array = combat.resolve_oathfire_cast(active_enemies, cast)
	set_meta("last_oathfire_cast", cast)
	set_meta("last_oathfire_hit_count", hits.size())
	audio.play_event("heavy", 0.03)
	_make_oathfire_beam(origin, endpoint, charge_ratio, not _performance_mode())
	CombatFeedback.beam_endpoint(zone_root, endpoint, locked_direction, not _performance_mode())
	if camera_rig != null:
		camera_rig.shake(0.12 + 0.08 * charge_ratio)
	CombatFeedback.ground_ring(zone_root, player.global_position, Color(0.18, 0.72, 0.95), 0.75, 0.18)
	CombatFeedback.impact_burst(zone_root, origin, false, Color(0.62, 0.95, 1.0))
	CombatFeedback.impact_burst(zone_root, endpoint, true, Color(0.26, 0.82, 1.0))
	for enemy in hits:
		if is_instance_valid(enemy) and enemy.has_method("interrupt_boss_windup") and str(enemy.get("enemy_id")) == "ashwing":
			if enemy.interrupt_boss_windup("oathfire"):
				hud.toast("Oathfire breaks Ashwing's breath.")
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
	var surface := "road" if on_road else "forest"
	if current_zone_id in ["vargan_court", "record_hall", "undercroft", "assembly"]:
		surface = "stone"
	elif current_zone_id in ["marsh_crossing", "old_mill", "burned_farmstead"]:
		surface = "mud"
	elif current_zone_id == "hart_glade":
		surface = "forest"
	audio.play_footstep(current_zone_id, on_road, surface)

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

func _purchase_from_vendor(vendor_id: String, item_id: String, quantity: int = 1) -> void:
	if vendor_service == null:
		return
	var result: Dictionary
	if item_id == "__emergency_arrows__":
		result = vendor_service.claim_emergency_arrow_refill(vendor_id, inventory)
	else:
		result = vendor_service.buy(vendor_id, item_id, quantity, inventory, story_state, quests)
	if bool(result.get("ok", false)):
		audio.play_event("ui")
		_refresh_equipment_readout()
		hud.show_status_cue(str(result.get("message", "Purchase complete.")), "item")
	else:
		audio.play_event("ui")

func _on_enemy_died(enemy) -> void:
	audio.play_event("death", 0.05)
	if camera_rig != null:
		camera_rig.shake(0.09)
	if zone_root != null and enemy != null:
		CombatFeedback.ground_ring(zone_root, enemy.global_position, Color(0.12, 0.08, 0.055), 0.9, 0.24)
	if bool(enemy.get("is_boss")):
		if enemy.enemy_id == "bell_eater":
			_restore_bell_eater_bystanders()
			story_state.set_flag("bell_eater_defeated", true)
			story_state.set_flag("cemetery_bell_silent", true)
			hud.show_status_cue("The Bell-Eater is silent", "victory")
			hud.toast("The chapel bell stops. Beneath the silence, the Crow Shrine waits for your answer.")
			hud.set_guidance_hint("Choose what the Crow Shrine should remember.", 6.0)
		elif enemy.enemy_id == "rootbound_colossus":
			story_state.set_flag("rootbound_colossus_defeated", true)
			hud.show_status_cue("The roots release Greyfen", "victory")
			hud.toast("The clearing opens around a heart of oathwood. The road remembers a new name.")
		elif enemy.enemy_id == "ashwing":
			story_state.set_flag("ashwing_defeated", true)
			hud.show_status_cue("Ashwing falls", "victory")
			hud.toast("The mill roof catches the last ember, then goes dark. Something useful survived in the ash.")
		elif enemy.enemy_id == "halvern_boss":
			story_state.set_flag("halvern_fate", "defeated")
			quests.complete_objective("main_last_witness", "break_halvern_guard")
			hud.show_status_cue("The Gravebound Knight yields", "victory")
			hud.set_guidance_hint("Decide whether Halvern's testimony should live.", 6.0)
		elif enemy.enemy_id == "white_hart_avatar":
			var ending = pending_ending if pending_ending != "" else "kill"
			pending_ending = ""
			story_state.set_flag("hart_defeated", true)
			_show_ending_consequence(ending)
	elif current_zone_id == "greyfen" and bool(enemy.get_meta("act_one_cemetery_ambush", false)):
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
			_activate_wychwood_wave(["wychwood_stalker"], "Branches snap along the left flank.")
		elif wychwood_pack_kills == 3:
			_activate_wychwood_wave(["wychwood_raider"], "A raider cuts across the clearing.")
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
			if not bool(story_state.get_flag("ashwing_spawned", false)) and enemy_defs.has("ashwing"):
				story_state.set_flag("ashwing_spawned", true)
				var ashwing := _spawn_enemy("ashwing", Vector3(0, 1.0, -9.0))
				if ashwing != null:
					ashwing.name = "AshwingCarrionDrake"
					ashwing.leash_radius = 10.0
					hud.toast("The mill roof groans. Ashwing drops through the smoke.")
			_make_named_interactable("miller_record", "dialogue", "Read the miller's record", Vector3(-7.0,0,-7), Color(0.5,0.4,0.25))
			hud.show_status_cue("The mill falls quiet", "victory")
			hud.set_guidance_hint("Read the miller's ledger beside the broken wall.", 5.5)
	if enemy.health_component != null:
		hud.show_enemy(enemy.display_name, 0.0, enemy.health_component.max_health)
	var memory_rule := str(enemy.get_meta("memory_rule", ""))
	if memory_rule != "" and not bool(enemy.get_meta("memory_rule_seen", false)):
		enemy.set_meta("memory_rule_seen", true)
		hud.toast("%s slain. %s" % [enemy.display_name, memory_rule])
	else:
		hud.toast("%s slain." % enemy.display_name)
	save_manager.autosave(self)

func _on_enemy_damaged(enemy, current: float, maximum: float) -> void:
	hud.show_enemy(enemy.display_name, current, maximum)
	hud.show_status_cue("Enemy hit", "item")
	audio.play_event_limited("stagger", 0.065, 0.06)

func _on_enemy_windup_started(enemy) -> void:
	audio.play_event_limited("enemy_windup", 0.28, 0.02)
	if zone_root != null and enemy != null:
		if bool(enemy.get("is_boss")):
			CombatFeedback.boss_telegraph(zone_root, enemy.global_position, enemy.enemy_id)
		else:
			CombatFeedback.ground_ring(zone_root, enemy.global_position, Color(0.46, 0.05, 0.025), 0.62, 0.18)
	if enemy != null and enemy.health_component != null:
		hud.show_enemy(enemy.display_name, enemy.health_component.health, enemy.health_component.max_health)
	if current_zone_id == "wychwood" and not bool(tutorial_flags.get("block_hint_done", false)):
		hud.set_guidance_hint("Tap Q at the lunge to parry. Hold Q to block.", 4.2)

func _on_enemy_attack_resolved(enemy, parried: bool, contact_position: Vector3) -> void:
	if parried:
		audio.play_event_limited("parry", 0.10, 0.03)
		if input_router != null:
			input_router.rumble(0.24, 0.52, 0.10)
		if camera_rig != null:
			camera_rig.shake(0.18)
		if zone_root != null:
			CombatFeedback.block_flash(zone_root, player.global_position, true, contact_position)
			CombatFeedback.impact_burst(zone_root, contact_position, true, Color(0.74, 0.88, 1.0))
			CombatFeedback.ground_ring(zone_root, player.global_position, Color(0.22, 0.46, 0.72), 0.65, 0.16)
		hud.show_status_cue("Parry", "parry")
		hud.toast("Parry breaks %s's guard." % enemy.display_name)
		if enemy != null and enemy.enemy_id == "bog_wretch":
			_record_bog_stagger(enemy, "parries")
	else:
		audio.play_event_limited("ghoulkin_lunge" if enemy != null and enemy.enemy_id == "ghoulkin" else "hit", 0.08, 0.04)
		if zone_root != null and enemy != null:
			CombatFeedback.impact_burst(zone_root, contact_position, false, Color(0.85, 0.30, 0.12))
	if enemy != null and enemy.health_component != null:
		hud.show_enemy(enemy.display_name, enemy.health_component.health, enemy.health_component.max_health)

func _on_enemy_parry_window_opened(enemy: Node, duration: float) -> void:
	if enemy == null or not is_instance_valid(enemy) or not bool(enemy.get("is_boss")):
		return
	if enemy.enemy_id == "halvern_boss":
		story_state.set_flag("halvern_guard_broken", true)
		if quests.is_active("main_last_witness"):
			quests.complete_objective("main_last_witness", "break_halvern_guard")
		hud.show_status_cue("Halvern's guard breaks", "parry")
		hud.set_guidance_hint("Speak to Halvern before the testimony window closes.", maxf(duration, 2.5))
		audio.play_event_limited("parry", 0.16, 0.02)

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

func _on_target_lock_changed(target_actor: Node3D, locked: bool) -> void:
	if hud == null:
		return
	if not locked or target_actor == null or not is_instance_valid(target_actor):
		hud.clear_target_lock_status()
		return
	var display_name := str(target_actor.get("display_name"))
	hud.set_target_lock_status(display_name if display_name != "" else "Enemy", player.global_position.distance_to(target_actor.global_position))

func _update_target_lock_hud() -> void:
	if hud == null or camera_rig == null or not camera_rig.has_method("get_locked_combat_target"):
		return
	var target_actor: Node3D = camera_rig.get_locked_combat_target()
	if target_actor == null or not is_instance_valid(target_actor):
		hud.clear_target_lock_status()
		return
	var display_name := str(target_actor.get("display_name"))
	hud.set_target_lock_status(display_name if display_name != "" else "Enemy", player.global_position.distance_to(target_actor.global_position))

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

func _consume_story_choice_interactable(id: String) -> void:
	if active_interactable != null and str(active_interactable.get("interaction_id")) == id:
		_mark_interaction_removed(active_interactable)
		active_interactable.queue_free()
		active_interactable = null
	_remove_interactable(id)

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
	var boss_states: Dictionary = boss_saved_states.duplicate(true)
	for enemy in active_enemies:
		if not is_instance_valid(enemy) or not bool(enemy.get("is_boss")):
			continue
		var controller: Node = enemy.get_node_or_null("BossEncounterController")
		if controller != null and controller.has_method("save_state"):
			boss_states[enemy.enemy_id] = controller.save_state()
	return {
		"removed_interactions": removed_interactions,
		"pending_ending": pending_ending,
		"wychwood_pack_kills": wychwood_pack_kills,
		"ghoulkin_kills": wychwood_pack_kills,
		"boss_states": boss_states,
		"day_night": day_night.save_state() if day_night != null else {}
	}

func load_world_state(state: Dictionary) -> void:
	removed_interactions = state.get("removed_interactions", {})
	pending_ending = str(state.get("pending_ending", ""))
	wychwood_pack_kills = int(state.get("wychwood_pack_kills", state.get("ghoulkin_kills", wychwood_pack_kills)))
	boss_saved_states = state.get("boss_states", {}) if typeof(state.get("boss_states", {})) == TYPE_DICTIONARY else {}
	if day_night != null:
		day_night.load_state(state.get("day_night", {}))

func _on_player_died() -> void:
	if camera_rig != null and camera_rig.has_method("clear_target_lock"):
		camera_rig.clear_target_lock()
	if hud != null and hud.has_method("clear_target_lock_status"):
		hud.clear_target_lock_status()
	audio.play_event("hurt")
	audio.set_game_paused(true)
	get_tree().paused = true
	hud.show_death_screen("The road keeps its dead.\n\nLoad Last Checkpoint returns Kael to the last safe contract marker with quest progress preserved.")

func _on_dialogue_closed_audio() -> void:
	if audio != null:
		audio.set_game_paused(false)

func _pause_game() -> void:
	if camera_rig != null and camera_rig.has_method("clear_target_lock"):
		camera_rig.clear_target_lock()
	if hud != null and hud.has_method("clear_target_lock_status"):
		hud.clear_target_lock_status()
	audio.set_game_paused(true)
	get_tree().paused = true
	paused_by_menu = true
	if input_router != null and input_router.has_method("set_context"):
		input_router.set_context("pause")
	audio.play_event("ui")
	hud.show_pause_menu()

func _resume_game() -> void:
	audio.set_game_paused(false)
	get_tree().paused = false
	paused_by_menu = false
	if input_router != null and input_router.has_method("set_gameplay_context"):
		input_router.set_gameplay_context()
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
	elif action == "high_contrast":
		settings.toggle_high_contrast()
	elif action == "control_preset":
		settings.cycle_control_preset()
	if action != "visual_preset":
		hud.toast("Settings updated.")
	hud.show_settings_menu(hud.controls_back_target)

func _apply_runtime_settings(current_settings: Dictionary) -> void:
	if performance_budget_monitor != null:
		performance_budget_monitor.quality = str(current_settings.get("quality_preset", "balanced"))
	if audio != null:
		audio.set_master_volume(float(current_settings.get("master_volume", 0.85)))
		audio.set_ambient_accents_enabled(str(current_settings.get("quality_preset", "balanced")) == "quality")
	if hud != null:
		hud.apply_accessibility(current_settings)
	if camera_rig != null:
		camera_rig.apply_settings(
			float(current_settings.get("mouse_sensitivity", 0.003)),
			bool(current_settings.get("invert_y", false)),
			float(current_settings.get("gamepad_look_sensitivity", 1.0))
		)
		camera_rig.shake_decay = 1000.0 if float(current_settings.get("camera_shake", 1.0)) <= 0.0 else 6.0 / maxf(float(current_settings.get("camera_shake", 1.0)), 0.5)
	if visual_director != null and visual_director.sun != null:
		visual_director.apply_settings(current_settings)
		visual_director.sun.shadow_enabled = int(current_settings.get("shadow_quality", 1)) > 0
		visual_director.sun.directional_shadow_max_distance = 42.0

func _refresh_tracker() -> void:
	var tracker_text: String
	if quest_beats != null and quest_beats.has_method("refresh"):
		quest_beats.refresh()
		tracker_text = str(quest_presentation.get_tracker_text() if quest_presentation != null else quests.get_tracker_text())
		if quest_beats.has_method("decorate_tracker"):
			tracker_text = quest_beats.decorate_tracker(tracker_text)
	elif zone_runtime_coordinator != null:
		tracker_text = zone_runtime_coordinator.refresh_presentation()
	else:
		tracker_text = str(quest_presentation.get_tracker_text() if quest_presentation != null else quests.get_tracker_text())
	hud.set_tracker(tracker_text)
	_update_compass()

func _refresh_equipment_readout() -> void:
	if hud == null or inventory == null:
		return
	var oil_name = ""
	if inventory.active_oil != "":
		oil_name = inventory.get_item_name(inventory.active_oil)
	hud.update_equipment(int(inventory.items.get("redroot_potion", 0)), int(inventory.items.get("ash_bomb", 0)), oil_name, int(inventory.items.get("standard_arrow", 0)), "Standard")

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
		hud.set_guidance_hint("The north road leaves Greyfen. Follow it into Wychwood.", 4.5)
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
		if wychwood_pack_kills == 0:
			_activate_wychwood_wave(["ghoulkin"], "A Ghoulkin unfolds beside the old road.")
	if current_zone_id == "wychwood" and not bool(tutorial_flags.get("near_clearing_audio", false)) and player.global_position.z < -4.0:
		tutorial_flags["near_clearing_audio"] = true
		audio.play_event("ghoulkin_idle", 0.03)
	if current_zone_id == "wychwood" \
			and not bool(story_state.get_flag("wychwood_pack_cleared", false)) \
			and _has_active_encounter_enemy() \
			and not bool(tutorial_flags.get("combat", false)):
		tutorial_flags["combat"] = true
		audio.set_music_state("ghoulkin_combat")
		audio.play_event("wychwood_tension", 0.01)
		hud.toast("Survive the Ghoulkin.")
		hud.set_guidance_hint("Left click strike | Space dodge | Tap Q parry | Hold Q block", 6.0)

func _update_compass() -> void:
	if hud == null or player == null:
		return
	var zone_name: String = str(quest_presentation.get_zone_display_name(current_zone_id)) if quest_presentation != null else _zone_display_name(current_zone_id)
	hud.set_compass("%s | %s" % [zone_name, _nearest_interactable_summary()])

func _nearest_interactable_summary() -> String:
	if zone_root == null or player == null:
		return "No marker"
	var best_text = "No marker"
	var best_score = 9999.0
	var tracked_id: String = quest_presentation.get_tracked_quest() if quest_presentation != null else (quests.get_tracked_quest() if quests.has_method("get_tracked_quest") else "")
	var tracked_objective: String = str(quest_presentation.get_active_objective_id(tracked_id)) if quest_presentation != null else _tracked_objective_id(tracked_id)
	var found_tracked_target := false
	# Interaction areas are indexed once on zone activation. Scanning every
	# direct child of the complete procedural zone from the compass timer caused
	# periodic frame spikes and could miss nested gate/clue areas. Use the same
	# authoritative cache as focus resolution instead.
	for child in interaction_area_cache:
		if child == null or not is_instance_valid(child) or not child.is_inside_tree():
			continue
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
		return quest_presentation.get_active_objective_text(tracked_id, tracked_objective) if quest_presentation != null else _tracked_objective_text(tracked_id, tracked_objective)
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
	if spatial_service != null and spatial_service.zone_id == zone:
		var active_candidate: Vector3 = spatial_service.validate_position(pos, 0.90, spatial_service.bank_for(pos))
		if river_z < 900.0 and absf(active_candidate.x) <= 2.0 and absf(active_candidate.z - river_z) <= 2.25 and not spatial_service.is_river_excluded(active_candidate, 0.90):
			active_candidate.y = maxf(active_candidate.y, 0.95)
			return active_candidate
		return spatial_service.nearest_safe(active_candidate, spatial_service.bank_for(active_candidate))
	var validator = ZoneSpatialService.new()
	validator.configure(zone, _river_center(zone), _zone_half_extents(zone))
	var fallback_candidate: Vector3 = validator.validate_position(pos, 0.90, validator.bank_for(pos))
	if river_z < 900.0 and absf(fallback_candidate.x) <= 2.0 and absf(fallback_candidate.z - river_z) <= 2.25 and not validator.is_river_excluded(fallback_candidate, 0.90):
		fallback_candidate.y = maxf(fallback_candidate.y, 0.95)
		validator.free()
		return fallback_candidate
	var safe := validator.nearest_safe(fallback_candidate, validator.bank_for(fallback_candidate))
	validator.free()
	return safe

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
	# The bridge deck occupies the river exclusion band by design. It is flush
	# with the banks, so identify the legal crossing by the full bridge corridor
	# rather than by actor height. This also prevents the recovery guard from
	# snapping a player off the deck while stepping onto the far bank.
	var on_bridge_deck := pos.y >= 0.2 and absf(pos.x) <= 2.72 and absf(pos.z - river_z) <= 3.15
	if on_bridge_deck:
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

func get_zone_half_extents(zone_id: String) -> Vector2:
	if zone_id == "wychwood":
		return Vector2(22, 17)
	if zone_id == "greyfen":
		return Vector2(21, 17)
	if zone_id == "bandit_road":
		return Vector2(22, 19)
	if zone_id in ["vargan_approach", "vargan_court"]:
		return Vector2(23, 19)
	if zone_id == "record_hall":
		return Vector2(17, 15)
	if zone_id == "undercroft":
		return Vector2(18, 17)
	if zone_id == "assembly":
		return Vector2(21, 17)
	if zone_id == "hart_glade":
		return Vector2(22, 19)
	return Vector2(24, 21)

func _zone_half_extents(zone_id: String) -> Vector2:
	return get_zone_half_extents(zone_id)

func _make_play_area_bounds(width: float, depth: float, color: Color) -> void:
	var half_w = width * 0.5
	var half_d = depth * 0.5
	_make_boundary_edge("north", width, depth, color)
	_make_boundary_edge("south", width, depth, color)
	_make_boundary_edge("west", width, depth, color)
	_make_boundary_edge("east", width, depth, color)

func _make_boundary_edge(edge_id: String, width: float, depth: float, color: Color) -> void:
	var half_w := width * 0.5
	var half_d := depth * 0.5
	var open_edge: Dictionary = seamless_world.open_edges_for(current_zone_id).get(edge_id, {}) if seamless_world != null else {}
	var opening_half := float(open_edge.get("half_width", 0.0))
	var lane := float(open_edge.get("lane", 0.0))
	var is_open := not open_edge.is_empty() and opening_half > 0.0
	var wall_thickness := 1.2
	var wall_height := 1.8
	var collision_thickness := 0.4
	if not is_open:
		match edge_id:
			"north":
				_make_prop_box("NorthBerm", Vector3(0, 0.9, -half_d), Vector3(width, wall_height, wall_thickness), color)
				_make_invisible_wall(Vector3(0, 1.6, -half_d - 0.65), Vector3(width, 3.2, collision_thickness))
			"south":
				_make_prop_box("SouthBerm", Vector3(0, 0.9, half_d), Vector3(width, wall_height, wall_thickness), color)
				_make_invisible_wall(Vector3(0, 1.6, half_d + 0.65), Vector3(width, 3.2, collision_thickness))
			"west":
				_make_prop_box("WestBerm", Vector3(-half_w, 0.9, 0), Vector3(wall_thickness, wall_height, depth), color)
				_make_invisible_wall(Vector3(-half_w - 0.65, 1.6, 0), Vector3(collision_thickness, 3.2, depth))
			"east":
				_make_prop_box("EastBerm", Vector3(half_w, 0.9, 0), Vector3(wall_thickness, wall_height, depth), color)
				_make_invisible_wall(Vector3(half_w + 0.65, 1.6, 0), Vector3(collision_thickness, 3.2, depth))
		return
	var line_half := half_w if edge_id in ["north", "south"] else half_d
	var start := clampf(lane - opening_half, -line_half + 0.6, line_half - 0.6)
	var finish := clampf(lane + opening_half, -line_half + 0.6, line_half - 0.6)
	var segments := [[-line_half, start], [finish, line_half]]
	for segment in segments:
		var segment_start := float(segment[0])
		var segment_end := float(segment[1])
		if segment_end - segment_start < 0.35:
			continue
		var center := (segment_start + segment_end) * 0.5
		var length := segment_end - segment_start
		match edge_id:
			"north":
				_make_prop_box("NorthBerm", Vector3(center, 0.9, -half_d), Vector3(length, wall_height, wall_thickness), color)
				_make_invisible_wall(Vector3(center, 1.6, -half_d - 0.65), Vector3(length, 3.2, collision_thickness))
			"south":
				_make_prop_box("SouthBerm", Vector3(center, 0.9, half_d), Vector3(length, wall_height, wall_thickness), color)
				_make_invisible_wall(Vector3(center, 1.6, half_d + 0.65), Vector3(length, 3.2, collision_thickness))
			"west":
				_make_prop_box("WestBerm", Vector3(-half_w, 0.9, center), Vector3(wall_thickness, wall_height, length), color)
				_make_invisible_wall(Vector3(-half_w - 0.65, 1.6, center), Vector3(collision_thickness, 3.2, length))
			"east":
				_make_prop_box("EastBerm", Vector3(half_w, 0.9, center), Vector3(wall_thickness, wall_height, length), color)
				_make_invisible_wall(Vector3(half_w + 0.65, 1.6, center), Vector3(collision_thickness, 3.2, length))

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
	var columns = 6 if paved else 1
	multimesh.instance_count = rows * columns
	var index = 0
	for row in range(rows):
		for column in range(columns):
			var row_offset := 0.09 if paved and row % 2 == 1 else 0.0
			var x = (float(column) - 2.5) * 0.62 + row_offset if paved else sin(float(row) * 1.7) * 0.55
			var z = -13.0 + float(row) * (0.63 if paved else 2.05)
			var yaw = sin(float(row * 7 + column * 3)) * 0.035 if paved else sin(float(row) * 0.8) * 0.16
			var basis := Basis(Vector3.UP, yaw)
			if paved:
				basis = basis.scaled(Vector3(0.82 + float((row + column) % 3) * 0.025, 1.0, 0.82 + float((row * 2 + column) % 3) * 0.025))
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
	for z in [-12, -4, 4, 12]:
		_make_path_stone(Vector3(-2.35 + randf_range(-0.12, 0.12), 0, z + randf_range(-0.35, 0.35)), 0.35)
		_make_path_stone(Vector3(2.35 + randf_range(-0.12, 0.12), 0, z + randf_range(-0.35, 0.35)), 0.32)

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
	if spatial_service != null and spatial_service.is_reserved(pos, maxf(size.x, size.z) * 0.5 + 0.35):
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
	for z in [-10.0, 2.0, 10.0]:
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
	var glow_mesh := SphereMesh.new()
	glow_mesh.radial_segments = 5
	glow_mesh.rings = 3
	glow.mesh = glow_mesh
	glow.scale = Vector3(0.16, 0.22, 0.16)
	glow.position = pos + Vector3(0.56, 1.17, 0)
	glow.material_override = _emissive_mat(glow_color, 1.25)
	glow.set_meta("world_prop_kind", "lantern")
	glow.set_meta("world_prop_id", "lantern_glow")
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
	var flame_mesh := SphereMesh.new()
	flame_mesh.radial_segments = 5
	flame_mesh.rings = 3
	flame.mesh = flame_mesh
	flame.scale = Vector3(0.07, 0.11, 0.07)
	flame.position = pos + Vector3(0, 0.39, 0)
	flame.material_override = _emissive_mat(Color(1.0, 0.48, 0.14), 1.1)
	zone_root.add_child(flame)

func _make_hanging_cloth(pos: Vector3, size: Vector3, color: Color) -> void:
	_make_visual_box("HangingCloth", pos, size, color)

func _make_fake_fog_bank(pos: Vector3) -> void:
	_make_visual_box("LowColdFogBank", pos + Vector3(0, 0.07, 0), Vector3(1.6, 0.10, 0.55), Color(0.105, 0.125, 0.118))

func _make_crow_silhouettes() -> void:
	var index := 0
	for item in [
		[Vector3(-8.5, 5.8, -11.5), -14.0],
		[Vector3(10.2, 5.5, -10.6), 18.0]
	]:
		var root := Node3D.new()
		root.name = "CrowSilhouette"
		root.position = item[0]
		root.rotation_degrees.y = float(item[1])
		root.set_meta("motion_type", "bird")
		root.set_meta("motion_phase", float(index) * 1.7)
		root.set_meta("motion_amount", 4.0)
		zone_root.add_child(root)
		_add_crow_part(root, "CrowBody", SphereMesh.new(), Vector3(0, 0, 0), Vector3(0.18, 0.12, 0.30), Color(0.010, 0.010, 0.012))
		_add_crow_part(root, "CrowHead", SphereMesh.new(), Vector3(0, 0.10, -0.22), Vector3(0.12, 0.11, 0.13), Color(0.016, 0.016, 0.018))
		var beak_mesh := CylinderMesh.new()
		beak_mesh.top_radius = 0.0
		beak_mesh.bottom_radius = 0.055
		beak_mesh.height = 0.16
		_add_crow_part(root, "CrowBeak", beak_mesh, Vector3(0, 0.08, -0.36), Vector3(0.72, 0.72, 1.0), Color(0.15, 0.12, 0.08), Vector3(-90, 0, 0))
		_add_crow_part(root, "CrowWingLeft", SphereMesh.new(), Vector3(-0.18, 0.0, -0.01), Vector3(0.30, 0.035, 0.13), Color(0.008, 0.008, 0.010), Vector3(0, 0, -18))
		_add_crow_part(root, "CrowWingRight", SphereMesh.new(), Vector3(0.18, 0.0, -0.01), Vector3(0.30, 0.035, 0.13), Color(0.008, 0.008, 0.010), Vector3(0, 0, 18))
		_add_crow_part(root, "CrowTail", SphereMesh.new(), Vector3(0, -0.02, 0.24), Vector3(0.12, 0.04, 0.24), Color(0.008, 0.008, 0.010), Vector3(18, 0, 0))
		index += 1

func _add_crow_part(parent: Node3D, name: String, mesh: Mesh, local_pos: Vector3, scale_value: Vector3, color: Color, rotation_degrees := Vector3.ZERO) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = name
	part.mesh = mesh
	part.position = local_pos
	part.scale = scale_value
	part.rotation_degrees = rotation_degrees
	part.material_override = _mat(color)
	part.visibility_range_end = 32.0
	parent.add_child(part)
	return part

func _make_visual_box(name: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	pos = river_safe_position(pos,size.z*0.5+0.18)
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = name
	mesh_instance.set_meta("visual_name", name)
	mesh_instance.position = pos
	mesh_instance.visibility_range_end = 32.0
	# Batched markers are removed during environment finalization, but they
	# still spend at least one frame in the scene tree. Give them a valid
	# fallback surface immediately so renderer cleanup cannot observe a null
	# mesh/material while a zone is being assembled.
	mesh_instance.mesh = shared_box_mesh
	mesh_instance.material_override = _valid_material_or_fallback(null)
	zone_root.add_child(mesh_instance)
	if environment_batches_flushed:
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
	mesh_instance.visibility_range_end = 32.0
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
	_make_named_interactable("post_victory_token", "clue", "Examine the token in the dead creature's hand", Vector3(1.35, 0.0, -4.55), Color(0.46, 0.28, 0.12), Vector3(0.55, 0.55, 0.55))

func _make_narrative_aftermath(zone_id: String) -> void:
	if zone_root == null:
		return
	if zone_id == "wychwood":
		if quests.is_objective_done("main_road_of_crows", "fight_ghoulkin") or bool(story_state.get_flag("wychwood_pack_cleared", false)):
			_make_post_ghoulkin_story_clue()
			_make_visual_box("WychwoodPackAshResidue", Vector3(0.0, 0.078, -7.0), Vector3(1.7, 0.018, 1.25), Color(0.045, 0.035, 0.032))
			_make_visual_box("WychwoodPackBrokenBinding", Vector3(1.2, 0.115, -6.4), Vector3(0.55, 0.025, 0.08), Color(0.22, 0.16, 0.10))
		if bool(story_state.get_flag("all_road_evidence", false)):
			_make_all_evidence_safe_edge()
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
	var roof_color := Color(0.16, 0.072, 0.045) if facade_variant != 2 else Color(0.12, 0.082, 0.060)
	if str(settings.settings.get("quality_preset", "balanced")) != "potato":
		# Use a real two-plane gable rather than two intersecting boxes. This keeps
		# the roof readable from the road and gives each house a grounded silhouette
		# without adding a high-poly asset or collision complexity.
		_add_house_gabled_roof(root, roof_color)
		root.set_meta("roof_treatment", "authored_gabled_mesh")
	else:
		root.set_meta("roof_treatment", "potato_fallback_slope")
		_add_house_box(root, "LeftRoofSlope", Vector3(-0.9, 2.42, 0), Vector3(2.55, 0.42, 3.95), Color(0.14, 0.055, 0.035), Vector3(0, 0, -13))
		_add_house_box(root, "RightRoofSlope", Vector3(0.9, 2.42, 0), Vector3(2.55, 0.42, 3.95), Color(0.14, 0.055, 0.035), Vector3(0, 0, 13))
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
	# Small structural details give the facade readable construction at the
	# actual gameplay camera distance while remaining part of the static batch.
	_add_house_box(root, "RoofEaveFront", Vector3(0, 2.12, -1.86), Vector3(4.62, 0.16, 0.18), roof_color)
	_add_house_box(root, "RoofEaveRear", Vector3(0, 2.12, 1.86), Vector3(4.62, 0.16, 0.18), roof_color)
	_add_house_box(root, "RoofRidgeCap", Vector3(0, 3.05, 0), Vector3(0.26, 0.16, 3.72), roof_color)
	_add_house_box(root, "UpperGableWindow", Vector3(0, 2.62, -1.80), Vector3(0.42, 0.28, 0.055), Color(0.92, 0.50, 0.17))
	_add_house_box(root, "UpperGableWindowFrame", Vector3(0, 2.62, -1.84), Vector3(0.08, 0.30, 0.07), timber)
	_add_house_box(root, "DoorFrameLeft", Vector3(-0.48, 0.79, -1.80), Vector3(0.10, 1.42, 0.14), timber)
	_add_house_box(root, "DoorFrameRight", Vector3(0.48, 0.79, -1.80), Vector3(0.10, 1.42, 0.14), timber)
	_add_house_box(root, "DoorLatch", Vector3(0.24, 0.80, -1.88), Vector3(0.08, 0.10, 0.035), Color(0.48, 0.38, 0.20))
	for x in [-1.42, 1.42]:
		var mullion_x: float = x * 0.62
		_add_house_box(root, "WindowMullionVertical", Vector3(mullion_x, 1.42, -1.85), Vector3(0.045, 0.40, 0.07), timber)
		_add_house_box(root, "WindowMullionHorizontal", Vector3(mullion_x, 1.42, -1.85), Vector3(0.54, 0.045, 0.07), timber)
	if str(settings.settings.get("quality_preset", "balanced")) != "potato":
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

func _add_house_gabled_roof(parent: Node3D, color: Color) -> MeshInstance3D:
	var width := 4.78
	var length := 4.10
	var eave_y := 2.08
	var ridge_y := 3.16
	var half_length := length * 0.5
	var half_width := width * 0.5
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	# Front is negative Z. Winding is chosen so both sloped planes face upward.
	_append_house_quad(vertices, normals, uvs, indices,
		Vector3(-half_width, eave_y, -half_length),
		Vector3(-half_width, eave_y, half_length),
		Vector3(0.0, ridge_y, half_length),
		Vector3(0.0, ridge_y, -half_length))
	_append_house_quad(vertices, normals, uvs, indices,
		Vector3(0.0, ridge_y, -half_length),
		Vector3(0.0, ridge_y, half_length),
		Vector3(half_width, eave_y, half_length),
		Vector3(half_width, eave_y, -half_length))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var roof_mesh := ArrayMesh.new()
	roof_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var roof := MeshInstance3D.new()
	roof.name = "AuthoredGabledRoof"
	roof.mesh = roof_mesh
	roof.material_override = world_materials.get_material("roof_tiles", str(settings.settings.get("quality_preset", "balanced")), color, 0.0, false)
	roof.set_meta("world_visual_role", "gabled_roof")
	parent.add_child(roof)
	return roof

func _append_house_quad(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var base := vertices.size()
	var normal := (b - a).cross(c - a).normalized()
	for point in [a, b, c, d]:
		vertices.append(point)
		normals.append(normal)
		uvs.append(Vector2(point.x * 0.32, point.z * 0.32))
	indices.append(base)
	indices.append(base + 1)
	indices.append(base + 2)
	indices.append(base)
	indices.append(base + 2)
	indices.append(base + 3)

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
	if key in ["forest_tree", "forest_tree_variant"]:
		# Loose authored trees used to bypass the environment batch and leave a
		# full imported mesh in the active scene. Queue them through the same
		# route-safe batch path as tree walls so the visual remains intact while
		# draw/triangle cost stays bounded.
		var before_count := tree_batch_data.size()
		_make_tree(pos)
		if tree_batch_data.size() > before_count:
			var item: Dictionary = tree_batch_data[tree_batch_data.size() - 1]
			item["asset_role"] = key
			item["asset_scale"] = scale_value
			item["asset_yaw"] = deg_to_rad(yaw)
			tree_batch_data[tree_batch_data.size() - 1] = item
		return null
	if key == "forest_rock":
		if _is_river_excluded(pos, 0.75) or _is_first_route_clearance(pos, 0.55):
			return null
		var rock := _make_role_visual("forest_rock", "environment", scale_value)
		if rock != null:
			rock.position = river_safe_position(pos, 0.75)
			rock.rotation_degrees.y = yaw
			zone_root.add_child(rock)
			return rock
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
	_make_world_prop_anchor("notice_board", "notice_board", pos, "evidence_report")

func _make_route_markers() -> void:
	for pos in [Vector3(-0.9, 0, -4.5), Vector3(0.95, 0, -8.2), Vector3(-0.7, 0, -11.4)]:
		_make_prop_box("RoadCandle", pos + Vector3(0, 0.18, 0), Vector3(0.14, 0.36, 0.14), Color(0.20, 0.11, 0.05))
		var flame = MeshInstance3D.new()
		var flame_mesh := SphereMesh.new()
		flame_mesh.radial_segments = 5
		flame_mesh.rings = 3
		flame.mesh = flame_mesh
		flame.scale = Vector3(0.12, 0.18, 0.12)
		flame.position = pos + Vector3(0, 0.48, 0)
		flame.material_override = _emissive_mat(Color(1.0, 0.48, 0.16), 1.1)
		flame.set_meta("world_prop_kind", "candle")
		flame.set_meta("world_prop_id", "road_candle")
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
	_make_world_prop_anchor("shrine", "shrine", pos, "crow_shrine_state")

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
	_make_world_prop_anchor("forge", "forge", pos + Vector3(1.5, 0.55, -1.1), "iron_fate")

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
	var prop_spec := _world_prop_spec(id)
	if not prop_spec.is_empty():
		area.set_meta("world_prop_id", id)
		var prop_component := InteractiveWorldProp.new()
		prop_component.name = "InteractiveWorldProp"
		area.add_child(prop_component)
		prop_component.configure(id, str(prop_spec.get("kind", "generic")), str(prop_spec.get("state_key", "")), "idle", story_state)
	var role = _role_for_interactable(id)
	var mapped = _make_role_visual(role, "characters", Vector3.ONE)
	if mapped != null:
		area.add_child(mapped)
		_configure_npc_animation(mapped, id)
	elif id == "vargan_ledger_choice":
		_make_ledger_interaction_visual(area, scale_override)
	elif id == "post_victory_token":
		_make_token_interaction_visual(area, scale_override)
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
		label.font_size = 14 if type == "zone" else 16
		label.pixel_size = 0.0038 if type == "zone" else 0.0048
		label.modulate = Color(0.84, 0.78, 0.62)
		label.outline_size = 3
		label.outline_modulate = Color(0.02, 0.018, 0.015)
		label.visible = false
		area.add_child(label)
	if type == "dialogue" and id != "notice_board" and has_character_role:
		var ambient = NpcAmbient.new()
		ambient.setup(id, player)
		area.add_child(ambient)
	_connect_interactable(area)
	return area

func _make_ledger_interaction_visual(area: Node3D, scale_override: Vector3) -> void:
	var ledger_root := Node3D.new()
	ledger_root.name = "SealedCommandLedgerVisual"
	ledger_root.scale = scale_override
	area.add_child(ledger_root)
	var cover := MeshInstance3D.new()
	cover.name = "LedgerLeatherCover"
	var cover_mesh := BoxMesh.new()
	cover_mesh.size = Vector3(0.82, 0.11, 0.56)
	cover.mesh = cover_mesh
	cover.position = Vector3(0.0, 0.17, 0.0)
	cover.rotation_degrees = Vector3(0.0, 0.0, -7.0)
	cover.material_override = _mat(Color(0.16, 0.075, 0.040))
	ledger_root.add_child(cover)
	var pages := MeshInstance3D.new()
	pages.name = "LedgerPages"
	var pages_mesh := BoxMesh.new()
	pages_mesh.size = Vector3(0.68, 0.065, 0.46)
	pages.mesh = pages_mesh
	pages.position = Vector3(0.0, 0.232, 0.0)
	pages.rotation_degrees = Vector3(0.0, 0.0, -7.0)
	pages.material_override = _mat(Color(0.58, 0.48, 0.31))
	ledger_root.add_child(pages)
	var seal := MeshInstance3D.new()
	seal.name = "LedgerWaxSeal"
	var seal_mesh := CylinderMesh.new()
	seal_mesh.top_radius = 0.075
	seal_mesh.bottom_radius = 0.075
	seal_mesh.height = 0.025
	seal_mesh.radial_segments = 10
	seal.mesh = seal_mesh
	seal.position = Vector3(0.18, 0.285, -0.04)
	seal.rotation_degrees = Vector3(90.0, 0.0, -7.0)
	seal.material_override = _mat(Color(0.43, 0.075, 0.045))
	ledger_root.add_child(seal)

func _make_token_interaction_visual(area: Node3D, scale_override: Vector3) -> void:
	var token_root := Node3D.new()
	token_root.name = "OrenTokenAndVarganWireVisual"
	token_root.scale = scale_override
	area.add_child(token_root)
	var token := MeshInstance3D.new()
	token.name = "OrenCompleteToken"
	var token_mesh := BoxMesh.new()
	token_mesh.size = Vector3(0.28, 0.07, 0.38)
	token.mesh = token_mesh
	token.position = Vector3(-0.12, 0.12, 0.0)
	token.rotation_degrees = Vector3(0.0, -24.0, 8.0)
	token.material_override = _mat(Color(0.48, 0.30, 0.12))
	token_root.add_child(token)
	var wire := MeshInstance3D.new()
	wire.name = "VarganBindingWire"
	var wire_mesh := TorusMesh.new()
	wire_mesh.inner_radius = 0.07
	wire_mesh.outer_radius = 0.09
	wire_mesh.rings = 8
	wire_mesh.ring_segments = 6
	wire.mesh = wire_mesh
	wire.position = Vector3(0.12, 0.15, 0.05)
	wire.rotation_degrees = Vector3(78.0, 12.0, 14.0)
	var wire_material := _mat(Color(0.13, 0.13, 0.12))
	wire_material.metallic = 0.55
	wire_material.roughness = 0.48
	wire.material_override = wire_material
	token_root.add_child(wire)

func _make_village_place(id: String, type: String, prompt: String, pos: Vector3, size: Vector3, color: Color):
	pos = river_safe_position(pos,maxf(size.z*0.5,0.8))
	var area = Interactable.new()
	area.setup(id,type,prompt)
	area.position = pos
	area.build_collision(1.35)
	zone_root.add_child(area)
	var prop_spec := _world_prop_spec(id)
	if not prop_spec.is_empty():
		area.set_meta("world_prop_id", id)
		var prop_component := InteractiveWorldProp.new()
		prop_component.name = "InteractiveWorldProp"
		area.add_child(prop_component)
		prop_component.configure(id, str(prop_spec.get("kind", "generic")), str(prop_spec.get("state_key", "")), "idle", story_state)
	var table := MeshInstance3D.new()
	table.name = "%s_VisibleProp" % id
	var mesh := BoxMesh.new()
	if type == "minigame":
		# A board-game table has visible legs, a thin worn top, two seats, and an
		# opponent. It should read as a social place before the overlay opens.
		mesh.size = Vector3(size.x, 0.16, size.z)
		table.position.y = size.y
		table.material_override = _mat(color.darkened(0.10))
		for x in [-size.x * 0.38, size.x * 0.38]:
			for z in [-size.z * 0.34, size.z * 0.34]:
				var leg := MeshInstance3D.new()
				leg.name = "%s_TableLeg" % id
				var leg_mesh := BoxMesh.new()
				leg_mesh.size = Vector3(0.14, size.y * 0.92, 0.14)
				leg.mesh = leg_mesh
				leg.position = Vector3(x, size.y * 0.46, z)
				leg.material_override = _mat(color.darkened(0.20))
				area.add_child(leg)
		_make_board_game_staging(area, id, size)
	elif type == "vendor":
		# A shop needs to read as a place before the prompt appears: counter,
		# canopy, stock crates, and a warm local light. The transaction remains
		# owned by VendorService so the dressing cannot change save state.
		mesh.size = Vector3(size.x, 0.16, size.z)
		table.position.y = size.y
		table.material_override = _mat(color.darkened(0.12))
		var canopy := MeshInstance3D.new()
		canopy.name = "%s_Canopy" % id
		var canopy_mesh := BoxMesh.new()
		canopy_mesh.size = Vector3(size.x + 0.32, 0.12, size.z + 0.28)
		canopy.mesh = canopy_mesh
		canopy.position = Vector3(0.0, size.y + 1.55, 0.0)
		canopy.material_override = _mat(color.lightened(0.12))
		area.add_child(canopy)
		for x in [-size.x * 0.42, size.x * 0.42]:
			var post := MeshInstance3D.new()
			post.name = "%s_CanopyPost" % id
			var post_mesh := BoxMesh.new()
			post_mesh.size = Vector3(0.10, 1.55, 0.10)
			post.mesh = post_mesh
			post.position = Vector3(x, size.y * 0.78, 0.0)
			post.material_override = _mat(color.darkened(0.25))
			area.add_child(post)
		for x in [-size.x * 0.30, size.x * 0.30]:
			var crate := MeshInstance3D.new()
			crate.name = "%s_StockCrate" % id
			var crate_mesh := BoxMesh.new()
			crate_mesh.size = Vector3(0.36, 0.30, 0.36)
			crate.mesh = crate_mesh
			crate.position = Vector3(x, 0.18, size.z * 0.58)
			crate.material_override = _mat(color.darkened(0.28))
			area.add_child(crate)
		_make_light("%s_ShopGlow" % id, pos + Vector3(0, 1.25, 0), color.lightened(0.18), 0.7)
	else:
		mesh.size = size
		table.position.y = size.y * 0.5
		table.material_override = _mat(color)
	table.mesh = mesh
	area.add_child(table)
	var label := Label3D.new()
	label.name = "InteractionWorldLabel"
	label.text = prompt
	label.position = Vector3(0,size.y+0.62,0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 14
	label.pixel_size = 0.0048
	label.modulate = Color(0.84,0.78,0.62)
	label.visible = false
	area.add_child(label)
	_connect_interactable(area)
	return area

func _make_board_game_staging(area: Node3D, id: String, size: Vector3) -> void:
	var board_size := Vector2(size.x * 0.70, size.z * 0.68)
	var board_back := MeshInstance3D.new()
	board_back.name = "%s_CarvedBoard" % id
	var board_mesh := BoxMesh.new()
	board_mesh.size = Vector3(board_size.x + 0.18, 0.055, board_size.y + 0.18)
	board_back.mesh = board_mesh
	board_back.position = Vector3(0.0, size.y + 0.10, 0.0)
	board_back.material_override = _mat(Color(0.20, 0.11, 0.055))
	area.add_child(board_back)
	var columns := 3 if id == "common_table" else 6
	var rows := columns
	for row in range(rows):
		for column in range(columns):
			var square := MeshInstance3D.new()
			square.name = "%s_BoardSquare_%d_%d" % [id, row, column]
			var square_mesh := BoxMesh.new()
			square_mesh.size = Vector3(board_size.x / columns - 0.018, 0.018, board_size.y / rows - 0.018)
			square.mesh = square_mesh
			var x := -board_size.x * 0.5 + board_size.x * (float(column) + 0.5) / float(columns)
			var z := -board_size.y * 0.5 + board_size.y * (float(row) + 0.5) / float(rows)
			square.position = Vector3(x, size.y + 0.14, z)
			square.material_override = _mat(Color(0.38, 0.24, 0.12) if (row + column) % 2 == 0 else Color(0.16, 0.095, 0.045))
			area.add_child(square)
			if id == "common_table" and (row + column) % 2 == 1 and row != 1:
				var mark := MeshInstance3D.new()
				mark.name = "%s_CarvedMark_%d_%d" % [id, row, column]
				var mark_mesh := CylinderMesh.new()
				mark_mesh.top_radius = 0.075
				mark_mesh.bottom_radius = 0.075
				mark_mesh.height = 0.035
				mark_mesh.radial_segments = 10
				mark.mesh = mark_mesh
				mark.position = Vector3(x, size.y + 0.18, z)
				mark.material_override = _mat(Color(0.72, 0.48, 0.20) if row < 2 else Color(0.72, 0.68, 0.48))
				area.add_child(mark)
	_make_board_game_chair(area, Vector3(0.0, 0.0, size.z * 0.90), PI)
	_make_board_game_chair(area, Vector3(0.0, 0.0, -size.z * 0.90), 0.0)
	var opponent_role := "rook_smuggler" if id == "common_table" else "blacksmith_tor"
	var opponent_id := "board_rook" if id == "common_table" else "board_tor"
	var opponent := _make_role_visual(opponent_role, "characters", Vector3.ONE)
	if opponent == null:
		return
	opponent.name = "%s_Opponent" % id
	opponent.position = Vector3(0.0, 0.0, size.z * 0.92)
	opponent.rotation_degrees.y = 180.0
	area.add_child(opponent)
	CharacterPresentation.apply_npc(opponent, opponent_id)
	_configure_npc_animation(opponent, "board_rook" if id == "common_table" else "board_tor")
	var gesture := Node3D.new()
	gesture.name = "BoardGameBeckoningGesture"
	gesture.position = Vector3(0.34, 1.18, -0.28)
	var palm := MeshInstance3D.new()
	var palm_mesh := BoxMesh.new()
	palm_mesh.size = Vector3(0.16, 0.09, 0.08)
	palm.mesh = palm_mesh
	palm.material_override = _mat(Color(0.58, 0.39, 0.25))
	gesture.add_child(palm)
	var finger := MeshInstance3D.new()
	var finger_mesh := BoxMesh.new()
	finger_mesh.size = Vector3(0.18, 0.045, 0.045)
	finger.mesh = finger_mesh
	finger.position = Vector3(0.08, 0.04, -0.01)
	finger.rotation_degrees.z = -18.0
	finger.material_override = palm.material_override
	gesture.add_child(finger)
	opponent.add_child(gesture)
	var gesture_controller := BoardGameOpponent.new()
	gesture_controller.name = "BoardGameOpponentController"
	opponent.add_child(gesture_controller)
	gesture_controller.configure(player, gesture)
	var ambient := NpcAmbient.new()
	ambient.setup("rook" if id == "common_table" else "blacksmith_tor", player)
	opponent.add_child(ambient)

func _make_board_game_chair(area: Node3D, position: Vector3, yaw: float) -> void:
	var chair := Node3D.new()
	chair.name = "BoardGameChair_North" if position.z < 0.0 else "BoardGameChair_South"
	chair.position = position
	chair.rotation.y = yaw
	area.add_child(chair)
	var seat := MeshInstance3D.new()
	var seat_mesh := BoxMesh.new()
	seat_mesh.size = Vector3(0.90, 0.14, 0.82)
	seat.mesh = seat_mesh
	seat.position.y = 0.62
	seat.material_override = _mat(Color(0.20, 0.12, 0.065))
	chair.add_child(seat)
	var back := MeshInstance3D.new()
	var back_mesh := BoxMesh.new()
	back_mesh.size = Vector3(0.90, 0.90, 0.12)
	back.mesh = back_mesh
	back.position = Vector3(0.0, 1.02, 0.32)
	back.material_override = seat.material_override
	chair.add_child(back)

func _world_prop_spec(id: String) -> Dictionary:
	return {
		"notice_board": {"kind": "notice_board", "state_key": "evidence_report"},
		"village_well": {"kind": "well", "state_key": "greyfen_well_state"},
		"forge_corner": {"kind": "forge", "state_key": "iron_fate"},
		"shrine_prayer": {"kind": "shrine", "state_key": "shrine_prayer_state"},
		"common_table": {"kind": "table", "state_key": "common_table_state"},
		"barrel_board": {"kind": "table", "state_key": "barrel_board_state"},
		"vargan_ledger_choice": {"kind": "ledger", "state_key": "vargan_ledger_state"},
	}.get(id, {})

func _configure_npc_animation(mapped: Node3D, id: String) -> void:
	var clips := {
		"idle": "Idle", "walk": "Walk", "walk_back": "Walk",
		"strafe": "Walk", "run": "Sprint", "work": "Interact",
		"dialogue": "Idle_Talking", "hit": "Hit_Chest", "death": "Death01"
	}
	var family := str(mapped.get_meta("character_animation_family", "")).to_lower()
	if family.contains("warrior"):
		clips.merge({"run": "Run", "work": "Idle_Weapon", "dialogue": "Idle", "hit": "RecieveHit", "death": "Death"}, true)
	elif family.contains("cleric"):
		clips.merge({"run": "Run", "work": "Idle_Weapon", "dialogue": "Idle", "hit": "RecieveHit", "death": "Death"}, true)
	elif family.contains("rogue"):
		clips.merge({"run": "Run", "work": "Idle", "dialogue": "Idle", "hit": "RecieveHit", "death": "Death"}, true)
	elif family.contains("monk"):
		clips.merge({"run": "Run", "work": "Idle", "dialogue": "Idle", "hit": "RecieveHit", "death": "Death"}, true)
	if id == "sister_anwen":
		clips["idle"] = "Idle_Talking"
		# The shared female base does not ship a death clip. Anwen is a protected
		# story NPC, so keep the real hit reaction as the safe non-lethal fallback
		# instead of claiming an unavailable death animation in the contract.
		clips["hit"] = "Hit_Chest"
		clips.erase("death")
	elif id == "rook":
		clips["idle"] = "Idle_Talking"
		clips["hit"] = "Hit_Head"
	elif id in ["board_rook", "board_tor"]:
		clips["idle"] = "Sitting_Idle"
		clips["dialogue"] = "Sitting_Talking"
		clips["work"] = "Sitting_Talking"
	var driver = CharacterAnimationDriver.new()
	driver.name = "CharacterAnimationDriver"
	mapped.add_child(driver)
	driver.configure(mapped, clips)
	# Interior archive actors are few and remain in view during the record-hall
	# presentation. Let Godot's normal animation callback distribute their small
	# updates per frame; manual 15 Hz advances create a visible CPU spike every
	# fourth frame on the Compatibility renderer. The player and combat actors
	# retain their explicit gameplay rates.
	var npc_animation_rate := 30.0
	if current_zone_id in ["record_hall", "undercroft"]:
		# Let the archive's small cast use the imported idle callback. The manual
		# timer advances several skin poses together and creates a larger periodic
		# Compatibility spike than the normal callback path.
		npc_animation_rate = 0.0
	elif current_zone_id in ["vargan_approach", "vargan_court", "assembly"]:
		npc_animation_rate = 20.0
	driver.set_update_rate_hz(npc_animation_rate)

func _stage_dialogue_moment(area) -> void:
	if player == null or area == null or not (area is Node3D):
		return
	var npc = area as Node3D
	dialogue_focus_actor = npc
	if area.interaction_id == "sister_anwen":
		npc.set_meta("dialogue_facing_lock", true)
		var anwen_driver = npc.find_child("CharacterAnimationDriver", true, false)
		if anwen_driver != null and anwen_driver.has_method("set_dialogue_pose"):
			anwen_driver.set_dialogue_pose(true)
	if player.has_method("face_target"):
		player.face_target(npc.global_position)
	_face_npc_toward_player(npc)
	# Prevent close-range interaction from placing both bodies in the same
	# screen position. A short, validated conversational step gives the camera
	# two readable silhouettes without changing quest or interaction range.
	var separation: float = player.global_position.distance_to(npc.global_position)
	if separation < 1.35:
		var staged_position: Vector3 = npc.global_position - npc.global_basis.z.normalized() * 1.75
		if has_method("validate_walkable_position"):
			staged_position = validate_walkable_position(staged_position)
		player.global_position = staged_position + Vector3.UP
		player.velocity = Vector3.ZERO
		if player.has_method("face_target"):
			player.face_target(npc.global_position)
		_face_npc_toward_player(npc)
	if camera_rig != null and camera_rig.has_method("frame_dialogue_target"):
		camera_rig.frame_dialogue_target(npc)

func _on_dialogue_page_changed(_speaker: String, _speaker_id: String, _page_index: int, _total_pages: int) -> void:
	# Dialogue is paused, so regular actor/camera processing is suspended. Reapply
	# the same face-to-face contract whenever a new speaker turn is rendered so
	# a multi-speaker exchange cannot drift after a page change or UI focus event.
	if player == null or dialogue_focus_actor == null or not is_instance_valid(dialogue_focus_actor):
		return
	_face_npc_toward_player(dialogue_focus_actor)
	if player.has_method("face_target"):
		player.face_target(dialogue_focus_actor.global_position)
	if camera_rig != null and camera_rig.has_method("frame_dialogue_target"):
		camera_rig.frame_dialogue_target(dialogue_focus_actor)

func _face_npc_toward_player(npc: Node3D) -> void:
	if npc == null or player == null:
		return
	var to_player: Vector3 = player.global_position - npc.global_position
	to_player.y = 0.0
	if to_player.length_squared() <= 0.01:
		return
	# All route-visible humanoids share the actor-facing -Z contract.
	npc.rotation.y = atan2(-to_player.x, -to_player.z)

func _release_dialogue_facing() -> void:
	audio.stop_voice()
	dialogue_focus_actor = null
	if zone_root == null:
		return
	var anwen = zone_root.find_child("sister_anwen", true, false)
	if anwen != null:
		anwen.set_meta("dialogue_facing_lock", false)
		var anwen_driver = anwen.find_child("CharacterAnimationDriver", true, false)
		if anwen_driver != null and anwen_driver.has_method("set_dialogue_pose"):
			anwen_driver.set_dialogue_pose(false)
	if pending_anwen_relocation:
		pending_anwen_relocation = false
		_relocate_anwen_to_cemetery()

func _make_gate_marker(parent: Node3D, color: Color, scale_override: Vector3) -> void:
	var pillar_material := _mat(color.lightened(0.10))
	for side in [-1.0, 1.0]:
		var pillar := MeshInstance3D.new()
		var pillar_mesh := BoxMesh.new()
		pillar_mesh.size = Vector3(0.30, 1.72, 0.26)
		pillar.mesh = pillar_mesh
		pillar.position = Vector3(side * 0.86 * scale_override.x, 0.86 * scale_override.y, 0)
		pillar.scale = Vector3(scale_override.x, scale_override.y, scale_override.z)
		pillar.material_override = pillar_material
		parent.add_child(pillar)
	var lintel := MeshInstance3D.new()
	var lintel_mesh := BoxMesh.new()
	lintel_mesh.size = Vector3(2.05, 0.24, 0.28)
	lintel.mesh = lintel_mesh
	lintel.position.y = 1.72 * scale_override.y
	lintel.scale = Vector3(scale_override.x, scale_override.y, scale_override.z)
	lintel.material_override = _mat(color.lightened(0.18))
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
	# The trigger remains owned by Interactable; only its old marker geometry is
	# replaced so route logic and save compatibility stay unchanged.
	for child in area.get_children():
		if child is MeshInstance3D:
			child.visible = false
	if seamless_world != null and seamless_world.should_suppress_exterior_gate(current_zone_id, zone_target):
		# Exterior travel is now driven by the sector boundary, not an in-world
		# portal. Keep the Area3D as a named migration marker for old saves, but
		# remove its focus/collision path so it cannot steal interaction priority.
		area.set_meta("seamless_exterior_gate", true)
		area.monitoring = false
		area.monitorable = false
		return area
	if seamless_world != null and seamless_world.should_use_physical_door(current_zone_id, zone_target):
		area.set_meta("interior_door", true)
		_add_physical_door_visual(area, zone_target)
		return area
	var portal := OathGatePortal.new()
	portal.name = "OathGatePortal"
	portal.configure(zone_target, "gate_%s" % zone_target)
	if portal.has_method("bind_audio"):
		portal.bind_audio(audio)
	area.add_child(portal)
	if zone_streaming != null and portal.has_method("bind_streaming"):
		portal.bind_streaming(zone_streaming)
		if zone_streaming.has_method("is_embedded_destination") and zone_streaming.is_embedded_destination(zone_target):
			portal.set_ready()
	else:
		portal.set_state(OathGatePortal.PortalState.READY)
	return area

func _add_physical_door_visual(area: Node3D, zone_target: String) -> void:
	var frame_material := _mat(Color(0.16, 0.13, 0.10))
	var door_material := _mat(Color(0.08, 0.055, 0.040))
	var frame := MeshInstance3D.new()
	frame.name = "InteriorDoorFrame"
	var frame_mesh := BoxMesh.new()
	frame_mesh.size = Vector3(2.5, 3.0, 0.24)
	frame.mesh = frame_mesh
	frame.position = Vector3(0, 1.5, 0)
	frame.material_override = frame_material
	area.add_child(frame)
	var door := MeshInstance3D.new()
	door.name = "InteriorDoor"
	var door_mesh := BoxMesh.new()
	door_mesh.size = Vector3(1.65, 2.45, 0.12)
	door.mesh = door_mesh
	door.position = Vector3(0, 1.25, -0.15)
	door.material_override = door_material
	area.add_child(door)
	var label := Label3D.new()
	label.name = "InteriorDoorDestination"
	label.text = _zone_display_name(zone_target)
	label.position = Vector3(0, 2.2, -0.24)
	label.font_size = 22
	label.modulate = Color(0.82, 0.72, 0.53, 0.85)
	label.visible = false
	area.add_child(label)

func _make_blocked_gate(prompt: String, pos: Vector3, message: String):
	var area = _make_named_interactable("blocked_ruins", "blocked_zone", prompt, pos, Color(0.20, 0.16, 0.11), Vector3(0.8, 0.8, 0.8))
	if area == null:
		return null
	area.set_meta("message", message)
	return area

func _connect_interactable(area) -> void:
	if area is Area3D and area not in interaction_area_cache:
		interaction_area_cache.append(area as Area3D)
	area.body_entered.connect(func(body: Node):
		if body == player and not bool(area.get_meta("seamless_exterior_gate", false)) and area not in interaction_candidates:
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
	_refresh_interaction_candidates()
	for candidate in interaction_candidates.duplicate():
		if candidate != null and is_instance_valid(candidate) and bool(candidate.get_meta("seamless_exterior_gate", false)):
			interaction_candidates.erase(candidate)
	var camera: Camera3D = get_viewport().get_camera_3d()
	var best = zone_runtime_coordinator.choose_interaction(interaction_candidates, player, camera, Callable(self, "_interaction_target_valid")) if zone_runtime_coordinator != null else null
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

func _refresh_interaction_candidates() -> void:
	if zone_root == null or player == null:
		return
	if not interaction_area_cache_ready:
		# Build this list once per active zone. The previous implementation walked
		# the complete zone tree every 100 ms, which made Greyfen frame pacing
		# collapse even though the interaction set itself was small and stable.
		for raw_candidate in zone_root.find_children("*", "Area3D", true, false):
			var discovered := raw_candidate as Area3D
			if discovered != null and discovered.has_method("get_context_prompt") and discovered not in interaction_area_cache:
				interaction_area_cache.append(discovered)
		interaction_area_cache_ready = true
	# Area signals are authoritative during ordinary movement, but can be missed
	# when a save, spawn, or zone arrival places Kael inside a trigger between
	# physics ticks. A small bounded scan keeps prompts deterministic without
	# walking the entire world or inventing a second focus system.
	for candidate in interaction_area_cache:
		if candidate == null or candidate.is_queued_for_deletion() or not candidate.has_method("get_context_prompt"):
			continue
		if bool(candidate.get_meta("seamless_exterior_gate", false)):
			continue
		var range_limit := 3.6 if str(candidate.get("interaction_type")) == "zone" else 2.8
		if candidate.global_position.distance_to(player.global_position) <= range_limit:
			if str(candidate.get("interaction_type")) == "zone":
				var portal := candidate.find_child("OathGatePortal", true, false) as OathGatePortal
				if portal != null and portal.state == OathGatePortal.PortalState.DORMANT:
					portal.begin_preload()
			if candidate in interaction_candidates:
				continue
			interaction_candidates.append(candidate)

func _interaction_target_valid(area: Area3D) -> bool:
	if player == null or area == null or not is_instance_valid(area):
		return false
	# Travel volumes sit inside authored gate/berm geometry. Camera rays can hit
	# that framing even while Kael is correctly standing in the gate trigger.
	if area.interaction_type == "zone":
		return player.global_position.distance_to(area.global_position) <= 3.65
	var camera := get_viewport().get_camera_3d()
	var origin: Vector3 = camera.global_position if camera != null else player.global_position + Vector3.UP
	var target_height := 0.92 if area.interaction_type in ["clue", "herb", "village_place"] else 0.5
	var target: Vector3 = area.global_position + Vector3.UP * target_height
	var direction := origin.direction_to(target)
	var forward: Vector3 = -camera.global_basis.z if camera != null else -player.global_basis.z
	if forward.dot(direction) < 0.22:
		return false
	# Ground clues are intentionally readable through low road dressing and
	# foliage. Their proximity/facing check remains strict; only the camera ray
	# is skipped because the target is below the normal eye-line.
	if area.interaction_type in ["clue", "herb", "village_place"]:
		return true
	var query := PhysicsRayQueryParameters3D.create(origin, target)
	query.exclude = [player.get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	# A named character's skinned body is the intended target, not an
	# obstruction. At conversation distance the eye-line ray naturally lands on
	# the speaker's own capsule or imported mesh. Accept only a collider that is
	# spatially bound to this interaction; unrelated scenery still blocks focus.
	var collider := hit.get("collider") as Node3D
	if collider != null:
		var current: Node = collider
		while current != null:
			if current == area or (current is Node3D and (current as Node3D).global_position.distance_to(area.global_position) <= 1.2):
				return true
			current = current.get_parent()
	return false

func _set_interactable_label_visible(area: Node, visible: bool) -> void:
	var label := area.find_child("InteractionWorldLabel", true, false) as Label3D
	if label != null:
		label.visible = visible

func _spawn_enemy(id: String, pos: Vector3) -> Node:
	if _boss_is_resolved(id):
		return null
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
	if current_zone_id == "wychwood" and id in ["ghoulkin", "wychwood_stalker", "wychwood_raider", "wychwood_brute"]:
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
	if enemy.has_signal("special_attack_resolved"):
		enemy.special_attack_resolved.connect(_on_boss_special_attack)
	if enemy.has_signal("parry_window_opened"):
		enemy.parry_window_opened.connect(_on_enemy_parry_window_opened)
	enemy.boss_phase_changed.connect(_on_boss_phase_changed)
	if bool(enemy_defs.get(id, {}).get("boss", false)):
		var boss_controller: Node = Node.new()
		boss_controller.set_script(BossEncounterScript)
		boss_controller.name = "BossEncounterController"
		enemy.add_child(boss_controller)
		var boss_definition: Dictionary = enemy_defs.get(id, {}).duplicate(true)
		if boss_defs.has(id) and typeof(boss_defs[id]) == TYPE_DICTIONARY:
			boss_definition.merge(boss_defs[id], true)
		boss_controller.call("configure", id, boss_definition, enemy, self)
		if boss_saved_states.has(id) and typeof(boss_saved_states[id]) == TYPE_DICTIONARY:
			boss_controller.call("load_state", boss_saved_states[id])
		if boss_controller.has_signal("phase_changed"):
			boss_controller.connect("phase_changed", Callable(self, "_on_boss_controller_phase_changed"))
		if boss_controller.has_signal("resolved"):
			boss_controller.connect("resolved", Callable(self, "_on_boss_resolved"))
	active_enemies.append(enemy)
	for peer in active_enemies:
		if is_instance_valid(peer) and peer.has_method("set_encounter_peers"):
			peer.set_encounter_peers(active_enemies)
	return enemy

func _boss_is_resolved(id: String) -> bool:
	if not bool(enemy_defs.get(id, {}).get("boss", false)):
		return false
	var story_resolved: String = str({
		"bell_eater": "bell_eater_defeated",
		"rootbound_colossus": "rootbound_colossus_defeated",
		"ashwing": "ashwing_defeated",
	}.get(id, ""))
	if story_resolved != "" and bool(story_state.get_flag(story_resolved, false)):
		return true
	if id == "white_hart_avatar" and bool(story_state.get_flag("final_choice_completed", false)):
		return true
	var saved: Variant = boss_saved_states.get(id, {})
	if typeof(saved) == TYPE_DICTIONARY:
		var saved_outcome := str(saved.get("outcome", ""))
		return saved_outcome in ["defeated", "release", "testimony", "witness", "mercy", "duty", "ash"]
	return false

func _ensure_bell_eater() -> void:
	if current_zone_id != "greyfen" or bool(story_state.get_flag("bell_eater_defeated", false)):
		return
	for enemy in active_enemies:
		if is_instance_valid(enemy) and str(enemy.get_meta("boss_id", "")) == "bell_eater" and not enemy.dead:
			return
	var boss := _spawn_enemy("bell_eater", Vector3(15.4, 0.8, 8.8))
	if boss != null:
		boss.name = "BellEaterEncounter"
		boss.leash_radius = 9.0
		boss.set_meta("boss_arena", "cemetery")
		_evacuate_bell_eater_bystanders()
		hud.show_status_cue("The Bell-Eater wakes", "danger")
		hud.toast("The bell rings once beneath the chapel. Something large pulls against the graves.")
		hud.set_guidance_hint("Defeat the Bell-Eater beneath the Crow Chapel.", 6.0)
		audio.play_event("boss", 0.02)

func _evacuate_bell_eater_bystanders() -> void:
	if zone_root == null:
		return
	var staging := {
		"sister_anwen": Vector3(9.2, 0.0, 5.2),
		"widow_elna": Vector3(8.6, 0.0, 6.0),
	}
	for actor_id in staging:
		var actor := zone_root.find_child(actor_id, true, false) as Node3D
		if actor == null or bool(actor.get_meta("bell_eater_evacuated", false)):
			continue
		actor.set_meta("bell_eater_evacuated", true)
		actor.set_meta("bell_eater_return_position", actor.global_position)
		actor.global_position = validate_walkable_position(staging[actor_id])
		if actor is Area3D:
			(actor as Area3D).monitoring = false
			(actor as Area3D).monitorable = false
		var driver := actor.find_child("CharacterAnimationDriver", true, false)
		if driver != null and driver.has_method("set_dialogue_pose"):
			driver.set_dialogue_pose(true)
		_face_npc_toward_player(actor)

func _restore_bell_eater_bystanders() -> void:
	if zone_root == null:
		return
	for actor_id in ["sister_anwen", "widow_elna"]:
		var actor := zone_root.find_child(actor_id, true, false) as Node3D
		if actor == null or not bool(actor.get_meta("bell_eater_evacuated", false)):
			continue
		var original: Variant = actor.get_meta("bell_eater_return_position", actor.global_position)
		if original is Vector3:
			actor.global_position = validate_walkable_position(original)
		if actor is Area3D:
			(actor as Area3D).monitoring = true
			(actor as Area3D).monitorable = true
		actor.set_meta("bell_eater_evacuated", false)
		var driver := actor.find_child("CharacterAnimationDriver", true, false)
		if driver != null and driver.has_method("set_dialogue_pose"):
			driver.set_dialogue_pose(false)

func _on_boss_controller_phase_changed(boss_id: String, phase: int) -> void:
	story_state.set_flag("boss_%s_phase" % boss_id, phase)
	if audio != null:
		audio.set_music_state("boss_%s" % boss_id)

func _on_boss_checkpoint(controller: Node) -> void:
	if controller == null:
		return
	var boss_id := str(controller.get("boss_id"))
	var state: Dictionary = controller.save_state() if controller.has_method("save_state") else {}
	boss_saved_states[boss_id] = state
	story_state.set_flag("boss_%s_checkpoint" % boss_id, int(controller.get("checkpoint")))
	# A phase boundary is an authored checkpoint. It must survive a reload even
	# when the player dies before the next ordinary autosave boundary.
	if save_manager != null and player != null and is_instance_valid(player) and not resource_shutdown_prepared:
		save_manager.checkpoint(self)

func _on_boss_resolved(boss_id: String, outcome: String) -> void:
	story_state.set_flag("boss_%s_outcome" % boss_id, outcome)
	for candidate in active_enemies:
		if not is_instance_valid(candidate) or str(candidate.enemy_id) != boss_id:
			continue
		var controller: Node = candidate.get_node_or_null("BossEncounterController")
		if controller != null and controller.has_method("save_state"):
			boss_saved_states[boss_id] = controller.save_state()
		break
	if save_manager != null and player != null and is_instance_valid(player) and not resource_shutdown_prepared:
		save_manager.checkpoint(self)

func _on_boss_peaceful_resolution(boss_id: String, outcome: String, enemy: Node) -> void:
	story_state.set_flag("boss_%s_outcome" % boss_id, outcome)
	if boss_id == "halvern_boss":
		story_state.set_flag("halvern_fate", "witness" if outcome in ["testimony", "release", "witness"] else outcome)
		if current_zone_id == "undercroft":
			quests.complete_objective("main_last_witness", "break_halvern_guard")
			hud.show_status_cue("Halvern lowers his blade", "victory")
			hud.toast("The knight will speak. The undercroft no longer needs a gravekeeper.")
			if enemy != null:
				enemy.set_encounter_active(false)
	elif boss_id == "white_hart_avatar":
		var covenant := str({"witness":"witness", "mercy":"mercy", "release":"mercy", "duty":"duty", "ash":"ash"}.get(outcome, outcome))
		story_state.set_flag("final_covenant", covenant)
		story_state.set_flag("final_choice_completed", true)
		quests.complete_objective("main_hart_remembers", "final_choice")
		if current_zone_id == "hart_glade":
			hud.show_status_cue("The Hart accepts the oath", "victory")
			hud.toast("The road remembers %s." % covenant.capitalize())
			if enemy != null:
				enemy.set_encounter_active(false)


func _on_boss_phase_changed(enemy: Node, phase: int) -> void:
	if enemy == null or not is_instance_valid(enemy) or not bool(enemy.get("is_boss")):
		return
	var cue := "The arena shifts beneath the witness."
	if enemy.enemy_id == "white_hart_avatar":
		cue = "The Hart tears roots from the old road." if phase == 2 else "The covenant is breaking."
	elif enemy.enemy_id == "bell_eater":
		cue = "The bell harness splits. The dead answer from below."
	elif enemy.enemy_id == "rootbound_colossus":
		cue = "The roots tear open around its heart."
	elif enemy.enemy_id == "ashwing":
		cue = "Ashwing breaks from the mill roof."
	elif enemy.enemy_id == "halvern_boss":
		cue = "Halvern stops defending the old command."
	hud.show_status_cue("%s — Phase %d" % [enemy.display_name, phase], "danger")
	hud.toast(cue)
	audio.set_music_state("boss_%s" % str(enemy.enemy_id))
	audio.play_event("reveal" if phase == 2 else "boss", 0.025)
	if world_vfx != null and is_instance_valid(world_vfx):
		world_vfx.pulse_interaction(enemy.global_position)
		CombatFeedback.impact_burst(zone_root, enemy.global_position + Vector3.UP, true, Color(0.58, 0.88, 0.72))

func _on_boss_special_attack(enemy: Node, attack_id: String, contact_position: Vector3, radius: float, damage: float, parried: bool) -> void:
	if enemy == null or not is_instance_valid(enemy) or not bool(enemy.get("is_boss")):
		return
	if zone_root != null:
		var attack_direction: Vector3 = -enemy.global_transform.basis.z
		CombatFeedback.boss_attack_release(zone_root, contact_position, attack_direction, attack_id, radius, parried)
	var cue: String = str({
		"bell_shockwave": "Bell shockwave",
		"grave_slam": "Grave slam",
		"ghoulkin_call": "The graves answer",
		"root_lanes": "Root lanes split the clearing",
		"ground_rupture": "The ground remembers the rupture",
		"heart_stagger": "The oathwood heart is exposed",
		"wing_blast": "Ashwing's wings break the air",
		"ash_breath": "Ash breath fills the mill",
		"swoop": "Ashwing drops from the smoke",
		"parry_test": "Halvern tests the guard",
		"counter_lunge": "Halvern answers the opening",
		"memory_echo": "The Hart returns a memory",
		"antler_sweep": "The Hart sweeps the old road",
		"road_reopening": "The road opens beneath the witness",
	}.get(attack_id, "The arena answers"))
	hud.show_status_cue(cue, "danger" if not parried else "parry")
	audio.play_event_limited("parry" if parried else "boss", 0.18, 0.025)
	if attack_id == "ghoulkin_call" and not bool(enemy.get_meta("called_ghoulkin", false)):
		enemy.set_meta("called_ghoulkin", true)
		var call_position: Vector3 = enemy.global_position + Vector3(2.2, 0.8, 1.4)
		var called := _spawn_enemy("ghoulkin", call_position)
		if called != null:
			called.set_meta("bell_called_ghoulkin", true)
			called.leash_radius = 8.0
			hud.toast("A Ghoulkin claws up through the bell's shadow.")

func _activate_wychwood_wave(ids: Array, cue: String) -> void:
	for enemy in active_enemies:
		if enemy != null and not enemy.dead and not enemy.is_encounter_active() and enemy.enemy_id in ids:
			enemy.set_encounter_active(true)
			break
	if hud != null:
		hud.toast(cue)
	if audio != null:
		audio.play_event("reveal", 0.02)

func _has_active_encounter_enemy() -> bool:
	for enemy in active_enemies:
		if enemy != null and is_instance_valid(enemy) and not enemy.dead and enemy.is_encounter_active():
			return true
	return false

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
	# Gate and bridge corridors are reserved before scenery is authored. Keep the
	# original request out of those volumes instead of nudging it back into the
	# player route with _route_safe_position().
	if spatial_service != null and spatial_service.is_reserved(pos, 1.35):
		return
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
	var tree_role := "forest_tree"
	# Keep most trees on the primary source, but reserve a small deterministic
	# share for a second silhouette so the forest reads as varied rather than
	# as one repeated wall. Both roles use the same licensed nature pack.
	var variant_selector := int(absf(pos.x * 17.0 + pos.z * 31.0))
	if variant_selector % 4 == 0:
		tree_role = "forest_tree_variant"
	tree_batch_data.append({
		"trunk": Transform3D(Basis.IDENTITY, pos + Vector3(0, 0.9, 0)),
		"crown": Transform3D(Basis.from_euler(Vector3(0, yaw, 0)).scaled(Vector3(radius, height, radius)), pos + Vector3(0, 2.35, 0)),
		"asset_position": pos,
		"asset_scale": Vector3(radius * 0.88, height * 0.38, radius * 0.88),
		"asset_yaw": yaw,
		"asset_role": tree_role,
		"color": Color(0.055, 0.18, 0.085).lerp(Color(0.13, 0.24, 0.11), randf())
	})
	if tree_collision_body == null:
		tree_collision_body = StaticBody3D.new()
		tree_collision_body.name = "BatchedTreeCollisions"
		zone_root.add_child(tree_collision_body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.58, 3.6, 0.58)
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
			# This node is a build-only transform carrier; the MultiMesh now owns
			# the rendered instance. Free it immediately so it cannot outlive the
			# zone root as an orphaned renderer instance during teardown.
			marker.free()
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
			# Like terrain markers, these nodes have no runtime purpose after the
			# batched transform has been copied.
			marker.free()
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
	if not tree_batch_data.is_empty() and not _flush_authored_tree_assets():
		var trunk_mesh := BoxMesh.new()
		trunk_mesh.size = Vector3(0.42, 1.8, 0.42)
		var trunks := _make_multimesh_batch("TreeTrunkBatch", trunk_mesh, tree_batch_data.size(), world_materials.get_material("timber", str(settings.settings.get("quality_preset", "balanced")), Color(0.42, 0.30, 0.20), 0.0, false))
		var crown_mesh := SphereMesh.new()
		crown_mesh.radius = 0.72
		crown_mesh.height = 1.62
		crown_mesh.radial_segments = 8
		crown_mesh.rings = 4
		var crown_material := _mat(Color.WHITE)
		crown_material.vertex_color_use_as_albedo = true
		var crowns := _make_multimesh_batch("TreeCrownBatch", crown_mesh, tree_batch_data.size(), crown_material, true)
		for i in range(tree_batch_data.size()):
			trunks.multimesh.set_instance_transform(i, tree_batch_data[i].trunk)
			var crown_transform: Transform3D = tree_batch_data[i].crown
			crown_transform.basis = crown_transform.basis.scaled(Vector3(1.10, 0.72, 1.10))
			crowns.multimesh.set_instance_transform(i, crown_transform)
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

func _flush_authored_tree_assets() -> bool:
	# Use the selected Quaternius tree mesh for Balanced/Quality. The old
	# primitive trunk+sphere fallback remains available for Potato and for
	# import failures, so the visual upgrade never removes the route.
	if asset_helper == null or settings == null:
		return false
	if str(settings.settings.get("quality_preset", "balanced")) == "potato":
		return false
	var grouped_items: Dictionary = {}
	for item in tree_batch_data:
		var role := str(item.get("asset_role", "forest_tree"))
		if not grouped_items.has(role):
			grouped_items[role] = []
		grouped_items[role].append(item)
	if grouped_items.is_empty():
		return false
	var created_batch := false
	for role in grouped_items.keys():
		var role_items: Array = grouped_items[role]
		if role_items.is_empty():
			continue
		var preview := _make_role_visual(str(role), "environment", Vector3.ONE)
		if preview == null:
			return false
		var mesh_nodes := preview.find_children("*", "MeshInstance3D", true, false)
		var source_mesh: Mesh = null
		var source_material: Material = null
		for raw_node in mesh_nodes:
			var source := raw_node as MeshInstance3D
			if source == null or source.mesh == null:
				continue
			source_mesh = source.mesh
			source_material = source.material_override
			if source_material == null and source_mesh.get_surface_count() > 0:
				source_material = source_mesh.surface_get_material(0)
			break
		preview.free()
		if source_mesh == null:
			return false
		if source_material == null:
			source_material = world_materials.get_material("forest_ground", str(settings.settings.get("quality_preset", "balanced")), Color(0.08, 0.18, 0.09), 0.0, false)
		var trees := _make_multimesh_batch("AuthoredTreeBatch_%s" % str(role).replace(":", "_"), source_mesh, role_items.size(), source_material)
		for index in range(role_items.size()):
			var item: Dictionary = role_items[index]
			var tree_position: Vector3 = item.get("asset_position", Vector3.ZERO)
			var tree_scale: Vector3 = item.get("asset_scale", Vector3.ONE)
			var tree_yaw: float = float(item.get("asset_yaw", 0.0))
			var basis := Basis.from_euler(Vector3(0.0, tree_yaw, 0.0)).scaled(tree_scale)
			trees.multimesh.set_instance_transform(index, Transform3D(basis, tree_position))
		created_batch = true
	return created_batch

func _make_multimesh_batch(node_name: String, mesh: Mesh, count: int, material: Material, use_colors: bool = false) -> MultiMeshInstance3D:
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	# These batches are authored static geometry. Disable transform
	# interpolation so their build-time instance transforms do not trigger
	# physics-interpolation writes outside the physics tick.
	instance.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
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
	if _compatibility_budget_mode():
		# Static environment batches do not need individual shadow maps on the
		# Compatibility/ANGLE target. The authored directional light and contact
		# materials still ground the route while this removes repeated shadow
		# submissions from Greyfen and forest dressing.
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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

func _make_world_wheel(id: String, pos: Vector3, radius: float, depth: float, color: Color, rotation_degrees: Vector3 = Vector3.ZERO) -> void:
	var wheel := MeshInstance3D.new()
	wheel.name = id
	var wheel_mesh := CylinderMesh.new()
	wheel_mesh.top_radius = radius
	wheel_mesh.bottom_radius = radius
	wheel_mesh.height = depth
	wheel_mesh.radial_segments = 16
	wheel.mesh = wheel_mesh
	wheel.position = pos
	wheel.rotation_degrees = rotation_degrees
	wheel.material_override = world_materials.get_material("timber", str(settings.settings.get("quality_preset", "balanced")), color, 0.0, true)
	wheel.set_meta("world_prop_kind", "mill_wheel")
	zone_root.add_child(wheel)
	var hub := MeshInstance3D.new()
	hub.name = "%sHub" % id
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = radius * 0.17
	hub_mesh.bottom_radius = radius * 0.17
	hub_mesh.height = depth * 1.18
	hub_mesh.radial_segments = 12
	hub.mesh = hub_mesh
	hub.position = pos
	hub.rotation_degrees = rotation_degrees
	hub.material_override = world_materials.get_material("metal", str(settings.settings.get("quality_preset", "balanced")), Color(0.20, 0.18, 0.14), 0.0, false)
	zone_root.add_child(hub)

func _make_water_patch(id: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var water := MeshInstance3D.new()
	water.name = id
	var water_mesh := BoxMesh.new()
	water_mesh.size = size
	water.mesh = water_mesh
	water.position = pos
	var material: StandardMaterial3D = world_materials.get_material("water", str(settings.settings.get("quality_preset", "balanced")), color, 1.0, true).duplicate() as StandardMaterial3D
	material.roughness = 0.24
	material.metallic = 0.08
	material.emission_enabled = true
	material.emission = color.lightened(0.12)
	material.emission_energy_multiplier = 0.16
	water.material_override = material
	water.set_meta("world_prop_kind", "marsh_water")
	water.set_meta("non_walkable_visual_only", true)
	zone_root.add_child(water)

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
		wheel.set_meta("world_prop_kind", "wheel")
		wheel.set_meta("world_prop_id", "greyfen_cart_wheel")
		zone_root.add_child(wheel)
	_make_world_prop_anchor("cart", "cart", pos)

func _make_world_prop_anchor(id: String, kind: String, pos: Vector3, state_key: String = "") -> Node3D:
	var anchor := Node3D.new()
	anchor.name = "WorldPropAnchor_%s" % id.capitalize()
	anchor.position = river_safe_position(pos, 0.42)
	anchor.set_meta("world_prop_id", id)
	anchor.set_meta("world_prop_kind", kind)
	anchor.set_meta("world_prop_state_key", state_key)
	zone_root.add_child(anchor)
	return anchor

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
	var flame_mesh := SphereMesh.new()
	flame_mesh.radial_segments = 5
	flame_mesh.rings = 3
	flame.mesh = flame_mesh
	flame.scale = Vector3(0.10, 0.18, 0.10)
	flame.position = pos + Vector3(0, 1.75, 0)
	flame.material_override = _emissive_mat(Color(1.0, 0.45, 0.14), 1.4)
	flame.set_meta("world_prop_kind", "flame")
	flame.set_meta("world_prop_id", "torch_flame")
	zone_root.add_child(flame)
	_make_light("TorchLight", pos + Vector3(0, 1.8, 0), Color(1.0, 0.45, 0.16), 1.45)

func _make_hit_spark(pos: Vector3, heavy: bool) -> void:
	if zone_root == null:
		return
	var spark = MeshInstance3D.new()
	var spark_mesh := SphereMesh.new()
	spark_mesh.radial_segments = 5
	spark_mesh.rings = 3
	spark.mesh = spark_mesh
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
	var authored_prop_ids: Array = zone_root.get_meta("authored_prop_ids", [])
	if name not in authored_prop_ids:
		authored_prop_ids.append(name)
		zone_root.set_meta("authored_prop_ids", authored_prop_ids)
	if name not in ["NorthBerm","SouthBerm","WestBerm","EastBerm"]:
		pos = river_safe_position(pos,size.z*0.5+0.15)
	# Solid scenery must yield to registered route and gate clearances. This is
	# deliberately applied before the shared collision batch receives a shape.
	# Decorative gate landmarks can be rebuilt around the opening by their caller.
	if spatial_service != null and spatial_service.is_reserved(pos, maxf(size.x, size.z) * 0.5 + 0.35):
		return
	var lower := name.to_lower()
	var separate_body := name in ["NorthBerm","SouthBerm","WestBerm","EastBerm"]
	# Thin seams, ledges, trim, and surface dressing are visual detail rather
	# than walkable blockers. Avoid creating hundreds of tiny physics shapes for
	# them; major walls, buildings, fences, and route props retain authoritative
	# collision below the detail threshold.
	var decorative_only := size.y <= 0.28 and not _prop_requires_collision(lower)
	var body: StaticBody3D = null
	if not decorative_only and separate_body:
		body = StaticBody3D.new()
		body.name = name
		body.position = pos
		zone_root.add_child(body)
	elif not decorative_only:
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
	if not decorative_only:
		if not separate_body:
			shape.position = pos
		body.add_child(shape)
	var mesh = MeshInstance3D.new()
	mesh.mesh = shared_box_mesh
	mesh.scale = size
	if lower.contains("glow") or lower.contains("window") or lower.contains("coal") or lower.contains("candle"):
		mesh.material_override = _emissive_mat(color, 0.65)
		if separate_body and body != null:
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
		# Preserve authored colour language when props are batched. The old
		# surface-only key reused one pale material for every wall, roof, and
		# timber piece, making Castle interiors read as blank white blocks. Keep
		# the shared surface textures, but quantize the tint into a small number of
		# cache-friendly variants so repeated geometry still batches efficiently.
		var surface_base := Color(0.72, 0.70, 0.66)
		var surface_tint := surface_base.lerp(color, 0.58)
		var tint_key := "%d_%d_%d" % [int(surface_tint.r * 8.0), int(surface_tint.g * 8.0), int(surface_tint.b * 8.0)]
		var batch_key := "%s_%s" % [surface, tint_key]
		var material = world_materials.get_material(surface, str(settings.settings.get("quality_preset", "balanced")), surface_tint, 0.15 if surface == "wet_mud" else 0.0, true)
		if not prop_batch_data.has(batch_key):
			prop_batch_data[batch_key] = {"material": material, "transforms": []}
		prop_batch_data[batch_key].transforms.append(Transform3D(Basis.IDENTITY.scaled(size), pos))

func _prop_requires_collision(lower_name: String) -> bool:
	return lower_name.contains("wall") or lower_name.contains("fence") or lower_name.contains("rail") \
		or lower_name.contains("post") or lower_name.contains("door") or lower_name.contains("gate") \
		or lower_name.contains("tower") or lower_name.contains("stable") or lower_name.contains("house") \
		or lower_name.contains("building") or lower_name.contains("bridge") or lower_name.contains("berm")

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
		"vargan_steward": "vargan_steward",
		"vargan_servant": "vargan_servant",
		"vargan_patrol": "vargan_patrol",
		"edric_castle": "edric_castle",
		"edric_campaign": "edric_campaign",
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
		"vargan_record_keeper": "villager_worker_human",
		"vargan_steward": "villager_worker_human",
		"vargan_servant": "villager_female_human",
		"vargan_patrol": "road_ranger_human",
		"edric_castle": "road_ranger_human",
		"edric_campaign": "road_ranger_human",
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
	if _compatibility_budget_mode() and category == "environment":
		# Balanced keeps only scale-safe, high-signal environment assets. Potato
		# remains primitive-light; larger source meshes stay Quality-only until
		# their imported bounds have an explicit normalization contract.
		var balanced_environment_roles := [
			"greyfen_door_facade", "greyfen_window_facade", "greyfen_chimney",
			"greyfen_roof",
			"forest_tree", "forest_tree_variant", "forest_rock",
			"castle_wall", "castle_arch", "castle_roof", "castle_door",
			"castle_bookcase", "castle_chair", "castle_bench", "castle_table",
			"castle_weapon_stand", "castle_lantern",
		]
		if str(settings.settings.get("quality_preset", "balanced")) == "potato" or role_name not in balanced_environment_roles:
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
		# Boss and creature display roles have richer visual mappings than the
		# legacy enemy-definitions table. Prefer those when available, while
		# retaining the combat mapping as a compatibility fallback.
		if asset_helper.has_method("spawn_visual_role") and asset_helper.has_method("has_visual_role") and asset_helper.has_visual_role(role_name):
			node = asset_helper.spawn_visual_role(role_name, "enemies")
		else:
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
		"vargan_gate_guard": "castle_guard_human",
		"vargan_record_keeper": "villager_worker_human",
		"vargan_steward": "villager_worker_human",
		"vargan_servant": "villager_female_human",
		"vargan_patrol": "road_ranger_human",
		"edric_castle": "road_ranger_human",
		"edric_campaign": "road_ranger_human",
		"road_ranger": "road_ranger_human"
	}
	return str(roles.get(role_name, ""))

func _make_light(name: String, pos: Vector3, color: Color, energy: float) -> void:
	if _compatibility_budget_mode() and not _keep_performance_light(name):
		return
	var quality := str(settings.settings.get("quality_preset", "balanced")) if settings != null else "balanced"
	# Two authored local pools preserve route landmarks without multiplying
	# Compatibility-renderer lighting work across the entire outdoor frame.
	var balanced_light_cap := 4 if current_zone_id == "record_hall" else 2
	if quality == "balanced" and runtime_light_count >= balanced_light_cap:
		return
	var light = OmniLight3D.new()
	light.name = name
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 14.0 if quality == "quality" or name in ["UndercroftNavigationFill", "UndercroftHalvernFill"] else 8.0
	light.shadow_enabled = false
	zone_root.add_child(light)
	runtime_light_count += 1

func _performance_mode() -> bool:
	return settings != null and bool(settings.settings.get("potato_mode", true))

func _compatibility_budget_mode() -> bool:
	return settings == null or str(settings.settings.get("quality_preset", "balanced")) != "quality"

func _keep_performance_light(name: String) -> bool:
	return name in ["Village Warmth", "Shrine Beacon", "Wychwood Gate Lantern", "Moon Shaft", "Trail Threat", "ClearingColdSpot", "SpawnWarmRead", "LedgerTableLight", "RecordHallNavigationFill", "RecordHallEntryFill", "RecordHallArchiveFill", "HartWitnessLight", "UndercroftNavigationFill", "UndercroftHalvernFill"]

func _build_global_environment() -> void:
	visual_director = VisualDirector.new()
	add_child(visual_director)

func _mat(color: Color) -> StandardMaterial3D:
	var record_hall_lift: bool = current_zone_id == "record_hall"
	var key := "flat:%s:%s" % [color.to_html(true), "record" if record_hall_lift else "world"]
	if material_cache.has(key):
		return material_cache[key]
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	if record_hall_lift:
		# Compatibility can leave upward-facing procedural archive surfaces
		# unlit. A restrained self-lit lift preserves their authored color without
		# turning the room into a flat white box.
		material.emission_enabled = true
		material.emission = color.lightened(0.18)
		material.emission_energy_multiplier = 0.52
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
		var road_tint := Color(0.82, 0.80, 0.76) if paved else Color(0.38, 0.31, 0.22).lerp(color, 0.15)
		return world_materials.get_material("cobblestone" if paved else "wet_mud", str(settings.settings.get("quality_preset", "balanced")), road_tint, 0.15 if paved else 0.78, true)
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
