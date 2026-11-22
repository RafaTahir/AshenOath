extends Node

signal changed(settings: Dictionary)

const SETTINGS_PATH := "user://ashen_oath_settings.json"
const DEFAULT_SETTINGS := {
	"quality_preset": "balanced",
	# Native 1280x720 avoids the Intel/ANGLE viewport-scaling performance path.
	"resolution_scale": 1.0,
	"shadow_quality": 0,
	"foliage_density": 1,
	"visual_density": 1,
	"vsync": true,
	"fullscreen": false,
	"potato_mode": false,
	"target_fps": 30,
	"mouse_sensitivity": 0.003,
	"gamepad_look_sensitivity": 1.0,
	"gamepad_deadzone": 0.16,
	"gamepad_invert_x": false,
	"gamepad_invert_y": false,
	"gamepad_vibration": true,
	"gamepad_rumble_strength": 1.0,
	"gamepad_profiles": {},
	"custom_bindings": {},
	"touch_controls": "auto",
	"touch_look_sensitivity": 1.0,
	"invert_y": false,
	"master_volume": 0.85,
	"subtitle_scale": 1.0,
	"camera_shake": 1.0,
	"reduced_motion": false,
	"high_contrast": false,
	"control_preset": "standard",
}

var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)

var _fps_sample_time := 0.0
var _fps_report_time := 0.0
var _fps_samples: Array[float] = []
var _frame_times_ms: Array[float] = []
var _frame_time_cursor := 0
var _frame_time_count := 0
var loaded_user_settings := false
var performance_logging_enabled := OS.get_environment("ASHEN_PERF_LOG") == "1"
const FRAME_TIME_CAPACITY := 600

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	apply()

func _process(delta: float) -> void:
	if delta > 0.0 and delta < 0.25:
		var frame_ms := delta * 1000.0
		if _frame_time_count < FRAME_TIME_CAPACITY:
			_frame_times_ms.append(frame_ms)
			_frame_time_count += 1
		else:
			_frame_times_ms[_frame_time_cursor] = frame_ms
		_frame_time_cursor = (_frame_time_cursor + 1) % FRAME_TIME_CAPACITY
	_fps_sample_time += delta
	_fps_report_time += delta
	if _fps_sample_time >= 1.0:
		_fps_sample_time = 0.0
		_fps_samples.append(float(Engine.get_frames_per_second()))
		if _fps_samples.size() > 30:
			_fps_samples.pop_front()
	if performance_logging_enabled and _fps_report_time >= 10.0 and not _fps_samples.is_empty():
		_fps_report_time = 0.0
		var snapshot = get_performance_snapshot()
		print("PERF: preset=%s fps_avg=%.1f fps_min=%.1f samples=%d" % [snapshot.preset, snapshot.average_fps, snapshot.minimum_fps, snapshot.samples])

func apply() -> void:
	# Let VSync pace the browser/ANGLE renderer. Lower sleep-based caps amplify
	# coarse Windows timer misses on the Dell and can halve the delivered rate.
	Engine.max_fps = 60
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings["vsync"] else DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED)
	RenderingServer.viewport_set_scaling_3d_scale(get_viewport().get_viewport_rid(), float(settings["resolution_scale"]))
	get_viewport().msaa_3d = Viewport.MSAA_2X if str(settings.get("quality_preset", "balanced")) == "quality" else Viewport.MSAA_DISABLED
	_save_settings()
	changed.emit(settings)

