extends SceneTree

class TestGame extends "res://scripts/game.gd":
	func _ready() -> void:
		set_process(false)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.set_script(TestGame)
	root.add_child(game)
	game.removed_interactions = {"greyfen:clue":true}
	var snapshot: Dictionary = game.save_world_state()
	game.removed_interactions["greyfen:later"] = true
	var passed: bool = not snapshot.removed_interactions.has("greyfen:later")
	var incoming := {"removed_interactions":{"wychwood:clue":true}, "boss_states":{"white_hart_avatar":{"phase":2}}}
	game.load_world_state(incoming)
	incoming.removed_interactions.clear()
	incoming.boss_states.white_hart_avatar.phase = 3
	passed = passed and game.removed_interactions.has("wychwood:clue")
	passed = passed and game.boss_saved_states.white_hart_avatar.phase == 2
	game.free()
	await process_frame
	if not passed:
		push_error("World save dictionaries must not alias live or caller state")
	print("WORLD SNAPSHOT ISOLATION: ", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)
