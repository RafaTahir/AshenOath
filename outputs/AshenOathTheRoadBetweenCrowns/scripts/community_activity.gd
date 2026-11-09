extends RefCounted

## An activity adapter, not another scene/process owner. StoryActivityDirector
## calls tick/cancel and owns its lifetime with the published sector.
const Rules = preload("res://scripts/community_campaign.gd")
const Ending = preload("res://scripts/community_ending.gd")
const Covenant = preload("res://scripts/covenant_resolution.gd")
const Decisions = preload("res://scripts/story_decision_coordinator.gd")
const StoryPerformance = preload("res://scripts/story_performance.gd")
var director: Node
var game
var zone := ""
var stations: Dictionary = {}
var menu_generation := 0
var menu_source: WeakRef
var menu_actions: Array[Dictionary] = []
var work: Dictionary = {}
var elapsed := 0.0
var work_start := Vector3.ZERO
var gesture := ""
var menu_view_generation := -1
var crossing_entered := false
var ferry_control := true
var ferry_safe := Vector3.ZERO
var published_shift := ""
var cohort: Node3D
var cohort_drivers: Array[Node] = []

func configure(owner: Node, build_stations: bool = true) -> void:
	director = owner
	game = owner.host
	zone = owner.zone
	preload("res://scripts/story_cast_profile.gd").load_region_life(zone,"res://data/community_cast_life.json")
	if build_stations: load("res://scripts/community_presentation.gd").ensure_stations(game,zone)
	var board: Dictionary = Rules.BOARDS[zone]
	_station("board", str(board.title), _position(board.position), {"operation":"board"})
	for id: String in Rules.data().get("work",{}):
		var task: Dictionary = Rules.data().work[id]
		if str(task.region) == zone:
			_station("work:"+id,str(task.prompt),_position(task.position),{"operation":"work","id":id,"seconds":float(task.seconds),"kind":str(task.kind)})
	for quest: String in Rules.AFTERMATH:
		if str(Rules.chapter(quest).region) != zone: continue
		var task: Dictionary = Rules.AFTERMATH[quest]
		_station("aftermath:"+quest,str(task.prompt),_position(task.position),{"operation":"aftermath","quest":quest,"seconds":float(task.seconds),"kind":str(task.kind)})
	if zone == "lantern_reach":
		_station("survey:near","Inspect the near landing and read the current",Vector3(1,0,-1),{"operation":"survey","id":"near","seconds":3.0,"kind":"inspect"})
		_station("survey:far","Inspect the far landing and its approach",Vector3(11,0,-1),{"operation":"survey","id":"far","seconds":3.0,"kind":"inspect"})
		_station("delivery","Set down the first load at the far landing",Vector3(11,0,1.5),{"operation":"delivery","quest":"main_road_kept_open","seconds":3.0,"kind":"haul"})
		_station("ferry","Board the ferry with the first load",Vector3(3.0,0,0.8),{"operation":"ferry","seconds":7.5,"kind":"haul"})
	for operation: String in ["departure_load","departure_delivery","departure_arrival"]:
		var entry: Dictionary=Rules.data().departure_journey[operation]
		if str(entry.zone)==zone:
			_station(operation,str(entry.prompt),_position(entry.position),{"operation":operation,"seconds":float(entry.seconds),"kind":str(entry.kind)})
	refresh()

func _station(id: String, prompt: String, position: Vector3, action: Dictionary) -> void:
	var node_id := "community_"+id.replace(":","_")
	director._point(game.zone_root,node_id,prompt,position,"",Color(0.62,0.57,0.42))
	var area := game.zone_root.find_child(node_id,true,false) as Node3D
	area.set("interaction_id","community:"+id)
	area.set_meta("community_action",action.duplicate(true))
	stations[id] = weakref(area)

