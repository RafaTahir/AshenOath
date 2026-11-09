extends RefCounted

## A journey chooses its graph once. Missing markers always mean the original
## campaign; loading/importing/replaying never upgrades an existing journey.
const LEGACY := 1
const EXPANDED := 2
const EXPANSION_ENABLED := false
const FLAG := "campaign_revision"
const LEGACY_CHAPTERS := [
	"main_road_of_crows", "main_bell_beneath_greyfen", "main_teeth_in_rain",
	"main_names_they_burned", "main_ash_at_the_mill", "main_soldier_without_banner",
	"main_blood_under_stone", "main_last_witness", "main_crowns_without_mercy", "main_hart_remembers"
]
const NEW_CHAPTERS := ["main_empty_tables", "main_road_kept_open", "main_house_many_names", "main_what_we_promise"]
const EXPANDED_CHAPTERS := [
	"main_road_of_crows", "main_bell_beneath_greyfen", "main_teeth_in_rain",
	"main_names_they_burned", "main_ash_at_the_mill", "main_empty_tables", "main_road_kept_open",
	"main_soldier_without_banner", "main_blood_under_stone", "main_last_witness",
	"main_house_many_names", "main_what_we_promise", "main_crowns_without_mercy", "main_hart_remembers"
]
const NEW_ZONES := ["lantern_reach", "hearthward"]
# Compact save-schema identities remain base-owned; validation runs before the
# optional story pack mounts and must not load its prose or scene resources.
const DEPARTURE_ACTORS := ["anwen", "rook", "mira", "tor", "elna", "toma", "senn", "edric", "vale", "merrow", "nessa", "nera"]
const OBJECTIVES := {
	"main_empty_tables":["reach_lantern_reach", "hear_households", "prepare_kitchen", "settle_tables"],
	"main_road_kept_open":["survey_crossing", "agree_route", "secure_route", "open_route"],
	"main_house_many_names":["reach_hearthward", "hear_households", "prepare_refuge", "settle_records"],
	"main_what_we_promise":["gather_cast", "test_arrangements", "choose_responsibilities", "carry_promise"]
}
const COMPLETION_FLAGS := {
	"main_empty_tables":"campaign_empty_tables_completed",
	"main_road_kept_open":"campaign_road_kept_open_completed",
	"main_house_many_names":"campaign_house_many_names_completed",
	"main_what_we_promise":"campaign_what_we_promise_completed"
}

static func new_journey_revision() -> int:
	return EXPANDED if EXPANSION_ENABLED else LEGACY

static func from_flags(flags: Dictionary) -> int:
	var value: Variant = flags.get(FLAG, LEGACY)
	return EXPANDED if typeof(value) in [TYPE_INT, TYPE_FLOAT] and value == EXPANDED else LEGACY

static func from_save(data: Dictionary) -> int:
	var story: Variant = data.get("story_state", {})
	if not story is Dictionary or not story.get("flags", {}) is Dictionary:
		return LEGACY
	return from_flags(story.get("flags", {}))

static func save_revision_error(data: Dictionary) -> String:
	var story: Variant = data.get("story_state", {})
	var flags: Dictionary = story.get("flags", {}) if story is Dictionary and story.get("flags", {}) is Dictionary else {}
	if flags.has(FLAG):
		var value: Variant = flags[FLAG]
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
			return "invalid_campaign_revision"
		if value > EXPANDED:
			return "future_version"
		if float(value) != float(LEGACY) and float(value) != float(EXPANDED):
			return "invalid_campaign_revision"
	# A region identifier is never evidence that an old journey opted in.
	if from_save(data) != EXPANDED and (str(data.get("zone", "")).strip_edges().to_lower() in NEW_ZONES or str(data.get("world_sector", "")).strip_edges().to_lower() in NEW_ZONES):
		return "campaign_region_revision_mismatch"
	var world: Variant=data.get("world_state",{})
	var pending: String=str(world.get("pending_ending","")) if world is Dictionary else ""
	var covenant := str(flags.get("final_covenant",""))
	if from_save(data)!=EXPANDED and (pending in ["share","depart","concord","open_road"] or covenant in ["concord","open_road"]): return "campaign_ending_revision_mismatch"
	if covenant=="open_road":
		if not _departure_flags_valid(flags): return "invalid_departure_consequence"
		if flags.get("open_road_protection_dismantled")==true:
			if flags.get("territorial_protection_active")!=false or flags.get("hart_complete_account_access")!=false or flags.get("human_records_preserved")!=true: return "invalid_departure_consequence"
		if flags.get("final_choice_completed")==true:
			for key: String in ["open_road_protection_dismantled","open_road_relocation_started","open_road_player_crossed","open_road_route_crossed","open_road_route_delivered","open_road_relocation_completed"]:
				if flags.get(key)!=true: return "invalid_departure_consequence"
	return ""

