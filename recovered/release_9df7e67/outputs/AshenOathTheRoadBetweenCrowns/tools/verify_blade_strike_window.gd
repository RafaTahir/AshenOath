extends SceneTree

const Combat = preload("res://scripts/combat_manager.gd")
class Controller extends "res://scripts/player_controller.gd":
	func _ready() -> void:
		set_physics_process(false)
		set_process(false)

class Target extends Node3D:
	var dead := false
	var display_name := "Strike fixture"
	var received := 0.0
	func apply_damage(amount: float, _tag: String) -> void:
		received += amount

var samples := 0
var first_samples := 0
var misses := 0
var passed := true

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var player := Controller.new()
	var enemy := Target.new()
	var combat := Combat.new()
	stage.add_child(player)
	stage.add_child(enemy)
	stage.add_child(combat)
	player.can_control = true
	player.blade_base_marker = Marker3D.new()
	player.blade_tip_marker = Marker3D.new()
	player.add_child(player.blade_base_marker)
	player.add_child(player.blade_tip_marker)
	enemy.position = Vector3(0, 0, -1)
	combat.contact_missed.connect(func(_result): misses += 1)
	player.blade_contact_requested.connect(func(contact):
		samples += 1
		if contact.first_sample:
			first_samples += 1
		var result := combat.resolve_player_blade_contact(player, [enemy], contact, "")
		player.confirm_blade_contact(int(contact.attack_id), bool(result.hit))
	)
	await physics_frame
	for heavy in [false, true]:
		var duration := 0.52 if heavy else 0.34
		var start := 0.30 if heavy else 0.18
		var finish := 0.64 if heavy else 0.42
		_set_blade(player, 3.0)
		player._begin_blade_attack(12.0, 2.0, heavy)
		player.attack_anim_time = duration * (1.0 - start - 0.01)
		player._update_blade_contact()
		var before := samples
		player._update_blade_contact()
		passed = passed and samples == before
		_set_blade(player, 0.0)
		player.attack_anim_time = duration * (1.0 - finish + 0.01)
		player._update_blade_contact()
		passed = passed and is_equal_approx(player.pending_attack_damage, 0.0)
		before = samples
		player.attack_anim_time = 0.0
		player._update_blade_contact()
		passed = passed and samples == before
	passed = passed and is_equal_approx(enemy.received, 24.0) and first_samples == 2 and misses == 0
	# An entire active window crossed in one low-FPS update still resolves once.
	_set_blade(player, 0.0)
	player._begin_blade_attack(12.0, 2.0, false)
	player.attack_anim_time = 0.34 * 0.5
	player._update_blade_contact()
	passed = passed and is_equal_approx(enemy.received, 36.0)
	# Forward targets cannot be hit by a distant blade, even with the legacy flag.
	_set_blade(player, 3.0)
	player._begin_blade_attack(12.0, 2.0, false)
	player.confirm_blade_contact(player.attack_sequence_id - 1, true)
	passed = passed and player.pending_attack_damage == 12.0
	player.attack_anim_time = 0.34 * 0.7
	player._update_blade_contact()
	player.attack_anim_time = 0.34 * 0.5
	player._update_blade_contact()
	passed = passed and misses == 1 and enemy.received == 36.0
	var segment := player.get_blade_world_segment()
	segment.merge({"damage": 12.0, "allow_forward_fallback": true})
	passed = passed and not combat.resolve_player_blade_contact(player, [enemy], segment, "").hit
	player._begin_blade_attack(12.0, 2.0, false)
	player.can_control = false
	var before := samples
	player._update_blade_contact()
	passed = passed and samples == before and player.pending_attack_damage == 0.0
	stage.free()
	print("BLADE STRIKE WINDOW: " + ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)

func _set_blade(player: Node3D, x: float) -> void:
	player.blade_base_marker.position = Vector3(x, 0.72, -0.5)
	player.blade_tip_marker.position = Vector3(x, 0.72, -1.5)