func refresh() -> void:
	published_shift = Rules.presence_shift(_minutes())
	# Regional actors retain the normal native routine owner. Availability is
	# rechecked when a menu commits, not only when this sector was constructed.
	var actors: Array = game.zone_root.find_children("*","Area3D",true,false)
	# Retire the outgoing shift before showing arrivals, keeping eight canonical
	# NPCs at most (plus Kael and Bracken) even on the handover frame.
	for actor in actors:
		if not actor.has_meta("community_actor_id"): continue
		if not _actor_present(actor): _set_present(actor,false)
	for actor in actors:
		if actor.has_meta("community_actor_id") and _actor_present(actor): _set_present(actor,true)
	var life: Node = game.zone_root.get_node_or_null("RegionalLifeController")
	if life != null: life.enroll_region()
	load("res://scripts/community_presentation.gd").refresh(game.zone_root,game.story_state)
	_refresh_cohort()
	for id: String in stations:
		var area: Node3D = stations[id].get_ref()
		if not is_instance_valid(area): continue
		var enabled := _available(area.get_meta("community_action"))
		area.visible = enabled
		area.set_interaction_enabled(enabled)
		if not enabled: game._remove_interaction_candidate(area)

func _minutes() -> float:
	var clock = game.get("day_night")
	return float(clock.get_time()) if clock != null else 600.0

func _actor_present(actor: Node3D) -> bool:
	return _actor_alive(actor) and Rules.actor_present(str(actor.get_meta("community_actor_id","")),zone,_minutes(),game.story_state,game.quests)

func _set_present(actor: Node3D, present: bool) -> void:
	if not present and not actor.has_meta("community_process_mode"):
		actor.set_meta("community_process_mode",actor.process_mode)
	if present and actor.has_meta("community_process_mode"):
		actor.process_mode = int(actor.get_meta("community_process_mode"))
		actor.remove_meta("community_process_mode")
	elif not present:
		actor.process_mode = Node.PROCESS_MODE_DISABLED
	actor.visible = present
	actor.set_interaction_enabled(present)
	if not present: game._remove_interaction_candidate(actor)

func activate(area: Node3D) -> void:
	if not _source_valid(area): return
	if area.has_meta("community_actor_id"):
		_open_actor(area)
		return
	var action: Dictionary = area.get_meta("community_action",{})
	if not _available(action): return
	if str(action.operation) == "board":
		_open_board(area)
	else:
		_begin_work(area,action)

func _source_valid(area: Node3D) -> bool:
	if is_instance_valid(area) and area.has_method("is_interaction_enabled") and not area.is_interaction_enabled(): return false
	if is_instance_valid(area) and area.has_meta("community_actor_id") and not _actor_present(area): return false
	return Rules.enabled(game.story_state) and is_instance_valid(area) and _actor_alive(area) and is_instance_valid(game.zone_root) and director.get_parent() == game.zone_root and str(game.current_zone_id) == zone and game.zone_root.is_ancestor_of(area) and area.is_visible_in_tree() and is_instance_valid(game.player) and area.global_position.distance_to(game.player.global_position) <= 2.8 and not game._journey_load_pending() and not game.zone_transition_pending and not game.zone_load_request_pending and game.pending_player_restore.is_empty() and (str(game.pending_ending) == "" or Covenant.relocation_pending(game.story_state)) and float(game.player.health_component.health) > 0.0 and not director._danger_near(game)

func _actor_alive(area: Node3D) -> bool:
	if not area.has_meta("community_actor_id"): return true
	var driver := area.find_child("CharacterAnimationDriver",true,false)
	return driver == null or driver.get("dead") != true

