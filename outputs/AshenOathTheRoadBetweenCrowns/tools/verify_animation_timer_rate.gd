extends SceneTree

class Driver extends "res://scripts/character_animation_driver.gd":
	var ticks: Array[float] = []
	func _advance_animation(delta: float) -> void:
		ticks.append(delta)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var actor := Node3D.new()
	root.add_child(actor)
	var driver := Driver.new()
	actor.add_child(driver)
	driver.character_root = actor
	driver.set_update_rate_hz(10.0)
	driver.manual_tick_timer.start(0.02)
	await create_timer(0.36).timeout
	var passed := driver.ticks.size() >= 3 and driver.ticks.size() <= 5
	passed = passed and is_equal_approx(driver.manual_tick_timer.wait_time, 0.1)
	passed = passed and is_equal_approx(driver.ticks[0], 0.02)
	for index in range(1, driver.ticks.size()):
		passed = passed and is_equal_approx(driver.ticks[index], 0.1)
	print("ANIMATION TIMER TICKS: " + str(driver.ticks))
	driver.set_distance_suspended(true)
	var count := driver.ticks.size()
	await create_timer(0.15).timeout
	passed = passed and driver.ticks.size() == count
	driver.set_distance_suspended(false)
	await create_timer(0.22).timeout
	passed = passed and driver.ticks.size() >= count + 1 and driver.ticks.size() <= count + 3
	driver.set_external_tick(true)
	count = driver.ticks.size()
	await create_timer(0.15).timeout
	passed = passed and driver.ticks.size() == count
	actor.queue_free()
	await process_frame
	print("ANIMATION TIMER RATE: %s - stagger, cadence, suspend/resume and external ownership" % ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
