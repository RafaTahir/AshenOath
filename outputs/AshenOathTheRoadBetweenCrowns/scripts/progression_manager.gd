extends Node

signal changed
signal message(text: String)

const DEFINITIONS_PATH := "res://data/upgrades.json"
const RULES_PATH := "res://data/progression.json"
const BRANCH_ORDER := ["blade", "survival", "oathfire", "hunter"]
const MASTERY_MARK_LIMIT := 12
const STATE_VERSION := 1

var definitions: Dictionary = {}
var rules: Dictionary = {}
var marks := 0
var unlocked: Dictionary = {}
var rewarded_quests: Dictionary = {}
var total_xp := 0
var issued_marks := 0
var claimed_rewards: Dictionary = {}
var visited_sectors: Dictionary = {}

func _ready() -> void:
	load_definitions()

func load_definitions() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DEFINITIONS_PATH))
	definitions = parsed if parsed is Dictionary else {}
	parsed = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
	rules = parsed if parsed is Dictionary else {}

func level_cap() -> int:
	return int(rules.get("level_cap", 20))

func xp_for_level(level: int) -> int:
	var steps := clampi(level, 1, level_cap()) - 1
	return steps * int(rules.get("first_level_xp", 200)) + int(float(steps * (steps - 1)) * 0.5) * int(rules.get("level_step_xp", 50))

func get_level() -> int:
	var level := 1
	while level < level_cap() and total_xp >= xp_for_level(level + 1):
		level += 1
	return level

func _marks_at_level(level: int) -> int:
	var count := 0
	for milestone: Variant in rules.get("mark_levels", []):
		if level >= int(milestone):
			count += 1
	return mini(count, MASTERY_MARK_LIMIT)

func _reconcile_marks() -> void:
	# Previously issued Marks are a floor, not another grant of the same milestones.
	issued_marks = maxi(issued_marks, _marks_at_level(get_level()))
	marks = maxi(0, issued_marks - _learned_count())

func region_for(zone_id: String) -> String:
	for region: String in rules.get("regions", {}):
		if zone_id in rules.regions[region].get("sectors", []):
			return region
	return ""

func _claim(id: String, amount: int, region: String, kind: String, label: String) -> bool:
	if id.is_empty() or amount <= 0 or claimed_rewards.has(id):
		return false
	var credited := mini(amount, maxi(0, xp_for_level(level_cap()) - total_xp))
	claimed_rewards[id] = {"xp": credited, "region": region, "kind": kind, "label": label}
	total_xp += credited
	_reconcile_marks()
	return true

func _announce(previous_xp: int, previous_level: int, previous_marks: int, label: String, quiet: bool) -> void:
	changed.emit()
	if quiet or total_xp == previous_xp:
		return
	var text := "+%d XP - %s" % [total_xp - previous_xp, label]
	if get_level() > previous_level:
		text += ". Level %d reached" % get_level()
	if marks > previous_marks:
		text += ". %d Oath Mark%s earned" % [marks - previous_marks, "" if marks - previous_marks == 1 else "s"]
	message.emit(text + ".")

func award_for_quest(quest_id: String, _quest_type: String = "", quiet := false) -> bool:
	var reward: Dictionary = rules.get("quests", {}).get(quest_id, {})
	if reward.is_empty():
		return false
	var before := total_xp
	var level := get_level()
	var available := marks
	if not _claim("quest:" + quest_id, int(reward.xp), str(reward.region), "quest", quest_id):
		return false
	rewarded_quests[quest_id] = true
	_announce(before, level, available, "Quest completed", quiet)
	return true

func reconcile_completed_quests(_quest_definitions: Dictionary, completed_quests: Dictionary) -> int:
	var count := 0
	for id: String in completed_quests:
		if _saved_true(completed_quests[id]) and award_for_quest(id, "", true):
			count += 1
	return count

