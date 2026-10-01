extends SceneTree

const Residency = preload("res://scripts/zone_residency_service.gd")

var failures: Array[String] = []
var audits := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var owner := Node3D.new()
	root.add_child(owner)
	var service := Residency.new()
	owner.add_child(service)
	service.configure(_validate)
	var zone := _zone(owner, "greyfen")
	var actor := Node3D.new()
	zone.add_child(actor)
	service._cache_route_zone("greyfen", zone, [actor], 17)
	_check(service.route_zone_cache.get("greyfen") == zone, "Cache ownership lost the root")
	_check(zone.position.y == -1000 and not zone.visible and zone.process_mode == Node.PROCESS_MODE_DISABLED, "Inactive zone suspension changed")
	_check(service.route_enemy_cache.greyfen == [actor] and service.route_zone_signatures.greyfen == 17, "Enemy/signature ownership changed")
	var body := zone.get_node("Body") as StaticBody3D
	_check(body.collision_layer == 5 and body.collision_mask == 3, "Offscreen caching changed preserved collision")
	_check(service._activate_cached_zone("greyfen") == zone, "Activation did not reuse the root")
	_check(zone.visible and zone.position == Vector3.ZERO and zone.process_mode == Node.PROCESS_MODE_INHERIT, "Activation state was not restored")
	service._cache_route_zone("greyfen", zone, [actor], 18, true)
	_check(body.collision_layer == 0 and body.collision_mask == 0, "Visible cache retained physical collision")
	service._activate_cached_zone("greyfen")
	_check(body.collision_layer == 5 and body.collision_mask == 3, "Activation changed authored collision masks")
	var spatial := Node.new()
	owner.add_child(spatial)
	service._cache_route_spatial_service("greyfen", spatial)
	service._release_route_spatial_service("greyfen", [spatial])
	_check(not spatial.is_queued_for_deletion(), "Protected spatial service was destroyed")
	service._cache_route_spatial_service("greyfen", spatial)
	var replacement := _zone(owner, "replacement")
	service._cache_route_zone("greyfen", zone, [actor], 18)
	service._cache_route_zone("greyfen", replacement, [], 19)
	_check(service.pending_zone_retirements == 1 and spatial.is_queued_for_deletion(), "Replaced cache did not retire its previous root/service")
	var second := _zone(owner, "wychwood")
	service._cache_route_zone("wychwood", second, [], 20)
	service._trim_route_zone_cache(["wychwood"])
	_check(service.route_zone_cache.keys() == ["wychwood"] and service.pending_zone_retirements == 2, "Cache trimming changed retention policy")
	var shape := zone.get_node("Body/Shape") as CollisionShape3D
	_check(is_instance_valid(zone) and shape.shape != null, "Geometry was freed before the renderer grace period")
	service._retire_zone_root(second)
	service._retire_zone_root(second)
	_check(service.pending_zone_retirements == 3, "Duplicate retirement changed ownership counts")
	for _index in range(Residency.ZONE_RETIRE_FRAMES + 3):
		await process_frame
	_check(not is_instance_valid(zone) and not is_instance_valid(replacement) and not is_instance_valid(second), "Retired roots outlived their grace period")
	_check(service.pending_zone_retirements == 0 and service.retired_zone_roots.is_empty() and service.retired_material_anchors.is_empty(), "Retirement retained roots or material anchors")
	_check(audits == 3, "Retirement skipped or duplicated its render-resource audit")
	service.release_shared_anchors()
	service.release_material_anchors()
	_check(not service.validate_resources.is_valid(), "Shutdown retained its validator owner")
	owner.queue_free()
	await process_frame
	await process_frame
	print("ZONE RESIDENCY VERIFIER: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func _zone(owner: Node, id: String) -> Node3D:
	var zone := Node3D.new()
	zone.name = id
	owner.add_child(zone)
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 5
	body.collision_mask = 3
	zone.add_child(body)
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	shape.shape = BoxShape3D.new()
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.material_override = StandardMaterial3D.new()
	zone.add_child(mesh)
	return zone

func _validate(_node: Node) -> Dictionary:
	audits += 1
	return {"ok": true}

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
