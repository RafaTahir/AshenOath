extends Node3D

var GreyfenSocialPresentation: Script:
	get: return _gameplay_script("greyfen_social_presentation")
var CemeteryEvidencePresentation: Script:
	get: return _gameplay_script("cemetery_evidence_presentation")
var WychwoodEvidencePresentation: Script:
	get: return _gameplay_script("wychwood_evidence_presentation")
var CampaignRecordPresentation: Script:
	get: return _gameplay_script("campaign_record_presentation")
var CampaignWildernessSection: Script:
	get: return _gameplay_script("zones/campaign_wilderness_section")
var WychwoodTerrainPresentation: Script:
	get: return _gameplay_script("wychwood_terrain_presentation")
var StoryActorPresence: Script:
	get: return _gameplay_script("story_actor_presence")
var StoryDecisionCoordinator: Script:
	get: return _gameplay_script("story_decision_coordinator")
var StoryWorldDirector: Script:
	get: return _gameplay_script("story_world_director")
var CovenantResolution: Script:
	get: return _gameplay_script("covenant_resolution")

const BridgeSurfaceContract = preload("res://scripts/bridge_surface_contract.gd")
const SpatialSurfaceContract = preload("res://scripts/spatial_surface_contract.gd")
var EnemyAI: Script:
	get: return _gameplay_script("enemy_ai")
const Interactable = preload("res://scripts/interactable.gd")
var VisualDirector: Script:
	get: return _gameplay_script("visual_director")
var NpcAmbient: Script:
	get: return _gameplay_script("npc_ambient")
var CharacterPresentation: Script:
	get: return _gameplay_script("character_presentation")
const CombatFeedback = preload("res://scripts/combat_feedback.gd")
var CharacterAnimationDriver: Script:
	get: return _gameplay_script("character_animation_driver")
var BoardGameOpponent: Script:
	get: return _gameplay_script("board_game_opponent")
var WorldVisualUpgrade: Script:
	get: return _gameplay_script("world_visual_upgrade")
var WorldMotionController: Script:
	get: return _gameplay_script("world_motion_controller")
const WorldPropController = preload("res://scripts/world_prop_controller.gd")
const InteractiveWorldProp = preload("res://scripts/interactive_world_prop.gd")
const OpeningSoundscape = preload("res://scripts/opening_soundscape.gd")
var SurfaceFeedbackManager: Script:
	get: return _gameplay_script("surface_feedback_manager")
var WorldVFXController: Script:
	get: return _gameplay_script("world_vfx_controller")
var EpilogueResolver: Script:
	get: return _gameplay_script("epilogue_resolver")
const ZoneSpatialService = preload("res://scripts/zone_spatial_service.gd")
const RuntimeServiceRegistry = preload("res://scripts/runtime_service_registry.gd")
var RuntimeActorFactory: Script:
	get: return _gameplay_script("runtime_actor_factory")
const ZoneCompositionRouter = preload("res://scripts/zone_composition_router.gd")
const ZoneRuntimeCoordinator = preload("res://scripts/zone_runtime_coordinator.gd")
const ZoneResidencyService = preload("res://scripts/zone_residency_service.gd")
const DialogueRuntimeCoordinator = preload("res://scripts/dialogue_runtime_coordinator.gd")
const CombatVfxCoordinator = preload("res://scripts/combat_vfx_coordinator.gd")
const QuestHudCoordinator = preload("res://scripts/quest_hud_coordinator.gd")
const ZoneSceneCatalog = preload("res://scripts/zone_scene_catalog.gd")
const CemeterySection = preload("res://scripts/cemetery_staging.gd")
const OathGatePortal = preload("res://scripts/oath_gate_portal.gd")
var BossEncounterScript: Script:
	get: return _gameplay_script("boss_encounter")
const PerformanceBudgetMonitor = preload("res://scripts/performance_budget_monitor.gd")
const SeamlessWorldService = preload("res://scripts/seamless_world_service.gd")
const CharacterRoleSpec = preload("res://scripts/character_role_spec.gd")
const ProductionObservationBridgeScript = preload("res://scripts/production_observation_bridge.gd")

var player
var gameplay_scripts: Dictionary = {}

func _gameplay_script(id: String) -> Script:
	if not gameplay_scripts.has(id):
		var script := load("res://scripts/%s.gd" % id) as Script
		if script == null or not script.can_instantiate():
			push_error("Required gameplay script unavailable: " + id)
			return null
		gameplay_scripts[id] = script
	return gameplay_scripts[id]

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
var _unbound_zone_fields := ZoneBuildContext.new_fields()
var world_vfx:
	get: return _zone_runtime_fields()["world_vfx"]
	set(value): _zone_runtime_fields()["world_vfx"] = value
var world_props: WorldPropController:
	get: return _zone_runtime_fields()["world_props"]
	set(value): _zone_runtime_fields()["world_props"] = value
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
var neighbor_building := false
var neighbor_crossing_pending := false
var neighbor_arrival_pending := false
var neighbor_crossing_was_paused := false
var scene_rng: RandomNumberGenerator
var active_interactable
var dialogue_runtime_coordinator := DialogueRuntimeCoordinator.new()
var combat_vfx_coordinator := CombatVfxCoordinator.new()
var quest_hud_coordinator := QuestHudCoordinator.new()
var interaction_candidates: Array:
	get: return _zone_runtime_fields()["interaction_candidates"]
	set(value): _zone_runtime_fields()["interaction_candidates"] = value
var interaction_area_cache: Array[Area3D]:
	get: return _zone_runtime_fields()["interaction_area_cache"]
	set(value): _zone_runtime_fields()["interaction_area_cache"] = value
var interaction_area_cache_ready: bool:
	get: return _zone_runtime_fields()["interaction_area_cache_ready"]
	set(value): _zone_runtime_fields()["interaction_area_cache_ready"] = value
var current_zone_id = "greyfen"
var enemy_defs = {}
var boss_defs = {}
var gameplay_runtime_ready := false
var browser_restore_revision := 0
var browser_restore_check := 0.0
var active_enemies: Array:
	get: return _zone_runtime_fields()["active_enemies"]
	set(value): _zone_runtime_fields()["active_enemies"] = value
var active_enemy_attacker: Node
var boss_saved_states: Dictionary = {}
var wychwood_pack_kills = 0
var wychwood_encounter_started := false
var game_started = false
var paused_by_menu = true
var pending_ending = ""
var story_action_in_progress := false
var story_save_pending := false
var preparation_action_in_progress := false
var progression_refresh_pending := false
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
var runtime_light_count: int:
	get: return _zone_runtime_fields()["runtime_light_count"]
	set(value): _zone_runtime_fields()["runtime_light_count"] = value
var tree_batch_data: Array[Dictionary]:
	get: return _zone_runtime_fields()["tree_batch_data"]
	set(value): _zone_runtime_fields()["tree_batch_data"] = value
var deadfall_batch_data: Array[Transform3D]:
	get: return _zone_runtime_fields()["deadfall_batch_data"]
	set(value): _zone_runtime_fields()["deadfall_batch_data"] = value
var tree_collision_body: StaticBody3D:
	get:
		return ZoneBuildContext.existing_collision_batch(zone_root, "BatchedTreeCollisions")
	set(_value):
		# Legacy reset assignments cannot reassign a zone-owned body.
		pass
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
var prop_batch_data: Dictionary:
	get: return _zone_runtime_fields()["prop_batch_data"]
	set(value): _zone_runtime_fields()["prop_batch_data"] = value
var visual_box_batch_data: Array[Dictionary]:
	get: return _zone_runtime_fields()["visual_box_batch_data"]
	set(value): _zone_runtime_fields()["visual_box_batch_data"] = value
var terrain_patch_batch_data: Array[Dictionary]:
	get: return _zone_runtime_fields()["terrain_patch_batch_data"]
	set(value): _zone_runtime_fields()["terrain_patch_batch_data"] = value
var house_batch_data: Dictionary:
	get: return _zone_runtime_fields()["house_batch_data"]
	set(value): _zone_runtime_fields()["house_batch_data"] = value
var house_module_batch_data: Dictionary:
	get: return _zone_runtime_fields()["house_module_batch_data"]
	set(value): _zone_runtime_fields()["house_module_batch_data"] = value
var spatial_service: Node:
	get: return _zone_runtime_fields()["spatial_service"]
	set(value): _zone_runtime_fields()["spatial_service"] = value
var zone_runtime_coordinator: ZoneRuntimeCoordinator
var zone_residency := ZoneResidencyService.new()
var environment_batches_flushed: bool:
	get: return _zone_runtime_fields()["environment_batches_flushed"]
	set(value): _zone_runtime_fields()["environment_batches_flushed"] = value
var prop_collision_body: StaticBody3D:
	get:
		return ZoneBuildContext.existing_collision_batch(zone_root, "BatchedPropCollisions")
	set(_value):
		# Keep legacy callers compatible without retaining another zone's body.
		pass
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
var opening_scene_pending := false
var zone_load_request_pending := false
var resource_shutdown_prepared := false
var requested_zone_id := ""
var requested_zone_spawn := Vector3.ZERO
var campaign_pack_waiting := false
var opening_pack_waiting := false
var greyfen_prewarm_started := false
var opening_prepare_generation := 0
var opening_phase_started_usec := 0
var opening_startup_metrics: Dictionary = {}
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

var interaction_focus_cooldown := 0.0
var interaction_input_block_until_usec := 0
var compass_refresh_cooldown := 0.0
var navigation_dial_refresh_cooldown := 0.0
var tutorial_refresh_cooldown := 0.0
var target_status_refresh_cooldown := 0.0
var interaction_focus_dirty: bool:
	get: return _zone_runtime_fields()["interaction_focus_dirty"]
	set(value): _zone_runtime_fields()["interaction_focus_dirty"] = value
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
	get_viewport().disable_3d = true
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
	_refresh_journey_models()
	hud.show_main_menu()
	audio.set_music_state("main_menu")
	get_tree().paused = true
	call_deferred("_prepare_opening_after_menu_render")
	print("LOADING: runtime ready total=%dms environment=%dms services=%dms" % [
		Time.get_ticks_msec() - ready_started, environment_ms, services_ms,
	])

func _prepare_opening_after_menu_render() -> void:
	if DisplayServer.get_name().to_lower() != "headless":
		await RenderingServer.frame_post_draw
	if not is_inside_tree():
		return
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.dispatchEvent(new CustomEvent('ashen-oath-ui-ready'));", false)
	opening_startup_metrics["menu_ready_ms"] = Time.get_ticks_msec()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.dispatchEvent(new CustomEvent('ashen-oath-menu-ready'));", false)
	print("LOADING: usable_menu_ready ms=%d" % Time.get_ticks_msec())
	await get_tree().process_frame
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
	if game_started and not get_tree().paused and not _journey_load_pending():
		_pause_game()

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
		get_viewport().set_input_as_handled()
		_dispatch_gameplay_action("interact")
	elif not get_tree().paused and input_router.accept_event(event, &"open_inventory", "gameplay"):
		get_viewport().set_input_as_handled()
		_dispatch_gameplay_action("open_inventory")

func _on_virtual_gameplay_action(request: Dictionary) -> void:
	_dispatch_gameplay_action(str(request.get("action", "")), int(request.get("target_instance_id", 0)))

func _dispatch_gameplay_action(action: String, target_instance_id: int = 0) -> void:
	if not game_started or get_tree().paused or input_router == null or not input_router.is_gameplay_context() or _journey_load_pending() or zone_transition_pending or zone_load_request_pending or opening_pack_waiting or campaign_pack_waiting:
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
			get_tree().paused = true
			_show_preparation_menu()
		"touch_more":
			_show_touch_actions()
		"companion_command":
			_show_companion_commands()

