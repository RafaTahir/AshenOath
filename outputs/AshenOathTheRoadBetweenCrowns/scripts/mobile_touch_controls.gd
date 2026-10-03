extends Control

signal gameplay_layout_unavailable(reason: String)
signal gameplay_layout_reason_changed(reason: String)

const TouchLayout = preload("res://scripts/mobile_touch_layout.gd")
const MODE_AUTO := "auto"
const MODE_ON := "on"
const MODE_OFF := "off"
const RELEASE_ACTIONS := ["interact", "pause", "open_inventory"]

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
var _visibility_refresh_pending := false
var _display_metrics: Dictionary = {}
var _layout: Dictionary = {}
var _actions: Array[Dictionary] = []
var _cancelled_touches: Dictionary = {}
var _down_touches: Dictionary = {}
var _cancelling := false
var _last_layout_reason := ""
var _layout_unavailable_announced := false

func _ready() -> void:
	name = "MobileTouchControls"
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process_input(true)
	set_process(false)
	touch_capable = _detect_touch_capability()
	visibility_changed.connect(queue_redraw)
	_update_layout()

func setup(router: Node, hud_node: CanvasLayer, settings: Dictionary) -> void:
	input_router = router
	hud = hud_node
	if not input_router.input_context_changed.is_connected(_on_input_context_changed):
		input_router.input_context_changed.connect(_on_input_context_changed)
	if not input_router.transient_input_reset.is_connected(_on_transient_input_reset):
		input_router.transient_input_reset.connect(_on_transient_input_reset)
	if not input_router.device_changed.is_connected(_on_device_changed):
		input_router.device_changed.connect(_on_device_changed)
	for layer in [hud.menu_layer, hud.dialogue_layer, hud.inventory_layer, hud.loading_layer]:
		if layer != null and not layer.visibility_changed.is_connected(_on_surface_changed):
			layer.visibility_changed.connect(_on_surface_changed)
	apply_settings(settings)
	if is_touch_enabled():
		input_router.activate_touch()
		hud.set_input_device("touch")
	_refresh_visibility()

func apply_settings(settings: Dictionary) -> void:
	cancel_active_touches("touch_settings")
	touch_mode = str(settings.get("touch_controls", MODE_AUTO)).to_lower()
	if touch_mode not in [MODE_AUTO, MODE_ON, MODE_OFF]:
		touch_mode = MODE_AUTO
	look_sensitivity = clampf(float(settings.get("touch_look_sensitivity", 1.0)), 0.55, 1.55)
	_update_layout()
	_queue_visibility_refresh()

func set_display_metrics(metrics: Dictionary) -> void:
	if metrics == _display_metrics:
		return
	cancel_active_touches("display_changed")
	_display_metrics = metrics.duplicate(true)
	_update_layout()
	_queue_visibility_refresh()

func set_force_touch_for_test(enabled: bool) -> void:
	cancel_active_touches("touch_mode_changed")
	force_touch_for_test = enabled
	if enabled:
		touch_capable = true
	_update_layout()
	_queue_visibility_refresh()

func is_touch_enabled() -> bool:
	return touch_mode == MODE_ON or force_touch_for_test or (touch_mode == MODE_AUTO and touch_capable)

func is_gameplay_visible() -> bool:
	if not is_touch_enabled() or hud == null or get_tree().paused:
		return false
	if input_router == null or not input_router.is_gameplay_context():
		return false
	if bool(hud.loading_armed) or (hud.loading_layer != null and hud.loading_layer.visible):
		return false
	if touch_mode == MODE_AUTO and not force_touch_for_test and str(input_router.active_device) != "touch":
		return false
	return hud.menu_layer != null and not hud.menu_layer.visible and hud.dialogue_layer != null and not hud.dialogue_layer.visible and hud.inventory_layer != null and not hud.inventory_layer.visible

func _process(_delta: float) -> void:
	# Compatibility for older callers; visibility is otherwise event-driven.
	_refresh_visibility()

