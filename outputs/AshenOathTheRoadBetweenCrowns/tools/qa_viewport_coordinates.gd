extends RefCounted
## QA only: native Input.parse_input_event positions start in window pixels.
## These fixtures require equal-aspect logical/client rectangles, no letterbox.

static func contract(logical_size: Vector2, physical_size: Vector2) -> Dictionary:
	var valid := logical_size.is_finite() and physical_size.is_finite() and logical_size.x > 0.0 and logical_size.y > 0.0 and physical_size.x > 0.0 and physical_size.y > 0.0
	var ratio := physical_size / logical_size if valid else Vector2.ZERO
	valid = valid and is_equal_approx(ratio.x, ratio.y)
	return {"valid":valid, "logical_size":[logical_size.x, logical_size.y],
		"window_client_size":[physical_size.x, physical_size.y],
		"logical_to_window_scale":[ratio.x, ratio.y],
		"policy":"production_internal_canvas_with_native_window_stretch", "physical_phone":false}

static func logical_to_window(point: Vector2, logical_size: Vector2, physical_size: Vector2) -> Vector2:
	if not point.is_finite() or not bool(contract(logical_size, physical_size).valid):
		return Vector2(INF, INF)
	return point * physical_size / logical_size

static func logical_delta_to_window(delta: Vector2, logical_size: Vector2, physical_size: Vector2) -> Vector2:
	return logical_to_window(delta, logical_size, physical_size)
