extends Node

const CURRENT_VERSION := 10
const PRE_COVENANT_PATH := "user://ashen_oath_before_covenant.json"
const SAVE_PATH := "user://ashen_oath_save.json"
const AUTOSAVE_PATH := "user://ashen_oath_autosave.json"
const CHECKPOINT_PATH := "user://ashen_oath_checkpoint.json"
const PRE_DECISION_PATH := "user://ashen_oath_before_decision.json"
const COMPLETED_CAMPAIGN_PATH := "user://ashen_oath_completed_campaign.json"
const MANUAL_SLOT_COUNT := 6
const MAX_IMPORT_BYTES := 2097152
const RESUME_PATH := "user://ashen_oath_resume.json"
const JourneySummary = preload("res://scripts/saved_journey_model.gd")
const CHAPTER_IDS := ["main_road_of_crows", "main_bell_beneath_greyfen", "main_teeth_in_rain", "main_names_they_burned", "main_ash_at_the_mill", "main_soldier_without_banner", "main_blood_under_stone", "main_last_witness", "main_crowns_without_mercy", "main_hart_remembers"]
const CAMPAIGN_RESUME_SLOTS := ["quick", "auto", "checkpoint", "manual_1", "manual_2", "manual_3", "manual_4", "manual_5", "manual_6"]
const REPLAY_RESUME_SLOTS := ["replay", "replay_checkpoint", "replay_quick", "manual_1", "manual_2", "manual_3", "manual_4", "manual_5", "manual_6"]
const RELEASED_ZONES := [
	"greyfen", "wychwood", "ruins", "cemetery", "deep_wood", "old_mill",
	"burned_farmstead", "marsh_crossing", "bandit_road", "vargan_approach",
	"vargan_court", "record_hall", "undercroft", "assembly", "hart_glade"
]

signal message(text: String)
signal library_changed
signal operation_finished(slot_id: String, operation: String, success: bool, text: String)
signal load_prepared_requested(prepared: Dictionary)

var replay_session := false
var journey_id := ""
var _browser_import_callback: JavaScriptObject
var _browser_import_slot := ""
var _import_dialog: FileDialog
var _pending_load: Dictionary = {}
var _load_serial: int = 0
var _summary_quests: Dictionary = {}
var _summary_items: Dictionary = {}

func save_game(game, path: String = SAVE_PATH, label: String = "Game saved.") -> bool:
	# Deferred autosaves can outlive a zone teardown. Never serialize a partially
	# released runtime, but keep invalid saves visible during normal play.
	if _is_game_shutting_down(game) or _save_is_gated(game):
		return false
	if not _has_valid_player(game):
		message.emit("Save failed. Your previous save was preserved.")
		return false
	var data := _build_save_data(game)
	if replay_session and path in [SAVE_PATH, AUTOSAVE_PATH, CHECKPOINT_PATH, PRE_DECISION_PATH, PRE_COVENANT_PATH]:
		path = path.replace("user://ashen_oath_", "user://ashen_oath_replay_")
	if not _write_atomic(path, data):
		message.emit("Save failed. Your previous save was preserved.")
		return false
	message.emit(label)
	_remember_gameplay_save(path, data)
	library_changed.emit()
	return true

func load_game(game, path: String = SAVE_PATH) -> bool:
	# Compatibility return values mean request acceptance, never completed load.
	return _request_model(_model_for_path(path))

func autosave(game) -> bool:
	return save_game(game, AUTOSAVE_PATH, "Autosaved.")

func checkpoint(game) -> bool:
	if _save_is_gated(game):
		return false
	capture_chapter(game)
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

func _save_is_gated(game) -> bool:
	if not _pending_load.is_empty():
		return true
	return game != null and is_instance_valid(game) and game.has_method("_journey_load_pending") and bool(game.call("_journey_load_pending"))

func is_load_pending() -> bool:
	return not _pending_load.is_empty()

func load_checkpoint(game) -> bool:
	return _request_model(checkpoint_model())

func load_pre_covenant(game) -> bool:
	return load_game(game, PRE_COVENANT_PATH.replace("user://ashen_oath_", "user://ashen_oath_replay_") if replay_session else PRE_COVENANT_PATH)

func load_first_available(game, paths: Array) -> bool:
	for path_value in paths:
		var model: Dictionary = _model_for_path(str(path_value))
		if str(model.get("status", "")) == "newer_version":
			return _request_model(model)
		if bool(model.get("available", false)):
			return _request_model(model)
	message.emit("No valid checkpoint found.")
	return false

func migrate_save_data(raw_data: Dictionary) -> Dictionary:
	if not _version_error(raw_data).is_empty():
		return {}
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
	var refill: Variant = data.vendors.get("emergency_refill_claimed", false)
	data.vendors["emergency_refill_claimed"] = typeof(refill) == TYPE_BOOL and refill
	var medicine: Variant = data.vendors.get("emergency_healing_claimed", false)
	data.vendors["emergency_healing_claimed"] = typeof(medicine) == TYPE_BOOL and medicine
	_sanitize_dictionary_fields(data.quests, ["active", "completed", "unlocked", "world_flags", "evidence_history"])
	_sanitize_dictionary_fields(data.story_state, ["flags", "values", "evidence"])
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
		world["wychwood_pack_kills"] = world.get("ghoulkin_kills", 0)
	world["wychwood_pack_kills"] = int(clampf(_finite_number(world.get("wychwood_pack_kills", 0), 0.0), 0.0, 5.0))
	world["ghoulkin_kills"] = int(world.get("wychwood_pack_kills", 0))
	world["pending_ending"] = _normalize_ending(str(world.get("pending_ending", "")))
	if typeof(world.get("boss_states", {})) != TYPE_DICTIONARY:
		world["boss_states"] = {}
	if typeof(world.get("day_night", {})) != TYPE_DICTIONARY:
		world["day_night"] = {}
	else:
		var day_night: Dictionary = world.get("day_night", {})
		day_night["world_time_minutes"] = clampf(_finite_number(day_night.get("world_time_minutes", 990.0), 990.0), 0.0, 1439.999)
		day_night["day_count"] = int(clampf(_finite_number(day_night.get("day_count", 0), 0.0), 0.0, 2147483647.0))
		world["day_night"] = day_night
	data["world_state"] = world
	data["player_health"] = _normalize_health(data.player_health)
	data["player_stamina"] = _normalize_stamina(data.player_stamina)
	data["settings"] = _sanitize_settings(data.settings)
	if typeof(data.get("text_history", [])) != TYPE_ARRAY:
		data["text_history"] = []
	data["replay_session"] = typeof(data.get("replay_session", false)) == TYPE_BOOL and bool(data.get("replay_session", false))
	data["saved_at_utc"] = str(data.get("saved_at_utc", ""))
	var saved_identity: String = str(data.get("journey_id", "")).validate_filename().left(80)
	data["journey_id"] = saved_identity if saved_identity != "" else "legacy-" + JSON.stringify(raw_data).sha256_text().left(24)
	data["migrated_from_version"] = int(raw_data.get("migrated_from_version", source_version))
	if source_version < 10:
		_migrate_story_campaign(data)
	return data

