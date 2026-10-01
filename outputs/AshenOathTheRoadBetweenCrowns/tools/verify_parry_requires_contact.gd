extends SceneTree

class Enemy extends "res://scripts/enemy_ai.gd":
	var endpoint := Vector3.ZERO
	func _ready() -> void:
		set_physics_process(false)
		set_process(false)
	func _attack_contact_point() -> Vector3:
		return endpoint

class Defender extends CharacterBody3D:
	var parry_window := 0.2
	var contacts := 0
	func take_damage(_damage: float) -> bool:
		contacts += 1
		return parry_window > 0.0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var enemy := Enemy.new()
	var defender := Defender.new()
	stage.add_child(enemy)
	stage.add_child(defender)
	enemy.player = defender
	defender.position.z = -1.0
	await physics_frame
	# Close enough for the former fallback, but the actual strike is to the side.
	enemy.attack_trace_start = Vector3(1, 1, 0)
	enemy.endpoint = Vector3(1.5, 1, 0)
	enemy._resolve_attack()
	var passed := defender.contacts == 0 and enemy.stagger_time == 0.0
	enemy.attack_trace_start = Vector3(0, 1, 0)
	enemy.endpoint = Vector3(0, 1, -1.2)
	enemy._resolve_attack()
	passed = passed and defender.contacts == 1 and enemy.stagger_time > 0.0
	enemy.stagger_time = 0.0
	defender.parry_window = 0.0
	enemy._resolve_attack()
	passed = passed and defender.contacts == 2 and enemy.stagger_time == 0.0
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3, 3, 0.1)
	collider.shape = shape
	wall.add_child(collider)
	wall.position = Vector3(0, 1, -0.5)
	stage.add_child(wall)
	await physics_frame
	await physics_frame
	defender.parry_window = 0.2
	enemy._resolve_attack()
	passed = passed and defender.contacts == 2 and enemy.stagger_time == 0.0
	stage.free()
	print("PARRY REQUIRES CONTACT: ", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)
