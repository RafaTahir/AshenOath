extends Node

const CURRENT_VERSION := 9
const SAVE_PATH := "user://ashen_oath_save.json"
const AUTOSAVE_PATH := "user://ashen_oath_autosave.json"
const CHECKPOINT_PATH := "user://ashen_oath_checkpoint.json"
const RELEASED_ZONES := [
	"greyfen", "wychwood", "ruins", "cemetery", "deep_wood", "old_mill",
	"burned_farmstead", "marsh_crossing", "bandit_road", "vargan_approach",
	"vargan_court", "record_hall", "undercroft", "assembly", "hart_glade"
]

signal message(text: String)

func save_game(game, path: String = SAVE_PATH, label: String = "Game saved.") -> bool:
	# Deferred autosaves can outlive a zone teardown. Never serialize a partially
	# released runtime, but keep invalid saves visible during normal play.
	if _is_game_shutting_down(game):
		return false
	if not _has_valid_player(game):
		message.emit("Save failed. Your previous save was preserved.")
		return false
	var data := _build_save_data(game)
	if not _write_atomic(path, data):
		message.emit("Save failed. Your previous save was preserved.")
		return false
	message.emit(label)
	return true

func load_game(game, path: String = SAVE_PATH) -> bool:
	var result := _read_slot(path)
	var recovered_backup := false
	if not bool(result.get("ok", false)):
		var backup_result := _read_slot(backup_path(path))
		if not bool(backup_result.get("ok", false)):
			message.emit("No valid save found.")
			return false
		result = backup_result
		recovered_backup = true
	game.load_save_state(result.data)
	message.emit("Recovered the previous save backup." if recovered_backup else "Game loaded.")
	return true

func autosave(game) -> bool:
	return save_game(game, AUTOSAVE_PATH, "Autosaved.")

func checkpoint(game) -> bool:
	return save_game(game, CHECKPOINT_PATH, "Checkpoint reached.")

func _is_game_shutting_down(game) -> bool:
	if game == null or not is_instance_valid(game):
		return true
	# A missing dynamic property is a safe non-shutdown value. Comparing against
	# true avoids invoking a runtime type constructor on older Godot Web builds.
	return game.get("resource_shutdown_prepared") == true

func _has_valid_player(game) -> bool:
	if game == null or not is_instance_valid(game):
		return false
	var runtime_player = game.get("player")
	return runtime_player != null and is_instance_valid(runtime_player)

func load_checkpoint(game) -> bool:
	return load_first_available(game, [CHECKPOINT_PATH, AUTOSAVE_PATH, SAVE_PATH])

func load_first_available(game, paths: Array) -> bool:
	for path_value in paths:
		var path := str(path_value)
		var result := _read_slot(path)
		var recovered_backup := false
		if not bool(result.get("ok", false)):
			result = _read_slot(backup_path(path))
			recovered_backup = bool(result.get("ok", false))
		if bool(result.get("ok", false)):
			game.load_save_state(result.data)
			message.emit("Recovered a checkpoint backup." if recovered_backup else "Checkpoint loaded.")
			return true
	message.emit("No valid checkpoint found.")
	return false

