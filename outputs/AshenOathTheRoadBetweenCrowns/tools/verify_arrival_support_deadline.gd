extends SceneTree

## No world or actors: actual cached SubViewport physics and the production
## coordinator's advance_transition(), including its strict support ownership.
const Coordinator = preload("res://scripts/zone_runtime_coordinator.gd")
const Residency = preload("res://scripts/zone_residency_service.gd")
const Spatial = preload("res://scripts/zone_spatial_service.gd")
const Surface = preload("res://scripts/spatial_surface_contract.gd")

class FixtureHud extends Node:
	var notices: Array[String] = []
	func toast(text: String) -> void:
		notices.append(text)

class FixtureHost extends Node3D:
	var zone_transition_pending := true
	var zone_transition_frames := 0
	var pending_spawn_position := Vector3(-5.874103, 0, 26.068644)
	var current_zone_id := "wychwood"
	var player := CharacterBody3D.new()
	var spatial_service: Node
	var zone_root: Node3D
	var hud := FixtureHud.new()
	var recovery_requests: Array[String] = []
	var metrics: Array[Dictionary] = []
	var probes: Array[Vector3] = []
	func _grounded_spawn_position(candidate: Vector3) -> Variant:
		probes.append(candidate)
		var hit: Dictionary = Surface.support_hit(get_world_3d().direct_space_state,
			candidate + Vector3.UP * 6, candidate - Vector3.UP * 12,
			[player.get_rid()], zone_root)
		return null if hit.is_empty() else Vector3(candidate.x, float(hit.position.y) + 0.95, candidate.z)
	func _record_loading_metrics(record: Dictionary) -> void:
		metrics.append(record)
	func _recover_failed_zone_load(previous_zone: String) -> void:
		recovery_requests.append(previous_zone)
		zone_transition_pending = false

