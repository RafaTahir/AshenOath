extends "res://tools/verify_community_world_input.gd"

## One New Game earns the entire expanded chain. Ending alternatives then use
## the visible Return to before the covenant option, preserving the earned
## journey. Legacy boundary cases are separately labelled and never count as
## fourteen-chapter proof. All mutations after startup remain ordinary input.
var expanded := true
var seeded_ferry := false
var legacy
var revision_script
var endings_script
var expected_chapters: Array=[]
var initial_completed: Array[String]=[]
var observed_chapters: Array[String]=[]
var chapter_events: Array[Dictionary]=[]
var ending_results: Array[Dictionary]=[]
var recording := false
var current_ending := ""
var mouse_held: Dictionary={}

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--") and argument.contains("="):
			var pair := argument.substr(2).split("=",true,1)
			options[pair[0]]=pair[1]
	output=str(options.get("output","")); case_id=str(options.get("case",""))
	start_ms=Time.get_ticks_msec()
	seeded_ferry=case_id=="seeded_departure_ferry"
	expanded=case_id=="full_six_endings" or seeded_ferry
	if output=="" or case_id not in ["full_six_endings","legacy_ash_missing","legacy_ash_v1","legacy_witness_missing","legacy_witness_v1","seeded_departure_ferry"]:
		_fail("Full campaign acceptance requires an explicit supported case")
		await _finish(); return
	if DisplayServer.get_name().to_lower()=="headless":
		_fail("Full campaign input requires a rendered viewport")
		await _finish(); return
	if not _background_rendered_ready():
		await _finish(); return
	var version: Dictionary=Engine.get_version_info()
	if int(version.major)!=4 or int(version.minor)!=6 or int(version.patch)!=3:
		_fail("Full campaign input requires pinned Godot 4.6.3")
		await _finish(); return
	if not ProjectSettings.load_resource_pack(str(options.get("root-pack","")),true):
		_fail("Frozen root pack did not mount")
		await _finish(); return
	var folder := str(options.get("packs",""))
	var names := DirAccess.get_files_at(folder); names.sort()
	for name: String in names:
		if name.ends_with(".pck") and not ProjectSettings.load_resource_pack(folder.path_join(name),true): _fail("Pack did not mount: "+name)
	if not failures.is_empty(): await _finish(); return
	rules=load("res://scripts/community_campaign.gd")
	topology=load("res://scripts/world_sector_manifest.gd")
	revision_script=load("res://scripts/campaign_revision.gd")
	endings_script=load("res://scripts/ending_catalog.gd")
	var adapter=load("res://tools/generated_legacy_input.gd")
	if rules==null or topology==null or revision_script==null or endings_script==null or adapter==null:
		_fail("Required runtime or frozen input adapter is missing")
		await _finish(); return
	legacy=adapter.new(); legacy.owner=self
	expected_chapters=revision_script.chapter_ids(2 if expanded else 1)
	DisplayServer.window_set_size(Vector2i(960,540) if options.get("viewport","desktop")=="touch" else Vector2i(1280,720))
	var scene := load("res://scenes/main.tscn") as PackedScene
	if scene==null:
		_fail("Main scene is missing")
		await _finish(); return
	game=scene.instantiate(); root.add_child(game)
	game.quest_completed.connect(_chapter_completed)
	await _frames(4)
	await _button("New Game" if expanded and not seeded_ferry else "Continue")
	region="hart_glade" if seeded_ferry else "greyfen" if expanded else ("old_mill" if case_id.begins_with("legacy_ash") else "undercroft")
	await _ready(region)
	if not failures.is_empty(): await _finish(); return
	_check(revision_script.from_state(game.story_state)==(2 if expanded else 1),"Journey revision is selected by normal New Game or the supplied legacy marker")
	for id: String in expected_chapters:
		if game.quests.is_completed(id): initial_completed.append(id)
	_check(initial_completed.size()==13 if seeded_ferry else initial_completed.is_empty() if expanded else initial_completed.size()==(5 if region=="old_mill" else 8),"Initial chapter history matches this case; full proof starts with none")
	observed_chapters.assign(initial_completed)
	recording=true
	if seeded_ferry: await _prepare_seeded_ferry()
	elif expanded: await _opening_to_mill()
	else: await _legacy_insertion_checks()
	if failures.is_empty() and not seeded_ferry and (expanded or case_id.begins_with("legacy_ash")):
		if expanded: await _community_pair("lantern")
		await _middle_campaign()
	if failures.is_empty() and not seeded_ferry:
		if expanded: await _community_pair("hearth")
		await _legacy("_travel_to_assembly")
		await _legacy("_hear_assembly_witnesses")
		await _legacy("_choose_assembly_testimony")
		await _legacy("_travel_to_hart_glade")
		await _resume()
	if failures.is_empty():
		var endings: Array=["depart"] if seeded_ferry else endings_script.IDS if expanded else ["expose"]
		for ending: String in endings:
			if not failures.is_empty(): break
			current_ending=ending
			await _ending_circuit(ending)
			if ending!=str(endings.back()) and failures.is_empty():
				await _button("Return to before the covenant")
				await _ready("hart_glade")
				region="hart_glade"
				_check(str(game.story_state.get_flag("final_covenant",""))=="" and not _flag("final_choice_completed"),"Visible revisit restores the genuinely earned pre-covenant moment")
	await _finish()

