extends RefCounted

const RESOURCE_TIMEOUT_MSEC := 30000

static func merged_paths(previous: Dictionary, desired: Array[String], reuse: bool) -> Array[String]:
	var paths: Array[String] = []
	if reuse:
		paths.assign(previous.paths)
	for path: String in desired:
		if path not in paths:
			paths.append(path)
	return paths

static func prepare(paths: Array[String], previous: Dictionary, reusable: bool) -> Dictionary:
	var resources: Dictionary = {}
	var current := str(previous.get("current_path", "")) if reusable else ""
	if current not in paths:
		current = ""
	if reusable:
		for path: String in paths:
			if previous.resources.has(path):
				resources[path] = previous.resources[path]
	return {
		"state": "waiting_pack" if current.is_empty() else "loading",
		"progress": float(resources.size()) / float(paths.size()),
		"resource": null, "paths": paths, "resources": resources,
		"current_path": current, "current_started_ms": int(previous.get("current_started_ms", 0)),
		"next_index": 0,
	}

static func next_path(request: Dictionary) -> String:
	var index := int(request.next_index)
	while index < request.paths.size() and request.resources.has(request.paths[index]):
		index += 1
	request.next_index = index
	return str(request.paths[index]) if index < request.paths.size() else ""

static func start_clock(request: Dictionary) -> void:
	request.current_started_ms = Time.get_ticks_msec()

static func poll(request: Dictionary, resources: RefCounted, owner: Node, id: String) -> Dictionary:
	var path := str(request.current_path)
	var result := {"progress": 0.0, "error": ""}
	if path.is_empty():
		return result
	var progress: Array = []
	var state: int = resources.status(path, progress)
	match state:
		ResourceLoader.THREAD_LOAD_LOADED:
			var loaded: Resource = resources.take(path, owner, id)
			request.current_path = ""
			if loaded != null:
				request.resources[path] = loaded
				return result
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if Time.get_ticks_msec() - int(request.current_started_ms) >= RESOURCE_TIMEOUT_MSEC:
				result.error = "Resource preparation timed out: %s" % path
			elif not progress.is_empty():
				result.progress = float(progress[0])
			return result
	result.error = "Unable to load %s" % path
	return result
