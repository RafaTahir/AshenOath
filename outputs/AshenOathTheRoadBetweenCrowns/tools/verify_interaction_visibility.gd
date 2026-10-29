extends SceneTree

const FocusService = preload("res://scripts/interaction_focus_service.gd")
const Interactable = preload("res://scripts/interactable.gd")
var failures: Array[String] = []

class PromptProbe extends Node:
	var model: Dictionary = {}
	func get_interaction_prompt_model() -> Dictionary: return model
	func set_guidance_hint(_text: String, _seconds: float) -> void: pass

class SessionProbe extends "res://scripts/systems/session_service.gd":
	var focus: Node
	var view: Camera3D
	var activations: Array[int] = []
	func _journey_load_pending() -> bool: return false
	func _interaction_target_valid(area: Area3D) -> bool:
		return focus.target_is_valid(area, player, view)
	func _handle_interaction(area) -> void:
		activations.append(area.get_instance_id())

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if "--dispatch-only" in OS.get_cmdline_user_args():
		await _verify_dispatch()
		print("DISPLAYED TARGET DISPATCH: %s" % ("PASS" if failures.is_empty() else "FAIL"))
		quit(0 if failures.is_empty() else 1)
		return
	if "--optional-focus-only" in OS.get_cmdline_user_args():
		_verify_optional_focus()
		print("OPTIONAL ACTIVITY FOCUS: %s" % ("PASS" if failures.is_empty() else "FAIL"))
		quit(0 if failures.is_empty() else 1)
		return
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
	area.position.z = -2.5
	_check(not focus.target_is_valid(area, player, camera), "Ground clue bypassed an unrelated wall")
	box.size.y = 0.1
	wall.position.y = -0.05
	await _sync_physics()
	_check(focus.target_is_valid(area, player, camera), "Ground support blocked the clue's player eye line")
	box.size.y = 2.0
	wall.position.y = 1.0
	area.interaction_type = "zone"
	_check(focus.target_is_valid(area, player, camera), "Gate framing blocked its travel volume")
	area.position.z = -3.66
	_check(not focus.target_is_valid(area, player, camera), "Gate visibility exceeded the existing range")
	area.position.z = -2.4
	area.interaction_type = "vendor"
	player.position.x = 1.2
	camera.position.x = -2
	wall.position.x = -1
	await _sync_physics()
	_check(focus.target_is_valid(area, player, camera), "Open physical shop approach lost the player-eye fallback")
	area.interaction_type = "dialogue"
	area.position.z = -3
	wall.position = Vector3(0, 1, -3)
	player.position.x = 0
	camera.position.x = 0
	await _sync_physics()
	_check(not focus.target_is_valid(area, player, camera), "Unrelated collision at the speaker was inferred to be owned")
	wall.position.z = -2.15
	await _sync_physics()
	_check(not focus.target_is_valid(area, player, camera), "Nearby furniture bypassed speaker visibility")
	wall.reparent(area, true)
	await _sync_physics()
	_check(focus.target_is_valid(area, player, camera), "Speaker-owned collision was treated as unrelated scenery")
	var second_wall := StaticBody3D.new()
	var second_shape := CollisionShape3D.new()
	second_shape.shape = box.duplicate()
	second_wall.add_child(second_shape)
	fixture.add_child(second_wall)
	second_wall.position = Vector3(0,1,-2.75)
	await _sync_physics()
	_check(not focus.target_is_valid(area, player, camera), "Owned body concealed an unrelated wall behind it")
	second_wall.queue_free()
	wall.reparent(fixture, true)
	area.set_meta("interaction_collision_owner", area.get_path_to(wall))
	await _sync_physics()
	_check(focus.target_is_valid(area, player, camera), "Explicit sibling collision ownership was ignored")
	area.set_meta("interaction_collision_owner", area.get_path_to(fixture))
	_check(not focus.target_is_valid(area, player, camera), "Shared zone parent was allowed to own every blocker")
	area.remove_meta("interaction_collision_owner")
	wall.position.z = -2.91
	box.size.z = 0.04
	await _sync_physics()
	_check(not focus.target_is_valid(area, player, camera), "Wall within old endpoint tolerance was bypassed")
	wall.queue_free()
	area.interaction_type = "story_activity"
	area.position = Vector3(0,0,-1.5)
	area.set_meta("interaction_hand_reach", 1.05)
	await _sync_physics()
	_check(not focus.target_is_valid(area, player, camera), "Unreachable handling prompt remained usable")
	area.position.z = -0.8
	_check(focus.target_is_valid(area, player, camera), "Arm's-reach fixture became inaccessible")
	area.remove_meta("interaction_hand_reach")
	area.set_meta("interaction_reach",0.35)
	area.position.z = -0.45
	_check(not focus.target_is_valid(area, player, camera), "Seat reach was expanded beyond its real activation distance")
	area.position.z = -0.3
	_check(focus.target_is_valid(area, player, camera), "Clear close seat was rejected")
	area.queue_free()
	await _sync_physics()
	for id: String in ["common_table", "barrel_board"]:
		var table := Interactable.new()
		table.setup(id,"minigame","Play")
		fixture.add_child(table)
		table.set_meta("interaction_anchor",Vector3(0,1.11,0))
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var mesh := load("res://assets_external/environment/props/GreyfenSocial_%s.res" % id) as ArrayMesh
		_check(mesh != null,"Missing actual table mesh: "+id)
		if mesh == null: continue
		shape.shape = mesh.create_trimesh_shape()
		body.add_child(shape)
		table.add_child(body)
		player.position = Vector3(2,0,0)
		camera.position = Vector3(2,1.5,1)
		camera.look_at(Vector3(0,1.11,0))
		await _sync_physics()
		_check(focus.target_is_valid(table,player,camera),"Actual table's own solid furniture blocks Play: "+id)
		table.queue_free()
		await _sync_physics()
	fixture.queue_free()
	await process_frame
	await process_frame
	print("INTERACTION VISIBILITY: %s (walls, explicit ownership, clue/gate/shop, real furniture, handling and seat reach)" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func _verify_dispatch() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	var focus := FocusService.new()
	var player := CharacterBody3D.new()
	var camera := Camera3D.new()
	var hud := PromptProbe.new()
	var router := preload("res://scripts/input_router.gd").new()
	var session := SessionProbe.new()
	for node: Node in [focus, player, camera, hud, router, session]:
		fixture.add_child(node)
	var state := preload("res://scripts/systems/game_state.gd").new(fixture)
	fixture.add_child(state.zone_residency)
	session.configure(fixture,state,{})
	session.player = player
	session.hud = hud
	session.zone_root = fixture
	session.input_router = router
	session.game_started = true
	session.focus = focus
	session.view = camera
	router.set_gameplay_context()
	router.gameplay_action_requested.connect(session._on_virtual_gameplay_action)
	var shown := Interactable.new()
	shown.setup("shown", "dialogue", "Speak")
	shown.position = Vector3(0,0,-2)
	fixture.add_child(shown)
	var other := Interactable.new()
	other.setup("other", "dialogue", "Speak")
	other.position = Vector3(0.4,0,-2)
	fixture.add_child(other)
	camera.position = Vector3(0,1,0)
	hud.model = {"available":true,"target_instance_id":shown.get_instance_id()}
	await _sync_physics()
	var key := InputEventKey.new()
	key.keycode = KEY_F9
	_check(bool(router.remap_action("interact",key).get("ok",false)),"Use could not be remapped for the dispatch check")
	key.pressed = true
	session.route_unhandled_input(key)
	session.route_unhandled_input(key)
	_check(session.activations == [shown.get_instance_id()],"Remapped repeated event did not activate exactly the displayed target once")
	router.request_virtual_action("interact",other.get_instance_id())
	await process_frame

	_check(session.activations.size() == 1,"Stale touch request activated a different target")
	router.request_virtual_action("interact",shown.get_instance_id())
	await process_frame
	_check(session.activations == [shown.get_instance_id(),shown.get_instance_id()],"Current virtual Use did not activate the displayed target once")
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1,2,0.1)
	shape.shape = box
	wall.add_child(shape)
	fixture.add_child(wall)
	wall.position = Vector3(0,1,-1)
	await _sync_physics()
	router.request_virtual_action("interact",shown.get_instance_id())
	await process_frame
	_check(session.activations.size() == 2,"Use failed to freshly reject an occluded displayed target")
	hud.model["available"] = false
	session._dispatch_gameplay_action("interact")
	_check(session.activations.size() == 2,"Unavailable prompt remained activatable")
	fixture.queue_free()
	await process_frame

func _verify_optional_focus() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	var focus := FocusService.new()
	var player := Node3D.new()
	var camera := Camera3D.new()
	var board := Interactable.new()
	var trial := Interactable.new()
	for node: Node in [focus,player,camera,board,trial]: fixture.add_child(node)
	camera.position.y = 1.0
	board.setup("common_table","minigame","Play")
	board.position.z = -2.4
	trial.setup("lr_trial","story_activity","Bracken's field trial")
	trial.position.z = -1.6
	trial.set_meta("optional_companion_interaction",true)
	_check(focus.choose([trial,board],player,camera,Callable()) == board,"Optional field-trial marker steals the examined game board")
	focus.reset()
	_check(focus.choose([trial],player,camera,Callable()) == trial,"Deliberately examined optional trial is inaccessible")
	fixture.free()

func _sync_physics() -> void:
	await physics_frame
	await physics_frame
	await process_frame

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
