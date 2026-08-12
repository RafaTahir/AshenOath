extends SceneTree

const PROJECT := "res://project.godot"
const EXPORT_PRESET := "res://export_presets.cfg"
const TELEMETRY := "res://scripts/qa_browser_telemetry.gd"
const BROWSER_HARNESS := "res://tools/verify_qa_002_browser.mjs"

var failures := 0

func _initialize() -> void:
	_verify_static_contract()
	await _verify_runtime_snapshot()
	print("QA-002 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _verify_static_contract() -> void:
	var project_source := _read(PROJECT)
	var export_source := _read(EXPORT_PRESET)
	var telemetry_source := _read(TELEMETRY)
	var browser_source := _read(BROWSER_HARNESS)
	_check(not project_source.contains("QABrowserTelemetry=\"*res://scripts/qa_browser_telemetry.gd\""),
		"QA telemetry must not be a production autoload")
	_check(export_source.contains("name=\"Web QA Browser\"") and export_source.contains("custom_features=\"ashenoath_qa\""),
		"Disposable QA Web preset is missing")
	_check(export_source.contains("export_files=PackedStringArray(\"res://scenes/main.tscn\"") and
		export_source.contains("\"res://scripts/qa_browser_telemetry.gd\""),
		"QA telemetry is missing from the disposable QA Web export")
	_check(telemetry_source.contains("URLSearchParams") and telemetry_source.contains("get('qa') === '1'"),
		"QA telemetry is not query-gated")
	_check(telemetry_source.contains("ashenoath_qa"),
		"QA telemetry is not custom-feature gated")
	_check(project_source.contains("OS.has_feature(\"ashenoath_qa\")") or _read("res://scripts/game.gd").contains("OS.has_feature(\"ashenoath_qa\")"),
		"Game does not attach QA telemetry only in the QA build")
	_check(telemetry_source.contains("snapshot_for_game"),
		"QA telemetry has no read-only snapshot interface")
	var production_section := export_source.split("[preset.1]", false)[0]
	_check(not production_section.contains("qa_browser_telemetry.gd"),
		"QA command implementation is not isolated from the production preset")
	_check(export_source.contains('name="Web QA Browser"') and
		export_source.contains('"res://scripts/qa_browser_telemetry.gd"'),
		"QA command implementation is not present in the disposable QA preset")
	for required in [
		"Input.dispatchKeyEvent",
		"Input.dispatchMouseEvent",
		"greyfen-wychwood-return",
		"greyfen-deep-woods-return",
		"greyfen-castle-record-hall-return",
		"console_errors",
		"failure_screenshot",
	]:
		_check(browser_source.contains(required), "Browser harness is missing %s" % required)

func _verify_runtime_snapshot() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	_check(scene != null, "Main scene is unavailable")
	if scene == null:
		return
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_on_launch_accepted")
	await process_frame
	game.call("_new_game")
	for _frame in range(180):
		if bool(game.get("game_started")) and str(game.get("current_zone_id")) == "greyfen" and not bool(game.get("zone_transition_pending")):
			break
		await process_frame
	var telemetry_script := load(TELEMETRY) as GDScript
	_check(telemetry_script != null, "QA telemetry script does not load")
	if telemetry_script == null:
		game.queue_free()
		return
	var telemetry: Node = telemetry_script.new()
	root.add_child(telemetry)
	var snapshot: Dictionary = telemetry.call("snapshot_for_game", game)
	_check(bool(snapshot.get("ready", false)), "Runtime telemetry did not report a playable game")
	_check(str(snapshot.get("zone", "")) == "greyfen", "Runtime telemetry did not report Greyfen")
	var player_state: Dictionary = snapshot.get("player", {})
	var camera_state: Dictionary = snapshot.get("camera", {})
	_check(player_state.has("position"), "Runtime telemetry omitted player position")
	_check(camera_state.has("yaw"), "Runtime telemetry omitted camera yaw")
	var targets: Array = []
	var gates: Array = snapshot.get("gates", [])
	for gate: Dictionary in gates:
		targets.append(str(gate.get("target", "")))
	for target in ["wychwood", "deep_wood", "vargan_approach"]:
		_check(target in targets, "Runtime telemetry omitted the %s gate" % target)
	_check(not bool(telemetry.get("enabled")), "QA telemetry enabled outside a query-gated Web run")
	telemetry.queue_free()
	game.queue_free()

func _read(path: String) -> String:
	_check(FileAccess.file_exists(path), "Missing QA-002 file: %s" % path)
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
