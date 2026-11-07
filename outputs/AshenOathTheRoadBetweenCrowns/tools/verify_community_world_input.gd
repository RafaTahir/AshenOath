extends SceneTree

## Native acceptance, never a progression shortcut. The runner installs one
## explicit boundary save before startup. Everything after Continue uses normal
## keyboard/mouse input; game state, route queries and snapshots are read-only.
## No preload: the isolated project mounts the exact frozen pack set first.
var options: Dictionary = {}
var game
var rules
var topology
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var completed_work: Array[String] = []
var held: Dictionary = {}
var output := ""
var case_id := ""
var input_events := 0
var start_ms := 0
var region := ""
var report_extra: Dictionary={}

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--") and argument.contains("="):
			var split := argument.substr(2).split("=",true,1)
			options[split[0]]=split[1]
	output=str(options.get("output",""))
	case_id=str(options.get("case",""))
	start_ms=Time.get_ticks_msec()
	if output=="" or case_id not in ["lantern_crossing","lantern_ferry","hearth_distributed","hearth_protected"]:
		_fail("Explicit output and supported case are required")
		await _finish()
		return
	if DisplayServer.get_name().to_lower()=="headless":
		_fail("Actual-input acceptance requires a rendered viewport")
		await _finish()
		return
	var version: Dictionary=Engine.get_version_info()
	if int(version.major)!=4 or int(version.minor)!=6 or int(version.patch)!=3:
		_fail("Acceptance requires the pinned Godot 4.6.3 runtime")
		await _finish()
		return
	if not ProjectSettings.load_resource_pack(str(options.get("root-pack","")),true):
		_fail("Frozen root pack did not mount")
		await _finish()
		return
	var folder := str(options.get("packs",""))
	var pack_names := DirAccess.get_files_at(folder)
	pack_names.sort()
	for pack: String in pack_names:
		if pack.ends_with(".pck") and not ProjectSettings.load_resource_pack(folder.path_join(pack),true):
			_fail("Secondary pack did not mount: "+pack)
	if not failures.is_empty():
		await _finish()
		return
	rules=load("res://scripts/community_campaign.gd")
	topology=load("res://scripts/world_sector_manifest.gd")
	if rules==null or topology==null:
		_fail("Community rules or topology missing from mounted packs")
		await _finish()
		return
	region="lantern_reach" if case_id.begins_with("lantern") else "hearthward"
	var viewport := Vector2i(960,540) if options.get("viewport","desktop")=="touch" else Vector2i(1280,720)
	DisplayServer.window_set_size(viewport)
	DisplayServer.window_move_to_foreground()
	var scene := load("res://scenes/main.tscn") as PackedScene
	if scene==null:
		_fail("Main scene is missing from mounted packs")
		await _finish()
		return
	game=scene.instantiate()
	root.add_child(game)
	await _frames(4)
	await _button("Continue")
	await _ready("old_mill" if region=="lantern_reach" else "undercroft")
	if failures.is_empty():
		_check(int(game.story_state.get_flag("campaign_revision",1))==2,"Seed must explicitly be revision two")
		await _cross_boundary(region)
		await _snapshot("arrived")
	if failures.is_empty():
		if region=="lantern_reach": await _lantern()
		else: await _hearth()
	if failures.is_empty():
		await _save_reload("completed_region")
		await _cross_boundary("old_mill" if region=="lantern_reach" else "undercroft")
		await _cross_boundary(region)
		await _snapshot("return_route")
	await _finish()

