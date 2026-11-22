extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	_check(scene != null, "main scene is missing")
	if scene == null:
		await _finish()
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	var touch = game.runtime_services.get_service("mobile_touch")
	var router = game.input_router
	_check(touch != null, "mobile touch service is missing")
	_check(router != null, "input router is missing")
	if touch == null or router == null:
		await _finish(game)
		return

	_verify_settings(game.settings)
	_verify_export_contract()
	touch.set_force_touch_for_test(true)
	game.call("_new_game")
	await _settle(8)
	_check(not touch.is_processing(), "Touch layout still polls idle frames")
	_check(touch.visible, "touch controls are not visible during gameplay")
	_check(not touch.rotate_required, "native 1280x720 landscape incorrectly requires rotation")
	_verify_layout(touch.get_layout_snapshot())
	_verify_touch_input(touch, router)
	await _verify_touch_hud(game.hud, router)

	game.hud.show_pause_menu()
	await _settle(2)
	_check(not touch.visible, "touch controls remain over the pause menu")
	game.hud.hide_menus()
	await _settle(2)
	_check(touch.visible, "touch controls do not return after closing menus")
	touch._begin_touch(30, touch._move_center() + Vector2(0, -68))
	game.minigames.open_game("tic_tac_toe")
	await _settle(2)
	_check(not touch.visible and router.movement_vector().is_zero_approx(), "Minigame retained touch controls or movement")
	game.minigames.close_game()
	await _settle(2)
	_check(touch.visible, "Touch controls did not return after minigame close")

	touch._release_all()
	await _finish(game)

func _verify_settings(settings: Node) -> void:
	_check(settings.settings.has("touch_controls"), "touch visibility mode is not persisted")
	_check(settings.settings.has("touch_look_sensitivity"), "touch look sensitivity is not persisted")
	var original_mode := str(settings.settings["touch_controls"])
	settings.cycle_touch_controls()
	_check(str(settings.settings["touch_controls"]) != original_mode, "touch visibility mode cannot be changed")
	var original_sensitivity := float(settings.settings["touch_look_sensitivity"])
	settings.cycle_touch_look_sensitivity()
	_check(not is_equal_approx(float(settings.settings["touch_look_sensitivity"]), original_sensitivity), "touch look sensitivity cannot be changed")

func _verify_export_contract() -> void:
	var registry := FileAccess.get_file_as_string("res://scripts/runtime_service_registry.gd")
	var preset := FileAccess.get_file_as_string("res://export_presets.cfg")
	_check(registry.contains("mobile_touch_controls.gd"), "runtime registry does not preload touch controls")
	_check(preset.contains("runtime_service_registry.gd"), "Web preset does not include the runtime service registry")
	_check(preset.contains("html/canvas_resize_policy=2"), "Web canvas is not configured for responsive resize")
	_check(not preset.contains("thread_support=true"), "mobile Web candidate unexpectedly enables threads")

func _verify_layout(snapshot: Dictionary) -> void:
	var viewport: Vector2 = snapshot["viewport"]
	var centers: Dictionary = snapshot["actions"]
	var radii: Dictionary = snapshot["radii"]
	var required := [
		"light_attack", "heavy_attack", "dodge", "block", "oathfire_beam",
		"interact", "jump", "use_potion", "throw_bomb", "open_inventory", "pause",
	]
	for action in required:
		_check(centers.has(action), "touch layout is missing %s" % action)
	for action in centers:
		var center: Vector2 = centers[action]
		var radius: float = float(radii[action])
		_check(center.x - radius >= 0.0 and center.y - radius >= 0.0, "%s exceeds the top/left safe area" % action)
		_check(center.x + radius <= viewport.x and center.y + radius <= viewport.y, "%s exceeds the bottom/right safe area" % action)
	var move_center: Vector2 = snapshot["move_center"]
	_check(move_center.x < viewport.x * 0.30 and move_center.y > viewport.y * 0.62, "movement stick is not in the lower-left thumb zone")
	for action in centers:
		_check(move_center.distance_to(Vector2(centers[action])) > 145.0, "%s overlaps the movement stick" % action)

