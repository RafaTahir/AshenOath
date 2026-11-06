extends RefCounted

const Palette = preload("res://scripts/systems/character_palette.gd")
const RoutineDirector = preload("res://scripts/systems/npc_routine_director.gd")

## Authored identity recipes shared by wardrobe, facial attitude and staging.
## Heights and authored faces remain owned by the existing imported rigs.
const CAST := {
	"nera": {"expression":"guarded", "gesture":"explain", "pace":0.88, "token":"road_knot", "motif":"road"},
	"nessa": {"expression":"warmth", "gesture":"offer", "pace":0.92, "token":"grain", "motif":"home"},
	"vale": {"expression":"guarded", "gesture":"explain", "pace":0.78, "token":"name", "motif":"names"},
	"merrow": {"expression":"concerned", "gesture":"acknowledge", "pace":0.84, "token":"seal", "motif":"duty"},
	"maren": {"expression":"guarded", "gesture":"explain", "pace":0.88, "token":"road_knot", "motif":"road"},
	"kael": {"expression":"guarded", "gesture":"acknowledge", "pace":0.86, "token":"broken_oath", "motif":"oath"},
	"anwen": {"expression":"concerned", "gesture":"offer", "pace":0.82, "token":"bell", "motif":"names"},
	"rook": {"expression":"wry", "gesture":"explain", "pace":1.06, "token":"road_knot", "motif":"road"},
	"mira": {"expression":"concerned", "gesture":"offer", "pace":0.88, "token":"root", "motif":"mercy"},
	"tor": {"expression":"resolute", "gesture":"acknowledge", "pace":0.76, "token":"iron", "motif":"duty"},
	"elna": {"expression":"grieving", "gesture":"remember", "pace":0.72, "token":"name", "motif":"names"},
	"toma": {"expression":"concerned", "gesture":"explain", "pace":0.96, "token":"grain", "motif":"road"},
	"senn": {"expression":"guarded", "gesture":"remember", "pace":0.78, "token":"broken_oath", "motif":"oath"},
	"edric": {"expression":"stern", "gesture":"explain", "pace":0.90, "token":"seal", "motif":"renewal"},
	"halvern": {"expression":"grieving", "gesture":"acknowledge", "pace":0.70, "token":"broken_oath", "motif":"oath"},
}

## Character intent is separate from wardrobe. Supporting people keep their
## retained visual recipes even when they acquire a richer performance profile.
const PRESENCE := {
	"maren": ["relief organizer", "capable, dry, independent", "people becoming cargo in someone else's promise", ["anwen", "tor", "nera"], "sort_supplies", "shelter"],
	"kael": ["hunter", "reserved, observant", "abandoning someone again", ["anwen", "rook", "mira"], "scan", "guard"],
	"anwen": ["caretaker", "patient, exhausted", "a name being forgotten", ["elna", "jory", "kael"], "care", "warn"],
	"tor": ["smith and mechanism keeper", "direct, dependable", "repairs arriving too late", ["rook", "anwen"], "forge", "warn"],
	"mira": ["herbalist", "warm, practical", "help becoming another obligation", ["anwen", "iven"], "sort_herbs", "shelter"],
	"rook": ["trader", "wry, watchful", "his family being followed", ["toma", "tor"], "check_supplies", "shelter"],
	"elna": ["villager", "quiet, attentive", "private grief made spectacle", ["anwen", "nessa"], "fold_cloth", "shelter"],
	"toma": ["farmer and working-trail keeper", "earnest, observant", "another family missing supper", ["rook", "nessa", "mira"], "check_supplies", "warn"],
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
	"nera": ["crossing keeper and relief organizer", "capable, candid, independent", "people becoming cargo in another person's promise", ["anwen", "tor", "rook", "senn"], "check_rope", "warn"],
	"tavin": ["quartermaster", "restless, practical", "hiding behind a borrowed name", ["nera", "senn"], "check_supplies", "shelter"],
	"lysa": ["archive assistant", "curious, careful", "a tidy copy replacing the truth", ["vale", "odran"], "read", "shelter"],
	"odran": ["gardener", "gentle, firm", "work being mistaken for consent", ["lysa"], "tend", "shelter"],
	"maelin": ["seed keeper", "hopeful, deliberate", "a promise replacing patient care", ["oris", "ressa"], "sort_seeds", "shelter"],
	"oris": ["stoneworker", "thoughtful, tired", "promising more than hands can make", ["maelin"], "repair", "warn"],
}

