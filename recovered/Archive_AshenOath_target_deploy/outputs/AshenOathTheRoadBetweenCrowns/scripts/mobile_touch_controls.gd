extends Control

const MODE_AUTO := "auto"
const MODE_ON := "on"
const MODE_OFF := "off"

var input_router: Node
var hud: CanvasLayer
var touch_mode := MODE_AUTO
var look_sensitivity := 1.0
var force_touch_for_test := false
var touch_capable := false
var move_touch := -1
var look_touch := -1
var move_origin := Vector2.ZERO
var move_value := Vector2.ZERO
var look_previous := Vector2.ZERO
var action_touches: Dictionary = {}
var action_centers: Dictionary = {}
var action_radii: Dictionary = {}
var rotate_required := false
var _announced := false

func _ready() -> void:
	name = "MobileTouchControls"
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process_input(true)
	touch_capable = _detect_touch_capability()
	visibility_changed.connect(queue_redraw)

func setup(router: Node, hud_node: CanvasLayer, settings: Dictionary) -> void:
	input_router = router
	hud = hud_node
	apply_settings(settings)
	if is_touch_enabled():
		input_router.activate_touch()
		hud.set_input_device("touch")

func apply_settings(settings: Dictionary) -> void:
	touch_mode = str(settings.get("touch_controls", MODE_AUTO)).to_lower()
	if touch_mode not in [MODE_AUTO, MODE_ON, MODE_OFF]:
		touch_mode = MODE_AUTO
	look_sensitivity = clampf(float(settings.get("touch_look_sensitivity", 1.0)), 0.55, 1.55)
	_update_layout()

func set_force_touch_for_test(enabled: bool) -> void:
	force_touch_for_test = enabled
	if enabled:
		touch_capable = true
	_update_layout()

func is_touch_enabled() -> bool:
	return touch_mode == MODE_ON or force_touch_for_test or (touch_mode == MODE_AUTO and touch_capable)

func is_gameplay_visible() -> bool:
	if not is_touch_enabled() or hud == null or get_tree().paused:
		return false
	var menus_hidden: bool = hud.menu_layer != null and not hud.menu_layer.visible
	var dialogue_hidden: bool = hud.dialogue_layer != null and not hud.dialogue_layer.visible
	var inventory_hidden: bool = hud.inventory_layer != null and not hud.inventory_layer.visible
	return menus_hidden and dialogue_hidden and inventory_hidden

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

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_layout()

func _input(event: InputEvent) -> void:
	if not visible or rotate_required or input_router == null:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_begin_touch(event.index, event.position)
		else:
			_end_touch(event.index)
	elif event is InputEventScreenDrag:
		_drag_touch(event.index, event.position)

func _begin_touch(index: int, position: Vector2) -> void:
	for action in action_centers:
		if position.distance_to(Vector2(action_centers[action])) <= float(action_radii[action]):
			action_touches[index] = action
			input_router.set_virtual_action(StringName(action), true)
			queue_redraw()
			get_viewport().set_input_as_handled()
			return
	var size := get_viewport_rect().size
	if position.x < size.x * 0.43 and position.y > size.y * 0.42 and move_touch < 0:
		move_touch = index
		move_origin = _move_center()
		_update_move(position)
	elif position.x > size.x * 0.40 and look_touch < 0:
		look_touch = index
		look_previous = position
		input_router.set_virtual_axes(move_value, Vector2.ZERO)
	get_viewport().set_input_as_handled()

func _drag_touch(index: int, position: Vector2) -> void:
	if index == move_touch:
		_update_move(position)
		get_viewport().set_input_as_handled()
	elif index == look_touch:
		var delta := position - look_previous
		look_previous = position
		var look := Vector2(delta.x, delta.y) / 24.0 * look_sensitivity
		input_router.set_virtual_axes(move_value, look.limit_length(1.0))
		get_viewport().set_input_as_handled()

func _end_touch(index: int) -> void:
	if index == move_touch:
		move_touch = -1
		move_value = Vector2.ZERO
		input_router.set_virtual_axes(Vector2.ZERO, Vector2.ZERO)
	elif index == look_touch:
		look_touch = -1
		input_router.set_virtual_axes(move_value, Vector2.ZERO)
	elif action_touches.has(index):
		var action: StringName = StringName(action_touches[index])
		action_touches.erase(index)
		input_router.set_virtual_action(action, false)
	queue_redraw()
	get_viewport().set_input_as_handled()

func _update_move(position: Vector2) -> void:
	var offset := (position - move_origin) / 82.0
	move_value = offset.limit_length(1.0)
	input_router.set_virtual_axes(move_value, Vector2.ZERO)
	queue_redraw()

