extends Node
class_name ZoneStreamingService

## Non-blocking resource request layer. Runtime-built zones can request an
## empty path and complete immediately; authored PackedScenes can opt into the
## same API without changing transition ownership in game.gd.
signal zone_progress(zone_id: String, progress: float)
signal zone_ready(zone_id: String, resource: Resource)
signal zone_failed(zone_id: String, reason: String)
signal zone_activation_requested(zone_id: String, arrival_id: String)

var requests: Dictionary = {}
var owner_node: Node

func setup(owner: Node) -> void:
	owner_node = owner
	process_mode = Node.PROCESS_MODE_ALWAYS

func request_zone(zone_id: String, resource_path: String = "") -> void:
	var id := zone_id.strip_edges().to_lower()
	if id == "":
		return
	if requests.has(id) and str(requests[id].get("state", "")) in ["loading", "ready"]:
		return
	if resource_path == "":
		requests[id] = {"state": "ready", "progress": 1.0, "resource": null, "path": ""}
		zone_progress.emit(id, 1.0)
		zone_ready.emit(id, null)
		return
	if not ResourceLoader.exists(resource_path):
		requests[id] = {"state": "failed", "progress": 0.0, "resource": null, "path": resource_path}
		zone_failed.emit(id, "Missing resource: %s" % resource_path)
		return
	var error := ResourceLoader.load_threaded_request(resource_path)
	if error != OK:
		requests[id] = {"state": "failed", "progress": 0.0, "resource": null, "path": resource_path}
		zone_failed.emit(id, "Threaded request failed: %s" % error_string(error))
		return
	requests[id] = {"state": "loading", "progress": 0.0, "resource": null, "path": resource_path}
	zone_progress.emit(id, 0.0)

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
	if requests.has(id) and str(requests[id].get("state", "")) == "loading":
		requests.erase(id)

func retire_unneeded_zones(keep_ids: Array[String]) -> void:
	var keep := {}
	for id in keep_ids:
		keep[str(id).to_lower()] = true
	for id in requests.keys():
		if not keep.has(str(id).to_lower()):
			requests.erase(id)

func _process(_delta: float) -> void:
	for id in requests.keys():
		var request: Dictionary = requests[id]
		if str(request.get("state", "")) != "loading":
			continue
		var path := str(request.get("path", ""))
		var progress := []
		var status := ResourceLoader.load_threaded_get_status(path, progress)
		var value := float(progress[0]) if not progress.is_empty() else 0.0
		request["progress"] = value
		requests[id] = request
		zone_progress.emit(str(id), value)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var resource := ResourceLoader.load_threaded_get(path)
			request["state"] = "ready"
			request["progress"] = 1.0
			request["resource"] = resource
			requests[id] = request
			zone_ready.emit(str(id), resource)
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			request["state"] = "failed"
			requests[id] = request
			zone_failed.emit(str(id), "Unable to load %s" % path)
