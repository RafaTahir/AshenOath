extends Node3D

const GreyfenSocialPresentation = preload("res://scripts/greyfen_social_presentation.gd")
const CemeteryEvidencePresentation = preload("res://scripts/cemetery_evidence_presentation.gd")
const WychwoodEvidencePresentation = preload("res://scripts/wychwood_evidence_presentation.gd")
const CampaignRecordPresentation = preload("res://scripts/campaign_record_presentation.gd")
const WychwoodTerrainPresentation = preload("res://scripts/wychwood_terrain_presentation.gd")
const StoryActorPresence = preload("res://scripts/story_actor_presence.gd")
const StoryDecisionCoordinator = preload("res://scripts/story_decision_coordinator.gd")
const StoryWorldDirector = preload("res://scripts/story_world_director.gd")
const CovenantResolution = preload("res://scripts/covenant_resolution.gd")

const BridgeSurfaceContract = preload("res://scripts/bridge_surface_contract.gd")
const SpatialSurfaceContract = preload("res://scripts/spatial_surface_contract.gd")
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
const ZoneResidencyService = preload("res://scripts/zone_residency_service.gd")
const DialogueRuntimeCoordinator = preload("res://scripts/dialogue_runtime_coordinator.gd")
const CombatVfxCoordinator = preload("res://scripts/combat_vfx_coordinator.gd")
const QuestHudCoordinator = preload("res://scripts/quest_hud_coordinator.gd")
const ZoneSceneCatalog = preload("res://scripts/zone_scene_catalog.gd")
const CemeterySection = preload("res://scripts/zones/cemetery_section.gd")
const GreyfenSection = preload("res://scripts/zones/greyfen_section.gd")
const RiverSection = preload("res://scripts/zones/river_section.gd")
const CampaignWildernessSection = preload("res://scripts/zones/campaign_wilderness_section.gd")
const OathGatePortal = preload("res://scripts/oath_gate_portal.gd")
const BossEncounterScript = preload("res://scripts/boss_encounter.gd")
const PerformanceBudgetMonitor = preload("res://scripts/performance_budget_monitor.gd")
const SeamlessWorldService = preload("res://scripts/seamless_world_service.gd")
const CharacterRoleSpec = preload("res://scripts/character_role_spec.gd")
const ProductionObservationBridgeScript = preload("res://scripts/production_observation_bridge.gd")

var player
var production_observation_bridge
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
var dialogue_runtime_coordinator := DialogueRuntimeCoordinator.new()
var combat_vfx_coordinator := CombatVfxCoordinator.new()
var quest_hud_coordinator := QuestHudCoordinator.new()
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
var story_action_in_progress := false
var story_save_pending := false
var preparation_action_in_progress := false
var story_guidance_refresh_pending := false
var journey_continuity := preload("res://scripts/journey_continuity_coordinator.gd").new()
var journey_loading := preload("res://scripts/journey_load_runtime.gd").new()
var journey_arrival_generation := 0
var journey_models_refresh_pending := false
var pending_player_restore: Dictionary = {}
var zone_pack_request_serial := 0
var removed_interactions = {}
var autosave_cooldown = 180.0
var last_safe_player_position = Vector3(0, 1, 9.8)
var tutorial_flags = {}
var material_cache: Dictionary = {}
var runtime_light_count := 0
var tree_batch_data: Array[Dictionary] = []
var deadfall_batch_data: Array[Transform3D] = []
var tree_collision_body: StaticBody3D
var route_zone_cache: Dictionary:
	get: return zone_residency.route_zone_cache
	set(value): zone_residency.route_zone_cache = value
var route_enemy_cache: Dictionary:
	get: return zone_residency.route_enemy_cache
	set(value): zone_residency.route_enemy_cache = value
var route_zone_signatures: Dictionary:
	get: return zone_residency.route_zone_signatures
	set(value): zone_residency.route_zone_signatures = value
var route_spatial_cache: Dictionary:
	get: return zone_residency.route_spatial_cache
	set(value): zone_residency.route_spatial_cache = value
var retired_zone_roots: Array[Node]:
	get: return zone_residency.retired_zone_roots
	set(value): zone_residency.retired_zone_roots = value
var retired_zone_cleanup_root: Node3D
var pending_zone_retirements: int:
	get: return zone_residency.pending_zone_retirements
	set(value): zone_residency.pending_zone_retirements = value
var retired_skinned_actor_pool: Node3D:
	get: return zone_residency.retired_skinned_actor_pool
	set(value): zone_residency.retired_skinned_actor_pool = value
var skinned_resource_anchors: Dictionary:
	get: return zone_residency.skinned_resource_anchors
	set(value): zone_residency.skinned_resource_anchors = value
var retired_material_anchors: Dictionary:
	get: return zone_residency.retired_material_anchors
	set(value): zone_residency.retired_material_anchors = value
var retirement_material: StandardMaterial3D:
	get: return zone_residency.retirement_material
	set(value): zone_residency.retirement_material = value
var transition_history: Array[Dictionary] = []
var active_zone_signature := -1
var shared_box_mesh: BoxMesh
var prop_batch_data: Dictionary = {}
var visual_box_batch_data: Array[Dictionary] = []
var terrain_patch_batch_data: Array[Dictionary] = []
var house_batch_data: Dictionary = {}
var house_module_batch_data: Dictionary = {}
var spatial_service: Node
var zone_runtime_coordinator: ZoneRuntimeCoordinator
var zone_residency := ZoneResidencyService.new()
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
var new_game_started_usec := 0
var last_loading_metrics: Dictionary = {}
var new_game_start_pending := false
var zone_load_request_pending := false
var resource_shutdown_prepared := false
var requested_zone_id := ""
var requested_zone_spawn := Vector3.ZERO
var campaign_pack_waiting := false
var opening_pack_waiting := false
var greyfen_prewarm_started := false
var opening_prepare_generation := 0
const OPENING_BUILD_SLICE_USEC := 8000
var startup_packs_waiting := false
var startup_prepare_failed := false
var new_game_requested_while_preparing := false
var greyfen_prewarm_spatial_service: Node
var opening_detail_pending := false
var opening_well_mesh: ArrayMesh
var opening_detail_stage_index := 0
var opening_detail_generation := 0
var opening_boot_material_restore_generation := 0
var opening_boot_material_restore_queue: Array[Dictionary] = []
var opening_save_generation := 0
var opening_checkpoint_pending := false
var campaign_visual_prewarm_started := false
var campaign_visual_prewarm_generation := 0
var campaign_visual_prewarm_not_before_msec := 0
var campaign_visual_prewarm_suspended := false
var campaign_visual_prewarm_zone := ""
var campaign_visual_prewarm_roles: Array[String] = []
var background_runtime_timer_pending := false
var owned_timers: Array[Timer] = []
# Keep each late-opening chunk small enough that the first controllable frame
# never competes with a large import or decoration batch on Web/ANGLE.
# Keep the first playable window free of optional scene imports, pack mounts,
# and IndexedDB writes. These operations resume after the player has had time
# to see the opening and the browser has completed its first capture.
const OPENING_DETAIL_INITIAL_DELAY_SECONDS := 30.0
# The boot Anwen and all legal exits are already interactive. Keep the full
# gameplay subtree out of the browser's first control window: even hidden
# imported actors allocate renderer state when attached, which previously held
# Edge's main thread before automation or a player could observe control.
const OPENING_GAMEPLAY_HYDRATE_DELAY_SECONDS := 0.75
const OPENING_DETAIL_STAGE_DELAY_SECONDS := 0.05
const OPENING_BOOT_MATERIAL_RESTORE_DELAY_SECONDS := 1.5
const OPENING_BOOT_MATERIAL_RESTORE_INTERVAL_SECONDS := 0.08
const OPENING_DETAIL_RETRY_SECONDS := 5.0
const BACKGROUND_RUNTIME_DELAY_SECONDS := 45.0
const BACKGROUND_RUNTIME_RETRY_SECONDS := 12.0
const OPENING_SAVE_DELAY_SECONDS := 30.0
const OPENING_GAMEPLAY_VISUAL_BUCKETS := 16
# Campaign presentation roles are optional. Only a sector immediately before a
# Castle destination may warm them; Greyfen startup and unrelated wilderness
# travel must never parse this OBJ set.
const CAMPAIGN_VISUAL_PREWARM_DELAY_SECONDS := 18.0
const CAMPAIGN_VISUAL_ROLES: Array[String] = [
	"castle_wall", "castle_arch", "castle_roof", "castle_bookcase",
	"castle_chair", "castle_bench", "castle_table", "castle_weapon_stand",
	"castle_lantern",
]
const PREDICTIVE_VISUAL_PREWARM_ROLES := {
	"bandit_road": ["castle_wall", "castle_arch", "castle_roof", "castle_lantern"],
	"vargan_approach": ["castle_bookcase", "castle_chair", "castle_bench", "castle_table", "castle_weapon_stand"],
}
# Environment OBJ meshes are normalized once by AssetSpawnHelper before zone
# builders place them. Builders request world dimensions through this contract
# instead of applying a second guessed multiplier to already-normalized bounds.
const ENVIRONMENT_ROLE_NORMALIZED_SIZE := {
	"greyfen_door_facade": Vector3(1.281, 2.0, 0.260),
	"greyfen_window_facade": Vector3(1.281, 2.0, 0.260),
	"greyfen_wall_facade": Vector3(1.281, 2.0, 0.260),
	"greyfen_roof": Vector3(2.935, 2.0, 3.498),
	"forest_tree": Vector3(10.563, 18.949, 9.203),
	"cart": Vector3(1.549393, 1.35, 0.543576),
	"castle_wall": Vector3(1.281, 2.0, 0.260),
	"castle_arch": Vector3(1.333, 2.0, 0.043),
	"castle_roof": Vector3(2.935, 2.0, 3.498),
	"castle_door": Vector3(0.639, 1.2, 0.069),
	"castle_bookcase": Vector3(0.689, 1.2, 0.202),
	"castle_chair": Vector3(0.620, 1.2, 0.586),
	"castle_bench": Vector3(4.8, 0.922, 0.924),
	"castle_table": Vector3(4.202, 1.2, 1.618),
	"castle_weapon_stand": Vector3(1.499505, 1.2, 1.063504),
	"castle_lantern": Vector3(0.321, 1.2, 1.169),
}
const OPENING_DETAIL_STAGES: Array[String] = [
	"gameplay_base", "gameplay_place_0", "gameplay_place_1", "gameplay_place_2", "gameplay_place_3", "gameplay_place_4",
	"gameplay_side_clues", "gameplay_main_clues", "gameplay_gate_links",
	"gameplay_gate_visual", "gameplay_route_markers", "gameplay_story",
	"gameplay_visual_0", "gameplay_visual_1", "gameplay_visual_2", "gameplay_visual_3",
	"gameplay_visual_4", "gameplay_visual_5", "gameplay_visual_6", "gameplay_visual_7",
	"gameplay_visual_8", "gameplay_visual_9", "gameplay_visual_10", "gameplay_visual_11",
	"gameplay_visual_12", "gameplay_visual_13", "gameplay_visual_14", "gameplay_visual_15",
	"gameplay_mira", "gameplay_rook", "gameplay_widow_elna",
	"gameplay_blacksmith_tor", "gameplay_farmer_toma", "gameplay_population",
	"gameplay_common_table", "gameplay_barrel_board",
	"gameplay_crowd_0", "gameplay_crowd_1", "gameplay_crowd_2", "gameplay_crowd_3",
	"gameplay_crowd_4", "gameplay_crowd_5", "gameplay_crowd_6", "gameplay_crowd_7",
	"gameplay_crowd_8", "gameplay_crowd_9",
	"opening_river_visual", "opening_terrain", "opening_lighting", "opening_spawn",
	"village_house_0", "village_house_1", "village_house_2", "village_house_3",
	"village_architectural_details_0", "village_architectural_details_1", "village_architectural_details_2",
	"village_architectural_details_3", "village_architectural_details_4",
	"boundary_horizon", "boundary_vegetation", "boundary_lights", "boundary_north_south_fences", "boundary_side_fences",
	"landmark_board", "landmark_shrine", "landmark_blacksmith",
	"landmark_cemetery_approach", "landmark_cemetery_boundary", "landmark_cemetery_graves",
	"landmark_cemetery_chapel", "landmark_cemetery_bell", "landmark_cemetery_edges",
	"landmark_cemetery_presentation_bell", "landmark_cemetery_presentation_chapel",
	"landmark_cemetery_presentation_graves", "landmark_cemetery_presentation_roost",
	"landmark_cemetery_presentation_states",
	"landmark_cart_road", "village_dressing",
	"village_first_impression_ruts", "village_first_impression_lanterns", "village_first_impression_shrine",
	"village_first_impression_story", "village_first_impression_crows", "village_quality", "trees", "aftermath"
]
const OPENING_NAMED_ACTOR_IDS := ["mira", "rook", "widow_elna", "blacksmith_tor", "farmer_toma"]

func _opening_stage_required_before_control(stage: String) -> bool:
	return stage.begins_with("opening_") or stage.begins_with("village_house_") \
		or stage.begins_with("village_architectural_details_") or stage.begins_with("boundary_") \
		or stage.begins_with("landmark_") or stage.begins_with("gameplay_place_") \
		or stage in ["gameplay_gate_links", "gameplay_gate_visual", "gameplay_route_markers",
			"gameplay_population", "gameplay_crowd_0", "gameplay_crowd_1"]

func _record_opening_stage(root: Node3D, stage: String) -> void:
	var completed: Dictionary = root.get_meta("opening_completed_stages", {})
	completed[stage] = true
	root.set_meta("opening_completed_stages", completed)

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

var interaction_focus_cooldown := 0.0
var interaction_input_block_until_usec := 0
var compass_refresh_cooldown := 0.0
var navigation_dial_refresh_cooldown := 0.0
var tutorial_refresh_cooldown := 0.0
var target_status_refresh_cooldown := 0.0
var interaction_focus_dirty := true
var interaction_focus_cache_valid := false
var last_focus_position := Vector3.ZERO
var last_focus_forward := Vector3.ZERO
var compass_dirty: bool:
	get: return quest_hud_coordinator.dirty
	set(value): quest_hud_coordinator.dirty = value
var compass_cache_valid: bool:
	get: return quest_hud_coordinator.cache_valid
	set(value): quest_hud_coordinator.cache_valid = value
var last_compass_position: Vector3:
	get: return quest_hud_coordinator.last_position
	set(value): quest_hud_coordinator.last_position = value
var last_compass_zone: String:
	get: return quest_hud_coordinator.last_zone
	set(value): quest_hud_coordinator.last_zone = value
var last_compass_signature: String:
	get: return quest_hud_coordinator.last_signature
	set(value): quest_hud_coordinator.last_signature = value
const MAX_CACHED_ROUTE_ZONES := ZoneResidencyService.MAX_CACHED_ROUTE_ZONES
const ZONE_RETIRE_FRAMES := ZoneResidencyService.ZONE_RETIRE_FRAMES
const MAX_SKINNED_RESOURCE_ANCHORS := ZoneResidencyService.MAX_SKINNED_RESOURCE_ANCHORS
const MAX_RETIRED_MATERIAL_ANCHORS := ZoneResidencyService.MAX_RETIRED_MATERIAL_ANCHORS
const MAX_TRANSITION_HISTORY := 16
const DIALOGUE_INTERACTION_GUARD_SECONDS := 0.8

func _ready() -> void:
	var ready_started := Time.get_ticks_msec()
	process_mode = Node.PROCESS_MODE_ALWAYS
	zone_residency.name = "ZoneResidencyService"
	add_child(zone_residency)
	zone_residency.configure(_validate_zone_render_resources)
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
	production_observation_bridge = ProductionObservationBridgeScript.new()
	production_observation_bridge.name = "ProductionObservationBridge"
	add_child(production_observation_bridge)
	production_observation_bridge.setup(self)
	var services_ms := Time.get_ticks_msec() - phase_started
	# The browser shell is already the audio/input consent surface. Showing a
	# second in-engine launch screen made startup require two clicks and doubled
	# the perceived wait. Both platforms enter the menu while Greyfen prewarms.
	if OS.has_feature("web"):
		hud.show_main_menu()
		if hud.has_method("set_boot_shell_cover_active"):
			hud.set_boot_shell_cover_active(true)
		_publish_web_opening_state("preparing", "Preparing Greyfen's first view...")
		# The HTML shell has already provided the consent/input surface. Start the
		# opening prewarm behind the real menu so New Game is immediately visible
		# and the player does not pay the Greyfen build cost after clicking it.
		_on_launch_accepted()
		print("LOADING: web_menu_ready opening_prewarm_hidden=true")
	else:
		hud.show_main_menu()
		_on_launch_accepted()
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
	if event.is_action_pressed("pause") and not event.is_echo():
		_request_pause_or_back(event)
	elif not get_tree().paused and input_router.accept_event(event, &"interact", "gameplay"):
		# Dispatch the same target whose prompt was visible for this fresh press.
		var focused_target: Area3D = active_interactable as Area3D if is_instance_valid(active_interactable) else null
		get_viewport().set_input_as_handled()
		if is_instance_valid(focused_target) and _interaction_target_valid(focused_target):
			_handle_interaction(focused_target)
		else:
			hud.set_guidance_hint("Face the object and move into clear view.", 2.0)
	elif not get_tree().paused and input_router.accept_event(event, &"open_inventory", "gameplay"):
		get_viewport().set_input_as_handled()
		audio.set_game_paused(true)
		get_tree().paused = true
		_show_preparation_menu()

func _request_pause_or_back(event: InputEvent) -> void:
	if _journey_load_pending():
		if event.is_action_pressed("pause") and not event.is_echo():
			get_viewport().set_input_as_handled()
			_cancel_journey_load()
		return
	if input_router == null or not input_router.accept_event(event, &"pause", input_router.get_context()):
		return
	get_viewport().set_input_as_handled()
	if zone_transition_pending or zone_load_request_pending or opening_pack_waiting or campaign_pack_waiting:
		return
	if get_tree().paused or not input_router.is_gameplay_context():
		# The active surface owns Back. Death, ending and transition screens must
		# never reach generic Resume merely because the tree happens to be paused.
		hud.request_back()
		return
	_pause_game()

func _invalidate_interaction_prompt() -> void:
	interaction_focus_dirty = true
	interaction_focus_cache_valid = false
	_publish_interaction_prompt()

func _publish_interaction_prompt() -> void:
	if hud == null:
		return
	if input_router == null or not input_router.is_gameplay_context() or get_tree().paused \
			or not is_instance_valid(active_interactable) or not _interaction_target_valid(active_interactable):
		hud.set_interaction_prompt({"available": false})
		return
	var prompt_model: Dictionary = active_interactable.get_prompt_model() if active_interactable.has_method("get_prompt_model") else {"text": active_interactable.get_context_prompt()}
	prompt_model["target_id"] = str(active_interactable.interaction_id)
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
	journey_loading.try_finish(self)
	if input_router == null or input_router.get_context() != "transition":
		_publish_journey_arrival()
		return
	if not game_started or get_tree().paused or not is_instance_valid(player):
		return
	if zone_transition_pending or zone_load_request_pending or opening_pack_waiting or campaign_pack_waiting:
		return
	if _journey_load_pending():
		return
	input_router.begin_context("gameplay")
	_invalidate_interaction_prompt()
	_publish_journey_arrival()

func _process(delta: float) -> void:
	if not game_started or player == null or get_tree().paused:
		return
	if zone_transition_pending:
		_advance_zone_transition()
		return
	if _journey_load_pending():
		journey_loading.try_finish(self)
		return
	if seamless_world != null and seamless_world.update_player(player, current_zone_id, delta):
		return
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
		save_manager.autosave(self)
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
	quest_hud_coordinator.configure(quest_presentation, quests)
	runtime_services.configure(self)
	hud.audio_mix_requested.connect(settings.set_mix_level)
	hud.revisit_covenant_requested.connect(func(): save_manager.load_pre_covenant(self))
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
	if game_started or zone_transition_pending or zone_load_request_pending or _journey_load_pending():
		return
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
	if OS.has_feature("web") and runtime_packs != null and runtime_packs.has_method("startup_packs_ready"):
		if not runtime_packs.startup_packs_ready():
			new_game_start_pending = true
			new_game_requested_while_preparing = true
			if not startup_packs_waiting and not greyfen_prewarm_started:
				_on_launch_accepted()
			if hud != null:
				hud.set_new_game_status("Greyfen is waking. Your New Game request will open as soon as it is ready.")
				hud.toast("Greyfen is still being prepared. New Game will open shortly.")
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
		return
	new_game_start_pending = true
	new_game_requested_while_preparing = false
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
	journey_loading.begin_arrival(self, "travel", zone_id)
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
		if not runtime_packs.zone_packs_ready(zone_id):
			opening_pack_waiting = true
			if hud != null and hud.has_method("arm_loading"):
				hud.arm_loading("Preparing the road into Wychwood...")
			runtime_packs.request_zone_packs(zone_id)
			_wait_for_opening_pack(zone_id, spawn_pos, zone_pack_request_serial)
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
		_wait_for_campaign_pack(zone_id, spawn_pos, zone_pack_request_serial)
		return
	_load_zone(zone_id, spawn_pos)

func _wait_for_campaign_pack(zone_id: String, spawn_pos: Vector3, request_serial: int) -> void:
	for _frame in range(900):
		await get_tree().process_frame
		if request_serial != zone_pack_request_serial or not campaign_pack_waiting:
			return
		if runtime_packs != null and runtime_packs.zone_packs_ready(zone_id):
			campaign_pack_waiting = false
			if hud != null and hud.has_method("hide_loading"):
				hud.hide_loading()
			_load_zone(zone_id, spawn_pos)
			return
		if runtime_packs != null and not runtime_packs.zone_pack_failures(zone_id).is_empty():
			break
	campaign_pack_waiting = false
	_recover_failed_pack_load("The road pack could not be prepared. Your current location remains open; use the crossing to retry.")

func _wait_for_opening_pack(zone_id: String, spawn_pos: Vector3, request_serial: int) -> void:
	for _frame in range(900):
		await get_tree().process_frame
		if request_serial != zone_pack_request_serial or not opening_pack_waiting:
			return
		if runtime_packs != null and runtime_packs.zone_packs_ready(zone_id):
			opening_pack_waiting = false
			if hud != null and hud.has_method("hide_loading"):
				hud.hide_loading()
			_load_zone(zone_id, spawn_pos)
			return
		if runtime_packs != null and not runtime_packs.zone_pack_failures(zone_id).is_empty():
			break
	opening_pack_waiting = false
	_recover_failed_pack_load("The opening pack could not be prepared. Your current location remains open; use the crossing to retry.")

func _recover_failed_pack_load(reason: String = "The destination could not load. Please retry.") -> void:
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
	opening_detail_pending = prewarmed_greyfen != null and str(prewarmed_greyfen.get_meta("opening_build_profile", "")) in ["opening_fast", "opening_boot"]
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
	print("LOADING: handoff_phase=quest_end")
	# The opening is now playable. Remaining packs must not delay New Game or
	# the first quest interaction. In particular, do not start the character-pack
	# download here: Web hash/mount work can monopolize the main thread before the
	# first input sample. The deferred visual-role stage requests that pack only
	# after first control, while Kael and Anwen remain root-resident.
	if runtime_packs != null and runtime_packs.has_method("request_background_packs"):
		call_deferred("_schedule_background_runtime_packs")
	print("LOADING: new_game_stage=state_ready elapsed=%.1f" % (float(Time.get_ticks_usec() - loading_started_usec) / 1000.0))
	if route_zone_cache.has("greyfen"):
		route_zone_signatures["greyfen"] = _zone_state_signature()
	print("LOADING: new_game_stage=zone_dispatch elapsed=%.1f" % (float(Time.get_ticks_usec() - loading_started_usec) / 1000.0))
	print("LOADING: handoff_phase=load_zone_begin")
	journey_loading.begin_arrival(self, "new_journey", "greyfen")
	_load_zone("greyfen", Vector3(0, 1, 9.8))
	print("LOADING: handoff_phase=load_zone_end")
	if not opening_boot_material_restore_queue.is_empty() \
			or (visual_director != null and visual_director.is_opening_boot_budget_active()):
		opening_boot_material_restore_generation += 1
		call_deferred("_restore_opening_boot_materials", opening_boot_material_restore_generation)
	if opening_detail_pending:
		call_deferred("_run_opening_detail_stage", opening_detail_generation)
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
	call_deferred("_schedule_opening_save", opening_save_generation)

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
	if runtime_packs.has_method("request_background_packs"):
		runtime_packs.request_background_packs()
	# Neighbor scene requests are also background work. Keep them behind the
	# first playable frame so a cold New Game never waits on campaign metadata.
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
		call_deferred("_schedule_opening_save", generation)
		return
	# Save the current state rather than a stale Greyfen-only snapshot. If the
	# player reaches another supported zone during the delay, the normal autosave
	# path still owns that transition and this checkpoint remains a safe fallback.
	save_manager.checkpoint(self)
	opening_checkpoint_pending = false

