extends Node
class_name BoardGameOpponent

## Small social cue for the physical board-game tables. It is intentionally
## cheap and only animates when the player is close enough to notice it.

var target: Node3D
var animation_driver: Node
var invitation_cooldown := 0.0
var invitation_started := false
var check_accumulator := 0.0
var inviting := false
var target_refresh_remaining := 0.0

func configure(player_target: Node3D, driver: Node) -> void:
	target = player_target
	animation_driver = driver

func _process(delta: float) -> void:
	check_accumulator += delta
	if check_accumulator < 0.10:
		return
	delta = check_accumulator
	check_accumulator = 0.0
	invitation_cooldown = maxf(0.0, invitation_cooldown - delta)
	if target == null or not is_instance_valid(target):
		target_refresh_remaining -= delta
		if target_refresh_remaining <= 0.0:
			target_refresh_remaining = 0.75
			target = get_tree().get_first_node_in_group("player") as Node3D
	if not is_instance_valid(animation_driver):
		animation_driver = get_parent().find_child("CharacterAnimationDriver", true, false)
	if not is_instance_valid(target) or not is_instance_valid(animation_driver):
		return
	var distance := (get_parent() as Node3D).global_position.distance_to(target.global_position)
	inviting = distance <= 4.8
	if inviting and invitation_cooldown <= 0.0 and not bool(animation_driver.action_active) and str(animation_driver.presentation_state) == "":
		invitation_started = animation_driver.trigger_action("dialogue")
		invitation_cooldown = 6.0
	elif not inviting and invitation_started:
		if bool(animation_driver.action_active) and str(animation_driver.current_state) == "dialogue":
			animation_driver.stop_action()
		invitation_started = false
