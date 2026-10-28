extends SceneTree
## Runtime awareness contract: credible priority, bounded distractions and resume.
const Life = preload("res://scripts/greyfen_life_controller.gd")
const Story = preload("res://scripts/story_state.gd")

class ErrorLog extends Logger:
	var errors: Array[String] = []
	func _log_error(_function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != Logger.ERROR_TYPE_WARNING:
			errors.append("%s:%d %s %s" % [file, line, code, rationale])

class QuietIndex extends RefCounted:
	var entries: Array = []
	func nearby(_point: Vector3, _radius: float) -> Array: return entries

class Enemy extends Node3D:
	var dead := false
	var encounter_active := true

class Spatial extends RefCounted:
	func build_route(start: Vector3, destination: Vector3, _radius: float) -> Array: return [start, destination]
	func validate_runtime_segment(_start: Vector3, _destination: Vector3, _radius: float) -> bool: return true

class Hud extends Node:
	var messages: Array[String] = []
	func toast(message: String, _duration: float) -> void: messages.append(message)

class Driver extends Node:
	var activity := ""
	func set_life_activity(value: String) -> void: activity = value
	func set_life_workstation(_value: Dictionary) -> void: pass
	func clear_life_activity() -> void: activity = ""
	func get_visible_forward() -> Vector3: return Vector3.FORWARD

class Face extends Node:
	var focus_target: Node3D
	var expression := "neutral"
	func set_focus_target(target: Node3D) -> void: focus_target = target
	func set_expression(value: String) -> void: expression = value

class Host extends Node3D:
	var game_started := true
	var story_save_pending := false
	var quests: Node
	var day_night: Node
	var audio: Node
	var story_state := Story.new()
	var encounter_spatial_index := QuietIndex.new()
	var zone_root := Node3D.new()
	var player := Node3D.new()
	var hud := Hud.new()
	func _init() -> void:
		add_child(zone_root)
		add_child(story_state)
		add_child(player)
		add_child(hud)
		player.position = Vector3(100, 0, 100)
	func _persist_story_action() -> void: pass

var failures: Array[String] = []
var checks := 0
var events: Array[String] = []
var error_log := ErrorLog.new()

func _initialize() -> void: call_deferred("_run")

func _fixture(with_face: bool = false) -> Dictionary:
	var host := Host.new()
	root.add_child(host)
	var life := Life.new()
	life.set_process(false)
	life.host = host
	life.player = host.player
	host.zone_root.add_child(life)
	life.awareness_changed.connect(func(id: String, kind: String): events.append(id + ":" + kind))
	var actor := Node3D.new()
	host.zone_root.add_child(actor)
	var driver := Driver.new()
	actor.add_child(driver)
	var entry: Dictionary = life._make_entry("walker_well", actor, [Vector3.ZERO, Vector3(0, 0, -3)], 0.62, driver, false)
	if with_face:
		var face := Face.new()
		actor.add_child(face)
		entry.face = face
	life.actors.append(entry)
	life._crowd_index.update(actor, entry)
	return {"host":host, "life":life, "entry":entry}

func _run() -> void:
	OS.add_logger(error_log)
	_verify_priority()
	_verify_sound_lease()
	_verify_resume_without_face()
	_verify_escape_anchor()
	_verify_protected_owner()
	_verify_contact_ownership()
	await _verify_focus()
	OS.remove_logger(error_log)
	_check(error_log.errors.is_empty(), "no engine or script errors during awareness verification")
	for error: String in error_log.errors:
		print("NPC AWARENESS ENGINE ERROR: " + error)
	print("NPC AWARENESS: %s checks=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _verify_priority() -> void:
	var f := _fixture()
	var life: Node = f.life
	var entry: Dictionary = f.entry
	var danger := Vector3(0, 0, -2)
	life._on_perception_cue(danger, 5.0, true)
	_check(entry.reaction == "fear", "civilian reacts to dangerous sound")
	var before := float(entry.reaction_time)
	life._on_perception_cue(Vector3(2, 0, 0), 5.0, false)
	_check(entry.reaction == "fear" and entry.threat_position == danger and float(entry.reaction_time) == before, "ordinary sound cannot cancel or redirect danger")
	_check(not life._start_reaction(entry, "suspicion", Vector3.ONE, 2.5), "weapon suspicion cannot displace active danger")
	_check(entry.threat_position == danger, "rejected reaction retains observed danger position")
	_check(life._start_reaction(entry, "fear", danger, 3.0), "contact can extend an equal-priority reaction")
	life._start_reaction(entry, "fear", danger, 2.5)
	_check(is_equal_approx(float(entry.reaction_time), 3.0), "shorter refresh does not shorten active response")
	f.host.free()

func _verify_sound_lease() -> void:
	var f := _fixture()
	var life: Node = f.life
	var entry: Dictionary = f.entry
	var state: Dictionary = f.host.story_state.save_state()
	var start := events.size()
	life._on_perception_cue(Vector3(0, 0, -1), 5.0, false)
	for tick in range(30):
		life._on_perception_cue(Vector3(1, 0, 0), 5.0, false)
		life._update_reaction(entry, 0.1)
	_check(float(entry.reaction_time) == 0.0 and entry.reaction == "", "repeated ordinary cues cannot keep a worker distracted forever")
	_check(events.slice(start) == ["walker_well:attention", "walker_well:"], "one distraction emits one start/end pair")
	_check(entry.threat_position == Vector3(0, 0, -1), "suppressed noise does not pull attention around")
	life._on_perception_cue(Vector3.ZERO, 5.0, true)
	_check(entry.reaction == "fear", "real danger bypasses ordinary-sound cooldown")
	_check(f.host.story_state.save_state() == state, "ambient awareness does not commit quest or relationship changes")
	f.host.free()

func _verify_resume_without_face() -> void:
	var f := _fixture()
	var life: Node = f.life
	var entry: Dictionary = f.entry
	life._start_reaction(entry, "fear", Vector3.ONE, 2.5)
	entry.route = [Vector3.ONE]
	entry.safety_route = [Vector3(3, 0, 0)]
	entry.driver.activity = "fear"
	entry.sense_clock = 10.0
	var path: Array = entry.path.duplicate()
	var target := int(entry.target)
	life._update_reaction(entry, 3.0)
	_check(entry.route.is_empty() and entry.safety_route.is_empty(), "expiry clears stale travel and escape legs without a face driver or sense tick")
	_check(entry.driver.activity == "" and not entry.reaction_active, "expiry releases fear pose exactly once")
	_check(entry.path == path and int(entry.target) == target, "authored schedule and destination survive interruption")
	var count := events.size()
	life._update_reaction(entry, 0.1)
	_check(events.size() == count, "settled reaction does not repeat completion")
	f.host.free()

func _verify_protected_owner() -> void:
	var f := _fixture()
	var entry: Dictionary = f.entry
	f.life._start_reaction(entry, "fear", Vector3.ONE, 2.5)
	entry.node.set_meta("cast_dialogue_owner", 123)
	entry.driver.activity = "dialogue"
	f.life._update_reaction(entry, 3.0)
	f.life._on_perception_cue(Vector3.ZERO, 5.0, true)
	_check(entry.driver.activity == "dialogue" and entry.reaction_active, "dialogue owns its pose despite reaction expiry or another cue")
	entry.node.remove_meta("cast_dialogue_owner")
	entry.node.set_meta("locomotion_owner", "relief_escort")
	f.life._update_reaction(entry, 0.1)
	f.life._on_perception_cue(Vector3.ZERO, 5.0, true)
	_check(entry.reaction_active and entry.driver.activity == "dialogue", "scripted escort ownership also defers awareness cleanup and cues")
	entry.node.set_meta("locomotion_owner", "greyfen_life")
	f.life._update_reaction(entry, 0.1)
	_check(not entry.reaction_active and entry.driver.activity == "", "deferred cleanup completes after dialogue releases ownership")
	f.host.free()

func _verify_escape_anchor() -> void:
	var f := _fixture()
	f.life.spatial_service = Spatial.new()
	f.life._start_reaction(f.entry, "fear", Vector3(0, 0, 1), 2.5)
	f.life._seek_safety(f.entry, Vector3(0, 0, 1), 0.0)
	_check(not f.entry.safety_route.is_empty(), "escape route is selected through the existing spatial service")
	f.life._start_reaction(f.entry, "fear", Vector3(0.6, 0, 1), 2.5)
	_check(not f.entry.safety_route.is_empty(), "small threat movement retains the existing escape plan")
	f.life._start_reaction(f.entry, "fear", Vector3(1.2, 0, 1), 2.5)
	_check(f.entry.safety_route.is_empty(), "cumulative threat motion invalidates the plan relative to its original observation")
	f.host.free()

func _verify_contact_ownership() -> void:
	var f := _fixture()
	f.entry.node.set_meta("locomotion_owner", "relief_escort")
	f.entry.driver.activity = "escort"
	f.life._receive_contact({"source_tag":"blade"}, f.entry)
	_check(f.entry.driver.activity == "escort", "physical contact does not overwrite a scripted escort pose")
	_check(f.host.story_save_pending and f.host.hud.messages.size() == 1 and not f.host.story_state.relationship_events("walker_well").is_empty(), "contact still records and schedules saving its existing grievance and player-facing warning")
	f.host.free()

func _verify_focus() -> void:
	var f := _fixture(true)
	var threat := Enemy.new()
	threat.position = Vector3(0, 0, -3)
	f.host.zone_root.add_child(threat)
	f.host.encounter_spatial_index.entries = [threat]
	await physics_frame
	f.life._update_reaction(f.entry, 0.1)
	_check(f.entry.face.focus_target == threat, "visual reaction focuses the observed threat rather than always the player")
	f.host.free()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		print("NPC AWARENESS FAILURE: " + label)