func _queue_visibility_refresh() -> void:
	if _visibility_refresh_pending or not is_inside_tree():
		return
	_visibility_refresh_pending = true
	call_deferred("_refresh_visibility")

func _on_surface_changed() -> void:
	cancel_active_touches("touch_surface_changed")
	_layout_unavailable_announced = false
	_queue_visibility_refresh()

func _on_input_context_changed(_context: String) -> void:
	_clear_touch_ownership()
	if _context != "gameplay":
		_layout_unavailable_announced = false
	_queue_visibility_refresh()

func _on_transient_input_reset(_reason: String) -> void:
	_clear_touch_ownership()
	_queue_visibility_refresh()

func _on_device_changed(_device: String) -> void:
	_clear_touch_ownership()
	_publish_layout_state()
	_queue_visibility_refresh()

func _refresh_visibility() -> void:
	_visibility_refresh_pending = false
	var should_show: bool = is_gameplay_visible()
	if visible != should_show:
		if not should_show:
			_clear_touch_ownership()
		visible = should_show
		if visible and not _announced:
			_announced = true
			print("MOBILE_TOUCH: ready landscape=%s viewport=%s" % [not rotate_required, get_viewport_rect().size])
	_publish_layout_state()

func gameplay_layout_reason() -> String:
	# Keep this meaningful while paused so Resume can require a usable touch
	# layout without automatically unpausing when orientation becomes usable.
	if input_router == null or str(input_router.active_device) != "touch" or not is_touch_enabled():
		return ""
	return "" if bool(_layout.get("playable", false)) else str(_layout.get("reason", "More space is needed for touch play"))

func _publish_layout_state() -> void:
	var reason: String = gameplay_layout_reason()
	if reason != _last_layout_reason:
		_last_layout_reason = reason
		gameplay_layout_reason_changed.emit(reason)
	if reason == "" or not is_inside_tree() or not is_gameplay_visible():
		_layout_unavailable_announced = false
	elif not _layout_unavailable_announced:
		_layout_unavailable_announced = true
		gameplay_layout_unavailable.emit(reason)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		cancel_active_touches("touch_viewport_changed")
		_update_layout()
		_queue_visibility_refresh()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel_active_touches("focus_lost")

func cancel_active_touches(reason: String) -> void:
	if _cancelling:
		return
	_cancelling = true
	_clear_touch_ownership()
	if input_router != null:
		input_router.reset_transient_input(reason)
	_cancelling = false

func _clear_touch_ownership() -> void:
	for raw_index: Variant in _down_touches:
		_cancelled_touches[int(raw_index)] = true
	move_touch = -1
	look_touch = -1
	move_value = Vector2.ZERO
	action_touches.clear()
	if input_router != null:
		input_router.clear_virtual_input()
	queue_redraw()

func _input(event: InputEvent) -> void:
	if input_router == null:
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if not touch.pressed:
			_down_touches.erase(touch.index)
			if _cancelled_touches.erase(touch.index):
				if input_router.is_gameplay_context():
					get_viewport().set_input_as_handled()
				return
			if _owns_touch(touch.index):
				_end_touch(touch.index, touch.position, touch.canceled)
			return
		# Device selection resets transient state. Do it before recording this
		# genuine new contact so its ownership survives the handoff.
		input_router.activate_touch()
		touch_capable = true
		_cancelled_touches.erase(touch.index)
		_refresh_visibility()
		if not visible or not is_gameplay_visible():
			return
		if _owns_touch(touch.index):
			_cancel_touch(touch.index)
		_down_touches[touch.index] = true
		_begin_touch(touch.index, touch.position)
	elif event is InputEventScreenDrag:
		if _cancelled_touches.has(event.index):
			if input_router.is_gameplay_context():
				get_viewport().set_input_as_handled()
			return
		if visible and is_gameplay_visible() and _owns_touch(event.index):
			_drag_touch(event.index, event.position)

