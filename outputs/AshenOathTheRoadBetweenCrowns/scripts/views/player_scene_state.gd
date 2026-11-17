extends CharacterBody3D
## Shared scene bindings; combat decisions live in the pure models.

const MotionStep = preload("res://scripts/systems/character_motion_step.gd")

signal blade_contact_requested(contact: Dictionary)
signal potion_requested
signal bomb_requested
signal beam_requested(charge_ratio: float, direction: Vector3)
signal beam_phase_changed(phase: String)
signal arrow_requested(request: Dictionary)
signal arrow_unavailable
signal footstep
signal ability_hint(text: String)
signal parried
signal blocked(amount: float)
signal hurt(amount: float)
signal stamina_exhausted(action: String)
signal died

const HealthComponent = preload("res://scripts/health_component.gd")
const StaminaComponent = preload("res://scripts/stamina_component.gd")
var AssetSpawnHelper: Script:
	get:
		return load("res://scripts/asset_spawn_helper.gd")
var CharacterPresentation: Script:
	get:
		return load("res://scripts/character_presentation.gd")
const CharacterRoleSpec = preload("res://scripts/character_role_spec.gd")
var CharacterAnimationDriver: Script:
	get:
		return load("res://scripts/character_animation_driver.gd")
const CharacterMaterialBindings = preload("res://scripts/character_material_bindings.gd")
const EquipmentLoadout = preload("res://scripts/equipment_loadout.gd")
const CombatBodyQuery = preload("res://scripts/combat_body_query.gd")

var walk_speed: float = 3.4
var run_speed: float = 5.3
var dodge_speed: float = 8.0
var gravity: float = 24.0
var jump_speed: float = 8.2
var acceleration: float = 17.0
var run_acceleration: float = 13.0
var deceleration: float = 21.0
var turn_speed: float = 11.0
var attack_cooldown: float = 0.0
var dodge_time: float = 0.0
var dodge_dir: Vector3 = Vector3.ZERO
var can_control: bool = true
var transition_locked := false
var difficulty_profile: Dictionary = {"incoming_damage_multiplier": 1.0, "parry_window": 0.30, "dodge_cost_modifier": 0.0, "attack_buffer": 0.18}
var camera_controller: Variant
var input_source: Node
var health_component: Variant
var stamina_component: Variant
var visual_root: Node3D
var _camera_close_view := false
var _camera_body_shadows: Dictionary = {}
var body_visual: MeshInstance3D
var body_base_color := Color(0.24, 0.27, 0.25)
var weapon_root: Node3D
var sword_visual: MeshInstance3D
var sword_hilt_visual: MeshInstance3D
var sword_trail_visual: MeshInstance3D
var rig_sword_visual: Node3D
var sword_attachment: BoneAttachment3D
var sword_equipment_pivot: Node3D
var guard_arm_ik: SkeletonIK3D
var guard_arm_applied := false
var companion_hand_ik: SkeletonIK3D
var companion_gesture_target: WeakRef
var companion_gesture_kind := ""
var companion_gesture_time := 0.0
var companion_gesture_duration := 0.0
var sword_grip_bones: Dictionary = {}
var sword_grip_base_rotations: Dictionary = {}
var sword_grip_applied_rotations: Dictionary = {}
var sword_grip_pose_applied := false
var slash_arc_root: Node3D
var slash_arc_primary: MeshInstance3D
var slash_arc_secondary: MeshInstance3D
var slash_arc_spark: MeshInstance3D
var asset_helper: Variant
var animation_driver: Variant
var move_phase: float = 0.0
var footstep_distance: float = 0.0
var locomotion_velocity := Vector3.ZERO
var _movement_frame_active := false
var _movement_frame_camera: Node
var _movement_reference_yaw := 0.0
var _movement_manual_yaw := 0.0
var _mapped_body: Node3D
var _hurt_overlay: StandardMaterial3D
var _hurt_overlay_bindings: Array[Dictionary] = []
var animation_step_signal_bound := false
var attack_anim_time: float = 0.0
var attack_anim_heavy: bool = false
var pending_attack_damage := 0.0
var pending_attack_radius := 0.0
var pending_attack_heavy := false
var attack_sequence_id := 0
var attack_contact_emitted := false
var previous_contact_progress := 0.0
var previous_blade_base := Vector3.ZERO
var previous_blade_tip := Vector3.ZERO
var visual_previous_blade_base := Vector3.ZERO
var visual_previous_blade_tip := Vector3.ZERO
var blade_base_marker: Node3D
var blade_tip_marker: Node3D
var hurt_flash_time: float = 0.0
var hurt_react_time: float = 0.0
var parry_window: float = 0.0
var buffered_attack := ""
var attack_buffer_time := 0.0
var block_pose_weight: float = 0.0
var grounded_weight: float = 0.0
var beam_charging: bool = false
var beam_charge_time: float = 0.0
var beam_cooldown: float = 0.0
var beam_charge_visual: MeshInstance3D
var beam_left_hand_glow: MeshInstance3D
var beam_right_hand_glow: MeshInstance3D
var beam_left_hand_socket: BoneAttachment3D
var beam_right_hand_socket: BoneAttachment3D
var beam_left_arm_ik: SkeletonIK3D
var beam_right_arm_ik: SkeletonIK3D
var beam_arm_pose_applied := false
var sheathed_sword_visual: Node3D
var blade_hand_visuals: Dictionary = {}
var blade_back_visuals: Dictionary = {}
var blade_scabbards: Dictionary = {}
var beam_cast_state := ""
var beam_state_time := 0.0
var beam_locked_direction := Vector3.ZERO
var beam_pending_ratio := 0.0
var beam_release_elapsed := 0.0
var beam_release_emitted := false
var beam_cancel_reason := ""
var beam_state_sequence := 0
var beam_release_direction := Vector3.ZERO
var beam_restore_equipment: Dictionary = {}
var equipment_loadout: EquipmentLoadout = EquipmentLoadout.new()
var sword_sheathed: bool:
	get:
		return not equipment_loadout.sword_drawn
	set(value):
		equipment_loadout.set_sword_drawn(not value)
