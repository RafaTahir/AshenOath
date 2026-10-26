extends RefCounted
## Immutable pre-refactor gameplay/presentation constants.

const BridgeSurfaceContract = preload("res://scripts/bridge_surface_contract.gd")

const SpatialSurfaceContract = preload("res://scripts/spatial_surface_contract.gd")

const Interactable = preload("res://scripts/interactable.gd")

const CombatFeedback = preload("res://scripts/combat_feedback.gd")

const WorldPropController = preload("res://scripts/world_prop_controller.gd")

const InteractiveWorldProp = preload("res://scripts/interactive_world_prop.gd")

const OpeningSoundscape = preload("res://scripts/opening_soundscape.gd")

const ZoneSpatialService = preload("res://scripts/zone_spatial_service.gd")

const RuntimeServiceRegistry = preload("res://scripts/runtime_service_registry.gd")

const ZoneCompositionRouter = preload("res://scripts/zone_composition_router.gd")

const ZoneRuntimeCoordinator = preload("res://scripts/zone_runtime_coordinator.gd")

const ZoneResidencyService = preload("res://scripts/zone_residency_service.gd")

const DialogueRuntimeCoordinator = preload("res://scripts/dialogue_runtime_coordinator.gd")

const CombatVfxCoordinator = preload("res://scripts/combat_vfx_coordinator.gd")

const QuestHudCoordinator = preload("res://scripts/quest_hud_coordinator.gd")

const ZoneSceneCatalog = preload("res://scripts/zone_scene_catalog.gd")

const CemeterySection = preload("res://scripts/cemetery_staging.gd")

const OathGatePortal = preload("res://scripts/oath_gate_portal.gd")

const PerformanceBudgetMonitor = preload("res://scripts/performance_budget_monitor.gd")

const SeamlessWorldService = preload("res://scripts/seamless_world_service.gd")

const CharacterRoleSpec = preload("res://scripts/character_role_spec.gd")

const ProductionObservationBridgeScript = preload("res://scripts/production_observation_bridge.gd")

const OPENING_BUILD_SLICE_USEC := 8000

const OPENING_DETAIL_INITIAL_DELAY_SECONDS := 30.0

const OPENING_GAMEPLAY_HYDRATE_DELAY_SECONDS := 0.75

const OPENING_DETAIL_STAGE_DELAY_SECONDS := 0.05

const OPENING_BOOT_MATERIAL_RESTORE_DELAY_SECONDS := 1.5

const OPENING_BOOT_MATERIAL_RESTORE_INTERVAL_SECONDS := 0.08

const OPENING_DETAIL_RETRY_SECONDS := 5.0

const BACKGROUND_RUNTIME_DELAY_SECONDS := 45.0

const BACKGROUND_RUNTIME_RETRY_SECONDS := 12.0

const OPENING_SAVE_DELAY_SECONDS := 30.0

const OPENING_GAMEPLAY_VISUAL_BUCKETS := 16

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

const MAX_CACHED_ROUTE_ZONES := ZoneResidencyService.MAX_CACHED_ROUTE_ZONES

const ZONE_RETIRE_FRAMES := ZoneResidencyService.ZONE_RETIRE_FRAMES

const MAX_SKINNED_RESOURCE_ANCHORS := ZoneResidencyService.MAX_SKINNED_RESOURCE_ANCHORS

const MAX_RETIRED_MATERIAL_ANCHORS := ZoneResidencyService.MAX_RETIRED_MATERIAL_ANCHORS

const MAX_TRANSITION_HISTORY := 16

const DIALOGUE_INTERACTION_GUARD_SECONDS := 0.8

const SettingsDelta = preload("res://scripts/settings_delta.gd")