func record_arrival(zone_id: String, quests, state, quiet := false) -> void:
	var region := region_for(zone_id)
	if region.is_empty():
		return
	var before := total_xp
	var level := get_level()
	var available := marks
	visited_sectors[zone_id] = true
	var updated := _claim("arrival:" + zone_id, int(rules.get("arrival_xp", 100)), region, "arrival", zone_id.replace("_", " ").capitalize())
	updated = _claim_returns(zone_id, quests, state) or updated
	if updated:
		_announce(before, level, available, "The road through " + str(rules.regions[region].name), quiet)

func sync_story(quests, state, zone_id: String, quiet := false) -> void:
	var before := total_xp
	var level := get_level()
	var available := marks
	var updated := false
	for id: String in rules.get("bosses", {}):
		var boss: Dictionary = rules.bosses[id]
		for flag: String in boss.get("flags", []):
			var value: Variant = state.get_flag(flag)
			if _saved_true(value) or (value is String and not value.is_empty() and value not in ["unresolved", "none", "active", "legacy_retired"]):
				updated = _claim("boss:" + id, int(boss.xp), str(boss.region), "encounter", str(boss.name)) or updated
				break
	for id: String in state.evidence:
		var entry: Variant = state.evidence[id]
		if not entry is Dictionary:
			continue
		var region := region_for(str(entry.get("zone", zone_id)))
		if not region.is_empty():
			updated = _claim("discovery:" + id, int(rules.get("discovery_xp", 50)), region, "discovery", str(entry.get("title", id))) or updated
	for key: String in quests.evidence_history:
		if not _saved_true(quests.evidence_history[key]):
			continue
		var quest_id := key.get_slice(":", 0)
		var region := str(rules.get("quests", {}).get(quest_id, {}).get("region", "")) if quiet else region_for(zone_id)
		if not region.is_empty():
			updated = _claim("evidence:" + key, int(rules.get("discovery_xp", 50)), region, "discovery", key.get_slice(":", 1).replace("_", " ").capitalize()) or updated
	updated = _claim_returns(zone_id, quests, state) or updated
	if updated:
		_announce(before, level, available, "Discovery and deeds", quiet)

func _claim_returns(zone_id: String, quests, state) -> bool:
	var updated := false
	for reward: Dictionary in rules.get("returns", []):
		if str(reward.zone) != zone_id or not visited_sectors.has(zone_id):
			continue
		var quest_id := str(reward.get("quest", ""))
		var flag := str(reward.get("flag", ""))
		if (quest_id != "" and not quests.is_completed(quest_id)) or (flag != "" and not _saved_true(state.get_flag(flag, false))):
			continue
		updated = _claim("return:" + str(reward.id), int(reward.xp), region_for(zone_id), "return", str(reward.name)) or updated
	return updated

func award_encounter(reward_id: String, zone_id: String, label: String) -> bool:
	var region := region_for(zone_id)
	if region.is_empty():
		return false
	var before := total_xp
	var level := get_level()
	var available := marks
	if not _claim("encounter:" + zone_id + ":" + reward_id, int(rules.get("encounter_xp", 75)), region, "encounter", label):
		return false
	_announce(before, level, available, label, false)
	return true

func restore_journey(quests, state, zone_id: String, discovered: Dictionary) -> void:
	# Migrate recorded history only, without inventing kills or replaying notices.
	reconcile_completed_quests(quests.quest_defs, quests.completed)
	for sector: String in discovered:
		if _saved_true(discovered[sector]) and not region_for(sector).is_empty():
			visited_sectors[sector] = true
	if not region_for(zone_id).is_empty():
		visited_sectors[zone_id] = true
	for sector: String in visited_sectors.keys():
		_claim("arrival:" + sector, int(rules.get("arrival_xp", 100)), region_for(sector), "arrival", sector.replace("_", " ").capitalize())
	for id: String in state.evidence:
		var entry: Variant = state.evidence[id]
		if entry is Dictionary and not entry.has("zone") and not claimed_rewards.has("discovery:" + id):
			# Do not assign older unlocated accounts to the current load location.
			claimed_rewards["discovery:" + id] = {"xp": 0, "region": "", "kind": "discovery", "label": str(entry.get("title", id))}
	sync_story(quests, state, zone_id, true)
	changed.emit()

