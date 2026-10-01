extends SceneTree

const Combat = preload("res://scripts/combat_manager.gd")

class Target extends Node3D:
	var dead := false
	var display_name := "Contact fixture"
	var received := 0.0
	func apply_damage(amount: float, _tag: String) -> void:
		received += amount

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var player := CharacterBody3D.new()
	var enemy := Target.new()
	var combat := Combat.new()
	stage.add_child(player)
	stage.add_child(enemy)
	stage.add_child(combat)
	enemy.position = Vector3(0.2, 0, -1)
	await physics_frame
	var request := {
		"base": Vector3(0, 0.72, -0.5), "tip": Vector3(0, 0.72, -1.5),
		"damage": 12.0, "reach": 2.0, "attack_id": "fixture",
	}
	var hit := combat.resolve_player_blade_contact(player, [enemy], request, "")
	var passed := bool(hit.hit) and is_equal_approx(enemy.received, 12.0)
	passed = passed and is_equal_approx(float(hit.contact_distance), 0.2)
	passed = passed and is_equal_approx(float(hit.blade_contact_distance), 0.2)
	request.base += Vector3(4, 0, 0)
	request.tip += Vector3(4, 0, 0)
	var miss := combat.resolve_player_blade_contact(player, [enemy], request, "")
	passed = passed and not bool(miss.hit) and is_inf(float(miss.blade_contact_distance))
	passed = passed and is_equal_approx(enemy.received, 12.0)
	stage.free()
	print("BLADE CONTACT DISTANCE: " + ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
