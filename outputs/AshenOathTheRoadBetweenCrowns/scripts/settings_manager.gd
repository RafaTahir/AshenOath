extends Node

signal changed(settings: Dictionary)

var settings = {
	"resolution_scale": 0.75,
	"shadow_quality": 0,
	"foliage_density": 1,
	"vsync": true,
	"fullscreen": false,
	"potato_mode": false,
	"target_fps": 60,
	"mouse_sensitivity": 0.003,
	"invert_y": false,
	"master_volume": 0.85
}

func apply() -> void:
	Engine.max_fps = int(settings.get("target_fps", 30))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings["vsync"] else DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED)
	RenderingServer.viewport_set_scaling_3d_scale(get_viewport().get_viewport_rid(), float(settings["resolution_scale"]))
	changed.emit(settings)

func set_potato_mode(enabled: bool) -> void:
	settings["potato_mode"] = enabled
	if enabled:
		settings["resolution_scale"] = 0.55
		settings["shadow_quality"] = 0
		settings["foliage_density"] = 0
		settings["target_fps"] = 30
	else:
		settings["resolution_scale"] = 0.75
		settings["shadow_quality"] = 0
		settings["foliage_density"] = 1
		settings["target_fps"] = 60
	apply()

func cycle_resolution_scale() -> void:
	var values = [0.55, 0.75, 1.0]
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
