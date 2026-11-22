extends SceneTree
## Phase 1 architecture and real scene/save boundary checks.
## Run: godot --headless --path . --script tools/verify_boundaries.gd
## -- --structure-only checks source contracts without starting a game.
## The full Linux run restarts with isolated user data before any game loads.

const GAME_PATH := "res://scripts/game.gd"
const HUD_PATH := "res://scripts/hud/hud_root.gd"
const DEADLINE_MS := 60000
const REQUIRED_SYSTEMS := {
	"zone_lifecycle": "zone_lifecycle_service",
	"combat": "combat_coordinator",
	"dialogue": "dialogue_service",
	"quest": "quest_service",
	"inventory": "inventory_service",
	"save": "save_service",
	"hud": "hud_coordinator",
}
const REQUIRED_OPERATIONS := {
	"zone_lifecycle": ["_load_zone"], "combat": ["_on_player_blade_contact"],
	"dialogue": ["_handle_dialogue_action"], "quest": ["_on_quest_completed"],
	"inventory": ["_use_inventory_item"], "save": ["save_world_state", "load_world_state"],
	"hud": ["_refresh_tracker"],
}
const SYSTEM_SIGNALS := {
	"zone_lifecycle": "zone_changed", "combat": "combat_impact",
	"dialogue": "dialogue_action_completed", "quest": "quest_completed",
	"inventory": "inventory_operation_completed", "save": "world_state_loaded",
	"hud": "tracker_refreshed",
}
const REQUIRED_PANELS := {
	"quest_panel": {"methods": ["set_tracker", "set_navigation_model"], "signal": "interaction_prompt_changed"},
	"dialogue_panel": {"methods": ["show_dialogue"], "signal": "action_selected"},
	"inventory_panel": {"methods": ["show_inventory", "show_vendor"], "signal": "craft_requested"},
	"settings_panel": {"methods": ["show_settings_menu", "apply_accessibility"], "signal": "settings_requested"},
	"combat_feedback": {"methods": ["update_health", "update_stamina", "post_notice"], "signal": "touch_quick_action_requested"},
}
const REQUIRED_SAVE_KEYS := [
	"version", "game_id", "journey_id", "zone", "world_sector", "player_position",
	"world_position", "seamless_world", "player_health", "player_stamina", "equipment",
	"inventory", "vendors", "minigames", "quests", "quest_presentation", "quest_beats",
	"story_state", "progression", "settings", "world_state", "text_history",
]
const PROBE_FLAG := "phase_1_boundary_save_probe"

class ErrorLog extends Logger:
	var errors: Dictionary = {}
	var warnings := 0
	var mutex := Mutex.new()
	func _log_error(_function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		mutex.lock()
		if error_type == Logger.ERROR_TYPE_WARNING:
			warnings += 1
		else:
			var key := "%s:%d %s %s" % [file, line, code, rationale]
			errors[key] = int(errors.get(key, 0)) + 1
		mutex.unlock()
	func snapshot() -> Dictionary:
		mutex.lock()
		var result := errors.duplicate()
		mutex.unlock()
		return result

var failures: Array[String] = []
var checks := 0
var error_log := ErrorLog.new()
var game: Node
var saved_payload: Dictionary = {}
var watchdog: SceneTreeTimer
var finishing := false
var opening_skip_sent := false
var zone_events: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if not arguments.has("--structure-only") and not arguments.has("--isolated-worker"):
		_run_isolated()
		return
	OS.add_logger(error_log)
	watchdog = create_timer(240.0, true)
	watchdog.timeout.connect(_on_timeout)
	_verify_structure()
	if not arguments.has("--structure-only"):
		var isolated := OS.get_environment("ASHENOATH_BOUNDARY_DATA_DIR")
		_check(not isolated.is_empty() and OS.get_user_data_dir().begins_with(isolated + "/"),
			"runtime uses a separate user-data directory")
		if isolated.is_empty() or not OS.get_user_data_dir().begins_with(isolated + "/"):
			_finish()
			return
		await _verify_runtime()
	_finish()

func _run_isolated() -> void:
	if OS.get_name() != "Linux":
		print("BOUNDARIES: FAIL - full verifier requires Linux user-data isolation")
		quit(1)
		return
	var directory := "/tmp/ashen-oath-boundaries-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		print("BOUNDARIES: FAIL - cannot create isolated save directory")
		quit(1)
		return
	OS.set_environment("XDG_DATA_HOME", directory)
	OS.set_environment("ASHENOATH_BOUNDARY_DATA_DIR", directory)
	var output: Array = []
	var status := OS.execute(OS.get_executable_path(), PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", get_script().resource_path, "--", "--isolated-worker",
	]), output, true)
	for text: String in output:
		print(text.trim_suffix("\n"))
	if status != 0:
		print("BOUNDARIES: worker failed; isolated saves retained at " + directory)
	else:
		_remove_directory(directory)
	quit(status if status >= 0 else 1)

