extends SceneTree
## Regression for named-actor promotion from village to regional routine ownership.
## Uses the authored CastProfile schedules without loading scenes or writing saves.

const Life = preload("res://scripts/greyfen_life_controller.gd")
const CastProfile = preload("res://scripts/story_cast_profile.gd")
const Story = preload("res://scripts/story_state.gd")
const Quests = preload("res://scripts/quest_manager.gd")
const NAMED := ["blacksmith_tor", "mira", "rook"]

class Clock extends Node:
	signal phase_changed(phase: String)
	var current_phase := "day"
	var day_count := 0
	func get_time() -> float: return 720.0

class Driver extends Node:
	signal activity_contact(event: String, point: Vector3)
	var activity := ""
	func get_visible_forward() -> Vector3: return Vector3.FORWARD
	func set_distance_suspended(_suspended: bool) -> void: pass
	func set_update_rate_hz(_rate: float) -> void: pass
	func set_life_activity(value: String) -> void: activity = value
	func clear_life_activity() -> void: activity = ""
	func set_life_workstation(_station: Dictionary) -> void: pass
	func set_carried_activity(_value: String) -> void: pass

class Host extends Node3D:
	var zone_root := Node3D.new()
	var player := CharacterBody3D.new()
	var story_state := Story.new()
	var quests := Quests.new()
	var day_night := Clock.new()
	var audio: Node
	var spatial_service: Node
	var asset_helper: Node
	var current_zone_id := "greyfen"
	var pending_ending := ""
	var zone_transition_pending := false
	func _ready() -> void:
		for child in [zone_root, player, story_state, quests, day_night]:
			add_child(child)
		player.position = Vector3(100, 0, 100)
	func validate_walkable_position(point: Vector3) -> Vector3: return point
	func river_safe_path(points: Array, _margin: float = 0.9) -> Array: return points
	func _story_has_active_combat() -> bool: return false

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_verify_promotion()
	_verify_deferred_hydration()
	_verify_temporary_restore(false)
	_verify_temporary_restore(true)
	_verify_regional_only()
	print("GREYFEN ROUTINE OWNERSHIP: %s checks=%d failures=%d" % [
		"PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _fixture(hydrated: bool = true, regional_only: bool = false) -> Dictionary:
	var host := Host.new()
	root.add_child(host)
	for id: String in NAMED:
		var actor := Node3D.new()
		actor.name = id
		host.zone_root.add_child(actor)
		if hydrated:
			_add_driver(actor)
	var life := Life.new()
	life.set_meta("staged_population", true)
	host.zone_root.add_child(life)
	life.configure(host, "balanced", regional_only)
	life.set_process(false)
	return {"host": host, "life": life}

func _add_driver(actor: Node3D) -> void:
	var driver := Driver.new()
	driver.name = "CharacterAnimationDriver"
	actor.add_child(driver)

func _verify_promotion() -> void:
	var fixture := _fixture()
	var life: Node = fixture.life
	for entry: Dictionary in life.actors:
		_check(not entry.pending_routine.profile.has("activities"), "fixture queues original village routine: " + str(entry.id))
	var signature: String = life.story_signature
	life.enroll_region()
	life._sync_story_state(false)
	_check(life.story_signature == signature, "promotion does not require a story change")
	for entry: Dictionary in life.actors:
		life._apply_pending_routine(entry)
		if _authored(entry, fixture, "initial promotion"):
			entry.node.global_position = entry.path[0]
			life._begin_activity(entry)
			_check(entry.activity_active and entry.driver.activity == entry.profile.activities[0], "promoted actor starts authored activity: " + str(entry.id))
			life._end_activity(entry)
	# Reconfiguration and story/time events must continue to queue regional data.
	life.configure(fixture.host, "balanced")
	fixture.host.day_night.current_phase = "night"
	fixture.host.day_night.phase_changed.emit("night")
	life._sync_story_state(false)
	life.enroll_region()
	for entry: Dictionary in life.actors:
		_check(not entry.pending_routine.is_empty(), "repeat enrollment preserves queued phase change: " + str(entry.id))
		life._apply_pending_routine(entry)
		_authored(entry, fixture, "night phase")
	fixture.host.story_state.set_flag("evidence_report", "public")
	life._sync_story_state(false)
	for entry: Dictionary in life.actors:
		life._apply_pending_routine(entry)
		_authored(entry, fixture, "story refresh")
	_dispose(fixture)

func _verify_deferred_hydration() -> void:
	var fixture := _fixture(false)
	var life: Node = fixture.life
	life.enroll_region()
	for entry: Dictionary in life.actors:
		_check(not bool(entry.get("regional", false)), "unhydrated actor waits for enrollment: " + str(entry.id))
		_add_driver(entry.node)
	life.configure(fixture.host, "balanced")
	life.enroll_region()
	life._sync_story_state(false)
	for entry: Dictionary in life.actors:
		life._apply_pending_routine(entry)
		_authored(entry, fixture, "deferred hydration")
	_dispose(fixture)

func _verify_temporary_restore(gathering: bool) -> void:
	var fixture := _fixture()
	var life: Node = fixture.life
	var host: Host = fixture.host
	if gathering:
		host.story_state.set_flag("evidence_report", "private")
		host.story_state.set_flag("lr_gathering_window", {"start": 0, "end": 1440, "names": "", "final": false})
		life._update_gathering_routines()
	else:
		life.request_table_visit("rook", Vector3(20, 0, 20))
	var rook: Dictionary = life._world_actor("rook")
	var restore_key := "gathering_restore" if gathering else "table_restore"
	_check(rook.has(restore_key) and not rook[restore_key].profile.has("activities"), "fixture retains pre-promotion " + restore_key)
	life.enroll_region()
	if gathering:
		host.story_state.set_flag("lr_gathering_window", {})
		life._update_gathering_routines()
	else:
		rook.table_seconds = 0.0
		life._update_actor(rook, 0.0)
	_check(not rook.has(restore_key), "temporary routine releases " + restore_key)
	_authored(rook, fixture, restore_key + " after promotion")
	_dispose(fixture)

func _verify_regional_only() -> void:
	var fixture := _fixture(true, true)
	_check(fixture.life.actors.is_empty(), "regional-only controller has no village queue")
	fixture.life.enroll_region()
	for entry: Dictionary in fixture.life.actors:
		fixture.life._apply_pending_routine(entry)
		_authored(entry, fixture, "direct regional enrollment")
	_dispose(fixture)

func _authored(entry: Dictionary, fixture: Dictionary, label: String) -> bool:
	var expected := CastProfile.routine(str(entry.id), "greyfen", fixture.host.story_state,
		fixture.host.quests, str(fixture.life.routine_phase))
	var valid: bool = bool(entry.get("regional", false)) and entry.profile.has("activities")
	_check(valid, label + " retains regional profile: " + str(entry.id))
	if not valid:
		return false
	for key: String in ["activities", "activity_seconds", "occupation", "identity", "line"]:
		_check(entry.profile[key] == expected[key], "%s preserves authored %s: %s" % [label, key, entry.id])
	_check(entry.path == expected.path, label + " preserves authored path: " + str(entry.id))
	return true

func _dispose(fixture: Dictionary) -> void:
	fixture.life.free()
	fixture.host.free()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		print("GREYFEN ROUTINE FAILURE: " + label)
