class_name CanonicalState
extends RefCounted

static func digest(value: Variant) -> String:
	var text: String = encode(value)
	return text.sha256_text() if not text.is_empty() else ""

static func encode(value: Variant) -> String:
	if not valid(value):
		return ""
	return JSON.stringify(_normalize(value), "", true, true)

static func valid(value: Variant, depth: int = 0) -> bool:
	if depth > 32:
		return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return true
		TYPE_FLOAT:
			return is_finite(value)
		TYPE_ARRAY:
			for entry: Variant in value:
				if not valid(entry, depth + 1):
					return false
			return true
		TYPE_DICTIONARY:
			for key: Variant in value:
				if not key is String or not valid(value[key], depth + 1):
					return false
			return true
	return false

static func _normalize(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key: String in value:
			result[key] = _normalize(value[key])
		return result
	if value is Array:
		var result: Array = []
		for entry: Variant in value:
			result.append(_normalize(entry))
		return result
	if typeof(value) == TYPE_FLOAT and absf(value) <= 9007199254740991.0 and value == floorf(value):
		return int(value)
	return value
