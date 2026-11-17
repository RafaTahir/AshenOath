extends RefCounted

const AttackShape = preload("res://scripts/models/enemy_attack_shape_model.gd")
## enemy strike view: scene-only responsibilities.

var _actor: CharacterBody3D

func _init(actor: CharacterBody3D) -> void:
	_actor = actor

func slow(seconds: float) -> void:
	if not _actor.encounter_active:
		return
	_actor.slowed_time = max(_actor.slowed_time, seconds)

func set_encounter_active(value: bool) -> void:
	_actor.encounter_active = value
	if not value:
		_actor.native_attack_tail_active = false
		if _actor.animation_driver != null:
			_actor.animation_driver.set_external_tick(false)
			# Suspension cancels the encounter's strike, including its post-contact
			# tail. Otherwise the frozen action rejects the next authorized Attack
			# after activation, despite the AI having started a fresh windup.
			if not _actor.dead and _actor.animation_driver.action_active and _actor.animation_driver.current_state in ["windup", "attack"]:
				_actor.animation_driver.stop_action()
		# A suspended strike must not reserve the encounter's attack lane or
		# resume halfway through its telegraph when this actor becomes active.
		_actor._release_attack_token()
		_actor.pending_attack_time = 0.0
		_actor.windup_time = 0.0
		_actor.velocity = Vector3.ZERO
		_actor._hide_windup_marker()
	_actor.visible = value
	_actor.set_physics_process(value)
	if _actor.visual_root != null:
		_actor.visual_root.process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED
	if _actor.navigation_agent != null:
		_actor.navigation_agent.process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED
	if _actor.animation_driver != null:
		_actor.animation_driver.set_distance_suspended(not value)
	for collision in _actor.find_children("*", "CollisionShape3D", true, false):
		collision.set_deferred("disabled", not value)
	if value:
		_actor.velocity = Vector3.ZERO
		_actor.near_tick_accumulator = 0.0
		_actor.CombatFeedback.prewarm_enemy_feedback(_actor)
		# Build the first windup marker at wave activation, before combat sampling
		# or the enemy's first attack. Lazy PrismMesh/material creation here can
		# otherwise create a single _actor.visible hitch on Intel/ANGLE.
		if _actor.windup_marker == null:
			_actor.windup_marker = _actor.CombatFeedback.warning_marker(_actor, _actor)
			if _actor.windup_marker != null:
				_actor.windup_marker.visible = false
		if _actor.animation_driver != null:
			_actor.animation_driver.set_locomotion(0.0, Vector3.ZERO, true)

func stagger(seconds: float = 0.7) -> void:
	_actor.native_attack_tail_active = false
	if _actor.animation_driver != null:
		_actor.animation_driver.set_external_tick(false)
	_actor.stagger_time = max(_actor.stagger_time, seconds)
	_actor.windup_time = 0.0
	_actor.pending_attack_time = 0.0
	_actor._release_attack_token()
	if _actor.animation_driver != null:
		_actor.animation_driver.trigger_action("hit")

func _tick_pending_attack(delta: float) -> void:
	if _actor.pending_attack_time <= 0.0:
		return
	# Read the opponent early, then commit. A late dodge can leave the blade
	# behind instead of being followed by an instantaneous full-body swivel.
	if is_instance_valid(_actor.player) and _actor.pending_attack_time > _actor.attack_windup_total * 0.45:
		var offset: Vector3 = _actor.player.global_position - _actor.global_position
		offset.y = 0.0
		if offset.length_squared() > 0.01:
			var desired_yaw: Variant = atan2(-offset.x, -offset.z)
			var turn_rate: Variant = 1.25 if _actor.enemy_id in ["wychwood_brute", "rootbound_colossus", "bell_eater"] else 2.1
			_actor.rotation.y += clampf(wrapf(desired_yaw - _actor.rotation.y, -PI, PI), -turn_rate * delta, turn_rate * delta)
	if _actor.animation_driver != null:
		_actor.animation_driver.advance_external(minf(delta, _actor.pending_attack_time))
	_actor.pending_attack_time = maxf(0.0, _actor.pending_attack_time - delta)
	_actor.attack_trace_end = _actor._attack_contact_point()
	if _actor.pending_attack_time <= 0.0:
		_actor._resolve_attack()

