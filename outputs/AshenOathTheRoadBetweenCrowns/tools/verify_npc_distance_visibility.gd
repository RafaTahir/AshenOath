extends SceneTree

const Ambient = preload("res://scripts/npc_ambient.gd")
var failures: Array[String] = []

class Driver extends Node:
	var suspended := false
	var dialogue := false
	func set_locomotion(_speed: float, _direction: Vector3, _grounded: bool) -> void:
		pass
	func set_dialogue_pose(value: bool) -> void:
		dialogue = value
	func set_distance_suspended(value: bool) -> void:
		suspended = value

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for role in ["sister_anwen", "rook", "mira"]:
		var actor := Node3D.new()
		var player := Node3D.new()
		var body := MeshInstance3D.new()
		body.mesh = BoxMesh.new()
		var hidden_equipment := MeshInstance3D.new()
		hidden_equipment.mesh = BoxMesh.new()
		hidden_equipment.hide()
		var animation := Driver.new()
		animation.name = "CharacterAnimationDriver"
		var face := Driver.new()
		face.name = "CharacterFaceDriver"
		actor.add_child(body)
		actor.add_child(hidden_equipment)
		actor.add_child(animation)
		actor.add_child(face)
		root.add_child(actor)
		root.add_child(player)
		var ambient := Ambient.new()
		ambient.setup(role, player)
		actor.add_child(ambient)
		ambient.set_process(false)
		player.position = Vector3(0, 0, 30)
		ambient._process(0.11)
		_check(body.visible, role + " disappeared at distance")
		_check(not hidden_equipment.visible, "ambient exposed intentionally hidden equipment")
		_check(animation.suspended and face.suspended, "distant animation was not suspended")
		if role == "sister_anwen":
			actor.set_meta("dialogue_facing_lock", true)
			ambient._process(0.11)
			_check(not animation.suspended and not face.suspended and animation.dialogue, "dialogue failed to wake Anwen")
			actor.set_meta("dialogue_facing_lock", false)
		player.position = Vector3(0, 0, 2)
		ambient._process(0.11)
		_check(not animation.suspended and not face.suspended, "nearby animation failed to resume")
		_check(body.visible and not hidden_equipment.visible, "approach changed equipment visibility")
		player.free()
		ambient._process(0.8)
		_check(ambient.focus_target == null, "freed player reference survived")
		actor.free()
	await process_frame
	print("NPC DISTANCE VISIBILITY: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)
