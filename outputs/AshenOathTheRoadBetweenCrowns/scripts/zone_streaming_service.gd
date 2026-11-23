extends Node
class_name ZoneStreamingService

## Prefetches real scene/builder resources without creating a second world.
## Readiness covers resource preparation, not activation or collision readiness.
signal zone_progress(zone_id: String, progress: float)
signal zone_ready(zone_id: String, resource: Resource)
signal zone_failed(zone_id: String, reason: String)
signal zone_activation_requested(zone_id: String, arrival_id: String)

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
var focused_destination := ""
const STATUS_POLL_INTERVAL := 0.10
const RESOURCE_TIMEOUT_MSEC := 30000

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
	return WorldSectorManifest.neighbors(zone_id,owner_node.get("story_state") if is_instance_valid(owner_node) else null)

func prewarm_neighbors(zone_id: String) -> void:
	# Proximity scheduling owns decoded resources. Merely mounting a shared pack
	# must not start importing every neighboring scene on the arrival frame.
	var keep_ids: Array[String] = []
	keep_ids.append(zone_id.strip_edges().to_lower())
	keep_ids.append_array(neighbors(zone_id))
	retire_unneeded_zones(keep_ids)

func set_focus_destination(zone_id: String) -> void:
	if focused_destination == zone_id:
		return
	focused_destination = zone_id
	set_process(true)

func get_resource(zone_id: String) -> Resource:
	return requests.get(zone_id.strip_edges().to_lower(), {}).get("resource") as Resource

func request_zone(zone_id: String, resource_path: String = "", additional_paths: Array[String] = [], exact_paths: bool = false) -> void:
	var id := zone_id.strip_edges().to_lower()
	if id == "":
		return
	if is_instance_valid(owner_node) and not preload("res://scripts/campaign_revision.gd").zone_available(id,owner_node.get("story_state")): return
	var canonical := "bandit_road" if id == "long_road" else id
	var desired: Array[String] = [resource_path]
	if resource_path == "":
		desired = SceneCatalog.resource_paths(canonical, SceneCatalog.prepared_road_layers(canonical)) if exact_paths else SceneCatalog.resource_paths(canonical)
		desired.append_array(CompositionRouter.resource_paths(canonical) + additional_paths)
	var previous: Dictionary = requests.get(id, {})
	var reusable := str(previous.get("state", "")) in ["waiting_pack", "loading", "ready"]
	# A portal request may reuse a broader preparation. An exact road request
	# replaces obsolete encounter inputs and adds every missing dependency.
	var paths: Array[String] = []
	if reusable and not exact_paths:
		paths.assign(previous.paths)
	for path: String in desired:
		if path not in paths: paths.append(path)
	if reusable and previous.paths == paths:
		return
	if paths.is_empty():
		if not reusable:
			requests[id] = {"state": "waiting_pack", "progress": 0.0}
		_fail_request(id, "No resource preparation registered for zone")
		return
	var resources: Dictionary = {}
	var current := str(previous.get("current_path", ""))
	if reusable:
		for path: String in paths:
			if previous.resources.has(path): resources[path] = previous.resources[path]
	if not reusable or current not in paths:
		_release_request(id)
		current = ""
	var progress := float(resources.size()) / float(paths.size())
	requests[id] = {"state": "waiting_pack" if current.is_empty() else "loading", "progress": progress,
		"resource": null, "paths": paths, "resources": resources, "current_path": current,
		"current_started_ms": int(previous.get("current_started_ms", 0)), "next_index": 0}
	var packs = owner_node.get("runtime_packs") if is_instance_valid(owner_node) else null
	if packs != null:
		for pack_id in packs.required_zone_packs(canonical):
			packs.request_pack(pack_id, 500)
	set_process(true)
	_begin_request(id)
	if get_state(id) != "failed": zone_progress.emit(id, progress)