func _request_pause_or_back(event: InputEvent) -> void:
	if is_instance_valid(zone_root) and bool(zone_root.get_meta("opening_scene_active", false)):
		if input_router.accept_event(event, &"pause", input_router.get_context()):
			get_viewport().set_input_as_handled()
			var life := zone_root.find_child("GreyfenLifeController", true, false)
			if life != null: life.finish_opening_scene("skipped")
		return
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
	_dispatch_gameplay_action("pause")

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
	_restore_browser_session(delta)
	if not game_started or player == null or get_tree().paused:
		return
	if opening_scene_pending and not zone_transition_pending and not zone_load_request_pending and input_router.is_gameplay_context() and player.can_control:
		var life := zone_root.find_child("GreyfenLifeController", true, false) if is_instance_valid(zone_root) else null
		if life != null:
			opening_scene_pending = false
			life.begin_opening_scene()
	if is_instance_valid(zone_root) and bool(zone_root.get_meta("opening_scene_active", false)):
		return
	if zone_transition_pending:
		_advance_zone_transition()
		return
	if _journey_load_pending():
		journey_loading.try_finish(self)
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
	_bind_runtime_services(runtime_services.create_services(true))
	runtime_services.configure_menu(self)

func _bind_runtime_services(services: Dictionary) -> void:
	for id in services:
		if id != "display_metrics":
			set(id, services[id])

func _ensure_gameplay_runtime() -> void:
	if gameplay_runtime_ready:
		return
	_bind_runtime_services(runtime_services.create_gameplay_services())
	if not runtime_services.is_complete():
		return
	gameplay_runtime_ready = true
	quest_hud_coordinator.configure(quest_presentation, quests, story_state)
	_build_global_environment()
	runtime_services.configure(self)
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
	if not game_started or journey_loading.pending(self): return
	neighbor_crossing_pending = true
	neighbor_crossing_was_paused = get_tree().paused
	get_tree().paused = true
	audio.set_game_paused(true)
	hud.begin_journey_load({"summary":{"title":_zone_display_name(zone_id)}})
	runtime_packs.prioritize_zone(zone_id,extras)

func _finish_travel_download() -> void:
	if not neighbor_crossing_pending: return
	neighbor_crossing_pending = false
	neighbor_arrival_pending = true
	get_tree().paused = neighbor_crossing_was_paused
	audio.set_game_paused(neighbor_crossing_was_paused)

func _wait_for_campaign_pack(zone_id: String, spawn_pos: Vector3, request_serial: int) -> void:
	for _frame in range(900):
		await get_tree().process_frame
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
		await get_tree().process_frame
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
		get_tree().paused = neighbor_crossing_was_paused
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
	get_viewport().disable_3d = false
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
		call_deferred("_schedule_background_runtime_packs")
	print("LOADING: new_game_stage=state_ready elapsed=%.1f" % (float(Time.get_ticks_usec() - loading_started_usec) / 1000.0))
	if route_zone_cache.has("greyfen"):
		route_zone_signatures["greyfen"] = _zone_state_signature("greyfen")
	print("LOADING: new_game_stage=zone_dispatch elapsed=%.1f" % (float(Time.get_ticks_usec() - loading_started_usec) / 1000.0))
	print("LOADING: handoff_phase=load_zone_begin")
	journey_loading.begin_arrival(self, "new_journey", "greyfen")
	opening_scene_pending = true
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
		call_deferred("_schedule_opening_save", generation)
		return
	# Save the current state rather than a stale Greyfen-only snapshot. If the
	# player reaches another supported zone during the delay, the normal autosave
	# path still owns that transition and this checkpoint remains a safe fallback.
	save_manager.checkpoint(self)
	opening_checkpoint_pending = false

func load_save_state(data: Dictionary) -> void:
	_ensure_gameplay_runtime()
	runtime_services.configure_campaign()
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
	opening_scene_pending = false
	_ensure_gameplay_runtime()
	if _zone_requires_campaign_pack(str(data.get("zone", "greyfen"))):
		runtime_services.configure_campaign()
	_begin_gameplay_handoff("load_journey")
	if not game_started:
		_discard_menu_opening()
	new_game_start_pending = false
	opening_save_generation += 1
	opening_checkpoint_pending = false
	story_save_pending = false
	_clear_route_zone_cache()
	game_started = true
	get_viewport().disable_3d = false
	paused_by_menu = false
	if audio != null:
		audio.set_game_paused(false)
	get_tree().paused = false
	hud.hide_menus()
	if vendor_service != null:
		vendor_service.load_state(data.get("vendors", {}))
	if minigames != null:
		minigames.load_state(data.get("minigames", {}) if data.get("minigames", {}) is Dictionary else {})
	quests.load_state(data.get("quests", {}))
	if quest_presentation != null:
		quest_presentation.load_state(data.get("quest_presentation", {}))
	if quest_beats != null:
		quest_beats.load_state(data.get("quest_beats", {}))
	# Journey snapshots are a legacy fallback, not an override for newer global
	# input/accessibility preferences selected before loading that journey.
	if settings != null and not settings.loaded_user_settings and typeof(data.get("settings", {})) == TYPE_DICTIONARY and not data.get("settings", {}).is_empty():
		settings.restore_settings(data.settings)
		settings.apply()
	story_state.load_state(data.get("story_state", {}))
	progression.load_state(data.get("progression", {}))
	if seamless_world != null and seamless_world.has_method("load_state"):
		seamless_world.load_state(data.get("seamless_world", {}))
	var saved_sector := str(data.get("world_sector", data.get("zone", "greyfen")))
	var discovered: Dictionary = seamless_world.discovered_sectors if seamless_world != null else {}
	progression.restore_journey(quests, story_state, saved_sector, discovered)
	# Restore entitlement ownership before migrating a legacy coating duration.
	inventory.load_state(data.get("inventory", {}), int(data.get("migrated_from_version", data.get("version", 0))) < 13)
	if int(data.get("version", 0)) < 3 and quests.is_completed("main_road_of_crows"):
		story_state.set_flag("legacy_report_choice_required", true)
	load_world_state(data.get("world_state", {}))
	var zone = str(data.get("world_sector", data.get("zone", "greyfen")))
	var pos_array: Array = data.get("player_position", [0, 1, 7])
	var pos = Vector3(float(pos_array[0]), float(pos_array[1]), float(pos_array[2]))
	var world_array: Array = data.get("world_position", [])
	if seamless_world != null and world_array.size() >= 3:
		pos = seamless_world.local_position_for(zone, Vector3(float(world_array[0]), float(world_array[1]), float(world_array[2])))
	if zone == "deep_wood" and quests.is_active("main_teeth_in_rain") and quests.is_objective_done("main_teeth_in_rain", "name_the_dead") and not quests.is_objective_done("main_teeth_in_rain", "bog_core_choice") and str(story_state.get_flag("saga_bog_arena_owner", "")) == "":
		pos = Vector3(-7,1,11)
		story_state.set_flag("saga_bog_arena_owner", "wychwood")
		story_state.record_evidence("saga_bog_migration", {"zone":"deep_wood", "title":"The memory's northern clearing", "text":"The Bog Wretch and its pending memory core now have one owner in northern Wychwood. Return south along the existing path. Your recorded fight, choices, health and supplies are unchanged."})
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
	return neighbor_crossing_pending or journey_loading.pending(self)

func _on_prepared_journey_load(prepared: Dictionary) -> void:
	journey_loading.request(self, prepared)

func _cancel_journey_load() -> void:
	if neighbor_crossing_pending:
		neighbor_crossing_pending = false
		zone_pack_request_serial += 1
		seamless_world.cancel_preparation()
		hud.end_journey_load(false)
		get_tree().paused = neighbor_crossing_was_paused
		audio.set_game_paused(neighbor_crossing_was_paused)
		_recover_failed_pack_load("Crossing cancelled. Your current location and journey are unchanged.")
		return
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
	print("JOURNEY: load_requested slot=%s source=%s" % [str(selection.get("slot_id", "")), str(selection.get("source", ""))])
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
	if not player.health_component.dead:
		player.reset_for_journey_restore()
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
	player.equipment_loadout.changed.connect(_refresh_equipment_readout)
	player.footstep.connect(_on_player_footstep)
	player.ability_hint.connect(func(text: String): hud.post_notice(text, "info", 2.5, "ability_requirement"))
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

var encounter_spatial_index:
	get: return _zone_runtime_fields()["encounter_spatial_index"]
	set(value): _zone_runtime_fields()["encounter_spatial_index"] = value

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
	var paired_crossing := game_started and seamless_world != null and current_zone_id != zone_id and not journey_loading.pending(self) and ZoneCompositionRouter.supports(zone_id)
	if paired_crossing and seamless_world != null and is_instance_valid(zone_root) and is_instance_valid(player) and not seamless_world.has_prepared(zone_id):
		neighbor_crossing_pending = true
		neighbor_crossing_was_paused = get_tree().paused
		get_tree().paused = true
		audio.set_game_paused(true)
		var serial := zone_pack_request_serial
		hud.begin_journey_load({"summary":{"title":"the road into " + _zone_display_name(zone_id)}})
		var ready: bool = await seamless_world.finish_preparation(zone_id,func(): return neighbor_crossing_pending and serial == zone_pack_request_serial and not resource_shutdown_prepared)
		if not neighbor_crossing_pending or serial != zone_pack_request_serial: return
		neighbor_crossing_pending = false
		get_tree().paused = neighbor_crossing_was_paused
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
	_finish_prewarmed_greyfen_runtime()

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
	StoryWorldDirector.decorate(self, root, zone_id)
	CovenantResolution.restore(self)
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

func _record_first_control() -> void:
	if opening_startup_metrics.has("first_control_ms") or not game_started or not is_instance_valid(player) or not player.can_control or player.transition_locked:
		return
	if opening_scene_pending or zone_transition_pending or zone_load_request_pending or opening_pack_waiting or campaign_pack_waiting or get_tree().paused or not input_router.is_gameplay_context():
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
			save_manager.autosave(self)
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
	_zone_construction()._add_visual_100_layer(zone_id)

func _install_world_prop_controller(zone_id: String) -> void:
	_zone_construction()._install_world_prop_controller(zone_id)

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
	if current_zone_id == "greyfen" and area != null:
		preload("res://scripts/greyfen_guidance.gd").learn(self, "use")
	if area != null and area.interaction_id == "bracken" and str(story_state.get_flag("bracken_home", "")) == "adopted":
		_show_companion_commands()
		return
	if area != null and area.interaction_type == "encounter" and area.interaction_id == "rootbound_challenge":
		_open_rootbound_encounter()
		return
	if area != null and area.interaction_type == "story_activity":
		preload("res://scripts/story_activity_director.gd").handle(self, area)
		return
	var prop_activated := false
	if world_props != null and area != null and area.has_meta("world_prop_id"):
		prop_activated = world_props.activate_prop(str(area.get_meta("world_prop_id", "")))
	var world_prop_component := area.find_child("InteractiveWorldProp", true, false) as InteractiveWorldProp if area != null else null
	if world_prop_component != null and not prop_activated:
		world_prop_component.activate()
	if world_vfx != null and is_instance_valid(world_vfx) and area is Node3D:
		world_vfx.pulse_interaction((area as Node3D).global_position)
	if area.interaction_type == "covenant":
		CovenantResolution.activate(self, area)
		return
	if area.interaction_type == "minigame":
		var village: Node = preload("res://scripts/greyfen_village_details.gd").current(self)
		if village != null and village.open_table(area): return
		minigames.open_game("tic_tac_toe" if area.interaction_id == "common_table" else "draughts", "rook" if area.interaction_id == "common_table" else "blacksmith_tor")
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
		if area.interaction_id == "bracken":
			for companion_action: Dictionary in dialogue_data.get("actions", []):
				companion_action["companion_actor_instance"] = area.get_instance_id()
		var report_chosen := false
		if _road_ready_to_report() and area.interaction_id in ["sister_anwen", "notice_board", "retain_evidence"]:
			report_chosen = true
			dialogue_data = dialogue.get_dialogue("report_decision")
		if area.interaction_id == "sister_anwen" and not quests.is_completed("main_road_of_crows") and not bool(tutorial_flags.get("anwen_talked", false)):
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
			audio.set_music_state("return_report")
			hud.show_status_cue("Anwen knows the sign", "victory")
			hud.toast("Anwen goes still at the feathers. 'Then it was called here,' she says, and will say no more.")
		_set_interactable_label_visible(area, false)
		if not report_chosen:
			preload("res://scripts/story_activity_director.gd").add_friend_invitation(self, area, dialogue_data)
			preload("res://scripts/story_activity_director.gd").add_personal_invitation(self, area, dialogue_data)
		for option: Dictionary in dialogue_data.get("actions", []):
			if not _dialogue_action_available(option):
				option["available"] = false
				option["unavailable_reason"] = _dialogue_action_unavailable_reason(option)
		_stage_dialogue_moment(area)
		var topic_context_id: String = dialogue_runtime_coordinator.bind_topic_context(str(area.interaction_id), current_zone_id)
		if not topic_context_id.is_empty():
			dialogue_data["topic_context_id"] = topic_context_id
			dialogue_data["optional_topics"] = dialogue.get_conversation_topics(str(area.interaction_id), current_zone_id, hud.get_dialogue_topic_seen_keys())
		preload("res://scripts/story_performance.gd").begin(area, player, dialogue_data, story_state)
		audio.set_dialogue_active(true)
		audio.set_game_paused(true)
		get_tree().paused = true
		hud.show_dialogue(_prepare_dialogue_presence(dialogue_data))
		# The displayed page owns its exact-text recording. A legacy scene-wide
		# sequence here would cancel that page and could speak a different turn.
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
		_present_castle_clue(str(area.interaction_id), str(area.prompt))
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
				load("res://scripts/zones/greyfen_section.gd").new().publish_returned_soldier(ZoneBuildContext.new(self, "greyfen"))
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
		"shrine_prayer":
			var activities := zone_root.get_node_or_null("StoryActivities")
			if activities != null:
				activities.activate("shrine_prayer")
		"river_water":
			player.stamina_component.restore(18.0)
			hud.toast("Cold river water. Clean enough above Greyfen, for now.")
		_: hud.toast("Greyfen has made use of everything it could keep.")