func _opening_to_mill() -> void:
	await _legacy("_run_opening")
	await _legacy("_continue_teeth_in_rain")
	await _legacy("_continue_names_they_burned")
	await _legacy("_return_register_to_deep_wood")
	await _legacy("_fight_rootbound_real_input")
	await _legacy("_return_from_rootbound")
	await _legacy("_prepare_for_ash_mill")
	await _legacy("_travel_to_ash_mill")
	await _legacy("_inspect_ash_millstones")
	await _legacy("_fight_ashwing_real_input")

func _middle_campaign() -> void:
	await _legacy("_travel_to_bandit_road")
	await _legacy("_fight_senn_guard")
	await _legacy("_travel_to_castle_approach")
	await _legacy("_collect_castle_evidence")
	await _legacy("_enter_record_hall")
	await _legacy("_resolve_record_ledger")
	await _legacy("_fight_record_haunting")
	await _legacy("_confront_edric")
	await _legacy("_enter_undercroft")
	await _legacy("_break_halvern_guard")
	await _legacy("_resolve_halvern_witness")

func _legacy(method: String) -> void:
	if not failures.is_empty(): return
	await _resume()
	region=str(game.current_zone_id)
	await legacy.call(method,game)
	_release()
	region=str(game.current_zone_id)
	await _snapshot(method.trim_prefix("_"))

func _resume() -> void:
	if not failures.is_empty(): return
	if paused and game.hud.active_menu=="pause": await _button("Resume")
	await _frames(8)
	if paused: _fail("Continuous campaign is paused outside a save boundary")

func _community_pair(pair: String) -> void:
	if not failures.is_empty(): return
	await _resume()
	var original_case := case_id
	if pair=="lantern":
		region="lantern_reach"; case_id="lantern_crossing"
		await _cross_boundary(region)
		await _lantern()
		await _cross_boundary("old_mill")
	else:
		region="hearthward"; case_id="hearth_distributed"
		await _cross_boundary(region)
		await _hearth()
		await _rest("Wait until morning")
		await _departure_answer("elna",true)
		await _departure_answer("toma",false)
		await _save_reload("voluntary_departure_answers")
		await _cross_boundary("undercroft")
	case_id=original_case
	region=str(game.current_zone_id)
	await _snapshot("completed_"+pair+"_insertion")

func _legacy_insertion_checks() -> void:
	var new_zone := "lantern_reach" if region=="old_mill" else "hearthward"
	_check(not topology.available_neighbors(region,game.quests,game.story_state).has(new_zone),"Legacy graph excludes "+new_zone)
	_check(topology.connections(region,game.story_state).all(func(edge): return str(edge.target)!=new_zone),"Legacy geometry has no expansion corridor")
	for area: Node3D in game.zone_root.find_children("*","Area3D",true,false):
		if area.get("zone_target")==new_zone: _check(not area.is_visible_in_tree() or not area.is_interaction_enabled(),"Legacy expansion gate is absent or inactive")
	for id: String in revision_script.NEW_CHAPTERS:
		_check(not game.quests.is_active(id) and not game.quests.is_completed(id),"Legacy save never infers new chapter: "+id)
	await _save_reload("legacy_insertion")
	_check(revision_script.from_state(game.story_state)==1,"Legacy revision stays legacy after actual reload")
	await _snapshot("legacy_insertion_verified")

