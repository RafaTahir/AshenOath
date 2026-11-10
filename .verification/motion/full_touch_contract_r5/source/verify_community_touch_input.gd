extends SceneTree

## Dispatch fixture for the acceptance adapter, not a level or phone test.
const Touch = preload("res://scripts/mobile_touch_controls.gd")
const Router = preload("res://scripts/input_router.gd")
const Adapter = preload("res://tools/community_touch_input.gd")
const Menu = preload("res://scripts/hud/menu_panel.gd")
const Dialogue = preload("res://scripts/hud/dialogue_panel.gd")
const PresentationState = preload("res://scripts/hud/hud_state.gd")

class FakeHud extends CanvasLayer:
	signal interaction_prompt_changed(model: Dictionary)
	var menu_layer := Control.new()
	var dialogue_layer := Control.new()
	var inventory_layer := Control.new()
	var loading_layer := Control.new()
	var loading_armed := false
	var style
	var menu
	func _style_button(button: Button) -> void: style._style_button(button)
	func _style_menu_action(button: Button) -> void: style._style_menu_action(button)
	func _hide_native_button_text(button: Button) -> void: style._hide_native_button_text(button)
	func _capture_menu_state() -> void: pass # No journey/menu persistence in this UI-only fixture.
	func _activate_menu_action(callback: Callable, generation: int) -> void: menu._activate_menu_action(callback,generation)
	func _ready() -> void:
		for layer in [menu_layer,dialogue_layer,inventory_layer,loading_layer]: add_child(layer)
		for layer in [dialogue_layer,inventory_layer,loading_layer]: layer.hide()
	func set_input_device(_device: String) -> void: pass
	func get_interaction_prompt_model() -> Dictionary:
		return {"available":true,"target_instance_id":get_instance_id()}

class LookConsumer extends Node:
	var router
	var received := Vector2.ZERO
	func _process(_delta: float) -> void:
		received+=router.consume_touch_look_delta()

