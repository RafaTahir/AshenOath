class_name LivingCastModel
extends RefCounted
signal awareness_changed(actor_id: String, reaction: String)
const Clock = preload("res://scripts/core/sim_clock.gd")
const Rng = preload("res://scripts/core/seeded_rng.gd")
const RoutineDirector = preload("res://scripts/systems/npc_routine_director.gd")
const AMBIENT_LINES := {
	"greyfen_road_quiet":"Road's quiet today. That's worse.",
	"greyfen_bell_dawn":"Bell rang before dawn. Nobody touched it.",
	"greyfen_shrine_voice":"Keep your voice low near the shrine.",
	"greyfen_anwen_sleep":"Anwen has not slept.",
	"greyfen_crows_fat":"Crows came back fat.",
	"greyfen_woods_stare":"Don't stare at the woods. It stares back.",
	"greyfen_forge_night":"Tor worked the forge through the night.",
	"greyfen_well_iron":"Water tastes of iron again.",
	"greyfen_cart_light":"Bram always brought the empty baskets back. Not this time.",
	"greyfen_roots_bitter":"Mira says the roots are bitter this year.",
	"greyfen_north_smoke":"No smoke from the north road.",
	"greyfen_keep_working":"We keep working. What else is there?"
}

const POST_REPORT_LINES := {
	"private": ["Anwen took the evidence inside. The village is pretending not to listen.", "Nobody asks what Kael told her. They watch the cemetery road instead."],
	"public": ["The notice board has new names on it. People read them and keep their hands busy.", "The bell changed the way Greyfen walks. No one crosses the square alone."],
	"retained": ["Someone kept a piece of the road's story. The crows know which piece.", "The evidence is not all in Anwen's hands. That makes every quiet conversation sharper."]
}

const ROUTINE_PROFILES := {
	"walker_well": {"occupation": "well keeper", "activity": "well", "activity_seconds": 2.8, "line": "greyfen_well_iron"},
	"walker_board": {"occupation": "notice reader", "activity": "notice_board", "activity_seconds": 2.4, "line": "greyfen_road_quiet"},
	"shrine_pilgrim": {"occupation": "shrine pilgrim", "activity": "shrine", "activity_seconds": 3.4, "line": "greyfen_shrine_voice"},
	"forge_helper": {"occupation": "forge helper", "activity": "forge", "activity_seconds": 3.1, "line": "greyfen_forge_night"},
	"herb_helper": {"occupation": "herb gatherer", "activity": "herb_stall", "activity_seconds": 2.6, "line": "greyfen_roots_bitter"},
	"worried_villager": {"occupation": "road lookout", "activity": "lookout", "activity_seconds": 2.0, "line": "greyfen_north_smoke"},
	"young_villager": {"occupation": "market runner", "activity": "market", "activity_seconds": 1.8, "line": "greyfen_cart_light"},
	"water_carrier": {"occupation": "water carrier", "activity": "well", "activity_seconds": 2.4, "line": "greyfen_well_iron"},
	"quality_sweeper": {"occupation": "street sweeper", "activity": "market", "activity_seconds": 2.2, "line": "greyfen_keep_working"},
	"quality_mourner": {"occupation": "mourner", "activity": "shrine", "activity_seconds": 3.0, "line": "greyfen_anwen_sleep"},
	"blacksmith_tor": {"occupation": "blacksmith", "activity": "forge", "activity_seconds": 3.6, "line": "greyfen_forge_night"},
	"mira": {"occupation": "herbalist", "activity": "herb_stall", "activity_seconds": 3.0, "line": "greyfen_roots_bitter"},
	"rook": {"occupation": "road watcher", "activity": "notice_board", "activity_seconds": 2.2, "line": "greyfen_crows_fat"}
}

const OCCUPATION_LINES := {
	"walker_well": "Sella left her washing on the line. I brought it in before the rain.",
	"walker_board": "Bram lent me his cart every harvest. Never asked for a coin.",
	"shrine_pilgrim": "Oren carved that wooden crow himself. Anwen kept telling him to mind his fingers.",
	"forge_helper": "Tor repaired Bram's axle yesterday. He still has the payment laid aside."
}