func migrate_save_data(raw_data: Dictionary) -> Dictionary:
	var data: Dictionary = raw_data.duplicate(true)
	var source_version := int(data.get("version", 0))
	if source_version > CURRENT_VERSION:
		return {}
	data["version"] = CURRENT_VERSION
	data["zone"] = _normalize_zone(str(data.get("zone", "greyfen")))
	data["player_position"] = _normalize_position(data.get("player_position", [0.0, 1.0, 7.0]), data.zone)
	data["world_sector"] = _normalize_zone(str(data.get("world_sector", data.zone)))
	data["world_position"] = _normalize_position(data.get("world_position", _local_to_world(data.player_position, data.world_sector)), data.world_sector)
	if not data.has("seamless_world") or typeof(data.get("seamless_world")) != TYPE_DICTIONARY:
		data["seamless_world"] = {}
	for key in ["inventory", "vendors", "quests", "story_state", "progression", "world_state", "player_health", "player_stamina", "equipment"]:
		if not data.has(key) or typeof(data.get(key)) != TYPE_DICTIONARY:
			data[key] = {}
	_sanitize_dictionary_fields(data.inventory, ["items", "ingredients"])
	_sanitize_dictionary_fields(data.vendors, ["emergency_refill_claimed"])
	_sanitize_dictionary_fields(data.quests, ["active", "completed", "unlocked", "world_flags"])
	_sanitize_dictionary_fields(data.story_state, ["flags", "values"])
	_sanitize_dictionary_fields(data.progression, ["unlocked", "rewarded_quests"])
	_sanitize_dictionary_fields(data.world_state, ["removed_interactions", "day_night"])
	if not data.has("quest_presentation") or typeof(data.get("quest_presentation")) != TYPE_DICTIONARY:
		data["quest_presentation"] = {}
	if not data.has("quest_beats") or typeof(data.get("quest_beats")) != TYPE_DICTIONARY:
		data["quest_beats"] = {}
	if not data.has("settings") or typeof(data.get("settings")) != TYPE_DICTIONARY:
		data["settings"] = {}
	var presentation: Dictionary = data.quest_presentation
	var presentation_zone := _normalize_zone(str(presentation.get("zone_id", data.zone)))
	presentation["zone_id"] = presentation_zone
	data["quest_presentation"] = presentation
	if source_version < 3 and _legacy_road_complete(data.quests):
		var story: Dictionary = data.story_state
		var flags: Dictionary = story.get("flags", {}) if typeof(story.get("flags", {})) == TYPE_DICTIONARY else {}
		flags["legacy_report_choice_required"] = true
		story["flags"] = flags
		data["story_state"] = story
	var world: Dictionary = data.world_state
	world["removed_interactions"] = _sanitize_bool_map(world.get("removed_interactions", {}))
	if not world.has("wychwood_pack_kills"):
		world["wychwood_pack_kills"] = int(world.get("ghoulkin_kills", 0))
	world["wychwood_pack_kills"] = clampi(int(world.get("wychwood_pack_kills", 0)), 0, 5)
	world["ghoulkin_kills"] = int(world.get("wychwood_pack_kills", 0))
	world["pending_ending"] = _normalize_ending(str(world.get("pending_ending", "")))
	if typeof(world.get("boss_states", {})) != TYPE_DICTIONARY:
		world["boss_states"] = {}
	if typeof(world.get("day_night", {})) != TYPE_DICTIONARY:
		world["day_night"] = {}
	else:
		var day_night: Dictionary = world.get("day_night", {})
		day_night["world_time_minutes"] = clampf(_finite_number(day_night.get("world_time_minutes", 990.0), 990.0), 0.0, 1439.999)
		day_night["day_count"] = maxi(int(day_night.get("day_count", 0)), 0)
		world["day_night"] = day_night
	data["world_state"] = world
	data["player_health"] = _normalize_health(data.player_health)
	data["player_stamina"] = _normalize_stamina(data.player_stamina)
	data["settings"] = _sanitize_settings(data.settings)
	data["saved_at_utc"] = str(data.get("saved_at_utc", Time.get_datetime_string_from_system(true)))
	data["migrated_from_version"] = source_version
	return data

func backup_path(path: String) -> String:
	return path + ".bak"

func _build_save_data(game) -> Dictionary:
	return {
		"version": CURRENT_VERSION,
		"saved_at_utc": Time.get_datetime_string_from_system(true),
		"zone": game.current_zone_id,
		"world_sector": game.current_zone_id,
		"player_position": [
			game.player.global_position.x,
			game.player.global_position.y,
			game.player.global_position.z
		],
		"world_position": _game_world_position(game),
		"seamless_world": game.seamless_world.save_state() if game.get("seamless_world") != null and game.seamless_world.has_method("save_state") else {},
		"player_health": game.player.health_component.save_state(),
		"player_stamina": game.player.stamina_component.save_state(),
		"equipment": game.player.save_equipment_state() if game.player.has_method("save_equipment_state") else {},
		"inventory": game.inventory.save_state(),
		"vendors": game.vendor_service.save_state() if game.get("vendor_service") != null else {},
		"quests": game.quests.save_state(),
		"quest_presentation": game.quest_presentation.save_state() if game.get("quest_presentation") != null else {},
		"quest_beats": game.quest_beats.save_state() if game.get("quest_beats") != null else {},
		"story_state": game.story_state.save_state(),
		"progression": game.progression.save_state(),
		"settings": game.settings.settings.duplicate(true) if game.get("settings") != null else {},
		"world_state": game.save_world_state()
	}