func _on_minigame_result(game_id: String, outcome: String) -> void:
	if game_id == "tic_tac_toe" and quests.is_active("saga_gre_q04") and str(story_state.get_flag("saga_gre_q04_outcome", "")) == "replayed":
		story_state.set_flag("saga_gre_q04:round_played", true)
	var played_id := "%s_played" % game_id
	story_state.set_flag(played_id, int(story_state.get_flag(played_id,0)) + 1)
	if outcome == "win":
		var wins_id := "%s_wins" % game_id
		story_state.set_flag(wins_id, int(story_state.get_flag(wins_id,0)) + 1)
		var reward_id := "%s_reward_claimed" % game_id
		var person: String = str(minigames.opponent_id)
		var legacy_opponent := (game_id == "tic_tac_toe" and person == "rook") or (game_id == "draughts" and person == "blacksmith_tor")
		if legacy_opponent and not bool(story_state.get_flag(reward_id,false)):
			story_state.set_flag(reward_id,true)
			if game_id == "tic_tac_toe":
				story_state.set_flag("rook_road_hint",true)
				hud.toast("Rook: Road wasn't always cursed. Ask who bent it.")
			elif game_id == "draughts":
				story_state.set_flag("tor_iron_hint",true)
				inventory.add_ingredients({"scrap_iron":1})
				hud.toast("Tor gives up scrap bearing an old Vargan stamp.")
		if game_id == "chess":
			var claim := "chess_prize:" + person
			if not bool(story_state.get_flag(claim, false)):
				story_state.set_flag(claim, true)
				inventory.add_reward({"coin": 3 if person == "rook" else 8})
				hud.toast("%s pays the table's one-time prize." % ("Rook" if person == "rook" else "Tor"))
	save_manager.autosave(self)

func _on_minigame_state_changed() -> void:
	if game_started and not zone_transition_pending and not zone_load_request_pending and pending_player_restore.is_empty():
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
	_zone_construction()._make_all_evidence_safe_edge()

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
		and bool(story_state.get_flag("bell_eater_defeated", false)) \
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
	if _boss_is_resolved("bell_eater"):
		_retire_bell_eater()
	if not quests.is_active("main_bell_beneath_greyfen"):
		return
	_relocate_anwen_to_cemetery()
	if _crow_shrine_choice_ready():
		_spawn_crow_shrine_choice()
	elif bool(story_state.get_flag("crow_chapel_opened", false)):
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
	if str(action.get("type", "")) == "greyfen_detail_action":
		preload("res://scripts/greyfen_village_details.gd").choose(self, action)
		return
	if str(action.get("type", "")) == "saga_action":
		var owner: Node = zone_root.get_node_or_null("StoryActivities/SixWorldStories") if is_instance_valid(zone_root) else null
		if owner != null:
			owner.choose(action)
		return
	if str(action.get("type", "")) == "gathering_choice":
		preload("res://scripts/greyfen_gathering.gd").choose(self, action)
		return
	if str(action.get("type", "")) == "field_trial":
		preload("res://scripts/bracken_field_trial.gd").choose(self, action)
		return
	if str(action.get("type", "")) == "range_choice":
		preload("res://scripts/greyfen_archery_range.gd").choose(self, action)
		return
	if str(action.get("type", "")) == "living_road_scene":
		preload("res://scripts/story_activity_director.gd").personal_scene(self, action)
		return
	if str(action.get("type", "")) == "friend_scene":
		preload("res://scripts/story_activity_director.gd").friend_scene(self, action)
		return
	if str(action.get("type", "")) == "rest_place":
		preload("res://scripts/story_activity_director.gd").rest_action(self, action)
		return
	if str(action.get("type", "")) == "companion_menu":
		_show_companion_commands()
		return
	if str(action.get("type", "")) == "companion_command":
		if not preload("res://scripts/companion_controller.gd").issue_command(self, str(action.get("command", ""))):
			hud.toast("Bracken cannot take that command during this journey handoff.")
		_resume_game()
		return
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
	var transaction = StoryDecisionCoordinator.new()
	transaction.begin(self)
	var applied: bool = _apply_dialogue_action(action)
	transaction.finish(self, action, applied)
	var blocking: bool = hud._gameplay_surface_blocked() or _journey_load_pending()
	get_tree().paused = blocking
	audio.set_game_paused(blocking)

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
	_collect_progression_rewards()
	story_save_pending = false
	save_manager.checkpoint(self)
	save_manager.autosave(self)

func _story_has_active_combat() -> bool:
	for enemy in active_enemies:
		if is_instance_valid(enemy) and not enemy.dead and player != null and enemy.is_encounter_active() and not bool(enemy.get_meta("dormant_arena", false)):
			if enemy.global_position.distance_squared_to(player.global_position) < 100.0:
				return true
	return false

func _apply_dialogue_action(action: Dictionary) -> bool:
	if not _dialogue_action_available(action):
		hud.toast(_dialogue_action_unavailable_reason(action))
		return false
	# Keep combat frozen until the complete choice transaction has published.
	get_tree().paused = true
	if hud != null:
		hud.hide_menus()
	audio.stop_voice()
	audio.play_event("ui")
	var type = str(action.get("type", ""))
	if type == "greyfen_restore_choice":
		if not story_state.confirm_greyfen_choice(str(action.get("key", "")), str(action.get("value", ""))):
			return false
	elif type == "opening_care_account":
		var opening_anwen := zone_root.find_child("sister_anwen", true, false) as Node3D
		if current_zone_id == "greyfen" and opening_anwen != null:
			story_state.set_flag("opening_care_introduced", true)
			call_deferred("_handle_interaction", opening_anwen)
	elif type == "opening_care_resume":
		var care_hint := "Oren's coat is on the bench. Anwen can tell you about the road whenever you are ready." if bool(story_state.get_flag("opening_cup_delivered", false)) else "The cup is on the low step. Anwen can tell you about the road whenever you are ready."
		hud.set_guidance_hint(care_hint, 8.0)
	elif type == "companion_choice":
		if not preload("res://scripts/companion_controller.gd").apply_choice(self, action):
			return false
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
		if not story_state.commitment_allows(action):
			hud.toast("That promise cannot be made while another commitment stands. Speak honestly with the person it concerns.")
			return false
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
		if not story_state.apply_commitment(action):
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
			if not _has_interactable("gate_greyfen"):
				_make_zone_gate("Return to Greyfen and take the southern Hart road", Vector3(7, 0, -14), "greyfen", Vector3(0, 0.95, 11))
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
	if action.get("sets_flags", {}).has("crow_shrine_state") and not bool(story_state.get_flag("bell_eater_defeated", false)):
		return false
	if action.get("sets_flags", {}).has("halvern_fate"):
		var yielding := bool(story_state.get_flag("halvern_guard_broken", false)) or bool(story_state.get_flag("command_proof_recovered", false)) or bool(story_state.get_flag("halvern_surrender_protected", false)) or str(story_state.get_flag("halvern_fate", "")) == "defeated"
		if not yielding:
			return false
	if not dialogue._conditions_match(action.get("conditions", {})):
		return false
	var type := str(action.get("type", ""))
	var quest_id := str(action.get("quest", ""))
	var objective_id := str(action.get("objective", ""))
	if type == "greyfen_restore_choice":
		var key := str(action.get("key", ""))
		var resolved: bool = quests.is_completed("side_iron_remembers") if key == "iron_fate" else quests.is_completed("main_road_of_crows") or quests.is_objective_done("main_road_of_crows", "return_village")
		return current_zone_id == "greyfen" and resolved and bool(story_state.get_flag(key + "_confirmation_needed", false))
	if type == "companion_choice":
		return preload("res://scripts/companion_controller.gd").choice_available(self, action)
	if type == "start_quest":
		return quest_id != "" and quests.is_unlocked(quest_id) and not quests.is_active(quest_id) and not quests.is_completed(quest_id)
	if type == "complete_objective":
		if quest_id == "side_iron_remembers" and objective_id == "recover_iron" and not story_state.has_evidence("massacre_iron"):
			return false
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

func _dialogue_action_unavailable_reason(action: Dictionary) -> String:
	if action.get("sets_flags", {}).has("crow_shrine_state"):
		return "Defeat the Bell-Eater before deciding the shrine's fate."
	if str(action.get("quest", "")) == "main_soldier_without_banner" and str(action.get("objective", "")) == "senn_choice":
		return "First settle the checkpoint guards, by combat or their earned surrender."
	if str(action.get("quest", "")) == "main_ash_at_the_mill" and not bool(story_state.get_flag("ashwing_defeated", false)):
		return "Defeat Ashwing before settling the mill's surviving records."
	return "Complete the current step before making this choice."

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
		if not runtime_packs.pack_progress.is_connected(_on_opening_pack_progress):
			runtime_packs.pack_progress.connect(_on_opening_pack_progress)
		if runtime_packs.has_signal("pack_ready") and not runtime_packs.pack_ready.is_connected(_on_startup_pack_ready):
			runtime_packs.pack_ready.connect(_on_startup_pack_ready)
		runtime_packs.request_startup_packs(retry_failed)
		# request_startup_packs may mount a cache immediately, before the
		# signal connection above can observe a later state change. Recheck on
		# the next idle frame as well as through pack_ready.
		call_deferred("_begin_opening_prewarm_if_ready", opening_prepare_generation)
		# Cached Web packs can complete synchronously. The signal path handles
		# asynchronous downloads without depending on a paused-tree frame.
		call_deferred("_wait_for_startup_packs_then_prewarm", opening_prepare_generation)
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
		await get_tree().process_frame
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
	call_deferred("_prepare_opening_services", opening_prepare_generation)

func _prepare_opening_services(generation: int) -> void:
	await _wait_for_opening_build_slot(generation)
	if not _opening_attempt_current(generation):
		return
	_publish_web_opening_state("services", "Preparing the journey...")
	await get_tree().process_frame
	if not _opening_attempt_current(generation):
		return
	var services_ready: bool = await runtime_services.prepare_gameplay_services(_opening_attempt_current.bind(generation))
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
	call_deferred("_prepare_opening_resources", generation)