func _available(action: Dictionary) -> bool:
	if str(action.get("operation","")).begins_with("departure_"): return _cohort_ready() and Ending.action_available(str(action.operation),zone,game.story_state)
	match str(action.get("operation","")):
		"board": return Rules.enabled(game.story_state)
		"work": return Rules.work_available(str(action.get("id","")),zone,game.story_state,game.quests)
		"survey": return zone == "lantern_reach" and Rules.current_objective("main_road_kept_open",game.quests) == "survey_crossing" and not Rules._true(game.story_state,"community_survey:"+str(action.id))
		"aftermath":
			return Rules.aftermath_available(str(action.get("quest","")),zone,game.story_state,game.quests) and (str(action.quest) != "main_road_kept_open" or not Rules._true(game.story_state,"community_route_load_carried"))
		"delivery": return Rules.aftermath_available("main_road_kept_open",zone,game.story_state,game.quests) and Rules._true(game.story_state,"community_route_load_carried") and Rules._true(game.story_state,"community_route_load_crossed")
		"ferry": return zone=="lantern_reach" and str(game.story_state.get_flag("community_route",""))=="ferry" and not Rules.Endings.concord_route_closed(game.story_state) and (Ending.crossing_needed(game.story_state) or (Rules.aftermath_available("main_road_kept_open",zone,game.story_state,game.quests) and Rules._true(game.story_state,"community_route_load_carried") and not Rules._true(game.story_state,"community_route_load_crossed")))
	return false

func _open_board(area: Node3D) -> void:
	var quest := Rules.active_chapter(zone,game.quests,game.story_state)
	var row := Rules.chapter(quest)
	var pages: Array = []
	for key: String in ["summary","stakes"]:
		if row.has(key): pages.append({"speaker":"Public account","speaker_id":"narrator","text":str(row[key]),"read_only":true})
	var status := ""
	var objective := Rules.current_objective(quest,game.quests)
	if objective in ["hear_households","gather_cast"]:
		pages.append({"speaker":"Public account","speaker_id":"narrator","text":_public_account(quest),"read_only":true})
	if objective in ["choose_responsibilities","carry_promise"] or game.quests.is_completed("main_what_we_promise"):
		status = _rota_text()
	if objective in ["prepare_kitchen","secure_route","prepare_refuge","test_arrangements"]:
		status = "Work still needed:"
		for id: String in Rules.work_ids(quest,game.story_state):
			if not Rules._true(game.story_state,"community_work:"+id): status += "\n• "+str(Rules.data().work[id].prompt)
	if pages.is_empty() and status=="": status="The completed work remains open to anyone who needs it."
	# Live checklists are a reading surface. Authored narration stays in separate
	# exact-text pages so the voice collector never needs combinatorial variants.
	if status!="": pages.append({"speaker":"Public work record","speaker_id":"system","text":status,"read_only":true})
	if Ending.departing(game.story_state):
		pages.append({"speaker":"Departure record","speaker_id":"system","text":Ending.roster_text(game.story_state),"read_only":true})
	if zone == "hearthward":
		pages.append({"speaker":"Visits and shifts","speaker_id":"system","text":_shift_text(),"read_only":true})
	_show(area,str(Rules.BOARDS[zone].title),pages,Rules.board_actions(zone,game.story_state,game.quests))

func _shift_text() -> String:
	var lines: Array[String] = ["People use the public rooms in two shifts. The shelter bench lets you wait until morning or evening."]
	for shift: String in ["morning","evening"]:
		var names: Array[String] = []
		for id: String in Rules.data().get("presence_shifts",{}).get(zone,{}).get(shift,[]):
			if Rules.actor_available(id,game.story_state,game.quests): names.append(str(Rules.data().participant_lines[id].name))
		lines.append(shift.capitalize()+": "+", ".join(names)+".")
	return "\n".join(lines)

func _public_account(quest: String) -> String:
	# These are practical requests authored for public circulation, never private
	# testimony attributed to an unavailable participant.
	return str(Rules.data().get("public_accounts",{}).get(quest,""))

func _rota_text() -> String:
	var answers: Dictionary = game.story_state.get_flag("community_keeper_consent",{})
	var lines: Array[String] = ["Recorded shifts — food and shelter do not depend on joining:"]
	for id: String in Rules.data().consent_offers:
		var value: Variant = answers.get(id)
		lines.append(id.capitalize()+": "+("offered; may withdraw" if typeof(value)==TYPE_BOOL and value else "vacant — no current agreement"))
	return "\n".join(lines)

