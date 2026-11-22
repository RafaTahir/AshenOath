extends Node

## Deliver displayed geometry independently of the fixed rendering viewport.
## The browser callback is retained until shutdown; updates are event-driven
## and carry only dimensions/input-capability hints, never game state.
const DISPLAY_EVENT := "ashen-oath-display"

var _targets: Array[WeakRef] = []
var _browser_window: JavaScriptObject
var _browser_callback: JavaScriptObject
var _geometry: Dictionary = {}
var _refresh_pending: bool = false
var _configured: bool = false
var _stopped: bool = false
var _revision: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	if not get_window().size_changed.is_connected(_queue_refresh):
		get_window().size_changed.connect(_queue_refresh)

func setup(hud: Node, mobile_touch: Node) -> void:
	if _configured or _stopped:
		return
	_configured = true
	# Touch cancels its old geometry before the HUD adopts the new bounds.
	for target: Node in [mobile_touch, hud]:
		if is_instance_valid(target):
			_targets.append(weakref(target))
	if OS.has_feature("web"):
		_browser_window = JavaScriptBridge.get_interface("window")
		if _browser_window != null:
			_browser_callback = JavaScriptBridge.create_callback(_on_browser_display)
			_browser_window.addEventListener(DISPLAY_EVENT, _browser_callback)
	_queue_refresh()

func _on_browser_display(_arguments: Array) -> void:
	_queue_refresh()

func _queue_refresh() -> void:
	if _stopped or not _configured or _refresh_pending or not is_inside_tree():
		return
	_refresh_pending = true
	call_deferred("_refresh")

func _refresh() -> void:
	_refresh_pending = false
	if _stopped or not _configured or not is_inside_tree():
		return
	var next: Dictionary = _read_geometry()
	if next.is_empty() or next == _geometry:
		return
	_geometry = next.duplicate(true)
	_revision += 1
	next["revision"] = _revision
	for reference: WeakRef in _targets:
		var target: Node = reference.get_ref() as Node
		if is_instance_valid(target) and target.has_method("set_display_metrics"):
			target.call("set_display_metrics", next.duplicate(true))

func _read_geometry() -> Dictionary:
	if OS.has_feature("web"):
		var encoded: Variant = JavaScriptBridge.eval("JSON.stringify(window.__ashenOathDisplay || null)", true)
		if encoded is String:
			var parsed: Variant = JSON.parse_string(encoded)
			if parsed is Dictionary:
				var browser: Dictionary = _normalized(parsed)
				if not browser.is_empty():
					return browser
	var window: Window = get_window()
	if window == null:
		return {}
	var displayed: Vector2i = DisplayServer.window_get_size(window.get_window_id())
	if displayed.x <= 0 or displayed.y <= 0:
		displayed = window.size
	return _normalized({"width": displayed.x, "height": displayed.y, "coarse_pointer": false})

func _normalized(raw: Dictionary) -> Dictionary:
	var width: float = _number(raw, "width")
	var height: float = _number(raw, "height")
	if width <= 0.0 or height <= 0.0:
		return {}
	return {
		"width": width,
		"height": height,
		"inset_left": clampf(_number(raw, "inset_left"), 0.0, width),
		"inset_right": clampf(_number(raw, "inset_right"), 0.0, width),
		"inset_top": clampf(_number(raw, "inset_top"), 0.0, height),
		"inset_bottom": clampf(_number(raw, "inset_bottom"), 0.0, height),
		"coarse_pointer": bool(raw.get("coarse_pointer", false))
	}

func _number(raw: Dictionary, key: String) -> float:
	var value: Variant = raw.get(key, 0.0)
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
		return 0.0
	return float(value)

func shutdown() -> void:
	if _stopped:
		return
	_stopped = true
	_refresh_pending = false
	if _browser_window != null and _browser_callback != null:
		_browser_window.removeEventListener(DISPLAY_EVENT, _browser_callback)
	_browser_callback = null
	_browser_window = null
	_targets.clear()
	var window: Window = get_window() if is_inside_tree() else null
	if window != null and window.size_changed.is_connected(_queue_refresh):
		window.size_changed.disconnect(_queue_refresh)

func _exit_tree() -> void:
	shutdown()
