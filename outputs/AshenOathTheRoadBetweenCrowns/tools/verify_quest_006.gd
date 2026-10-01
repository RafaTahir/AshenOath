extends SceneTree

const EpilogueResolver = preload("res://scripts/epilogue_resolver.gd")
const StoryState = preload("res://scripts/story_state.gd")
var failures := 0

func _initialize() -> void:
	var contract = JSON.parse_string(FileAccess.get_file_as_string("res://epilogue_contract.json"))
	check(typeof(contract) == TYPE_DICTIONARY, "QUEST-006 contract is invalid")
	var state = StoryState.new()
	root.add_child(state)
	state.set_flag("names_policy", "published")
	state.set_flag("crow_shrine_state", "cleansed")
	state.set_flag("edric_stance", "cooperate")
	state.set_flag("halvern_fate", "witness")
	state.set_flag("senn_fate", "testimony")
	state.set_flag("mill_fate", "preserved")
	state.set_flag("widow_truth", "told")
	state.set_flag("iron_fate", "memorial")
	state.set_flag("mira_truth", "confessed")
	state.set_flag("black_dog_fate", "spared")
	state.set_flag("returned_soldier_fate", "named")
	state.set_flag("oren_charm_returned", true)
	state.set_flag("three_candles_lit", true)
	state.set_flag("rook_map_fate", "preserved")
	state.set_flag("ash_measure_fate", "farmer")
	state.set_flag("bannerless_fate", "testimony")
	state.adjust_value("anwen_trust", 2)
	var witness := EpilogueResolver.resolve("expose", state)
	var mercy := EpilogueResolver.resolve("free", state)
	var duty := EpilogueResolver.resolve("bind", state)
	var ash := EpilogueResolver.resolve("kill", state)
	for result in [witness, mercy, duty, ash]:
		check(result.size() >= 6, "A resolved epilogue omitted consequence cards")
	check(witness[0] != mercy[0] and mercy[0] != duty[0] and duty[0] != ash[0], "Ending covenant cards are not distinct")
	check("Elna's bell" in witness[-1], "Village-story consequences are missing")
	check("Oren's charm: returned to his named grave" in witness[-1], "Oren's returned charm is missing from the epilogue")
	check("Bram, Sella, and Oren's candles: lit along the cemetery road" in witness[-1], "Three named candles are missing from the epilogue")
	check("Rook's road: preserved" in witness[-1], "Rook's preserved road is missing from the epilogue")
	check("the miller's measure: farmer" in witness[-1], "The miller's measure outcome is missing from the epilogue")
	check("the bannerless soldiers: testimony" in witness[-1], "The deserters' testimony is missing from the epilogue")

	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.settings.set_quality_preset("balanced")
	game.call("_new_game")
	await settle(3)
	game.quests.unlocked["main_hart_remembers"] = true
	game.quests.start_quest("main_hart_remembers")
	game.story_state.set_flag("confession_method", "kael")
	game.call("_show_ending_consequence", "expose")
	await settle(2)
	var saved_cards = game.story_state.get_flag("epilogue_cards", [])
	check(typeof(saved_cards) == TYPE_ARRAY and saved_cards.size() >= 4, "Runtime epilogue cards were not stored")
	var saved: Dictionary = game.story_state.save_state()
	game.story_state.load_state(saved)
	check(game.story_state.get_flag("epilogue_cards", []).size() == saved_cards.size(), "Epilogue cards failed save round-trip")
	var result_code := 0 if failures == 0 else 1
	await _shutdown_game(game, state)
	print("QUEST-006 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(result_code)

func settle(count: int) -> void:
	for _index in range(count):
		await process_frame

func _shutdown_game(game: Node, state: Node) -> void:
	if is_instance_valid(game) and game.has_method("prepare_resource_shutdown"):
		game.prepare_resource_shutdown()
		await settle(20)
	if is_instance_valid(game) and game.has_method("finalize_resource_shutdown"):
		game.finalize_resource_shutdown()
		await settle(12)
	print("VERIFIER_PHASE: SHUTDOWN")
	if is_instance_valid(game):
		game.queue_free()
		await settle(8)
	if is_instance_valid(state):
		state.queue_free()
		await settle(4)
	RenderingServer.force_sync()
	await settle(4)

func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
