extends Node

signal changed
signal state_changed(changes: Dictionary)
signal honor_changed(entry: Dictionary)

const Honor = preload("res://scripts/story_honor.gd")

const VERSION := 2
const GREYFEN_DECISIONS := {
	"evidence_report": ["private", "public", "retained"],
	"iron_fate": ["memorial", "tools", "surrendered"]
}
const VALUE_LIMITS := {
	"anwen_trust": Vector2i(-3, 3),
	"greyfen_fear": Vector2i(0, 6),
	"hart_debt": Vector2i(-3, 6)
}
const RELATIONSHIP_KINDS := ["help", "promise", "kept", "broken", "refused", "friendship", "interest", "commitment", "boundary"]
const HELP_MEMORIES := {
	"cart_helped": {"id": "lr.rook.flour", "actor": "rook", "kind": "help", "text": "Kael carried the flour to the common kitchen and freed Rook's cart.", "acknowledgement": "That flour reached the kitchen. You made a useful sort of entrance."},
	"road_repaired": {"id": "lr.tor.drain", "actor": "tor", "kind": "help", "text": "Kael cleared the drain and helped Tor restore the kitchen road.", "acknowledgement": "The boards stayed dry in the rain. That was worth doing."},
	"opening_cup_delivered": {"id": "lr.anwen.water", "actor": "anwen", "kind": "help", "text": "Kael brought water to Anwen's injured traveler.", "acknowledgement": "You brought the water before asking what anyone owed you. I noticed."}
}

var world_reads = preload("res://scripts/world_read_scope.gd").new()
var _flags: Dictionary = {}
var flags: Dictionary:
	get:
		world_reads.read("flags")
		return _flags
	set(value):
		_flags = value
var _values: Dictionary = {"anwen_trust": 0, "greyfen_fear": 0, "hart_debt": 0}
var values: Dictionary:
	get:
		world_reads.read("values")
		return _values
	set(value):
		_values = value
var _evidence: Dictionary = {}
var evidence: Dictionary:
	get:
		world_reads.read("evidence")
		return _evidence
	set(value):
		_evidence = value
var _decisions: Array = []
var decisions: Array:
	get:
		world_reads.read("decisions", "all")
		return _decisions
	set(value):
		_decisions = value
var _change_depth := 0
var _change_pending := false
var _changed_keys: Dictionary = {}

func begin_change() -> void:
	_change_depth += 1

func end_change() -> void:
	_change_depth = maxi(0, _change_depth - 1)
	if _change_depth == 0 and _change_pending:
		_change_pending = false
		var changes := _changed_keys.duplicate(true)
		_changed_keys.clear()
		state_changed.emit(changes)
		changed.emit()

func _notify_change(bucket: String = "*", id: String = "*") -> void:
	if not _changed_keys.has(bucket): _changed_keys[bucket] = {}
	_changed_keys[bucket][id] = true
	if _change_depth > 0:
		_change_pending = true
	else:
		var changes := _changed_keys.duplicate(true)
		_changed_keys.clear()
		state_changed.emit(changes)
		changed.emit()

func set_flag(id: String, value: Variant) -> void:
	var previous: Variant = _flags.get(id)
	var confirmation_pending: bool = GREYFEN_DECISIONS.has(id) and str(value) in GREYFEN_DECISIONS[id] and bool(_flags.get(id + "_confirmation_needed", false))
	if _flags.has(id) and previous == value and not confirmation_pending:
		return
	begin_change()
	flags[id] = value
	if GREYFEN_DECISIONS.has(id) and str(value) in GREYFEN_DECISIONS[id]:
		flags[id + "_confirmation_needed"] = false
		if confirmation_pending: _notify_change("flags", id + "_confirmation_needed")
	if previous != value:
		_capture_relationship_flag(id, value)
		_capture_honor_flags(id)
	_notify_change("flags", id)
	end_change()

func get_flag(id: String, fallback: Variant = null) -> Variant:
	world_reads.read("flags", id)
	return _flags.get(id, fallback)

func record_honor_event(id: String, announce: bool = true) -> bool:
	if not Honor.DEEDS.has(id) or not Honor.satisfied(self, Honor.DEEDS[id]):
		return false
	var rule: Dictionary = Honor.DEEDS[id]
	var raw: Variant = flags.get("honor_ledger", {})
	var ledger: Dictionary = raw.duplicate(true) if raw is Dictionary else {}
	var group := str(rule.get("group", id))
	if int(rule.weight) > 0:
		for other_id: String in Honor.DEEDS:
			var other: Dictionary = Honor.DEEDS[other_id]
			if str(other.get("group", other_id)) == group and int(other.weight) < 0 and Honor.satisfied(self, other):
				return false
	var previous: Dictionary = ledger.get(group, {})
	# A harmful method supersedes its generic help; a later refresh cannot wash it away.
	if str(previous.get("id", "")) == id or (not previous.is_empty() and int(previous.get("weight", 0)) < 0):
		return false
	var before := int(honor_view().score)
	var entry: Dictionary = rule.duplicate(true)
	entry["id"] = id
	entry["sequence"] = int(previous.get("sequence", ledger.size() + 1))
	ledger[group] = entry
	flags["honor_ledger"] = ledger
	_notify_change("flags", "honor_ledger")
	if announce:
		var notification := entry.duplicate(true)
		notification["delta"] = int(honor_view().score) - before
		honor_changed.emit(notification)
	return true