func load_save_state(data: Dictionary) -> void:
	# Direct payload callers retain the same preparation boundary as file-backed
	# selections. SaveManager owns identity/history for ordinary UI loads.
	var migrated_data: Dictionary = data
	if save_manager != null and save_manager.has_method("migrate_save_data"):
		migrated_data = save_manager.migrate_save_data(data)
		if migrated_data.is_empty():
			if hud != null:
				hud.toast("This save belongs to a newer version of Ashen Oath.")
			return
	_on_prepared_journey_load({
		"ok": true, "request_id": "direct:%d" % Time.get_ticks_usec(),
		"data": migrated_data, "summary": {}, "source": {"direct_data": true}
	})

func _apply_loaded_journey(data: Dictionary) -> void:
	_begin_gameplay_handoff("load_journey")
	if not game_started:
		_discard_menu_opening()
	new_game_start_pending = false
	opening_save_generation += 1
	opening_checkpoint_pending = false
	story_save_pending = false
	_clear_route_zone_cache()
	game_started = true
	paused_by_menu = false
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
		settings.restore_settings(data.settings)
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
	pending_player_restore = {
		"health": data.get("player_health", {}).duplicate(true),
		"stamina": data.get("player_stamina", {}).duplicate(true),
		"equipment": data.get("equipment", {}).duplicate(true)
	}
	_load_zone_after_runtime_pack(zone, pos)
	_refresh_tracker()
	_refresh_equipment_readout()
	call_deferred("_finish_gameplay_handoff")

func _journey_load_pending() -> bool:
	return journey_loading.pending(self)

func _on_prepared_journey_load(prepared: Dictionary) -> void:
	journey_loading.request(self, prepared)

func _cancel_journey_load() -> void:
	journey_loading.cancel(self)

func _publish_journey_arrival() -> void:
	journey_loading.publish_arrival(self)

func _queue_journey_models_refresh() -> void:
	if journey_models_refresh_pending:
		return
	journey_models_refresh_pending = true
	call_deferred("_refresh_journey_models")

func _refresh_journey_models() -> void:
	journey_models_refresh_pending = false
	if hud == null or save_manager == null or resource_shutdown_prepared:
		return
	var current: Dictionary = {}
	if game_started:
		current = preload("res://scripts/story_journal.gd").recap_model(quests, story_state, str(current_zone_id))
	hud.set_journey_models({"continue": save_manager.continue_model(), "recovery": save_manager.checkpoint_model(), "current": current})

func _request_journey_load(selection: Dictionary) -> void:
	audio.play_event("ui")
	save_manager.request_load(selection)

func _open_journal_section(section_id: String) -> void:
	if _journey_load_pending():
		return
	_update_preparation_context()
	hud.show_inventory(inventory, quests, story_state, progression, section_id)

func _apply_pending_player_restore() -> void:
	if pending_player_restore.is_empty() or player == null or not is_instance_valid(player):
		return
	var restore := pending_player_restore
	pending_player_restore = {}
	player.health_component.load_state(restore.health)
	player.stamina_component.load_state(restore.stamina)
	if player.has_method("load_equipment_state"):
		player.load_equipment_state(restore.equipment)
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
	_bind_spatial_player_body()
	_sync_camera_enemy_cache()
	hud.update_health(player.health_component.health, player.health_component.max_health)
	hud.update_stamina(player.stamina_component.stamina, player.stamina_component.max_stamina)

func _sync_camera_enemy_cache() -> void:
	# Keep restored encounter actors on the same owned peer list as the camera.
	# Cached-zone activation replaces active_enemies with a fresh filtered Array;
	# rebinding here keeps spacing and attack-lane checks on the restored list;
	# enemy controllers never discover peers in unrelated scene-tree groups.
	for enemy in active_enemies:
		if is_instance_valid(enemy) and enemy.has_method("set_encounter_peers"):
			enemy.set_encounter_peers(active_enemies)
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
	zone_runtime_coordinator.load_zone(zone_id, spawn_pos)
	_finish_gameplay_handoff()

func _advance_zone_transition() -> void:
	zone_runtime_coordinator.advance_transition()
	_finish_gameplay_handoff()

func _apply_zone_audio(zone_id: String) -> void:
	if audio == null or zone_id == "":
		return
	audio.play_ambient(zone_id)
	audio.set_music_state(audio.music_state_for_zone(zone_id))
	audio.set_story_context(story_state, zone_id)
	if zone_id == "greyfen":
		audio.play_event("shrine_hum", 0.01)

func _schedule_deferred_zone_audio(zone_id: String, root: Node3D) -> void:
	if root == null or not is_instance_valid(root) or not bool(root.get_meta("zone_audio_pending", false)):
		return
	root.set_meta("zone_audio_pending", false)
	call_deferred("_finish_deferred_zone_audio", zone_id, root)

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
	call_deferred("_finish_prewarmed_greyfen_runtime")

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
	call_deferred("_run_campaign_visual_prewarm", campaign_visual_prewarm_generation, 0)

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

func should_defer_character_role(role: String, actor_id: String) -> bool:
	# Castle NPC bodies are presentation work, while their Area3D, interaction,
	# prompt, and patrol ownership are required immediately. Keeping only this
	# small named-cast slice deferred removes a cold transition hitch without
	# making the opening actors appear late.
	if role == "" or actor_id == "":
		return false
	var preparing_greyfen := zone_root != null and zone_root.name == "greyfen"
	if OS.has_feature("web") and (current_zone_id == "greyfen" or preparing_greyfen) and role != "sister_anwen_human":
		# Always publish a marker first. Pack readiness can change between stage
		# construction and imported-scene parsing, including menu-covered prewarm.
		# Direct spawning here requests Character-pack GLBs before they mount.
		return true
	if not game_started:
		return false
	return current_zone_id in ["vargan_court", "record_hall"]

func _schedule_deferred_visual_roles(root: Node3D) -> void:
	if root == null or not is_instance_valid(root):
		return
	if bool(root.get_meta("deferred_visual_roles_pending", false)):
		return
	var markers := _deferred_visual_markers(root)
	if markers.is_empty():
		return
	root.set_meta("deferred_visual_roles_pending", true)
	call_deferred("_run_deferred_visual_roles", root)

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
			call_deferred("_run_deferred_visual_roles", root)
		return
	for marker in markers:
		if resource_shutdown_prepared or not is_instance_valid(marker) or root != zone_root or not game_started:
			if is_instance_valid(root):
				root.set_meta("deferred_visual_roles_pending", false)
			return
		await get_tree().process_frame
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
		var parent := marker.get_parent()
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
			call_deferred("_run_campaign_visual_prewarm", generation, role_index)
		return
	# Never parse an OBJ in the middle of a scene swap or a paused menu. One
	# role per settled frame keeps imported castle dressing out of the cold
	# transition while still warming the exact cache used by the builder.
	if campaign_visual_prewarm_suspended or zone_transition_pending or zone_load_request_pending or get_tree().paused:
		await get_tree().process_frame
		call_deferred("_run_campaign_visual_prewarm", generation, role_index)
		return
	await get_tree().process_frame
	if generation != campaign_visual_prewarm_generation or not game_started or resource_shutdown_prepared:
		return
	if campaign_visual_prewarm_suspended or zone_transition_pending or zone_load_request_pending or get_tree().paused:
		call_deferred("_run_campaign_visual_prewarm", generation, role_index)
		return
	var role := campaign_visual_prewarm_roles[role_index]
	var started_usec := Time.get_ticks_usec()
	var result: Dictionary = asset_helper.prewarm_roles([role])
	var missing: Array = result.get("missing", [])
	print("LOADING: campaign_visual_prewarm role=%s ms=%.1f missing=%s" % [
		role, float(Time.get_ticks_usec() - started_usec) / 1000.0, not missing.is_empty(),
	])
	call_deferred("_run_campaign_visual_prewarm", generation, role_index + 1)

func _schedule_zone_runtime_finalize(zone_id: String, root: Node3D, service: Node, enemies: Array, navigation_pending: bool) -> void:
	call_deferred("_finish_zone_runtime_finalize", zone_id, root, service, enemies, navigation_pending)

func _finish_zone_runtime_finalize(zone_id: String, root: Node3D, service: Node, enemies: Array, navigation_pending: bool) -> void:
	# Yield once and then give the renderer a short normal frame window. This
	# keeps cold activation responsive without weakening the active-zone audit.
	await get_tree().process_frame
	var settle_timer := _create_owned_timer(0.12, true)
	await settle_timer.timeout
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
	StoryWorldDirector.decorate(self, root, zone_id)
	CovenantResolution.restore(self)
	_persist_story_action()
	print("LOADING: zone_stage=runtime_finalized zone=%s navigation=%s ms=%d" % [zone_id, navigation_pending, Time.get_ticks_msec() - started])

func _finish_prewarmed_greyfen_runtime() -> void:
	# Complete deferred navigation and renderer validation only after the first
	# controllable frame. The metadata guard prevents a late callback from
	# touching a zone that has already been replaced or retired.
	await get_tree().process_frame
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
	if get_world_3d() == null:
		return null
	var excluded: Array[RID] = []
	if player != null:
		excluded.append(player.get_rid())
	var hit := SpatialSurfaceContract.support_hit(get_world_3d().direct_space_state, candidate + Vector3.UP * 6.0, candidate - Vector3.UP * 12.0, excluded)
	if hit.is_empty():
		return null
	return Vector3(candidate.x, float(hit.position.y) + 0.95, candidate.z)

func _zone_display_name(zone_id: String) -> String:
	return zone_id.replace("_", " ").capitalize()

func _valid_cached_enemies(entries: Array) -> Array:
	return zone_residency._valid_cached_enemies(entries)

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
	transition_history.append(metrics.duplicate(true))
	while transition_history.size() > MAX_TRANSITION_HISTORY:
		transition_history.pop_front()

func _create_owned_timer(seconds: float, ignore_time_scale: bool = false) -> Timer:
	var timer := Timer.new()
	timer.name = "OwnedDelayTimer"
	timer.wait_time = maxf(seconds, 0.0)
	timer.one_shot = true
	timer.ignore_time_scale = ignore_time_scale
	add_child(timer)
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
			save_manager.autosave(self)
	)

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
	journey_loading.cancel(self, "", false, true)
	if resource_shutdown_prepared:
		return
	resource_shutdown_prepared = true
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
	StoryWorldDirector.decorate(self, zone_root, zone_id)
	CovenantResolution.restore(self)
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
	StoryWorldDirector.decorate(self, zone_root, zone_id)
	CovenantResolution.restore(self)
	call_deferred("_persist_story_action")
	call_deferred("_finish_covenant_if_ready")
	if audio != null:
		audio.set_story_context(story_state, zone_id)
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
	if area != null and area.interaction_type == "story_activity":
		preload("res://scripts/story_activity_director.gd").handle(self, area)
		return
	if world_props != null and area != null and area.has_meta("world_prop_id"):
		world_props.activate_prop(str(area.get_meta("world_prop_id", "")))
	var world_prop_component := area.find_child("InteractiveWorldProp", true, false) as InteractiveWorldProp if area != null else null
	if world_prop_component != null:
		world_prop_component.activate()
	if world_vfx != null and is_instance_valid(world_vfx) and area is Node3D:
		world_vfx.pulse_interaction((area as Node3D).global_position)
	if area.interaction_type == "covenant":
		CovenantResolution.activate(self, area)
		return
	if area.interaction_type == "minigame":
		minigames.open_game("tic_tac_toe" if area.interaction_id == "common_table" else "draughts")
	elif area.interaction_type == "vendor":
		if vendor_service == null:
			hud.toast("The shop is not available right now.")
			return
		audio.set_game_paused(true)
		get_tree().paused = true
		_update_preparation_context()
		hud.show_vendor(area.interaction_id, vendor_service, inventory, quests, story_state)
	elif area.interaction_type == "village_place":
		_handle_village_place(area.interaction_id)
	elif area.interaction_type == "dialogue":
		if area.interaction_id == "sister_anwen" and preload("res://scripts/opening_care_scene.gd").introduce(self, area):
			return
		if area.interaction_id == "vargan_ledger_choice":
			audio.play_event("record_page", 0.02)
			quests.complete_evidence("main_blood_under_stone", "evidence_ledger_fragment")
			quests.complete_objective("main_blood_under_stone", "recover_ledger")
		var dialogue_data = dialogue.get_dialogue(area.dialogue_id)
		var played_report_voice = false
		var report_chosen := false
		if _road_ready_to_report() and area.interaction_id in ["sister_anwen", "notice_board", "retain_evidence"]:
			report_chosen = true
			dialogue_data = dialogue.get_dialogue("report_decision")
		if area.interaction_id == "sister_anwen" and not bool(tutorial_flags.get("anwen_talked", false)):
			tutorial_flags["anwen_talked"] = true
			quests.complete_objective("main_road_of_crows", "speak_anwen")
		elif area.interaction_id == "sister_anwen" and not report_chosen and quests.is_active("main_bell_beneath_greyfen"):
			quests.complete_objective("main_bell_beneath_greyfen", "meet_anwen_gate")
			story_state.set_flag("bell_gate_met", true)
			dialogue_data = dialogue.get_dialogue(area.dialogue_id)
			audio.set_music_state("shrine_anwen")
			hud.toast("The cut bell rope runs beneath the graves. Anwen waits for proof.")
			_show_current_objective_guidance(6.0)
		if report_chosen and area.interaction_id == "sister_anwen":
			audio.play_event("return_report", 0.02)
			audio.play_voice("voice_sister_anwen_report_01")
			played_report_voice = true
			audio.set_music_state("return_report")
			hud.show_status_cue("Anwen knows the sign", "victory")
			hud.toast("Anwen goes still at the feathers. 'Then it was called here,' she says, and will say no more.")
		_set_interactable_label_visible(area, false)
		_stage_dialogue_moment(area)
		var topic_context_id: String = dialogue_runtime_coordinator.bind_topic_context(str(area.interaction_id), current_zone_id)
		if not topic_context_id.is_empty():
			dialogue_data["topic_context_id"] = topic_context_id
			dialogue_data["optional_topics"] = dialogue.get_conversation_topics(str(area.interaction_id), current_zone_id, hud.get_dialogue_topic_seen_keys())
		preload("res://scripts/story_performance.gd").begin(area, player, dialogue_data, story_state)
		audio.set_dialogue_active(true)
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
		elif area.interaction_id in ["sheepfold", "bandit_camp"]:
			story_state.set_flag("black_dog_%s_inspected" % area.interaction_id, true)
			_try_complete_black_dog_investigation()
		elif area.interaction_id == "oren_charm_shrine":
			story_state.set_flag("oren_charm_returned", true)
			quests.complete_objective("side_childs_charm", "return_charm")
		elif area.interaction_id.begins_with("memorial_candle_"):
			var candle_name: String = str(area.interaction_id).trim_prefix("memorial_candle_")
			story_state.set_flag("candle_%s_lit" % candle_name, true)
			if bool(story_state.get_flag("candle_bram_lit", false)) and bool(story_state.get_flag("candle_sella_lit", false)) and bool(story_state.get_flag("candle_oren_lit", false)):
				story_state.set_flag("three_candles_lit", true)
			var candle_visual := area.get_node_or_null("MemorialCandleVisual") as Node3D
			if candle_visual != null:
				candle_visual.reparent(zone_root, true)
				candle_visual.name = "LitMemorialCandle_%s" % candle_name
				var flame := candle_visual.get_node_or_null("Flame") as MeshInstance3D
				if flame != null:
					flame.visible = true
			quests.complete_objective("side_three_candles", "light_%s" % candle_name)
		elif area.interaction_id == "sacrifice_roots":
			story_state.set_flag("mira_garden_inspected", true)
		else:
			quests.complete_evidence(area.quest_id, area.objective_id)
		story_state.record_evidence(str(area.interaction_id), {"zone": current_zone_id, "kind": "fact", "title": str(area.prompt)})
		if area.interaction_id == "tracks":
			if quests.is_objective_done("main_road_of_crows", "fight_ghoulkin"):
				hud.toast("The tracks change after the Ghoulkin falls: boots beside claws, both leading back toward Greyfen.")
				_show_current_objective_guidance(5.5)
				audio.play_event("tracks_found", 0.02)
				audio.play_voice("voice_player_return_report_01")
				audio.set_music_state("return_report")
			else:
				hud.toast("The tracks pass untouched food and lead toward the tokens. These things are following names, not hunger.", 5.5)
				audio.play_voice("voice_player_clue_observation_01")
			audio.play_event("reveal", 0.02)
		elif area.interaction_id == "corpse":
			hud.toast("Bram's ledger. A page of debts, all crossed out. His hand still grips the cart brake.", 5.5)
		elif area.interaction_id == "claw_marks":
			hud.toast("Vargan binding wire. Someone fastened a name to these creatures, then tried to burn it off.", 5.5)
		elif area.interaction_id == "black_feathers":
			hud.toast("Sella's red thread. The knot is Anwen's. The feathers were tied here, not scattered by a bird.", 5.5)
		elif area.interaction_id == "oren_token":
			hud.toast("Oren's wooden crow. The wings are worn smooth; only his name has been scraped away.", 5.5)
		elif area.interaction_id == "chapel_names":
			story_state.set_flag("chapel_names_read", true)
			_try_complete_oren_thread_trace()
			hud.toast("The chapel lists Bram and Sella. Oren's name was cut away, but the red thread still marks his place.")
			_show_current_objective_guidance(6.0)
			audio.play_event("reveal", 0.02)
		elif area.interaction_id == "ritual_stones":
			quests.complete_objective("main_teeth_in_rain", "name_the_dead")
			story_state.set_flag("oren_name_spoken", true)
			_try_complete_oren_thread_trace()
			hud.toast("Kael speaks Oren's name. Something deeper in Wychwood answers.")
			_show_current_objective_guidance(6.0)
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
		elif area.interaction_id == "rooks_false_road":
			hud.toast("Rook's older road is still here. The newer waystone hides where the refugees were sent.")
		elif area.interaction_id == "hidden_ash_measure":
			story_state.set_flag("ash_measure_recovered", true)
			hud.toast("The hidden measure weighs Greyfen's harvest against missing refugee wagons.")
		elif area.interaction_id == "deserters_muster":
			story_state.set_flag("deserters_muster_read", true)
			hud.toast("The deserters signed their refusal beneath an order to erase the refugee names.")
		elif area.interaction_id == "empty_grave_tracks":
			quests.complete_objective("side_empty_grave", "follow_empty_grave")
			if current_zone_id == "greyfen":
				GreyfenSection.new().publish_returned_soldier(ZoneBuildContext.new(self, "greyfen"))
			hud.toast("Bare footprints leave the grave and stop beside the old road.")
			_show_current_objective_guidance(5.0)
		elif area.interaction_id == "oren_charm_shrine":
			hud.toast("Oren's name has a place now. The red thread no longer marks an absence.")
		elif area.interaction_id.begins_with("memorial_candle_"):
			hud.toast("A candle burns for %s. The road keeps a name." % area.interaction_id.trim_prefix("memorial_candle_").capitalize())
		elif area.interaction_id == "bandit_camp":
			hud.toast("Boot prints. Rope. A child's torn ribbon. Not a dog's work.")
		elif area.interaction_id == "sheepfold":
			hud.toast("Human boot prints leave the fold beside smaller paw marks. Follow both into Wychwood.")
		elif area.interaction_id == "bitter_roots":
			quests.complete_objective("side_bitter_roots", "collect_roots")
			story_state.set_flag("bitter_roots_collected", true)
		elif area.interaction_id == "sacrifice_roots":
			hud.toast("The roots drink from old blood. Mira knew this place.")
		elif area.interaction_id == "post_victory_token":
			story_state.set_flag("road_token_recovered", true)
			_try_complete_oren_thread_trace()
			hud.toast("Oren's token is complete. Vargan binding wire is wound through the scratched name.")
			_show_current_objective_guidance(6.0)
			audio.play_event("reveal", 0.02)
		elif area.interaction_id == "chapel_door":
			story_state.set_flag("crow_chapel_opened", true)
			hud.toast("The chapel seal yields. The Crow Shrine inside is still bound to the erased names.")
			_show_current_objective_guidance(6.0)
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
		StoryWorldDirector.refresh(self)
		story_save_pending = true
		call_deferred("_persist_story_action")
		_mark_interaction_removed(area)
		if area.interaction_id.begins_with("memorial_candle_"):
			area.queue_free()
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
			if bool(story_state.get_flag("opening_coat_sheltered", false)) and not bool(story_state.get_flag("opening_coat_recalled", false)):
				story_state.set_flag("opening_coat_recalled", true)
				hud.set_guidance_hint("His coat is still on Anwen's bench. Someone mended the sleeve expecting him home.", 10.0)
			_try_complete_oren_thread_trace()
		"claw_marks":
			quests.complete_evidence("main_road_of_crows", "vargan_wire")
			story_state.set_flag("road_evidence_vargan_wire", true)
		"tracks":
			quests.complete_evidence("main_road_of_crows", "drag_marks")
			story_state.set_flag("road_evidence_drag_marks", true)
	if _road_evidence_count() >= 5 and not bool(story_state.get_flag("all_road_evidence", false)):
		story_state.set_flag("all_road_evidence", true)
		if quests.is_objective_done("main_road_of_crows", "fight_ghoulkin"):
			hud.toast("Every clue agrees: the pack followed the names, not the food.")
		else:
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
	_make_named_interactable("crow_shrine_choice", "dialogue", "Choose the Crow Shrine's fate", CemeterySection.CROW_SHRINE_INTERACTION_STAGE, Color(0.3,0.38,0.3), Vector3(0.45,0.45,0.45))

func _restore_greyfen_cemetery_state() -> void:
	if not quests.is_active("main_bell_beneath_greyfen"):
		# Shrine choice completes the quest, not the undefeated encounter.
		if bool(story_state.get_flag("crow_chapel_opened", false)):
			_ensure_bell_eater()
		return
	_relocate_anwen_to_cemetery()
	if _crow_shrine_choice_ready():
		_spawn_crow_shrine_choice()
		_ensure_bell_eater()
	else:
		_ensure_cemetery_ambush()

func _relocate_anwen_to_cemetery() -> void:
	if zone_root == null:
		return
	var anwen = zone_root.find_child("sister_anwen", true, false)
	if anwen == null:
		return
	var requested_position: Vector3 = CemeterySection.ANWEN_CEMETERY_STAGE
	var safe_position: Vector3 = Vector3(spatial_service.validate_position(requested_position, 0.85, spatial_service.bank_for(requested_position)))
	# This is an authored flat cemetery stage. A generic downward ray can hit
	# the nearby wall/roof collision and float Anwen above the graves.
	safe_position.y = 0.0
	anwen.global_position = safe_position + Vector3.UP * 0.02
	anwen.set("prompt", "Meet Sister Anwen at the cemetery gate")
	_face_npc_toward_player(anwen)

func _handle_dialogue_action(action: Dictionary) -> void:
	if str(action.get("type", "")) == "story_travel":
		preload("res://scripts/story_activity_director.gd").travel(self, action)
		return
	if not _dialogue_action_available(action):
		_apply_dialogue_action(action)
		return
	if str(action.get("type", "")) == "story_choice":
		var choice_id := str(action.get("choice_id", "%s:%s" % [action.get("quest", ""), action.get("objective", "")]))
		if choice_id == ":":
			var effect_keys: Array = action.get("sets_flags", {}).keys()
			effect_keys.sort()
			choice_id = "promise:" + ",".join(effect_keys)
		save_manager.predecision(self, choice_id)
	var transaction := StoryDecisionCoordinator.new()
	transaction.begin(self)
	var applied: bool = _apply_dialogue_action(action)
	transaction.finish(self, action, applied)

func _finish_story_action(action: Dictionary) -> void:
	if not game_started or resource_shutdown_prepared:
		return
	if action.get("sets_flags", {}).has("evidence_report"):
		story_state.set_flag("cemetery_bell_rung", true)
		story_state.set_flag("legacy_report_choice_required", false)
		_relocate_anwen_to_cemetery()
	if action.get("sets_flags", {}).has("mira_truth"):
		story_state.set_flag("mira_truth_known", true)
	if action.get("sets_flags", {}).has("confession_method"):
		story_state.set_flag("renewal_stopped", true)
	StoryWorldDirector.refresh(self)
	_refresh_tracker()
	if str(action.get("type", "")) in ["story_choice", "resolve_side_quest", "ending"]:
		var receipt: Dictionary = preload("res://scripts/story_choice_presenter.gd").receipt(action, story_state, quests, current_zone_id)
		if not receipt.is_empty():
			hud.show_decision_result(receipt)
	if audio != null and not _story_has_active_combat():
		audio.set_story_context(story_state, current_zone_id)
	story_save_pending = true
	call_deferred("_persist_story_action")

