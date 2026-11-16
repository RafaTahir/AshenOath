extends Node3D
## Shared session bindings; subsystem behavior remains with its injected owner.
## Compatibility bindings only: typed property aliases and explicit service calls.
## All behavior is owned by the injected systems. No scene traversal.
const Definitions = preload("res://scripts/systems/game_definitions.gd")
const BridgeSurfaceContract = Definitions.BridgeSurfaceContract
const SpatialSurfaceContract = Definitions.SpatialSurfaceContract
const Interactable = Definitions.Interactable
const CombatFeedback = Definitions.CombatFeedback
const WorldPropController = Definitions.WorldPropController
const InteractiveWorldProp = Definitions.InteractiveWorldProp
const OpeningSoundscape = Definitions.OpeningSoundscape
const ZoneSpatialService = Definitions.ZoneSpatialService
const RuntimeServiceRegistry = Definitions.RuntimeServiceRegistry
const ZoneCompositionRouter = Definitions.ZoneCompositionRouter
const ZoneRuntimeCoordinator = Definitions.ZoneRuntimeCoordinator
const ZoneResidencyService = Definitions.ZoneResidencyService
const DialogueRuntimeCoordinator = Definitions.DialogueRuntimeCoordinator
const CombatVfxCoordinator = Definitions.CombatVfxCoordinator
const QuestHudCoordinator = Definitions.QuestHudCoordinator
const ZoneSceneCatalog = Definitions.ZoneSceneCatalog
const CemeterySection = Definitions.CemeterySection
const OathGatePortal = Definitions.OathGatePortal
const PerformanceBudgetMonitor = Definitions.PerformanceBudgetMonitor
const SeamlessWorldService = Definitions.SeamlessWorldService
const CharacterRoleSpec = Definitions.CharacterRoleSpec
const ProductionObservationBridgeScript = Definitions.ProductionObservationBridgeScript
const OPENING_BUILD_SLICE_USEC = Definitions.OPENING_BUILD_SLICE_USEC
const OPENING_DETAIL_INITIAL_DELAY_SECONDS = Definitions.OPENING_DETAIL_INITIAL_DELAY_SECONDS
const OPENING_GAMEPLAY_HYDRATE_DELAY_SECONDS = Definitions.OPENING_GAMEPLAY_HYDRATE_DELAY_SECONDS
const OPENING_DETAIL_STAGE_DELAY_SECONDS = Definitions.OPENING_DETAIL_STAGE_DELAY_SECONDS
const OPENING_BOOT_MATERIAL_RESTORE_DELAY_SECONDS = Definitions.OPENING_BOOT_MATERIAL_RESTORE_DELAY_SECONDS
const OPENING_BOOT_MATERIAL_RESTORE_INTERVAL_SECONDS = Definitions.OPENING_BOOT_MATERIAL_RESTORE_INTERVAL_SECONDS
const OPENING_DETAIL_RETRY_SECONDS = Definitions.OPENING_DETAIL_RETRY_SECONDS
const BACKGROUND_RUNTIME_DELAY_SECONDS = Definitions.BACKGROUND_RUNTIME_DELAY_SECONDS
const BACKGROUND_RUNTIME_RETRY_SECONDS = Definitions.BACKGROUND_RUNTIME_RETRY_SECONDS
const OPENING_SAVE_DELAY_SECONDS = Definitions.OPENING_SAVE_DELAY_SECONDS
const OPENING_GAMEPLAY_VISUAL_BUCKETS = Definitions.OPENING_GAMEPLAY_VISUAL_BUCKETS
const CAMPAIGN_VISUAL_PREWARM_DELAY_SECONDS = Definitions.CAMPAIGN_VISUAL_PREWARM_DELAY_SECONDS
const CAMPAIGN_VISUAL_ROLES = Definitions.CAMPAIGN_VISUAL_ROLES
const PREDICTIVE_VISUAL_PREWARM_ROLES = Definitions.PREDICTIVE_VISUAL_PREWARM_ROLES
const ENVIRONMENT_ROLE_NORMALIZED_SIZE = Definitions.ENVIRONMENT_ROLE_NORMALIZED_SIZE
const OPENING_DETAIL_STAGES = Definitions.OPENING_DETAIL_STAGES
const OPENING_NAMED_ACTOR_IDS = Definitions.OPENING_NAMED_ACTOR_IDS
const MAX_CACHED_ROUTE_ZONES = Definitions.MAX_CACHED_ROUTE_ZONES
const ZONE_RETIRE_FRAMES = Definitions.ZONE_RETIRE_FRAMES
const MAX_SKINNED_RESOURCE_ANCHORS = Definitions.MAX_SKINNED_RESOURCE_ANCHORS
const MAX_RETIRED_MATERIAL_ANCHORS = Definitions.MAX_RETIRED_MATERIAL_ANCHORS
const MAX_TRANSITION_HISTORY = Definitions.MAX_TRANSITION_HISTORY
const DIALOGUE_INTERACTION_GUARD_SECONDS = Definitions.DIALOGUE_INTERACTION_GUARD_SECONDS
const SettingsDelta = Definitions.SettingsDelta
const State = preload("res://scripts/systems/game_state.gd")
const InstanceScope = preload("res://scripts/core/zone_instance_scope.gd")
var _construction_scope: InstanceScope
const TransitionModel = preload("res://scripts/models/world_transition_model.gd")
var world_transition: TransitionModel:
	get: return _state.world_transition
