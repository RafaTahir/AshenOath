extends SceneTree
## Fixed-tick routine regressions with real Node3D translation and tiny fixtures.
## No scene/asset loads, save writes, physics scans, or story progression.

const Life = preload("res://scripts/greyfen_life_controller.gd")

class ErrorLog extends Logger:
	var errors: Array[String] = []
	func _log_error(_function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != Logger.ERROR_TYPE_WARNING:
			errors.append("%s:%d %s %s" % [file, line, code, rationale])

class Driver extends Node:
	var actor: Node3D
	var activity := ""
	var station: Dictionary = {}
	var velocity := Vector3.ZERO
	func get_visible_forward() -> Vector3: return -actor.global_basis.z
	func set_working(_active: bool) -> void: clear_life_activity()
	func set_dialogue_pose(_active: bool) -> void: pass
	func set_locomotion(_speed: float, _direction: Vector3, _grounded: bool) -> void: pass
	func set_locomotion_motion(value: Vector3, _grounded: bool) -> void: velocity = value
	func set_life_activity(value: String) -> void: activity = value
	func clear_life_activity() -> void:
		activity = ""
		station = {}
	func set_life_workstation(value: Dictionary) -> void: station = value.duplicate()
	func set_carried_activity(_value: String) -> void: pass

class Hud extends Node:
	func ambient_subtitle_available(_owner: int) -> bool: return false

class Spatial extends RefCounted:
	var block_detours := false
	var block_reconnect := false
	var detour_checks := 0
	var reconnect_checks := 0
	var runtime_checks := 0
	var route_builds := 0
	func build_route(start: Vector3, destination: Vector3, _clearance: float) -> Array:
		route_builds += 1
		return [start, destination]
	func validate_runtime_segment(start: Vector3, destination: Vector3, _clearance: float) -> bool:
		runtime_checks += 1
		if absf(destination.x - start.x) > 0.1:
			detour_checks += 1
			if block_detours: return false
		if absf(start.x) > 0.5 and absf(destination.x) < 0.01 and start.z < -1.0:
			reconnect_checks += 1
			if block_reconnect: return false
		return true

class Host extends Node3D:
	var zone_root := Node3D.new()
	var player := CharacterBody3D.new()
	var hud := Hud.new()
	var audio: Node
	var quests: Node
	var day_night: Node
	func _ready() -> void:
		for child in [zone_root, player, hud]: add_child(child)
		player.position = Vector3(20, 0, 20)
	func validate_walkable_position(point: Vector3) -> Vector3: return point

var failures: Array[String] = []
var checks := 0
var error_log := ErrorLog.new()
var scripted_steps := 0
var scripted_queries := 0
var scripted_max_queries_per_step := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	OS.add_logger(error_log)
	_verify_attention_resume()
	_verify_nearby_walk()
	_verify_blocked_player()
	_verify_player_pass()
	_verify_crossing_player()
	_verify_swept_clearance()
	_verify_separate_floor()
	_verify_crowd_visibility()
	_verify_detour_reconnection()
	for kind: String in ["world", "safety"]:
		_verify_scripted_heading(kind)
		_verify_scripted_corner(kind)
		_verify_scripted_arrival(kind)
		_verify_scripted_intermediate(kind)
		_verify_scripted_player_clearance(kind)
	_check(scripted_queries > 0 and scripted_max_queries_per_step <= 1, "scripted walking uses at most one existing spatial validation per actor step")
	OS.remove_logger(error_log)
	_check(error_log.errors.is_empty(), "no engine or script errors during movement verification")
	for error: String in error_log.errors:
		print("NPC ATTENTION MOVEMENT ENGINE ERROR: " + error)
	print("NPC SCRIPTED MOVEMENT BUDGET: steps=%d validations=%d max_per_step=%d" % [scripted_steps, scripted_queries, scripted_max_queries_per_step])
	print("NPC ATTENTION MOVEMENT: %s checks=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _fixture() -> Dictionary:
	var host := Host.new()
	root.add_child(host)
	var life := Life.new()
	host.zone_root.add_child(life)
	life.set_process(false)
	life.host = host
	life.player = host.player
	life.spatial_service = Spatial.new()
	var actor := Node3D.new()
	host.zone_root.add_child(actor)
	var driver := Driver.new()
	driver.actor = actor
	actor.add_child(driver)
	var entry: Dictionary = life._make_entry("test_walker", actor, [Vector3.ZERO, Vector3(0, 0, -8)], 0.8, driver, false)
	entry.pause = 0.0
	entry.profile = {"occupation":"worker", "activity":"rest", "activities":["rest", "rest"], "activity_seconds":20.0, "workstation":{"activity":"rest", "point":Vector3(0, 0, -1)}}
	life.actors.append(entry)
	return {"host":host, "life":life, "entry":entry}

func _tick(fixture: Dictionary, count: int) -> void:
	for _index in count:
		fixture.life._update_actor(fixture.entry, 0.05)

func _verify_attention_resume() -> void:
	var f := _fixture()
	var entry: Dictionary = f.entry
	f.host.player.position = Vector3(1.3, 0, 0)
	f.life._begin_activity(entry)
	entry.activity_elapsed = 0.4
	entry.route = [Vector3(0, 0, -8)]
	var station: String = entry.station
	_tick(f, 10)
	_check(is_equal_approx(entry.activity_elapsed, 0.4), "acknowledgement briefly pauses existing activity")
	_check(entry.activity_active and f.life.activity_reservations.get(station) == entry.node, "brief attention retains workstation ownership")
	_tick(f, 60)
	_check(entry.activity_elapsed > 2.0 and entry.activity_cycles == 1, "nearby worker resumes the same activity cycle")
	_check(entry.driver.station == entry.profile.workstation, "workstation pose binding resumes after acknowledgement")
	_check(entry.target == 1 and entry.route == [Vector3(0, 0, -8)] and entry.node.position == Vector3.ZERO, "attention preserves routine target, route, and feet")
	var elapsed: float = entry.activity_elapsed
	_tick(f, 40)
	_check(entry.activity_elapsed > elapsed + 1.9 and entry.attention_remaining == 0.0, "hovering does not rearm attention")
	f.host.player.position = Vector3(4, 0, 0)
	_tick(f, 1)
	f.host.player.position = Vector3(1.3, 0, 0)
	elapsed = entry.activity_elapsed
	_tick(f, 1)
	_check(entry.attention_remaining > 1.1 and entry.activity_elapsed == elapsed, "leaving and reapproaching rearms one acknowledgement")
	f.life._release_activity(entry)
	entry.node.set_meta("cast_dialogue_owner", 42)
	entry.driver.activity = "external_dialogue"
	entry.driver.station = {"owner":"external"}
	entry.attention_used = false
	entry.attention_remaining = 0.0
	var position: Vector3 = entry.node.position
	var yaw: float = entry.node.rotation.y
	_tick(f, 40)
	_check(not entry.attention_used and entry.node.position == position and entry.node.rotation.y == yaw, "dialogue owner suppresses attention and routine motion")
	_check(entry.driver.activity == "external_dialogue" and entry.driver.station == {"owner":"external"}, "protected owner retains its activity and workstation pose")
	f.host.free()

func _verify_nearby_walk() -> void:
	var f := _fixture()
	f.host.player.position = Vector3(1.3, 0, -1.2)
	_tick(f, 160)
	_check(f.entry.node.position.z < -3.0, "walker resumes past a nearby off-route player")
	f.host.free()

func _verify_blocked_player() -> void:
	var f := _fixture()
	f.host.player.position = Vector3(0, 0, -1.2)
	f.entry.attention_used = true
	f.life.spatial_service.block_detours = true
	var minimum := INF
	var largest_step := 0.0
	for _index in 240:
		var before: Vector3 = f.entry.node.position
		_tick(f, 1)
		minimum = minf(minimum, f.entry.node.position.distance_to(f.host.player.position))
		largest_step = maxf(largest_step, before.distance_to(f.entry.node.position))
	_check(minimum >= 0.72 and f.entry.node.position.z > -0.49, "blocked passage yields without entering the player body")
	_check(largest_step <= 0.041 and f.entry.driver.velocity.length() < 0.05, "blocked actor plants its feet without teleporting or walking in place")
	_check(f.life.spatial_service.detour_checks > 0 and f.entry.route.size() == 2, "unavailable sidesteps are rejected without route growth")
	f.host.free()

func _verify_player_pass() -> void:
	var f := _fixture()
	f.host.player.position = Vector3(0, 0, -1.4)
	f.entry.attention_used = true
	var minimum := INF
	for _index in 440:
		_tick(f, 1)
		minimum = minf(minimum, f.entry.node.position.distance_to(f.host.player.position))
	_check(f.entry.node.position.z < -3.0 and minimum >= 0.72, "validated sidestep passes stationary player without overlap")
	f.host.free()

func _verify_swept_clearance() -> void:
	var f := _fixture()
	f.host.player.position = Vector3(0, 0, -1)
	f.life._move_actor(f.entry, Vector3.FORWARD, 10.0, 1.0)
	_check(f.entry.node.position.z < -0.2 and f.entry.node.position.distance_to(f.host.player.position) >= 0.72, "large swept movement cannot cross the player")
	f.entry.node.position = Vector3.ZERO
	f.host.player.position = Vector3(0, 0, -0.3)
	f.life._move_actor(f.entry, Vector3.FORWARD, 0.8, 0.05)
	_check(f.entry.node.position == Vector3.ZERO, "existing overlap cannot deepen")
	f.life._move_actor(f.entry, Vector3.BACK, 0.8, 0.05)
	_check(f.entry.node.position.z > 0.0, "existing overlap can separate through ordinary movement")
	f.host.free()

func _verify_crossing_player() -> void:
	var f := _fixture()
	f.entry.attention_used = true
	f.life.spatial_service.block_detours = true
	f.host.player.position = Vector3(1.2, 0, -2)
	var minimum := INF
	for index in 80:
		f.host.player.position.x = maxf(0.0, 1.2 - float(index) * 0.06)
		_tick(f, 1)
		minimum = minf(minimum, f.entry.node.position.distance_to(f.host.player.position))
	_check(minimum >= 0.72, "crossing player retains clearance after social attention expires")
	var stopped: Vector3 = f.entry.node.position
	f.host.player.position.x = -2.0
	_tick(f, 60)
	_check(f.entry.node.position.z < stopped.z - 1.0, "walker resumes when crossing player clears the route")
	f.host.free()

func _verify_crowd_visibility() -> void:
	var f := _fixture()
	var other := Node3D.new()
	f.host.zone_root.add_child(other)
	other.position = Vector3(0, 0, -0.7)
	var person := Node3D.new()
	person.name = "Person"
	other.add_child(person)
	f.life._crowd_index.update(other, {"id":"blocker", "node":other})
	other.hide()
	_check(f.life._crowd_pace(f.entry, Vector3.FORWARD, 0.05) == 1.0, "hidden actor does not block a living route")
	other.show()
	person.hide()
	_check(f.life._crowd_pace(f.entry, Vector3.FORWARD, 0.05) == 1.0, "hidden presentation does not leave a ghost obstruction")
	person.show()
	other.set_meta("cast_work_owner", 42)
	_check(f.life._crowd_pace(f.entry, Vector3.FORWARD, 0.05) < 0.15, "visible work owner remains a physical obstruction")
	f.host.free()

func _verify_separate_floor() -> void:
	var f := _fixture()
	f.host.player.position = Vector3(0, 3, -0.8)
	_check(f.life._crowd_pace(f.entry, Vector3.FORWARD, 0.05) == 1.0, "player on another floor does not obstruct routine pacing")
	f.life._move_actor(f.entry, Vector3.FORWARD, 1.0, 1.0)
	_check(is_equal_approx(f.entry.node.position.z, -1.0), "separate-floor player does not clip actual movement")
	_check(f.life._clear_detour_segment(Vector3.ZERO, Vector3(0, 0, -2)), "separate-floor player does not invalidate a detour")
	f.host.free()

func _verify_detour_reconnection() -> void:
	var f := _fixture()
	f.host.player.position = Vector3(0, 0, -0.8)
	f.entry.route = [Vector3(0, 0, -8)]
	f.entry.route_index = 0
	f.entry.yield_time = 1.21
	f.life.spatial_service.block_reconnect = true
	f.life._crowd_pace(f.entry, Vector3.FORWARD, 0.05)
	_check(f.life.spatial_service.reconnect_checks == 2 and f.entry.route.size() == 1, "both detour reconnections must be safe before inserting waypoints")
	f.host.free()

func _scripted_fixture(kind: String, target: Vector3, intermediate: bool = false) -> Dictionary:
	var f := _fixture()
	var points: Array = [Vector3(0, 0, -1.5), target] if intermediate else [target]
	if kind == "safety":
		f.entry.reaction = "fear"
		f.entry.safety_route = points
		f.entry.safety_index = 0
	else:
		f.entry.route = points
		f.entry.route_index = 0
	return f

func _scripted_tick(f: Dictionary, kind: String, target: Vector3) -> bool:
	var before: int = f.life.spatial_service.runtime_checks
	var arrived: bool = f.life._world_walk_to(f.entry, target, 0.05) if kind == "world" else not f.life._seek_safety(f.entry, Vector3(0, 0, 1), 0.05)
	var queries: int = f.life.spatial_service.runtime_checks - before
	scripted_steps += 1
	scripted_queries += queries
	scripted_max_queries_per_step = maxi(scripted_max_queries_per_step, queries)
	return arrived

func _verify_scripted_heading(kind: String) -> void:
	var target := Vector3(1, 0, -4)
	var f := _scripted_fixture(kind, target)
	f.entry.node.rotation.y = 0.2
	f.entry.motion_speed = 0.5
	f.entry.travel_direction = Vector3.RIGHT
	var path: Array = f.entry.path.duplicate()
	var routine_target: int = f.entry.target
	_scripted_tick(f, kind, target)
	var moved: Vector3 = f.entry.node.position
	var heading: Vector3 = f.entry.driver.get_visible_forward()
	_check(moved.length() > 0.01 and moved.normalized().dot(heading) > 0.999, kind + " translation follows the visible chest while turning")
	_check((f.entry.travel_direction as Vector3).dot(moved.normalized()) > 0.999, kind + " movement replaces stale travel direction with achieved motion")
	var before: Vector3 = f.entry.node.position
	f.life._brake_actor(f.entry, 0.05)
	var braking: Vector3 = f.entry.node.position - before
	_check(braking.length() > 0.005 and braking.normalized().dot(moved.normalized()) > 0.999, kind + " braking follows the last scripted movement rather than an old routine leg")
	_check(f.entry.path == path and f.entry.target == routine_target, kind + " movement preserves the authored routine destination")
	f.host.free()

func _verify_scripted_corner(kind: String) -> void:
	var target := Vector3(0, 0, -4)
	var f := _scripted_fixture(kind, target)
	f.entry.node.rotation.y = -PI * 0.5
	f.entry.travel_direction = Vector3.RIGHT
	f.entry.motion_speed = 0.7
	var yaw: float = f.entry.node.rotation.y
	_scripted_tick(f, kind, target)
	_check(f.entry.node.position.x > 0.02 and absf(f.entry.node.position.z) < 0.00001 and f.entry.node.rotation.y == yaw, kind + " sharp corner brakes along the prior leg before rotating")
	var maximum_turn := 0.0
	var arrived := false
	for _index in 200:
		yaw = f.entry.node.rotation.y
		arrived = _scripted_tick(f, kind, target)
		maximum_turn = maxf(maximum_turn, absf(wrapf(f.entry.node.rotation.y - yaw, -PI, PI)))
		if arrived: break
	_check(arrived and f.entry.node.position.z < -3.7, kind + " corner turns and completes actual travel without stalling")
	_check(maximum_turn <= Life.ROUTE_TURN_RATE * 0.05 + 0.00001, kind + " corner preserves the bounded turn rate")
	f.host.free()

func _verify_scripted_arrival(kind: String) -> void:
	var target := Vector3(0, 0, -2)
	var f := _scripted_fixture(kind, target)
	var radius := 0.2 if kind == "world" else 0.12
	var limit := 0.7 if kind == "world" else 0.92
	# Exercise normal world route construction once, then retain it until arrival.
	if kind == "world": f.entry.route = []
	var arrived := false
	var slowed := false
	var maximum_speed := 0.0
	for _index in 180:
		var before: Vector3 = f.entry.node.position
		arrived = _scripted_tick(f, kind, target)
		var achieved_speed: float = before.distance_to(f.entry.node.position) / 0.05
		maximum_speed = maxf(maximum_speed, achieved_speed)
		var distance: float = f.entry.node.position.distance_to(target)
		if not arrived and distance < radius + 0.2 and achieved_speed > 0.01 and achieved_speed < limit - 0.15:
			slowed = true
		if arrived: break
	var distance: float = f.entry.node.position.distance_to(target)
	_check(arrived and distance >= radius - 0.001 and distance <= radius + 0.005, kind + " arrives finitely at its original radius without teleporting")
	_check(slowed and maximum_speed <= limit + 0.00001, kind + " decelerates before final arrival and retains its speed cap")
	_check(f.entry.motion_speed == 0.0 and f.entry.driver.velocity == Vector3.ZERO, kind + " completed arrival reports planted feet")
	_check(f.life.spatial_service.route_builds == (1 if kind == "world" else 0), kind + " arrival does not rebuild its active route each frame")
	f.host.free()

func _verify_scripted_intermediate(kind: String) -> void:
	var target := Vector3(0, 0, -4)
	var f := _scripted_fixture(kind, target, true)
	f.entry.motion_speed = 0.7
	var crossed := false
	var crossing_speed := 0.0
	for _index in 80:
		_scripted_tick(f, kind, target)
		var index: int = f.entry.route_index if kind == "world" else f.entry.safety_index
		if index > 0:
			crossed = true
			crossing_speed = f.entry.motion_speed
			break
	_check(crossed and f.entry.node.position.z < -1.25 and crossing_speed >= 0.69, kind + " collinear intermediate anchor does not trigger final-arrival braking")
	f.host.free()

func _verify_scripted_player_clearance(kind: String) -> void:
	var target := Vector3(0, 0, -4)
	var f := _scripted_fixture(kind, target)
	f.host.player.position = Vector3(0, 0, -1)
	var minimum := INF
	var arrived := false
	for _index in 100:
		arrived = _scripted_tick(f, kind, target) or arrived
		minimum = minf(minimum, f.entry.node.position.distance_to(f.host.player.position))
	_check(not arrived and minimum >= 0.72 and f.entry.node.position.z > -0.29, kind + " scripted walking respects a blocking player without premature completion")
	f.host.player.position.x = 2.0
	for _index in 160:
		arrived = _scripted_tick(f, kind, target)
		if arrived: break
	_check(arrived and f.entry.node.position.z < -3.7, kind + " scripted walking resumes after the player clears its route")
	f.host.free()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)
