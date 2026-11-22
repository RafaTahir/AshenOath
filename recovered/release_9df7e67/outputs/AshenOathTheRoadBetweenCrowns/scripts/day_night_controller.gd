extends Node

signal time_changed(world_time_minutes: float, phase: String, day_count: int)
signal phase_changed(phase: String)

const FULL_DAY_MINUTES := 1440.0
const CYCLE_SECONDS := 2160.0
const START_TIME_MINUTES := 990.0

var world_time_minutes := START_TIME_MINUTES
var day_count := 0
var time_locked := false
var current_phase := "dusk"
var _tick_accumulator := 0.0
const VISUAL_UPDATE_INTERVAL := 0.2

func _ready() -> void:
	current_phase = _phase_for_time(world_time_minutes)

func _process(delta: float) -> void:
	if time_locked or get_tree().paused:
		return
	_tick_accumulator += delta
	if _tick_accumulator < VISUAL_UPDATE_INTERVAL:
		return
	var elapsed := _tick_accumulator
	_tick_accumulator = 0.0
	world_time_minutes += elapsed * FULL_DAY_MINUTES / CYCLE_SECONDS
	while world_time_minutes >= FULL_DAY_MINUTES:
		world_time_minutes -= FULL_DAY_MINUTES
		day_count += 1
	_emit_time()

func set_time(minutes: float, new_day_count: int = -1) -> void:
	world_time_minutes = fposmod(minutes, FULL_DAY_MINUTES)
	if new_day_count >= 0:
		day_count = new_day_count
	_emit_time(true)

func get_time() -> float:
	return world_time_minutes

func set_time_lock(locked: bool) -> void:
	time_locked = locked

func save_state() -> Dictionary:
	return {"world_time_minutes": world_time_minutes, "day_count": day_count}

func load_state(data: Dictionary) -> void:
	set_time(float(data.get("world_time_minutes", START_TIME_MINUTES)), int(data.get("day_count", 0)))

func _emit_time(force_phase: bool = false) -> void:
	var next_phase := _phase_for_time(world_time_minutes)
	if force_phase or next_phase != current_phase:
		current_phase = next_phase
		phase_changed.emit(current_phase)
	time_changed.emit(world_time_minutes, current_phase, day_count)

func _phase_for_time(minutes: float) -> String:
	if minutes >= 330.0 and minutes < 420.0:
		return "dawn"
	if minutes >= 420.0 and minutes < 1110.0:
		return "day"
	if minutes >= 1110.0 and minutes < 1200.0:
		return "dusk"
	return "night"
