extends Node

var actor: Node3D
var origin := Vector3.ZERO
var direction := 1.0
var distance := 5.0
var speed := 0.75

func configure(patrol_actor: Node3D) -> void:
	actor = patrol_actor
	origin = actor.position

func _process(delta: float) -> void:
	if actor == null or not is_instance_valid(actor) or get_tree().paused:
		return
	actor.position.x += direction * speed * delta
	if abs(actor.position.x - origin.x) >= distance:
		direction *= -1.0
	actor.rotation.y = -PI * 0.5 if direction > 0.0 else PI * 0.5