func _persist_story_action() -> void:
	if not story_save_pending or resource_shutdown_prepared or not game_started:
		return
	if _journey_load_pending():
		return
	if zone_transition_pending or zone_load_request_pending or not pending_player_restore.is_empty():
		return
	story_save_pending = false
	save_manager.checkpoint(self)
	save_manager.autosave(self)

func _story_has_active_combat() -> bool:
	for enemy in active_enemies:
		if is_instance_valid(enemy) and not enemy.dead and player != null:
			if enemy.global_position.distance_squared_to(player.global_position) < 100.0:
				return true
	return false

func _apply_dialogue_action(action: Dictionary) -> bool:
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
		return false
	if type == "opening_care_account":
		var opening_anwen := zone_root.find_child("sister_anwen", true, false) as Node3D
		if current_zone_id == "greyfen" and opening_anwen != null:
			story_state.set_flag("opening_care_introduced", true)
			call_deferred("_handle_interaction", opening_anwen)
	elif type == "opening_care_resume":
		var care_hint := "Oren's coat is on the bench. Anwen can tell you about the road whenever you are ready." if bool(story_state.get_flag("opening_cup_delivered", false)) else "The cup is on the low step. Anwen can tell you about the road whenever you are ready."
		hud.set_guidance_hint(care_hint, 8.0)
	elif type == "start_quest":
		quests.start_quest(action.get("quest", ""))
		if str(action.get("quest", "")) == "side_childs_charm":
			_try_complete_oren_thread_trace(false)
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
			_show_current_objective_guidance(6.0)
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
		else:
			return false
	elif type == "story_choice":
		if action.get("sets_flags", {}).has("crow_shrine_state") and str(story_state.get_flag("crow_shrine_state", "")) != "":
			hud.toast("The Crow Shrine has already answered Kael's choice.")
			return false
		if action.get("sets_flags", {}).has("bog_core_fate") and str(story_state.get_flag("bog_core_fate", "")) != "":
			hud.toast("The memory core has already been given a fate.")
			return false
		# Every consequential story choice is one-shot. The flag guard above
		# covers legacy one-off choices with custom wording; the objective guard
		# keeps names, mill, testimony, ledger, and ending decisions from being
		# replayed through a stale dialogue node or a saved interaction prompt.
		var choice_quest_id := str(action.get("quest", ""))
		var choice_objective_id := str(action.get("objective", ""))
		if choice_quest_id != "" and choice_objective_id != "" and quests.is_objective_done(choice_quest_id, choice_objective_id) and not (choice_quest_id == "main_road_of_crows" and _legacy_report_choice_required()):
			hud.toast("That decision has already been made.")
			return false
		for id in action.get("sets_flags", {}):
			story_state.set_flag(str(id), action["sets_flags"][id])
		for id in action.get("adjusts_values", {}):
			story_state.adjust_value(str(id), int(action["adjusts_values"][id]))
		if action.has("quest") and action.has("objective"):
			quests.complete_choice(str(action["quest"]), str(action["objective"]))
		for completion in action.get("completes", []):
			quests.complete_choice(str(completion.get("quest", "")), str(completion.get("objective", "")))
		for item_id in action.get("gives_items", {}):
			inventory.add_item(str(item_id), int(action["gives_items"][item_id]))
		if action.get("sets_flags", {}).has("crow_shrine_state"):
			hud.show_status_cue("The covenant changes", "victory")
			_show_current_objective_guidance(6.0)
			if active_interactable != null and str(active_interactable.get("interaction_id")) == "crow_shrine_choice":
				_mark_interaction_removed(active_interactable)
				active_interactable.queue_free()
				active_interactable = null
		elif action.get("sets_flags", {}).has("bog_core_fate"):
			hud.show_status_cue("Memory given a fate", "victory")
			_show_current_objective_guidance(6.0)
			if active_interactable != null and str(active_interactable.get("interaction_id")) == "bog_core_choice":
				_mark_interaction_removed(active_interactable)
				active_interactable.queue_free()
				active_interactable = null
		elif action.get("sets_flags", {}).has("names_policy"):
			hud.show_status_cue("The names have a new public life", "victory")
			_show_current_objective_guidance(6.0)
			_consume_story_choice_interactable("names_decision")
		elif action.get("sets_flags", {}).has("mill_fate"):
			hud.show_status_cue("The mill's record is settled", "victory")
			_show_current_objective_guidance(6.0)
			_consume_story_choice_interactable("miller_record")
		elif action.get("sets_flags", {}).has("senn_fate"):
			if not StoryActorPresence.remains("captain_senn", str(story_state.get_flag("senn_fate", ""))):
				_consume_story_choice_interactable("captain_senn")
		elif action.get("sets_flags", {}).has("confession_method") and current_zone_id == "assembly":
			if not _has_interactable("gate_hart_glade"):
				_make_zone_gate("Walk the reopened road", Vector3(7, 0, -14), "hart_glade", Vector3(0, 1, 12))
			_show_current_objective_guidance(6.0)
		if action.get("sets_flags", {}).has("halvern_fate"):
			var halvern_outcome := str(action["sets_flags"]["halvern_fate"])
			_publish_halvern_exit()
			for boss in active_enemies:
				if not is_instance_valid(boss) or boss.enemy_id != "halvern_boss":
					continue
				var controller: Node = boss.get_node_or_null("BossEncounterController")
				if controller != null and controller.has_method("resolve_peaceful"):
					controller.resolve_peaceful(halvern_outcome)
				break
			if not StoryActorPresence.remains("halvern", halvern_outcome):
				_consume_story_choice_interactable("halvern")
		if str(action.get("quest", "")) == "main_blood_under_stone" and str(action.get("objective", "")) == "ledger_choice":
			story_state.set_flag("vargan_ledger_found", true)
			story_state.set_flag("vargan_ledger_choice_made", true)
			story_state.set_flag("record_hall_unlocked", true)
			_show_current_objective_guidance(5.0)
	elif type == "ending":
		return _complete_ending(action.get("ending", "expose"))
	else:
		return false
	if audio != null:
		audio.set_game_paused(false)
	get_tree().paused = false
	hud.hide_menus()
	_refresh_tracker()
	# Dialogue choices usually mutate state that is already reflected in-place.
	# Rebuilding the same zone for those actions creates an avoidable Web
	# lifecycle handoff and can leave control pending while the retired root is
	# still being collected. Only quest starts and objective completions that can
	# add gated world content need a composition rebuild.
	var refresh_zone_after_action := _dialogue_action_requires_zone_rebuild(action)
	if refresh_zone_after_action and current_zone_id != "":
		_load_zone(current_zone_id, player.global_position)
	return true

func _dialogue_action_requires_zone_rebuild(action: Dictionary) -> bool:
	var action_type := str(action.get("type", ""))
	if action_type == "story_choice":
		# The ledger decision changes the active Record Hall composition: the
		# haunting and its post-choice handoff are authored by the zone builder.
		# Rebuild this one stateful choice so the new encounter appears without
		# requiring the player to leave and re-enter the hall.
		return str(action.get("quest", "")) == "main_blood_under_stone" \
			and str(action.get("objective", "")) == "ledger_choice"
	if action_type in ["give_ingredients", "resolve_side_quest"]:
		return false
	if action_type == "complete_objective":
		# These two opening interactions update their visible state directly.
		# Rebuilding them would retire the active Greyfen root for no spatial gain.
		var quest_id := str(action.get("quest", ""))
		var objective_id := str(action.get("objective", ""))
		if quest_id == "main_road_of_crows" and objective_id == "speak_anwen":
			return false
		if quest_id == "main_teeth_in_rain" and objective_id == "speak_mira":
			return false
		return true
	return action_type == "start_quest"

func _dialogue_action_available(action: Dictionary) -> bool:
	if action.get("sets_flags", {}).has("halvern_fate"):
		var yielding := bool(story_state.get_flag("halvern_guard_broken", false)) or bool(story_state.get_flag("command_proof_recovered", false)) or bool(story_state.get_flag("halvern_surrender_protected", false)) or str(story_state.get_flag("halvern_fate", "")) == "defeated"
		if not yielding:
			return false
	if not dialogue._conditions_match(action.get("conditions", {})):
		return false
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
		if quest_id == "main_road_of_crows" and objective_id == "return_village" and _legacy_report_choice_required():
			return true
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

func _on_launch_accepted() -> void:
	if startup_packs_waiting or greyfen_prewarm_started or game_started:
		return
	opening_prepare_generation += 1
	if runtime_packs != null:
		runtime_packs.quality_preset = str(settings.settings.get("quality_preset", "balanced"))
	audio.play_event("ui", 0.0)
	var retry_failed := startup_prepare_failed
	startup_prepare_failed = false
	_publish_web_opening_state("preparing", "Preparing Greyfen...")
	if hud != null and hud.has_method("set_new_game_status"):
		hud.set_new_game_status("Greyfen is waking. New Game remains available while it prepares.")
	# Keep the same menu-covered prewarm on Web and desktop. The HTML shell is
	# already visible, so moving Greyfen construction before the New Game click
	# removes the long post-click stall without introducing a black loading frame.
	# Keep New Game actionable while the menu-covered prewarm runs. _new_game()
	# records the request and starts it as soon as the prepared Greyfen cache is
	# published; disabling the button here made the queue path unreachable to a
	# real mouse or controller click.
	if hud != null and hud.has_method("set_new_game_ready") and not route_zone_cache.has("greyfen"):
		hud.set_new_game_ready(true)
	if OS.has_feature("web") and runtime_packs != null and runtime_packs.has_method("request_startup_packs"):
		if runtime_packs.startup_packs_ready():
			print("LOADING: startup_pack_ready source=launch")
			_begin_opening_prewarm()
			return
		if startup_packs_waiting:
			return
		startup_packs_waiting = true
		if runtime_packs.has_signal("pack_ready") and not runtime_packs.pack_ready.is_connected(_on_startup_pack_ready):
			runtime_packs.pack_ready.connect(_on_startup_pack_ready)
		runtime_packs.request_startup_packs(retry_failed)
		# request_startup_packs may mount a cache immediately, before the
		# signal connection above can observe a later state change. Recheck on
		# the next idle frame as well as through pack_ready.
		call_deferred("_begin_opening_prewarm_if_ready")
		# Cached Web packs can complete synchronously. The signal path handles
		# asynchronous downloads without depending on a paused-tree frame.
		call_deferred("_wait_for_startup_packs_then_prewarm", opening_prepare_generation)
		return
	if not greyfen_prewarm_started and not game_started:
		_begin_opening_prewarm()

func _on_startup_pack_ready(_pack_id: String) -> void:
	if game_started or startup_prepare_failed or not startup_packs_waiting or runtime_packs == null:
		return
	if not runtime_packs.startup_packs_ready():
		return
	print("LOADING: startup_pack_ready source=signal id=%s" % _pack_id)
	startup_packs_waiting = false
	_begin_opening_prewarm()

func _begin_opening_prewarm_if_ready() -> void:
	if game_started or greyfen_prewarm_started or runtime_packs == null:
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
			if hud != null:
				hud.toast("Opening content could not be prepared. Select New Game to retry.")
			_opening_prepare_failed("Opening content could not be prepared. Select New Game to retry.")
			return
		await get_tree().process_frame
	startup_packs_waiting = false
	if hud != null:
		hud.toast("Opening content took too long to prepare. Select New Game to retry.")
	_opening_prepare_failed("Opening content took too long to prepare. Select New Game to retry.")

func _begin_opening_prewarm() -> void:
	if game_started or greyfen_prewarm_started or route_zone_cache.has("greyfen"):
		return
	# A returning player needs the saved world, not a disposable New Game world.
	# Explicit New Game still takes the normal queued/prewarmed path.
	if not new_game_start_pending and hud != null and hud._has_continue_save():
		var generation := opening_prepare_generation
		hud.set_new_game_status("Continue your saved journey, or begin a new one.")
		hud.set_boot_shell_cover_active(false)
		if OS.has_feature("web"):
			# Saved journeys skip world prewarm, but still need the rendered menu
			# handoff that releases the HTML loading cover.
			await RenderingServer.frame_post_draw
			if not _opening_attempt_current(generation):
				return
			await get_tree().process_frame
			if not _opening_attempt_current(generation):
				return
			_publish_web_opening_state("ready", "Continue your saved journey, or begin a new one.")
		return
	greyfen_prewarm_started = true
	world_materials.begin_prewarm_attempt()
	asset_helper.begin_resource_attempt()
	# Both platforms now own the opening pack before requesting its resources.
	if DisplayServer.get_name().to_lower() != "headless":
		world_materials.prewarm_surfaces(["forest_ground", "cobblestone", "wet_mud", "medieval_brick", "plaster", "timber", "roof_tiles"], str(settings.settings.get("quality_preset", "balanced")))
		var props_status: Error = asset_helper.request_resource_paths(CharacterPresentation.OPENING_OCCUPATION_PROP_PATHS)
		if props_status != OK:
			_opening_prepare_failed("Greyfen's opening props could not be prepared. Select New Game to retry.")
			return
	if not OS.has_feature("web") and DisplayServer.get_name().to_lower() != "headless":
		var named_roles: Array[String] = []
		for actor_id in OPENING_NAMED_ACTOR_IDS:
			named_roles.append(_role_for_interactable(actor_id))
		var actors_status: Error = asset_helper.request_role_resources(named_roles)
		if actors_status != OK:
			_opening_prepare_failed("Greyfen's opening characters could not be prepared. Select New Game to retry.")
			return
	# Opening resources have mounted before this point on Web. Later character,
	# monster and campaign packs remain independent of menu readiness.
	print("LOADING: Greyfen prewarm begin")
	call_deferred("_prepare_opening_resources", opening_prepare_generation)

func _opening_attempt_current(generation: int) -> bool:
	return generation == opening_prepare_generation and not resource_shutdown_prepared and not game_started

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
				_opening_prepare_failed("Greyfen's authored resources could not be prepared. Select New Game to retry.")
				return
			await get_tree().process_frame
	if _opening_attempt_current(generation):
		_prewarm_greyfen_after_menu_frame(generation)

func _discard_menu_opening() -> void:
	opening_prepare_generation += 1
	_clear_route_zone_cache()
	_abort_opening_prewarm(zone_root, greyfen_prewarm_spatial_service, "Preparing Greyfen...")

func _restart_menu_opening() -> void:
	if game_started:
		return
	_discard_menu_opening()
	var generation := opening_prepare_generation
	await get_tree().process_frame
	if _opening_attempt_current(generation):
		_on_launch_accepted()

func _opening_prepare_failed(message: String) -> void:
	opening_prepare_generation += 1
	startup_packs_waiting = false
	greyfen_prewarm_started = false
	startup_prepare_failed = true
	if hud != null and hud.has_method("set_new_game_ready"):
		hud.set_new_game_ready(true)
	if hud != null and hud.has_method("set_new_game_status"):
		hud.set_new_game_status(message)
	if hud != null and hud.has_method("set_boot_shell_cover_active"):
		hud.set_boot_shell_cover_active(false)
	_publish_web_opening_state("failed", message)

func _abort_opening_prewarm(prewarm_root: Node3D, prewarm_service: Node, message: String) -> void:
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
	_opening_prepare_failed(message)

func _publish_web_opening_state(state: String, message: String = "") -> void:
	if not OS.has_feature("web"):
		return
	var payload := JSON.stringify({
		"state": state,
		"message": message,
		"timestamp_ms": Time.get_ticks_msec(),
	})
	JavaScriptBridge.eval("window.__ashenOathOpeningState = %s;" % payload, false)

func _prewarm_greyfen_after_menu_frame(generation: int = -1) -> void:
	if generation < 0:
		generation = opening_prepare_generation
	if not _opening_attempt_current(generation):
		return
	# Start immediately after the launch shell is accepted. Deferring the first
	# build frame allowed a fast test click (and a fast human click) to race the
	# prewarm and fall back to a cold Greyfen build. The launch/menu presentation
	# is already covering the viewport, so doing the construction here makes the
	# later New Game action deterministic without adding a second loading stall.
	if game_started or zone_root != null or route_zone_cache.has("greyfen"):
		return
	# Prepare required scenery under the cover on both platforms. Only small
	# dressing and additional population stages remain after the handoff.
	var prewarm_started := Time.get_ticks_msec()
	print("LOADING: Greyfen prewarm build_begin")
	var phase_started := prewarm_started
	var prewarm_service := ZoneSpatialService.new()
	prewarm_service.name = "GreyfenPrewarmSpatialService"
	add_child(prewarm_service)
	prewarm_service.configure("greyfen", _river_center("greyfen"), _zone_half_extents("greyfen"))
	spatial_service = prewarm_service
	zone_root = Node3D.new()
	zone_root.name = "greyfen"
	zone_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(zone_root)
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
	var prewarm_build := ZoneCompositionRouter.build_core(self, "greyfen", "opening_boot")
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
	phase_started = Time.get_ticks_msec()
	for visual_bucket in range(OPENING_GAMEPLAY_VISUAL_BUCKETS):
		ZoneCompositionRouter.build_core_detail_stage(self, "greyfen", "gameplay_visual_%d" % visual_bucket)
	_flush_environment_batches()
	_add_visual_100_layer("greyfen")
	_apply_first_route_materials(zone_root)
	# These are correctness passes, not prerequisites for the first player frame.
	# Publish a valid cache now and finish them after handoff so a menu click does
	# not inherit a synchronous navigation or recursive renderer walk.
	prewarm_root.set_meta("prewarm_navigation_pending", true)
	prewarm_root.set_meta("opening_build_profile", "opening_boot")
	_clear_environment_batch_buffers()
	var world_finalize_ms := Time.get_ticks_msec() - phase_started
	greyfen_prewarm_spatial_service = prewarm_service
	# Kael's rig and camera are also expensive to instantiate in WebGL. Prepare
	# them while the launch/menu presentation is already covering the viewport.
	phase_started = Time.get_ticks_msec()
	_spawn_player(Vector3(0, 1, 9.8))
	camera_rig.prepare_view()
	var player_ms := Time.get_ticks_msec() - phase_started
	# Keep the real gameplay view active behind the opaque menu so WebGL compiles
	# the same skinned materials and camera path used after New Game.
	player.visible = true
	player.set_transition_locked(true)
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	camera_rig.process_mode = Node.PROCESS_MODE_INHERIT
	var gameplay_camera := camera_rig.find_child("Camera3D", true, false) as Camera3D
	if gameplay_camera != null:
		gameplay_camera.current = true
	zone_root.visible = true
	zone_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	zone_root.position = Vector3.ZERO
	# `_load_zone()` applies this profile immediately before the first gameplay
	# draw. Render the same environment here under the HTML shell so WebGL does
	# not compile Greyfen's real sky and lighting only after New Game is clicked.
	if visual_director != null:
		visual_director.apply_zone("greyfen", prewarm_root)
		visual_director.set_opening_boot_budget(false)
		prewarm_root.set_meta("opening_visual_profile_prewarmed", true)
	var was_paused := get_tree().paused
	# A constructed scene is not render-ready: Compatibility compiles material
	# programs synchronously on first use. Keep queued clicks pending until the
	# real camera has rendered, rather than reporting that cost as warm travel.
	if DisplayServer.get_name().to_lower() != "headless":
		if hud != null and hud.has_method("set_new_game_status"):
			hud.set_new_game_status("Preparing Greyfen's first view...")
		# The menu pauses the tree, but the first gameplay frame evaluates Kael's
		# skeleton, animation driver, camera, and physics together. Give that exact
		# transition-locked state one covered frame so WebGL does not compile it
		# after the player clicks New Game.
		get_tree().paused = false
		await get_tree().process_frame
		if not _opening_attempt_current(generation):
			return
		await RenderingServer.frame_post_draw
		if not _opening_attempt_current(generation) or not is_instance_valid(prewarm_root):
			return
		prewarm_root.set_meta("opening_unpaused_frame_prewarmed", true)
	# Complete first-use mesh and texture decoding under the menu cover. Doing
	# this after control is handed over causes visible 40-70 ms hydration frames.
	get_tree().paused = false
	opening_well_mesh = load("res://assets_external/environment/village/GreyfenWell_Authored.res") as ArrayMesh
	if opening_well_mesh == null or opening_well_mesh.get_surface_count() != 6:
		get_tree().paused = was_paused
		_abort_opening_prewarm(prewarm_root, prewarm_service, "Greyfen's authored well could not be prepared. Select New Game to retry.")
		return
	var slice_started := Time.get_ticks_usec()
	for covered_stage in OPENING_DETAIL_STAGES:
		if not _opening_stage_required_before_control(covered_stage):
			continue
		if not _opening_attempt_current(generation) or not is_instance_valid(prewarm_root):
			return
		environment_batches_flushed = false
		var covered_result := ZoneCompositionRouter.build_core_detail_stage(self, "greyfen", covered_stage)
		if not bool(covered_result.get("ok", false)):
			get_tree().paused = was_paused
			_abort_opening_prewarm(prewarm_root, prewarm_service, "Greyfen's opening scene could not be prepared. Select New Game to retry.")
			return
		_flush_environment_batches()
		_clear_environment_batch_buffers()
		environment_batches_flushed = true
		_record_opening_stage(prewarm_root, covered_stage)
		if Time.get_ticks_usec() - slice_started >= OPENING_BUILD_SLICE_USEC:
			await get_tree().process_frame
			slice_started = Time.get_ticks_usec()
	if not _opening_attempt_current(generation):
		return
	if not _opening_presentation_present(prewarm_root):
		get_tree().paused = was_paused
		_abort_opening_prewarm(prewarm_root, prewarm_service, "Greyfen's scenery is incomplete. Select New Game to retry.")
		return
	if visual_director != null:
		visual_director.refresh_zone_lighting(prewarm_root)
	camera_rig.prepare_view()
	if DisplayServer.get_name().to_lower() != "headless":
		await get_tree().process_frame
		if not _opening_attempt_current(generation):
			return
		await RenderingServer.frame_post_draw
		if not _opening_attempt_current(generation):
			return
		prewarm_root.set_meta("opening_first_frame_rendered", true)
	prewarm_root.set_meta("opening_presentation_ready", true)
	get_tree().paused = was_paused
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
	if hud != null and hud.has_method("set_new_game_status"):
		hud.set_new_game_status("Greyfen is ready.")
	if hud != null and hud.has_method("set_boot_shell_cover_active"):
		hud.set_boot_shell_cover_active(false)
	# Keep the HTML shell over the canvas until the prepared Godot menu has
	# completed one real draw. Publishing readiness in the same tick as the
	# reveal lets the shell disappear onto an uncompiled black frame in WebGL.
	await RenderingServer.frame_post_draw
	if not _opening_attempt_current(generation):
		return
	await get_tree().process_frame
	if not _opening_attempt_current(generation):
		return
	greyfen_prewarm_started = false
	_publish_web_opening_state("ready", "Greyfen is ready.")
	print("LOADING: opening_menu_render_ready")
	print("LOADING: Greyfen prewarmed total=%dms build=%dms world=%dms player=%dms" % [
		Time.get_ticks_msec() - prewarm_started, build_ms, world_finalize_ms, player_ms,
	])
	if new_game_start_pending:
		get_tree().paused = false
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
		await get_tree().process_frame
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
		await get_tree().process_frame
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
			call_deferred("_run_opening_detail_stage", generation)
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
			call_deferred("_run_opening_detail_stage", generation)
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
				call_deferred("_run_opening_detail_stage", generation)
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
				call_deferred("_run_opening_detail_stage", generation)
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
				call_deferred("_run_opening_detail_stage", generation)
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
			call_deferred("_run_opening_detail_stage", generation)
			return
	# Each stage gets fresh buffers. Published MultiMeshes remain untouched,
	# while late decoration is still grouped instead of creating one
	# renderer instance per small prop.
	environment_batches_flushed = false
	var published_ids := {}
	for child in zone_root.get_children():
		published_ids[child.get_instance_id()] = true
	var result := ZoneCompositionRouter.build_core_detail_stage(self, "greyfen", stage)
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
			life.configure(self, str(settings.settings.get("quality_preset", "balanced")))
	_record_opening_stage(zone_root, stage)
	opening_detail_stage_index += 1
	print("LOADING: Greyfen deferred_detail stage=%s ms=%d" % [stage, Time.get_ticks_msec() - started])
	# Yield between chunks so movement, focus, and audio get a normal frame even
	# on Web/ANGLE. A generation token cancels the continuation on zone travel.
	call_deferred("_run_opening_detail_stage", generation)