func backup_path(path: String) -> String:
	return path + ".bak"

func _build_save_data(game) -> Dictionary:
	if journey_id.is_empty():
		journey_id = "%d-%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_msec()]
	return {
		"version": CURRENT_VERSION,
		"game_id": "ashen-oath",
		"replay_session": replay_session,
		"journey_id": journey_id,
		"text_history": game.hud.save_text_history() if game.get("hud") != null and game.hud.has_method("save_text_history") else [],
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
	var content: String = file.get_as_text()
	if parser.parse(content) != OK:
		return {"ok": false, "path": path, "reason": "invalid_json"}
	var parsed = parser.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "path": path, "reason": "invalid_json"}
	var version_error := _version_error(parsed)
	if not version_error.is_empty():
		return {"ok": false, "path": path, "reason": version_error}
	if typeof(parsed.get("zone")) != TYPE_STRING or str(parsed.get("zone", "")).is_empty() or str(parsed.get("game_id", "ashen-oath")) != "ashen-oath":
		return {"ok": false, "path": path, "reason": "invalid_save"}
	if not _supported_saved_zone(str(parsed.zone)) or not _supported_saved_zone(str(parsed.get("world_sector", parsed.zone))):
		return {"ok": false, "path": path, "reason": "invalid_location"}
	var migrated := migrate_save_data(parsed)
	if migrated.is_empty():
		return {"ok": false, "path": path, "reason": "future_version"}
	return {"ok": true, "path": path, "data": migrated, "recorded": _recorded_metadata(parsed), "token": content.sha256_text()}

func _supported_saved_zone(value: String) -> bool:
	var zone: String = value.strip_edges().to_lower()
	return zone in RELEASED_ZONES or zone in ["deep_woods", "long_road", "castle_approach", "courtyard"]

func _recorded_metadata(raw: Dictionary) -> Dictionary:
	var stamp: String = str(raw.get("saved_at_utc", ""))
	var world: Dictionary = raw.get("world_state", {}) if typeof(raw.get("world_state")) == TYPE_DICTIONARY else {}
	var result: Dictionary = {"saved_at_utc": stamp, "saved_at_known": _timestamp_value(stamp) >= 0, "place_known": raw.has("world_sector") or raw.has("zone"), "quests_known": typeof(raw.get("quests")) == TYPE_DICTIONARY, "story_known": typeof(raw.get("story_state")) == TYPE_DICTIONARY, "day_night": world.get("day_night", {}) if typeof(world.get("day_night")) == TYPE_DICTIONARY else {}}
	for key: String in ["player_health", "player_stamina", "inventory", "equipment"]:
		result[key] = raw[key].duplicate(true) if typeof(raw.get(key)) == TYPE_DICTIONARY else {}
	return result

func _timestamp_value(value: String) -> int:
	var normalized: String = value.strip_edges().trim_suffix("Z").replace(" ", "T")
	if normalized.length() != 19 or normalized.substr(4, 1) != "-" or normalized.substr(7, 1) != "-" or normalized.substr(10, 1) != "T" or normalized.substr(13, 1) != ":" or normalized.substr(16, 1) != ":":
		return -1
	for piece: String in [normalized.substr(0, 4), normalized.substr(5, 2), normalized.substr(8, 2), normalized.substr(11, 2), normalized.substr(14, 2), normalized.substr(17, 2)]:
		if not piece.is_valid_int():
			return -1
	var year: int = int(normalized.substr(0, 4))
	var month: int = int(normalized.substr(5, 2))
	var day: int = int(normalized.substr(8, 2))
	var hour: int = int(normalized.substr(11, 2))
	var minute: int = int(normalized.substr(14, 2))
	var second: int = int(normalized.substr(17, 2))
	if year < 1970 or month < 1 or month > 12 or day < 1 or day > 31 or hour < 0 or hour > 23 or minute < 0 or minute > 59 or second < 0 or second > 59:
		return -1
	var month_days: Array[int] = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	if year % 4 == 0 and (year % 100 != 0 or year % 400 == 0):
		month_days[1] = 29
	if day > month_days[month - 1]:
		return -1
	var timestamp: int = int(Time.get_unix_time_from_datetime_string(normalized))
	return timestamp if Time.get_datetime_string_from_unix_time(timestamp) == normalized else -1

func _version_error(data: Dictionary) -> String:
	var version: Variant = data.get("version", 0)
	if typeof(version) not in [TYPE_INT, TYPE_FLOAT]:
		return "invalid_version"
	var number := float(version)
	if not is_finite(number) or number < 0.0 or number != floorf(number):
		return "invalid_version"
	return "future_version" if number > CURRENT_VERSION else ""

func _reject_newer_save(result: Dictionary) -> bool:
	if result.get("reason", "") != "future_version":
		return false
	message.emit("This save needs a newer game version. Your save files were preserved.")
	return true

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
		"high_contrast", "control_preset", "difficulty", "pause_on_focus_loss", "music_volume", "sfx_volume", "voice_volume",
		"subtitle_background_opacity", "subtitle_speaker_names", "flash_reduction", "targeting_assist", "block_mode", "sprint_mode", "text_locale",
	]
	var result: Dictionary = {}
	for key in allowed:
		if not state.has(key):
			continue
		var value: Variant = state[key]
		if key in ["gamepad_profiles", "custom_bindings"]:
			if typeof(value) == TYPE_DICTIONARY:
				result[key] = value.duplicate(true)
		elif key in ["vsync", "fullscreen", "potato_mode", "invert_y", "gamepad_invert_x", "gamepad_invert_y", "gamepad_vibration", "reduced_motion", "high_contrast", "pause_on_focus_loss", "subtitle_speaker_names", "flash_reduction", "targeting_assist"]:
			if typeof(value) == TYPE_BOOL:
				result[key] = value
		elif key in ["shadow_quality", "foliage_density", "visual_density", "target_fps"]:
			if typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and absf(float(value)) <= 2147483647.0:
				result[key] = int(value)
		elif key in ["quality_preset", "touch_controls", "control_preset", "difficulty", "block_mode", "sprint_mode", "text_locale"]:
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
	var aliases := {"witness": "expose", "mercy": "free", "duty": "bind", "ash": "kill"}
	value = str(aliases.get(value, value))
	return value if value in ["", "expose", "free", "bind", "kill"] else ""

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