func _verify_structure() -> void:
	_check_line_limit(GAME_PATH, 500)
	_check_line_limit(HUD_PATH, 400)
	for id: String in REQUIRED_SYSTEMS:
		var path := "res://scripts/systems/%s.gd" % REQUIRED_SYSTEMS[id]
		_check(FileAccess.file_exists(path), "service source exists: " + id)
		if FileAccess.file_exists(path):
			var script := load(path) as Script
			_check(script != null and script.can_instantiate(), "service script parses: " + id)
			if script != null:
				_check(_script_has(script, "configure", false), "service explicitly accepts dependencies: " + id)
				_check(_script_has(script, "configured", true), "service exposes configured signal: " + id)
				var source := FileAccess.get_file_as_string(path)
				for method: String in REQUIRED_OPERATIONS[id]:
					_check(source.contains("\nfunc " + method + "("), "service owns operation: %s.%s" % [id, method])
				if SYSTEM_SIGNALS.has(id):
					_check(_script_has(script, SYSTEM_SIGNALS[id], true), "service exposes semantic signal: " + id)
	for id: String in REQUIRED_PANELS:
		var path := "res://scripts/hud/%s.gd" % id
		_check(FileAccess.file_exists(path), "HUD panel source exists: " + id)
		if not FileAccess.file_exists(path):
			continue
		var script := load(path) as Script
		_check(script != null and script.can_instantiate(), "HUD panel script parses: " + id)
		if script == null:
			continue
		var source := FileAccess.get_file_as_string(path)
		for method: String in REQUIRED_PANELS[id].methods:
			_check(source.contains("\nfunc " + method + "("), "panel owns operation: %s.%s" % [id, method])
		_check(_script_has(script, "configure", false), "HUD panel accepts injected dependencies: " + id)
		_check(_script_has(script, REQUIRED_PANELS[id].signal, true), "HUD panel exposes request signal: " + id)
	for directory in ["res://scripts/systems", "res://scripts/hud"]:
		_check_no_ancestor_access(directory)
	print("BOUNDARIES STRUCTURE: %s" % ("PASS" if failures.is_empty() else "FAIL"))

func _check_line_limit(path: String, limit: int) -> void:
	_check(FileAccess.file_exists(path), "source exists: " + path)
	if not FileAccess.file_exists(path):
		return
	var text := FileAccess.get_file_as_string(path)
	var count := text.count("\n") + (0 if text.ends_with("\n") else 1)
	_check(count < limit, "%s has %d lines; required <%d" % [path, count, limit])

func _script_has(script: Script, member: String, is_signal: bool) -> bool:
	var current := script
	while current != null:
		var members: Array = current.get_script_signal_list() if is_signal else current.get_script_method_list()
		for entry: Dictionary in members:
			if str(entry.name) == member:
				return true
		current = current.get_base_script()
	return false

