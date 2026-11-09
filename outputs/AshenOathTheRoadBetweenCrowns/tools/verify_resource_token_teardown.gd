extends SceneTree

## Isolates the engine loader from game objects and the shared request registry.
## A functional PASS is not a shutdown PASS: inspect the engine's exit output.
const CATALOG := "res://data/environment_material_dependencies.json"
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	if not catalog is Dictionary or not catalog.get("textures") is Dictionary:
		push_error("Resource-token fixture requires the generated environment catalog")
		quit(1)
		return
	var synchronous := "--synchronous" in OS.get_cmdline_user_args()
	var paths: Array[String] = []
	for path: String in catalog.textures:
		if "opening" in catalog.textures[path].get("consumers", []):
			paths.append(path)
	paths.sort()
	if paths.is_empty():
		push_error("Resource-token fixture has no opening textures")
		quit(1)
		return
	var retained: Array[Resource] = []
	var pending: Array[String] = []
	for path in paths:
		if synchronous:
			var resource := ResourceLoader.load(path)
			_check_texture(resource, path)
			retained.append(resource)
		elif ResourceLoader.load_threaded_request(path) == OK:
			pending.append(path)
		else:
			failures.append("Request failed: " + path)
	var deadline := Time.get_ticks_msec() + 30000
	while not pending.is_empty() and Time.get_ticks_msec() < deadline:
		for path in pending.duplicate():
			var state := ResourceLoader.load_threaded_get_status(path)
			if state == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				continue
			if state not in [ResourceLoader.THREAD_LOAD_LOADED, ResourceLoader.THREAD_LOAD_FAILED]:
				failures.append("Invalid request: " + path)
			else:
				var resource := ResourceLoader.load_threaded_get(path)
				_check_texture(resource, path)
				retained.append(resource)
			pending.erase(path)
		if not pending.is_empty():
			await process_frame
	if not pending.is_empty():
		failures.append("Loader deadline expired: " + str(pending))
		# Match every successful request even on fixture failure.
		for path in pending:
			ResourceLoader.load_threaded_get(path)
	var unconsumed: Array[String] = []
	if not synchronous:
		for path in paths:
			if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				unconsumed.append(path)
	if not unconsumed.is_empty():
		failures.append("Unconsumed engine claims: " + str(unconsumed))
	retained.clear()
	print("RESOURCE TOKEN TEARDOWN: " + JSON.stringify({
		"functional_status": "PASS" if failures.is_empty() else "FAIL",
		"mode": "synchronous" if synchronous else "threaded",
		"texture_count": paths.size(), "unconsumed": unconsumed,
		"failures": failures, "shutdown_status": "inspect_exit_output",
	}))
	quit(0 if failures.is_empty() else 1)

func _check_texture(resource: Resource, path: String) -> void:
	var texture := resource as Texture2D
	if texture == null or texture.get_width() <= 0 or texture.get_height() <= 0:
		failures.append("Missing or invalid texture: " + path)
