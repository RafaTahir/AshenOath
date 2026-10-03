extends RefCounted

## Only reading positions and identifiers live here. Story content is always
## resolved again by the current journal; a return trail cannot retain a prior
## journey's evidence, known people, or conclusions.
const RETURN_CAPACITY := 8
const POSITION_CAPACITY := 40

var filter_id: String = "all"
var selected_id: String = ""
var _positions: Dictionary = {}
var _position_order: Array[String] = []
var _returns: Array[Dictionary] = []

func remember(position_key: String, state: Dictionary) -> void:
	if position_key.is_empty():
		return
	var scrolls: Dictionary = {}
	var raw_scrolls: Variant = state.get("scrolls", {})
	if raw_scrolls is Dictionary:
		for raw_key: Variant in raw_scrolls:
			var value: Variant = raw_scrolls[raw_key]
			if typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)):
				scrolls[str(raw_key)] = maxf(0.0, float(value))
	_positions[position_key] = {
		"focus": str(state.get("focus", "")),
		"index": maxi(0, int(state.get("index", 0))),
		"scrolls": scrolls
	}
	_position_order.erase(position_key)
	_position_order.append(position_key)
	while _position_order.size() > POSITION_CAPACITY:
		_positions.erase(_position_order.pop_front())

func position(position_key: String) -> Dictionary:
	var remembered: Dictionary = _positions.get(position_key, {})
	return remembered.duplicate(true)

func push_return(location: Dictionary) -> void:
	var section_id: String = str(location.get("section_id", ""))
	if section_id.is_empty():
		return
	_returns.append({
		"section_id": section_id,
		"entry_id": str(location.get("entry_id", "")),
		"filter_id": str(location.get("filter_id", "all")),
		"position_key": str(location.get("position_key", ""))
	})
	while _returns.size() > RETURN_CAPACITY:
		_returns.pop_front()

func pop_return() -> Dictionary:
	if _returns.is_empty():
		return {}
	var location: Dictionary = _returns.pop_back()
	return location.duplicate(true)

func has_return() -> bool:
	return not _returns.is_empty()

func clear_returns() -> void:
	_returns.clear()

func reset() -> void:
	filter_id = "all"
	selected_id = ""
	_positions.clear()
	_position_order.clear()
	_returns.clear()
