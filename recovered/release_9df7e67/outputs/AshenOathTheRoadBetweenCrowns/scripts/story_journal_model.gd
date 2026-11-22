extends RefCounted

## Presentation consumes explicit knowledge; it never completes objectives or
## treats a document, old quest completion, or a person's silence as consent.
const Routes = preload("res://scripts/story_route_catalog.gd")
const PEOPLE_PATH := "res://data/journal_people.json"
const WORK_PATH := "res://data/journal_work.json"
const EVIDENCE_DETAILS_PATH := "res://data/journal_evidence_details.json"
const ENEMIES_PATH := "res://data/enemies.json"
const PREPARATION_PATH := "res://data/preparation_notes.json"
static var _people_data: Dictionary = {}
static var _work_data: Dictionary = {}
static var _evidence_details_data: Dictionary = {}
static var _enemy_data: Dictionary = {}
static var _preparation_data: Dictionary = {}

static func _catalog(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return raw if typeof(raw) == TYPE_DICTIONARY else {}

static func people_catalog() -> Dictionary:
	if _people_data.is_empty():
		_people_data = _catalog(PEOPLE_PATH)
	return _people_data

static func work_catalog() -> Dictionary:
	if _work_data.is_empty():
		_work_data = _catalog(WORK_PATH)
	return _work_data

static func evidence_details_catalog() -> Dictionary:
	if _evidence_details_data.is_empty():
		var loaded: Dictionary = _catalog(EVIDENCE_DETAILS_PATH)
		if int(loaded.get("version", 0)) == 1:
			_evidence_details_data = loaded
	return _evidence_details_data

static func encounter_record(speaker_id: String, zone_id: String) -> Dictionary:
	var normalized: String = speaker_id.strip_edges().to_lower().replace("'", "").replace(" ", "_").replace("-", "_")
	for person in people_catalog().get("people", []):
		if typeof(person) != TYPE_DICTIONARY:
			continue
		var actor_id: String = str(person.get("id", ""))
		var named: bool = normalized in person.get("aliases", [])
		var unnamed: bool = normalized in person.get("unidentified_aliases", [])
		if not named and not unnamed:
			continue
		var record_id: String = "person:" + actor_id if named else "person:unidentified:" + actor_id
		return {"id": record_id, "entry": {"kind": "speaker", "actor_id": actor_id, "identified": named, "title": str(person.get("title", actor_id)) if named else str(person.get("unidentified_title", "An unnamed witness")), "zone": zone_id, "source": "A displayed account"}}
	return {}

static func sections(campaign: Dictionary, quests, state, zone_id: String) -> Array[Dictionary]:
	var recap: Dictionary = recap_model(campaign, quests, state, zone_id)
	var returns: Array[Dictionary] = [
		{"id": "promise", "title": "Current purpose" if _flag_text(state, "kael_pledge") == "" else "The promise", "body": str(recap.promise)},
		{"id": "last_commitment", "title": "What Kael last committed to", "body": str(recap.last_commitment)},
		{"id": "next_action", "title": "The next known step", "body": "%s\n%s%s" % [str(recap.next_action), "Where: " + str(recap.destination_name) + "\n" if str(recap.destination_name) != "" else "", str(recap.reason)]}
	]
	var covenant: Dictionary = _covenant_entry(campaign, state)
	if not covenant.is_empty():
		returns.append(covenant)
	var people: Array[Dictionary] = _people_entries(campaign, quests, state)
	var evidence: Array[Dictionary] = _evidence_entries(campaign, quests, state, zone_id)
	var work: Array[Dictionary] = _work_entries(quests, state, zone_id)
	var preparation: Array[Dictionary] = _preparation_entries(quests, state)
	var creatures: Array[Dictionary] = creature_entries(campaign, quests, state)
	return [
		{"id": "return", "title": "On Return", "body": str(recap.heading), "entries": returns},
		{"id": "people", "title": "People & Promises", "body": "These are the people whose names or accounts Kael has encountered. A remembered account and a freely given promise are different things." if not people.is_empty() else "No named account has been recorded yet.", "entries": people},
		{"id": "evidence", "title": "Evidence", "body": "Observation, testimony and inference are kept separate. Only recovered information appears here; there is no checklist of undiscovered secrets." if not evidence.is_empty() else "No evidence has been recorded. Inspect what the road leaves behind and hear the people who know it.", "entries": evidence},
		{"id": "work", "title": "Unfinished Work", "body": "Known obligations and their recorded results. An unrecorded result remains unknown; it does not mean that Kael failed." if not work.is_empty() else "No practical obligation is currently recorded. The next known story step remains in On Return.", "entries": work},
		{"id": "creatures", "title": "Known Creatures", "body": "Observed encounters and discovered accounts. Inference is not testimony; an unrecorded cause remains unknown." if not creatures.is_empty() else "No creature account is known yet. Undiscovered creatures and their details remain concealed.", "entries": creatures},
		{"id": "preparation", "title": "Preparation", "body": "What recovered evidence teaches Kael about surviving the road. Equipment and supplies remain available alongside these notes." if not preparation.is_empty() else "Newly understood encounters will add practical preparation here. Equipment and supplies remain available alongside the journal.", "entries": preparation}
	]

static func _covenant_entry(campaign: Dictionary, state) -> Dictionary:
	var value: String = _flag_text(state, "final_covenant")
	var ending_id: String = str({"witness": "expose", "mercy": "free", "duty": "bind", "ash": "kill"}.get(value, value))
	if ending_id == "":
		return {}
	for ending in campaign.get("endings", []):
		if str(ending.get("id", "")) != ending_id:
			continue
		var complete: bool = _flag_bool(state, "final_choice_completed")
		var body: String = "Chosen intention: " + str(ending.get("intention", ""))
		if complete:
			body += "\n\nWhat this leaves: " + str(ending.get("benefit", "")) + "\n\nWhat it costs: " + str(ending.get("cost", ""))
			body += "\n\n" + "\n\n".join(preload("res://scripts/epilogue_resolver.gd").living_road_cards(state))
		else:
			body += "\n\nThis intention is recorded, but its resolution has not yet been completed. Follow the next known step in the glade."
		return {"id": "covenant:" + ending_id, "title": str(ending.get("title", "Covenant")) + (" — carried out" if complete else " — intention chosen"), "body": body, "status": "completed" if complete else "pending"}
	return {}

static func recap_model(campaign: Dictionary, quests, state, zone_id: String) -> Dictionary:
	var promise: String = "Follow the missing travelers' account and preserve what the road reveals. No further personal pledge has been recorded."
	var pledge: String = _flag_text(state, "kael_pledge")
	if pledge == "protect":
		promise = "Stay while the people carrying this account need protection. Kael has promised his own work, not anybody else's testimony."
	elif pledge == "account":
		promise = "Stay and keep a record that cannot be closed again. Preserving the account does not give Kael ownership of another person's story."
	elif pledge == "stay":
		promise = "Kael chose to stay with the road's living consequences. He can keep his own promise without binding the people beside him."
	var last: String = "No consequential commitment has been recorded yet. Listening or inspecting a clue does not make the choice."
	var recorded: Variant = state.get("decisions") if state != null else []
	if typeof(recorded) == TYPE_ARRAY and not recorded.is_empty():
		var decision: Variant = recorded[-1]
		if typeof(decision) == TYPE_DICTIONARY:
			last = str(decision.get("label", "A commitment is recorded."))
			var result: String = str(decision.get("result", ""))
			if result != "":
				last += "\n" + result
	else:
		var known_outcomes: Array[Dictionary] = _resolved_outcomes(campaign, state)
		if not known_outcomes.is_empty():
			last = "Earlier choices survive in this save, but their order was not recorded. People & Promises preserves each known outcome without inventing which happened last."
	var recap: Dictionary = {"heading": "The road ahead", "promise": promise, "last_commitment": last, "next_action": "Read Greyfen's notice or speak with Anwen about the missing travelers.", "destination_zone": "greyfen", "destination_name": "Greyfen", "reason": "Begin with the people asking for an account; no new promise has been made for you."}
	var continuation: Dictionary = Routes.ending_continuation(state, zone_id) if state != null else {}
	if not continuation.is_empty():
		recap["heading"] = str(continuation.get("title", "What follows the covenant"))
		recap["next_action"] = str(continuation.get("action", continuation.get("next_action", "Return to the people waiting in Greyfen.")))
		recap["destination_zone"] = str(continuation.get("destination_zone", "greyfen"))
		recap["destination_name"] = str(continuation.get("destination_name", "Greyfen"))
		recap["reason"] = str(continuation.get("purpose", continuation.get("route_hint", "The covenant's consequences need ordinary work.")))
		if _flag_bool(state, "final_choice_completed"):
			recap["promise"] = "The covenant's outcome stands. Keep the surviving account and return to the people who must live with what comes next."
		return _finish_recap(recap)
	if _flag_bool(state, "final_choice_completed"):
		recap.merge({"heading": "The road remains open", "promise": "The final choice and the return to Greyfen are recorded. Their consequences remain part of this journey.", "next_action": "Visit a known place or take up an unfinished task in the journal.", "destination_zone": zone_id, "destination_name": _zone_name(zone_id), "reason": "There is no new covenant or unseen obligation waiting to be selected for you."}, true)
		return _finish_recap(recap)
	var quest_id: String = str(quests.get_tracked_quest()) if quests != null else ""
	if quest_id == "" and quests != null:
		for chapter in campaign.get("chapters", []):
			var candidate: String = str(chapter.get("quest_id", ""))
			if quests.is_active(candidate):
				quest_id = candidate
				break
	if quest_id != "" and quests != null:
		var objective_id: String = str(quests.get_active_objective_id(quest_id))
		var definition: Dictionary = quests.quest_defs.get(quest_id, {})
		recap["heading"] = str(definition.get("title", "The current promise"))
		for objective in definition.get("objectives", []):
			if str(objective.get("id", "")) == objective_id:
				recap["next_action"] = str(objective.get("text", "Follow the next known lead."))
				break
		var route: Dictionary = Routes.for_objective(quest_id, objective_id, state, quests, zone_id)
		recap["destination_zone"] = str(route.get("destination_zone", ""))
		recap["destination_name"] = str(route.get("destination_name", ""))
		recap["reason"] = str(route.get("purpose", "Follow the lead already recorded; further conclusions belong to what Kael discovers there."))
		if str(route.get("next_action", "")) != "":
			recap["next_action"] = str(route.next_action)
		for chapter in campaign.get("chapters", []):
			if str(chapter.get("quest_id", "")) == quest_id:
				recap["reason"] = str(chapter.get("question", recap.reason))
				break
	return _finish_recap(recap)

static func _finish_recap(recap: Dictionary) -> Dictionary:
	recap["body"] = "%s\nLast commitment: %s\nNext: %s%s\n%s" % [str(recap.promise), str(recap.last_commitment), str(recap.next_action), " (" + str(recap.destination_name) + ")" if str(recap.destination_name) != "" else "", str(recap.reason)]
	return recap

static func _people_entries(campaign: Dictionary, quests, state) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var covered_flags: Dictionary = {}
	if _flag_bool(state, "lr_vale_letter_read"):
		var letter_reply := _flag_text(state, "lr_vale_letter_reply")
		entries.append({"id":"lr_vale_correspondence", "title":"A letter from Record Keeper Vale", "body":"Vale asks the investigator to distinguish a person's name from permission to publish it. The letter makes no claim about a missing record and grants no access to Vargan.\n\nReply: " + (letter_reply.replace("_", " ") if letter_reply != "" else "Not sent. The letter remains at Greyfen's noticeboard.")})
	for person in people_catalog().get("people", []):
		if typeof(person) != TYPE_DICTIONARY:
			continue
		var id: String = str(person.get("id", ""))
		var identified: bool = _has_evidence(state, "person:" + id) or _any_gate(person.get("known_any", []), quests, state)
		var anonymous: bool = _has_evidence(state, "person:unidentified:" + id)
		if not identified and not anonymous:
			continue
		var title: String = str(person.get("title", id)) if identified else str(person.get("unidentified_title", "An unnamed witness"))
		var lines: Array[String] = [str(person.get("body", "")) if identified else str(person.get("unidentified_body", "Kael has heard this figure. Their identity has not been established."))]
		if identified:
			if state != null and state.commitment_partner() == id:
				lines.append("Current personal commitment: Kael and " + str(person.get("title", id)) + " explicitly chose each other. This does not supply testimony, evidence or consent to speak publicly.")
			for fact in person.get("facts", []):
				if typeof(fact) == TYPE_DICTIONARY and _gate(fact.get("gate", {}), quests, state):
					lines.append(str(fact.get("body", "")))
			for resolved in _resolved_outcomes(campaign, state):
				if str(resolved.flag) in person.get("decision_flags", []):
					lines.append("Recorded commitment: " + str(resolved.title) + "\n" + str(resolved.body))
					covered_flags[str(resolved.flag)] = true
			for promise in person.get("promises", []):
				if typeof(promise) == TYPE_DICTIONARY and _gate(promise.get("gate", {}), quests, state):
					lines.append(str(promise.get("body", "")))
			if state != null and state.has_method("relationship_events"):
				for event: Dictionary in state.relationship_events(id):
					lines.append("Remembered " + str(event.kind).replace("_", " ") + ": " + str(event.text))
			var consent_key: String = str(person.get("consent_flag", ""))
			var consent: String = _flag_text(state, consent_key) if consent_key != "" else ""
			var unavailable: String = str(person.get("unavailable_flag", ""))
			if unavailable != "" and _flag_text(state, unavailable) in person.get("unavailable_values", []):
				lines.append("Availability: " + str(person.get("unavailable_body", "This person is no longer available to take part. Their surviving records do not supply a new promise.")))
			elif consent_key != "" and (consent != "" or _flag_bool(state, "renewal_announced") or _flag_bool(state, "renewal_stopped")):
				lines.append("Participation: " + _consent_text(consent))
		entries.append({"id": "person:" + id, "title": title, "body": "\n\n".join(lines), "identified": identified})
	for resolved in _resolved_outcomes(campaign, state):
		if not covered_flags.has(str(resolved.flag)):
			entries.append({"id": "commitment:" + str(resolved.id), "title": "Recorded commitment — " + str(resolved.title), "body": str(resolved.body)})
	return entries

static func _resolved_outcomes(campaign: Dictionary, state) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for decision in campaign.get("decisions", []):
		var flag: String = str(decision.get("flag", ""))
		var value: String = _flag_text(state, flag)
		if value == "":
			continue
		for outcome in decision.get("outcomes", []):
			if str(outcome.get("value", "")) == value:
				entries.append({"id": str(decision.get("id", flag)), "flag": flag, "title": str(outcome.get("label", value)), "body": str(outcome.get("result", "The choice is recorded."))})
	return entries

static func evidence_model(campaign: Dictionary, quests, state, zone_id: String = "") -> Dictionary:
	var entries: Array[Dictionary] = _evidence_entries(campaign, quests, state, zone_id)
	var filters: Array[Dictionary] = [{"id": "all", "label": "All records", "count": entries.size()}]
	for kind: String in ["observed", "testimony", "inference"]:
		var count: int = 0
		for entry: Dictionary in entries:
			if str(entry.get("kind", "")) == kind:
				count += 1
		if count > 0:
			filters.append({"id": kind, "label": _evidence_kind_label(kind), "count": count})
	return {
		"body": "Select a recorded account to read its source, interpretation and limits. Related reading contains only what this journey has already uncovered." if not entries.is_empty() else "No evidence has been recorded. Inspect what the road leaves behind and hear the people who know it.",
		"entries": entries,
		"filters": filters
	}

static func evidence_detail(campaign: Dictionary, entry_id: String, quests, state, zone_id: String = "") -> Dictionary:
	if entry_id == "":
		return {}
	var stable_id: String = entry_id if entry_id.begins_with("evidence:") else "evidence:" + entry_id
	for entry: Dictionary in _evidence_entries(campaign, quests, state, zone_id):
		if str(entry.get("id", "")) == stable_id:
			return entry
	return {}

static func _evidence_kind_label(kind: String) -> String:
	return str({"observed": "Observation", "testimony": "Testimony", "inference": "Inference"}.get(kind, "Record"))

static func _evidence_entries(campaign: Dictionary, quests, state, zone_id: String = "") -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var authored_by_id: Dictionary = {}
	var raw_details: Variant = evidence_details_catalog().get("details", [])
	if raw_details is Array:
		for raw_detail: Variant in raw_details:
			if raw_detail is Dictionary and str(raw_detail.get("id", "")) != "":
				authored_by_id[str(raw_detail.get("id", ""))] = raw_detail
	for kind: String in ["observed", "testimony", "inference"]:
		for raw_evidence: Variant in campaign.get("evidence", []):
			if not raw_evidence is Dictionary:
				continue
			var evidence: Dictionary = raw_evidence
			# Detail prose, provenance aliases and related quests are presentation
			# only. They never broaden the established discovery predicate.
			if str(evidence.get("kind", "observed")) != kind or not _discovered(evidence, quests, state):
				continue
			var id: String = str(evidence.get("id", ""))
			if id == "":
				continue
			var authored: Dictionary = authored_by_id.get(id, {})
			var blocks: Array[Dictionary] = _evidence_blocks(authored, quests, state)
			var recorded_text: String = str(evidence.get("text", "")) if authored.is_empty() else ""
			var compact: String = recorded_text
			for block: Dictionary in blocks:
				if str(block.get("kind", "")) in ["observation", "testimony"]:
					compact = str(block.get("body", ""))
					break
			if compact == "":
				compact = "This record is known; no further account is recorded here."
			var source: String = str(authored.get("source", evidence.get("source", ""))).strip_edges()
			var provenance: Dictionary = _evidence_provenance(evidence, authored, state)
			var place: String = str(provenance.get("place", ""))
			var place_label: String = str(provenance.get("place_label", ""))
			var body: String = compact
			if source != "":
				body += "\n\nSource: " + source
			if place != "":
				body += "\n" + place_label + ": " + place
			entries.append({
				"id": "evidence:" + id,
				"detail_id": "evidence:" + id,
				"title": str(evidence.get("title", "Record")),
				"body": body,
				"kind": kind,
				"kind_label": _evidence_kind_label(kind),
				"source": source,
				"place": place,
				"place_label": place_label,
				"zone": str(provenance.get("zone", "")),
				"recorded_text": recorded_text,
				"text_label": "Recorded account",
				"blocks": blocks,
				"known_relevance": _evidence_known_lead(authored, quests, state, zone_id),
				"links": []
			})
	var creatures: Array[Dictionary] = creature_entries(campaign, quests, state)
	var visible: Dictionary = {"evidence": {}, "people": {}, "preparation": {}, "creatures": {}}
	for entry: Dictionary in entries:
		visible["evidence"][str(entry.get("id", ""))] = str(entry.get("title", "Record"))
	for entry: Dictionary in _people_entries(campaign, quests, state):
		visible["people"][str(entry.get("id", ""))] = str(entry.get("title", "Person"))
	for entry: Dictionary in _preparation_entries(quests, state):
		visible["preparation"][str(entry.get("id", ""))] = str(entry.get("title", "Preparation"))
	for creature: Dictionary in creatures:
		visible["creatures"][str(creature.id)] = str(creature.title)
	for entry: Dictionary in entries:
		var id: String = str(entry.get("id", "")).trim_prefix("evidence:")
		entry["links"] = _evidence_links(authored_by_id.get(id, {}), visible, str(entry.get("id", "")))
		for creature: Dictionary in creatures:
			for link: Dictionary in creature.get("links", []):
				if str(link.get("entry_id", "")) == str(entry.id):
					entry.links.append({"section_id":"creatures", "entry_id":str(creature.id), "label":str(creature.title)})
	return entries

static func _evidence_blocks(authored: Dictionary, quests, state) -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	var raw_sections: Variant = authored.get("sections", [])
	if not raw_sections is Array:
		return blocks
	for raw_section: Variant in raw_sections:
		if not raw_section is Dictionary:
			continue
		var section: Dictionary = raw_section
		var kind: String = str(section.get("kind", ""))
		if kind not in ["observation", "testimony", "interpretation", "limit", "relevance"]:
			continue
		if section.has("gate") and not _gate(section.get("gate", {}), quests, state):
			continue
		var body: String = str(section.get("body", "")).strip_edges()
		if body == "":
			continue
		var fallback_title: String = str({"observation": "Recorded observation", "testimony": "Recorded account", "interpretation": "Kael's interpretation", "limit": "Limits of this record", "relevance": "Known relevance"}[kind])
		blocks.append({"id": str(section.get("id", "block_%d" % blocks.size())), "kind": kind, "title": str(section.get("title", fallback_title)), "body": body})
	return blocks

static func _evidence_provenance(evidence: Dictionary, authored: Dictionary, state) -> Dictionary:
	var record_ids: Array[String] = [str(evidence.get("id", ""))]
	var raw_ids: Variant = authored.get("record_ids", [])
	if raw_ids is Array:
		for raw_id: Variant in raw_ids:
			if raw_id is String and str(raw_id) != "" and not record_ids.has(str(raw_id)):
				record_ids.append(str(raw_id))
	var ledger: Variant = state.get("evidence") if state != null else {}
	if ledger is Dictionary:
		for record_id: String in record_ids:
			var raw_record: Variant = ledger.get(record_id, {})
			if not raw_record is Dictionary:
				continue
			var recorded_zone: String = str(raw_record.get("zone", "")).strip_edges()
			if recorded_zone != "":
				return {"zone": recorded_zone, "place": Routes.zone_name(recorded_zone), "place_label": "Recorded at"}
	var associated_zone: String = str(evidence.get("zone", "")).strip_edges()
	return {"zone": associated_zone, "place": Routes.zone_name(associated_zone) if associated_zone != "" else "", "place_label": "Associated place" if associated_zone != "" else ""}

static func _evidence_links(authored: Dictionary, visible: Dictionary, current_id: String) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var raw_related: Variant = authored.get("related_ids", [])
	if raw_related is Array:
		for raw_id: Variant in raw_related:
			if raw_id is String and str(raw_id) != "":
				var id: String = str(raw_id)
				candidates.append({"section_id": "evidence", "entry_id": id if id.begins_with("evidence:") else "evidence:" + id})
	var raw_entries: Variant = authored.get("related_entries", [])
	if raw_entries is Array:
		for raw_entry: Variant in raw_entries:
			if raw_entry is Dictionary and str(raw_entry.get("section_id", "")) in ["people", "preparation", "creatures"]:
				candidates.append(raw_entry)
	var links: Array[Dictionary] = []
	var added: Dictionary = {}
	for candidate: Dictionary in candidates:
		var section_id: String = str(candidate.get("section_id", ""))
		var entry_id: String = str(candidate.get("entry_id", ""))
		var available: Dictionary = visible.get(section_id, {})
		var link_key: String = section_id + "/" + entry_id
		if entry_id == current_id or not available.has(entry_id) or added.has(link_key):
			continue
		added[link_key] = true
		links.append({"section_id": section_id, "entry_id": entry_id, "label": str(available.get(entry_id, ""))})
	return links

static func _evidence_known_lead(authored: Dictionary, quests, state, zone_id: String) -> Array[Dictionary]:
	var leads: Array[Dictionary] = []
	var related: Variant = authored.get("related_quests", [])
	if quests == null or not related is Array:
		return leads
	var candidates: Array[String] = []
	var tracked_id: String = str(quests.get_tracked_quest())
	if tracked_id != "" and related.has(tracked_id):
		candidates.append(tracked_id)
	for raw_id: Variant in related:
		if raw_id is String and str(raw_id) != "" and not candidates.has(str(raw_id)):
			candidates.append(str(raw_id))
	for quest_id: String in candidates:
		if not bool(quests.is_active(quest_id)):
			continue
		var objective_id: String = str(quests.get_active_objective_id(quest_id))
		if objective_id == "":
			continue
		var definition: Dictionary = quests.quest_defs.get(quest_id, {})
		var objective: Dictionary = {}
		for raw_objective: Variant in definition.get("objectives", []):
			if raw_objective is Dictionary and str(raw_objective.get("id", "")) == objective_id:
				objective = raw_objective
				break
		var action: String = str(objective.get("text", "")).strip_edges()
		if action == "":
			continue
		# A grouped evidence step must not select a missing sub-record for the
		# journal reader. Its already-visible objective is sufficient context.
		var grouped: bool = str(objective.get("group", "")) != "" or int(objective.get("required_count", 0)) > 0
		var route: Dictionary = {} if grouped else Routes.for_objective(quest_id, objective_id, state, quests, zone_id)
		var body: String = str(route.get("next_action", action))
		var destination: String = str(route.get("destination_name", ""))
		var hint: String = str(route.get("route_hint", ""))
		if destination != "":
			body += "\nWhere: " + destination
		if hint != "" and hint != body:
			body += "\n" + hint
		leads.append({"id": "quest:%s:%s" % [quest_id, objective_id], "title": "Current known lead — " + str(definition.get("title", "The current task")), "body": body})
		break
	return leads

static func _work_entries(quests, state, zone_id: String) -> Array[Dictionary]:
	var open_entries: Array[Dictionary] = []
	var settled_entries: Array[Dictionary] = []
	for work in work_catalog().get("work", []):
		if typeof(work) != TYPE_DICTIONARY or not _any_gate(work.get("known_any", []), quests, state):
			continue
		var selected: Dictionary = {}
		for stage in work.get("stages", []):
			if typeof(stage) == TYPE_DICTIONARY and _gate(stage.get("gate", {}), quests, state):
				selected = stage
				break
		var status: String = str(selected.get("status", "unresolved"))
		var body: String = str(selected.get("body", work.get("body", "This work is known; its result has not been recorded.")))
		var zone: String = str(work.get("zone", ""))
		body += "\n\nWhere: " + _zone_name(zone) if zone != "" else ""
		var entry: Dictionary = {"id": "work:" + str(work.get("id", "")), "title": str(work.get("title", "Known work")), "body": body, "status": status, "zone": zone, "local": zone == zone_id}
		if status in ["completed", "recorded"]:
			settled_entries.append(entry)
		else:
			open_entries.append(entry)
	open_entries.append_array(settled_entries)
	return open_entries

static func _preparation_entries(quests, state) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var known_creatures: Dictionary = _known_creatures(quests, state)
	var grave_count: int = 0
	for id in ["grave_harl", "grave_child", "grave_soldier"]:
		if _discovered({"id": id, "gate": {"quest": "main_bell_beneath_greyfen", "objective": id}}, quests, state):
			grave_count += 1
	if grave_count >= 2:
		entries.append({"id": "preparation:bell", "title": "Read the bell", "body": "The cut ropes share a pull. Watch the raised clapper and step clear. Reading the graves gives extra time on its first tell in each phase; an avoided bell action leaves a short recovery opening."})
	if _discovered({"id": "mill_accounts", "gate": {"quest": "main_ash_at_the_mill", "objective": "inspect_millstones"}}, quests, state):
		entries.append({"id": "preparation:ashwing", "title": "Cross Ashwing's plume", "body": "Dust reveals the breath's direction. Move across the plume. Avoiding its prepared attack gives a brief opening once per phase."})
	if _flag_bool(state, "command_proof_recovered"):
		entries.append({"id": "preparation:halvern", "title": "Question the guarded account", "body": "The order establishes the witness's refusal, not his knowledge of the present. A clean parry gives a longer first opening in each phase for the question his bounded memory can answer."})
	if _discovered({"id": "chapel_names", "gate": {"quest": "main_teeth_in_rain", "objective": "read_chapel_names"}}, quests, state) and _discovered({"id": "ritual_stones", "gate": {"quest": "main_teeth_in_rain", "objective": "name_the_dead"}}, quests, state):
		entries.append({"id": "preparation:bog", "title": "Read the restored name", "body": "The restored name gives time to read the Bog Wretch's first approach. Moon Oil and clean interruptions help expose its memory; neither is a required purchase."})
	for enemy_id: String in _enemy_data:
		if not known_creatures.has(enemy_id) and not _has_evidence(state, "creature:" + enemy_id):
			continue
		var definition: Dictionary = _enemy_data[enemy_id]
		var blade_id := EquipmentLoadout.preferred_blade_for_tag(str(definition.get("tag", "")))
		if blade_id == "":
			continue
		var blade_name := "Steel" if blade_id == "steel" else "Oathblade"
		var basis := "a physical body" if blade_id == "steel" else "an oathbound or spiritual body"
		var percent := int(round((EquipmentLoadout.AFFINITY_MULTIPLIER - 1.0) * 100.0))
		entries.append({"id": "preparation:blade:" + enemy_id, "title": str(definition.get("name", enemy_id)) + " - blade preparation", "body": "%s gains %d%% blade damage against this foe's nature: %s. The other blade still deals normal damage. Oils and existing openings remain useful; no blade is compulsory." % [blade_name, percent, basis]})
	return entries

static func _known_creatures(quests, state) -> Dictionary:
	if _enemy_data.is_empty():
		_enemy_data = _catalog(ENEMIES_PATH)
	if _preparation_data.is_empty():
		_preparation_data = _catalog(PREPARATION_PATH)
	var known: Dictionary = {}
	for id: String in _enemy_data:
		var note: Dictionary = _preparation_data.get("creatures", {}).get(id, {})
		var outcome_flag: String = str(note.get("outcome_flag", ""))
		if _has_evidence(state, "creature:" + id) or _gate(note.get("known_gate", {}), quests, state) or (outcome_flag != "" and _gate({"flag":outcome_flag}, quests, state)):
			known[id] = true
	var graves: int = 0
	for id: String in ["grave_harl", "grave_child", "grave_soldier"]:
		if _discovered({"id":id, "gate":{"quest":"main_bell_beneath_greyfen", "objective":id}}, quests, state):
			graves += 1
	if graves >= 2:
		known["bell_eater"] = true
	if _discovered({"id":"mill_accounts", "gate":{"quest":"main_ash_at_the_mill", "objective":"inspect_millstones"}}, quests, state):
		known["ashwing"] = true
	if _discovered({"id":"chapel_names", "gate":{"quest":"main_teeth_in_rain", "objective":"read_chapel_names"}}, quests, state) and _discovered({"id":"ritual_stones", "gate":{"quest":"main_teeth_in_rain", "objective":"name_the_dead"}}, quests, state):
		known["bog_wretch"] = true
	return known

static func creature_entries(campaign: Dictionary, quests, state) -> Array[Dictionary]:
	var known: Dictionary = _known_creatures(quests, state)
	var entries: Array[Dictionary] = []
	for id: String in _enemy_data:
		if not known.has(id):
			continue
		var definition: Dictionary = _enemy_data[id]
		var note: Dictionary = _preparation_data.get("creatures", {}).get(id, {})
		var observed: bool = _has_evidence(state, "creature:" + id)
		var body: String = "Observed: Kael has faced this creature." if observed else "Known from a recovered account or a recorded encounter outcome."
		var blade: String = EquipmentLoadout.preferred_blade_for_tag(str(definition.get("tag", "")))
		body += "\n\nPREPARATION\n"
		if blade != "":
			body += "%s has a %d%% affinity advantage; the other blade still works normally.\n" % ["Steel" if blade == "steel" else "Oathblade", int(round((EquipmentLoadout.AFFINITY_MULTIPLIER - 1.0) * 100.0))]
		body += str(note.get("approach", "Leave room to retreat and watch a committed attack before answering."))
		var links: Array[Dictionary] = []
		for raw: Variant in campaign.get("evidence", []):
			if not raw is Dictionary or str(raw.get("id", "")) not in note.get("evidence", []) or not _discovered(raw, quests, state):
				continue
			var label: String = "Inference" if str(raw.get("kind", "")) == "inference" else ("Testimony" if str(raw.get("kind", "")) == "testimony" else "Known observation")
			body += "\n\n%s - %s\n%s" % [label, str(raw.get("title", "Recorded account")), str(raw.get("text", ""))]
			links.append({"section_id":"evidence", "entry_id":"evidence:" + str(raw.id), "label":str(raw.get("title", "Recorded account"))})
		body += "\n\nUnavailable: the human cause is not established by this record." if links.is_empty() else "\n\nLimits: these records establish only their own observations and accounts, not every creature's intent."
		var resolved: bool = false
		var outcome_flag: String = str(note.get("outcome_flag", ""))
		if outcome_flag != "" and _gate({"flag":outcome_flag}, quests, state):
			resolved = id != "white_hart_avatar" or _flag_bool(state, "final_choice_completed")
			var outcome: Variant = state.get_flag(outcome_flag, "")
			body += "\n\nRECORDED OUTCOME\n" + ("The encounter is resolved." if outcome is bool else str(outcome).replace("_", " ").capitalize())
			for decision: Dictionary in campaign.get("decisions", []):
				if str(decision.get("flag", "")) == outcome_flag:
					for result: Dictionary in decision.get("outcomes", []):
						if str(result.get("value", "")) == str(outcome):
							body += "\n" + str(result.get("result", result.get("label", "")))
			body += "\nNo further attack is needed for this recorded outcome." if resolved else "\nThis intention is not yet a completed resolution. Follow the current objective."
		var suggested: Array[String] = []
		var tag: String = str(definition.get("tag", ""))
		if tag in ["spirit", "undead"]:
			suggested.append("moon_oil" if tag == "spirit" else "rot_oil")
		var weakness: String = str(definition.get("weakness", ""))
		if weakness in ["iron_trap", "ash_bomb"]:
			suggested.append(weakness)
		entries.append({"id":"creature:" + id, "title":str(definition.get("name", id)), "body":body, "links":links, "suggested_items":suggested, "resolved":resolved})
	return entries

static func _consent_text(value: String) -> String:
	return str({"voluntary": "has freely chosen to speak about their own part.", "protected": "has chosen to speak under protection; food and safe departure must remain independent of assent.", "compelled": "an admission was compelled. It is evidence, not consent to a new oath.", "refused": "has declined. A surviving record does not reverse that refusal.", "unavailable": "is unavailable. Records can establish facts but cannot make this person's promise."}.get(value, "no freely given participation has been recorded. Kael cannot presume it."))

static func _discovered(evidence: Dictionary, quests, state) -> bool:
	return _has_evidence(state, str(evidence.get("id", ""))) or _gate(evidence.get("gate", {}), quests, state)

static func _any_gate(raw: Variant, quests, state) -> bool:
	if typeof(raw) != TYPE_ARRAY:
		return false
	for gate in raw:
		if _gate(gate, quests, state):
			return true
	return false

static func _gate(raw: Variant, quests, state) -> bool:
	if typeof(raw) != TYPE_DICTIONARY or raw.is_empty():
		return false
	var gate: Dictionary = raw
	if gate.has("all"):
		for part in gate.all:
			if not _gate(part, quests, state):
				return false
		return not gate.all.is_empty()
	if gate.has("any"):
		return _any_gate(gate.any, quests, state)
	if gate.has("evidence"):
		return _has_evidence(state, str(gate.evidence))
	if gate.has("flag"):
		if state == null:
			return false
		var actual: Variant = state.get_flag(str(gate.flag), null)
		if gate.has("value"):
			return actual == gate.value
		if gate.has("min"):
			return typeof(actual) in [TYPE_INT, TYPE_FLOAT] and float(actual) >= float(gate.min)
		if gate.has("values"):
			return actual in gate.values
		return actual != null and actual != false and str(actual) != ""
	if gate.has("quest") and gate.has("objective"):
		if quests == null:
			return false
		var evidence_history: Variant = quests.get("evidence_history")
		if typeof(evidence_history) == TYPE_DICTIONARY and bool(evidence_history.get(str(gate.quest) + ":" + str(gate.objective), false)):
			return true
		return bool(quests.is_active(str(gate.quest))) and bool(quests.is_objective_done(str(gate.quest), str(gate.objective)))
	return false

static func _has_evidence(state, id: String) -> bool:
	if state == null or id == "":
		return false
	var evidence: Variant = state.get("evidence")
	return typeof(evidence) == TYPE_DICTIONARY and evidence.has(id)

static func _flag_text(state, id: String) -> String:
	return str(state.get_flag(id, "")) if state != null and id != "" else ""

static func _flag_bool(state, id: String) -> bool:
	return bool(state.get_flag(id, false)) if state != null else false

static func _zone_name(id: String) -> String:
	return str({"greyfen": "Greyfen", "wychwood": "Wychwood", "cemetery": "Greyfen Cemetery", "ruins": "The ruins", "deep_wood": "Deep Wood", "old_mill": "Old Mill", "burned_farmstead": "Burned Farmstead", "marsh_crossing": "Marsh Crossing", "bandit_road": "Bandit Road", "vargan_approach": "Vargan Approach", "vargan_court": "Vargan Court", "record_hall": "Record Hall", "undercroft": "Vargan Undercroft", "assembly": "Greyfen Assembly", "hart_glade": "Hart Glade"}.get(id, id.replace("_", " ").capitalize()))
