extends RefCounted

## Read-only directions for an already active story step. This catalog never
## discovers a place, chooses a quest, or changes progression.
const ZONE_NAMES := {
	"greyfen":"Greyfen", "wychwood":"Wychwood", "deep_wood":"Deep Wychwood",
	"old_mill":"Old Mill", "burned_farmstead":"Burned Farmstead", "marsh_crossing":"Marsh Crossing",
	"bandit_road":"Bandit Road", "vargan_approach":"Castle Vargan Approach",
	"vargan_court":"Castle Vargan Courtyard", "record_hall":"Vargan Record Hall",
	"undercroft":"Vargan Undercroft", "assembly":"Greyfen Assembly", "hart_glade":"White Hart Glade",
	"cemetery":"Greyfen Cemetery", "ruins":"Old Ruins"
}

# zone, public interaction IDs, local context, why the step matters. Empty IDs
# deliberately leave investigation and combat as areas rather than hidden pins.
const ROUTES := {
	"main_road_of_crows": {
		"speak_anwen":["greyfen", ["sister_anwen"], "Anwen waits at the shrine.", "Learn who is missing before taking the road."],
		"evidence_ready":["wychwood", [], "Inspect the broken cart and the disturbed roadside.", "Identify the missing people from what remains."],
		"fight_ghoulkin":["wychwood", [], "The pack holds the clearing beyond the cart.", "Carry the road's account back to the living."],
		"return_village":["greyfen", ["sister_anwen", "notice_board", "retain_evidence"], "Choose how to report at the shrine or notice board.", "What you report will shape Greyfen's response."]
	},
	"main_bell_beneath_greyfen": {
		"meet_anwen_gate":["greyfen", ["sister_anwen"], "The cemetery is within Greyfen, beside the ruined chapel.", "Hear what Anwen knows about the bell."],
		"grave_truth":["greyfen", [], "Compare the disturbed graves beside the chapel.", "Let each grave add to the account."],
		"cemetery_ambush":["greyfen", [], "Watch the bell's rings and use the marked shelter.", "Survive long enough to open the chapel."],
		"open_chapel":["greyfen", ["chapel_door"], "Approach the ruined chapel beyond the graves.", "Reach the record Greyfen kept sealed."],
		"crow_shrine_choice":["greyfen", ["crow_shrine_choice"], "The opened chapel holds the Crow Shrine.", "Decide what this shrine will preserve."]
	},
	"main_teeth_in_rain": {
		"speak_mira":["greyfen", ["mira"], "Mira works beside the village well.", "Ask how the ash touches the living."],
		"read_chapel_names":["greyfen", ["chapel_names"], "Read the wall inside the ruined Crow Chapel.", "Recover a name before speaking for the dead."],
		"name_the_dead":["wychwood", ["ritual_stones"], "The ritual stones stand beyond the roadside clearing.", "Speak Oren's recovered name."],
		"fight_bog_wretch":["deep_wood", [], "Follow the path into the deeper clearing.", "Find the memory held in the wood."],
		"bog_core_choice":["deep_wood", ["bog_core_choice"], "Return to the memory core in the clearing.", "Decide how this memory reaches the living."]
	},
	"main_names_they_burned": {
		"reconstruct_register":["greyfen", [], "Compare surviving pages in Greyfen and along the old mill road.", "Three fragments can restore the missing names."],
		"fragment_anwen":["greyfen", [], "Search near Anwen's shrine for the surviving register page.", "Preserve the names without inventing the missing parts."],
		"fragment_tor":["greyfen", [], "Look for the register page at Tor's forge.", "Compare another part of the refugee account."],
		"fragment_rook":["burned_farmstead", [], "Search what remains along the farmstead road.", "Recover a surviving part of the register."],
		"fragment_mira":["marsh_crossing", [], "Look for the healer's register fragment at the crossing.", "Recover a surviving part of the register."],
		"names_choice":["greyfen", ["names_decision"], "Bring the restored register to the village shrine.", "Choose when and how the names become public."]
	},
	"main_ash_at_the_mill": {
		"reach_mill":["old_mill", [], "The mill lies beyond Deep Wychwood.", "Learn what has been feeding Greyfen's fields."],
		"inspect_millstones":["old_mill", ["millstones"], "Inspect the stones inside the mill.", "Establish what was ground into the flour."],
		"mill_encounter":["old_mill", [], "The sluice opens an escape channel; the hauling rope can ground Ashwing.", "People and their records remain at risk during the fight."],
		"mill_choice":["old_mill", ["miller_record"], "The miller's record lies beside the stones.", "Settle the mill's future with the account intact."]
	},
	"main_soldier_without_banner": {
		"reach_bandit_road":["bandit_road", ["captain_senn"], "The old checkpoint lies beyond the marsh crossing.", "Find the soldier who kept control of the road."],
		"senn_confrontation":["bandit_road", [], "Face the checkpoint soldiers; a known account may earn their surrender.", "Secure the road without mistaking obedience for testimony."],
		"senn_choice":["bandit_road", ["captain_senn"], "Return to Senn at the checkpoint.", "Decide his accountability and hear his own answer."]
	},
	"main_blood_under_stone": {
		"reach_castle":["vargan_approach", [], "Follow the military road to Vargan's outer gate.", "Find the authority behind the closure."],
		"speak_guard":["vargan_court", ["vargan_gate_guard"], "The guard stands just inside the courtyard gate.", "Ask who ordered the road closed."],
		"enter_courtyard":["vargan_court", [], "Pass through Vargan's outer gate.", "Follow the order into the castle."],
		"castle_evidence_ready":["vargan_court", [], "Compare the closure notice and the traces of the old order.", "Establish why the road was closed."],
		"evidence_mile_marker":["vargan_approach", [], "Read the worn marker on the military road.", "Compare what the road promised with what was ordered."],
		"evidence_supply_cart":["vargan_approach", [], "Inspect the abandoned military cart beside the approach.", "Account for the supplies taken down this road."],
		"evidence_gate_notice":["vargan_court", [], "Read the closure notice beside the courtyard gate.", "Establish who claimed the authority to close the road."],
		"evidence_iron_binding":["vargan_court", [], "Examine the blackened binding wire in the courtyard.", "Connect the castle's order to its trace on the road."],
		"evidence_ledger_fragment":["record_hall", [], "Examine the command ledger inside the archive.", "Compare the missing names with the written orders."],
		"locate_record_hall":["record_hall", [], "The archive entrance is at the far side of the courtyard.", "Follow the written command to its source."],
		"recover_ledger":["record_hall", ["vargan_ledger_choice"], "The sealed ledger rests at the end of the archive aisle.", "Recover the command as evidence."],
		"ledger_choice":["record_hall", ["vargan_ledger_choice"], "Return to the command ledger.", "Choose how to preserve and disclose the orders."],
		"survive_haunting":["record_hall", [], "The haunting has risen inside the archive.", "Keep the recovered account safe."],
		"last_witness_hook":["record_hall", ["edric_campaign"], "Edric waits beyond the ledger table.", "Demand an answer about the renewal before seeking the last witness."]
	},
	"main_last_witness": {
		"reach_undercroft":["undercroft", [], "Descend from Vargan's record hall.", "Hear the account the castle buried."],
		"break_halvern_guard":["undercroft", [], "Answer Halvern's guard; recovered command proof can support a peaceful appeal.", "Earn a hearing without treating surrender as another target."],
		"halvern_choice":["undercroft", ["halvern"], "Halvern waits beyond the broken guard.", "Let the last witness answer for himself."]
	},
	"main_crowns_without_mercy": {
		"gather_witnesses":["assembly", ["witnesses_ready"], "Gather at the assembly's central record table.", "Records and willing accounts can stand together; participation is a choice."],
		"greyfen_assembly":["assembly", ["assembly_choice"], "Address the people gathered at the assembly.", "Bring the scattered accounts into a common hearing."],
		"confession_choice":["assembly", ["assembly_choice"], "Return to the assembly's speaking place.", "Decide what Kael will carry in his own name."]
	},
	"main_hart_remembers": {
		"enter_glade":["hart_glade", [], "Take the reopened road from the assembly.", "Meet the witness at the heart of the binding."],
		"hear_testimony":["hart_glade", ["white_hart"], "The Hart waits within the circle.", "Hear the complete account before choosing its future."],
		"final_choice":["hart_glade", ["white_hart"], "Ask the Hart what each intention requires.", "Choose the responsibility Kael is willing to carry."]
	},
	"side_widows_bell": {
		"find_bell":["greyfen", [], "Listen at Harl's grave in the village cemetery.", "Find the account Elna has been denied."],
		"widow_choice":["greyfen", ["widow_elna"], "Return to Elna beside the graves.", "Her participation remains hers to decide."]
	},
	"side_iron_remembers": {
		"recover_iron":["greyfen", [], "Search the blackened iron by the ruined chapel.", "Recover what Tor needs to face the forge's history."],
		"tor_choice":["greyfen", ["blacksmith_tor"], "Speak with Tor at the forge.", "Decide what happens to the marked stock."]
	},
	"side_bitter_roots": {
		"collect_roots":["wychwood", [], "Search the root beds beyond the roadside clearing.", "Bring evidence into the treatment decision."],
		"study_roots":["wychwood", [], "Examine the ash bed near the ritual stones.", "Keep the source of the roots distinct from their use."],
		"mira_choice":["greyfen", ["mira"], "Return to Mira beside the well.", "Agree a treatment plan with an honest account of the cost."]
	},
	"side_black_dog": {
		"find_dog":["greyfen", [], "Begin at the sheepfold and follow the disturbed road.", "Compare the tracks with the attack on the fold."],
		"dog_choice":["greyfen", ["farmer_toma"], "Return to Toma at the sheepfold.", "Choose how the fold will be protected."]
	},
	"side_empty_grave": {
		"follow_empty_grave":["greyfen", [], "Follow the prints beside the cemetery's empty grave.", "Learn who has returned to the watch."],
		"walker_choice":["greyfen", ["returned_soldier"], "Speak with the soldier beside the graves.", "Settle the watch while preserving its name."]
	},
	"side_childs_charm": {
		"trace_thread":["wychwood", [], "Follow the red thread along the cart road.", "Recover Oren's own trace."],
		"return_charm":["greyfen", ["oren_charm_shrine"], "Place the charm at Oren's grave.", "Return the token to a named resting place."]
	},
	"side_soldiers_debt": {
		"find_deserters":["bandit_road", [], "Look for the abandoned soldiers' record near the checkpoint.", "Hear what refusal cost the soldiers."],
		"debt_choice":["bandit_road", ["captain_senn"], "Bring the soldiers' account to Senn.", "Protect their choice about public identities."]
	},
	"side_millers_measure": {
		"weigh_ash":["old_mill", [], "Look for the hidden measure on the mill floor.", "Recover the true quantity before choosing its use."],
		"ash_choice":["greyfen", ["mira", "farmer_toma"], "Bring the true measure to Mira or Toma.", "Put the account where people can act on it."]
	},
	"side_rooks_map": {
		"walk_false_road":["deep_wood", [], "Compare the map with the bent waystone.", "Learn which part of the remembered road remains useful."],
		"map_choice":["greyfen", ["rook"], "Return to Rook beside the village road.", "Keep the route without deciding Rook's consent."]
	},
	"side_three_candles": {
		"light_bram":["greyfen", ["memorial_candle_bram"], "Return to the memorial candles by the chapel.", "Give the recovered name a place among the living."],
		"light_sella":["greyfen", ["memorial_candle_sella"], "Return to the memorial candles by the chapel.", "Give the recovered name a place among the living."],
		"light_oren":["greyfen", ["memorial_candle_oren"], "Return to the memorial candles by the chapel.", "Give the recovered name a place among the living."]
	}
}