func _defer_opening_renderables(published_nodes: Array[Node]) -> void:
	var visual_index := 0
	for published in published_nodes:
		for descendant in published.find_children("*", "", true, false):
			if not descendant is VisualInstance3D or not descendant.visible:
				continue
			descendant.visible = false
			descendant.set_meta("opening_visual_bucket", visual_index % OPENING_GAMEPLAY_VISUAL_BUCKETS)
			visual_index += 1

func _complete_ending(ending: String) -> bool:
	var ending_id := str(ending)
	if ending_id not in ["expose", "free", "bind", "kill"]:
		hud.toast("The covenant offers no such answer.")
		return false
	if str(story_state.get_flag("final_covenant", "")) != "" or bool(story_state.get_flag("final_choice_completed", false)):
		hud.toast("The covenant has already been chosen.")
		return false
	if not quests.is_active("main_hart_remembers") or str(story_state.get_flag("confession_method", "")) == "":
		hud.toast("The Hart will not answer until Greyfen has heard the testimony.")
		return false
	# Preserve the last freely revisitable moment in its own slot.
	save_manager.save_game(self, save_manager.PRE_COVENANT_PATH, "The moment before the covenant has been saved.")
	var witnesses: Array[String] = ["kael"]
	for witness in ["anwen", "rook", "mira", "edric", "halvern", "senn"]:
		if str(story_state.get_flag("witness_consent_" + witness, "")) == "voluntary":
			witnesses.append(witness)
	story_state.set_flag("final_witnesses", witnesses)
	story_state.set_flag("final_covenant", {"expose":"witness", "free":"mercy", "bind":"duty", "kill":"ash"}[ending_id])
	quests.world_flags["ending"] = ending_id
	quests.complete_objective("main_hart_remembers", "hear_testimony")
	if ending_id != "kill":
		CovenantResolution.begin(self, ending_id)
		return true
	pending_ending = ending_id
	story_state.set_flag("human_records_preserved", true)
	active_interactable = null
	hud.set_prompt("")
	hud.hide_menus()
	get_tree().paused = false
	audio.set_game_paused(false)
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
	hud.toast("The human record is safe. The Hart rises to defend the covenant.")
	return true

func _show_ending_consequence(ending: String) -> void:
	if bool(story_state.get_flag("final_choice_completed", false)):
		return
	story_action_in_progress = true
	story_state.begin_change()
	quests.begin_change()
	quests.world_flags["ending"] = ending
	story_state.set_flag("final_choice_completed", true)
	story_state.set_flag("covenant_ritual_ready", false)
	story_state.set_flag("renewal_stopped", true)
	pending_ending = ""
	quests.complete_choice("main_hart_remembers", "final_choice")
	var cards: Array[String] = EpilogueResolver.resolve(ending, story_state)
	story_state.set_flag("epilogue_cards", cards)
	quests.end_change()
	story_state.end_change()
	story_action_in_progress = false
	StoryWorldDirector.refresh(self)
	audio.set_story_context(story_state, current_zone_id)
	audio.set_game_paused(true)
	get_tree().paused = true
	hud.show_ending("The covenant is made", "The Hart has answered. The road behind you leads to Greyfen.\n\nReturn to the people who must live with this decision. There is still work to do, and lives to hear before this account is closed.")
	story_save_pending = true
	call_deferred("_persist_story_action")

func _show_completed_epilogue() -> void:
	if not bool(story_state.get_flag("final_choice_completed", false)):
		return
	var ending := str(quests.world_flags.get("ending", "expose"))
	var cards: Array[String] = EpilogueResolver.resolve(ending, story_state)
	story_state.set_flag("epilogue_cards", cards)
	story_state.set_flag("epilogue_presented", true)
	audio.set_dialogue_active(false)
	audio.set_game_paused(true)
	get_tree().paused = true
	hud.show_ending("The lives that continue", "\n\n".join(cards))
	story_save_pending = true
	call_deferred("_persist_story_action")

func _on_player_blade_contact(contact: Dictionary) -> void:
	var heavy := bool(contact.get("heavy", false))
	if bool(contact.get("first_sample", true)):
		audio.play_event("heavy" if heavy else "swing")
	var result: Dictionary = combat.resolve_player_blade_contact(player, active_enemies, contact, inventory.active_oil)
	player.confirm_blade_contact(int(contact.get("attack_id", -1)), bool(result.get("hit", false)))
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
		audio.play_spatial_event("heavy_hit" if heavy else "light_hit",
			result.get("contact_point", result.get("point", player.global_position)),
			player.global_position, 16.0, 0.045, 0.04)
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
	var query := PhysicsRayQueryParameters3D.create(origin, endpoint, 1)
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
	combat_vfx_coordinator.make_arrow_trail(zone_root, origin, endpoint, color)

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
	var query = PhysicsRayQueryParameters3D.create(origin, endpoint, 1)
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
	var reduce_flashes := bool(settings.settings.get("flash_reduction", false))
	combat_vfx_coordinator.make_oathfire_beam(zone_root, origin, endpoint, charge_ratio, rich_effect, reduce_flashes)

func _clear_oathfire_effects() -> void:
	combat_vfx_coordinator.clear_oathfire_effects()

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
	elif spatial_service != null and spatial_service.is_on_bridge(player.global_position):
		surface = "wood"
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
	_use_quick_item("redroot_potion")

func _throw_bomb() -> void:
	_use_quick_item("ash_bomb")

func _use_inventory_item(item_id: String) -> Dictionary:
	if player == null or not is_instance_valid(player) or inventory == null:
		return _preparation_item_result(item_id, false, "Kael must be on the road to prepare this item.")
	var item_name: String = inventory.get_item_name(item_id)
	if not inventory.can_consume(item_id):
		return _preparation_item_result(item_id, false, "No %s left." % item_name)
	if inventory.get_item_type(item_id) == "ammo":
		if player.get_selected_arrow_id() == item_id:
			return _preparation_item_result(item_id, false, "%s is already selected." % item_name, "select")
		var selected: bool = player.select_arrow(item_id)
		return _preparation_item_result(item_id, selected, "%s selected for the next shot." % item_name if selected else "These arrows cannot be selected.", "select")
	if inventory.get_item_type(item_id) == "oil":
		if str(inventory.active_oil) == item_id:
			return _preparation_item_result(item_id, false, "%s already coats the blade." % item_name, "apply")
		var applied: bool = inventory.apply_oil(item_id)
		return _preparation_item_result(item_id, applied, "%s coats the blade." % item_name if applied else "The coating could not be applied.", "apply")
	var effect: Dictionary = preload("res://scripts/preparation_view_model.gd").resolved_effect(item_id, inventory, progression)
	if item_id == "redroot_potion":
		var missing_health: float = maxf(0.0, player.health_component.max_health - player.health_component.health)
		if missing_health <= 0.0:
			return _preparation_item_result(item_id, false, "Health is full. Redroot remains in your pack.")
		if not inventory.consume(item_id):
			return _preparation_item_result(item_id, false, "No Redroot remains.")
		var restored: float = minf(missing_health, float(effect.get("heal", 45.0)))
		player.health_component.heal(restored)
		audio.play_event("potion")
		return _preparation_item_result(item_id, true, "Redroot restored %s health." % str(snappedf(restored, 0.1)), "use", 1)
	if item_id == "bitterleaf_tonic":
		var missing_stamina: float = maxf(0.0, player.stamina_component.max_stamina - player.stamina_component.stamina)
		if missing_stamina <= 0.0:
			return _preparation_item_result(item_id, false, "Stamina is full. Bitterleaf remains in your pack.")
		if not inventory.consume(item_id):
			return _preparation_item_result(item_id, false, "No Bitterleaf remains.")
		var restored: float = minf(missing_stamina, float(effect.get("stamina", 55.0)))
		player.stamina_component.restore(restored)
		audio.play_event("potion")
		return _preparation_item_result(item_id, true, "Bitterleaf restored %s stamina." % str(snappedf(restored, 0.1)), "use", 1)
	if item_id == "ash_bomb":
		if not inventory.consume(item_id):
			return _preparation_item_result(item_id, false, "No Ash Bomb remains.")
		audio.play_event("bomb")
		if camera_rig != null:
			camera_rig.shake(0.12)
		combat.throw_bomb(player, active_enemies, float(effect.get("damage", 45.0)))
		for enemy in active_enemies:
			if is_instance_valid(enemy) and not enemy.dead and enemy.enemy_id == "bog_wretch" and enemy.global_position.distance_to(player.global_position) <= 6.5:
				_expose_bog_core(enemy, "Ash Bomb")
		return _preparation_item_result(item_id, true, "Ash Bomb thrown.", "use", 1)
	if item_id == "iron_trap":
		if not inventory.consume(item_id):
			return _preparation_item_result(item_id, false, "No Iron Trap remains.")
		combat.place_trap(player, active_enemies)
		return _preparation_item_result(item_id, true, "Iron Trap set at your feet.", "use", 1)
	return _preparation_item_result(item_id, false, "This item has no preparation action.")

func _preparation_item_result(item_id: String, ok: bool, message: String, operation: String = "use", consumed: int = 0) -> Dictionary:
	return {
		"ok": ok, "operation": operation, "item_id": item_id,
		"quantity": consumed, "message": message, "reason": "" if ok else message,
		"spent": {"items": {item_id: consumed}} if consumed > 0 else {},
		"remaining": {"items": inventory.items.duplicate(true), "coin": int(inventory.coin)} if inventory != null else {}
	}

func _update_preparation_context() -> void:
	var snapshot: Dictionary = {"zone_id": current_zone_id}
	if player != null and is_instance_valid(player):
		snapshot.merge({
			"health": float(player.health_component.health), "max_health": float(player.health_component.max_health),
			"stamina": float(player.stamina_component.stamina), "max_stamina": float(player.stamina_component.max_stamina),
			"weapon_mode": str(player.get_weapon_mode()), "selected_arrow_id": str(player.get_selected_arrow_id())
		})
	hud.set_preparation_context(snapshot)

func _show_preparation_menu() -> void:
	_update_preparation_context()
	hud.show_inventory(inventory, quests, story_state, progression)

func _craft_preparation_item(item_id: String) -> void:
	preparation_action_in_progress = true
	var result: Dictionary = crafting.craft_result(item_id)
	preparation_action_in_progress = false
	_finish_preparation_operation(result)

func _use_preparation_item(item_id: String) -> void:
	preparation_action_in_progress = true
	var result: Dictionary = _use_inventory_item(item_id)
	preparation_action_in_progress = false
	_finish_preparation_operation(result)

func _learn_preparation_practice(upgrade_id: String) -> void:
	preparation_action_in_progress = true
	var result: Dictionary = progression.unlock_result(upgrade_id)
	preparation_action_in_progress = false
	if bool(result.get("ok", false)):
		_apply_progression_to_player()
	_finish_preparation_operation(result)

func _use_quick_item(item_id: String) -> void:
	preparation_action_in_progress = true
	var result: Dictionary = _use_inventory_item(item_id)
	preparation_action_in_progress = false
	var ok: bool = bool(result.get("ok", false))
	hud.post_notice(str(result.get("message", "")), "inventory" if ok else "error", 3.5, "quick:" + item_id)
	if ok:
		_refresh_equipment_readout()
		story_save_pending = true
		call_deferred("_persist_story_action")

func _finish_preparation_operation(result: Dictionary, vendor_id: String = "") -> void:
	if bool(result.get("ok", false)):
		_refresh_equipment_readout()
		story_save_pending = true
		call_deferred("_persist_story_action")
	# Let the currently pressed control finish its event before rebuilding it.
	var screen_key: String = hud.preparation_screen_key()
	call_deferred("_refresh_preparation_after_operation", result, vendor_id, screen_key)

func _refresh_preparation_after_operation(result: Dictionary, vendor_id: String, screen_key: String) -> void:
	if resource_shutdown_prepared or hud == null:
		return
	if screen_key == "" or hud.preparation_screen_key() != screen_key:
		hud.post_notice(str(result.get("message", result.get("reason", ""))), "inventory" if bool(result.get("ok", false)) else "error", 3.5)
		return
	_update_preparation_context()
	if vendor_id == "":
		hud.show_inventory(inventory, quests, story_state, progression)
	else:
		hud.show_vendor(vendor_id, vendor_service, inventory, quests, story_state)
	if not hud.show_preparation_result(result):
		hud.post_notice(str(result.get("message", result.get("reason", ""))), "inventory" if bool(result.get("ok", false)) else "error", 3.5)

func _purchase_from_vendor(vendor_id: String, item_id: String, quantity: int = 1) -> void:
	if vendor_service == null:
		return
	var result: Dictionary
	preparation_action_in_progress = true
	if item_id == "__emergency_arrows__":
		result = vendor_service.claim_emergency_arrow_refill(vendor_id, inventory)
	elif item_id == "__emergency_healing__":
		result = vendor_service.claim_emergency_healing_refill(vendor_id, inventory)
	else:
		result = vendor_service.buy(vendor_id, item_id, quantity, inventory, story_state, quests)
	preparation_action_in_progress = false
	audio.play_event("ui")
	_finish_preparation_operation(result, vendor_id)

func _on_enemy_died(enemy) -> void:
	audio.play_enemy_event(enemy.enemy_id, "death", enemy.global_position, player.global_position)
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
			_show_current_objective_guidance(6.0)
		elif enemy.enemy_id == "rootbound_colossus":
			story_state.set_flag("rootbound_colossus_defeated", true)
			hud.show_status_cue("The roots release Greyfen", "victory")
			hud.toast("The clearing opens around a heart of oathwood. The road remembers a new name.")
		elif enemy.enemy_id == "ashwing":
			story_state.set_flag("ashwing_defeated", true)
			if current_zone_id == "old_mill" and not quests.is_objective_done("main_ash_at_the_mill", "mill_choice"):
				_make_named_interactable("miller_record", "dialogue", "Read the miller's record", Vector3(-7.0,0,-7), Color(0.5,0.4,0.25))
			hud.show_status_cue("Ashwing falls", "victory")
			hud.toast("The mill roof catches the last ember, then goes dark. Something useful survived in the ash.")
		elif enemy.enemy_id == "halvern_boss":
			story_state.set_flag("halvern_fate", "defeated")
			_publish_halvern_exit()
			quests.complete_objective("main_last_witness", "break_halvern_guard")
			hud.show_status_cue("The Gravebound Knight yields", "victory")
			_show_current_objective_guidance(6.0)
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
		_show_current_objective_guidance(5.0)
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
			_show_current_objective_guidance(6.0)
			hud.toast("The Ghoulkin dies too far from its den. Something drew it to the road. Search the tracks.")
			_make_post_ghoulkin_story_clue()
	elif enemy.enemy_id == "bog_wretch":
		quests.complete_objective("main_teeth_in_rain", "fight_bog_wretch")
		story_state.set_flag("bog_memory_core_revealed", true)
		if not bool(story_state.get_flag("bog_core_exposed", false)):
			story_state.set_flag("bog_core_forced_open", true)
		_make_named_interactable("bog_core_choice", "dialogue", "Choose the memory core's fate", enemy.global_position, Color(0.35, 0.58, 0.52), Vector3(0.4, 0.4, 0.4))
		hud.show_status_cue("A memory remains", "victory")
		_show_current_objective_guidance(5.0)
	elif enemy.enemy_id == "wychwood_stalker" and current_zone_id == "record_hall":
		story_state.set_flag("castle_haunting_cleared", true)
		quests.complete_objective("main_blood_under_stone", "survive_haunting")
		hud.toast("The erased names settle. Edric waits beneath the Vargan seal.")
		_show_current_objective_guidance(6.0)
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
			_show_current_objective_guidance(5.5)
		elif current_zone_id == "wychwood" and quests.is_active("side_black_dog") and not _has_living_enemy("bandit"):
			story_state.set_flag("black_dog_bandits_defeated", true)
			_try_complete_black_dog_investigation()

	elif current_zone_id == "old_mill" and bool(enemy.get_meta("ash_mill_enemy", false)):
		var ash_enemy_alive := false
		for candidate in active_enemies:
			if is_instance_valid(candidate) and candidate != enemy and not candidate.dead and bool(candidate.get_meta("ash_mill_enemy", false)):
				ash_enemy_alive = true
				break
		if not ash_enemy_alive:
			quests.complete_objective("main_ash_at_the_mill", "mill_encounter")
			story_state.set_flag("ash_mill_cleared", true)
			if not _has_living_enemy("ashwing") and not bool(story_state.get_flag("ashwing_defeated", false)) and enemy_defs.has("ashwing"):
				var ashwing := _spawn_enemy("ashwing", Vector3(5.0, 1.0, -6.5))
				if ashwing != null:
					story_state.set_flag("ashwing_spawned", true)
					ashwing.name = "AshwingCarrionDrake"
					ashwing.leash_radius = 10.0
					hud.toast("The mill roof groans. Ashwing drops through the smoke.")
			hud.show_status_cue("The mill falls quiet", "victory")
		_show_current_objective_guidance(5.5)
	if enemy.health_component != null:
		hud.show_enemy(enemy.display_name, 0.0, enemy.health_component.max_health)
	var memory_rule := str(enemy.get_meta("memory_rule", ""))
	if memory_rule != "" and not bool(enemy.get_meta("memory_rule_seen", false)):
		enemy.set_meta("memory_rule_seen", true)
		hud.toast("%s slain. %s" % [enemy.display_name, memory_rule])
	else:
		hud.toast("%s slain." % enemy.display_name)
	save_manager.autosave(self)

func _try_complete_black_dog_investigation() -> void:
	if not quests.is_active("side_black_dog") or quests.is_objective_done("side_black_dog", "find_dog"):
		return
	if not bool(story_state.get_flag("black_dog_sheepfold_inspected", false)):
		return
	if not bool(story_state.get_flag("black_dog_bandit_camp_inspected", false)):
		return
	if not bool(story_state.get_flag("black_dog_bandits_defeated", false)):
		return
	quests.complete_objective("side_black_dog", "find_dog")
	hud.toast("The bandits held the ribbon. The black dog drove them from the children, not toward them.")
	_show_current_objective_guidance(5.0)

func _try_complete_oren_thread_trace(publish_return := true) -> void:
	if not quests.is_active("side_childs_charm") or quests.is_objective_done("side_childs_charm", "trace_thread"):
		return
	var found_oren := bool(story_state.get_flag("road_evidence_oren", false)) \
		or bool(story_state.get_flag("road_token_recovered", false)) \
		or bool(story_state.get_flag("oren_name_spoken", false))
	if not found_oren or not bool(story_state.get_flag("chapel_names_read", false)):
		return
	quests.complete_objective("side_childs_charm", "trace_thread")
	if publish_return and current_zone_id == "greyfen" and zone_root != null:
		GreyfenSection.new().publish_oren_charm_return(ZoneBuildContext.new(self, "greyfen"))
	hud.toast("The red thread from Oren's token matches his erased place in the chapel.")
	_show_current_objective_guidance(5.0)

func _on_enemy_damaged(enemy, current: float, maximum: float) -> void:
	hud.show_enemy(enemy.display_name, current, maximum)
	hud.show_status_cue("Enemy hit", "item")
	audio.play_enemy_event(enemy.enemy_id, "hit", enemy.global_position, player.global_position)

func _on_enemy_windup_started(enemy) -> void:
	if enemy != null and player != null:
		audio.play_enemy_event(enemy.enemy_id, "windup", enemy.global_position, player.global_position)
	if zone_root != null and enemy != null:
		if bool(enemy.get("is_boss")):
			CombatFeedback.boss_telegraph(zone_root, enemy.global_position, enemy.enemy_id)
		else:
			CombatFeedback.ground_ring(zone_root, enemy.global_position, Color(0.46, 0.05, 0.025), 0.62, 0.18)
	if enemy != null and enemy.health_component != null:
		hud.show_enemy(enemy.display_name, enemy.health_component.health, enemy.health_component.max_health)
	if current_zone_id == "wychwood" and not bool(tutorial_flags.get("block_hint_done", false)):
		hud.set_guidance_hint(_guard_tutorial_hint(), 4.2)

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
		if enemy != null:
			audio.play_enemy_event(enemy.enemy_id, "attack", contact_position, player.global_position)
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
		_show_current_objective_guidance(maxf(duration, 2.5))
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
	if not story_action_in_progress:
		story_save_pending = true
		call_deferred("_persist_story_action")

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
	_hitstop(0.055 if heavy else 0.032)
	if audio != null:
		audio.play_event("heavy_hit" if heavy else "light_hit", 0.04)
	if camera_rig != null:
		camera_rig.shake(0.11 if heavy else 0.06)
	_make_hit_spark(pos, heavy)
	if zone_root != null:
		CombatFeedback.ground_ring(zone_root, pos, Color(0.54, 0.36, 0.16), 0.42 if heavy else 0.30, 0.12)

var _hitstop_generation := 0
var _hitstop_restore_scale := 1.0

func _hitstop(seconds: float) -> void:
	if get_tree().paused or zone_transition_pending:
		return
	if settings != null and bool(settings.settings.get("reduced_motion", false)):
		return
	if not is_equal_approx(Engine.time_scale, 0.18):
		_hitstop_restore_scale = Engine.time_scale
	_hitstop_generation += 1
	var generation := _hitstop_generation
	Engine.time_scale = 0.18
	var timer := _create_owned_timer(seconds, true)
	timer.process_mode = Node.PROCESS_MODE_ALWAYS
	timer.timeout.connect(func():
		if generation == _hitstop_generation:
			Engine.time_scale = _hitstop_restore_scale
	)

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
			if child.has_method("set_interaction_enabled"):
				child.set_interaction_enabled(false)
			_remove_interaction_candidate(child)
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
	if area.has_method("set_interaction_enabled"):
		area.set_interaction_enabled(false)
	_remove_interaction_candidate(area)
	_invalidate_interaction_prompt()

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
		"removed_interactions": removed_interactions.duplicate(true),
		"pending_ending": pending_ending,
		"wychwood_pack_kills": wychwood_pack_kills,
		"ghoulkin_kills": wychwood_pack_kills,
		"boss_states": boss_states,
		"day_night": day_night.save_state() if day_night != null else {}
	}

func load_world_state(state: Dictionary) -> void:
	removed_interactions = state.get("removed_interactions", {}).duplicate(true) if typeof(state.get("removed_interactions", {})) == TYPE_DICTIONARY else {}
	pending_ending = str(state.get("pending_ending", ""))
	wychwood_pack_kills = int(state.get("wychwood_pack_kills", state.get("ghoulkin_kills", wychwood_pack_kills)))
	boss_saved_states = state.get("boss_states", {}).duplicate(true) if typeof(state.get("boss_states", {})) == TYPE_DICTIONARY else {}
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
	hud.clear_journey_transients(false)
	_refresh_journey_models()
	hud.show_death_screen("The road keeps its dead.\n\nChoose a recorded journey to return to its saved story state.")

func _on_dialogue_closed_audio() -> void:
	# First encounters are collected as their pages are read. Persist them when
	# the reading surface closes, keeping disk writes out of voice/page handoff.
	call_deferred("_persist_story_action")
	if bool(story_state.get_flag("aftermath_epilogue_pending", false)):
		story_state.set_flag("aftermath_epilogue_pending", false)
		call_deferred("_show_completed_epilogue")
	if audio != null:
		audio.set_game_paused(false)
	interaction_focus_dirty = true
	interaction_focus_cache_valid = false
	call_deferred("_finish_covenant_if_ready")

func _finish_covenant_if_ready() -> void:
	CovenantResolution.finish_if_ready(self)
	if bool(story_state.get_flag("aftermath_epilogue_pending", false)):
		story_state.set_flag("aftermath_epilogue_pending", false)
		call_deferred("_show_completed_epilogue")
	_publish_journey_arrival()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and input_router != null:
		input_router.reset_transient_input("focus_lost")
		if is_instance_valid(player) and player.has_method("cancel_buffered_input"):
			player.cancel_buffered_input("focus_lost")
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and game_started and settings != null:
		if bool(settings.settings.get("pause_on_focus_loss", true)) and not get_tree().paused:
			_pause_game()

func _on_touch_layout_unavailable(reason: String) -> void:
	if hud != null:
		hud.set_touch_layout_reason(reason)
	if reason.is_empty() or resource_shutdown_prepared or not game_started or _journey_load_pending():
		return
	# A layout change must not leave a running fight behind unavailable touch
	# controls. Existing Pause retains the journey and exposes the way back.
	if not get_tree().paused:
		_pause_game()

