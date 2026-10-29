extends RefCounted

## Authored deeds only. StoryState owns the ledger; no prices, XP or ending gates.
const ALIASES := {"sister_anwen":"anwen", "blacksmith_tor":"tor", "vargan_record_keeper":"vale", "vargan_steward":"merrow", "captain_senn":"senn"}
const DEEDS := {
	"bracken_rescue":{"flag":"bracken_bond_events", "member":"rescue", "weight":5, "text":"Freed Bracken from the trap.", "known":[]},
	"kitchen_flour":{"flag":"cart_helped", "value":true, "weight":2, "text":"Helped Rook carry flour to the common kitchen.", "known":["rook", "nessa"]},
	"kitchen_drain":{"flag":"road_repaired", "value":true, "weight":2, "text":"Helped Tor clear the kitchen road's drain.", "known":["tor"]},
	"traveler_water":{"flag":"opening_cup_delivered", "value":true, "weight":2, "text":"Brought water to Anwen's injured traveler.", "known":["anwen"]},
	"rook_privacy_kept":{"flag":"rook_disclosure", "value":"protected", "requires":{"lr_rook_privacy":"promised"}, "memory":"lr.rook.privacy.kept", "group":"rook_privacy", "weight":5, "text":"Kept the explicit promise to protect Rook's family mark without destroying the route.", "known":["rook"]},
	"rook_privacy_broken":{"flag":"rook_disclosure", "value":"public", "requires":{"lr_rook_privacy":"promised"}, "memory":"lr.rook.privacy.broken", "group":"rook_privacy", "weight":-15, "text":"Published Rook's family mark after explicitly promising to keep it private.", "known":["rook"], "grievance":["rook"]},
	"grain_help":{"flag":"saga_gre_q01:weigh_next_batch:part", "at_least":2, "group":"grain", "weight":2, "text":"Checked the next grain delivery with Nessa.", "known":["nessa", "toma"]},
	"grain_coercion":{"flag":"saga_gre_q01_outcome", "value":"coerced", "group":"grain", "weight":-10, "text":"Threatened to expose a grain household's address to secure repayment.", "known":["nessa", "toma"], "grievance":["toma"]},
	"bell_work":{"flag":"saga_gre_q02:sound_trial:part", "at_least":2, "weight":2, "text":"Helped restore and publicly test Tor's warning mechanism.", "known":["jory", "tor", "nessa"]},
	"arrivals_shelter":{"flag":"saga_gre_q05:post_terms:part", "at_least":2, "weight":5, "text":"Escorted the arriving travelers to unconditional shelter and delivered its supplies.", "known":["nessa", "anwen"]},
	"friend_tor_hinge":{"flag":"lr_friend_tor_hinge", "value":"worked", "weight":2, "text":"Finished Tor's offered hinge work.", "known":["tor"]},
	"friend_mira_garden":{"flag":"lr_friend_mira_garden", "value":"worked", "weight":2, "text":"Finished the shared work in Mira's garden.", "known":["mira"]},
	"friend_rook_stool":{"flag":"lr_friend_rook_stool", "value":"worked", "weight":2, "text":"Repaired Rook's stool through the offered shared work.", "known":["rook"]},
	"friend_anwen_shrine":{"flag":"lr_friend_anwen_shrine", "value":"worked", "weight":2, "text":"Finished the shrine work Anwen asked to share.", "known":["anwen"]},
	"freight_help":{"flag":"saga_dep_q01:mark_next_load:part", "at_least":2, "group":"dispatch", "weight":2, "text":"Marked the next freight load against the current account.", "known":["dain"]},
	"dispatch_falsified":{"flag":"saga_dep_q01:mark_next_load:part", "at_least":2, "requires":{"saga_dep_q01_outcome":"falsified"}, "group":"dispatch", "weight":-10, "text":"Knowingly placed a false current dispatch on the next freight load.", "known":["dain"], "grievance":["dain"]},
	"servant_pass":{"flag":"saga_var_q02:confirm_departure:part", "at_least":1, "group":"complaint", "weight":2, "text":"Delivered the servant household's passage documents.", "known":["merrow", "servant"]},
	"complaint_silenced":{"flag":"saga_var_q02:deliver_copy:part", "at_least":2, "requires":{"saga_var_q02_outcome":"conditional_pass"}, "group":"complaint", "weight":-10, "text":"Accepted Merrow's family pass on condition that the optional complaint was withheld.", "known":["merrow", "servant"], "grievance":["servant"]}
}

static func actor_key(id: String) -> String:
	var key := str(ALIASES.get(id, id.trim_prefix("saga_")))
	var person := preload("res://scripts/story_cast_profile.gd").canonical_identity(key)
	return person if person != "" else key

static func includes_actor(people: Array, actor: String) -> bool:
	for person: String in people:
		if actor_key(person) == actor:
			return true
	return false

static func satisfied(state, rule: Dictionary) -> bool:
	if rule.has("memory"):
		var memories: Variant = state.get_flag("living_road_relationships", {})
		if not memories is Dictionary or not memories.has(str(rule.memory)): return false
	var actual: Variant = state.get_flag(str(rule.flag), null)
	if rule.has("member"):
		if not actual is Dictionary or not actual.has(str(rule.member)):
			return false
	elif rule.has("at_least"):
		if (not actual is int and not actual is float) or not is_finite(float(actual)) or int(actual) < int(rule.at_least):
			return false
	elif actual != rule.get("value"):
		return false
	for key: String in rule.get("requires", {}):
		if state.get_flag(key, null) != rule.requires[key]:
			return false
	return true

static func band(score: int) -> String:
	return "Distrusted" if score <= -10 else ("Respected" if score >= 10 else "Unproven")