var weapon_cycle_armed := false
var weapon_cycle_held := false
var weapon_cycle_elapsed := 0.0
var equipment_pending_attack := ""
var bow_back_visual: Node3D
var equipment_left_arm_ik: SkeletonIK3D
var sword_grip_basis := Basis.IDENTITY
var sword_grip_calibrated := false
var inventory_ref: Variant
var weapon_mode: String:
	get:
		return equipment_loadout.active_weapon
	set(value):
		equipment_loadout.set_active_weapon(value)
var bow_aiming := false
var field_tool_aiming := false
var _field_tool_pressed := false
var bow_draw_time := 0.0
var bow_recovery := 0.0
var bow_drawing := false
var bow_requires_fire_release := false
var bow_pose_aim := 0.0
var bow_pose_direction := Vector3.FORWARD
var bow_pose_local_origin := Vector3.ZERO
var bow_pose_valid := false
var bow_aim_solution: Dictionary = {}
var bow_presentation: SkeletonModifier3D
var training_range: WeakRef
var selected_arrow_id := "standard_arrow"
var bow_visual: Node3D
var bow_quiver_visual: Node3D
var bow_attachment: BoneAttachment3D
var bow_quiver_attachment: BoneAttachment3D
const BOW_MAX_DRAW := 1.0
const BOW_RANGE := 24.0
const MODELED_SWORD_PATH := "res://assets_external/characters/Sword.fbx"
const HeldPropGeometry = preload("res://scripts/held_prop_geometry.gd")
const MODELED_BOW_PATH := "res://assets_external/characters/Ranger_Bow.fbx"
const MODELED_ARROW_PATH := "res://assets/characters/kael_arrow.glb"

const BEAM_STATE_IDLE := ""
const BEAM_STATE_SHEATHING := "sheathing"
const BEAM_STATE_CHARGING := "charging"
const BEAM_STATE_RELEASING := "releasing"
const BEAM_STATE_REDRAWING := "redrawing"
var movement_state: String = "idle"
var movement_blend: float = 0.0
var strafe_blend: float = 0.0
var backward_blend: float = 0.0
var jump_pose_weight: float = 0.0
var landing_compression: float = 0.0
var smoothed_ground_normal: Vector3 = Vector3.UP
var left_foot_ground_offset: float = 0.0
var right_foot_ground_offset: float = 0.0
var ground_adaptation_accumulator := 0.0
const GROUND_ADAPTATION_INTERVAL := 1.0 / 30.0
var contact_shadow: Node3D
var was_on_floor: bool = false
var step_up_cooldown: float = 0.0
var progression: Variant

const CombatModel = preload("res://scripts/models/player_combat_locomotion_model.gd")
const BowModel = preload("res://scripts/models/bow_aim_release_model.gd")
const SimClock = preload("res://scripts/core/sim_clock.gd")
const Events = preload("res://scripts/core/sim_event_bus.gd")
const Frame = preload("res://scripts/core/input_frame.gd")
var combat_model: CombatModel = CombatModel.new()
var bow_model: BowModel = BowModel.new()
var simulation_clock: SimClock = SimClock.new()
var combat_events: Events = Events.new()
var presentation_enabled: bool = true
var _tick_delta: float = SimClock.TICK_DT
var _simulation_tick: int = 0
var _first_substep: bool = true
var _pending_pressed: Dictionary = {}
var _pending_released: Dictionary = {}
var player_equipment_view: RefCounted
var player_blade_geometry_view: RefCounted
var player_character_view: RefCounted
var player_equipment_pose_view: RefCounted
var player_animation_view: RefCounted
var player_camera_occlusion_view: RefCounted
var player_locomotion_view: RefCounted
var player_action_view: RefCounted
var player_bow_view: RefCounted
var player_oathfire_view: RefCounted
var player_blade_contact_view: RefCounted