func _preserve_legacy_slot(result: Dictionary) -> bool:
	var data: Dictionary = result.get("data", {})
	if int(data.get("migrated_from_version", CURRENT_VERSION)) >= CURRENT_VERSION:
		return true
	var path: String = str(result.get("path", ""))
	if path == "" or not FileAccess.file_exists(path):
		return false
	var original: String = path + ".before-story-overhaul"
	if not FileAccess.file_exists(original):
		return DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(original)) == OK
	return true

func _migrate_story_campaign(data: Dictionary) -> void:
	var state: Dictionary = data.story_state
	var flags: Dictionary = state.get("flags", {})
	# A completed objective cannot establish consent or an unrecorded choice.
	# Preserve old outcomes as history; missing fields remain explicitly unknown.
	if _legacy_road_complete(data.quests) and str(flags.get("evidence_report", "")) == "":
		flags["legacy_report_choice_required"] = true
	if str(flags.get("confession_method", "")) != "":
		flags["renewal_stopped"] = true
	if not bool(flags.get("final_choice_completed", false)):
		var pending := str(data.world_state.get("pending_ending", ""))
		if pending in ["bind", "expose", "free"]:
			flags["covenant_ritual_started"] = true
			flags["covenant_ritual_step"] = int(flags.get("covenant_ritual_step", 0))
	state["flags"] = flags
	state["version"] = 2
	data["story_state"] = state

func set_summary_definitions(quest_definitions: Dictionary, item_definitions: Dictionary) -> void:
	_summary_quests = quest_definitions.duplicate(true)
	_summary_items = item_definitions.duplicate(true)

func _slot_label(slot_id: String) -> String:
	if slot_id.begins_with("manual_"):
		return "Manual save " + slot_id.trim_prefix("manual_")
	return str({"quick": "Quick save", "auto": "Autosave", "checkpoint": "Checkpoint", "decision": "Before the last decision", "covenant": "Before the final covenant", "completed": "Completed campaign", "replay": "Replay autosave", "replay_quick": "Replay quick save", "replay_checkpoint": "Replay checkpoint", "replay_decision": "Before the replay decision", "replay_covenant": "Before the replay covenant"}.get(slot_id, "Saved journey"))

func _empty_model(status: String, reason: String, summary: Dictionary = {}) -> Dictionary:
	return {"available": false, "selection": {}, "summary": summary, "source_label": "", "status": status, "reason": reason, "backup_available": false, "recovery": []}

func _reason_text(reason: String) -> String:
	return str({"missing": "This save copy is missing. Choose a recorded recovery copy or another journey.", "unreadable": "This save copy could not be opened. Your current journey remains in place.", "invalid_json": "This save copy is damaged or incomplete. A readable backup may still be available.", "invalid_save": "This file does not contain a readable Ashen Oath journey.", "invalid_location": "This save names a destination that this release cannot restore. Your current journey remains in place.", "invalid_version": "This save has an unreadable version record. Its files have been preserved.", "future_version": "This save needs a newer game version. Its files have been preserved.", "changed": "This save changed after it was displayed. Read the refreshed journey card before loading it.", "invalid_selection": "This saved journey is no longer available. Choose it again from Saved Journeys."}.get(reason, "The saved journey could not be prepared. Your current session remains in place."))

func _summary_for_result(result: Dictionary, fallback_title: String) -> Dictionary:
	var data: Dictionary = result.get("data", {}).duplicate(true)
	if str(data.get("slot_name", "")).is_empty():
		data["slot_name"] = fallback_title
	return JourneySummary.describe(data, result.get("recorded", {}), _summary_quests, _summary_items)

func _card_for_result(slot_id: String, source: String, result: Dictionary) -> Dictionary:
	var backup: bool = source == "backup"
	var summary: Dictionary = _summary_for_result(result, _slot_label(slot_id))
	var source_label: String = ("Previous copy of " if backup else "") + _slot_label(slot_id)
	if bool(summary.get("replay", false)) and not source_label.to_lower().contains("replay"):
		source_label += " (replay)"
	return {"available": true, "selection": {"slot_id": slot_id, "source": source, "token": str(result.get("token", ""))}, "state_token": _journey_payload_token(result.get("data", {})), "summary": summary, "source_label": source_label, "status": "recoverable" if backup else "ready", "reason": "Loads the previous recorded copy, including its story state." if backup else "", "recovery": []}

func _slot_model(slot_id: String) -> Dictionary:
	var path: String = slot_path(slot_id)
	if path == "":
		return _empty_model("unavailable", _reason_text("invalid_selection"))
	var primary: Dictionary = _read_slot(path)
	if str(primary.get("reason", "")) == "future_version":
		return _empty_model("newer_version", _reason_text("future_version"))
	var previous: Dictionary = _read_slot(backup_path(path))
	var backup_available: bool = bool(previous.get("ok", false))
	if bool(primary.get("ok", false)):
		var model: Dictionary = _card_for_result(slot_id, "primary", primary)
		model["backup_available"] = backup_available
		if backup_available:
			model["recovery"] = [_card_for_result(slot_id, "backup", previous)]
		return model
	if backup_available:
		var model: Dictionary = _card_for_result(slot_id, "backup", previous)
		model["backup_available"] = true
		model["reason"] = "The main copy is unavailable. This loads its readable previous copy and that copy's recorded choices."
		return model
	var newer: bool = str(previous.get("reason", "")) == "future_version"
	var missing: bool = str(primary.get("reason", "")) == "missing" and str(previous.get("reason", "")) == "missing"
	return _empty_model("newer_version" if newer else ("empty" if missing else "unavailable"), _reason_text("future_version" if newer else str(primary.get("reason", "missing"))))

func _specific_model(slot_id: String, source: String) -> Dictionary:
	var selection: Dictionary = {"slot_id": slot_id, "source": source, "token": ""}
	var result: Dictionary = _read_selection(selection, false)
	if not bool(result.get("ok", false)):
		return _empty_model("newer_version" if str(result.get("reason", "")) == "future_version" else "unavailable", _reason_text(str(result.get("reason", ""))))
	return _card_for_result(slot_id, source, result)

