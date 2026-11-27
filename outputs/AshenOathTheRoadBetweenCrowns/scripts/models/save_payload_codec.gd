class_name SavePayloadCodec
extends RefCounted

const CURRENT_VERSION: int = 14
const Fields = preload("res://scripts/models/save_payload_fields.gd")
const Ammo = preload("res://scripts/models/ammo_loadout_model.gd")
const Canonical = preload("res://scripts/core/canonical_state.gd")
const Clock = preload("res://scripts/core/sim_clock.gd")
const CampaignRevision = preload("res://scripts/campaign_revision.gd")

static func _migrate(raw_data: Dictionary, target_version: int) -> Dictionary:
	if not _version_error(raw_data).is_empty():
		return {}
	var data: Dictionary = raw_data.duplicate(true)
	var source_version := int(data.get("version", 0))
	if source_version > CURRENT_VERSION:
		return {}
	data["version"] = target_version
	data["zone"] = Fields._normalize_zone(str(data.get("zone", "greyfen")))
	data["player_position"] = Fields._normalize_position(data.get("player_position", [0.0, 1.0, 7.0]), data.zone)
	data["world_sector"] = Fields._normalize_zone(str(data.get("world_sector", data.zone)))
	data["world_position"] = Fields._normalize_position(data.get("world_position", Fields._local_to_world(data.player_position, data.world_sector)), data.world_sector)
	data["world_position"] = Fields._correct_sector_origin(raw_data, data.world_sector, data.player_position, data.world_position)
	if not data.has("seamless_world") or typeof(data.get("seamless_world")) != TYPE_DICTIONARY:
		data["seamless_world"] = {}
	for key in ["inventory", "vendors", "quests", "story_state", "progression", "world_state", "player_health", "player_stamina", "equipment"]:
		if not data.has(key) or typeof(data.get(key)) != TYPE_DICTIONARY:
			data[key] = {}
	Fields._sanitize_dictionary_fields(data.inventory, ["items", "ingredients"])
	var refill: Variant = data.vendors.get("emergency_refill_claimed", false)
	data.vendors["emergency_refill_claimed"] = typeof(refill) == TYPE_BOOL and refill
	var medicine: Variant = data.vendors.get("emergency_healing_claimed", false)
	data.vendors["emergency_healing_claimed"] = typeof(medicine) == TYPE_BOOL and medicine
	Fields._sanitize_dictionary_fields(data.quests, ["active", "completed", "unlocked", "world_flags", "evidence_history", "completed_objectives"])
	Fields._sanitize_dictionary_fields(data.story_state, ["flags", "values", "evidence"])
	# Missing campaign markers stay missing: a schema upgrade cannot opt an
	# existing journey into a different campaign.
	if data.story_state.flags.has(CampaignRevision.FLAG):
		data.story_state.flags[CampaignRevision.FLAG] = CampaignRevision.from_save(raw_data)
	Fields._sanitize_dictionary_fields(data.progression, ["unlocked", "rewarded_quests", "claimed_rewards", "visited_sectors"])
	Fields._sanitize_dictionary_fields(data.world_state, ["removed_interactions", "day_night"])
	if not data.has("quest_presentation") or typeof(data.get("quest_presentation")) != TYPE_DICTIONARY:
		data["quest_presentation"] = {}
	if not data.has("quest_beats") or typeof(data.get("quest_beats")) != TYPE_DICTIONARY:
		data["quest_beats"] = {}
	if not data.has("settings") or typeof(data.get("settings")) != TYPE_DICTIONARY:
		data["settings"] = {}
	var presentation: Dictionary = data.quest_presentation
	var presentation_zone := Fields._normalize_zone(str(presentation.get("zone_id", data.zone)))
	presentation["zone_id"] = presentation_zone
	data["quest_presentation"] = presentation
	if source_version < 3 and Fields._legacy_road_complete(data.quests):
		var story: Dictionary = data.story_state
		var flags: Dictionary = story.get("flags", {}) if typeof(story.get("flags", {})) == TYPE_DICTIONARY else {}
		flags["legacy_report_choice_required"] = true
		story["flags"] = flags
		data["story_state"] = story
	var world: Dictionary = data.world_state
	world["removed_interactions"] = Fields._sanitize_bool_map(world.get("removed_interactions", {}))
	if not world.has("wychwood_pack_kills"):
		world["wychwood_pack_kills"] = world.get("ghoulkin_kills", 0)
	world["wychwood_pack_kills"] = int(clampf(Fields._finite_number(world.get("wychwood_pack_kills", 0), 0.0), 0.0, 5.0))
	world["ghoulkin_kills"] = int(world.get("wychwood_pack_kills", 0))
	world["pending_ending"] = Fields._normalize_ending(str(world.get("pending_ending", "")))
	if typeof(world.get("boss_states", {})) != TYPE_DICTIONARY:
		world["boss_states"] = {}
	if typeof(world.get("day_night", {})) != TYPE_DICTIONARY:
		world["day_night"] = {}
	else:
		var day_night: Dictionary = world.get("day_night", {})
		day_night["world_time_minutes"] = clampf(Fields._finite_number(day_night.get("world_time_minutes", 990.0), 990.0), 0.0, 1439.999)
		day_night["day_count"] = int(clampf(Fields._finite_number(day_night.get("day_count", 0), 0.0), 0.0, 2147483647.0))
		world["day_night"] = day_night
	data["world_state"] = world
	data["player_health"] = Fields._normalize_health(data.player_health)
	data["player_stamina"] = Fields._normalize_stamina(data.player_stamina)
	data["settings"] = Fields._sanitize_settings(data.settings)
	if typeof(data.get("text_history", [])) != TYPE_ARRAY:
		data["text_history"] = []
	data["replay_session"] = typeof(data.get("replay_session", false)) == TYPE_BOOL and bool(data.get("replay_session", false))
	data["saved_at_utc"] = str(data.get("saved_at_utc", ""))
	var saved_identity: String = str(data.get("journey_id", "")).validate_filename().left(80)
	data["journey_id"] = saved_identity if saved_identity != "" else "legacy-" + JSON.stringify(raw_data).sha256_text().left(24)
	data["migrated_from_version"] = int(raw_data.get("migrated_from_version", source_version))
	if source_version < 10:
		_migrate_story_campaign(data)
	if source_version < 11:
		var flags: Dictionary = data.story_state.get("flags", {})
		# An earned old shrine choice must not be revoked or turned into kill credit.
		if str(flags.get("crow_shrine_state", "")) != "" and not bool(flags.get("bell_eater_defeated", false)):
			flags["bell_eater_legacy_retired"] = true
		var started: bool = int(world.get("wychwood_pack_kills", 0)) > 0 or (data.zone == "wychwood" and float(data.player_position[2]) < 1.0)
		world["wychwood_encounter"] = {"started": started, "wave": int(world.get("wychwood_pack_kills", 0))}
	if target_version >= 14:
		data["ruleset_version"] = Clock.RULESET_VERSION
		data["inventory"] = Ammo.migrate_inventory(data.inventory, data.equipment)
	return data