var failures: Array[String]=[]
var input_events := 0
var clicked: Array[String]=[]
var requests: Array[Dictionary]=[]
var gui_events: Array[Dictionary]=[]
var original_style := false
var ui_surfaces: Dictionary={}
var held_samples: Array[Dictionary]=[]

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size=Vector2i.ZERO
	root.size=Vector2i(960,540)
	var previous_emulation := Input.emulate_mouse_from_touch
	var previous_touch_emulation := Input.emulate_touch_from_mouse
	Input.emulate_mouse_from_touch=true
	Input.emulate_touch_from_mouse=true
	_check(DisplayServer.is_touchscreen_available(),"Native ScrollContainer sees the simulated touchscreen")
	var router := Router.new()
	root.add_child(router)
	router.install_default_actions()
	router.gameplay_action_requested.connect(func(request: Dictionary): requests.append(request))
	var hud := FakeHud.new()
	root.add_child(hud)
	var style_path := "res://scripts/hud/hud_style.gd"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--original-style="):
			style_path=argument.trim_prefix("--original-style=")
			original_style=true
	var style=load(style_path).new()
	var presentation := PresentationState.new()
	style.configure(hud,presentation)
	hud.add_child(style)
	hud.style=style
	var menu := Menu.new()
	menu.configure(hud,presentation)
	hud.add_child(menu)
	hud.menu=menu
	var dialogue := Dialogue.new()
	dialogue.configure(hud,presentation)
	hud.add_child(dialogue)
	presentation.input_source=router
	var control := Touch.new()
	root.add_child(control)
	control.setup(router,hud,{"touch_controls":"auto"})
	var adapter := Adapter.new()
	adapter.owner=self
	for surface: String in ["menu","dialogue"]:
		await _exercise_scroll(surface,hud,presentation,menu,dialogue,adapter)
		if not failures.is_empty():
			await _done(adapter,[control,hud,router],previous_emulation,previous_touch_emulation)
			return
	_check(requests.is_empty(),"HUD-owned screen presses and drags dispatch no gameplay action")
	_check(str(router.active_device)=="touch" and control.touch_capable,"Genuine contact selects touch without test forcing")
	hud.menu_layer.hide()
	router.set_gameplay_context()
	await _frames(3)
	adapter.move(Vector2.UP,true)
	await _frames(2)
	_check(router.movement_vector().y< -0.9,"Screen stick drag drives normal movement axes")
	adapter.move(Vector2.UP,false)
	await _frames(2)
	_check(router.movement_vector().is_zero_approx(),"Finger release clears movement")
	var consumer := LookConsumer.new()
	consumer.router=router
	root.add_child(consumer)
	await adapter.look(0.3,0.003)
	_check(consumer.received.x< -1.0,"Screen look drag reaches the regular look consumer")
	await adapter.action("interact")
	_check(requests.size()==1 and requests[0].action=="interact" and requests[0].target_instance_id==hud.get_instance_id(),"Screen Use release retains the selected interaction target")
	adapter.hold_action("block",true)
	_sample_hold("guard_queued",router,control,adapter)
	for index in range(3):
		await _frames(1)
		_sample_hold("guard_frame_"+str(index+1),router,control,adapter)
	_check(router.is_action_pressed("block"),"Held screen Guard persists across frames")
	adapter.hold_action("block",false)
	await _frames(2)
	_check(not router.is_action_pressed("block"),"Releasing Guard clears the actual router hold")
	control.set_weapon_mode("bow") # Fixture UI layout only; no game/player exists.
	await _frames(3)
	adapter.move(Vector2.UP,true)
	adapter.hold_action("aim_bow",true)
	adapter.hold_action("fire_bow",true)
	await _frames(3)
	_check(router.is_action_pressed("aim_bow") and router.is_action_pressed("fire_bow") and router.movement_vector().y< -0.9,"Independent fingers hold movement, Aim and Draw together")
	adapter.hold_action("fire_bow",false)
	await _frames(2)
	_check(router.is_action_pressed("aim_bow") and not router.is_action_pressed("fire_bow"),"Loose releases Draw while Aim remains held")
	# An actual More button request presents a fixture-only visible menu. Its
	# screen selection changes the input context just as the live HUD does.
	var remedy := Button.new()
	remedy.text="Use remedy"
	remedy.set_meta("navigation_key","touch:use_potion")
	remedy.position=Vector2(360,180)
	remedy.size=Vector2(240,80)
	remedy.action_mode=BaseButton.ACTION_MODE_BUTTON_RELEASE
	hud.menu_layer.add_child(remedy)
	remedy.pressed.connect(func():
		clicked.append("Use remedy")
		hud.menu_layer.hide()
		router.set_gameplay_context()
	)
	router.gameplay_action_requested.connect(func(request: Dictionary):
		if request.action=="touch_more":
			_check(not router.is_action_pressed("aim_bow") and not router.is_action_pressed("fire_bow") and router.movement_vector().is_zero_approx(),"More opens after all gameplay contacts release")
			hud.menu_layer.show()
			router.set_ui_context("menu")
	)
	await adapter.more("use_potion")
	_check(clicked.count("Use remedy")==1 and int(adapter.menu_evidence.get("use_potion",0))==1,"More action uses its actual visible screen button exactly once")
	_check(router.is_action_pressed("aim_bow") and not router.is_action_pressed("fire_bow") and router.movement_vector().is_zero_approx(),"More reacquires Aim with a fresh contact without resuming Draw or movement")
	_check(int(adapter.menu_reacquisitions.get("aim_bow",0))==1 and int(adapter.action_evidence.aim_bow.pressed)==2,"Reacquisition records a second physical Aim press")
	adapter.release()
	await _frames(2)
	_check(not router.is_action_pressed("aim_bow") and not router.is_action_pressed("fire_bow"),"Final release clears both actual bow holds")
	adapter.move(Vector2.UP,true)
	router.set_ui_context("menu")
	await _frames(2)
	adapter.release()
	await _frames(2)
	_check(router.movement_vector().is_zero_approx() and adapter.contacts.is_empty(),"Context cancellation and cleanup leave no held input")
	_check(adapter.complete(),"All touch adapter input paths are exercised")
	_check(adapter.simultaneous_aim_fire==1,"Evidence retains actual simultaneous Aim/Draw contact")
	await _done(adapter,[consumer,control,hud,router],previous_emulation,previous_touch_emulation)

