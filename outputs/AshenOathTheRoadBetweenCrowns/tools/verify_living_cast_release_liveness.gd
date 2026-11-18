extends SceneTree
## Real station/contact views and reservation model; synthetic pose observer only.
## No game, save data, renderer or retained asset construction is required.
const Life = preload("res://scripts/greyfen_life_controller.gd")

class Modifier extends Node:
	var rest_anchor: Dictionary = {}

class PoseProbe extends Node:
	var life_modifier: Modifier = Modifier.new()
	var tool: Node3D = Node3D.new()
	var calls: Array[String] = []
	func _init() -> void:
		add_child(life_modifier)
		add_child(tool)
	func set_life_activity(value: String) -> void:
		calls.append("activity:" + value)
	func set_life_rest_anchor(value: Dictionary) -> void:
		calls.append("rest")
		life_modifier.rest_anchor = value
	func set_activity_prop(value: String) -> void:
		calls.append("prop:" + value)
		tool.visible = not value.is_empty()
	func clear_life_activity() -> void:
		calls.append("clear")
		tool.visible = false
	func set_carried_activity(value: String) -> void:
		calls.append("carry:" + value)
	func set_life_workstation(_value: Dictionary) -> void:
		calls.append("station")

class ErrorLog extends Logger:
	var errors: Array[String] = []
	func _log_error(_function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != Logger.ERROR_TYPE_WARNING:
			errors.append("%s:%d %s %s" % [file, line, code, rationale])

var failures: Array[String] = []
var checks := 0
var error_log := ErrorLog.new()

func _initialize() -> void:
	OS.add_logger(error_log)
	_run.call_deferred()

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func _run() -> void:
	for release_pose: bool in [true, false]:
		for active: bool in [true, false]:
			for freed_driver: bool in [true, false]:
				_run_case(true, freed_driver, active, release_pose, false)
		_run_case(false, false, true, true, false)
	_run_case(false, false, false, true, false)
	_run_case(false, false, true, false, false)
	_run_case(true, true, true, true, true)
	_check(error_log.errors.is_empty(), "No typed-boundary, freed-instance or cleanup engine errors")
	print(JSON.stringify({"fixture":"living_cast_release_liveness", "passed":failures.is_empty(),
		"checks":checks, "failures":failures, "engine_errors":error_log.errors,
		"actual_station_view":true, "actual_contact_view":true, "actual_reservations":true,
		"pose_probe":"synthetic", "gameplay":false, "render_capture":false, "save_data":false}))
	quit(0 if failures.is_empty() else 1)

func _run_case(freed_actor: bool, freed_driver: bool, active: bool, release_pose: bool, reowned: bool) -> void:
	var label := "actor_freed=%s driver_freed=%s active=%s pose=%s reowned=%s" % [freed_actor,freed_driver,active,release_pose,reowned]
	var life := Life.new()
	var owner := Node3D.new()
	root.add_child(owner)
	var actor := Node3D.new()
	owner.add_child(actor)
	var driver := PoseProbe.new()
	owner.add_child(driver)
	driver.life_modifier.rest_anchor = {"awake_rest_owner":life.get_instance_id()}
	var station := "fixture_station"
	var entry := {"id":"retiring_worker", "node":actor, "driver":driver, "face":null,
		"profile":{"activity":"forge", "prop":"hammer"}, "activity_active":active,
		"station":station, "carry_route_scope":"fixture_scope"}
	var other := Node3D.new()
	owner.add_child(other)
	var other_entry := {"id":"other_worker", "node":other}
	life.actors = [entry,other_entry]
	_check(life.reserve_station(station, actor), "Station initially reserved: " + label)
	if reowned:
		life.release_station(station)
		_check(life.reserve_station(station, other), "Station acquired by another living actor")
	var contact := Node3D.new()
	owner.add_child(contact)
	var original := Transform3D(Basis.from_euler(Vector3(0.1,0.2,0.3)),Vector3(2,3,4))
	contact.transform = original.scaled_local(Vector3(1.1,0.9,1.0))
	var effect := {"actor":weakref(actor), "node":weakref(contact), "transform":original}
	life.work_contact_effects.append(effect)
	var other_contact := Node3D.new()
	owner.add_child(other_contact)
	life.work_contact_effects.append({"actor":weakref(other), "node":weakref(other_contact), "scale":Vector3.ONE})
	if freed_driver: driver.free()
	if freed_actor: actor.free()
	# These Dictionary values intentionally retain freed Object references, as
	# actual zone retirement does before the controller receives _exit_tree.
	life.living_cast_station_view._release_activity(entry, release_pose)
	_check(not entry.has("carry_route_scope") and entry.station == "" and not entry.activity_active, "All entry ownership released: " + label)
	_check(life.model.reservation_owner(station) == ("other_worker" if reowned else ""), "Reservation cleaned without releasing another actor: " + label)
	_check(contact.transform.is_equal_approx(original), "Living contact prop restored after owner release: " + label)
	_check(life.work_contact_effects.size() == 1 and life.work_contact_effects[0].node.get_ref() == other_contact, "Only released/orphaned effects removed: " + label)
	if not freed_driver:
		if release_pose:
			_check("carry:" in driver.calls and "station" in driver.calls, "Living driver drops carried/workstation state: " + label)
			_check(("clear" in driver.calls) == active, "Activity clear policy unchanged: " + label)
			_check(("activity:" in driver.calls) == (active and not freed_actor), "Only living actor receives pose release: " + label)
			_check(driver.tool.visible == (not active), "Held tool hides on active release: " + label)
		else:
			_check(driver.calls == ["rest"] and driver.life_modifier.rest_anchor.is_empty(), "Other pose owner retained; owned awake seat released: " + label)
			_check(driver.tool.visible, "Other pose owner keeps its held prop: " + label)
	# Double release must be safe after all reservation/contact ownership is gone.
	life.living_cast_station_view._release_activity(entry, release_pose)
	_check(life.work_contact_effects.size() == 1, "Repeated release preserves unrelated live effects: " + label)
	life.free()
	owner.free()