func _owns_touch(index: int) -> bool:
	return index == move_touch or index == look_touch or action_touches.has(index)

func _begin_touch(index: int, position: Vector2) -> void:
	for row: Dictionary in _actions:
		var action: String = str(row.get("id", ""))
		if position.distance_to(Vector2(row.get("center", Vector2.ZERO))) > float(row.get("radius", 0.0)):
			continue
		var already_held: bool = action_touches.values().has(action)
		action_touches[index] = action
		if not already_held and action not in RELEASE_ACTIONS:
			input_router.set_virtual_action(StringName(action), true)
		queue_redraw()
		get_viewport().set_input_as_handled()
		return
	if not bool(_layout.get("playable", false)):
		return
	var move_region: Rect2 = _layout.get("move_region", Rect2())
	var look_region: Rect2 = _layout.get("look_region", Rect2())
	if move_region.has_point(position) and move_touch < 0:
		move_touch = index
		move_origin = _move_center()
		_update_move(position)
	elif look_region.has_point(position) and look_touch < 0:
		look_touch = index
		look_previous = position
	else:
		return
	get_viewport().set_input_as_handled()

func _drag_touch(index: int, position: Vector2) -> void:
	if index == move_touch:
		_update_move(position)
	elif index == look_touch:
		var delta: Vector2 = position - look_previous
		look_previous = position
		var unit: float = maxf(float(_layout.get("unit_scale", 1.0)), 0.001)
		var look: Vector2 = delta / (24.0 * unit) * look_sensitivity
		input_router.set_virtual_axes(move_value, look.limit_length(1.0))
	elif action_touches.has(index):
		var action: String = str(action_touches[index])
		if not _inside_action(action, position):
			_cancel_touch(index)
	queue_redraw()
	get_viewport().set_input_as_handled()

func _inside_action(action: String, position: Vector2) -> bool:
	return action_centers.has(action) and position.distance_to(Vector2(action_centers[action])) <= float(action_radii.get(action, 0.0))

func _cancel_touch(index: int) -> void:
	_cancelled_touches[index] = true
	_end_touch(index, Vector2.ZERO, true)

func _end_touch(index: int, position: Vector2, cancelled: bool = false) -> void:
	if index == move_touch:
		move_touch = -1
		move_value = Vector2.ZERO
		input_router.set_virtual_axes(Vector2.ZERO, Vector2.ZERO)
	elif index == look_touch:
		look_touch = -1
		input_router.clear_virtual_look()
	elif action_touches.has(index):
		var action: String = str(action_touches[index])
		action_touches.erase(index)
		if not action_touches.values().has(action):
			if action in RELEASE_ACTIONS:
				if not cancelled and visible and is_gameplay_visible() and _inside_action(action, position):
					input_router.set_virtual_action(StringName(action), true)
					input_router.set_virtual_action(StringName(action), false)
			else:
				input_router.set_virtual_action(StringName(action), false)
	queue_redraw()
	get_viewport().set_input_as_handled()

func _update_move(position: Vector2) -> void:
	var travel: float = maxf(float(_layout.get("move_travel", 44.0)), 1.0)
	move_value = ((position - move_origin) / travel).limit_length(1.0)
	input_router.set_virtual_axes(move_value, Vector2.ZERO)
	queue_redraw()

func _release_all() -> void:
	_clear_touch_ownership()

func _update_layout() -> void:
	var canvas_size: Vector2 = get_viewport_rect().size
	if canvas_size.x <= 0 or canvas_size.y <= 0:
		return
	var display: Dictionary = _display_metrics
	if display.is_empty():
		var native_size: Vector2i = DisplayServer.window_get_size()
		display = {"width": native_size.x if native_size.x > 0 else canvas_size.x, "height": native_size.y if native_size.y > 0 else canvas_size.y}
	_layout = TouchLayout.build(canvas_size, display)
	rotate_required = not bool(_layout.get("landscape", true))
	_actions.clear()
	action_centers.clear()
	action_radii.clear()
	for raw_action: Variant in _layout.get("actions", []):
		if not raw_action is Dictionary:
			continue
		var row: Dictionary = raw_action
		_actions.append(row)
		action_centers[str(row.get("id", ""))] = row.get("center", Vector2.ZERO)
		action_radii[str(row.get("id", ""))] = float(row.get("radius", 0.0))
	_publish_layout_state()
	queue_redraw()

