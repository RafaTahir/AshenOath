extends Node
class_name BoardGameOpponent

## Small social cue for the physical board-game tables. It is intentionally
## cheap and only animates when the player is close enough to notice it.

var target: Node3D
var gesture: Node3D
var phase := 0.0
var check_accumulator := 0.0
var inviting := false

func configure(player_target: Node3D, gesture_node: Node3D) -> void:
	target = player_target
	gesture = gesture_node
	if gesture != null:
		gesture.visible = false

func _process(delta: float) -> void:
	check_accumulator += delta
	if check_accumulator < 0.10:
		return
	check_accumulator = 0.0
	if target == null or not is_instance_valid(target):
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty() and players[0] is Node3D:
			target = players[0]
	if target == null or gesture == null:
		return
	var distance := (get_parent() as Node3D).global_position.distance_to(target.global_position)
	inviting = distance <= 4.8
	gesture.visible = inviting
	if inviting:
		phase += delta * 5.0
		gesture.rotation_degrees.z = sin(phase) * 20.0
		gesture.position.y = 1.18 + sin(phase * 0.5) * 0.025
	else:
		gesture.rotation_degrees.z = 0.0