var _host: Node3D
var _state: State
var _systems: Dictionary = {}
signal configured(service_name: String)
var GreyfenSocialPresentation: Script:
	get: return _state.GreyfenSocialPresentation
var CemeteryEvidencePresentation: Script:
	get: return _state.CemeteryEvidencePresentation
var WychwoodEvidencePresentation: Script:
	get: return _state.WychwoodEvidencePresentation
var CampaignRecordPresentation: Script:
	get: return _state.CampaignRecordPresentation
var CampaignWildernessSection: Script:
	get: return _state.CampaignWildernessSection
var WychwoodTerrainPresentation: Script:
	get: return _state.WychwoodTerrainPresentation
var StoryActorPresence: Script:
	get: return _state.StoryActorPresence
var StoryDecisionCoordinator: Script:
	get: return _state.StoryDecisionCoordinator
var StoryWorldDirector: Script:
	get: return _state.StoryWorldDirector
var CovenantResolution: Script:
	get: return _state.CovenantResolution
var EnemyAI: Script:
	get: return _state.EnemyAI
var VisualDirector: Script:
	get: return _state.VisualDirector
var NpcAmbient: Script:
	get: return _state.NpcAmbient
var CharacterPresentation: Script:
	get: return _state.CharacterPresentation
var CharacterAnimationDriver: Script:
	get: return _state.CharacterAnimationDriver
var BoardGameOpponent: Script:
	get: return _state.BoardGameOpponent
var WorldVisualUpgrade: Script:
	get: return _state.WorldVisualUpgrade
var WorldMotionController: Script:
	get: return _state.WorldMotionController
var SurfaceFeedbackManager: Script:
	get: return _state.SurfaceFeedbackManager
var WorldVFXController: Script:
	get: return _state.WorldVFXController
var EpilogueResolver: Script:
	get: return _state.EpilogueResolver
var RuntimeActorFactory: Script:
	get: return _state.RuntimeActorFactory
var BossEncounterScript: Script:
	get: return _state.BossEncounterScript
var player:
	get: return _state.player
	set(value): _state.player = value
var gameplay_scripts: Dictionary:
	get: return _state.gameplay_scripts
	set(value): _state.gameplay_scripts = value
var production_observation_bridge:
	get: return _state.production_observation_bridge
	set(value): _state.production_observation_bridge = value
var camera_rig:
	get: return _state.camera_rig
	set(value): _state.camera_rig = value
var hud:
	get: return _state.hud
	set(value): _state.hud = value
var quests:
	get: return _state.quests
	set(value): _state.quests = value
var quest_presentation:
	get: return _state.quest_presentation
	set(value): _state.quest_presentation = value
var quest_beats:
	get: return _state.quest_beats
	set(value): _state.quest_beats = value
var dialogue:
	get: return _state.dialogue
	set(value): _state.dialogue = value
var story_state:
	get: return _state.story_state
	set(value): _state.story_state = value
var inventory:
	get: return _state.inventory
	set(value): _state.inventory = value
var vendor_service:
	get: return _state.vendor_service
	set(value): _state.vendor_service = value
var crafting:
	get: return _state.crafting
	set(value): _state.crafting = value
var combat:
	get: return _state.combat
	set(value): _state.combat = value
var save_manager:
	get: return _state.save_manager
	set(value): _state.save_manager = value
var settings:
	get: return _state.settings
	set(value): _state.settings = value
var world_materials:
	get: return _state.world_materials
	set(value): _state.world_materials = value
var day_night:
	get: return _state.day_night
	set(value): _state.day_night = value
var audio:
	get: return _state.audio
	set(value): _state.audio = value
var asset_helper:
	get: return _state.asset_helper
	set(value): _state.asset_helper = value
var visual_director:
	get: return _state.visual_director
	set(value): _state.visual_director = value
var _unbound_zone_fields: InstanceScope:
	get: return _state._unbound_zone_fields
	set(value): _state._unbound_zone_fields = value
