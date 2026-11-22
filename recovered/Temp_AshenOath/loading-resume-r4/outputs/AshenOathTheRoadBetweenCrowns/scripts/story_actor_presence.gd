extends RefCounted

const DEPARTED_OUTCOMES := {
	"captain_senn": ["exile", "punished"],
	"halvern": ["released", "destroyed"],
}

static func remains(actor_id: String, outcome: String) -> bool:
	return not DEPARTED_OUTCOMES.get(actor_id, []).has(outcome)
