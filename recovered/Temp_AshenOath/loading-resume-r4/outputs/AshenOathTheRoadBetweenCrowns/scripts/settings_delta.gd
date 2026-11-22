extends RefCounted

static func changed(cache: Dictionary, group: String, target: Object, current: Dictionary, keys: Array) -> bool:
	if not is_instance_valid(target):
		return false
	var values: Dictionary = {}
	for key in keys:
		values[key] = current.get(key)
	var previous: Dictionary = cache.get(group, {})
	if previous.get("target") != null and previous.target.get_ref() == target and previous.get("values") == values:
		return false
	cache[group] = {"target": weakref(target), "values": values.duplicate(true)}
	return true