func _model_for_path(path: String) -> Dictionary:
	for id: String in _all_slot_ids():
		if slot_path(id) == path:
			return _slot_model(id)
		if backup_path(slot_path(id)) == path:
			return _specific_model(id, "backup")
	return _empty_model("unavailable", _reason_text("invalid_selection"))

func _all_slot_ids() -> Array[String]:
	var result: Array[String] = []
	for number in range(1, MANUAL_SLOT_COUNT + 1):
		result.append("manual_%d" % number)
	result.append_array(["quick", "auto", "checkpoint", "decision", "covenant", "completed", "replay", "replay_quick", "replay_checkpoint", "replay_decision", "replay_covenant"])
	return result

func continue_model() -> Dictionary:
	var pointer: Dictionary = _read_resume_pointer()
	if bool(pointer.get("exists", false)):
		if not bool(pointer.get("ok", false)):
			return _empty_model("unavailable", "The remembered Continue selection could not be read. Your saves remain in Saved Journeys.")
		var identity: Dictionary = pointer.get("data", {})
		var model: Dictionary = _specific_model(str(identity.get("slot_id", "")), str(identity.get("source", "primary")))
		var same_state: bool = str(identity.get("state_token", "")) == "" or str(identity.get("state_token", "")) == str(model.get("state_token", ""))
		var same: bool = bool(model.get("available", false)) and same_state and _matches_journey(model.get("summary", {}), str(identity.get("journey_id", "")), bool(identity.get("replay", false)))
		if same:
			return model
		var reason: String = str(model.get("reason", ""))
		if bool(model.get("available", false)):
			reason = "The remembered slot now holds a different recorded state. Choose that copy or a recovery explicitly in Saved Journeys."
		var unavailable: Dictionary = _empty_model(str(model.get("status", "unavailable")) if not bool(model.get("available", false)) else "unavailable", reason, identity.get("summary", {}))
		unavailable["source_label"] = ("Previous copy of " if str(identity.get("source", "")) == "backup" else "") + _slot_label(str(identity.get("slot_id", "")))
		unavailable["recovery"] = _same_journey_recovery(str(identity.get("journey_id", "")), bool(identity.get("replay", false)))
		return unavailable
	var candidates: Array[Dictionary] = []
	var newer_found: bool = false
	for slot_id: String in CAMPAIGN_RESUME_SLOTS:
		var model: Dictionary = _slot_model(slot_id)
		if str(model.get("status", "")) == "newer_version":
			newer_found = true
		if bool(model.get("available", false)) and not bool(model.get("summary", {}).get("replay", false)):
			candidates.append(model)
	_sort_recorded_time(candidates)
	if newer_found:
		var blocked: Dictionary = _empty_model("newer_version", "A saved journey needs a newer game version. Choose an available copy explicitly in Saved Journeys.")
		blocked["recovery"] = candidates.slice(0, 3)
		return blocked
	if candidates.is_empty():
		return _empty_model("empty", "No readable campaign journey is saved on this device. Begin a journey or open Saved Journeys to import one.")
	var selected: Dictionary = candidates[0]
	selected["reason"] = "Continue uses the most recent recorded save time." if bool(selected.get("summary", {}).get("saved_at_known", false)) else "Save time was not recorded. This available copy is selected in quick save, autosave, checkpoint and manual-slot order."
	return selected

func checkpoint_model() -> Dictionary:
	var current_id: String = journey_id
	var current_replay: bool = replay_session
	if current_id == "":
		var resume: Dictionary = continue_model()
		if not bool(resume.get("available", false)):
			return resume
		current_id = str(resume.get("summary", {}).get("journey_id", ""))
		current_replay = bool(resume.get("summary", {}).get("replay", false))
	var ids: Array = ["replay_checkpoint", "replay", "replay_quick"] if current_replay else ["checkpoint", "auto", "quick"]
	for id: String in ids:
		var model: Dictionary = _slot_model(id)
		if str(model.get("status", "")) == "newer_version":
			return model
		if bool(model.get("available", false)) and _matches_journey(model.get("summary", {}), current_id, current_replay):
			model["reason"] = "Returns to this copy's recorded place, supplies and choices. Progress made after this save is not part of the copy."
			return model
		for recovery: Dictionary in model.get("recovery", []):
			if _matches_journey(recovery.get("summary", {}), current_id, current_replay):
				return recovery
	var missing: Dictionary = _empty_model("unavailable", "No readable checkpoint for this journey is available. Open Saved Journeys to choose another recorded copy.")
	missing["recovery"] = _same_journey_recovery(current_id, current_replay)
	return missing

func _matches_journey(summary: Dictionary, identity: String, replay: bool) -> bool:
	return identity != "" and str(summary.get("journey_id", "")) == identity and bool(summary.get("replay", false)) == replay

func _journey_payload_token(data: Dictionary) -> String:
	var stable: Dictionary = migrate_save_data(data)
	stable.erase("slot_name")
	return JSON.stringify(stable).sha256_text()

func _same_journey_recovery(identity: String, replay: bool) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var seen: Dictionary = {}
	var ids: Array = REPLAY_RESUME_SLOTS if replay else CAMPAIGN_RESUME_SLOTS
	for id: String in ids:
		var model: Dictionary = _slot_model(id)
		var copies: Array = model.get("recovery", []).duplicate()
		if bool(model.get("available", false)):
			copies.push_front(model)
		for copy: Dictionary in copies:
			var token: String = str(copy.get("selection", {}).get("token", ""))
			if token != "" and not seen.has(token) and _matches_journey(copy.get("summary", {}), identity, replay):
				seen[token] = true
				var card: Dictionary = copy.duplicate(true)
				card["recovery"] = []
				candidates.append(card)
	_sort_recorded_time(candidates)
	var limited: Array[Dictionary] = []
	for index in range(mini(candidates.size(), 3)):
		limited.append(candidates[index])
	return limited

func _sort_recorded_time(candidates: Array[Dictionary]) -> void:
	# Insertion sort retains deterministic source order for equal/unknown times.
	for index in range(1, candidates.size()):
		var entry: Dictionary = candidates[index]
		var timestamp: int = _timestamp_value(str(entry.get("summary", {}).get("saved_at", "")))
		var previous: int = index - 1
		while previous >= 0 and _timestamp_value(str(candidates[previous].get("summary", {}).get("saved_at", ""))) < timestamp:
			candidates[previous + 1] = candidates[previous]
			previous -= 1
		candidates[previous + 1] = entry