func _lantern() -> void:
	await _board("Hear the practical needs")
	# Movement must discard the first partial operation; earned work then survives
	# a real Quick Save / Main Menu / Continue round trip.
	await _interact("community:work:kitchen_trestle")
	await _seconds(0.7)
	_key(KEY_S,true)
	await _seconds(0.5)
	_key(KEY_S,false)
	_check(not _flag("community_work:kitchen_trestle"),"Interrupted trestle was not awarded")
	for id: String in ["kitchen_trestle","kitchen_screen","kitchen_places"]: await _task(id)
	await _save_reload("kitchen_prepared")
	var distribution := "central" if case_id=="lantern_crossing" else "households"
	await _board(str(rules.chapter("main_empty_tables").choices[distribution].label))
	await _operation("aftermath:main_empty_tables","community_aftermath:main_empty_tables",9.0)
	await _operation("survey:near","community_survey:near",8.0)
	# Initial survey uses the retained northern footway, never the unbuilt route.
	await _walk_direct(Vector3(2.5,1,-3.0))
	await _walk_direct(Vector3(10.5,1,-3.0))
	await _operation("survey:far","community_survey:far",8.0)
	await _walk_direct(Vector3(10.5,1,-3.0))
	await _walk_direct(Vector3(2.5,1,-3.0))
	var route := "crossing" if case_id=="lantern_crossing" else "ferry"
	await _board(str(rules.chapter("main_road_kept_open").choices[route].label))
	for id: String in rules.chapter("main_road_kept_open").choices[route].work: await _task(id)
	await _operation("aftermath:main_road_kept_open","community_route_load_carried",9.0)
	await _save_reload("first_load_carried")
	_check(not _flag("community_route_load_crossed"),"Loading a saved bundle does not award a passage")
	if route=="crossing":
		for point: Vector3 in [Vector3(3,1,0),Vector3(5,1,0),Vector3(7.5,1,0),Vector3(10.5,1,0)]: await _walk_direct(point)
	else:
		await _interact("community:ferry")
		await _seconds(1.2)
		await _tap(KEY_ESCAPE)
		await _button("Resume")
		await _frames(8)
		_check(game.player.can_control and game.player.global_position.x<4.0,"Paused ferry returns control at its safe bank")
		_check(not _flag("community_route_load_crossed"),"Interrupted ferry does not award a passage")
		await _operation("ferry","community_route_load_crossed",15.0)
	await _wait_flag("community_route_load_crossed",true,3.0)
	await _operation("delivery","community_aftermath:main_road_kept_open",9.0)
	_check(not _flag("community_route_load_carried"),"Delivered bundle is released")
	_check(game.quests.is_completed("main_empty_tables") and game.quests.is_completed("main_road_kept_open"),"Both Lantern Reach chapters complete through enacted work")

func _hearth() -> void:
	await _board("Hear the practical needs")
	for id: String in ["refuge_bunks","refuge_shelves","refuge_places"]: await _task(id)
	await _save_reload("refuge_prepared")
	var records := "distributed" if case_id=="hearth_distributed" else "protected"
	await _board(str(rules.chapter("main_house_many_names").choices[records].label))
	await _operation("aftermath:main_house_many_names","community_aftermath:main_house_many_names",9.0)
	await _board("Open the meeting")
	for id: String in ["promise_meal","promise_alarm","promise_records"]: await _task(id)
	# The existing rest menu owns clock changes and life reconciliation.
	await _rest("Wait until morning")
	await _presence("morning")
	for id: String in ["anwen","nessa","vale"]:
		await _consent(id,true)
	await _consent("nessa",false)
	await _save_reload("consent_withdrawn")
	_check(game.story_state.get_flag("community_keeper_consent",{}).get("nessa")==false,"Explicit withdrawal survives reload")
	await _consent("nessa",true)
	await _rest("Wait until evening")
	await _presence("evening")
	await _board("Post only the answers actually given")
	await _operation("aftermath:main_what_we_promise","community_aftermath:main_what_we_promise",11.0)
	_check(game.quests.is_completed("main_house_many_names") and game.quests.is_completed("main_what_we_promise"),"Both Hearthward chapters complete through enacted work")

