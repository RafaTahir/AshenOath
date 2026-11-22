extends "res://tools/verify_perf_001.gd"

const OUTPUT := "D:/Temp/AshenOath/perf_worker_owner_20260928"
var trace_frames: Array[Dictionary] = []
var observed_game: Node
var previous_stage := "bootstrap"
var previous_usec := 0

func _initialize() -> void:
	var hashes: Dictionary = {}
	for path in ["scripts/game.gd", "scripts/visual_director.gd", "scripts/world_material_library.gd", "scripts/audio_manager.gd", "scripts/asset_spawn_helper.gd", "tools/verify_perf_001.gd"]:
		hashes[path] = FileAccess.get_sha256("res://" + path)
	var header := FileAccess.open(OUTPUT + "/header.json", FileAccess.WRITE)
	header.store_string(JSON.stringify({"pid": OS.get_process_id(), "epoch_seconds": Time.get_unix_time_from_system(), "ticks_usec": Time.get_ticks_usec(), "source_hashes": hashes, "scope": "worker/resource/driver ownership diagnostic NOT FPS acceptance", "gpu_timers": "not available through the public GDScript rendering API"}))
	header.close()
	previous_usec = Time.get_ticks_usec()
	process_frame.connect(_trace_frame)
	await super._initialize()

func _trace_frame() -> void:
	if not is_instance_valid(observed_game):
		for child in root.get_children():
			var script: Script = child.get_script()
			if script != null and script.resource_path == "res://scripts/game.gd":
				observed_game = child
				break
	var stage := "bootstrap"
	var resource_status: Dictionary = {}
	if is_instance_valid(observed_game):
		if observed_game.game_started:
			stage = str(observed_game.OPENING_DETAIL_STAGES[observed_game.opening_detail_stage_index]) if observed_game.opening_detail_stage_index < observed_game.OPENING_DETAIL_STAGES.size() else "settled"
		else:
			stage = "menu_preparation"
		if observed_game.asset_helper != null:
			for path in observed_game.asset_helper.pending_role_resources:
				resource_status[path] = ResourceLoader.load_threaded_get_status(path)
	var now := Time.get_ticks_usec()
	trace_frames.append({"epoch_seconds": Time.get_unix_time_from_system(), "ticks_usec": now, "frame_ms": (now - previous_usec) / 1000.0, "stage_before": previous_stage, "stage_after": stage, "pending_resources": resource_status})
	previous_usec = now
	previous_stage = stage

func _write_report() -> void:
	# Keep this diagnostic report isolated; do not overwrite the canonical gate.
	var file := FileAccess.open(OUTPUT + "/frames.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope": "instrumented diagnostic NOT benchmark", "frames": trace_frames, "native_report": report}, "\t"))
	file.close()
