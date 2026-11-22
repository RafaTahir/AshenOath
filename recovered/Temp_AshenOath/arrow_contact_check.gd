extends SceneTree

class Target:
	extends CharacterBody3D
	var dead := false
	var display_name := "Archery target"
	var hits := 0
	func apply_damage(_damage: float, _source: String) -> void:
		hits += 1

var results: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var combat = load("res://scripts/combat_manager.gd").new()
	stage.add_child(combat)
	var coordinator = load("res://scripts/combat_vfx_coordinator.gd").new()
	var target := Target.new()
	var shape := CollisionShape3D.new()
	shape.shape = CapsuleShape3D.new()
	shape.position.y = 1.0
	target.add_child(shape)
	target.position.z = -3.0
	stage.add_child(target)
	await physics_frame
	var excluded: Array[RID] = [target.get_rid()]
	coordinator.launch_arrow(stage, Vector3(0,1,0), Vector3.FORWARD, 6.0, [target], combat, excluded, {"damage":28.0,"width":0.34}, func(result): results.append(result.hit))
	for frame in 60: await physics_frame
	var wall := StaticBody3D.new()
	var barrier := CollisionShape3D.new()
	barrier.shape = BoxShape3D.new()
	barrier.shape.size = Vector3(2,3,0.3)
	wall.position = Vector3(0,1,-1.5)
	wall.add_child(barrier)
	stage.add_child(wall)
	await physics_frame
	coordinator.launch_arrow(stage, Vector3(0,1,0), Vector3.FORWARD, 6.0, [target], combat, excluded, {"damage":28.0,"width":0.34}, func(result): results.append(result.hit))
	for frame in 60: await physics_frame
	var passed: bool = results == [true,false] and target.hits == 1
	print("ARROW CONTACT CHECK: ", "PASS" if passed else "FAIL", " callbacks=", results, " damage_applications=",target.hits)
	stage.queue_free()
	await process_frame
	quit(0 if passed else 1)