func _check_no_ancestor_access(path: String) -> void:
	var directory := DirAccess.open(path)
	_check(directory != null, "extracted source directory exists: " + path)
	if directory == null:
		return
	var ancestor := RegEx.new()
	ancestor.compile("\\b(get_parent|find_parent|get_owner)\\s*\\(|(?:get_node|get_node_or_null)\\s*\\(\\s*[\"']\\.\\.|get_tree\\s*\\(\\s*\\)\\s*\\.\\s*(root|get_root)")
	for filename in directory.get_files():
		if not filename.ends_with(".gd"):
			continue
		var source_path := path.path_join(filename)
		var number := 0
		for line: String in FileAccess.get_file_as_string(source_path).split("\n"):
			number += 1
			var executable := line.split("#", true, 1)[0]
			_check(ancestor.search(executable) == null and not executable.contains('$"../'),
				"no ancestor lookup: %s:%d" % [source_path, number])
	for child in directory.get_directories():
		_check_no_ancestor_access(path.path_join(child))

func _verify_runtime() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	_check(scene != null, "main scene loads")
	if scene == null:
		return
	game = scene.instantiate()
	if game.has_signal("zone_changed"):
		game.connect("zone_changed", func(zone: String): zone_events.append(zone))
	root.add_child(game)
	game.call("_new_game")
	if not await _wait_for_zone("greyfen"):
		await _shutdown()
		return
	_verify_system_bindings()
	_verify_zone("greyfen")
	_check(zone_events.has("greyfen"), "initial zone event reaches composition root")
	game.call("_refresh_tracker")
	await process_frame
	var view: Dictionary = game.quest_presentation.get_objective_view_model()
	_check(view.get("quest_id") == "main_road_of_crows", "opening quest remains selected")
	_check(view.get("objective_id") == "speak_anwen", "opening objective remains selected")
	var action := str(view.get("contextual_text", ""))
	_check(not action.is_empty() and str(game.hud.tracker_label.text).contains(action), "HUD renders authored opening objective")
	game.story_state.set_flag(PROBE_FLAG, "saved")
	_check(game.save_manager.save_named(game, "manual_6", "Phase 1 boundary round trip"), "current save writes through SaveManager")
	var slot: Dictionary = game.save_manager._read_slot(game.save_manager.slot_path("manual_6"))
	_check(bool(slot.get("ok", false)), "current save reads through SaveManager")
	saved_payload = slot.get("data", {}).duplicate(true)
	_verify_save_schema(saved_payload, "greyfen")
	game.story_state.set_flag(PROBE_FLAG, "changed after save")
	for zone: String in ["wychwood", "greyfen"]:
		var event_start := zone_events.size()
		game.call("_load_zone", zone, Vector3(0, 1, 7))
		if not await _wait_for_zone(zone):
			await _shutdown()
			return
		_verify_zone(zone)
		_check(zone_events.slice(event_start).has(zone), "zone event reaches composition root: " + zone)
		_verify_save_schema(game.save_manager._build_save_data(game), zone)
	_check(str(game.story_state.get_flag(PROBE_FLAG, "")) == "changed after save", "ordinary travel preserves story state")
	await _verify_save_round_trip()
	await _shutdown()

