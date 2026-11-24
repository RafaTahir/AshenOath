extends RefCounted

const Revision = preload("res://scripts/campaign_revision.gd")
const ROUTE_WORK := {
	"crossing": ["crossing_beam", "crossing_rail", "crossing_load"],
	"ferry": ["ferry_landing", "ferry_rope", "ferry_load"]
}

## Read the recorded choices only. Menu summaries may run before the regional pack mounts.
static func apply_progress(result: Dictionary, quest: String, objective: String, state: Variant) -> void:
	if state == null or quest not in Revision.NEW_CHAPTERS:
		return
	var route := str(state.get_flag("community_route", ""))
	var targets: Array[String] = []
	if objective == "secure_route":
		for work_id: String in ROUTE_WORK.get(route, []):
			targets.append("community:work:" + work_id)
	else:
		targets.assign(result.target_ids)
	var remaining: Array[String] = []
	for target: String in targets:
		if target.begins_with("community:work:") and state.get_flag("community_work:" + target.get_slice(":", 2), false) == true:
			continue
		if target.begins_with("community:survey:") and state.get_flag("community_survey:" + target.get_slice(":", 2), false) == true:
			continue
		remaining.append(target)
	match objective:
		"survey_crossing":
			if remaining.size() == 1:
				result.next_action = "Inspect the %s landing" % remaining[0].get_slice(":", 2)
				result.route_hint = "The other bank is already marked. The old service footway runs north of the water."
		"settle_tables":
			var food := str(state.get_flag("community_distribution", ""))
			if food in ["central", "households"]:
				remaining.assign(["community:aftermath:" + quest])
				result.next_action = "Serve the first meal"
				result.route_hint = "The common kitchen is ready for its first queue." if food == "central" else "The carriers are packing the household shares at the landing."
		"settle_records":
			var custody := str(state.get_flag("community_records", ""))
			if custody in ["distributed", "protected"]:
				remaining.assign(["community:aftermath:" + quest])
				result.next_action = "Welcome the first arrivals at the refuge"
				result.route_hint = "The public copies have their own shelves. Private testimony stays sealed." if custody == "distributed" else "The public summary is on display. Willing custodians hold the full account."
		"open_route":
			if route not in ROUTE_WORK:
				remaining.clear()
				result.next_action = "Consult the passage record at Lantern Reach"
				result.route_hint = "This journey has no recorded passage arrangement."
			elif state.get_flag("community_route_load_carried", false) == true:
				if state.get_flag("community_route_load_crossed", false) == true:
					remaining.assign(["community:delivery"])
					result.next_action = "Set down the first load at the far landing"
					result.route_hint = "You have already crossed with the load."
				else:
					remaining.assign(["community:ferry"] if route == "ferry" else [])
					result.next_action = "Board the ferry with the load" if route == "ferry" else "Carry the load across the repaired bridge"
					result.route_hint = "The ferry boards at the near landing." if route == "ferry" else "Walk between the two railings to the far bank."
		"carry_promise":
			if state.get_flag("community_rota_posted", false) == true:
				result.next_action = "Keep the first watch at Hearthward"
				result.route_hint = "The rota is already posted beside the public table. Unclaimed shifts stay vacant."
	result.target_ids = remaining
	result.pinpoint = not remaining.is_empty()

static func departure(state: Variant) -> Dictionary:
	var delivered: bool = state.get_flag("open_road_route_delivered", false) == true
	var result := {
		"id": "open_road_departure", "title": "THE CHOSEN DEPARTURE",
		"action": "Resume the households' move at Hearthward" if delivered else "Resume the households' passage at Lantern Reach",
		"destination_zone": "hearthward" if delivered else "lantern_reach",
		"target_ids": [], "route_hint": "", "pinpoint": false, "guidance_scope": "local",
		"purpose": "Accompany the households who asked to move."
	}
	const ENDING_PATH := "res://scripts/community_ending.gd"
	if not FileAccess.file_exists("res://data/community_campaign.json") or not ResourceLoader.exists(ENDING_PATH):
		return result
	var ending_rules: Variant = load(ENDING_PATH)
	var row: Dictionary = ending_rules.continuation(state) if ending_rules != null else {}
	if row.is_empty():
		return result
	result.action = row.action
	result.destination_zone = row.zone
	result.target_ids = row.get("target_ids", []).duplicate()
	if state.get_flag("open_road_load_carried", false) == true and state.get_flag("open_road_route_crossed", false) != true:
		match str(state.get_flag("community_route", "")):
			"crossing":
				result.target_ids = []
				result.route_hint = "Stay close to the households and walk between the bridge railings."
			"ferry":
				result.route_hint = "Bring the households together at the near landing before boarding."
			_:
				result.target_ids = []
	result.pinpoint = not result.target_ids.is_empty()
	return result

## Display the local agreement only after its first meal, delivery or welcome.
static func public_records(zone: String, data: Dictionary, state: Variant) -> Array[Dictionary]:
	var pages: Array[Dictionary] = []
	for quest: String in Revision.NEW_CHAPTERS:
		var chapter: Dictionary = data.get("chapters", {}).get(quest, {})
		if chapter.get("region") != zone or not chapter.has("choice"):
			continue
		if state.get_flag("community_aftermath:" + quest, false) != true:
			continue
		var chosen := str(state.get_flag(str(chapter.choice), ""))
		var arrangement: Dictionary = chapter.get("choices", {}).get(chosen, {})
		if not arrangement.is_empty():
			pages.append({"speaker": str(chapter.title), "speaker_id": "system", "text": str(arrangement.aftermath), "read_only": true})
	return pages
