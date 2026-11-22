extends SceneTree

const Helper = preload("res://scripts/asset_spawn_helper.gd")
const PATH := "res://assets_external/environment/village/Wall_Plaster_Door_Flat.obj"

class Database extends Node:
	func get_asset_for_role(role: String) -> Dictionary:
		return {"path": PATH} if role == "door" else {}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var helper := Helper.new()
	var database := Database.new()
	helper.setup(database)
	root.add_child(helper)
	var passed := helper.request_role_resources(["missing"]) == ERR_FILE_NOT_FOUND
	passed = passed and helper.pending_role_resources.is_empty()
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
	print("ROLE RESOURCE PREWARM: %s" % ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