func slot_path(slot_id: String) -> String:
	if slot_id.begins_with("manual_"):
		var number := slot_id.trim_prefix("manual_").to_int()
		return "user://ashen_oath_manual_%d.json" % number if number >= 1 and number <= MANUAL_SLOT_COUNT and slot_id == "manual_%d" % number else ""
	return {"quick": SAVE_PATH, "auto": AUTOSAVE_PATH, "checkpoint": CHECKPOINT_PATH, "decision": PRE_DECISION_PATH, "covenant": PRE_COVENANT_PATH, "completed": COMPLETED_CAMPAIGN_PATH, "replay": "user://ashen_oath_replay_autosave.json", "replay_quick": "user://ashen_oath_replay_save.json", "replay_checkpoint": "user://ashen_oath_replay_checkpoint.json", "replay_decision": "user://ashen_oath_replay_before_decision.json", "replay_covenant": "user://ashen_oath_replay_before_covenant.json"}.get(slot_id, "")

func _read_selection(selection: Dictionary, require_token: bool = true) -> Dictionary:
	var slot_id: String = str(selection.get("slot_id", ""))
	var source: String = str(selection.get("source", ""))
	var path: String = ""
	if slot_id.begins_with("chapter:") and source == "chapter":
		var chapter_id: String = slot_id.trim_prefix("chapter:")
		if chapter_id not in CHAPTER_IDS:
			return {"ok": false, "reason": "invalid_selection"}
		var completed: Dictionary = _read_slot(COMPLETED_CAMPAIGN_PATH)
		if not bool(completed.get("ok", false)):
			return completed
		path = _chapter_path(chapter_id, str(completed.data.get("journey_id", "")))
	elif source in ["primary", "backup"]:
		path = slot_path(slot_id)
		if path == "":
			return {"ok": false, "reason": "invalid_selection"}
		if source == "backup":
			var primary: Dictionary = _read_slot(path)
			if str(primary.get("reason", "")) == "future_version":
				return primary
			path = backup_path(path)
	else:
		return {"ok": false, "reason": "invalid_selection"}
	var result: Dictionary = _read_slot(path)
	if bool(result.get("ok", false)) and require_token:
		var expected: String = str(selection.get("token", ""))
		if expected == "" or str(result.get("token", "")) != expected:
			return {"ok": false, "reason": "changed", "path": path}
	return result

func _request_model(model: Dictionary) -> bool:
	if not bool(model.get("available", false)):
		message.emit(str(model.get("reason", "The saved journey is unavailable.")))
		return false
	return request_load(model.get("selection", {}))

func request_load(selection: Dictionary) -> bool:
	var prepared: Dictionary = prepare_load(selection)
	if not bool(prepared.get("ok", false)):
		var text: String = str(prepared.get("message", "The saved journey could not be prepared."))
		operation_finished.emit(str(selection.get("slot_id", "")), "load", false, text)
		message.emit(text)
		library_changed.emit()
		return false
	load_prepared_requested.emit(prepared)
	return true

func prepare_load(selection: Dictionary) -> Dictionary:
	if not _pending_load.is_empty() and bool(_pending_load.get("accepted", false)):
		return {"ok": false, "request_id": "", "data": {}, "summary": {}, "source": {}, "reason": "busy", "message": "A journey is already being placed on the road. Wait for that arrival before loading another copy."}
	var result: Dictionary = _read_selection(selection)
	if not bool(result.get("ok", false)):
		var reason: String = str(result.get("reason", "invalid_selection"))
		return {"ok": false, "request_id": "", "data": {}, "summary": {}, "source": {}, "reason": reason, "message": _reason_text(reason)}
	_load_serial += 1
	var request_id: String = "journey-%d-%d" % [_load_serial, Time.get_ticks_msec()]
	var data: Dictionary = result.data.duplicate(true)
	var slot_id: String = str(selection.get("slot_id", ""))
	var source_kind: String = str(selection.get("source", "primary"))
	var is_chapter: bool = source_kind == "chapter"
	if is_chapter:
		data["replay_session"] = true
	var card: Dictionary = _card_for_result(slot_id, source_kind, result)
	var summary: Dictionary = card.get("summary", {}).duplicate(true)
	summary["replay"] = bool(data.get("replay_session", false))
	var source: Dictionary = {"slot_id": slot_id, "source": source_kind, "token": str(result.get("token", "")), "label": "Chapter replay copy" if is_chapter else str(card.get("source_label", _slot_label(slot_id))), "recovered_backup": source_kind == "backup", "replay": bool(data.get("replay_session", false))}
	var prepared: Dictionary = {"ok": true, "request_id": request_id, "data": data, "summary": summary, "source": source, "message": "Preparing the saved destination.", "reason": ""}
	_pending_load = prepared.duplicate(true)
	_pending_load["selection"] = selection.duplicate(true)
	_pending_load["read_result"] = result
	_pending_load["accepted"] = false
	return prepared

func accept_prepared_load(request_id: String) -> Dictionary:
	if _pending_load.is_empty() or str(_pending_load.get("request_id", "")) != request_id:
		return {"ok": false, "request_id": request_id, "reason": "superseded", "message": "That load request is no longer active."}
	if bool(_pending_load.get("accepted", false)):
		return {"ok": true, "request_id": request_id, "reason": "", "message": "The saved journey is ready to apply."}
	# Keep the displayed copy exact even if an import or rename happened while
	# packs were downloading. No active game state has changed at this boundary.
	var current: Dictionary = _read_selection(_pending_load.get("selection", {}))
	if not bool(current.get("ok", false)):
		var reason: String = str(current.get("reason", "changed"))
		return {"ok": false, "request_id": request_id, "reason": reason, "message": _reason_text(reason)}
	if not _preserve_legacy_slot(current):
		return {"ok": false, "request_id": request_id, "reason": "archive_failed", "message": "The original legacy copy could not be preserved. The current journey remains in place."}
	if str(_pending_load.get("source", {}).get("source", "")) == "chapter":
		if not _write_atomic(slot_path("replay_checkpoint"), _pending_load.get("data", {})):
			return {"ok": false, "request_id": request_id, "reason": "replay_copy_failed", "message": "The separate replay copy could not be written. Your current journey and original campaign remain in place."}
	_pending_load["accepted"] = true
	return {"ok": true, "request_id": request_id, "reason": "", "message": "The saved journey is ready to apply."}

