extends SceneTree

const Driver = preload("res://scripts/character_animation_driver.gd")
const Profiles = preload("res://scripts/native_attack_profiles.gd")
const Roles = preload("res://scripts/character_role_spec.gd")

class Defender extends CharacterBody3D:
	var contacts := 0
	var parries := false
	func take_damage(_amount: float) -> bool:
		contacts += 1
		return parries

class EnemyProbe extends "res://scripts/enemy_ai.gd":
	func _has_attack_line() -> bool:
		return true
	func _boss_attack_id() -> String:
		return "fixture_attack" if is_boss else ""
	func _special_attack_hits_player(_id: String, _radius: float) -> bool:
		return false

class GeometryOnlyEnemy extends "res://scripts/enemy_ai.gd":
	func _try_build_mapped_body() -> bool:
		return true

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for fraction in [0.3, 0.5, 0.7]:
		for fps in [20.0, 30.0, 60.0, 144.0]:
			_timing_case(fraction, fps)
	for kind: String in ["stagger", "cancel", "deactivate", "death", "parry", "boss_interrupt"]:
		_interrupt_case(kind)
	for after_contact in [false, true]:
		_reactivated_strike(after_contact)
	for state: String in ["hit", "death"]:
		_dormant_protected_pose(state)
	_repeated_parries()
	for rate in [12.0,30.0]:
		for fps in [20.0,60.0,144.0]:
			for id: String in ["bell_eater","rootbound_colossus","ashwing"]:
				_consecutive_boss_strikes(id, rate, fps)
	_consecutive_boss_strikes("bell_eater", 12.0, 60.0, true)
	_dimensions()
	_selection_policy()
	for failure in failures: push_error(failure)
	print("NATIVE ATTACK TIMING: ", "PASS" if failures.is_empty() else "FAIL", "; full Attack, unchanged contact/recovery clocks, split steps, interruption ownership, ten finite cylinder dimensions and deterministic calibration policy")
	quit(0 if failures.is_empty() else 1)

func _rig(fraction: float) -> Dictionary:
	var actor := EnemyProbe.new()
	actor.enemy_id = "ghoulkin"
	actor.set_physics_process(false)
	actor.attack_cooldown = 7.0
	actor.contact_radius = 0.12
	root.add_child(actor)
	var defender := Defender.new()
	root.add_child(defender)
	defender.position = Vector3(0, 0, -2.0 * fraction)
	actor.player = defender
	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	skeleton.add_bone("hand_r")
	skeleton.set_bone_rest(0, Transform3D(Basis.IDENTITY, Vector3.UP))
	actor.add_child(skeleton)
	var player := AnimationPlayer.new()
	actor.add_child(player)
	var library := AnimationLibrary.new()
	for clip_name: String in ["Idle", "Attack", "Windup", "HitReact", "Death"]:
		var animation := Animation.new()
		animation.length = 2.0 if clip_name == "Attack" else 1.0
		var track := animation.add_track(Animation.TYPE_POSITION_3D)
		animation.track_set_path(track, NodePath("Skeleton3D:hand_r"))
		animation.position_track_insert_key(track, 0.0, Vector3.UP)
		animation.position_track_insert_key(track, animation.length, Vector3(0,1,-2) if clip_name == "Attack" else Vector3.UP)
		library.add_animation(clip_name, animation)
	player.add_animation_library("", library)
	var driver := Driver.new()
	actor.add_child(driver)
	_check(driver.configure(actor, {"idle":"Idle", "windup":"Windup", "attack":"Attack", "hit":"HitReact", "death":"Death"}), "fixture requires a bound animation graph")
	driver.set_update_rate_hz(12.0)
	actor.animation_driver = driver
	actor.native_attack_profile = {"contact_fraction":fraction}
	actor._configure_attack_contact_bone()
	var actions: Array[String] = []
	var finished: Array[String] = []
	driver.action_started.connect(func(action): actions.append(action))
	driver.action_finished.connect(func(action): finished.append(action))
	return {"actor":actor,"defender":defender,"driver":driver,"skeleton":skeleton,"actions":actions,"finished":finished}

func _begin(context: Dictionary) -> void:
	context.actor.windup_time = 0.46
	context.actor.pending_attack_time = 0.46
	context.actor.attack_windup_total = 0.46
	context.actor._start_attack_animation()
	context.actor.attack_trace_start = context.actor._attack_contact_point()

