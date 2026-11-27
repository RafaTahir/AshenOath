extends RefCounted

const Rules = preload("res://scripts/community_campaign.gd")
const NOVEL_GROUPS := [
	{"id":"bera", "members":["bera","bera_daughter","bera_child_1","bera_child_2"], "labels":["Bera","Bera's daughter","Bera's older grandchild","Bera's younger grandchild"], "passengers":4},
	{"id":"siv", "members":["siv","siv_father","siv_sister"], "labels":["Siv","Siv's father","Siv's sister"], "passengers":3},
]
const NOVEL_LOSSES := ["Siv's father's chair", "a bedding chest", "two sacks of grain", "much of the last load of tools"]
const NOVEL_PROMPTS := {"departure_load":"Read back the two household requests and check the lines", "departure_second_rescue":"Bring Siv's household down to the west-bank ferry", "departure_delivery":"Count seven safe on the east bank and take shelter", "departure_arrival":"Count both households inside Hearthward", "departure_handover":"Agree the relief routes and seated stores check", "departure_crossing":"Board the ferry at its current dock"}

static func novel_departure(state: Object) -> bool:
	if state == null: return false
	var edition: Variant = state.get_flag("novel_edition",0)
	return departing(state) and typeof(edition) in [TYPE_INT,TYPE_FLOAT] and edition == 1

static func _departure_legs(state: Object) -> int:
	var value: Variant = state.get_flag("novel_departure_legs",0)
	if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or value < 0 or value > 3 or value != int(value): return -1
	return int(value)

static func departure_manifest(state: Object) -> Dictionary:
	if not novel_departure(state) or _departure_legs(state) < 0: return {}
	var legs := _departure_legs(state)
	var groups: Array = NOVEL_GROUPS.duplicate(true)
	var arrived: Array[String] = []
	var count := 0
	for group: Dictionary in groups:
		group["arrived"] = legs >= (1 if group.id == "bera" else 3)
		if group.arrived:
			arrived.append(str(group.id))
			count += int(group.passengers)
	return {"capacity":6, "crew":["kael","ferryman"], "groups":groups, "completed_legs":legs, "arrived_groups":arrived, "arrived_passengers":count}

static func departure_dock(state: Object) -> String:
	if not novel_departure(state) or _departure_legs(state) < 0: return ""
	return "west" if _departure_legs(state) in [0,2] else "east"

static func next_departure_leg(state: Object) -> Dictionary:
	if not novel_departure(state) or not journey_open(state) or not Rules._true(state,"novel_departure_requests_verified") or not Rules._true(state,"open_road_load_carried"): return {}
	if int(state.get_flag("covenant_ritual_step",0)) != 3 or not Rules._true(state,"community_route_ready") or not Rules._true(state,"community_refuge_ready"): return {}
	var legs := _departure_legs(state)
	if legs < 0 or legs >= 3 or (legs == 2 and not Rules._true(state,"novel_departure_second_rescue")): return {}
	var group: Dictionary = NOVEL_GROUPS[0] if legs == 0 else (NOVEL_GROUPS[1] if legs == 2 else {})
	var passengers := int(group.get("passengers",0))
	return {"leg":legs+1, "from":departure_dock(state), "to":"east" if legs in [0,2] else "west", "group":group.get("id",""), "passengers":passengers, "passenger_ids":group.get("members",[]).duplicate(), "passenger_labels":group.get("labels",[]).duplicate(), "crew":2, "crew_ids":["kael","ferryman"], "aboard":passengers+2, "capacity":6}

static func complete_departure_leg(leg: int, state: Object) -> bool:
	# The existing activity owner verifies the physical far-dock arrival first.
	var expected := next_departure_leg(state)
	if expected.is_empty() or leg != int(expected.leg) or int(expected.aboard) > int(expected.capacity) or int(state.get_flag("covenant_ritual_step",0)) != 3: return false
	state.begin_change()
	state.set_flag("novel_departure_legs",leg)
	if leg == 3:
		state.set_flag("open_road_player_crossed",true)
		state.set_flag("open_road_crossing_progress",1.0)
		state.set_flag("open_road_route_crossed",true)
	state.end_change()
	return true

