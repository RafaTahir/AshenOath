extends RefCounted
class_name StoryJournal

## Read-only interpretation of discovered evidence and explicit decisions.
## Quest completion never manufactures consent or an unrecorded choice.
const CAMPAIGN_PATH := "res://data/story_campaign.json"
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
	var chapter := active_chapter(game.quests)
	var lines: Array[String] = ["Your promise: find the missing and preserve their account."]
	if not chapter.is_empty():
		lines.append("Now: %s - %s" % [chapter.get("title", "The road"), chapter.get("question", "Who is being kept silent?")])
	var recorded = game.story_state.get("decisions")
	if typeof(recorded) == TYPE_ARRAY and not recorded.is_empty() and typeof(recorded[-1]) == TYPE_DICTIONARY:
		lines.append("Last commitment: " + str(recorded[-1].get("label", "A recorded decision stands.")))
	return "\n".join(lines)

static func build_from_state(quests, state) -> String:
	var data := campaign()
	var sections: Array[String] = []
	sections.append("THE PROMISE\nFind the people missing from the road. Keep the recovered record safe. No person's silence gives Kael permission to speak for them.")
	var chapter := active_chapter(quests, data)
	if not chapter.is_empty():
		var lead := ""
		var quest_id := str(chapter.get("quest_id", ""))
		if quests != null:
			var objective_id := str(quests.get_active_objective_id(quest_id))
			for objective in quests.quest_defs.get(quest_id, {}).get("objectives", []):
				if str(objective.get("id", "")) == objective_id:
					lead = str(objective.get("text", ""))
		sections.append("WHERE KAEL STANDS\n%s\nQuestion: %s\nAt stake: %s\nNext lead: %s" % [chapter.get("title", "The road"), chapter.get("question", "Who is being kept silent?"), chapter.get("stakes", "The living must answer for what the road carries."), lead if lead != "" else "Review the tracked promise below."])
	var decisions: Array[String] = []
	var last_commitment := ""
	var recorded = state.get("decisions") if state != null else null
	if typeof(recorded) == TYPE_ARRAY and not recorded.is_empty():
		var last: Dictionary = recorded[-1] if typeof(recorded[-1]) == TYPE_DICTIONARY else {}
		last_commitment = str(last.get("label", ""))
	for decision in data.get("decisions", []):
		var flag := str(decision.get("flag", ""))
		var value := str(state.get_flag(flag, "")) if state != null and flag != "" else ""
		if value == "":
			continue
		for outcome in decision.get("outcomes", []):
			if str(outcome.get("value", "")) == value:
				decisions.append("%s: %s\n%s%s" % [decision.get("title", "Decision"), outcome.get("label", value), outcome.get("result", "The decision stands."), "\nCost: " + str(outcome.get("cost", "")) if str(outcome.get("cost", "")) != "" else ""])
	if not decisions.is_empty():
		sections.append("ON RETURN\n%s\n\nCONSEQUENCES THAT STAND\n%s" % ["Last recorded commitment: " + last_commitment if last_commitment != "" else "The recorded commitments below still stand.", "\n\n".join(decisions)])
	else:
		sections.append("ON RETURN\nNo major commitment has been recorded yet. An inspected clue is evidence, not a decision.")
	for kind in ["observed", "testimony", "inference"]:
		var entries: Array[String] = []
		for evidence in data.get("evidence", []):
			if str(evidence.get("kind", "observed")) != kind or not _discovered(evidence, quests, state):
				continue
			entries.append("%s\n%s\nSource: %s" % [evidence.get("title", "Record"), evidence.get("text", ""), evidence.get("source", "Kael's observation")])
		var heading: String = {"observed":"OBSERVED FACTS", "testimony":"WITNESS ACCOUNTS", "inference":"KAEL'S INFERENCES"}[kind]
		sections.append(heading + "\n" + ("\n\n".join(entries) if not entries.is_empty() else "Nothing recorded in this category yet."))
	var witnesses: Array[String] = []
	if state != null:
		for actor in ["anwen", "rook", "mira", "tor", "elna", "senn", "edric"]:
			var consent := str(state.get_flag("witness_consent_" + actor, ""))
			if consent != "":
				witnesses.append("%s: %s" % [actor.capitalize(), {"voluntary":"has chosen to speak", "protected":"has chosen to speak under protection", "compelled":"has been compelled; this is not consent", "refused":"declined public testimony", "unavailable":"is unavailable; records can establish facts, not consent"}.get(consent, "participation remains unresolved")])
	if not witnesses.is_empty():
		sections.append("WHO HAS CHOSEN TO SPEAK\n" + "\n".join(witnesses))
	var tactics: Array[String] = []
	var grave_count := 0
	for id in ["grave_harl", "grave_child", "grave_soldier"]:
		if _discovered({"id":id, "gate":{"quest":"main_bell_beneath_greyfen", "objective":id}}, quests, state):
			grave_count += 1
	if grave_count >= 2:
		tactics.append("Bell beneath Greyfen: the cut ropes share a pull. Watch the raised clapper and step clear. Reading the graves gives extra time on its first tell in each phase; an avoided bell action leaves a short recovery opening.")
	if _discovered({"id":"mill_accounts", "gate":{"quest":"main_ash_at_the_mill", "objective":"inspect_millstones"}}, quests, state):
		tactics.append("Ashwing: dust reveals the breath's direction. Move across the plume. A successful avoidance of its prepared attack gives a brief opening once per phase.")
	if state != null and bool(state.get_flag("command_proof_recovered", false)):
		tactics.append("Halvern: the order establishes his refusal, not his knowledge of the present. A clean parry gives a longer first opening in each phase for the question his bounded memory can answer.")
	if _discovered({"id":"chapel_names", "gate":{"quest":"main_teeth_in_rain", "objective":"read_chapel_names"}}, quests, state) and _discovered({"id":"ritual_stones", "gate":{"quest":"main_teeth_in_rain", "objective":"name_the_dead"}}, quests, state):
		tactics.append("Bog Wretch: the restored name gives time to read its first approach. Moon Oil and clean interruptions help expose its memory; neither is a required purchase.")
	if not tactics.is_empty():
		sections.append("PREPARATION FROM EVIDENCE\n" + "\n\n".join(tactics))
	return "\n\n".join(sections)

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
