extends RefCounted

const CAPACITY := 12
const PRIORITY := {"error": 100, "unavailable": 90, "story": 70, "inventory": 40, "info": 30, "save": 20, "combat": 10}
var pending: Array[Dictionary] = []
var sequence := 0

func push(text: String, category: String, duration: float, dedupe_key: String) -> void:
	text = text.strip_edges()
	if text.is_empty():
		return
	category = category if PRIORITY.has(category) else "info"
	var key := dedupe_key if dedupe_key != "" else category + ":" + text
	for index in range(pending.size() - 1, -1, -1):
		if str(pending[index].key) == key:
			pending.remove_at(index)
	sequence += 1
	pending.append({"text": text, "category": category, "duration": clampf(duration, 2.2, 12.0), "key": key, "priority": int(PRIORITY[category]), "sequence": sequence, "expires": Time.get_ticks_msec() + (2500 if category == "combat" else 180000)})
	pending.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.priority) > int(b.priority) if int(a.priority) != int(b.priority) else int(a.sequence) < int(b.sequence))
	while pending.size() > CAPACITY:
		pending.pop_back()

func take(dialogue_open: bool, suppressed: bool, menu_open: bool = false) -> Dictionary:
	var now := Time.get_ticks_msec()
	for index in range(pending.size() - 1, -1, -1):
		if int(pending[index].expires) < now:
			pending.remove_at(index)
	for index in range(pending.size()):
		var notice := pending[index]
		if menu_open and str(notice.category) == "combat":
			continue
		if dialogue_open or (suppressed and str(notice.category) not in ["error", "unavailable"]):
			continue
		pending.remove_at(index)
		return notice
	return {}

func has_pending() -> bool:
	return not pending.is_empty()

func priority(category: String) -> int:
	return int(PRIORITY.get(category, 30))
