extends SceneTree

const Helper = preload("res://scripts/asset_spawn_helper.gd")
const PATH := "res://assets_external/environment/village/Wall_Plaster_Door_Flat.obj"

class Database extends Node:
	func get_asset_for_role(role: String) -> Dictionary:
		return {"path": PATH} if role == "door" else {}

class RequestProbe extends RefCounted:
	var texture: Texture2D = GradientTexture2D.new()
	var resources: Dictionary = {}
	var states: Dictionary = {}
	var owners: Dictionary = {}
	var request_error: Error = OK
	func request(path: String, owner: Object, _token: String = "") -> Error:
		if request_error != OK:
			return request_error
		if not owners.has(path):
			owners[path] = {}
		owners[path][owner.get_instance_id()] = true
		return OK
	func status(path: String) -> int:
		return int(states.get(path, ResourceLoader.THREAD_LOAD_LOADED)) if owners.has(path) else ResourceLoader.THREAD_LOAD_INVALID_RESOURCE
	func take(path: String, owner: Object, token: String = "", _wait: bool = false) -> Resource:
		var resource: Resource = resources.get(path, texture)
		release(path, owner, token)
		return resource
	func release(path: String, owner: Object, _token: String = "", _drain: bool = false) -> void:
		if owners.has(path):
			owners[path].erase(owner.get_instance_id())
			if owners[path].is_empty():
				owners.erase(path)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var helper := Helper.new()
	var database := Database.new()
	helper.setup(database)
	root.add_child(helper)
	var passed := helper.request_role_resources(["missing"]) == ERR_FILE_NOT_FOUND
	passed = passed and helper.pending_role_resources.is_empty()
	passed = passed and helper.poll_role_resources() == ERR_FILE_NOT_FOUND
	helper.begin_resource_attempt()
	passed = passed and helper.request_role_resources(["door", "door"]) == OK
	passed = passed and helper.pending_role_resources.size() == 1
	var deadline := Time.get_ticks_msec() + 10000
	var status: Error = ERR_BUSY
	while status == ERR_BUSY and Time.get_ticks_msec() < deadline:
		await process_frame
		status = helper.poll_role_resources()
	passed = passed and status == OK and helper.resource_cache.get(PATH) is ArrayMesh
	var cached: Resource = helper.resource_cache.get(PATH)
	passed = passed and helper.request_role_resources(["door"]) == OK
	passed = passed and helper.pending_role_resources.is_empty()
	passed = passed and helper.load_runtime_resource(PATH) == cached
	helper.resource_prewarm_error = "prior timeout"
	helper.begin_resource_attempt()
	passed = passed and helper.resource_prewarm_error.is_empty() and helper.load_runtime_resource(PATH) == cached
	helper.clear_runtime_caches()
	passed = passed and helper.resource_cache.is_empty()
	passed = passed and helper.request_role_resources(["door"]) == OK
	# Exercise shutdown before the consumer polls, then retry from an empty cache.
	helper.clear_runtime_caches()
	passed = passed and helper.pending_role_resources.is_empty()
	helper.queue_free()
	database.free()
	await process_frame
	passed = _verify_environment_preflight() and passed
	print("ROLE RESOURCE PREWARM: %s" % ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)

func _verify_environment_preflight() -> bool:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Helper.ENVIRONMENT_RESOURCE_CATALOG))
	var expected: Array[String] = []
	for path: String in catalog.textures:
		var entry: Dictionary = catalog.textures[path]
		if entry.owner == "opening" or "opening" in entry.consumers:
			expected.append(path)
	if expected.is_empty():
		return false
	var helper := Helper.new()
	var requests := RequestProbe.new()
	helper.resource_requests = requests
	var path: String = expected[0]
	var passed := helper.request_environment_resources(["quality_materials"]) == OK
	passed = helper.pending_role_resources.is_empty() and passed
	passed = helper.request_environment_resources(["opening"]) == OK and passed
	passed = helper.pending_role_resources.size() == expected.size() and passed
	for required in expected:
		passed = helper.pending_role_resources.has(required) and passed
	# A decoded parent-like Resource, an empty texture, and null are all failures.
	for invalid: Resource in [Resource.new(), ImageTexture.new(), null]:
		helper.begin_resource_attempt()
		helper.resource_cache.erase(path)
		requests.resources[path] = invalid
		passed = helper.request_environment_resources(["opening"]) == OK and passed
		passed = helper.poll_role_resources() == ERR_CANT_OPEN and passed
		var failure: String = helper.resource_prewarm_error
		passed = failure.contains(path) and not helper.resource_cache.has(path) and passed
		passed = helper.poll_role_resources() == ERR_CANT_OPEN and helper.resource_prewarm_error == failure and passed
		passed = helper.request_resource_paths([PATH]) == ERR_CANT_OPEN and passed
		requests.resources.erase(path)
		helper.begin_resource_attempt()
		passed = helper.request_environment_resources(["opening"]) == OK and passed
		passed = helper.poll_role_resources() == OK and helper.resource_cache.get(path) == requests.texture and passed
	# Reject a failed cache entry instead of interpreting its key as readiness.
	helper.begin_resource_attempt()
	helper.resource_cache[path] = ImageTexture.new()
	passed = helper.request_environment_resources(["opening"]) == ERR_CANT_OPEN and passed
	passed = not helper.resource_cache.has(path) and helper.poll_role_resources() == ERR_CANT_OPEN and passed
	helper.begin_resource_attempt()
	requests.request_error = ERR_CANT_OPEN
	passed = helper.request_environment_resources(["opening"]) == ERR_CANT_OPEN and passed
	passed = helper.poll_role_resources() == ERR_CANT_OPEN and helper.resource_prewarm_error.contains(path) and passed
	requests.request_error = OK
	helper.begin_resource_attempt()
	# Abandoned work cannot poison a new scope or release another consumer.
	requests.states[path] = ResourceLoader.THREAD_LOAD_IN_PROGRESS
	passed = helper.request_environment_resources(["opening"]) == OK and passed
	var other_owner := RefCounted.new()
	requests.request(path, other_owner)
	passed = helper.poll_role_resources() == ERR_BUSY and passed
	helper.begin_resource_attempt()
	passed = helper.pending_role_resources.is_empty() and requests.owners.get(path, {}).size() == 1 and passed
	passed = requests.owners.get(path, {}).has(other_owner.get_instance_id()) and passed
	passed = helper.request_environment_resources(["quality_materials"]) == OK and helper.poll_role_resources() == OK and passed
	requests.states.erase(path)
	requests.release(path, other_owner)
	passed = helper.request_environment_resources(["opening"]) == OK and passed
	passed = helper.poll_role_resources() == OK and helper.resource_cache.size() == expected.size() and passed
	for required in expected:
		passed = helper.resource_cache.get(required) == requests.texture and passed
	helper.clear_runtime_caches()
	helper.free()
	return passed
