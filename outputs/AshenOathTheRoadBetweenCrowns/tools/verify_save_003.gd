extends SceneTree

const SaveManager = preload("res://scripts/save_manager.gd")
const StoryState = preload("res://scripts/story_state.gd")
const QuestManager = preload("res://scripts/quest_manager.gd")

var failures: Array[String] = []

func _initialize() -> void:
	var manager := SaveManager.new()
	root.add_child(manager)
	await process_frame
	_verify_migration_contract(manager)
	_verify_story_and_quest_sanitization()

	var scene := load("res://scenes/main.tscn") as PackedScene
	_check(scene != null, "Main scene failed to load")
	if scene != null:
		var game := scene.instantiate()
		root.add_child(game)
		await _frames(3)
		game.call("_new_game")
		await _wait_for_zone(game, "greyfen")
		_verify_runtime_save_shape(game, manager)
		await _verify_invalid_position_recovery(game, manager)
		game.prepare_resource_shutdown()
		await _wait_for_retirement(game)
		game.queue_free()
		await _frames(24)

	manager.queue_free()
	await process_frame
	if failures.is_empty():
		print("SAVE-003 VERIFIER: PASS")
	else:
		print("SAVE-003 VERIFIER: FAIL (%d)" % failures.size())
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _verify_migration_contract(manager: Node) -> void:
	var legacy := {
		"version": 6,
		"zone": "record_hall_old",
		"player_position": [99999.0, -20.0, 99999.0],
		"quests": {"active": {"removed_quest": {}}, "completed": {"removed_quest": true}, "tracked_quest_id": "removed_quest"},
		"quest_presentation": {"zone_id": "deleted_zone"},
		"story_state": {"flags": [], "values": {"anwen_trust": "broken", "hart_debt": 9}},
		"world_state": {"removed_interactions": ["bad"], "pending_ending": "not_an_ending", "wychwood_pack_kills": 99},
		"settings": {"fullscreen": "yes", "master_volume": 0.5, "custom_bindings": []},
	}
	var migrated: Dictionary = manager.migrate_save_data(legacy)
	_check(not migrated.is_empty(), "Legacy save migration returned empty data")
	_check(int(migrated.get("version", 0)) == int(manager.CURRENT_VERSION), "Save schema did not advance to current version")
	_check(str(migrated.get("zone", "")) == "greyfen", "Unknown campaign zone did not receive a safe fallback")
	_check(migrated.get("player_position", []) == [0.0, 1.0, 7.0], "Out-of-bounds position was not normalized")
	_check(typeof(migrated.get("quest_presentation", {}).get("zone_id", null)) == TYPE_STRING, "Quest presentation migration is malformed")
	_check(str(migrated.quest_presentation.zone_id) == "greyfen", "Quest presentation kept an invalid zone")
	_check(typeof(migrated.world_state.removed_interactions) == TYPE_DICTIONARY, "Interaction state was not sanitized")
	_check(int(migrated.world_state.wychwood_pack_kills) == 5, "Encounter kill count was not bounded")
	_check(str(migrated.world_state.pending_ending) == "", "Invalid pending ending was retained")
	_check(typeof(migrated.settings.get("fullscreen", false)) == TYPE_BOOL, "Invalid setting type was retained")
	_check(typeof(migrated.settings.get("custom_bindings", {})) == TYPE_DICTIONARY, "Custom bindings were not normalized")
	_check(manager.migrate_save_data({"version": manager.CURRENT_VERSION + 1}).is_empty(), "Future save version was accepted")

func _verify_story_and_quest_sanitization() -> void:
	var story := StoryState.new()
	story.load_state({"flags": [], "values": {"anwen_trust": "bad", "hart_debt": 99, "greyfen_fear": -4}})
	_check(int(story.values.get("anwen_trust", 99)) == 0, "Story value fallback was not neutral")
	_check(int(story.values.get("hart_debt", 0)) == 6, "Story value upper bound was not enforced")
	_check(int(story.values.get("greyfen_fear", 0)) == 0, "Story value lower bound was not enforced")
	var quests := QuestManager.new()
	root.add_child(quests)
	quests.load_quests("res://data/quests.json")
	quests.load_state({
		"active": {"unknown_quest": {"objectives": []}},
		"completed": {"unknown_quest": true},
		"unlocked": {"main_road_of_crows": true},
		"tracked_quest_id": "unknown_quest",
		"tracker_context_zone": "deleted_zone",
	})
	_check(not quests.active.has("unknown_quest"), "Unknown active quest survived migration")
	_check(not quests.completed.has("unknown_quest"), "Unknown completed quest survived migration")
	_check(quests.get_tracked_quest() == "", "Invalid tracked quest was not cleared")
	quests.queue_free()

func _verify_runtime_save_shape(game: Node, manager: Node) -> void:
	var data: Dictionary = manager.migrate_save_data({
		"version": manager.CURRENT_VERSION,
		"zone": game.current_zone_id,
		"player_position": [game.player.global_position.x, game.player.global_position.y, game.player.global_position.z],
		"quests": game.quests.save_state(),
		"story_state": game.story_state.save_state(),
		"progression": game.progression.save_state(),
		"inventory": game.inventory.save_state(),
		"settings": game.settings.settings.duplicate(true),
		"world_state": game.save_world_state(),
	})
	_check(int(data.get("version", 0)) == int(manager.CURRENT_VERSION), "Current runtime save shape did not round-trip")
	_check(typeof(data.get("quest_presentation", {})) == TYPE_DICTIONARY, "Runtime save omitted quest presentation state")
	_check(typeof(data.get("quest_beats", {})) == TYPE_DICTIONARY, "Runtime save omitted quest beat state")

func _verify_invalid_position_recovery(game: Node, manager: Node) -> void:
	var current := {
		"version": manager.CURRENT_VERSION,
		"zone": "wychwood",
		"player_position": [8.0, -4.0, -0.8],
		"quests": game.quests.save_state(),
		"story_state": game.story_state.save_state(),
		"progression": game.progression.save_state(),
		"inventory": game.inventory.save_state(),
		"settings": game.settings.settings.duplicate(true),
		"world_state": game.save_world_state(),
	}
	game.load_save_state(current)
	await _wait_for_zone(game, "wychwood")
	_check(game.player.global_position.y >= 0.9, "Loaded player remained below walkable height")
	_check(not game.spatial_service.is_river_excluded(game.player.global_position, 0.75), "Loaded player remained in river exclusion")
	_check(game.spatial_service.bank_for(game.player.global_position) == -1, "Loaded river recovery crossed to the wrong bank")

func _wait_for_zone(game: Node, zone_id: String) -> void:
	for _index in range(140):
		await process_frame
		if str(game.current_zone_id) == zone_id and game.zone_root != null and not game.zone_transition_pending:
			return
	_check(false, "Timed out waiting for zone: %s" % zone_id)

func _wait_for_retirement(game: Node) -> void:
	for _index in range(600):
		await process_frame
		if int(game.zone_lifecycle_snapshot().get("retiring_count", 0)) == 0:
			return
	_check(false, "Save verifier left a retired root alive")

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
