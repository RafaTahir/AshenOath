extends RefCounted

static func progress(quest: String, objective: String, entry: Array, state: Variant) -> Array:
	if state == null or quest not in preload("res://scripts/campaign_revision.gd").NEW_CHAPTERS: return entry
	var result := entry.duplicate(true)
	if objective=="secure_route":
		result[1]=[]
		var ids: Array = ["crossing_beam","crossing_rail","crossing_load"] if str(state.get_flag("community_route",""))=="crossing" else ["ferry_landing","ferry_rope","ferry_load"]
		for id: String in ids: result[1].append("community:work:"+id)
	var targets: Array = []
	for id: String in result[1]:
		if id.begins_with("community:work:") and bool(state.get_flag("community_work:"+id.trim_prefix("community:work:"),false)): continue
		if id.begins_with("community:survey:") and bool(state.get_flag("community_survey:"+id.trim_prefix("community:survey:"),false)): continue
		targets.append(id)
	result[1]=targets
	var choice_flag := "community_distribution" if quest=="main_empty_tables" else "community_records"
	if objective in ["settle_tables","settle_records"] and str(state.get_flag(choice_flag,""))!="": result[1]=["community:aftermath:"+quest]
	if objective=="open_route" and bool(state.get_flag("community_route_load_carried",false)):
		if bool(state.get_flag("community_route_load_crossed",false)): result[1]=["community:delivery"]
		elif str(state.get_flag("community_route",""))=="ferry": result[1]=["community:ferry"]
		else:
			result[1]=[]
			result[2]="Carry the load over the repaired crossing between the two railings."
	return result