func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var raw_settings := file.get_as_text()
	if raw_settings.strip_edges().is_empty():
		# A previously interrupted Web/local write can leave an empty file. Treat
		# it as a first launch and let the next apply() write valid defaults.
		return
	var parser := JSON.new()
	if parser.parse(raw_settings) != OK:
		push_warning("Ignoring invalid Ashen Oath settings; defaults will be restored.")
		return
	var stored = parser.data
	if typeof(stored) != TYPE_DICTIONARY:
		return
	loaded_user_settings = true
	for key in DEFAULT_SETTINGS:
		if stored.has(key) and typeof(stored[key]) == typeof(DEFAULT_SETTINGS[key]):
			settings[key] = stored[key]
	settings["quality_preset"] = str(settings.get("quality_preset", "balanced")).to_lower()
	if settings["quality_preset"] not in ["potato", "balanced", "quality"]:
		settings["quality_preset"] = "balanced"
	settings["mouse_sensitivity"] = clampf(float(settings["mouse_sensitivity"]), 0.0018, 0.0048)
	settings["gamepad_look_sensitivity"] = clampf(float(settings["gamepad_look_sensitivity"]), 0.55, 1.55)
	settings["gamepad_deadzone"] = clampf(float(settings.get("gamepad_deadzone", 0.16)), 0.05, 0.35)
	settings["gamepad_invert_x"] = bool(settings.get("gamepad_invert_x", false))
	settings["gamepad_invert_y"] = bool(settings.get("gamepad_invert_y", false))
	settings["gamepad_rumble_strength"] = clampf(float(settings.get("gamepad_rumble_strength", 1.0)), 0.0, 1.0)
	settings["touch_look_sensitivity"] = clampf(float(settings["touch_look_sensitivity"]), 0.55, 1.55)
	settings["touch_controls"] = str(settings["touch_controls"]).to_lower()
	if settings["touch_controls"] not in ["auto", "on", "off"]:
		settings["touch_controls"] = "auto"
	settings["master_volume"] = clampf(float(settings["master_volume"]), 0.0, 1.0)
	settings["subtitle_scale"] = clampf(float(settings["subtitle_scale"]), 0.9, 1.2)
	settings["camera_shake"] = clampf(float(settings["camera_shake"]), 0.0, 1.0)
	settings["shadow_quality"] = clampi(int(settings["shadow_quality"]), 0, 2)
	settings["potato_mode"] = settings["quality_preset"] == "potato"
	settings["control_preset"] = str(settings.get("control_preset", "standard"))
	if settings["control_preset"] not in ["standard", "left_handed"]:
		settings["control_preset"] = "standard"

func _save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(settings))

func save_now() -> void:
	_save_settings()

func set_potato_mode(enabled: bool) -> void:
	set_quality_preset("potato" if enabled else "balanced")

func apply_platform_defaults(touch_capable: bool) -> void:
	if touch_capable and not loaded_user_settings:
		set_quality_preset("potato")

func set_quality_preset(preset: String) -> void:
	var normalized = preset.to_lower()
	if normalized not in ["potato", "balanced", "quality"]:
		normalized = "balanced"
	settings["quality_preset"] = normalized
	settings["potato_mode"] = normalized == "potato"
	match normalized:
		"potato":
			settings["resolution_scale"] = 1.0
			settings["shadow_quality"] = 0
			settings["foliage_density"] = 0
			settings["visual_density"] = 0
			settings["target_fps"] = 30
		"quality":
			settings["resolution_scale"] = 1.0
			settings["shadow_quality"] = 1
			settings["foliage_density"] = 2
			settings["visual_density"] = 2
			settings["target_fps"] = 30
		_:
			settings["resolution_scale"] = 1.0
			# Balanced keeps native 720p and authored contact grounding without
			# redrawing the dense village in a directional shadow pass.
			settings["shadow_quality"] = 0
			settings["foliage_density"] = 1
			settings["visual_density"] = 1
			settings["target_fps"] = 30
	apply()

func cycle_quality_preset() -> String:
	var values = ["potato", "balanced", "quality"]
	var current = str(settings.get("quality_preset", "balanced"))
	var idx = values.find(current)
	set_quality_preset(values[(idx + 1) % values.size()])
	return str(settings["quality_preset"])

func get_performance_snapshot() -> Dictionary:
	var average := 0.0
	var minimum := 0.0
	var one_percent_low := 0.0
	if not _fps_samples.is_empty():
		minimum = _fps_samples[0]
		for sample in _fps_samples:
			average += sample
			minimum = min(minimum, sample)
		average /= float(_fps_samples.size())
	if not _frame_times_ms.is_empty():
		var sorted_times := _frame_times_ms.slice(0, _frame_time_count)
		sorted_times.sort()
		var slow_count := maxi(1, ceili(float(sorted_times.size()) * 0.01))
		var slow_total := 0.0
		for index in range(sorted_times.size() - slow_count, sorted_times.size()):
			slow_total += float(sorted_times[index])
		one_percent_low = 1000.0 / maxf(slow_total / float(slow_count), 0.001)
	return {
		"preset": str(settings.get("quality_preset", "balanced")),
		"average_fps": average,
		"minimum_fps": minimum,
		"one_percent_low_fps": one_percent_low,
		"samples": _fps_samples.size(),
		"frame_samples": _frame_times_ms.size(),
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"static_memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
	}

