extends SceneTree

class Driver extends Node:
	var action_active := false
	var presentation_state := ""
	var current_state := "idle"
	var requests := 0
	func trigger_action(action: String) -> bool:
		requests += 1
		action_active = true
		current_state = action
		return true
	func stop_action() -> void:
		action_active = false
		current_state = "idle"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var actor := Node3D.new()
	var target := Node3D.new()
	var driver := Driver.new()
	var controller := BoardGameOpponent.new()
	root.add_child(actor)
	root.add_child(target)
	actor.add_child(driver)
	actor.add_child(controller)
	controller.set_process(false)
	controller.configure(target, driver)
	controller._process(0.11)
	var passed := driver.requests == 1 and driver.current_state == "dialogue"
	driver.stop_action()
	controller._process(0.2)
	passed = passed and driver.requests == 1
	driver.presentation_state = "dialogue"
	controller._process(6.1)
	passed = passed and driver.requests == 1
	driver.presentation_state = ""
	controller._process(0.11)
	passed = passed and driver.requests == 2
	target.position = Vector3(10, 0, 0)
	controller._process(0.11)
	passed = passed and not driver.action_active
	target.free()
	controller._process(0.8)
	actor.free()
	await process_frame
	print("BOARD INVITATION: %s" % ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