func _wait_for_opening_build_slot(generation: int) -> void:
	# Settings/save browsing gets the main thread; an explicit New Game owns it.
	while _opening_attempt_current(generation) and not new_game_start_pending and hud.active_menu != "main":
		await get_tree().process_frame

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
			await get_tree().process_frame
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
	get_viewport().disable_3d = true

func _restart_menu_opening() -> void:
	if game_started or _journey_load_pending():
		return
	_discard_menu_opening()
	if hud != null:
		hud.set_new_game_ready(false)
		_publish_web_opening_state("preparing", "Preparing the selected visual quality...")
	var generation := opening_prepare_generation
	await get_tree().process_frame
	if _opening_attempt_current(generation):
		_on_launch_accepted()

func _opening_prepare_failed(message: String) -> void:
	if game_started or resource_shutdown_prepared:
		return
	# Retry must not retain a partial world that makes the next build early-out.
	if zone_root != null or player != null or route_zone_cache.has("greyfen"):
		_discard_menu_opening()
	get_viewport().disable_3d = true
	get_tree().paused = true
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
	add_child(prewarm_service)
	prewarm_service.configure("greyfen", _river_center("greyfen"), _zone_half_extents("greyfen"))
	greyfen_prewarm_spatial_service = prewarm_service
	zone_root = Node3D.new()
	zone_root.name = "greyfen"
	zone_root.visible = false
	zone_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(zone_root)
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
	await get_tree().process_frame
	await _wait_for_opening_build_slot(generation)
	if not _opening_attempt_current(generation):
		return
	phase_started = Time.get_ticks_msec()
	var slice_started := Time.get_ticks_usec()
	for visual_bucket in range(OPENING_GAMEPLAY_VISUAL_BUCKETS):
		ZoneCompositionRouter.build_core_detail_stage(self, "greyfen", "gameplay_visual_%d" % visual_bucket)
		_record_opening_stage(zone_root, "gameplay_visual_%d" % visual_bucket)
		if Time.get_ticks_usec() - slice_started >= OPENING_BUILD_SLICE_USEC:
			await get_tree().process_frame
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
	await get_tree().process_frame
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
	var was_paused := get_tree().paused
	# Complete first-use mesh and texture decoding under the menu cover. Doing
	# this after control is handed over causes visible 40-70 ms hydration frames.
	opening_well_mesh = load("res://assets_external/environment/village/GreyfenWell_Authored.res") as ArrayMesh
	if opening_well_mesh == null or opening_well_mesh.get_surface_count() != 6:
		get_tree().paused = was_paused
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
		var covered_result := ZoneCompositionRouter.build_core_detail_stage(self, "greyfen", covered_stage)
		if not bool(covered_result.get("ok", false)):
			get_tree().paused = was_paused
			_abort_opening_prewarm(prewarm_root, prewarm_service, "Greyfen's opening scene could not be prepared. Select New Game to retry.")
			return
		if not await _publish_opening_batches(generation):
			return
		_clear_environment_batch_buffers()
		environment_batches_flushed = true
		_record_opening_stage(prewarm_root, covered_stage)
		if Time.get_ticks_usec() - slice_started >= OPENING_BUILD_SLICE_USEC:
			await get_tree().process_frame
			await _wait_for_opening_build_slot(generation)
			if not _opening_attempt_current(generation):
				return
			slice_started = Time.get_ticks_usec()
	if not _opening_attempt_current(generation):
		return
	if not _opening_presentation_present(prewarm_root):
		get_tree().paused = was_paused
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
	get_viewport().disable_3d = false
	if DisplayServer.get_name().to_lower() != "headless":
		_publish_web_opening_state("first_view", "Preparing Greyfen's first view...")
		# Evaluate the complete, transition-locked rig before its first draw.
		await get_tree().process_frame
		if not _opening_attempt_current(generation):
			return
		await RenderingServer.frame_post_draw
		if not _opening_attempt_current(generation):
			return
		prewarm_root.set_meta("opening_unpaused_frame_prewarmed", true)
		prewarm_root.set_meta("opening_first_frame_rendered", true)
	prewarm_root.set_meta("opening_presentation_ready", true)
	get_tree().paused = was_paused
	get_viewport().disable_3d = true
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
	var civilians := _civilian_contact_candidates(player.global_position, 4.0)
	var result: Dictionary = combat.resolve_player_blade_contact(player, active_enemies, contact, inventory.active_oil, civilians)
	if not bool(result.get("hit", false)):
		var practice: Node = preload("res://scripts/greyfen_village_details.gd").current(self)
		if practice != null and practice.blade_contact(contact):
			result["hit"] = true
			result["surface"] = "wood"
			result["kind"] = "practice"
	player.confirm_blade_contact(int(contact.get("attack_id", -1)), bool(result.get("hit", false)))
	if bool(result.get("hit", false)):
		_present_surface_contact(result, false)
		_hitstop(0.055 if heavy else 0.032)
		var contact_color := Color(0.66, 0.88, 1.0) if str(result.get("blade_id", "steel")) == "oathblade" or str(result.get("source_tag", "")) == "spirit" else Color(0.98, 0.78, 0.34)
		if str(result.get("surface", "")) != "flesh": CombatFeedback.weapon_contact(
			zone_root,
			result.get("blade_base", player.global_position),
			result.get("blade_tip", player.global_position),
			result.get("contact_point", result.get("point", player.global_position)),
			heavy,
			contact_color,
			result.get("previous_base", Vector3.ZERO),
			result.get("previous_tip", Vector3.ZERO)
		)
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
	if bool(request.get("training", false)):
		var range_node := instance_from_id(int(request.get("training_owner", 0))) as Node
		if is_instance_valid(range_node) and range_node == zone_root.get_node_or_null("GreyfenArcheryRange"):
			range_node.fire(request)
		# A retired or cancelled training request can never fall through to damage.
		return
	var origin: Vector3 = request.get("origin", player.global_position + Vector3.UP * 1.3)
	var direction: Vector3 = request.get("direction", -player.global_transform.basis.z)
	if direction.length_squared() < 0.5:
		direction = -player.global_transform.basis.z
	direction = direction.normalized()
	var arrow_id := str(request.get("arrow_id", "standard_arrow"))
	var arrow_def: Dictionary = inventory.item_defs.get(arrow_id, {})
	var effect: Dictionary = arrow_def.get("effect", {})
	var damage := float(effect.get("damage", 28.0))
	if float(request.get("draw_ratio", 0.0)) >= 0.99:
		damage *= progression.effect_value("saga_full_draw_damage_multiplier", 1.0)
	var arrow_exclusions: Array[RID] = [player.get_rid()]
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			arrow_exclusions.append(enemy.get_rid())
	audio.play_event("swing", 0.02)
	var arrow_targets: Array = active_enemies.duplicate()
	arrow_targets.append_array(_civilian_contact_candidates(origin, float(request.get("range",24.0)) + 2.0))
	combat_vfx_coordinator.launch_arrow(zone_root, origin, direction, float(request.get("range", 24.0)), arrow_targets, combat, arrow_exclusions, {
		"width": float(request.get("width", 0.34)),
		"damage": damage,
		"source_tag": "arrow_%s" % arrow_id,
	}, _on_arrow_impact.bind(arrow_id, damage, zone_root.get_instance_id()))

func _on_arrow_impact(result: Dictionary, arrow_id: String, damage: float, zone_instance: int) -> void:
	if not is_instance_valid(zone_root) or zone_instance != zone_root.get_instance_id(): return
	if bool(result.get("hit", false)):
		_present_surface_contact(result, true)
		if str(result.get("kind", "")) == "scenery": return
		hud.show_status_cue("Arrow struck a person" if str(result.get("kind", "")) == "civilian" else "Arrow hit: %d" % int(damage), "item")
		var target = result.get("enemy")
		if target != null and is_instance_valid(target):
			hud.show_enemy(target.display_name, target.health_component.health, target.health_component.max_health)
			if target.dead and arrow_id in ["standard_arrow", "bodkin_arrow"] and progression.effect_value("arrow_recovery_on_kill", 0.0) > 0.0:
				inventory.add_item(arrow_id, 1)
				story_save_pending = true
				call_deferred("_persist_story_action")

func _present_surface_contact(result: Dictionary, arrow: bool) -> void:
	var surface := str(result.get("surface", "metal"))
	var event := ("arrow_contact" if arrow else "flesh_contact") if surface == "flesh" else str({"wood":"wood_contact","stone":"stone_contact","foliage":"foliage_contact"}.get(surface,"light_hit"))
	audio.play_spatial_event(event,result.get("point",player.global_position),player.global_position,14.0,0.06,0.06)
	combat_vfx_coordinator.surface_contact(zone_root,result,bool(settings.settings.get("blood_effects",true)),bool(settings.settings.get("flash_reduction",false)))
	audio.perception_cue.emit(result.get("point",player.global_position),7.0,str(result.get("kind","")) != "scenery")

func _civilian_contact_candidates(position: Vector3, radius: float) -> Array:
	if not is_instance_valid(zone_root): return []
	var life: Node
	for owner_name: String in ["GreyfenLifeController", "RegionalLifeController"]:
		life = zone_root.get_node_or_null(owner_name)
		if life != null: break
	var people: Array = []
	for area in interaction_focus.registered_nearby(position,zone_root,radius):
		if str(area.get("interaction_type")) == "dialogue" and area.find_child("CharacterAnimationDriver",true,false) != null:
			people.append(area)
	if life == null and not people.is_empty():
		life = _gameplay_script("greyfen_life_controller").new()
		life.name = "RegionalLifeController"
		zone_root.add_child(life)
		life.configure(self,str(settings.settings.get("quality_preset","balanced")),true)
	if life == null: return []
	for person in people: life.enroll_contact_actor(person)
	return life.contact_candidates(position,radius)
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
	var practice: Node = preload("res://scripts/greyfen_village_details.gd").current(self)
	if practice != null: practice.oathfire_contact(cast)
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
	if current_zone_id == "wychwood": preload("res://scripts/greyfen_guidance.gd").learn(self, "parry")
	if progression != null and player != null:
		player.stamina_component.restore(progression.effect_value("parry_stamina_restore", 0.0) + progression.entitlement_effect("saga_parry_restore", 0.0))
	tutorial_flags["block_hint_done"] = true
	hud.set_guidance_hint("")

func _on_player_blocked(_amount: float) -> void:
	if current_zone_id == "wychwood": preload("res://scripts/greyfen_guidance.gd").learn(self, "block")
	audio.play_event("block")
	if input_router != null:
		input_router.rumble(0.18, 0.32, 0.08)
	if camera_rig != null:
		camera_rig.shake(0.08)
	if zone_root != null and player != null:
		var blade: Dictionary = player.get_blade_world_segment()
		var contact: Vector3 = (blade.base as Vector3).lerp(blade.tip, 0.55)
		CombatFeedback.block_flash(zone_root, player.global_position, false, contact)
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
	_use_quick_item(inventory.quick_item("use_potion"))

