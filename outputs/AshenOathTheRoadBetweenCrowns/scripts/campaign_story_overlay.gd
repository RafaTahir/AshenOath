extends RefCounted

## Immutable prose, projected by the current journey. Merely mounting the pack
## never upgrades a save or writes expanded definitions into a legacy owner.
const Revision = preload("res://scripts/campaign_revision.gd")
const PATH := "res://data/community_story_overlay.json"
const BASE_CATALOG_PATH := "res://data/runtime_story_campaign.json"
const SCENES := ["white_hart","aftermath_names_concord","aftermath_work_concord","aftermath_road_concord","aftermath_names_open_road","aftermath_work_open_road","aftermath_road_open_road"]
static var _data: Dictionary = {}

static func required_for(zone: String, flags: Dictionary, completed: Dictionary) -> bool:
	if Revision.from_flags(flags) != Revision.EXPANDED: return false
	if zone in Revision.NEW_ZONES: return true
	if bool(completed.get("main_ash_at_the_mill",false)): return true
	for id: String in Revision.NEW_CHAPTERS:
		if bool(completed.get(id,false)) or flags.get(Revision.COMPLETION_FLAGS[id])==true: return true
	return str(flags.get("final_covenant","")) in ["concord","open_road"]

static func ready() -> bool:
	return not data().is_empty()

static func eligible(state, quests = null) -> bool:
	if Revision.from_state(state)!=Revision.EXPANDED: return false
	if quests!=null and quests.is_completed("main_ash_at_the_mill"): return true
	if state.get_flag("ashwing_defeated",false)==true: return true
	for id: String in Revision.NEW_CHAPTERS:
		if state.get_flag(Revision.COMPLETION_FLAGS[id],false)==true or state.get_flag("community_account:"+id,false)==true: return true
	return str(state.get_flag("final_covenant","")) in ["concord","open_road"]

static func data() -> Dictionary:
	if not _data.is_empty(): return _data
	# Do not cache a missing pack: a later verified mount must become visible.
	if not FileAccess.file_exists(PATH): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not valid_payload(parsed): return {}
	_data=parsed
	return _data

static func valid_payload(parsed: Variant) -> bool:
	if not parsed is Dictionary or parsed.get("version")!=1: return false
	for key: String in ["scenes","catalog","ending_rituals","ending_cards"]:
		if not parsed.get(key) is Dictionary: return false
	for id: String in SCENES:
		if not parsed.scenes.get(id) is Dictionary or parsed.scenes[id].is_empty(): return false
	for field: String in ["chapters","endings"]:
		var rows: Variant = parsed.catalog.get(field)
		if not rows is Array: return false
		var identities: Array = []
		for row: Variant in rows:
			if not row is Dictionary or row.get("campaign_revision")!=2: return false
			identities.append(str(row.get("quest_id" if field=="chapters" else "id","")))
		if identities!=(Revision.NEW_CHAPTERS if field=="chapters" else ["share","depart"]): return false
	for id: String in ["share","depart"]:
		var steps: Variant = parsed.ending_rituals.get(id)
		if not steps is Array or steps.size()!=3 or str(parsed.ending_cards.get(id,"")).is_empty(): return false
		for step: Variant in steps:
			if not step is Array or step.size()!=2 or not step[0] is String or not step[1] is String: return false
	return true

static func scene(id: String, state, quests = null) -> Dictionary:
	if not eligible(state,quests): return {}
	return data().get("scenes",{}).get(id,{}).duplicate(true)

static func base_scene(value: Dictionary) -> Dictionary:
	# Source/editor reads use the same ownership rule as compiled PCK reads.
	if str(value.get("source_tag",""))=="campaign_revision_2" or value.get("campaign_revision")==2: return {}
	var result := value.duplicate(true)
	for field: String in ["variants","actions","lines","pages"]:
		if result.has(field): result[field]=result[field].filter(func(row): return not row is Dictionary or (str(row.get("source_tag",""))!="campaign_revision_2" and row.get("campaign_revision")!=2))
	return result

static func base_catalog(value: Dictionary) -> Dictionary:
	var result := value.duplicate(true)
	for field: String in ["chapters","endings"]:
		var key := "quest_id" if field=="chapters" else "id"
		var rows: Array = []
		for row: Dictionary in result.get(field,[]):
			rows.append({key:row[key],"title":row.title,"campaign_revision":2} if row.get("campaign_revision")==2 else row)
		result[field]=rows
	return result

static func catalog(base: Dictionary, state) -> Dictionary:
	if not eligible(state): return base
	var result := base.duplicate(true)
	var additions: Dictionary = data().get("catalog",{})
	for field: String in ["chapters","endings"]:
		var key := "quest_id" if field=="chapters" else "id"
		var by_id: Dictionary = {}
		for row: Dictionary in additions.get(field,[]): by_id[str(row[key])]=row
		for index in result.get(field,[]).size():
			var id := str(result[field][index].get(key,""))
			if by_id.has(id): result[field][index]=by_id[id].duplicate(true)
	return result

static func ritual(ending: String, state) -> Array:
	return data().get("ending_rituals",{}).get(ending,[]).duplicate(true) if Revision.from_state(state)==Revision.EXPANDED else []

static func ending_card(ending: String, state) -> String:
	return str(data().get("ending_cards",{}).get(ending,"")) if Revision.from_state(state)==Revision.EXPANDED else ""
