extends Node
class_name SeamlessWorldService

const WorldSectorManifest = preload("res://scripts/world_sector_manifest.gd")

signal boundary_transition_requested(source_zone: String, target_zone: String, edge_id: String)
signal sector_activated(zone_id: String)
signal sector_failed(zone_id: String, reason: String)

var host: Node
var streaming_service: Node
var current_sector := ""
var previous_sector := ""
var pending_transition: Dictionary = {}
var discovered_sectors: Dictionary = {}
var active_sector_ids: Array[String] = []
var transition_count := 0
var failed_transition_count := 0
var last_transition: Dictionary = {}
var last_world_position := Vector3.ZERO
var cooldown := 0.0

func configure(runtime_host: Node, stream_service: Node) -> void:
	host = runtime_host
	streaming_service = stream_service
	process_mode = Node.PROCESS_MODE_ALWAYS

func open_edges_for(zone_id: String) -> Dictionary:
	return WorldSectorManifest.open_edges(zone_id)

func is_exterior_route(source_zone: String, target_zone: String) -> bool:
	return WorldSectorManifest.is_exterior(source_zone) \
		and WorldSectorManifest.is_exterior(target_zone) \
		and not WorldSectorManifest.edge_between(source_zone, target_zone).is_empty()

func is_interior_route(source_zone: String, target_zone: String) -> bool:
	var source := WorldSectorManifest.canonical(source_zone)
	var target := WorldSectorManifest.canonical(target_zone)
	return not is_exterior_route(source, target) \
		and target in WorldSectorManifest.neighbors(source) \
		and (not WorldSectorManifest.is_exterior(source) or not WorldSectorManifest.is_exterior(target))

func should_suppress_exterior_gate(source_zone: String, target_zone: String) -> bool:
	return is_exterior_route(source_zone, target_zone)

func should_use_physical_door(source_zone: String, target_zone: String) -> bool:
	return is_interior_route(source_zone, target_zone)

func update_player(actor: Node3D, zone_id: String, delta: float) -> bool:
	if actor == null or not is_instance_valid(actor):
		return false
	cooldown = maxf(cooldown - delta, 0.0)
	if not pending_transition.is_empty():
		return true
	var source := WorldSectorManifest.canonical(zone_id)
	if current_sector != source:
		on_zone_activated(source, actor.global_position)
	if cooldown > 0.0 or not WorldSectorManifest.is_exterior(source):
		return false
	var bounds := _zone_bounds(source)
	var edge := WorldSectorManifest.edge_for_position(source, actor.global_position, bounds, 0.85)
	if edge.is_empty():
		return false
	var target := WorldSectorManifest.canonical(str(edge.get("target", "")))
	if target == "" or host == null or not host.has_method("request_seamless_boundary_transition"):
		return false
	var raw_arrival: Array = edge.get("arrival", [0.0, 0.9, 12.0])
	var arrival := Vector3(float(raw_arrival[0]), float(raw_arrival[1]), float(raw_arrival[2]))
	if streaming_service != null and streaming_service.has_method("request_zone"):
		streaming_service.request_zone(target)
	pending_transition = {
		"source": source,
		"target": target,
		"edge": str(edge.get("id", "")),
		"arrival": arrival,
		"requested_at_usec": Time.get_ticks_usec(),
	}
	var accepted: bool = host.request_seamless_boundary_transition(target, arrival, str(edge.get("id", "")))
	if not accepted:
		pending_transition.clear()
		return false
	# The host can complete a synchronous local transition. Do not leave a
	# stale pending lock after the new sector has already been activated.
	if current_sector == target:
		pending_transition.clear()
	transition_count += 1
	last_transition = pending_transition.duplicate(true)
	boundary_transition_requested.emit(source, target, str(edge.get("id", "")))
	return true

func on_zone_activated(zone_id: String, local_position: Vector3 = Vector3.ZERO) -> void:
	var normalized := WorldSectorManifest.canonical(zone_id)
	previous_sector = current_sector if current_sector != normalized else previous_sector
	current_sector = normalized
	last_world_position = WorldSectorManifest.local_to_world(normalized, local_position)
	if normalized not in discovered_sectors:
		discovered_sectors[normalized] = true
	if normalized not in active_sector_ids:
		active_sector_ids.append(normalized)
	active_sector_ids = _kept_sector_ids(normalized)
	pending_transition.clear()
	cooldown = 0.25
	last_transition["state"] = "active"
	last_transition["activated_at_usec"] = Time.get_ticks_usec()
	if streaming_service != null:
		for neighbor in WorldSectorManifest.neighbors(normalized):
			if streaming_service.has_method("request_zone"):
				streaming_service.request_zone(neighbor)
		if streaming_service.has_method("retire_unneeded_zones"):
			streaming_service.retire_unneeded_zones(active_sector_ids)
	sector_activated.emit(normalized)

func on_zone_failed(zone_id: String, reason: String) -> void:
	failed_transition_count += 1
	pending_transition.clear()
	last_transition["state"] = "failed"
	last_transition["reason"] = reason
	sector_failed.emit(WorldSectorManifest.canonical(zone_id), reason)

func world_position_for_player(actor: Node3D, zone_id: String = "") -> Vector3:
	var source := WorldSectorManifest.canonical(zone_id if zone_id != "" else current_sector)
	if actor == null or not is_instance_valid(actor):
		return last_world_position
	last_world_position = WorldSectorManifest.local_to_world(source, actor.global_position)
	return last_world_position

func local_position_for(zone_id: String, world_position: Vector3) -> Vector3:
	return WorldSectorManifest.world_to_local(zone_id, world_position)

func save_state() -> Dictionary:
	return {
		"current_sector": current_sector,
		"previous_sector": previous_sector,
		"discovered_sectors": discovered_sectors.duplicate(true),
		"last_world_position": [last_world_position.x, last_world_position.y, last_world_position.z],
	}

func load_state(data: Dictionary) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	current_sector = WorldSectorManifest.canonical(str(data.get("current_sector", current_sector)))
	previous_sector = WorldSectorManifest.canonical(str(data.get("previous_sector", previous_sector)))
	discovered_sectors = data.get("discovered_sectors", {}).duplicate(true) if typeof(data.get("discovered_sectors", {})) == TYPE_DICTIONARY else {}
	var raw_position: Array = data.get("last_world_position", [])
	if raw_position.size() >= 3:
		last_world_position = Vector3(float(raw_position[0]), float(raw_position[1]), float(raw_position[2]))

func snapshot() -> Dictionary:
	return {
		"current_sector": current_sector,
		"previous_sector": previous_sector,
		"pending_transition": pending_transition.duplicate(true),
		"active_sector_ids": active_sector_ids.duplicate(),
		"discovered_count": discovered_sectors.size(),
		"transition_count": transition_count,
		"failed_transition_count": failed_transition_count,
		"last_world_position": [last_world_position.x, last_world_position.y, last_world_position.z],
	}

func _zone_bounds(zone_id: String) -> Vector2:
	if host != null and host.has_method("get_zone_half_extents"):
		return host.get_zone_half_extents(zone_id)
	return WorldSectorManifest.bounds(zone_id)

func _kept_sector_ids(zone_id: String) -> Array[String]:
	var kept: Array[String] = [zone_id]
	for neighbor in WorldSectorManifest.neighbors(zone_id):
		if neighbor not in kept:
			kept.append(neighbor)
	return kept
