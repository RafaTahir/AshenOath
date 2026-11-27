extends RefCounted

const EndingCatalog = preload("res://scripts/ending_catalog.gd")
const RELEASED_ZONES := [
	"greyfen", "wychwood", "ruins", "cemetery", "deep_wood", "old_mill",
	"burned_farmstead", "marsh_crossing", "bandit_road", "vargan_approach",
	"vargan_court", "record_hall", "undercroft", "assembly", "hart_glade", "lantern_reach", "hearthward"
]

static func _supported_saved_zone(value: String) -> bool:
	var zone: String = value.strip_edges().to_lower()
	return zone in RELEASED_ZONES or zone in ["deep_woods", "long_road", "castle_approach", "courtyard"]

static func _recorded_metadata(raw: Dictionary) -> Dictionary:
	var stamp: String = str(raw.get("saved_at_utc", ""))
	var world: Dictionary = raw.get("world_state", {}) if typeof(raw.get("world_state")) == TYPE_DICTIONARY else {}
	var result: Dictionary = {"saved_at_utc": stamp, "saved_at_known": _timestamp_value(stamp) >= 0, "place_known": raw.has("world_sector") or raw.has("zone"), "quests_known": typeof(raw.get("quests")) == TYPE_DICTIONARY, "story_known": typeof(raw.get("story_state")) == TYPE_DICTIONARY, "day_night": world.get("day_night", {}) if typeof(world.get("day_night")) == TYPE_DICTIONARY else {}}
	for key: String in ["player_health", "player_stamina", "inventory", "equipment"]:
		result[key] = raw[key].duplicate(true) if typeof(raw.get(key)) == TYPE_DICTIONARY else {}
	return result

static func _timestamp_value(value: String) -> int:
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

static func _normalize_zone(zone: String) -> String:
	zone = zone.strip_edges().to_lower()
	var aliases := {
		"deep_woods": "deep_wood",
		"long_road": "bandit_road",
		"castle_approach": "vargan_approach",
		"courtyard": "vargan_court",
	}
	zone = str(aliases.get(zone, zone))
	return zone if zone in RELEASED_ZONES else "greyfen"

static func _local_to_world(local_position: Array, zone: String) -> Array:
	var position := _normalize_position(local_position, zone)
	var world := preload("res://scripts/world_sector_manifest.gd").local_to_world(zone, Vector3(position[0], position[1], position[2]))
	return [world.x, world.y, world.z]

## Released saves wrote these three sector origins using a stale private atlas.
## Recognize that exact signature when a local position survived the save.
static func _correct_sector_origin(raw: Dictionary, sector: String, local: Array, world: Array) -> Array:
	if sector not in ["lantern_reach", "hearthward", "assembly"] or not raw.get("player_position") is Array or raw.player_position.size() != 3:
		return world
	var legacy_offset := Vector3(48, 0, 400) if sector == "assembly" else Vector3.ZERO
	var local_point := Vector3(local[0], local[1], local[2])
	var stored := Vector3(world[0], world[1], world[2])
	if stored.is_equal_approx(local_point + legacy_offset):
		return _local_to_world(local, sector)
	return world

static func _normalize_position(raw_position: Variant, zone: String) -> Array:
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

static func _default_position(zone: String) -> Array:
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

static func _normalize_health(state: Dictionary) -> Dictionary:
	var maximum := clampf(_finite_number(state.get("max_health", 100.0), 100.0), 1.0, 999.0)
	var current := clampf(_finite_number(state.get("health", maximum), maximum), 1.0, maximum)
	return {"health": current, "max_health": maximum, "dead": false}

static func _normalize_stamina(state: Dictionary) -> Dictionary:
	var maximum := clampf(_finite_number(state.get("max_stamina", 100.0), 100.0), 1.0, 999.0)
	var current := clampf(_finite_number(state.get("stamina", maximum), maximum), 0.0, maximum)
	return {"stamina": current, "max_stamina": maximum}

static func _sanitize_settings(state: Dictionary) -> Dictionary:
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

static func _sanitize_bool_map(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var result: Dictionary = {}
	for key in value:
		if typeof(value[key]) == TYPE_BOOL and bool(value[key]):
			result[str(key)] = true
	return result

static func _normalize_ending(value: String) -> String:
	return EndingCatalog.normalize(value)

static func _legacy_road_complete(quests: Dictionary) -> bool:
	var completed: Variant = quests.get("completed", {})
	return typeof(completed) == TYPE_DICTIONARY and completed.has("main_road_of_crows")

static func _sanitize_dictionary_fields(container: Dictionary, fields: Array) -> void:
	for field in fields:
		if container.has(field) and typeof(container[field]) != TYPE_DICTIONARY:
			container.erase(field)

static func _finite_number(value: Variant, fallback: float) -> float:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return fallback
	var result := float(value)
	return result if is_finite(result) else fallback

static func _sort_recorded_time(candidates: Array[Dictionary]) -> void:
	# Insertion sort retains deterministic source order for equal/unknown times.
	for index in range(1, candidates.size()):
		var entry: Dictionary = candidates[index]
		var timestamp: int = _timestamp_value(str(entry.get("summary", {}).get("saved_at", "")))
		var previous: int = index - 1
		while previous >= 0 and _timestamp_value(str(candidates[previous].get("summary", {}).get("saved_at", ""))) < timestamp:
			candidates[previous + 1] = candidates[previous]
			previous -= 1
		candidates[previous + 1] = entry

static func _safe_slot_name(title: String) -> String:
	var result := title.replace("\n", " ").replace("\r", " ").replace("\t", " ").strip_edges().left(48)
	return "Unnamed journey" if result.is_empty() else result
