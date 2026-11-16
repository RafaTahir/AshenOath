extends SceneTree
const Cast = preload("res://scripts/models/living_cast_model.gd")
const Bindings = preload("res://scripts/models/input_binding_model.gd")
const Clock = preload("res://scripts/core/sim_clock.gd")
const Canonical = preload("res://scripts/core/canonical_state.gd")
const Router = preload("res://scripts/input_router.gd")
const Hud = preload("res://scripts/hud.gd")
const Inventory = preload("res://scripts/inventory_manager.gd")
const Vendor = preload("res://scripts/vendor_service.gd")
const Life = preload("res://scripts/greyfen_life_controller.gd")
const Saga = preload("res://scripts/saga_activities.gd")
var checks: int = 0
var failures: Array[String] = []
var receipts: Array[Dictionary] = []
var selections: Array[Dictionary] = []
var _inventory: Inventory
var _vendor: Vendor
var _scene_completed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)

func _cast_replay(seed_value: int) -> Dictionary:
	var model: Cast = Cast.new()
	model.reset(seed_value)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/cast_life.json"))
	var ids: Array[String] = ["blacksmith_tor","mira","rook"]
	var reactions: Array[Dictionary] = []
	var observe: Callable = func(id: String, kind: String) -> void: reactions.append({"tick":model.clock.tick,"id":id,"kind":kind})
	model.awareness_changed.connect(observe)
	for id: String in ids:
		model.register_actor(id,Cast.ROUTINE_PROFILES[id],Vector3.ZERO)
	var frames: Array[String] = []
	var double_bookings: int = 0
	for tick: int in 600:
		model.advance(Clock.TICK_DT)
		var chapter: int = mini(2,tick / 200)
		var report: String = ["private","public","retained"][chapter]
		var phase: String = ["morning","midday","evening"][chapter]
		model.set_chapter(report,phase)
		var minute: float = [480.0,780.0,1140.0][chapter]
		if tick % 200 == 0:
			for station: String in model.activity_reservations.keys():
				model.release_station(station,model.reservation_owner(station))
			for id: String in ids:
				var definition: Dictionary = {"work":[1,0,1],"rest":[2,0,2],"errand":[3,0,3]}
				var intent: Dictionary = model.scheduled_intent(data,id,definition,Cast.ROUTINE_PROFILES[id],minute)
				model.actors[id].profile = intent
				var station: String = "station:" + str(model.rng.range_int(0,1))
				var owner: String = model.reservation_owner(station)
				var reserved: bool = model.reserve_station(station,id)
				if owner != "" and owner != id and reserved: double_bookings += 1
				model.actors[id].bark = model.post_report_line(report,chapter,report == "public")
		for index: int in ids.size():
			var id: String = ids[index]
			model.proximity(id,3.5 if tick % 90 < 30 else 5.0,false,true,true)
		model.stage_gathering(chapter == 2)
		var state: Dictionary = model.snapshot()
		var digest: String = Canonical.digest(state)
		if digest == "": double_bookings += 1
		frames.append(digest)
	model.awareness_changed.disconnect(observe)
	return {"digest":Canonical.digest({"frames":frames,"reactions":reactions}),"double_bookings":double_bookings,"reactions":reactions,"snapshot":model.snapshot()}

func _cast_checks() -> void:
	var first: Dictionary = _cast_replay(44017)
	var second: Dictionary = _cast_replay(44017)
	_check(first.digest != "" and first == second,"600-tick cast replay is bit-identical across all three phases/reports")
	_check(int(first.double_bookings) == 0,"station reservations never double-book")
	_check(first.reactions.size() == 3,"each nearby actor greets once without repeat farming")
	_check(int(first.snapshot.tick) == 600 and first.snapshot.phase == "evening" and first.snapshot.report == "retained","simulation clock and chapter state advance together")
	_check(_cast_replay(44018).digest != first.digest,"changed seed changes cast replay")
	var model: Cast = Cast.new()
	model.register_actor("worker",{},Vector3.ZERO)
	_check(not model.proximity("worker",4.01,false,true,true),"greeting radius excludes beyond four metres")
	_check(not model.proximity("worker",4.0,true,true,true),"sleep does not greet")
	_check(model.proximity("worker",4.0,false,true,true),"visible awake actor greets at four metres")
	_check(not model.proximity("worker",3.0,false,true,true),"approach greeting is once-only")
	_check(model.reserve_station("forge","worker") and not model.reserve_station("forge","other"),"exclusive reservation rejects a second actor")
	_check(not model.release_station("forge","other") and model.release_station("forge","worker"),"only the reservation owner releases")
	_check(model.record_awareness("worker","fear") and not model.record_awareness("worker","attention"),"danger outranks an existing greeting")
	_check(model.post_report_line("private",0,false) == "" and model.post_report_line("retained",0,false) == "","private history is not public gossip")
	_check(model.post_report_line("public",0,true) != "","public report produces its authored bark")
	_check(model.stage_gathering(true) and not model.stage_gathering(true) and model.gathering_positions().size() == 5,"gathering projection changes once and retains authored positions")
	var tick: int = model.clock.tick
	model.advance(0.0)
	_check(model.clock.tick == tick,"pause does not advance cast cooldowns")
	_check(Life != null and Saga != null,"cast and regional scene adapters compile")
	var source: String = FileAccess.get_file_as_string("res://scripts/greyfen_life_controller.gd")
	_check(not source.contains("Time.get_ticks") and not source.contains("randf("),"life coordinator has no wall-clock/unseeded randomness")
	print("Living cast: 600 ticks x2; SHA-256 %s; three phases/reports; no double-bookings; 4m awareness." % first.digest)