func _open_actor(actor: Node3D, reply: String = "") -> void:
	var id := str(actor.get_meta("community_actor_id",""))
	if id not in Rules.REGIONAL_ACTORS.get(zone,[]) or not Rules.actor_available(id,game.story_state,game.quests): return
	var row: Dictionary = Rules.data().get("participant_lines",{}).get(id,{})
	var words := reply if reply != "" else str(row.get(zone,""))
	var pages: Array = [{"speaker":str(row.get("name",id.capitalize())),"speaker_id":str(Rules.ACTORS[id]),"text":words,"performance":{"emotion":"warmth","gesture":"reassure"}}]
	var actions: Array[Dictionary] = []
	if Rules.consent_available(id,game.story_state,game.quests):
		var offer: Dictionary = Rules.data().consent_offers[id]
		pages.append({"speaker":"Kael","speaker_id":"player","text":str(offer.question),"performance":{"gesture":"guarded_listening"}})
		# Ask each person for an answer. A separately presented answer is then
		# recorded, so a menu cannot substitute Kael's choice for their speech.
		actions.append({"operation":"ask_consent","id":id,"label":"Hear the shift they are offering."})
		actions.append({"operation":"ask_refusal","id":id,"label":"Leave this responsibility open."})
		var consent: Dictionary = game.story_state.get_flag("community_keeper_consent",{})
		if consent.get(id) == true: actions.append({"operation":"withdraw","id":id,"label":"Release the recorded shift."})
	if Ending.offers_available(id,game.story_state,game.quests):
		var offer: Dictionary=Rules.data().departure_offers[id]
		pages.append({"speaker":"Kael","speaker_id":"player","text":str(offer.question),"performance":{"gesture":"guarded_listening"}})
		actions.append({"operation":"ask_departure_yes","id":id,"label":"Hear whether they choose to relocate."})
		actions.append({"operation":"ask_departure_no","id":id,"label":"Hear their decision to remain."})
		if game.story_state.get_flag(Ending.DEPARTURE_ANSWERS,{}).get(id)==true: actions.append({"operation":"withdraw_departure","id":id,"label":"Withdraw their recorded departure."})
	_show(actor,str(row.get("name",id.capitalize())),pages,actions)

func _show(source: Node3D, title: String, pages: Array, actions: Array[Dictionary]) -> void:
	cancel(false)
	menu_generation += 1
	menu_source = weakref(source)
	menu_actions = actions.duplicate(true)
	var published: Array[Dictionary] = []
	for index in range(menu_actions.size()):
		var option := menu_actions[index].duplicate(true)
		option.merge({"type":"community_action","generation":menu_generation,"index":index,"source":source.get_instance_id()})
		published.append(option)
	published.append({"type":"close","label":"Leave the conversation"})
	var content := {"name":title,"pages":pages,"actions":published}
	if source.has_meta("community_actor_id"):
		game._stage_dialogue_moment(source)
		StoryPerformance.begin(source,game.player,content,game.story_state)
	game.audio.set_dialogue_active(true)
	game.audio.set_game_paused(true)
	game.get_tree().paused = true
	game.hud.show_dialogue(game._prepare_dialogue_presence(content))
	menu_view_generation = int(game.hud._dialogue_view_generation)

