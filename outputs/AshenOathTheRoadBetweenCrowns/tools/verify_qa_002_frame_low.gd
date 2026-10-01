extends SceneTree

const Observer = preload("res://scripts/production_observation_bridge.gd")
const QAObserver = preload("res://scripts/qa_browser_telemetry.gd")

func _initialize() -> void:
	var frames: Array[float] = []
	for index in range(198):
		frames.append(1.0 / 60.0)
	frames.append(0.05)
	frames.append(0.10)
	for observer_script in [Observer, QAObserver]:
		var observer: Node = observer_script.new()
		root.add_child(observer)
		observer.set("_frame_times", frames)
		var performance: Dictionary = observer.call("_performance_state")
		if absf(float(performance.one_percent_low_fps) - 13.333333) > 0.01:
			push_error("Browser 1%% low must average the two slowest of 200 frames: %s" % str(performance))
			quit(1)
			return
		observer.queue_free()
	var production: Node = Observer.new()
	root.add_child(production)
	for index in range(120):
		production.call("_record_frame", 1.0 / 60.0, "greyfen", true)
	var greyfen: Dictionary = production.call("_performance_state")
	if greyfen.zone != "greyfen" or int(greyfen.samples) != 120:
		push_error("Greyfen performance window was not recorded: %s" % str(greyfen))
		quit(1)
		return
	production.call("_record_frame", 0.1, "wychwood", true)
	var wychwood: Dictionary = production.call("_performance_state")
	if wychwood.zone != "wychwood" or int(wychwood.samples) != 1:
		push_error("Zone change retained the previous performance window: %s" % str(wychwood))
		quit(1)
		return
	production.call("_record_frame", 0.01, "wychwood", false)
	var paused: Dictionary = production.call("_performance_state")
	if paused.zone != "" or int(paused.samples) != 0:
		push_error("Paused gameplay retained a stale performance window: %s" % str(paused))
		quit(1)
		return
	production.queue_free()
	print("QA-002 FRAME LOW: PASS")
	quit(0)
