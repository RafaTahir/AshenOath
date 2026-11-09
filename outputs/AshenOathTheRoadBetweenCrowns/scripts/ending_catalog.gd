extends RefCounted

const Campaign = preload("res://scripts/campaign_revision.gd")
const IDS := ["expose", "free", "bind", "kill", "share", "depart"]
const ORIGINAL_IDS := ["expose", "free", "bind", "kill"]
const COVENANTS := {"expose":"witness", "free":"mercy", "bind":"duty", "kill":"ash", "share":"concord", "depart":"open_road"}
const TITLES := {"expose":"Witness", "free":"Mercy", "bind":"Duty", "kill":"Ash", "share":"Concord", "depart":"Open Road"}
const CONSENT_GROUPS := [["anwen", "mira"], ["nera", "nessa"], ["vale", "merrow"]]
const CONSENT_FLAG := "community_keeper_consent"

static func normalize(value: String) -> String:
	if value in IDS:
		return value
	for id: String in IDS:
		if COVENANTS[id] == value:
			return id
	return ""

static func covenant(value: String) -> String:
	return str(COVENANTS.get(normalize(value), ""))

static func title(value: String) -> String:
	return str(TITLES.get(normalize(value), "Unresolved"))

static func is_peaceful(value: String) -> bool:
	var id := normalize(value)
	return id != "" and id != "kill"

static func has_keeper_consent(state) -> bool:
	var consent: Variant = state.get_flag(CONSENT_FLAG, {})
	if not consent is Dictionary:
		return false
	for group: Array in CONSENT_GROUPS:
		var accepted := false
		for id: String in group:
			var answer: Variant = consent.get(id, false)
			if typeof(answer) == TYPE_BOOL and answer:
				accepted = true
		if not accepted:
			return false
	return true

static func available(value: String, state, quests) -> bool:
	var id := normalize(value)
	if id == "":
		return false
	if id in ORIGINAL_IDS:
		return true
	if Campaign.from_state(state) != Campaign.EXPANDED or not Campaign.expansion_completed(quests):
		return false
	if id == "share":
		return has_keeper_consent(state)
	return _true_flag(state, "community_route_ready") and _true_flag(state, "community_refuge_ready")

static func record_keeper_consent(state, actor: String, accepted: bool) -> bool:
	# Call only from an authored participant interaction. Relationship scores,
	# documents, and other actors cannot manufacture another person's consent.
	if state == null or Campaign.from_state(state) != Campaign.EXPANDED:
		return false
	# The locked original acceptance remains in final_keeper_consent. Continuing
	# obligations may be released or freely renewed after Concord is enacted.
	var continuing := str(state.get_flag("final_covenant",""))=="concord" and _true_flag(state,"final_choice_completed")
	if not continuing and (str(state.get_flag("final_covenant", "")) != "" or _true_flag(state, "final_choice_completed")):
		return false
	var recognized := false
	for group: Array in CONSENT_GROUPS:
		if actor in group:
			recognized = true
	if not recognized:
		return false
	var raw: Variant = state.get_flag(CONSENT_FLAG, {})
	var consent: Dictionary = raw.duplicate(true) if raw is Dictionary else {}
	consent[actor] = accepted
	state.set_flag(CONSENT_FLAG, consent)
	return true

static func keeper_group_covered(state, group: int) -> bool:
	if group<0 or group>=CONSENT_GROUPS.size(): return false
	var raw: Variant=state.get_flag(CONSENT_FLAG,{})
	if not raw is Dictionary: return false
	for id: String in CONSENT_GROUPS[group]:
		if typeof(raw.get(id))==TYPE_BOOL and raw[id]: return true
	return false

static func concord_route_closed(state) -> bool:
	return Campaign.from_state(state)==Campaign.EXPANDED and str(state.get_flag("final_covenant",""))=="concord" and _true_flag(state,"final_choice_completed") and not keeper_group_covered(state,1)

static func _true_flag(state, key: String) -> bool:
	var value: Variant = state.get_flag(key, false)
	return typeof(value) == TYPE_BOOL and value
