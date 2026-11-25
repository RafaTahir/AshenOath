extends SceneTree

## Focused headless mechanics fixture. No level, renderer capture or save data.
const Shape = preload("res://scripts/models/enemy_attack_shape_model.gd")
const Feedback = preload("res://scripts/combat_feedback.gd")

class EnemyProbe extends "res://scripts/enemy_ai.gd":
	var line_clear := true
	func _has_attack_line() -> bool:
		return line_clear

class HealthStub extends RefCounted:
	var health := 100.0
	var max_health := 100.0
	func damage(amount: float) -> void:
		health -= amount

class DriverStub extends RefCounted:
	var accepted := true
	var external_tick := true
	var stopped := 0
	var action_active := true
	var current_state := "attack"
	func trigger_action(action: String, _scale: float = 1.0, _blend: float = 0.1, _force: bool = false, _duration: float = 0.0, _reset: bool = false) -> bool:
		if accepted: current_state = action
		return accepted
	func set_external_tick(value: bool) -> void:
		external_tick = value
	func stop_action() -> void:
		stopped += 1
		current_state = "idle"
	func is_valid() -> bool:
		return false

class NavigationStub extends RefCounted:
	var blocked := true
	var validations := 0
	func build_route(start: Vector3, finish: Vector3, _clearance: float, _ignore_body: CollisionObject3D = null) -> Array[Vector3]:
		var route: Array[Vector3] = [start, finish]
		return route
	func validate_segment(_start: Vector3, _finish: Vector3, _clearance: float) -> bool:
		validations += 1
		return not blocked

class BossStub extends Node:
	func phase_definition() -> Dictionary:
		return {"telegraph": "root_lanes"}

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func _check_locomotion(world: Node3D, definitions: Dictionary) -> void:
	var target := Node3D.new()
	world.add_child(target)
	for identity: String in definitions:
		var definition: Dictionary = definitions[identity]
		var profile: Dictionary = definition.get("locomotion", {})
		_check(not profile.is_empty(), identity + " has an authored stride")
		if profile.is_empty(): continue
		var actor := EnemyProbe.new(false)
		world.add_child(actor)
		actor.setup(identity, definition, target)
		actor.set_physics_process(false)
		var nav: RefCounted = actor.enemy_navigation_view
		var service := NavigationStub.new()
		service.blocked = false
		actor.spatial_service = service
		actor.navigation_agent = NavigationAgent3D.new()
		actor.add_child(actor.navigation_agent)
		actor.can_see_player = true
		actor.approach_angle_degrees = 0.0
		target.position = Vector3.FORWARD * 9.0
		var dt := 1.0 / 30.0
		nav.step_pursuit(target.position, 9.0, dt)
		_check(is_equal_approx(actor.velocity.length(), float(profile.acceleration) * dt), identity + " uses first-step acceleration")
		_check(not nav.turn_towards(Vector3.BACK, dt) and is_equal_approx(absf(actor.rotation.y), deg_to_rad(float(profile.turn_degrees)) * dt), identity + " cannot pivot instantly to strike")
		actor.rotation.y = 0.0
		service.blocked = true
		nav.step_pursuit(target.position, 9.0, dt)
		_check(actor.velocity == Vector3.ZERO, identity + " cannot carry momentum into a blocked route")
		service.blocked = false
		if profile.has("burst"):
			var burst: Dictionary = profile.burst
			var distance := float(burst.range) - 0.15
			target.position = Vector3.FORWARD * distance
			actor.last_known_player_position = target.position
			actor.can_see_player = false
			nav.step_pursuit(target.position, distance, dt)
			_check(nav._gather_left == 0.0 and nav._surge_left == 0.0, identity + " never bursts on a remembered position")
			actor.can_see_player = true
			nav.step_pursuit(target.position, distance, dt)
			_check(nav._gather_left > 0.0 and nav._surge_left == 0.0, identity + " gathers before a burst")
			for _tick: int in ceili(float(burst.gather) / dt) + 1:
				nav.step_pursuit(target.position, distance, dt)
			_check(nav._surge_left > 0.0, identity + " launches after the gather")
			var heading: Vector3 = nav._surge_heading
			target.position.x += 1.25
			var peer := EnemyProbe.new(false)
			world.add_child(peer)
			peer.position = Vector3.LEFT * 0.9
			peer.set_physics_process(false)
			actor.encounter_peers = [peer]
			var checked_final_step := false
			var peak := 0.0
			for _tick: int in ceili(float(burst.duration) / dt) + 2:
				var remaining: float = nav._surge_left
				nav.step_pursuit(target.position, distance, dt)
				peak = maxf(peak, actor.velocity.length())
				if remaining > 0.000001:
					var before_spacing := actor.velocity
					nav._apply_peer_spacing(dt * 0.5)
					nav._apply_peer_spacing(dt * 0.5)
					_check(actor.velocity.is_equal_approx(before_spacing) and actor.velocity.normalized().dot(heading) > 0.98, identity + " keeps its launch line past a nearby peer")
					if nav._surge_left <= 0.000001:
						checked_final_step = true
			_check(checked_final_step, identity + " keeps commitment through the final fractional decision")
			actor.encounter_peers = []
			peer.free()
			_check(peak > actor.move_speed * float(profile.pace) * 1.08, identity + " achieves a distinct burst speed")
			_check(not nav._burst_armed and nav._surge_left == 0.0 and nav._gather_left == 0.0, identity + " cannot cycle bursts at a stationary target")
			nav.reset_stride()
			actor.slowed_time = 1.0
			nav.step_pursuit(target.position, distance, dt)
			_check(nav._gather_left == 0.0 and nav._surge_left == 0.0, identity + " slow prevents a fresh burst")
			actor.slowed_time = 0.0
			target.position.x = 0.0
			nav.step_pursuit(target.position, distance, dt)
			actor.set_encounter_active(false)
			_check(actor.velocity == Vector3.ZERO and nav._surge_left == 0.0 and nav._gather_left == 0.0, identity + " suspension clears momentum and commitment")
		actor.free()
	target.free()

