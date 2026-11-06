extends SceneTree

const Community = preload("res://scripts/community_campaign.gd")
const Revision = preload("res://scripts/campaign_revision.gd")
const Quests = preload("res://scripts/quest_manager.gd")
const State = preload("res://scripts/story_state.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for route: String in ["crossing","ferry"]:
		_chain(route)
	_revision_boundaries()
	for failure: String in failures: printerr("COMMUNITY CAMPAIGN: " + failure)
	print("COMMUNITY CAMPAIGN: %s checks=%d (real quest/state owners; memory only; no world or physical-input claim)" % ["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)

func _manager() -> Node:
	var manager := Quests.new()
	manager.load_quests("res://data/quests.json")
	_check(manager.configure_campaign_revision(2),"authored expanded graph accepted")
	return manager

func _chain(route: String) -> void:
	var state := State.new()
	state.set_flag("campaign_revision",2)
	var quests := _manager()
	for id: String in Revision.NEW_CHAPTERS:
		if not quests.is_active(id):
			quests.unlocked[id] = true
			_check(quests.start_quest(id),"explicit test entry starts " + id)
		var zone := str(Community.chapter(id).region)
		_check(not Community.finish_aftermath(id,zone,state,quests),"aftermath cannot bypass preparation")
		if id in ["main_empty_tables","main_house_many_names"]:
			_check(quests.complete_objective(id,str(Revision.OBJECTIVES[id][0])),"arrival owner completes region arrival")
			_check(Community.apply_board_action({"operation":"account","quest":id},zone,state,quests),"public account records preparation needs")
		elif id == "main_road_kept_open":
			_check(not Community.apply_board_action({"operation":"account","quest":id},zone,state,quests),"board cannot substitute for physical survey")
			_check(Community.inspect_landing("near",zone,state,quests),"near landing inspection accepted")
			_check(not Community.inspect_landing("near",zone,state,quests),"duplicate inspection has no effect")
			_check(not quests.is_objective_done(id,"survey_crossing"),"one landing is insufficient")
			_check(Community.inspect_landing("far",zone,state,quests),"both landings surveyed")
			_check(Community.apply_board_action({"operation":"choice","quest":id,"value":route},zone,state,quests),"chosen route commits through explicit choice owner")
		else:
			_check(Community.apply_board_action({"operation":"account","quest":id},zone,state,quests),"meeting account accepts absent participants")
		var tasks := Community.work_ids(id,state)
		_check(tasks.size()==3,"three concrete preparation tasks selected")
		for work: String in tasks:
			_check(not Community.complete_work(work,"greyfen",state,quests),"wrong region cannot complete physical work")
			_check(Community.complete_work(work,zone,state,quests),"physical completion accepted: " + work)
			_check(not Community.complete_work(work,zone,state,quests),"work completion is idempotent")
		_check(quests.is_objective_done(id,Community.PREPARATION[id]),"all physical work finishes preparation objective")
		if id in ["main_empty_tables","main_house_many_names"]:
			var choice := "central" if id == "main_empty_tables" else "distributed"
			_check(not Community.apply_board_action({"operation":"choice","quest":id,"value":"forged"},zone,state,quests),"unknown distribution/custody choice rejected")
			_check(Community.apply_board_action({"operation":"choice","quest":id,"value":choice},zone,state,quests),"valid choice recorded")
			_check(not quests.is_completed(id),"choice alone does not enact aftermath")
		elif id == "main_what_we_promise":
			_check(not Community.record_consent("sister_anwen",true,state,quests),"consent requires canonical participant identity")
			_check(Community.record_consent("anwen",true,state,quests),"actual Anwen offer can be recorded")
			_check(Community.record_consent("anwen",false,state,quests),"Anwen may withdraw before ending")
			_check(Community.apply_board_action({"operation":"vacancies","quest":id},zone,state,quests),"posting vacancies preserves refusal")
			_check(state.get_flag("community_keeper_consent",{}).get("anwen")==false,"vacancy action does not infer consent")
		if id == "main_road_kept_open":
			_check(not Community.finish_aftermath(id,zone,state,quests,true),"delivery requires an actual load")
			_check(Community.finish_aftermath(id,zone,state,quests),"first load can be carried")
			_check(not quests.is_completed(id),"loading alone does not complete crossing")
			_check(not Community.finish_aftermath(id,zone,state,quests,true),"far-landing action cannot bypass physical crossing")
			_check(not Community.record_route_crossing("ferry" if route=="crossing" else "crossing",state,quests),"wrong route cannot record passage")
			_check(Community.record_route_crossing(route,state,quests),"the selected route records physical passage")
			_check(not Community.record_route_crossing(route,state,quests),"duplicate passage cannot repeat credit")
			var restored := _manager()
			restored.load_state(quests.save_state())
			state.load_state(JSON.parse_string(JSON.stringify(state.save_state())))
			quests.free()
			quests = restored
			_check(Community.finish_aftermath(id,zone,state,quests,true),"enacted far-landing delivery completes after reload")
		else:
			_check(Community.finish_aftermath(id,zone,state,quests),"physical enacted aftermath completes chapter")
		_check(quests.is_completed(id),"chapter complete through actual quest owner: " + id)
		_check(not Community.finish_aftermath(id,zone,state,quests),"repeating aftermath cannot duplicate completion")
	_check(Revision.expansion_completed(quests),"all four chapters complete")
	_check(not Community.actor_available("senn",state,quests),"unresolved Senn cannot be recruited")
	for fate: String in ["exile","punished"]:
		state.set_flag("senn_fate",fate)
		_check(not Community.actor_available("senn",state,quests),"departed Senn outcome respected")
	state.set_flag("senn_fate","testimony")
	_check(Community.actor_available("senn",state,quests),"surviving testimony Senn available")
	state.set_flag("final_covenant","witness")
	_check(not Community.record_consent("mira",true,state,quests),"ending lock rejects changed consent")
	quests.free()
	state.free()

func _revision_boundaries() -> void:
	for marker: Variant in [null,1,1.0]:
		for region: String in Revision.NEW_ZONES:
			var flags := {} if marker == null else {"campaign_revision":marker}
			var save := {"zone":region,"story_state":{"flags":flags}}
			_check(Revision.save_revision_error(save)=="campaign_region_revision_mismatch","legacy new-region save rejects without inference")
			_check(Revision.from_save(save)==1,"region name cannot upgrade revision")
	_check(Revision.save_revision_error({"zone":"lantern_reach","story_state":{"flags":{"campaign_revision":3}}})=="future_version","future revision retains diagnostic priority")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/story_campaign.json"))
	var legacy := Revision.project_catalog(catalog,1)
	var expanded := Revision.project_catalog(catalog,2)
	_check(legacy.chapters.size()==10 and legacy.endings.size()==4,"legacy catalog retains ten chapters and four endings")
	_check(expanded.chapters.size()==14 and expanded.endings.size()==6,"expanded catalog exposes fourteen chapters and six endings")
	_check(catalog.chapters.size()==14,"projection does not mutate authored catalog")

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