func _chapter_completed(id: String) -> void:
	if not recording or id not in revision_script.EXPANDED_CHAPTERS: return
	var repeated_finale := id=="main_hart_remembers" and observed_chapters==expected_chapters and not ending_results.is_empty()
	if not repeated_finale:
		var expected := str(expected_chapters[observed_chapters.size()]) if observed_chapters.size()<expected_chapters.size() else "<none>"
		_check(id==expected,"Actual chapter completion order: expected "+expected+", received "+id)
		observed_chapters.append(id)
	chapter_events.append({"id":id,"elapsed_ms":Time.get_ticks_msec()-start_ms,"ending":current_ending,"input_events":input_events,"zone":str(game.current_zone_id)})

func _choose_at(id: String, label: String) -> void:
	if not failures.is_empty(): return
	region=str(game.current_zone_id)
	await _interact(id)
	await _dialogue_button(label)
	await _frames(8)

func _close_dialogue() -> void:
	if not failures.is_empty(): return
	for index in range(64):
		if not game.hud.dialogue_layer.visible: return
		await _tap(KEY_ENTER)
		await _frames(3)
	_fail("Actual dialogue input did not return control")

func _travel(destination: String) -> void:
	if not failures.is_empty(): return
	await _resume()
	var source := str(game.current_zone_id)
	var queue: Array[String]=[source]
	var previous: Dictionary={source:""}
	while not queue.is_empty() and not previous.has(destination):
		var current: String=queue.pop_front()
		for next: String in topology.available_neighbors(current,game.quests,game.story_state):
			if previous.has(next): continue
			previous[next]=current; queue.append(next)
	if not previous.has(destination):
		_fail("Current allowed topology has no route to "+destination)
		return
	var path: Array[String]=[]
	var cursor := destination
	while cursor!=source:
		path.push_front(cursor); cursor=str(previous[cursor])
	for target: String in path:
		region=str(game.current_zone_id)
		var connection: Dictionary=topology.connection_between(region,target)
		if not connection.is_empty():
			await _cross_boundary(target)
		else:
			var gate: Node3D
			for candidate: Node3D in game.zone_root.find_children("*","Area3D",true,false):
				if candidate.get("zone_target")==target and candidate.is_visible_in_tree(): gate=candidate; break
			if gate==null:
				_fail("Allowed interior door is missing: "+region+" -> "+target)
				return
			await _interact(str(gate.get("interaction_id")))
			await _ready(target)
		region=str(game.current_zone_id)
		if not failures.is_empty(): return

func _ending_circuit(ending: String) -> void:
	region="hart_glade"
	await _interact("white_hart")
	for index in range(64):
		if game.hud.dialogue_page_index>=game.hud.dialogue_pages.size()-1: break
		await _tap(KEY_ENTER)
	var labels: Dictionary={}
	var authored: Dictionary=game.dialogue.get_dialogue("white_hart")
	for action: Dictionary in authored.actions:
		if str(action.get("type",""))=="ending": labels[str(action.ending)]=str(action.label)
	var visible: Array[String]=[]
	for id: String in endings_script.IDS:
		if not labels.has(id): continue
		for button: Button in game.hud.dialogue_actions.get_children():
			if button.is_visible_in_tree() and not button.disabled and button.text.trim_prefix("Commit: ").begins_with(str(labels[id])):
				visible.append(id); break
	_check(visible==endings_script.IDS if expanded else visible==endings_script.ORIGINAL_IDS,"Visible ending menu has exactly the available six or original four choices")
	await _button(str(labels[ending]))
	await _frames(8)
	var covenant := str(endings_script.covenant(ending))
	_check(str(game.story_state.get_flag("final_covenant",""))==covenant,"Actual selected ending is locked before enactment")
	var original_evidence: Dictionary=game.story_state.evidence.duplicate(true)
	var consequences: Dictionary={}
	var ritual_steps := 0
	if ending=="kill":
		await legacy._fight_hart_ending(game,"ash")
		_release()
	else:
		for index in range(3):
			await _interact("covenant_%s_%d" % [ending,index])
			await _close_dialogue()
			_check(int(game.story_state.get_flag("covenant_ritual_step",0))==index+1,"Ritual step earned through its actual interaction")
			ritual_steps+=1
			if index==0:
				await _save_reload("ritual_"+ending)
				_check(str(game.pending_ending)==ending and int(game.story_state.get_flag("covenant_ritual_step",0))==1,"Mid-ritual reload preserves exact progress")
	if ending=="depart": consequences=await _open_road_departure(original_evidence)
	_check(_flag("final_choice_completed") and game.quests.is_completed("main_hart_remembers"),"Enacted ending finishes the final chapter")
	_check(observed_chapters==expected_chapters,"All campaign chapters were completed in order")
	await _snapshot("ending_"+ending)
	# Reload the earned completed state before walking home. This proves the
	# actual memorial resource survives restoration rather than only refreshing.
	await _button("Return to Main Menu")
	await _button("Continue")
	await _ready("hearthward" if ending=="depart" else "hart_glade")
	region=str(game.current_zone_id)
	if ending=="depart":
		_check(_departure_costs(),"Relocation and both irreversible losses survive completed Continue")
		await _travel("hart_glade")
	var memorial := game.zone_root.get_node_or_null("HartAftermathSeal") as MeshInstance3D
	var memorial_restored := memorial!=null and memorial.mesh!=null and str(memorial.mesh.get_meta("covenant",""))==covenant
	_check(memorial_restored,"Completed ending restores its matching authored memorial")
	_check(str(game.story_state.get_flag("final_covenant",""))==covenant and _flag("final_choice_completed"),"Completed ending survives Continue")
	await _snapshot("memorial_reload_"+ending)
	if ending=="share": consequences["concord_revocation_verified"]=await _continuing_concord()
	await _travel("greyfen")
	for id: String in ["aftermath_names","aftermath_work","aftermath_road"]:
		await _interact(id)
		await _close_dialogue()
		await _frames(8)
	_check(_flag("aftermath_names_returned") and _flag("aftermath_work_promised") and _flag("aftermath_walk_completed") and _flag("epilogue_presented"),"Actual return-home interactions present the epilogue")
	var cards: Variant=game.story_state.get_flag("epilogue_cards",[])
	_check(cards is Array and not cards.is_empty(),"Ending has actual epilogue cards")
	await _snapshot("epilogue_"+ending)
	ending_results.append({"ending":ending,"covenant":covenant,"ritual_steps":ritual_steps,"visible_options":visible,"memorial_reload":memorial_restored,"return_home":str(game.current_zone_id)=="greyfen","epilogue_presented":_flag("epilogue_presented"),"cards":cards,"input_events":input_events,"consequences":consequences})

