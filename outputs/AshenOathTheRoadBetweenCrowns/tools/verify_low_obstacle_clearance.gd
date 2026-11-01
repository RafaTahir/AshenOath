extends SceneTree
## Real physics probes with no game world, imported art or user save data.

const Spatial = preload("res://scripts/zone_spatial_service.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var service := Spatial.new()
	stage.add_child(service)
	service.configure("clearance_fixture", 999.0, Vector2(12, 12))
	var floor_body := _box(stage, Vector3(0, -0.1, 0), Vector3(20, 0.2, 20))
	var obstacle := _box(stage, Vector3(0, 0.125, 0), Vector3(1, 0.25, 1))
	await _settle()
	_check(not service.is_position_occupied(Vector3(4, 0, 0), 0.3016, 1.65), "Flat floor must not count as body occupancy")
	_check(service.validate_runtime_segment(Vector3(3, 0, 0), Vector3(4, 0, 0), 0.58), "Flat unobstructed floor must remain traversable")
	_check(service.is_position_occupied(Vector3.ZERO, 0.3016, 1.65), "A 25cm prop must occupy the NPC feet probe")
	_check(not service.validate_runtime_segment(Vector3(-2, 0, 0), Vector3(2, 0, 0), 0.58), "A swept NPC step must not cross a 25cm prop")
	obstacle.position.y = 0.60
	(obstacle.get_child(0).shape as BoxShape3D).size.y = 1.2
	await _settle()
	_check(service.is_position_occupied(Vector3.ZERO, 0.3016, 1.65), "Tall obstacle occupancy must remain blocked")
	_check(not service.validate_runtime_segment(Vector3(-2, 0, 0), Vector3(2, 0, 0), 0.58), "Tall obstacle sweep must remain blocked")
	# The same probe offset must work above a raised bridge deck.
	floor_body.position.y = 0.45
	obstacle.position.y = 0.675
	(obstacle.get_child(0).shape as BoxShape3D).size.y = 0.25
	await _settle()
	_check(not service.is_position_occupied(Vector3(4, 0.55, 0), 0.3016, 1.65), "Raised deck must not count as occupancy")
	_check(service.is_position_occupied(Vector3(0, 0.55, 0), 0.3016, 1.65), "Low prop on raised deck must remain occupied")
	_check(not service.validate_runtime_segment(Vector3(-2, 0.55, 0), Vector3(2, 0.55, 0), 0.58), "Raised-deck low prop must block the sweep")
	var actor := CharacterBody3D.new()
	stage.add_child(actor)
	actor.position = Vector3(4, 0.55, 0)
	var actor_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.30
	capsule.height = 1.65
	actor_shape.shape = capsule
	actor_shape.position.y = capsule.height * 0.5
	actor.add_child(actor_shape)
	await _settle()
	_check(service.is_position_occupied(actor.position, 0.3016, 1.65), "Unexcluded actor must be detected")
	service.set_player_body(actor)
	_check(not service.is_position_occupied(actor.position, 0.3016, 1.65), "Bound player exclusion must remain effective")
	service.reserve_exclusion("authored", Vector3(4, 0.55, 3), Vector2(0.5, 0.5))
	_check(not service.validate_runtime_segment(Vector3(3, 0.55, 3), Vector3(5, 0.55, 3), 0.58), "Authored exclusions must still block movement")
	stage.free()
	print("LOW OBSTACLE CLEARANCE: %s checks=%d" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _box(parent: Node3D, position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	parent.add_child(body)
	body.position = position
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body

func _settle() -> void:
	await physics_frame
	await process_frame
	await physics_frame

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)
