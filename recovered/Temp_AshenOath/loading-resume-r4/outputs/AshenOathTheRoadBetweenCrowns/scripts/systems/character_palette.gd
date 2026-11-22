extends RefCounted

const PATH := "res://data/palettes.json"
static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary and int(parsed.get("version", 0)) == 1:
			_data = parsed
		else:
			push_error("Character palette is missing or invalid: " + PATH)
	return _data

static func identity(role: String, seed: String = "") -> String:
	var catalog := data()
	var alias := str(catalog.get("aliases", {}).get(role, ""))
	if not alias.is_empty():
		return alias
	var words := " " + (role + " " + seed).to_lower().replace("_", " ").replace("-", " ") + " "
	for id: String in catalog.get("named", {}):
		if words.contains(" " + id + " "):
			return id
	return ""

static func for_actor(role: String, seed: String = "", zone_hint: String = "") -> Dictionary:
	var catalog := data()
	var id := identity(role, seed)
	var named: Dictionary = catalog.get("named", {}).get(id, {})
	var regions: Dictionary = catalog.get("zone_regions", {})
	var region := str(regions.get(zone_hint, zone_hint))
	if not catalog.get("regions", {}).has(region):
		region = str(named.get("region", ""))
	if region.is_empty():
		var words := role + " " + seed
		region = "greyfen"
		for zone: String in regions:
			if words.contains(zone):
				region = str(regions[zone])
				break
		if role.contains("guard") or role.contains("vargan"):
			region = "castle_vargan"
		elif role.contains("ranger") or role.contains("bandit"):
			region = "long_road"
	var result: Dictionary = catalog.get("regions", {}).get(region, {}).duplicate(true)
	result.merge(named, true)
	# A palette has either one accent, or none. Other clothing channels are bases.
	result["id"] = id
	result["region"] = region
	result["eyes"] = "1b1816"
	if not result.has("skin"):
		var skins := ["8d604c", "a97559", "bc876b", "76503f"]
		var hairs := ["241a15", "4a3020", "71604e", "302523"]
		var key := absi((role + "|" + seed).hash())
		result["skin"] = skins[key % skins.size()]
		result["hair"] = hairs[int(key / 3) % hairs.size()]
	return result

static func colors(role: String, seed: String = "", zone_hint: String = "") -> Dictionary:
	var result := for_actor(role, seed, zone_hint)
	for channel: String in ["primary", "secondary", "linen", "leather", "boots", "metal", "skin", "hair", "eyes", "accent"]:
		if result.has(channel):
			result[channel] = Color(str(result[channel]))
	return result
