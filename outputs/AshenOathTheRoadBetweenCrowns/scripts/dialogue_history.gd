extends RefCounted

const CAPACITY := 400
var entries: Array[Dictionary] = []

func record(speaker: String, text: String, kind: String = "speech", source_id: String = "") -> void:
	text = text.strip_edges()
	if text.is_empty():
		return
	if not entries.is_empty() and str(entries.back().get("speaker", "")) == speaker and str(entries.back().get("text", "")) == text:
		return
	entries.append({"speaker": speaker.left(100), "text": text.left(12000), "kind": kind, "source_id": source_id.left(200)})
	while entries.size() > CAPACITY:
		entries.pop_front()

func save_state() -> Array:
	return entries.duplicate(true)

func load_state(raw: Variant) -> void:
	entries.clear()
	if typeof(raw) != TYPE_ARRAY:
		return
	for value in raw.slice(maxi(0, raw.size() - CAPACITY)):
		if typeof(value) == TYPE_DICTIONARY and typeof(value.get("text")) == TYPE_STRING:
			record(str(value.get("speaker", "")), str(value.text), str(value.get("kind", "speech")), str(value.get("source_id", "")))

func text() -> String:
	var result := PackedStringArray()
	for entry in entries:
		result.append("%s\n%s" % [str(entry.get("speaker", "The road")), str(entry.get("text", ""))])
	return "\n\n".join(result) if not result.is_empty() else "Conversations and the choices you commit to will appear here."