const PRESENCE_ALIASES := {"sister_anwen":"anwen", "sister_anwen_human":"anwen", "blacksmith_tor":"tor", "widow_elna":"elna", "farmer_toma":"toma", "captain_senn":"senn", "returned_soldier":"len", "vargan_record_keeper":"vale", "record_keeper_vale":"vale", "vargan_steward":"merrow", "steward_merrow":"merrow", "mill_worker":"dain"}
static var _life_data: Dictionary = {}
static var _design_cast: Dictionary = {}

const LIFE_MOTION := {
	"kael":{"library":"res://assets_external/characters_prepared/animations/life_P01.res", "work":[], "contact":0.50, "idle_only":true, "clips":["Life_Idle_A", "Life_Idle_B"]},
	"anwen":{"library":"res://assets_external/characters_prepared/animations/life_C01.res", "work":["care"], "contact":0.50},
	"tor":{"library":"res://assets_external/characters_prepared/animations/life_C04.res", "work":["forge", "repair"], "contact":0.50},
	"mira":{"library":"res://assets_external/characters_prepared/animations/life_C03.res", "work":["sort_herbs", "herb_stall", "sort_seeds"], "contact":0.50, "contact_probe":"palm"},
	"rook":{"library":"res://assets_external/characters_prepared/animations/life_C02.res", "work":["check_supplies", "sort_supplies", "check_rope"], "contact":0.50, "contact_probe":"palm"},
	"nessa":{"library":"res://assets_external/characters_prepared/animations/life_C11.res", "work":["bake", "care"], "contact":0.50, "contact_probe":"palm", "requires_station":true},
	"elna":{"library":"res://assets_external/characters_prepared/animations/life_C05.res", "work":["fold_cloth"], "contact":0.50, "contact_probe":"palm", "requires_station":true},
	"toma":{"library":"res://assets_external/characters_prepared/animations/life_C06.res", "work":["tend", "sort_seeds", "check_supplies"], "contact":0.50, "contact_probe":"palm", "requires_station":true},
	"nera":{"library":"res://assets_external/characters_prepared/animations/life_C12.res", "work":["check_rope", "check_supplies"], "contact":0.50, "contact_probe":"palm", "requires_station":true},
	"senn":{"library":"res://assets_external/characters_prepared/animations/life_C07.res", "work":["watch", "lookout"], "contact":0.50},
	"vale":{"library":"res://assets_external/characters_prepared/animations/life_C09.res", "work":["read", "write"], "contact":0.50, "contact_probe":"palm", "requires_station":true, "extra_clips":{"lower_book":"Life_Lower_Book"}},
	"merrow":{"library":"res://assets_external/characters_prepared/animations/life_C10.res", "work":["check_supplies", "read", "administer"], "contact":0.50, "contact_probe":"palm", "requires_station":true, "extra_clips":{"drink":"Life_Drink", "cup_hold":"Life_Cup_Hold"}},
	"edric":{"library":"res://assets_external/characters_prepared/animations/life_C08.res", "work":["read", "review_dispatch"], "contact":0.50, "contact_probe":"palm", "requires_station":true},
}

static func life_motion_profile(actor_id: String) -> Dictionary:
	return LIFE_MOTION.get(canonical_identity(actor_id), {}).duplicate(true)

static func design_cast() -> Dictionary:
	if _design_cast.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/design_pack_cast.json"))
		if data is Dictionary and int(data.get("version", 0)) == 1:
			_design_cast = data
	return _design_cast

static func canonical_identity(actor_id: String) -> String:
	var key := actor_id.to_lower()
	var roster: Dictionary = design_cast().get("cast", {})
	if roster.has(key):
		return key
	return str(design_cast().get("legacy_cast", {}).get(key, ""))

static func visual_role(actor_id: String, fallback: String = "") -> String:
	var person: Dictionary = design_cast().get("cast", {}).get(canonical_identity(actor_id), {})
	return str(person.get("role", fallback))

