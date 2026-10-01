extends SceneTree

const Settings = preload("res://scripts/settings_manager.gd")
var failures := 0

func _initialize() -> void:
	var manager := Settings.new()
	var path := "D:/Temp/AshenOath/settings-roundtrip-%d.json" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"shadow_quality": 2, "visual_density": 2, "foliage_density": 0, "target_fps": 60, "invert_y": true, "master_volume": 0.4}))
	file.close()
	manager._load_settings(path)
	check(manager.settings.shadow_quality == 2, "JSON must restore integer shadow setting")
	check(manager.settings.visual_density == 2, "JSON must restore integer visual density")
	check(manager.settings.foliage_density == 0, "JSON must restore integer foliage density")
	check(manager.settings.target_fps == 60, "JSON must restore integer FPS preference")
	check(manager.settings.invert_y and is_equal_approx(manager.settings.master_volume, 0.4), "Boolean and float choices must survive")
	manager.restore_settings({"shadow_quality": 0.0, "master_volume": 1, "invert_y": false})
	check(manager.settings.shadow_quality == 0 and manager.settings.master_volume == 1.0 and not manager.settings.invert_y, "Save-state restore must accept valid numeric representations")
	for invalid in [[], {}, null, true, "2", INF, NAN, 1e100, 1.5]:
		manager.restore_settings({"shadow_quality": invalid})
		check(manager.settings.shadow_quality == 0, "Malformed discrete values must not overwrite settings")
	manager.restore_settings({"master_volume": NAN, "invert_y": "true", "unknown_setting": true})
	check(manager.settings.master_volume == 1.0 and not manager.settings.invert_y, "Nonfinite floats and string booleans must not overwrite settings")
	check(not manager.settings.has("unknown_setting"), "Unknown settings must remain excluded")
	var bindings := {"jump": {"key": 32}}
	manager.restore_settings({"custom_bindings": bindings})
	bindings.jump.key = 65
	check(manager.settings.custom_bindings.jump.key == 32, "Restored binding maps must not alias input data")
	DirAccess.remove_absolute(path)
	manager.free()
	print("SETTINGS ROUNDTRIP: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
