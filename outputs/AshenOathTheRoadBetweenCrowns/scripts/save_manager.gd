extends Node

const Codec = preload("res://scripts/models/save_payload_codec.gd")
const Selection = preload("res://scripts/models/save_selection_model.gd")
const Fields = preload("res://scripts/models/save_payload_fields.gd")
const CURRENT_VERSION := Codec.CURRENT_VERSION
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
const CampaignRevision = preload("res://scripts/campaign_revision.gd")
const CHAPTER_IDS := CampaignRevision.EXPANDED_CHAPTERS
const CAMPAIGN_RESUME_SLOTS := ["quick", "auto", "checkpoint", "manual_1", "manual_2", "manual_3", "manual_4", "manual_5", "manual_6"]
const REPLAY_RESUME_SLOTS := ["replay", "replay_checkpoint", "replay_quick", "manual_1", "manual_2", "manual_3", "manual_4", "manual_5", "manual_6"]

signal message(text: String)
signal library_changed
signal operation_finished(slot_id: String, operation: String, success: bool, text: String)
signal load_prepared_requested(prepared: Dictionary)
signal durability_changed(state: String, detail: String)

var replay_session := false
var journey_id := ""
var _browser_import_callback: JavaScriptObject
var _browser_import_slot := ""
var _import_dialog: FileDialog
var _pending_load: Dictionary = {}
var _load_serial: int = 0
var _summary_quests: Dictionary = {}
var _summary_items: Dictionary = {}
var _decoded_slots: Dictionary = {}
var _summary_cache: Dictionary = {}
var _payload_tokens: Dictionary = {}
var _browser_sync_pending := false
var _browser_sync_generation := 0
var _browser_sync_files: Dictionary = {}
var _browser_sync_callback: JavaScriptObject
var _persistence_write_failures: Dictionary = {}
var durability_state := "idle"
var durability_detail := ""

func save_game(game, path: String = SAVE_PATH, label: String = "Game saved.") -> bool:
	# Deferred autosaves can outlive a zone teardown. Never serialize a partially
	# released runtime, but keep invalid saves visible during normal play.
	if _is_game_shutting_down(game) or _save_is_gated(game):
		return false
	if not _has_valid_player(game):
		message.emit("Save failed. Your previous save was preserved.")
		return false
	var data := _build_save_data(game, path == CHECKPOINT_PATH or path.ends_with("replay_checkpoint.json"))
	if replay_session and path in [SAVE_PATH, AUTOSAVE_PATH, CHECKPOINT_PATH, PRE_DECISION_PATH, PRE_COVENANT_PATH]:
		path = path.replace("user://ashen_oath_", "user://ashen_oath_replay_")
	if not _write_atomic(path, data):
		message.emit("Save failed. Your previous save was preserved.")
		return false
	if _remember_gameplay_save(path, data):
		message.emit(_save_message(label))
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
	if game != null and is_instance_valid(game):
		var arrival_root: Node = game.get("zone_root")
		if is_instance_valid(arrival_root) and bool(arrival_root.get_meta("arrival_support_pending", false)):
			return true
	return game != null and is_instance_valid(game) and game.has_method("_journey_load_pending") and bool(game.call("_journey_load_pending"))

func migrate_save_data(raw_data: Dictionary) -> Dictionary:
	return Codec.migrate(raw_data)

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

func backup_path(path: String) -> String:
	return path + ".bak"

static func stop_transient_activity_for_save(game) -> void:
	# An in-flight ferry is transient motion. Its existing activity owner returns
	# the player to the safe bank before snapshotting; carried work stays durable.
	var root = game.get("zone_root")
	var activities = root.get_node_or_null("StoryActivities") if is_instance_valid(root) else null
	# Closing one reading page can queue an autosave while its answer page is
	# already open. Snapshotting stops physical work, not that new menu's owner.
	if activities != null and activities.get("community") != null: activities.community.cancel(false)

