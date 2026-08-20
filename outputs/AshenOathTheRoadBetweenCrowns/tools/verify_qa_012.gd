extends SceneTree

const Game = preload("res://scripts/game.gd")

const RELEASED_ZONES := [
	"greyfen",
	"wychwood",
	"deep_wood",
	"old_mill",
	"burned_farmstead",
	"marsh_crossing",
	"bandit_road",
	"vargan_approach",
	"vargan_court",
	"record_hall",
	"undercroft",
	"assembly",
	"hart_glade"
]

var failures := 0

func _initialize() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	check(scene != null, "Main scene is missing")
	if scene == null:
		quit(1)
		return
	var game := scene.instantiate() as Node
	root.add_child(game)
	await process_frame
	game.call("_new_game")
	await _frames(5)
	check(bool(game.player.can_control), "New Game did not restore player control")
	for zone_id in RELEASED_ZONES:
		game.call("_load_zone", zone_id, Vector3(0, 1, 12))
		await _frames(2)
		check(str(game.current_zone_id) == zone_id, "Released zone did not activate: %s" % zone_id)
		check(not bool(game.zone_transition_pending), "Released zone remained in transition: %s" % zone_id)
		check(bool(game.player.can_control), "Player remained locked in zone: %s" % zone_id)
	var saved: Dictionary = game.save_world_state()
	check(saved.has("removed_interactions") and saved.has("boss_states") and saved.has("day_night"), "World save omitted campaign state")
	game.load_world_state(saved)
	check(game.call("_grounded_spawn_position", game.player.global_position) != null, "Reloaded player position is not grounded")
	print("QA-012 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	if game.has_method("prepare_resource_shutdown"):
		game.prepare_resource_shutdown()
	game.free()
	await _frames(4)
	quit(0 if failures == 0 else 1)

func _frames(count: int) -> void:
	for index in range(count):
		await process_frame

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