func _begin_request(id: String) -> void:
	if not focused_destination.is_empty() and id != focused_destination:
		var explicit_journey := is_instance_valid(owner_node) and (not bool(owner_node.get("game_started")) or bool(owner_node.call("_journey_load_pending")))
		if not explicit_journey: return
	var packs = owner_node.get("runtime_packs") if is_instance_valid(owner_node) else null
	if packs != null and not packs.zone_packs_ready(id):
		var failures: Array[String] = packs.zone_pack_failures(id)
		if not failures.is_empty():
			_fail_request(id, "Required packs failed: %s" % ", ".join(failures))
		return
	var request: Dictionary = requests[id]
	if not str(request.get("current_path","")).is_empty(): return
	var index := int(request.next_index)
	while index < request.paths.size() and request.resources.has(request.paths[index]):
		index += 1
	request.next_index = index
	if index < request.paths.size():
		var path: String = request.paths[index]
		if not ResourceLoader.exists(path):
			_fail_request(id, "Missing resource: %s" % path)
			return
		var error: Error = resource_requests.request(path, self, id)
		if error != OK:
			_fail_request(id, "Unable to request %s: %s" % [path, error_string(error)])
			return
		request["current_path"] = path
		request["current_started_ms"] = Time.get_ticks_msec()
	request.state = "loading"

func request_zone_for_portal(zone_id: String) -> bool:
	var id := zone_id.strip_edges().to_lower()
	set_focus_destination(id)
	request_zone(id, str(AUTHORED_LAYER_PATHS.get(id, "")))
	return str(requests.get(id, {}).get("state", "")) in ["waiting_pack", "loading", "ready"]

func is_embedded_destination(zone_id: String) -> bool:
	return not AUTHORED_LAYER_PATHS.has(zone_id.strip_edges().to_lower())

func get_state(zone_id: String) -> String:
	return str(requests.get(zone_id.strip_edges().to_lower(), {}).get("state", ""))

func get_last_error(zone_id: String) -> String:
	return str(requests.get(zone_id.strip_edges().to_lower(), {}).get("error", ""))

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

func release_prepared_road(zone_id: String) -> void:
	cancel_request(zone_id)
	if focused_destination == zone_id:
		set_focus_destination("")

func clear_requests() -> void:
	for id in requests:
		_release_request(str(id), true)
	requests.clear()
	_status_poll_accumulator = 0.0
	focused_destination = ""
	set_process(false)

func _release_request(id: String, drain: bool = false) -> void:
	var active := str(requests.get(id, {}).get("current_path", ""))
	if not active.is_empty(): resource_requests.release(active, self, id, drain)

func _fail_request(id: String, reason: String) -> void:
	_release_request(id)
	requests[id] = {"state": "failed", "progress": 0.0, "error": reason}
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
		var request: Dictionary = requests.get(id, {})
		if str(request.get("state", "")) == "waiting_pack":
			_begin_request(str(id))
			pending = true
		if get_state(str(id)) != "loading":
			continue
		pending = true
		var partial := 0.0
		var path := str(request.current_path)
		if not path.is_empty():
			var progress: Array = []
			var status: int = resource_requests.status(path, progress)
			if status == ResourceLoader.THREAD_LOAD_LOADED:
				var loaded: Resource = resource_requests.take(path, self, str(id))
				request["current_path"] = ""
				if loaded == null:
					_fail_request(str(id), "Unable to load %s" % path)
					continue
				request.resources[path] = loaded
			elif status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				if Time.get_ticks_msec() - int(request.current_started_ms) >= RESOURCE_TIMEOUT_MSEC:
					_fail_request(str(id), "Resource preparation timed out: %s" % path)
					continue
				partial = float(progress[0]) if not progress.is_empty() else 0.0
			else:
				_fail_request(str(id), "Unable to load %s" % path)
				continue
		var complete: bool = request.resources.size() == request.paths.size()
		var value := (float(request.resources.size()) + partial) / float(request.paths.size())
		var previous_value := float(request.get("progress", 0.0))
		request["progress"] = value
		if complete:
			request["state"] = "ready"
			request["resource"] = request.resources[request.paths[0]]
		if absf(value - previous_value) >= 0.001:
			zone_progress.emit(str(id), value)
		if not is_same(requests.get(id), request): continue
		if complete:
			zone_ready.emit(str(id), request.resource)
		elif str(request.current_path).is_empty():
			_begin_request(str(id))
	if not pending:
		set_process(false)

func _exit_tree() -> void:
	clear_requests()

func _load_topology() -> void:
	# Resource prefetch, traversal and the atlas share the same connection owner.
	topology.clear()
	for id: String in WorldSectorManifest.all_ids():
		topology[id] = WorldSectorManifest.neighbors(id)
