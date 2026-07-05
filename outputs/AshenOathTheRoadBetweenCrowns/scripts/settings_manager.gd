extends Node

signal changed(settings: Dictionary)

var settings = {
	"quality_preset": "balanced",
	"resolution_scale": 1.0,
	"shadow_quality": 1,
	"foliage_density": 1,
	"visual_density": 1,
	"vsync": true,
	"fullscreen": false,
	"potato_mode": false,
	"target_fps": 30,
	"mouse_sensitivity": 0.003,
	"invert_y": false,
	"master_volume": 0.85
}

var _fps_sample_time := 0.0
var _fps_report_time := 0.0
var _fps_samples: Array[float] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	_fps_sample_time += delta
	_fps_report_time += delta
	if _fps_sample_time >= 1.0:
		_fps_sample_time = 0.0
		_fps_samples.append(float(Engine.get_frames_per_second()))
		if _fps_samples.size() > 30:
			_fps_samples.pop_front()
	if _fps_report_time >= 10.0 and not _fps_samples.is_empty():
		_fps_report_time = 0.0
		var snapshot = get_performance_snapshot()
		print("PERF: preset=%s fps_avg=%.1f fps_min=%.1f samples=%d" % [snapshot.preset, snapshot.average_fps, snapshot.minimum_fps, snapshot.samples])

func apply() -> void:
	Engine.max_fps = int(settings.get("target_fps", 30))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings["vsync"] else DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED)
	RenderingServer.viewport_set_scaling_3d_scale(get_viewport().get_viewport_rid(), float(settings["resolution_scale"]))
	get_viewport().msaa_3d = Viewport.MSAA_2X if str(settings.get("quality_preset", "balanced")) == "quality" else Viewport.MSAA_DISABLED
	changed.emit(settings)

func set_potato_mode(enabled: bool) -> void:
	set_quality_preset("potato" if enabled else "balanced")

func set_quality_preset(preset: String) -> void:
	var normalized = preset.to_lower()
	if normalized not in ["potato", "balanced", "quality"]:
		normalized = "balanced"
	settings["quality_preset"] = normalized
	settings["potato_mode"] = normalized == "potato"
	match normalized:
		"potato":
			settings["resolution_scale"] = 0.65
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
			settings["shadow_quality"] = 1
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
	if not _fps_samples.is_empty():
		minimum = _fps_samples[0]
		for sample in _fps_samples:
			average += sample
			minimum = min(minimum, sample)
		average /= float(_fps_samples.size())
	return {
		"preset": str(settings.get("quality_preset", "balanced")),
		"average_fps": average,
		"minimum_fps": minimum,
		"samples": _fps_samples.size(),
	}

func cycle_resolution_scale() -> void:
	var values = [0.65, 0.85, 1.0]
	var idx = values.find(float(settings["resolution_scale"]))
	settings["resolution_scale"] = values[(idx + 1) % values.size()]
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