func _pause_game() -> void:
	if _journey_load_pending():
		return
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
	_refresh_journey_models()
	hud.show_pause_menu()

func _resume_game() -> void:
	if _journey_load_pending():
		return
	var touch_reason: String = mobile_touch.gameplay_layout_reason() if mobile_touch != null else ""
	hud.set_touch_layout_reason(touch_reason)
	if not touch_reason.is_empty():
		if not get_tree().paused or hud.active_menu != "pause":
			_pause_game()
		return
	audio.set_game_paused(false)
	get_tree().paused = false
	paused_by_menu = false
	if input_router != null and input_router.has_method("set_gameplay_context"):
		input_router.set_gameplay_context()
	audio.play_event("ui")
	hud.hide_menus()
	_publish_journey_arrival()
	if bool(story_state.get_flag("final_choice_completed", false)) and current_zone_id == "hart_glade":
		story_state.set_flag("aftermath_returned", true)
		story_save_pending = true
		_load_zone_after_runtime_pack("greyfen", Vector3(0, 1, 9.8))

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
			_load_zone_after_runtime_pack(current_zone_id, player.global_position)
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
	elif action == "difficulty":
		settings.cycle_difficulty()
	elif action == "focus_pause":
		settings.toggle_pause_on_focus_loss()
	if action != "visual_preset":
		hud.toast("Settings updated.")
	hud.show_settings_menu(hud.controls_back_target)

func _apply_runtime_settings(current_settings: Dictionary) -> void:
	CombatFeedback.reduce_flashes = bool(current_settings.get("flash_reduction", false))
	if runtime_packs != null:
		var preset := str(current_settings.get("quality_preset", "balanced"))
		var changed: bool = runtime_packs.quality_preset != preset
		runtime_packs.quality_preset = preset
		if changed and not game_started and (greyfen_prewarm_started or startup_packs_waiting or route_zone_cache.has("greyfen")):
			_restart_menu_opening()
	if performance_budget_monitor != null:
		performance_budget_monitor.quality = str(current_settings.get("quality_preset", "balanced"))
	if audio != null:
		audio.set_master_volume(float(current_settings.get("master_volume", 0.85)))
		audio.apply_mix_settings(current_settings)
		audio.set_ambient_accents_enabled(str(current_settings.get("quality_preset", "balanced")) == "quality")
	if hud != null:
		hud.apply_accessibility(current_settings)
	if player != null and is_instance_valid(player):
		player.apply_difficulty_profile(settings.get_difficulty_profile())
	if camera_rig != null:
		camera_rig.apply_settings(
			float(current_settings.get("mouse_sensitivity", 0.003)),
			bool(current_settings.get("invert_y", false)),
			float(current_settings.get("gamepad_look_sensitivity", 1.0))
		)
		camera_rig.apply_accessibility(current_settings)
		camera_rig.shake_decay = 1000.0 if float(current_settings.get("camera_shake", 1.0)) <= 0.0 else 6.0 / maxf(float(current_settings.get("camera_shake", 1.0)), 0.5)
	if visual_director != null and visual_director.sun != null:
		visual_director.apply_settings(current_settings)
		visual_director.sun.shadow_enabled = int(current_settings.get("shadow_quality", 1)) > 0
		visual_director.sun.directional_shadow_max_distance = 42.0

func _queue_story_guidance_refresh() -> void:
	compass_dirty = true
	if story_guidance_refresh_pending:
		return
	story_guidance_refresh_pending = true
	call_deferred("_apply_story_guidance_refresh")

func _apply_story_guidance_refresh() -> void:
	story_guidance_refresh_pending = false
	if resource_shutdown_prepared or hud == null or quest_hud_coordinator == null:
		return
	_refresh_tracker()

func _refresh_tracker() -> void:
	# Quest changes can alter both the preferred interaction target and the
	# compass summary without moving the player. Invalidate the small runtime
	# caches instead of forcing per-frame scans.
	interaction_focus_dirty = true
	compass_dirty = true
	quest_hud_coordinator.refresh_tracker(hud, zone_runtime_coordinator.refresh_presentation if zone_runtime_coordinator != null else Callable())
	_update_compass()

func _show_current_objective_guidance(seconds: float = 5.0) -> void:
	quest_hud_coordinator.show_guidance(hud, seconds)

func _refresh_equipment_readout() -> void:
	if hud == null or inventory == null:
		return
	var oil_name = ""
	if inventory.active_oil != "":
		oil_name = inventory.get_item_name(inventory.active_oil)
	hud.update_equipment(int(inventory.items.get("redroot_potion", 0)), int(inventory.items.get("ash_bomb", 0)), oil_name, int(inventory.items.get("standard_arrow", 0)), "Standard")

func _guard_tutorial_hint() -> String:
	var guard: Dictionary = input_router.describe_action("block") if input_router != null else {}
	return "Begin guarding as the lunge lands to parry. %s." % str(guard.get("instruction", "Use your guard control to block")).trim_suffix(".")

func _update_tutorial_prompts() -> void:
	if player == null:
		return
	if active_interactable != null and not bool(tutorial_flags.get("interact", false)):
		tutorial_flags["interact"] = true
	if current_zone_id == "greyfen" and not bool(tutorial_flags.get("route", false)) and player.global_position.z < -8.0:
		tutorial_flags["route"] = true
		audio.play_event("cloth_wind", 0.03)
		audio.set_music_state("wychwood_tension")
		hud.toast("The village noise thins behind you. The old road keeps its own silence.")
		_show_current_objective_guidance(4.5)
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
			and player.global_position.z < 1.0 \
			and _has_active_encounter_enemy() \
			and not bool(tutorial_flags.get("combat", false)):
		tutorial_flags["combat"] = true
		audio.set_music_state("ghoulkin_combat")
		audio.play_event("wychwood_tension", 0.01)
		hud.toast("Survive the Ghoulkin.")
		var strike_binding: String = input_router.action_label("light_attack") if input_router != null else "Attack"
		var dodge_binding: String = input_router.action_label("dodge") if input_router != null else "Dodge"
		hud.set_guidance_hint("%s strike | %s dodge\n%s" % [strike_binding, dodge_binding, _guard_tutorial_hint()], 6.0)

func _update_compass() -> void:
	quest_hud_coordinator.update_compass(hud, player, current_zone_id, interaction_area_cache if zone_root != null else [], _zone_display_name(current_zone_id))

func _compass_state_signature() -> String:
	return quest_hud_coordinator.state_signature()

func _compass_needs_refresh() -> bool:
	return quest_hud_coordinator.needs_refresh(player, current_zone_id)

func _distance_to_tracked_interactable(objective_view: Dictionary) -> int:
	return quest_hud_coordinator.objective_distance(objective_view, player, interaction_area_cache if zone_root != null else [])

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
		player.velocity = Vector3.ZERO
		last_safe_player_position = player.global_position
		hud.toast("Kael catches himself before the dark takes him.")

func _safe_loaded_position(zone: String, pos: Vector3) -> Vector3:
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
	if spatial_service != null and spatial_service.zone_id == current_zone_id:
		return spatial_service.is_river_excluded(pos, margin)
	return SpatialSurfaceContract.is_river_excluded(current_zone_id, pos, margin)

func river_safe_position(pos: Vector3, margin: float = 0.55) -> Vector3:
	if spatial_service != null:
		return spatial_service.validate_position(pos, margin)
	var validator := ZoneSpatialService.new()
	validator.configure(current_zone_id, _river_center(), _zone_half_extents(current_zone_id))
	var result: Vector3 = validator.validate_position(pos, margin, validator.bank_for(pos))
	validator.free()
	return result

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
	var enclosed_zone: bool = current_zone_id in ["record_hall", "undercroft"]
	if not is_open:
		match edge_id:
			"north":
				if not enclosed_zone:
					_make_prop_box("NorthBerm", Vector3(0, 0.9, -half_d), Vector3(width, wall_height, wall_thickness), color)
				_make_invisible_wall(Vector3(0, 1.6, -half_d - 0.65), Vector3(width, 3.2, collision_thickness))
			"south":
				if not enclosed_zone:
					_make_prop_box("SouthBerm", Vector3(0, 0.9, half_d), Vector3(width, wall_height, wall_thickness), color)
				_make_invisible_wall(Vector3(0, 1.6, half_d + 0.65), Vector3(width, 3.2, collision_thickness))
			"west":
				if not enclosed_zone:
					_make_prop_box("WestBerm", Vector3(-half_w, 0.9, 0), Vector3(wall_thickness, wall_height, depth), color)
				_make_invisible_wall(Vector3(-half_w - 0.65, 1.6, 0), Vector3(collision_thickness, 3.2, depth))
			"east":
				if not enclosed_zone:
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
				if not enclosed_zone:
					_make_prop_box("NorthBerm", Vector3(center, 0.9, -half_d), Vector3(length, wall_height, wall_thickness), color)
				_make_invisible_wall(Vector3(center, 1.6, -half_d - 0.65), Vector3(length, 3.2, collision_thickness))
			"south":
				if not enclosed_zone:
					_make_prop_box("SouthBerm", Vector3(center, 0.9, half_d), Vector3(length, wall_height, wall_thickness), color)
				_make_invisible_wall(Vector3(center, 1.6, half_d + 0.65), Vector3(length, 3.2, collision_thickness))
			"west":
				if not enclosed_zone:
					_make_prop_box("WestBerm", Vector3(-half_w, 0.9, center), Vector3(wall_thickness, wall_height, length), color)
				_make_invisible_wall(Vector3(-half_w - 0.65, 1.6, center), Vector3(collision_thickness, 3.2, length))
			"east":
				if not enclosed_zone:
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
	_finish_greyfen_ground_surfaces()
	_finish_greyfen_paved_roads()
	_make_terrain_patch("GreyfenCemeterySoil", Vector3(14.0, 0.028, 8.6), Vector3(8.0, 0.045, 5.0), Color(0.095, 0.090, 0.078))
	_make_grass_tufts([
		Vector3(-3.4, 0, -11.5), Vector3(3.1, 0, -10.7), Vector3(-3.6, 0, -7.5), Vector3(3.3, 0, -5.6),
		Vector3(-3.8, 0, -1.4), Vector3(3.6, 0, 1.8), Vector3(-3.0, 0, 5.6), Vector3(3.7, 0, 7.9),
		Vector3(-3.2, 0, -9.5), Vector3(3.0, 0, -8.1), Vector3(-3.0, 0, -5.0), Vector3(3.2, 0, -3.0),
		Vector3(-3.1, 0, 8.4), Vector3(3.2, 0, 9.0), Vector3(-3.3, 0, 11.2), Vector3(3.4, 0, 11.5),
		Vector3(-3.5, 0, 13.6), Vector3(3.1, 0, 13.4), Vector3(5.2, 0, -8.8), Vector3(7.4, 0, -4.9),
		Vector3(11.9, 0, 7.4), Vector3(14.8, 0, 6.2)
	], Color(0.070, 0.145, 0.070))

func _finish_greyfen_ground_surfaces() -> void:
	if zone_root.find_child("GreyfenGroundMerged", true, false) != null:
		return
	var combined := SurfaceTool.new()
	combined.begin(Mesh.PRIMITIVE_TRIANGLES)
	var source_surfaces: Array[MeshInstance3D] = []
	for ground_name in ["GroundNorthWest", "GroundNorthEast", "GroundSouthWest", "GroundSouthEast", "GroundCenterNorthVisual", "GroundCenterSouthVisual"]:
		var ground := zone_root.find_child(ground_name, true, false)
		if ground == null:
			continue
		var surface := ground as MeshInstance3D if ground is MeshInstance3D else ground.get_node_or_null("Surface") as MeshInstance3D
		if surface == null:
			continue
		var origin: Vector3 = zone_root.to_local(surface.global_position)
		var half_size: Vector3 = surface.scale * 0.5
		var top: float = origin.y + half_size.y
		var columns := maxi(2, ceili(half_size.x * 2.0 / 1.5))
		var rows := maxi(2, ceili(half_size.z * 2.0 / 1.5))
		for row in range(rows):
			var z0 := lerpf(origin.z - half_size.z, origin.z + half_size.z, float(row) / float(rows))
			var z1 := lerpf(origin.z - half_size.z, origin.z + half_size.z, float(row + 1) / float(rows))
			# Crop only the visual ground. Its unchanged collision still owns the bank.
			if ground_name in ["GroundNorthWest", "GroundNorthEast"]:
				z1 = minf(z1, 4.5 - 2.02)
			elif ground_name in ["GroundSouthWest", "GroundSouthEast"]:
				z0 = maxf(z0, 4.5 + 2.02)
			if z1 <= z0:
				continue
			for column in range(columns):
				var x0 := lerpf(origin.x - half_size.x, origin.x + half_size.x, float(column) / float(columns))
				var x1 := lerpf(origin.x - half_size.x, origin.x + half_size.x, float(column + 1) / float(columns))
				for point in [Vector3(x0, top, z0), Vector3(x1, top, z0), Vector3(x0, top, z1), Vector3(x1, top, z0), Vector3(x1, top, z1), Vector3(x0, top, z1)]:
					combined.set_normal(Vector3.UP)
					combined.set_uv(Vector2(point.x, point.z))
					combined.set_color(_greyfen_ground_tint(point))
					combined.add_vertex(point)
		source_surfaces.append(surface)
	if source_surfaces.size() != 6:
		push_error("Greyfen authored ground is incomplete: %d/6 surfaces" % source_surfaces.size())
		return
	_append_greyfen_river_banks(combined)
	var ground_visual := MeshInstance3D.new()
	ground_visual.name = "GreyfenGroundMerged"
	ground_visual.mesh = combined.commit()
	var ground_material := world_materials.get_material("forest_ground", str(settings.settings.get("quality_preset", "balanced")), Color.WHITE, 0.0, false).duplicate() as StandardMaterial3D
	ground_material.resource_name = "GreyfenGroundBlended"
	ground_material.vertex_color_use_as_albedo = true
	ground_visual.material_override = ground_material
	ground_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	zone_root.add_child(ground_visual)
	for surface in source_surfaces:
		surface.visible = false
		surface.queue_free()

func _append_greyfen_river_banks(surface: SurfaceTool) -> void:
	var bridge_half := BridgeSurfaceContract.HALF_WIDTH
	var river := RiverSection.new()
	for bank_side in [-1.0, 1.0]:
		var land_z: float = 4.5 + bank_side * 2.02
		for section in [[-21.0, -bridge_half + 0.08], [bridge_half - 0.08, 21.0]]:
			var segments := maxi(12, ceili((float(section[1]) - float(section[0])) / 0.85))
			for index in range(segments):
				var x0 := lerpf(float(section[0]), float(section[1]), float(index) / float(segments))
				var x1 := lerpf(float(section[0]), float(section[1]), float(index + 1) / float(segments))
				var a := Vector3(x0, 0.006, land_z)
				var b := Vector3(x1, 0.006, land_z)
				var edge0 := river._water_channel_vertex(x0 / 42.0 + 0.5, 0.0 if bank_side < 0 else 1.0, 42.0, 3.4).z + 4.5
				var edge1 := river._water_channel_vertex(x1 / 42.0 + 0.5, 0.0 if bank_side < 0 else 1.0, 42.0, 3.4).z + 4.5
				# The lower edge stays under the lowest animated wave, not above it.
				var c := Vector3(x0, -0.30, edge0 - bank_side * 0.06)
				var d := Vector3(x1, -0.30, edge1 - bank_side * 0.06)
				var triangles := [a, b, c, b, d, c] if bank_side < 0.0 else [a, c, b, b, c, d]
				for point in triangles:
					var shore_weight := clampf((0.006 - point.y) / 0.306, 0.0, 1.0)
					var tint := _greyfen_ground_tint(point).lerp(Color(0.29, 0.41, 0.35), shore_weight)
					surface.set_normal(Vector3.UP)
					surface.set_uv(Vector2(point.x, point.z))
					surface.set_color(tint)
					surface.add_vertex(point)

func _greyfen_ground_tint(point: Vector3) -> Color:
	var tint := Color(0.42, 0.62, 0.40)
	for region in [
		[Vector2(-9.5, -4.0), Vector2(6.5, 5.0), Color(0.51, 0.48, 0.35)],
		[Vector2(6.0, -7.0), Vector2(4.6, 3.5), Color(0.40, 0.57, 0.39)],
		[Vector2(9.5, 4.5), Vector2(4.5, 3.7), Color(0.49, 0.44, 0.34)],
		[Vector2(-5.4, 11.5), Vector2(3.4, 2.5), Color(0.52, 0.47, 0.35)],
		[Vector2(7.0, 10.3), Vector2(2.8, 2.4), Color(0.49, 0.46, 0.35)],
	]:
		var offset := Vector2((point.x - region[0].x) / region[1].x, (point.z - region[0].y) / region[1].y)
		tint = tint.lerp(region[2], 1.0 - smoothstep(0.60, 1.0, offset.length()))
	var roadside := 1.0 - smoothstep(0.25, 1.55, absf(absf(point.x) - 3.25))
	var span_weight := 0.0
	for span in [Vector2(-13.5, -2.0), Vector2(2.0, 6.7), Vector2(11.0, 14.0)]:
		span_weight = maxf(span_weight, smoothstep(0.0, 1.2, point.z - span.x) * smoothstep(0.0, 1.2, span.y - point.z))
	return tint.lerp(Color(0.45, 0.58, 0.36), roadside * span_weight * 0.75)

func _finish_greyfen_paved_roads() -> void:
	for road_name in ["PavedRoadMain", "PavedRoadVillage", "PavedRoadCastle"]:
		var road := zone_root.find_child(road_name, true, false) as MeshInstance3D
		if road == null:
			continue
		var road_size := road.scale
		road.mesh = _make_greyfen_road_surface(road_size, road.position)
		road.scale = Vector3.ONE
		var road_material := _road_material(true, Color(0.16, 0.13, 0.09)).duplicate() as StandardMaterial3D
		road_material.vertex_color_use_as_albedo = true
		road.material_override = road_material

