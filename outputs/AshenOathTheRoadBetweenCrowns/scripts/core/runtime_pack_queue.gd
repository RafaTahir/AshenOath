extends RefCounted

static func dependencies(id: String, packs: Dictionary, marks: Dictionary, order: Array[String]) -> String:
	if int(marks.get(id, 0)) == 1:
		return "Runtime pack dependency cycle at %s" % id
	if int(marks.get(id, 0)) == 2:
		return ""
	var pack: Variant = packs.get(id, {})
	if not pack is Dictionary or pack.is_empty():
		return "Unknown runtime pack dependency: %s" % id
	var required: Variant = pack.get("dependencies", [])
	if not required is Array:
		return "Invalid dependencies for %s" % id
	marks[id] = 1
	for dependency in required:
		if not dependency is String or str(dependency).strip_edges().to_lower() == "":
			return "Invalid dependency ID for %s" % id
		var failure := dependencies(str(dependency).strip_edges().to_lower(), packs, marks, order)
		if failure != "":
			return failure
	marks[id] = 2
	order.append(id)
	return ""

