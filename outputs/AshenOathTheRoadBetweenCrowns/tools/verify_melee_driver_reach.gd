extends "res://tools/verify_opening_real_input_native.gd"

class Fixture extends Node:
	var player: CharacterBody3D

func _initialize() -> void:
	var fixture := Fixture.new()
	fixture.player = CharacterBody3D.new()
	fixture.add_child(fixture.player)
	var player_shape := CollisionShape3D.new()
	player_shape.shape = CapsuleShape3D.new()
	player_shape.shape.radius = 0.32
	fixture.player.add_child(player_shape)
	for specification in [[0.35, 1.1], [0.82, 1.2], [0.78, 1.16], [1.05, 1.43]]:
		var enemy := CharacterBody3D.new()
		var collider := CollisionShape3D.new()
		collider.shape = CapsuleShape3D.new()
		collider.shape.radius = specification[0]
		enemy.add_child(collider)
		fixture.add_child(enemy)
		var actual := _melee_approach_radius(fixture, enemy)
		if not is_equal_approx(actual, specification[1]) or actual <= specification[0] + 0.32:
			_fail("Driver approach violates actual capsule clearance/reach: radius=%.2f approach=%.2f" % [specification[0], actual])
	fixture.free()
	print("MELEE DRIVER REACH: cases=4 measured_contact=true capsule_clearance=0.06 logic_only=true")
	quit(0 if failures.is_empty() else 1)