func _resolve_attack() -> void:
	if _actor.animation_driver != null:
		_actor.animation_driver.set_external_tick(false)
	_actor._release_attack_token()
	if _actor.dead or _actor.player == null or not (_actor.player != null):
		return
	# Recovery belongs to the attempted swing, including a successful dodge.
	_actor.attack_recovery_time = maxf(_actor.attack_recovery_time, _actor._strike_recovery())
	_actor.attack_trace_end = _actor._attack_contact_point()
	var player_contact: Vector3 = _actor.player.global_position + Vector3(0.0, 1.0, 0.0)
	# A verifier, a scripted boss beat, or a restored save can resolve an
	# attack after the actor has been repositioned without a fresh windup frame.
	# Never reuse a stale trace from the previous location; seed the trace from
	# this enemy's current chest so contact and parry feedback stay local.
	if _actor.attack_trace_start == Vector3.ZERO or _actor.attack_trace_start.distance_to(_actor.global_position) > maxf(_actor.attack_range * 2.5, 3.5):
		_actor.attack_trace_start = _actor.global_position + Vector3(0.0, 0.9, 0.0)
	var sweep_start: Vector3 = _actor.attack_trace_start
	var sweep_end: Vector3 = _actor.attack_trace_end
	_actor.last_attack_contact = Geometry3D.get_closest_point_to_segment(player_contact, sweep_start, sweep_end)
	var boss_attack: Variant = _actor._boss_attack_id()
	var special_radius: Variant = _actor._boss_attack_radius(boss_attack)
	var story_encounter: Variant = _actor.get_node_or_null("StoryEncounterPreparation")
	if story_encounter != null and (story_encounter != null) and story_encounter.blocks_attack(boss_attack):
		_actor.attack_recovery_time = maxf(_actor.attack_recovery_time, 0.9)
		_actor._fit_native_attack_tail()
		_actor.special_attack_resolved.emit(_actor, boss_attack, _actor.attack_trace_end, special_radius, 0.0, false)
		return
	_actor._fit_native_attack_tail()
	var special_contact: Variant = _actor.is_boss and boss_attack != "" and _actor._special_attack_hits_player(boss_attack, special_radius)
	var melee_contact: Variant = player_contact.distance_to(_actor.last_attack_contact) <= _actor.contact_radius and _actor._has_attack_line()
	if not melee_contact and not special_contact:
		if _actor.is_boss and boss_attack != "":
			# A missed boss action is still an authored beat. The release VFX and
			# audio must communicate the dodge instead of disappearing silently.
			_actor.special_attack_resolved.emit(_actor, boss_attack, _actor.attack_trace_end, special_radius, 0.0, false)
		return
	var applied_damage: float = _actor.damage * (0.72 if special_contact and not melee_contact else 1.0)
	var parried: bool = bool(_actor.player.take_damage(applied_damage))
	var contact_position: Variant = _actor.last_attack_contact
	_actor.attack_resolved.emit(_actor, parried, contact_position)
	if _actor.is_boss and boss_attack != "":
		_actor.special_attack_resolved.emit(_actor, boss_attack, contact_position, special_radius, applied_damage, parried)
	if parried:
		_actor.parry_exposed_time = 1.15
		_actor.stagger(1.15)
		if _actor.is_boss:
			_actor.write_presentation_tag(_actor, "last_parried", true)
			_actor.parry_window_opened.emit(_actor, 1.15)

func _strike_recovery() -> float:
	if _actor.enemy_id in ["wychwood_brute", "rootbound_colossus", "bell_eater"]:
		return 0.65
	if _actor.enemy_id in ["halvern_boss", "wychwood_stalker"]:
		return 0.34
	return 0.48 if _actor.is_boss else 0.42

func _strike_presentation_ready() -> bool:
	if _actor.animation_driver == null or not _actor.animation_driver.action_active:
		return true
	return int(_actor.CharacterAnimationDriver.ACTION_PRIORITY.get(_actor.animation_driver.current_state, 0)) <= int(_actor.CharacterAnimationDriver.ACTION_PRIORITY.attack)

func _begin_attack() -> bool:
	if not _strike_presentation_ready():
		_actor._release_attack_token()
		return false
	_actor.windup_time = _actor._windup_duration()
	_actor.pending_attack_time = _actor.windup_time
	_actor.attack_windup_total = _actor.windup_time
	if _actor.animation_driver != null and not _actor._start_attack_animation():
		_actor._cancel_pending_strike(false)
		return false
	_actor.attack_cooldown = _actor._attack_cooldown()
	_actor.attack_trace_start = _actor._attack_contact_point()
	_actor.attack_trace_end = _actor.attack_trace_start
	_actor._show_windup_marker()
	_actor.windup_started.emit(_actor)
	return true