func _build_save_data(game, for_checkpoint: bool = false) -> Dictionary:
	stop_transient_activity_for_save(game)
	preload("res://scripts/bracken_field_trial.gd").stop_activity(game)
	preload("res://scripts/greyfen_archery_range.gd").stop_activity(game)
	preload("res://scripts/companion_controller.gd").capture(game)
	if journey_id.is_empty():
		journey_id = "%d-%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_msec()]
	var position: Vector3 = game.checkpoint_return_position() if for_checkpoint else game.player.global_position
	return {
		"version": CURRENT_VERSION,
		"ruleset_version": preload("res://scripts/core/sim_clock.gd").RULESET_VERSION,
		"game_id": "ashen-oath",
		"replay_session": replay_session,
		"journey_id": journey_id,
		"text_history": game.hud.save_text_history() if game.get("hud") != null and game.hud.has_method("save_text_history") else [],
		"saved_at_utc": Time.get_datetime_string_from_system(true),
		"zone": game.current_zone_id,
		"world_sector": game.current_zone_id,
		"player_position": [
			position.x,
			position.y,
			position.z
		],
		"world_position": Fields._local_to_world([position.x, position.y, position.z], game.current_zone_id),
		"seamless_world": game.seamless_world.save_state() if game.get("seamless_world") != null and game.seamless_world.has_method("save_state") else {},
		"player_health": game.player.health_component.save_state(),
		"player_stamina": game.player.stamina_component.save_state(),
		"equipment": game.player.save_equipment_state() if game.player.has_method("save_equipment_state") else {},
		"inventory": game.inventory.save_state(),
		"vendors": game.vendor_service.save_state() if game.get("vendor_service") != null else {},
		"minigames": game.minigames.save_state() if game.get("minigames") != null else {},
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
	_queue_browser_sync(path)
	return true

func confirm_file_persistence(path: String) -> void:
	if not FileAccess.file_exists(path):
		report_persistence_failure(path, "Saved data could not be read back. Save again before closing this session.")
		return
	_queue_browser_sync(path)

func report_persistence_failure(path: String, detail: String) -> void:
	_persistence_write_failures[path] = detail
	_browser_sync_generation += 1
	_set_durability_failure(detail)

func _queue_browser_sync(path: String = RESUME_PATH) -> void:
	_persistence_write_failures.erase(path)
	if not OS.has_feature("web"):
		if not _persistence_write_failures.is_empty():
			_set_durability_failure(str(_persistence_write_failures.values()[0]))
			return
		durability_state = "durable"
		durability_detail = "Saved locally."
		durability_changed.emit(durability_state, durability_detail)
		return
	if FileAccess.file_exists(path):
		_browser_sync_files[ProjectSettings.globalize_path(path)] = FileAccess.get_sha256(path)
	_browser_sync_generation += 1
	durability_state = "pending"
	durability_detail = "Saving to browser storage. Keep this tab open."
	durability_changed.emit(durability_state, durability_detail)
	if _browser_sync_pending: return
	_browser_sync_pending = true
	call_deferred("_sync_browser_files")

func _sync_browser_files() -> void:
	_browser_sync_pending = false
	# FileAccess closes the temporary file before the atomic rename. Request
	# persistence again after the complete batch has published its final names.
	if OS.has_feature("web"):
		JavaScriptBridge.force_fs_sync()
		if not _persistence_write_failures.is_empty():
			_set_durability_failure(str(_persistence_write_failures.values()[0]))
			return
		var bridge: JavaScriptObject = JavaScriptBridge.get_interface("__ashenOathSaveDurability")
		if bridge == null:
			_set_durability_failure("Browser storage confirmation is unavailable. Save again or export your journey before closing.")
			return
		var settings_path := "user://ashen_oath_settings.json"
		if FileAccess.file_exists(settings_path):
			_browser_sync_files[ProjectSettings.globalize_path(settings_path)] = FileAccess.get_sha256(settings_path)
		if _browser_sync_callback == null:
			_browser_sync_callback = JavaScriptBridge.create_callback(_on_browser_sync_result)
		bridge.confirm(JSON.stringify(_browser_sync_files), _browser_sync_generation, _browser_sync_callback)

func _on_browser_sync_result(arguments: Array) -> void:
	if arguments.is_empty(): return
	var result: Variant = JSON.parse_string(str(arguments[0]))
	if not result is Dictionary or int(result.get("generation", -1)) != _browser_sync_generation: return
	if bool(result.get("ok", false)):
		durability_state = "durable"
		durability_detail = "Saved data confirmed in browser storage."
		_browser_sync_files.clear()
		durability_changed.emit(durability_state, durability_detail)
	else:
		_set_durability_failure("Browser storage could not confirm this save. Save again or export your journey before closing. " + str(result.get("error", "")))

func _set_durability_failure(detail: String) -> void:
	durability_state = "failed"
	durability_detail = detail
	durability_changed.emit(durability_state, durability_detail)
	message.emit(durability_detail)

func _save_message(text: String) -> String:
	# Queued operation notices must not retain an obsolete persistence phase.
	# durability_changed owns pending, confirmed and failed browser storage.
	return text.trim_suffix(".") + " (local copy)." if OS.has_feature("web") else text

func _read_slot(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "path": path, "reason": "missing"}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "path": path, "reason": "unreadable"}
	var content: String = file.get_as_text()
	file.close()
	# Always read the real storage boundary, including after atomic rename/import.
	# Only parse/migration work is reused, keyed by exact bytes, never mtime.
	var token := content.sha256_text()
	if _decoded_slots.has(token):
		var cached: Dictionary = _decoded_slots[token].duplicate(true)
		cached["path"] = path
		return cached
	var result: Dictionary = Codec.decode(content, path)
	if not bool(result.get("ok", false)):
		return result
	if _decoded_slots.size() >= 8:
		_decoded_slots.erase(_decoded_slots.keys()[0])
	_decoded_slots[token] = result.duplicate(true)
	return result