static func display_name(actor_id: String, fallback: String = "") -> String:
	var person: Dictionary = design_cast().get("cast", {}).get(canonical_identity(actor_id), {})
	return str(person.get("name", fallback))

static func same_person(first: String, second: String) -> bool:
	if first == second:
		return true
	var identity_id := canonical_identity(first)
	return identity_id != "" and identity_id == canonical_identity(second)

static func introduce(game, actor_id: String, dialogue_data: Dictionary) -> String:
	var identity_id := canonical_identity(actor_id)
	var key := "design_cast_introduction:" + identity_id
	var words := str(design_cast().get("introductions", {}).get(identity_id, ""))
	if words.is_empty() or bool(game.story_state.get_flag(key, false)):
		return ""
	var pages: Array = dialogue_data.get("pages", [])
	if pages.is_empty():
		return ""
	pages.push_front({"speaker":display_name(actor_id), "speaker_id":"narrator", "text":words, "performance":{"framing":"two_shot"}})
	dialogue_data["pages"] = pages
	return key

static func remember_introduction(game, key: String) -> void:
	if key.is_empty():
		return
	game.story_state.set_flag(key, true)
	game.story_save_pending = true
	game.call_deferred("_persist_story_action")

static func registered_actor(zone_root: Node3D, actor_id: String) -> Node3D:
	if not is_instance_valid(zone_root):
		return null
	var identity_id := canonical_identity(actor_id)
	var registry: Dictionary = zone_root.get_meta("design_cast_registry", {})
	var reference: Variant = registry.get(identity_id)
	var actor := reference.get_ref() as Node3D if reference is WeakRef else null
	return actor if is_instance_valid(actor) and zone_root.is_ancestor_of(actor) else null

static func register_actor(zone_root: Node3D, actor: Node3D, actor_id: String) -> void:
	var identity_id := canonical_identity(actor_id)
	if identity_id == "" or not is_instance_valid(actor):
		return
	var existing := registered_actor(zone_root, actor_id)
	if existing != null and existing != actor:
		return
	var registry: Dictionary = zone_root.get_meta("design_cast_registry", {})
	registry[identity_id] = weakref(actor)
	zone_root.set_meta("design_cast_registry", registry)
	actor.set_meta("story_cast_identity", identity_id)