func _verify_system_bindings() -> void:
	_check(game.has_method("get_system"), "game exposes explicit system lookup")
	if not game.has_method("get_system"):
		return
	for id: String in REQUIRED_SYSTEMS:
		var service: Node = game.get_system(id)
		_check(is_instance_valid(service) and service.is_inside_tree(), "live service is bound: " + id)
		if is_instance_valid(service):
			_check(service.has_method("configure") and service.has_signal("configured"), "live service API: " + id)
			_check(service.get("_host") == game and service.get("_state") == game.get("_state"), "service uses injected host and shared state: " + id)
			for method: String in REQUIRED_OPERATIONS[id]:
				_check(service.has_method(method), "live service operation: %s.%s" % [id, method])
			if SYSTEM_SIGNALS.has(id):
				var event: String = SYSTEM_SIGNALS[id]
				_check(service.has_signal(event) and not service.get_signal_connection_list(event).is_empty(), "service event is routed by composition root: " + id)
	for name in ["runtime_services", "world_materials", "hud", "quests", "story_state", "save_manager", "inventory", "zone_runtime_coordinator"]:
		_check(game.get(name) != null, "existing game property remains available: " + name)
	for id: String in REQUIRED_PANELS:
		var panel: Node = game.hud.get(id)
		_check(is_instance_valid(panel) and panel.is_inside_tree(), "live HUD panel is bound: " + id)
		if not is_instance_valid(panel):
			continue
		_check(panel.get("view") == game.hud and panel.get("state") == game.hud.get("state"), "panel uses injected view and presentation state: " + id)
		for method: String in REQUIRED_PANELS[id].methods:
			_check(panel.has_method(method), "live HUD panel operation: %s.%s" % [id, method])
		var request: String = REQUIRED_PANELS[id].signal
		_check(panel.has_signal(request) and not panel.get_signal_connection_list(request).is_empty(), "panel request is routed by HUD root: " + id)

func _wait_for_zone(zone: String) -> bool:
	var deadline := Time.get_ticks_msec() + DEADLINE_MS
	var stable_frames := 0
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if not error_log.snapshot().is_empty():
			_check(false, "zone transition has no engine or script errors: " + zone)
			# Preserve the failure while allowing independent save/cleanup checks
			# once the real game readiness contract is satisfied.
		if is_instance_valid(game.zone_root) and bool(game.zone_root.get_meta("opening_scene_active", false)) and not opening_skip_sent:
			# Use the same Escape event a player uses to skip the authored introduction.
			opening_skip_sent = true
			var event := InputEventKey.new()
			event.keycode = KEY_ESCAPE
			event.physical_keycode = KEY_ESCAPE
			event.pressed = true
			Input.parse_input_event(event)
			event = event.duplicate()
			event.pressed = false
			Input.parse_input_event(event)
		var ready: bool = game.game_started and is_instance_valid(game.player) and is_instance_valid(game.zone_root) \
			and str(game.current_zone_id) == zone and not game.new_game_start_pending \
			and not game.zone_transition_pending and not game.zone_load_request_pending \
			and not game.neighbor_crossing_pending and not game.neighbor_arrival_pending \
			and not game.opening_pack_waiting and not game.campaign_pack_waiting \
			and not bool(game.call("_journey_load_pending")) \
			and game.player.can_control and not game.player.transition_locked and not paused
		stable_frames = stable_frames + 1 if ready else 0
		if stable_frames >= 3:
			print("BOUNDARIES ZONE: %s ready with player control" % zone)
			return true
	_check(false, "zone became playable before deadline: " + zone)
	return false

func _verify_zone(zone: String) -> void:
	_check(game.zone_root.is_visible_in_tree(), "active zone is visible: " + zone)
	_check(game.player.is_inside_tree(), "player remains scene-owned: " + zone)
	_check(game.world_materials != null and game.hud != null, "world and HUD dependencies survive: " + zone)
	var snapshot: Dictionary = game.zone_lifecycle_snapshot()
	_check(str(snapshot.get("active_owner", "")) == "active", "zone has active ownership: " + zone)
	_check(int(snapshot.get("cached_count", 0)) <= 1, "zone cache remains bounded: " + zone)
	if zone == "greyfen":
		_check(game.zone_root.find_child("sister_anwen", true, false) != null, "Anwen exists in active Greyfen")
	if zone == "wychwood":
		_check(game.active_enemies.size() == 5, "Wychwood contains all five enemies")
		for enemy: Node in game.active_enemies:
			_check(is_instance_valid(enemy) and enemy.is_inside_tree(), "Wychwood enemy has a live scene reference")
			if is_instance_valid(enemy):
				_check(enemy.get("health_component") != null, "Wychwood enemy has health component")