func _reject_newer_save(result: Dictionary) -> bool:
	if result.get("reason", "") != "future_version":
		return false
	message.emit("This save needs a newer game version. Your save files were preserved.")
	return true

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

func set_summary_definitions(quest_definitions: Dictionary, item_definitions: Dictionary) -> void:
	_summary_quests = quest_definitions.duplicate(true)
	_summary_items = item_definitions.duplicate(true)
	_summary_cache.clear()

func _summary_for_result(result: Dictionary, fallback_title: String) -> Dictionary:
	var key := str(result.get("token", "")) + ":" + fallback_title
	var cacheable := not str(result.get("token", "")).is_empty()
	if cacheable and _summary_cache.has(key):
		return _summary_cache[key].duplicate(true)
	var data: Dictionary = result.get("data", {}).duplicate(true)
	if str(data.get("slot_name", "")).is_empty():
		data["slot_name"] = fallback_title
	var summary: Dictionary = JourneySummary.describe(data, result.get("recorded", {}), _summary_quests, _summary_items)
	if _summary_cache.size() >= 32:
		_summary_cache.erase(_summary_cache.keys()[0])
	if cacheable:
		_summary_cache[key] = summary.duplicate(true)
	return summary

func _payload_token_for_result(result: Dictionary) -> String:
	var key := str(result.get("token", ""))
	if key.is_empty():
		return Codec.payload_token(result.get("data", {}))
	if not _payload_tokens.has(key):
		if _payload_tokens.size() >= 32:
			_payload_tokens.erase(_payload_tokens.keys()[0])
		_payload_tokens[key] = Codec.payload_token(result.get("data", {}))
	return str(_payload_tokens[key])

func _card_for_result(slot_id: String, source: String, result: Dictionary) -> Dictionary:
	return Selection.card(slot_id, source, result, _summary_for_result(result, Selection._slot_label(slot_id)), _payload_token_for_result(result))

func _slot_model(slot_id: String) -> Dictionary:
	var path: String = slot_path(slot_id)
	if path == "":
		return Selection._empty_model("unavailable", Selection._reason_text("invalid_selection"))
	var primary: Dictionary = _read_slot(path)
	if str(primary.get("reason", "")) == "future_version":
		return Selection._empty_model("newer_version", Selection._reason_text("future_version"))
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
	return Selection._empty_model("newer_version" if newer else ("empty" if missing else "unavailable"), Selection._reason_text("future_version" if newer else str(primary.get("reason", "missing"))))

func _specific_model(slot_id: String, source: String) -> Dictionary:
	var selection: Dictionary = {"slot_id": slot_id, "source": source, "token": ""}
	var result: Dictionary = _read_selection(selection, false)
	if not bool(result.get("ok", false)):
		return Selection._empty_model("newer_version" if str(result.get("reason", "")) == "future_version" else "unavailable", Selection._reason_text(str(result.get("reason", ""))))
	return _card_for_result(slot_id, source, result)