# Contact points are local to retained work geometry, not actor shoulders.
const WORKSTATIONS := {
	"sister_anwen":{"node":"LifeWork_anwen", "markers":true, "activity":"care", "period":4.0},
	"mira":{"node":"LifeWork_mira", "markers":true, "activity":"sort_herbs", "period":4.0, "surface_prop":"MiraRaisedDryingRack"},
	"rook":{"node":"LifeWork_rook", "markers":true, "activity":"check_supplies", "period":4.0, "surface_prop":"RookStationSatchel", "contact_event":"satchel_cinch"},
	"blacksmith_tor":{"node":"BlacksmithFittedWork", "point":Vector3(-1.22,0.92,0.10), "stand":Vector3(-1.40,0,0.45), "look":Vector3(-1.40,1.10,-0.35), "left":Vector3(-1.52,1.01,0.10), "right":Vector3(-1.22,1.185,0.10), "activity":"forge", "sound":"forge_hammer", "period":4.0, "lift":0.36},
	"saga_nessa":{"node":"LifeWork_nessa", "alternates":["LifeWork_nessa_after"], "markers":true, "activity":"bake", "activities":["bake", "care"], "surface_prop":"StationWork_nessa", "contact_event":"life_work:nessa", "period":4.0},
	"widow_elna":{"node":"LifeWork_elna", "markers":true, "activity":"fold_cloth", "surface_prop":"StationWork_elna", "contact_event":"life_work:elna", "period":4.0},
	"farmer_toma":{"node":"LifeWork_toma", "markers":true, "activity":"tend", "activities":["tend", "sort_seeds", "check_supplies"], "surface_prop":"StationWork_toma", "contact_event":"life_work:toma", "period":4.0},
	"saga_nera":{"node":"LifeWork_nera", "alternates":["LifeWork_nera_after"], "markers":true, "activity":"check_rope", "activities":["check_rope", "check_supplies"], "surface_prop":"StationWork_nera", "contact_event":"life_work:nera", "period":4.0},
	"vargan_record_keeper":{"node":"LifeWork_vale", "markers":true, "activity":"read", "activities":["read", "write"], "surface_prop":"StationWork_vale", "contact_event":"life_work:vale", "sound":"record_page", "period":4.0},
	"vargan_steward":{"node":"LifeWork_merrow", "markers":true, "activity":"check_supplies", "activities":["check_supplies", "read", "administer"], "surface_prop":"StationWork_merrow", "contact_event":"life_work:merrow", "sound":"record_page", "period":4.0},
	"edric":{"node":"LifeWork_edric", "markers":true, "activity":"review_dispatch", "activities":["review_dispatch", "read"], "surface_prop":"StationWork_edric", "contact_event":"life_work:edric", "sound":"record_page", "period":4.0},
	"saga_jory":{"quest":"saga_gre_q02", "point":Vector3(0.30,1.05,0), "stand":Vector3(0.30,0,0.65), "left":Vector3(0.30,0.95,0), "right":Vector3(0.30,1.13,0), "activity":"check_rope", "period":2.4, "lift":0.08},
	"saga_lysa":{"quest":"saga_var_q01", "point":Vector3(0,0.5,0), "stand":Vector3(0,0,0.65), "left":Vector3(-0.12,0.58,0.10), "right":Vector3(0.12,0.58,0.10), "activity":"read", "sound":"record_page", "period":6.0},
	"saga_ressa":{"quest":"saga_dep_q02", "point":Vector3(0,0.15,0), "stand":Vector3(0,0,0.70), "left":Vector3(-0.12,0.24,0.15), "right":Vector3(0.12,0.24,0.15), "activity":"tend", "period":3.0},
	"saga_odran":{"quest":"saga_var_q03", "point":Vector3(0,0.15,0), "stand":Vector3(0,0,0.70), "left":Vector3(-0.12,0.24,0.15), "right":Vector3(0.12,0.24,0.15), "activity":"tend", "period":3.2},
	"saga_maelin":{"quest":"saga_har_q04", "point":Vector3(0,0.15,0), "stand":Vector3(0,0,0.70), "left":Vector3(-0.12,0.24,0.15), "right":Vector3(0.12,0.24,0.15), "activity":"sort_seeds", "period":3.0},
}

static func life_data() -> Dictionary:
	if _life_data.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/cast_life.json"))
		if data is Dictionary and int(data.get("version", 0)) in [1, 2]:
			_life_data = data
	return _life_data

static func load_region_life(zone: String, path: String) -> bool:
	# Optional regions provide their routine records only after their own pack
	# mounts. The opening catalog never asks for late campaign resources.
	if zone not in ["lantern_reach","hearthward"] or path != "res://data/community_cast_life.json": return false
	var catalog := life_data()
	if catalog.get("zones",{}).has(zone): return true
	if not FileAccess.file_exists(path): return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not parsed.get("zones",{}).get(zone) is Dictionary: return false
	catalog.get_or_add("zones",{})[zone] = parsed.zones[zone].duplicate(true)
	return true

