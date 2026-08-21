extends Node

var actor: Node3D
var origin := Vector3.ZERO
var direction := 1.0
var distance := 5.0
var speed := 0.75
var animation_driver: Node
var last_position := Vector3.ZERO

func configure(patrol_actor: Node3D) -> void:
	actor = patrol_actor
	origin = actor.position
	last_position = actor.position
	animation_driver = actor.find_child("CharacterAnimationDriver", true, false)

func _process(delta: float) -> void:
	if actor == null or not is_instance_valid(actor) or get_tree().paused:
		return
	actor.position.x += direction * speed * delta
	if abs(actor.position.x - origin.x) >= distance:
		direction *= -1.0
	actor.rotation.y = -PI * 0.5 if direction > 0.0 else PI * 0.5
	if animation_driver != null and is_instance_valid(animation_driver) and animation_driver.has_method("set_locomotion"):
		animation_driver.set_locomotion(clampf(speed / 3.4, 0.05, 0.45), Vector3(direction, 0.0, 0.0), true)
	last_position = actor.position
