extends RefCounted
var _router: Node
func _init(router: Node) -> void:
	_router = router
var _web_pointer_capture_block_until := 0
var _web_pointer_capture_denied := false
var _web_pointer_window: JavaScriptObject
var _web_pointer_callback: JavaScriptObject

func show_pointer() -> void:
	if OS.has_feature("web"):
		_web_pointer_capture_block_until = Time.get_ticks_msec() + 350
	_router._set_pointer_mode(Input.MOUSE_MODE_VISIBLE)

func capture_pointer(keyboard_gesture: bool = false) -> void:
	if _router.active_device == _router.DEVICE_TOUCH:
		_router.show_pointer()
		return
	if OS.has_feature("web") and _web_pointer_capture_denied:
		return
	if OS.has_feature("web") and not keyboard_gesture and Time.get_ticks_msec() < _web_pointer_capture_block_until:
		return
	_router._set_pointer_mode(Input.MOUSE_MODE_CAPTURED)

func _install_web_pointer_fallback() -> void:
	if not OS.has_feature("web"):
		return
	_web_pointer_window = JavaScriptBridge.get_interface("window")
	if _web_pointer_window == null:
		_web_pointer_capture_denied = true
		return
	if not bool(JavaScriptBridge.eval("Boolean(document.getElementById('canvas') && document.getElementById('canvas').requestPointerLock)", true)):
		_web_pointer_capture_denied = true
		return
	_web_pointer_callback = JavaScriptBridge.create_callback(_router._on_web_pointer_capture_denied)
	_web_pointer_window.ashenOathPointerCaptureFallback = _web_pointer_callback
	JavaScriptBridge.eval("""
(() => {
  const canvas = document.getElementById('canvas');
  if (!canvas || !canvas.requestPointerLock || canvas.ashenOathPointerLock) return;
  const original = canvas.requestPointerLock;
  const owner = window.ashenOathPointerCaptureFallback;
  const denied = () => {
    if (window.ashenOathPointerCaptureFallback === owner) owner();
  };
  const wrapped = function(...args) {
    try {
      const result = original.apply(this, args);
      return result && typeof result.catch === 'function' ? result.catch(denied) : result;
    } catch (error) { denied(); }
  };
  canvas.requestPointerLock = wrapped;
  document.addEventListener('pointerlockerror', denied);
  canvas.ashenOathPointerLock = {original, wrapped, denied, owner};
})();
""", true)

func _on_web_pointer_capture_denied(_arguments: Array) -> void:
	_web_pointer_capture_denied = true
	_router.show_pointer()

func _exit_tree() -> void:
	if _web_pointer_window == null:
		return
	JavaScriptBridge.eval("""
(() => {
  const canvas = document.getElementById('canvas');
  const state = canvas && canvas.ashenOathPointerLock;
  if (!state || state.owner !== window.ashenOathPointerCaptureFallback) return;
  document.removeEventListener('pointerlockerror', state.denied);
  if (canvas.requestPointerLock === state.wrapped) canvas.requestPointerLock = state.original;
  delete canvas.ashenOathPointerLock;
})();
""", true)
	_web_pointer_window.ashenOathPointerCaptureFallback = null
	_web_pointer_callback = null
	_web_pointer_window = null

func release_pointer() -> void:
	_router.show_pointer()

func restore_gameplay_pointer() -> void:
	if _router.active_device == _router.DEVICE_TOUCH:
		_router.show_pointer()
	elif OS.has_feature("web"):
		_router.show_pointer()
	else:
		_router.capture_pointer()

func is_pointer_captured() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func _set_pointer_mode(mode: int) -> void:
	if Input.mouse_mode == mode:
		return
	Input.mouse_mode = mode
	_router.pointer_mode_changed.emit(mode)