func _check_planted_armour(world: Node3D, definitions: Dictionary) -> void:
	for identity: String in ["gravebound_knight", "rootbound_colossus", "ghoulkin"]:
		for impact: String in ["early cut", "planted cut", "heavy", "coated", "recovery"]:
			var actor := EnemyProbe.new(false)
			world.add_child(actor)
			actor.set_physics_process(false)
			actor.enemy_id = identity
			actor.health_component = HealthStub.new()
			actor.animation_driver = DriverStub.new()
			var profile: Dictionary = definitions[identity].strike
			actor.enemy_strike_view._strike = profile
			actor.attack_windup_total = float(profile.windup)
			actor.pending_attack_time = actor.attack_windup_total if impact == "early cut" else 0.1
			if impact == "recovery": actor.pending_attack_time = 0.0
			actor.apply_damage(6.0, "undead" if impact == "coated" else "", impact != "heavy")
			var should_hold := impact == "planted cut" and identity != "ghoulkin"
			_check(actor.health_component.health < 100.0, identity + " takes damage from " + impact)
			_check((actor.animation_driver.current_state == "attack") == should_hold, identity + " reaction to " + impact)
			_check((actor.pending_attack_time > 0.0) == should_hold, identity + " swing ownership after " + impact)
			actor.free()

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var player := Node3D.new()
	world.add_child(player)
	var enemy = EnemyProbe.new()
	world.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.player = player
	enemy.position = Vector3(0, 0, 6)
	var gate := {"claims": 0, "releases": 0}
	enemy.attack_gate = func(_actor, claim: bool) -> bool:
		gate["claims" if claim else "releases"] += 1
		return true
	var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	_check_locomotion(world, definitions)
	_check_planted_armour(world, definitions)
	enemy.health_component = HealthStub.new()
	enemy.perception_memory_time = 1.0
	for identity: String in definitions:
		var definition: Dictionary = definitions[identity]
		enemy.attack_range = float(definition.get("attack_range", 1.5))
		enemy.preferred_distance = float(definition.get("preferred_distance", 2.15))
		enemy.approach_angle_degrees = float(definition.get("approach_angle", 0))
		enemy.can_see_player = true
		enemy.attack_recovery_time = 0.0
		enemy.attack_cooldown = 0.0
		_check(enemy._engagement_target().distance_to(player.global_position) < enemy.attack_range, identity + " ready closes in reach")
		enemy.attack_cooldown = 0.5
		_check(is_equal_approx(enemy._engagement_target().distance_to(player.global_position), enemy.preferred_distance), identity + " cooldown retains standoff")
		enemy.attack_cooldown = 0.0
		enemy.can_see_player = false
		_check(is_equal_approx(enemy._engagement_target().distance_to(player.global_position), enemy.preferred_distance), identity + " searching retains spacing")
		# Navigation and the attack decision must use the same ready ring. A
		# native hand can still miss when a strike starts at the outer stat range.
		enemy.position = Vector3(0, 0, enemy.attack_range * 0.93)
		enemy.can_see_player = true
		_check(enemy.enemy_navigation_view.choose_tactical_mode() == "pursue", identity + " outer reach approaches before windup")
		enemy.attack_cooldown = 0.5
		_check(enemy.enemy_navigation_view.choose_tactical_mode() == "attack", identity + " cooldown retains waiting gate")
		enemy.attack_cooldown = 0.0
		_check(enemy.enemy_navigation_view.choose_tactical_mode() == "pursue", identity + " expired cooldown restores close approach")
		enemy.position.z = enemy.attack_range * 0.84
		_check(enemy.enemy_navigation_view.choose_tactical_mode() == "attack", identity + " close ready actor can wind up")
		enemy.pending_attack_time = 0.2
		_check(enemy.enemy_navigation_view.choose_tactical_mode() == "windup", identity + " pending strike keeps decision priority")
		enemy.pending_attack_time = 0.0
	enemy.position = Vector3(0, 0, 6)
	_check(gate.claims == 0 and gate.releases == 0, "approaching never reserves an attack token")
	var navigation := NavigationStub.new()
	enemy.spatial_service = navigation
	enemy.navigation_agent = NavigationAgent3D.new()
	enemy.add_child(enemy.navigation_agent)
	enemy.approach_angle_degrees = 0.0
	enemy.can_see_player = true
	enemy.attack_cooldown = 0.0
	for identity: String in definitions:
		enemy.attack_range = float(definitions[identity].get("attack_range", 1.5))
		enemy.preferred_distance = float(definitions[identity].get("preferred_distance", 2.15))
		enemy.position = Vector3(0, 0, enemy.attack_range * 0.85 + 0.01)
		var target: Vector3 = enemy._engagement_target()
		_check(enemy.enemy_navigation_view.choose_tactical_mode() == "pursue", identity + " just outside commit ring keeps approaching")
		_check(enemy._navigation_direction(target, true).length_squared() > 0.0, identity + " final route tolerance cannot stop outside commit ring")
		enemy.position.z = enemy.attack_range * 0.85 - 0.01
		_check(enemy.enemy_navigation_view.choose_tactical_mode() == "attack", identity + " inside commit ring can stop and strike")
	enemy.position = Vector3(0, 0, 6)
	_check(enemy._validated_step_direction(Vector3.FORWARD, Vector3(0, 0, -3), 0.1) == Vector3.ZERO, "blocked direct and rerouted steps remain blocked")
	_check(navigation.validations == 2, "obstruction is checked for direct and rerouted steps")
	navigation.blocked = false
	_check(enemy._validated_step_direction(Vector3.FORWARD, Vector3(0, 0, -3), 0.1) == Vector3.FORWARD, "clear navigation remains usable")

	for boss in [false, true]:
		var driver := DriverStub.new()
		enemy.animation_driver = driver
		enemy.enemy_id = "rootbound_colossus" if boss else "wychwood_stalker"
		enemy.is_boss = boss
		enemy.health_component = HealthStub.new()
		enemy.weakness = "oathfire" if boss else "iron_trap"
		enemy.pending_attack_time = 0.4
		enemy.windup_time = 0.4
		enemy.stagger_time = 0.0
		enemy.owns_attack_token = true
		enemy.native_attack_tail_active = true
		enemy.apply_damage(9.0)
		_check(is_equal_approx(enemy.health_component.health, 91.0), "reaction preserves incoming damage")
		_check(enemy.pending_attack_time == 0.0 and enemy.windup_time == 0.0, "accepted hit cancels old strike clocks")
		_check(not enemy.owns_attack_token and not driver.external_tick, "accepted hit releases token and external clock")
		_check(not enemy.native_attack_tail_active and driver.current_state == "hit" and driver.stopped == 0, "new HitReact remains active")
		_check(is_equal_approx(enemy.stagger_time, 0.16), "ordinary reaction retains existing stagger duration")
	var rejected := DriverStub.new()
	rejected.accepted = false
	enemy.animation_driver = rejected
	enemy.pending_attack_time = 0.4
	enemy.windup_time = 0.4
	enemy.owns_attack_token = true
	enemy.apply_damage(1.0)
	_check(enemy.pending_attack_time == 0.4 and enemy.owns_attack_token, "rejected reaction does not cancel an unchanged visible action")
	enemy.interrupt_boss_windup("fixture")
	_check(enemy.pending_attack_time == 0.0 and enemy.stagger_time >= 0.9, "explicit boss interruption retains its existing stagger")
	var denied := DriverStub.new()
	denied.current_state = "hit"
	enemy.animation_driver = denied
	enemy.attack_cooldown = 0.0
	enemy.owns_attack_token = true
	_check(not enemy._begin_attack() and enemy.pending_attack_time == 0.0 and not enemy.owns_attack_token, "higher-priority hit cannot arm another strike")
	_check(enemy.attack_cooldown == 0.0 and denied.current_state == "hit", "denied start preserves reaction and does not consume cooldown")
	denied.current_state = "idle"
	denied.accepted = false
	enemy.native_attack_profile = {"contact_fraction": 0.5}
	enemy.owns_attack_token = true
	_check(not enemy._begin_attack() and enemy.pending_attack_time == 0.0 and enemy.windup_time == 0.0 and not enemy.owns_attack_token, "rejected animation cannot arm damage or retain token")
	_check(enemy.attack_cooldown == 0.0 and not denied.external_tick, "rejected start preserves cooldown and relinquishes external clock")
	denied.accepted = true
	denied.current_state = "idle"
	_check(enemy._begin_attack(), "accepted animation arms a real strike")
	_check(is_equal_approx(enemy.pending_attack_time, 0.92) and is_equal_approx(enemy.attack_cooldown, 2.10), "accepted boss start retains authoritative windup and cooldown")
	enemy._cancel_pending_strike(false)
	enemy.animation_driver = null

	for attack in ["wing_blast", "ash_breath", "swoop", "counter_lunge"]:
		var threshold := 0.32 if attack == "wing_blast" else (0.809 if attack == "counter_lunge" else 0.48)
		for dot in [threshold - 0.01, threshold + 0.01]:
			var offset := Vector3(sqrt(1.0 - dot * dot), 0, -dot) * 3.0
			_check(Shape.contains(attack, offset) == (dot >= threshold), attack + " retains angular boundary")
		_check(not Shape.contains(attack, Vector3.BACK * 3), attack + " excludes rear")
	for x in [0.0, 0.61, 0.63, 1.4, 1.71, 1.73, 2.35, 2.96, 2.98, 3.8]:
		var lane := fmod(absf(x), 2.35)
		var expected := lane < 0.62 or lane > 1.72
		_check(Shape.contains("root_lanes", Vector3(x, 0, -1)) == expected, "positive root-lane boundary " + str(x))
		_check(Shape.contains("root_lanes", Vector3(-x, 0, -1)) == expected, "negative root-lane boundary " + str(x))
	var intervals := Shape.lane_intervals(4.0)
	_check(intervals.size() == 3 and intervals[0].is_equal_approx(Vector2(-0.62, 0.62)) and intervals[1].is_equal_approx(Vector2(1.72, 2.97)) and intervals[2].is_equal_approx(Vector2(-2.97, -1.72)), "rendered root bands preserve exact hit intervals")
	for attack in ["root_lanes", "wing_blast", "ash_breath", "bell_shockwave", "antler_sweep"]:
		var triangles := Shape.footprint_triangles(attack, 4.0)
		_check(not triangles.is_empty() and triangles.size() % 3 == 0, attack + " produces triangles")
		for index in range(0, triangles.size(), 3):
			var center := (triangles[index] + triangles[index + 1] + triangles[index + 2]) / 3.0
			_check(center.length() <= 4.00001 and Shape.contains(attack, center), attack + " visible triangle belongs to damage footprint")
			for vertex in [triangles[index], triangles[index + 1], triangles[index + 2]]:
				_check(vertex.length() <= 4.00001 and vertex.y == 0.0, attack + " footprint stays flat and within range")
	_check(Shape.footprint_triangles("root_lanes", -1.0).is_empty(), "invalid radius has no presentation geometry")
	for yaw in [0.0, 0.73, -1.41]:
		enemy.rotation.y = yaw
		for local in [Vector3(0, 0, -3), Vector3(3, 0, 0), Vector3(0, 0, 3), Vector3(1.4, 0, -1)]:
			player.global_position = enemy.global_position + enemy.global_basis * local
			for attack in ["root_lanes", "wing_blast", "ash_breath", "antler_sweep"]:
				_check(enemy._special_attack_hits_player(attack, 4.0) == Shape.contains(attack, local), attack + " authoritative rotated query matches shared shape")
		enemy.line_clear = false
		player.global_position = enemy.global_position - enemy.global_basis.z * 2.0
		_check(not enemy._special_attack_hits_player("wing_blast", 4.0), "attack obstruction still blocks the footprint")
		enemy.line_clear = true
		player.global_position = enemy.global_position - enemy.global_basis.z * 4.1
		_check(not enemy._special_attack_hits_player("wing_blast", 4.0), "authoritative range remains unchanged")

	var controller := BossStub.new()
	controller.name = "BossEncounterController"
	enemy.add_child(controller)
	enemy.is_boss = true
	enemy.pending_attack_time = 0.92
	enemy.windup_time = 0.92
	enemy.rotation.y = 0.73
	enemy._show_windup_marker()
	_check(enemy.windup_marker.visible and enemy.windup_marker.position.is_equal_approx(Vector3(0, 0.055, 0)), "boss warning uses actor origin")
	_check(enemy.windup_marker.mesh.resource_name == "attack_footprint:root_lanes:4.000000", "boss warning uses current phase and authoritative radius")
	_check(enemy.windup_marker.get_parent() == enemy, "windup warning follows actor commitment without another timer")
	enemy._cancel_pending_strike()
	_check(not enemy.windup_marker.visible, "cancelled strike immediately hides footprint")
	var warning_mesh: Mesh = enemy.windup_marker.mesh
	for reduced in [false, true]:
		Feedback.reduce_flashes = reduced
		Feedback.configure_boss_warning(enemy.windup_marker, "root_lanes", 4.0)
		_check(enemy.windup_marker.mesh == warning_mesh, "flash setting retains exact shared footprint")
		_check(enemy.windup_marker.material_override.emission_enabled == (not reduced), "reduced flashes disables warning emission")
		Feedback.boss_attack_release(world, enemy.global_position, -enemy.global_basis.z, "root_lanes", 4.0, false)
		var released: Node3D = world.get_children().back()
		_check(released.global_position.is_equal_approx(enemy.global_position + Vector3(0, 0.06, 0)), "release centre remains on actor")
		_check((-released.global_basis.z).is_equal_approx(-enemy.global_basis.z), "release direction matches hit query")
		_check(released.get_node("AttackFootprint").mesh == warning_mesh, "warning and release share exact cached geometry")
		released.free()
	Feedback.reduce_flashes = false
	Feedback.clear_runtime_caches()
	world.free()
	print(JSON.stringify({"fixture": "monster_mechanics_contract", "checks": checks, "passed": failures.is_empty(), "failures": failures, "gameplay": false, "render_capture": false, "save_data": false}))
	quit(0 if failures.is_empty() else 1)
