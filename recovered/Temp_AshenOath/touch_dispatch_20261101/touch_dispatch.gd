extends SceneTree
const Router = preload("res://scripts/input_router.gd")
const Touch = preload("res://scripts/mobile_touch_controls.gd")
class FakeHud extends CanvasLayer:
 signal interaction_prompt_changed(model: Dictionary)
 var menu_layer := Control.new()
 var dialogue_layer := Control.new()
 var inventory_layer := Control.new()
 var loading_layer := Control.new()
 var loading_armed := false
 func _ready() -> void:
  for layer: Control in [menu_layer,dialogue_layer,inventory_layer,loading_layer]:
   add_child(layer)
   layer.hide()
 func set_input_device(_device: String) -> void: pass
 func get_interaction_prompt_model() -> Dictionary: return {}
class ObservedTouch extends Touch:
 var events: Array[String] = []
 func _input(event: InputEvent) -> void:
  if event is InputEventScreenTouch or event is InputEventScreenDrag:
   events.append(event.get_class())
   print("TOUCH_EVENT %s p=%s device=%s" % [event.get_class(),event.position,event.device])
  super._input(event)
class ObservedRouter extends Router:
 var events: Array[String] = []
 func _input(event: InputEvent) -> void:
  if event is InputEventScreenTouch or event is InputEventScreenDrag:
   events.append(event.get_class())
   print("ROUTER_EVENT %s p=%s device=%s" % [event.get_class(),event.position,event.device])
  super._input(event)
var failures: Array[String] = []
var router: Node
var touch: Control
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
 root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
 root.content_scale_size = Vector2i(1280,720)
 root.size = Vector2i(960,540)
 router = ObservedRouter.new()
 root.add_child(router)
 var hud := FakeHud.new()
 root.add_child(hud)
 touch = ObservedTouch.new()
 root.add_child(touch)
 touch.setup(router,hud,{"touch_controls":"on"})
 touch.set_display_metrics({"width":960.0,"height":540.0,"coarse_pointer":true})
 router.set_gameplay_context()
 router.device_changed.connect(func(device: String): print("DEVICE ",device))
 router.transient_input_reset.connect(func(reason: String): print("RESET ",reason))
 await _frames(4)
 print("GEOMETRY root=%s viewport=%s center=%s layout=%s" % [root.size,touch.get_viewport_rect(),touch._move_center(),touch.get_layout_snapshot()])
 _check(touch.get_viewport_rect().size == Vector2(1280,720),"fixed viewport1280x720")
 _check(touch._move_center().distance_to(Vector2(96,618.6667)) < 0.1,"reported canvas center matches960 display")
 for mode: String in ["on","auto"]:
  touch.touch_capable = true
  touch.apply_settings({"touch_controls":mode})
  await _frames(2)
  _keyboard()
  await _frames(2)
  _check(router.active_device == "keyboard_mouse","keyboard precondition "+mode)
  _touch(true)
  await _frames(2)
  _check(router.active_device == "touch","press handoff "+mode)
  _check(touch.move_touch == 7,"stick ownership after real press "+mode)
  _drag()
  await _frames(3)
  print("RESULT mode=%s device=%s owner=%s move=%s events=%s" % [mode,router.active_device,touch.move_touch,router.movement_vector(),touch.events])
  _check(router.movement_vector().y < -0.8,"drag moves through real _input "+mode)
  var mouse := InputEventMouseMotion.new()
  mouse.device = -1
  mouse.relative = Vector2(20,0)
  Input.parse_input_event(mouse)
  await _frames(2)
  _check(router.active_device == "touch" and touch.move_touch == 7 and router.movement_vector().y < -0.8,"emulated mouse preserves touch "+mode)
  _touch(false)
  await _frames(2)
  _check(touch.move_touch == -1 and router.movement_vector().is_zero_approx(),"release clears actual owned finger "+mode)
 _check(touch.events.count("InputEventScreenTouch") == 4 and touch.events.count("InputEventScreenDrag") == 2,"real event delivery counts")
 # Show the distinguishing physical mouse control, not an inferred browser event.
 _touch(true)
 _drag()
 var physical := InputEventMouseMotion.new()
 physical.device = 0
 physical.relative = Vector2(20,0)
 Input.parse_input_event(physical)
 await _frames(2)
 _check(router.active_device == "keyboard_mouse" and touch.move_touch == -1,"physical mouse legitimately resets touch")
 _touch(false)
 print("TOUCH DISPATCH FIXTURE ","PASS" if failures.is_empty() else "FAIL", " failures=",failures)
 touch.queue_free()
 hud.queue_free()
 router.queue_free()
 await _frames(2)
 quit(0 if failures.is_empty() else 1)
func _touch(pressed: bool) -> void:
 var event := InputEventScreenTouch.new()
 event.index = 7
 event.position = Vector2(72,464)
 event.pressed = pressed
 Input.parse_input_event(event)
func _drag() -> void:
 var event := InputEventScreenDrag.new()
 event.index = 7
 event.position = Vector2(72,398)
 event.relative = Vector2(0,-66)
 Input.parse_input_event(event)
func _keyboard() -> void:
 var event := InputEventKey.new()
 event.keycode = KEY_A
 event.pressed = true
 Input.parse_input_event(event)
 event = InputEventKey.new()
 event.keycode = KEY_A
 event.pressed = false
 Input.parse_input_event(event)
func _frames(count: int) -> void:
 for i in range(count): await process_frame
func _check(ok: bool, message: String) -> void:
 print("CHECK ","PASS " if ok else "FAIL ",message)
 if not ok: failures.append(message)