func _presence(shift: String) -> void:
	var present: Array[String]=[]
	var expected_cast: Array[String]=[]
	for id: String in rules.REGIONAL_ACTORS[region]:
		if rules.actor_present(id,region,float(game.day_night.get_time()),game.story_state,game.quests): expected_cast.append(id)
	for actor: Node3D in game.zone_root.find_children("*","Area3D",true,false):
		if not actor.has_meta("community_actor_id"): continue
		var id := str(actor.get_meta("community_actor_id"))
		var expected: bool=rules.actor_present(id,region,float(game.day_night.get_time()),game.story_state,game.quests)
		_check(actor.visible==expected,"Shift visibility: "+id)
		if expected: present.append(id)
		else: _check(actor.process_mode==Node.PROCESS_MODE_DISABLED and not actor.is_interaction_enabled(),"Absent actor is inactive: "+id)
	present.sort()
	expected_cast.sort()
	_check(present==expected_cast,"Every available actor in this shift is actually present")
	_check(present.size()<=8,"Community shift stays within eight visible canonical NPCs")
	var skeletons := 0
	for skeleton: Skeleton3D in root.find_children("*","Skeleton3D",true,false):
		if skeleton.is_visible_in_tree(): skeletons+=1
	_check(skeletons<=10,"Visible world skeletons remain within ten including Kael and Bracken")
	await _snapshot("shift_"+shift,{"present":present,"visible_skeletons":skeletons})

func _rest(label: String) -> void:
	var id := str(load("res://scripts/story_activity_director.gd").REST_PLACES[region].id)
	await _interact(id)
	await _dialogue_button(label)
	await _seconds(5.0)
	await _ready(region)

func _consent(id: String, accept: bool) -> void:
	if not failures.is_empty(): return
	await _interact(str(rules.ACTORS[id]))
	await _dialogue_button("Hear the shift they are offering." if accept else "Release the recorded shift.")
	if accept: await _dialogue_button("Record that answer, with the right to withdraw.")
	elif game.hud.dialogue_layer.visible: await _tap(KEY_ESCAPE)
	await _frames(10)
	_check(game.story_state.get_flag("community_keeper_consent",{}).get(id)==accept,"Participant's own answer recorded: "+id)
	await _snapshot("consent_"+id+"_"+str(accept))

func _board(label: String) -> void:
	await _interact("community:board")
	await _dialogue_button(label)
	await _frames(10)

func _task(id: String) -> void:
	if not failures.is_empty(): return
	_check(not _flag("community_work:"+id),"Task must be unearned before input: "+id)
	await _operation("work:"+id,"community_work:"+id,float(rules.data().work[id].seconds)+6.0)
	if failures.is_empty(): completed_work.append(id)
	await _snapshot("work_"+id)

func _operation(id: String, flag: String, timeout: float) -> void:
	await _interact("community:"+id)
	await _wait_flag(flag,true,timeout)

func _interact(id: String) -> void:
	if not failures.is_empty(): return
	await _ready(region)
	var area: Node3D
	for candidate: Node3D in game.zone_root.find_children("*","Area3D",true,false):
		if str(candidate.get("interaction_id"))==id and candidate.is_visible_in_tree():
			area=candidate
			break
	if area==null:
		_fail("Visible interaction is missing: "+id)
		return
	# Pick a clear approach around the actual object; never move a prop, actor
	# or player to repair the fixture. Rest benches and beds block their back edge.
	var approach := Vector3.INF
	var best_distance := INF
	for index in range(8):
		var angle := float(index)*TAU/8.0
		var candidate := _ground_point(area.global_position+Vector3(sin(angle),0,cos(angle))*1.2)
		if not candidate.is_finite() or game.spatial_service.is_position_occupied(candidate,0.36,1.65): continue
		var distance := candidate.distance_squared_to(game.player.global_position)
		if distance<best_distance:
			best_distance=distance
			approach=candidate
	if not approach.is_finite():
		_fail("No unobstructed player approach to "+id)
		return
	await _walk_to(approach)
	if not failures.is_empty(): return
	await _face(area.global_position)
	var deadline := Time.get_ticks_msec()+4000
	while Time.get_ticks_msec()<deadline and game.active_interactable!=area: await process_frame
	if game.active_interactable!=area:
		_fail("Normal interaction selection did not select "+id+"; selected="+str(game.active_interactable))
		return
	await _tap(KEY_E)
	await _frames(6)

