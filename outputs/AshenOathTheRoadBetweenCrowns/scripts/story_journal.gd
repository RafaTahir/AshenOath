extends RefCounted
class_name StoryJournal

## Read-only interpretation of discovered evidence and explicit decisions.
## Quest completion never manufactures consent or an unrecorded choice.
const CAMPAIGN_PATH := "res://data/story_campaign.json"
const Model = preload("res://scripts/story_journal_model.gd")
static var _campaign_data: Dictionary = {}

static func campaign() -> Dictionary:
	if not _campaign_data.is_empty():
		return _campaign_data
	if not FileAccess.file_exists(CAMPAIGN_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CAMPAIGN_PATH))
	_campaign_data = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	return _campaign_data

static func build(game) -> String:
	return build_from_state(game.quests, game.story_state)

static func recap(game) -> String:
	var zone_id: String = str(game.get("current_zone_id"))
	return str(recap_model(game.quests, game.story_state, zone_id).get("body", ""))

static func sections(quests, state, zone_id: String = "") -> Array[Dictionary]:
	return Model.sections(campaign(), quests, state, zone_id)

static func evidence_model(quests, state, zone_id: String = "") -> Dictionary:
	return Model.evidence_model(campaign(), quests, state, zone_id)

static func evidence_detail(entry_id: String, quests, state, zone_id: String = "") -> Dictionary:
	return Model.evidence_detail(campaign(), entry_id, quests, state, zone_id)

static func recap_model(quests, state, zone_id: String = "") -> Dictionary:
	return Model.recap_model(campaign(), quests, state, zone_id)

static func encounter_record(speaker_id: String, zone_id: String) -> Dictionary:
	return Model.encounter_record(speaker_id, zone_id)

static func build_from_state(quests, state) -> String:
	var result: Array[String] = []
	for section in sections(quests, state):
		var body: String = str(section.title).to_upper() + "\n" + str(section.body)
		for entry in section.get("entries", []):
			body += "\n\n" + str(entry.get("title", "")) + "\n" + str(entry.get("body", ""))
		result.append(body)
	return "\n\n".join(result)

static func active_chapter(quests, data: Dictionary = {}) -> Dictionary:
	if quests == null:
		return {}
	if data.is_empty():
		data = campaign()
	var tracked := str(quests.get_tracked_quest())
	for chapter in data.get("chapters", []):
		if str(chapter.get("quest_id", "")) == tracked:
			return chapter
	for chapter in data.get("chapters", []):
		if quests.is_active(str(chapter.get("quest_id", ""))):
			return chapter
	return {}

static func decision_preview(action: Dictionary) -> String:
	var explicit := str(action.get("preview", action.get("consequence_preview", "")))
	if explicit != "":
		return explicit
	var flags: Dictionary = action.get("sets_flags", {})
	for decision in campaign().get("decisions", []):
		var flag := str(decision.get("flag", ""))
		if not flags.has(flag):
			continue
		for outcome in decision.get("outcomes", []):
			if str(outcome.get("value", "")) == str(flags[flag]):
				return "%s%s" % [outcome.get("result", ""), " Cost: " + str(outcome.get("cost", "")) if str(outcome.get("cost", "")) != "" else ""]
	return str(action.get("cost", ""))

static func _discovered(evidence: Dictionary, quests, state) -> bool:
	if state != null:
		var ledger = state.get("evidence")
		if typeof(ledger) == TYPE_DICTIONARY and ledger.has(str(evidence.get("id", ""))):
			return true
	var gate: Dictionary = evidence.get("gate", {})
	if gate.has("quest") and gate.has("objective"):
		if quests == null:
			return false
		var history = quests.get("evidence_history")
		if typeof(history) == TYPE_DICTIONARY and bool(history.get("%s:%s" % [gate.quest, gate.objective], false)):
			return true
		return quests.is_active(str(gate.quest)) and quests.is_objective_done(str(gate.quest), str(gate.objective))
	if gate.has("flag"):
		if state == null:
			return false
		var actual = state.get_flag(str(gate.flag), null)
		return actual == gate.value if gate.has("value") else actual != null and actual != false and str(actual) != ""
	# Unspecified discovery cannot expose future revelations.
	return false
