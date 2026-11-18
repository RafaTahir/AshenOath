extends SceneTree
## Actual source-local main/opening import closure only. No rendered, gameplay
## or performance acceptance; the caller installs disposable APPDATA first.
class Errors extends Logger:
	var messages: Array[String] = []
	func _log_error(_function: String,file: String,line: int,code: String,rationale: String,
			_editor_notify: bool,error_type: int,_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type!=Logger.ERROR_TYPE_WARNING: messages.append("%s:%d %s %s"%[file,line,code,rationale])
var errors := Errors.new()
var game: Variant
var failures: Array[String] = []
var destination := ""

func _initialize() -> void:
	OS.add_logger(errors)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): destination = argument.trim_prefix("--output=")
	call_deferred("_run")

func _wait(predicate: Callable,seconds: float) -> bool:
	var deadline := Time.get_ticks_msec()+int(seconds*1000)
	while true:
		if bool(predicate.call()): return true
		if not errors.messages.is_empty() or Time.get_ticks_msec()>=deadline: return false
		await process_frame
	return false

func _run() -> void:
	if not OS.get_environment("APPDATA").replace("\\","/").begins_with("D:/Temp/AO_MonsterVitality_20261118/"):
		failures.append("Disposable profile environment required")
	else:
		var staff: Resource = load("res://assets_external/design_pack_v1/C01_ash_staff.glb")
		if not staff is PackedScene: failures.append("Actual cached staff scene/dependencies did not load")
		game = load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		if not await _wait(func() -> bool: return game.opening_startup_metrics.has("menu_ready_ms"),120.0):
			failures.append("Source-local main/opening menu did not prepare cleanly")
		elif errors.messages.is_empty():
			game._new_game()
			if not await _wait(func() -> bool: return game.game_started and is_instance_valid(game.player) and game.player.can_control and not game.zone_transition_pending and not game.opening_scene_pending,120.0):
				failures.append("Actual new-journey player construction/opening did not finish cleanly")
	var player_constructed: bool = is_instance_valid(game) and is_instance_valid(game.player) and game.player.body_visual!=null and game.player.animation_driver!=null
	if not player_constructed: failures.append("Actual retained player body/driver were unavailable")
	if is_instance_valid(game):
		game.queue_free()
		for index in 3: await process_frame
	if not errors.messages.is_empty(): failures.append("Source-local startup/retirement emitted engine errors")
	var report := {"kind":"baseline_native_import_startup_closure","passed":failures.is_empty(),"failures":failures,"engine_errors":errors.messages,
		"actual_player_constructed":player_constructed,"user_data_dir":OS.get_user_data_dir(),"project":ProjectSettings.globalize_path("res://"),
		"headless":true,"rendered_acceptance":false,"gameplay_acceptance":false,"performance_acceptance":false}
	if not destination.is_empty():
		var file := FileAccess.open(destination,FileAccess.WRITE)
		if file!=null: file.store_string(JSON.stringify(report,"\t")+"\n")
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
