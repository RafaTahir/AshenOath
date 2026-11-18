extends SceneTree
## Real residency/resource ownership fixture; no campaign or visual acceptance.
const Residency = preload("res://scripts/zone_residency_service.gd")

class ReleaseProbe extends Node:
	var pending_victim: WeakRef
	var geometry_victim: WeakRef
	var counters: Dictionary
	func _clear_playback() -> void:
		counters.calls += 1
		for reference: WeakRef in [pending_victim, geometry_victim]:
			var target: Variant = reference.get_ref()
			if is_instance_valid(target): target.free()

class ErrorLog extends Logger:
	var errors: Array[String] = []
	func _log_error(_function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != Logger.ERROR_TYPE_WARNING:
			errors.append("%s:%d %s %s" % [file, line, code, rationale])

var failures: Array[String] = []
var error_log := ErrorLog.new()
var audits := 0
var checks := 0

func _initialize() -> void:
	OS.add_logger(error_log)
	_run.call_deferred()

func _run() -> void:
	var owner := Node3D.new()
	root.add_child(owner)
	var service := Residency.new()
	owner.add_child(service)
	service.configure(_validate)
	_check(Residency.MAX_CACHED_ROUTE_ZONES == 1 and Residency.ZONE_RETIRE_FRAMES == 8,
		"Route retention or renderer grace budget changed")
	_check(Residency.MAX_SKINNED_RESOURCE_ANCHORS == 4 and Residency.MAX_RETIRED_MATERIAL_ANCHORS == 64,
		"Shared-resource retention caps changed")
	await _queued_nodes_freed_during_release(owner, service)
	await _two_returns_and_destination_shutdown(owner, service)
	_check(audits == 3, "Retirement validation was skipped or repeated")
	service.release_shared_anchors()
	service.release_material_anchors()
	_check(service.pending_zone_retirements == 0 and service.retired_zone_roots.is_empty(),
		"Shutdown retained a retiring root or pending counter")
	_check(service.route_zone_cache.is_empty() and service.route_enemy_cache.is_empty(),
		"Shutdown retained route ownership")
	_check(service.skinned_resource_anchors.is_empty() and service.retired_material_anchors.is_empty(),
		"Shutdown retained shared-resource anchors")
	_check(not service.validate_resources.is_valid(), "Shutdown retained its validator")
	RenderingServer.force_sync()
	owner.free()
	await process_frame
	await process_frame
	if not error_log.errors.is_empty():
		failures.append("Engine errors observed: %d" % error_log.errors.size())
	print("ZONE RETIREMENT LIVENESS: %s checks=%d engine_errors=%d returns=2" % [
		"PASS" if failures.is_empty() else "FAIL", checks, error_log.errors.size()])
	quit(0 if failures.is_empty() else 1)

func _queued_nodes_freed_during_release(owner: Node3D, service: Residency) -> void:
	var zone := Node3D.new()
	zone.name = "CleanupInvalidation"
	owner.add_child(zone)
	var pending_victim := Node.new()
	zone.add_child(pending_victim)
	var probe := ReleaseProbe.new()
	zone.add_child(probe)
	var counters := {"calls": 0}
	probe.counters = counters
	# This skeleton has no skinned mesh, so it is not a shared-resource anchor.
	# Its actual playback-clear callback invalidates both cleanup worklists.
	var skeleton := Skeleton3D.new()
	skeleton.set_meta("character_motion_owner", weakref(probe))
	zone.add_child(skeleton)
	var geometry_victim := _mesh(zone, "GeometryVictim")
	var survivor := _mesh(zone, "Survivor")
	probe.pending_victim = weakref(pending_victim)
	probe.geometry_victim = weakref(geometry_victim)
	service._retire_zone_root(zone)
	service._retire_zone_root(zone)
	_check(service.pending_zone_retirements == 1, "Duplicate retirement added an owner")
	_check(is_instance_valid(zone) and survivor.mesh != null, "Retirement skipped its renderer grace period")
	_check(service.skinned_resource_anchors.size() <= Residency.MAX_SKINNED_RESOURCE_ANCHORS
		and service.retired_material_anchors.size() <= Residency.MAX_RETIRED_MATERIAL_ANCHORS,
		"Retirement exceeded its retained-resource budget")
	await _drain(service)
	_check(counters.calls == 1, "Actual playback-clear callback did not run exactly once")
	_check(not is_instance_valid(pending_victim) and not is_instance_valid(geometry_victim),
		"Fixture did not invalidate both the traversal and geometry worklists")
	_check(not is_instance_valid(zone) and not is_instance_valid(survivor),
		"Remaining live geometry/root did not finish retirement after stale entries")
	_check(service.retired_zone_roots.is_empty() and service.retired_material_anchors.is_empty(),
		"Stale traversal entries stranded retirement ownership")

func _two_returns_and_destination_shutdown(owner: Node3D, service: Residency) -> void:
	var source := _zone(owner, "greyfen")
	var destination := _zone(owner, "wychwood")
	var source_id := source.get_instance_id()
	var destination_id := destination.get_instance_id()
	service._cache_route_zone("wychwood", destination, [], 17)
	for cycle in range(2):
		service._cache_route_zone("greyfen", source, [], 20 + cycle)
		destination = service._activate_cached_zone("wychwood")
		# ZoneRuntimeCoordinator consumes the enemy handoff after activation.
		_check(service._valid_cached_enemies(service.route_enemy_cache.get("wychwood", [])).is_empty(), "Unexpected destination enemy handoff")
		service.route_enemy_cache.erase("wychwood")
		_check(is_instance_valid(destination) and destination.get_instance_id() == destination_id,
			"Outgoing passage failed to reuse its destination root")
		service._trim_route_zone_cache(["greyfen"])
		service._cache_route_zone("wychwood", destination, [], 30 + cycle)
		source = service._activate_cached_zone("greyfen")
		_check(service._valid_cached_enemies(service.route_enemy_cache.get("greyfen", [])).is_empty(), "Unexpected source enemy handoff")
		service.route_enemy_cache.erase("greyfen")
		_check(is_instance_valid(source) and source.get_instance_id() == source_id,
			"Return failed to reuse the active source root")
		_check(source.visible and source.transform == Transform3D.IDENTITY
			and source.process_mode == Node.PROCESS_MODE_PAUSABLE,
			"Return did not restore source-world visibility, placement or processing")
		var body := source.get_node("Body") as StaticBody3D
		_check(body.collision_layer == 5 and body.collision_mask == 3,
			"Return changed authored source-world collision masks")
		_check(service.route_zone_cache.size() == Residency.MAX_CACHED_ROUTE_ZONES,
			"Two-return flow changed the route-cache budget")
	service._retire_zone_root(destination)
	destination.free() # A shutdown owner may destroy the branch during grace.
	await _drain(service)
	_check(service.retired_zone_roots.is_empty(), "External free retained an invalid typed-array slot")
	_check(is_instance_valid(source) and (source.get_node("Mesh") as MeshInstance3D).mesh != null,
		"Destination shutdown released active source-world resources")
	service._retire_zone_root(source)
	await _drain(service)
	_check(not is_instance_valid(source), "Normal source retirement did not finish after two returns")
	RenderingServer.force_sync()

func _drain(service: Residency) -> void:
	var frames := 0
	while service.pending_zone_retirements > 0 and frames < 128:
		await process_frame
		frames += 1
	_check(service.pending_zone_retirements == 0, "Retirement failed to drain within its bounded fixture window")

func _zone(owner: Node3D, name_value: String) -> Node3D:
	var zone := Node3D.new()
	zone.name = name_value
	owner.add_child(zone)
	_mesh(zone, "Mesh")
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 5
	body.collision_mask = 3
	zone.add_child(body)
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	shape.shape = BoxShape3D.new()
	body.add_child(shape)
	return zone

func _mesh(parent: Node3D, name_value: String) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = name_value
	mesh.mesh = BoxMesh.new()
	mesh.material_override = StandardMaterial3D.new()
	parent.add_child(mesh)
	return mesh

func _validate(_node: Node) -> Dictionary:
	audits += 1
	return {"ok": true}

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)
