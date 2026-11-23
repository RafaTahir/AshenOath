extends RefCounted

static func metadata(id: String) -> Dictionary:
	if not OS.has_feature("web"):
		return {}
	var raw_metadata := str(JavaScriptBridge.eval(
		"JSON.stringify((window.__ashenOathPreloadedPacks || {})[%s] || null)" % JSON.stringify(id), true
	))
	var parsed: Variant = JSON.parse_string(raw_metadata)
	return parsed if parsed is Dictionary else {}

static func inspect(metadata: Dictionary, pack: Dictionary) -> Dictionary:
	var expected_hash := str(pack.get("sha256", "")).to_lower()
	var expected_bytes := int(pack.get("bytes", 0))
	if str(metadata.get("sha256", "")).to_lower() != expected_hash \
			or int(metadata.get("bytes", 0)) != expected_bytes \
			or str(metadata.get("version", "")) != str(pack.get("version", "")):
		return {"error": "The browser pack identity did not match this release"}
	var path := str(metadata.get("path", ""))
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": "The browser could not open the prepared pack"}
	var magic := file.get_buffer(4)
	var actual_bytes := file.get_length()
	file.close()
	if actual_bytes != expected_bytes or magic != PackedByteArray([71, 68, 80, 67]):
		return {"error": "The browser pack file was incomplete or invalid"}
	return {"error": "", "path": path, "bytes": actual_bytes}
