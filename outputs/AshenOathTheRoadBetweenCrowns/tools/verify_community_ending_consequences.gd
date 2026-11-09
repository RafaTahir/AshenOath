extends "res://tools/verify_replay_import_isolation.gd"
## Pure transitions and in-memory import/reload. No world, models or engine
## interaction proof; the rendered acceptance harness separately earns input.
const Ending = preload("res://scripts/community_ending.gd")
const Endings = preload("res://scripts/ending_catalog.gd")
const Rules = preload("res://scripts/community_campaign.gd")
const Revision = preload("res://scripts/campaign_revision.gd")
const State = preload("res://scripts/story_state.gd")
const Quests = preload("res://scripts/quest_manager.gd")
const Routes = preload("res://scripts/story_route_catalog.gd")

func _run() -> void:
	OS.add_logger(error_log)
	for route: String in ["crossing","ferry"]:
		for replay: bool in [false,true]: _departure(route,replay)
	_concord()
	for marker: Variant in [null,1]:
		var raw := _payload("legacy-ending")
		if marker!=null: raw.story_state.flags.campaign_revision=marker
		raw.story_state.flags.final_covenant="open_road"
		_check(Revision.save_revision_error(raw)!="","Legacy can never infer expanded ending from an outcome flag")
	await process_frame
	OS.remove_logger(error_log)
	_check(error_log.errors.is_empty(),"No engine/script errors")
	for error: String in error_log.errors: printerr(error)
	print("COMMUNITY ENDING CONSEQUENCES: %s checks=%d storage=in_memory world=none" % ["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)

func _quests() -> Node:
	var quests := Quests.new()
	quests.load_quests("res://data/quests.json")
	quests.configure_campaign_revision(2)
	for id: String in Revision.NEW_CHAPTERS: quests.completed[id]=true
	return quests

func _departure(route: String, replay: bool) -> void:
	var state := State.new()
	var quests := _quests()
	state.set_flag("campaign_revision",2)
	state.set_flag("community_route",route)
	state.set_flag("community_route_ready",true)
	state.set_flag("community_refuge_ready",true)
	state.record_evidence("human_command",{"text":"Unchanged human evidence","private":true})
	var evidence := state.evidence.duplicate(true)
	_check(Ending.record_answer("elna",true,state,quests),"Individual explicitly chooses relocation")
	_check(Ending.record_answer("toma",false,state,quests),"Individual refusal is recorded")
	_check(not Ending.record_answer("senn",true,state,quests),"Absent/exiled Senn cannot be enrolled")
	_check(not Ending.record_answer("nera",true,state,quests),"Unintroduced Nera cannot be enrolled")
	_check(Ending.record_answer("elna",false,state,quests),"Relocation answer can be withdrawn before lock")
	_check(Ending.record_answer("elna",true,state,quests),"Only a new personal answer restores relocation consent")
	state.set_flag("community_keeper_consent",{"mira":true})
	state.set_flag("final_covenant","open_road")
	state.set_flag("covenant_ritual_started",true)
	_check(not Ending.record_answer("toma",true,state,quests),"Locked roster cannot be filled by a late forged action")
	_check(not Ending.enact(2,state,quests),"Last glade act cannot skip dismantling")
	for step in range(3):
		state.set_flag("covenant_ritual_step",step)
		_check(Ending.enact(step,state,quests),"Ordered glade act accepted")
		state.set_flag("covenant_ritual_step",step+1)
		_check(not Ending.ready_to_finish(state),"Glade tokens alone never complete relocation")
	_check(state.get_flag(Ending.RELOCATED)==["elna"],"Keeper consent, silence and refusal never create a departure answer")
	_check(state.get_flag("territorial_protection_active")==false and state.get_flag("hart_complete_account_access")==false,"Both irreversible losses are explicit")
	_check(state.evidence==evidence,"Dismantling never edits human evidence")
	_check(Routes.ending_continuation(state,"hart_glade").destination_zone=="lantern_reach","Pending load directs to prepared route after reload")
	_check(not Ending.complete_action("departure_arrival","hearthward",state),"Refuge arrival cannot bypass passage")
	_check(Ending.complete_action("departure_load","lantern_reach",state),"Collect actual household load")
	_check(not Ending.complete_action("departure_load","lantern_reach",state),"Load is single-use")
	_check(not Ending.player_crossed("ferry" if route=="crossing" else "crossing",state),"Unprepared route never counts")
	if route=="crossing":
		_check(not Ending.player_crossed(route,state),"Player crossing alone cannot strand the households")
		state.set_flag("open_road_crossing_progress",1.0)
		_check(Ending.finish_crossing(state),"Households must reach the far bank too")
	else:
		_check(Ending.player_crossed(route,state),"Completed ferry carries passengers and last load together")
	_check(Ending.complete_action("departure_delivery","lantern_reach",state),"Secure people and evidence on far bank")
	_check(not Ending.ready_to_finish(state),"Crossing alone still requires a prepared refuge arrival")
	_check(Routes.ending_continuation(state,"lantern_reach").destination_zone=="hearthward","After passage guidance points at actual refuge")
	var manager := MemorySaveManager.new()
	root.add_child(manager)
	var raw := _payload("depart-"+route)
	raw.story_state=state.save_state(); raw.replay_session=replay
	raw.world_state.pending_ending="depart"; raw.zone="lantern_reach"; raw.world_sector="lantern_reach"
	_check(manager.import_save_text(JSON.stringify(raw),"manual_1"),"Mid-relocation save imports without losing costs")
	var restored: Dictionary=manager._read_slot(manager.slot_path("manual_1")).data
	_check(restored.replay_session==replay,"Replay mode survives import")
	for key: String in raw.story_state.flags:
		var expected: Variant=raw.story_state.flags[key]
		var actual: Variant=restored.story_state.flags.get(key)
		var same: bool = (typeof(actual) in [TYPE_INT,TYPE_FLOAT] and actual==expected) if typeof(expected) in [TYPE_INT,TYPE_FLOAT] else JSON.stringify(actual)==JSON.stringify(expected)
		_check(same,"Relocation/consent field survives JSON save format: "+key)

	state.load_state(restored.story_state)
	_check(Ending.complete_action("departure_arrival","hearthward",state),"Actual arrival finishes remaining obligation")
	_check(Ending.ready_to_finish(state),"Only complete relocation permits final chapter completion")
	state.set_flag("final_choice_completed",true)
	raw.story_state=state.save_state(); raw.world_state.pending_ending=""
	_check(Revision.save_revision_error(raw)=="","Completed consequence state is restorable")
	for key: String in ["open_road_route_crossed","open_road_route_delivered","open_road_relocation_completed","territorial_protection_active","hart_complete_account_access","human_records_preserved"]:
		var corrupt := raw.duplicate(true)
		corrupt.story_state.flags.erase(key)
		_check(Revision.save_revision_error(corrupt)!="","Incomplete saved consequence is rejected: "+key)
	_check(Ending.relocated("widow_elna",state) and not Ending.relocated("farmer_toma",state),"Home/routine projection respects individual answers")
	_check(state.evidence==evidence,"Arrival retains exact human evidence")
	state.free(); quests.free(); manager.queue_free()

func _concord() -> void:
	var state := State.new()
	var quests := _quests()
	state.set_flag("campaign_revision",2)
	for id: String in ["anwen","nessa","vale"]: _check(Endings.record_keeper_consent(state,id,true),"Participant offers initial keeper shift")
	var original: Dictionary=state.get_flag(Endings.CONSENT_FLAG).duplicate(true)
	state.set_flag("final_keeper_consent",original)
	state.set_flag("final_covenant","concord")
	state.set_flag("final_choice_completed",true)
	_check(Rules.consent_available("nessa",state,quests),"Continuing obligation remains available for an in-person answer")
	_check(Rules.record_consent("nessa",false,state,quests),"Keeper can withdraw after ending is enacted")
	_check(Endings.concord_route_closed(state),"Uncovered logistics closes the public passage")
	_check(state.get_flag("final_keeper_consent")==original,"Current withdrawal cannot rewrite original acceptance")
	_check(not Rules.record_consent("nera",true,state,quests),"Unavailable replacement cannot fill the vacancy")
	_check(Rules.record_consent("nessa",true,state,quests),"Existing participant may freely return")
	_check(not Endings.concord_route_closed(state),"New consent reopens the public passage")
	state.free(); quests.free()