const GATHERING_POSITIONS: Dictionary = {"rook":Vector3(-7.6,0,9.3),"blacksmith_tor":Vector3(-3.2,0,9.3),"sister_anwen":Vector3(-4.2,0,8.5),"mira":Vector3(-6.5,0,8.5),"saga_nessa":Vector3(-5.4,0,8.2)}
var clock: Clock = Clock.new()
var rng: Rng = Rng.new(44017)
var actors: Dictionary = {}
var activity_reservations: Dictionary[String, String] = {}
var gathering_staged: bool = false
var chapter_report: String = ""
var phase: String = "morning"

func reset(seed_value: int) -> void:
	clock = Clock.new()
	rng = Rng.new(seed_value)
	actors.clear()
	activity_reservations.clear()
	gathering_staged = false

func milliseconds() -> int:
	return floori(float(clock.tick) * 1000.0 / Clock.TICK_HZ)

func advance(delta: float) -> int:
	return clock.consume(delta)

func register_actor(id: String, profile: Dictionary, position: Vector3) -> void:
	if actors.has(id): return
	actors[id] = {"profile":profile.duplicate(true),"position":position,"reaction":"","reaction_until":0,"greeting_until":0,"approached":false}

func set_chapter(report: String, day_phase: String) -> void:
	chapter_report = report if report in ["private","public","retained"] else ""
	phase = day_phase

func reservation_owner(station: String) -> String:
	return str(activity_reservations.get(station,""))

func reserve_station(station: String, actor_id: String) -> bool:
	if station == "" or actor_id == "": return false
	var owner: String = reservation_owner(station)
	if owner != "" and owner != actor_id: return false
	activity_reservations[station] = actor_id
	return true

func release_station(station: String, actor_id: String) -> bool:
	if reservation_owner(station) != actor_id: return false
	return activity_reservations.erase(station)

func record_awareness(actor_id: String, reaction: String, seconds: float = 2.5) -> bool:
	if not actors.has(actor_id): return false
	var actor: Dictionary = actors[actor_id]
	if clock.tick < int(actor.reaction_until) and reaction_priority(reaction) < reaction_priority(str(actor.reaction)): return false
	var changed: bool = str(actor.reaction) != reaction or clock.tick >= int(actor.reaction_until)
	actor.reaction = reaction
	actor.reaction_until = clock.tick + ceili(seconds * Clock.TICK_HZ)
	if changed: awareness_changed.emit(actor_id,reaction)
	return true

static func reaction_priority(kind: String) -> int:
	return int({"attention":1,"suspicion":2,"fear":3,"anger":3}.get(kind,0))

func proximity(actor_id: String, distance: float, sleeping: bool, visible: bool, available: bool) -> bool:
	if not actors.has(actor_id): return false
	var actor: Dictionary = actors[actor_id]
	if distance > 4.6: actor.approached = false
	if not is_finite(distance) or distance > 4.0 or sleeping or not visible or not available or bool(actor.approached) or clock.tick < int(actor.greeting_until): return false
	actor.approached = true
	actor.greeting_until = clock.tick + 60 * Clock.TICK_HZ
	record_awareness(actor_id,"attention",1.2)
	return true

func post_report_line(report: String, cycle: int, known: bool) -> String:
	if not known: return ""
	var lines: Array = POST_REPORT_LINES.get(report,[])
	return str(lines[posmod(cycle,lines.size())]) if not lines.is_empty() else ""

func stage_gathering(active: bool) -> bool:
	if gathering_staged == active: return false
	gathering_staged = active
	return true

func gathering_positions() -> Dictionary:
	return GATHERING_POSITIONS.duplicate()

func scheduled_intent(data: Dictionary, id: String, definition: Dictionary, profile: Dictionary, minutes: float) -> Dictionary:
	return RoutineDirector.resolve(data,id,definition,profile,minutes)

func existing_route(data: Dictionary, id: String, profile: Dictionary, route: Array, minutes: float) -> Dictionary:
	return RoutineDirector.for_existing_route(data,id,profile,route,minutes)

static func _snapshot_value(value: Variant) -> Variant:
	if value is Vector3: return [value.x,value.y,value.z]
	if value is Array:
		var result: Array = []
		for item: Variant in value: result.append(_snapshot_value(item))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key: String in value: result[key] = _snapshot_value(value[key])
		return result
	return value

func snapshot() -> Dictionary:
	return {"tick":clock.tick,"rng_state":rng.get_state(),"actors":_snapshot_value(actors),"reservations":activity_reservations.duplicate(),"gathering":gathering_staged,"report":chapter_report,"phase":phase}
