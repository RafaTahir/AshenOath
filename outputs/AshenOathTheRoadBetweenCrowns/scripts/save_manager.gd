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
const RELEASED_ZONES := [
	"greyfen", "wychwood", "ruins", "cemetery", "deep_wood", "old_mill",
	"burned_farmstead", "marsh_crossing", "bandit_road", "vargan_approach",
	"vargan_court", "record_hall", "undercroft", "assembly", "hart_glade"
]

signal message(text: String)
signal library_changed

var replay_session := false
var journey_id := ""
var _browser_import_callback: JavaScriptObject
var _browser_import_slot := ""
var _import_dialog: FileDialog

func save_game(game, path: String = SAVE_PATH, label: String = "Game saved.") -> bool:
	# Deferred autosaves can outlive a zone teardown. Never serialize a partially
	# released runtime, but keep invalid saves visible during normal play.
	if _is_game_shutting_down(game):
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
	library_changed.emit()
	return true

func load_game(game, path: String = SAVE_PATH) -> bool:
	var result := _read_slot(path)
	if _reject_newer_save(result):
		return false
	var recovered_backup := false
	if not bool(result.get("ok", false)):
		var backup_result := _read_slot(backup_path(path))
		if _reject_newer_save(backup_result):
			return false
		if not bool(backup_result.get("ok", false)):
			message.emit("No valid save found.")
			return false
		result = backup_result
		recovered_backup = true
	_preserve_legacy_slot(result)
	replay_session = bool(result.data.get("replay_session", false))
	journey_id = str(result.data.get("journey_id", "legacy")).validate_filename()
	game.load_save_state(result.data)
	_restore_text_history(game, result.data)
	message.emit("Recovered the previous save backup." if recovered_backup else "Game loaded.")
	return true

func autosave(game) -> bool:
	return save_game(game, AUTOSAVE_PATH, "Autosaved.")

func checkpoint(game) -> bool:
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

func load_checkpoint(game) -> bool:
	if replay_session:
		return load_first_available(game, ["user://ashen_oath_replay_checkpoint.json", "user://ashen_oath_replay_autosave.json", "user://ashen_oath_replay_save.json"])
	return load_first_available(game, [CHECKPOINT_PATH, AUTOSAVE_PATH, SAVE_PATH])

func load_pre_covenant(game) -> bool:
	return load_game(game, PRE_COVENANT_PATH.replace("user://ashen_oath_", "user://ashen_oath_replay_") if replay_session else PRE_COVENANT_PATH)

func load_first_available(game, paths: Array) -> bool:
	for path_value in paths:
		var path := str(path_value)
		var result := _read_slot(path)
		if _reject_newer_save(result):
			return false
		var recovered_backup := false
		if not bool(result.get("ok", false)):
			result = _read_slot(backup_path(path))
			if _reject_newer_save(result):
				return false
			recovered_backup = bool(result.get("ok", false))
		if bool(result.get("ok", false)):
			_preserve_legacy_slot(result)
			replay_session = bool(result.data.get("replay_session", false))
			journey_id = str(result.data.get("journey_id", "legacy")).validate_filename()
			game.load_save_state(result.data)
			_restore_text_history(game, result.data)
			message.emit("Recovered a checkpoint backup." if recovered_backup else "Checkpoint loaded.")
			return true
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
	data["saved_at_utc"] = str(data.get("saved_at_utc", Time.get_datetime_string_from_system(true)))
	data["journey_id"] = str(data.get("journey_id", "legacy-" + str(data["saved_at_utc"]))).validate_filename().left(80)
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
	if parser.parse(file.get_as_text()) != OK:
		return {"ok": false, "path": path, "reason": "invalid_json"}
	var parsed = parser.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "path": path, "reason": "invalid_json"}
	var version_error := _version_error(parsed)
	if not version_error.is_empty():
		return {"ok": false, "path": path, "reason": version_error}
	var migrated := migrate_save_data(parsed)
	if migrated.is_empty():
		return {"ok": false, "path": path, "reason": "future_version"}
	return {"ok": true, "path": path, "data": migrated}

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

func _preserve_legacy_slot(result: Dictionary) -> void:
	var data: Dictionary = result.get("data", {})
	if int(data.get("migrated_from_version", CURRENT_VERSION)) >= CURRENT_VERSION:
		return
	var path := str(result.get("path", ""))
	if path == "" or not FileAccess.file_exists(path):
		return
	var original := path + ".before-story-overhaul"
	if not FileAccess.file_exists(original):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(original))

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

