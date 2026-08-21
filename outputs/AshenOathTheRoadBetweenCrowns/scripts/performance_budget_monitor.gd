extends Node
class_name PerformanceBudgetMonitor

const ZoneBudget = preload("res://scripts/zone_budget.gd")

signal snapshot_updated(snapshot: Dictionary)

const FRAME_SAMPLE_CAPACITY := 600
const SNAPSHOT_INTERVAL := 0.50
const WARMUP_SAMPLE_COUNT := 30

var host: Node
var active_zone := ""
var active_root: Node
var player: Node3D
var quality := "balanced"
var suspended := true
var snapshot: Dictionary = {}
var frame_times_ms: Array[float] = []
var frame_time_cursor := 0
var sample_accumulator := 0.0
var snapshot_accumulator := 0.0
var transition_ms := -1.0
var zone_started_usec := 0
var zone_budget_snapshot: Dictionary = {}
var budget_violations: Array[String] = []

func configure(runtime_host: Node) -> void:
	host = runtime_host
	process_mode = Node.PROCESS_MODE_ALWAYS
	clear()

func set_active_zone(zone_id: String, root: Node, target: Node3D, quality_preset: String) -> void:
	active_zone = zone_id.strip_edges().to_lower()
	active_root = root
	player = target
	quality = quality_preset if quality_preset in ["potato", "balanced", "quality"] else "balanced"
	suspended = active_root == null or not is_instance_valid(active_root)
	frame_times_ms.clear()
	frame_time_cursor = 0
	sample_accumulator = 0.0
	snapshot_accumulator = 0.0
	transition_ms = -1.0
	zone_started_usec = Time.get_ticks_usec()
	zone_budget_snapshot = {}
	budget_violations.clear()
	snapshot = _empty_snapshot()
	snapshot["active_zone"] = active_zone
	snapshot["quality"] = quality
	snapshot["suspended"] = suspended

func suspend() -> void:
	suspended = true
	active_root = null
	player = null
	snapshot["suspended"] = true

func clear() -> void:
	active_zone = ""
	active_root = null
	player = null
	suspended = true
	frame_times_ms.clear()
	frame_time_cursor = 0
	sample_accumulator = 0.0
	snapshot_accumulator = 0.0
	transition_ms = -1.0
	zone_started_usec = 0
	zone_budget_snapshot = {}
	budget_violations.clear()
	snapshot = _empty_snapshot()
	snapshot["quality"] = quality

func _empty_snapshot() -> Dictionary:
	return {
		"active_zone": "",
		"quality": "balanced",
		"sample_count": 0,
		"warm": false,
		"suspended": true,
		"average_fps": 0.0,
		"minimum_fps": 0.0,
		"one_percent_low_fps": 0.0,
		"frame_time_ms": 0.0,
		"transition_ms": -1.0,
		"static_memory_bytes": 0,
		"draw_calls": 0,
		"primitives": 0,
		"zone_budget": {},
		"budget_violations": [],
		"elapsed_ms": 0.0,
	}

func record_transition(elapsed_ms: float) -> void:
	transition_ms = maxf(elapsed_ms, 0.0)
	_update_snapshot(true)

func _process(delta: float) -> void:
	if suspended or get_tree().paused or active_root == null or not is_instance_valid(active_root):
		return
	if delta <= 0.0 or delta >= 0.25:
		return
	var frame_ms := delta * 1000.0
	if frame_times_ms.size() < FRAME_SAMPLE_CAPACITY:
		frame_times_ms.append(frame_ms)
	else:
		frame_times_ms[frame_time_cursor] = frame_ms
	frame_time_cursor = (frame_time_cursor + 1) % FRAME_SAMPLE_CAPACITY
	sample_accumulator += delta
	snapshot_accumulator += delta
	if snapshot_accumulator >= SNAPSHOT_INTERVAL:
		snapshot_accumulator = 0.0
		_update_snapshot(false)

func get_snapshot() -> Dictionary:
	return snapshot.duplicate(true)

func refresh_budget_snapshot() -> Dictionary:
	# This recursive walk is intentionally explicit. It is useful for release
	# reports and lifecycle tests, but never runs on the gameplay frame loop.
	if suspended or active_root == null or not is_instance_valid(active_root):
		zone_budget_snapshot = {}
		budget_violations.clear()
		return {}
	zone_budget_snapshot = ZoneBudget.capture(active_root)
	budget_violations = ZoneBudget.violations(zone_budget_snapshot)
	_update_snapshot(true)
	return zone_budget_snapshot.duplicate(true)

func _update_snapshot(force: bool) -> void:
	if suspended or active_root == null or not is_instance_valid(active_root):
		snapshot["suspended"] = true
		return
	var frame_stats := _frame_stats()
	var memory_bytes := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	snapshot = {
		"active_zone": active_zone,
		"quality": quality,
		"sample_count": frame_times_ms.size(),
		"warm": frame_times_ms.size() >= WARMUP_SAMPLE_COUNT,
		"suspended": false,
		"average_fps": frame_stats.average_fps,
		"minimum_fps": frame_stats.minimum_fps,
		"one_percent_low_fps": frame_stats.one_percent_low_fps,
		"frame_time_ms": frame_stats.average_frame_ms,
		"transition_ms": transition_ms,
		"static_memory_bytes": memory_bytes,
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"zone_budget": zone_budget_snapshot.duplicate(true),
		"budget_violations": budget_violations.duplicate(),
		"elapsed_ms": float(Time.get_ticks_usec() - zone_started_usec) / 1000.0 if zone_started_usec > 0 else 0.0,
	}
	if force or frame_times_ms.size() >= WARMUP_SAMPLE_COUNT:
		snapshot_updated.emit(snapshot.duplicate(true))

func _frame_stats() -> Dictionary:
	if frame_times_ms.is_empty():
		return {"average_fps": 0.0, "minimum_fps": 0.0, "one_percent_low_fps": 0.0, "average_frame_ms": 0.0}
	var total_ms := 0.0
	var minimum_fps := INF
	for frame_ms in frame_times_ms:
		total_ms += frame_ms
		minimum_fps = minf(minimum_fps, 1000.0 / maxf(frame_ms, 0.001))
	var sorted_times: Array = frame_times_ms.duplicate()
	sorted_times.sort()
	var slow_count := maxi(1, ceili(float(sorted_times.size()) * 0.01))
	var slow_total := 0.0
	for index in range(sorted_times.size() - slow_count, sorted_times.size()):
		slow_total += float(sorted_times[index])
	var average_ms := total_ms / float(frame_times_ms.size())
	return {
		"average_fps": 1000.0 / maxf(average_ms, 0.001),
		"minimum_fps": minimum_fps if minimum_fps != INF else 0.0,
		"one_percent_low_fps": 1000.0 / maxf(slow_total / float(slow_count), 0.001),
		"average_frame_ms": average_ms,
	}
