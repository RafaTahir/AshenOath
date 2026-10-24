extends RefCounted

## Authored identity recipes shared by wardrobe, facial attitude and staging.
## Heights and authored faces remain owned by the existing imported rigs.
const CAST := {
	"maren": {"primary":"35423a", "secondary":"705849", "hair":"40352d", "skin":"a07861", "width":1.0, "depth":1.0, "expression":"guarded", "gesture":"explain", "pace":0.88, "accent":"9f916e", "token":"road_knot", "motif":"road"},
	"kael": {"primary":"26352f", "secondary":"493b32", "hair":"77756f", "skin":"a9785f", "width":1.0, "depth":1.0, "expression":"guarded", "gesture":"acknowledge", "pace":0.86, "accent":"a18c60", "token":"broken_oath", "motif":"oath"},
	"anwen": {"primary":"28334b", "secondary":"646075", "hair":"b8b4aa", "skin":"a98270", "width":1.0, "depth":1.0, "expression":"concerned", "gesture":"offer", "pace":0.82, "accent":"b19b74", "token":"bell", "motif":"names"},
	"rook": {"primary":"263a32", "secondary":"756047", "hair":"3b2c23", "skin":"8f664f", "width":0.95, "depth":0.97, "expression":"wry", "gesture":"explain", "pace":1.06, "accent":"aa805a", "token":"road_knot", "motif":"road"},
	"mira": {"primary":"364a38", "secondary":"786e51", "hair":"33251e", "skin":"a97559", "width":0.98, "depth":1.01, "expression":"concerned", "gesture":"offer", "pace":0.88, "accent":"799672", "token":"root", "motif":"mercy"},
	"tor": {"primary":"312a27", "secondary":"6c4935", "hair":"66554a", "skin":"a88a6c", "width":1.07, "depth":1.04, "expression":"resolute", "gesture":"acknowledge", "pace":0.76, "accent":"897565", "token":"iron", "motif":"duty"},
	"elna": {"primary":"373341", "secondary":"646271", "hair":"96908a", "skin":"a47a66", "width":0.96, "depth":0.98, "expression":"grieving", "gesture":"remember", "pace":0.72, "accent":"c0ad87", "token":"name", "motif":"names"},
	"toma": {"primary":"594c36", "secondary":"918371", "hair":"5c4939", "skin":"b07f68", "width":1.02, "depth":1.0, "expression":"concerned", "gesture":"explain", "pace":0.96, "accent":"c4b999", "token":"grain", "motif":"road"},
	"senn": {"primary":"3e4a4c", "secondary":"544b42", "hair":"746b5a", "skin":"916b54", "width":1.02, "depth":1.02, "expression":"guarded", "gesture":"remember", "pace":0.78, "accent":"aa9470", "token":"broken_oath", "motif":"oath"},
	"edric": {"primary":"363b45", "secondary":"622f32", "hair":"574639", "skin":"a2765e", "width":1.03, "depth":1.0, "expression":"stern", "gesture":"explain", "pace":0.90, "accent":"ac945b", "token":"seal", "motif":"renewal"},
	"halvern": {"primary":"424953", "secondary":"574946", "hair":"7d7669", "skin":"89715e", "width":1.03, "depth":1.04, "expression":"grieving", "gesture":"acknowledge", "pace":0.70, "accent":"8c8370", "token":"broken_oath", "motif":"oath"},
}

