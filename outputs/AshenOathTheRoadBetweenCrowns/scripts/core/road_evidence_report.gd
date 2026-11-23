extends RefCounted

static func pending(state: Variant) -> bool:
	return state != null and bool(state.get_flag("legacy_report_choice_required", false)) and str(state.get_flag("evidence_report", "")) == ""

static func guidance(state: Variant, quests: Variant, zone_id: String) -> Dictionary:
	if zone_id not in ["greyfen", "wychwood"] or not pending(state):
		return {}
	if bool(state.get_flag("final_choice_completed", false)) or (quests != null and quests.tracked_quest_is_manual and quests.get_tracked_quest() != ""):
		return {}
	var route := preload("res://scripts/story_route_catalog.gd").for_objective("main_road_of_crows", "return_village", state, quests, zone_id)
	route["id"] = "legacy_road_report"
	route["title"] = "The unfiled road report"
	route["purpose"] = "The road investigation is recorded. Choose how to share what survives in the account."
	return route

static func summary(state: Variant) -> String:
	match str(state.get_flag("evidence_report", "")) if state != null else "":
		"private":
			return "Kael reported privately to Anwen. The sealed account stays with her at the north shrine."
		"public":
			return "Kael put the recovered evidence before Greyfen. The notice board carries the public account."
		"retained":
			return "Kael kept the original evidence and agreed to make protected copies. The village notice calls for a watch on the road."
	if pending(state):
		return "The investigation is recorded. Anwen and the village notice board still offer a choice about sharing the evidence."
	return ""
