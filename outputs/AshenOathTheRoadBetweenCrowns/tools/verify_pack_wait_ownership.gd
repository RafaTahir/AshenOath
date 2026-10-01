extends SceneTree

class ReadyPacks extends Node:
	func zone_packs_ready(_zone: String) -> bool:
		return true

class PlayerProbe extends CharacterBody3D:
	var transition_locked := true
	func set_transition_locked(value: bool) -> void:
		transition_locked = value

class TestGame extends "res://scripts/game.gd":
	var activations := 0
	func _ready() -> void:
		set_process(false)
	func _load_zone(_zone: String, _position: Vector3 = Vector3.ZERO) -> void:
		activations += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.set_script(TestGame)
	root.add_child(game)
	game.runtime_packs = ReadyPacks.new()
	game.add_child(game.runtime_packs)
	game.zone_pack_request_serial = 2
	game.opening_pack_waiting = true
	await game._wait_for_opening_pack("wychwood", Vector3.ZERO, 1)
	var passed: bool = game.activations == 0 and game.opening_pack_waiting
	game.campaign_pack_waiting = true
	await game._wait_for_campaign_pack("hart_glade", Vector3.ZERO, 1)
	passed = passed and game.activations == 0 and game.campaign_pack_waiting
	await game._wait_for_campaign_pack("hart_glade", Vector3.ZERO, 2)
	passed = passed and game.activations == 1 and not game.campaign_pack_waiting
	var original_zone := Node3D.new()
	game.add_child(original_zone)
	game.zone_root = original_zone
	game.pending_player_restore = {"health": {"health": 47.0}}
	game._recover_failed_pack_load()
	passed = passed and is_instance_valid(original_zone) and game.zone_root == original_zone
	passed = passed and original_zone.is_inside_tree() and not original_zone.is_queued_for_deletion()
	passed = passed and game.pending_player_restore.is_empty() and not game.game_started
	var actor := PlayerProbe.new()
	game.add_child(actor)
	actor.position = Vector3(3, 1, -2)
	actor.velocity = Vector3(2, 0, 0)
	game.player = actor
	game.game_started = true
	game.opening_pack_waiting = true
	game.campaign_pack_waiting = true
	game._recover_failed_pack_load()
	passed = passed and game.zone_root == original_zone and original_zone.is_inside_tree()
	passed = passed and game.game_started and not actor.transition_locked
	passed = passed and actor.position == Vector3(3, 1, -2) and actor.velocity == Vector3.ZERO
	passed = passed and not game.opening_pack_waiting and not game.campaign_pack_waiting
	game.free()
	await process_frame
	if not passed:
		push_error("Stale pack waiters must not activate or cancel a newer request")
	print("PACK WAIT OWNERSHIP: ", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)