func choose(action: Dictionary) -> void:
	var source: Node3D = menu_source.get_ref() if menu_source != null else null
	var index := int(action.get("index",-1))
	# HUD closes the source surface (advancing its generation once) immediately
	# before emitting this action. Its old button cannot close a later surface.
	if not _source_valid(source) or game.hud.dialogue_layer.visible or int(game.hud._dialogue_view_generation) != menu_view_generation+1 or int(action.get("generation",-1)) != menu_generation or int(action.get("source",0)) != source.get_instance_id() or index < 0 or index >= menu_actions.size():
		game._resume_game()
		return
	# Trust the owner's immutable menu entry, never the caller's effects/ID.
	var chosen := menu_actions[index].duplicate(true)
	menu_generation += 1
	menu_actions.clear()
	game._resume_game()
	var operation := str(chosen.operation)
	if operation in ["ask_consent","ask_refusal"]:
		var id := str(chosen.id)
		if not _participant_source(source,id): return
		var accepted := operation == "ask_consent"
		var text := str(Rules.data().consent_offers[id]["yes" if accepted else "no"])
		_show(source,id.capitalize(),[{"speaker":id.capitalize(),"speaker_id":Rules.ACTORS[id],"text":text,"performance":{"gesture":"acknowledge" if accepted else "disagree"}}],[{"operation":"record_consent","id":id,"accepted":accepted,"label":"Record that answer, with the right to withdraw."}])
		return
	if operation in ["ask_departure_yes","ask_departure_no"]:
		var id := str(chosen.id)
		if not _participant_source(source,id,true): return
		var accepted := operation=="ask_departure_yes"
		var offer: Dictionary=Rules.data().departure_offers[id]
		_show(source,id.capitalize(),[{"speaker":id.capitalize(),"speaker_id":str(offer.speaker_id),"text":str(offer["yes" if accepted else "no"]),"performance":{"gesture":"acknowledge" if accepted else "disagree"}}],[{"operation":"record_departure","id":id,"accepted":accepted,"label":"Record their answer without changing anyone else's."}])
		return
	var transaction := Decisions.new()
	var receipt := {"type":"story_choice","quest":str(chosen.get("quest","")),"choice_id":"community:"+operation+":"+str(chosen.get("quest",chosen.get("id",""))),"label":str(chosen.get("label",""))}
	if operation == "choice":
		receipt["sets_flags"] = {str(Rules.chapter(str(chosen.quest)).choice):str(chosen.value)}
	game.save_manager.predecision(game,str(receipt.choice_id))
	transaction.begin(game)
	var applied := false
	if operation in ["record_departure","withdraw_departure"]:
		var id := str(chosen.id)
		if _participant_source(source,id,true): applied=Ending.record_answer(id,bool(chosen.get("accepted",false)) if operation=="record_departure" else false,game.story_state,game.quests)
	elif operation in ["record_consent","withdraw"]:
		var id := str(chosen.id)
		if _participant_source(source,id): applied = Rules.record_consent(id,bool(chosen.get("accepted",false)) if operation == "record_consent" else false,game.story_state,game.quests)
	else:
		if source.get_meta("community_action",{}).get("operation","") == "board": applied = Rules.apply_board_action(chosen,zone,game.story_state,game.quests)
	transaction.finish(game,receipt,applied)
	if applied:
		refresh()
		if operation=="withdraw_departure": _open_actor(source,str(Rules.data().departure_offers[str(chosen.id)].withdraw))
		elif operation == "withdraw": _open_actor(source,str(Rules.data().consent_offers[str(chosen.id)].withdraw))
		else: game.hud.toast("The public account now records that answer.")

func _participant_source(source: Node3D, id: String, departure: bool = false) -> bool:
	return _source_valid(source) and id in Rules.REGIONAL_ACTORS.get(zone,[]) and str(source.get_meta("community_actor_id","")) == id and str(source.get("interaction_id")) == str(Rules.ACTORS.get(id,"!")) and (Ending.offers_available(id,game.story_state,game.quests) if departure else Rules.consent_available(id,game.story_state,game.quests))

func _begin_work(area: Node3D, action: Dictionary) -> void:
	if director._rest_unavailable(area) != "" or not _available(action): return
	director._cancel_rest()
	director._cancel_friend_work()
	cancel()
	work = action.duplicate(true)
	work["source"] = weakref(area)
	work_start = game.player.global_position
	if str(action.operation)=="ferry":
		ferry_safe = game.zone_root.to_global(Vector3(3,0.02,1.5))
		ferry_control = game.player.can_control
		game.player.can_control = false
	game.player._request_equipment(game.player.weapon_mode,game.player.get_selected_blade_id(),false)
	game.hud.set_guidance_hint(str(area.get("prompt"))+". Stay beside the work; move to stop.",float(action.seconds)+3.0)

