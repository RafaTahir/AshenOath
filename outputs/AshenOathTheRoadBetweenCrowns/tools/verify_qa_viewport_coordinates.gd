extends SceneTree
## Headless QA geometry only; no world, resources, input dispatch or save access.
const Coordinates = preload("res://tools/qa_viewport_coordinates.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	var logical := Vector2(1280, 720)
	var desktop := Vector2(1280, 720)
	var touch := Vector2(960, 540)
	_check(bool(Coordinates.contract(logical, desktop).valid), "Desktop dimensions supported")
	_check(bool(Coordinates.contract(logical, touch).valid), "Touch client preserves production logical canvas")
	_check(Coordinates.logical_to_window(Vector2(640, 360), logical, desktop) == Vector2(640, 360), "Desktop input unchanged")
	_check(Coordinates.logical_to_window(Vector2(640, 360), logical, touch) == Vector2(480, 270), "Touch GUI center maps to client pixels")
	_check(Coordinates.logical_to_window(Vector2(1120, 592), logical, touch) == Vector2(840, 444), "Touch action target maps to client pixels")
	_check(Coordinates.logical_delta_to_window(Vector2(-120, 32), logical, touch) == Vector2(-90, 24), "Touch drag relative and screen_relative are physical")
	_check(Coordinates.logical_to_window(Vector2(1280, 720), logical, touch) == touch, "Viewport edge maps to client edge")
	_check(not bool(Coordinates.contract(Vector2.ZERO, touch).valid), "Zero logical size fails closed")
	_check(not bool(Coordinates.contract(logical, Vector2(-1, 540)).valid), "Negative physical size fails closed")
	_check(not bool(Coordinates.contract(logical, Vector2(960, 600)).valid), "Arbitrary letterboxing fails closed")
	_check(not bool(Coordinates.contract(Vector2(NAN, 720), touch).valid), "Nonfinite size fails closed")
	_check(not Coordinates.logical_to_window(Vector2(INF, 1), logical, touch).is_finite(), "Nonfinite point fails closed")
	_check(not Coordinates.logical_delta_to_window(Vector2.ONE, logical, Vector2.ZERO).is_finite(), "Invalid drag dimensions fail closed")
	print(JSON.stringify({"kind":"qa_logical_to_client_coordinates", "checks":checks,
		"passed":failures.is_empty(), "failures":failures, "world_loaded":false,
		"real_input_acceptance":false, "physical_phone":false}))
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