func cycle_resolution_scale() -> void:
	settings["resolution_scale"] = 1.0
	apply()

func cycle_shadows() -> void:
	settings["shadow_quality"] = (int(settings["shadow_quality"]) + 1) % 3
	apply()

func toggle_vsync() -> void:
	settings["vsync"] = not bool(settings["vsync"])
	apply()

func toggle_fullscreen() -> void:
	settings["fullscreen"] = not bool(settings["fullscreen"])
	apply()

func cycle_mouse_sensitivity() -> void:
	var values = [0.0018, 0.0024, 0.003, 0.0038, 0.0048]
	var idx = values.find(float(settings["mouse_sensitivity"]))
	if idx < 0:
		idx = 2
	settings["mouse_sensitivity"] = values[(idx + 1) % values.size()]
	apply()

func cycle_gamepad_look_sensitivity() -> void:
	var values := [0.65, 1.0, 1.35]
	var current := float(settings.get("gamepad_look_sensitivity", 1.0))
	var idx := values.find(current)
	settings["gamepad_look_sensitivity"] = values[(idx + 1) % values.size()]
	apply()

func toggle_gamepad_vibration() -> void:
	settings["gamepad_vibration"] = not bool(settings.get("gamepad_vibration", true))
	apply()

func cycle_gamepad_deadzone() -> void:
	settings["gamepad_deadzone"] = _cycle_float(float(settings.get("gamepad_deadzone", 0.16)), [0.08, 0.12, 0.16, 0.22, 0.30])
	apply()

func toggle_gamepad_invert_x() -> void:
	settings["gamepad_invert_x"] = not bool(settings.get("gamepad_invert_x", false))
	apply()

func toggle_gamepad_invert_y() -> void:
	settings["gamepad_invert_y"] = not bool(settings.get("gamepad_invert_y", false))
	apply()

func cycle_gamepad_rumble_strength() -> void:
	settings["gamepad_rumble_strength"] = _cycle_float(float(settings.get("gamepad_rumble_strength", 1.0)), [0.0, 0.35, 0.65, 1.0])
	apply()

func cycle_touch_controls() -> void:
	var values := ["auto", "on", "off"]
	var current := str(settings.get("touch_controls", "auto"))
	var index := values.find(current)
	settings["touch_controls"] = values[(index + 1) % values.size()]
	apply()

func cycle_touch_look_sensitivity() -> void:
	var values := [0.65, 1.0, 1.35]
	var current := float(settings.get("touch_look_sensitivity", 1.0))
	var index := values.find(current)
	settings["touch_look_sensitivity"] = values[(index + 1) % values.size()]
	apply()

func toggle_invert_y() -> void:
	settings["invert_y"] = not bool(settings["invert_y"])
	apply()

func cycle_master_volume() -> void:
	var values = [0.0, 0.35, 0.6, 0.85, 1.0]
	var idx = values.find(float(settings["master_volume"]))
	if idx < 0:
		idx = 3
	settings["master_volume"] = values[(idx + 1) % values.size()]
	apply()

func cycle_subtitle_scale() -> void:
	settings["subtitle_scale"] = _cycle_float(float(settings["subtitle_scale"]), [0.9, 1.0, 1.2])
	apply()

func cycle_camera_shake() -> void:
	settings["camera_shake"] = _cycle_float(float(settings["camera_shake"]), [0.0, 0.5, 1.0])
	apply()

func toggle_reduced_motion() -> void:
	settings["reduced_motion"] = not bool(settings["reduced_motion"])
	apply()

func toggle_high_contrast() -> void:
	settings["high_contrast"] = not bool(settings.get("high_contrast", false))
	apply()

func cycle_control_preset() -> void:
	settings["control_preset"] = "left_handed" if str(settings.get("control_preset", "standard")) == "standard" else "standard"
	apply()

func _cycle_float(current: float, values: Array) -> float:
	var index := values.find(current)
	return float(values[(index + 1) % values.size()])