func finish_load(game, request_id: String, success: bool, reason: String = "") -> Dictionary:
	if _pending_load.is_empty() or str(_pending_load.get("request_id", "")) != request_id:
		return {"ok": false, "request_id": request_id, "summary": {}, "source": {}, "reason": "superseded", "message": ""}
	var pending: Dictionary = _pending_load
	var source: Dictionary = pending.get("source", {}).duplicate(true)
	var summary: Dictionary = pending.get("summary", {}).duplicate(true)
	if success and not bool(pending.get("accepted", false)):
		return {"ok": false, "request_id": request_id, "summary": summary, "source": source, "reason": "not_accepted", "message": "The saved destination has not been accepted for loading."}
	_pending_load = {}
	if not success:
		if reason != "":
			operation_finished.emit(str(source.get("slot_id", "")), "load", false, reason)
		return {"ok": false, "request_id": request_id, "summary": summary, "source": source, "reason": reason, "message": reason}
	var data: Dictionary = pending.get("data", {})
	replay_session = bool(data.get("replay_session", false))
	journey_id = str(data.get("journey_id", "")).validate_filename()
	_restore_text_history(game, data)
	var pointer_slot: String = str(source.get("slot_id", ""))
	var pointer_source: String = str(source.get("source", "primary"))
	if pointer_source == "chapter":
		pointer_slot = "replay_checkpoint"
		pointer_source = "primary"
	var remembered: bool = _write_resume_pointer(pointer_slot, pointer_source, data, summary)
	var text: String = "Recovery copy restored." if bool(source.get("recovered_backup", false)) else ("Chapter replay restored in its separate copy." if str(source.get("source", "")) == "chapter" else "Journey restored.")
	if not remembered:
		text += " Continue could not remember this selection; use Saved Journeys to choose the copy again."
	operation_finished.emit(str(source.get("slot_id", "")), "load", true, text)
	library_changed.emit()
	return {"ok": true, "request_id": request_id, "summary": summary, "source": source, "reason": "" if remembered else "resume_pointer_unwritten", "message": text}

func _read_resume_pointer() -> Dictionary:
	if not FileAccess.file_exists(RESUME_PATH):
		return {"ok": false, "exists": false}
	var file := FileAccess.open(RESUME_PATH, FileAccess.READ)
	if file == null or file.get_length() > MAX_IMPORT_BYTES:
		return {"ok": false, "exists": true}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "exists": true}
	if typeof(parsed.get("version")) not in [TYPE_INT, TYPE_FLOAT] or float(parsed.version) != 1.0:
		return {"ok": false, "exists": true}
	if slot_path(str(parsed.get("slot_id", ""))) == "" or str(parsed.get("source", "")) not in ["primary", "backup"] or str(parsed.get("journey_id", "")) == "" or typeof(parsed.get("replay")) != TYPE_BOOL:
		return {"ok": false, "exists": true}
	if typeof(parsed.get("summary")) != TYPE_DICTIONARY:
		parsed["summary"] = {}
	return {"ok": true, "exists": true, "data": parsed}

func _write_resume_pointer(slot_id: String, source: String, data: Dictionary, summary: Dictionary = {}) -> bool:
	if slot_path(slot_id) == "" or source not in ["primary", "backup"]:
		return false
	var saved_summary: Dictionary = summary.duplicate(true)
	if saved_summary.is_empty():
		saved_summary = JourneySummary.describe(data, _recorded_metadata(data), _summary_quests, _summary_items)
	var pointer: Dictionary = {"version": 1, "slot_id": slot_id, "source": source, "journey_id": str(data.get("journey_id", "")), "replay": bool(data.get("replay_session", false)), "state_token": _journey_payload_token(data), "summary": saved_summary}
	var temporary: String = RESUME_PATH + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(pointer, "\t"))
	file.flush()
	file = null
	var destination: String = ProjectSettings.globalize_path(RESUME_PATH)
	var previous: String = ProjectSettings.globalize_path(backup_path(RESUME_PATH))
	_remove_absolute_if_present(previous)
	if FileAccess.file_exists(RESUME_PATH) and DirAccess.rename_absolute(destination, previous) != OK:
		_remove_if_present(temporary)
		return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), destination) != OK:
		if FileAccess.file_exists(backup_path(RESUME_PATH)):
			DirAccess.rename_absolute(previous, destination)
		_remove_if_present(temporary)
		return false
	return true

func _remember_gameplay_save(path: String, data: Dictionary) -> void:
	for slot_id: String in _all_slot_ids():
		if path != slot_path(slot_id) or (slot_id not in CAMPAIGN_RESUME_SLOTS and slot_id not in REPLAY_RESUME_SLOTS):
			continue
		if not _write_resume_pointer(slot_id, "primary", data):
			message.emit("The journey was saved, but Continue could not remember its source. It remains available in Saved Journeys.")
		return

func list_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for number in range(1, MANUAL_SLOT_COUNT + 1):
		slots.append(_slot_summary("manual_%d" % number, "Journey %d" % number, false))
	for slot_id: String in ["quick", "auto", "checkpoint", "decision", "covenant", "completed", "replay", "replay_quick", "replay_checkpoint", "replay_decision", "replay_covenant"]:
		if slot_id.begins_with("replay_") and not FileAccess.file_exists(slot_path(slot_id)) and not FileAccess.file_exists(backup_path(slot_path(slot_id))):
			continue
		slots.append(_slot_summary(slot_id, _slot_label(slot_id), true))
	return slots

func _slot_summary(slot_id: String, fallback_title: String, protected_slot: bool) -> Dictionary:
	var path: String = slot_path(slot_id)
	var primary: Dictionary = _read_slot(path)
	var model: Dictionary = _slot_model(slot_id)
	var summary: Dictionary = model.get("summary", {})
	if str(model.get("source_label", "")) == "":
		model["source_label"] = _slot_label(slot_id)
	model["backup_available"] = bool(model.get("backup_available", false))
	model.merge({"id": slot_id, "title": str(summary.get("title", fallback_title)), "zone": str(summary.get("place", "")), "saved_at": str(summary.get("saved_at", "")), "valid": bool(primary.get("ok", false)), "exists": FileAccess.file_exists(path), "protected": protected_slot, "replay": bool(summary.get("replay", false))}, true)
	return model

func save_named(game, slot_id: String, title: String) -> bool:
	if _save_is_gated(game):
		operation_finished.emit(slot_id, "save", false, "Finish returning to the road before saving this journey.")
		return false
	if not slot_id.begins_with("manual_") or slot_path(slot_id).is_empty() or _is_game_shutting_down(game) or not _has_valid_player(game):
		operation_finished.emit(slot_id, "save", false, "Start or load a journey before creating a manual save.")
		return false
	var data := _build_save_data(game)
	data["slot_name"] = _safe_slot_name(title)
	if not _write_atomic(slot_path(slot_id), data):
		operation_finished.emit(slot_id, "save", false, "The save could not be written. The previous copy is preserved.")
		return false
	operation_finished.emit(slot_id, "save", true, "Saved: " + str(data.slot_name))
	_remember_gameplay_save(slot_path(slot_id), data)
	library_changed.emit()
	return true

