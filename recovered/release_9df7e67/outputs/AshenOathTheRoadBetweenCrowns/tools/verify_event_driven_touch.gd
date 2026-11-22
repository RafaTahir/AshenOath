extends SceneTree

const Touch = preload("res://scripts/mobile_touch_controls.gd")
const Router = preload("res://scripts/input_router.gd")

class FakeHud extends CanvasLayer:
	var menu_layer := Control.new()
	var dialogue_layer := Control.new()
	var inventory_layer := Control.new()
	func _ready() -> void:
		add_child(menu_layer)
		add_child(dialogue_layer)
		add_child(inventory_layer)
		dialogue_layer.hide()
		inventory_layer.hide()
	func set_input_device(_device: String) -> void:
		pass

class PolledTouch extends Touch:
	func _process(_delta: float) -> void:
		var should_show := is_gameplay_visible()
		if visible != should_show:
			visible = should_show
			if not visible:
				_release_all()
			elif not _announced:
				input_router.activate_touch()
				_announced = true
				print("MOBILE_TOUCH: ready landscape=%s viewport=%s" % [not rotate_required, get_viewport_rect().size])
		_update_layout()

class MeasuredTouch extends Touch:
	var layout_calls := 0
	var process_calls := 0
	func _update_layout() -> void:
		layout_calls += 1
		super._update_layout()
	func _process(delta: float) -> void:
		process_calls += 1
		super._process(delta)

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var router := Router.new()
	root.add_child(router)
	router.install_default_actions()
	var hud := FakeHud.new()
	root.add_child(hud)
	var touch := MeasuredTouch.new()
	root.add_child(touch)
	touch.setup(router, hud, {"touch_controls": "on"})
	await _frames(3)
	_check(not touch.visible and not touch.is_processing(), "Menu touch state was not event-driven")
	hud.menu_layer.hide()
	await _frames(3)
	_check(touch.visible, "Closing menu did not show touch controls")
	var before := touch.layout_calls
	await _frames(40)
	_check(touch.layout_calls == before and touch.process_calls == 0, "Unchanged frames rebuilt or polled touch layout")
	var expected := touch.get_layout_snapshot()
	var old_script = PolledTouch
	if old_script != null:
		var baseline = PolledTouch.new()
		root.add_child(baseline)
		baseline.setup(router, hud, {"touch_controls": "on"})
		baseline.set_process(false)
		await _frames(2)
		var baseline_layout: Dictionary = baseline.get_layout_snapshot()
		_check(expected.actions == baseline_layout.actions and expected.radii == baseline_layout.radii, "Event layout differs from the retained original")
		var elapsed: Array[int] = []
		for _round in range(3):
			var started := Time.get_ticks_usec()
			for _index in range(6000):
				baseline._process(1.0 / 60.0)
			elapsed.append(Time.get_ticks_usec() - started)
		print("ARCH-002 TOUCH COST: old 6000 idle callbacks us=%s; new 40 actual idle frames: process=%d layout_delta=%d" % [elapsed, touch.process_calls, touch.layout_calls - before])
		baseline.queue_free()
	touch._begin_touch(2, touch._move_center() + Vector2(0, -65))
	_check(router.movement_vector().length() > 0.5, "Movement control did not respond")
	paused = true
	hud.dialogue_layer.show()
	await _frames(3)
	_check(not touch.visible and router.movement_vector().is_zero_approx(), "Paused dialogue retained touch movement")
	paused = false
	hud.dialogue_layer.hide()
	await _frames(3)
	_check(touch.visible, "Closing dialogue did not restore touch controls")
	hud.inventory_layer.show()
	await _frames(3)
	_check(not touch.visible, "Inventory did not hide touch controls")
	hud.inventory_layer.hide()
	await _frames(3)
	touch._begin_touch(4, touch._move_center() + Vector2(0, -65))
	router.set_ui_context("minigame")
	paused = true
	await _frames(3)
	_check(not touch.visible and router.movement_vector().is_zero_approx(), "Minigame context retained touch movement")
	paused = false
	router.set_gameplay_context()
	await _frames(3)
	_check(touch.visible, "Minigame close did not restore touch controls")
	touch.apply_settings({"touch_controls": "off"})
	await _frames(3)
	_check(not touch.visible, "Disabling touch left controls visible")
	touch.apply_settings({"touch_controls": "on"})
	await _frames(3)
	touch._begin_touch(3, touch._move_center() + Vector2(0, -65))
	root.size = Vector2i(720, 1280)
	await _frames(4)
	_check(touch.rotate_required and router.movement_vector().is_zero_approx(), "Portrait resize retained movement or stale landscape layout")
	root.size = Vector2i(1920, 1080)
	await _frames(4)
	_check(not touch.rotate_required and touch.get_layout_snapshot().viewport == Vector2(1920, 1080), "1080p resize did not update geometry")
	touch._release_all()
	touch.queue_free()
	hud.queue_free()
	router.queue_free()
	await _frames(3)
	print("EVENT DRIVEN TOUCH: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
