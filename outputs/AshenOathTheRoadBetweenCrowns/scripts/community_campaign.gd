extends RefCounted

## Pure chapter rules. StoryActivityDirector owns interaction time and physical
## validation; QuestManager owns objective completion, unlocks and rewards.
const Revision = preload("res://scripts/campaign_revision.gd")
const Endings = preload("res://scripts/ending_catalog.gd")
const DATA_PATH := "res://data/community_campaign.json"
const ACTORS := {"anwen":"sister_anwen","rook":"rook","mira":"mira","tor":"blacksmith_tor","elna":"widow_elna","toma":"farmer_toma","senn":"captain_senn","edric":"edric_campaign","vale":"vargan_record_keeper","merrow":"vargan_steward","nessa":"saga_nessa","nera":"saga_nera"}
const REGIONAL_ACTORS := {"lantern_reach":["nessa","elna","toma","tor","rook","nera"],"hearthward":["anwen","mira","vale","merrow","nessa","nera","rook","tor","elna","toma","edric","senn"]}
const READINESS := {"main_empty_tables":"community_kitchen_ready","main_road_kept_open":"community_route_ready","main_house_many_names":"community_refuge_ready"}
const PREPARATION := {"main_empty_tables":"prepare_kitchen","main_road_kept_open":"secure_route","main_house_many_names":"prepare_refuge","main_what_we_promise":"test_arrangements"}
const BOARDS := {
	"lantern_reach":{"position":[-2,0,7],"title":"The landing's waiting table"},
	"hearthward":{"position":[0,0,7],"title":"The refuge's public table"}
}
const AFTERMATH := {
	"main_empty_tables":{"position":[-5,0,5],"prompt":"Serve the first meal under the chosen arrangement","seconds":4.0,"kind":"sort"},
	"main_road_kept_open":{"position":[3,0,0],"prompt":"Load the first public passage","seconds":4.0,"kind":"haul"},
	"main_house_many_names":{"position":[-7,0,5],"prompt":"Welcome the arrivals without requiring their names","seconds":4.0,"kind":"sort"},
	"main_what_we_promise":{"position":[0,0,11],"prompt":"Keep the first watch beside the posted rota","seconds":6.0,"kind":"inspect"}
}
static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(DATA_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary and int(parsed.get("version",0)) == 1: _data = parsed
	return _data

static func enabled(state) -> bool:
	return Revision.from_state(state) == Revision.EXPANDED

static func chapter(quest: String) -> Dictionary:
	return data().get("chapters",{}).get(quest,{})

static func active_chapter(zone: String, quests, state) -> String:
	if not enabled(state) or quests == null: return ""
	for id: String in Revision.NEW_CHAPTERS:
		if str(chapter(id).get("region","")) == zone and quests.is_active(id): return id
	return ""

static func current_objective(quest: String, quests) -> String:
	return str(quests.get_active_objective_id(quest)) if quests != null and quests.is_active(quest) else ""

static func actor_available(id: String, state, quests) -> bool:
	if not enabled(state) or not ACTORS.has(id): return false
	if id == "senn": return str(state.get_flag("senn_fate","")) == "testimony"
	if id == "edric": return str(state.get_flag("edric_stance","")) == "cooperate"
	# The personal account remains with Nera's existing introduction. An absent
	# keeper never blocks shelter, meals or the original four ending options.
	if id == "nera":
		return _true(state,"escort_abandonment_acknowledged") and (quests == null or not quests.is_active("side_escort_04"))
	return true

static func presence_shift(minutes: float) -> String:
	var time := fposmod(minutes,1440.0)
	return "morning" if time >= 420.0 and time < 1080.0 else "evening"

static func actor_present(id: String, zone: String, minutes: float, state, quests) -> bool:
	if not actor_available(id,state,quests) or id not in REGIONAL_ACTORS.get(zone,[]): return false
	var shifts: Dictionary = data().get("presence_shifts",{}).get(zone,{})
	return shifts.is_empty() or id in shifts.get(presence_shift(minutes),[])

static func work_ids(quest: String, state) -> Array:
	var row := chapter(quest)
	if row.has("work"): return row.work.duplicate()
	var choice := str(state.get_flag(str(row.get("choice","")),""))
	return row.get("choices",{}).get(choice,{}).get("work",[]).duplicate()

static func work_quest(id: String) -> String:
	for quest: String in Revision.NEW_CHAPTERS:
		var row := chapter(quest)
		if id in row.get("work",[]): return quest
		for choice: Dictionary in row.get("choices",{}).values():
			if id in choice.get("work",[]): return quest
	return ""

static func work_available(id: String, zone: String, state, quests) -> bool:
	if not enabled(state): return false
	var task: Dictionary = data().get("work",{}).get(id,{})
	var quest := work_quest(id)
	return not task.is_empty() and str(task.region) == zone and current_objective(quest,quests) == str(PREPARATION.get(quest,"!")) \
		and id in work_ids(quest,state) and not _true(state,"community_work:"+id)

static func complete_work(id: String, zone: String, state, quests) -> bool:
	if not work_available(id,zone,state,quests): return false
	var quest := work_quest(id)
	state.set_flag("community_work:"+id,true)
	var all_done := true
	for task: String in work_ids(quest,state):
		if not _true(state,"community_work:"+task): all_done = false
	if all_done:
		if READINESS.has(quest): state.set_flag(READINESS[quest],true)
		_complete(quest,PREPARATION[quest],quests)
	return true

static func board_actions(zone: String, state, quests) -> Array[Dictionary]:
	var quest := active_chapter(zone,quests,state)
	var objective := current_objective(quest,quests)
	var result: Array[Dictionary] = []
	if objective in ["hear_households","gather_cast"]:
		result.append({"operation":"account","quest":quest,"label":{"hear_households":"Hear the practical needs without asking for private names.","survey_crossing":"Inspect the current and both marked landings.","gather_cast":"Open the meeting and set out the available answers."}[objective]})
	var row := chapter(quest)
	if row.has("choices") and objective in ["settle_tables","agree_route","settle_records"] and str(state.get_flag(str(row.choice),"")) == "":
		for value: String in row.choices:
			result.append({"operation":"choice","quest":quest,"value":value,"label":str(row.choices[value].label),"preview":str(row.choices[value].aftermath)})
	if objective == "choose_responsibilities":
		result.append({"operation":"vacancies","quest":quest,"label":"Post only the answers actually given; leave every other shift vacant."})
	return result

static func apply_board_action(action: Dictionary, zone: String, state, quests) -> bool:
	var accepted := false
	for allowed: Dictionary in board_actions(zone,state,quests):
		if str(allowed.operation) == str(action.get("operation","")) and str(allowed.quest) == str(action.get("quest","")) and str(allowed.get("value","")) == str(action.get("value","")):
			accepted = true
			break
	if not accepted: return false
	var quest := str(action.quest)
	var objective := current_objective(quest,quests)
	match str(action.operation):
		"account":
			# Survey requires actually visiting both physical inspection stations.
			if objective == "survey_crossing": return false
			state.set_flag("community_account:"+quest,true)
			_complete(quest,objective,quests)
		"choice":
			var row := chapter(quest)
			state.set_flag(str(row.choice),str(action.value))
			# Kitchen/refuge decisions remain unfinished until the enacted return.
			if objective == "agree_route": _complete(quest,objective,quests)
		"vacancies":
			state.set_flag("community_rota_posted",true)
			_complete(quest,objective,quests)
		_: return false
	return true

static func inspect_landing(id: String, zone: String, state, quests) -> bool:
	if not enabled(state) or zone != "lantern_reach" or id not in ["near","far"] or current_objective("main_road_kept_open",quests) != "survey_crossing": return false
	if _true(state,"community_survey:"+id): return false
	state.set_flag("community_survey:"+id,true)
	if _true(state,"community_survey:near") and _true(state,"community_survey:far"):
		_complete("main_road_kept_open","survey_crossing",quests)
	return true

static func aftermath_available(quest: String, zone: String, state, quests) -> bool:
	if not enabled(state) or not AFTERMATH.has(quest) or str(chapter(quest).get("region","")) != zone: return false
	var objectives: Array = Revision.OBJECTIVES[quest]
	if current_objective(quest,quests) != str(objectives.back()): return false
	var row := chapter(quest)
	if row.has("choice") and not row.get("choices",{}).has(str(state.get_flag(str(row.choice),""))): return false
	if READINESS.has(quest) and not _true(state,READINESS[quest]): return false
	return true

static func finish_aftermath(quest: String, zone: String, state, quests, delivered: bool = false) -> bool:
	if not aftermath_available(quest,zone,state,quests): return false
	if quest == "main_road_kept_open":
		if not delivered:
			if _true(state,"community_route_load_carried"): return false
			state.set_flag("community_route_load_carried",true)
			state.set_flag("community_route_load_crossed",false)
			return true
		if not _true(state,"community_route_load_carried"): return false
		if not _true(state,"community_route_load_crossed"): return false
		state.set_flag("community_route_load_carried",false)
	state.set_flag("community_aftermath:"+quest,true)
	_complete(quest,str((Revision.OBJECTIVES[quest] as Array).back()),quests)
	return true

static func record_route_crossing(route: String, state, quests) -> bool:
	if not aftermath_available("main_road_kept_open","lantern_reach",state,quests) or not _true(state,"community_route_load_carried") or _true(state,"community_route_load_crossed") or route not in ["crossing","ferry"] or str(state.get_flag("community_route","")) != route: return false
	state.set_flag("community_route_load_crossed",true)
	return true

static func consent_available(id: String, state, quests) -> bool:
	if not data().get("consent_offers",{}).has(id) or not actor_available(id,state,quests): return false
	if str(state.get_flag("final_covenant","")) != "": return false
	return quests != null and (quests.is_active("main_what_we_promise") or quests.is_completed("main_what_we_promise"))

static func record_consent(id: String, accepted: bool, state, quests) -> bool:
	if not consent_available(id,state,quests): return false
	return Endings.record_keeper_consent(state,id,accepted)

static func aftermath_text(quest: String, state) -> String:
	var row := chapter(quest)
	var value := str(state.get_flag(str(row.get("choice","")),""))
	if row.get("choices",{}).has(value): return str(row.choices[value].aftermath)
	return "The rota lists only freely offered shifts. Vacancies remain visible, with a way to withdraw. Food and shelter stay open to people who refuse."

static func _complete(quest: String, objective: String, quests) -> bool:
	return quests.complete_choice(quest,objective) if quests.is_choice_objective(quest,objective) else quests.complete_objective(quest,objective)

static func _true(state, key: String) -> bool:
	var value: Variant = state.get_flag(key,false)
	return typeof(value) == TYPE_BOOL and value