func _model_for_path(path: String) -> Dictionary:
	for id: String in _all_slot_ids():
		if slot_path(id) == path:
			return _slot_model(id)
		if backup_path(slot_path(id)) == path:
			return _specific_model(id, "backup")
	return Selection._empty_model("unavailable", Selection._reason_text("invalid_selection"))

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
			return Selection._empty_model("unavailable", "The remembered Continue selection could not be read. Your saves remain in Saved Journeys.")
		var identity: Dictionary = pointer.data
		var model: Dictionary = _specific_model(str(identity.get("slot_id", "")), str(identity.get("source", "primary")))
		var result: Dictionary = Selection.remembered_continue(identity, model)
		if bool(result.get("read_snapshot", false)):
			result = Selection.remembered_continue(identity, model, _specific_model(str(identity.get("slot_id", "")), "resume"))
		if bool(result.get("read_recovery", false)):
			result.erase("read_recovery")
			result["recovery"] = _same_journey_recovery(str(identity.get("journey_id", "")), bool(identity.get("replay", false)))
		return result
	var candidates: Array[Dictionary] = []
	var newer_found: bool = false
	for slot_id: String in CAMPAIGN_RESUME_SLOTS:
		var model: Dictionary = _slot_model(slot_id)
		newer_found = newer_found or str(model.get("status", "")) == "newer_version"
		if bool(model.get("available", false)) and not bool(model.get("summary", {}).get("replay", false)):
			candidates.append(model)
	return Selection.fallback_continue(candidates, newer_found)

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
		if bool(model.get("available", false)) and Selection._matches_journey(model.get("summary", {}), current_id, current_replay):
			model["reason"] = "Returns to this copy's recorded place, supplies and choices. Progress made after this save is not part of the copy."
			return model
		for recovery: Dictionary in model.get("recovery", []):
			if Selection._matches_journey(recovery.get("summary", {}), current_id, current_replay):
				return recovery
	var missing: Dictionary = Selection._empty_model("unavailable", "No readable checkpoint for this journey is available. Open Saved Journeys to choose another recorded copy.")
	missing["recovery"] = _same_journey_recovery(current_id, current_replay)
	return missing

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
			if token != "" and not seen.has(token) and Selection._matches_journey(copy.get("summary", {}), identity, replay):
				seen[token] = true
				var card: Dictionary = copy.duplicate(true)
				card["recovery"] = []
				candidates.append(card)
	Fields._sort_recorded_time(candidates)
	var limited: Array[Dictionary] = []
	for index in range(mini(candidates.size(), 3)):
		limited.append(candidates[index])
	return limited

func slot_path(slot_id: String) -> String:
	if slot_id.begins_with("manual_"):
		var number := slot_id.trim_prefix("manual_").to_int()
		return "user://ashen_oath_manual_%d.json" % number if number >= 1 and number <= MANUAL_SLOT_COUNT and slot_id == "manual_%d" % number else ""
	return {"quick": SAVE_PATH, "auto": AUTOSAVE_PATH, "checkpoint": CHECKPOINT_PATH, "decision": PRE_DECISION_PATH, "covenant": PRE_COVENANT_PATH, "completed": COMPLETED_CAMPAIGN_PATH, "replay": "user://ashen_oath_replay_autosave.json", "replay_quick": "user://ashen_oath_replay_save.json", "replay_checkpoint": "user://ashen_oath_replay_checkpoint.json", "replay_decision": "user://ashen_oath_replay_before_decision.json", "replay_covenant": "user://ashen_oath_replay_before_covenant.json"}.get(slot_id, "")

