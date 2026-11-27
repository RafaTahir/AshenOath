extends RefCounted

const Rules = preload("res://scripts/community_campaign.gd")
const Ending = preload("res://scripts/community_ending.gd")

static func shift_text(game: Node, zone: String) -> String:
	var lines: Array[String] = ["People use the public rooms in two shifts. The shelter bench lets you wait until morning or evening."]
	for shift: String in ["morning","evening"]:
		var names: Array[String] = []
		for id: String in Rules.data().get("presence_shifts",{}).get(zone,{}).get(shift,[]):
			if Rules.actor_available(id,game.story_state,game.quests): names.append(str(Rules.data().participant_lines[id].name))
		lines.append(shift.capitalize()+": "+", ".join(names)+".")
	return "\n".join(lines)

static func rota_text(game: Node) -> String:
	var answers: Dictionary = game.story_state.get_flag("community_keeper_consent",{})
	var lines: Array[String] = ["Recorded shifts — food and shelter do not depend on joining:"]
	for id: String in Rules.data().consent_offers:
		var value: Variant = answers.get(id)
		lines.append(id.capitalize()+": "+("offered; may withdraw" if typeof(value)==TYPE_BOOL and value else "vacant — no current agreement"))
	return "\n".join(lines)

static func participant(game: Node, zone: String, id: String, reply: String) -> Dictionary:
	if id not in Rules.REGIONAL_ACTORS.get(zone,[]) or not Rules.actor_available(id,game.story_state,game.quests): return {}
	var row: Dictionary = Rules.data().get("participant_lines",{}).get(id,{})
	var words := reply if reply != "" else str(row.get(zone,""))
	var pages: Array = [{"speaker":str(row.get("name",id.capitalize())),"speaker_id":str(Rules.ACTORS[id]),"text":words,"performance":{"emotion":"warmth","gesture":"reassure"}}]
	var actions: Array[Dictionary] = []
	if Rules.consent_available(id,game.story_state,game.quests):
		var offer: Dictionary = Rules.data().consent_offers[id]
		pages.append({"speaker":"Kael","speaker_id":"player","text":str(offer.question),"performance":{"gesture":"guarded_listening"}})
		# Ask each person for an answer. A separately presented answer is then
		# recorded, so a menu cannot substitute Kael's choice for their speech.
		actions.append({"operation":"ask_consent","id":id,"label":"Hear the shift they are offering."})
		actions.append({"operation":"ask_refusal","id":id,"label":"Leave this responsibility open."})
		var consent: Dictionary = game.story_state.get_flag("community_keeper_consent",{})
		if consent.get(id) == true: actions.append({"operation":"withdraw","id":id,"label":"Release the recorded shift."})
	if Ending.offers_available(id,game.story_state,game.quests):
		var offer: Dictionary=Rules.data().departure_offers[id]
		pages.append({"speaker":"Kael","speaker_id":"player","text":str(offer.question),"performance":{"gesture":"guarded_listening"}})
		if not Ending.chooses_to_stay(id,game.story_state):
			actions.append({"operation":"ask_departure_yes","id":id,"label":"Hear whether they choose to relocate."})
		actions.append({"operation":"ask_departure_no","id":id,"label":"Hear their decision to remain."})
		if game.story_state.get_flag(Ending.DEPARTURE_ANSWERS,{}).get(id)==true: actions.append({"operation":"withdraw_departure","id":id,"label":"Withdraw their recorded departure."})
	return {"title":str(row.get("name",id.capitalize())),"pages":pages,"actions":actions}