static func novel_action_text(operation: String) -> String:
	match operation:
		"departure_load": return "Vale read back both requests for shelter. Bera brought four and Siv brought three. Flood debris tore the upstream guide loose. The hauling line held."
		"departure_second_rescue": return "The Stalker cut Kael's calf. Rook and Siv's sister brought her father down while Siv steadied him. Kael cut his snagged bow loose so the ferry could leave. Rook stayed on his own bank."
		"departure_delivery": return "Nera counted seven safe on the east bank. Siv bound Kael's calf and Anwen cleaned it at the overnight shelter. The river took the chair, bedding chest, two grain sacks and much of the last tool load."
		"departure_arrival": return "Nera made the final mark after all seven were inside Hearthward. Mira put in twelve stitches, Anwen helped with the care, and Nessa found meals and dry beds."
		"departure_handover": return "Nera confirmed a crew for the Greyfen ferry and Siv and Toma for the mill. She took the outlying shelters with two drivers. Kael agreed to check stores seated with Merrow, and Vale will check after them."
	return ""

static func _novel_action_available(operation: String, zone: String, state: Object) -> bool:
	var legs := _departure_legs(state)
	if legs < 0: return false
	match operation:
		"departure_load": return zone == "lantern_reach" and legs == 0 and not Rules._true(state,"novel_departure_requests_verified") and not Rules._true(state,"open_road_load_carried") and not Rules._true(state,"open_road_route_delivered")
		"departure_second_rescue": return zone == "lantern_reach" and legs == 2 and Rules._true(state,"open_road_load_carried") and not Rules._true(state,"novel_departure_second_rescue")
		"departure_delivery": return zone == "lantern_reach" and legs == 3 and Rules._true(state,"open_road_load_carried") and Rules._true(state,"open_road_route_crossed") and not Rules._true(state,"open_road_route_delivered")
		"departure_arrival": return zone == "hearthward" and legs == 3 and Rules._true(state,"open_road_route_delivered") and not Rules._true(state,"open_road_relocation_completed") and int(departure_manifest(state).arrived_passengers) == 7
		"departure_handover": return zone == "hearthward" and legs == 3 and Rules._true(state,"open_road_relocation_completed") and state.get_flag("novel_departure_arrival_count",0) == 7 and not Rules._true(state,"novel_departure_handover")
	return false

static func _complete_novel_action(operation: String, state: Object) -> bool:
	var raw_care: Variant = state.get_flag("novel_departure_care",{})
	var care: Dictionary = raw_care.duplicate(true) if raw_care is Dictionary else {}
	state.begin_change()
	match operation:
		"departure_load":
			state.set_flag("novel_departure_requests_verified",true)
			state.set_flag("novel_departure_legs",0)
			state.set_flag("novel_departure_upstream_guide_lost",true)
			state.set_flag("novel_departure_hauling_line_retained",true)
			state.set_flag("open_road_load_carried",true)
			state.set_flag("open_road_crossing_progress",0.0)
			state.set_flag("covenant_ritual_ready",false)
		"departure_second_rescue":
			state.set_flag("novel_departure_calf_injured",true)
			state.set_flag("novel_departure_bow_lost",true)
			state.set_flag("novel_departure_second_rescue",true)
		"departure_delivery":
			state.set_flag("novel_departure_supply_losses",NOVEL_LOSSES.duplicate())
			care.merge({"wound_bound":"siv", "wound_cleaned":"anwen"},true)
			state.set_flag("novel_departure_care",care)
			state.set_flag("open_road_route_delivered",true)
			state.set_flag("open_road_load_carried",false)
		"departure_arrival":
			state.set_flag("novel_departure_arrival_count",7)
			care.merge({"arrival_count":"nera", "twelve_stitches":"mira", "food_and_places":"nessa"},true)
			state.set_flag("novel_departure_care",care)
			state.set_flag("open_road_relocation_completed",true)
			state.set_flag("covenant_ritual_ready",false)
		"departure_handover":
			state.set_flag("novel_departure_handover_assignments",{
				"greyfen_ferry":{"crew_assigned":true},
				"mill_run":{"carriers":["siv","toma"]},
				"outlying_shelters":{"lead":"nera","drivers":2},
				"stores_check":{"workers":["kael","merrow"],"seated":true},
				"follow_up":"vale",
			})
			state.set_flag("novel_departure_handover",true)
			state.set_flag("covenant_ritual_ready",true)
	state.end_change()
	return true