func _read_selection(selection: Dictionary, require_token: bool = true) -> Dictionary:
	var slot_id: String = str(selection.get("slot_id", ""))
	var source: String = str(selection.get("source", ""))
	if source == "resume":
		var primary := _read_slot(slot_path(slot_id)) if slot_path(slot_id) != "" else {}
		if str(primary.get("reason", "")) == "future_version":
			return primary
		var snapshot := _read_resume_snapshot(slot_id)
		if bool(snapshot.get("ok", false)) and require_token \
				and str(snapshot.get("token", "")) != str(selection.get("token", "")):
			return {"ok": false, "reason": "changed", "path": RESUME_PATH}
		return snapshot
	var path: String = ""
	if slot_id.begins_with("chapter:") and source == "chapter":
		var chapter_id: String = slot_id.trim_prefix("chapter:")
		if chapter_id not in CHAPTER_IDS:
			return {"ok": false, "reason": "invalid_selection"}
		var completed: Dictionary = _read_slot(COMPLETED_CAMPAIGN_PATH)
		if not bool(completed.get("ok", false)):
			return completed
		if chapter_id not in CampaignRevision.chapter_ids(CampaignRevision.from_save(completed.data)):
			return {"ok": false, "reason": "invalid_selection"}
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
		print("JOURNEY: load_rejected reason=%s" % str(prepared.get("reason", "unavailable")))
		operation_finished.emit(str(selection.get("slot_id", "")), "load", false, text)
		message.emit(text)
		library_changed.emit()
		return false
	print("JOURNEY: load_prepared destination=%s" % str(prepared.get("data", {}).get("zone", "")))
	load_prepared_requested.emit(prepared)
	return true

func prepare_load(selection: Dictionary) -> Dictionary:
	if not _pending_load.is_empty() and bool(_pending_load.get("accepted", false)):
		return {"ok": false, "request_id": "", "data": {}, "summary": {}, "source": {}, "reason": "busy", "message": "A journey is already being placed on the road. Wait for that arrival before loading another copy."}
	var result: Dictionary = _read_selection(selection)
	if not bool(result.get("ok", false)):
		var reason: String = str(result.get("reason", "invalid_selection"))
		return {"ok": false, "request_id": "", "data": {}, "summary": {}, "source": {}, "reason": reason, "message": Selection._reason_text(reason)}
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
	var source: Dictionary = {"slot_id": slot_id, "source": source_kind, "token": str(result.get("token", "")), "label": "Chapter replay copy" if is_chapter else str(card.get("source_label", Selection._slot_label(slot_id))), "recovered_backup": source_kind == "backup", "replay": bool(data.get("replay_session", false))}
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
		return {"ok": false, "request_id": request_id, "reason": reason, "message": Selection._reason_text(reason)}
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
	if pointer_source == "resume":
		pointer_source = str(pending.get("read_result", {}).get("resume_source", "primary"))
	elif pointer_source == "chapter":
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
	var content := file.get_as_text()
	var parsed: Variant = JSON.parse_string(content)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "exists": true}
	if not Codec.valid_resume_pointer(parsed, slot_path(str(parsed.get("slot_id", ""))) != ""):
		return {"ok": false, "exists": true}
	if typeof(parsed.get("summary")) != TYPE_DICTIONARY:
		parsed["summary"] = {}
	return {"ok": true, "exists": true, "data": parsed, "token": content.sha256_text()}

func _read_resume_snapshot(slot_id: String) -> Dictionary:
	var record: Dictionary = _read_resume_pointer()
	if not bool(record.get("ok", false)):
		return {"ok": false, "reason": "invalid_selection"}
	return Codec.resume_snapshot(record.data, slot_id, RESUME_PATH, str(record.token))

func _write_resume_pointer(slot_id: String, source: String, data: Dictionary, summary: Dictionary = {}) -> bool:
	if slot_path(slot_id) == "" or source not in ["primary", "backup"]:
		return false
	var saved_summary: Dictionary = summary.duplicate(true)
	if saved_summary.is_empty():
		saved_summary = JourneySummary.describe(data, Fields._recorded_metadata(data), _summary_quests, _summary_items)
	var pointer: Dictionary = {"version": 1, "slot_id": slot_id, "source": source, "journey_id": str(data.get("journey_id", "")), "replay": bool(data.get("replay_session", false)), "state_token": Codec.payload_token(data), "summary": saved_summary, "payload": data}
	var content := JSON.stringify(pointer, "\t")
	if content.to_utf8_buffer().size() > MAX_IMPORT_BYTES:
		return false
	var temporary: String = RESUME_PATH + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(content)
	file.flush()
	var write_error := file.get_error()
	file = null
	if write_error != OK or FileAccess.get_file_as_string(temporary) != content:
		_remove_if_present(temporary)
		return false
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
	_queue_browser_sync()
	return true

