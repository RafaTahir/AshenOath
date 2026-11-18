extends SceneTree
## Optional-controller lookup and real weather signal path; no world or saves.
const Everyday = preload("res://scripts/everyday_life.gd")
const Presentation = preload("res://scripts/everyday_world_presentation.gd")
const Clock = preload("res://scripts/day_night_controller.gd")

class HostProbe extends Node:
	var zone_root: Variant
	var world_vfx: Node
	var player: Node3D

class LifeProbe extends Node:
	var story_dirty := false

class WeatherProbe extends Node:
	var notifications: Array[String] = []
	var last_player: Node3D
	func set_weather(weather: String, actor: Node3D) -> void:
		notifications.append(weather)
		last_player = actor

class ErrorLog extends Logger:
	var errors: Array[String] = []
	func _log_error(_function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != Logger.ERROR_TYPE_WARNING:
			errors.append("%s:%d %s %s" % [file, line, code, rationale])

var failures: Array[String] = []
var checks := 0
var error_log := ErrorLog.new()

func _initialize() -> void:
	OS.add_logger(error_log)
	_run.call_deferred()

func _run() -> void:
	var owner := Node.new()
	root.add_child(owner)
	var everyday := Everyday.new()
	everyday.process_mode = Node.PROCESS_MODE_DISABLED
	owner.add_child(everyday)
	_check(everyday.life() == null, "Unbound everyday service must have no controller")
	var host := HostProbe.new()
	owner.add_child(host)
	var player := Node3D.new()
	owner.add_child(player)
	var weather := WeatherProbe.new()
	owner.add_child(weather)
	host.player = player
	host.world_vfx = weather
	everyday.host = host
	var presentation := Presentation.new()
	presentation.process_mode = Node.PROCESS_MODE_DISABLED
	presentation.service = everyday
	presentation.host = host
	owner.add_child(presentation)
	var clock := Clock.new()
	clock.process_mode = Node.PROCESS_MODE_DISABLED
	owner.add_child(clock)
	clock.weather_changed.connect(presentation.weather_changed)
	_check(everyday.life() == null, "Unbound zone root must have no controller")
	_notify(clock, weather, 990.0, 0)
	var former := Node3D.new()
	owner.add_child(former)
	host.zone_root = former
	former.free()
	_check(everyday.life() == null, "Freed zone reference must have no controller")
	_notify(clock, weather, 0.0, 1)
	var zone := Node3D.new()
	zone.name = "ReplacementWorld"
	owner.add_child(zone)
	host.zone_root = zone
	_check(everyday.life() == null, "New world without optional life must return null")
	_notify(clock, weather, 720.0, 1)
	var regional := LifeProbe.new()
	regional.name = "RegionalLifeController"
	zone.add_child(regional)
	_check(everyday.life() == regional, "Regional life lookup changed")
	_notify(clock, weather, 0.0, 0)
	_check(regional.story_dirty, "Weather must still dirty an attached regional controller")
	regional.story_dirty = false
	var greyfen := LifeProbe.new()
	greyfen.name = "GreyfenLifeController"
	zone.add_child(greyfen)
	_check(everyday.life() == greyfen, "Greyfen controller lost its existing priority")
	_notify(clock, weather, 0.0, 1)
	_check(greyfen.story_dirty and not regional.story_dirty, "Weather changed controller priority or dirtied both")
	greyfen.free()
	_check(everyday.life() == regional, "Removing Greyfen life must restore the existing regional fallback")
	_notify(clock, weather, 720.0, 1)
	_check(regional.story_dirty, "Regional controller did not resume receiving weather notifications")
	regional.story_dirty = false
	host.zone_root = null
	_check(everyday.life() == null, "Cleared world ownership must not return the former controller")
	_notify(clock, weather, 990.0, 0)
	_check(not regional.story_dirty, "Cleared world ownership still dirtied the old controller")
	_check(weather.last_player == player, "Nullable life lookup changed the existing weather/player notification")
	var weather_count := weather.notifications.size()
	_check(weather_count == 7, "The seven ownership-state weather notifications were not exercised")
	clock.weather_changed.disconnect(presentation.weather_changed)
	host.free()
	_check(everyday.life() == null, "Released host must not be dereferenced")
	owner.free()
	await process_frame
	if not error_log.errors.is_empty():
		failures.append("Engine errors observed: %d" % error_log.errors.size())
	print("EVERYDAY LIFE ZONE LIVENESS: %s checks=%d weather_notifications=%d engine_errors=%d" % [
		"PASS" if failures.is_empty() else "FAIL", checks, weather_count, error_log.errors.size()])
	quit(0 if failures.is_empty() else 1)

func _notify(clock: Clock, weather: WeatherProbe, minutes: float, day: int) -> void:
	var expected := weather.notifications.size() + 1
	clock.set_time(minutes, day)
	_check(weather.notifications.size() == expected, "Real weather signal stopped while optional world life was unavailable")
	_check(weather.notifications.back() == clock.current_weather, "Weather signal lost its authored value")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)