func slot_path(slot_id: String) -> String:
	if slot_id.begins_with("manual_"):
		var number := slot_id.trim_prefix("manual_").to_int()
		return "user://ashen_oath_manual_%d.json" % number if number >= 1 and number <= MANUAL_SLOT_COUNT else ""
	return {"quick": SAVE_PATH, "auto": AUTOSAVE_PATH, "checkpoint": CHECKPOINT_PATH, "decision": PRE_DECISION_PATH, "covenant": PRE_COVENANT_PATH, "completed": COMPLETED_CAMPAIGN_PATH, "replay": "user://ashen_oath_replay_autosave.json"}.get(slot_id, "")

func list_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for number in range(1, MANUAL_SLOT_COUNT + 1):
		slots.append(_slot_summary("manual_%d" % number, "Journey %d" % number, false))
	for slot_id in ["quick", "auto", "checkpoint", "decision", "covenant", "completed", "replay"]:
		var label := str({"quick": "Quick save", "auto": "Autosave", "checkpoint": "Checkpoint", "decision": "Before the last decision", "covenant": "Before the final covenant", "completed": "Completed campaign", "replay": "Replay autosave"}[slot_id])
		slots.append(_slot_summary(slot_id, label, true))
	return slots

func _slot_summary(slot_id: String, fallback_title: String, protected_slot: bool) -> Dictionary:
	var path := slot_path(slot_id)
	var result := _read_slot(path)
	var exists := FileAccess.file_exists(path)
	var valid := bool(result.get("ok", false))
	var data: Dictionary = result.get("data", {})
	return {"id": slot_id, "title": str(data.get("slot_name", fallback_title)), "zone": str(data.get("zone", "")).replace("_", " ").capitalize(), "saved_at": str(data.get("saved_at_utc", "")), "valid": valid, "exists": exists, "protected": protected_slot, "replay": bool(data.get("replay_session", false))}

func save_named(game, slot_id: String, title: String) -> bool:
	if not slot_id.begins_with("manual_") or slot_path(slot_id).is_empty() or _is_game_shutting_down(game) or not _has_valid_player(game):
		message.emit("Start or load a journey before creating a manual save.")
		return false
	var data := _build_save_data(game)
	data["slot_name"] = _safe_slot_name(title)
	if not _write_atomic(slot_path(slot_id), data):
		message.emit("The save could not be written. The previous copy is preserved.")
		return false
	message.emit("Saved: " + str(data.slot_name))
	library_changed.emit()
	return true

func rename_slot(slot_id: String, title: String) -> bool:
	if not slot_id.begins_with("manual_") or slot_path(slot_id).is_empty():
		return false
	var result := _read_slot(slot_path(slot_id))
	if not bool(result.get("ok", false)):
		return false
	result.data["slot_name"] = _safe_slot_name(title)
	var saved := _write_atomic(slot_path(slot_id), result.data)
	if saved:
		library_changed.emit()
	return saved

func has_previous_slot(slot_id: String) -> bool:
	return slot_id.begins_with("manual_") and not slot_path(slot_id).is_empty() and FileAccess.file_exists(backup_path(slot_path(slot_id)))

func restore_previous_slot(slot_id: String) -> bool:
	if not has_previous_slot(slot_id):
		return false
	var path := slot_path(slot_id)
	var previous := _read_slot(backup_path(path))
	if not bool(previous.get("ok", false)):
		message.emit("The previous copy cannot be read. The current save remains in place.")
		return false
	var restored := _write_atomic(path, previous.data)
	if restored:
		message.emit("Previous slot copy restored. The displaced copy is now its backup.")
		library_changed.emit()
	return restored

func load_slot(game, slot_id: String) -> bool:
	var path := slot_path(slot_id)
	return false if path.is_empty() else load_game(game, path)

func predecision(game, choice_id: String) -> bool:
	if _is_game_shutting_down(game) or not _has_valid_player(game):
		return false
	var data := _build_save_data(game)
	data["slot_name"] = "Before " + choice_id.replace("_", " ").replace(":", ": ")
	var path := PRE_DECISION_PATH.replace("user://ashen_oath_", "user://ashen_oath_replay_") if replay_session else PRE_DECISION_PATH
	return _write_atomic(path, data)

