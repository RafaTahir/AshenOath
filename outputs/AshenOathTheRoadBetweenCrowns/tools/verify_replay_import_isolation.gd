extends SceneTree
## Exercises real import/load/save routing with JSON bytes held only in memory.
## No FileAccess or DirAccess writes, real registered saves, scenes or actors.

const SaveManager = preload("res://scripts/save_manager.gd")

class ErrorLog extends Logger:
	var errors: Array[String] = []
	func _log_error(_function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != Logger.ERROR_TYPE_WARNING:
			errors.append("%s:%d %s %s" % [file, line, code, rationale])

class MemorySaveManager extends SaveManager:
	var files: Dictionary = {}
	var writes: Array[String] = []

	func _write_atomic(path: String, data: Dictionary) -> bool:
		_store(path, data)
		return true

	func _read_slot(path: String) -> Dictionary:
		if not files.has(path):
			return {"ok": false, "path": path, "reason": "missing"}
		var content: String = files[path]
		var raw: Dictionary = JSON.parse_string(content)
		return {"ok": true, "path": path, "data": migrate_save_data(raw),
			"recorded": _recorded_metadata(raw), "token": content.sha256_text()}

	func _read_resume_pointer() -> Dictionary:
		if not files.has(RESUME_PATH):
			return {"ok": false, "exists": false}
		return {"ok": true, "exists": true, "data": JSON.parse_string(files[RESUME_PATH])}

	func _write_resume_pointer(slot_id: String, source: String, data: Dictionary, summary: Dictionary = {}) -> bool:
		_store(RESUME_PATH, {"version": 1, "slot_id": slot_id, "source": source,
			"journey_id": str(data.journey_id), "replay": bool(data.replay_session),
			"state_token": _journey_payload_token(data), "summary": summary, "payload": data})
		return true

	func _store(path: String, data: Dictionary) -> void:
		files[path] = JSON.stringify(data)
		writes.append(path)

class StateStub extends Node:
	var state: Dictionary
	var active: Dictionary = {}
	func _init(initial: Dictionary = {}) -> void:
		load_state(initial)
	func save_state() -> Dictionary:
		return state.duplicate(true)
	func load_state(value: Dictionary) -> void:
		state = value.duplicate(true)
		active = state.get("active", {}).duplicate(true)
	func get_flag(id: String, fallback: Variant = null) -> Variant:
		return state.get("flags", {}).get(id, fallback)

class PlayerStub extends Node3D:
	var health_component := StateStub.new({"health": 80.0, "max_health": 125.0, "dead": false})
	var stamina_component := StateStub.new({"stamina": 55.0, "max_stamina": 100.0})
	func _init() -> void:
		add_child(health_component)
		add_child(stamina_component)

class GameStub extends Node:
	var current_zone_id := "greyfen"
	var zone_root := Node3D.new()
	var player := PlayerStub.new()
	var inventory := StateStub.new({"items": {}, "ingredients": {}, "coin": 72})
	var quests := StateStub.new({"active": {}, "completed": {}, "unlocked": {}, "world_flags": {}})
	var story_state := StateStub.new({"flags": {}, "values": {}, "evidence": {}})
	var progression := StateStub.new()
	var loaded: Dictionary = {}
	func _init() -> void:
		for child in [zone_root, player, inventory, quests, story_state, progression]:
			add_child(child)
	func save_world_state() -> Dictionary:
		return {}
	func checkpoint_return_position() -> Vector3:
		return player.global_position
	func load_save_state(data: Dictionary) -> void:
		loaded = data.duplicate(true)
		inventory.load_state(data.inventory)

var failures: Array[String] = []
var checks := 0
var error_log := ErrorLog.new()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	OS.add_logger(error_log)
	for wrapped: bool in [false, true]:
		for flag_case: String in ["replay", "campaign", "missing", "malformed"]:
			_verify_import(wrapped, flag_case)
	OS.remove_logger(error_log)
	_check(error_log.errors.is_empty(), "No engine or script errors during replay import verification")
	for error: String in error_log.errors:
		print("REPLAY IMPORT ENGINE ERROR: " + error)
	print("REPLAY IMPORT ISOLATION: %s checks=%d cases=8 storage=in_memory" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _payload(identity: String) -> Dictionary:
	return {"version": SaveManager.CURRENT_VERSION, "game_id": "ashen-oath",
		"journey_id": identity, "zone": "greyfen", "player_position": [0, 1, 7],
		"inventory": {"items": {}, "ingredients": {}, "coin": 72},
		"quests": {"active": {}, "completed": {}, "unlocked": {}, "world_flags": {}},
		"story_state": {"flags": {}, "values": {}, "evidence": {}}, "world_state": {}}

func _verify_import(wrapped: bool, flag_case: String) -> void:
	var label := ("envelope" if wrapped else "raw") + ":" + flag_case
	var replay := flag_case == "replay"
	var manager := MemorySaveManager.new()
	var game := GameStub.new()
	root.add_child(manager)
	root.add_child(game)
	# Distinct campaign primary/backup bytes must survive all replay operations.
	var campaign_before: Dictionary = {}
	for slot: String in ["quick", "auto", "checkpoint", "decision", "covenant", "completed"]:
		for path: String in [manager.slot_path(slot), manager.backup_path(manager.slot_path(slot))]:
			var original := _payload("protected-" + slot)
			original["slot_name"] = path
			manager.files[path] = JSON.stringify(original)
			campaign_before[path] = manager.files[path]
	var payload := _payload("portable-" + label.validate_filename())
	match flag_case:
		"replay": payload["replay_session"] = true
		"campaign": payload["replay_session"] = false
		"malformed": payload["replay_session"] = "true"
	var content := JSON.stringify({"format": "ashen-oath-save", "format_version": 1, "save": payload} if wrapped else payload)
	# Explicit destination avoids even consulting real user:// slot occupancy.
	_check(manager.import_save_text(content, "manual_1"), label + ": import accepted")
	var imported: Dictionary = manager._read_slot(manager.slot_path("manual_1"))
	_check(bool(imported.data.replay_session) == replay, label + ": imported replay flag preserved/defaulted")
	_check(int(imported.data.version) == SaveManager.CURRENT_VERSION, label + ": schema version unchanged")
	_check(str(imported.data.journey_id) == str(payload.journey_id), label + ": journey identity preserved")
	var requests: Array[Dictionary] = []
	manager.load_prepared_requested.connect(func(prepared: Dictionary): requests.append(prepared.duplicate(true)))
	_check(manager.load_slot(game, "manual_1"), label + ": load requested")
	_check(requests.size() == 1, label + ": one prepared load")
	if requests.size() == 1:
		var prepared: Dictionary = requests[0]
		_check(bool(prepared.data.replay_session) == replay, label + ": prepared replay flag retained")
		var accepted: Dictionary = manager.accept_prepared_load(str(prepared.request_id))
		_check(bool(accepted.ok), label + ": load accepted")
		game.load_save_state(prepared.data)
		var finished: Dictionary = manager.finish_load(game, str(prepared.request_id), true)
		_check(bool(finished.ok) and manager.replay_session == replay, label + ": finished load retains routing mode")
		_check(int(game.loaded.inventory.coin) == 72, label + ": imported supplies retained")
		for operation: String in ["quick", "auto", "checkpoint", "decision", "covenant"]:
			_verify_write(manager, game, operation, replay, label)
	if replay:
		for path: String in campaign_before:
			_check(manager.files.get(path) == campaign_before[path], label + ": campaign bytes unchanged: " + path)
	game.free()
	manager.free()

func _verify_write(manager: MemorySaveManager, game: GameStub, operation: String, replay: bool, label: String) -> void:
	manager.writes.clear()
	var succeeded := false
	match operation:
		"quick": succeeded = manager.save_game(game)
		"auto": succeeded = manager.autosave(game)
		"checkpoint": succeeded = manager.checkpoint(game)
		"decision": succeeded = manager.predecision(game, "fixture_choice")
		"covenant": succeeded = manager.save_game(game, SaveManager.PRE_COVENANT_PATH)
	var slot := ("replay_quick" if operation == "quick" else "replay" if operation == "auto" else "replay_" + operation) if replay else operation
	var expected := manager.slot_path(slot)
	_check(succeeded and manager.writes.has(expected), label + ": " + operation + " writes the expected route")
	for path: String in manager.writes:
		_check(path == expected or path == SaveManager.RESUME_PATH, label + ": " + operation + " has no other slot writes: " + path)
	var saved: Dictionary = manager._read_slot(expected)
	_check(bool(saved.get("ok", false)) and bool(saved.get("data", {}).get("replay_session", false)) == replay,
		label + ": " + operation + " keeps its replay flag on the next save")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		print("REPLAY IMPORT FAILURE: " + message)