func _make_greyfen_road_surface(size: Vector3, origin: Vector3) -> ArrayMesh:
	var along_z := size.z >= size.x
	var length := size.z if along_z else size.x
	var half_width := (size.x if along_z else size.z) * 0.5
	var rows := maxi(4, ceili(length / 0.9))
	var lateral := [-1.0, -0.65, 0.0, 0.65, 1.0]
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for row in range(rows + 1):
		var forward := length * (float(row) / float(rows) - 0.5)
		var bend := sin(forward * 0.51 + origin.x * 0.17) * 0.08
		var shoulder := half_width - 0.13 + sin(forward * 1.37 + origin.z * 0.29) * 0.12
		for column in range(lateral.size()):
			var side := float(lateral[column])
			var across := bend + side * (shoulder if absf(side) > 0.9 else half_width)
			var point := Vector3(across, size.y * 0.5, forward) if along_z else Vector3(forward, size.y * 0.5, across)
			vertices.append(point)
			normals.append(Vector3.UP)
			uvs.append(Vector2(origin.x + point.x, origin.z + point.z))
			var edge_mix := 1.0 - smoothstep(0.62, 1.0, absf(side))
			colors.append(Color(0.54, 0.58, 0.49).lerp(Color.WHITE, edge_mix))
	for row in range(rows):
		for column in range(lateral.size() - 1):
			var a := row * lateral.size() + column
			var b := a + 1
			var c := a + lateral.size()
			var d := c + 1
			indices.append_array(PackedInt32Array([a, b, c, b, d, c]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _make_wychwood_terrain_layers() -> void:
	if not WychwoodTerrainPresentation.integrate(zone_root):
		push_error("Wychwood walkable terrain could not be integrated")
		return
	_make_grass_tufts([
		Vector3(-2.8, 0, 11.8), Vector3(2.6, 0, 10.5), Vector3(-3.1, 0, 7.2), Vector3(3.3, 0, 5.6),
		Vector3(-3.4, 0, 2.0), Vector3(3.5, 0, -0.2), Vector3(-3.7, 0, -4.2), Vector3(3.4, 0, -6.1),
		Vector3(-5.0, 0, -8.4), Vector3(5.3, 0, -9.0)
	], Color(0.045, 0.115, 0.065))

func _make_wychwood_clearing_floor() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3(0, 0.059, -6.5)
	var segments := 20
	for index in segments:
		var angle := TAU * float(index) / float(segments)
		var next_angle := TAU * float(index + 1) / float(segments)
		var radius := 0.88 + 0.12 * sin(float(index) * 2.17)
		var next_radius := 0.88 + 0.12 * sin(float(index + 1) * 2.17)
		var inner := center + Vector3(cos(angle) * 3.25 * radius, 0, sin(angle) * 2.35 * radius)
		var inner_next := center + Vector3(cos(next_angle) * 3.25 * next_radius, 0, sin(next_angle) * 2.35 * next_radius)
		var outer := center + Vector3(cos(angle) * 5.25 * radius, 0, sin(angle) * 3.75 * radius)
		var outer_next := center + Vector3(cos(next_angle) * 5.25 * next_radius, 0, sin(next_angle) * 3.75 * next_radius)
		for point in [[center, Color(0.52, 0.53, 0.47)], [inner_next, Color(0.68, 0.68, 0.57)], [inner, Color(0.68, 0.68, 0.57)], [inner, Color(0.68, 0.68, 0.57)], [inner_next, Color(0.68, 0.68, 0.57)], [outer_next, Color(0.91, 0.93, 0.83)], [inner, Color(0.68, 0.68, 0.57)], [outer_next, Color(0.91, 0.93, 0.83)], [outer, Color(0.91, 0.93, 0.83)]]:
			surface.set_normal(Vector3.UP)
			surface.set_color(point[1])
			surface.set_uv(Vector2(point[0].x, point[0].z) * 0.55)
			surface.add_vertex(point[0])
	var floor := MeshInstance3D.new()
	floor.name = "WychwoodClearingMud"
	floor.mesh = surface.commit()
	var material := world_materials.get_material("wet_mud", str(settings.settings.get("quality_preset", "balanced")), Color(0.30, 0.36, 0.29), 0.0, true).duplicate() as StandardMaterial3D
	material.vertex_color_use_as_albedo = true
	floor.material_override = material
	floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	zone_root.add_child(floor)

func _make_wychwood_winding_path() -> void:
	if zone_root.find_child("WychwoodWindingPath", true, false) != null:
		return
	var mud_surface := SurfaceTool.new()
	mud_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shoulder_surface := SurfaceTool.new()
	shoulder_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var river_edge := BridgeSurfaceContract.RIVER_HALF_SPAN
	for span in [Vector2(-10.5, -river_edge), Vector2(river_edge, 16.5)]:
		var rows := ceili((span.y - span.x) / 0.9)
		for row in range(rows):
			var z0 := lerpf(span.x, span.y, float(row) / float(rows))
			var z1 := lerpf(span.x, span.y, float(row + 1) / float(rows))
			var bridge_blend0 := 1.0 - smoothstep(river_edge, river_edge + 3.0, absf(z0))
			var bridge_blend1 := 1.0 - smoothstep(river_edge, river_edge + 3.0, absf(z1))
			var core0 := lerpf(1.26 + 0.16 * sin(z0 * 1.37) + 0.07 * sin(z0 * 2.59), 2.28, bridge_blend0)
			var core1 := lerpf(1.26 + 0.16 * sin(z1 * 1.37) + 0.07 * sin(z1 * 2.59), 2.28, bridge_blend1)
			var outer0 := maxf(3.48, core0 + 0.80) + 0.24 * sin(z0 * 1.41)
			var outer1 := maxf(3.48, core1 + 0.80) + 0.24 * sin(z1 * 1.41)
			var lateral0 := [-outer0, -core0, 0.0, core0, outer0]
			var lateral1 := [-outer1, -core1, 0.0, core1, outer1]
			for band in range(4):
				var x00: float = _wychwood_path_center(z0) + float(lateral0[band])
				var x01: float = _wychwood_path_center(z1) + float(lateral1[band])
				var x10: float = _wychwood_path_center(z0) + float(lateral0[band + 1])
				var x11: float = _wychwood_path_center(z1) + float(lateral1[band + 1])
				var surface := mud_surface if band in [1, 2] else shoulder_surface
				var left_color := Color(0.70, 0.73, 0.66) if band == 0 else Color(0.82, 0.84, 0.78) if band == 1 else Color(0.97, 0.98, 0.94) if band == 2 else Color(0.58, 0.62, 0.55)
				var right_color := Color(0.58, 0.62, 0.55) if band == 0 else Color(0.97, 0.98, 0.94) if band == 1 else Color(0.82, 0.84, 0.78) if band == 2 else Color(0.70, 0.73, 0.66)
				for vertex in [
					[Vector3(x00, 0.057, z0), left_color], [Vector3(x10, 0.057, z0), right_color], [Vector3(x01, 0.057, z1), left_color],
					[Vector3(x10, 0.057, z0), right_color], [Vector3(x11, 0.057, z1), right_color], [Vector3(x01, 0.057, z1), left_color],
				]:
					surface.set_normal(Vector3.UP)
					surface.set_color(vertex[1])
					surface.set_uv(Vector2(vertex[0].x, vertex[0].z) * 0.55)
					surface.add_vertex(vertex[0])
	var path := MeshInstance3D.new()
	path.name = "WychwoodWindingPath"
	var mesh := mud_surface.commit()
	shoulder_surface.commit(mesh)
	var mud_material := world_materials.get_material("wet_mud", str(settings.settings.get("quality_preset", "balanced")), Color(0.56, 0.50, 0.42), 0.20, true).duplicate() as StandardMaterial3D
	mud_material.resource_name = "WychwoodWindingPathMud"
	mud_material.roughness = 0.88
	mud_material.vertex_color_use_as_albedo = true
	mesh.surface_set_material(0, mud_material)
	var shoulder_material := world_materials.get_material("forest_ground", str(settings.settings.get("quality_preset", "balanced")), Color(0.58, 0.62, 0.54), 0.0, true).duplicate() as StandardMaterial3D
	shoulder_material.vertex_color_use_as_albedo = true
	mesh.surface_set_material(1, shoulder_material)
	path.mesh = mesh
	path.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	zone_root.add_child(path)

func _wychwood_path_center(z: float) -> float:
	return sin(z * 0.28) * 0.62 * smoothstep(2.3, 7.0, absf(z))

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
		_make_low_berm(Vector3(-4.25, 0, z), Vector3(1.4, 0.48, 2.2), Color(0.030, 0.060, 0.038))
		_make_low_berm(Vector3(4.25, 0, z), Vector3(1.4, 0.48, 2.2), Color(0.030, 0.060, 0.038))

func _make_terrain_patch(name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var river_z := _river_center()
	var river_min := river_z - BridgeSurfaceContract.RIVER_HALF_SPAN
	var river_max := river_z + BridgeSurfaceContract.RIVER_HALF_SPAN
	var patch_min := pos.z - size.z * 0.5
	var patch_max := pos.z + size.z * 0.5
	if river_z < SpatialSurfaceContract.NO_RIVER and patch_min < river_max and patch_max > river_min:
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
	mesh.rotation_degrees.y = 0.0 if current_zone_id == "wychwood" else randf_range(-2.0, 2.0)
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
	mesh.name = "RoundedEarthBerm"
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var columns := 8
	var rows := 10
	var points: Array[Vector3] = []
	for row in range(rows + 1):
		for column in range(columns + 1):
			var u := float(column) / columns * 2.0 - 1.0
			var v := float(row) / rows * 2.0 - 1.0
			var shoulder := pow(pow(absf(u), 4.0) + pow(absf(v), 4.0), 0.25)
			var rise := 1.0 - smoothstep(0.40, 1.0, shoulder)
			var irregularity := sin(u * 4.1 + pos.z) * sin(v * 3.2 + pos.x) * 0.07 * rise
			var edge_x := 1.0 + 0.10 * sin(v * 3.1 + pos.z)
			var edge_z := 1.0 + 0.09 * sin(u * 4.0 + pos.x)
			points.append(Vector3(u * (size.x * 0.5 + 0.28) * edge_x, -size.y * 0.5 - 0.015 + size.y * (rise + irregularity), v * (size.z * 0.5 + 0.28) * edge_z))
	for row in range(rows):
		for column in range(columns):
			var a := row * (columns + 1) + column
			var b := a + 1
			var c := a + columns + 1
			var d := c + 1
			for index in [a, b, c, b, d, c]:
				var point := points[index]
				surface.set_uv(Vector2(point.x + pos.x, point.z + pos.z))
				surface.add_vertex(point)
	surface.generate_normals()
	mesh.mesh = surface.commit()
	mesh.material_override = _terrain_material("WychwoodEarthBerm", color)
	body.add_child(mesh)

func _make_grass_tufts(points: Array, color: Color) -> void:
	var safe_points: Array = []
	for point in points:
		if not _is_river_excluded(point,0.25) and (spatial_service == null or not spatial_service.is_reserved(point, 0.25)):
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
	for pos in [Vector3(-3.1, 0, 4.2), Vector3(3.0, 0, 3.4), Vector3(-2.9, 0, 0.2), Vector3(2.9, 0, -1.5)]:
		_make_path_stone(pos, 0.22)
	_make_lantern_post(Vector3(-2.8, 0, 5.7), false, true)
	_make_lantern_post(Vector3(2.65, 0, 1.5), false, false)
	_make_firewood_stack(Vector3(-5.1, 0, 5.2), 18.0)
	_make_broken_fence_run(Vector3(4.7, 0, 5.8), false)

func _make_greyfen_first_impression_dressing(stage: String = "") -> void:
	var stages := ["ruts", "lanterns", "shrine", "story", "crows"]
	if stage != "" and stage not in stages:
		push_error("Unknown Greyfen first-impression stage: " + stage)
		return
	var marker := zone_root.find_child("GreyfenFirstImpressionDressing", true, false)
	if marker == null:
		marker = Node3D.new()
		marker.name = "GreyfenFirstImpressionDressing"
		zone_root.add_child(marker)
	for part in stages:
		if (stage != "" and stage != part) or bool(marker.get_meta("built_" + part, false)):
			continue
		match part:
			"ruts": _make_road_ruts()
			"lanterns": _make_lantern_rhythm()
			"shrine": _make_shrine_approach()
			"story": _make_village_story_clusters()
			"crows": _make_crow_silhouettes()
		marker.set_meta("built_" + part, true)
	for part in stages:
		if not bool(marker.get_meta("built_" + part, false)):
			return
	marker.set_meta("first_impression_complete", true)

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
	# The base road already contains the authored wear pass. These repeated
	# raised strips read as tiled blocks at gameplay distance and add no route
	# or narrative value, so keep the dressing hook without spawning them.
	return

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
	var pool := _make_visual_box(name, pos, size, color)
	pool.set_meta("night_only_geometry", true)

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
	var columns := 5
	var rows := 3
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for row in range(rows + 1):
		var v := float(row) / float(rows)
		for column in range(columns + 1):
			var u := float(column) / float(columns)
			var x := (u - 0.5) * size.x
			var hem := (0.07 + 0.04 * sin(float(column) * 2.3)) * v * v
			var y := (0.5 - v) * size.y + hem
			var z := sin(u * PI * 4.0) * 0.055 + v * v * 0.035
			vertices.append(Vector3(x, y, z))
			normals.append(Vector3.BACK)
			uvs.append(Vector2(u, v))
	for row in range(rows):
		for column in range(columns):
			var a := row * (columns + 1) + column
			var b := a + 1
			var c := a + columns + 1
			var d := c + 1
			indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var cloth_mesh := ArrayMesh.new()
	cloth_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var cloth := MeshInstance3D.new()
	cloth.name = "HangingClothDrape_%d" % zone_root.get_child_count()
	cloth.position = pos
	cloth.mesh = cloth_mesh
	var cloth_material := _mat(color).duplicate() as StandardMaterial3D
	cloth_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	cloth_material.roughness = 0.96
	cloth.material_override = cloth_material
	zone_root.add_child(cloth)

func _make_fake_fog_bank(pos: Vector3) -> void:
	_make_visual_box("LowColdFogBank", pos + Vector3(0, 0.07, 0), Vector3(1.6, 0.10, 0.55), Color(0.105, 0.125, 0.118))

func _make_crow_silhouettes() -> void:
	# These sub-metre silhouettes share geometry; default spheres spend thousands
	# of triangles on each wing despite occupying only a few gameplay pixels.
	var silhouette_mesh := SphereMesh.new()
	silhouette_mesh.radial_segments = 12
	silhouette_mesh.rings = 7
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
		_add_crow_part(root, "CrowBody", silhouette_mesh, Vector3(0, 0, 0), Vector3(0.18, 0.12, 0.30), Color(0.010, 0.010, 0.012))
		_add_crow_part(root, "CrowHead", silhouette_mesh, Vector3(0, 0.04, -0.13), Vector3(0.12, 0.11, 0.13), Color(0.016, 0.016, 0.018))
		var beak_mesh := CylinderMesh.new()
		beak_mesh.top_radius = 0.0
		beak_mesh.bottom_radius = 0.055
		beak_mesh.height = 0.16
		beak_mesh.radial_segments = 8
		_add_crow_part(root, "CrowBeak", beak_mesh, Vector3(0, 0.04, -0.22), Vector3(0.72, 0.72, 1.0), Color(0.15, 0.12, 0.08), Vector3(-90, 0, 0))
		_add_crow_part(root, "CrowWingLeft", silhouette_mesh, Vector3(-0.18, 0.0, -0.01), Vector3(0.30, 0.035, 0.13), Color(0.008, 0.008, 0.010), Vector3(0, 0, -18))
		_add_crow_part(root, "CrowWingRight", silhouette_mesh, Vector3(0.18, 0.0, -0.01), Vector3(0.30, 0.035, 0.13), Color(0.008, 0.008, 0.010), Vector3(0, 0, 18))
		_add_crow_part(root, "CrowTail", silhouette_mesh, Vector3(0, -0.02, 0.24), Vector3(0.12, 0.04, 0.24), Color(0.008, 0.008, 0.010), Vector3(18, 0, 0))
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
	# Long interior trim spans most of a room. Passing its half-depth through the
	# outdoor occupancy clamp can move authored pilasters and rafters into the
	# central aisle, where they become camera-blocking slabs. Interior zones have
	# no river crossing to protect, so retain their authored placement.
	var preserve_interior_position: bool = current_zone_id in ["record_hall", "undercroft"]
	if not preserve_interior_position:
		pos = river_safe_position(pos, size.z * 0.5 + 0.18)
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = name
	mesh_instance.set_meta("visual_name", name)
	mesh_instance.position = pos
	mesh_instance.visibility_range_end = 32.0
	zone_root.add_child(mesh_instance)
	if environment_batches_flushed:
		mesh_instance.mesh = shared_box_mesh
		mesh_instance.scale = size
		mesh_instance.material_override = _mat(color)
	else:
		# A pending marker carries only a transform, not visible geometry. Binding
		# a unit cube here creates disposable renderer work and can flash a wrong
		# shape before the batch is published. Terrain markers follow this rule too.
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
	CemeteryEvidencePresentation.add_disturbed_soil(zone_root, Vector3(13.65, 0.057, 9.45), world_materials.get_material("wet_mud", str(settings.settings.get("quality_preset", "balanced")), Color(0.43, 0.38, 0.31), 0.0, false))
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
		if bool(story_state.get_flag("all_road_evidence", false)) and not quests.is_objective_done("main_road_of_crows", "fight_ghoulkin"):
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
	if current_zone_id == "wychwood":
		var trace := MeshInstance3D.new()
		trace.name = name
		trace.mesh = world_materials.make_organic_ground_patch(size, pos)
		trace.position = pos
		trace.material_override = world_materials.get_material("wet_mud", str(settings.settings.get("quality_preset", "balanced")), color.lightened(0.18), 0.0, false)
		trace.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		zone_root.add_child(trace)
		return
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
	var house_variant := 0
	match node_name:
		"DressedVillageHouse_WestLane": house_variant = 1
		"DressedVillageHouse_EastLane": house_variant = 2
		"DressedVillageHouse_ShrineFrame": house_variant = 3
	var mesh_path := "res://assets_external/environment/village/GreyfenHouse_Authored.res" if house_variant == 0 else "res://assets_external/environment/village/GreyfenHouse_Authored_%d.res" % house_variant
	var authored_mesh := load(mesh_path) as ArrayMesh
	if authored_mesh == null or authored_mesh.get_surface_count() != 6:
		push_error("Required Greyfen house mesh is unavailable: " + node_name)
		return
	var root = Node3D.new()
	root.name = node_name
	root.add_to_group("first_route_house")
	root.add_to_group("greyfen_house")
	root.set_meta("visible_house", true)
	root.set_meta("house_variant", house_variant)
	root.position = pos
	root.rotation_degrees.y = yaw
	zone_root.add_child(root)
	_make_house_collision(root)
	var house_visual := MeshInstance3D.new()
	house_visual.name = "AuthoredHouse"
	house_visual.mesh = authored_mesh
	root.add_child(house_visual)
	var authored_tints := {
		"medieval_brick": Color(0.67, 0.65, 0.59),
		"plaster": [Color(0.76, 0.70, 0.58), Color(0.65, 0.68, 0.62), Color(0.78, 0.64, 0.48), Color(0.71, 0.72, 0.68)][house_variant],
		"timber": [Color(0.72, 0.57, 0.40), Color(0.62, 0.53, 0.43), Color(0.78, 0.54, 0.34), Color(0.53, 0.49, 0.43)][house_variant],
		"roof_tiles": [Color(0.76, 0.47, 0.37), Color(0.63, 0.51, 0.46), Color(0.82, 0.52, 0.39), Color(0.60, 0.59, 0.57)][house_variant],
		"glazing": Color(0.16, 0.22, 0.24),
		"metal": Color(0.34, 0.34, 0.32),
	}
	var house_quality := str(settings.settings.get("quality_preset", "balanced"))
	for surface_index in authored_mesh.get_surface_count():
		var surface_name := authored_mesh.surface_get_name(surface_index)
		if not authored_tints.has(surface_name):
			push_error("Unknown authored Greyfen house surface: " + surface_name)
			return
		var material_role := surface_name if world_materials.SURFACES.has(surface_name) else "metal"
		var surface_material: StandardMaterial3D = _mat(authored_tints[surface_name]) if surface_name == "glazing" else world_materials.get_material(material_role, house_quality, authored_tints[surface_name], 0.0, false)
		house_visual.set_surface_override_material(surface_index, surface_material)
	root.set_meta("roof_treatment", "authored_mesh")
	return

func _add_house_module(parent: Node3D, role_name: String, scale_value: Vector3, local_pos: Vector3, yaw: float, node_name: String) -> Node3D:
	var module: Node3D = _make_house_facade_module(role_name, scale_value) if role_name in ["greyfen_door_facade", "greyfen_window_facade", "greyfen_wall_facade", "greyfen_roof"] else _make_role_visual(role_name, "environment", scale_value)
	if module == null:
		return null
	module.name = node_name
	module.position = local_pos
	module.rotation_degrees.y = yaw
	module.set_meta("world_001_module", true)
	parent.add_child(module)
	if role_name in ["greyfen_window_facade", "greyfen_wall_facade"] and module is MeshInstance3D:
		var facade := module as MeshInstance3D
		var batch_key := "%s_%s" % [role_name, parent.name]
		if not house_module_batch_data.has(batch_key):
			house_module_batch_data[batch_key] = {"mesh": facade.mesh, "transforms": []}
		house_module_batch_data[batch_key].transforms.append(parent.transform * facade.transform)
		facade.visible = false
	return module

func _make_house_facade_module(role_name: String, scale_value: Vector3) -> MeshInstance3D:
	if asset_helper == null or asset_helper.database == null:
		return null
	var entry: Dictionary = asset_helper.database.get_asset_for_role(role_name)
	var path := str(entry.get("path", ""))
	var source: ArrayMesh = asset_helper.load_runtime_resource(path) as ArrayMesh
	if source == null or source.get_surface_count() < 2:
		push_error("Greyfen facade lost material-grouped mesh: " + role_name)
		return null
	var mesh := source.duplicate() as ArrayMesh
	var quality := str(settings.settings.get("quality_preset", "balanced"))
	for index in range(mesh.get_surface_count()):
		var group := source.surface_get_name(index).to_lower()
		var surface_id := ""
		if group.contains("plaster"):
			surface_id = "plaster"
		elif group.contains("roundtiles"):
			surface_id = "roof_tiles"
		elif group.contains("wood"):
			surface_id = "timber"
		elif group.contains("brick") or group.contains("rock"):
			surface_id = "medieval_brick"
		if surface_id == "":
			push_error("Unknown Greyfen facade material group: " + group)
			return null
		var tint := Color(0.48, 0.41, 0.34) if surface_id == "plaster" else Color.WHITE
		mesh.surface_set_material(index, world_materials.get_material(surface_id, quality, tint, 0.0, true))
	var module := MeshInstance3D.new()
	module.mesh = mesh
	var native_size := source.get_aabb().size
	if native_size.x <= 0.001 or native_size.y <= 0.001 or native_size.z <= 0.001:
		push_error("Greyfen module has invalid native bounds: " + role_name)
		return null
	var target_size: Vector3 = ENVIRONMENT_ROLE_NORMALIZED_SIZE.get(role_name, native_size)
	module.scale = Vector3(
		scale_value.x * target_size.x / native_size.x,
		scale_value.y * target_size.y / native_size.y,
		scale_value.z * target_size.z / native_size.z
	)
	module.set_meta("world_material_groups", mesh.get_surface_count())
	return module

func _add_house_gables(parent: Node3D, plaster: Color, timber: Color, authored_facades: bool) -> void:
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
	if not authored_facades:
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
	if lower in ["litwindow", "rearlitwindow", "sidewindow", "uppergablewindow"]:
		surface = "emissive_window"
	elif lower == "glazedpane":
		surface = "glazing"
	elif lower.contains("roof") or lower.contains("awning") or lower.contains("canopy"):
		surface = "roof_tiles"
	elif lower.contains("timber") or lower.contains("door") or lower.contains("window") or lower.contains("shutter") or lower.contains("post") or lower.contains("shelf"):
		surface = "timber"
	elif lower.contains("foundation") or lower.contains("stone") or lower.contains("step"):
		surface = "medieval_brick"
	var batch_key := surface if surface != "emissive_window" else "%s:%s" % [surface, color.to_html(false)]
	if not house_batch_data.has(batch_key):
		var material: Material
		if surface == "emissive_window":
			material = _emissive_mat(color, 0.7)
		elif surface == "glazing":
			material = _mat(color)
		else:
			material = world_materials.get_material(surface, str(settings.settings.get("quality_preset", "balanced")), Color.WHITE, 0.0, true).duplicate()
			(material as StandardMaterial3D).vertex_color_use_as_albedo = true
		house_batch_data[batch_key] = {"material": material, "transforms": [], "colors": []}
	var rotation_radians := Vector3(deg_to_rad(local_rot.x), deg_to_rad(local_rot.y), deg_to_rad(local_rot.z))
	var basis := Basis.from_euler(rotation_radians).scaled(size)
	var zone_transform: Transform3D = parent.transform * Transform3D(basis, local_pos)
	house_batch_data[batch_key].transforms.append(zone_transform)
	var tint := color.lightened(0.20 if surface == "plaster" else 0.12)
	house_batch_data[batch_key].colors.append(Color.WHITE if surface in ["emissive_window", "glazing"] else tint)
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
	# The authored roof rises above the solid wall box. A camera-only volume
	# catches the orbit ray without widening the player's road collision.
	var camera_roof := StaticBody3D.new()
	camera_roof.name = "CameraRoofCollision"
	camera_roof.collision_layer = 1 << 6
	camera_roof.collision_mask = 0
	parent.add_child(camera_roof)
	var roof_shape := CollisionShape3D.new()
	var roof_box := BoxShape3D.new()
	roof_box.size = Vector3(5.0, 1.6, 4.2)
	roof_shape.shape = roof_box
	roof_shape.position.y = 3.2
	camera_roof.add_child(roof_shape)
	if int(parent.get_meta("house_variant", 0)) == 1:
		for x in [-0.98, 0.98]:
			var post := CollisionShape3D.new()
			var post_box := BoxShape3D.new()
			post_box.size = Vector3(0.12, 1.60, 0.12)
			post.shape = post_box
			post.position = Vector3(x, 0.95, -2.36)
			body.add_child(post)

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
		["crate", Vector3(11.1, 0, -3.7), 0.72, -18.0],
		["barrel", Vector3(10.7, 0, 2.9), 0.58, 18.0],
		# Keep the return-to-Castle sightline clear. This rock used to sit on the
		# diagonal from the Wychwood arrival to Greyfen's east exit and its imported
		# collider stopped the player before the gate became focusable.
		["forest_rock", Vector3(8.6, 0, -11.7), 0.55, 0.0],
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
		["forest_rock", Vector3(-4.6, 0, 9.0), 0.46, 8.0],
		["forest_rock", Vector3(4.7, 0, 7.8), 0.40, -16.0],
		["forest_rock", Vector3(-4.8, 0, 1.6), 0.52, 22.0],
		["forest_rock", Vector3(4.9, 0, -1.7), 0.44, 0.0],
		["barrel", Vector3(-5.2, 0, 8.2), 0.48, 0.0],
		["crate", Vector3(-5.8, 0, 7.6), 0.56, 11.0]
	]:
		_make_loose_role(str(item[0]), item[1], Vector3.ONE * float(item[2]), float(item[3]))
	# Keep fallen trunks beyond the player/camera corridor. The previous east
	# trunk at (4.6, 10.5) sat directly in the standard clue-route framing.
	for pos in [Vector3(-7.0, 0, 11.5), Vector3(7.1, 0, 3.0), Vector3(-7.0, 0, -2.0), Vector3(7.1, 0, -4.8)]:
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
			var safe_rock_position := river_safe_position(pos, 0.75)
			# `nearest_safe()` is an actor-recovery API. It can legitimately return
			# an authored spawn anchor when a scenery source point overlaps a wall or
			# another prop, but a visual rock must never be teleported across the
			# zone into a player route. Omit the obstructed decoration instead.
			if safe_rock_position.distance_to(pos) > 1.6:
				rock.free()
				return null
			rock.position = safe_rock_position
			rock.rotation_degrees.y = yaw
			zone_root.add_child(rock)
			if current_zone_id == "old_mill":
				# Arena stones are visual dressing, not player obstacles. Their
				# rendered bounds still need to keep the combat camera out of cover.
				var rock_meshes := rock.find_children("*", "MeshInstance3D", true, false)
				if rock is MeshInstance3D:
					rock_meshes.append(rock)
				for raw_mesh in rock_meshes:
					var mesh := raw_mesh as MeshInstance3D
					if mesh.mesh == null:
						continue
					var bounds := mesh.mesh.get_aabb()
					var clearance := StaticBody3D.new()
					clearance.name = "RockCameraClearance"
					clearance.collision_layer = 1 << 6
					clearance.collision_mask = 0
					var collision := CollisionShape3D.new()
					var shape := BoxShape3D.new()
					shape.size = bounds.size
					collision.shape = shape
					collision.position = bounds.get_center()
					clearance.add_child(collision)
					mesh.add_child(clearance)
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
	var shrine_mesh := load("res://assets_external/environment/village/GreyfenShrine_Authored.res") as ArrayMesh
	if shrine_mesh == null or shrine_mesh.get_surface_count() != 6:
		push_error("Required authored Greyfen shrine is unavailable")
		return
	var shrine := MeshInstance3D.new()
	shrine.name = "GreyfenAuthoredOathstone"
	shrine.position = pos
	shrine.mesh = shrine_mesh
	zone_root.add_child(shrine)
	var shrine_tints := {
		"medieval_brick": Color(0.68, 0.68, 0.62),
		"plaster": Color(0.70, 0.71, 0.66),
		"timber": Color(0.37, 0.27, 0.19),
		"roof_tiles": Color(0.39, 0.18, 0.17),
		"glazing": Color(0.29, 0.56, 0.50),
		"metal": Color(0.20, 0.28, 0.26),
	}
	var shrine_quality := str(settings.settings.get("quality_preset", "balanced"))
	for surface_index in shrine_mesh.get_surface_count():
		var surface_name := shrine_mesh.surface_get_name(surface_index)
		if not shrine_tints.has(surface_name):
			push_error("Unknown authored Greyfen shrine surface: " + surface_name)
			return
		var material_role := surface_name if world_materials.SURFACES.has(surface_name) else "metal"
		var material: StandardMaterial3D = _mat(shrine_tints[surface_name]) if surface_name == "glazing" else world_materials.get_material(material_role, shrine_quality, shrine_tints[surface_name], 0.0, false)
		shrine.set_surface_override_material(surface_index, material)
	_make_collision_box("ShrinePlinth", pos + Vector3(0, 0.18, 0), Vector3(2.36, 0.36, 1.64))
	_make_collision_box("ShrineOathstone", pos + Vector3(0, 0.96, 0), Vector3(0.88, 1.10, 0.62))
	_make_loose_role("crate", pos + Vector3(-1.15, 0, -0.65), Vector3.ONE * 0.48, -12.0)
	# Keep shrine dressing off the diagonal Greyfen-to-Castle approach. This
	# barrel used to sit directly on the player-sized route after returning from
	# Wychwood, making the Castle gateway fail its real capsule sweep.
	_make_loose_role("barrel", pos + Vector3(1.2, 0, 1.40), Vector3.ONE * 0.42, 16.0)
	_make_light("ShrineGlow", pos + Vector3(0, 1.7, -0.3), Color(0.56, 0.78, 0.62), 1.6)
	_make_world_prop_anchor("shrine", "shrine", pos, "crow_shrine_state")

func _make_blacksmith_scene(pos: Vector3) -> void:
	var forge_mesh := load("res://assets_external/environment/village/GreyfenForge_Authored.res") as ArrayMesh
	if forge_mesh == null or forge_mesh.get_surface_count() != 6:
		push_error("Required authored Greyfen forge is unavailable")
		return
	var shop := Node3D.new()
	shop.name = "GreyfenBlacksmithStoneShop"
	shop.position = pos
	zone_root.add_child(shop)
	var workshop := MeshInstance3D.new()
	workshop.name = "BlacksmithAuthoredForge"
	workshop.mesh = forge_mesh
	shop.add_child(workshop)
	var forge_tints := {
		"medieval_brick": Color(0.66, 0.62, 0.55),
		"plaster": Color(0.77, 0.69, 0.57),
		"timber": Color(0.42, 0.31, 0.21),
		"roof_tiles": Color(0.40, 0.26, 0.20),
		"glazing": Color(0.16, 0.22, 0.24),
		"metal": Color(0.30, 0.30, 0.29),
	}
	var forge_quality := str(settings.settings.get("quality_preset", "balanced"))
	for surface_index in forge_mesh.get_surface_count():
		var surface_name := forge_mesh.surface_get_name(surface_index)
		if not forge_tints.has(surface_name):
			push_error("Unknown authored Greyfen forge surface: " + surface_name)
			return
		var material_role := surface_name if world_materials.SURFACES.has(surface_name) else "metal"
		var material: StandardMaterial3D = _mat(forge_tints[surface_name]) if surface_name == "glazing" else world_materials.get_material(material_role, forge_quality, forge_tints[surface_name], 0.0, false)
		workshop.set_surface_override_material(surface_index, material)
	_make_collision_box("BlacksmithRearWall", pos + Vector3(0, 1.27, 2.33), Vector3(3.4, 1.94, 0.20))
	for side in [-1.0, 1.0]:
		_make_collision_box("BlacksmithSideWall", pos + Vector3(side * 1.69, 1.27, 1.2), Vector3(0.20, 1.94, 2.4))
	_make_collision_box("ForgeHearth", pos + Vector3(1.5, 0.30, -1.1), Vector3(0.96, 0.55, 0.88))
	_make_collision_box("ForgeCoal", pos + Vector3(1.5, 0.38, -1.1), Vector3(0.62, 0.08, 0.48))
	_make_light("ForgeLight", pos + Vector3(1.5, 1.5, -1.1), Color(1.0, 0.35, 0.12), 2.5)
	var work := MeshInstance3D.new()
	work.name = "BlacksmithFittedWork"
	work.mesh = load("res://assets_external/environment/props/GreyfenForgeWork_Authored.res") as ArrayMesh
	if work.mesh == null:
		push_error("Greyfen requires its fitted anvil, workbench, stock and fuel")
		work.free()
		return
	shop.add_child(work)
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
	var presentation_id: String = {"witness_-7": "mira", "witness_-3": "rook", "witness_3": "sister_anwen"}.get(id, id)
	if id in ["notice_board", "side_contracts"]:
		# The supported notice-board assembly owns both visible notices. These
		# areas own dialogue/focus, not a second capsule-shaped prop.
		area.set_meta("external_world_prop", "notice_board")
	elif id == "white_hart":
		# The finale builder owns the visible witness; this area owns interaction only.
		area.set_meta("external_character_visual", "WhiteHartWitnessDisplay")
	elif type == "clue" and current_zone_id == "wychwood" and WychwoodEvidencePresentation.apply(area, id):
		pass
	elif type == "clue" and CemeteryEvidencePresentation.apply(area, id):
		pass
	elif CampaignRecordPresentation.apply(area, id):
		pass
	elif should_defer_character_role(role, id):
		var marker := Node3D.new()
		marker.name = "DeferredCharacterVisual_%s" % id
		marker.set_meta("deferred_visual_role", role)
		marker.set_meta("deferred_visual_category", "characters")
		marker.set_meta("deferred_visual_actor_id", presentation_id)
		marker.set_meta("deferred_visual_scale", Vector3.ONE)
		area.add_child(marker)
		area.set_meta("character_variant_seed", presentation_id)
	else:
		var mapped = _make_role_visual(role, "characters", Vector3.ONE)
		if mapped != null:
			area.add_child(mapped)
			area.set_meta("character_variant_seed", presentation_id)
			_configure_npc_animation(mapped, presentation_id)
		elif id in ["assembly_choice", "witness_7"]:
			_make_ledger_interaction_visual(area, Vector3.ONE)
			var book := area.get_node("SealedCommandLedgerVisual") as Node3D
			book.position.y = 0.83
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
	if type == "dialogue" and id not in ["notice_board", "white_hart"] and has_character_role and not should_defer_character_role(role, id):
		CharacterPresentation.apply_npc(area, presentation_id)
	if current_zone_id == "assembly" and id in ["witness_-7", "witness_-3", "witness_3"]:
		# Testimony is focal staging, not a distant crowd LOD. The normal camera
		# can sit beyond the generic villager cutoff even inside this small court.
		for witness_mesh in area.find_children("*", "MeshInstance3D", true, false):
			witness_mesh.visibility_range_end = maxf(witness_mesh.visibility_range_end, 32.0)
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
		ambient.setup(presentation_id, player)
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
	var table: MeshInstance3D = null
	var mesh: BoxMesh = null
	if id in ["forge_corner", "tor_forge"]:
		# The authored workshop is the visible prop for both interactions.
		pass
	elif id in ["common_table", "barrel_board", "mira_apothecary"]:
		GreyfenSocialPresentation.apply(area, id)
		if type == "minigame":
			_make_board_game_staging(area, id, size)
	else:
		table = MeshInstance3D.new()
		table.name = "%s_VisibleProp" % id
		mesh = BoxMesh.new()
	if table == null:
		pass
	elif id == "village_well":
		table.position.y = 0.0
	elif id == "shrine_prayer":
		mesh.size = Vector3(size.x, 0.12, size.z)
		table.position.y = 0.48
		table.material_override = _mat(color.lightened(0.12))
		var supports := _make_multimesh_batch("ShrineBenchSupports", shared_box_mesh, 2, _mat(color.darkened(0.12)))
		supports.reparent(area, false)
		for index in range(2):
			var x := -size.x * 0.38 if index == 0 else size.x * 0.38
			supports.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3(0.18, 0.42, size.z * 0.75)), Vector3(x, 0.21, 0.0)))
	elif type == "minigame":
		# A board-game table has visible legs, a thin worn top, two seats, and an
		# opponent. It should read as a social place before the overlay opens.
		mesh.size = Vector3(size.x, 0.16, size.z)
		table.position.y = size.y
		table.material_override = _mat(color.darkened(0.10))
		var legs := _make_multimesh_batch("%s_TableLegs" % id, shared_box_mesh, 4, _mat(color.darkened(0.20)))
		legs.reparent(area, false)
		legs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var leg_index := 0
		for x in [-size.x * 0.38, size.x * 0.38]:
			for z in [-size.z * 0.34, size.z * 0.34]:
				legs.multimesh.set_instance_transform(leg_index, Transform3D(Basis.IDENTITY.scaled(Vector3(0.14, size.y * 0.92, 0.14)), Vector3(x, size.y * 0.46, z)))
				leg_index += 1
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
		var posts := _make_multimesh_batch("%s_CanopyPosts" % id, shared_box_mesh, 2, _mat(color.darkened(0.25)))
		posts.reparent(area, false)
		posts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var crates := _make_multimesh_batch("%s_StockCrates" % id, shared_box_mesh, 2, _mat(color.darkened(0.28)))
		crates.reparent(area, false)
		crates.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for index in range(2):
			var side := -1.0 if index == 0 else 1.0
			posts.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3(0.10, 1.55, 0.10)), Vector3(side * size.x * 0.42, size.y * 0.78, 0.0)))
			crates.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3(0.36, 0.30, 0.36)), Vector3(side * size.x * 0.30, 0.18, size.z * 0.58)))
		_make_light("%s_ShopGlow" % id, pos + Vector3(0, 1.25, 0), color.lightened(0.18), 0.7)
	else:
		mesh.size = size
		table.position.y = size.y * 0.5
		table.material_override = _mat(color)
	if table != null:
		table.mesh = mesh
		area.add_child(table)
	if id == "village_well":
		_apply_greyfen_well_visual(table, pos)
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

