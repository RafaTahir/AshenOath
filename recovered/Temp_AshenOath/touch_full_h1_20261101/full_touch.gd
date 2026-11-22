extends SceneTree
const Fixture = preload("res://tools/runtime_fixture.gd")
var game: Node
var touch: Control
var router: Node
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
 root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
 root.content_scale_size = Vector2i(1280,720)
 root.size = Vector2i(960,540)
 var scene: PackedScene = load("res://scenes/main.tscn")
 game = scene.instantiate()
 root.add_child(game)
 await process_frame
 touch = game.runtime_services.get_service("mobile_touch")
 router = game.input_router
 router.transient_input_reset.connect(func(reason: String): print("TRACE_RESET ",reason," ",get_stack()))
 router.device_changed.connect(func(device: String): print("TRACE_DEVICE ",device," ",get_stack()))
 touch.visibility_changed.connect(func(): print("TRACE_TOUCH_VISIBILITY ",touch.visible," ",get_stack()))
 touch.resized.connect(func(): print("TRACE_TOUCH_RESIZE ",touch.size," ",get_stack()))
 touch.apply_settings({"touch_controls":"on"})
 touch.set_display_metrics({"width":960.0,"height":540.0,"coarse_pointer":true})
 print("WAIT_START")
 if not await Fixture.start(game,180000):
  quit(2)
  return
 for i in range(8): await physics_frame
 # Supply the actual browser display independently of the fixed viewport.
 touch.set_display_metrics({"width":960.0,"height":540.0,"coarse_pointer":true})
 for i in range(3): await physics_frame
 print("ROUTER_IDS game=",game.input_router.get_instance_id()," local=",router.get_instance_id()," touch=",touch.input_router.get_instance_id()," player=",game.player.input_source.get_instance_id()," registry=",game.runtime_services.get_service("input_router").get_instance_id()," all_equal=",game.input_router == touch.input_router and game.input_router == game.player.input_source)
 print("INPUT_ELIGIBILITY touch=",touch.is_processing_input()," router=",router.is_processing_input()," touch_visible_tree=",touch.is_visible_in_tree()," touch_mode=",touch.touch_mode," touch_process_mode=",touch.process_mode," parent_process_mode=",touch.get_parent().process_mode)
 _state("ready")
 var before: Vector3 = game.player.global_position
 _touch(true)
 _state("pressed_sync")
 for i in range(3):
  await physics_frame
  _state("pressed_"+str(i))
 _drag()
 _state("drag_sync")
 for i in range(15):
  await physics_frame
  _state("held_"+str(i))
 _touch(false)
 for i in range(3): await physics_frame
 _state("released")
 print("FULL_TOUCH_DELTA ",game.player.global_position-before)
 await Fixture.shutdown(game)
 quit(0)
func _touch(pressed: bool) -> void:
 var event := InputEventScreenTouch.new()
 event.index=7
 event.position=Vector2(72,464)
 event.pressed=pressed
 Input.parse_input_event(event)
func _drag() -> void:
 var event := InputEventScreenDrag.new()
 event.index=7
 event.position=Vector2(72,428)
 event.relative=Vector2(0,-36)
 Input.parse_input_event(event)
func _state(label: String) -> void:
 var player: Node = game.player
 print("FRAME ",label," ms=",Time.get_ticks_msec()," owner=",touch.move_touch," down=",touch._down_touches," cancelled=",touch._cancelled_touches," visible=",touch.visible," enable=",touch.is_touch_enabled()," layout=",touch._move_center()," virtual=",router.virtual_move," move=",router.movement_vector()," context=",router.input_context," device=",router.active_device," control=",player.can_control," transition=",player.transition_locked," vel=",player.velocity," pos=",player.global_position," physics=",player.is_physics_processing()," paused=",paused," loading=",game.hud.loading_armed," menu=",game.hud.active_menu)