func _capture_honor_flags(changed_flag: String = "", announce: bool = true) -> void:
	for id: String in Honor.DEEDS:
		var rule: Dictionary = Honor.DEEDS[id]
		if changed_flag == "" or str(rule.flag) == changed_flag or rule.get("requires", {}).has(changed_flag):
			record_honor_event(id, announce)

func honor_view(actor_id: String = "") -> Dictionary:
	var score := 0
	var deeds: Array[Dictionary] = []
	var grievance := false
	var actor := Honor.actor_key(actor_id)
	var raw: Variant = get_flag("honor_ledger", {})
	if raw is Dictionary:
		for entry: Variant in raw.values():
			if not entry is Dictionary or not Honor.DEEDS.has(str(entry.get("id", ""))):
				continue
			var canonical: Dictionary = Honor.DEEDS[str(entry.id)]
			if actor != "" and actor not in canonical.get("known", []):
				continue
			score += int(canonical.weight)
			grievance = grievance or actor in canonical.get("grievance", [])
			deeds.append({"id":str(entry.id), "text":str(canonical.text), "weight":int(canonical.weight), "sequence":int(entry.get("sequence", 0))})
	deeds.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.sequence) < int(b.sequence))
	score = clampi(score, -100, 100)
	return {"score":score, "band":Honor.band(score), "deeds":deeds, "known":not deeds.is_empty(), "grievance":grievance, "reaction":"I remember what you did to us. Good work elsewhere does not settle that." if grievance else ("I have seen you keep your word. I will hear you out; the answer is still mine." if score >= 10 else ("I will check the account myself before I agree to anything." if score <= -10 else "I can speak to what I have seen, not everything said about you."))}

func world_signature_state(zone_id: String) -> Dictionary:
	return world_reads.snapshot(zone_id, {"flags": _flags, "values": _values, "evidence": _evidence, "decisions": {"all": _decisions}})

func adjust_value(id: String, amount: int) -> int:
	var limit: Vector2i = VALUE_LIMITS.get(id, Vector2i(-999, 999))
	var next := clampi(int(values.get(id, 0)) + amount, limit.x, limit.y)
	if values.has(id) and int(values[id]) == next: return next
	values[id] = next
	_notify_change("values", id)
	return int(values[id])

func record_evidence(id: String, entry: Dictionary = {}) -> void:
	if id == "" or evidence.has(id):
		return
	evidence[id] = entry.duplicate(true)
	_notify_change("evidence", id)

func has_evidence(id: String) -> bool:
	world_reads.read("evidence", id)
	return _evidence.has(id)

func companion_events() -> Dictionary:
	var saved: Variant = get_flag("bracken_bond_events", {})
	return saved.duplicate(true) if saved is Dictionary else {}

func remember_companion_event(id: String, zone: String) -> bool:
	if id not in ["rescue", "return_home", "survived_danger", "rest_after_testimony"]:
		return false
	var events := companion_events()
	if events.has(id):
		return false
	events[id] = {"zone": zone, "sequence": events.size() + 1}
	set_flag("bracken_bond_events", events)
	return true

func companion_response() -> String:
	var events := companion_events()
	if events.has("rest_after_testimony"):
		return "Bracken rests his chin against Kael's hand. He asks for none of the words the day has cost."
	if events.has("return_home"):
		return "Bracken checks the road, then looks back at Kael. He knows now that leaving can end in coming home."
	if events.has("survived_danger"):
		return "At the sound of Kael's step, Bracken leaves his shelter. He keeps closer on this stretch of road."
	return "Bracken approaches the hand that freed him, slowly enough to change his mind."

func has_heard_testimony() -> bool:
	if bool(get_flag("mira_truth_known", false)) or bool(get_flag("senn_ready_to_testify", false)):
		return true
	for entry: Variant in evidence.values():
		if entry is Dictionary and str(entry.get("kind", "")) == "testimony":
			return true
	return false

