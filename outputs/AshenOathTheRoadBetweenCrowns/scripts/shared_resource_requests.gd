extends RefCounted

## One engine request per path, with independent claims for each consumer.
## A cancelled consumer cannot discard another consumer's completed resource.
static var _instance: WeakRef
var _requests: Dictionary = {}

static func acquire() -> RefCounted:
	var current: RefCounted = _instance.get_ref() if _instance != null else null
	if current == null:
		current = load("res://scripts/shared_resource_requests.gd").new()
		_instance = weakref(current)
	return current

func request(path: String, owner: Object, token: String = "") -> Error:
	_collect_finished_orphans()
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
	if int(record.status) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		var values: Array = []
		record.status = ResourceLoader.load_threaded_get_status(path, values)
		record.progress = float(values[0]) if not values.is_empty() else 0.0
		if int(record.status) == ResourceLoader.THREAD_LOAD_LOADED:
			record.resource = ResourceLoader.load_threaded_get(path)
			record.progress = 1.0
			if record.resource == null:
				record.status = ResourceLoader.THREAD_LOAD_FAILED
	if not progress.is_empty():
		progress[0] = record.progress
	else:
		progress.append(record.progress)
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
	if record.owners.is_empty():
		var state := status(path)
		if state == ResourceLoader.THREAD_LOAD_IN_PROGRESS and drain:
			ResourceLoader.load_threaded_get(path)
		elif state == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return # The engine cannot cancel; consume it on the next poll or shutdown.
		_requests.erase(path)

func _collect_finished_orphans() -> void:
	for path in _requests.keys():
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