func rename_slot(slot_id: String, title: String) -> bool:
	if not slot_id.begins_with("manual_") or slot_path(slot_id).is_empty():
		return false
	var result := _read_slot(slot_path(slot_id))
	if not bool(result.get("ok", false)):
		operation_finished.emit(slot_id, "rename", false, "The slot could not be read; its name is unchanged.")
		return false
	result.data["slot_name"] = _safe_slot_name(title)
	var saved := _write_atomic(slot_path(slot_id), result.data)
	operation_finished.emit(slot_id, "rename", saved, "Journey renamed." if saved else "The new name could not be saved.")
	if saved:
		library_changed.emit()
	return saved

func has_previous_slot(slot_id: String) -> bool:
	if not slot_id.begins_with("manual_") or slot_path(slot_id).is_empty():
		return false
	var primary: Dictionary = _read_slot(slot_path(slot_id))
	return str(primary.get("reason", "")) != "future_version" and bool(_read_slot(backup_path(slot_path(slot_id))).get("ok", false))

func restore_previous_slot(slot_id: String) -> bool:
	if not has_previous_slot(slot_id):
		return false
	var path := slot_path(slot_id)
	var previous := _read_slot(backup_path(path))
	if not bool(previous.get("ok", false)):
		operation_finished.emit(slot_id, "restore", false, "The previous copy cannot be read. The current save remains in place.")
		return false
	var restored := _write_atomic(path, previous.data)
	operation_finished.emit(slot_id, "restore", restored, "Previous slot copy restored. The displaced copy is now its backup." if restored else "The previous copy could not be restored.")
	if restored:
		library_changed.emit()
	return restored

func load_slot(game, slot_id: String) -> bool:
	return _request_model(_slot_model(slot_id))

func predecision(game, choice_id: String) -> bool:
	if _is_game_shutting_down(game) or _save_is_gated(game) or not _has_valid_player(game):
		return false
	var data := _build_save_data(game)
	data["slot_name"] = "Before " + choice_id.replace("_", " ").replace(":", ": ")
	var path := PRE_DECISION_PATH.replace("user://ashen_oath_", "user://ashen_oath_replay_") if replay_session else PRE_DECISION_PATH
	var written: bool = _write_atomic(path, data)
	if written:
		library_changed.emit()
	return written

func export_slot(slot_id: String) -> bool:
	var path := slot_path(slot_id)
	if path.is_empty():
		return false
	var result := _read_slot(path)
	if not bool(result.get("ok", false)):
		operation_finished.emit(slot_id, "export", false, "There is no readable save to export in this slot.")
		return false
	var content := JSON.stringify({"format": "ashen-oath-save", "format_version": 1, "save": result.data}, "\t")
	var filename := "ashen-oath-%s-%d.json" % [slot_id, int(Time.get_unix_time_from_system())]
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(content.to_utf8_buffer(), filename, "application/json")
		operation_finished.emit(slot_id, "export", true, "Save download requested. Keep the JSON file to restore this journey.")
	else:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://exports"))
		var export_path := "user://exports/" + filename
		var output := FileAccess.open(export_path, FileAccess.WRITE)
		if output == null:
			operation_finished.emit(slot_id, "export", false, "Could not create the export file.")
			return false
		output.store_string(content)
		output.close()
		operation_finished.emit(slot_id, "export", true, "Exported to " + ProjectSettings.globalize_path(export_path))
	return true

func request_import_file(target_slot: String = "") -> void:
	if target_slot != "" and (not target_slot.begins_with("manual_") or slot_path(target_slot).is_empty()):
		return
	if OS.has_feature("web"):
		_browser_import_slot = target_slot
		_browser_import_callback = JavaScriptBridge.create_callback(_on_browser_import)
		var window := JavaScriptBridge.get_interface("window")
		window.ashenOathReceiveSave = _browser_import_callback
		JavaScriptBridge.eval("""(function(){ const input=document.createElement('input'); input.type='file'; input.accept='.json,application/json'; input.onchange=async()=>{const f=input.files[0]; if(!f)return; if(f.size>2097152){window.ashenOathReceiveSave('', 'This file is too large. Choose an Ashen Oath save below 2 MB.');return;} try{window.ashenOathReceiveSave(await f.text(),'');}catch(e){window.ashenOathReceiveSave('', 'The selected file could not be read.');}}; input.click(); })();""", true)
		return
	if is_instance_valid(_import_dialog):
		_import_dialog.queue_free()
	_import_dialog = FileDialog.new()
	_import_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	_import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_import_dialog.filters = PackedStringArray(["*.json ; Ashen Oath save"])
	_import_dialog.file_selected.connect(func(path: String):
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null or file.get_length() > MAX_IMPORT_BYTES:
			operation_finished.emit(target_slot, "import", false, "Choose a readable Ashen Oath JSON save below 2 MB.")
			return
		import_save_text(file.get_as_text(), target_slot)
	)
	add_child(_import_dialog)
	_import_dialog.popup_centered_ratio(0.75)

func _on_browser_import(arguments: Array) -> void:
	if arguments.size() < 2:
		return
	if str(arguments[1]) != "":
		operation_finished.emit(_browser_import_slot, "import", false, str(arguments[1]))
		return
	import_save_text(str(arguments[0]), _browser_import_slot)
	_browser_import_slot = ""