func _draw() -> void:
	if not visible:
		return
	var unit: float = maxf(float(_layout.get("unit_scale", 1.0)), 0.001)
	var safe: Rect2 = _layout.get("safe_rect", get_viewport_rect())
	if not bool(_layout.get("playable", false)):
		draw_rect(safe, Color(0.015, 0.018, 0.021, 0.90))
		_draw_centered_label(safe.get_center(), str(_layout.get("reason", "More space is needed for touch play")), maxi(12, int(18.0 * unit)))
		_draw_centered_label(safe.get_center() + Vector2(0, 28.0 * unit), "Pause and Journal remain available", maxi(12, int(14.0 * unit)))
	else:
		var center: Vector2 = _move_center()
		var radius: float = float(_layout.get("move_radius", 56.0))
		draw_circle(center, radius, Color(0.03, 0.04, 0.05, 0.54))
		draw_arc(center, radius, 0.0, TAU, 48, Color(0.72, 0.62, 0.43, 0.62), 2.0 * unit)
		draw_circle(center + move_value * float(_layout.get("move_travel", 44.0)), float(_layout.get("move_knob_radius", 22.0)), Color(0.70, 0.61, 0.43, 0.76))
	for row: Dictionary in _actions:
		var action: String = str(row.get("id", ""))
		var center: Vector2 = row.get("center", Vector2.ZERO)
		var radius: float = float(row.get("radius", 24.0))
		var descriptor: Dictionary = input_router.describe_action(action) if input_router != null else {}
		var toggle: bool = str(descriptor.get("mode", "hold")) == "toggle"
		var pressed: bool = action_touches.values().has(action) or (toggle and bool(descriptor.get("active", false)))
		draw_circle(center, radius, Color(0.40, 0.12, 0.08, 0.84) if pressed else Color(0.04, 0.045, 0.05, 0.64))
		draw_arc(center, radius, 0.0, TAU, 40, Color(0.86, 0.70, 0.44, 0.80), 2.0 * unit)
		var caption: String = str(row.get("label", action))
		var toggled_on: bool = toggle and bool(descriptor.get("active", false))
		_draw_centered_label(center - Vector2(0, 5.0 * unit) if toggled_on else center, caption, maxi(10, int((12.0 if action != "pause" else 19.0) * unit)))
		if toggled_on:
			_draw_centered_label(center + Vector2(0, 10.0 * unit), "ON", maxi(10, int(10.0 * unit)))

func _draw_centered_label(center: Vector2, text: String, font_size: int) -> void:
	var font: Font = ThemeDB.fallback_font
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, center + Vector2(-width * 0.5, font_size * 0.34), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.96, 0.90, 0.78))

func _move_center() -> Vector2:
	return _layout.get("move_center", Vector2.ZERO)

func get_layout_snapshot() -> Dictionary:
	var result: Dictionary = _layout.duplicate(true)
	result["viewport"] = get_viewport_rect().size
	result["rotate_required"] = rotate_required
	result["actions"] = action_centers.duplicate(true)
	result["radii"] = action_radii.duplicate(true)
	return result

func _detect_touch_capability() -> bool:
	if OS.has_feature("mobile"):
		return true
	if OS.has_feature("web"):
		var result: Variant = JavaScriptBridge.eval("Boolean((navigator.maxTouchPoints||0)>0 || new URLSearchParams(location.search).has('touch'))", true)
		return bool(result)
	return DisplayServer.is_touchscreen_available()