func _write_atomic(path: String, data: Dictionary) -> bool:
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	file = null
	var written := _read_slot(temporary)
	if not bool(written.get("ok", false)):
		_remove_if_present(temporary)
		return false
	var absolute_path := ProjectSettings.globalize_path(path)
	var absolute_temporary := ProjectSettings.globalize_path(temporary)
	var absolute_backup := ProjectSettings.globalize_path(backup_path(path))
	_remove_absolute_if_present(absolute_backup)
	if FileAccess.file_exists(path):
		if DirAccess.rename_absolute(absolute_path, absolute_backup) != OK:
			_remove_if_present(temporary)
			return false
	var rename_error := DirAccess.rename_absolute(absolute_temporary, absolute_path)
	if rename_error != OK:
		if FileAccess.file_exists(backup_path(path)):
			DirAccess.rename_absolute(absolute_backup, absolute_path)
		_remove_if_present(temporary)
		return false
	return true

func _read_slot(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "path": path, "reason": "missing"}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "path": path, "reason": "unreadable"}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {"ok": false, "path": path, "reason": "invalid_json"}
	var parsed = parser.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "path": path, "reason": "invalid_json"}
	var migrated := migrate_save_data(parsed)
	if migrated.is_empty():
		return {"ok": false, "path": path, "reason": "future_version"}
	return {"ok": true, "path": path, "data": migrated}

func _normalize_zone(zone: String) -> String:
	zone = zone.strip_edges().to_lower()
	var aliases := {
		"deep_woods": "deep_wood",
		"long_road": "bandit_road",
		"castle_approach": "vargan_approach",
		"courtyard": "vargan_court",
	}
	zone = str(aliases.get(zone, zone))
	return zone if zone in RELEASED_ZONES else "greyfen"

func _game_world_position(game) -> Array:
	var local_position := Vector3(game.player.global_position)
	var service = game.get("seamless_world")
	if service != null and service.has_method("world_position_for_player"):
		local_position = service.world_position_for_player(game.player, game.current_zone_id)
	return [local_position.x, local_position.y, local_position.z]

func _local_to_world(local_position: Array, zone: String) -> Array:
	var position := _normalize_position(local_position, zone)
	var coordinates := {
		"greyfen": Vector2i(0, 0),
		"wychwood": Vector2i(0, 1),
		"deep_wood": Vector2i(0, 2),
		"old_mill": Vector2i(0, 3),
		"burned_farmstead": Vector2i(0, 4),
		"marsh_crossing": Vector2i(0, 5),
		"bandit_road": Vector2i(0, 6),
		"vargan_approach": Vector2i(1, 6),
		"vargan_court": Vector2i(1, 7),
		"record_hall": Vector2i(1, 8),
		"undercroft": Vector2i(1, 9),
		"assembly": Vector2i(1, 10),
		"hart_glade": Vector2i(1, 11),
		"cemetery": Vector2i(1, 0),
		"ruins": Vector2i(-1, 0),
	}
	var cell: Vector2i = coordinates.get(zone, Vector2i.ZERO)
	return [float(cell.x * 48.0) + float(position[0]), position[1], float(cell.y * 40.0) + float(position[2])]

func _normalize_position(raw_position: Variant, zone: String) -> Array:
	if typeof(raw_position) != TYPE_ARRAY or raw_position.size() < 3:
		return _default_position(zone)
	var result: Array = []
	for index in range(3):
		if typeof(raw_position[index]) not in [TYPE_INT, TYPE_FLOAT]:
			return _default_position(zone)
		var value := float(raw_position[index])
		if not is_finite(value) or absf(value) > 10000.0:
			return _default_position(zone)
		result.append(value)
	return result

