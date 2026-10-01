extends SceneTree

const FocusService = preload("res://scripts/interaction_focus_service.gd")
const Interactable = preload("res://scripts/interactable.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	var focus := FocusService.new()
	var player := CharacterBody3D.new()
	var camera := Camera3D.new()
	var area := Interactable.new()
	fixture.add_child(focus)
	fixture.add_child(player)
	fixture.add_child(camera)
	fixture.add_child(area)
	area.setup("visibility_fixture", "dialogue", "Speak")
	area.position = Vector3(0, 0, -3)
	camera.position = Vector3(0, 1, 0)
	await _sync_physics()
	_check(focus.target_is_valid(area, player, camera), "Clear dialogue eye line was rejected")
	camera.rotation.y = PI
	_check(not focus.target_is_valid(area, player, camera), "A speaker behind the camera was accepted")
	camera.rotation.y = 0.0
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 2, 0.5)
	collision.shape = box
	wall.add_child(collision)
	fixture.add_child(wall)
	wall.position = Vector3(0, 1, -1.5)
	await _sync_physics()
	_check(not focus.target_is_valid(area, player, camera), "Unrelated wall did not block both speaker eye lines")
	area.interaction_type = "clue"
	_check(focus.target_is_valid(area, player, camera), "Ground clue lost its existing low-dressing exception")
	area.interaction_type = "zone"
	_check(focus.target_is_valid(area, player, camera), "Gate framing blocked its travel volume")
	area.position.z = -3.66
	_check(not focus.target_is_valid(area, player, camera), "Gate visibility exceeded the existing range")
	area.position.z = -3
	area.interaction_type = "vendor"
	player.position.x = 2
	camera.position.x = -2
	wall.position.x = -1
	await _sync_physics()
	_check(focus.target_is_valid(area, player, camera), "Open physical shop approach lost the player-eye fallback")
	area.interaction_type = "dialogue"
	wall.position = Vector3(0, 1, -3)
	player.position.x = 0
	camera.position.x = 0
	await _sync_physics()
	_check(focus.target_is_valid(area, player, camera), "Speaker-bound collision was treated as unrelated scenery")
	fixture.queue_free()
	await process_frame
	await process_frame
	print("INTERACTION VISIBILITY: %s (clear/behind/blocked dialogue, clue, gate range, shop fallback, actor collision)" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func _sync_physics() -> void:
	await physics_frame
	await physics_frame
	await process_frame

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