func _done(adapter, nodes: Array, previous_emulation: bool, previous_touch_emulation: bool) -> void:
	adapter.release()
	await _frames(2)
	print("COMMUNITY_TOUCH_INPUT "+JSON.stringify({"status":"pass" if failures.is_empty() else "fail","failures":failures,"counts":adapter.counts,"actions":adapter.evidence(),"gui_events":gui_events,"ui_surfaces":ui_surfaces,"held_samples":held_samples,"input_events":input_events,"actual_hud_builders":true,"original_style":original_style,"gameplay_acceptance":false,"physical_phone_coverage":false}))
	adapter.owner=null
	adapter=null
	for node in nodes: node.queue_free()
	await _frames(3)
	Input.emulate_mouse_from_touch=previous_emulation
	Input.emulate_touch_from_mouse=previous_touch_emulation
	quit(0 if failures.is_empty() else 1)

func _sample_hold(label: String,router,control,adapter) -> void:
	held_samples.append({"label":label,"ticks_ms":Time.get_ticks_msec(),"process_frame":Engine.get_process_frames(),"physics_frame":Engine.get_physics_frames(),
		"snapshot_frame":router._snapshot_frame,"guard_snapshot":router._action_snapshot.get("block",{}).duplicate(true),"virtual_actions":router._virtual_actions.duplicate(true),
		"pending_pressed":router._pending_pressed.duplicate(true),"awaiting_release":router._awaiting_release.duplicate(true),"suppressed_frame":router._suppressed_frame,
		"active_device":router.active_device,"context":router.get_context(),"visible_controls":control.is_gameplay_visible(),"action_touches":control.action_touches.duplicate(true),
		"down_touches":control._down_touches.duplicate(true),"cancelled_touches":control._cancelled_touches.duplicate(true),"adapter_contacts":str(adapter.contacts)})

func _exercise_scroll(surface: String, hud, presentation, menu, dialogue, adapter) -> void:
	var scroll := ScrollContainer.new()
	scroll.position=Vector2(40,80)
	scroll.size=Vector2(260,150)
	hud.menu_layer.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	rows.set_meta("menu_button_width",200.0)
	rows.set_meta("menu_button_height",65.0)
	scroll.add_child(rows)
	presentation.dialogue_actions=rows
	var before := clicked.size()
	var requests_before := requests.size()
	var buttons: Array[Button]=[]
	for index in range(6):
		var label := surface+" Target "+str(index)
		var callback := func(value: String=label): clicked.append(value)
		# Actual builders retain production filters and click ownership.
		var button: Button=menu._add_menu_button(rows,label,callback) if surface=="menu" else dialogue._add_topic_navigation_button(label,"fixture_"+str(index),callback)
		button.custom_minimum_size=Vector2(200,65)
		buttons.append(button)
	for observed: Control in [scroll,scroll.get_v_scroll_bar(),rows,buttons[0],buttons[1]]:
		observed.gui_input.connect(func(event: InputEvent, source: Control=observed):
			if gui_events.size()>=512: return
			var entry := {"surface":surface,"owner":str(source.name),"type":source.get_class(),"event":event.get_class(),"frame":Engine.get_process_frames(),"scroll":scroll.scroll_vertical}
			if event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag: entry["position"]=str(event.position)
			if event is InputEventMouseButton or event is InputEventScreenTouch: entry["pressed"]=event.pressed
			if event is InputEventMouseMotion or event is InputEventScreenDrag: entry["relative"]=str(event.relative)
			gui_events.append(entry)
		)
	await _frames(4)
	await adapter.button(buttons[0])
	await adapter.button(buttons[-1])
	var activated := clicked.slice(before)
	var scrolled := scroll.scroll_vertical>0
	var native_motion := gui_events.any(func(row: Dictionary): return row.surface==surface and row.type=="ScrollContainer" and row.event=="InputEventMouseMotion")
	ui_surfaces[surface]={"clicked":activated,"scrolled":scrolled,"native_motion":native_motion,"gameplay_requests":requests.size()-requests_before}
	_check(activated==[surface+" Target 0",surface+" Target 5"],"Screen presses/scrolls reach only the two requested menu buttons")
	_check(scrolled,"Real styled menu/dialogue rows scroll through native dispatch")
	_check(native_motion,"Native ScrollContainer receives the emulated motion originating from screen drag")
	_check(requests.size()==requests_before,"HUD-owned screen presses and drags dispatch no gameplay action")
	presentation.dialogue_actions=null
	scroll.queue_free()
	await _frames(3)

func _frames(count: int) -> void:
	for index in range(count): await process_frame

func _check(condition: bool, label: String) -> void:
	if not condition: _fail(label)

func _fail(reason: String) -> void:
	failures.append(reason)
	push_error(reason)