func _apply_greyfen_well_visual(visual: MeshInstance3D, pos: Vector3) -> void:
	var well_mesh := opening_well_mesh if opening_well_mesh != null else load("res://assets_external/environment/village/GreyfenWell_Authored.res") as ArrayMesh
	if well_mesh == null or well_mesh.get_surface_count() != 6:
		push_error("Required authored Greyfen well is unavailable")
		return
	visual.mesh = well_mesh
	var well_tints := {
		"medieval_brick": Color(0.69, 0.67, 0.61),
		"plaster": Color(0.72, 0.72, 0.67),
		"timber": Color(0.44, 0.33, 0.22),
		"roof_tiles": Color(0.42, 0.24, 0.16),
		"glazing": Color(0.10, 0.25, 0.29),
		"metal": Color(0.24, 0.27, 0.27),
	}
	var well_quality := str(settings.settings.get("quality_preset", "balanced"))
	for surface_index in well_mesh.get_surface_count():
		var surface_name := well_mesh.surface_get_name(surface_index)
		if not well_tints.has(surface_name):
			push_error("Unknown authored Greyfen well surface: " + surface_name)
			return
		var material: StandardMaterial3D = _mat(well_tints[surface_name]) if surface_name == "glazing" else world_materials.get_material(surface_name, well_quality, well_tints[surface_name], 0.0, false)
		visual.set_surface_override_material(surface_index, material)
	var body := StaticBody3D.new()
	body.name = "GreyfenWellBody"
	body.position = pos + Vector3(0, 0.42, 0)
	zone_root.add_child(body)
	var collision := CollisionShape3D.new()
	collision.name = "GreyfenWellCollision"
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.87
	cylinder.height = 0.84
	collision.shape = cylinder
	body.add_child(collision)

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
	var square_size := Vector3(board_size.x / columns - 0.018, 0.018, board_size.y / rows - 0.018)
	var square_batches: Array[MultiMeshInstance3D] = []
	for parity in range(2):
		var count := (columns * rows + 1) / 2 if parity == 0 else columns * rows / 2
		var material := _mat(Color(0.38, 0.24, 0.12) if parity == 0 else Color(0.16, 0.095, 0.045))
		var batch := _make_multimesh_batch("%s_BoardSquares_%d" % [id, parity], shared_box_mesh, int(count), material)
		batch.reparent(area, false)
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		square_batches.append(batch)
	var square_indices := [0, 0]
	for row in range(rows):
		for column in range(columns):
			var x := -board_size.x * 0.5 + board_size.x * (float(column) + 0.5) / float(columns)
			var z := -board_size.y * 0.5 + board_size.y * (float(row) + 0.5) / float(rows)
			var parity := (row + column) % 2
			square_batches[parity].multimesh.set_instance_transform(square_indices[parity], Transform3D(Basis.IDENTITY.scaled(square_size), Vector3(x, size.y + 0.14, z)))
			square_indices[parity] += 1
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
	var chair_batch: MultiMeshInstance3D = null
	if not bool(area.get_meta("authored_social_furniture", false)):
		chair_batch = _make_multimesh_batch("%s_ChairParts" % id, shared_box_mesh, 4, _mat(Color(0.20, 0.12, 0.065)))
		chair_batch.reparent(area, false)
		chair_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_make_board_game_chair(area, Vector3(0.0, 0.0, size.z * 0.90), PI, chair_batch, 0)
	_make_board_game_chair(area, Vector3(0.0, 0.0, -size.z * 0.90), 0.0, chair_batch, 2)
	var opponent_role := "rook_smuggler" if id == "common_table" else "blacksmith_tor"
	var opponent_id := "board_rook" if id == "common_table" else "board_tor"
	if should_defer_character_role(opponent_role, opponent_id):
		var deferred_opponent := Node3D.new()
		deferred_opponent.name = "%s_Opponent" % id
		deferred_opponent.position = Vector3(0.0, 0.0, size.z * 0.92)
		deferred_opponent.rotation_degrees.y = 180.0
		area.add_child(deferred_opponent)
		var marker := Node3D.new()
		marker.name = "DeferredCharacterVisual_%s" % opponent_id
		marker.set_meta("deferred_visual_role", opponent_role)
		marker.set_meta("deferred_visual_category", "characters")
		marker.set_meta("deferred_visual_actor_id", opponent_id)
		marker.set_meta("deferred_visual_scale", Vector3.ONE)
		deferred_opponent.add_child(marker)
		var deferred_gesture := BoardGameOpponent.new()
		deferred_gesture.name = "BoardGameOpponentController"
		deferred_opponent.add_child(deferred_gesture)
		deferred_gesture.configure(player, null)
		var deferred_ambient := NpcAmbient.new()
		deferred_ambient.setup("rook" if id == "common_table" else "blacksmith_tor", player)
		deferred_opponent.add_child(deferred_ambient)
		return
	var opponent := _make_role_visual(opponent_role, "characters", Vector3.ONE)
	if opponent == null:
		return
	opponent.name = "%s_Opponent" % id
	opponent.position = Vector3(0.0, 0.0, size.z * 0.92)
	opponent.rotation_degrees.y = 180.0
	area.add_child(opponent)
	CharacterPresentation.apply_npc(opponent, opponent_id)
	_configure_npc_animation(opponent, "board_rook" if id == "common_table" else "board_tor")
	var gesture_controller := BoardGameOpponent.new()
	gesture_controller.name = "BoardGameOpponentController"
	opponent.add_child(gesture_controller)
	gesture_controller.configure(player, opponent.find_child("CharacterAnimationDriver", true, false))
	var ambient := NpcAmbient.new()
	ambient.setup("rook" if id == "common_table" else "blacksmith_tor", player)
	opponent.add_child(ambient)

func _make_board_game_chair(area: Node3D, position: Vector3, yaw: float, batch: MultiMeshInstance3D, first_index: int) -> void:
	var chair := Node3D.new()
	chair.name = "BoardGameChair_North" if position.z < 0.0 else "BoardGameChair_South"
	chair.position = position
	chair.rotation.y = yaw
	area.add_child(chair)
	if batch == null:
		return
	var orientation := Basis(Vector3.UP, yaw)
	batch.multimesh.set_instance_transform(first_index, Transform3D(orientation.scaled(Vector3(0.90, 0.14, 0.82)), position + orientation * Vector3(0.0, 0.62, 0.0)))
	batch.multimesh.set_instance_transform(first_index + 1, Transform3D(orientation.scaled(Vector3(0.90, 0.90, 0.12)), position + orientation * Vector3(0.0, 1.02, 0.32)))

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
	if id not in ["board_rook", "board_tor"]:
		load("res://scripts/grounded_feet_modifier.gd").install_npc(mapped, driver)
	# Non-player rigs do not own physics or combat timing. Drive them through a
	# phase-staggered manual clock so imported skin evaluation cannot wake every
	# skeleton on every rendered frame. The player and active enemies retain
	# their explicit gameplay rates. Eight Hz is still frequent enough for an
	# idle or conversation pose at the camera distances used by these actors,
	# while removing the synchronized 20 Hz/idle-callback spikes measured in the
	# Castle and Record Hall performance samples.
	var npc_animation_rate := 8.0
	driver.set_update_rate_hz(npc_animation_rate)

func _stage_dialogue_moment(area) -> void:
	if not (area is Node3D):
		return
	dialogue_runtime_coordinator.stage(area, player, camera_rig, validate_walkable_position)

func _on_dialogue_page_changed(_speaker: String, _speaker_id: String, _page_index: int, _total_pages: int) -> void:
	var page: Dictionary = hud.get_current_dialogue_page()
	var read_only: bool = bool(page.get("read_only", false))
	# Optional questions enter the existing reading history, without registering
	# new story evidence or changing a person's commitments. Persist on close.
	if read_only:
		story_save_pending = true
	var encounter: Dictionary = {} if read_only else preload("res://scripts/story_journal.gd").encounter_record(_speaker_id, current_zone_id)
	if not encounter.is_empty():
		var encounter_id: String = str(encounter.get("id", ""))
		if encounter_id != "" and not story_state.has_evidence(encounter_id):
			# Record only the speaker whose words are currently displayed. Later
			# participants remain undiscovered until their own page is reached.
			story_state.record_evidence(encounter_id, encounter.get("entry", {}))
			story_save_pending = true
	dialogue_runtime_coordinator.refresh_page(player, camera_rig, page)
	if audio != null:
		audio.set_dialogue_active(true)
		audio.play_dialogue_page(page)
	preload("res://scripts/story_performance.gd").page(dialogue_runtime_coordinator.get_focus_actor(), page)

func _on_dialogue_topic_requested(context_id: String, topic_id: String, revision_key: String) -> void:
	# A reading request never re-enters interaction or action dispatch. Resolve
	# against the still-present speaker and current knowledge at selection time.
	var context: Dictionary = dialogue_runtime_coordinator.get_topic_context(context_id)
	if resource_shutdown_prepared or _journey_load_pending() or context.is_empty() or str(context.get("zone_id", "")) != current_zone_id:
		hud.dialogue_topic_unavailable(context_id)
		return
	var topic: Dictionary = dialogue.get_conversation_topic(topic_id, str(context.get("actor_id", "")), current_zone_id, revision_key)
	if topic.is_empty():
		hud.dialogue_topic_unavailable(context_id)
		return
	topic["topic_context_id"] = context_id
	hud.show_dialogue_topic(topic)

func _face_npc_toward_player(npc: Node3D) -> void:
	dialogue_runtime_coordinator.face_actor(npc, player)

func _release_dialogue_facing() -> void:
	audio.stop_voice()
	audio.set_dialogue_active(false)
	preload("res://scripts/story_performance.gd").finish(dialogue_runtime_coordinator.get_focus_actor())
	interaction_input_block_until_usec = Time.get_ticks_usec() + int(DIALOGUE_INTERACTION_GUARD_SECONDS * 1000000.0)
	dialogue_runtime_coordinator.release(player)
	if zone_root == null:
		return
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
		if body == player and is_instance_valid(area) and not area.is_queued_for_deletion() and not bool(area.get_meta("seamless_exterior_gate", false)) and area not in interaction_candidates:
			interaction_candidates.append(area)
			interaction_focus_dirty = true
	)
	area.body_exited.connect(func(body: Node):
		if body == player:
			_remove_interaction_candidate(area)
			if is_instance_valid(area):
				_set_interactable_label_visible(area,false)
			if is_instance_valid(active_interactable) and is_instance_valid(area) and active_interactable == area:
				active_interactable = null
			interaction_focus_dirty = true
	)

func _update_interaction_focus() -> void:
	_refresh_interaction_candidates()
	for index in range(interaction_candidates.size() - 1, -1, -1):
		var candidate = interaction_candidates[index]
		if candidate == null or not is_instance_valid(candidate):
			interaction_candidates.remove_at(index)
			continue
		if bool(candidate.get_meta("seamless_exterior_gate", false)):
			interaction_candidates.remove_at(index)
	var camera: Camera3D = get_viewport().get_camera_3d()
	var best = zone_runtime_coordinator.choose_interaction(interaction_candidates, player, camera, Callable(self, "_interaction_target_valid")) if zone_runtime_coordinator != null else null
	if active_interactable != best:
		if active_interactable != null and is_instance_valid(active_interactable):
			_set_interactable_label_visible(active_interactable,false)
		active_interactable = best
		compass_dirty = true
		if active_interactable != null:
			_set_interactable_label_visible(active_interactable,true)
	_publish_interaction_prompt()
	interaction_focus_dirty = false
	interaction_focus_cache_valid = true
	last_focus_position = player.global_position
	var camera_after_update: Camera3D = get_viewport().get_camera_3d()
	last_focus_forward = (-camera_after_update.global_basis.z).normalized() if camera_after_update != null else (-player.global_basis.z).normalized()

func _interaction_focus_needs_refresh() -> bool:
	if player == null or interaction_focus_dirty or not interaction_focus_cache_valid:
		return true
	if interaction_focus != null and interaction_focus.needs_refresh():
		return true
	if active_interactable != null and (not is_instance_valid(active_interactable) or not _interaction_target_valid(active_interactable)):
		return true
	if player.global_position.distance_squared_to(last_focus_position) >= 0.0064:
		return true
	var camera: Camera3D = get_viewport().get_camera_3d()
	var current_forward: Vector3 = (-camera.global_basis.z).normalized() if camera != null else (-player.global_basis.z).normalized()
	return last_focus_forward.is_zero_approx() or last_focus_forward.dot(current_forward) < 0.9995

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
	_prune_invalid_interaction_candidates()
	# Area signals are authoritative during ordinary movement, but can be missed
	# when a save, spawn, or zone arrival places Kael inside a trigger between
	# physics ticks. A small bounded scan keeps prompts deterministic without
	# walking the entire world or inventing a second focus system.
	for index in range(interaction_area_cache.size() - 1, -1, -1):
		var candidate = interaction_area_cache[index]
		if candidate == null or not is_instance_valid(candidate):
			# Do not pass a freed object back to a typed Array[Area3D].
			# remove_at(index) remains valid even after Godot has invalidated the
			# object reference during deferred clue/zone teardown.
			interaction_area_cache.remove_at(index)
			continue
		if candidate.is_queued_for_deletion() or not candidate.has_method("get_context_prompt"):
			continue
		if not candidate.is_visible_in_tree() or (candidate.has_method("is_interaction_enabled") and not candidate.is_interaction_enabled()):
			continue
		if bool(candidate.get_meta("seamless_exterior_gate", false)):
			continue
		var candidate_type := str(candidate.get("interaction_type"))
		var range_limit := 3.6 if candidate_type in ["zone", "dialogue"] else 2.8
		if candidate.global_position.distance_to(player.global_position) <= range_limit:
			if str(candidate.get("interaction_type")) == "zone":
				var portal := candidate.find_child("OathGatePortal", true, false) as OathGatePortal
				if portal != null and portal.state == OathGatePortal.PortalState.DORMANT:
					portal.begin_preload()
			if candidate in interaction_candidates:
				continue
			interaction_candidates.append(candidate)

func _prune_invalid_interaction_candidates() -> void:
	for index in range(interaction_candidates.size() - 1, -1, -1):
		var candidate = interaction_candidates[index]
		if candidate == null or not is_instance_valid(candidate):
			interaction_candidates.remove_at(index)

func _remove_interaction_candidate(area) -> void:
	if interaction_focus != null:
		interaction_focus.forget(area)
	for index in range(interaction_candidates.size() - 1, -1, -1):
		var candidate = interaction_candidates[index]
		if candidate == null or not is_instance_valid(candidate):
			interaction_candidates.remove_at(index)
			continue
		if area != null and is_instance_valid(area) and candidate == area:
			interaction_candidates.remove_at(index)

func _interaction_target_valid(area: Area3D) -> bool:
	return interaction_focus != null and interaction_focus.target_is_valid(area, player, get_viewport().get_camera_3d())

func _set_interactable_label_visible(area: Node, visible: bool) -> void:
	var label := area.find_child("InteractionWorldLabel", true, false) as Label3D
	if label != null:
		label.visible = visible

