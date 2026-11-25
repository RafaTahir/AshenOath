extends CharacterBody3D

signal died(enemy: Node)
signal damaged(enemy: Node, current: float, maximum: float)
signal windup_started(enemy: Node)
signal attack_resolved(enemy: Node, parried: bool, contact_position: Vector3)
signal special_attack_resolved(enemy: Node, attack_id: String, contact_position: Vector3, radius: float, damage: float, parried: bool)
signal special_attack_interrupted(enemy: Node, attack_id: String, reason: String)
signal parry_window_opened(enemy: Node, duration: float)
signal boss_phase_changed(enemy: Node, phase: int)

const HealthComponent = preload("res://scripts/health_component.gd")
var AssetSpawnHelper: Script:
	get:
		return load("res://scripts/asset_spawn_helper.gd")
var CharacterPresentation: Script:
	get:
		return load("res://scripts/character_presentation.gd")
const CharacterRoleSpec = preload("res://scripts/character_role_spec.gd")
var CombatFeedback: Script:
	get:
		return load("res://scripts/combat_feedback.gd")
var CharacterAnimationDriver: Script:
	get:
		return load("res://scripts/character_animation_driver.gd")
const MotionStep = preload("res://scripts/systems/character_motion_step.gd")
const NativeAttackProfiles = preload("res://scripts/native_attack_profiles.gd")
# The role manifest owns the Ashwing source selected at runtime; do not pull
# the large optional enemy asset into the browser boot dependency graph here.

var enemy_id: String = "ghoulkin"
var visual_role_override := ""
var display_name: String = "Enemy"
var player: Variant
var health_component: Variant
var damage: float = 10.0
var move_speed: float = 2.0
var attack_range: float = 1.4
var sense_range: float = 10.0
var tag: String = "beast"
var weakness: String = ""
var memory_rule := ""
var motivation := ""
var attack_cooldown: float = 0.0
var slowed_time: float = 0.0
var dead: bool = false
var body_visual: MeshInstance3D
var visual_root: Node3D
var boss_visual_root: Node3D
var boss_phase_sigil: MeshInstance3D
var asset_helper: Variant
var base_color: Color = Color.WHITE
var base_body_scale: Vector3 = Vector3.ONE
var anim_phase: float = 0.0
var windup_time: float = 0.0
var hit_flash_time: float = 0.0
var pending_attack_time: float = 0.0
var attack_windup_total := 0.0
var stagger_time: float = 0.0
var surrender_offer := false
var surrender_declined := false
var resolved_nonlethal := false
var home_position: Vector3 = Vector3.ZERO
var leash_radius: float = 14.0
var windup_marker: MeshInstance3D
var attack_recovery_time: float = 0.0
var death_pose_time: float = 0.0
var animation_driver: Variant
var behavior_profile := "direct"
var flank_sign := 1.0
var parry_exposed_time := 0.0
var far_tick_accumulator := 0.0
var near_tick_accumulator := 0.0
const NEAR_AI_TICK_INTERVAL := 1.0 / 30.0
const MIN_COMBAT_SPACING := 0.82
var attack_gate: Callable
var owns_attack_token := false
var encounter_active := true
var spatial_service: Variant
var navigation_agent: NavigationAgent3D
var navigation_route: Array[Vector3] = []
var navigation_route_index := 0
var navigation_refresh_time := 0.0
var navigation_target := Vector3.INF
var encounter_slot := 0
var preferred_distance := 2.15
var approach_angle_degrees := 0.0
var contact_radius := 0.72
var strike_profile: Dictionary = {}
var attack_contact_bone := -1
var attack_contact_local_offset := Vector3.ZERO
var attack_trace_start := Vector3.ZERO
var attack_trace_end := Vector3.ZERO
var last_attack_contact := Vector3.ZERO
var attack_trace_uses_skeleton := false
var perception_memory_duration := 2.5
var perception_memory_time := 0.0
var perception_refresh_time := 0.0
var can_see_player := false
var last_known_player_position := Vector3.INF
var boss_phase := 1
var is_boss := false
var base_move_speed := 2.0
var base_damage := 10.0
var boss_visual_time := 0.0
var boss_identity_base_scale := Vector3.ONE
var encounter_peers: Array = []
var ambient_state := "resting"
var native_ambient_authored := false
var native_ambient_elapsed := 0.0
var native_ambient_phase := -1
var ambient_elapsed := 0.0
var ambient_remaining := 0.0
var ambient_target := Vector3.INF
var ambient_cycle := 0
var had_player_contact := false
var native_face: Node
var native_attack_profile: Dictionary = {}
var native_attack_tail_active := false
var presence_home_yaw := 0.0
var presence_clock := 0.0
var heard_cue_deadline := 0


var encounter_spatial_index: Variant
var _query_scratch: Variant = preload("res://scripts/physics_query_scratch.gd").new()
var _perception_query_key: Array = []
var _perception_query_result := false
var _decision_phase_applied := false


const Tactics = preload("res://scripts/models/enemy_tactics_model.gd")
const SeededRng = preload("res://scripts/core/seeded_rng.gd")
const SimClock = preload("res://scripts/core/sim_clock.gd")
var tactics: Tactics = Tactics.new()
var combat_rng: SeededRng = SeededRng.new(1)
var simulation_clock: SimClock = SimClock.new()
var presentation_enabled: bool = true
var enemy_visual_view: RefCounted
var enemy_body_view: RefCounted
var enemy_identity_view: RefCounted
var enemy_equipment_view: RefCounted
var enemy_navigation_view: RefCounted
var enemy_presence_view: RefCounted
var enemy_strike_view: RefCounted