func _mouse_button(button: MouseButton, pressed: bool) -> void:
	if bool(mouse_held.get(button,false))==pressed: return
	mouse_held[button]=pressed
	var event := InputEventMouseButton.new()
	event.button_index=button; event.pressed=pressed
	Input.parse_input_event(event); input_events+=1

func _release() -> void:
	super._release()
	for button: MouseButton in mouse_held.keys():
		if mouse_held[button]: _mouse_button(button,false)

func _expected_work() -> Array:
	return ["kitchen_trestle","kitchen_screen","kitchen_places","crossing_beam","crossing_rail","crossing_load","refuge_bunks","refuge_shelves","refuge_places","promise_meal","promise_alarm","promise_records"] if expanded and not seeded_ferry else []

func _finish() -> void:
	if recording:
		_check(observed_chapters==expected_chapters,"Required complete campaign history is present")
		var expected: Array=["depart"] if seeded_ferry else endings_script.IDS if expanded else ["expose"]
		_check(ending_results.map(func(row): return str(row.ending))==expected,"Every required ending completed its enactment and return-home circuit")
	report_extra={"suite":"seeded_departure" if seeded_ferry else "full_campaign" if expanded else "legacy_insertion","initial_completed":initial_completed,"expected_chapters":expected_chapters,"observed_chapters":observed_chapters,"chapter_events":chapter_events,"endings":ending_results,"started_with_new_game":expanded and not seeded_ferry,"seeded_boundary":not expanded or seeded_ferry}
	if legacy!=null: legacy.owner=null; legacy=null
	await super._finish()

func _departure_answer(id: String, accept: bool) -> void:
	await _interact(str(rules.ACTORS[id]))
	await _dialogue_button("Hear whether they choose to relocate." if accept else "Hear their decision to remain.")
	await _dialogue_button("Record their answer without changing anyone else's.")
	_check(game.story_state.get_flag("community_departure_consent",{}).get(id)==accept,"Separate personal relocation answer is recorded: "+id)

func _departure_costs() -> bool:
	return _flag("open_road_protection_dismantled") and game.story_state.get_flag("territorial_protection_active")==false and game.story_state.get_flag("hart_complete_account_access")==false and _flag("human_records_preserved")

