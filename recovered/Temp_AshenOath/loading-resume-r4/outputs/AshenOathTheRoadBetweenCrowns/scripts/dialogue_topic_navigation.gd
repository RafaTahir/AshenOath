extends RefCounted

# A single reading detour, never a second dialogue transaction stack.
var mode := "primary"
var primary: Dictionary = {}
var list_reading: Dictionary = {}
var requested_id := ""
var requested_revision := ""
var list_message := ""

func reset() -> void:
	mode = "primary"
	primary.clear()
	list_reading.clear()
	requested_id = ""
	requested_revision = ""
	list_message = ""

func remember_primary(session: Dictionary, pages: Array, page: int, reading: Dictionary, detail: Dictionary) -> void:
	primary = {"session":session.duplicate(true), "pages":pages.duplicate(true), "page":page, "reading":reading.duplicate(true), "detail":detail.duplicate(true)}
	list_reading.clear()
	list_message = ""

func context_id() -> String:
	var session: Dictionary = primary.get("session", {})
	return str(session.get("topic_context_id", ""))

func rows() -> Array:
	var session: Dictionary = primary.get("session", {})
	return session.get("optional_topics", [])

static func seen_keys(entries: Array) -> Array[String]:
	var keys: Array[String] = []
	for raw: Variant in entries:
		if not raw is Dictionary:
			continue
		var source: String = str(raw.get("source_id", ""))
		if not source.begins_with("conversation_topic:"):
			continue
		var separator: int = source.rfind(":page:")
		if separator < 0 or not source.substr(separator + 6).is_valid_int():
			continue
		var key: String = source.left(separator)
		if not keys.has(key):
			keys.append(key)
	return keys
