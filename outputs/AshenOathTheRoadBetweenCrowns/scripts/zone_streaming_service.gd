extends Node
class_name ZoneStreamingService

## Prefetches real scene/builder resources without creating a second world.
## Readiness covers resource preparation, not activation or collision readiness.
signal zone_progress(zone_id: String, progress: float)
signal zone_ready(zone_id: String, resource: Resource)
signal zone_failed(zone_id: String, reason: String)
signal zone_activation_requested(zone_id: String, arrival_id: String)

const TOPOLOGY_PATH := "res://zone_streaming_topology.json"
const SharedResourceRequests = preload("res://scripts/shared_resource_requests.gd")
const SceneCatalog = preload("res://scripts/zone_scene_catalog.gd")
const CompositionRouter = preload("res://scripts/zone_composition_router.gd")
const AUTHORED_LAYER_PATHS := {
	"greyfen": "res://scenes/runtime/greyfen_gameplay_core.tscn",
	"wychwood": "res://scenes/zones/wychwood_gameplay.tscn",
	"cemetery": "res://scenes/zones/cemetery_gameplay.tscn",
}
const EMBEDDED_ZONE_IDS := [
	"greyfen", "wychwood", "cemetery", "ruins", "deep_wood", "long_road", "bandit_road",
	"old_mill", "burned_farmstead", "marsh_crossing",
	"vargan_approach", "vargan_court", "record_hall", "undercroft", "assembly", "hart_glade",
]

var requests: Dictionary = {}
var owner_node: Node
var topology: Dictionary = {}
var resource_requests = SharedResourceRequests.acquire()
var _status_poll_accumulator := 0.0
const STATUS_POLL_INTERVAL := 0.10

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_topology()
	set_process(false)

func setup(owner: Node) -> void:
	owner_node = owner
	process_mode = Node.PROCESS_MODE_ALWAYS
	if topology.is_empty():
		_load_topology()

func neighbors(zone_id: String) -> Array[String]:
	var result: Array[String] = []
	var normalized := zone_id.strip_edges().to_lower()
	for value in topology.get(normalized, []):
		result.append(str(value))
	return result

func prewarm_neighbors(zone_id: String) -> void:
	for neighbor in neighbors(zone_id):
		request_zone(neighbor)
	var keep_ids: Array[String] = []
	keep_ids.append(zone_id.strip_edges().to_lower())
	keep_ids.append_array(neighbors(zone_id))
	retire_unneeded_zones(keep_ids)

func get_resource(zone_id: String) -> Resource:
	return requests.get(zone_id.strip_edges().to_lower(), {}).get("resource") as Resource

func request_zone(zone_id: String, resource_path: String = "") -> void:
	var id := zone_id.strip_edges().to_lower()
	if id == "":
		return
	if requests.has(id) and str(requests[id].get("state", "")) in ["waiting_pack", "loading", "ready"]:
		return
	var canonical := "bandit_road" if id == "long_road" else id
	var paths: Array[String] = [resource_path] if resource_path != "" else SceneCatalog.resource_paths(canonical)
	if resource_path == "":
		paths.append_array(CompositionRouter.resource_paths(canonical))
	if paths.is_empty():
		requests[id] = {"state": "failed", "progress": 0.0}
		zone_failed.emit(id, "No resource preparation registered for zone")
		return
	requests[id] = {"state": "waiting_pack", "progress": 0.0, "resource": null, "paths": paths, "resources": {}}
	var packs = owner_node.get("runtime_packs") if is_instance_valid(owner_node) else null
	if packs != null:
		for pack_id in packs.required_zone_packs(canonical):
			packs.request_pack(pack_id, 500)
	set_process(true)
	_begin_request(id)
	zone_progress.emit(id, 0.0)

func _begin_request(id: String) -> void:
	var packs = owner_node.get("runtime_packs") if is_instance_valid(owner_node) else null
	if packs != null and not packs.zone_packs_ready(id):
		var failures: Array[String] = packs.zone_pack_failures(id)
		if not failures.is_empty():
			_fail_request(id, "Required packs failed: %s" % ", ".join(failures))
		return
	var request: Dictionary = requests[id]
	for path in request.paths:
		if not ResourceLoader.exists(path):
			_fail_request(id, "Missing resource: %s" % path)
			return
		var error: Error = resource_requests.request(path, self, id)
		if error != OK:
			_fail_request(id, "Unable to request %s: %s" % [path, error_string(error)])
			return
	request.state = "loading"