class ObservedCoordinator extends Coordinator:
	var arrivals: Array[Vector3] = []
	var source_recoveries: Array[Vector3] = []
	# Observe the readiness boundary without constructing unrelated HUD, audio,
	# quest and encounter services. The support/recovery decision is inherited.
	func _complete_supported_arrival(grounded: Vector3) -> void:
		arrivals.append(grounded)
		host.player.position = grounded
		host.zone_transition_pending = false
	func _complete_source_recovery(grounded: Vector3) -> void:
		source_recoveries.append(grounded)
		host.player.position = grounded
		host.zone_transition_pending = false

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for initial_frames in [0, 1]:
		await _expired_recovery_case(initial_frames, true)
		await _expired_recovery_case(initial_frames, false)
	await _primary_readiness_case()
	await _primary_after_first_frame_recovery_case()
	await _normal_grace_case()
	await _source_recovery_case(true)
	await _source_recovery_case(false)
	for failure: String in failures:
		push_error(failure)
	print("ARRIVAL SUPPORT DEADLINE: %s checks=%d (real cached physics; first/second-frame expiry, primary readiness, bounded recovery and source preservation)" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _fixture(destination_floor: bool) -> Dictionary:
	var host := FixtureHost.new()
	root.add_child(host)
	host.add_child(host.player)
	host.add_child(host.hud)
	host.player.position = Vector3(6.125897, 0.95, -23.931356)
	var residency := Residency.new()
	host.add_child(residency)
	var view := SubViewport.new()
	view.size = Vector2i(2, 2)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.add_child(view)
	var zone := Node3D.new()
	zone.process_mode = Node.PROCESS_MODE_DISABLED
	view.add_child(zone)
	host.zone_root = zone
	var spatial := Spatial.new()
	zone.add_child(spatial)
	spatial.configure("wychwood", 0.0, Vector2(22, 17))
	host.spatial_service = spatial
	_floor(zone, Vector3(0, -0.1, 0), Vector3(44, 0.2, 34), 1 if destination_floor else 0)
	# A source-owned retained road supports the exact cold point, but must not
	# masquerade as confirmed destination support, even when recovery is absent.
	var source := Node3D.new()
	host.add_child(source)
	_floor(source, Vector3(0, -0.1, 20), Vector3(44, 0.2, 20), 1)
	residency._cache_route_zone("wychwood", zone, [], 17)
	var retiring_world: World3D = view.find_world_3d()
	view.own_world_3d = false
	retiring_world = null
	_check(residency._activate_cached_zone("wychwood") == zone, "Legitimate cached destination was not reused")
	var coordinator := ObservedCoordinator.new(host)
	coordinator.source_zone = "greyfen"
	for _index in range(3):
		await physics_frame
	_check(zone.get_world_3d() == host.get_world_3d(), "Prepared destination did not join the active physics world")
	return {"host":host, "coordinator":coordinator, "source":source, "zone":zone}

func _expired_recovery_case(initial_frames: int, destination_floor: bool) -> void:
	var context: Dictionary = await _fixture(destination_floor)
	var host: Node = context.host
	var coordinator: RefCounted = context.coordinator
	var source_position: Vector3 = host.player.position
	host.zone_transition_frames = initial_frames
	coordinator._support_deadline_msec = Time.get_ticks_msec() - 1
	coordinator.advance_transition()
	if initial_frames == 0 and destination_floor:
		_check(coordinator.arrivals.is_empty() and host.zone_transition_pending, "First-frame recovery bypassed the two-frame readiness boundary")
		_check(coordinator._arrival_recovered, "Expired first frame did not record confirmed recovery")
		coordinator.advance_transition()
	var prefix := "expired frame%d/floor%s: " % [initial_frames + 1, destination_floor]
	_check(host.probes.size() >= 2 and host.probes[1].z == 16.0, prefix + "existing nearest_safe recovery was not probed before timeout")
	if destination_floor:
		_check(coordinator.arrivals.size() == 1 and coordinator.arrivals[0].z == 16.0, prefix + "valid actual destination floor was rolled back")
		_check(coordinator._arrival_recovered and coordinator.failure_count == 0 and host.recovery_requests.is_empty(), prefix + "valid recovery retained failure/rollback state")
	else:
		_check(coordinator.arrivals.is_empty() and coordinator.failure_count == 1 and host.recovery_requests == ["greyfen"], prefix + "unrecoverable floor did not use bounded source rollback")
		_check(not coordinator._arrival_recovered and host.player.position == source_position, prefix + "unsupported transition invented support or moved the source player")
		_check(not host.zone_transition_pending and host.metrics.size() == 1 and host.metrics[0].error == "arrival_support_missing", prefix + "unrecoverable transition did not publish its failure state")
	_check(is_instance_valid(context.source) and is_instance_valid(context.zone), prefix + "support decision destroyed a legitimate cached/source world")
	await _retire(context)

func _primary_readiness_case() -> void:
	var context: Dictionary = await _fixture(true)
	var host: Node = context.host
	var coordinator: RefCounted = context.coordinator
	host.pending_spawn_position = Vector3(0, 0, 10)
	coordinator._support_deadline_msec = Time.get_ticks_msec() - 1
	coordinator.advance_transition()
	_check(coordinator.arrivals.is_empty() and host.zone_transition_pending, "Confirmed primary support bypassed first-frame readiness")
	coordinator.advance_transition()
	_check(coordinator.arrivals.size() == 1 and coordinator.arrivals[0].z == 10.0, "Confirmed primary support was replaced by an emergency recovery point")
	_check(not coordinator._arrival_recovered and coordinator.failure_count == 0, "Confirmed primary arrival was labelled recovered/failed")
	await _retire(context)

func _normal_grace_case() -> void:
	var context: Dictionary = await _fixture(true)
	var host: Node = context.host
	var coordinator: RefCounted = context.coordinator
	coordinator._support_deadline_msec = Time.get_ticks_msec() + 10000
	for _index in range(3):
		coordinator.advance_transition()
	_check(host.probes.size() == 3 and host.zone_transition_pending and coordinator.arrivals.is_empty(), "Unexpired support lost its original three-frame collision grace")
	coordinator.advance_transition()
	_check(coordinator.arrivals.size() == 1 and coordinator._arrival_recovered, "Normal fourth-frame recovery no longer completes")
	await _retire(context)

func _primary_after_first_frame_recovery_case() -> void:
	var context: Dictionary = await _fixture(true)
	var host: Node = context.host
	var coordinator: RefCounted = context.coordinator
	coordinator._support_deadline_msec = Time.get_ticks_msec() - 1
	coordinator.advance_transition()
	_check(coordinator._arrival_recovered and host.zone_transition_pending and coordinator.arrivals.is_empty(), "First-frame fallback did not wait at the normal readiness boundary")
	# A queued collider can register between the two readiness probes. Accept
	# the now-confirmed authored position without retaining a stale recovery flag.
	_floor(context.zone, Vector3(0, -0.1, 26), Vector3(44, 0.2, 4), 1)
	for _index in range(3):
		await physics_frame
	coordinator.advance_transition()
	_check(coordinator.arrivals.size() == 1 and coordinator.arrivals[0].z == host.pending_spawn_position.z, "Newly confirmed primary support lost the authored arrival")
	_check(not coordinator._arrival_recovered and coordinator.failure_count == 0, "Primary support inherited an earlier frame's recovery state")
	await _retire(context)

func _source_recovery_case(destination_floor: bool) -> void:
	var context: Dictionary = await _fixture(destination_floor)
	var host: Node = context.host
	var coordinator: RefCounted = context.coordinator
	coordinator._restoring_source = true
	host.zone_transition_frames = 1
	coordinator._support_deadline_msec = Time.get_ticks_msec() - 1
	coordinator.advance_transition()
	_check(host.probes.size() == 2, "Source restoration did not try existing recovery before its deadline")
	if destination_floor:
		_check(coordinator.source_recoveries.size() == 1 and coordinator.arrivals.is_empty() and coordinator._arrival_recovered, "Confirmed source recovery used the wrong readiness finalizer")
	else:
		_check(coordinator.source_recoveries.is_empty() and coordinator.arrivals.is_empty() and not host.zone_transition_pending, "Unsupported source restoration invented ground or kept waiting")
		_check(not coordinator._restoring_source and not host.hud.notices.is_empty(), "Unsupported source restoration hid its bounded failure")
	await _retire(context)

func _floor(parent: Node3D, position: Vector3, size: Vector3, layer: int) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.position = position
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)

func _retire(context: Dictionary) -> void:
	context.coordinator.host = null
	context.host.free()
	for _index in range(2):
		await process_frame

func _check(valid: bool, detail: String) -> void:
	checks += 1
	if not valid:
		failures.append(detail)