func tick(delta: float) -> void:
	if director.get_parent()!=game.zone_root or str(game.current_zone_id)!=zone:
		cancel()
		return
	if published_shift != Rules.presence_shift(_minutes()): refresh()
	_tick_crossing()
	_tick_cohort(delta)
	if work.is_empty(): return
	if str(work.operation)=="ferry":
		_tick_ferry(delta)
		return
	var area: Node3D = work.source.get_ref()
	if not _source_valid(area) or not _available(work) or director._rest_unavailable(area) != "" or not game.player.can_control or game.player.transition_locked or game.player.global_position.distance_to(work_start) > 0.3:
		cancel()
		return
	if game.player.equipment_loadout.is_transitioning():
		if gesture != "": cancel()
		return
	if game.player.equipment_loadout.is_drawn():
		cancel()
		return
	if gesture == "":
		gesture = "story_explain" if str(work.kind) == "inspect" else "story_offer"
		var offset: Vector3 = area.global_position-game.player.global_position
		if Vector2(offset.x,offset.z).length_squared() > 0.01: game.player.rotation.y = atan2(-offset.x,-offset.z)
		if game.player.animation_driver != null: game.player.animation_driver.trigger_action(gesture,1.0,0.15,false,float(work.seconds))
	elapsed += maxf(0.0,delta)
	if str(work.operation)=="work": load("res://scripts/community_presentation.gd").animate_work(game.zone_root,str(work.id),elapsed/float(work.seconds))
	if elapsed < float(work.seconds): return
	var completed := work.duplicate()
	cancel()
	var transaction := Decisions.new()
	transaction.begin(game)
	var applied := false
	var result := ""
	if str(completed.operation).begins_with("departure_"):
		applied=Ending.complete_action(str(completed.operation),zone,game.story_state)
		result=str(Rules.data().departure_journey[str(completed.operation)].text)
	match str(completed.operation):
		"work":
			applied = Rules.complete_work(str(completed.id),zone,game.story_state,game.quests)
			result = str(Rules.data().work[str(completed.id)].result)
		"survey":
			applied = Rules.inspect_landing(str(completed.id),zone,game.story_state,game.quests)
			result = "The landing's footing and the current are marked for the public route decision."
		"aftermath","delivery":
			applied = Rules.finish_aftermath(str(completed.quest),zone,game.story_state,game.quests,str(completed.operation)=="delivery")
			result = Rules.aftermath_text(str(completed.quest),game.story_state)
			if str(completed.quest)=="main_road_kept_open" and str(completed.operation)=="aftermath": result = "The load is secure. Carry it to the far landing and set it down there."
	transaction.finish(game,{"type":"community_work","label":result},applied)
	if applied:
		game.audio.play_event("cloth_wind",0.015)
		game.hud.toast(result)
		game.hud.set_guidance_hint(result,8.0)
		refresh()
		if str(completed.operation)=="departure_arrival": Covenant.finish_if_ready(game)

func cancel(invalidate_menu: bool = true) -> void:
	_cohort_motion(Vector3.ZERO)
	if not work.is_empty() and str(work.operation)=="ferry" and game != null and is_instance_valid(game.player):
		if director.get_parent()==game.zone_root and str(game.current_zone_id)==zone:
			if not game.player.transition_locked and float(game.player.health_component.health)>0: game.player.can_control = ferry_control
			game.player.velocity = Vector3.ZERO
			game.player.global_position = ferry_safe
		var boat := game.zone_root.get_node_or_null("CommunityWork/PublicRoute_ferry/Ferry") as Node3D if is_instance_valid(game.zone_root) else null
		if boat != null: boat.position.x = 3.5
		if director.get_parent()==game.zone_root and is_instance_valid(cohort): _refresh_cohort()
	if gesture != "" and game != null and is_instance_valid(game.player) and game.player.animation_driver != null and game.player.animation_driver.current_state == gesture:
		game.player.animation_driver.stop_action("idle",0.12)
	work.clear()
	elapsed = 0.0
	gesture = ""
	if game != null and is_instance_valid(game.zone_root): load("res://scripts/community_presentation.gd").refresh(game.zone_root,game.story_state)
	if invalidate_menu:
		menu_generation += 1
		menu_actions.clear()
		menu_source = null