func _open_road_departure(evidence: Dictionary) -> Dictionary:
	_check(not _flag("final_choice_completed") and str(game.pending_ending)=="depart","Hart acts alone cannot complete the promised relocation")
	_check(_departure_costs(),"The ward and access to the full Hart account are actually lost")
	await _save_reload("ward_dismantled")
	_check(_departure_costs() and not _flag("final_choice_completed"),"Mid-departure Continue preserves irreversible cost and unfinished work")
	await _travel("lantern_reach")
	await _operation("departure_load","open_road_load_carried",10.0)
	var cohort: Node3D=game.zone_root.get_node_or_null("OpenRoadHouseholds")
	var bodies_visible := cohort!=null and cohort.get_child_count()==2 and cohort.get_children().all(func(body): return body.is_visible_in_tree() and body.find_child("CharacterAnimationDriver",true,false)!=null)
	_check(bodies_visible,"The consenting households have two actual native bodies beside the passage")
	await _save_reload("departure_load")
	if str(game.story_state.get_flag("community_route",""))=="crossing":
		# Walk beyond the follower's end point plus lead gap and movement tolerance.
		for point: Vector3 in [Vector3(3,1,0),Vector3(5,1,0),Vector3(7.5,1,0),Vector3(10.5,1,0),Vector3(12,1,0)]:
			await _walk_direct(point)
			await _seconds(1.0)
	else:
		await _interact("community:ferry")
		await _seconds(2.0)
		await _tap(KEY_ESCAPE)
		_check(not _flag("open_road_route_crossed"),"Paused ferry awards no relocation passage")
		await _button("Resume")
		await _interact("community:ferry")
	await _wait_flag("open_road_route_crossed",true,18.0)
	await _operation("departure_delivery","open_road_route_delivered",9.0)
	await _save_reload("households_across")
	await _travel("hearthward")
	await _operation("departure_arrival","open_road_relocation_completed",11.0)
	var intact := true
	for id: String in evidence:
		if game.story_state.evidence.get(id)!=evidence[id]: intact=false
	var named: Array=game.story_state.get_flag("open_road_named_roster",[])
	var answers: Dictionary=game.story_state.get_flag("community_departure_consent",{})
	var consent_only := named.all(func(id): return answers.get(id)==true)
	_check(consent_only and "elna" in named and "toma" not in named,"Only the explicitly willing named participant relocates")
	_check(intact,"Every previously recovered human evidence record is unchanged")
	return {"route":str(game.story_state.get_flag("community_route","")),"route_crossed":_flag("open_road_route_crossed"),"arrival":_flag("open_road_relocation_completed"),"losses_persisted":_departure_costs(),"human_evidence_preserved":intact,"named_consent_only":consent_only,"native_households":bodies_visible}

func _continuing_concord() -> bool:
	await _travel("hearthward")
	await _rest("Wait until morning")
	var original: Dictionary=game.story_state.get_flag("final_keeper_consent",{}).duplicate(true)
	await _consent("nessa",false)
	await _save_reload("concord_continuing_withdrawal")
	_check(game.story_state.get_flag("final_keeper_consent",{})==original,"Continuing withdrawal never rewrites original acceptance")
	_check(endings_script.concord_route_closed(game.story_state),"A real route vacancy closes the public passage")
	await _travel("lantern_reach")
	await _frames(3)
	var barrier: Node3D=game.zone_root.find_child("UnstaffedRouteBarrier2",true,false)
	var closed := barrier!=null and barrier.visible and barrier.find_children("*","CollisionShape3D",true,false).all(func(shape): return not shape.disabled)
	_check(closed,"Unstaffed bridge has visible physical barriers; service footway remains")
	await _snapshot("concord_route_closed")
	await _travel("hearthward")
	await _rest("Wait until morning")
	await _consent("nessa",true)
	_check(not endings_script.concord_route_closed(game.story_state),"Only a new voluntary offer reopens the vacancy")
	return closed and game.story_state.get_flag("final_keeper_consent",{})==original

func _prepare_seeded_ferry() -> void:
	_check(str(game.story_state.get_flag("community_route",""))=="ferry" and _flag("community_route_ready") and _flag("community_refuge_ready"),"Labelled boundary setup provides a prepared ferry and refuge")
	_check(not _flag("final_choice_completed") and str(game.pending_ending)=="","Seed does not provide an enacted ending")
	await _travel("hearthward")
	await _rest("Wait until morning")
	for id: String in ["anwen","nessa","vale"]: await _consent(id,true)
	await _departure_answer("elna",true)
	await _departure_answer("toma",false)
	await _travel("hart_glade")
	await _snapshot("seeded_ferry_boundary_not_full_campaign_proof")