func export_slot(slot_id: String) -> bool:
	var path := slot_path(slot_id)
	if path.is_empty():
		return false
	var result := _read_slot(path)
	if not bool(result.get("ok", false)):
		message.emit("There is no readable save to export in this slot.")
		return false
	var content := JSON.stringify({"format": "ashen-oath-save", "format_version": 1, "save": result.data}, "\t")
	var filename := "ashen-oath-%s-%d.json" % [slot_id, int(Time.get_unix_time_from_system())]
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(content.to_utf8_buffer(), filename, "application/json")
		message.emit("Save download requested. Keep the JSON file to restore this journey.")
	else:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://exports"))
		var export_path := "user://exports/" + filename
		var output := FileAccess.open(export_path, FileAccess.WRITE)
		if output == null:
			message.emit("Could not create the export file.")
			return false
		output.store_string(content)
		output.close()
		message.emit("Exported to " + ProjectSettings.globalize_path(export_path))
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
			message.emit("Choose a readable Ashen Oath JSON save below 2 MB.")
			return
		import_save_text(file.get_as_text(), target_slot)
	)
	add_child(_import_dialog)
	_import_dialog.popup_centered_ratio(0.75)

func _on_browser_import(arguments: Array) -> void:
	if arguments.size() < 2:
		return
	if str(arguments[1]) != "":
		message.emit(str(arguments[1]))
		return
	import_save_text(str(arguments[0]), _browser_import_slot)
	_browser_import_slot = ""

func import_save_text(content: String, target_slot: String = "") -> bool:
	if content.to_utf8_buffer().size() > MAX_IMPORT_BYTES:
		message.emit("The save is larger than the 2 MB import limit.")
		return false
	var parser := JSON.new()
	if parser.parse(content) != OK or typeof(parser.data) != TYPE_DICTIONARY:
		message.emit("Choose an Ashen Oath JSON save. This file could not be read.")
		return false
	var raw: Dictionary = parser.data
	if raw.has("format"):
		if str(raw.get("format", "")) != "ashen-oath-save" or typeof(raw.get("save")) != TYPE_DICTIONARY:
			message.emit("This file is not an Ashen Oath save export.")
			return false
		raw = raw.save
	var error := _import_error(raw)
	if error != "":
		message.emit(error)
		return false
	var destination := target_slot
	if destination != "" and (not destination.begins_with("manual_") or slot_path(destination).is_empty()):
		message.emit("Choose a manual slot for an import.")
		return false
	if destination.is_empty():
		for number in range(1, MANUAL_SLOT_COUNT + 1):
			var candidate := "manual_%d" % number
			if not FileAccess.file_exists(slot_path(candidate)):
				destination = candidate
				break
	if destination.is_empty():
		message.emit("All six manual slots are occupied. Choose a slot and use Import File Into This Slot; its previous copy will remain recoverable.")
		return false
	var data := migrate_save_data(raw)
	data["slot_name"] = _safe_slot_name(str(raw.get("slot_name", "Imported journey")))
	data["replay_session"] = false
	if not _write_atomic(slot_path(destination), data):
		message.emit("The import could not be saved. Existing journeys are unchanged.")
		return false
	message.emit("Imported into %s. Select the slot to load it." % destination.replace("_", " ").capitalize())
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
	if replay_session or not _has_valid_player(game) or game.get("quests") == null:
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
	for quest_id in ["main_road_of_crows", "main_bell_beneath_greyfen", "main_teeth_in_rain", "main_names_they_burned", "main_ash_at_the_mill", "main_soldier_without_banner", "main_blood_under_stone", "main_last_witness", "main_crowns_without_mercy", "main_hart_remembers"]:
		var result := _read_slot(_chapter_path(quest_id, source_journey))
		if bool(result.get("ok", false)):
			chapters.append({"id": quest_id, "title": str(result.data.get("slot_name", quest_id))})
	return chapters

func replay_chapter(game, quest_id: String) -> bool:
	var available := false
	for entry in chapter_replays():
		if str(entry.id) == quest_id:
			available = true
	if not available:
		return false
	var completed := _read_slot(COMPLETED_CAMPAIGN_PATH)
	if not bool(completed.get("ok", false)):
		return false
	var source_journey := str(completed.data.get("journey_id", "legacy"))
	var result := _read_slot(_chapter_path(quest_id, source_journey))
	if not bool(result.get("ok", false)):
		return false
	var data: Dictionary = result.data.duplicate(true)
	data["replay_session"] = true
	if not _write_atomic("user://ashen_oath_replay_checkpoint.json", data):
		message.emit("Could not create the replay copy. The original journey remains in place.")
		return false
	replay_session = true
	journey_id = source_journey
	game.load_save_state(data)
	_restore_text_history(game, data)
	message.emit("Chapter replay: automatic saves use a separate copy. Your original campaign remains available in the save library.")
	return true