func _tick_crossing() -> void:
	if not _passage_safe():
		crossing_entered=false
		return
	if zone!="lantern_reach" or str(game.story_state.get_flag("community_route",""))!="crossing" or (not Ending.crossing_needed(game.story_state) and (not Rules._true(game.story_state,"community_route_load_carried") or Rules._true(game.story_state,"community_route_load_crossed"))):
		crossing_entered=false
		return
	var position: Vector3 = game.zone_root.to_local(game.player.global_position)
	# PlayerController's root is at its feet, not the capsule centre. The deck
	# top is 0.12 + 0.13/2 = 0.185 m; the unfinished channel bed is below zero.
	if absf(position.z)<=0.9 and position.x>=4.0 and position.x<=7.5 and position.y>=0.10 and position.y<=0.65: crossing_entered=true
	if absf(position.z)>1.5 or position.y<0.10: crossing_entered=false
	if crossing_entered and position.x>=9.5 and absf(position.z)<=1.5 and _record_crossing("crossing"):
		_crossing_finished()

func _tick_ferry(delta: float) -> void:
	var boat := game.zone_root.get_node_or_null("CommunityWork/PublicRoute_ferry/Ferry") as Node3D
	if boat==null or (Ending.crossing_needed(game.story_state) and not _cohort_ready()) or director.get_parent()!=game.zone_root or str(game.current_zone_id)!=zone or not _available(work) or game._journey_load_pending() or game.zone_transition_pending or game.zone_load_request_pending or not game.pending_player_restore.is_empty() or director._danger_near(game) or float(game.player.health_component.health)<=0 or float(game.player.hurt_react_time)>0:
		cancel()
		return
	if game.player.equipment_loadout.is_transitioning(): return
	if game.player.equipment_loadout.is_drawn():
		cancel()
		return
	elapsed += maxf(delta,0)
	boat.position.x = lerpf(3.5,9.5,clampf(elapsed/float(work.seconds),0,1))
	game.player.velocity=Vector3.ZERO
	# FerryDeck is centred at .15 with .18 height: feet rest just above .24.
	game.player.global_position=boat.to_global(Vector3(0,0.25,0))
	if is_instance_valid(cohort) and Ending.crossing_needed(game.story_state):
		cohort.position=Vector3(boat.position.x,0.25,0)
		for index in cohort.get_child_count(): cohort.get_child(index).position=Vector3(-.72 if index==0 else .72,0,0)
		_cohort_motion(Vector3.ZERO)
	if elapsed<float(work.seconds): return
	ferry_safe=game.zone_root.to_global(Vector3(10.5,0.02,1.5))
	var applied := _record_crossing("ferry")
	cancel()
	if applied: _crossing_finished()

func _crossing_finished() -> void:
	game.story_save_pending=true
	game.call_deferred("_persist_story_action")
	game.hud.set_guidance_hint("The households and load have crossed. Secure them at the far landing." if Ending.departing(game.story_state) else "The first load has crossed. Set it down at the far landing.",6.0)
	refresh()

static func _position(value: Array) -> Vector3:
	return Vector3(float(value[0]),float(value[1]),float(value[2]))

func _record_crossing(route: String) -> bool:
	if Ending.crossing_needed(game.story_state) and not _cohort_ready(): return false
	return Ending.player_crossed(route,game.story_state) if Ending.crossing_needed(game.story_state) else Rules.record_route_crossing(route,game.story_state,game.quests)

