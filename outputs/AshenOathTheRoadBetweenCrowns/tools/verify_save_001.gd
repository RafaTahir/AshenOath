extends SceneTree
## Registered save slots are exercised in a separate user-data process.

const SaveManager = preload("res://scripts/save_manager.gd")
const ZoneSpatialService = preload("res://scripts/zone_spatial_service.gd")

class ErrorLog extends Logger:
	var errors: Array[String] = []
	func _log_error(_function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != Logger.ERROR_TYPE_WARNING:
			errors.append("%s:%d %s %s" % [file, line, code, rationale])

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
	# An empty owned zone has no active trial, archery range, or companion.
	var zone_root := Node3D.new()
	var player := PlayerStub.new()
	var inventory := StateStub.new({"items": {}, "ingredients": {}, "active_oil": "", "coin": 17})
	var quests := StateStub.new({"active": {}, "completed": {}, "unlocked": {}, "world_flags": {}})
	var story_state := StateStub.new({"version": 1, "flags": {}, "values": {}})
	var progression := StateStub.new({"marks": 1, "unlocked": {"keen_edge": true}, "rewarded_quests": {"main_road_of_crows": true}})
	var world_state := {"ghoulkin_kills": 2, "day_night": {}}
	var loaded: Dictionary = {}
	func _init() -> void:
		add_child(zone_root)
		add_child(player)
		add_child(inventory)
		add_child(quests)
		add_child(story_state)
		add_child(progression)
	func save_world_state() -> Dictionary:
		return world_state.duplicate(true)
	func load_save_state(data: Dictionary) -> void:
		loaded = data.duplicate(true)
		inventory.load_state(data.get("inventory", {}))

var failures: Array[String] = []
var checks := 0
var prepared_requests: Array[Dictionary] = []
var error_log := ErrorLog.new()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-worker"):
		_run_isolated()
		return
	OS.add_logger(error_log)
	var isolated := OS.get_environment("ASHENOATH_SAVE_001_DATA_DIR").replace("\\", "/")
	var user_data := OS.get_user_data_dir().replace("\\", "/")
	_check(not isolated.is_empty() and user_data.begins_with(isolated + "/"), "test must use isolated user data before accessing registered slots")
	if not failures.is_empty():
		_finish()
		return
	var manager := SaveManager.new()
	var game := GameStub.new()
	manager.load_prepared_requested.connect(func(prepared: Dictionary): prepared_requests.append(prepared.duplicate(true)))
	root.add_child(manager)
	root.add_child(game)
	await process_frame
	_verify_migration(manager)
	_verify_atomic_backup(manager, game)
	_verify_fallback_order(manager, game)
	_verify_future_version_boundary(manager, game)
	_verify_spatial_recovery()
	game.queue_free()
	manager.queue_free()
	await process_frame
	_finish()

func _run_isolated() -> void:
	var environment := "APPDATA" if OS.get_name() == "Windows" else "XDG_DATA_HOME"
	var directory := OS.get_cache_dir().path_join("ashen-oath-save-001-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		print("SAVE-001 VERIFIER: FAIL - cannot create isolated user-data directory")
		quit(1)
		return
	OS.set_environment(environment, directory)
	OS.set_environment("ASHENOATH_SAVE_001_DATA_DIR", directory)
	var output: Array = []
	var status := OS.execute(OS.get_executable_path(), PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", get_script().resource_path, "--", "--isolated-worker",
	]), output, true)
	for text: String in output:
		print(text.trim_suffix("\n"))
	if status == 0:
		_remove_directory(directory)
	else:
		print("SAVE-001: isolated fixtures retained at " + directory)
	quit(status if status >= 0 else 1)

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
	_check(typeof(migrated.progression) == TYPE_DICTIONARY and migrated.progression.is_empty(), "legacy save did not receive neutral progression state")
	_check(int(migrated.world_state.wychwood_pack_kills) == 2, "legacy Ghoulkin count was not migrated")
	_check(float(migrated.player_health.health) >= 1.0 and not bool(migrated.player_health.dead), "dead/corrupt health was not restored safely")
	_check(float(migrated.player_stamina.stamina) == 100.0, "stamina was not clamped")
	_check(manager.migrate_save_data({"version": manager.CURRENT_VERSION + 1}).is_empty(), "future save version was accepted")