static func _version_error(data: Dictionary) -> String:
	if data.has("ruleset_version") and data.ruleset_version != Clock.RULESET_VERSION:
		return "future_version"
	var campaign_error := CampaignRevision.save_revision_error(data)
	if campaign_error != "":
		return campaign_error
	var version: Variant = data.get("version", 0)
	if typeof(version) not in [TYPE_INT, TYPE_FLOAT]:
		return "invalid_version"
	var number := float(version)
	if not is_finite(number) or number < 0.0 or number != floorf(number):
		return "invalid_version"
	return "future_version" if number > CURRENT_VERSION else ""

static func _migrate_story_campaign(data: Dictionary) -> void:
	var state: Dictionary = data.story_state
	var flags: Dictionary = state.get("flags", {})
	# A completed objective cannot establish consent or an unrecorded choice.
	# Preserve old outcomes as history; missing fields remain explicitly unknown.
	if Fields._legacy_road_complete(data.quests) and str(flags.get("evidence_report", "")) == "":
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

static func _import_error(data: Dictionary) -> String:
	var error := _version_error(data)
	if error == "future_version":
		return "This save requires a newer Ashen Oath release. Existing slots are preserved."
	if error != "" or not data.has("version") or not data.has("zone"):
		return "This file does not contain a supported Ashen Oath save."
	if str(data.get("game_id", "ashen-oath")) != "ashen-oath":
		return "This save belongs to a different game."
	var zone := str(data.zone).strip_edges().to_lower()
	if not Fields._supported_saved_zone(zone):
		return "The save names a location that this release does not contain."
	var sector := str(data.get("world_sector", zone)).strip_edges().to_lower()
	if not Fields._supported_saved_zone(sector):
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

