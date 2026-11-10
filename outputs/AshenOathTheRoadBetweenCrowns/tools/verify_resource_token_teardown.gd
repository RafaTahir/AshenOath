extends SceneTree

## Isolates the engine loader from game objects and the shared request registry.
## A functional PASS is not a shutdown PASS: inspect the engine's exit output.
const CATALOG := "res://data/environment_material_dependencies.json"
const ACTOR_CATALOG := "res://data/prepared_actors.json"
var failures: Array[String] = []
var completed_rounds := 0
var requested_rounds := 1

class LoadBatch extends RefCounted:
	var paths: Array[String] = []
	var resources: Array[Resource] = []
	func run() -> void:
		# Only this dedicated thread writes the batch; the caller joins before
		# reading it. No live scene nodes or shared resources are modified here.
		for path in paths:
			resources.append(ResourceLoader.load(path))

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if completed_rounds == 0:
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--rounds="):
				requested_rounds = clampi(argument.trim_prefix("--rounds=").to_int(), 1, 100)
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	if not catalog is Dictionary or not catalog.get("textures") is Dictionary:
		push_error("Resource-token fixture requires the generated environment catalog")
		quit(1)
		return
	var synchronous := "--synchronous" in OS.get_cmdline_user_args()
	var owned_thread := "--owned-thread" in OS.get_cmdline_user_args()
	var join_immediately := "--join-immediately" in OS.get_cmdline_user_args()
	var blocking_get := "--blocking-get" in OS.get_cmdline_user_args()
	if synchronous and owned_thread:
		push_error("Select only one resource-token fixture mode")
		quit(1)
		return
	if join_immediately and not owned_thread:
		push_error("Immediate join requires the owned-thread diagnostic")
		quit(1)
		return
	if blocking_get and (owned_thread or synchronous):
		push_error("Blocking get requires the engine-threaded diagnostic")
		quit(1)
		return
	var paths: Array[String] = []
	for path: String in catalog.textures:
		if "opening" in catalog.textures[path].get("consumers", []):
			paths.append(path)
	paths.sort()
	var actor := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--actor="):
			actor = argument.trim_prefix("--actor=")
	if not actor.is_empty():
		paths.clear()
		var actors: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ACTOR_CATALOG))
		for entry: Dictionary in actors.values():
			if str(entry.get("role", "")) == actor:
				paths.append(str(entry.path))
				break
	if paths.is_empty():
		push_error("Resource-token fixture has no opening textures")
		quit(1)
		return
	var retained: Array[Resource] = []
	var pending: Array[String] = []
	var started := Time.get_ticks_usec()
	var max_poll_interval_usec := 0
	if owned_thread:
		var batch := LoadBatch.new()
		batch.paths.assign(paths)
		var worker := Thread.new()
		var error := worker.start(batch.run)
		if error != OK:
			failures.append("Owned loader thread failed to start: " + str(error))
		else:
			var previous_owned_poll := Time.get_ticks_usec()
			while worker.is_alive() and not join_immediately:
				await process_frame
				var now := Time.get_ticks_usec()
				max_poll_interval_usec = maxi(max_poll_interval_usec, now - previous_owned_poll)
				previous_owned_poll = now
			print("RESOURCE TOKEN JOIN: " + ("immediate" if join_immediately else "completed"))
			worker.wait_to_finish()
			for index in paths.size():
				_check_resource(batch.resources[index], paths[index])
			retained.assign(batch.resources)
			batch.resources.clear()
	else:
		for path in paths:
			if synchronous:
				var resource := ResourceLoader.load(path)
				_check_resource(resource, path)
				retained.append(resource)
			elif ResourceLoader.load_threaded_request(path) == OK:
				pending.append(path)
			else:
				failures.append("Request failed: " + path)
	var deadline := Time.get_ticks_msec() + 30000
	var previous_poll := Time.get_ticks_usec()
	if blocking_get:
		print("RESOURCE TOKEN GET: blocking")
		for path in pending:
			var resource := ResourceLoader.load_threaded_get(path)
			_check_resource(resource, path)
			retained.append(resource)
		pending.clear()
	while not pending.is_empty() and Time.get_ticks_msec() < deadline:
		for path in pending.duplicate():
			var state := ResourceLoader.load_threaded_get_status(path)
			if state == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				continue
			if state not in [ResourceLoader.THREAD_LOAD_LOADED, ResourceLoader.THREAD_LOAD_FAILED]:
				failures.append("Invalid request: " + path)
			else:
				var resource := ResourceLoader.load_threaded_get(path)
				_check_resource(resource, path)
				retained.append(resource)
			pending.erase(path)
		if not pending.is_empty():
			await process_frame
			var now := Time.get_ticks_usec()
			max_poll_interval_usec = maxi(max_poll_interval_usec, now - previous_poll)
			previous_poll = now
	if not pending.is_empty():
		failures.append("Loader deadline expired: " + str(pending))
		# Match every successful request even on fixture failure.
		for path in pending:
			ResourceLoader.load_threaded_get(path)
	var unconsumed: Array[String] = []
	if not synchronous and not owned_thread:
		for path in paths:
			if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				unconsumed.append(path)
	if not unconsumed.is_empty():
		failures.append("Unconsumed engine claims: " + str(unconsumed))
	retained.clear()
	completed_rounds += 1
	print("RESOURCE TOKEN TEARDOWN: " + JSON.stringify({
		"functional_status": "PASS" if failures.is_empty() else "FAIL",
		"mode": "owned_thread" if owned_thread else ("synchronous" if synchronous else "threaded"),
		"texture_count": paths.size() if actor.is_empty() else 0,
		"actor": actor, "resource_count": paths.size(), "unconsumed": unconsumed,
		"join_immediately": join_immediately,
		"blocking_get": blocking_get,
		"round": completed_rounds, "requested_rounds": requested_rounds,
		"object_count": Performance.get_monitor(Performance.OBJECT_COUNT),
		"static_memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC),
		"failures": failures, "shutdown_status": "inspect_exit_output",
		"load_elapsed_ms": (Time.get_ticks_usec() - started) / 1000.0,
		"max_poll_interval_ms": max_poll_interval_usec / 1000.0,
	}))
	if failures.is_empty() and completed_rounds < requested_rounds:
		# Release this invocation's locals before repeating; do not add a sleep
		# that could conceal the resource completion/teardown race.
		call_deferred("run")
		return
	quit(0 if failures.is_empty() else 1)

func _check_resource(resource: Resource, path: String) -> void:
	if path.ends_with(".scn"):
		var scene := resource as PackedScene
		if scene == null or not scene.can_instantiate():
			failures.append("Missing or invalid prepared scene: " + path)
		return
	var texture := resource as Texture2D
	if texture == null or texture.get_width() <= 0 or texture.get_height() <= 0:
		failures.append("Missing or invalid texture: " + path)