func _timing_case(fraction: float, fps: float) -> void:
	var context := _rig(fraction)
	_begin(context)
	var actor = context.actor
	var driver = context.driver
	var elapsed := 0.0
	var delta := 1.0 / fps
	while elapsed + delta < 0.46:
		actor._tick_pending_attack(delta)
		elapsed += delta
	_check(context.defender.contacts == 0, "native strike must not damage before the existing windup expires")
	# Deliberately cross the contact boundary; only the remaining windup may be
	# advanced, and one contact must be delivered regardless of polling cadence.
	actor._tick_pending_attack(0.46 - elapsed + 0.013)
	_check(context.actions == ["attack"] and context.defender.contacts == 1, "native contact must play full Attack and apply damage exactly once")
	_check(driver.current_state == "attack" and not driver.externally_ticked, "contact must continue the same Attack under the recovered animation clock")
	_check(driver.is_evaluation_scheduled(), "contact must return the same strike to its scheduled 12 Hz animation owner")
	_check(absf(context.skeleton.get_bone_pose_position(0).z + 2.0 * fraction) < 0.015, "contact pose must match the calibrated authored fraction")
	_check(is_equal_approx(driver.action_elapsed, 0.46) and is_equal_approx(driver.action_duration, 0.88), "contact and recovery durations must remain 0.46 + 0.42 seconds")
	_check(is_equal_approx(driver.current_playback_scale, 2.0 * (1.0 - fraction) / 0.42) and is_equal_approx(driver.current_playback_scale, driver.target_playback_scale), "tail rate must change immediately, without smoothing")
	_check(is_equal_approx(actor.attack_cooldown, 7.0) and is_equal_approx(actor.attack_recovery_time, 0.42), "animation timing must not alter gameplay cooldown/recovery")
	actor._tick_pending_attack(delta)
	_check(context.defender.contacts == 1, "a completed pending strike must not emit a second contact")
	driver.set_external_tick(true)
	driver.advance_external(0.419)
	_check(driver.current_state == "attack", "the strike tail must remain active until recovery ends")
	driver.advance_external(0.00101)
	_check(driver.current_state == "idle" and not driver.action_active, "the full strike must finish at the existing recovery boundary")
	_check(context.finished.count("attack") == 1, "a completed strike must emit exactly one action_finished")
	_dispose(context)

func _interrupt_case(kind: String) -> void:
	var context := _rig(0.5)
	_begin(context)
	var actor = context.actor
	var driver = context.driver
	match kind:
		"stagger": actor.stagger(0.7)
		"cancel": actor._cancel_pending_strike()
		"deactivate": actor.set_encounter_active(false)
		"death": actor._on_died()
		"boss_interrupt":
			actor.is_boss = true
			_check(actor.interrupt_boss_windup("fixture"), "boss interrupt must retain the existing interrupt contract")
			_check(is_equal_approx(actor.attack_recovery_time, 0.18) and is_equal_approx(actor.stagger_time, 0.9), "boss interrupt balance must remain unchanged")
		"parry":
			context.defender.parries = true
			actor._tick_pending_attack(0.46)
			_check(context.defender.contacts == 1 and is_equal_approx(actor.stagger_time, 1.15), "parry must still occur once at real contact and retain its stagger")
	_check(not driver.externally_ticked, "every interruption must release external attack clock ownership: " + kind)
	_check(not driver.fit_action_tail(0.5, 0.42) if kind in ["cancel", "deactivate", "death"] else true, "cancelled/dead actions must not acquire a strike tail")
	_check(actor.pending_attack_time == 0.0, "interruption must clear the pending contact: " + kind)
	actor._tick_pending_attack(1.0)
	_check(context.defender.contacts == (1 if kind == "parry" else 0), "interrupted windups must not deliver stale damage: " + kind)
	_dispose(context)

func _reactivated_strike(after_contact: bool) -> void:
	var context := _rig(0.5)
	var actor = context.actor
	var driver = context.driver
	_begin(context)
	actor._tick_pending_attack(0.46 if after_contact else 0.23)
	if after_contact:
		actor.windup_time = 0.0
		_check(actor.native_attack_tail_active and actor.pending_attack_time == 0.0, "tail suspension must exercise a contacted strike without a pending windup")
	var contacts_before := int(context.defender.contacts)
	var recovery_before := float(actor.attack_recovery_time)
	actor.set_encounter_active(false)
	_check(not driver.action_active and driver.current_state == "idle" and is_zero_approx(driver.action_elapsed), "deactivation must cancel the displayed strike, including a post-contact tail")
	_check(not actor.native_attack_tail_active and not driver.externally_ticked and actor.pending_attack_time == 0.0 and actor.windup_time == 0.0, "deactivation must relinquish both presentation and AI strike ownership")
	_check(is_equal_approx(actor.attack_cooldown, 7.0) and is_equal_approx(actor.attack_recovery_time, recovery_before), "cancelling presentation must preserve cooldown and recovery balance")
	actor.set_encounter_active(false)
	actor.set_encounter_active(true)
	actor.set_physics_process(false)
	_check(not driver.action_active and not driver.distance_suspended and driver.current_state == "idle", "reactivation must not resume the cancelled strike")
	_check(context.finished.is_empty(), "cancellation must not falsely report a completed attack")
	_begin(context)
	_check(context.actions.count("attack") == 2 and driver.externally_ticked and is_zero_approx(driver.action_elapsed), "reactivation must accept a fresh strike at phase zero")
	actor._tick_pending_attack(0.459)
	_check(context.defender.contacts == contacts_before, "fresh attack must retain its full windup after reactivation")
	actor._tick_pending_attack(0.00101)
	_check(context.defender.contacts == contacts_before + 1 and absf(context.skeleton.get_bone_pose_position(0).z + 1.0) < 0.015, "reactivated strike must deliver one contact at the calibrated visible pose")
	_dispose(context)