static func _bounded_json(value: Variant, depth: int) -> bool:
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

static func migrate(raw_data: Dictionary) -> Dictionary:
	return _migrate(raw_data, CURRENT_VERSION)

static func state_digest(data: Dictionary) -> String:
	return Canonical.digest(data)

static func payload_token(data: Dictionary) -> String:
	var round_trip: Variant = JSON.parse_string(JSON.stringify(data))
	var stable: Dictionary = migrate(round_trip if round_trip is Dictionary else data)
	if stable.is_empty():
		return ""
	stable.erase("slot_name")
	return state_digest(stable)

static func legacy_payload_token(data: Dictionary) -> String:
	if int(data.get("version", 0)) >= 14:
		return ""
	var round_trip: Variant = JSON.parse_string(JSON.stringify(data))
	var stable: Dictionary = _migrate(round_trip if round_trip is Dictionary else data, 13)
	stable.erase("slot_name")
	return JSON.stringify(stable).sha256_text()

static func matches_payload_token(data: Dictionary, token: String) -> bool:
	return not token.is_empty() and (payload_token(data) == token or legacy_payload_token(data) == token)

static func decode(content: String, path: String) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(content) != OK:
		return {"ok": false, "path": path, "reason": "invalid_json"}
	var parsed: Variant = parser.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "path": path, "reason": "invalid_json"}
	var version_error := _version_error(parsed)
	if not version_error.is_empty():
		return {"ok": false, "path": path, "reason": version_error}
	if typeof(parsed.get("zone")) != TYPE_STRING or str(parsed.get("zone", "")).is_empty() or str(parsed.get("game_id", "ashen-oath")) != "ashen-oath":
		return {"ok": false, "path": path, "reason": "invalid_save"}
	if not Fields._supported_saved_zone(str(parsed.zone)) or not Fields._supported_saved_zone(str(parsed.get("world_sector", parsed.zone))):
		return {"ok": false, "path": path, "reason": "invalid_location"}
	var migrated := migrate(parsed)
	if migrated.is_empty():
		return {"ok": false, "path": path, "reason": "future_version"}
	var result := {"ok": true, "path": path, "data": migrated, "recorded": Fields._recorded_metadata(parsed), "token": content.sha256_text(), "legacy_state_token": legacy_payload_token(parsed)}
	return result

static func resume_snapshot(pointer: Dictionary, slot_id: String, path: String, token: String) -> Dictionary:
	var raw: Variant = pointer.get("payload")
	if str(pointer.get("slot_id", "")) != slot_id or not raw is Dictionary:
		return {"ok": false, "reason": "invalid_selection"}
	var version_error := _version_error(raw)
	if not version_error.is_empty():
		return {"ok": false, "reason": version_error}
	if str(raw.get("game_id", "ashen-oath")) != "ashen-oath" \
			or not Fields._supported_saved_zone(str(raw.get("zone", ""))) \
			or not Fields._supported_saved_zone(str(raw.get("world_sector", raw.get("zone", "")))):
		return {"ok": false, "reason": "invalid_save"}
	var data := migrate(raw)
	if data.is_empty() or str(data.get("journey_id", "")) != str(pointer.get("journey_id", "")) \
			or bool(data.get("replay_session", false)) != bool(pointer.get("replay", false)) \
			or str(pointer.get("state_token", "")) == "" \
			or not matches_payload_token(raw, str(pointer.state_token)):
		return {"ok": false, "reason": "invalid_save"}
	return {"ok": true, "path": path, "data": data,
		"recorded": Fields._recorded_metadata(raw), "token": token,
		"resume_source": str(pointer.source)}

static func valid_resume_pointer(parsed: Dictionary, slot_valid: bool) -> bool:
	if typeof(parsed.get("version")) not in [TYPE_INT, TYPE_FLOAT] or float(parsed.version) != 1.0:
		return false
	return slot_valid and str(parsed.get("source", "")) in ["primary", "backup"] and str(parsed.get("journey_id", "")) != "" and typeof(parsed.get("replay")) == TYPE_BOOL
