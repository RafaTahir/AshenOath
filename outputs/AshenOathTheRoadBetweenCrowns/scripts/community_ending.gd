extends RefCounted

## Expanded covenant consequences. Existing covenant/activity owners call these
## pure transitions; no process, travel, save or NPC owner is introduced here.
const Rules = preload("res://scripts/community_campaign.gd")
const DEPARTURE_ANSWERS := "community_departure_consent"
const RELOCATED := "open_road_named_roster"
const HOUSEHOLDS := ["water_carrier", "quality_sweeper"]

static func departing(state) -> bool:
	return Rules.enabled(state) and str(state.get_flag("final_covenant",""))=="open_road"

static func journey_open(state) -> bool:
	return departing(state) and Rules._true(state,"open_road_relocation_started") and not Rules._true(state,"final_choice_completed")

static func offers_available(id: String, state, quests) -> bool:
	return Rules.actor_available(id,state,quests) and str(state.get_flag("final_covenant",""))=="" and quests!=null and quests.is_completed("main_house_many_names") and Rules.data().get("departure_offers",{}).has(id)

static func record_answer(id: String, accepted: bool, state, quests) -> bool:
	if not offers_available(id,state,quests): return false
	var raw: Variant=state.get_flag(DEPARTURE_ANSWERS,{})
	var answers: Dictionary=raw.duplicate(true) if raw is Dictionary else {}
	answers[id]=accepted
	state.set_flag(DEPARTURE_ANSWERS,answers)
	return true

static func enact(step: int, state, quests) -> bool:
	if not departing(state) or not Rules._true(state,"covenant_ritual_started") or step!=int(state.get_flag("covenant_ritual_step",0)): return false
	match step:
		0:
			# The authored signed household requests are read at the first anchor.
			# They do not authorize any of the twelve named participants.
			state.set_flag("open_road_households",HOUSEHOLDS.duplicate())
			var raw: Variant=state.get_flag(DEPARTURE_ANSWERS,{})
			var roster: Array[String]=[]
			if raw is Dictionary:
				for id: String in Rules.ACTORS:
					if typeof(raw.get(id))==TYPE_BOOL and raw[id] and Rules.actor_available(id,state,quests): roster.append(id)
			state.set_flag(RELOCATED,roster)
		1:
			state.set_flag("open_road_protection_dismantled",true)
			state.set_flag("territorial_protection_active",false)
			state.set_flag("hart_complete_account_access",false)
			state.set_flag("human_records_preserved",true)
		2:
			if not Rules._true(state,"open_road_protection_dismantled"): return false
			state.set_flag("open_road_relocation_started",true)
		_: return false
	return true

static func action_available(operation: String, zone: String, state) -> bool:
	if not journey_open(state) or int(state.get_flag("covenant_ritual_step",0))<3: return false
	if not Rules._true(state,"community_route_ready") or not Rules._true(state,"community_refuge_ready"): return false
	match operation:
		"departure_load": return zone=="lantern_reach" and not Rules._true(state,"open_road_load_carried") and not Rules._true(state,"open_road_route_delivered")
		"departure_delivery": return zone=="lantern_reach" and Rules._true(state,"open_road_load_carried") and Rules._true(state,"open_road_route_crossed") and not Rules._true(state,"open_road_route_delivered")
		"departure_arrival": return zone=="hearthward" and Rules._true(state,"open_road_route_delivered") and not Rules._true(state,"open_road_relocation_completed")
	return false

static func complete_action(operation: String, zone: String, state) -> bool:
	if not action_available(operation,zone,state): return false
	match operation:
		"departure_load":
			state.set_flag("open_road_load_carried",true)
			state.set_flag("open_road_crossing_progress",0.0)
		"departure_delivery":
			state.set_flag("open_road_route_delivered",true)
			state.set_flag("open_road_load_carried",false)
		"departure_arrival":
			state.set_flag("open_road_relocation_completed",true)
			state.set_flag("covenant_ritual_ready",true)
	return true

static func crossing_needed(state) -> bool:
	return journey_open(state) and Rules._true(state,"open_road_load_carried") and not Rules._true(state,"open_road_route_crossed")

static func player_crossed(route: String, state) -> bool:
	if not crossing_needed(state) or route!=str(state.get_flag("community_route","")) or route not in ["crossing","ferry"]: return false
	state.set_flag("open_road_player_crossed",true)
	if route=="ferry": state.set_flag("open_road_crossing_progress",1.0)
	return finish_crossing(state)

static func finish_crossing(state) -> bool:
	if not crossing_needed(state) or not Rules._true(state,"open_road_player_crossed") or float(state.get_flag("open_road_crossing_progress",0.0))<1.0: return false
	state.set_flag("open_road_route_crossed",true)
	return true

static func ready_to_finish(state) -> bool:
	return departing(state) and int(state.get_flag("covenant_ritual_step",0))==3 and Rules._true(state,"open_road_protection_dismantled") and Rules._true(state,"open_road_route_crossed") and Rules._true(state,"open_road_route_delivered") and Rules._true(state,"open_road_relocation_completed") and state.get_flag("territorial_protection_active") == false and state.get_flag("hart_complete_account_access") == false and Rules._true(state,"human_records_preserved")

static func relocated(id: String, state) -> bool:
	if not departing(state) or not Rules._true(state,"open_road_relocation_started"): return false
	if id in HOUSEHOLDS: return id in state.get_flag("open_road_households",[])
	var canonical: String=preload("res://scripts/story_cast_profile.gd").canonical_identity(id)
	return canonical!="" and canonical in state.get_flag(RELOCATED,[])

static func continuation(state) -> Dictionary:
	var operation := "departure_load"
	if Rules._true(state,"open_road_route_delivered"): operation="departure_arrival"
	elif Rules._true(state,"open_road_route_crossed"): operation="departure_delivery"
	elif Rules._true(state,"open_road_load_carried"): operation="departure_crossing"
	return Rules.data().get("departure_journey",{}).get(operation,{}).duplicate(true)

static func roster_text(state) -> String:
	var names: Array[String]=[]
	for id: String in state.get_flag(RELOCATED,[]): names.append(str(Rules.data().participant_lines[id].name))
	return "Named people who agreed to relocate: "+(", ".join(names) if not names.is_empty() else "none recorded")+". Every other named person's home and answer remain unchanged."