func request_zone_for_portal(zone_id: String) -> bool:
	var id := zone_id.strip_edges().to_lower()
	request_zone(id, str(AUTHORED_LAYER_PATHS.get(id, "")))
	return str(requests.get(id, {}).get("state", "")) in ["waiting_pack", "loading", "ready"]

func is_embedded_destination(zone_id: String) -> bool:
	return not AUTHORED_LAYER_PATHS.has(zone_id.strip_edges().to_lower())

func get_state(zone_id: String) -> String:
	return str(requests.get(zone_id.strip_edges().to_lower(), {}).get("state", ""))

func get_progress(zone_id: String) -> float:
	return clampf(float(requests.get(zone_id.strip_edges().to_lower(), {}).get("progress", 0.0)), 0.0, 1.0)

func is_ready(zone_id: String) -> bool:
	return str(requests.get(zone_id.strip_edges().to_lower(), {}).get("state", "")) == "ready"

func activate_zone(zone_id: String, arrival_id: String = "") -> bool:
	var id := zone_id.strip_edges().to_lower()
	if not is_ready(id):
		return false
	zone_activation_requested.emit(id, arrival_id)
	return true

func cancel_request(zone_id: String) -> void:
	var id := zone_id.strip_edges().to_lower()
	if requests.has(id):
		_release_request(id)
		requests.erase(id)

func clear_requests() -> void:
	for id in requests:
		_release_request(str(id), true)
	requests.clear()
	_status_poll_accumulator = 0.0
	set_process(false)

func _release_request(id: String, drain: bool = false) -> void:
	for path in requests.get(id, {}).get("paths", []):
		resource_requests.release(str(path), self, id, drain)

func _fail_request(id: String, reason: String) -> void:
	_release_request(id)
	requests[id]["state"] = "failed"
	zone_failed.emit(id, reason)

func retire_unneeded_zones(keep_ids: Array[String]) -> void:
	var keep := {}
	for id in keep_ids:
		keep[str(id).to_lower()] = true
	for id in requests.keys():
		if not keep.has(str(id).to_lower()):
			_release_request(str(id))
			requests.erase(id)

func _process(delta: float) -> void:
	# Threaded loading does not need a status query on every rendered frame. On
	# Compatibility/ANGLE, polling and emitting progress each frame can compete
	# with the active zone even though the loader itself runs off the main thread.
	_status_poll_accumulator += delta
	if _status_poll_accumulator < STATUS_POLL_INTERVAL:
		return
	_status_poll_accumulator = 0.0
	var pending := false
	for id in requests.keys():
		var request: Dictionary = requests[id]
		if str(request.get("state", "")) == "waiting_pack":
			_begin_request(str(id))
			pending = true
		if str(request.get("state", "")) != "loading":
			continue
		pending = true
		var total := 0.0
		var complete := true
		var failed := false
		for path in request.paths:
			if request.resources.has(path):
				total += 1.0
				continue
			var progress: Array = []
			var status: int = resource_requests.status(path, progress)
			total += float(progress[0]) if not progress.is_empty() else 0.0
			if status == ResourceLoader.THREAD_LOAD_LOADED:
				request.resources[path] = resource_requests.take(path, self, str(id))
			elif status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				complete = false
			else:
				_fail_request(str(id), "Unable to load %s" % path)
				failed = true
				break
		if failed:
			continue
		var value := total / maxf(1.0, request.paths.size())
		var previous_value := float(request.get("progress", 0.0))
		request["progress"] = value
		requests[id] = request
		if absf(value - previous_value) >= 0.001:
			zone_progress.emit(str(id), value)
		if complete:
			var resource: Resource = request.resources[request.paths[0]]
			request["state"] = "ready"
			request["progress"] = 1.0
			request["resource"] = resource
			requests[id] = request
			zone_ready.emit(str(id), resource)
	if not pending:
		set_process(false)

func _exit_tree() -> void:
	clear_requests()

func _load_topology() -> void:
	if not FileAccess.file_exists(TOPOLOGY_PATH):
		topology = {}
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(TOPOLOGY_PATH))
	topology = parsed.get("topology", {}) if typeof(parsed) == TYPE_DICTIONARY else {}