static func _departure_flags_valid(flags: Dictionary) -> bool:
	var step: Variant=flags.get("covenant_ritual_step",0)
	if typeof(step) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(step)) or step<0 or step>3 or step!=int(step): return false
	for key: String in ["open_road_protection_dismantled","territorial_protection_active","hart_complete_account_access","human_records_preserved","open_road_relocation_started","open_road_load_carried","open_road_player_crossed","open_road_route_crossed","open_road_route_delivered","open_road_relocation_completed","final_choice_completed"]:
		if flags.has(key) and typeof(flags[key])!=TYPE_BOOL: return false
	var answers: Variant=flags.get("community_departure_consent",{})
	if not answers is Dictionary: return false
	for id: Variant in answers:
		if not id is String or id not in DEPARTURE_ACTORS or typeof(answers[id])!=TYPE_BOOL: return false
	var roster: Variant=flags.get("open_road_named_roster",[])
	if not roster is Array: return false
	var seen: Dictionary={}
	for id: Variant in roster:
		if not id is String or id not in DEPARTURE_ACTORS or seen.has(id) or answers.get(id)!=true: return false
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

static func from_state(state) -> int:
	return from_flags({FLAG:state.get_flag(FLAG, LEGACY)}) if state != null else LEGACY

static func chapter_ids(revision: int) -> Array:
	return EXPANDED_CHAPTERS.duplicate() if revision == EXPANDED else LEGACY_CHAPTERS.duplicate()

static func zone_available(zone_id: String, state) -> bool:
	return zone_id not in NEW_ZONES or from_state(state) == EXPANDED

static func project_catalog(data: Dictionary, revision: int) -> Dictionary:
	var result := data.duplicate(true)
	var chapters := chapter_ids(revision)
	result["chapters"] = (result.get("chapters", []) as Array).filter(func(row): return str(row.get("quest_id", "")) in chapters)
	if revision != EXPANDED:
		result["endings"] = (result.get("endings", []) as Array).filter(func(row): return str(row.get("id", "")) in ["expose","free","bind","kill"])
	return result

static func project_quests(definitions: Dictionary, revision: int) -> Dictionary:
	var result := definitions.duplicate(true)
	var chapters := chapter_ids(revision)
	if revision != EXPANDED:
		for id: String in NEW_CHAPTERS:
			result.erase(id)
	# Rebuild only main-to-main edges; side content and existing IDs retain their
	# own identity and dependencies in both projections.
	for index in chapters.size():
		var id: String = chapters[index]
		if not result.has(id):
			continue
		var successors: Array = []
		for next_id: String in result[id].get("unlocks", []):
			if next_id not in EXPANDED_CHAPTERS:
				successors.append(next_id)
		if index + 1 < chapters.size():
			successors.append(chapters[index + 1])
		result[id]["unlocks"] = successors
	return result

static func has_complete_expansion(definitions: Dictionary) -> bool:
	for id: String in NEW_CHAPTERS:
		if not definitions.get(id) is Dictionary:
			return false
		var actual: Array = []
		for objective: Dictionary in definitions[id].get("objectives", []):
			actual.append(str(objective.get("id", "")))
		if actual != OBJECTIVES[id]:
			return false
	return true

static func expansion_completed(quests) -> bool:
	if quests == null:
		return false
	for id: String in NEW_CHAPTERS:
		if not quests.is_completed(id):
			return false
	return true