func _verify_atomic_backup(manager: Node, game: Node) -> void:
	var path: String = manager.slot_path("manual_1")
	_check(manager.save_game(game, path, "test"), "initial atomic save failed")
	_check(FileAccess.file_exists(path), "atomic save did not publish the primary file")
	_check(not FileAccess.file_exists(path + ".tmp"), "temporary save file remained after publish")
	game.inventory.state["coin"] = 29
	_check(manager.save_game(game, path, "test"), "second atomic save failed")
	_check(FileAccess.file_exists(manager.backup_path(path)), "previous save backup was not retained")
	var primary := _read_json(path)
	var backup := _read_json(manager.backup_path(path))
	_check_coin(primary, 29, "new primary save")
	_check_coin(backup, 17, "previous valid backup")
	if not _write_file(path, "{broken"):
		return
	var backup_bytes := FileAccess.get_file_as_string(manager.backup_path(path))
	game.inventory.state["coin"] = 0
	game.loaded.clear()
	_check(manager.load_game(game, path), "corrupt primary did not recover from backup")
	_complete_prepared_load(manager, game, "manual_1", "backup", 17)
	_check(FileAccess.get_file_as_string(path) == "{broken", "backup recovery overwrote the corrupt primary")
	_check(FileAccess.get_file_as_string(manager.backup_path(path)) == backup_bytes, "backup recovery altered the selected generation")

func _verify_fallback_order(manager: Node, game: Node) -> void:
	var first: String = manager.slot_path("manual_1")
	var second: String = manager.slot_path("manual_2")
	var third: String = manager.slot_path("manual_3")
	if not _write_file(first, "not json"):
		return
	_remove(manager.backup_path(first))
	game.inventory.state["coin"] = 41
	_check(manager.save_game(game, second, "test"), "fallback slot setup failed")
	game.inventory.state["coin"] = 53
	_check(manager.save_game(game, third, "test"), "later fallback slot setup failed")
	game.inventory.state["coin"] = 0
	game.loaded.clear()
	_check(manager.load_first_available(game, [first, second, third]), "valid fallback slot was not selected")
	_complete_prepared_load(manager, game, "manual_2", "primary", 41)
	if not _write_file(second, "also broken"):
		return
	game.inventory.state["coin"] = 0
	game.loaded.clear()
	_check(manager.load_first_available(game, [first, second, third]), "later valid fallback was not selected")
	_complete_prepared_load(manager, game, "manual_3", "primary", 53)
	game.inventory.state["coin"] = 0
	game.loaded.clear()
	_check(not manager.load_first_available(game, [first, second]), "all-corrupt slots accepted a load")
	_check(prepared_requests.is_empty() and not manager.is_load_pending(), "all-corrupt slots prepared a journey")
	_check(game.loaded.is_empty() and int(game.inventory.state.coin) == 0, "all-corrupt slots changed current state")
	_check(FileAccess.get_file_as_string(first) == "not json" and FileAccess.get_file_as_string(second) == "also broken", "fallback loading altered rejected files")

func _complete_prepared_load(manager: Node, game: Node, slot_id: String, source: String, coin: int) -> void:
	_check(prepared_requests.size() == 1, "load request must emit exactly one prepared journey")
	if prepared_requests.size() != 1:
		prepared_requests.clear()
		return
	var prepared: Dictionary = prepared_requests.pop_front()
	_check(bool(prepared.get("ok", false)), "prepared journey must be valid")
	_check(str(prepared.get("source", {}).get("slot_id", "")) == slot_id, "load selected the wrong slot")
	_check(str(prepared.get("source", {}).get("source", "")) == source, "load selected the wrong primary/backup source")
	_check(bool(prepared.get("source", {}).get("recovered_backup", false)) == (source == "backup"), "recovery provenance was lost")
	_check_coin(prepared.get("data", {}), coin, "prepared journey")
	_check(game.loaded.is_empty() and int(game.inventory.state.coin) == 0, "request acceptance synchronously changed current state")
	_check(manager.is_load_pending(), "accepted request is not marked pending")
	var request_id: String = str(prepared.get("request_id", ""))
	_check(not request_id.is_empty(), "prepared journey has no request identity")
	var premature: Dictionary = manager.finish_load(game, request_id, true)
	_check(not bool(premature.get("ok", false)) and str(premature.get("reason", "")) == "not_accepted", "unaccepted journey was completed")
	_check(manager.is_load_pending(), "premature completion discarded the pending journey")
	var accepted: Dictionary = manager.accept_prepared_load(request_id)
	_check(bool(accepted.get("ok", false)), "prepared journey could not be accepted")
	if not bool(accepted.get("ok", false)):
		manager.finish_load(game, request_id, false)
		return
	# Stand in for the journey coordinator's explicit apply/arrival callbacks.
	# Request acceptance alone does not promise that a real zone has loaded.
	game.load_save_state(prepared.data)
	var completed: Dictionary = manager.finish_load(game, request_id, true)
	_check(bool(completed.get("ok", false)), "accepted journey could not complete")
	_check(not manager.is_load_pending(), "completed journey remained pending")
	_check_coin(game.loaded, coin, "completed journey")
	_check(int(game.inventory.state.coin) == coin, "completed journey restored the wrong inventory generation")
	var continued: Dictionary = manager.continue_model()
	_check(bool(continued.get("available", false)), "completed journey is unavailable to Continue")
	_check(str(continued.get("selection", {}).get("slot_id", "")) == slot_id and str(continued.get("selection", {}).get("source", "")) == source, "Continue lost the completed slot/source identity")

