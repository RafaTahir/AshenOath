extends RefCounted

## Builders declare dependencies by reading them. Direct dictionary access is
## deliberately conservative: it declares the entire bucket, never a partial one.
var capturing := ""
var zones: Dictionary = {}

func begin(zone_id: String, reset: bool = true) -> void:
	capturing = zone_id
	if reset or not zones.has(zone_id):
		zones[zone_id] = {}

func end() -> void:
	capturing = ""

func read(bucket: String, key: String = "*") -> void:
	if capturing.is_empty():
		return
	if not zones[capturing].has(bucket):
		zones[capturing][bucket] = {}
	zones[capturing][bucket][key] = true

func snapshot(zone_id: String, buckets: Dictionary) -> Dictionary:
	if not zones.has(zone_id):
		return buckets # First build has no observed dependency declaration yet.
	var result := {}
	for bucket in buckets:
		var selected: Dictionary = zones[zone_id].get(bucket, {})
		if selected.has("*"):
			result[bucket] = buckets[bucket]
		else:
			var values := {}
			for key in selected:
				# Keep absent distinct from present-null; default arguments may differ.
				values[key] = [buckets[bucket].has(key), buckets[bucket].get(key)]
			result[bucket] = values
	return result
