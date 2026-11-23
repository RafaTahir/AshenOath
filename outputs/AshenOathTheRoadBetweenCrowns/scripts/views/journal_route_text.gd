extends RefCounted

static func covenant(campaign: Dictionary, state: Variant) -> Dictionary:
	var value: String = str(state.get_flag("final_covenant", "")) if state != null else ""
	var ending_id: String = preload("res://scripts/ending_catalog.gd").normalize(value)
	if ending_id == "":
		return {}
	for ending in campaign.get("endings", []):
		if str(ending.get("id", "")) != ending_id:
			continue
		var complete: bool = bool(state.get_flag("final_choice_completed", false))
		var body: String = "Chosen intention: " + str(ending.get("intention", ""))
		if complete:
			body += "\n\nWhat this leaves: " + str(ending.get("benefit", "")) + "\n\nWhat it costs: " + str(ending.get("cost", ""))
			body += "\n\n" + "\n\n".join(preload("res://scripts/epilogue_resolver.gd").living_road_cards(state))
		else:
			body += "\n\nThis intention is recorded, but its resolution has not yet been completed. Follow the next known step in the glade."
		return {"id": "covenant:" + ending_id, "title": str(ending.get("title", "Covenant")) + (" — carried out" if complete else " — intention chosen"), "body": body, "status": "completed" if complete else "pending"}
	return {}

static func complete(recap: Dictionary) -> Dictionary:
	var hint: String = str(recap.get("route_hint", ""))
	recap["body"] = "%s\nLast commitment: %s\nNext: %s%s\n%s%s" % [str(recap.promise), str(recap.last_commitment), str(recap.next_action), " (" + str(recap.destination_name) + ")" if str(recap.destination_name) != "" else "", hint + "\n" if hint != "" else "", str(recap.reason)]
	return recap

static func next_step(recap: Dictionary) -> String:
	var next_parts: Array[String] = [str(recap.next_action)]
	if str(recap.destination_name) != "":
		next_parts.append("Where: " + str(recap.destination_name))
	var hint: String = str(recap.get("route_hint", ""))
	if hint != "":
		next_parts.append(hint)
	next_parts.append(str(recap.reason))
	return "\n".join(next_parts)

static func arrival(context: Dictionary, objective_view: Dictionary, recap: Dictionary, reason: String, restored: bool, next_action: String, destination_name: String) -> String:
	var body_parts: Array[String] = []
	if restored:
		var source_label: String = str(context.get("source_label", "")).strip_edges()
		if source_label != "":
			body_parts.append("Recorded source: " + source_label)
		body_parts.append("This moment's recorded story state has been restored.")
	var promise: String = str(recap.get("promise", "")).strip_edges()
	if promise != "":
		body_parts.append(promise)
	if restored:
		var last_commitment: String = str(recap.get("last_commitment", "")).strip_edges()
		if last_commitment != "":
			body_parts.append("Last commitment: " + last_commitment)
	if next_action != "":
		body_parts.append("Next: %s%s" % [next_action, " (" + destination_name + ")" if destination_name != "" else ""])
	if restored or reason in ["new_journey", "new_game"]:
		var route_hint: String = str(recap.get("route_hint", "") if objective_view.is_empty() else objective_view.get("route_hint", "")).strip_edges()
		if route_hint != "" and route_hint.trim_suffix(".") != next_action.trim_suffix("."):
			body_parts.append(route_hint)
	return "\n\n".join(body_parts)

static func objectives(entries: Array, current: String) -> String:
	var body := ""
	for objective: Dictionary in entries:
		var done: bool = bool(objective.get("done", false))
		if current != "" and not done and str(objective.get("id", "")) != current:
			continue
		body += "\n    %s %s" % ["[x]" if done else "[ ]", str(objective.text)]
	return body