func relationship_events(actor_id: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var stored: Variant = get_flag("living_road_relationships", {})
	if not stored is Dictionary:
		return result
	for raw: Variant in stored.values():
		if raw is Dictionary and str(raw.get("kind", "")) in RELATIONSHIP_KINDS and str(raw.get("id", "")).begins_with("lr.") and (actor_id == "" or str(raw.get("actor", "")) == actor_id):
			result.append(raw.duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("sequence", 0)) < int(b.get("sequence", 0)))
	return result

func record_relationship_event(entry: Dictionary) -> bool:
	var id := str(entry.get("id", ""))
	var actor := str(entry.get("actor", ""))
	var kind := str(entry.get("kind", ""))
	var words := str(entry.get("text", "")).strip_edges()
	if not id.begins_with("lr.") or actor == "" or kind not in RELATIONSHIP_KINDS or words == "":
		return false
	var raw: Variant = flags.get("living_road_relationships", {})
	var stored: Dictionary = raw.duplicate(true) if raw is Dictionary else {}
	if stored.has(id):
		return false
	stored[id] = {"id": id, "actor": actor, "kind": kind, "text": words, "acknowledgement": str(entry.get("acknowledgement", "")), "promise_id": str(entry.get("promise_id", "")), "sequence": stored.size() + 1}
	flags["living_road_relationships"] = stored
	_notify_change()
	return true

func record_relationship_choice(action: Dictionary) -> void:
	var raw: Variant = action.get("relationship_event", {})
	if raw is Dictionary and not raw.is_empty():
		record_relationship_event(raw)

func relationship_acknowledgement(actor_id: String) -> String:
	var events := relationship_events(actor_id)
	for index in range(events.size() - 1, -1, -1):
		var words := str(events[index].get("acknowledgement", ""))
		if words != "":
			return words
	return ""

func commitment_partner() -> String:
	var partner := str(get_flag("lr_commitment_partner", ""))
	return partner if partner in ["mira", "vale"] else ""

func consume_relationship_greeting(actor_id: String) -> String:
	var events := relationship_events(actor_id)
	if events.is_empty():
		return ""
	var event: Dictionary = events.back()
	var words := str(event.get("acknowledgement", ""))
	var heard: Variant = flags.get("living_road_greetings", {})
	var id := str(event.get("id", ""))
	if words == "" or heard is Dictionary and str(heard.get(actor_id, "")) == id:
		return ""
	var updated: Dictionary = heard.duplicate() if heard is Dictionary else {}
	updated[actor_id] = id
	flags["living_road_greetings"] = updated
	_notify_change()
	return words

func commitment_allows(action: Dictionary) -> bool:
	var change := str(action.get("relationship_change", ""))
	if change == "":
		return true
	var actor := str(action.get("relationship_actor", ""))
	if actor not in ["mira", "vale"]:
		return false
	if change == "commit":
		if commitment_partner() != "" or str(get_flag("lr_" + actor + "_personal", "")) != "interest" or get_flag("lr_" + actor + "_commitment_answer", null) != null:
			return false
		if actor == "mira":
			return str(get_flag("lr_mira_truth_talk", "")) == "agreed" or str(get_flag("lr_mira_reconciled", "")) == "acknowledged"
		return bool(get_flag("vargan_ledger_choice_made", false)) and str(get_flag("lr_vale_terms", "")) in ["respected", "reconsidered"]
	if change == "end":
		return commitment_partner() == actor
	return false

func apply_commitment(action: Dictionary) -> bool:
	if not commitment_allows(action):
		return false
	var change := str(action.get("relationship_change", ""))
	if change != "":
		set_flag("lr_commitment_partner", str(action.relationship_actor) if change == "commit" else "")
	return true

func _capture_relationship_flag(id: String, value: Variant) -> void:
	if HELP_MEMORIES.has(id) and value is bool and value:
		record_relationship_event(HELP_MEMORIES[id])
	if id == "lr_rook_privacy" and str(value) in ["promised", "declined"]:
		var promised := str(value) == "promised"
		record_relationship_event({"id": "lr.rook.privacy." + str(value), "actor": "rook", "kind": "promise" if promised else "refused", "promise_id": "rook_family_privacy", "text": "Kael promised not to publish Rook's family mark." if promised else "Kael declined to promise secrecy about Rook's family mark.", "acknowledgement": "You said the family mark would stay off the board. I am trusting the words, not buying protection." if promised else "You would not promise secrecy. At least I know what I have not been promised."})
	if id == "rook_disclosure" and str(get_flag("lr_rook_privacy", "")) == "promised" and str(value) in ["public", "protected", "erased"]:
		var kept := str(value) != "public"
		var explanation := "Kael withheld the family mark from publication." if kept else "Kael published the family mark after promising to keep it private."
		if str(value) == "erased":
			explanation += " Destroying the map also lost a route others could have used; privacy is not absolution."
		record_relationship_event({"id": "lr.rook.privacy." + ("kept" if kept else "broken"), "actor": "rook", "kind": "kept" if kept else "broken", "promise_id": "rook_family_privacy", "text": explanation, "acknowledgement": "You kept the mark off the board, as you said. We still have to answer for what happened to the map." if kept else "You promised to keep my family's mark private. Now a guard can follow it to their door."})
	if id.begins_with("witness_consent_") and str(value) == "refused":
		var actor := id.trim_prefix("witness_consent_")
		record_relationship_event({"id": "lr." + actor + ".witness_refused", "actor": actor, "kind": "boundary", "text": "This person declined to take part as a witness. Neither help nor a surviving record reverses that refusal."})

