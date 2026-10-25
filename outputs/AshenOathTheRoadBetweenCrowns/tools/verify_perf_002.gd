extends SceneTree

const WARMUP_ROUTE: Array[String] = [
	"wychwood", "greyfen", "vargan_approach", "greyfen",
]
const REPEAT_ROUTE: Array[String] = [
	"wychwood", "greyfen", "vargan_approach", "greyfen",
]

var failures := 0

class TickProbe extends Node:
	var ticks := 0
	func _process(_delta: float) -> void: ticks += 1

func _initialize() -> void:
	if "--anchor-contract-only" in OS.get_cmdline_user_args():
		call_deferred("_anchor_contract")
		return
	var scene := load("res://scenes/main.tscn") as PackedScene
	check(scene != null, "Main scene is unavailable")
	if scene == null:
		_finish()
		return
	var game = scene.instantiate()
	root.add_child(game)
	await _frames(3)
	game.call("_new_game")
	await _wait_for_zone(game, "greyfen")
	for zone_id in WARMUP_ROUTE:
		await _visit_zone(game, zone_id)
	var baseline_memory := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	for zone_id in REPEAT_ROUTE:
		await _visit_zone(game, zone_id)
	var final_snapshot: Dictionary = game.zone_lifecycle_snapshot()
	var growth := int(final_snapshot.static_memory_bytes) - baseline_memory
	check(growth <= 16 * 1024 * 1024, "Repeated route memory grew by more than 16 MB: %d" % growth)
	check(final_snapshot.transition_history.size() <= game.MAX_TRANSITION_HISTORY, "Transition history is unbounded")
	var warm_samples: Array[float] = []
	for entry in final_snapshot.transition_history:
		if str(entry.get("zone", "")) == "greyfen":
			warm_samples.append(float(entry.get("to_playable_ms", 99999.0)))
	check(warm_samples.size() >= 2, "Warm Greyfen transitions were not measured")
	if warm_samples.size() >= 2:
		check(warm_samples.min() <= 350.0, "No warm transition met the 350 ms Web budget: %s" % [warm_samples])
	print("PERF-002 METRICS: memory_growth_mb=%.2f anchors=%d warm_ms=%s" % [
		float(growth) / (1024.0 * 1024.0),
		int(final_snapshot.resource_anchor_count),
		str(warm_samples),
	])
	game.prepare_resource_shutdown()
	await _wait_for_retirement(game)
	game.queue_free()
	await _frames(5)
	_finish()

func _anchor_contract() -> void:
	var residency = preload("res://scripts/zone_residency_service.gd").new()
	root.add_child(residency)
	residency.configure(func(_branch: Node): pass)
	var zone := Node3D.new()
	root.add_child(zone)
	var actor := Node3D.new()
	zone.add_child(actor)
	var body := StaticBody3D.new()
	body.process_mode = Node.PROCESS_MODE_PAUSABLE
	actor.add_child(body)
	var collision := CollisionShape3D.new()
	collision.shape = BoxShape3D.new()
	body.add_child(collision)
	var worker := TickProbe.new()
	worker.process_mode = Node.PROCESS_MODE_ALWAYS
	actor.add_child(worker)
	var skeleton := Skeleton3D.new()
	skeleton.add_bone("root")
	actor.add_child(skeleton)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	var skin := Skin.new()
	skin.add_bind(0, Transform3D.IDENTITY)
	mesh.skin = skin
	skeleton.add_child(mesh)
	await physics_frame
	await process_frame
	var ray := PhysicsRayQueryParameters3D.create(Vector3(0, 2, 0), Vector3(0, -2, 0), 1)
	check(not zone.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "Anchor fixture has no initial physics body")
	residency._anchor_shared_skinned_resources(zone)
	var ticks := worker.ticks
	await _frames(3)
	await physics_frame
	check(residency.skinned_resource_anchors.size() == 1, "Shared skin resource was not retained")
	check(worker.ticks == ticks, "Retired skin anchor still processes explicit ALWAYS descendants")
	check(body.collision_layer == 0 and body.collision_mask == 0, "Retired skin anchor retains active collision")
	check(zone.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "Retired skin anchor still blocks the active physics world")
	residency.release_shared_anchors()
	residency.release_material_anchors()
	zone.free()
	residency.free()
	await _frames(3)
	print("RETIRED ANCHOR CONTRACT: %s (resource lifetime, processing and physics only)" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

func _visit_zone(game, zone_id: String) -> void:
	game.call("_load_zone", zone_id, Vector3(0, 1, 7))
	await _wait_for_zone(game, zone_id)
	await _wait_for_retirement(game)
	var snapshot: Dictionary = game.zone_lifecycle_snapshot()
	check(int(snapshot.cached_count) <= 1, "Route cache exceeded one zone in %s" % zone_id)
	check(int(snapshot.retiring_count) == 0, "Retirement did not settle in %s" % zone_id)
	check(int(snapshot.resource_anchor_count) <= game.MAX_SKINNED_RESOURCE_ANCHORS, "Shared skinned-resource anchor cap exceeded")
	check(int(snapshot.material_anchor_count) <= game.MAX_RETIRED_MATERIAL_ANCHORS, "Retired material anchor cap exceeded")
	check(int(snapshot.active_navigation_regions) <= 1, "Duplicate active navigation regions in %s" % zone_id)

func _wait_for_zone(game, zone_id: String) -> void:
	for _index in range(180):
		await process_frame
		if str(game.current_zone_id) == zone_id and game.zone_root != null and not game.zone_transition_pending:
			return
	check(false, "Timed out waiting for zone: %s" % zone_id)

func _wait_for_retirement(game) -> void:
	for _index in range(180):
		await process_frame
		if int(game.zone_lifecycle_snapshot().retiring_count) == 0:
			return
	check(false, "Timed out waiting for staged retirement")

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _finish() -> void:
	print("PERF-002 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