func _dialogue_button(label: String) -> void:
	if not failures.is_empty(): return
	if not game.hud.dialogue_layer.visible:
		_fail("Dialogue did not open before action: "+label)
		return
	for page in range(48):
		if game.hud.dialogue_page_index>=game.hud.dialogue_pages.size()-1: break
		await _tap(KEY_ENTER)
		await _frames(3)
	await _button(label)
	await _frames(6)

func _button(prefix: String) -> void:
	if not failures.is_empty(): return
	var deadline := Time.get_ticks_msec()+(120000 if prefix in ["Continue","New Game"] else 10000)
	var visible := false
	while not visible and Time.get_ticks_msec()<deadline:
		for candidate: Button in root.find_children("*","Button",true,false):
			if candidate.is_visible_in_tree() and not candidate.disabled and candidate.text.trim_prefix("Commit: ").begins_with(prefix):
				visible=true
				break
		if not visible: await process_frame
	if not visible:
		_fail("Requested visible menu action did not become available: "+prefix)
		return
	for index in range(64):
		var focused := root.gui_get_focus_owner() as Button
		if focused!=null and focused.is_visible_in_tree() and not focused.disabled and focused.text.trim_prefix("Commit: ").begins_with(prefix):
			await _tap(KEY_ENTER)
			return
		await _tap(KEY_TAB)
	_fail("Visible menu action is not keyboard reachable: "+prefix)

func _save_reload(label: String) -> void:
	if not failures.is_empty(): return
	var before: Dictionary=game.story_state.save_state().flags.duplicate(true)
	await _tap(KEY_ESCAPE)
	await _button("Quick Save")
	await _frames(12)
	if not game.hud.menu_layer.visible: await _tap(KEY_ESCAPE)
	await _button("Main Menu")
	await _button("Continue")
	await _ready(region)
	var after: Dictionary=game.story_state.save_state().flags
	for key: String in before:
		if key.begins_with("community_") or key.begins_with("campaign_"):
			_check(before[key]==after.get(key),"Save/load retained "+key)
	await _snapshot("reload_"+label)

func _cross_boundary(destination: String) -> void:
	if not failures.is_empty(): return
	var source := str(game.current_zone_id)
	var edge: Dictionary=topology.connection_between(source,destination)
	if edge.is_empty():
		_fail("Physical edge is missing: "+source+" -> "+destination)
		return
	var points: PackedVector3Array=topology.connector_points(edge)
	await _walk_to(points[0])
	for point: Vector3 in points:
		if str(game.current_zone_id)!=source: break
		await _walk_direct(point,source)
	if str(game.current_zone_id)==source:
		await _walk_direct(points[-1]+topology.direction(str(edge.id))*2.0,source)
	await _ready(destination)

func _walk_to(target: Vector3) -> void:
	if not failures.is_empty(): return
	var route: Array=_live_route(target)
	if route.is_empty():
		_fail("Read-only navigation found no route to "+str(target))
		return
	for point: Vector3 in route: await _walk_direct(point)