var minigames:
	get: return _state.minigames
	set(value): _state.minigames = value
var progression:
	get: return _state.progression
	set(value): _state.progression = value
var input_router:
	get: return _state.input_router
	set(value): _state.input_router = value
var interaction_focus:
	get: return _state.interaction_focus
	set(value): _state.interaction_focus = value
var mobile_touch:
	get: return _state.mobile_touch
	set(value): _state.mobile_touch = value
var zone_streaming:
	get: return _state.zone_streaming
	set(value): _state.zone_streaming = value
var seamless_world: SeamlessWorldService:
	get: return _state.seamless_world
	set(value): _state.seamless_world = value
var runtime_packs:
	get: return _state.runtime_packs
	set(value): _state.runtime_packs = value
var qa_adapter:
	get: return _state.qa_adapter
	set(value): _state.qa_adapter = value
var neighbor_crossing_pending: bool:
	get: return _state.neighbor_crossing_pending
	set(value): _state.neighbor_crossing_pending = value
var neighbor_arrival_pending: bool:
	get: return _state.neighbor_arrival_pending
	set(value): _state.neighbor_arrival_pending = value
var neighbor_crossing_was_paused: bool:
	get: return _state.neighbor_crossing_was_paused
	set(value): _state.neighbor_crossing_was_paused = value
var scene_rng: RandomNumberGenerator:
	get: return _state.scene_rng
	set(value): _state.scene_rng = value
var active_interactable:
	get: return _state.active_interactable
	set(value): _state.active_interactable = value
var dialogue_runtime_coordinator: DialogueRuntimeCoordinator:
	get: return _state.dialogue_runtime_coordinator
	set(value): _state.dialogue_runtime_coordinator = value
var combat_vfx_coordinator: CombatVfxCoordinator:
	get: return _state.combat_vfx_coordinator
	set(value): _state.combat_vfx_coordinator = value
var quest_hud_coordinator: QuestHudCoordinator:
	get: return _state.quest_hud_coordinator
	set(value): _state.quest_hud_coordinator = value
var enemy_defs: Dictionary:
	get: return _state.enemy_defs
	set(value): _state.enemy_defs = value
var boss_defs: Dictionary:
	get: return _state.boss_defs
	set(value): _state.boss_defs = value
var gameplay_runtime_ready: bool:
	get: return _state.gameplay_runtime_ready
	set(value): _state.gameplay_runtime_ready = value
var browser_restore_revision: int:
	get: return _state.browser_restore_revision
	set(value): _state.browser_restore_revision = value
var browser_restore_check: float:
	get: return _state.browser_restore_check
	set(value): _state.browser_restore_check = value
var active_enemy_attacker: Node:
	get: return _state.active_enemy_attacker
	set(value): _state.active_enemy_attacker = value
var boss_saved_states: Dictionary:
	get: return _state.boss_saved_states
	set(value): _state.boss_saved_states = value
var wychwood_pack_kills: int:
	get: return _state.wychwood_pack_kills
	set(value): _state.wychwood_pack_kills = value
var wychwood_encounter_started: bool:
	get: return _state.wychwood_encounter_started
	set(value): _state.wychwood_encounter_started = value
var game_started: bool:
	get: return _state.game_started
	set(value): _state.game_started = value
var paused_by_menu: bool:
	get: return _state.paused_by_menu
	set(value): _state.paused_by_menu = value
var pending_ending: String:
	get: return _state.pending_ending
	set(value): _state.pending_ending = value
var story_action_in_progress: bool:
	get: return _state.story_action_in_progress
	set(value): _state.story_action_in_progress = value
var story_save_pending: bool:
	get: return _state.story_save_pending
	set(value): _state.story_save_pending = value
var preparation_action_in_progress: bool:
	get: return _state.preparation_action_in_progress
	set(value): _state.preparation_action_in_progress = value
var progression_refresh_pending: bool:
	get: return _state.progression_refresh_pending
	set(value): _state.progression_refresh_pending = value
var story_guidance_refresh_pending: bool:
	get: return _state.story_guidance_refresh_pending
	set(value): _state.story_guidance_refresh_pending = value
const Type_journey_continuity = preload("res://scripts/journey_continuity_coordinator.gd")
var journey_continuity: Type_journey_continuity:
	get: return _state.journey_continuity
	set(value): _state.journey_continuity = value
const Type_journey_loading = preload("res://scripts/journey_load_runtime.gd")
var journey_loading: Type_journey_loading:
	get: return _state.journey_loading
	set(value): _state.journey_loading = value
var journey_arrival_generation: int:
	get: return _state.journey_arrival_generation
	set(value): _state.journey_arrival_generation = value
