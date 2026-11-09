extends RefCounted

## Acceptance-only input adapter. Reads live controls and sends screen events;
## never calls their action handlers, writes progression or moves an actor.
var owner
var contacts: Dictionary = {}
var counts := {"screen_touch":0,"screen_drag":0,"ui":0,"move":0,"look":0,"action":0}
const ACTION_IDS := ["interact","pause","open_inventory","touch_more","target_lock","cycle_arrow","jump","heavy_attack","oathfire_beam","block","light_attack","dodge","aim_bow","fire_bow"]
var action_contacts: Dictionary = {}
var action_evidence: Dictionary = {}
var menu_evidence: Dictionary = {}
var menu_reacquisitions: Dictionary = {}
var ui_labels: Dictionary = {}
var simultaneous_aim_fire := 0
var scroll_gestures: Array[Dictionary]=[]

func controls():
	return owner.root.find_child("MobileTouchControls",true,false)

func contact(index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index=index
	event.position=point
	event.pressed=pressed
	if pressed: contacts[index]=point
	else: contacts.erase(index)
	Input.parse_input_event(event)
	counts.screen_touch+=1
	owner.input_events+=1

func drag(index: int, point: Vector2) -> void:
	if not contacts.has(index):
		owner._fail("Touch drag has no matching contact")
		return
	var event := InputEventScreenDrag.new()
	event.index=index
	event.position=point
	event.relative=point-Vector2(contacts[index])
	event.screen_relative=event.relative
	contacts[index]=point
	Input.parse_input_event(event)
	counts.screen_drag+=1
	owner.input_events+=1

func release() -> void:
	for id: String in action_contacts.keys(): hold_action(id,false)
	for index: int in contacts.keys(): contact(index,contacts[index],false)

func move(direction: Vector2, pressed: bool) -> void:
	if not pressed:
		if contacts.has(1): contact(1,contacts[1],false)
		return
	var control=controls()
	if control==null or not control.is_gameplay_visible():
		owner._fail("Touch movement has no visible gameplay controls")
		return
	var layout: Dictionary=control._layout
	var center: Vector2=layout.move_center
	if not contacts.has(1): contact(1,center,true)
	drag(1,center+direction*float(layout.move_travel))
	counts.move+=1

func action(id: String) -> void:
	hold_action(id,true)
	await owner._frames(2)
	hold_action(id,false)
	await owner._frames(3)

func hold_action(id: String, pressed: bool) -> void:
	if not pressed:
		if not action_contacts.has(id): return
		var index: int = action_contacts[id]
		if contacts.has(index): contact(index,contacts[index],false)
		action_contacts.erase(id)
		action_evidence[id].released += 1
		action_evidence[id].held_ms += maxi(0,Time.get_ticks_msec()-int(action_evidence[id].started_ms))
		return
	if not owner.failures.is_empty(): return
	if action_contacts.has(id) and contacts.has(int(action_contacts[id])): return
	var control=controls()
	if id not in ACTION_IDS or control==null or not control.is_gameplay_visible() or not control.action_centers.has(id) or not control._action_enabled(id):
		owner._fail("Touch action has no visible control: "+id)
		return
	var index := 3 + ACTION_IDS.find(id)
	var point: Vector2=control.action_centers[id]
	contact(index,point,true)
	action_contacts[id]=index
	if not action_evidence.has(id): action_evidence[id]={"pressed":0,"released":0,"held_ms":0,"started_ms":0}
	action_evidence[id].pressed += 1
	action_evidence[id].started_ms=Time.get_ticks_msec()
	if id=="fire_bow" and action_contacts.has("aim_bow"): simultaneous_aim_fire+=1
	counts.action+=1

func more(id: String) -> void:
	# Menus deliberately cancel gameplay fingers. Only an already-held guard
	# or aim is deliberately reacquired afterward; attacks never auto-resume.
	var reacquire: Array[String]=[]
	for action_id: String in ["aim_bow","block"]:
		if action_contacts.has(action_id): reacquire.append(action_id)
	release()
	await action("touch_more")
	if not owner.failures.is_empty(): return
	var target: Button
	var deadline := Time.get_ticks_msec()+10000
	while target==null and Time.get_ticks_msec()<deadline:
		for candidate: Button in owner.root.find_children("*","Button",true,false):
			if candidate.is_visible_in_tree() and not candidate.disabled and str(candidate.get_meta("navigation_key",""))=="touch:"+id:
				target=candidate
				break
		if target==null: await owner._frames(1)
	if target==null:
		owner._fail("More menu has no enabled visible action: "+id)
		return
	await button(target)
	menu_evidence[id]=int(menu_evidence.get(id,0))+1
	await owner._frames(3)
	var control=controls()
	if control==null or not control.is_gameplay_visible():
		owner._fail("More action did not restore visible gameplay controls: "+id)
		return
	for action_id: String in reacquire:
		if control.action_centers.has(action_id):
			hold_action(action_id,true)
			menu_reacquisitions[action_id]=int(menu_reacquisitions.get(action_id,0))+1
	await owner._frames(2)

func look(turn: float, sensitivity: float) -> void:
	var control=controls()
	if control==null or not control.is_gameplay_visible():
		owner._fail("Touch look has no visible gameplay controls")
		return
	var layout: Dictionary=control._layout
	var area: Rect2=layout.look_region
	# Keep the entire gesture in the unobstructed upper look region. Larger
	# turns are completed by successive normal camera corrections, not warps.
	var start := Vector2(area.get_center().x,area.position.y+minf(64.0,area.size.y*0.2))
	var pixels := -turn*float(layout.unit_scale)/maxf(sensitivity*2.0*float(control.look_sensitivity),0.00001)
	var finish := start+Vector2(clampf(pixels,-area.size.x*0.35,area.size.x*0.35),0)
	contact(2,start,true)
	drag(2,finish)
	await owner._frames(2)
	contact(2,finish,false)
	counts.look+=1

func button(target: Button) -> void:
	for attempt in range(24):
		if not is_instance_valid(target) or target.disabled or not target.is_visible_in_tree():
			owner._fail("Touch menu target disappeared before activation")
			return
		var shown := target.get_global_rect().intersection(owner.root.get_visible_rect())
		var ancestor: Node=target.get_parent()
		var scrolling: ScrollContainer
		while ancestor!=null:
			if ancestor is Control and ancestor.clip_contents:
				shown=shown.intersection(ancestor.get_global_rect())
				if ancestor is ScrollContainer and not ancestor.get_global_rect().encloses(target.get_global_rect()): scrolling=ancestor
			ancestor=ancestor.get_parent()
		if shown.size.x>=12.0 and shown.size.y>=12.0:
			var point := shown.get_center()
			var label := target.text
			contact(0,point,true)
			await owner._frames(2)
			contact(0,point,false)
			counts.ui+=1
			ui_labels[label]=int(ui_labels.get(label,0))+1
			await owner._frames(4)
			return
		if scrolling==null:
			owner._fail("Touch menu target has no reachable visible area")
			return
		var area := scrolling.get_global_rect().intersection(owner.root.get_visible_rect())
		if area.size.x<24 or area.size.y<24:
			owner._fail("Touch menu scroll container is clipped")
			return
		var direction := -1.0 if target.get_global_rect().get_center().y>area.get_center().y else 1.0
		var start := Vector2(area.end.x-18.0,area.get_center().y-direction*area.size.y*0.3)
		var trace := {"attempt":attempt,"target":target.text,"target_rect":str(target.get_global_rect()),"clipped_rect":str(shown),"scroll_rect":str(scrolling.get_global_rect()),"scrollbar_rect":str(scrolling.get_v_scroll_bar().get_global_rect()),"start":str(start),"before":scrolling.scroll_vertical,"ancestors":[]}
		var traced: Node=target
		while traced!=null:
			if traced is Control:
				trace.ancestors.append({"name":str(traced.name),"type":traced.get_class(),"rect":str(traced.get_global_rect()),"clip":traced.clip_contents,"mouse_filter":traced.mouse_filter})
			traced=traced.get_parent()
		contact(0,start,true)
		for step in range(1,7):
			drag(0,start+Vector2(0,direction*area.size.y*0.6*float(step)/6.0))
			await owner._frames(1)
		contact(0,contacts[0],false)
		await owner._frames(8)
		trace["after"]=scrolling.scroll_vertical
		scroll_gestures.append(trace)
	owner._fail("Touch scrolling did not expose the requested menu action")

func complete() -> bool:
	if not contacts.is_empty() or not action_contacts.is_empty(): return false
	for row: Dictionary in action_evidence.values():
		if int(row.pressed)!=int(row.released): return false
	return counts.screen_touch>0 and counts.screen_drag>0 and counts.ui>0 and counts.move>0 and counts.look>0 and counts.action>0

func evidence() -> Dictionary:
	return {"actions":action_evidence.duplicate(true),"menu_actions":menu_evidence.duplicate(),"menu_reacquisitions":menu_reacquisitions.duplicate(),"ui_labels":ui_labels.duplicate(),"simultaneous_aim_fire":simultaneous_aim_fire,"open_contacts":contacts.size(),"scroll_gestures":scroll_gestures.duplicate(true)}