func _remember_gameplay_save(path: String, data: Dictionary) -> bool:
	for slot_id: String in _all_slot_ids():
		if path != slot_path(slot_id) or (slot_id not in CAMPAIGN_RESUME_SLOTS and slot_id not in REPLAY_RESUME_SLOTS):
			continue
		if slot_id in ["checkpoint", "replay_checkpoint"]:
			var pointer: Dictionary = _read_resume_pointer()
			var selected: Dictionary = pointer.get("data", {})
			var selected_slot := str(selected.get("slot_id", ""))
			var explicit_copy := selected_slot.begins_with("manual_") or selected_slot in ["quick", "replay_quick"] or str(selected.get("source", "")) == "backup"
			if bool(pointer.get("ok", false)) and explicit_copy and str(selected.get("journey_id", "")) == str(data.get("journey_id", "")):
				# Background/death checkpoints remain available independently;
				# they must not retarget an explicit quick/manual/recovery choice.
				return true
		var recorded: Dictionary = _read_slot(path)
		if not bool(recorded.get("ok", false)) or not _write_resume_pointer(slot_id, "primary", recorded.get("data", data)):
			message.emit(_save_message("The journey was written, but Continue could not remember its source. Choose the copy in Saved Journeys."))
			return false
		return true
	return true

func list_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for number in range(1, MANUAL_SLOT_COUNT + 1):
		slots.append(_slot_summary("manual_%d" % number, "Journey %d" % number, false))
	for slot_id: String in ["quick", "auto", "checkpoint", "decision", "covenant", "completed", "replay", "replay_quick", "replay_checkpoint", "replay_decision", "replay_covenant"]:
		if slot_id.begins_with("replay_") and not FileAccess.file_exists(slot_path(slot_id)) and not FileAccess.file_exists(backup_path(slot_path(slot_id))):
			continue
		slots.append(_slot_summary(slot_id, Selection._slot_label(slot_id), true))
	return slots

func _slot_summary(slot_id: String, fallback_title: String, protected_slot: bool) -> Dictionary:
	var path: String = slot_path(slot_id)
	var primary: Dictionary = _read_slot(path)
	var model: Dictionary = _slot_model(slot_id)
	var summary: Dictionary = model.get("summary", {})
	if str(model.get("source_label", "")) == "":
		model["source_label"] = Selection._slot_label(slot_id)
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
	data["slot_name"] = Fields._safe_slot_name(title)
	if not _write_atomic(slot_path(slot_id), data):
		operation_finished.emit(slot_id, "save", false, "The save could not be written. The previous copy is preserved.")
		return false
	var remembered := _remember_gameplay_save(slot_path(slot_id), data)
	var text := "Saved: " + str(data.slot_name)
	if not remembered:
		text += ". Continue selection is unchanged; choose this copy in Saved Journeys."
	operation_finished.emit(slot_id, "save", true, _save_message(text))
	library_changed.emit()
	return true

func rename_slot(slot_id: String, title: String) -> bool:
	if not slot_id.begins_with("manual_") or slot_path(slot_id).is_empty():
		return false
	var result := _read_slot(slot_path(slot_id))
	if not bool(result.get("ok", false)):
		operation_finished.emit(slot_id, "rename", false, "The slot could not be read; its name is unchanged.")
		return false
	result.data["slot_name"] = Fields._safe_slot_name(title)
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
	var error := Codec._import_error(raw)
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
	data["slot_name"] = Fields._safe_slot_name(str(raw.get("slot_name", "Imported journey")))
	# Moving a replay between devices must retain its separate automatic saves.
	# Migration already validates this flag and defaults older campaign saves.
	if not _write_atomic(slot_path(destination), data):
		operation_finished.emit(destination, "import", false, "The import could not be saved. Existing journeys are unchanged.")
		return false
	operation_finished.emit(destination, "import", true, "Imported into %s. Select the slot to load it." % destination.replace("_", " ").capitalize())
	library_changed.emit()
	return true

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
	for quest_id: String in CampaignRevision.chapter_ids(CampaignRevision.from_save(completed.data)):
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
