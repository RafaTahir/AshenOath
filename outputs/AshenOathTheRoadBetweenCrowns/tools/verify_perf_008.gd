extends SceneTree

const SettingsManager = preload("res://scripts/settings_manager.gd")
const PerformanceBudgetMonitor = preload("res://scripts/performance_budget_monitor.gd")

var failures := 0

func _initialize() -> void:
	var settings := SettingsManager.new()
	root.add_child(settings)
	await process_frame
	for preset in ["potato", "balanced", "quality"]:
		settings.set_quality_preset(preset)
		check(is_equal_approx(float(settings.settings.resolution_scale), 1.0), "%s changed native render scale" % preset)
		check(int(settings.settings.target_fps) == 30, "%s lost the 30 FPS gameplay target" % preset)
		check(settings.get_performance_snapshot().has("one_percent_low_fps"), "%s has no 1%% low telemetry" % preset)
	settings.set_quality_preset("balanced")
	check(int(settings.settings.foliage_density) == 1, "Balanced foliage budget is not deterministic")
	check(int(settings.settings.visual_density) == 1, "Balanced visual budget is not deterministic")
	settings.set_quality_preset("potato")
	check(int(settings.settings.foliage_density) == 0, "Potato foliage budget is not reduced")
	check(int(settings.settings.shadow_quality) == 0, "Potato shadow budget is not reduced")
	var monitor := PerformanceBudgetMonitor.new()
	root.add_child(monitor)
	monitor.configure(null)
	check(monitor.has_method("set_active_zone"), "Performance monitor has no zone binding contract")
	check(monitor.has_method("record_transition"), "Performance monitor has no transition timing contract")
	check(monitor.has_method("get_snapshot"), "Performance monitor has no report snapshot")
	var snapshot := monitor.get_snapshot()
	check(snapshot.has("sample_count") and snapshot.has("budget_violations"), "Performance monitor snapshot is incomplete")
	monitor.queue_free()
	print("PERF-008 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