func _ground_point(point: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(Vector3(point.x,1.6,point.z),Vector3(point.x,-0.8,point.z),1)
	query.exclude=[game.player.get_rid()]
	query.collide_with_areas=false
	var hit: Dictionary=game.player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return Vector3.INF
	var ground: Vector3=hit.position
	# These compact regions and their joining corridors have flat ground and a
	# .185 m deck. A table top, roof, water bed or steep obstacle is not a path.
	if ground.y < -0.05 or ground.y > 0.35 or (hit.normal as Vector3).y<0.85: return Vector3.INF
	return ground

func _live_segment(start: Vector3, end: Vector3) -> bool:
	if not game.spatial_service.validate_runtime_segment(start,end,0.70,game.player): return false
	for index in range(1,maxi(2,ceili(start.distance_to(end)/0.4))):
		var point := start.lerp(end,float(index)/float(maxi(2,ceili(start.distance_to(end)/0.4))))
		if not _ground_point(point).is_finite(): return false
	return true

func _live_route(target: Vector3) -> Array[Vector3]:
	var start := _ground_point(game.player.global_position)
	var finish := _ground_point(target)
	if not start.is_finite() or not finish.is_finite(): return []
	if _live_segment(start,finish): return [start,finish]
	# Read-only path planning over live collision. The game's construction-time
	# route helper intentionally ignores props, so it cannot certify this input
	# route. Every graph edge is walked with the real player controller below.
	var graph := AStar3D.new()
	var cells: Dictionary={}
	var points: Dictionary={}
	var half: Vector2=topology.bounds(str(game.current_zone_id))+Vector2(10,10)
	var next_id := 1
	for x in range(-int(half.x),int(half.x)+1):
		for z in range(-int(half.y),int(half.y)+1):
			var point := _ground_point(Vector3(x,0,z))
			if not point.is_finite() or game.spatial_service.is_position_occupied(point,0.36,1.65): continue
			graph.add_point(next_id,point)
			cells[Vector2i(x,z)]=next_id
			points[next_id]=point
			next_id+=1
	for cell: Vector2i in cells:
		for step: Vector2i in [Vector2i(1,0),Vector2i(0,1),Vector2i(1,1),Vector2i(1,-1)]:
			if not cells.has(cell+step): continue
			var first: int=cells[cell]
			var second: int=cells[cell+step]
			if _live_segment(points[first],points[second]): graph.connect_points(first,second)
	var first_id := next_id
	var last_id := next_id+1
	graph.add_point(first_id,start)
	graph.add_point(last_id,finish)
	for endpoint: int in [first_id,last_id]:
		var at := graph.get_point_position(endpoint)
		for id: int in points:
			if at.distance_to(points[id])<=1.8 and _live_segment(at,points[id]): graph.connect_points(endpoint,id)
	var result: Array[Vector3]=[]
	for point: Vector3 in graph.get_point_path(first_id,last_id): result.append(point)
	return result

func _walk_direct(target: Vector3, stop_zone: String="") -> void:
	if not failures.is_empty(): return
	var deadline := Time.get_ticks_msec()+25000
	while Time.get_ticks_msec()<deadline:
		if stop_zone!="" and (str(game.current_zone_id)!=stop_zone or game.zone_transition_pending): break
		var offset: Vector3=target-game.player.global_position
		offset.y=0
		if offset.length()<0.33: break
		if not game.player.can_control or paused:
			_fail("Movement lost normal gameplay ownership before destination")
			break
		await _face(target)
		_key(KEY_W,true)
		await _frames(2)
	_release()
	if Time.get_ticks_msec()>=deadline: _fail("Movement did not reach "+str(target)+" from "+str(game.player.global_position))

func _face(target: Vector3) -> void:
	var offset: Vector3=target-game.player.global_position
	if Vector2(offset.x,offset.z).length()<0.02: return
	var camera=game.camera_rig
	var desired := atan2(-offset.x,-offset.z)
	var turn := angle_difference(float(camera.yaw),desired)
	if absf(turn)<0.025: return
	var event := InputEventMouseMotion.new()
	event.device=0
	event.relative=Vector2(-turn/maxf(float(camera.sensitivity),0.00001),0)
	event.screen_relative=event.relative
	Input.parse_input_event(event)
	input_events+=1
	await process_frame

func _ready(expected: String) -> void:
	if not failures.is_empty(): return
	var deadline := Time.get_ticks_msec()+120000
	while Time.get_ticks_msec()<deadline:
		if game.game_started and str(game.current_zone_id)==expected and not game.zone_transition_pending and not game.zone_load_request_pending and not game._journey_load_pending() and game.pending_player_restore.is_empty() and game.player.can_control and not paused:
			await _frames(8)
			return
		await process_frame
	_fail("Controllable destination did not become ready: "+expected)

func _wait_flag(flag: String, expected: bool, timeout: float) -> void:
	if not failures.is_empty(): return
	var deadline := Time.get_ticks_msec()+int(timeout*1000)
	while Time.get_ticks_msec()<deadline:
		if _flag(flag)==expected: return
		await process_frame
	_check(_flag(flag)==expected,"Input earned expected state: "+flag)

func _flag(key: String) -> bool:
	return game.story_state.get_flag(key,false)==true

func _snapshot(label: String, extra: Dictionary={}) -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.player): return
	var row := {"label":label,"elapsed_ms":Time.get_ticks_msec()-start_ms,"zone":str(game.current_zone_id),"position":str(game.player.global_position),"flags":game.story_state.save_state().flags.duplicate(true),"quests":game.quests.save_state(),"input_events":input_events}
	row.merge(extra)
	await RenderingServer.frame_post_draw
	var path := output.path_join("%02d_%s.png" % [observations.size(),label])
	var error := root.get_texture().get_image().save_png(path)
	_check(error==OK,"Rendered milestone saved: "+label)
	row["image"]=path
	observations.append(row)
	print("COMMUNITY_INPUT "+JSON.stringify({"label":label,"failures":failures.size(),"input_events":input_events}))