func _verify_touch_input(touch: Control, router: Node) -> void:
	var snapshot: Dictionary = touch.get_layout_snapshot()
	var centers: Dictionary = snapshot["actions"]
	touch._begin_touch(10, touch._move_center() + Vector2(0.0, -68.0))
	_check(router.active_device == "touch", "touch movement did not select touch input")
	_check(router.movement_vector().y < -0.75, "touch movement stick did not produce forward movement")
	_check(router.is_action_pressed("run"), "full touch-stick travel does not enable run")
	touch._end_touch(10)
	_check(router.movement_vector() == Vector2.ZERO, "touch movement remained stuck after release")

	touch._begin_touch(11, Vector2(700.0, 260.0))
	touch._drag_touch(11, Vector2(735.0, 245.0))
	_check(router.look_vector().length() > 0.20, "touch look drag did not reach the camera input")
	touch._end_touch(11)
	_check(router.look_vector() == Vector2.ZERO, "touch look remained stuck after release")

	for test_action in ["light_attack", "block", "oathfire_beam", "interact", "pause"]:
		touch._begin_touch(20, Vector2(centers[test_action]))
		_check(Input.is_action_pressed(test_action), "%s touch button did not press its semantic action" % test_action)
		touch._end_touch(20)
		_check(not Input.is_action_pressed(test_action), "%s touch button remained stuck after release" % test_action)

func _verify_touch_hud(hud: Node, router: Node) -> void:
	router._set_device("touch")
	hud.set_input_device("touch")
	hud.set_prompt("E - Speak to Sister Anwen")
	_check(hud.prompt_label.text.begins_with("[Use]"), "interaction prompt did not switch to touch")
	hud.set_guidance_hint("Left click strike | Space dodge | Tap Q parry | Hold C Oathfire", 5.0)
	_check(hud.hint_label.text.contains("[Strike]") and hud.hint_label.text.contains("[Dodge]") and hud.hint_label.text.contains("[Guard]") and hud.hint_label.text.contains("[Oath]"), "combat guidance did not switch to touch")
	hud.update_equipment(2, 1, "Moon Oil")
	_check(hud.equipment_label.text.contains("[Potion]") and hud.equipment_label.text.contains("[Bomb]"), "equipment shortcuts did not switch to touch")
	hud.show_controls_menu("main")
	await process_frame
	var text := ""
	for label in hud.menu_layer.find_children("*", "Label", true, false):
		text += str(label.text) + "\n"
	_check(text.contains("Left thumb move") and text.to_lower().contains("landscape"), "controls screen lacks the touch layout")
	hud.hide_menus()

func _settle(frames: int) -> void:
	for _index in range(frames):
		await process_frame
		await physics_frame

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("MOBILE-001: %s" % message)


func _finish(game: Node = null) -> void:
	var result_code := 0 if failures.is_empty() else 1
	if game != null and is_instance_valid(game) and game.has_method("prepare_resource_shutdown"):
		game.prepare_resource_shutdown()
	await _settle(20)
	if game != null and is_instance_valid(game) and game.has_method("finalize_resource_shutdown"):
		game.finalize_resource_shutdown()
	await _settle(12)
	print("VERIFIER_PHASE: SHUTDOWN")
	if game != null and is_instance_valid(game) and game.is_inside_tree():
		root.remove_child(game)
	if game != null and is_instance_valid(game):
		game.free()
	RenderingServer.force_sync()
	await _settle(8)
	RenderingServer.force_sync()
	if failures.is_empty():
		print("MOBILE-001 VERIFIER: PASS (touch layout, actions, prompts, settings, menu safety)")
	else:
		print("MOBILE-001 VERIFIER: FAIL (%d)" % failures.size())
	quit(result_code)