static func zone_name(zone_id: String) -> String:
	return str(ZONE_NAMES.get(zone_id, zone_id.replace("_", " ").capitalize()))

static func for_objective(quest_id: String, objective_id: String, state = null, quests = null, current_zone: String = "") -> Dictionary:
	var entry: Array = ROUTES.get(quest_id, {}).get(objective_id, [])
	if entry.is_empty():
		return {}
	if quests != null:
		if quest_id == "main_names_they_burned" and objective_id == "reconstruct_register":
			entry = _unfinished_group_route(quest_id, ["fragment_anwen", "fragment_tor", "fragment_rook", "fragment_mira"], quests, current_zone, entry)
		elif quest_id == "main_blood_under_stone" and objective_id == "castle_evidence_ready":
			entry = _unfinished_group_route(quest_id, ["evidence_mile_marker", "evidence_supply_cart", "evidence_gate_notice", "evidence_iron_binding", "evidence_ledger_fragment"], quests, current_zone, entry)
	if current_zone == "assembly" and (quest_id == "side_millers_measure" and objective_id == "ash_choice" or quest_id == "side_soldiers_debt" and objective_id == "debt_choice"):
		entry = ["assembly", ["assembly_choice"], "Bring the recovered account to the assembly.", "Keep this record available without claiming anyone's consent."]
	var ids: Array[String] = []
	for id in entry[1]:
		ids.append(str(id))
	var result := {"destination_zone":str(entry[0]), "destination_name":zone_name(str(entry[0])), "target_ids":ids, "route_hint":str(entry[2]), "purpose":str(entry[3]), "pinpoint":not ids.is_empty()}
	if quest_id == "main_last_witness" and objective_id == "break_halvern_guard":
		result["next_action"] = "Break Halvern's guard or earn his peaceful hearing"
		if state != null and bool(state.get_flag("command_proof_recovered", false)):
			result["route_hint"] = "Present the recovered order at the marked place before Halvern."
	if quest_id == "main_blood_under_stone" and objective_id == "last_witness_hook":
		result["next_action"] = "Demand Edric's answer about the renewal"
	elif quest_id == "main_blood_under_stone" and objective_id == "castle_evidence_ready":
		result["next_action"] = "Compare three accounts of Vargan's road closure"
	return result