func _default_position(zone: String) -> Array:
	var defaults := {
		"greyfen": [0.0, 1.0, 7.0],
		"wychwood": [0.0, 1.0, 8.0],
		"cemetery": [0.0, 1.0, 12.0],
		"deep_wood": [0.0, 1.0, 12.0],
		"old_mill": [0.0, 1.0, 12.0],
		"burned_farmstead": [0.0, 1.0, 12.0],
		"marsh_crossing": [0.0, 1.0, 12.0],
		"bandit_road": [0.0, 1.0, 12.0],
		"vargan_approach": [0.0, 1.0, 10.0],
		"vargan_court": [0.0, 1.0, 12.0],
		"record_hall": [0.0, 1.0, 7.0],
		"undercroft": [0.0, 1.0, 12.0],
		"assembly": [0.0, 1.0, 12.0],
		"hart_glade": [0.0, 1.0, 12.0],
	}
	return defaults.get(zone, [0.0, 1.0, 6.0]).duplicate()

func _normalize_health(state: Dictionary) -> Dictionary:
	var maximum := clampf(_finite_number(state.get("max_health", 100.0), 100.0), 1.0, 999.0)
	var current := clampf(_finite_number(state.get("health", maximum), maximum), 1.0, maximum)
	return {"health": current, "max_health": maximum, "dead": false}

func _normalize_stamina(state: Dictionary) -> Dictionary:
	var maximum := clampf(_finite_number(state.get("max_stamina", 100.0), 100.0), 1.0, 999.0)
	var current := clampf(_finite_number(state.get("stamina", maximum), maximum), 0.0, maximum)
	return {"stamina": current, "max_stamina": maximum}

func _sanitize_settings(state: Dictionary) -> Dictionary:
	var allowed := [
		"quality_preset", "resolution_scale", "shadow_quality", "foliage_density", "visual_density",
		"vsync", "fullscreen", "potato_mode", "target_fps", "mouse_sensitivity",
		"gamepad_look_sensitivity", "gamepad_deadzone", "gamepad_invert_x", "gamepad_invert_y",
		"gamepad_vibration", "gamepad_rumble_strength", "gamepad_profiles", "custom_bindings",
		"touch_controls", "touch_look_sensitivity",
		"invert_y", "master_volume", "subtitle_scale", "camera_shake", "reduced_motion",
		"high_contrast", "control_preset",
	]
	var result: Dictionary = {}
	for key in allowed:
		if not state.has(key):
			continue
		var value: Variant = state[key]
		if key in ["gamepad_profiles", "custom_bindings"]:
			if typeof(value) == TYPE_DICTIONARY:
				result[key] = value.duplicate(true)
		elif key in ["vsync", "fullscreen", "potato_mode", "gamepad_invert_x", "gamepad_invert_y", "gamepad_vibration", "reduced_motion", "high_contrast"]:
			if typeof(value) == TYPE_BOOL:
				result[key] = value
		elif key in ["shadow_quality", "foliage_density", "visual_density", "target_fps"]:
			if typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)):
				result[key] = int(value)
		elif key in ["quality_preset", "touch_controls", "control_preset"]:
			if typeof(value) == TYPE_STRING:
				result[key] = value
		elif typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)):
			result[key] = float(value)
	return result

func _sanitize_bool_map(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var result: Dictionary = {}
	for key in value:
		if typeof(value[key]) == TYPE_BOOL and bool(value[key]):
			result[str(key)] = true
	return result

func _normalize_ending(value: String) -> String:
	return value if value in ["", "witness", "mercy", "duty", "ash"] else ""

func _legacy_road_complete(quests: Dictionary) -> bool:
	var completed = quests.get("completed", {})
	return typeof(completed) == TYPE_DICTIONARY and completed.has("main_road_of_crows")

func _sanitize_dictionary_fields(container: Dictionary, fields: Array) -> void:
	for field in fields:
		if container.has(field) and typeof(container[field]) != TYPE_DICTIONARY:
			container.erase(field)

func _finite_number(value: Variant, fallback: float) -> float:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return fallback
	var result := float(value)
	return result if is_finite(result) else fallback

func _remove_if_present(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _remove_absolute_if_present(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