func _verify_save_schema(payload: Dictionary, zone: String) -> void:
	_check(int(payload.get("version", -1)) == 13, "save format stays version 13")
	_check(str(payload.get("zone", "")) == zone, "save captures current zone: " + zone)
	for key in REQUIRED_SAVE_KEYS:
		_check(payload.has(key), "save schema retains " + key)

func _verify_save_round_trip() -> void:
	_check(game.save_manager.load_slot(game, "manual_6"), "current save load request is accepted")
	if not await _wait_for_zone("greyfen"):
		return
	_check(str(game.story_state.get_flag(PROBE_FLAG, "")) == "saved", "current save restores earlier story state")
	_check(_same_saved_value(game.inventory.save_state(), saved_payload.get("inventory", {})), "current save restores inventory exactly")
	_check(game.quests.save_state().get("evidence_history", {}) == saved_payload.get("quests", {}).get("evidence_history", {}), "current save preserves evidence history")
	var legacy: Dictionary = saved_payload.duplicate(true)
	legacy["version"] = 12
	var file := FileAccess.open(game.save_manager.slot_path("manual_5"), FileAccess.WRITE)
	_check(file != null, "legacy compatibility fixture can be written")
	if file == null:
		return
	file.store_string(JSON.stringify(legacy))
	file.close()
	game.story_state.set_flag(PROBE_FLAG, "changed before legacy load")
	_check(game.save_manager.load_slot(game, "manual_5"), "version 12 save load request is accepted")
	if not await _wait_for_zone("greyfen"):
		return
	_check(str(game.story_state.get_flag(PROBE_FLAG, "")) == "saved", "legacy save restores story state")
	_check(_same_saved_value(game.inventory.save_state(), saved_payload.get("inventory", {})), "legacy save preserves inventory")
	var future: Dictionary = saved_payload.duplicate(true)
	future["version"] = 14
	_check(game.save_manager.migrate_save_data(future).is_empty(), "future save versions remain rejected")
	_verify_save_schema(game.save_manager._build_save_data(game), "greyfen")

func _same_saved_value(actual: Variant, expected: Variant) -> bool:
	# JSON numbers decode as floats, while live inventory counts are integers.
	# Compare every key and value using the representation written to saves.
	return JSON.parse_string(JSON.stringify(actual)) == JSON.parse_string(JSON.stringify(expected))

func _shutdown() -> void:
	if not is_instance_valid(game):
		return
	game.prepare_resource_shutdown()
	for _index in range(40):
		await process_frame
	game.finalize_resource_shutdown()
	for _index in range(12):
		await process_frame
	if game.is_inside_tree():
		root.remove_child(game)
	game.free()
	game = null
	RenderingServer.force_sync()
	for _index in range(8):
		await process_frame

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition and not failures.has(label):
		failures.append(label)
		print("BOUNDARY FAILURE: " + label)

func _finish() -> void:
	if finishing:
		return
	finishing = true
	OS.remove_logger(error_log)
	var errors := error_log.snapshot()
	_check(errors.is_empty(), "no engine or script errors during boundary verification")
	for error: String in errors:
		print("BOUNDARY ENGINE ERROR (%d): %s" % [errors[error], error])
	print("BOUNDARIES: %s checks=%d failures=%d engine_error_types=%d warnings=%d" % [
		"PASS" if failures.is_empty() else "FAIL", checks, failures.size(), errors.size(), error_log.warnings,
	])
	quit(0 if failures.is_empty() else 1)

func _on_timeout() -> void:
	_check(false, "boundary verifier completed within 240 seconds")
	_finish()

func _remove_directory(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for filename in directory.get_files():
		directory.remove(filename)
	for child in directory.get_directories():
		_remove_directory(path.path_join(child))
	DirAccess.remove_absolute(path)