func _start_attack_animation() -> bool:
	if not _actor.native_attack_profile.is_empty():
		# EnemyAI still owns the unchanged telegraph/contact clock. Reach the
		# calibrated pose of the complete strike exactly when that clock expires.
		var fraction: Variant = float(_actor.native_attack_profile.contact_fraction)
		# The physics recovery clock can expire between animation timer ticks.
		# Only a completed contact's old tail may yield to this authorized swing;
		# action priority and unfinished telegraphs remain protected.
		if _actor.native_attack_tail_active and _actor.animation_driver.action_active and _actor.animation_driver.current_state == "attack":
			_actor.animation_driver.set_external_tick(true)
			_actor.animation_driver.advance_external(maxf(0.0, _actor.animation_driver.action_duration - _actor.animation_driver.action_elapsed))
		_actor.native_attack_tail_active = false
		_actor.animation_driver.set_external_tick(true)
		if not _actor.animation_driver.trigger_action("attack", 1.0, 0.10, false, _actor.windup_time / fraction, true):
			_actor.animation_driver.set_external_tick(false)
			return false
		return true
	var clip: StringName = _actor.animation_driver.get_clip_for_state("windup")
	# The retained Skeleton clip reaches its strike at 85% of its authored
	# length. Preserve the telegraph clock and leave uncalibrated families alone.
	var duration: float = _actor.windup_time / 0.85 if str(clip) == "SkeletonArmature|Skeleton_Attack" else 0.0
	_actor.animation_driver.set_external_tick(true)
	if not _actor.animation_driver.trigger_action("windup", 1.0, 0.10, false, duration):
		_actor.animation_driver.set_external_tick(false)
		return false
	return true

func _fit_native_attack_tail() -> void:
	if _actor.native_attack_profile.is_empty() or _actor.animation_driver == null or not _actor.animation_driver.action_active or _actor.animation_driver.current_state != "attack":
		return
	_actor.native_attack_tail_active = _actor.animation_driver.fit_action_tail(float(_actor.native_attack_profile.contact_fraction), _actor.attack_recovery_time)

func _cancel_pending_strike(interrupt_animation: bool = true) -> void:
	_actor.native_attack_tail_active = false
	var had_strike: bool = _actor.pending_attack_time > 0.0 or _actor.windup_time > 0.0
	_actor.pending_attack_time = 0.0
	_actor.windup_time = 0.0
	_actor._release_attack_token()
	if _actor.animation_driver != null:
		_actor.animation_driver.set_external_tick(false)
		if interrupt_animation and had_strike and not _actor.dead:
			_actor.animation_driver.stop_action()
	_actor._hide_windup_marker()

func _boss_attack_id() -> String:
	if not _actor.is_boss:
		return ""
	var controller: Variant = _actor.get_node_or_null("BossEncounterController")
	if controller != null and (controller != null):
		var phase_data: Dictionary = controller.phase_definition()
		return str(phase_data.get("telegraph", ""))
	return ""

func interrupt_boss_windup(reason: String = "interrupt") -> bool:
	if not _actor.is_boss or _actor.windup_time <= 0.0:
		return false
	var attack_id: Variant = _actor._boss_attack_id()
	_actor.windup_time = 0.0
	_actor.pending_attack_time = 0.0
	_actor.attack_recovery_time = 0.18
	_actor.stagger(0.90)
	_actor.write_presentation_tag(_actor, "last_boss_interrupt", reason)
	_actor.special_attack_interrupted.emit(_actor, attack_id, reason)
	return true

func _boss_attack_radius(attack_id: String) -> float:
	return {
		"bell_shockwave": 4.8,
		"grave_slam": 3.7,
		"ghoulkin_call": 3.2,
		"root_lanes": 4.0,
		"ground_rupture": 4.1,
		"heart_stagger": 2.9,
		"wing_blast": 4.6,
		"ash_breath": 5.6,
		"swoop": 3.6,
		"parry_test": 2.3,
		"counter_lunge": 2.6,
		"memory_echo": 4.4,
		"antler_sweep": 3.8,
		"road_reopening": 4.0,
	}.get(attack_id, _actor.attack_range + 0.8)

func _special_attack_hits_player(attack_id: String, radius: float) -> bool:
	if _actor.player == null or _actor.player_contact_distance() > radius or not _actor._has_attack_line():
		return false
	var offset: Vector3 = _actor.player.global_position - _actor.global_position
	offset.y = 0.0
	var local: Vector3 = _actor.global_transform.basis.inverse() * offset
	return AttackShape.contains(attack_id, local)

func _windup_duration() -> float:
	var preparation: Node = _actor.get_node_or_null("StoryEncounterPreparation")
	var bonus: float = float(preparation.preparation_windup_bonus()) if preparation != null else 0.0
	return _actor.tactics.windup_duration(_actor.enemy_id, _actor.is_boss, bonus)

func _attack_cooldown() -> float:
	return _actor.tactics.cooldown_duration(_actor.enemy_id, _actor.is_boss, _actor.boss_phase)