## Character intent is separate from wardrobe. Supporting people keep their
## retained visual recipes even when they acquire a richer performance profile.
const PRESENCE := {
	"maren": ["relief organizer", "capable, dry, independent", "people becoming cargo in someone else's promise", ["anwen", "tor", "nera"], "sort_supplies", "shelter"],
	"kael": ["hunter", "reserved, observant", "abandoning someone again", ["anwen", "rook", "mira"], "scan", "guard"],
	"anwen": ["caretaker", "patient, exhausted", "a name being forgotten", ["elna", "jory", "kael"], "care", "warn"],
	"tor": ["blacksmith", "direct, dependable", "repairs arriving too late", ["rook", "jory"], "forge", "warn"],
	"mira": ["herbalist", "warm, practical", "help becoming another obligation", ["anwen", "iven"], "sort_herbs", "shelter"],
	"rook": ["trader", "wry, watchful", "his family being followed", ["toma", "tor"], "check_supplies", "shelter"],
	"elna": ["villager", "quiet, attentive", "private grief made spectacle", ["anwen", "nessa"], "remember", "shelter"],
	"toma": ["farmer", "earnest, worried", "another family missing supper", ["rook", "nessa"], "check_supplies", "warn"],
	"senn": ["road captain", "controlled, weary", "order repeating a wrong", ["tavin", "nera"], "watch", "guard"],
	"edric": ["lord", "polished, defensive", "accountability undoing his authority", ["merrow", "halvern"], "read", "guard"],
	"halvern": ["knight", "disciplined, burdened", "testimony becoming an excuse", ["edric", "vale"], "watch", "guard"],
	"vale": ["record keeper", "precise, guarded", "a source being erased", ["lysa", "merrow"], "read", "shelter"],
	"merrow": ["steward", "methodical, cautious", "servants bearing a lord's debt", ["vale", "edric"], "check_supplies", "warn"],
	"len": ["returned soldier", "hesitant, vigilant", "being used as proof instead of heard", ["anwen", "senn"], "watch", "shelter"],
	"nessa": ["baker", "generous, blunt", "winter without enough bread", ["toma", "jory"], "bake", "shelter"],
	"jory": ["bellkeeper", "eager, conscientious", "the warning failing someone", ["anwen", "tor"], "check_rope", "warn"],
	"iven": ["forester", "patient, economical", "fear being mistaken for knowledge", ["edda", "mira"], "tend", "warn"],
	"edda": ["charcoal burner", "dry, resilient", "earning a living by harming home", ["iven"], "sort_supplies", "shelter"],
	"dain": ["millwright", "measured, resourceful", "useful work excusing old harm", ["ressa", "tor"], "repair", "warn"],
	"ressa": ["grower", "determined, unsentimental", "a new home becoming a memorial", ["dain", "maelin"], "tend", "shelter"],
	"nera": ["crossing keeper", "vigilant, candid", "another unsafe crossing", ["tavin", "senn"], "check_rope", "warn"],
	"tavin": ["quartermaster", "restless, practical", "hiding behind a borrowed name", ["nera", "senn"], "check_supplies", "shelter"],
	"lysa": ["archive assistant", "curious, careful", "a tidy copy replacing the truth", ["vale", "odran"], "read", "shelter"],
	"odran": ["gardener", "gentle, firm", "work being mistaken for consent", ["lysa"], "tend", "shelter"],
	"maelin": ["seed keeper", "hopeful, deliberate", "a promise replacing patient care", ["oris", "ressa"], "sort_seeds", "shelter"],
	"oris": ["stoneworker", "thoughtful, tired", "promising more than hands can make", ["maelin"], "repair", "warn"],
}

const PRESENCE_ALIASES := {"sister_anwen":"anwen", "sister_anwen_human":"anwen", "blacksmith_tor":"tor", "widow_elna":"elna", "farmer_toma":"toma", "captain_senn":"senn", "returned_soldier":"len", "vargan_record_keeper":"vale", "record_keeper_vale":"vale", "vargan_steward":"merrow", "steward_merrow":"merrow", "mill_worker":"dain"}
static var _life_data: Dictionary = {}

