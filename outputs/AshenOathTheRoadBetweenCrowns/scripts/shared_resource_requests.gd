extends RefCounted

## One engine request per path, with independent claims for each consumer.
## A cancelled consumer cannot discard another consumer's completed resource.
static var _instance: WeakRef
var _requests: Dictionary = {}
var _last_orphan_sweep_frame := -1

static func acquire() -> RefCounted:
	var current: RefCounted = _instance.get_ref() if _instance != null else null
	if current == null:
		current = load("res://scripts/shared_resource_requests.gd").new()
		_instance = weakref(current)
	return current

func request(path: String, owner: Object, token: String = "") -> Error:
	var frame := Engine.get_process_frames()
	# Recheck an earlier claim for the requested path even within a frame.
	var sweep: Array = [path] if _requests.has(path) else []
	if frame != _last_orphan_sweep_frame:
		_last_orphan_sweep_frame = frame
		sweep = _requests.keys()
	for known_path: String in sweep:
		_collect_finished_orphan(known_path)
	if not _requests.has(path):
		var error := ResourceLoader.load_threaded_request(path)
		if error != OK:
			return error
		_requests[path] = {"owners": {}, "status": ResourceLoader.THREAD_LOAD_IN_PROGRESS, "resource": null, "progress": 0.0}
	_requests[path]["owners"][_claim(owner, token)] = weakref(owner)
	return OK

func status(path: String, progress: Array = []) -> int:
	if not _requests.has(path):
		return ResourceLoader.THREAD_LOAD_INVALID_RESOURCE
	var record: Dictionary = _requests[path]
	preload("res://scripts/core/threaded_resource_poll.gd").refresh(path, record)
	if progress.is_empty():
		progress.append(record.progress)
	else:
		progress[0] = record.progress
	return int(record.status)

func take(path: String, owner: Object, token: String = "", wait: bool = false) -> Resource:
	if not _requests.has(path):
		return null
	var state := status(path)
	if state == ResourceLoader.THREAD_LOAD_IN_PROGRESS and wait:
		var record: Dictionary = _requests[path]
		record.resource = ResourceLoader.load_threaded_get(path)
		record.status = ResourceLoader.THREAD_LOAD_LOADED if record.resource != null else ResourceLoader.THREAD_LOAD_FAILED
	var result: Resource = _requests[path].resource
	release(path, owner, token)
	return result

func load_now(path: String, owner: Object) -> Resource:
	# Join a real prefetch, but do not enqueue a worker just to block on it.
	# ResourceLoader's normal cache still shares synchronous decoded resources.
	if not _requests.has(path):
		return ResourceLoader.load(path)
	if request(path, owner) != OK:
		return null
	return take(path, owner, "", true)

func release(path: String, owner: Object, token: String = "", drain: bool = false) -> void:
	if not _requests.has(path):
		return
	var record: Dictionary = _requests[path]
	record.owners.erase(_claim(owner, token))
	if not record.owners.is_empty():
		return
	if status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		if not drain:
			return # The worker still owns its engine request until it finishes.
		ResourceLoader.load_threaded_get(path)
	_requests.erase(path)

func _collect_finished_orphan(path: String) -> void:
	var record: Dictionary = _requests[path]
	for key in record.owners.keys():
		if record.owners[key].get_ref() == null:
			record.owners.erase(key)
	if record.owners.is_empty() and status(path) != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		_requests.erase(path)

func _claim(owner: Object, token: String) -> String:
	return "%d:%s" % [owner.get_instance_id(), token]

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for path in _requests:
			if int(_requests[path].status) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				ResourceLoader.load_threaded_get(path)
		_requests.clear()
