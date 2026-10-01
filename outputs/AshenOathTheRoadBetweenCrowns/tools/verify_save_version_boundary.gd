extends SceneTree

const Saves = preload("res://scripts/save_manager.gd")
class Receiver:
	extends Node
	var loaded := {}
	func load_save_state(data: Dictionary) -> void:
		loaded = data

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var manager := Saves.new()
	var receiver := Receiver.new()
	var path := "D:/Temp/AshenOath/save-version-%d.json" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var future := JSON.stringify({"version": Saves.CURRENT_VERSION + 1})
	write_file(path, future)
	write_file(path + ".bak", JSON.stringify({"version": Saves.CURRENT_VERSION}))
	check(not manager.load_game(receiver, path), "Future primary must not silently load an older backup")
	check(receiver.loaded.is_empty(), "Future primary must leave the game unchanged")
	check(not manager.load_first_available(receiver, [path]), "Checkpoint loading must reject future primary too")
	check(FileAccess.get_file_as_string(path) == future, "Future save bytes must remain untouched")
	receiver.loaded = {}
	write_file(path, "broken JSON")
	check(manager.load_game(receiver, path), "Corrupt JSON must still recover a compatible backup")
	check(not receiver.loaded.is_empty(), "Compatible backup must be delivered")
	for invalid in [[], {}, null, true, "9", -1, 1.5, INF, NAN]:
		check(manager.migrate_save_data({"version": invalid}).is_empty(), "Invalid version must be rejected without conversion errors")
	check(not manager.migrate_save_data({}).is_empty(), "Versionless legacy data remains migratable")
	check(not manager.migrate_save_data({"version": float(Saves.CURRENT_VERSION)}).is_empty(), "JSON numeric version remains valid")
	write_file(path, JSON.stringify({"version": []}))
	check(manager._read_slot(path).get("reason") == "invalid_version", "Malformed version must not be mislabeled as a future save")
	write_file(path, "broken JSON")
	write_file(path + ".bak", future)
	receiver.loaded = {}
	check(not manager.load_first_available(receiver, [path]), "Future backup must not be silently skipped")
	check(receiver.loaded.is_empty(), "Future backup must not change state")
	var numeric_strings := manager.migrate_save_data({"world_state": {"wychwood_pack_kills": "3", "day_night": {"day_count": "4"}}})
	check(numeric_strings.world_state.wychwood_pack_kills == 0, "Malformed kill counter must not manufacture encounter progress")
	check(numeric_strings.world_state.day_night.day_count == 0, "Malformed day count must use safe default")
	var inverted := manager.migrate_save_data({"settings": {"invert_y": true}})
	check(inverted.settings.get("invert_y") == true, "Saved mouse inversion must survive migration")
	for invalid in [[], {}, null, true, INF, NAN]:
		var migrated := manager.migrate_save_data({"world_state": {"ghoulkin_kills": invalid, "day_night": {"day_count": invalid}}})
		check(migrated.world_state.wychwood_pack_kills == 0, "Invalid legacy kills must not crash or create progress")
		check(migrated.world_state.day_night.day_count == 0, "Invalid day count must not crash")
	var valid := manager.migrate_save_data({"world_state": {"ghoulkin_kills": 3, "day_night": {"day_count": 42}}, "settings": {"invert_y": false}})
	check(valid.world_state.wychwood_pack_kills == 3 and valid.world_state.ghoulkin_kills == 3, "Valid legacy encounter progress must survive")
	check(valid.world_state.day_night.day_count == 42 and valid.settings.get("invert_y") == false, "Valid day and inversion state must survive")
	var huge := manager.migrate_save_data({"world_state": {"ghoulkin_kills": 1e100, "day_night": {"day_count": 1e100}}})
	check(huge.world_state.wychwood_pack_kills == 5 and huge.world_state.day_night.day_count == 2147483647, "Numeric bounds must apply before integer conversion")
	var settings: Dictionary = manager.migrate_save_data({"settings": {"shadow_quality": 1e100, "target_fps": 30.0, "invert_y": "true"}}).settings
	check(not settings.has("shadow_quality") and not settings.has("invert_y"), "Invalid setting values must not survive migration")
	check(settings.target_fps == 30, "Valid JSON integer setting must survive migration")
	for file in [path, path + ".bak"]:
		DirAccess.remove_absolute(file)
	manager.free()
	receiver.free()
	print("SAVE VERSION BOUNDARY: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

func write_file(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