func _throw_bomb() -> void:
	_use_quick_item(inventory.quick_item("throw_bomb"))

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
		var applied: bool = inventory.apply_oil(item_id)
		return _preparation_item_result(item_id, applied, "%s coats the blades for %s of active play. One bottle used." % [item_name, inventory.oil_time_text()] if applied else "The coating could not be applied.", "apply", 1 if applied else 0)
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
	snapshot["respec_reason"] = _respec_unavailable_reason()
	if quest_presentation != null:
		snapshot["objective"] = quest_presentation.get_objective_view_model()
	var supply_sources: Dictionary = {}
	if vendor_service != null and inventory != null:
		for vendor_id: String in ["tor_forge", "mira_apothecary"]:
			for stock: Dictionary in vendor_service.list_stock(vendor_id, inventory, story_state, quests):
				var item_id: String = str(stock.get("item_id", ""))
				var quote: Dictionary = vendor_service.quote(vendor_id, item_id, 1, inventory, story_state, quests)
				if not supply_sources.has(item_id):
					supply_sources[item_id] = []
				supply_sources[item_id].append({"vendor_id":vendor_id, "name":str(vendor_service.get_vendor(vendor_id).get("name", vendor_id)), "price":int(stock.get("price", 0)), "reason":str(quote.get("reason", ""))})
	snapshot["supply_sources"] = supply_sources
	if player != null and is_instance_valid(player):
		snapshot.merge({
			"health": float(player.health_component.health), "max_health": float(player.health_component.max_health),
			"stamina": float(player.stamina_component.stamina), "max_stamina": float(player.stamina_component.max_stamina),
			"weapon_mode": str(player.get_weapon_mode()), "selected_arrow_id": str(player.get_selected_arrow_id()),
			"equipment": player.save_equipment_state()
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

func _set_inventory_preference(key: String, value: String) -> void:
	var ok: bool = inventory.set_quick_item(key.trim_prefix("quick:"), value) if key.begins_with("quick:") else inventory.set_kit_preference(key, value)
	var message: String = "Pack order saved."
	if key == "category":
		message = value.capitalize()
	elif key.begins_with("quick:"):
		message = inventory.get_item_name(value) + " assigned to the " + ("remedy" if key == "quick:use_potion" else "field tool") + " slot."
	_finish_preparation_operation({"ok": ok, "operation": "inventory_preference", "message": message if ok else "That inventory choice is unavailable."})

func _learn_preparation_practice(upgrade_id: String) -> void:
	preparation_action_in_progress = true
	var result: Dictionary = progression.unlock_result(upgrade_id)
	preparation_action_in_progress = false
	if bool(result.get("ok", false)):
		_apply_progression_to_player()
	_finish_preparation_operation(result)

func _respec_unavailable_reason() -> String:
	if not game_started or current_zone_id != "greyfen" or not is_instance_valid(player) or not is_instance_valid(zone_root):
		return "Visit the shrine bench in Greyfen."
	if _journey_load_pending() or zone_transition_pending or zone_load_request_pending:
		return "Wait until the journey handoff has finished."
	if _story_has_active_combat():
		return "Finish the encounter before redistributing practices."
	var bench := zone_root.find_child("shrine_prayer", true, false) as Node3D
	if bench == null or player.global_position.distance_to(bench.global_position) > 3.5:
		return "Stand beside Greyfen's shrine bench, then open Growth."
	return ""

func _redistribute_practices() -> void:
	var reason := _respec_unavailable_reason()
	if reason != "":
		_finish_preparation_operation({"ok": false, "operation": "respec", "message": reason})
		return
	preparation_action_in_progress = true
	var result: Dictionary = progression.respec_result()
	preparation_action_in_progress = false
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

func _sell_to_vendor(vendor_id: String, item_id: String, quantity: int) -> void:
	if vendor_service == null or inventory == null or not game_started: return
	preparation_action_in_progress = true
	var result: Dictionary = vendor_service.sell(vendor_id,item_id,quantity,inventory)
	preparation_action_in_progress = false
	_finish_preparation_operation(result,vendor_id)

func _on_enemy_died(enemy) -> void:
	if progression != null and not bool(enemy.get("is_boss")) and not bool(enemy.get_meta("bell_called_ghoulkin", false)):
		var reward_id := str(enemy.get_meta("progression_reward_id", ""))
		if bool(enemy.get_meta("progression_opening_wave", false)):
			reward_id = "opening_wave:%d" % mini(wychwood_pack_kills, 4)
		if reward_id != "":
			progression.award_encounter(reward_id, str(enemy.get_meta("progression_zone", current_zone_id)), enemy.display_name)
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
			_retire_bell_eater()
			_spawn_crow_shrine_choice()
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
				_make_named_interactable("miller_record", "dialogue", "Read the miller's record", Vector3(-5.2,0.48,-3.4), Color(0.5,0.4,0.25))
			hud.show_status_cue("Ashwing falls", "victory")
			hud.toast("The mill roof catches the last ember, then goes dark. Something useful survived in the ash.")
		elif enemy.enemy_id == "bog_wretch":
			quests.complete_objective("main_teeth_in_rain", "fight_bog_wretch")
			story_state.set_flag("bog_memory_core_revealed", true)
			if not bool(story_state.get_flag("bog_core_exposed", false)):
				story_state.set_flag("bog_core_forced_open", true)
			_make_named_interactable("bog_core_choice", "dialogue", "Choose the memory core's fate", enemy.global_position, Color(0.35,0.58,0.52), Vector3.ONE * 0.4)
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
			if not bool(story_state.get_flag("saga_senn_requires_duel", false)):
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
	_collect_progression_rewards()
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
		load("res://scripts/zones/greyfen_section.gd").new().publish_oren_charm_return(ZoneBuildContext.new(self, "greyfen"))
	hud.toast("The red thread from Oren's token matches his erased place in the chapel.")
	_show_current_objective_guidance(5.0)

func _record_encounter_knowledge(enemy) -> void:
	if story_state == null or not is_instance_valid(enemy):
		return
	var enemy_id := str(enemy.enemy_id)
	var evidence_id := "creature:" + enemy_id
	if story_state.has_evidence(evidence_id):
		return
	story_state.record_evidence(evidence_id, {
		"kind": "observed", "enemy_id": enemy_id,
		"title": str(enemy.display_name), "zone": current_zone_id,
		"source": "Encounter in " + current_zone_id.replace("_", " ").capitalize(),
		"body": "Kael has faced this foe and seen how it moves."
	})

func _on_enemy_damaged(enemy, current: float, maximum: float) -> void:
	_record_encounter_knowledge(enemy)
	hud.show_enemy(enemy.display_name, current, maximum)
	hud.show_status_cue("Enemy hit", "item")
	audio.play_enemy_event(enemy.enemy_id, "hit", enemy.global_position, player.global_position)

func _on_enemy_windup_started(enemy) -> void:
	_record_encounter_knowledge(enemy)
	if enemy != null and player != null:
		audio.play_enemy_event(enemy.enemy_id, "windup", enemy.global_position, player.global_position)
	if zone_root != null and enemy != null:
		if bool(enemy.get("is_boss")):
			CombatFeedback.boss_telegraph(zone_root, enemy.global_position, enemy.enemy_id)
		else:
			CombatFeedback.ground_ring(zone_root, enemy.global_position, Color(0.46, 0.05, 0.025), 0.62, 0.18)
	if enemy != null and enemy.health_component != null:
		hud.show_enemy(enemy.display_name, enemy.health_component.health, enemy.health_component.max_health)
	var guide_guard_pending := str(story_state.get_flag("greyfen_guide", "")) == "active" and (not bool(story_state.get_flag("greyfen_lesson:block", false)) or not bool(story_state.get_flag("greyfen_lesson:parry", false)))
	if current_zone_id == "wychwood" and (guide_guard_pending or not bool(tutorial_flags.get("block_hint_done", false))):
		hud.set_guidance_hint(_guard_tutorial_hint(), 4.2)

func _on_enemy_attack_resolved(enemy, parried: bool, contact_position: Vector3) -> void:
	if parried:
		var blade: Dictionary = player.get_blade_world_segment()
		contact_position = Geometry3D.get_closest_point_to_segment(contact_position, blade.base, blade.tip)
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
	if enemy.enemy_id == "captain_senn":
		preload("res://scripts/saga_encounters.gd").senn_yields(self, enemy)
	elif enemy.enemy_id == "halvern_boss":
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

func _on_progression_changed() -> void:
	if hud != null and progression != null:
		hud.update_progression(progression.progress_model())

func _queue_progression_rewards() -> void:
	if progression_refresh_pending or not game_started or resource_shutdown_prepared:
		return
	progression_refresh_pending = true
	call_deferred("_flush_progression_rewards")

func _flush_progression_rewards() -> void:
	progression_refresh_pending = false
	if not game_started or resource_shutdown_prepared or _journey_load_pending() or zone_transition_pending or zone_load_request_pending:
		return
	if _collect_progression_rewards():
		story_save_pending = true
		call_deferred("_persist_story_action")

func _collect_progression_rewards() -> bool:
	if progression == null or quests == null or story_state == null or not game_started:
		return false
	var before: int = progression.claimed_rewards.size()
	progression.sync_story(quests, story_state, current_zone_id)
	return progression.claimed_rewards.size() != before

func _on_progression_arrival(zone_id: String) -> void:
	if not game_started or progression == null or resource_shutdown_prepared:
		return
	progression.record_arrival(zone_id, quests, story_state, _journey_load_pending())
	_queue_progression_rewards()

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
		if is_instance_valid(enemy) and not enemy.dead and enemy.enemy_id == enemy_id:
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
		"wychwood_encounter": {"started": wychwood_encounter_started, "wave": wychwood_pack_kills},
		"boss_states": boss_states,
		"day_night": day_night.save_state() if day_night != null else {}
	}

func load_world_state(state: Dictionary) -> void:
	removed_interactions = state.get("removed_interactions", {}).duplicate(true) if typeof(state.get("removed_interactions", {})) == TYPE_DICTIONARY else {}
	pending_ending = str(state.get("pending_ending", ""))
	wychwood_pack_kills = int(state.get("wychwood_pack_kills", state.get("ghoulkin_kills", wychwood_pack_kills)))
	var encounter: Variant = state.get("wychwood_encounter", {})
	wychwood_encounter_started = bool(encounter.get("started", wychwood_pack_kills > 0)) if encounter is Dictionary else wychwood_pack_kills > 0
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
	if not game_started or not is_instance_valid(player) or _journey_load_pending():
		return
	if is_instance_valid(zone_root) and bool(zone_root.get_meta("opening_scene_active", false)):
		var life := zone_root.find_child("GreyfenLifeController", true, false)
		if life != null: life.finish_opening_scene("interrupted")
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

func _show_companion_commands() -> void:
	if not game_started or _journey_load_pending() or zone_transition_pending or zone_load_request_pending or str(story_state.get_flag("bracken_home", "")) != "adopted":
		return
	audio.set_game_paused(true)
	get_tree().paused = true
	paused_by_menu = true
	input_router.set_context("pause")
	preload("res://scripts/companion_controller.gd").capture(self)
	var travel: Dictionary = preload("res://scripts/companion_controller.gd").saved_travel(self)
	var companion := zone_root.get_node_or_null("Bracken") as Node3D
	travel["present"] = companion != null and companion.is_visible_in_tree()
	hud.show_companion_commands(travel)

func _show_touch_actions() -> void:
	if not is_instance_valid(player):
		return
	audio.set_game_paused(true)
	get_tree().paused = true
	paused_by_menu = true
	input_router.set_context("pause")
	hud.show_touch_actions(player.get_selected_weapon_name(), not player.sword_sheathed if player.weapon_mode == "sword" else player.equipment_loadout.is_drawn())

func _on_touch_quick_action(action: String) -> void:
	if hud.active_menu != "touch_actions" or not get_tree().paused:
		return
	if action == "companion_command":
		_show_companion_commands()
		return
	var allowed := ["weapon_sword", "weapon_oathblade", "weapon_bow", "weapon_sheath", "use_potion", "throw_bomb", "target_lock", "target_next", "target_previous", "cycle_arrow", "camera_zoom_in", "camera_zoom_out"]
	if action not in allowed:
		return
	_resume_game()
	if get_tree().paused or not input_router.is_gameplay_context() or _journey_load_pending() or zone_transition_pending or zone_load_request_pending:
		return
	input_router.set_virtual_action(StringName(action), true)
	input_router.set_virtual_action(StringName(action), false)

func _resume_game() -> void:
	if not game_started or not is_instance_valid(player) or _journey_load_pending() or hud.active_menu == "main":
		return
	var returning_from_ending: bool = hud.active_menu == "ending"
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
	if returning_from_ending and bool(story_state.get_flag("final_choice_completed", false)) and current_zone_id == "hart_glade":
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
	elif action == "blood_effects":
		settings.toggle_blood_effects()
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
	else:
		settings.cycle_accessibility(action)
	if action != "visual_preset":
		hud.toast("Settings updated.")
	hud.show_settings_menu(hud.controls_back_target)

var _applied_setting_groups: Dictionary = {}
const SettingsDelta = preload("res://scripts/settings_delta.gd")

func _apply_runtime_settings(current_settings: Dictionary) -> void:
	CombatFeedback.reduce_flashes = bool(current_settings.get("flash_reduction", false))
	if runtime_packs != null:
		var preset := str(current_settings.get("quality_preset", "balanced"))
		var changed: bool = runtime_packs.quality_preset != preset
		runtime_packs.quality_preset = preset
		if changed and not game_started and (greyfen_prewarm_started or startup_packs_waiting \
				or startup_prepare_failed or route_zone_cache.has("greyfen")):
			_restart_menu_opening()
	if performance_budget_monitor != null:
		performance_budget_monitor.quality = str(current_settings.get("quality_preset", "balanced"))
	if SettingsDelta.changed(_applied_setting_groups, "audio", audio, current_settings, ["master_volume", "music_volume", "sfx_volume", "voice_volume", "quality_preset"]):
		audio.set_master_volume(float(current_settings.get("master_volume", 0.85)))
		audio.apply_mix_settings(current_settings)
		audio.set_ambient_accents_enabled(str(current_settings.get("quality_preset", "balanced")) == "quality")
	if SettingsDelta.changed(_applied_setting_groups, "hud", hud, current_settings, ["reduced_motion", "flash_reduction", "subtitle_speaker_names", "high_contrast", "subtitle_scale", "subtitle_background_opacity"]):
		hud.apply_accessibility(current_settings)
	if SettingsDelta.changed(_applied_setting_groups, "player", player, current_settings, ["difficulty"]):
		player.apply_difficulty_profile(settings.get_difficulty_profile())
	if SettingsDelta.changed(_applied_setting_groups, "camera", camera_rig, current_settings, ["mouse_sensitivity", "invert_y", "gamepad_look_sensitivity", "camera_shake", "reduced_motion", "flash_reduction", "targeting_assist"]):
		camera_rig.apply_settings(
			float(current_settings.get("mouse_sensitivity", 0.003)),
			bool(current_settings.get("invert_y", false)),
			float(current_settings.get("gamepad_look_sensitivity", 1.0))
		)
		camera_rig.apply_accessibility(current_settings)
		camera_rig.shake_decay = 1000.0 if float(current_settings.get("camera_shake", 1.0)) <= 0.0 else 6.0 / maxf(float(current_settings.get("camera_shake", 1.0)), 0.5)
	if visual_director != null and visual_director.sun != null and SettingsDelta.changed(_applied_setting_groups, "visuals", visual_director.sun, current_settings, ["quality_preset", "reduced_motion", "shadow_quality"]):
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
	_reconcile_preparation_objective()
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
	var weapon_name := "Steel"
	var arrow_id := "standard_arrow"
	if is_instance_valid(player):
		weapon_name = player.get_selected_weapon_name()
		arrow_id = player.equipment_loadout.selected_arrow_id
	var arrow_type := str({"standard_arrow": "Standard", "bodkin_arrow": "Bodkin", "ashfire_arrow": "Ashfire"}.get(arrow_id, "Standard"))
	var remedy_id: String = inventory.quick_item("use_potion")
	var tool_id: String = inventory.quick_item("throw_bomb")
	hud.update_equipment(int(inventory.items.get(remedy_id, 0)), int(inventory.items.get(tool_id, 0)), oil_name, int(inventory.items.get(arrow_id, 0)), arrow_type, weapon_name, remedy_id, tool_id, ceili(inventory.oil_remaining_seconds))
	if mobile_touch != null and is_instance_valid(player):
		mobile_touch.set_weapon_mode(player.get_weapon_mode())

func _reconcile_preparation_objective() -> void:
	if not game_started or _journey_load_pending() or inventory == null or quests == null:
		return
	if quests.is_active("main_teeth_in_rain") and not quests.is_objective_done("main_teeth_in_rain", "craft_moon_oil"):
		if int(inventory.items.get("moon_oil", 0)) > 0 or str(inventory.active_oil) == "moon_oil":
			quests.complete_objective("main_teeth_in_rain", "craft_moon_oil")

func _guard_tutorial_hint() -> String:
	var guard: Dictionary = input_router.describe_action("block") if input_router != null else {}
	var guarded := bool(story_state.get_flag("greyfen_lesson:block", false))
	return ("Begin guarding as the lunge lands to parry. " if guarded else "Hold your guard through an incoming strike to block. ") + str(guard.get("instruction", "Use your guard control")).trim_suffix(".")

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
	if current_zone_id == "wychwood" and (wychwood_encounter_started or player.global_position.z < 1.0):
		_ensure_wychwood_wave()
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

func _make_play_area_bounds(width: float, depth: float, color: Color) -> void:
	_zone_construction()._make_play_area_bounds(width, depth, color)

func _make_boundary_edge(edge_id: String, width: float, depth: float, color: Color) -> void:
	_zone_construction()._make_boundary_edge(edge_id, width, depth, color)

func _make_invisible_wall(pos: Vector3, size: Vector3) -> void:
	_zone_construction()._make_invisible_wall(pos, size)

func _make_greyfen_terrain_layers() -> void:
	_zone_construction()._make_greyfen_terrain_layers()

func _finish_greyfen_ground_surfaces() -> void:
	_zone_construction()._finish_greyfen_ground_surfaces()

func _finish_greyfen_paved_roads() -> void:
	_zone_construction()._finish_greyfen_paved_roads()

func _make_wychwood_terrain_layers() -> void:
	_zone_construction()._make_wychwood_terrain_layers()

func _make_wychwood_clearing_floor() -> void:
	var floor := MeshInstance3D.new()
	floor.name = "WychwoodClearingMud"
	floor.mesh = preload("res://scripts/prepared_zone_geometry.gd").mesh("wychwood_clearing")
	var material := world_materials.get_material("wet_mud", str(settings.settings.get("quality_preset", "balanced")), Color(0.30, 0.36, 0.29), 0.0, true).duplicate() as StandardMaterial3D
	material.vertex_color_use_as_albedo = true
	floor.material_override = material
	floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	zone_root.add_child(floor)

func _make_wychwood_winding_path() -> void:
	if zone_root.find_child("WychwoodWindingPath", true, false) != null:
		return
	var path := MeshInstance3D.new()
	path.name = "WychwoodWindingPath"
	var mesh := preload("res://scripts/prepared_zone_geometry.gd").mesh("wychwood_winding_path").duplicate() as ArrayMesh
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
	_zone_construction()._make_greyfen_path_edges()

func _make_wychwood_path_edges() -> void:
	_zone_construction()._make_wychwood_path_edges()

func _make_terrain_patch(name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	_zone_construction()._make_terrain_patch(name, pos, size, color)

func _make_terrain_patch_raw(name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	_zone_construction()._make_terrain_patch_raw(name, pos, size, color)

func _make_path_stone(pos: Vector3, scale_value: float) -> void:
	_zone_construction()._make_path_stone(pos, scale_value)

func _make_low_berm(pos: Vector3, size: Vector3, color: Color) -> void:
	_zone_construction()._make_low_berm(pos, size, color)

func _make_grass_tufts(points: Array, color: Color) -> void:
	_zone_construction()._make_grass_tufts(points, color)

func _make_spawn_composition() -> void:
	_zone_construction()._make_spawn_composition()

func _make_greyfen_first_impression_dressing(stage: String = "") -> void:
	_zone_construction()._make_greyfen_first_impression_dressing(stage)

func _make_quality_greyfen_overhaul() -> void:
	_zone_construction()._make_quality_greyfen_overhaul()

func _make_quality_survival_cluster(pos: Vector3) -> void:
	_zone_construction()._make_quality_survival_cluster(pos)

func _make_road_ruts() -> void:
	_zone_construction()._make_road_ruts()

func _make_lantern_rhythm() -> void:
	_zone_construction()._make_lantern_rhythm()

func _make_shrine_approach() -> void:
	_zone_construction()._make_shrine_approach()

func _make_village_story_clusters() -> void:
	_zone_construction()._make_village_story_clusters()

func _make_lantern_post(pos: Vector3, shrine_style: bool, casts_light: bool) -> void:
	_zone_construction()._make_lantern_post(pos, shrine_style, casts_light)

func _make_fake_light_pool(name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	_zone_construction()._make_fake_light_pool(name, pos, size, color)

func _make_firewood_stack(pos: Vector3, yaw: float) -> void:
	_zone_construction()._make_firewood_stack(pos, yaw)

func _make_broken_fence_run(pos: Vector3, vertical: bool) -> void:
	_zone_construction()._make_broken_fence_run(pos, vertical)

func _make_wheelbarrow(pos: Vector3, yaw: float) -> void:
	_zone_construction()._make_wheelbarrow(pos, yaw)

func _make_mourning_marker(pos: Vector3) -> void:
	_zone_construction()._make_mourning_marker(pos)

func _make_shrine_candle(pos: Vector3) -> void:
	_zone_construction()._make_shrine_candle(pos)

func _make_hanging_cloth(pos: Vector3, size: Vector3, color: Color) -> void:
	_zone_construction()._make_hanging_cloth(pos, size, color)

func _make_fake_fog_bank(pos: Vector3) -> void:
	_zone_construction()._make_fake_fog_bank(pos)

func _make_crow_silhouettes() -> void:
	_zone_construction()._make_crow_silhouettes()

func _add_crow_part(parent: Node3D, name: String, mesh: Mesh, local_pos: Vector3, scale_value: Vector3, color: Color, rotation_degrees := Vector3.ZERO) -> MeshInstance3D:
	return _zone_construction()._add_crow_part(parent, name, mesh, local_pos, scale_value, color, rotation_degrees)

func _make_visual_box(name: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	return _zone_construction()._make_visual_box(name, pos, size, color)

func _append_prepared_detail(id: String) -> void:
	_zone_construction()._append_prepared_detail(id)

func _make_prepared_prop(id: String) -> void:
	_zone_construction()._make_prepared_prop(id)

func _add_visual_box_child(parent: Node3D, name: String, local_pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	return _zone_construction()._add_visual_box_child(parent, name, local_pos, size, color)

func _make_greyfen_road_of_crows_story_beats() -> void:
	_zone_construction()._make_greyfen_road_of_crows_story_beats()

func _make_wychwood_road_of_crows_story_beats() -> void:
	_zone_construction()._make_wychwood_road_of_crows_story_beats()

func _make_post_ghoulkin_story_clue() -> void:
	_zone_construction()._make_post_ghoulkin_story_clue()

func _make_narrative_aftermath(zone_id: String) -> void:
	_zone_construction()._make_narrative_aftermath(zone_id)

func _make_black_feather_scatter(base_name: String, center: Vector3, count: int, spread: float) -> void:
	_zone_construction()._make_black_feather_scatter(base_name, center, count, spread)

func _make_broken_charm(name: String, pos: Vector3, yaw: float) -> void:
	_zone_construction()._make_broken_charm(name, pos, yaw)

func _make_dark_track(name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	_zone_construction()._make_dark_track(name, pos, size, color)

func _make_claw_marks(name: String, pos: Vector3, vertical: bool) -> void:
	_zone_construction()._make_claw_marks(name, pos, vertical)

func _make_wychwood_corridor() -> void:
	_zone_construction()._make_wychwood_corridor()

func _make_stylized_house(pos: Vector3) -> void:
	_make_prop_box("VillageHouseBody", pos + Vector3(0, 1.05, 0), Vector3(3.8, 2.1, 3.0), Color(0.25, 0.18, 0.13))
	_make_roof(pos + Vector3(0, 2.45, 0), Vector3(4.6, 0.95, 3.6), Color(0.12, 0.085, 0.06))
	_make_prop_box("VillageDoor", pos + Vector3(0, 0.75, -1.55), Vector3(0.75, 1.35, 0.12), Color(0.08, 0.055, 0.035))
	_make_prop_box("VillageWindow", pos + Vector3(-1.15, 1.25, -1.56), Vector3(0.55, 0.45, 0.08), Color(0.86, 0.55, 0.22))
	_make_prop_box("VillageWindow", pos + Vector3(1.15, 1.25, -1.56), Vector3(0.55, 0.45, 0.08), Color(0.86, 0.55, 0.22))

func _make_village_house_dressed(pos: Vector3, yaw: float, node_name: String) -> void:
	_zone_construction()._make_village_house_dressed(pos, yaw, node_name)

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
	_zone_construction()._make_house_collision(parent)

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
	_zone_construction()._make_village_dressing()

func _make_wychwood_gate_scene(pos: Vector3) -> void:
	_zone_construction()._make_wychwood_gate_scene(pos)

func _make_wychwood_route_dressing() -> void:
	_zone_construction()._make_wychwood_route_dressing()

func _make_quality_wychwood_overhaul() -> void:
	_zone_construction()._make_quality_wychwood_overhaul()

func _make_loose_role(role_name: String, pos: Vector3, scale_value: Vector3, yaw: float) -> Node3D:
	return _zone_construction()._make_loose_role(role_name, pos, scale_value, yaw)

func _make_roof(pos: Vector3, size: Vector3, color: Color) -> void:
	_make_prop_box("VillageRoof", pos, size, color)
	_make_prop_box("RoofRidge", pos + Vector3(0, 0.55, 0), Vector3(size.x * 0.18, 0.18, size.z * 1.05), color.darkened(0.18))

func _make_notice_board(pos: Vector3) -> void:
	_zone_construction()._make_notice_board(pos)

func _make_route_markers() -> void:
	_zone_construction()._make_route_markers()

func _make_shrine_scene(pos: Vector3) -> void:
	_zone_construction()._make_shrine_scene(pos)

func _make_blacksmith_scene(pos: Vector3) -> void:
	_zone_construction()._make_blacksmith_scene(pos)

func _make_cemetery_scene(pos: Vector3) -> void:
	_make_prop_box("CemeteryWall", pos + Vector3(0, 0.35, 1.9), Vector3(7.0, 0.7, 0.45), Color(0.18, 0.18, 0.17))
	for i in range(5):
		_make_gravestone(pos + Vector3(-2.6 + i * 1.3, 0, 0.4 + (i % 2) * 0.75))
	for offset in [Vector3(-3.4, 0, 2.0), Vector3(3.2, 0, 1.8), Vector3(0.4, 0, 2.2)]:
		_make_rubble(pos + offset)
	_make_fog_sheet(pos + Vector3(0, 0.55, 0.8), Vector3(7.2, 0.7, 2.8), Color(0.18, 0.18, 0.16, 0.11))

func _make_tree_cluster(points: Array) -> void:
	_zone_construction()._make_tree_cluster(points)

func _make_collapsed_road(pos: Vector3) -> void:
	_make_prop_box("BlockedRoadBerm", pos + Vector3(0.8, 0.65, 0), Vector3(3.2, 1.3, 5.4), Color(0.10, 0.095, 0.075))
	_make_prop_box("BlockedRoadPalisade", pos + Vector3(-0.1, 1.05, -1.25), Vector3(0.28, 2.1, 0.28), Color(0.13, 0.075, 0.04))
	_make_prop_box("BlockedRoadPalisade", pos + Vector3(-0.1, 1.05, 1.25), Vector3(0.28, 2.1, 0.28), Color(0.13, 0.075, 0.04))
	_make_prop_box("BlockedRoadRail", pos + Vector3(-0.15, 1.25, 0), Vector3(0.28, 0.28, 3.4), Color(0.15, 0.08, 0.045))
	for offset in [Vector3(0.5, 0, -1.8), Vector3(1.0, 0, 1.6), Vector3(1.4, 0, 0.2)]:
		_make_rubble(pos + offset)
	_make_torch(pos + Vector3(-1.0, 0, -2.1))

func _make_monster_clearing(pos: Vector3) -> void:
	_zone_construction()._make_monster_clearing(pos)

func _make_named_interactable(id: String, type: String, prompt: String, pos: Vector3, color: Color, scale_override: Vector3 = Vector3.ONE):
	return _zone_construction()._make_named_interactable(id, type, prompt, pos, color, scale_override)

func _make_ledger_interaction_visual(area: Node3D, scale_override: Vector3) -> void:
	_zone_construction()._make_ledger_interaction_visual(area, scale_override)

func _make_token_interaction_visual(area: Node3D, scale_override: Vector3) -> void:
	_zone_construction()._make_token_interaction_visual(area, scale_override)

func _make_village_place(id: String, type: String, prompt: String, pos: Vector3, size: Vector3, color: Color):
	return _zone_construction()._make_village_place(id, type, prompt, pos, size, color)

func _apply_greyfen_well_visual(visual: MeshInstance3D, pos: Vector3) -> void:
	_zone_construction()._apply_greyfen_well_visual(visual, pos)

func _make_board_game_staging(area: Node3D, id: String, size: Vector3) -> void:
	_zone_construction()._make_board_game_staging(area, id, size)

func _make_board_game_chair(area: Node3D, position: Vector3, yaw: float, batch: MultiMeshInstance3D, first_index: int) -> void:
	_zone_construction()._make_board_game_chair(area, position, yaw, batch, first_index)

func _world_prop_spec(id: String) -> Dictionary:
	return {
		"notice_board": {"kind": "notice_board", "state_key": "greyfen_prop:notice_board"},
		"village_well": {"kind": "well", "state_key": "greyfen_well_state"},
		"forge_corner": {"kind": "forge", "state_key": "greyfen_prop:forge_corner"},
		"shrine_prayer": {"kind": "shrine", "state_key": "shrine_prayer_state"},
		"common_table": {"kind": "table", "state_key": "common_table_state"},
		"barrel_board": {"kind": "table", "state_key": "barrel_board_state"},
		"vargan_ledger_choice": {"kind": "ledger", "state_key": "vargan_ledger_state"},
	}.get(id, {})

func _configure_npc_animation(mapped: Node3D, id: String) -> void:
	_zone_construction()._configure_npc_animation(mapped, id)

func _prepare_dialogue_presence(content: Dictionary) -> Dictionary:
	var result: Dictionary = content.duplicate(true)
	var aliases := {"anwen":"sister_anwen", "senn":"captain_senn", "tor":"blacksmith_tor", "elna":"widow_elna", "edric":"edric_campaign", "record_keeper_vale":"vargan_record_keeper", "vale":"vargan_record_keeper", "guard":"vargan_gate_guard"}
	for page: Dictionary in result.get("pages", []):
		var id := str(page.get("speaker_id", "narrator"))
		if id in ["player", "kael", "narrator", ""]:
			continue
		var supplied := instance_from_id(int(page.get("speaker_actor_id", 0))) as Node3D
		var actor: Node3D = supplied if is_instance_valid(supplied) and is_instance_valid(zone_root) and zone_root.is_ancestor_of(supplied) else null
		if actor == null:
			actor = zone_root.find_child(str(aliases.get(id, id)), true, false) as Node3D if zone_root != null else null
		if actor == null and zone_root != null and id == "edric":
			actor = zone_root.find_child("edric_castle", true, false) as Node3D
		if actor == null and zone_root != null:
			var witness: String = {"mira":"witness_-7", "rook":"witness_-3", "anwen":"witness_3"}.get(id, "")
			if witness != "":
				actor = zone_root.find_child(witness, true, false) as Node3D
		if actor != null and actor.is_visible_in_tree() and (player == null or actor.global_position.distance_to(player.global_position) <= 12.0):
			page["speaker_actor_id"] = actor.get_instance_id()
		else:
			page["speaker"] = str(page.get("speaker", id.capitalize())) + " - recorded account"
			page["speaker_id"] = "narrator"
			page["voice"] = ""
	return result

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
	preload("res://scripts/story_performance.gd").page(dialogue_runtime_coordinator.get_page_actor(), page, audio)

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
	_zone_construction()._make_gate_marker(parent, color, scale_override)

func _label_for_interactable(id: String, prompt: String) -> String:
	if dialogue != null and dialogue.has_dialogue(id):
		return dialogue.display_name(id, prompt)
	if id.begins_with("gate_"):
		return prompt
	return prompt.replace("Inspect ", "").replace("Gather ", "").replace("Take ", "")

func _make_clue(id: String, prompt: String, pos: Vector3, quest_id: String, objective_id: String, color: Color):
	return _zone_construction()._make_clue(id, prompt, pos, quest_id, objective_id, color)

func _present_castle_clue(id: String, title: String) -> void:
	var accounts := {
		"vargan_mile_marker": "Vargan's crest is worn into the roadside marker. Compare the passage this road promised with the closure posted at the gate.",
		"vargan_supply_cart": "A military supply cart stands abandoned on the approach. Keep this trace beside the dated command ledger before deciding whose order it supports.",
		"vargan_gate_notice": "The gatehouse notice closes the road under Vargan's authority. The written command, rather than the decorative crest alone, belongs in the account.",
		"vargan_iron_binding": "The blackened wire matches the binding recovered from the road tokens. It links the later containment to Vargan, not the original attack to a proven commander."
	}
	if not accounts.has(id):
		return
	audio.set_game_paused(true)
	hud.show_dialogue({"name": title, "pages": [{"speaker": "The recovered account", "speaker_id": "narrator", "text": accounts[id]}], "actions": []})

func _make_herb(id: String, pos: Vector3, color: Color):
	return _zone_construction()._make_herb(id, pos, color)

func _make_zone_gate(prompt: String, pos: Vector3, zone_target: String, spawn_pos: Vector3):
	return _zone_construction()._make_zone_gate(prompt, pos, zone_target, spawn_pos)

func _add_physical_door_visual(area: Node3D, zone_target: String) -> void:
	_zone_construction()._add_physical_door_visual(area, zone_target)

func _make_blocked_gate(prompt: String, pos: Vector3, message: String):
	var area = _make_named_interactable("blocked_ruins", "blocked_zone", prompt, pos, Color(0.20, 0.16, 0.11), Vector3(0.8, 0.8, 0.8))
	if area == null:
		return null
	area.set_meta("message", message)
	return area

func _connect_interactable(area, owner_root: Node3D = null, owner_cache: Array = []) -> void:
	var root := owner_root if is_instance_valid(owner_root) else zone_root
	var cache: Array = owner_cache if owner_root != null else interaction_area_cache
	if area is Area3D and area not in cache:
		cache.append(area as Area3D)
		if interaction_focus != null and root == zone_root:
			interaction_focus.register(area)
	area.body_entered.connect(func(body: Node):
		if root != zone_root or not is_instance_valid(root):
			return
		if body == player and is_instance_valid(area) and not area.is_queued_for_deletion() and not bool(area.get_meta("seamless_exterior_gate", false)) and area not in interaction_candidates:
			if interaction_focus != null:
				interaction_focus.register(area)
			interaction_candidates.append(area)
			interaction_focus_dirty = true
	)
	area.body_exited.connect(func(body: Node):
		if root != zone_root or not is_instance_valid(root):
			return
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
			if discovered != null and not discovered.is_queued_for_deletion() and discovered.has_method("get_context_prompt"):
				if discovered not in interaction_area_cache:
					interaction_area_cache.append(discovered)
				# Prepared roots already own their area list, but must join the
				# active targeting index exactly when that root is published.
				if interaction_focus != null:
					interaction_focus.register(discovered)
		interaction_area_cache_ready = true
	_prune_invalid_interaction_candidates()
	# The registered grid also covers save/spawn placement between Area signals.
	# Rebuild only the local set, not every interactable in the zone.
	interaction_candidates.clear()
	for candidate in interaction_focus.nearby(player.global_position, zone_root):
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
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.width = 240.0
		label.visible = visible

func _spawn_enemy(id: String, pos: Vector3, visual_role: String = "") -> Node:
	return _zone_construction()._spawn_enemy(id, pos, visual_role)

func _boss_is_resolved(id: String) -> bool:
	if id == "bell_eater" and bool(story_state.get_flag("bell_eater_legacy_retired", false)):
		return true
	if id == "bog_wretch" and quests.is_objective_done("main_teeth_in_rain", "fight_bog_wretch"):
		return true
	if id == "captain_senn" and (quests.is_objective_done("main_soldier_without_banner", "senn_confrontation") or str(story_state.get_flag("senn_fate", "")) not in ["", "unresolved"]):
		return true
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
	if current_zone_id != "greyfen" or _boss_is_resolved("bell_eater"):
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

func _retire_bell_eater() -> void:
	for enemy in active_enemies.duplicate():
		if not is_instance_valid(enemy):
			continue
		if str(enemy.enemy_id) != "bell_eater" and not bool(enemy.get_meta("bell_called_ghoulkin", false)):
			continue
		if enemy.dead:
			continue
		enemy.set_encounter_active(false)
		active_enemies.erase(enemy)
		if active_enemy_attacker == enemy:
			active_enemy_attacker = null
		enemy.queue_free()
	_restore_bell_eater_bystanders()
	if camera_rig != null:
		camera_rig.clear_target_lock()
	if hud != null:
		hud.hide_enemy()
	_sync_camera_enemy_cache()

func _open_rootbound_encounter() -> void:
	story_state.set_flag("rootbound_arena_entered", true)
	for enemy in active_enemies:
		if is_instance_valid(enemy) and str(enemy.enemy_id) == "rootbound_colossus":
			enemy.set_meta("dormant_arena", false)
			enemy.set_physics_process(true)
	var invitation: Node = zone_root.find_child("rootbound_challenge", true, false) if zone_root != null else null
	if invitation != null:
		_remove_interaction_candidate(invitation)
		invitation.queue_free()
	hud.toast("The guardian braces around the name-board. Follow the root channels before its heart opens.")

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
	_collect_progression_rewards()
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
	if current_zone_id == "undercroft" and str(story_state.get_flag("halvern_fate", "")) != "" and not _has_interactable("gate_record_hall"):
		_make_zone_gate("Return through the Record Hall toward Greyfen", Vector3(-6, 0, 14), "record_hall", Vector3(6, 0.95, -12))

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
	wychwood_encounter_started = true
	for enemy in active_enemies:
		if enemy != null and not enemy.dead and not enemy.is_encounter_active() and enemy.enemy_id in ids:
			enemy.set_encounter_active(true)
			break
	if hud != null:
		hud.toast(cue)
	if audio != null:
		audio.play_event("reveal", 0.02)

func _ensure_wychwood_wave() -> void:
	if wychwood_pack_kills >= 5 or quests.is_objective_done("main_road_of_crows", "fight_ghoulkin"):
		return
	for enemy in active_enemies:
		if not is_instance_valid(enemy) or enemy.dead or not enemy.has_meta("wychwood_wave"):
			continue
		if int(enemy.get_meta("wychwood_wave")) != wychwood_pack_kills:
			continue
		wychwood_encounter_started = true
		if not enemy.is_encounter_active():
			enemy.set_encounter_active(true)
			if hud != null:
				hud.toast("Movement answers from the clearing.")
		return

func checkpoint_return_position() -> Vector3:
	var recorded: Vector3 = player.global_position
	if spatial_service == null or not _story_has_active_combat():
		return recorded
	var bank: int = spatial_service.bank_for(recorded)
	var best: Vector3 = recorded
	var best_clearance := -1.0
	var anchors: Array = spatial_service.safe_spawns.duplicate()
	anchors.append_array(spatial_service.recovery_anchors)
	for anchor: Vector3 in anchors:
		if spatial_service.bank_for(anchor) != bank or not spatial_service.is_walkable_position(anchor, 0.55, bank):
			continue
		var clearance := INF
		for enemy in active_enemies:
			if is_instance_valid(enemy) and not enemy.dead and enemy.is_encounter_active():
				clearance = minf(clearance, anchor.distance_to(enemy.global_position))
		if clearance > best_clearance:
			best_clearance = clearance
			best = anchor
	return best if best_clearance >= 5.0 else recorded

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
	_zone_construction()._make_ground(pos, size, color, collision_enabled)

func _make_split_ground(width: float, depth: float, river_z: float, river_span: float, color: Color, bridge_width: float = 0.0, bridge_length: float = 0.0, bridge_approach_length: float = 0.0) -> void:
	_zone_construction()._make_split_ground(width, depth, river_z, river_span, color, bridge_width, bridge_length, bridge_approach_length)

func _make_bridge_corridor_collision(bridge_width: float, river_z: float, bridge_length: float, approach_length: float, zone_depth: float) -> void:
	_zone_construction()._make_bridge_corridor_collision(bridge_width, river_z, bridge_length, approach_length, zone_depth)

func _make_hut(pos: Vector3) -> void:
	_make_prop_box("Hut", pos + Vector3(0, 1, 0), Vector3(3.6, 2, 3.0), Color(0.22, 0.16, 0.12))
	_make_prop_box("Roof", pos + Vector3(0, 2.25, 0), Vector3(4.2, 0.8, 3.6), Color(0.10, 0.09, 0.08))
	_make_prop_box("Door", pos + Vector3(0, 0.65, -1.54), Vector3(0.75, 1.25, 0.08), Color(0.10, 0.07, 0.045))
	_make_prop_box("Chimney", pos + Vector3(1.1, 2.95, 0.4), Vector3(0.38, 0.9, 0.38), Color(0.12, 0.11, 0.10))

func _scene_randf() -> float:
	return _zone_construction()._scene_randf()

func _scene_randf_range(from: float, to: float) -> float:
	return _zone_construction()._scene_randf_range(from, to)

func _make_tree(pos: Vector3) -> void:
	_zone_construction()._make_tree(pos)

func _make_tree_wall(axis_extent: float, fixed_pos: float, count: int, along_x: bool) -> void:
	_zone_construction()._make_tree_wall(axis_extent, fixed_pos, count, along_x)

func _make_deadfall(pos: Vector3) -> void:
	_zone_construction()._make_deadfall(pos)

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

func _upload_static_batch(instance: MultiMeshInstance3D, transforms: Array, colors: Array = []) -> void:
	_zone_construction()._upload_static_batch(instance, transforms, colors)

func _flush_environment_batches() -> void:
	_zone_construction()._flush_environment_batches()

func _flush_authored_tree_assets() -> bool:
	return _zone_construction()._flush_authored_tree_assets()

func _make_multimesh_batch(node_name: String, mesh: Mesh, count: int, material: Material, use_colors: bool = false) -> MultiMeshInstance3D:
	return _zone_construction()._make_multimesh_batch(node_name, mesh, count, material, use_colors)

func _valid_material_or_fallback(material: Material) -> Material:
	return _zone_construction()._valid_material_or_fallback(material)

func _ensure_mesh_surface_materials(mesh: Mesh, fallback: Material) -> int:
	return _zone_construction()._ensure_mesh_surface_materials(mesh, fallback)

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
	_zone_construction()._make_road(pos, size, color)

func _make_world_wheel(id: String, pos: Vector3, radius: float, depth: float, color: Color, rotation_degrees: Vector3 = Vector3.ZERO) -> void:
	_zone_construction()._make_world_wheel(id, pos, radius, depth, color, rotation_degrees)

func _make_water_patch(id: String, pos: Vector3, size: Vector3, color: Color) -> void:
	_zone_construction()._make_water_patch(id, pos, size, color)

func _make_fence(pos: Vector3, vertical: bool) -> void:
	_zone_construction()._make_fence(pos, vertical)

func _make_gravestone(pos: Vector3) -> void:
	_zone_construction()._make_gravestone(pos)

func _make_cart(pos: Vector3, include_visual: bool = true) -> void:
	_zone_construction()._make_cart(pos, include_visual)

func _make_world_prop_anchor(id: String, kind: String, pos: Vector3, state_key: String = "") -> Node3D:
	return _zone_construction()._make_world_prop_anchor(id, kind, pos, state_key)

func _make_ritual_stone(pos: Vector3) -> void:
	_zone_construction()._make_ritual_stone(pos)

func _make_pillar(pos: Vector3) -> void:
	_zone_construction()._make_pillar(pos)

func _make_rubble(pos: Vector3) -> void:
	_zone_construction()._make_rubble(pos)

func _make_torch(pos: Vector3) -> void:
	_zone_construction()._make_torch(pos)

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
	_zone_construction()._make_fog_sheet(pos, scale_value, color)

func _make_prop_box(name: String, pos: Vector3, size: Vector3, color: Color, render_geometry: bool = true, prepared: Dictionary = {}) -> void:
	_zone_construction()._make_prop_box(name, pos, size, color, render_geometry, prepared)

func _make_collision_box(name: String, pos: Vector3, size: Vector3) -> void:
	_zone_construction()._make_collision_box(name, pos, size)

func _prop_requires_collision(lower_name: String) -> bool:
	return _zone_construction()._prop_requires_collision(lower_name)

func _is_first_route_clearance(pos: Vector3, radius: float = 0.0) -> bool:
	return _zone_construction()._is_first_route_clearance(pos, radius)

func _route_safe_position(pos: Vector3, target_x: float) -> Vector3:
	return _zone_construction()._route_safe_position(pos, target_x)

func _apply_first_route_materials(root: Node) -> void:
	_zone_construction()._apply_first_route_materials(root)

func _first_route_palette_key(node: Node) -> String:
	return _zone_construction()._first_route_palette_key(node)

func _node_keyword_path(node: Node) -> String:
	return _zone_construction()._node_keyword_path(node)

func _mesh_needs_visible_fallback(mesh_instance: MeshInstance3D) -> bool:
	return _zone_construction()._mesh_needs_visible_fallback(mesh_instance)

func _surface_has_authored_colors(mesh: Mesh, surface_index: int, material: Material) -> bool:
	return _zone_construction()._surface_has_authored_colors(mesh, surface_index, material)

func _is_bad_white_material(material: Material) -> bool:
	return _zone_construction()._is_bad_white_material(material)

func _first_route_material(key: String) -> StandardMaterial3D:
	return _zone_construction()._first_route_material(key)

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
		"halvern": "halvern_boss",
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
		"edric_castle": "castle_guard_human",
		"edric_campaign": "castle_guard_human",
		"captain_senn": "road_ranger_human",
		"halvern": "halvern_boss"
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
	return _zone_construction()._make_role_visual(role_name, category, scale_value)

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
		"edric_castle": "castle_guard_human",
		"edric_campaign": "castle_guard_human",
		"halvern_boss": "halvern_boss",
		"road_ranger": "road_ranger_human"
	}
	return str(roles.get(role_name, ""))

func _make_light(name: String, pos: Vector3, color: Color, energy: float) -> void:
	_zone_construction()._make_light(name, pos, color, energy)

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

func _zone_construction() -> Node3D:
	return ZoneBuildContext.active_host(self)

func _zone_runtime_fields() -> Dictionary:
	return ZoneBuildContext.fields_for(zone_root) if is_instance_valid(zone_root) else _unbound_zone_fields

func _publish_opening_batches(generation: int) -> bool:
	var root := zone_root
	var builder := _zone_construction()
	var slice_started := Time.get_ticks_usec()
	for phase in range(7):
		if not _opening_attempt_current(generation) or not is_instance_valid(root) or zone_root != root:
			return false
		builder.flush_environment_batch_step(phase)
		if Time.get_ticks_usec() - slice_started >= OPENING_BUILD_SLICE_USEC:
			await get_tree().process_frame
			await _wait_for_opening_build_slot(generation)
			slice_started = Time.get_ticks_usec()
	return _opening_attempt_current(generation) and is_instance_valid(root) and zone_root == root