func import_save_text(content: String, target_slot: String = "") -> bool:
	if content.to_utf8_buffer().size() > MAX_IMPORT_BYTES:
		operation_finished.emit(target_slot, "import", false, "The save is larger than the 2 MB import limit.")
		return false
	var parser := JSON.new()
	if parser.parse(content) != OK or typeof(parser.data) != TYPE_DICTIONARY:
		operation_finished.emit(target_slot, "import", false, "Choose an Ashen Oath JSON save. This file could not be read.")
		return false
	var raw: Dictionary = parser.data
	if raw.has("format"):
		if str(raw.get("format", "")) != "ashen-oath-save" or typeof(raw.get("save")) != TYPE_DICTIONARY:
			operation_finished.emit(target_slot, "import", false, "This file is not an Ashen Oath save export.")
			return false
		raw = raw.save
	var error := _import_error(raw)
	if error != "":
		operation_finished.emit(target_slot, "import", false, error)
		return false
	var destination := target_slot
	if destination != "" and (not destination.begins_with("manual_") or slot_path(destination).is_empty()):
		operation_finished.emit(target_slot, "import", false, "Choose a manual slot for an import.")
		return false
	if destination.is_empty():
		for number in range(1, MANUAL_SLOT_COUNT + 1):
			var candidate := "manual_%d" % number
			if not FileAccess.file_exists(slot_path(candidate)):
				destination = candidate
				break
	if destination.is_empty():
		operation_finished.emit(target_slot, "import", false, "All six manual slots are occupied. Choose a slot and use Import File Into This Slot; its previous copy will remain recoverable.")
		return false
	var data := migrate_save_data(raw)
	data["slot_name"] = _safe_slot_name(str(raw.get("slot_name", "Imported journey")))
	data["replay_session"] = false
	if not _write_atomic(slot_path(destination), data):
		operation_finished.emit(destination, "import", false, "The import could not be saved. Existing journeys are unchanged.")
		return false
	operation_finished.emit(destination, "import", true, "Imported into %s. Select the slot to load it." % destination.replace("_", " ").capitalize())
	library_changed.emit()
	return true

func _import_error(data: Dictionary) -> String:
	var error := _version_error(data)
	if error == "future_version":
		return "This save requires a newer Ashen Oath release. Existing slots are preserved."
	if error != "" or not data.has("version") or not data.has("zone"):
		return "This file does not contain a supported Ashen Oath save."
	if str(data.get("game_id", "ashen-oath")) != "ashen-oath":
		return "This save belongs to a different game."
	var zone := str(data.zone).strip_edges().to_lower()
	if zone not in RELEASED_ZONES and zone not in ["deep_woods", "long_road", "castle_approach", "courtyard"]:
		return "The save names a location that this release does not contain."
	var sector := str(data.get("world_sector", zone)).strip_edges().to_lower()
	if sector not in RELEASED_ZONES and sector not in ["deep_woods", "long_road", "castle_approach", "courtyard"]:
		return "The save names a world sector that this release does not contain."
	for key in ["player_position", "world_position"]:
		if not data.has(key):
			continue
		var position: Variant = data[key]
		if typeof(position) != TYPE_ARRAY or position.size() != 3:
			return "The save has an unreadable player position."
		for coordinate in position:
			if typeof(coordinate) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(coordinate)) or absf(float(coordinate)) > 10000.0:
				return "The save's player position is outside the supported world."
	for key in ["inventory", "quests", "story_state", "world_state"]:
		if typeof(data.get(key)) != TYPE_DICTIONARY:
			return "The save is missing its %s record." % key.replace("_", " ")
	if not _bounded_json(data, 0):
		return "The save contains unsupported or excessively nested values."
	return ""

func _bounded_json(value: Variant, depth: int) -> bool:
	if depth > 18:
		return false
	if typeof(value) == TYPE_DICTIONARY:
		if value.size() > 5000:
			return false
		for key in value:
			if str(key).length() > 512 or not _bounded_json(value[key], depth + 1):
				return false
	elif typeof(value) == TYPE_ARRAY:
		if value.size() > 5000:
			return false
		for element in value:
			if not _bounded_json(element, depth + 1):
				return false
	elif typeof(value) == TYPE_STRING:
		return value.length() <= 32000
	elif typeof(value) in [TYPE_INT, TYPE_FLOAT]:
		return is_finite(float(value)) and absf(float(value)) <= 2147483647.0
	return true

func _safe_slot_name(title: String) -> String:
	var result := title.replace("\n", " ").replace("\r", " ").replace("\t", " ").strip_edges().left(48)
	return "Unnamed journey" if result.is_empty() else result

func _restore_text_history(game, data: Dictionary) -> void:
	if game.get("hud") != null and game.hud.has_method("load_text_history"):
		game.hud.load_text_history(data.get("text_history", []))

func capture_chapter(game) -> void:
	if replay_session or _save_is_gated(game) or _is_game_shutting_down(game) or not _has_valid_player(game) or game.get("quests") == null:
		return
	var data := _build_save_data(game)
	if bool(game.story_state.get_flag("final_choice_completed", false)):
		data["slot_name"] = "Completed campaign — " + str(game.story_state.get_flag("final_covenant", "The road home")).capitalize()
		_write_atomic(COMPLETED_CAMPAIGN_PATH, data)
	for quest_id in game.quests.active:
		if not str(quest_id).begins_with("main_"):
			continue
		var path := _chapter_path(str(quest_id))
		if FileAccess.file_exists(path):
			continue
		data["slot_name"] = str(game.quests.quest_defs.get(quest_id, {}).get("title", str(quest_id).trim_prefix("main_").replace("_", " ").capitalize()))
		_write_atomic(path, data)

func begin_new_journey() -> void:
	if bool(_pending_load.get("accepted", false)):
		return
	_pending_load = {}
	_load_serial += 1
	replay_session = false
	journey_id = "%d-%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_msec()]

func _chapter_path(quest_id: String, source_journey: String = "") -> String:
	var identity := journey_id if source_journey.is_empty() else source_journey
	return "user://ashen_oath_chapter_%s_%s.json" % [identity.validate_filename().left(80), quest_id.validate_filename()]

func chapter_replays() -> Array[Dictionary]:
	var chapters: Array[Dictionary] = []
	if not FileAccess.file_exists(COMPLETED_CAMPAIGN_PATH):
		return chapters
	var completed := _read_slot(COMPLETED_CAMPAIGN_PATH)
	if not bool(completed.get("ok", false)):
		return chapters
	var source_journey := str(completed.data.get("journey_id", "legacy"))
	for quest_id: String in CHAPTER_IDS:
		var result := _read_slot(_chapter_path(quest_id, source_journey))
		if bool(result.get("ok", false)):
			var model: Dictionary = _card_for_result("chapter:" + quest_id, "chapter", result)
			model["id"] = quest_id
			model["title"] = str(result.data.get("slot_name", quest_id))
			model["source_label"] = "Chapter replay copy"
			model["summary"]["replay"] = true
			model["reason"] = "Starts from this chapter's first recorded checkpoint in a separate replay copy."
			chapters.append(model)
	return chapters

func replay_chapter(game, quest_id: String) -> bool:
	for entry in chapter_replays():
		if str(entry.id) == quest_id:
			return _request_model(entry)
	message.emit("That chapter has no readable recorded checkpoint. The completed campaign remains available in Saved Journeys.")
	return false