func _verify_future_version_boundary(manager: Node, game: Node) -> void:
	var first: String = manager.slot_path("manual_1")
	var fallback: String = manager.slot_path("manual_3")
	var compatible := FileAccess.get_file_as_string(fallback)
	var future := _read_json(fallback)
	future["version"] = manager.CURRENT_VERSION + 1
	var future_bytes := JSON.stringify(future)
	if not _write_file(first, future_bytes) or not _write_file(manager.backup_path(first), compatible):
		return
	game.inventory.state["coin"] = 0
	game.loaded.clear()
	_check(not manager.load_game(game, first), "future primary silently loaded an older backup")
	_check(not manager.load_first_available(game, [first, fallback]), "future primary silently selected a later slot")
	_check(prepared_requests.is_empty() and not manager.is_load_pending(), "future primary prepared a journey")
	_check(game.loaded.is_empty() and int(game.inventory.state.coin) == 0, "future primary changed current state")
	_check(FileAccess.get_file_as_string(first) == future_bytes and FileAccess.get_file_as_string(manager.backup_path(first)) == compatible, "future primary/compatible backup bytes changed")
	if not _write_file(first, "broken future slot") or not _write_file(manager.backup_path(first), future_bytes):
		return
	_check(not manager.load_first_available(game, [first, fallback]), "future backup silently selected a later slot")
	_check(prepared_requests.is_empty() and not manager.is_load_pending(), "future backup prepared a journey")
	_check(game.loaded.is_empty() and int(game.inventory.state.coin) == 0, "future backup changed current state")
	_check(FileAccess.get_file_as_string(first) == "broken future slot" and FileAccess.get_file_as_string(manager.backup_path(first)) == future_bytes, "future backup rejection changed source files")

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
	_check(file != null and typeof(parsed) == TYPE_DICTIONARY and not parsed.is_empty(), "expected a readable save fixture: " + path)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _check_coin(payload: Dictionary, expected: int, label: String) -> void:
	var inventory: Variant = payload.get("inventory")
	_check(inventory is Dictionary and inventory.has("coin"), label + " has no saved coin value")
	if inventory is Dictionary and inventory.has("coin"):
		_check(typeof(inventory.coin) in [TYPE_INT, TYPE_FLOAT] and float(inventory.coin) == float(expected), label + " has the wrong coin value")

func _write_file(path: String, contents: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "fixture file could not be written: " + path)
	if file == null:
		return false
	file.store_string(contents)
	file.close()
	_check(FileAccess.get_file_as_string(path) == contents, "fixture bytes did not persist: " + path)
	return FileAccess.get_file_as_string(path) == contents

func _remove_directory(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for filename in directory.get_files():
		DirAccess.remove_absolute(path.path_join(filename))
	for child in directory.get_directories():
		_remove_directory(path.path_join(child))
	DirAccess.remove_absolute(path)

func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		print("SAVE-001 FAILURE: " + message)

func _finish() -> void:
	OS.remove_logger(error_log)
	_check(error_log.errors.is_empty(), "no engine or script errors during save verification")
	for error in error_log.errors:
		print("SAVE-001 ENGINE ERROR: " + error)
	if not failures.is_empty():
		print("SAVE-001 VERIFIER: FAIL (%d) checks=%d engine_errors=%d" % [failures.size(), checks, error_log.errors.size()])
		quit(1)
		return
	print("SAVE-001 VERIFIER: PASS checks=%d engine_errors=0" % checks)
	quit()