func _spawn_enemy(id: String, pos: Vector3, visual_role: String = "") -> Node:
	if _boss_is_resolved(id):
		return null
	if active_enemies.size() >= 5:
		return null
	pos = river_safe_position(pos,1.2)
	# Enemy roots use the same floor-origin contract as the player. Only
	# explicitly airborne roles retain an authored vertical spawn offset.
	if not CharacterRoleSpec.is_airborne(id):
		pos.y = 0.0
	var enemy = EnemyAI.new()
	enemy.visual_role_override = visual_role
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
	preload("res://scripts/story_encounter_director.gd").apply(self, enemy)
	for peer in active_enemies:
		if is_instance_valid(peer) and peer.has_method("set_encounter_peers"):
			peer.set_encounter_peers(active_enemies)
	_sync_camera_enemy_cache()
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
	# The chapel shell is occupied scenery. Spawn the boss in the broad west
	# cemetery approach so spatial recovery cannot relocate it outside its arena.
	var boss := _spawn_enemy("bell_eater", Vector3(10.0, 0.8, 8.0))
	if boss != null:
		boss.name = "BellEaterEncounter"
		boss.leash_radius = 9.0
		boss.set_meta("boss_arena", "cemetery")
		_evacuate_bell_eater_bystanders()
		hud.show_status_cue("The Bell-Eater wakes", "danger")
		hud.toast("The bell rings once beneath the chapel. Something large pulls against the graves.")
		_show_current_objective_guidance(6.0)
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
	_apply_boss_resolution_contract(boss_id)
	for candidate in active_enemies:
		if not is_instance_valid(candidate) or str(candidate.enemy_id) != boss_id:
			continue
		var controller: Node = candidate.get_node_or_null("BossEncounterController")
		if controller != null and controller.has_method("save_state"):
			boss_saved_states[boss_id] = controller.save_state()
		break
	if save_manager != null and player != null and is_instance_valid(player) and not resource_shutdown_prepared:
		save_manager.checkpoint(self)

func _apply_boss_resolution_contract(boss_id: String) -> void:
	var definition: Dictionary = boss_defs.get(boss_id, {})
	if definition.is_empty():
		return
	var grant_key := "boss_reward_granted_%s" % boss_id
	if not bool(story_state.get_flag(grant_key, false)):
		var rewards: Variant = definition.get("rewards", [])
		if typeof(rewards) == TYPE_ARRAY:
			for reward_id in rewards:
				var reward := str(reward_id).strip_edges()
				if reward != "":
					story_state.set_flag("boss_reward_%s" % reward, true)
		story_state.set_flag(grant_key, true)
	var aftermath := str(definition.get("aftermath_state", "")).strip_edges()
	if aftermath != "":
		story_state.set_flag(aftermath, true)

func _publish_halvern_exit() -> void:
	if current_zone_id == "undercroft" and str(story_state.get_flag("halvern_fate", "")) != "" and not _has_interactable("gate_assembly"):
		_make_zone_gate("Return to Greyfen for the assembly", Vector3(6, 0, -14), "assembly", Vector3(0, 1, 12))

func _on_boss_peaceful_resolution(boss_id: String, outcome: String, enemy: Node) -> void:
	story_state.set_flag("boss_%s_outcome" % boss_id, outcome)
	if boss_id == "halvern_boss":
		story_state.set_flag("halvern_fate", "witness" if outcome in ["testimony", "release", "witness"] else outcome)
		_publish_halvern_exit()
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

func _make_ground(pos: Vector3, size: Vector3, color: Color, collision_enabled: bool = true) -> void:
	var parent: Node3D = zone_root
	if collision_enabled:
		var body := StaticBody3D.new()
		body.position = pos
		zone_root.add_child(body)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		parent = body
	var mesh := MeshInstance3D.new()
	mesh.mesh = world_materials.make_tiled_box(size, pos)
	mesh.position = Vector3.ZERO if collision_enabled else pos
	mesh.material_override = _terrain_material("CampaignGround", color)
	mesh.set_meta("split_ground_size", size)
	mesh.set_meta("split_ground_origin", pos)
	parent.add_child(mesh)

func _make_split_ground(width: float, depth: float, river_z: float, river_span: float, color: Color, bridge_width: float = 0.0, bridge_length: float = 0.0, bridge_approach_length: float = 0.0) -> void:
	var south_edge := river_z + river_span * 0.5
	var north_edge := river_z - river_span * 0.5
	var north_depth := north_edge + depth * 0.5
	var south_depth := depth * 0.5 - south_edge
	if bridge_width > 0.0 and bridge_length > 0.0 and bridge_approach_length > 0.0:
		var side_width := maxf((width - bridge_width) * 0.5, 0.1)
		var side_center := bridge_width * 0.5 + side_width * 0.5
		_make_ground(Vector3(-side_center,-0.08,-depth*0.5+north_depth*0.5),Vector3(side_width,0.16,north_depth),color)
		_make_ground(Vector3(side_center,-0.08,-depth*0.5+north_depth*0.5),Vector3(side_width,0.16,north_depth),color)
		_make_ground(Vector3(-side_center,-0.08,south_edge+south_depth*0.5),Vector3(side_width,0.16,south_depth),color)
		_make_ground(Vector3(side_center,-0.08,south_edge+south_depth*0.5),Vector3(side_width,0.16,south_depth),color)
		# The center lane is split into bank approaches and one short bridge
		# surface. Keeping these extents finite prevents a stale zone-wide box
		# from owning the bank/bridge seam and lets the visual ramp meet one
		# authoritative collision surface.
		var support_half_length := bridge_length * 0.5 + bridge_approach_length
		var north_corridor_end := river_z - support_half_length
		var north_corridor_depth := maxf(north_corridor_end + depth * 0.5, 0.0)
		if north_corridor_depth > 0.05:
			# Keep the center-lane mesh visual-only. One continuous collision slab
			# below removes the exposed vertical face at the bank/bridge seam.
			_make_ground(Vector3(0.0,-0.08,-depth*0.5+north_corridor_depth*0.5), Vector3(bridge_width,0.16,north_corridor_depth), color, false)
		var south_corridor_start := river_z + support_half_length
		var south_corridor_depth := maxf(depth * 0.5 - south_corridor_start, 0.0)
		if south_corridor_depth > 0.05:
			_make_ground(Vector3(0.0,-0.08,south_corridor_start+south_corridor_depth*0.5), Vector3(bridge_width,0.16,south_corridor_depth), color, false)
		_make_bridge_corridor_collision(bridge_width, river_z, bridge_length, bridge_approach_length, depth)
		return
	_make_ground(Vector3(0,-0.08,-depth*0.5+north_depth*0.5),Vector3(width,0.16,north_depth),color)
	_make_ground(Vector3(0,-0.08,south_edge+south_depth*0.5),Vector3(width,0.16,south_depth),color)

func _make_bridge_corridor_collision(bridge_width: float, river_z: float, bridge_length: float, approach_length: float, zone_depth: float) -> void:
	var body := StaticBody3D.new()
	body.name = "RiverBridgeContinuousSurface"
	# The visual bank meshes remain split around the water, but the center lane
	# uses one continuous surface across both joins. This prevents a CharacterBody
	# capsule from catching the coplanar vertical faces of touching floor boxes.
	body.position = Vector3(0.0, 0.0, 0.0)
	zone_root.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	var support_length := maxf(zone_depth, bridge_length + approach_length * 2.0)
	shape.size = Vector3(bridge_width, 0.20, support_length)
	collision.position = Vector3(0.0, -0.10, 0.0)
	collision.shape = shape
	body.add_child(collision)

func _make_hut(pos: Vector3) -> void:
	_make_prop_box("Hut", pos + Vector3(0, 1, 0), Vector3(3.6, 2, 3.0), Color(0.22, 0.16, 0.12))
	_make_prop_box("Roof", pos + Vector3(0, 2.25, 0), Vector3(4.2, 0.8, 3.6), Color(0.10, 0.09, 0.08))
	_make_prop_box("Door", pos + Vector3(0, 0.65, -1.54), Vector3(0.75, 1.25, 0.08), Color(0.10, 0.07, 0.045))
	_make_prop_box("Chimney", pos + Vector3(1.1, 2.95, 0.4), Vector3(0.38, 0.9, 0.38), Color(0.12, 0.11, 0.10))

func _make_tree(pos: Vector3) -> void:
	# Gate and bridge corridors are reserved before scenery is authored. Keep the
	# original request out of those volumes instead of nudging it back into the
	# player route with _route_safe_position().
	# Greyfen's cemetery is a composed investigation site. The boundary wall
	# and village cluster otherwise place full tree crowns over its bell and
	# chapel, despite their trunks sitting outside the walkable court.
	if current_zone_id == "greyfen" and pos.x > 10.0 and pos.z > 7.5 and pos.z < 18.0:
		return
	if spatial_service != null and spatial_service.is_reserved(pos, 1.35):
		return
	if _is_river_excluded(pos,1.5):
		return
	pos = _route_safe_position(pos, 4.9)
	if spatial_service != null and spatial_service.is_reserved(pos, 1.35):
		return
	if _is_first_route_clearance(pos, 1.55):
		return
	if current_zone_id == "greyfen":
		for house in get_tree().get_nodes_in_group("greyfen_house"):
			if not zone_root.is_ancestor_of(house):
				continue
			var house_position: Vector3 = zone_root.to_local((house as Node3D).global_position)
			if Vector2(pos.x, pos.z).distance_to(Vector2(house_position.x, house_position.z)) < 5.5:
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
	elif current_zone_id == "wychwood":
		tree_role = "forest_tree_secondary"
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

func _clear_environment_batch_buffers() -> void:
	# Build-time arrays are only transform carriers. Once copied into their
	# MultiMesh nodes they must be released, otherwise a later detail stage would
	# rebatch the entire zone and duplicate geometry.
	tree_batch_data.clear()
	deadfall_batch_data.clear()
	prop_batch_data.clear()
	visual_box_batch_data.clear()
	terrain_patch_batch_data.clear()
	house_batch_data.clear()
	house_module_batch_data.clear()

func _flush_environment_batches() -> void:
	var terrain_groups: Dictionary = {}
	for item in terrain_patch_batch_data:
		var terrain_key := str(item.material.get_instance_id())
		if not terrain_groups.has(terrain_key):
			terrain_groups[terrain_key] = {"material":item.material,"items":[]}
		terrain_groups[terrain_key].items.append(item)
	for terrain_key in terrain_groups:
		var terrain_group: Dictionary = terrain_groups[terrain_key]
		var terrain_items: Array = terrain_group.items
		var terrain_batch := MeshInstance3D.new()
		terrain_batch.name = "TerrainPatchBatch_%s" % terrain_key
		var surface := SurfaceTool.new()
		for i in range(terrain_items.size()):
			var marker: Node3D = terrain_items[i].node
			var patch_size: Vector3 = terrain_items[i].size
			var patch_mesh: ArrayMesh = world_materials.make_organic_ground_patch(patch_size, marker.position, marker.basis) if current_zone_id == "wychwood" else world_materials.make_tiled_ground_patch(patch_size, marker.position, marker.basis)
			surface.append_from(patch_mesh, 0, marker.transform)
			# This node is a build-only transform carrier; the merged mesh now owns
			# its geometry. Defer removal until the current scene-tree
			# notification finishes so RenderingServer can unregister the instance
			# without leaving a detached renderer allocation.
			marker.queue_free()
		terrain_batch.mesh = surface.commit()
		terrain_batch.material_override = terrain_group.material
		zone_root.add_child(terrain_batch)
	var visual_groups: Dictionary = {}
	for item in visual_box_batch_data:
		var color: Color = item.color
		var use_instance_colors: bool = current_zone_id != "record_hall"
		var visual_key := "instance_colors" if use_instance_colors else color.to_html(true)
		var night_only: bool = item.node.get_meta("night_only_geometry", false)
		if night_only:
			visual_key = "night_" + visual_key
		if not visual_groups.has(visual_key):
			var material: StandardMaterial3D
			if use_instance_colors:
				if not material_cache.has("detail_instance_colors"):
					var shared_material := StandardMaterial3D.new()
					shared_material.roughness = 0.9
					shared_material.vertex_color_use_as_albedo = true
					material_cache["detail_instance_colors"] = shared_material
				material = material_cache["detail_instance_colors"]
			else:
				material = _mat(color)
			visual_groups[visual_key] = {"material": material, "colors": use_instance_colors, "night_only": night_only, "items": []}
		visual_groups[visual_key].items.append(item)
	for visual_key in visual_groups:
		var group: Dictionary = visual_groups[visual_key]
		var items: Array = group.items
		var detail_batch := _make_multimesh_batch("AuthoredDetailBatch_%s" % visual_key, shared_box_mesh, items.size(), group.material, group.colors)
		if group.night_only:
			detail_batch.set_meta("night_only_geometry", true)
		for i in range(items.size()):
			var marker: Node3D = items[i].node
			var detail_size: Vector3 = items[i].size
			detail_batch.multimesh.set_instance_transform(i, Transform3D(marker.basis.scaled(detail_size), marker.position))
			if group.colors:
				detail_batch.multimesh.set_instance_color(i, items[i].color)
			# Like terrain markers, these nodes have no runtime purpose after the
			# batched transform has been copied. Defer removal for the same
			# scene-tree/renderer ownership reason as terrain markers.
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
		if str(house_key).begins_with("emissive_window:"):
			house_batch.set_meta("night_window_material", house_group.material)
			house_batch.set_meta("night_window_color", house_group.material.albedo_color)
		for transform_index in range(house_transforms.size()):
			house_batch.multimesh.set_instance_transform(transform_index, house_transforms[transform_index])
			house_batch.multimesh.set_instance_color(transform_index, house_group.colors[transform_index])
	for batch_key in house_module_batch_data:
		var module_group: Dictionary = house_module_batch_data[batch_key]
		var module_transforms: Array = module_group.transforms
		if module_transforms.is_empty():
			continue
		var module_batch := _make_multimesh_batch(
			"HouseModuleBatch_%s" % batch_key,
			module_group.mesh,
			module_transforms.size(),
			null
		)
		# Preserve each imported material group rather than replacing the
		# entire module with the generic static-batch material.
		module_batch.material_override = null
		for index in range(module_transforms.size()):
			module_batch.multimesh.set_instance_transform(index, module_transforms[index])
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
		if preview is MeshInstance3D:
			mesh_nodes.push_front(preview)
		var source_mesh: Mesh = null
		var source_material: Material = null
		for raw_node in mesh_nodes:
			var source := raw_node as MeshInstance3D
			if source == null or source.mesh == null:
				continue
			source_mesh = source.mesh
			source_material = source.material_override
			if source_material == null and source_mesh.get_surface_count() == 1:
				source_material = source_mesh.surface_get_material(0)
			break
		preview.free()
		if source_mesh == null:
			return false
		var source_bounds := source_mesh.get_aabb()
		if source_bounds.size.y <= 0.001:
			return false
		var source_scale := 6.0 / source_bounds.size.y
		var source_normalization := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * source_scale),
			Vector3(0, -source_bounds.position.y * source_scale, 0))
		if source_material == null and source_mesh.get_surface_count() == 1:
			source_material = world_materials.get_material("forest_ground", str(settings.settings.get("quality_preset", "balanced")), Color(0.08, 0.18, 0.09), 0.0, false)
		var trees := _make_multimesh_batch("AuthoredTreeBatch_%s" % str(role).replace(":", "_"), source_mesh, role_items.size(), source_material)
		var camera_clearance := StaticBody3D.new()
		camera_clearance.name = "TreeCameraClearance_%s" % str(role).replace(":", "_")
		camera_clearance.collision_layer = 1 << 6
		camera_clearance.collision_mask = 0
		zone_root.add_child(camera_clearance)
		for index in range(role_items.size()):
			var item: Dictionary = role_items[index]
			var tree_position: Vector3 = item.get("asset_position", Vector3.ZERO)
			var tree_scale: Vector3 = item.get("asset_scale", Vector3.ONE)
			var tree_yaw: float = float(item.get("asset_yaw", 0.0))
			var basis := Basis.from_euler(Vector3(0.0, tree_yaw, 0.0)).scaled(tree_scale)
			var tree_transform := Transform3D(basis, tree_position) * source_normalization
			trees.multimesh.set_instance_transform(index, tree_transform)
			# The orbit must stop before the rendered crown, not only its narrow
			# walking collider. This layer is shared with authored camera roofs.
			var clearance_shape := CollisionShape3D.new()
			var clearance_box := BoxShape3D.new()
			clearance_box.size = source_bounds.size * tree_scale * source_scale
			clearance_shape.shape = clearance_box
			clearance_shape.transform = Transform3D(Basis(Vector3.UP, tree_yaw), tree_transform * source_bounds.get_center())
			camera_clearance.add_child(clearance_shape)
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
	instance.material_override = null if material == null and base_mesh.get_surface_count() > 1 else _valid_material_or_fallback(material)
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
		# Mesh-owned materials are valid without an instance override. Replacing
		# them here destroys transparency/emission (including the star field).
	root.set_meta("zone_render_resource_report", report)
	return report

func _make_road(pos: Vector3, size: Vector3, color: Color) -> void:
	var mesh = MeshInstance3D.new()
	mesh.name = "PavedRoad" if current_zone_id == "greyfen" else "MudRoad"
	mesh.mesh = world_materials.make_tiled_ground_patch(size, pos)
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

func _make_cart(pos: Vector3, include_visual: bool = true) -> void:
	pos = river_safe_position(pos,1.0)
	if include_visual:
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
	# Gate and bridge corridors are registered before scenery is authored. Rubble
	# must honor those reservations before _route_safe_position() can move it into
	# the lane, otherwise a decorative source point can become a hard blocker.
	if spatial_service != null and spatial_service.is_reserved(pos, 0.95):
		return
	pos = _route_safe_position(pos, 3.8)
	if spatial_service != null and spatial_service.is_reserved(pos, 0.95):
		return
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
	_make_light("BanditWarmLantern" if current_zone_id == "bandit_road" else "TorchLight", pos + Vector3(0, 1.8, 0), Color(1.0, 0.45, 0.16), 1.45)

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

func _make_prop_box(name: String, pos: Vector3, size: Vector3, color: Color, render_geometry: bool = true) -> void:
	var authored_prop_ids: Array = zone_root.get_meta("authored_prop_ids", [])
	if name not in authored_prop_ids:
		authored_prop_ids.append(name)
		zone_root.set_meta("authored_prop_ids", authored_prop_ids)
	# Authored cemetery landmarks are deliberately fitted against the chapel
	# shell. Do not run them through actor recovery: nearby chapel geometry would
	# relocate the prop and the reserved-route check would then discard it.
	var preserve_authored_position := name in ["OssuarySealedDoor", "CemeteryCrowShrine", "GreyfenRiverShoreStone"]
	if name not in ["NorthBerm","SouthBerm","WestBerm","EastBerm"] and not preserve_authored_position:
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
	# Torch and lantern posts are visual route dressing. Their tiny collision
	# footprints create disproportionate capsule snags at diagonal approaches,
	# especially where a player is following a validated sector edge lane.
	var decorative_only := name == "GreyfenRiverShoreStone" \
		or (size.y <= 0.28 and not _prop_requires_collision(lower)) \
		or lower.contains("torch") or lower.contains("lantern")
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
	if not decorative_only:
		var shape := CollisionShape3D.new()
		shape.name = "%sCollision" % name
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		if not separate_body:
			shape.position = pos
		body.add_child(shape)
	if not render_geometry:
		return
	if current_zone_id == "wychwood" and separate_body and body != null:
		var bank := MeshInstance3D.new()
		bank.name = "WychwoodForestBerm"
		bank.mesh = world_materials.make_forest_berm(size, pos)
		bank.material_override = world_materials.get_material("forest_ground", str(settings.settings.get("quality_preset", "balanced")), Color(0.40, 0.48, 0.34), 0.0, false)
		body.add_child(bank)
		return
	if lower.contains("glow") or lower.contains("window") or lower.contains("coal") or lower.contains("candle"):
		var mesh := MeshInstance3D.new()
		mesh.mesh = shared_box_mesh
		mesh.scale = size
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

func _make_collision_box(name: String, pos: Vector3, size: Vector3) -> void:
	# Fitted modular art and collision must not both render as overlapping shells.
	if prop_collision_body == null:
		prop_collision_body = StaticBody3D.new()
		prop_collision_body.name = "BatchedPropCollisions"
		zone_root.add_child(prop_collision_body)
	var shape := CollisionShape3D.new()
	shape.name = "%sCollision" % name
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = pos
	prop_collision_body.add_child(shape)

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
	if mesh_instance.mesh == null:
		return true
	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		var material := mesh_instance.get_active_material(surface_index)
		if material == null:
			return true
		if _is_bad_white_material(material) and not _surface_has_authored_colors(mesh_instance.mesh, surface_index, material):
			return true
	return mesh_instance.mesh.get_surface_count() == 0

func _surface_has_authored_colors(mesh: Mesh, surface_index: int, material: Material) -> bool:
	if not material is StandardMaterial3D or not (material as StandardMaterial3D).vertex_color_use_as_albedo:
		return false
	var arrays := mesh.surface_get_arrays(surface_index)
	if not arrays[Mesh.ARRAY_COLOR] is PackedColorArray:
		return false
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	if colors.size() != (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
		return false
	# White albedo multiplies authored vertex colors; it is not missing paint.
	for color in colors:
		if color.r <= 0.85 or color.g <= 0.85 or color.b <= 0.85:
			return true
	return false

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
		"returned_soldier": "castle_guard",
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
		"white_hart": "white_hart_avatar",
		"witness_-7": "mira_herbalist",
		"witness_-3": "rook_smuggler",
		"witness_3": "sister_anwen"
	}
	return str(roles.get(id, ""))

func _visual_role_for_interactable(id: String) -> String:
	var roles = {
		"sister_anwen": "sister_anwen_human",
		"mira": "mira_human",
		"rook": "rook_human",
		"widow_elna": "villager_female_human",
		"blacksmith_tor": "villager_worker_human",
		"farmer_toma": "villager_human",
		"returned_soldier": "castle_guard_human",
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
			"greyfen_roof", "cart",
			"forest_tree", "forest_tree_variant", "forest_tree_secondary", "forest_rock", "forest_bush",
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
			node = asset_helper.spawn_visual_role(visual_role, "characters", role_name)
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

func _environment_role_scale(role_name: String, target_size: Vector3) -> Vector3:
	var normalized_size: Vector3 = ENVIRONMENT_ROLE_NORMALIZED_SIZE.get(role_name, Vector3.ZERO)
	if normalized_size == Vector3.ZERO:
		push_error("No fitted environment bounds registered for role '%s'" % role_name)
		return Vector3.ONE
	return Vector3(
		target_size.x / maxf(normalized_size.x, 0.001),
		target_size.y / maxf(normalized_size.y, 0.001),
		target_size.z / maxf(normalized_size.z, 0.001)
	)

func _visual_role_for_legacy_character(role_name: String) -> String:
	var roles = {
		"player_kael": "player_human",
		"sister_anwen": "sister_anwen_human",
		"mira_herbalist": "mira_human",
		"rook_smuggler": "rook_human",
		"widow_elna": "villager_female_human",
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
	light.light_energy = energy * (1.38 if name == "BanditWarmLantern" else 1.0)
	light.omni_range = 11.0 if name == "BanditWarmLantern" else (14.0 if quality == "quality" or current_zone_id == "record_hall" or name in ["UndercroftNavigationFill", "UndercroftHalvernFill"] else 8.0)
	light.shadow_enabled = false
	zone_root.add_child(light)
	runtime_light_count += 1

func _performance_mode() -> bool:
	return settings != null and bool(settings.settings.get("potato_mode", true))

func _compatibility_budget_mode() -> bool:
	return settings == null or str(settings.settings.get("quality_preset", "balanced")) != "quality"

func _keep_performance_light(name: String) -> bool:
	return name in ["Village Warmth", "Shrine Beacon", "Wychwood Gate Lantern", "Moon Shaft", "Trail Threat", "ClearingColdSpot", "SpawnWarmRead", "AshMillFacadeFill", "BanditWarmLantern", "LedgerTableLight", "RecordHallNavigationFill", "RecordHallEntryFill", "RecordHallArchiveFill", "HartWitnessLight", "HartAftermathLight", "UndercroftNavigationFill", "UndercroftHalvernFill"]

func _build_global_environment() -> void:
	visual_director = VisualDirector.new()
	add_child(visual_director)

func _mat(color: Color) -> StandardMaterial3D:
	var interior_lift: bool = current_zone_id in ["record_hall", "undercroft", "old_mill"]
	var key := "flat:%s:%s" % [color.to_html(true), current_zone_id if interior_lift else "world"]
	if material_cache.has(key):
		return material_cache[key]
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	if interior_lift:
		# Compatibility can leave upward-facing procedural archive surfaces
		# unlit. A restrained self-lit lift preserves their authored color without
		# turning the room into a flat white box.
		material.emission_enabled = true
		material.emission = color.lightened(0.18)
		var lift_strength := 0.52 if current_zone_id == "record_hall" else (0.22 if current_zone_id == "old_mill" else 0.34)
		material.emission_energy_multiplier = lift_strength
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
		var tint_lift := 0.34 if lower.begins_with("wychwood") or current_zone_id == "wychwood" else 0.65
		return world_materials.get_material(surface, str(settings.settings.get("quality_preset", "balanced")), color.lightened(tint_lift), wetness, true)
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
		var road_tint := Color(0.64, 0.61, 0.56) if paved else Color(0.38, 0.31, 0.22).lerp(color, 0.15)
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
