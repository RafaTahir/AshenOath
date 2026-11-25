extends RefCounted
## Only the two banks of the ford share the carter's vocabulary. A strike
## still gets its own sound identity for enemy hearing and event cooldowns.
const ROAD_KNOCKS := ["wychwood_road_call", "wychwood_road_answer", "wychwood_road_grant", "wychwood_road_ack"]
const WINDUPS := {
	"wychwood_stalker": "stalker_husk_rasp", "wychwood_raider": "raider_cord_cinch", "wychwood_brute": "brute_heel_set"
}
const ATTACKS := {
	"wychwood_stalker": "stalker_branch_snap", "wychwood_raider": "raider_rake", "wychwood_brute": "brute_blow"
}
const CONTACT_STREAMS := {"stalker_branch_snap":"wood_contact", "raider_rake":"flesh_contact", "brute_blow":"heavy_hit"}

static func event_for(species: String, phase: String) -> String:
	match phase:
		"windup": return WINDUPS[species]
		"attack": return ATTACKS[species]
		"hit": return "flesh_contact"
		"death": return "wood_contact"
	return ""