# Contact points are local to retained work geometry, not actor shoulders.
const WORKSTATIONS := {
	"blacksmith_tor":{"node":"BlacksmithFittedWork", "point":Vector3(-1.18,0.92,-0.35), "stand":Vector3(-1.18,0,0.35), "left":Vector3(-1.30,1.01,-0.25), "right":Vector3(-1.06,1.01,-0.25), "activity":"forge", "sound":"forge_hammer", "period":2.0, "lift":0.36},
	"saga_nessa":{"quest":"saga_gre_q01", "point":Vector3(0,0.48,0), "stand":Vector3(0,0,0.65), "left":Vector3(-0.12,0.54,0.10), "right":Vector3(0.12,0.54,0.10), "activity":"bake", "period":2.5},
	"saga_jory":{"quest":"saga_gre_q02", "point":Vector3(0.30,1.05,0), "stand":Vector3(0.30,0,0.65), "left":Vector3(0.30,0.95,0), "right":Vector3(0.30,1.13,0), "activity":"check_rope", "period":2.4, "lift":0.08},
	"saga_lysa":{"quest":"saga_var_q01", "point":Vector3(0,0.5,0), "stand":Vector3(0,0,0.65), "left":Vector3(-0.12,0.58,0.10), "right":Vector3(0.12,0.58,0.10), "activity":"read", "sound":"record_page", "period":6.0},
	"saga_ressa":{"quest":"saga_dep_q02", "point":Vector3(0,0.15,0), "stand":Vector3(0,0,0.70), "left":Vector3(-0.12,0.24,0.15), "right":Vector3(0.12,0.24,0.15), "activity":"tend", "period":3.0},
	"saga_odran":{"quest":"saga_var_q03", "point":Vector3(0,0.15,0), "stand":Vector3(0,0,0.70), "left":Vector3(-0.12,0.24,0.15), "right":Vector3(0.12,0.24,0.15), "activity":"tend", "period":3.2},
	"saga_maelin":{"quest":"saga_har_q04", "point":Vector3(0,0.15,0), "stand":Vector3(0,0,0.70), "left":Vector3(-0.12,0.24,0.15), "right":Vector3(0.12,0.24,0.15), "activity":"sort_seeds", "period":3.0},
}

static func life_data() -> Dictionary:
	if _life_data.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/cast_life.json"))
		if data is Dictionary and int(data.get("version", 0)) == 1:
			_life_data = data
	return _life_data

static func routine(id: String, zone: String, state, quests, phase: String) -> Dictionary:
	var definition: Dictionary = life_data().get("zones", {}).get(zone, {}).get(id, {})
	if id == "saga_maren":
		var location: Dictionary = preload("res://scripts/saga_catalog.gd").person_location(id, quests)
		if str(location.zone) != zone:
			location = {"site":{"greyfen":"arrivals", "wychwood":"workers", "old_mill":"shelter", "marsh_crossing":"causeway", "record_hall":"archive", "hart_glade":"plot"}.get(zone, "arrivals")}
		var point: Vector3 = preload("res://scripts/saga_catalog.gd").SITES.get(zone, {}).get(str(location.site), Vector3(3, 0, 8))
		definition = {"profile":"maren", "work":[point.x,point.y,point.z], "stationary":true, "line":"Set the heavy end down first. We can talk while I check the straps."}
	if definition.is_empty():
		return {}
	var profile := presence_profile(str(definition.get("profile", id)))
	var work: Array = definition.work
	var activity := str(profile.activity)
	var line := str(definition.get("line", ""))
	var resolved: bool = quests != null and str(definition.get("after_quest", "")) != "" and quests.is_completed(str(definition.after_quest))
	if resolved:
		work = definition.get("after_work", work)
		activity = str(definition.get("after_activity", activity))
		line = str(definition.get("after_line", line))
	var rest: Array = definition.get("rest", work)
	var errand: Array = definition.get("errand", work)
	var path: Array = [Vector3(work[0],work[1],work[2]), Vector3(errand[0],errand[1],errand[2])]
	var activities: Array[String] = [activity, "check_supplies"]
	if bool(definition.get("stationary", false)):
		path.resize(1)
		activities = [activity]
	elif phase == "night" and not bool(definition.get("night_work", false)):
		path = [Vector3(rest[0],rest[1],rest[2])]
		activities = ["rest"]
	elif phase == "dusk" and definition.has("social"):
		var social: Array = definition.social
		path = [Vector3(social[0],social[1],social[2]), Vector3(work[0],work[1],work[2])]
		activities = ["rest", activity]
	return {"occupation":profile.occupation, "activity":activities[0], "activity_seconds":12.0 if phase == "night" else 8.0, "path":path, "activities":activities, "line":line, "identity":profile.id, "station":WORKSTATIONS.get(id, {}), "revision":str([phase,resolved,state.get_flag("final_covenant", "") if state != null else ""])}