func _release_all() -> void:
	move_touch = -1
	look_touch = -1
	move_value = Vector2.ZERO
	action_touches.clear()
	if input_router != null:
		input_router.clear_virtual_input()
	queue_redraw()

func _update_layout() -> void:
	var size := get_viewport_rect().size
	if size.x <= 0.0 or size.y <= 0.0:
		return
	rotate_required = size.x / maxf(size.y, 1.0) < 1.28
	var edge := maxf(22.0, size.x * 0.018)
	var base_x := size.x - edge
	var base_y := size.y - edge
	action_centers = {
		"light_attack": Vector2(base_x - 92.0, base_y - 116.0),
		"heavy_attack": Vector2(base_x - 46.0, base_y - 206.0),
		"dodge": Vector2(base_x - 186.0, base_y - 56.0),
		"block": Vector2(base_x - 286.0, base_y - 76.0),
		"oathfire_beam": Vector2(base_x - 286.0, base_y - 178.0),
		"interact": Vector2(base_x - 92.0, base_y - 306.0),
		"jump": Vector2(base_x - 190.0, base_y - 270.0),
		"use_potion": Vector2(base_x - 390.0, base_y - 62.0),
		"throw_bomb": Vector2(base_x - 462.0, base_y - 62.0),
		"open_inventory": Vector2(size.x * 0.42, base_y - 18.0),
		"pause": Vector2(size.x * 0.48, base_y - 18.0),
	}
	action_radii = {
		"light_attack": 46.0,
		"heavy_attack": 40.0,
		"dodge": 42.0,
		"block": 40.0,
		"oathfire_beam": 43.0,
		"interact": 40.0,
		"jump": 38.0,
		"use_potion": 34.0,
		"throw_bomb": 34.0,
		"open_inventory": 28.0,
		"pause": 28.0,
	}
	queue_redraw()

func _draw() -> void:
	if not visible:
		return
	var size := get_viewport_rect().size
	if rotate_required:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.018, 0.021, 0.90))
		var font := ThemeDB.fallback_font
		var message := "Rotate device to landscape"
		var width := font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		draw_string(font, Vector2((size.x - width) * 0.5, size.y * 0.5), message, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.92, 0.82, 0.63))
		return
	var move_center := _move_center()
	draw_circle(move_center, 88.0, Color(0.03, 0.04, 0.05, 0.54))
	draw_arc(move_center, 88.0, 0.0, TAU, 48, Color(0.72, 0.62, 0.43, 0.62), 2.0)
	draw_circle(move_center + move_value * 53.0, 34.0, Color(0.70, 0.61, 0.43, 0.76))
	var labels := {
		"light_attack": "STRIKE",
		"heavy_attack": "HEAVY",
		"dodge": "DODGE",
		"block": "GUARD",
		"oathfire_beam": "OATH",
		"interact": "USE",
		"jump": "JUMP",
		"use_potion": "POTION",
		"throw_bomb": "BOMB",
		"open_inventory": "BOOK",
		"pause": "II",
	}
	for action in action_centers:
		var center: Vector2 = action_centers[action]
		var radius: float = action_radii[action]
		var pressed: bool = action in action_touches.values()
		draw_circle(center, radius, Color(0.40, 0.12, 0.08, 0.84) if pressed else Color(0.04, 0.045, 0.05, 0.64))
		draw_arc(center, radius, 0.0, TAU, 40, Color(0.86, 0.70, 0.44, 0.80), 2.0)
		_draw_centered_label(center, str(labels[action]), 13 if action != "pause" else 19)

func _draw_centered_label(center: Vector2, text: String, font_size: int) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, center + Vector2(-width * 0.5, font_size * 0.34), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.96, 0.90, 0.78))

func _move_center() -> Vector2:
	var size := get_viewport_rect().size
	return Vector2(maxf(126.0, size.x * 0.105), size.y - maxf(124.0, size.y * 0.17))

func get_layout_snapshot() -> Dictionary:
	return {
		"viewport": get_viewport_rect().size,
		"rotate_required": rotate_required,
		"move_center": _move_center(),
		"actions": action_centers.duplicate(true),
		"radii": action_radii.duplicate(true),
	}

func _detect_touch_capability() -> bool:
	if OS.has_feature("mobile"):
		return true
	if OS.has_feature("web"):
		var result = JavaScriptBridge.eval(
			"Boolean((navigator.maxTouchPoints||0)>0 || new URLSearchParams(location.search).has('touch'))",
			true
		)
		return bool(result)
	return DisplayServer.is_touchscreen_available()
