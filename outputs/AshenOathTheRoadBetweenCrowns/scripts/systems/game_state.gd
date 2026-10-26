extends "res://scripts/systems/game_definitions.gd"
## Shared session data. Values and save-facing property names are unchanged.
var _host: Node3D

func _init(host: Node3D) -> void:
	_host = host

var GreyfenSocialPresentation: Script:
	get: return _host._gameplay_script("greyfen_social_presentation")

var CemeteryEvidencePresentation: Script:
	get: return _host._gameplay_script("cemetery_evidence_presentation")

var WychwoodEvidencePresentation: Script:
	get: return _host._gameplay_script("wychwood_evidence_presentation")

var CampaignRecordPresentation: Script:
	get: return _host._gameplay_script("campaign_record_presentation")

var CampaignWildernessSection: Script:
	get: return _host._gameplay_script("zones/campaign_wilderness_section")

var WychwoodTerrainPresentation: Script:
	get: return _host._gameplay_script("wychwood_terrain_presentation")

var StoryActorPresence: Script:
	get: return _host._gameplay_script("story_actor_presence")

var StoryDecisionCoordinator: Script:
	get: return _host._gameplay_script("story_decision_coordinator")

var StoryWorldDirector: Script:
	get: return _host._gameplay_script("story_world_director")

var CovenantResolution: Script:
	get: return _host._gameplay_script("covenant_resolution")

var EnemyAI: Script:
	get: return _host._gameplay_script("enemy_ai")

var VisualDirector: Script:
	get: return _host._gameplay_script("visual_director")

var NpcAmbient: Script:
	get: return _host._gameplay_script("npc_ambient")

var CharacterPresentation: Script:
	get: return _host._gameplay_script("character_presentation")

var CharacterAnimationDriver: Script:
	get: return _host._gameplay_script("character_animation_driver")

var BoardGameOpponent: Script:
	get: return _host._gameplay_script("board_game_opponent")

var WorldVisualUpgrade: Script:
	get: return _host._gameplay_script("world_visual_upgrade")

var WorldMotionController: Script:
	get: return _host._gameplay_script("world_motion_controller")

var SurfaceFeedbackManager: Script:
	get: return _host._gameplay_script("surface_feedback_manager")

var WorldVFXController: Script:
	get: return _host._gameplay_script("world_vfx_controller")

var EpilogueResolver: Script:
	get: return _host._gameplay_script("epilogue_resolver")

var RuntimeActorFactory: Script:
	get: return _host._gameplay_script("runtime_actor_factory")

var BossEncounterScript: Script:
	get: return _host._gameplay_script("boss_encounter")

var player

var gameplay_scripts: Dictionary = {}

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
	get: return _host._zone_runtime_fields()["world_vfx"]
	set(value): _host._zone_runtime_fields()["world_vfx"] = value

var world_props: WorldPropController:
	get: return _host._zone_runtime_fields()["world_props"]
	set(value): _host._zone_runtime_fields()["world_props"] = value

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
	get: return _host._zone_runtime_fields()["interaction_candidates"]
	set(value): _host._zone_runtime_fields()["interaction_candidates"] = value

var interaction_area_cache: Array[Area3D]:
	get: return _host._zone_runtime_fields()["interaction_area_cache"]
	set(value): _host._zone_runtime_fields()["interaction_area_cache"] = value

var interaction_area_cache_ready: bool:
	get: return _host._zone_runtime_fields()["interaction_area_cache_ready"]
	set(value): _host._zone_runtime_fields()["interaction_area_cache_ready"] = value

var current_zone_id = "greyfen"

var enemy_defs = {}

var boss_defs = {}

var gameplay_runtime_ready := false

var browser_restore_revision := 0

var browser_restore_check := 0.0

var active_enemies: Array:
	get: return _host._zone_runtime_fields()["active_enemies"]
	set(value): _host._zone_runtime_fields()["active_enemies"] = value

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
	get: return _host._zone_runtime_fields()["runtime_light_count"]
	set(value): _host._zone_runtime_fields()["runtime_light_count"] = value

var tree_batch_data: Array[Dictionary]:
	get: return _host._zone_runtime_fields()["tree_batch_data"]
	set(value): _host._zone_runtime_fields()["tree_batch_data"] = value

var deadfall_batch_data: Array[Transform3D]:
	get: return _host._zone_runtime_fields()["deadfall_batch_data"]
	set(value): _host._zone_runtime_fields()["deadfall_batch_data"] = value

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
	get: return _host._zone_runtime_fields()["prop_batch_data"]
	set(value): _host._zone_runtime_fields()["prop_batch_data"] = value

var visual_box_batch_data: Array[Dictionary]:
	get: return _host._zone_runtime_fields()["visual_box_batch_data"]
	set(value): _host._zone_runtime_fields()["visual_box_batch_data"] = value

var terrain_patch_batch_data: Array[Dictionary]:
	get: return _host._zone_runtime_fields()["terrain_patch_batch_data"]
	set(value): _host._zone_runtime_fields()["terrain_patch_batch_data"] = value

var house_batch_data: Dictionary:
	get: return _host._zone_runtime_fields()["house_batch_data"]
	set(value): _host._zone_runtime_fields()["house_batch_data"] = value

var house_module_batch_data: Dictionary:
	get: return _host._zone_runtime_fields()["house_module_batch_data"]
	set(value): _host._zone_runtime_fields()["house_module_batch_data"] = value

var spatial_service: Node:
	get: return _host._zone_runtime_fields()["spatial_service"]
	set(value): _host._zone_runtime_fields()["spatial_service"] = value

var zone_runtime_coordinator: ZoneRuntimeCoordinator

var zone_residency := ZoneResidencyService.new()

var environment_batches_flushed: bool:
	get: return _host._zone_runtime_fields()["environment_batches_flushed"]
	set(value): _host._zone_runtime_fields()["environment_batches_flushed"] = value

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

var interaction_focus_cooldown := 0.0

var interaction_input_block_until_usec := 0

var compass_refresh_cooldown := 0.0

var navigation_dial_refresh_cooldown := 0.0

var tutorial_refresh_cooldown := 0.0

var target_status_refresh_cooldown := 0.0

var interaction_focus_dirty: bool:
	get: return _host._zone_runtime_fields()["interaction_focus_dirty"]
	set(value): _host._zone_runtime_fields()["interaction_focus_dirty"] = value

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

var encounter_spatial_index:
	get: return _host._zone_runtime_fields()["encounter_spatial_index"]
	set(value): _host._zone_runtime_fields()["encounter_spatial_index"] = value

var _hitstop_generation := 0

var _hitstop_restore_scale := 1.0

var _applied_setting_groups: Dictionary = {}
