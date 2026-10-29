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

static func dialogue_callbacks(id: String, pages: Array, state, quests) -> Array:
	if state == null: return pages
	var result: Array = pages.duplicate(true)
	if id == "halvern" and bool(state.get_flag("escort_abandonment_acknowledged", false)):
		for page: Dictionary in result:
			if str(page.get("speaker_id", "")) == "player" and str(page.get("text", "")).begins_with("I was ordered to retreat from another road"):
				page["text"] = "Nera has already heard me say it. I left civilians on a different road after promising escort, called it retreat, and never went back. Your refusal does not excuse mine."
	var speaker := ""
	var words := ""
	if id == "notice_board" and not bool(state.get_flag("escort_abandonment_acknowledged", false)):
		speaker = "narrator"
		words = "A fresh delivery note: Nera's relief cart is at the arrivals yard. Tor has left an axle brace; Anwen has the clean linen. Another pair of hands would be welcome."
	if quests != null and quests.is_completed("side_escort_01"):
		match id:
			"blacksmith_tor":
				speaker = "blacksmith_tor"
				if quests.is_completed("side_escort_04"):
					result.append({"speaker":"Kael", "speaker_id":"player", "text":"Nera's crew reached the far shoulder. Your brace held.", "beat":"shared_account"})
				words = "That relief axle is seated. A wheel should turn without someone having to hold their breath. " + ("It held through the crossing, by the account you brought back." if quests.is_completed("side_escort_04") else "Tell Nera to check it again after the crossing.")
			"sister_anwen":
				speaker = "sister_anwen"
				words = "Nera brought the load in with half an axle and all her opinions. Useful woman. You left the linen where I could reach it; thank you."
	var correction := str(state.get_flag("side_escort_05_outcome", ""))
	if correction != "" and quests != null and quests.is_completed("side_escort_05"):
		if id == "vargan_record_keeper":
			speaker = "vargan_record_keeper"
			words = "Your correction is beside its source. Nera's account remains in its agreed custody. I have not put words into the gaps."
		elif correction == "public" and id == "rook":
			speaker = "rook"
			words = "Read your correction. Not going to make a joke about that one. There is still a chair here, if you can bear me being sensible for a moment."
		elif correction == "public" and id == "assembly_choice":
			speaker = "narrator"
			words = "Kael's public correction is available beside his own report. Nera's limited account does not speak for the other survivors and supplies no proof of Vargan's massacre."
	if words != "":
		result.append({"speaker":"A remembered act" if speaker == "narrator" else {"blacksmith_tor":"Tor", "sister_anwen":"Anwen", "rook":"Rook", "vargan_record_keeper":"Vale"}.get(speaker, speaker), "speaker_id":speaker, "text":words, "beat":"remembered_action"})
	return result

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
