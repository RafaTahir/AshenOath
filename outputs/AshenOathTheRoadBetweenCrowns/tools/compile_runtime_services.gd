extends SceneTree
## Build-time compilation of demand-loaded services; no instances or gameplay.

func _initialize() -> void:
	var registry: Script = load("res://scripts/runtime_service_registry.gd")
	if registry == null or not registry.can_instantiate():
		push_error("Runtime service registry did not compile.")
		quit(1)
		return
	var paths: Dictionary = registry.get_script_constant_map().get("SERVICE_PATHS", {})
	if paths.is_empty():
		push_error("Runtime service registry has no service paths.")
		quit(1)
		return
	var failed := false
	for id: String in paths:
		var path := "res://scripts/%s.gd" % str(paths[id])
		var script := load(path) as Script
		if script == null or not script.can_instantiate():
			push_error("Required service did not compile: %s (%s)" % [id, path])
			failed = true
	if not failed:
		print("Compiled %d required runtime services; none instantiated." % paths.size())
	quit(1 if failed else 0)