func record_decision(id: String, action: Dictionary) -> void:
	if id == "":
		return
	for previous in decisions:
		if str(previous.get("id", "")) == id:
			return
	decisions.append({
		"id": id, "label": str(action.get("label", "A promise made")),
		"result": str(action.get("result", "")),
		"flags": action.get("sets_flags", {}).duplicate(true),
		"sequence": decisions.size() + 1
	})
	_notify_change()

func matches(conditions: Dictionary) -> bool:
	for id in conditions:
		var expected: Variant = conditions[id]
		if id in VALUE_LIMITS:
			var actual := int(values.get(id, 0))
			if expected is Dictionary:
				if expected.has("min") and actual < int(expected["min"]): return false
				if expected.has("max") and actual > int(expected["max"]): return false
			elif actual != int(expected): return false
		elif flags.get(id, false if expected is bool else null) != expected:
			return false
	return true

func save_state() -> Dictionary:
	return {"version": VERSION, "flags": flags.duplicate(true), "values": values.duplicate(true), "evidence": evidence.duplicate(true), "decisions": decisions.duplicate(true)}

func _repair_greyfen_prop_choices() -> void:
	for key: String in GREYFEN_DECISIONS:
		var value := str(_flags.get(key, ""))
		if value == "" or value in GREYFEN_DECISIONS[key]:
			continue
		_flags["greyfen_prop_recovered:" + key] = value
		_flags.erase(key)
		# A decorative 'used' state is not evidence of the player's decision.
		for index in range(decisions.size() - 1, -1, -1):
			var recorded: Variant = decisions[index].get("flags", {})
			if recorded is Dictionary and str(recorded.get(key, "")) in GREYFEN_DECISIONS[key]:
				_flags[key] = str(recorded[key])
				break
		_flags[key + "_confirmation_needed"] = not _flags.has(key)

func confirm_greyfen_choice(key: String, value: String) -> bool:
	if not GREYFEN_DECISIONS.has(key) or value not in GREYFEN_DECISIONS[key] or not bool(_flags.get(key + "_confirmation_needed", false)):
		return false
	# Recovery restores a recollection, not a new reward, deed or relationship.
	_flags[key] = value
	_flags[key + "_confirmation_needed"] = false
	record_decision("greyfen_restore:" + key, {"label":"Confirmed the surviving account", "sets_flags":{key:value}})
	_notify_change()
	return true

func load_state(data: Dictionary) -> void:
	_change_depth = 0
	_change_pending = false
	_changed_keys.clear()
	var loaded_evidence: Variant = data.get("evidence", {})
	evidence = loaded_evidence.duplicate(true) if loaded_evidence is Dictionary else {}
	decisions = []
	var loaded_decisions: Variant = data.get("decisions", [])
	if loaded_decisions is Array:
		for decision in loaded_decisions:
			if decision is Dictionary and str(decision.get("id", "")) != "":
				decisions.append(decision.duplicate(true))
	var loaded_flags: Variant = data.get("flags", {})
	flags = loaded_flags.duplicate(true) if typeof(loaded_flags) == TYPE_DICTIONARY else {}
	_repair_greyfen_prop_choices()
	var loaded_values_raw: Variant = data.get("values", {})
	var loaded: Dictionary = loaded_values_raw if typeof(loaded_values_raw) == TYPE_DICTIONARY else {}
	values = {"anwen_trust": 0, "greyfen_fear": 0, "hart_debt": 0}
	for id in loaded:
		if typeof(loaded[id]) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(loaded[id])):
			continue
		var limit: Vector2i = VALUE_LIMITS.get(id, Vector2i(-999, 999))
		values[id] = clampi(int(loaded[id]), limit.x, limit.y)
	# Only explicit recorded deeds migrate. Refusal, endings and missing work are neutral.
	begin_change()
	_capture_honor_flags("", false)
	_change_pending = false
	end_change()
	_changed_keys.clear()
	state_changed.emit({"*":{"*":true}})
	changed.emit()
