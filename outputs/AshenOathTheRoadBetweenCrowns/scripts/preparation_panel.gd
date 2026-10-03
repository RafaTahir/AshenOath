extends RefCounted

# Plain-text presentation only. Services own all availability and mutations.
static func item_text(detail: Dictionary) -> String:
	var lines: Array[String] = [str(detail.get("title", "Supplies")).to_upper()]
	var cap: int = int(detail.get("cap", -1))
	lines.append("Carrying %d%s%s" % [int(detail.get("owned", 0)), " / %d" % cap if cap > 0 else "", "  ·  Selected" if bool(detail.get("selected", false)) else ""])
	_append(lines, "", str(detail.get("body", "")))
	for raw: Variant in detail.get("effects", []):
		if raw is Dictionary:
			_append(lines, str(raw.get("label", "Effect")), str(raw.get("text", "")))
	var comparisons: Array = detail.get("comparison", [])
	if not comparisons.is_empty():
		lines.append("\nCOMPARED WITH YOUR CURRENT SELECTION")
		for raw: Variant in comparisons:
			if raw is Dictionary:
				var unit: String = str(raw.get("unit", ""))
				lines.append("%s: %s → %s%s" % [str(raw.get("label", "Effect")), str(raw.get("current", "—")), str(raw.get("candidate", "—")), " " + unit if unit != "" else ""])
	for raw: Variant in detail.get("known_use", []):
		if raw is Dictionary:
			_append(lines, str(raw.get("title", "Known use")), str(raw.get("body", "")))
	for raw: Variant in detail.get("actions", []):
		if raw is Dictionary and not bool(raw.get("available", false)):
			_append(lines, "Unavailable now", str(raw.get("reason", "")))
	return "\n".join(lines)

static func craft_text(quote: Dictionary) -> String:
	var lines: Array[String] = ["\nCRAFTING"]
	for raw: Variant in quote.get("costs", []):
		if not raw is Dictionary:
			continue
		var cost: Dictionary = raw
		lines.append("%s: carrying %d / need %d" % [str(cost.get("name", cost.get("id", "Ingredient"))), int(cost.get("owned", 0)), int(cost.get("required", 0))])
		lines.append("Spend %d · Remaining %d%s" % [int(cost.get("spent", cost.get("required", 0))), int(cost.get("after", 0)), " · %d returned through practice" % int(cost.get("returned", 0)) if int(cost.get("returned", 0)) > 0 else ""])
	if bool(quote.get("ok", false)):
		lines.append("Makes %d. Ingredients are spent when you craft." % int(quote.get("output_quantity", 1)))
	else:
		_append(lines, "Unavailable now", str(quote.get("reason", quote.get("message", ""))))
	return "\n".join(lines)

static func purchase_text(quote: Dictionary) -> String:
	var lines: Array[String] = ["\nTHIS EXCHANGE"]
	var quantity: int = int(quote.get("quantity", 0))
	var total: int = int(quote.get("total_price", 0))
	lines.append("Receive %d · Cost %d coin" % [quantity, total])
	lines.append("Afterward: %d / %d carried · %d coin remaining" % [int(quote.get("after", quote.get("owned", 0))), int(quote.get("cap", 0)), int(quote.get("coin_after", 0))])
	_append(lines, "Supply", str(quote.get("supply_note", "")))
	if not bool(quote.get("ok", false)):
		_append(lines, "Unavailable now", str(quote.get("reason", quote.get("message", ""))))
	return "\n".join(lines)

static func practice_text(model: Dictionary) -> String:
	var lines: Array[String] = [str(model.get("title", "Practice")).to_upper(), str(model.get("body", ""))]
	if bool(model.get("learned", false)):
		lines.append("\nLearned. This benefit is already available.")
	else:
		lines.append("\nCost: %d Mark%s" % [int(model.get("cost", 1)), "s" if int(model.get("cost", 1)) != 1 else ""])
		var prerequisite: String = str(model.get("prerequisite_name", ""))
		_append(lines, "Requires", prerequisite)
		if bool(model.get("available", false)):
			lines.append("Marks remaining afterward: %d" % int(model.get("marks_after", 0)))
		else:
			_append(lines, "Unavailable now", str(model.get("reason", "")))
	return "\n".join(lines)

static func decision_text(model: Dictionary) -> String:
	var lines: Array[String] = [str(model.get("label", "This choice")).to_upper()]
	_append(lines, "Commitment", str(model.get("commitment", "")))
	_append(lines, "Cost", str(model.get("cost", "")))
	var known: Array = model.get("known_facts", [])
	for raw: Variant in known.slice(0, 3):
		if raw is Dictionary:
			_append(lines, str(raw.get("title", "Known now")), str(raw.get("text", "")))
	_append(lines, "Still uncertain", str(model.get("uncertainty", "")))
	_append(lines, "What follows now", str(model.get("follow_through", "")))
	if not bool(model.get("available", true)):
		_append(lines, "Unavailable now", str(model.get("reason", "")))
	return "\n".join(lines)

static func _append(lines: Array[String], label: String, value: String) -> void:
	if value.strip_edges() != "":
		lines.append("\n%s%s" % [label + ": " if label != "" else "", value])
