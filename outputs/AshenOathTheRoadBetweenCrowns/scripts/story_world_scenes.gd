extends RefCounted

## Finite direction consumed by the existing routine controller; no quest authority.
static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/people_place_scenes.json"))
		if parsed is Dictionary:
			_data = parsed
	return _data

static func eligible(scene: Dictionary, host) -> bool:
	if str(scene.zone) != str(host.current_zone_id):
		return false
	for key: String in scene.get("when", {}):
		var wanted: Variant = scene.when[key]
		var actual: Variant = host.story_state.get_flag(key, false if wanted is bool else null)
		if key == "final_covenant":
			actual = {"expose":"witness", "free":"mercy", "bind":"duty", "kill":"ash"}.get(str(actual), actual)
		if wanted is Array:
			if actual not in wanted: return false
		elif actual != wanted:
			return false
	for key: String in scene.get("unless", []):
		if host.story_state.get_flag(key, null) not in [null, false, ""]:
			return false
	for id: String in scene.get("quests", []):
		if not host.quests.is_completed(id): return false
	if bool(scene.get("gathering", false)) and not preload("res://scripts/greyfen_gathering.gd").active(host):
		return false
	return true

static func has_zone(zone: String) -> bool:
	for scene: Dictionary in data().get("scenes", []):
		if str(scene.zone) == zone: return true
	return false

static func turns(scene: Dictionary, host) -> Array:
	for variant: Dictionary in scene.get("variants", []):
		if eligible(variant.merged({"zone":scene.zone}), host):
			return variant.turns
	return scene.get("turns", [])

static func reflections(state) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var heard: Variant = state.get_flag("world_scenes_heard", {})
	if not heard is Dictionary: return result
	for reflection: Dictionary in data().get("reflections", []):
		if not bool(heard.get(str(reflection.scene), false)): continue
		if reflection.has("flag") and not bool(state.get_flag(str(reflection.flag), false)): continue
		var body := str(reflection.text)
		if str(reflection.id) == "hartlands":
			body += " The recorded covenant is " + str(state.get_flag("final_covenant", "unresolved")) + ". That outcome stands; no unchosen feeling is recorded for Kael."
		result.append({"id":"reflection:" + str(reflection.id), "title":str(reflection.title), "body":body})
	return result