var journey_models_refresh_pending: bool:
	get: return _state.journey_models_refresh_pending
	set(value): _state.journey_models_refresh_pending = value
var pending_player_restore: Dictionary:
	get: return _state.pending_player_restore
	set(value): _state.pending_player_restore = value
var zone_pack_request_serial: int:
	get: return _state.zone_pack_request_serial
	set(value): _state.zone_pack_request_serial = value
var removed_interactions: Dictionary:
	get: return _state.removed_interactions
	set(value): _state.removed_interactions = value
var autosave_cooldown: float:
	get: return _state.autosave_cooldown
	set(value): _state.autosave_cooldown = value
var last_safe_player_position: Vector3:
	get: return _state.last_safe_player_position
	set(value): _state.last_safe_player_position = value
var tutorial_flags: Dictionary:
	get: return _state.tutorial_flags
	set(value): _state.tutorial_flags = value
var material_cache: Dictionary:
	get: return _state.material_cache
	set(value): _state.material_cache = value
var tree_collision_body: StaticBody3D:
	get: return _state.tree_collision_body
	set(value): _state.tree_collision_body = value
var route_zone_cache: Dictionary:
	get: return _state.route_zone_cache
	set(value): _state.route_zone_cache = value
var route_enemy_cache: Dictionary:
	get: return _state.route_enemy_cache
	set(value): _state.route_enemy_cache = value
var route_zone_signatures: Dictionary:
	get: return _state.route_zone_signatures
	set(value): _state.route_zone_signatures = value
var route_spatial_cache: Dictionary:
	get: return _state.route_spatial_cache
	set(value): _state.route_spatial_cache = value
var retired_zone_roots: Array[Node]:
	get: return _state.retired_zone_roots
	set(value): _state.retired_zone_roots = value
var retired_zone_cleanup_root: Node3D:
	get: return _state.retired_zone_cleanup_root
	set(value): _state.retired_zone_cleanup_root = value
var pending_zone_retirements: int:
	get: return _state.pending_zone_retirements
	set(value): _state.pending_zone_retirements = value
var retired_skinned_actor_pool: Node3D:
	get: return _state.retired_skinned_actor_pool
	set(value): _state.retired_skinned_actor_pool = value
var skinned_resource_anchors: Dictionary:
	get: return _state.skinned_resource_anchors
	set(value): _state.skinned_resource_anchors = value
var retired_material_anchors: Dictionary:
	get: return _state.retired_material_anchors
	set(value): _state.retired_material_anchors = value
var retirement_material: StandardMaterial3D:
	get: return _state.retirement_material
	set(value): _state.retirement_material = value
var transition_history: Array[Dictionary]:
	get: return _state.transition_history
	set(value): _state.transition_history = value
var active_zone_signature: int:
	get: return _state.active_zone_signature
	set(value): _state.active_zone_signature = value
var shared_box_mesh: BoxMesh:
	get: return _state.shared_box_mesh
	set(value): _state.shared_box_mesh = value
var zone_runtime_coordinator: ZoneRuntimeCoordinator:
	get: return _state.zone_runtime_coordinator
	set(value): _state.zone_runtime_coordinator = value
var zone_residency: ZoneResidencyService:
	get: return _state.zone_residency
	set(value): _state.zone_residency = value
var prop_collision_body: StaticBody3D:
	get: return _state.prop_collision_body
	set(value): _state.prop_collision_body = value
var pending_anwen_relocation: bool:
	get: return _state.pending_anwen_relocation
	set(value): _state.pending_anwen_relocation = value
var runtime_services: Node:
	get: return _state.runtime_services
	set(value): _state.runtime_services = value
var performance_budget_monitor: PerformanceBudgetMonitor:
	get: return _state.performance_budget_monitor
	set(value): _state.performance_budget_monitor = value
var zone_transition_pending: bool:
	get: return _state.zone_transition_pending
	set(value): _state.zone_transition_pending = value
var zone_transition_frames: int:
	get: return _state.zone_transition_frames
	set(value): _state.zone_transition_frames = value
var pending_spawn_position: Vector3:
	get: return _state.pending_spawn_position
	set(value): _state.pending_spawn_position = value
var pending_spawn_facing: float:
	get: return _state.pending_spawn_facing
	set(value): _state.pending_spawn_facing = value
var loading_started_usec: int:
	get: return _state.loading_started_usec
	set(value): _state.loading_started_usec = value
var new_game_started_usec: int:
	get: return _state.new_game_started_usec
	set(value): _state.new_game_started_usec = value
var last_loading_metrics: Dictionary:
	get: return _state.last_loading_metrics
	set(value): _state.last_loading_metrics = value
