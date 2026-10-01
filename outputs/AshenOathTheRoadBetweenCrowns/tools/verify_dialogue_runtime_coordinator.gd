extends SceneTree

const Coordinator = preload("res://scripts/dialogue_runtime_coordinator.gd")

class PoseDriver extends Node:
	var in_dialogue := false
	func set_dialogue_pose(active: bool) -> void:
		in_dialogue = active

class PlayerFixture extends CharacterBody3D:
	var animation_driver := PoseDriver.new()
	func _ready() -> void:
		add_child(animation_driver)
	func face_target(target: Vector3) -> void:
		var offset := target - global_position
		rotation.y = atan2(-offset.x, -offset.z)

class ActorFixture extends Node3D:
	var interaction_id := "sister_anwen"
	var animation_driver := PoseDriver.new()
	func _ready() -> void:
		animation_driver.name = "CharacterAnimationDriver"
		add_child(animation_driver)

class CameraFixture extends Node:
	var frames := 0
	func frame_dialogue_target(_actor: Node3D) -> void:
		frames += 1

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	var player := PlayerFixture.new()
	var actor := ActorFixture.new()
	var camera := CameraFixture.new()
	fixture.add_child(player)
	fixture.add_child(actor)
	fixture.add_child(camera)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10.0, 0.1, 10.0)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.05
	fixture.add_child(floor_body)
	await physics_frame
	await physics_frame
	var coordinator := Coordinator.new()
	player.position = Vector3(0, 0, 1)
	var initial_position := player.global_position
	coordinator.stage(actor, player, camera, func(position: Vector3) -> Vector3: return position + Vector3.RIGHT)
	_check(player.global_position == initial_position, "Blocked conversation step moved the player")
	_check(player.animation_driver.in_dialogue and actor.animation_driver.in_dialogue, "Dialogue did not stage both animation poses before pause")
	_check(actor.get_meta("dialogue_facing_lock", false), "Anwen facing lock was not owned by the coordinator")
	_check(coordinator.get_focus_actor() == actor and camera.frames == 1, "Speaker/camera staging was lost")
	coordinator.stage(actor, player, camera, func(position: Vector3) -> Vector3: return position)
	_check(player.position.is_equal_approx(Vector3(0, 0.002, 1.75)), "Conversation step is not grounded before physics pauses")
	player.rotation.y = 0.8
	actor.rotation.y = 0.8
	paused = true
	coordinator.refresh_page(player, camera)
	_check(is_equal_approx(player.rotation.y, 0.0) and is_equal_approx(absf(actor.rotation.y), PI), "Paused speaker turn did not restore face-to-face orientation")
	_check(camera.frames == 3, "Paused speaker turn did not refresh camera framing")
	paused = false
	coordinator.release(player)
	_check(coordinator.get_focus_actor() == null and not actor.get_meta("dialogue_facing_lock", true), "Close left a focus reference or Anwen lock")
	_check(not player.animation_driver.in_dialogue and not actor.animation_driver.in_dialogue, "Close left a dialogue animation pose")
	floor_body.position.y = 0.20
	await physics_frame
	await physics_frame
	player.position = Vector3(0, 0, 1)
	coordinator.stage(actor, player, camera, func(position: Vector3) -> Vector3: return position)
	_check(player.position.is_equal_approx(Vector3(0, 0.252, 1.75)), "Conversation ignored the actual raised floor")
	coordinator.release(player)
	floor_body.position.y = 0.95
	await physics_frame
	await physics_frame
	player.position = Vector3(0, 0, 1)
	coordinator.stage(actor, player, camera, func(position: Vector3) -> Vector3: return position)
	_check(player.position.is_equal_approx(Vector3(0, 0, 1)), "Conversation teleported the player onto a high platform")
	coordinator.release(player)
	floor_body.free()
	await physics_frame
	player.position = Vector3(0, 0, 1)
	coordinator.stage(actor, player, camera, func(position: Vector3) -> Vector3: return position)
	_check(player.position.is_equal_approx(Vector3(0, 0, 1)), "Unsupported conversation step moved the player")
	coordinator.release(player)
	coordinator.stage(actor, player, camera, Callable())
	actor.free()
	coordinator.refresh_page(player, camera)
	coordinator.release(player)
	coordinator.release(player)
	_check(coordinator.get_focus_actor() == null and not player.animation_driver.in_dialogue, "Actor retirement left a stale reference or player pose")
	coordinator = null
	fixture.queue_free()
	await process_frame
	await process_frame
	print("DIALOGUE RUNTIME COORDINATOR: %s (blocked/valid separation, paused page, close, retired actor, idempotent release)" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