func _binding_checks() -> void:
	var model: Bindings = Bindings.new()
	model.load_bindings({"interact":[{"type":"key","keycode":KEY_E}],"run":[{"type":"key","keycode":KEY_SHIFT}],"light_attack":[{"type":"mouse","button":MOUSE_BUTTON_LEFT}],"fire_bow":[{"type":"mouse","button":MOUSE_BUTTON_LEFT}]})
	var before: Dictionary = model.save_bindings()
	var changed: Dictionary = model.remap("interact",{"type":"key","keycode":KEY_SHIFT})
	_check(bool(changed.ok) and changed.conflict == "run","remapping swaps one conflict atomically")
	_check(model.bindings.run == before.interact and model.bindings.interact == before.run,"displaced binding preserved")
	var restored: Bindings = Bindings.new()
	restored.load_bindings(model.save_bindings())
	_check(restored.save_bindings() == model.save_bindings(),"custom remaps round-trip losslessly")
	_check(model.conflicts("fire_bow",{"type":"mouse","button":MOUSE_BUTTON_LEFT}).is_empty(),"legitimate weapon-family shared binding is retained")
	_check(not bool(model.remap("interact",{"type":"key","keycode":0}).ok),"invalid remap rejected")
	var snapshot: Dictionary = {"run":{"held":true},"light_attack":{"held":true},"block":{"held":true},"aim_bow":{"held":true},"fire_bow":{"held":true}}
	for context: String in ["menu","dialogue","pause","settings","transition","death","minigame"]:
		model.set_context(context)
		var frame: Dictionary = model.emit_frame(10,Vector2.ONE,Vector2.ONE,snapshot).to_dict()
		_check(frame.buttons == 0 and frame.move_x == 0 and frame.move_y == 0,"context isolation: " + context)
	model.set_context("gameplay")
	var active: Dictionary = model.emit_frame(11,Vector2(0,-1),Vector2(0.25,-0.5),snapshot).to_dict()
	_check(active.buttons == (1|4|32|256|512) and active.move_y == -1,"clean semantic frame bitmask")
	_check(model.emit_frame(12,Vector2.ZERO,Vector2.ZERO,{"light_attack":{"held":false,"pressed":true,"released":true}}).buttons == 4,"tap between physics ticks survives in the replay frame")
	_check(model.emit_frame(13,Vector2.ZERO,Vector2.ZERO,{}).buttons == 0,"tap pulse releases on the following frame")
	model.push_context("dialogue")
	_check(not model.allows_action("light_attack") and model.allows_action("ui_accept"),"nested dialogue allows only UI actions")
	_check(model.pop_context() == "gameplay" and model.allows_action("light_attack"),"context stack restores gameplay")
	model.set_context("invalid")
	_check(model.context() == "menu","unknown contexts fail closed")
	print("Input model: remap swap/serialization, shared bindings, context stack and deterministic frame bitmasks pass.")

func _button(branch: Node, key: String) -> Button:
	for node: Button in branch.find_children("*","Button",true,false):
		if str(node.get_meta("navigation_key","")) == key: return node
	return null

func _buy(vendor_id: String, item_id: String, quantity: int) -> void:
	receipts.append(_vendor.buy(vendor_id,item_id,quantity,_inventory))
func _sell(vendor_id: String, item_id: String, quantity: int) -> void:
	receipts.append(_vendor.sell(vendor_id,item_id,quantity,_inventory))