func _dormant_protected_pose(state: String) -> void:
	var context := _rig(0.5)
	if state == "death":
		context.actor._on_died()
	else:
		context.driver.trigger_action(state)
	context.actor.set_encounter_active(false)
	_check(context.driver.current_state == state and context.driver.action_active, "encounter strike cancellation must preserve a protected non-strike pose: " + state)
	context.actor.set_encounter_active(true)
	context.actor.set_physics_process(false)
	_check(context.driver.current_state == state and context.driver.action_active and (context.driver.dead if state == "death" else not context.driver.dead), "reactivation must preserve terminal and non-strike action ownership: " + state)
	_dispose(context)

func _dimensions() -> void:
	for id: String in ["silt_maw","millback","glassmoth","knell_leech","hearthscale","gallows_weaver","reed_choir","inkblind","cairn_mother","shroud_swimmer","ghoulkin"]:
		var actor := GeometryOnlyEnemy.new()
		actor.enemy_id = id
		actor._build_body(Color.WHITE)
		var collision := actor.get_child(0) as CollisionShape3D
		var role := Roles.for_role(id)
		var height := float(role.collision_height)
		var radius := float(role.collision_radius)
		_check(collision.shape is CylinderShape3D if id != "ghoulkin" else collision.shape is CapsuleShape3D, "role must use a supported collision shape: " + id)
		_check(is_equal_approx(collision.shape.height, height) and is_equal_approx(collision.shape.radius, radius), "collision height/radius must not be silently coerced: " + id)
		_check(is_equal_approx(collision.position.y, height * 0.5 + radius * 0.18), "existing authored floor clearance must remain unchanged: " + id)
		actor.free()

func _repeated_parries() -> void:
	var context := _rig(0.5)
	context.defender.parries = true
	for fps in [20.0,30.0,60.0,144.0]:
		context.driver.stop_action("idle", 0.0)
		context.actor.stagger_time = 0.0
		_begin(context)
		var before := int(context.defender.contacts)
		for frame in range(int(ceil(0.46 * fps))):
			context.actor._tick_pending_attack(1.0 / fps)
		_check(context.defender.contacts == before + 1 and is_equal_approx(context.actor.stagger_time, 1.15), "parry/queued idle/restart must retain real contact at every cadence")
		_check(context.driver.animation_graph.active_state == context.driver.animation_graph.requested, "queued action restarts must retain the current graph rate owner")
	_dispose(context)