static func presence_profile(role: String, seed: String = "") -> Dictionary:
	var words := " " + (role + " " + seed).to_lower().replace("_", " ").replace("-", " ") + " "
	var id := str(PRESENCE_ALIASES.get(role, identity(role, seed)))
	if id == "":
		for candidate: String in PRESENCE:
			if words.contains(" " + candidate + " "):
				id = candidate
				break
	var row: Array = PRESENCE.get(id, ["guard" if words.contains("guard") else "villager", "attentive", "danger to the community", [], "watch" if words.contains("guard") else "idle", "guard" if words.contains("guard") else "shelter"])
	var original: Dictionary = CAST.get(id, {})
	return {"id":id, "occupation":row[0], "personality":row[1], "concern":row[2], "relationships":row[3].duplicate(), "activity":row[4], "danger_response":row[5], "expression":str(original.get("expression", "neutral"))}

static func identity(role: String, seed: String = "") -> String:
	var words := (role + " " + seed).to_lower()
	words = " " + words.replace("_", " ").replace("-", " ") + " "
	if role in ["player", "player_human", "player_kael"]:
		return "kael"
	for id in CAST:
		if words.contains(" " + str(id) + " "):
			return str(id)
	return ""

static func get_profile(role: String, seed: String = "") -> Dictionary:
	var id := identity(role, seed)
	if id == "":
		return {}
	var result: Dictionary = CAST[id].duplicate()
	result["id"] = id
	result.merge(presence_profile(role, seed), false)
	return result

static func expression_for(profile: Dictionary, state) -> String:
	if state != null and str(profile.get("id", "")) != "":
		for memory: Dictionary in state.relationship_events(str(profile.get("id", ""))):
			if str(memory.id).ends_with(".weapon_contact"): return "guarded"
	var id := str(profile.get("id", ""))
	if state != null:
		if id == "maren":
			return "neutral" if str(state.get_flag("side_escort_06_outcome", "")) == "company" else "guarded"
		var standing: Dictionary = state.honor_view(id) if id != "" else {}
		if bool(standing.get("grievance", false)):
			return "guarded"
		# Emotions follow the person's own recorded experience. An ending does
		# not make every person, including absent witnesses, feel the same way.
		if id != "" and state.has_method("relationship_events"):
			var events: Array = state.relationship_events(id)
			if not events.is_empty():
				var kind := str(events.back().get("kind", ""))
				if kind in ["broken", "boundary"]:
					return "guarded"
				if kind in ["kept", "friendship", "commitment", "help"]:
					return "warmth"
		if id == "kael" and bool(state.get_flag("kael_confessed", false)):
			return "resolute"
		if id == "edric" and str(state.get_flag("confession_method", "")) != "":
			return "guarded"
		if id == "mira" and str(state.get_flag("mira_truth", "")) != "":
			return "relieved"
		if bool(standing.get("known", false)) and str(standing.get("band", "")) == "Distrusted":
			return "guarded"
		if bool(standing.get("known", false)) and str(standing.get("band", "")) == "Respected":
			return "warmth"
	return str(profile.get("expression", "neutral"))
