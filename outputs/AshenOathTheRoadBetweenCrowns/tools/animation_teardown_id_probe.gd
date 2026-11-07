extends RefCounted

## Opt-in diagnostics only. Snapshots retain IDs and paths, not game objects.
const NODE_LIMIT := 8192
const OBJECT_LIMIT := 4096
const CONTAINER_LIMIT := 64
const DEPTH_LIMIT := 6

class RequestTrace extends "res://scripts/shared_resource_requests.gd":
	static var seen_paths: Dictionary = {}
	func request(path: String, owner: Object, token: String = "") -> Error:
		seen_paths[path] = true
		return super.request(path, owner, token)

static func install_request_trace() -> RefCounted:
	var shared = load("res://scripts/shared_resource_requests.gd")
	var current: RefCounted = shared._instance.get_ref() if shared._instance != null else null
	if current != null:
		push_error("Request tracing must be installed before runtime services")
		return null
	RequestTrace.seen_paths.clear()
	var trace := RequestTrace.new()
	shared._instance = weakref(trace)
	return trace

static func emit_request_snapshot(label: String) -> void:
	var pending: Dictionary = {}
	for path: String in RequestTrace.seen_paths:
		var status := ResourceLoader.load_threaded_get_status(path)
		if status != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			pending[path] = status
	print("TEARDOWN_REQUEST_SNAPSHOT: " + JSON.stringify({"label": label, "seen_paths": RequestTrace.seen_paths.size(), "unconsumed": pending}))

static func emit_snapshot(game: Node, label: String) -> void:
	var state := {"queue": [], "queued": {}, "nodes": {}, "objects": {}, "rows": [], "truncated": []}
	if is_instance_valid(game):
		_queue_node(game, state)
	while not state.queue.is_empty() and state.nodes.size() < NODE_LIMIT:
		var node: Node = state.queue.pop_front()
		if not is_instance_valid(node) or state.nodes.has(node.get_instance_id()):
			continue
		state.nodes[node.get_instance_id()] = true
		var path := str(node.get_path()) if node.is_inside_tree() else "detached:" + str(node.name) + "#" + str(node.get_instance_id())
		_scan_script_fields(node, path, state, 0)
		for key: StringName in node.get_meta_list():
			_scan_value(node.get_meta(key), path + ".meta[" + str(key) + "]", state, 0)
		for child: Node in node.get_children():
			_queue_node(child, state)
	if not state.queue.is_empty():
		_truncate("node limit", state)
	state.rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.id) < str(b.id))
	print("TEARDOWN_ID_SNAPSHOT: " + JSON.stringify({"label": label, "nodes": state.nodes.size(), "objects": state.rows, "truncated": state.truncated}))

static func _queue_node(node: Node, state: Dictionary) -> void:
	var id := node.get_instance_id()
	if state.queued.has(id):
		return
	if state.queued.size() >= NODE_LIMIT:
		_truncate("node limit", state)
		return
	state.queued[id] = true
	state.queue.append(node)

static func _truncate(reason: String, state: Dictionary) -> void:
	if state.truncated.size() < CONTAINER_LIMIT and not state.truncated.has(reason):
		state.truncated.append(reason)

static func _scan_script_fields(object: Object, path: String, state: Dictionary, depth: int) -> void:
	if depth > DEPTH_LIMIT:
		return
	for property: Dictionary in object.get_property_list():
		if (int(property.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		# Script-valued properties include demand-loading getters. Observing a
		# shutdown must not load campaign dependencies that normal startup omits.
		var script_types := ["Script", "GDScript", "CSharpScript"]
		if int(property.get("type", TYPE_NIL)) == TYPE_OBJECT and (
			str(property.get("class_name", "")) in script_types
			or (int(property.get("hint", PROPERTY_HINT_NONE)) == PROPERTY_HINT_RESOURCE_TYPE
				and str(property.get("hint_string", "")) in script_types)):
			continue
		var name := str(property.name)
		_scan_value(object.get(name), path + "." + name, state, depth + 1)

static func _scan_value(value: Variant, path: String, state: Dictionary, depth: int) -> void:
	if depth > DEPTH_LIMIT:
		return
	if typeof(value) == TYPE_OBJECT:
		if not is_instance_valid(value) or value is Resource:
			return
		if value is WeakRef:
			_scan_value(value.get_ref(), path + ".weak", state, depth + 1)
			return
		if value is Node:
			_queue_node(value, state)
			return
		if not value is RefCounted:
			return
		var id := str(value.get_instance_id())
		if state.objects.has(id):
			var aliases: Array = state.rows[int(state.objects[id])].owners
			if aliases.size() < 8 and not aliases.has(path):
				aliases.append(path)
			return
		if state.objects.size() >= OBJECT_LIMIT:
			_truncate("object limit", state)
			return
		var script: Script = value.get_script()
		state.objects[id] = state.rows.size()
		state.rows.append({"id": id, "class": value.get_class(), "script": script.resource_path if script != null else "", "owners": [path]})
		_scan_script_fields(value, path, state, depth + 1)
	elif value is Dictionary:
		if value.size() > CONTAINER_LIMIT:
			_truncate(path + " dictionary " + str(value.size()), state)
			return
		for key: Variant in value:
			_scan_value(value[key], path + "[" + str(key).left(80) + "]", state, depth + 1)
	elif value is Array:
		if value.size() > CONTAINER_LIMIT:
			_truncate(path + " array " + str(value.size()), state)
			return
		for index in value.size():
			_scan_value(value[index], path + "[" + str(index) + "]", state, depth + 1)
