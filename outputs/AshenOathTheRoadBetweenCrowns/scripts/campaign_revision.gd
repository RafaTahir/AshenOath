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
	return ""

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
