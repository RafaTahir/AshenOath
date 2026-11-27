extends RefCounted

static func consistent(flags: Dictionary, participants: Array) -> bool:
	var step: Variant=flags.get("covenant_ritual_step",0)
	if typeof(step) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(step)) or step<0 or step>3 or step!=int(step): return false
	for key: String in ["open_road_protection_dismantled","territorial_protection_active","hart_complete_account_access","human_records_preserved","open_road_relocation_started","open_road_load_carried","open_road_player_crossed","open_road_route_crossed","open_road_route_delivered","open_road_relocation_completed","final_choice_completed"]:
		if flags.has(key) and typeof(flags[key])!=TYPE_BOOL: return false
	var answers: Variant=flags.get("community_departure_consent",{})
	if not answers is Dictionary: return false
	for id: Variant in answers:
		if not id is String or id not in participants or typeof(answers[id])!=TYPE_BOOL: return false
	var roster: Variant=flags.get("open_road_named_roster",[])
	if not roster is Array: return false
	var seen: Dictionary={}
	for id: Variant in roster:
		if not id is String or id not in participants or seen.has(id) or answers.get(id)!=true: return false
		seen[id]=true
	var households: Variant=flags.get("open_road_households",[])
	if not households is Array: return false
	if flags.has("open_road_households") and households!=["water_carrier","quality_sweeper"]: return false
	if step>=1 and (not flags.has("open_road_named_roster") or not flags.has("open_road_households")): return false
	var progress: Variant=flags.get("open_road_crossing_progress",0.0)
	if typeof(progress) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(progress)) or progress<0.0 or progress>1.0: return false
	if flags.get("open_road_relocation_started")==true and (step!=3 or flags.get("open_road_protection_dismantled")!=true): return false
	if flags.get("open_road_route_crossed")==true and (flags.get("open_road_relocation_started")!=true or flags.get("open_road_player_crossed")!=true or progress!=1.0): return false
	if flags.get("open_road_route_delivered")==true and flags.get("open_road_route_crossed")!=true: return false
	if flags.get("open_road_relocation_completed")==true and flags.get("open_road_route_delivered")!=true: return false
	return true