func _tap(key: Key) -> void:
	if not failures.is_empty(): return
	_key(key,true)
	await _frames(2)
	_key(key,false)
	await _frames(3)

func _key(key: Key, pressed: bool) -> void:
	if bool(held.get(key,false))==pressed: return
	held[key]=pressed
	var event := InputEventKey.new()
	event.keycode=key
	event.physical_keycode=key
	event.pressed=pressed
	Input.parse_input_event(event)
	input_events+=1

func _release() -> void:
	for key: Key in held.keys():
		if held[key]: _key(key,false)

func _frames(count: int) -> void:
	for frame in range(count): await process_frame

func _seconds(seconds: float) -> void:
	if failures.is_empty(): await create_timer(seconds,true,false,true).timeout

func _check(condition: bool, label: String) -> void:
	if not condition: _fail(label)

func _fail(reason: String) -> void:
	failures.append(reason)
	push_error("COMMUNITY_INPUT "+reason)

func _finish() -> void:
	_release()
	if rules!=null: _check(completed_work==_expected_work(),"Exact physical task set for this route was earned")
	var report := {"schema_version":1,"kind":"community_world_real_input","case":case_id,"status":"pass" if failures.is_empty() else "fail","failures":failures,"completed_work":completed_work,"observations":observations,"input_events":input_events,"user_data_dir":OS.get_user_data_dir(),"elapsed_ms":Time.get_ticks_msec()-start_ms,"viewport":str(DisplayServer.window_get_size()),"physical_phone_coverage":false,"touch_input_coverage":false,"progression_injection":false}
	report.merge(report_extra)
	if output!="":
		var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
		if file!=null: file.store_string(JSON.stringify(report,"\t"))
	if is_instance_valid(game):
		paused=false
		game.prepare_resource_shutdown()
		await _frames(int(game.ZONE_RETIRE_FRAMES)+6)
		game.finalize_resource_shutdown()
		game.queue_free()
		await _frames(3)
	print("COMMUNITY_INPUT "+str(report.status)+" "+case_id)
	quit(0 if failures.is_empty() else 1)

func _expected_work() -> Array:
	var expected: Array=[]
	if case_id.begins_with("lantern"):
		expected=["kitchen_trestle","kitchen_screen","kitchen_places"]
		expected.append_array(rules.chapter("main_road_kept_open").choices["crossing" if case_id=="lantern_crossing" else "ferry"].work)
	else: expected=["refuge_bunks","refuge_shelves","refuge_places","promise_meal","promise_alarm","promise_records"]
	return expected