func _scene_checks() -> void:
	var orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var router: Router = Router.new()
	root.add_child(router)
	router.activate_touch()
	router.begin_context("gameplay")
	await physics_frame
	await physics_frame
	router.set_virtual_axes(Vector2(0.4,-0.8),Vector2.ZERO)
	await physics_frame
	_check(router.input_frame.move_y < -0.79 and router.input_frame.tick > 0,"hardware coordinator emits fixed-tick movement frame")
	router.begin_context("dialogue")
	await physics_frame
	await physics_frame
	_check(router.input_frame.buttons == 0 and router.input_frame.move_x == 0 and router.input_frame.move_y == 0,"scene router blocks movement during dialogue")
	_inventory = Inventory.new()
	_inventory.load_items("res://data/items.json")
	_inventory.coin = 100
	_inventory.items["redroot_potion"] = 6
	_inventory.items["iron_trap"] = 5
	_vendor = Vendor.new()
	_vendor.load_vendors("res://data/vendors.json")
	var hud: Hud = Hud.new()
	root.add_child(hud)
	hud.set_input_source(router)
	hud.vendor_purchase_requested.connect(_buy)
	hud.vendor_sale_requested.connect(_sell)
	hud.journey_load_requested.connect(func(selection: Dictionary) -> void: selections.append(selection))
	hud.state._preparation_selection["vendor:tor_forge"] = {"kind":"item","id":"bodkin_arrow"}
	hud.show_vendor("tor_forge",_vendor,_inventory)
	await process_frame
	var buy: Button = _button(hud,"action:buy:bodkin_arrow")
	_check(buy != null and not buy.disabled,"Tor shop mounts a buy intent")
	if buy != null: buy.pressed.emit()
	_check(receipts.size() == 1 and bool(receipts[0].ok) and _inventory.coin == 96,"Tor UI intent executes pure economy receipt")
	hud.state._preparation_selection["vendor:mira_apothecary"] = {"kind":"item","id":"bitterleaf_tonic"}
	hud.show_vendor("mira_apothecary",_vendor,_inventory)
	await process_frame
	buy = _button(hud,"action:buy:bitterleaf_tonic")
	_check(buy != null and not buy.disabled,"Mira shop mounts a buy intent")
	if buy != null: buy.pressed.emit()
	_check(receipts.size() == 2 and bool(receipts[1].ok) and _inventory.coin == 91,"Mira UI intent executes pure economy receipt")
	var sell: Button = _button(hud,"action:sell:redroot_potion")
	_check(sell != null and not sell.disabled,"Mira shop offers surplus without consuming road reserves")
	if sell != null: sell.pressed.emit()
	_check(receipts.size() == 3 and bool(receipts[2].ok) and _inventory.items.redroot_potion == 5,"sell UI intent executes once")
	hud.hide_menus()
	hud.set_new_game_ready(true)
	hud.set_opening_preparation("ready","Greyfen is ready.",1.0)
	var recovery: Dictionary = {"available":true,"status":"ready","selection":{"slot_id":"checkpoint"},"summary":{"title":"Road checkpoint","place":"Wychwood","chapter":"Road of Crows","time_label":"Recorded checkpoint"}}
	var unavailable: Dictionary = {"available":false,"status":"unavailable","recovery":[recovery],"summary":{"title":"Selected journey","place":"Greyfen"}}
	hud.set_journey_models({"continue":unavailable})
	hud.show_main_menu()
	await process_frame
	_check(is_instance_valid(hud.state._journey_card) and hud.state._journey_card.text.contains("Selected journey"),"saved journey card mounts from selected model")
	var recover: Button = _button(hud,"recovery_option:0")
	_check(recover != null and not recover.disabled,"recoverable journey remains available")
	hud.journey_load_view._request_journey_selection("recovery_option:0")
	_check(selections.size() == 1 and selections[0].slot_id == "checkpoint","journey view emits exact selected source once")
	hud.begin_journey_load(recovery)
	_check(hud.state._journey_load_active and hud.state.loading_layer.visible,"journey preparation opens protected progress")
	hud.end_journey_load(false,"Cancelled for test")
	_check(not hud.state._journey_load_active and hud.state.menu_layer.visible,"cancel restores the prior menu")
	hud.show_pause_menu()
	await process_frame
	_check(hud.state.active_menu == "pause","pause shell remains functional")
	hud.clear_journey_transients(true)
	hud.queue_free()
	router.queue_free()
	await process_frame
	await process_frame
	_vendor.free()
	_inventory.free()
	_vendor = null
	_inventory = null
	_check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == orphans,"HUD/input teardown leaves no orphan nodes")
	_scene_completed = true
	print("HUD/shop: mounted real hud.gd; Tor/Mira buy and surplus sell signals; recovery selection, loading cancel and pause; no orphan growth.")

func _run() -> void:
	_cast_checks()
	_binding_checks()
	await _scene_checks()
	_check(_scene_completed,"HUD integration reaches completed teardown")
	print("PHASE 4 CAST INPUT AND HUD: %s (%d checks)" % ["PASS" if failures.is_empty() else "FAIL",checks])
	for issue: String in failures: print("FAIL: " + issue)
	quit(0 if failures.is_empty() else 1)