func _consecutive_boss_strikes(id: String, rate: float, fps: float, missed: bool = false) -> void:
	var context := _rig(0.5)
	var actor = context.actor
	var driver = context.driver
	actor.enemy_id = id
	actor.is_boss = true
	actor.boss_phase = 3
	driver.set_update_rate_hz(rate)
	actor.attack_cooldown = 0.0
	if missed: context.defender.position = Vector3(4,0,-1)
	var tail_elapsed := 0.0
	var starts := 0
	var unfinished_tails := 0
	var delta := 1.0 / fps
	# Exercise the real production timer callback at its scheduled cadence,
	# independently of the physics decision clock. No tail is advanced to R by
	# hand; eligible physics decisions deliberately occur before that frame's
	# animation tick, as they can in a throttled browser.
	for frame in range(int(ceil(fps * 7.0))):
		actor.attack_cooldown = maxf(0.0, actor.attack_cooldown - delta)
		actor.attack_recovery_time = maxf(0.0, actor.attack_recovery_time - delta)
		var contacted := false
		if actor.pending_attack_time > 0.0:
			actor.windup_time = maxf(0.0, actor.windup_time - delta)
			actor._tick_pending_attack(delta)
			contacted = actor.pending_attack_time == 0.0
		elif actor.attack_cooldown <= 0.0 and actor.attack_recovery_time <= 0.0 and starts < 4:
			if actor.native_attack_tail_active and driver.action_active and driver.current_state == "attack": unfinished_tails += 1
			actor.windup_time = actor._windup_duration()
			actor.pending_attack_time = actor.windup_time
			actor.attack_windup_total = actor.windup_time
			actor.attack_cooldown = actor._attack_cooldown()
			actor._start_attack_animation()
			actor.attack_trace_start = actor._attack_contact_point()
			_check(context.finished.count("attack") == starts, "every prior post-contact tail must finish exactly once before the new authorized strike: " + id)
			starts += 1
			_check(driver.externally_ticked and driver.current_state == "attack", "authorized boss swing must acquire a fresh strike even while the previous timer tail is unfinished: " + id)
		if contacted:
			tail_elapsed = 0.0
		elif not driver.externally_ticked:
			tail_elapsed += delta
			while tail_elapsed + 0.00000001 >= 1.0 / rate:
				driver._on_manual_tick()
				tail_elapsed -= 1.0 / rate
		if starts == 4 and ((not missed and context.defender.contacts == 4) or (missed and context.finished.count("attack") == 4)): break
	_check(starts == 4 and context.defender.contacts == (0 if missed else 4) and context.actions.count("attack") == 4, "consecutive phase-3 boss decisions must retain one animated strike/contact per decision: " + id)
	if missed: _check(context.finished.count("attack") == 4, "all missed strikes must complete their full tails exactly once")
	if rate == 12.0 and fps == 60.0:
		_check(unfinished_tails > 0, "12 Hz/60 Hz fixture must exercise an unfinished tail at the next authorized strike: " + id)
	_dispose(context)

func _selection_policy() -> void:
	var samples: Array[Dictionary] = [{"seconds":0.56,"point":Vector3(0.4,1,-1.2)},{"seconds":0.60,"point":Vector3(0.2,1,-1.2)},{"seconds":0.80,"point":Vector3(0.2,1,-1.2)}]
	var chosen := Profiles.choose_fraction("M01", 2.0, samples)
	_check(is_equal_approx(chosen.contact_fraction, 0.3), "sampling ties must choose the earliest minimum deterministically")
	samples = [{"seconds":0.56,"point":Vector3.UP},{"seconds":1.4,"point":Vector3.UP}]
	chosen = Profiles.choose_fraction("M01", 2.0, samples)
	_check(chosen.contact_fraction == 0.7 and chosen.requires_visual_acceptance and chosen.method == "declared_recovery_boundary_fallback", "static probes must use the labelled .7 fallback")
	chosen = Profiles.choose_fraction("M06", 2.0, samples)
	_check(chosen.contact_fraction == 0.5 and chosen.method == "authored_procedural_apex", "procedural sources must retain the authored .5 apex")
	_check(Profiles.choose_fraction("M01", 0.0, samples).is_empty(), "invalid clip duration must reject calibration")
	for id: String in ["M01", "M02"]:
		var window := Vector2(0.28, 0.7) if id == "M01" else Vector2(0, 1)
		for minimum_at_end in [false, true]:
			samples = []
			for index in 3:
				var fraction := lerpf(window.x, window.y, float(index) / 2.0)
				var distance := float(2 - index if minimum_at_end else index) * 0.1
				samples.append({"seconds":fraction * 2.0, "point":Vector3(distance, 1, -1.2)})
			chosen = Profiles.choose_fraction(id, 2.0, samples)
			_check(chosen.method == "declared_recovery_boundary_fallback" and chosen.fallback_reason == "endpoint_minimum", "search-window endpoints must never be labelled measured: " + id)
	var source := "res://assets_external/design_pack_v1/creatures/fixture.glb"
	var digest := "a".repeat(64)
	Profiles._loaded = true
	Profiles._hashes = {source:digest}
	Profiles._profiles = {source:{"clip":"Attack", "source_sha256":digest, "duration_seconds":2.0, "contact_fraction":0.5}}
	_check(not Profiles.for_source(source, "Attack", 2.0).is_empty(), "runtime timing must accept an exact ledger/clip binding")
	_check(Profiles.for_source(source, "Attack", 2.1).is_empty() and Profiles.for_source(source, "AttackHeavy", 2.0).is_empty(), "runtime timing must reject stale duration/clip bindings")
	Profiles._hashes[source] = "b".repeat(64)
	_check(Profiles.for_source(source, "Attack", 2.0).is_empty(), "runtime timing must reject a stale source hash")
	Profiles._loaded = false
	Profiles._profiles.clear()
	Profiles._hashes.clear()

func _dispose(context: Dictionary) -> void:
	context.actor.free()
	context.defender.free()

func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