func _refresh_cohort() -> void:
	var state=game.story_state
	var visible := Ending.departing(state) and Rules._true(state,"open_road_relocation_started") and ((zone=="lantern_reach" and not Rules._true(state,"open_road_route_delivered")) or (zone=="hearthward" and Rules._true(state,"open_road_route_delivered")))
	if not visible:
		if is_instance_valid(cohort): cohort.queue_free()
		cohort=null; cohort_drivers.clear()
		return
	if not is_instance_valid(cohort):
		cohort=Node3D.new(); cohort.name="OpenRoadHouseholds"
		game.zone_root.add_child(cohort)
		for index in range(2):
			var role := "villager_human" if index==0 else "villager_female_human"
			var visual=game._make_role_visual(role,"characters",Vector3.ONE)
			if visual==null:
				push_error("Required relocated household visual is unavailable: "+role)
				continue
			var body := Node3D.new()
			body.name=Ending.HOUSEHOLDS[index]; body.position.z=-.36 if index==0 else .36
			body.rotation.y=-PI/2.0
			body.set_meta("locomotion_owner","community_activity")
			cohort.add_child(body); body.add_child(visual)
			visual.set_meta("locomotion_owner","community_activity")
			game._configure_npc_animation(visual,role)
			var driver=visual.get_node_or_null("CharacterAnimationDriver")
			if driver!=null: driver.set_update_rate_hz(30); cohort_drivers.append(driver)
	var progress := clampf(float(state.get_flag("open_road_crossing_progress",0.0)),0.0,1.0)
	cohort.position=Vector3(-8.4,0,3.4) if zone=="hearthward" else Vector3(lerpf(3.0,10.5,progress),.185,0)
	if zone=="lantern_reach" and str(state.get_flag("community_route",""))=="ferry": cohort.position=Vector3(10.8,0,-1.5) if progress>=1.0 else Vector3(2,0,0)
	for index in cohort.get_child_count(): cohort.get_child(index).position=Vector3(0,0,-.36 if index==0 else .36)
	_cohort_motion(Vector3.ZERO)

func _tick_cohort(delta: float) -> void:
	if not _cohort_ready() or zone!="lantern_reach" or not Ending.crossing_needed(game.story_state) or str(game.story_state.get_flag("community_route",""))!="crossing" or not _passage_safe():
		_cohort_motion(Vector3.ZERO)
		return
	var player: Vector3=game.zone_root.to_local(game.player.global_position)
	var before: Vector3=cohort.position
	if player.distance_to(cohort.position)<5.5 and player.x>cohort.position.x+.85:
		cohort.position.x=move_toward(cohort.position.x,minf(player.x-.85,10.5),1.2*delta)
		cohort.position.y=.185
	_cohort_motion((cohort.position-before)/maxf(delta,.001))
	# The existing activity owner saves progress; no new controller/disk writes.
	game.story_state.flags["open_road_crossing_progress"]=clampf((cohort.position.x-3.0)/7.5,0.0,1.0)
	if Ending.finish_crossing(game.story_state): _crossing_finished()

func _cohort_motion(velocity: Vector3) -> void:
	for driver: Node in cohort_drivers:
		if is_instance_valid(driver): driver.set_locomotion_motion(velocity,true)

func _passage_safe() -> bool:
	return is_instance_valid(game.player) and game.player.can_control and not game.player.transition_locked and float(game.player.health_component.health)>0 and float(game.player.hurt_react_time)<=0 and not game._journey_load_pending() and not game.zone_transition_pending and not game.zone_load_request_pending and game.pending_player_restore.is_empty() and not director._danger_near(game)

func _cohort_ready() -> bool:
	return is_instance_valid(cohort) and cohort.get_child_count()==2 and cohort_drivers.size()==2 and cohort.get_children().all(func(body): return body.is_visible_in_tree()) and cohort_drivers.all(func(driver): return is_instance_valid(driver) and driver.has_method("is_valid") and driver.is_valid())
