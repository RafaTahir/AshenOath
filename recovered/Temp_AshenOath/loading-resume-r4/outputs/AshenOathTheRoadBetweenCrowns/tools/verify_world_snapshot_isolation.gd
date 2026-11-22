extends SceneTree

class TestGame extends "res://scripts/game.gd":
	func _ready() -> void:
		set_process(false)

class ControlledPlayer extends Node3D:
	var can_control := true
	var transition_locked := false

class InputContext extends Node:
	func is_gameplay_context() -> bool: return true

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := TestGame.new()
	game.add_child(game.zone_residency)
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
	var story = load("res://scripts/story_state.gd").new()
	var quests = load("res://scripts/quest_manager.gd").new()
	root.add_child(story)
	root.add_child(quests)
	quests.load_quests("res://data/quests.json")
	story.world_reads.begin("wychwood")
	story.get_flag("rootbound_colossus_defeated", false)
	story.has_evidence("local_fact")
	story.world_reads.end()
	quests.world_reads.begin("wychwood")
	quests.is_objective_done("main_road_of_crows", "speak_anwen")
	quests.is_unlocked("main_road_of_crows")
	quests.world_reads.end()
	var signature := hash([story.world_signature_state("wychwood"), quests.world_signature_state("wychwood")])
	story.set_flag("unrelated_prop", "open")
	story.record_evidence("elsewhere", {})
	quests.unlocked["elsewhere"] = true
	passed = passed and signature == hash([story.world_signature_state("wychwood"), quests.world_signature_state("wychwood")])
	story.record_evidence("local_fact", {})
	passed = passed and signature != hash([story.world_signature_state("wychwood"), quests.world_signature_state("wychwood")])
	quests.world_reads.begin("direct_reader")
	var direct_read: Dictionary = quests.unlocked
	quests.world_reads.end()
	var direct_signature := hash(quests.world_signature_state("direct_reader"))
	direct_read["later"] = true
	passed = passed and direct_signature != hash(quests.world_signature_state("direct_reader"))
	game.zone_root = Node3D.new()
	game.add_child(game.zone_root)
	game.player = ControlledPlayer.new()
	game.add_child(game.player)
	game.input_router = InputContext.new()
	game.add_child(game.input_router)
	game.game_started = true
	game._record_loading_metrics({"phase": "world_ready"})
	passed = passed and game.opening_startup_metrics.has("world_ready_ms") and not game.opening_startup_metrics.has("first_control_ms")
	game.opening_scene_pending = true
	game._record_first_control()
	passed = passed and not game.opening_startup_metrics.has("first_control_ms")
	game.opening_scene_pending = false
	game.zone_root.set_meta("opening_scene_active", true)
	game._record_first_control()
	passed = passed and not game.opening_startup_metrics.has("first_control_ms")
	game.zone_root.set_meta("opening_scene_active", false)
	game.player.can_control = false
	game._record_first_control()
	passed = passed and not game.opening_startup_metrics.has("first_control_ms")
	game.player.can_control = true
	game._record_first_control()
	passed = passed and game.opening_startup_metrics.has("first_control_ms")
	game.game_started = false
	story.free()
	quests.free()
	game.free()
	await process_frame
	if not passed:
		push_error("World save dictionaries must not alias live or caller state")
	print("WORLD SNAPSHOT ISOLATION: ", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)