func can_unlock(id: String) -> bool:
	return bool(upgrade_status(id).get("available", false))

func upgrade_status(id: String) -> Dictionary:
	var definition: Dictionary = definitions.get(id, {})
	var required := str(definition.get("requires", ""))
	var required_name := str(definitions.get(required, {}).get("name", required))
	var learned := has_upgrade(id)
	var reason := ""
	if definition.is_empty():
		reason = "This practice is unavailable."
	elif learned:
		reason = "You have already learned this practice."
	elif required != "" and not has_upgrade(required):
		reason = "Learn %s first." % required_name
	elif marks < 1:
		reason = "Earn an Oath Mark at the next marked level."
	var available := reason == ""
	return {"id": id, "title": str(definition.get("name", id)), "body": str(definition.get("description", "")), "branch": str(definition.get("branch", "")), "learned": learned, "available": available, "reason": reason, "cost": 1, "marks_after": marks - 1 if available else marks, "prerequisite_id": required, "prerequisite_name": required_name}

func unlock(id: String) -> bool:
	var result := unlock_result(id)
	message.emit(str(result.get("message", "")))
	return bool(result.get("ok", false))

func unlock_result(id: String) -> Dictionary:
	var status := upgrade_status(id)
	if not bool(status.get("available", false)):
		return {"ok": false, "operation": "learn", "item_id": id, "quantity": 0, "reason": str(status.reason), "message": str(status.reason)}
	unlocked[id] = true
	marks -= 1
	changed.emit()
	return {"ok": true, "operation": "learn", "item_id": id, "quantity": 1, "spent": {"marks": 1}, "remaining": {"marks": marks}, "reason": "", "message": "%s learned. %d Oath Marks remain." % [str(status.title), marks]}

func respec_result() -> Dictionary:
	var refunded := _learned_count()
	if refunded == 0:
		return {"ok": false, "operation": "respec", "message": "No learned practices to redistribute."}
	unlocked.clear()
	_reconcile_marks()
	changed.emit()
	return {"ok": true, "operation": "respec", "message": "%d Oath Marks returned. Your XP, journey and equipment are unchanged." % refunded}

func has_upgrade(id: String) -> bool:
	return bool(unlocked.get(id, false))

func effect_value(effect_id: String, fallback: float = 0.0) -> float:
	for id: String in unlocked:
		var effects: Dictionary = definitions.get(id, {}).get("effects", {})
		if has_upgrade(id) and effects.has(effect_id):
			return float(effects[effect_id])
	return fallback

func ordered_upgrade_ids() -> Array[String]:
	var result: Array[String] = []
	for branch: String in BRANCH_ORDER:
		for tier in range(1, 4):
			for id: String in definitions:
				var definition: Dictionary = definitions[id]
				if str(definition.get("branch", "")) == branch and int(definition.get("tier", 0)) == tier:
					result.append(id)
	return result

func progress_model() -> Dictionary:
	var level := get_level()
	var floor_xp := xp_for_level(level)
	var next_xp := xp_for_level(level + 1) if level < level_cap() else floor_xp
	var next_mark := 0
	for milestone: Variant in rules.get("mark_levels", []):
		if _marks_at_level(int(milestone)) > issued_marks:
			next_mark = int(milestone)
			break
	return {"level": level, "cap": level_cap(), "xp": total_xp, "current": total_xp - floor_xp, "needed": next_xp - floor_xp, "marks": marks, "learned": _learned_count(), "next_mark_level": next_mark}

