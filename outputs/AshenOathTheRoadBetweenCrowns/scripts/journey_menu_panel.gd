extends RefCounted

static func status_text(status: String) -> String:
	return str({"empty":"Empty", "ready":"Ready", "recoverable":"Previous copy available", "unavailable":"Unavailable", "newer_version":"Created by a newer version"}.get(status, "Unavailable"))

static func card(model: Dictionary, current: bool = false) -> String:
	var summary: Dictionary = model if current else model.get("summary", {})
	var lines: Array[String] = []
	if current:
		lines.append(str(summary.get("heading", "On this journey")))
	else:
		lines.append(str(summary.get("title", "Saved journey")))
		var source_label: String = str(model.get("source_label", ""))
		if source_label != "" and source_label != str(summary.get("title", "")):
			lines.append(source_label)
		lines.append(status_text(str(model.get("status", "unavailable"))))
		if bool(summary.get("replay", false)):
			lines.append("Chapter replay")
	var place: String = str(summary.get("place", ""))
	var chapter: String = str(summary.get("chapter", ""))
	if place != "" or chapter != "":
		lines.append(" · ".join(PackedStringArray([place, chapter])) if place != "" and chapter != "" else place + chapter)
	if not current:
		lines.append(str(summary.get("time_label", "Saved time unavailable")))
		_append(lines, "World time", str(summary.get("world_clock_label", "")))
	_append(lines, "Promise", str(summary.get("promise", "")))
	_append(lines, "Last commitment", str(summary.get("last_commitment", "")))
	_append(lines, "Next known step", str(summary.get("next_action", "")))
	_append(lines, "Where", str(summary.get("destination_name", "")))
	for raw: Variant in summary.get("resource_lines", []):
		if str(raw) != "":
			lines.append(str(raw))
	if not current:
		_append(lines, "", str(model.get("reason", "")))
	return "\n".join(lines)

static func slot_row(slot: Dictionary) -> String:
	var summary: Dictionary = slot.get("summary", {})
	var lines: Array[String] = [str(slot.get("title", summary.get("title", "Journey")))]
	var source_label: String = str(slot.get("source_label", ""))
	if source_label != "" and source_label != str(slot.get("title", "")):
		lines.append(source_label)
	lines.append(status_text(str(slot.get("status", "ready" if bool(slot.get("valid", false)) else "empty"))))
	var place: String = str(summary.get("place", slot.get("zone", "")))
	var chapter: String = str(summary.get("chapter", ""))
	if place != "" or chapter != "":
		lines.append(place + (" · " if place != "" and chapter != "" else "") + chapter)
	if not summary.is_empty():
		lines.append(str(summary.get("time_label", "Saved time unavailable")))
		var next: String = str(summary.get("next_action", ""))
		if next != "":
			lines.append("Next: " + (next.left(117) + "…" if next.length() > 120 else next))
	if bool(summary.get("replay", slot.get("replay", false))):
		lines.append("Replay journey")
	return "\n".join(lines)

static func load_label(model: Dictionary, recovery: bool = false) -> String:
	if str(model.get("status", "")) == "recoverable":
		return "Load the Previous Copy" if recovery else "Continue from Previous Copy"
	if recovery:
		var summary: Dictionary = model.get("summary", {})
		return "Load " + str(summary.get("title", "Recorded Journey"))
	return "Continue"

static func _append(lines: Array[String], label: String, value: String) -> void:
	if value.strip_edges() != "":
		lines.append("\n" + (label + ": " if label != "" else "") + value)