static func _unfinished_group_route(quest_id: String, members: Array, quests, current_zone: String, fallback: Array) -> Array:
	# Prefer unfinished evidence in this place without revealing a hidden pin.
	# Quest completion also preserves discoveries from saves predating evidence history.
	var first_pending: Array = []
	for raw_member in members:
		var member: String = str(raw_member)
		if quests.is_objective_done(quest_id, member):
			continue
		var entry: Array = ROUTES[quest_id][member]
		if first_pending.is_empty():
			first_pending = entry
		if str(entry[0]) == current_zone:
			return entry
	return fallback if first_pending.is_empty() else first_pending

static func ending_continuation(state, current_zone: String) -> Dictionary:
	if state == null:
		return {}
	var completed: bool = bool(state.get_flag("final_choice_completed", false))
	var covenant: String = str(state.get_flag("final_covenant", ""))
	if not completed and covenant != "":
		var ending: String = str({"witness":"expose", "mercy":"free", "duty":"bind", "ash":"kill"}.get(covenant, ""))
		var steps: Dictionary = {
			"expose":["Lay the command ledger", "Speak the recovered names", "Speak of the retreat"],
			"free":["Return the family tokens", "Keep the public record", "Untie the witness"],
			"bind":["Set down the old badge", "Name the limits of the promise", "Take the willing burden"]
		}
		if steps.has(ending) and bool(state.get_flag("covenant_ritual_started", false)):
			var step: int = clampi(int(state.get_flag("covenant_ritual_step", 0)), 0, 3)
			var ritual_result := _continuation("covenant_resolution", "THE CHOSEN PROMISE", "Let the covenant settle" if step >= 3 else str(steps[ending][step]), "hart_glade", "The marked places carry the promise in order.", "Carry out the intention you chose.")
			if step < 3:
				ritual_result["target_ids"] = ["covenant_%s_%d" % [ending, step]]
				ritual_result["pinpoint"] = true
			return ritual_result
		if ending == "kill":
			return _continuation("covenant_ash", "THE CHOSEN PROMISE", "Face the Hart and carry out the choice of Ash", "hart_glade", "Watch the marked attacks in the glade.", "The choice is still being carried out.")
	if not completed or bool(state.get_flag("aftermath_walk_completed", false)):
		return {}
	var result: Dictionary
	if not bool(state.get_flag("aftermath_names_returned", false)):
		result = _continuation("aftermath_names", "THE ROAD HOME", "Return to the names with Anwen", "greyfen", "Anwen waits at the village shrine.", "Bring the account to the people who must live with it.")
	elif not bool(state.get_flag("aftermath_work_promised", false)):
		result = _continuation("aftermath_work", "THE ROAD HOME", "Join Tor and Rook at the workbench", "greyfen", "The workbench stands beside the common kitchen.", "Give the promise an ordinary task.")
	else:
		result = _continuation("aftermath_road", "THE ROAD HOME", "Meet the road beyond the kitchen", "greyfen", "Walk to the road on the south side of the kitchen.", "Decide how Kael carries the next day.")
	result["target_ids"] = [str(result["id"])]
	result["pinpoint"] = true
	result["guidance_scope"] = "aftermath"
	if current_zone == "hart_glade":
		result["action"] = "Take the return to Greyfen"
		result["route_hint"] = "The ending's return brings you back to the village."
	return result

static func _continuation(id: String, title: String, action: String, destination: String, hint: String, purpose: String) -> Dictionary:
	return {"id":id, "title":title, "action":action, "destination_zone":destination, "destination_name":zone_name(destination), "target_ids":[], "route_hint":hint, "purpose":purpose, "pinpoint":false, "guidance_scope":"local"}