func get_summary_text() -> String:
	var model := progress_model()
	var text := "LEVEL %d / %d | %d XP\n" % [int(model.level), int(model.cap), total_xp]
	text += "%d / %d XP to the next level.\n" % [int(model.current), int(model.needed)] if int(model.needed) > 0 else "Campaign level cap reached.\n"
	text += "OATH MARKS: %d | PRACTICES: %d / %d\n" % [marks, _learned_count(), MASTERY_MARK_LIMIT]
	if int(model.next_mark_level) > 0:
		text += "Next Oath Mark: level %d.\n" % int(model.next_mark_level)
	text += "\nREGIONAL RECORD\n"
	for region: String in rules.get("regions", {}):
		var record: Dictionary = rules.regions[region]
		var sectors := 0
		var earned := 0
		var deeds := 0
		var returns := 0
		for sector: String in record.sectors:
			if visited_sectors.has(sector):
				sectors += 1
		for reward: Dictionary in claimed_rewards.values():
			if str(reward.get("region", "")) == region:
				earned += int(reward.get("xp", 0))
				deeds += 1
				if str(reward.get("kind", "")) == "return":
					returns += 1
		text += "\n%s\n%d / %d places visited | %d XP | %d deeds | %d meaningful returns\n" % [str(record.name), sectors, record.sectors.size(), earned, deeds, returns]
	text += "\nFirst arrivals, discoveries, resolved encounters and new return milestones grant XP once. Ordinary revisits do not. All regions grow the same permanent level.\n\nMarks are earned at even levels and levels 5 and 15. Learn practices in Preparation. Redistribute them freely at Greyfen's shrine bench outside combat."
	return text

func save_state() -> Dictionary:
	return {"progression_version": STATE_VERSION, "xp": total_xp, "issued_marks": issued_marks, "marks": marks, "unlocked": unlocked.duplicate(true), "rewarded_quests": rewarded_quests.duplicate(true), "claimed_rewards": claimed_rewards.duplicate(true), "visited_sectors": visited_sectors.duplicate(true)}

func load_state(state: Dictionary) -> void:
	if definitions.is_empty() or rules.is_empty():
		load_definitions()
	total_xp = _saved_int(state.get("xp", 0), xp_for_level(level_cap()))
	unlocked.clear()
	var loaded: Dictionary = state.get("unlocked", {}) if state.get("unlocked", {}) is Dictionary else {}
	for id: String in ordered_upgrade_ids():
		var required := str(definitions[id].get("requires", ""))
		if _saved_true(loaded.get(id, false)) and (required == "" or has_upgrade(required)):
			unlocked[id] = true
	issued_marks = maxi(_saved_int(state.get("issued_marks", 0), MASTERY_MARK_LIMIT), _learned_count() + _saved_int(state.get("marks", 0), MASTERY_MARK_LIMIT - _learned_count()))
	_reconcile_marks()
	rewarded_quests.clear()
	var rewards: Variant = state.get("rewarded_quests", {})
	if rewards is Dictionary:
		for id: Variant in rewards:
			if id is String and rules.get("quests", {}).has(id) and _saved_true(rewards[id]):
				rewarded_quests[id] = true
	claimed_rewards.clear()
	var claims: Variant = state.get("claimed_rewards", {})
	if claims is Dictionary:
		for id: Variant in claims:
			if not id is String or id.length() > 240 or not claims[id] is Dictionary or claimed_rewards.size() >= 4096:
				continue
			var reward: Dictionary = claims[id]
			claimed_rewards[id] = {"xp": _saved_int(reward.get("xp", 0), xp_for_level(level_cap())), "region": str(reward.get("region", "")), "kind": str(reward.get("kind", "")), "label": str(reward.get("label", "")).left(160)}
	visited_sectors.clear()
	var visits: Variant = state.get("visited_sectors", {})
	if visits is Dictionary:
		for sector: Variant in visits:
			if sector is String and not region_for(sector).is_empty() and _saved_true(visits[sector]):
				visited_sectors[sector] = true
	changed.emit()

func _learned_count() -> int:
	return unlocked.size()

func _saved_int(value: Variant, maximum: int) -> int:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) or float(value) != floorf(float(value)):
		return 0
	return int(clampf(float(value), 0.0, float(maximum)))

func _saved_true(value: Variant) -> bool:
	return typeof(value) == TYPE_BOOL and value == true
