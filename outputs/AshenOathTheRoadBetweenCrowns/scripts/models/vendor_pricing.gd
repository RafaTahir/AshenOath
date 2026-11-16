extends RefCounted

static func apply(vendor_id: String, entry: Dictionary, state: Dictionary) -> void:
	var item_id := str(entry.get("item_id", ""))
	var price := int(entry["price"])
	var iron := str(state.get("iron_fate", ""))
	var treatment := str(state.get("mira_treatment", ""))
	var truth := str(state.get("mira_truth", ""))
	var mill := str(state.get("mill_operation", ""))
	var reason := ""
	if vendor_id == "tor_forge":
		if iron == "memorial" and item_id == "iron_trap":
			price -= 2
			reason = "Tor's replacement work leaves prepared trap parts."
		elif iron == "tools" and item_id in ["standard_arrow", "bodkin_arrow"]:
			price -= 1
			reason = "Acknowledged village tools support ordinary repair and arrows."
		elif iron == "surrendered":
			if item_id == "standard_arrow":
				price = 1
				reason = "The village reserve keeps ordinary arrows available."
			elif item_id in ["bodkin_arrow", "ashfire_arrow", "iron_trap"]:
				price += 1
				reason = "Shared stock takes extra labor; ordinary arrows remain affordable."
	if vendor_id == "mira_apothecary" and item_id in ["redroot_potion", "bitterleaf_tonic"]:
		if truth == "confessed" or treatment == "consented":
			price -= 1
			reason = "Disclosed treatment and agreed assistance support the dispensary."
		elif truth == "destroyed" or treatment == "replacement":
			price += 1
			reason = "Replacement medicine needs more gathering; basic care stays available."
		if mill == "closed":
			price += 1
			reason += " Relief supplies replace the closed mill."
		elif mill == "restitution":
			price -= 1
			reason += " Mill restitution helps pay for care."
		elif mill == "supervised":
			reason += " Supervised supplies keep basic medicine in circulation."
	# Consequences alter preparation within a bounded range; essentials never vanish.
	entry["price"] = clampi(price, 1, maxi(int(entry["price"]) + 2, 1))
	entry["supply_note"] = reason.strip_edges()
