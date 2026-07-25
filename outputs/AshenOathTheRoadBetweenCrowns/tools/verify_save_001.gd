extends SceneTree

const SaveManager = preload("res://scripts/save_manager.gd")
const ZoneSpatialService = preload("res://scripts/zone_spatial_service.gd")

class StateStub:
	extends Node
	var state: Dictionary
	func _init(initial: Dictionary = {}) -> void:
		state = initial.duplicate(true)
	func save_state() -> Dictionary:
		return state.duplicate(true)
	func load_state(value: Dictionary) -> void:
		state = value.duplicate(true)

class PlayerStub:
	extends Node3D
	var health_component := StateStub.new({"health": 80.0, "max_health": 100.0, "dead": false})
	var stamina_component := StateStub.new({"stamina": 55.0, "max_stamina": 100.0})
	func _init() -> void:
		add_child(health_component)
		add_child(stamina_component)

class GameStub:
	extends Node
	var current_zone_id := "greyfen"
	var player := PlayerStub.new()
	var inventory := StateStub.new({"items": {}, "ingredients": {}, "active_oil": "", "coin": 17})
	var quests := StateStub.new({"active": {}, "completed": {}, "unlocked": {}, "world_flags": {}})
	var story_state := StateStub.new({"version": 1, "flags": {}, "values": {}})
	var world_state := {"ghoulkin_kills": 2, "day_night": {}}
	var loaded: Dictionary = {}
	func _init() -> void:
		add_child(player)
		add_child(inventory)
		add_child(quests)
		add_child(story_state)
	func save_world_state() -> Dictionary:
		return world_state.duplicate(true)
	func load_save_state(data: Dictionary) -> void:
		loaded = data.duplicate(true)
		inventory.load_state(data.get("inventory", {}))

var failures: Array[String] = []
var test_paths := [
	"user://save_001_primary_test.json",
	"user://save_001_secondary_test.json",
]

func _initialize() -> void:
	_cleanup()
	var manager := SaveManager.new()
	var game := GameStub.new()
	root.add_child(manager)
	root.add_child(game)
	await process_frame
	_verify_migration(manager)
	_verify_atomic_backup(manager, game)
	_verify_fallback_order(manager, game)
	_verify_spatial_recovery()
	_cleanup()
	game.queue_free()
	manager.queue_free()
	await process_frame
	_finish()

func _verify_migration(manager: Node) -> void:
	var legacy := {
		"version": 2,
		"zone": "unknown_castle_room",
		"player_position": [INF, -50000.0, 2.0],
		"quests": {"completed": {"main_road_of_crows": true}},
		"story_state": {"flags": [], "values": "damaged"},
		"inventory": {"items": [], "coin": 12},
		"world_state": {"ghoulkin_kills": 2},
		"player_health": {"health": -20.0, "max_health": "bad", "dead": true},
		"player_stamina": {"stamina": 9000.0, "max_stamina": 100.0},
	}
	var migrated: Dictionary = manager.migrate_save_data(legacy)
	_check(int(migrated.version) == manager.CURRENT_VERSION, "legacy save version was not migrated")
	_check(str(migrated.zone) == "greyfen", "unknown legacy zone did not fall back to Greyfen")
	_check(migrated.player_position == [0.0, 1.0, 7.0], "invalid legacy position was not reset")
	_check(bool(migrated.story_state.flags.get("legacy_report_choice_required", false)), "legacy report choice was invented or omitted")
	_check(int(migrated.world_state.wychwood_pack_kills) == 2, "legacy Ghoulkin count was not migrated")
	_check(float(migrated.player_health.health) >= 1.0 and not bool(migrated.player_health.dead), "dead/corrupt health was not restored safely")
	_check(float(migrated.player_stamina.stamina) == 100.0, "stamina was not clamped")
	_check(manager.migrate_save_data({"version": manager.CURRENT_VERSION + 1}).is_empty(), "future save version was accepted")

func _verify_atomic_backup(manager: Node, game: Node) -> void:
	var path := str(test_paths[0])
	_check(manager.save_game(game, path, "test"), "initial atomic save failed")
	_check(FileAccess.file_exists(path), "atomic save did not publish the primary file")
	_check(not FileAccess.file_exists(path + ".tmp"), "temporary save file remained after publish")
	game.inventory.state["coin"] = 29
	_check(manager.save_game(game, path, "test"), "second atomic save failed")
	_check(FileAccess.file_exists(manager.backup_path(path)), "previous save backup was not retained")
	var primary := _read_json(path)
	var backup := _read_json(manager.backup_path(path))
	_check(int(primary.inventory.coin) == 29, "new primary save has stale state")
	_check(int(backup.inventory.coin) == 17, "backup does not contain the previous valid state")
	var corrupt := FileAccess.open(path, FileAccess.WRITE)
	corrupt.store_string("{broken")
	corrupt = null
	game.inventory.state["coin"] = 0
	_check(manager.load_game(game, path), "corrupt primary did not recover from backup")
	_check(int(game.loaded.inventory.coin) == 17, "backup recovery loaded the wrong generation")

func _verify_fallback_order(manager: Node, game: Node) -> void:
	var first := str(test_paths[0])
	var second := str(test_paths[1])
	var corrupt := FileAccess.open(first, FileAccess.WRITE)
	corrupt.store_string("not json")
	corrupt = null
	_remove(manager.backup_path(first))
	game.inventory.state["coin"] = 41
	_check(manager.save_game(game, second, "test"), "fallback slot setup failed")
	game.inventory.state["coin"] = 0
	_check(manager.load_first_available(game, [first, second]), "valid fallback slot was not loaded")
	_check(int(game.loaded.inventory.coin) == 41, "fallback order did not select the first valid slot")

func _verify_spatial_recovery() -> void:
	var service := ZoneSpatialService.new()
	service.configure("wychwood", 0.0, Vector2(22.0, 18.0))
	var recovered: Vector3 = service.nearest_safe(Vector3(8.0, -4.0, 0.0), -1)
	_check(not service.is_river_excluded(recovered, 0.8), "invalid saved river position did not recover")
	_check(service.bank_for(recovered) == -1, "saved position recovery crossed to the wrong bank")
	_check(recovered.y >= 0.0, "saved position recovery remained below the world")
	service.free()

func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text()) if file != null else {}
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _cleanup() -> void:
	for path in test_paths:
		for suffix in ["", ".bak", ".tmp"]:
			_remove(str(path) + suffix)

func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _finish() -> void:
	if not failures.is_empty():
		print("SAVE-001 VERIFIER: FAIL (%d)" % failures.size())
		quit(1)
		return
	print("SAVE-001 VERIFIER: PASS")
	quit()