static func departing(state: Object) -> bool:
	return Rules.enabled(state) and str(state.get_flag("final_covenant",""))=="open_road"

static func journey_open(state: Object) -> bool:
	return departing(state) and Rules._true(state,"open_road_relocation_started") and not Rules._true(state,"final_choice_completed")


static func departure_continuation(state: Object) -> Dictionary:
	var novel_operation := "departure_load"
	if Rules._true(state,"novel_departure_handover"): return {}
	if Rules._true(state,"open_road_relocation_completed"): novel_operation = "departure_handover"
	elif Rules._true(state,"open_road_route_delivered"): novel_operation = "departure_arrival"
	elif _departure_legs(state) == 3: novel_operation = "departure_delivery"
	elif _departure_legs(state) == 2 and not Rules._true(state,"novel_departure_second_rescue"): novel_operation = "departure_second_rescue"
	elif Rules._true(state,"open_road_load_carried"): novel_operation = "departure_crossing"
	var base := "departure_arrival" if novel_operation == "departure_handover" else ("departure_load" if novel_operation == "departure_second_rescue" else novel_operation)
	var entry: Dictionary = Rules.data().get("departure_journey",{}).get(base,{}).duplicate(true)
	entry["operation"] = novel_operation
	entry["prompt"] = str(NOVEL_PROMPTS.get(novel_operation,""))
	entry["action"] = entry.prompt
	entry["text"] = {"departure_load":"Only Bera's four and Siv's three are passengers. Read both household requests back before working the surviving hauling line.", "departure_second_rescue":"Bera's four are safe east. The empty ferry returned west; Siv's father still needs help down to the boat.", "departure_delivery":"Both households are safe east. Count people separately from lost belongings, then find overnight shelter and wound care.", "departure_arrival":"Bring all seven inside Hearthward before Nera makes the final arrival mark.", "departure_handover":"The arrivals and care are recorded. Agree the next routes and seated stores check; companionship remains a separate choice.", "departure_crossing":"Keep each passenger group intact and leave room for Kael and the ferryman."}.get(novel_operation,"")
	entry["route_hint"] = "The household count belongs inside Hearthward." if novel_operation in ["departure_arrival","departure_handover"] else "Use the ferry's west and east landings; the lost guide is separate from the surviving hauling line."
	var target := "community:" + novel_operation
	if novel_operation == "departure_second_rescue": entry["position"] = [2.0,0.0,-1.5]
	elif novel_operation == "departure_handover": entry["position"] = [-4.5,0.0,4.5]
	if novel_operation == "departure_crossing":
		target = "community:ferry" if departure_dock(state) == "west" else "community:departure_return_ferry"
		entry["position"] = [3.0,0.0,0.8] if departure_dock(state) == "west" else [10.5,0.0,0.8]
	entry["target_ids"] = [target]
	return entry

static func chooses_to_stay(id: String, state: Object) -> bool:
	# Rook sends the relief on its way. His room, shop and obligations stay in Greyfen.
	return id == "rook" and state.get_flag("novel_edition",0) == 1

static func offers_available(id: String, state: Object, quests: Object) -> bool:
	return Rules.actor_available(id,state,quests) and str(state.get_flag("final_covenant",""))=="" and quests!=null and quests.is_completed("main_house_many_names") and Rules.data().get("departure_offers",{}).has(id)

static func expanded_steps(ending: String, state: Object) -> Array:
	var steps := preload("res://scripts/campaign_story_overlay.gd").ritual(ending,state)
	if ending == "depart" and not steps.is_empty() and novel_departure(state):
		steps[0] = ["Read Bera’s and Siv’s shelter requests", "Vale reads both requests aloud. Siv asks for beds and help carrying her father. Bera asks for a place her grandchildren can reach and somewhere to dry their boots. Shelter is available without an oath, testimony or a place on the keeper rota."]
		steps[2] = ["Meet the households at Lantern Reach", "The ward is gone and the human copies are already under protection. Bera and Siv wait with their families at Lantern Reach. Bring them across and make sure all seven reach Hearthward."]
	return steps