static func routine(id: String, zone: String, state, quests, phase: String, minutes: float = -1.0) -> Dictionary:
	var definition: Dictionary = life_data().get("zones", {}).get(zone, {}).get(id, {}).duplicate(true)
	if id == "saga_maren":
		var location: Dictionary = preload("res://scripts/saga_catalog.gd").person_location(id, quests)
		if str(location.zone) != zone:
			location = {"site":{"greyfen":"arrivals", "wychwood":"workers", "old_mill":"shelter", "marsh_crossing":"causeway", "record_hall":"archive", "hart_glade":"plot"}.get(zone, "arrivals")}
		var point: Vector3 = preload("res://scripts/saga_catalog.gd").SITES.get(zone, {}).get(str(location.site), Vector3(3, 0, 8))
		definition = {"profile":"maren", "work":[point.x,point.y,point.z], "stationary":true, "line":"Set the heavy end down first. We can talk while I check the straps."}
	if definition.is_empty():
		return {}
	var profile := presence_profile(str(definition.get("profile", id)))
	var resolved: bool = quests != null and str(definition.get("after_quest", "")) != "" and quests.is_completed(str(definition.after_quest))
	if resolved:
		definition["work"] = definition.get("after_work", definition.work)
		definition["activity"] = definition.get("after_activity", profile.activity)
		definition["line"] = definition.get("after_line", definition.get("line", ""))
	var consequences: Array[String] = []
	for projection: Dictionary in definition.get("consequences", []):
		var flag := str(projection.get("flag", ""))
		if state == null or flag == "" or state.get_flag(flag, null) != projection.get("value"):
			continue
		consequences.append(flag + ":" + str(projection.value))
		for key: String in ["work", "errand", "rest", "social", "activity", "line", "station"]:
			if projection.has(key): definition[key] = projection[key]
	var work: Array = definition.work
	var activity := str(definition.get("activity", profile.activity))
	var line := str(definition.get("line", ""))
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
	var station_id := str({"nera":"saga_nera", "nessa":"saga_nessa", "vale":"vargan_record_keeper", "merrow":"vargan_steward", "elna":"widow_elna", "toma":"farmer_toma"}.get(str(profile.id), id))
	var result := {"occupation":profile.occupation, "activity":activities[0], "activity_seconds":12.0 if phase == "night" else 8.0, "path":path, "activities":activities, "line":line, "identity":profile.id, "station":definition.get("station", WORKSTATIONS.get(station_id, WORKSTATIONS.get(id, {}))), "revision":str([phase,resolved,consequences,state.get_flag("final_covenant", "") if state != null else ""])}
	result["meal_group"] = str(definition.get("meal_group", ""))
	if minutes >= 0.0:
		var locations := definition.duplicate(true)
		locations.work = work
		# Work intent always resolves the consequence-specific occupation, not a
		# temporary rest pose from the legacy phase-only projection above.
		result.activity = activity
		result = RoutineDirector.resolve(life_data(), id, locations, result, minutes)
	return result

static func presence_profile(role: String, seed: String = "") -> Dictionary:
	var words := " " + (role + " " + seed).to_lower().replace("_", " ").replace("-", " ") + " "
	var id := str(PRESENCE_ALIASES.get(role, identity(role, seed)))
	if id == "":
		for candidate: String in PRESENCE:
			if words.contains(" " + candidate + " "):
				id = candidate
				break
	var canonical := canonical_identity(id)
	if canonical != "":
		id = canonical
	var row: Array = PRESENCE.get(id, ["guard" if words.contains("guard") else "villager", "attentive", "danger to the community", [], "watch" if words.contains("guard") else "idle", "guard" if words.contains("guard") else "shelter"])
	var original: Dictionary = CAST.get(id, {})
	var relationships: Array[String] = []
	for other: String in row[3]:
		var person := canonical_identity(other)
		if person == "":
			person = other
		if person != id and not relationships.has(person):
			relationships.append(person)
	return {"id":id, "occupation":row[0], "personality":row[1], "concern":row[2], "relationships":relationships, "activity":row[4], "danger_response":row[5], "expression":str(original.get("expression", "neutral"))}

static func identity(role: String, seed: String = "") -> String:
	var canonical := canonical_identity(seed)
	if canonical == "":
		canonical = canonical_identity(role)
	if canonical != "":
		return canonical
	var words := (role + " " + seed).to_lower()
	words = " " + words.replace("_", " ").replace("-", " ") + " "
	if role in ["player", "player_human", "player_kael"]:
		return "kael"
	for id in CAST:
		if words.contains(" " + str(id) + " "):
			return str(id)
	return ""

static func get_profile(role: String, seed: String = "") -> Dictionary:
	var canonical := identity(role, seed)
	var palette := Palette.for_actor(canonical if canonical != "" else role, canonical if canonical != "" else seed)
	var id := str(palette.id)
	if id == "":
		return {}
	var result: Dictionary = CAST.get(id, {"expression":"neutral", "gesture":"acknowledge", "pace":0.88, "token":"name", "motif":"road"}).duplicate()
	result.merge(palette, true)
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
