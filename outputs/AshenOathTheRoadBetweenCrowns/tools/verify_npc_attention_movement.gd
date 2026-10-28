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
	func build_route(start: Vector3, destination: Vector3, _clearance: float) -> Array:
		return [start, destination]
	func validate_runtime_segment(start: Vector3, destination: Vector3, _clearance: float) -> bool:
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
	OS.remove_logger(error_log)
	_check(error_log.errors.is_empty(), "no engine or script errors during movement verification")
	for error: String in error_log.errors:
		print("NPC ATTENTION MOVEMENT ENGINE ERROR: " + error)
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

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)
